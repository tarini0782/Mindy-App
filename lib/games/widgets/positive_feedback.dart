import 'package:flutter/material.dart';
import '../base/game_session_controller.dart';

/// Renders the floating emoji bursts a game asks for through
/// `controller.burst(position, '⭐')`. Ignores touches so it never
/// blocks gameplay. Place it on top of the game inside one Stack.
class FeedbackLayer extends StatelessWidget {
  final GameSessionController controller;
  const FeedbackLayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final b in controller.bursts)
              _BurstWidget(
                key: ValueKey(b.id),
                burst: b,
                onDone: () => controller.removeBurst(b.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _BurstWidget extends StatelessWidget {
  final FeedbackBurst burst;
  final VoidCallback onDone;
  const _BurstWidget({super.key, required this.burst, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      onEnd: onDone,
      builder: (context, t, _) {
        return Positioned(
          left: burst.position.dx - 22,
          top: burst.position.dy - 22 - 70 * t,
          child: Opacity(
            opacity: (1.0 - t * t).clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(
              scale: 0.8 + 0.5 * t,
              child: Text(
                burst.emoji,
                style: const TextStyle(fontSize: 34, height: 1.0),
              ),
            ),
          ),
        );
      },
    );
  }
}
