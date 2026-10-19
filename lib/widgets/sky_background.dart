import 'dart:math';
import 'package:flutter/material.dart';

/// A gently animated gradient backdrop with a few drifting clouds and
/// twinkling stars -- gives every screen a "world" feel instead of a
/// flat color, without needing any image asset.
///
/// Wrap any screen's body with this:
///   SkyBackground(colors: AppColors.skyMorning, child: ...)
class SkyBackground extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  final bool showStars;

  const SkyBackground({
    super.key,
    required this.colors,
    required this.child,
    this.showStars = false,
  });

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.colors,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _DriftPainter(
              t: _controller.value,
              showStars: widget.showStars,
            ),
            size: Size.infinite,
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _DriftPainter extends CustomPainter {
  final double t; // 0..1 looping
  final bool showStars;
  _DriftPainter({required this.t, required this.showStars});

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);

    // Three clouds drifting left-to-right at different speeds/heights.
    _drawCloud(canvas, size, cloudPaint, baseY: 0.12, speed: 1.0, scale: 1.0);
    _drawCloud(canvas, size, cloudPaint, baseY: 0.22, speed: 0.6, scale: 0.7);
    _drawCloud(canvas, size, cloudPaint, baseY: 0.06, speed: 0.4, scale: 0.5);

    if (showStars) {
      final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
      final rand = Random(7); // fixed seed so stars don't jump every frame
      for (var i = 0; i < 18; i++) {
        final dx = rand.nextDouble() * size.width;
        final dy = rand.nextDouble() * size.height * 0.6;
        final twinkle = (sin(t * 2 * pi + i) + 1) / 2;
        canvas.drawCircle(Offset(dx, dy), 1.4 + twinkle * 1.6, starPaint);
      }
    }
  }

  void _drawCloud(
    Canvas canvas,
    Size size,
    Paint paint, {
    required double baseY,
    required double speed,
    required double scale,
  }) {
    final travel = size.width * 1.4;
    final x = ((t * speed) % 1.0) * travel - size.width * 0.2;
    final y = size.height * baseY;
    final w = 90.0 * scale;
    final h = 34.0 * scale;

    final path = Path()
      ..addOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h))
      ..addOval(Rect.fromCenter(
          center: Offset(x - w * 0.3, y + h * 0.1), width: w * 0.6, height: h * 0.7))
      ..addOval(Rect.fromCenter(
          center: Offset(x + w * 0.35, y + h * 0.05), width: w * 0.55, height: h * 0.65));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DriftPainter oldDelegate) => oldDelegate.t != t;
}
