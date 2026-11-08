"""Tests for webhook_verifier.verify().

All 7 cases required by the review checklist are covered:
1. Valid recent signature → no exception
2. Valid but stale → InvalidSignature
3. Wrong signature (tampered digest) → InvalidSignature
4. Malformed header (no t=) → InvalidSignature
5. Missing header (None) → InvalidSignature
6. Wrong secret → InvalidSignature
7. Tampered body → InvalidSignature

the header carries a LIST of `sha256=` values
during a dual-signature secret roll (current secret first, previous
secret second, for 24h after a roll). The verifier must accept the
delivery if ANY value matches, and must parse the list from day one even
though outside a roll there is exactly one value. See
TestMultipleSha256Values. The verifier also rejects
a tampered `t=` specifically (not just a tampered body) — see
test_tampered_timestamp_raises.

Review fixes, added in the same change:
- TestToleranceBoundary (fix #1): the 300s window is symmetric in both
  directions — exercises the exact boundary at -300/-301/+300/+301.
- TestMalformedDigest (fix #2): a malformed `sha256=` value (wrong
  length, non-hex, uppercase, non-ASCII, empty) must be rejected through
  verify()'s normal InvalidSignature path, not crash hmac.compare_digest
  with an uncaught TypeError.
- TestStrictHeaderGrammar (fix #3): the header grammar is ASCII-digits-
  only for `t=`, exactly one `t=`, at most 2 `sha256=` values, and
  unknown keys are ignored (forward-compatible), documented in
  webhook_verifier.verify()'s docstring.
- TestGoldenVector (fix #7): a fixed (secret, timestamp, body, header)
  tuple that is also asserted by the Bawarii platform's own signing tests;
  keep both in sync.
"""

import hashlib
import hmac

import pytest

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from webhook_verifier import InvalidSignature, verify


SECRET = "test-webhook-secret-xyz"
FIXED_NOW = 1_700_000_000.0


