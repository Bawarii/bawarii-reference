import 'reference_workflow.dart';
import 'verdict.dart';

/// Typed model for the result returned by `GET /reference/result/{sessionId}`.
///
/// The API response shape (proxied verbatim from the Bawarii platform):
/// ```json
/// {
///   "session_id": "...",
///   "verdict": "APPROVED",
///   "workflow": "document_and_liveness",
///   "pending_steps": [],
///   "assurance_level": 2,
///   "reference_id": "...",
///   "fields": {
///     "document_type": "E_TAZKIRA",
///     "extracted_fields_hash": "...",
///     "national_id": "...",
///     "dob_gregorian": "...",
///     "date_of_expiry_gregorian": "...",
///     "sex": "M",
///     "given_name_latin": "TEST",
///     "surname_latin": "PERSON",
///     "full_name": "TEST PERSON"
///   } | null,
///   "rejection_reasons": [] | null,
///   "checked_at": "2026-07-05T10:00:00Z",
///   "extraction_meta": {
///     "field_confidences": {"national_id": 0.95, "surname_latin": 0.90},
///     "sides": {
///       "front": {"status": "ACCEPTED", "issues": [], "ocr_confidence": 0.93, "mrz_valid": null},
///       "back": {"status": "ACCEPTED", "issues": ["NAME_TOKEN_REPAIRED"], "ocr_confidence": 0.95, "mrz_valid": true}
///     },
///     "mrz_valid": true,
///     "ocr_confidence": 0.95,
///     "issues": ["NAME_TOKEN_REPAIRED"],
///     "schema_version": "1.0"
///   } // key entirely absent (not null) when the platform has no data for it
/// }
/// ```
///
final class ReferenceResult {
  const ReferenceResult({
    required this.sessionId,
    required this.verdict,
    required this.workflow,
    required this.referenceId,
    required this.checkedAt,
    this.createdAt,
    this.assuranceLevel,
    this.fullName,
    this.dateOfBirth,
    this.nationalId,
    this.documentType,
    this.givenNameLatin,
    this.surnameLatin,
    this.sex,
    this.dateOfExpiryGregorian,
    this.rejectionReasons = const [],
    this.pendingSteps = const [],
    this.extractionMeta,
    this.rawJson,
  });

  final String sessionId;
  final Verdict verdict;
  final ReferenceWorkflow workflow;
  final String? referenceId;
  final String? checkedAt;

  /// Session creation timestamp.
  final String? createdAt;

  /// `0`–`3`. Null on responses that
  /// predate this field — callers fall back to a verdict-derived default.
  final int? assuranceLevel;

  // ── Fields from nested "fields" object ──────────────────────────────────────
  final String? fullName;
  final String? dateOfBirth;
  final String? nationalId;
  final String? documentType;

  /// Design: `full_name` is a composite the backend returns
  /// alongside its constituents, but `field_confidences` is keyed per
  /// constituent (`given_name_latin` / `surname_latin`) — a composite value
  /// cannot carry an honest confidence, so the client tier shows these
  /// separately rather than the composite. Null on older/legacy responses
  /// whose `fields` blob only ever had `full_name`.
  final String? givenNameLatin;
  final String? surnameLatin;

  /// `sex` and `date_of_expiry_gregorian` — present in the real `fields`
  /// blob (Appendix B.2) alongside `national_id` and `dob_gregorian`, and
  /// part of the canonical six-row identity breakdown. Null on
  /// older/legacy responses.
  final String? sex;
  final String? dateOfExpiryGregorian;

  final List<String> rejectionReasons;
  final List<String> pendingSteps;

  /// Extraction pipeline metadata. Only ever present when the
  /// backend was called with the platform's X-API-Key channel and the
  /// session has a merged canonical document — null otherwise (e.g. the
  /// upstream response simply omits the `extraction_meta` key entirely).
  final ExtractionMeta? extractionMeta;

  /// The verbatim decoded response body, retained so the developer panel's
  /// `RAW RESPONSE` group can show the actual payload
  /// rather than a lossy reconstruction from this typed model's fields —
  /// this is the same response already fetched via `/reference/result`, not
  /// a new network call.
  final Map<String, dynamic>? rawJson;

