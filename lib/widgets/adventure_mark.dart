import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// THE ADVENTURE MARK — a lit lantern.
///
/// Replaces the unicorn emoji that used to head the sign-in, consent and
/// "choosing your adventure" screens. Three reasons it is a lantern:
///
///  * It is the same motif the trail already uses — the lanterns Pip walks
///    towards in Calm Maze, the fireflies, the light at each stop — so the
///    first screen belongs to the same world as the rest.
///  * It is drawn in code, so there is no asset to ship, nothing to fail
///    to load, and no licence to check. (The project has no image assets
///    at all; every folder under `assets/` holds only a README.)
///  * An emoji renders differently on every platform and cannot be
///    coloured. A grown-up sign-in screen should not be at the mercy of
///    whichever unicorn the device happens to have.
///
/// [glow] draws the warm halo. Turn it off on a light background, where
/// the halo has nothing to glow against.
class AdventureMark extends StatelessWidget {
  final double size;
  final bool glow;

  const AdventureMark({super.key, this.size = 96, this.glow = true});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LanternPainter(glow: glow)),
      );
}

class _LanternPainter extends CustomPainter {
  final bool glow;
  const _LanternPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    // Everything below is expressed as a fraction of `s`, so the mark is
    // identical at 48px and at 160px.
    double u(double v) => s * v;

    if (glow) {
      final r = u(0.52);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x66FFE9A8), Color(0x00FFE9A8)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // Handle: a hoop above the lantern.
    canvas.drawArc(
      Rect.fromCenter(
          center: c.translate(0, -u(0.34)), width: u(0.26), height: u(0.22)),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u(0.045)
        ..strokeCap = StrokeCap.round
        ..color = CalmColors.treasureDeep,
    );

    // Cap.
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: c.translate(0, -u(0.27)), width: u(0.46), height: u(0.11)),
      Radius.circular(u(0.05)),
    );
    canvas.drawRRect(cap, Paint()..color = CalmColors.treasure);

    // The glass body: a tapered box.
    final body = Path()
      ..moveTo(c.dx - u(0.17), c.dy - u(0.21))
      ..lineTo(c.dx + u(0.17), c.dy - u(0.21))
      ..lineTo(c.dx + u(0.21), c.dy + u(0.21))
      ..lineTo(c.dx - u(0.21), c.dy + u(0.21))
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFFFF1C9));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u(0.035)
        ..strokeJoin = StrokeJoin.round
        ..color = CalmColors.treasureDeep,
    );

    // The flame.
    final flame = Path()
      ..moveTo(c.dx, c.dy - u(0.13))
      ..quadraticBezierTo(c.dx + u(0.10), c.dy - u(0.02), c.dx, c.dy + u(0.10))
      ..quadraticBezierTo(c.dx - u(0.10), c.dy - u(0.02), c.dx, c.dy - u(0.13))
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFF2993C));
    final inner = Path()
      ..moveTo(c.dx, c.dy - u(0.06))
      ..quadraticBezierTo(c.dx + u(0.05), c.dy + u(0.01), c.dx, c.dy + u(0.07))
      ..quadraticBezierTo(c.dx - u(0.05), c.dy + u(0.01), c.dx, c.dy - u(0.06))
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFF6DC));

    // Base.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: c.translate(0, u(0.26)), width: u(0.52), height: u(0.12)),
        Radius.circular(u(0.05)),
      ),
      Paint()..color = CalmColors.treasure,
    );

    // Two sparks, so the mark reads as "a light in the dark" rather than
    // an object sitting still.
    canvas.drawCircle(c.translate(u(0.34), -u(0.30)), u(0.035),
        Paint()..color = const Color(0xCCFFE9A8));
    canvas.drawCircle(c.translate(-u(0.31), -u(0.14)), u(0.026),
        Paint()..color = const Color(0x99FFE9A8));
  }

  @override
  bool shouldRepaint(covariant _LanternPainter old) => old.glow != glow;
}
