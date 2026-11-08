import 'field_provenance.dart';
import 'reference_result.dart';

/// One row of the client-tier "Extracted identity" card.
///
/// [key] is the canonical `field_confidences` key this row corresponds to —
/// `null` for the legacy composite `full_name` row, which by design
/// can never carry a confidence value. [confidence] is `null` whenever the
/// backend returned no matching `field_confidences` entry for [key] (older
/// sessions, or the Bearer-auth channel where `extraction_meta` is entirely
/// absent) — such rows render plainly, with no rail or chips.
final class IdentityFieldRow {
  const IdentityFieldRow({
    required this.key,
    required this.label,
    required this.value,
    required this.mono,
    this.mask = false,
    this.confidence,
    this.issues = const [],
    this.provenance,
  });

  final String? key;
  final String label;
  final String value;
  final bool mono;
  final bool mask;
  final double? confidence;
  final List<String> issues;
  final FieldProvenance? provenance;
}

/// The name-related issue codes the backend reports without per-field
/// attribution (see `field_provenance.dart` for why this module infers one).
const _nameIssueCodes = {
  'NAME_TOKEN_REPAIRED',
  'NAME_TOKEN_FILTERED',
  'NAME_UNCORROBORATED',
};

/// Builds the six-row (or fewer) identity field breakdown for
/// [ExtractionQualityCard] / the identity fields card, from the real
/// [ReferenceResult] — never from the design's demo `FIELDS` array.
///
/// Order matches: SURNAME, GIVEN NAME, NATIONAL ID,
/// DATE OF BIRTH, SEX, DATE OF EXPIRY. A row is included only when its
/// value is present. When neither constituent name field is present but a
/// legacy composite `full_name` is, a single plain `FULL NAME` row is shown
/// instead (no confidence key exists for a composite value —).
List<IdentityFieldRow> buildIdentityFieldRows(ReferenceResult result) {
  final meta = result.extractionMeta;
  final confidences = meta?.fieldConfidences ?? const {};
  final mergedIssues = meta?.issues ?? const [];

  // Name-related issues have no per-field attribution in the real contract
  // (`extraction_meta.issues` is a flat, merged list). We infer the more
  // plausible of the two name fields: whichever has the lower confidence,
  // since the pipeline has no reason to flag a name it read confidently.
  String? nameIssueTarget;
  if (mergedIssues.any(_nameIssueCodes.contains)) {
    final surnameConf = confidences['surname_latin'];
    final givenConf = confidences['given_name_latin'];
    if (surnameConf != null && givenConf != null) {
      nameIssueTarget = givenConf <= surnameConf
          ? 'given_name_latin'
          : 'surname_latin';
    } else if (givenConf != null) {
      nameIssueTarget = 'given_name_latin';
    } else if (surnameConf != null) {
      nameIssueTarget = 'surname_latin';
    }
  }

  List<String> issuesFor(String fieldKey) {
    final out = <String>[];
    if (fieldKey == nameIssueTarget) {
      out.addAll(mergedIssues.where(_nameIssueCodes.contains));
    }
    if (fieldKey == 'national_id') {
      out.addAll(
        mergedIssues.where(
          (i) => i == 'NIN_VIZ_MISMATCH' || i == 'NIN_NOT_FOUND',
        ),
      );
    }
    if (fieldKey == 'dob_gregorian') {
      out.addAll(mergedIssues.where((i) => i == 'DOB_DATE_INVALID'));
    }
    if (fieldKey == 'date_of_expiry_gregorian') {
      out.addAll(mergedIssues.where((i) => i == 'EXPIRY_DATE_INVALID'));
    }
    return out;
  }

  IdentityFieldRow? row({
    required String fieldKey,
    required String label,
    required String? value,
    bool mono = false,
    bool mask = false,
  }) {
    if (value == null || value.isEmpty) return null;
    final confidence = confidences[fieldKey];
    final issues = issuesFor(fieldKey);
    return IdentityFieldRow(
      key: fieldKey,
      label: label,
      value: value,
      mono: mono,
      mask: mask,
      confidence: confidence,
      issues: issues,
      provenance: confidence == null
          ? null
          : FieldProvenance.derive(
              fieldKey: fieldKey,
              confidence: confidence,
              issues: issues,
              fieldLabel: label.toLowerCase(),
            ),
    );
  }

  final rows = <IdentityFieldRow>[];

  final surnameRow = row(
    fieldKey: 'surname_latin',
    label: 'Surname',
    value: result.surnameLatin,
  );
  final givenNameRow = row(
    fieldKey: 'given_name_latin',
    label: 'Given name',
    value: result.givenNameLatin,
  );

  if (surnameRow != null || givenNameRow != null) {
    if (surnameRow != null) rows.add(surnameRow);
    if (givenNameRow != null) rows.add(givenNameRow);
  } else if ((result.fullName ?? '').isNotEmpty) {
    // Legacy shape: only the composite is available. No confidence key
    // exists for it — always renders plainly.
    rows.add(
      IdentityFieldRow(
        key: null,
        label: 'Full name',
        value: result.fullName!,
        mono: false,
      ),
    );
  }

  final nationalIdRow = row(
    fieldKey: 'national_id',
    label: 'National ID',
    value: result.nationalId,
    mono: true,
    mask: true,
  );
  if (nationalIdRow != null) rows.add(nationalIdRow);

  final dobRow = row(
    fieldKey: 'dob_gregorian',
    label: 'Date of birth',
    value: result.dateOfBirth,
    mono: true,
  );
  if (dobRow != null) rows.add(dobRow);

  final sexRow = row(fieldKey: 'sex', label: 'Sex', value: result.sex);
  if (sexRow != null) rows.add(sexRow);

  final expiryRow = row(
    fieldKey: 'date_of_expiry_gregorian',
    label: 'Date of expiry',
    value: result.dateOfExpiryGregorian,
    mono: true,
  );
  if (expiryRow != null) rows.add(expiryRow);

  return rows;
}
