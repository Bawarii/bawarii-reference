import 'confidence_tier.dart';
import 'identity_field_row.dart';
import 'reference_result.dart';

/// The three ExtractionQualityCard headline metrics,
/// plus the tier distribution used to render the ConfidenceDistributionBar.
///
/// Only meaningful when `extraction_meta` is present — callers should not
/// show the quality card at all when [ReferenceResult.extractionMeta] is
/// null (older sessions / Bearer-auth channel).
final class ExtractionQualitySummary {
  const ExtractionQualitySummary({
    required this.fieldsRead,
    required this.fieldsTotal,
    required this.mrzStatus,
    required this.sidesStatus,
    required this.highCount,
    required this.checkCount,
    required this.reviewCount,
  });

  /// `{n} of {total} fields read` —: count of non-null values in
  /// `fields` vs. count of `field_confidences` keys.
  final int fieldsRead;
  final int fieldsTotal;

  /// `Valid` / `Failed` / `Not found`.
  final String mrzStatus;

  /// `Both` / `Front only` / `Back only` / `Neither`.
  final String sidesStatus;

  final int highCount;
  final int checkCount;
  final int reviewCount;

  int get flaggedCount => checkCount + reviewCount;

  factory ExtractionQualitySummary.fromResult(ReferenceResult result) {
    final meta = result.extractionMeta!;
    final confidences = meta.fieldConfidences;

    var read = 0;
    for (final entry in confidences.entries) {
      if ((_valueForKey(result, entry.key) ?? '').isNotEmpty) read++;
    }

    final mrzStatus = switch (meta.mrzValid) {
      true => 'Valid',
      false => 'Failed',
      null => 'Not found',
    };

    final frontAccepted = _isAccepted(meta.sides['front']?.status);
    final backAccepted = _isAccepted(meta.sides['back']?.status);
    final sidesStatus = switch ((frontAccepted, backAccepted)) {
      (true, true) => 'Both',
      (true, false) => 'Front only',
      (false, true) => 'Back only',
      (false, false) => 'Neither',
    };

    final rows = buildIdentityFieldRows(result);
    var high = 0, check = 0, review = 0;
    for (final row in rows) {
      final c = row.confidence;
      if (c == null) continue;
      switch (tierOfConfidence(c)) {
        case ConfidenceTier.high:
          high++;
        case ConfidenceTier.check:
          check++;
        case ConfidenceTier.review:
          review++;
      }
    }

    return ExtractionQualitySummary(
      fieldsRead: read,
      fieldsTotal: confidences.length,
      mrzStatus: mrzStatus,
      sidesStatus: sidesStatus,
      highCount: high,
      checkCount: check,
      reviewCount: review,
    );
  }

  static bool _isAccepted(String? status) =>
      (status ?? '').toUpperCase() == 'ACCEPTED';

  static String? _valueForKey(ReferenceResult r, String key) {
    return switch (key) {
      'surname_latin' => r.surnameLatin,
      'given_name_latin' => r.givenNameLatin,
      'national_id' => r.nationalId,
      'dob_gregorian' => r.dateOfBirth,
      'sex' => r.sex,
      'date_of_expiry_gregorian' => r.dateOfExpiryGregorian,
      _ => null,
    };
  }
}
