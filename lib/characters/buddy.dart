import 'dart:math';
import 'package:flutter/material.dart';
import '../games/widgets/scene_art.dart';
import '../models/emotion_state.dart';

/// Mindy and the emotion creatures: ONE consistent family of original
/// 2D characters (same body shape, same face language), each with its own
/// colour, expression, props and gentle animation. Drawn in code, so no
/// artwork is needed and nothing can go missing.
///
///   mindy    the recurring mascot (violet star-sprite)
///   scared   "Bean"     mint, worried eyes, holds a heart shield: SAFE
///   sad      "Drizzle"  soft blue, teardrop, little rain cloud and a heart
///   neutral  "Moss"     lime, relaxed smile, a leaf on its head
///   calm     "Luna"     lavender, closed eyes, stars, slow breathing
///   happy    "Sparkle"  sunny yellow, huge smile, rainbow, hearts, bounce
///   worried / excited are extra faces used by the Feelings Memory cards.
enum BuddyKind { mindy, scared, sad, neutral, calm, happy, worried, excited }

extension EmotionBuddy on EmotionState {
  BuddyKind get buddy {
    switch (this) {
      case EmotionState.scared:
        return BuddyKind.scared;
      case EmotionState.sad:
        return BuddyKind.sad;
      case EmotionState.neutral:
        return BuddyKind.neutral;
      case EmotionState.calm:
        return BuddyKind.calm;
      case EmotionState.happy:
        return BuddyKind.happy;
    }
  }

  /// The creature's own name (shown only in small friendly captions).
  String get buddyName {
    switch (this) {
      case EmotionState.scared:
        return 'Bean';
      case EmotionState.sad:
        return 'Drizzle';
      case EmotionState.neutral:
        return 'Moss';
      case EmotionState.calm:
        return 'Luna';
      case EmotionState.happy:
        return 'Sparkle';
    }
  }

  EmotionPalette get palette => EmotionPalette.of(this);
}

class EmotionPalette {
  final Color top;
  final Color bottom;
  final Color accent;
  final Color ink;
  const EmotionPalette(this.top, this.bottom, this.accent, this.ink);

  static EmotionPalette of(EmotionState e) {
    switch (e) {
      case EmotionState.scared:
        return const EmotionPalette(
            Color(0xFFFFE8D2), Color(0xFFD9CCFF), Color(0xFF6BCDB8), Color(0xFF3B2F63));
      case EmotionState.sad:
        return const EmotionPalette(
            Color(0xFFD9EAFF), Color(0xFFB7C9F2), Color(0xFF6FA8F2), Color(0xFF2B3A67));
      case EmotionState.neutral:
        return const EmotionPalette(
            Color(0xFFEAF8D6), Color(0xFFC9E8B4), Color(0xFF9CCB5E), Color(0xFF334B2A));
      case EmotionState.calm:
        return const EmotionPalette(
            Color(0xFFDCD2FF), Color(0xFFA9B8F5), Color(0xFFB39BFF), Color(0xFF2E2A5E));
      case EmotionState.happy:
        return const EmotionPalette(
            Color(0xFFFFF4A8), Color(0xFFFFC2DA), Color(0xFFFFB84D), Color(0xFF5B3A12));
    }
  }
}

class BuddyPainter extends CustomPainter {
  final BuddyKind kind;
  final double t; // 0..1 looping clock
  BuddyPainter(this.kind, this.t);

  late double u;
  static const Color _ink = Color(0xFF2B2350);

