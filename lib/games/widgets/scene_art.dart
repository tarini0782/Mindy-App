import 'dart:math';
import 'package:flutter/material.dart';

/// Small drawing helpers shared by the world scenes (flowers, stars,
/// butterflies, clouds). Plain Canvas calls: no assets, nothing to go
/// missing, same soft style as the characters.

void paintStar(Canvas canvas, Offset c, double r, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rad = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + i * pi / 5;
    final p = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// A flower: stem, leaves, petals and a centre. [bloom] 0..1.
void paintFlower(Canvas canvas, Offset base, double height, Color petal,
    double bloom,
    {int petals = 7}) {
  final b = bloom.clamp(0.0, 1.0).toDouble();
  final stemTop = Offset(base.dx, base.dy - height * (0.35 + 0.65 * b));
  canvas.drawLine(
    base,
    stemTop,
    Paint()
      ..color = const Color(0xFF5BB46B)
      ..strokeWidth = max(2.0, height * 0.045)
      ..strokeCap = StrokeCap.round,
  );
  final leaf = Paint()..color = const Color(0xFF7ACF84);
  final mid = Offset(base.dx, base.dy - height * 0.25 * (0.4 + 0.6 * b));
  canvas.drawOval(
      Rect.fromCenter(
          center: mid.translate(-height * 0.10, 0),
          width: height * 0.22,
          height: height * 0.09),
      leaf);
  canvas.drawOval(
      Rect.fromCenter(
          center: mid.translate(height * 0.10, -height * 0.04),
          width: height * 0.22,
          height: height * 0.09),
      leaf);
  final pr = height * (0.10 + 0.20 * b);
  final fill = Paint()..color = petal;
  for (var i = 0; i < petals; i++) {
    final a = i * 2 * pi / petals;
    canvas.drawCircle(
        Offset(stemTop.dx + cos(a) * pr * 0.85, stemTop.dy + sin(a) * pr * 0.85),
        pr * 0.62,
        fill);
  }
  canvas.drawCircle(stemTop, pr * 0.55, Paint()..color = const Color(0xFFFFE066));
}

void paintButterfly(Canvas canvas, Offset c, double size, Color color,
    double flap) {
  final w = size * (0.45 + 0.55 * flap.abs());
  final wing = Paint()..color = color;
  final wing2 = Paint()..color = color.withValues(alpha: 0.75);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-w * 0.45, -size * 0.12),
          width: w,
          height: size * 0.62),
      wing);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(w * 0.45, -size * 0.12),
          width: w,
          height: size * 0.62),
      wing);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-w * 0.35, size * 0.18),
          width: w * 0.7,
          height: size * 0.44),
      wing2);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(w * 0.35, size * 0.18),
          width: w * 0.7,
          height: size * 0.44),
      wing2);
  canvas.drawOval(
      Rect.fromCenter(center: c, width: size * 0.12, height: size * 0.6),
      Paint()..color = const Color(0xFF4A3B66));
}

void paintCloud(Canvas canvas, Offset c, double w, {double opacity = 0.85}) {
  final p = Paint()..color = Colors.white.withValues(alpha: opacity);
  final h = w * 0.45;
  canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), p);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(-w * 0.28, h * 0.1), width: w * 0.55, height: h * 0.8),
      p);
  canvas.drawOval(
      Rect.fromCenter(
          center: c.translate(w * 0.30, h * 0.08), width: w * 0.5, height: h * 0.75),
      p);
}

/// Seven soft rainbow arcs. [opacity] 0..1.
void paintRainbow(Canvas canvas, Offset center, double radius, double opacity) {
  const colors = [
    Color(0xFFFF6F91),
    Color(0xFFFF9A5A),
    Color(0xFFFFD166),
    Color(0xFF8EE0A0),
    Color(0xFF6FC3FF),
    Color(0xFF8E8BFF),
    Color(0xFFC79BFF),
  ];
  final stroke = radius * 0.07;
  for (var i = 0; i < colors.length; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - i * stroke),
      pi,
      pi,
      false,
      Paint()
        ..color = colors[i].withValues(alpha: opacity.clamp(0.0, 1.0).toDouble())
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }
}
