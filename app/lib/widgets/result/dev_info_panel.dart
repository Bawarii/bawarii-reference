import 'dart:convert';

import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/issue_severity.dart';
import '../../models/reference_result.dart';
import '../../models/verdict_presentation.dart';
import '../../theme/ref_colors.dart';
import '../../theme/ref_text_styles.dart';
import '../../utils/timestamp_format.dart';
import '../primitives/kv_row.dart';
import '../primitives/mono_row.dart';
import '../primitives/rb_card.dart';
import '../primitives/rb_chip.dart';

/// S4-D — the developer info panel: collapsed by default,
/// expands in place. Seven groups, each a nested card.
///
/// **Honesty note (real-data gaps):** the design's wireframe MRZ group also
/// shows a `format` field and the three raw MRZ lines. The committed
/// `ExtractionMeta` contract (Appendix B-verified) carries neither — only
/// `mrzValid` — so this panel renders the checksum-validity row only and
/// omits the format/lines subsection rather than fabricating card content.
class DevInfoPanel extends StatelessWidget {
  const DevInfoPanel({
    super.key,
    required this.result,
    required this.expanded,
    required this.onToggle,
    this.measuredElapsed,
  });

  final ReferenceResult result;
  final bool expanded;
  final VoidCallback onToggle;

  /// Client-measured elapsed time, used only when the server didn't return
  /// both `created_at` and `checked_at`.
  final Duration? measuredElapsed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Developer info, ${expanded ? 'expanded' : 'collapsed'}',
          child: Material(
            color: BawariiColors.paper,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(BawariiRadii.r20),
              bottom: Radius.circular(expanded ? 0 : BawariiRadii.r20),
            ),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(BawariiRadii.r20),
                bottom: Radius.circular(expanded ? 0 : BawariiRadii.r20),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: BawariiColors.hairline),
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(BawariiRadii.r20),
                    bottom: Radius.circular(expanded ? 0 : BawariiRadii.r20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.code,
                      size: 18,
                      // : ink70, not ink50 — fails contrast at 16sp.
                      color: BawariiColors.ink70,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Developer info',
                        style: BawariiTextStyles.body.copyWith(
                          color: BawariiColors.ink70,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: BawariiColors.ink70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded) _ExpandedContent(result: result, measuredElapsed: measuredElapsed),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({required this.result, this.measuredElapsed});

  final ReferenceResult result;
  final Duration? measuredElapsed;

  @override
  Widget build(BuildContext context) {
    final meta = result.extractionMeta;
    final serverElapsed = formatElapsedSeconds(result.createdAt, result.checkedAt);
    final elapsedText = serverElapsed ??
        (measuredElapsed == null
            ? null
            : '${(measuredElapsed!.inMilliseconds / 1000).toStringAsFixed(1)} s '
                '(measured on device)');

    return Container(
      decoration: BoxDecoration(
        color: BawariiColors.bone,
        border: const Border(
          left: BorderSide(color: BawariiColors.hairline),
          right: BorderSide(color: BawariiColors.hairline),
          bottom: BorderSide(color: BawariiColors.hairline),
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(BawariiRadii.r20),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DevGroup(
            title: 'Session',
            child: Column(
              children: [
                MonoRow(label: 'Session ID', value: result.sessionId),
                const Divider(height: 1, color: BawariiColors.hairline),
                MonoRow(
                  label: 'Reference ID',
                  value: result.referenceId ?? '—',
                ),
                const Divider(height: 12, color: Colors.transparent),
                KvRow(label: 'Workflow', value: result.workflow.apiValue),
                KvRow(label: 'Document type', value: result.documentType ?? '—'),
                KvRow(
                  label: 'Created at',
                  value: formatDisplayTimestamp(result.createdAt),
                  mono: false,
                ),
                KvRow(
                  label: 'Checked at',
                  value: formatDisplayTimestamp(result.checkedAt),
                  mono: false,
                ),
                KvRow(
                  label: 'Elapsed',
                  value: elapsedText ?? '—',
                  mono: false,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DevGroup(
            title: 'Decision',
            child: Column(
              children: [
                KvRow(
                  label: 'Verdict',
                  value: '',
                  valueWidget: _VerdictChip(result: result),
                ),
                KvRow(
                  label: 'Assurance level',
                  value:
                      '${result.assuranceLevel ?? verdictPresentations[result.verdict]!.defaultLevel} of 3',
                  mono: false,
                ),
                KvRow(
                  label: 'Pending steps',
                  value: result.pendingSteps.isEmpty
                      ? '—'
                      : result.pendingSteps.join(', '),
                ),
                KvRow(
                  label: 'Rejection reasons',
                  value: result.rejectionReasons.isEmpty
                      ? '—'
                      : result.rejectionReasons.join(', '),
                  last: true,
                ),
              ],
            ),
          ),
          if (meta != null && meta.fieldConfidences.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DevGroup(
              title: 'Field confidences',
              child: Column(
                children: [
                  for (final entry in _sortedByConfidenceDescending(meta.fieldConfidences))
                    _ConfidenceBar(label: entry.key, confidence: entry.value),
                ],
              ),
            ),
          ],
          if (meta != null) ...[
            const SizedBox(height: 12),
            _DevGroup(
              title: 'Per-side status',
              child: Column(
                children: [
                  for (final side in const ['front', 'back'])
                    if (meta.sides[side] != null)
                      _SideStatusGroup(side: side, meta: meta.sides[side]!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DevGroup(
              title: 'Machine-readable zone',
              child: KvRow(
                label: 'Checksums',
                value: '',
                mono: false,
                last: true,
                valueWidget: switch (meta.mrzValid) {
                  true => const RbChip(
                    label: 'VALID',
                    fill: BawariiColors.successSoft,
                    textColor: RefColors.successInk,
                    mono: true,
                    height: 24,
                  ),
                  false => const RbChip(
                    label: 'FAILED',
                    fill: BawariiColors.errorSoft,
                    textColor: RefColors.errorInk,
                    mono: true,
                    height: 24,
                  ),
                  null => Text(
                    'Not found',
                    style: BawariiTextStyles.bodySmall.copyWith(
                      color: BawariiColors.ink70,
                    ),
                  ),
                },
              ),
            ),
            const SizedBox(height: 12),
            _ExtractionIssuesGroup(meta: meta),
          ],
          const SizedBox(height: 12),
          _RawResponseGroup(result: result),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: BawariiColors.ink50),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This result was fetched by the reference backend using an '
                  'API key. The SDK never handles PII — it only transmits '
                  'captured images. This is the correct production '
                  'integration pattern.',
                  style: BawariiTextStyles.fine.copyWith(
                    color: BawariiColors.ink70,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<MapEntry<String, double>> _sortedByConfidenceDescending(
    Map<String, double> confidences,
  ) {
    final entries = confidences.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.result});

  final ReferenceResult result;

  @override
  Widget build(BuildContext context) {
    final presentation = verdictPresentations[result.verdict]!;
    return RbChip(
      label: presentation.label,
      fill: presentation.fill,
      textColor: presentation.ink,
      mono: true,
      height: 24,
    );
  }
}

class _DevGroup extends StatelessWidget {
  const _DevGroup({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RbCard(
      borderRadius: BawariiRadii.r14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!.toUpperCase(),
              style: BawariiTextStyles.caption.copyWith(color: BawariiColors.ink70),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.label, required this.confidence});

  final String label;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final tier = confidence >= 0.90
        ? BawariiColors.success
        : confidence >= 0.70
            ? RefColors.warningMid
            : BawariiColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              label,
              style: RefTextStyles.monoSmall,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BawariiRadii.r6),
                  child: LinearProgressIndicator(
                    value: confidence.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: BawariiColors.ink10,
                    valueColor: AlwaysStoppedAnimation(tier),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: Text(
                  confidence.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: RefTextStyles.monoSmall.copyWith(color: BawariiColors.ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideStatusGroup extends StatelessWidget {
  const _SideStatusGroup({required this.side, required this.meta});

  final String side;
  final SideExtractionMeta meta;

  @override
  Widget build(BuildContext context) {
    final isAccepted = meta.status.toUpperCase() == 'ACCEPTED';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  side.toUpperCase(),
                  style: BawariiTextStyles.fine.copyWith(
                    color: BawariiColors.ink70,
                    letterSpacing: 0.08 * 12,
                  ),
                ),
              ),
              RbChip(
                label: meta.status.toUpperCase(),
                fill: isAccepted ? BawariiColors.successSoft : BawariiColors.ink10,
                textColor: isAccepted
                    ? RefColors.successInk
                    : BawariiColors.ink70,
                mono: true,
                height: 24,
              ),
            ],
          ),
          if (meta.issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in meta.issues)
                  IssueChip(code: code, severity: severityOfIssue(code)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExtractionIssuesGroup extends StatelessWidget {
  const _ExtractionIssuesGroup({required this.meta});

  final ExtractionMeta meta;

  @override
  Widget build(BuildContext context) {
    final all = <String>{
      ...meta.issues,
      ...?meta.sides['front']?.issues,
      ...?meta.sides['back']?.issues,
    }.toList();

    if (all.isEmpty) {
      return _DevGroup(
        title: 'Extraction issues',
        child: Text(
          'No issues reported.',
          style: BawariiTextStyles.bodySmall.copyWith(color: BawariiColors.ink70),
        ),
      );
    }

    final bySeverity = <IssueSeverity?, List<String>>{};
    for (final code in all) {
      bySeverity.putIfAbsent(severityOfIssue(code), () => []).add(code);
    }

    const order = [IssueSeverity.fatal, IssueSeverity.warning, IssueSeverity.advisory, null];

    return _DevGroup(
      title: 'Extraction issues (${all.length})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final severity in order)
            if (bySeverity[severity] case final codes? when codes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _severityHeader(severity),
                      style: BawariiTextStyles.fine.copyWith(
                        color: _severityHeaderColor(severity),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final code in codes)
                          IssueChip(code: code, severity: severity),
                      ],
                    ),
                    for (final code in codes)
                      if (plainLanguageForIssue(code) case final text?)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            text,
                            style: BawariiTextStyles.bodySmall.copyWith(
                              color: BawariiColors.ink70,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _severityHeader(IssueSeverity? severity) => switch (severity) {
    IssueSeverity.fatal => '⊗ FATAL',
    IssueSeverity.warning => '⚠ WARNING',
    IssueSeverity.advisory => 'ⓘ ADVISORY',
    null => 'UNCLASSIFIED',
  };

  Color _severityHeaderColor(IssueSeverity? severity) => switch (severity) {
    IssueSeverity.fatal => RefColors.errorInk,
    IssueSeverity.warning => RefColors.warningInk,
    IssueSeverity.advisory => BawariiColors.trust,
    null => BawariiColors.ink70,
  };
}

class _RawResponseGroup extends StatelessWidget {
  const _RawResponseGroup({required this.result});

  final ReferenceResult result;

  @override
  Widget build(BuildContext context) {
    final json = result.rawJson;
    final pretty = json == null
        ? '// raw response unavailable'
        : const JsonEncoder.withIndent('  ').convert(json);

    return _DevGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RAW RESPONSE',
                  style: BawariiTextStyles.caption.copyWith(
                    color: BawariiColors.ink70,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: json == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: pretty));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Result payload copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_outlined, size: 14),
                label: const Text('Copy'),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: SelectableText(
                  pretty,
                  style: RefTextStyles.monoTiny,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
