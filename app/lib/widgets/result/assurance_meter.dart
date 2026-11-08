import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../../models/verdict_presentation.dart';
import '../dashed_rrect_border.dart';

/// The three-segment assurance-level meter. Segment 3
/// renders as an unfilled, dashed placeholder below level 3 — a deliberate
/// demo hook for "what's level 3?" (NFC chip read, on the roadmap).
class AssuranceMeter extends StatelessWidget {
  const AssuranceMeter({super.key, required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Assurance level $level of 3, '
          '${assuranceLevelCaptions[level]?.split('· ').last ?? ''}',
      child: ExcludeSemantics(
        child: Row(
          children: List.generate(3, (i) {
            final segment = i + 1;
            final filled = segment <= level;
            final future = segment == 3 && level < 3;
            final segmentBody = Container(
              height: 8,
              decoration: BoxDecoration(
                color: filled
                    ? color
                    : (future ? Colors.transparent : BawariiColors.ink10),
                borderRadius: BorderRadius.circular(BawariiRadii.r6),
              ),
            );
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                child: future
                    ? DashedRRectBorder(
                        color: BawariiColors.ink30,
                        radius: BawariiRadii.r6,
                        child: segmentBody,
                      )
                    : segmentBody,
              ),
            );
          }),
        ),
      ),
    );
  }
}
