import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../models/reference_result.dart';
import '../models/verdict_presentation.dart';
import '../theme/ref_text_styles.dart';
import 'result/assurance_meter.dart';

/// The verdict hero card — all seven API verdicts.
///
/// `APPROVE_PENDING` now renders as a positive, success-styled
/// in-review state (never the grey "could not be determined" `UNKNOWN`
/// treatment), and `CANCELLED` is visually distinct from `UNKNOWN`.
class VerdictHeroCard extends StatefulWidget {
  const VerdictHeroCard({super.key, required this.result});

  final ReferenceResult result;

  @override
  State<VerdictHeroCard> createState() => _VerdictHeroCardState();
}

class _VerdictHeroCardState extends State<VerdictHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didUpdateWidget(covariant VerdictHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  void _syncSpin() {
    final presentation = verdictPresentations[widget.result.verdict]!;
    if (presentation.spin && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!presentation.spin) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final presentation = verdictPresentations[result.verdict]!;
    final level = result.assuranceLevel ?? presentation.defaultLevel;
    final rationale = presentation.rationaleFor(result.workflow);
    final caption = assuranceLevelCaptions[level] ?? assuranceLevelCaptions[0]!;

    return Semantics(
      header: true,
      label: '${presentation.label}. $rationale. Assurance level $level of 3, '
          '${caption.split('· ').last}.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: presentation.fill,
            borderRadius: BorderRadius.circular(BawariiRadii.r20),
            border: Border.all(color: presentation.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RotationTransition(
                    turns: _spinController,
                    child: Icon(
                      presentation.icon,
                      size: 32,
                      color: presentation.border,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      presentation.label,
                      style: RefTextStyles.verdictLabel.copyWith(
                        color: presentation.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                rationale,
                style: BawariiTextStyles.body.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: BawariiColors.hairline),
              const SizedBox(height: 16),
              Text(
                'ASSURANCE LEVEL',
                style: BawariiTextStyles.caption.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
              const SizedBox(height: 8),
              AssuranceMeter(level: level, color: presentation.meterColor),
              const SizedBox(height: 8),
              Text(
                caption,
                style: BawariiTextStyles.bodySmall.copyWith(
                  color: BawariiColors.ink70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