  Paint _f(Color c) => Paint()..color = c;
  Paint _s(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;
  Offset _p(double x, double y) => Offset(x * u, y * u);

  (Color, Color) get _body {
    switch (kind) {
      case BuddyKind.mindy:
        return (const Color(0xFFC9B8FF), const Color(0xFF8F7BFF));
      case BuddyKind.scared:
        return (const Color(0xFFB4EEE0), const Color(0xFF6BCDB8));
      case BuddyKind.sad:
        return (const Color(0xFFB7D6FF), const Color(0xFF6FA8F2));
      case BuddyKind.neutral:
        return (const Color(0xFFD9F1A4), const Color(0xFF9CCB5E));
      case BuddyKind.calm:
        return (const Color(0xFFE4D9FF), const Color(0xFFB39BFF));
      case BuddyKind.happy:
        return (const Color(0xFFFFEE8A), const Color(0xFFFFB84D));
      case BuddyKind.worried:
        return (const Color(0xFFFFB9AE), const Color(0xFFFF7A6B));
      case BuddyKind.excited:
        return (const Color(0xFFFFB5DC), const Color(0xFFFF6FB5));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    u = size.width;

    // Props that sit BEHIND the body.
    if (kind == BuddyKind.happy) {
      paintRainbow(canvas, _p(0.5, 0.62), u * 0.52, 0.85);
    }
    if (kind == BuddyKind.calm) {
      canvas.drawCircle(_p(0.5, 0.58), u * 0.46, _f(const Color(0x22FFFFFF)));
    }

    // Ground shadow.
    canvas.drawOval(
        Rect.fromCenter(center: _p(0.5, 1.0), width: 0.46 * u, height: 0.05 * u),
        _f(const Color(0x22000000)));

    final (light, dark) = _body;
    final breathe = kind == BuddyKind.calm ? 1.0 + 0.04 * sin(t * 2 * pi) : 1.0;

    canvas.save();
    canvas.translate(0.5 * u, 0.9 * u);
    canvas.scale(breathe, breathe);
    canvas.translate(-0.5 * u, -0.9 * u);

    // Feet
    canvas.drawOval(Rect.fromCenter(center: _p(0.38, 0.93), width: 0.15 * u, height: 0.08 * u), _f(dark));
    canvas.drawOval(Rect.fromCenter(center: _p(0.62, 0.93), width: 0.15 * u, height: 0.08 * u), _f(dark));

    // Head accessories behind the body (ears / drop)
    _headBack(canvas, light, dark);

    // Body: soft squircle with a vertical gradient.
    final bodyRect = Rect.fromCenter(center: _p(0.5, 0.60), width: 0.70 * u, height: 0.62 * u);
    final rr = RRect.fromRectAndRadius(bodyRect, Radius.circular(0.28 * u));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, dark],
        ).createShader(bodyRect),
    );
    // Belly
    canvas.drawOval(Rect.fromCenter(center: _p(0.5, 0.74), width: 0.38 * u, height: 0.26 * u),
        _f(Colors.white.withValues(alpha: 0.35)));

    // Arms
    _arms(canvas, dark);

    // Face
    _face(canvas);

    // Props in FRONT
    _headFront(canvas);
    _props(canvas);