def _make_header(
    body: bytes,
    secret: str = SECRET,
    timestamp: int = int(FIXED_NOW),
) -> str:
    signed_payload = f"{timestamp}.".encode("ascii") + body
    digest = hmac.new(
        secret.encode("ascii"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()
    return f"t={timestamp},sha256={digest}"


BODY = b'{"event":"verification.decision","session_id":"ses_abc123"}'


# ─── Case 1: valid recent signature ──────────────────────────────────────────


def test_valid_signature_passes() -> None:
    header = _make_header(BODY)
    # Must not raise
    verify(
        signature_header=header,
        raw_body=BODY,
        secret=SECRET,
        now=lambda: FIXED_NOW,
    )


# ─── Case 2: stale timestamp ─────────────────────────────────────────────────


def test_stale_signature_raises() -> None:
    stale_timestamp = int(FIXED_NOW) - 301
    header = _make_header(BODY, timestamp=stale_timestamp)
    with pytest.raises(InvalidSignature, match="stale"):
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 3: tampered digest ─────────────────────────────────────────────────


def test_wrong_digest_raises() -> None:
    header = f"t={int(FIXED_NOW)},sha256=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    with pytest.raises(InvalidSignature, match="mismatch"):
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 4: malformed header (missing t=) ───────────────────────────────────


def test_malformed_header_no_t_raises() -> None:
    header = "sha256=abc123"
    with pytest.raises(InvalidSignature, match="malformed"):
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 5: missing header (None) ───────────────────────────────────────────


def test_none_header_raises() -> None:
    with pytest.raises(InvalidSignature, match="missing"):
        verify(
            signature_header=None,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 6: wrong secret ────────────────────────────────────────────────────


def test_wrong_secret_raises() -> None:
    header = _make_header(BODY, secret="correct-secret")
    with pytest.raises(InvalidSignature, match="mismatch"):
        verify(
            signature_header=header,
            raw_body=BODY,
            secret="wrong-secret",
            now=lambda: FIXED_NOW,
        )


# ─── Case 7: tampered body ───────────────────────────────────────────────────


def test_tampered_body_raises() -> None:
    original_body = b'{"event":"verification.decision","session_id":"ses_abc123"}'
    header = _make_header(original_body)
    tampered_body = b'{"event":"verification.decision","session_id":"ses_EVIL999"}'
    with pytest.raises(InvalidSignature, match="mismatch"):
        verify(
            signature_header=header,
            raw_body=tampered_body,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 8: tampered timestamp ───────────────────────────


def test_tampered_timestamp_raises() -> None:
    """The `t=` value is itself part of the signed string — rewriting it
    to a fresh timestamp while keeping the original digest (an attacker
    trying to defeat the freshness check without resigning) must fail
    signature verification, not merely look "stale"."""
    header = _make_header(BODY, timestamp=int(FIXED_NOW) - 100)
    original_ts, digest = header.split(",", 1)
    assert original_ts.startswith("t=")
    forged_header = f"t={int(FIXED_NOW)},{digest}"
    with pytest.raises(InvalidSignature, match="mismatch"):
        verify(
            signature_header=forged_header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── Case 9: malformed header (no sha256= at all) ────────────────────────────


def test_malformed_header_no_sha256_raises() -> None:
    header = f"t={int(FIXED_NOW)}"
    with pytest.raises(InvalidSignature, match="malformed"):
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── multiple sha256= values (dual-signature roll) ─


class TestMultipleSha256Values:
    """During a 24h dual-signature roll, the header carries two `sha256=`
    values — current secret first, previous secret second. The verifier
    must accept if EITHER matches, and must keep rejecting a header where
    NEITHER matches."""

    def test_accepts_when_first_value_matches_current_secret(self) -> None:
        current_secret = "new-secret"
        previous_secret = "old-secret"
        timestamp = int(FIXED_NOW)
        current_digest = _make_header(BODY, secret=current_secret, timestamp=timestamp).split(
            "sha256="
        )[1]
        previous_digest = _make_header(BODY, secret=previous_secret, timestamp=timestamp).split(
            "sha256="
        )[1]
        header = f"t={timestamp},sha256={current_digest},sha256={previous_digest}"

        verify(
            signature_header=header,
            raw_body=BODY,
            secret=current_secret,
            now=lambda: FIXED_NOW,
        )

    def test_accepts_when_second_value_matches_previous_secret(self) -> None:
        """A tenant still configured with the OLD secret (hasn't rolled
        over yet) must still verify during the grace window."""
        current_secret = "new-secret"
        previous_secret = "old-secret"
        timestamp = int(FIXED_NOW)
        current_digest = _make_header(BODY, secret=current_secret, timestamp=timestamp).split(
            "sha256="
        )[1]
        previous_digest = _make_header(BODY, secret=previous_secret, timestamp=timestamp).split(
            "sha256="
        )[1]
        header = f"t={timestamp},sha256={current_digest},sha256={previous_digest}"

        verify(
            signature_header=header,
            raw_body=BODY,
            secret=previous_secret,
            now=lambda: FIXED_NOW,
        )

    def test_rejects_when_neither_value_matches(self) -> None:
        timestamp = int(FIXED_NOW)
        wrong_digest_1 = "a" * 64
        wrong_digest_2 = "b" * 64
        header = f"t={timestamp},sha256={wrong_digest_1},sha256={wrong_digest_2}"

        with pytest.raises(InvalidSignature, match="mismatch"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_single_value_outside_a_roll_still_works(self) -> None:
        """Regression guard: the common (non-roll) case of exactly one
        `sha256=` value must keep working unchanged."""
        header = _make_header(BODY)

        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── tolerance boundary, both directions ──


class TestToleranceBoundary:
    """The freshness check is `abs(time.time() - sent_ts) >
    MAX_AGE_SECONDS` — symmetric. These pin the exact boundary on both
    sides with `now` frozen/injected, rather than only exercising one
    stale case (the pre-fix test suite only had `now - 301`)."""

    def test_timestamp_exactly_300s_in_the_past_is_accepted(self) -> None:
        header = _make_header(BODY, timestamp=int(FIXED_NOW) - 300)
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )

    def test_timestamp_301s_in_the_past_is_rejected(self) -> None:
        header = _make_header(BODY, timestamp=int(FIXED_NOW) - 301)
        with pytest.raises(InvalidSignature, match="stale"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_timestamp_exactly_300s_in_the_future_is_accepted(self) -> None:
        header = _make_header(BODY, timestamp=int(FIXED_NOW) + 300)
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )

    def test_timestamp_301s_in_the_future_is_rejected(self) -> None:
        header = _make_header(BODY, timestamp=int(FIXED_NOW) + 301)
        with pytest.raises(InvalidSignature, match="stale"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )


# ─── malformed digest must not crash ───────────


class TestMalformedDigest:
    """A `sha256=` value that isn't 64 lowercase hex characters must be
    rejected through verify()'s normal InvalidSignature path. Before this
    fix, a non-ASCII digest reached `hmac.compare_digest(expected,
    digest)`, which raises TypeError (not InvalidSignature) on a string
    containing non-ASCII characters — an uncaught 500 at the HTTP layer
    instead of a 401."""

    def test_non_hex_characters_are_rejected(self) -> None:
        bad_digest = "g" * 64  # 'g' is outside [0-9a-f]
        header = f"t={int(FIXED_NOW)},sha256={bad_digest}"
        with pytest.raises(InvalidSignature, match="malformed"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_wrong_length_is_rejected(self) -> None:
        bad_digest = "a" * 63  # one short of 64
        header = f"t={int(FIXED_NOW)},sha256={bad_digest}"
        with pytest.raises(InvalidSignature, match="malformed"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_uppercase_hex_is_rejected(self) -> None:
        """Decision (documented in webhook_verifier.verify()'s docstring):
        uppercase hex is REJECTED, not normalized — even when it is the
        uppercased form of the otherwise-correct digest."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        correct_digest = correct_header.split("sha256=")[1]
        header = f"t={timestamp},sha256={correct_digest.upper()}"
        with pytest.raises(InvalidSignature, match="malformed"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_non_ascii_digest_is_rejected_not_crashed(self) -> None:
        """Reproduces the exact pre-fix crash: a digest containing a
        non-ASCII character used to raise TypeError out of
        hmac.compare_digest instead of InvalidSignature."""
        bad_digest = "\xff" + "a" * 63
        header = f"t={int(FIXED_NOW)},sha256={bad_digest}"
        with pytest.raises(InvalidSignature, match="malformed"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_empty_digest_is_rejected(self) -> None:
        header = f"t={int(FIXED_NOW)},sha256="
        with pytest.raises(InvalidSignature, match="malformed"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_one_malformed_one_well_formed_correct_digest_still_verifies(self) -> None:
        """A roll header where one candidate is malformed and the other is
        the well-formed, correct digest must still verify — the malformed
        candidate is dropped, not treated as poisoning the whole header."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        correct_digest = correct_header.split("sha256=")[1]
        bad_digest = "\xff" + "a" * 63
        header = f"t={timestamp},sha256={bad_digest},sha256={correct_digest}"

        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── strict header grammar ─────────────────────


class TestStrictHeaderGrammar:
    """`t=` must be ASCII digits only, parsed with `re.fullmatch`, not
    Python's `int()` (which also accepts a leading '+', '_' digit-group
    separators, non-ASCII decimal digits, and surrounding whitespace).
    Exactly one `t=` is allowed. At most 2 `sha256=` values are allowed
    (a roll never needs more than 2). An unrecognized
    `key=value` segment is ignored, not rejected (forward compatibility,
    documented in verify()'s docstring)."""

    def test_leading_plus_sign_timestamp_is_rejected(self) -> None:
        """Python's int('+1700000000') == 1700000000, but '+' is not an
        ASCII digit — must be rejected even though int() would accept it."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t=+{timestamp},sha256={digest}"
        with pytest.raises(InvalidSignature, match="not an integer"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_underscore_digit_separator_timestamp_is_rejected(self) -> None:
        """Python's int('1_700_000_000') == 1700000000 — must be rejected
        even though it round-trips to the correct, freshly-signed value."""
        timestamp = int(FIXED_NOW)
        assert timestamp == 1_700_000_000
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t=1_700_000_000,sha256={digest}"
        with pytest.raises(InvalidSignature, match="not an integer"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_arabic_indic_digits_timestamp_is_rejected(self) -> None:
        """Python's int() accepts non-ASCII Unicode decimal digits (e.g.
        Arabic-Indic ٠-٩) — `\\d` without re.ASCII would too. The header
        grammar is ASCII digits only."""
        header = f"t=١٧٠٠٠٠٠٠٠٠٠,sha256={'a' * 64}"
        with pytest.raises(InvalidSignature, match="not an integer"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_padded_whitespace_timestamp_is_rejected(self) -> None:
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t= {timestamp} ,sha256={digest}"
        with pytest.raises(InvalidSignature, match="not an integer"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_leading_zero_timestamp_is_rejected(self) -> None:
        """Python's int('01700000000') == 1700000000, but a leading zero
        is not canonical ASCII-digit form — must be rejected even though
        int() would silently normalise it to the correctly-signed value.
        A port that signs the raw `t=` string rather than int()'s
        normalised value would disagree with this verifier otherwise."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t=0{timestamp},sha256={digest}"
        with pytest.raises(InvalidSignature, match="not an integer"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_duplicate_t_is_rejected_not_last_wins(self) -> None:
        timestamp = int(FIXED_NOW)
        stale_timestamp = timestamp - 100_000
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t={stale_timestamp},t={timestamp},sha256={digest}"
        with pytest.raises(InvalidSignature, match="duplicate"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_two_sha256_values_is_the_allowed_maximum(self) -> None:
        """Regression guard for the cap itself: exactly 2 (the dual-
        signature roll's maximum) must still verify."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t={timestamp},sha256={'f' * 64},sha256={digest}"
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )

    def test_three_sha256_values_is_rejected(self) -> None:
        """Only one roll can be pending at a time, so a
        legitimate header never carries more than 2 `sha256=` values."""
        timestamp = int(FIXED_NOW)
        correct_header = _make_header(BODY, timestamp=timestamp)
        digest = correct_header.split("sha256=")[1]
        header = f"t={timestamp},sha256={'e' * 64},sha256={'f' * 64},sha256={digest}"
        with pytest.raises(InvalidSignature, match="too many"):
            verify(
                signature_header=header,
                raw_body=BODY,
                secret=SECRET,
                now=lambda: FIXED_NOW,
            )

    def test_unknown_key_is_ignored_not_rejected(self) -> None:
        """Forward compatibility (documented in verify()'s docstring): an
        unrecognized `key=value` segment must not break verification of an
        otherwise-valid header."""
        header = f"v=1,{_make_header(BODY)}"
        verify(
            signature_header=header,
            raw_body=BODY,
            secret=SECRET,
            now=lambda: FIXED_NOW,
        )


# ─── golden vector shared with the Bawarii platform ──
#
# KEEP THIS BLOCK IDENTICAL to the GOLDEN_* constants in the Bawarii
# platform's webhook signing tests — the two assert sign and
# verify agree on the exact same (secret, timestamp, body) tuple. If you
# change one, change the other in the same change.

GOLDEN_SECRET = "bwr_whsec_TESTONLYbawariiGoldenVectorDoNotUse12345"
GOLDEN_TIMESTAMP = 1735689600  # 2025-01-01T00:00:00Z — fixed, arbitrary
# NIT: the previous vector paired assurance_level=2 with a
# not_enabled face-match reason — a combination the decision engine can
# never actually produce (assurance_level=2 only comes from
# OCR_BIOMETRIC_CONFIRMED, which requires a real facial_similarity match,
# never a skipped/not-performed one). Regenerated with the pair the
# automatic path really writes: assurance_level=1 (PHASE1A_NO_FACE_MATCH)
# with reason=phase1a_degraded. Keep identical to the platform's
# GOLDEN_* constants — this verifier
# doesn't parse the body's JSON shape at all (verify() treats it as opaque
# bytes), so this change is purely to keep the two repos' fixed vectors in
# lockstep.
GOLDEN_BODY = (
    b'{"event":"verification.decision","event_id":"evt_'
    b"00000000000000000000000000000000"
    b'","session_id":"sess_goldenvector0001",'
    b'"tenant_id":"tnt_golden_test","reference_id":"ref_goldenvector0001",'
    b'"decision":"APPROVED","assurance_level":1,'
    b'"decision_source":"automatic","decided_at":"2025-01-01T00:00:00+00:00",'
    b'"environment":"production",'
    b'"checks":{"face_match":{"status":"not_performed","reason":"phase1a_degraded"}}}'
)
GOLDEN_HEADER = (
    "t=1735689600,"
    "sha256=535a606e9521edb867b4b1bde2b23b7db100af52a1af360172a0246da27e5fac"
)


class TestGoldenVector:
    """Pins this repo's verify side against the fixed vector the service
    repo's signing side checks on the other side — a change to either
    repo's signed-string construction fails this test loudly before it
    fails in integration."""

    def test_verify_accepts_the_golden_vector(self) -> None:
        verify(
            signature_header=GOLDEN_HEADER,
            raw_body=GOLDEN_BODY,
            secret=GOLDEN_SECRET,
            now=lambda: float(GOLDEN_TIMESTAMP),
        )
