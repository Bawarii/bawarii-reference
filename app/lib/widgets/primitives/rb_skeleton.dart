import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

/// A static skeleton block — deliberately **no shimmer**: a shimmer sweep repaints a large surface every frame and is the
/// first thing to drop frames on a low-end device. A single 240ms fade-in
/// on static `ink10` blocks reads as "loading" for free.
class RbSkeleton extends StatefulWidget {
  const RbSkeleton({super.key, this.width = double.infinity, this.height = 14});

  final double width;
  final double height;

  @override
  State<RbSkeleton> createState() => _RbSkeletonState();
}

class _RbSkeletonState extends State<RbSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: BawariiColors.ink10,
          borderRadius: BorderRadius.circular(BawariiRadii.r10),
        ),
      ),
    );
  }
}
