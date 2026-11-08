import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

import 'id_illustration.dart';

/// H — the SDK handoff "arming" state.
///
/// Shown for a minimum of 400ms between the `Start` tap and the SDK's first
/// rendered frame, so a fast camera-init never flashes past unseen and a
/// slow one never shows a black frame. The secondary line pre-loads the very
/// first instruction the SDK will give, so the user is already acting by the
/// time the viewfinder appears.
class ArmingView extends StatefulWidget {
  const ArmingView({super.key});

  @override
  State<ArmingView> createState() => _ArmingViewState();
}

class _ArmingViewState extends State<ArmingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IdIllustration(liveness: false, scale: 0.72, dim: true),
            const SizedBox(height: 24),
            Text(
              'Opening camera…',
              style: BawariiTextStyles.heading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Point the camera at the front of your Tazkira',
              style: BawariiTextStyles.bodySmall.copyWith(
                color: BawariiColors.ink70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _ThreeDotProgress(controller: _controller),
          ],
        ),
      ),
    );
  }
}

class _ThreeDotProgress extends StatelessWidget {
  const _ThreeDotProgress({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (controller.value - (i * 0.14)) % 1.0;
              final lift = t < 0.5 ? (t * 2) : (2 - t * 2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Transform.translate(
                  offset: Offset(0, -4 * lift),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: BawariiColors.trust,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