    canvas.restore();
  }

  void _headBack(Canvas canvas, Color light, Color dark) {
    switch (kind) {
      case BuddyKind.scared:
      case BuddyKind.neutral:
      case BuddyKind.happy:
      case BuddyKind.worried:
      case BuddyKind.excited:
        canvas.drawCircle(_p(0.27, 0.30), 0.09 * u, _f(dark));
        canvas.drawCircle(_p(0.73, 0.30), 0.09 * u, _f(dark));
        canvas.drawCircle(_p(0.27, 0.30), 0.05 * u, _f(const Color(0x55FFFFFF)));
        canvas.drawCircle(_p(0.73, 0.30), 0.05 * u, _f(const Color(0x55FFFFFF)));
        break;
      case BuddyKind.sad:
        // droopy ears
        canvas.drawOval(Rect.fromCenter(center: _p(0.25, 0.38), width: 0.12 * u, height: 0.20 * u), _f(dark));
        canvas.drawOval(Rect.fromCenter(center: _p(0.75, 0.38), width: 0.12 * u, height: 0.20 * u), _f(dark));
        break;
      case BuddyKind.calm:
        canvas.drawCircle(_p(0.28, 0.31), 0.08 * u, _f(dark));
        canvas.drawCircle(_p(0.72, 0.31), 0.08 * u, _f(dark));
        break;
      case BuddyKind.mindy:
        canvas.drawCircle(_p(0.28, 0.31), 0.08 * u, _f(dark));
        canvas.drawCircle(_p(0.72, 0.31), 0.08 * u, _f(dark));
        break;
    }
  }

  void _arms(Canvas canvas, Color dark) {
    final up = kind == BuddyKind.happy || kind == BuddyKind.excited;
    final wave = sin(t * 4 * pi) * 0.03;
    if (up) {
      canvas.drawOval(Rect.fromCenter(center: _p(0.17, 0.52 + wave), width: 0.12 * u, height: 0.2 * u), _f(dark));
      canvas.drawOval(Rect.fromCenter(center: _p(0.83, 0.52 - wave), width: 0.12 * u, height: 0.2 * u), _f(dark));
    } else {
      canvas.drawOval(Rect.fromCenter(center: _p(0.17, 0.68), width: 0.11 * u, height: 0.18 * u), _f(dark));
      canvas.drawOval(Rect.fromCenter(center: _p(0.83, 0.68), width: 0.11 * u, height: 0.18 * u), _f(dark));
    }
  }

  void _face(Canvas canvas) {
    const ey = 0.50;
    final ex1 = 0.38, ex2 = 0.62;
    final stroke = _s(_ink, 0.024 * u);

    // ---- eyes
    switch (kind) {
      case BuddyKind.happy:
        for (final x in [ex1, ex2]) {
          canvas.drawArc(Rect.fromCenter(center: _p(x, ey + 0.02), width: 0.10 * u, height: 0.09 * u),
              pi, pi, false, _s(_ink, 0.03 * u));
        }
        break;
      case BuddyKind.calm:
        for (final x in [ex1, ex2]) {
          canvas.drawArc(Rect.fromCenter(center: _p(x, ey - 0.005), width: 0.10 * u, height: 0.07 * u),
              0.15, pi - 0.3, false, _s(_ink, 0.028 * u));
        }
        break;
      case BuddyKind.excited:
        for (final x in [ex1, ex2]) {
          canvas.drawOval(Rect.fromCenter(center: _p(x, ey), width: 0.095 * u, height: 0.115 * u), _f(_ink));
          canvas.drawCircle(_p(x + 0.015, ey - 0.025), 0.022 * u, _f(Colors.white));
          canvas.drawCircle(_p(x - 0.012, ey + 0.02), 0.012 * u, _f(Colors.white));
        }
        break;
      case BuddyKind.scared:
        for (final x in [ex1, ex2]) {
          canvas.drawOval(Rect.fromCenter(center: _p(x, ey), width: 0.10 * u, height: 0.125 * u), _f(_ink));
          canvas.drawCircle(_p(x + 0.015, ey - 0.03), 0.026 * u, _f(Colors.white));
          canvas.drawCircle(_p(x - 0.014, ey + 0.02), 0.013 * u, _f(Colors.white));
        }
        break;
      case BuddyKind.sad:
        for (final x in [ex1, ex2]) {
          canvas.drawOval(Rect.fromCenter(center: _p(x, ey + 0.01), width: 0.085 * u, height: 0.10 * u), _f(_ink));
          canvas.drawCircle(_p(x + 0.012, ey - 0.015), 0.02 * u, _f(Colors.white));
        }
        break;
      default:
        for (final x in [ex1, ex2]) {
          canvas.drawOval(Rect.fromCenter(center: _p(x, ey), width: 0.075 * u, height: 0.095 * u), _f(_ink));
          canvas.drawCircle(_p(x + 0.012, ey - 0.02), 0.017 * u, _f(Colors.white));
        }
    }

    // ---- brows
    switch (kind) {
      case BuddyKind.scared:
      case BuddyKind.worried:
        canvas.drawLine(_p(0.31, 0.405), _p(0.42, 0.37), stroke);
        canvas.drawLine(_p(0.69, 0.405), _p(0.58, 0.37), stroke);
        break;
      case BuddyKind.sad:
        canvas.drawLine(_p(0.30, 0.385), _p(0.42, 0.41), stroke);
        canvas.drawLine(_p(0.70, 0.385), _p(0.58, 0.41), stroke);
        break;
      default:
        break;
    }

    // ---- cheeks
    final cheek = kind == BuddyKind.happy || kind == BuddyKind.excited || kind == BuddyKind.mindy
        ? const Color(0x88FF6FA5)
        : const Color(0x55FF6FA5);
    canvas.drawCircle(_p(0.27, 0.58), 0.045 * u, _f(cheek));
    canvas.drawCircle(_p(0.73, 0.58), 0.045 * u, _f(cheek));

    // ---- mouth
    const my = 0.61;
    switch (kind) {
      case BuddyKind.happy:
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my - 0.01), width: 0.24 * u, height: 0.20 * u),
            0, pi, true, _f(const Color(0xFFD94A6A)));
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my + 0.045), width: 0.12 * u, height: 0.08 * u),
            0, pi, true, _f(const Color(0xFFFF8FA8)));
        break;
      case BuddyKind.excited:
        canvas.drawOval(Rect.fromCenter(center: _p(0.5, my + 0.02), width: 0.12 * u, height: 0.15 * u),
            _f(const Color(0xFFD94A6A)));
        break;
      case BuddyKind.mindy:
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my - 0.015), width: 0.17 * u, height: 0.12 * u),
            0.1, pi - 0.2, false, _s(_ink, 0.026 * u));
        break;
      case BuddyKind.scared:
        final path = Path()
          ..moveTo(0.43 * u, (my + 0.02) * u)
          ..quadraticBezierTo(0.465 * u, (my - 0.02) * u, 0.5 * u, (my + 0.02) * u)
          ..quadraticBezierTo(0.535 * u, (my + 0.06) * u, 0.57 * u, (my + 0.02) * u);
        canvas.drawPath(path, stroke);
        break;
      case BuddyKind.worried:
        final path = Path()
          ..moveTo(0.42 * u, (my + 0.03) * u)
          ..quadraticBezierTo(0.46 * u, (my - 0.01) * u, 0.5 * u, (my + 0.03) * u)
          ..quadraticBezierTo(0.54 * u, (my + 0.07) * u, 0.58 * u, (my + 0.03) * u);
        canvas.drawPath(path, stroke);
        break;
      case BuddyKind.sad:
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my + 0.045), width: 0.12 * u, height: 0.08 * u),
            pi + 0.3, pi - 0.6, false, stroke);
        break;
      case BuddyKind.calm:
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my - 0.015), width: 0.11 * u, height: 0.07 * u),
            0.2, pi - 0.4, false, stroke);
        break;
      case BuddyKind.neutral:
        canvas.drawArc(Rect.fromCenter(center: _p(0.5, my - 0.01), width: 0.13 * u, height: 0.07 * u),
            0.25, pi - 0.5, false, stroke);
        break;
    }

    // teardrop for sad
    if (kind == BuddyKind.sad) {
      final drop = (t * 2) % 1.0;
      final dy = 0.55 + 0.12 * drop;
      final op = (1 - drop).clamp(0.0, 1.0).toDouble();
      final d = Path()
        ..moveTo(0.33 * u, (dy - 0.035) * u)
        ..quadraticBezierTo(0.30 * u, (dy + 0.02) * u, 0.33 * u, (dy + 0.03) * u)
        ..quadraticBezierTo(0.36 * u, (dy + 0.02) * u, 0.33 * u, (dy - 0.035) * u);
      canvas.drawPath(d, _f(const Color(0xFF8EC9FF).withValues(alpha: 0.5 + 0.5 * op)));
    }
  }

  void _headFront(Canvas canvas) {
    switch (kind) {
      case BuddyKind.mindy:
        // star antenna
        canvas.drawLine(_p(0.5, 0.31), _p(0.5, 0.17), _s(const Color(0xFF8F7BFF), 0.02 * u));
        paintStar(canvas, _p(0.5, 0.13), 0.075 * u, const Color(0xFFFFD166));
        break;
      case BuddyKind.neutral:
        // leaf on top
        final leaf = Path()
          ..moveTo(0.5 * u, 0.31 * u)
          ..quadraticBezierTo(0.62 * u, 0.12 * u, 0.74 * u, 0.20 * u)
          ..quadraticBezierTo(0.64 * u, 0.32 * u, 0.5 * u, 0.31 * u);
        canvas.drawPath(leaf, _f(const Color(0xFF5BB46B)));
        canvas.drawLine(_p(0.52, 0.29), _p(0.68, 0.22), _s(const Color(0xFF3F8F50), 0.01 * u));
        break;
      case BuddyKind.sad:
        // droplet tip on the head
        final d = Path()
          ..moveTo(0.5 * u, 0.20 * u)
          ..quadraticBezierTo(0.42 * u, 0.31 * u, 0.5 * u, 0.33 * u)
          ..quadraticBezierTo(0.58 * u, 0.31 * u, 0.5 * u, 0.20 * u);
        canvas.drawPath(d, _f(const Color(0xFF8EC9FF)));
        break;
      case BuddyKind.calm:
        paintStar(canvas, _p(0.5, 0.20), 0.05 * u, const Color(0xFFFFF3B0));
        break;
      case BuddyKind.happy:
        paintStar(canvas, _p(0.5, 0.21), 0.05 * u, const Color(0xFFFF6FA5));
        break;
      default:
        break;
    }
  }

  void _props(Canvas canvas) {
    switch (kind) {
      case BuddyKind.scared:
        // protective heart shield held in front
        final shield = Path()
          ..moveTo(0.60 * u, 0.74 * u)
          ..lineTo(0.86 * u, 0.74 * u)
          ..lineTo(0.86 * u, 0.86 * u)
          ..quadraticBezierTo(0.73 * u, 0.99 * u, 0.60 * u, 0.86 * u)
          ..close();
        canvas.drawPath(shield, _f(const Color(0xFFFFFFFF)));
        canvas.drawPath(shield, _s(const Color(0xFF6BCDB8), 0.015 * u));
        _heart(canvas, _p(0.73, 0.83), 0.05 * u, const Color(0xFFFF6FA5));
        break;
      case BuddyKind.sad:
        // little rain cloud + comforting heart
        paintCloud(canvas, _p(0.80, 0.16), 0.26 * u, opacity: 0.95);
        for (var i = 0; i < 3; i++) {
          final f = ((t * 1.5 + i * 0.33) % 1.0);
          canvas.drawLine(_p(0.74 + i * 0.06, 0.24 + f * 0.14),
              _p(0.74 + i * 0.06, 0.27 + f * 0.14), _s(const Color(0xFF8EC9FF), 0.012 * u));
        }
        _heart(canvas, _p(0.20, 0.80), 0.04 * u, const Color(0xFFFF9BB8));
        break;
      case BuddyKind.calm:
        // floating leaf and stars
        final fy = 0.12 + 0.03 * sin(t * 2 * pi);
        paintStar(canvas, _p(0.15, fy + 0.10), 0.03 * u, const Color(0xFFFFF3B0));
        paintStar(canvas, _p(0.85, fy + 0.20), 0.025 * u, const Color(0xFFFFF3B0));
        final leaf = Path()
          ..moveTo(0.10 * u, 0.50 * u)
          ..quadraticBezierTo(0.15 * u, 0.40 * u, 0.22 * u, 0.46 * u)
          ..quadraticBezierTo(0.15 * u, 0.55 * u, 0.10 * u, 0.50 * u);
        canvas.drawPath(leaf, _f(const Color(0xFF9BDDB0)));
        break;
      case BuddyKind.happy:
        for (var i = 0; i < 4; i++) {
          final a = t * 2 * pi + i * pi / 2;
          final p = _p(0.5 + cos(a) * 0.46, 0.45 + sin(a) * 0.38);
          if (i.isEven) {
            paintStar(canvas, p, 0.035 * u, const Color(0xFFFFD166));
          } else {
            _heart(canvas, p, 0.03 * u, const Color(0xFFFF6FA5));
          }
        }
        break;
      case BuddyKind.excited:
        for (var i = 0; i < 3; i++) {
          final a = t * 2 * pi + i * 2.1;
          paintStar(canvas, _p(0.5 + cos(a) * 0.46, 0.40 + sin(a) * 0.30),
              0.035 * u, const Color(0xFFFFE066));
        }
        break;
      case BuddyKind.worried:
        paintCloud(canvas, _p(0.80, 0.17), 0.24 * u, opacity: 0.9);
        break;
      case BuddyKind.mindy:
        paintStar(canvas, _p(0.14, 0.40), 0.03 * u, const Color(0xFFFFD166));
        paintStar(canvas, _p(0.88, 0.50), 0.025 * u, const Color(0xFFFF8AD0));
        break;
      case BuddyKind.neutral:
        break;
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 2, c.dy - r * 0.2, c.dx - r * 0.9, c.dy - r * 1.4, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.9, c.dy - r * 1.4, c.dx + r * 2, c.dy - r * 0.2, c.dx, c.dy + r);
    canvas.drawPath(p, _f(color));
  }

  @override
  bool shouldRepaint(covariant BuddyPainter old) => old.t != t || old.kind != kind;
}

