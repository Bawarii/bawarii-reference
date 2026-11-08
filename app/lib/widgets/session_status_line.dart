import 'package:bawarii_ui/bawarii_ui.dart';
import 'package:flutter/material.dart';

enum SessionStatusPhase { initialising, ready }

/// The pre-capture session status line — "the single
/// most valuable addition to this screen": names what the app is doing,
/// replacing an unexplained disabled button.
class SessionStatusLine extends StatelessWidget {
  const SessionStatusLine({super.key, required this.phase});

  final SessionStatusPhase phase;

  @override
  Widget build(BuildContext context) {
    final (dotColor, copy) = switch (phase) {
      SessionStatusPhase.initialising => (
        BawariiColors.warning,
        'Creating a secure session…',
      ),
      SessionStatusPhase.ready => (
        BawariiColors.success,
        'Session ready · your API key never left your server',
      ),
    };

    return Semantics(
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(
              color: dotColor,
              pulse: phase == SessionStatusPhase.initialising,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                copy,
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

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});

  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse) return dot;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: dot,
    );
  }
}
