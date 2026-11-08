import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../models/reference_workflow.dart';
import '../widgets/dashed_rrect_border.dart';
import '../widgets/dev_info_chip.dart';
import '../widgets/icons/emblem.dart';
import '../widgets/primitives/section_label.dart';
import '../widgets/primitives/test_environment_strip.dart';
import '../widgets/workflow_card.dart';
import 'architecture_sheet.dart';
import 'pre_capture_screen.dart';

/// S1 — HomeScreen: showcase + workflow selection.
///
/// Two-zone layout:
///   Zone A (260dp + top safe area): trust-navy hero with emblem, wordmark,
///                                   tagline, and pipeline strip.
///   Zone B (fills the rest): bone action panel with the TEST ENVIRONMENT
///                             strip, workflow cards, the progressive-
///                             enhancement specimen strip, and the footer.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _HeroPanelA(),
          Expanded(child: _ActionPanelB()),
        ],
      ),
    );
  }
}

// ── Zone A — Hero Panel ──────────────────────────────────────────────────────

class _HeroPanelA extends StatelessWidget {
  const _HeroPanelA();

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    // : below 700dp viewport height, compact the hero.
    final compact = viewportHeight < 700;
    final heroHeight =
        (compact ? 220.0 : 260.0) + MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      height: heroHeight,
      color: BawariiColors.trust,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Emblem(size: compact ? 24 : 28),
          SizedBox(height: compact ? 16 : 24),
          Text(
            'BAWARII',
            textAlign: TextAlign.center,
            style: BawariiTextStyles.titleLarge.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: BawariiColors.bone,
              letterSpacing: 0.06 * 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Afghan identity. Verified.',
            textAlign: TextAlign.center,
            style: BawariiTextStyles.bodySmall.copyWith(
              color: BawariiColors.volt,
            ),
          ),
          SizedBox(height: compact ? 16 : 24),
          const _PipelineStrip(),
        ],
      ),
    );
  }
}

class _PipelineStrip extends StatelessWidget {
  const _PipelineStrip();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Verification pipeline: scan ID, liveness, verify.',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Pill(icon: Icons.crop_free, label: 'Scan ID', conditional: false),
              _Chevron(),
              _Pill(icon: Icons.face_outlined, label: 'Liveness', conditional: true),
              _Chevron(),
              _Pill(icon: Icons.check, label: 'Verify', conditional: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.conditional,
  });

  final IconData icon;
  final String label;

  /// : conditionality is signalled structurally (a dashed border),
  /// never by dimming the label — a dimmed `ink50`-on-`trustDeep` label
  /// measured 3.84:1 and failed AA at 12sp.
  final bool conditional;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: BawariiColors.trustDeep,
        borderRadius: BorderRadius.circular(BawariiRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: BawariiColors.volt),
          const SizedBox(width: 6),
          Text(
            label,
            style: BawariiTextStyles.fine.copyWith(color: BawariiColors.bone),
          ),
        ],
      ),
    );

    if (!conditional) return pill;

    return DashedRRectBorder(
      color: BawariiColors.volt.withValues(alpha: 0.5),
      radius: BawariiRadii.pill,
      child: pill,
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 14,
        color: Color(0x99EEF2F8), // bone @ 60%
      ),
    );
  }
}

// ── Zone B — Action Panel ────────────────────────────────────────────────────

class _ActionPanelB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final showTestEnvironmentStrip = MediaQuery.sizeOf(context).height >= 720;

    // Lives inside Expanded, so it gets a tight height constraint. Split
    // into a scrollable content region and a pinned footer so the layout
    // never overflows even on short screens (e.g. the 360x640 test).
    return ColoredBox(
      color: BawariiColors.bone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TestEnvironmentStrip(),
                  const SizedBox(height: 16),
                  const SectionLabel('Select a workflow', padding: EdgeInsets.zero),
                  const SizedBox(height: 12),
                  WorkflowCard(
                    workflow: ReferenceWorkflow.documentOnly,
                    onTap: () => _navigateToPreCapture(
                      context,
                      ReferenceWorkflow.documentOnly,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WorkflowCard(
                    workflow: ReferenceWorkflow.documentAndLiveness,
                    onTap: () => _navigateToPreCapture(
                      context,
                      ReferenceWorkflow.documentAndLiveness,
                    ),
                  ),
                  if (showTestEnvironmentStrip) ...[
                    const SizedBox(height: 16),
                    const _TestEnvironmentStrip(),
                  ],
                ],
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () => ArchitectureSheet.show(context),
              child: Text(
                'How this works',
                style: BawariiTextStyles.body.copyWith(
                  color: BawariiColors.ink70,
                  decoration: TextDecoration.underline,
                  decorationColor: BawariiColors.ink30,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: bottomPad > 16 ? bottomPad : 16,
            ),
            child: const DevInfoChip(),
          ),
        ],
      ),
    );
  }

  void _navigateToPreCapture(BuildContext context, ReferenceWorkflow workflow) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PreCaptureScreen(workflow: workflow),
      ),
    );
  }
}

class _TestEnvironmentStrip extends StatelessWidget {
  const _TestEnvironmentStrip();

  @override
  Widget build(BuildContext context) {
    return DashedRRectBorder(
      color: BawariiColors.ink30,
      radius: BawariiRadii.r10,
      strokeWidth: 1,
      dashLength: 4,
      gapLength: 4,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 14,
              color: BawariiColors.ink50,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This sample runs against a Bawarii test environment; sessions and results are non-production.',
                style: BawariiTextStyles.fine.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