/// One creature, with its own slow looping motion. Pass [clock] to share one
/// AnimationController across many creatures (check-in screen), or leave it
/// null for a self-animated creature.
class BuddyWidget extends StatefulWidget {
  final BuddyKind kind;
  final double size;
  final bool animated;
  final Animation<double>? clock;
  final double phase;

  const BuddyWidget({
    super.key,
    required this.kind,
    this.size = 96,
    this.animated = true,
    this.clock,
    this.phase = 0,
  });

  @override
  State<BuddyWidget> createState() => _BuddyWidgetState();
}

class _BuddyWidgetState extends State<BuddyWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;

  @override
  void initState() {
    super.initState();
    if (widget.animated && widget.clock == null) {
      _own = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 4000))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  double _bob(double t) {
    switch (widget.kind) {
      case BuddyKind.happy:
      case BuddyKind.excited:
        return sin(t * 4 * pi).abs() * 0.07;
      case BuddyKind.scared:
        return 0.0;
      case BuddyKind.sad:
        return sin(t * 2 * pi) * 0.012;
      default:
        return sin(t * 2 * pi) * 0.025;
    }
  }

  double _sway(double t) =>
      widget.kind == BuddyKind.scared ? sin(t * 6 * pi) * 0.025 : 0.0;

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final Listenable? l = widget.clock ?? _own;
    Widget body(double t) => Transform.translate(
          offset: Offset(0, -_bob(t) * s),
          child: Transform.rotate(
            angle: _sway(t),
            child: CustomPaint(
              size: Size(s, s * 1.05),
              painter: BuddyPainter(widget.kind, t),
            ),
          ),
        );
    if (!widget.animated || l == null) {
      return SizedBox(width: s, height: s * 1.05, child: body(0));
    }
    return SizedBox(
      width: s,
      height: s * 1.05,
      child: AnimatedBuilder(
        animation: l,
        builder: (_, __) {
          final base = widget.clock?.value ?? _own!.value;
          return body((base + widget.phase) % 1.0);
        },
      ),
    );
  }
}

