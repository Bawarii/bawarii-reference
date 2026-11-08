import hmac
import hashlib
import re
import time
from collections.abc import Callable

# Canonical non-negative integer, up to 12 digits: "0", or a non-zero
# digit followed by up to 11 more digits — `0|[1-9][0-9]{0,11}`. No
# leading zeros: "01700000000" is NOT a valid `t=` value, even though
# Python's int() would normalise it to the same number a bare
# "[0-9]{1,12}" match would accept — a port that signs the raw string
# rather than the int() value would disagree with this verifier on what
# was signed. Deliberately NOT `\d` (which, without re.ASCII, also
# matches non-ASCII decimal digits such as Arabic-Indic ٠-٩) and
# deliberately not Python's int(), which additionally accepts a leading
# "+", underscore digit-group separators ("1_700_000_000") and
# surrounding whitespace — none of which are a valid `t=` value per the
# header grammar.
_TIMESTAMP_RE = re.compile(r"0|[1-9][0-9]{0,11}")

# A SHA-256 hex digest: exactly 64 lowercase hex characters. Checked
# BEFORE any value reaches hmac.compare_digest(), which raises TypeError
# on a non-ASCII-only string instead of returning False — an unvalidated
# digest can therefore crash the verifier (500) rather than simply fail
# verification (401). Uppercase hex is deliberately rejected, not
# normalized: Bawarii always emits lowercase, so an uppercase digest is
# either a non-compliant sender or tampering, and normalizing it would
# quietly widen what this verifier accepts beyond the documented format.
_DIGEST_RE = re.compile(r"[0-9a-f]{64}")

# The dual-signature secret roll carries at most TWO
# `sha256=` values (current secret first, previous second), and "only one
# roll can be pending at a time" — so a legitimate header never carries
# more than two. Capping here bounds the number of digest comparisons a
# caller can force the verifier to perform per request.
_MAX_SHA256_VALUES = 2


class InvalidSignature(Exception):
    """Raised when a Bawarii webhook signature fails any validation step."""


def verify(
    *,
    signature_header: str | None,
    raw_body: bytes,
    secret: str,
    now: Callable[[], float] = time.time,
    max_age_seconds: int = 300,
) -> None:
    """Verify a Bawarii webhook signature header.

    Returns ``None`` on success.  Raises ``InvalidSignature`` on any failure.

    The header format is::

        t={canonical_unix_timestamp},sha256={hex_digest}[,sha256={hex_digest}...]

    where ``{canonical_unix_timestamp}`` is ``0|[1-9][0-9]{0,11}`` — ASCII
    digits, no leading zeros. A value such as ``01700000000`` is rejected
    as malformed even though it normalises to a valid timestamp under
    Python's int(): this verifier signs the *canonical* decimal string,
    and a leading zero would make a port that signs the raw `t=` string
    disagree with it about what was signed.

    One or more ``sha256=`` values may be present — a dual-
    signature secret roll carries both the new and the old secret's digest
    in a single header (current secret first) for 24h after a roll, so
    integrators who haven't picked up the new secret yet still verify.
    Outside a roll there is exactly one ``sha256=`` value. This verifier
    accepts the delivery if the timestamp is fresh AND *any* ``sha256=``
    value matches — it must parse a list from day one even
    though only one value is ever sent today (the roll itself is implemented
    separately). A header is rejected as malformed if it carries more than
    ``_MAX_SHA256_VALUES`` (2) ``sha256=`` values, or more than one ``t=``.

    Both the past AND the future are bounded, symmetrically, by
    ``max_age_seconds``: ``abs(time.time() - sent_ts) >
    MAX_AGE_SECONDS`` — a timestamp far in the future is rejected exactly
    like a stale one, rather than only bounding staleness in one direction.

    Any key in the header other than ``t`` or ``sha256`` is ignored, not
    rejected — this mirrors the Stripe-style signed-payload scheme's own
    forward-compatibility behaviour (this verifier follows that precedent
    by design, see below) and general forward-compatibility
    stance for the 0.x contract: a future Bawarii release must be able to
    add a new header segment without instantly breaking every
    already-deployed integrator verifier copied from this file.

    The signed payload is::

        f"{timestamp}.".encode('ascii') + raw_body

    This mirrors the Stripe-style signed-payload scheme so integrators can
    re-use the same verification library.
    """
    if signature_header is None:
        raise InvalidSignature("missing header")

    # Parse t={timestamp},sha256={hex_digest}[,sha256={hex_digest}...].
    # Grammar is enforced strictly: exactly one
    # `t=`, at most `_MAX_SHA256_VALUES` `sha256=` values, and unknown
    # `key=value` segments are ignored rather than rejected (see the
    # forward-compatibility note in the docstring).
    timestamp_str: str | None = None
    digests: list[str] = []
    for part in signature_header.split(","):
        part = part.strip()
        key, sep, value = part.partition("=")
        if not sep:
            continue
        if key == "t":
            if timestamp_str is not None:
                raise InvalidSignature("malformed header: duplicate t=")
            timestamp_str = value
        elif key == "sha256":
            if len(digests) >= _MAX_SHA256_VALUES:
                raise InvalidSignature("malformed header: too many sha256= values")
            digests.append(value)

    if timestamp_str is None or not digests:
        raise InvalidSignature("malformed header")

    if not _TIMESTAMP_RE.fullmatch(timestamp_str):
        raise InvalidSignature("malformed header: timestamp is not an integer")
    timestamp = int(timestamp_str)

    if abs(now() - timestamp) > max_age_seconds:
        raise InvalidSignature("stale")

    # Each candidate digest must look like a SHA-256 hex digest BEFORE it
    # is handed to hmac.compare_digest(), which raises TypeError (crashing
    # the caller with a 500) rather than returning False when given a
    # string containing non-ASCII characters. A value that doesn't match
    # is a malformed header, not a signature mismatch — and is rejected
    # through this same InvalidSignature path either way.
    well_formed_digests = [d for d in digests if _DIGEST_RE.fullmatch(d)]
    if not well_formed_digests:
        raise InvalidSignature("malformed header: invalid sha256 digest format")

    signed_payload = f"{timestamp}.".encode("ascii") + raw_body
    expected = hmac.new(
        secret.encode("ascii"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()

    # Constant-time compare against each well-formed candidate; accept if
    # any matches.
    if not any(hmac.compare_digest(expected, digest) for digest in well_formed_digests):
        raise InvalidSignature("signature mismatch")
