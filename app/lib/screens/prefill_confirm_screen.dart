import 'package:bawarii_kyc/bawarii_kyc.dart';
import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../theme/ref_colors.dart';
import '../theme/ref_text_styles.dart';
import '../widgets/primitives/rb_banner.dart';
import '../widgets/primitives/rb_chip.dart';
import '../widgets/primitives/test_environment_strip.dart';
import 'result_screen.dart';

/// S3 — PrefillConfirmScreen: shows unverified OCR pre-fill for user review.
///
/// Inserted between onComplete and ResultScreen.
///
/// The fields are pre-populated from [BawariiPrefillData] but fully editable.
/// A warning banner makes clear the data is unverified. The dev caption
/// calls out that this is sample data in dev mode.
///
/// Continue → ResultScreen. User edits are for display purposes only — they
/// are not posted back to the API (prefill is UX convenience only).
class PrefillConfirmScreen extends StatefulWidget {
  const PrefillConfirmScreen({
    super.key,
    required this.prefillData,
    required this.sessionId,
  });

  final BawariiPrefillData prefillData;
  final String sessionId;

  @override
  State<PrefillConfirmScreen> createState() => _PrefillConfirmScreenState();
}

class _PrefillConfirmScreenState extends State<PrefillConfirmScreen> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _nationalIdCtrl;
  late final TextEditingController _dobCtrl;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(text: widget.prefillData.fullName ?? '');
    _nationalIdCtrl = TextEditingController(text: widget.prefillData.nationalId ?? '');
    _dobCtrl = TextEditingController(text: widget.prefillData.dateOfBirth ?? '');
    for (final c in [_fullNameCtrl, _nationalIdCtrl, _dobCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nationalIdCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _onContinue() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(sessionId: widget.sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Details'),
        leading: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            tooltip: 'Cancel',
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const TestEnvironmentStrip(),
                  const SizedBox(height: 16),
                  const RbBanner(
                    severity: RbBannerSeverity.warning,
                    rail: true,
                    icon: Icons.warning_amber_rounded,
                    title: 'Unverified — read from your scan',
                    body: 'Check each field before continuing.',
                  ),
                  const SizedBox(height: 20),
                  Text('Your details', style: BawariiTextStyles.heading),
                  const SizedBox(height: 4),
                  Text(
                    'These fields were read from your document scan. '
                    'Please check they are correct.',
                    style: BawariiTextStyles.bodySmall.copyWith(
                      color: BawariiColors.ink70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PrefillField(
                    label: 'Full name',
                    controller: _fullNameCtrl,
                    originalValue: widget.prefillData.fullName,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _PrefillField(
                    label: 'National ID',
                    controller: _nationalIdCtrl,
                    originalValue: widget.prefillData.nationalId,
                    mono: true,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _PrefillField(
                    label: 'Date of birth',
                    controller: _dobCtrl,
                    originalValue: widget.prefillData.dateOfBirth,
                    mono: true,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Sample data (dev mode) · نمونه داده',
                      textAlign: TextAlign.center,
                      style: BawariiTextStyles.fine.copyWith(
                        color: BawariiColors.ink70,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              MediaQuery.of(context).padding.bottom > 24
                  ? MediaQuery.of(context).padding.bottom
                  : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onContinue,
                    child: const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 8),
                // — honest framing: edits here are display-only.
                Text(
                  'Edits are shown for review only and are not sent to '
                  'the verification service.',
                  textAlign: TextAlign.center,
                  style: BawariiTextStyles.fine.copyWith(
                    color: BawariiColors.ink70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefillField extends StatelessWidget {
  const _PrefillField({
    required this.label,
    required this.controller,
    required this.originalValue,
    this.mono = false,
    this.textInputAction = TextInputAction.next,
  });

  final String label;
  final TextEditingController controller;
  final String? originalValue;
  final bool mono;
  final TextInputAction textInputAction;

  bool get _notRead => (originalValue ?? '').isEmpty;
  bool get _edited => !_notRead && controller.text != originalValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
            ),
            if (_edited) ...[
              const SizedBox(width: 8),
              const RbChip(
                label: 'Edited',
                fill: BawariiColors.trustSoft,
                textColor: BawariiColors.trust,
                height: 20,
              ),
            ],
            if (_notRead) ...[
              const SizedBox(width: 8),
              const RbChip(
                label: 'Not read',
                fill: BawariiColors.ink10,
                textColor: BawariiColors.ink70,
                height: 20,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: mono ? RefTextStyles.mono : BawariiTextStyles.heading,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            filled: true,
            fillColor: BawariiColors.paper,
            hintText: _notRead ? '—' : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BawariiRadii.r10),
              borderSide: BorderSide(
                color: _edited ? BawariiColors.trust : BawariiColors.hairline,
                width: _edited ? 1.5 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BawariiRadii.r10),
              borderSide: BorderSide(
                color: _edited ? BawariiColors.trust : BawariiColors.hairline,
                width: _edited ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(BawariiRadii.r10),
              borderSide: const BorderSide(color: BawariiColors.trust, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        if (_notRead) ...[
          const SizedBox(height: 4),
          Text(
            'Not read from document',
            style: BawariiTextStyles.fine.copyWith(color: RefColors.warningInk),
          ),
        ],
      ],
    );
  }
}
