import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import '../env.dart';

/// Displays the configured reference backend URL for integration engineers.
///
/// Not tappable — purely informational. Positioned at the bottom of HomeScreen.
class DevInfoChip extends StatelessWidget {
  const DevInfoChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.api,
          size: 14,
          color: BawariiColors.ink50,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              'backend: ${Env.referenceBackendUrl}',
              // : ink70, not ink50/ink30 — fails contrast at fine/12sp.
              style: BawariiTextStyles.fine.copyWith(color: BawariiColors.ink70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