  factory ReferenceResult.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] as Map<String, dynamic>?;
    final extractionMetaJson = json['extraction_meta'] as Map<String, dynamic>?;
    final rejectionReasons = (json['rejection_reasons'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[];
    return ReferenceResult(
      sessionId: json['session_id'] as String,
      verdict: verdictFromApi(
        json['verdict'] as String?,
        rejectionReasons: rejectionReasons,
      ),
      workflow: workflowFromApi(json['workflow'] as String? ?? ''),
      referenceId: json['reference_id'] as String?,
      checkedAt: json['checked_at'] as String?,
      createdAt: json['created_at'] as String?,
      assuranceLevel: json['assurance_level'] as int?,
      fullName: fields?['full_name'] as String?,
      dateOfBirth: fields?['dob_gregorian'] as String?,
      nationalId: fields?['national_id'] as String?,
      documentType: fields?['document_type'] as String?,
      givenNameLatin: fields?['given_name_latin'] as String?,
      surnameLatin: fields?['surname_latin'] as String?,
      sex: fields?['sex'] as String?,
      dateOfExpiryGregorian: fields?['date_of_expiry_gregorian'] as String?,
      rejectionReasons: rejectionReasons,
      pendingSteps: (json['pending_steps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      extractionMeta: extractionMetaJson != null
          ? ExtractionMeta.fromJson(extractionMetaJson)
          : null,
      rawJson: json,
    );
  }
}

/// Per-side OCR extraction metadata, sourced from the
/// platform's `document_sides[side]["extraction"]` — the raw per-side
/// processor output captured at upload time.
final class SideExtractionMeta {
  const SideExtractionMeta({
    required this.status,
    required this.ocrConfidence,
    this.issues = const [],
    this.mrzValid,
  });

  final String status;
  final List<String> issues;
  final double ocrConfidence;

  /// MRZ check-digit validity. Always null for the front side (no MRZ).
  final bool? mrzValid;

  factory SideExtractionMeta.fromJson(Map<String, dynamic> json) {
    return SideExtractionMeta(
      status: json['status'] as String? ?? '',
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 0.0,
      mrzValid: json['mrz_valid'] as bool?,
    );
  }
}

/// Document extraction pipeline metadata: per-field OCR
/// confidence, per-side extraction status/issues, and merged-level MRZ
/// validity / OCR confidence / issues from the verified canonical document.
///
/// X-API-Key only — see [ReferenceResult.extractionMeta] for when this is
/// null.
final class ExtractionMeta {
  const ExtractionMeta({
    this.fieldConfidences = const {},
    this.sides = const {},
    this.mrzValid,
    this.ocrConfidence,
    this.issues = const [],
    this.schemaVersion,
  });

  /// Per-field confidence scores from the merged canonical document
  /// (e.g. `{"national_id": 0.95, "surname_latin": 0.90}`).
  final Map<String, double> fieldConfidences;

  /// Per-side extraction metadata, keyed `"front"` / `"back"`.
  final Map<String, SideExtractionMeta> sides;

  /// Merged-level MRZ check-digit validity (from the back side's MRZ).
  final bool? mrzValid;

  /// Merged-level overall OCR confidence.
  final double? ocrConfidence;

  /// Merged-level issue codes (e.g. NAME_TOKEN_REPAIRED,
  /// CROSS_CHECK_UNAVAILABLE). MRZ_VIZ_MISMATCH is no longer a merged-level
  /// example — it is per-side only, in
  /// [SideExtractionMeta.issues].
  final List<String> issues;

  /// canonical_document schema_version this metadata was produced under.
  final String? schemaVersion;

  factory ExtractionMeta.fromJson(Map<String, dynamic> json) {
    final rawFieldConfidences =
        json['field_confidences'] as Map<String, dynamic>? ?? const {};
    final rawSides = json['sides'] as Map<String, dynamic>? ?? const {};
    return ExtractionMeta(
      fieldConfidences: rawFieldConfidences.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      sides: rawSides.map(
        (key, value) => MapEntry(
          key,
          SideExtractionMeta.fromJson(value as Map<String, dynamic>),
        ),
      ),
      mrzValid: json['mrz_valid'] as bool?,
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble(),
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      schemaVersion: json['schema_version'] as String?,
    );
  }
}