/// The recurring Mindy mascot.
class MindyMascot extends StatelessWidget {
  final double size;
  const MindyMascot({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) =>
      BuddyWidget(kind: BuddyKind.mindy, size: size);
}

/// The atmosphere behind an emotion: sky colours plus slow, soft motion
/// (no flashing). [t] is a looping 0..1 clock.
class EmotionBackdropPainter extends CustomPainter {
  final EmotionState emotion;
  final double t;
  EmotionBackdropPainter(this.emotion, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pal = emotion.palette;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.top, pal.bottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    switch (emotion) {
      case EmotionState.scared:
        // a warm glow and slowly floating hearts: "you are safe"
        canvas.drawCircle(Offset(w * 0.5, h * 0.95), w * 0.55,
            Paint()..color = const Color(0x33FFD9A8));
        for (var i = 0; i < 4; i++) {
          final f = (t + i * 0.25) % 1.0;
          final x = w * (0.15 + 0.7 * ((i * 0.37) % 1.0));
          final y = h * (1.0 - f * 0.9);
          _heart(canvas, Offset(x, y), 5 + 2.0 * (i % 2),
              const Color(0xFFFF9BB8).withValues(alpha: 0.55));
        }
        break;
      case EmotionState.sad:
        canvas.drawCircle(Offset(w * 0.5, h), w * 0.5,
            Paint()..color = const Color(0x33FFE2B8));
        for (var i = 0; i < 9; i++) {
          final f = (t * 1.0 + i * 0.111) % 1.0;
          final x = w * ((i * 0.131 + 0.07) % 1.0);
          final y = h * f;
          canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + 8),
              Paint()
                ..color = const Color(0xFF8EC9FF).withValues(alpha: 0.55)
                ..strokeWidth = 2
                ..strokeCap = StrokeCap.round);
        }
        break;
      case EmotionState.neutral:
        for (var i = 0; i < 4; i++) {
          final f = (t * 0.7 + i * 0.25) % 1.0;
          final x = w * ((f + i * 0.2) % 1.0);
          final y = h * (0.2 + 0.6 * ((i * 0.3 + f * 0.4) % 1.0));
          _leaf(canvas, Offset(x, y), 9, const Color(0xFF7CC47A).withValues(alpha: 0.55));
        }
        canvas.drawOval(
            Rect.fromCenter(center: Offset(w * 0.5, h * 1.02), width: w * 1.2, height: h * 0.25),
            Paint()..color = const Color(0xFFA6D98A));
        break;
      case EmotionState.calm:
        final r = Random(3);
        for (var i = 0; i < 9; i++) {
          final x = r.nextDouble() * w;
          final y = r.nextDouble() * h * 0.7;
          final tw = 0.5 + 0.5 * sin(t * 2 * pi + i);
          paintStar(canvas, Offset(x, y), 2.5 + 2 * tw,
              Colors.white.withValues(alpha: 0.55 + 0.35 * tw));
        }
        paintCloud(canvas, Offset(((t * 0.5) % 1.0) * w * 1.2 - w * 0.1, h * 0.2),
            w * 0.4, opacity: 0.6);
        for (var i = 0; i < 2; i++) {
          final f = (t + i * 0.5) % 1.0;
          _leaf(canvas, Offset(w * (0.2 + 0.6 * f), h * (0.55 + 0.1 * sin(f * 6.28 + i))), 8,
              const Color(0xFFB7E4C7).withValues(alpha: 0.7));
        }
        break;
      case EmotionState.happy:
        // sun rays (slow rotation, very soft) + rainbow + sparkles
        canvas.save();
        canvas.translate(w * 0.5, h * 0.35);
        canvas.rotate(t * 0.6);
        for (var i = 0; i < 10; i++) {
          canvas.rotate(2 * pi / 10);
          canvas.drawRect(Rect.fromLTWH(0, -3, w * 0.9, 6),
              Paint()..color = const Color(0x18FFFFFF));
        }
        canvas.restore();
        paintRainbow(canvas, Offset(w * 0.5, h * 0.62), w * 0.62, 0.55);
        for (var i = 0; i < 8; i++) {
          final f = (t + i * 0.125) % 1.0;
          final tw = 0.5 + 0.5 * sin(f * 2 * pi);
          paintStar(canvas, Offset(w * ((i * 0.23 + 0.1) % 1.0), h * ((i * 0.37 + 0.05) % 0.8)),
              3 + 3 * tw, const Color(0xFFFFF59D).withValues(alpha: 0.6 + 0.3 * tw));
        }
        for (var i = 0; i < 3; i++) {
          final f = (t + i * 0.33) % 1.0;
          _heart(canvas, Offset(w * (0.2 + 0.3 * i), h * (1.0 - f * 0.8)), 5,
              const Color(0xFFFF8AB0).withValues(alpha: 0.6));
        }
        break;
    }
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 2, c.dy - r * 0.2, c.dx - r * 0.9, c.dy - r * 1.4, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.9, c.dy - r * 1.4, c.dx + r * 2, c.dy - r * 0.2, c.dx, c.dy + r);
    canvas.drawPath(p, Paint()..color = color);
  }

  void _leaf(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy - r * 1.2, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy + r * 1.2, c.dx - r, c.dy);
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant EmotionBackdropPainter old) =>
      old.t != t || old.emotion != emotion;
}
