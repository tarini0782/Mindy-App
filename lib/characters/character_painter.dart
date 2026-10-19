import 'dart:math';
import 'package:flutter/material.dart';
import 'character_id.dart';
import 'companion.dart';

/// Draws the six Mindy characters as simple, consistent 2D vector shapes
/// (same proportions, same soft outline-free style, same face language).
/// All units are multiples of the canvas width [u]; height is 1.1 * u.
class CharacterPainter extends CustomPainter {
  final CharacterId id;
  final CharacterState state;
  final double t; // 0..1 looping clock
  final double blink; // 0 open .. 1 closed
  final CompanionLook look;

  CharacterPainter({
    required this.id,
    required this.state,
    required this.t,
    required this.blink,
    required this.look,
  });

  static const Color _ink = Color(0xFF2B2350);

  late double u;

  Paint _fill(Color c) => Paint()..color = c;

  Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  Offset _p(double x, double y) => Offset(x * u, y * u);

  void _oval(Canvas c, double cx, double cy, double w, double h, Color color) {
    c.drawOval(
        Rect.fromCenter(center: _p(cx, cy), width: w * u, height: h * u),
        _fill(color));
  }

  void _circle(Canvas c, double cx, double cy, double r, Color color) {
    c.drawCircle(_p(cx, cy), r * u, _fill(color));
  }

  void _star(Canvas c, Offset center, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(center.dx + cos(a) * rad, center.dy + sin(a) * rad);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, _fill(color));
  }

  void _tri(Canvas c, Offset a, Offset b, Offset d, Color color) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..close();
    c.drawPath(path, _fill(color));
  }

  @override
  void paint(Canvas canvas, Size size) {
    u = size.width;

    // Soft glow for calm, ground shadow for everyone.
    if (state == CharacterState.calm) {
      _circle(canvas, 0.5, 0.56, 0.52, id.accent.withValues(alpha: 0.18));
    }
    canvas.drawOval(
      Rect.fromCenter(center: _p(0.5, 1.03), width: 0.5 * u, height: 0.06 * u),
      _fill(const Color(0x22000000)),
    );

    switch (id) {
      case CharacterId.kara:
        _kara(canvas);
        break;
      case CharacterId.nova:
        _nova(canvas);
        break;
      case CharacterId.lumi:
        _lumi(canvas);
        break;
      case CharacterId.bubbles:
        _bubbles(canvas);
        break;
      case CharacterId.pip:
        _pip(canvas);
        break;
      case CharacterId.twinkle:
        _twinkle(canvas);
        break;
    }
    _stateSparkles(canvas);
  }

  // ---------------------------------------------------------------- shared

  void _face(Canvas canvas, {double eyeY = 0.43, Color cheek = const Color(0x66FF6FA5)}) {
    final ex1 = 0.5 - 0.105, ex2 = 0.5 + 0.105;
    final happyEyes = state == CharacterState.happy ||
        state == CharacterState.excited ||
        state == CharacterState.celebrating;
    final closed = state == CharacterState.calm || blink > 0.6;
    final stroke = _line(_ink, 0.022 * u);

    for (final x in [ex1, ex2]) {
      if (happyEyes) {
        canvas.drawArc(
            Rect.fromCenter(
                center: _p(x, eyeY + 0.012), width: 0.085 * u, height: 0.07 * u),
            pi, pi, false, stroke);
      } else if (closed) {
        canvas.drawArc(
            Rect.fromCenter(
                center: _p(x, eyeY - 0.004), width: 0.085 * u, height: 0.06 * u),
            0.1, pi - 0.2, false, stroke);
      } else {
        canvas.drawOval(
            Rect.fromCenter(
                center: _p(x, eyeY), width: 0.062 * u, height: 0.08 * u),
            _fill(_ink));
        canvas.drawCircle(
            _p(x + 0.012, eyeY - 0.016), 0.014 * u, _fill(Colors.white));
      }
    }
    _circle(canvas, 0.5 - 0.175, eyeY + 0.055, 0.035, cheek);
    _circle(canvas, 0.5 + 0.175, eyeY + 0.055, 0.035, cheek);

    final my = eyeY + 0.10;
    if (state == CharacterState.excited || state == CharacterState.celebrating) {
      canvas.drawArc(
          Rect.fromCenter(center: _p(0.5, my), width: 0.11 * u, height: 0.09 * u),
          0, pi, true, _fill(const Color(0xFFFF6F91)));
    } else {
      final wide = state == CharacterState.happy ? 0.12 : 0.085;
      canvas.drawArc(
          Rect.fromCenter(
              center: _p(0.5, my - 0.012), width: wide * u, height: 0.06 * u),
          0.15, pi - 0.3, false, stroke);
    }
  }

  void _stateSparkles(Canvas canvas) {
    if (state == CharacterState.excited ||
        state == CharacterState.celebrating ||
        state == CharacterState.encouraging) {
      final n = state == CharacterState.celebrating ? 5 : 3;
      for (var i = 0; i < n; i++) {
        final a = t * 2 * pi + i * 2 * pi / n;
        final r = 0.46 + 0.04 * sin(t * 6 * pi + i);
        final pos = _p(0.5 + cos(a) * r, 0.52 + sin(a) * r * 0.85);
        final colors = [
          const Color(0xFFFFD166),
          const Color(0xFFFF8AD0),
          const Color(0xFF8EDCF5),
          const Color(0xFFA6F0B8),
          const Color(0xFFC9B6FF),
        ];
        _star(canvas, pos, 0.035 * u + 0.012 * u * sin(t * 8 * pi + i),
            colors[i % colors.length]);
      }
    }
  }

  // ----------------------------------------------------------- the six kids
  //
  // v29: the hosts used to be creatures -- a unicorn with a horn and mane, a
  // baby dragon with spikes and a tail, a fairy. Drawn as flat shapes they
  // read as little monsters rather than friends, so all six are now children,
  // in the SAME visual language as the character the child makes for
  // themselves (see avatar_painter.dart). Each one keeps its name, its
  // colours and its personality; only the drawing changed.
  //
  // Proportions are unchanged, so _face() and every caller still line up:
  //   head   circle at (0.5, 0.42), r 0.27
  //   body   oval   at (0.5, 0.80), 0.46 x 0.38
  //   feet   y 0.98

  /// One child. [hair] and [skin] set who it is; [prop] picks the one thing
  /// they carry or wear, which is what makes them recognisable at a glance.
  void _kid(
    Canvas canvas, {
    required Color skin,
    required Color hair,
    required Color clothes,
    required int hairStyle, // 0 short, 1 bob, 2 long, 3 curly, 4 buns, 5 pony
    required int prop, // 0 none, 1 star clip, 2 cape, 3 flower crown,
    // 4 bubble wand, 5 explorer cap, 6 lantern
    double eyeY = 0.43,
  }) {
    final sway = sin(t * 2 * pi) * 0.012;
    final armSwing = sin(t * 2 * pi) * 0.02;

    // cape goes behind everything
    if (prop == 2) {
      final cape = Path()
        ..moveTo(0.30 * u, 0.60 * u)
        ..quadraticBezierTo((0.10 + sway) * u, 0.84 * u, 0.24 * u, 1.0 * u)
        ..lineTo(0.76 * u, 1.0 * u)
        ..quadraticBezierTo((0.90 - sway) * u, 0.84 * u, 0.70 * u, 0.60 * u)
        ..close();
      canvas.drawPath(cape, _fill(const Color(0xFFFF6F91)));
    }

    // legs + shoes
    _oval(canvas, 0.43, 0.95, 0.09, 0.14, skin);
    _oval(canvas, 0.57, 0.95, 0.09, 0.14, skin);
    _oval(canvas, 0.43, 1.00, 0.12, 0.07, clothes);
    _oval(canvas, 0.57, 1.00, 0.12, 0.07, clothes);

    // long hair falls behind the body
    if (hairStyle == 2) _oval(canvas, 0.5, 0.60, 0.50, 0.62, hair);

    // body + arms
    _oval(canvas, 0.5, 0.80, 0.46, 0.38, clothes);
    _oval(canvas, 0.26, 0.78 + armSwing, 0.12, 0.26, clothes);
    _oval(canvas, 0.74, 0.78 - armSwing, 0.12, 0.26, clothes);
    _circle(canvas, 0.26, 0.90 + armSwing, 0.052, skin);
    _circle(canvas, 0.74, 0.90 - armSwing, 0.052, skin);

    // head
    _circle(canvas, 0.5, 0.42, 0.27, skin);
    _circle(canvas, 0.235, 0.45, 0.042, skin); // ears
    _circle(canvas, 0.765, 0.45, 0.042, skin);

    // hair behind / beside the face
    switch (hairStyle) {
      case 1: // bob
        _oval(canvas, 0.28, 0.44, 0.12, 0.30, hair);
        _oval(canvas, 0.72, 0.44, 0.12, 0.30, hair);
        break;
      case 3: // curly volume
        for (final o in [
          [0.27, 0.30],
          [0.73, 0.30],
          [0.24, 0.44],
          [0.76, 0.44],
        ]) {
          _circle(canvas, o[0], o[1], 0.085, hair);
        }
        break;
      case 4: // two buns
        _circle(canvas, 0.24, 0.20, 0.080, hair);
        _circle(canvas, 0.76, 0.20, 0.080, hair);
        break;
      case 5: // ponytail
        _oval(canvas, 0.78, 0.52, 0.13, 0.36, hair);
        break;
    }

    // the cap of hair over the top of the head, common to all styles
    canvas.drawArc(
        Rect.fromCenter(center: _p(0.5, 0.40), width: 0.56 * u, height: 0.56 * u),
        pi * 1.02, pi * 0.96, true, _fill(hair));
    if (hairStyle == 0) {
      // short: a small sweep across the brow
      canvas.drawArc(
          Rect.fromCenter(center: _p(0.46, 0.34), width: 0.34 * u, height: 0.22 * u),
          pi, pi * 0.9, true, _fill(hair));
    }

    _prop(canvas, prop, hair);
    _face(canvas, eyeY: eyeY);
  }

  /// The one thing that makes each child recognisable. Nothing here has a
  /// horn, a spike or a tail.
  void _prop(Canvas canvas, int prop, Color hair) {
    switch (prop) {
      case 1: // star hair clip
        _star(canvas, _p(0.70, 0.24), 0.055 * u, const Color(0xFFFFD166));
        break;
      case 3: // flower crown
        canvas.drawArc(
            Rect.fromCenter(center: _p(0.5, 0.34), width: 0.50 * u, height: 0.44 * u),
            pi * 1.08, pi * 0.84, false, _line(const Color(0xFF7FC25C), 0.022 * u));
        for (final x in [0.34, 0.5, 0.66]) {
          _circle(canvas, x, 0.185, 0.038, const Color(0xFFFF8AD0));
          _circle(canvas, x, 0.185, 0.016, const Color(0xFFFFF3D6));
        }
        break;
      case 4: // bubble wand, held in the raised hand
        canvas.drawLine(_p(0.80, 0.86), _p(0.90, 0.64),
            _line(const Color(0xFF8D6E63), 0.018 * u));
        canvas.drawCircle(_p(0.90, 0.60), 0.055 * u,
            _line(const Color(0xFF6FC3FF), 0.016 * u));
        _circle(canvas, 0.82, 0.46, 0.030, const Color(0x886FC3FF));
        _circle(canvas, 0.94, 0.40, 0.020, const Color(0x886FC3FF));
        break;
      case 5: // explorer cap
        canvas.drawArc(
            Rect.fromCenter(center: _p(0.5, 0.30), width: 0.56 * u, height: 0.44 * u),
            pi, pi, true, _fill(const Color(0xFF4FB6D9)));
        _oval(canvas, 0.74, 0.30, 0.26, 0.055, const Color(0xFF3A9CBD));
        break;
      case 6: // paper lantern
        canvas.drawLine(_p(0.76, 0.88), _p(0.86, 0.70),
            _line(const Color(0xFF8D6E63), 0.016 * u));
        _oval(canvas, 0.88, 0.62, 0.15, 0.17, const Color(0xFFFFE27A));
        _circle(canvas, 0.88, 0.62, 0.035, const Color(0xFFFFF7D6));
        break;
      default:
        break;
    }
  }

  void _accessory(Canvas canvas, int acc) {
    switch (acc) {
      case 1: // crown
        final crown = Path()
          ..moveTo(0.33 * u, 0.26 * u)
          ..lineTo(0.35 * u, 0.11 * u)
          ..lineTo(0.43 * u, 0.20 * u)
          ..lineTo(0.50 * u, 0.08 * u)
          ..lineTo(0.57 * u, 0.20 * u)
          ..lineTo(0.65 * u, 0.11 * u)
          ..lineTo(0.67 * u, 0.26 * u)
          ..close();
        canvas.drawPath(crown, _fill(const Color(0xFFFFD166)));
        _circle(canvas, 0.5, 0.19, 0.020, const Color(0xFFFF6F91));
        break;
      case 2: // party hat
        _tri(canvas, _p(0.36, 0.24), _p(0.5, 0.01), _p(0.64, 0.24),
            const Color(0xFF8EA8FF));
        _circle(canvas, 0.5, 0.02, 0.028, const Color(0xFFFFD166));
        break;
      case 3: // bow
        _tri(canvas, _p(0.70, 0.22), _p(0.82, 0.15), _p(0.82, 0.29),
            const Color(0xFFFF6F91));
        _tri(canvas, _p(0.70, 0.22), _p(0.58, 0.15), _p(0.58, 0.29),
            const Color(0xFFFF6F91));
        _circle(canvas, 0.70, 0.22, 0.024, const Color(0xFFFFB3C9));
        break;
      default:
        break;
    }
  }

  // Kara: the guide. Rainbow-loving, star clip, dress-up colour applies.
  void _kara(Canvas canvas) {
    _kid(canvas,
        skin: const Color(0xFFF6C99B),
        hair: const Color(0xFF8B5E3C),
        clothes: look.bodyColor == const Color(0xFFFFF1FA)
            ? const Color(0xFFEE86B7)
            : look.bodyColor,
        hairStyle: 2,
        prop: look.accessory == 4 ? 2 : 1);
    _accessory(canvas, look.accessory);
  }

  // Nova: the small hero. Cape, short hair, bold colours.
  void _nova(Canvas canvas) => _kid(canvas,
      skin: const Color(0xFFC07E55),
      hair: const Color(0xFF14110F),
      clothes: const Color(0xFF4F7CFF),
      hairStyle: 0,
      prop: 2);

  // Lumi: calm and kind, flower crown.
  void _lumi(Canvas canvas) => _kid(canvas,
      skin: const Color(0xFFFFE0C4),
      hair: const Color(0xFFE8B45C),
      clothes: const Color(0xFFB57BFF),
      hairStyle: 1,
      prop: 3);

  // Bubbles: playful, two buns, bubble wand.
  void _bubbles(Canvas canvas) => _kid(canvas,
      skin: const Color(0xFFE0A579),
      hair: const Color(0xFF3B2A20),
      clothes: const Color(0xFF2A9FD8),
      hairStyle: 4,
      prop: 4);

  // Pip: the explorer. Was a baby dragon; now a kid in an explorer cap.
  void _pip(Canvas canvas) => _kid(canvas,
      skin: const Color(0xFF9A5E3C),
      hair: const Color(0xFF14110F),
      clothes: const Color(0xFF6FDD9C),
      hairStyle: 3,
      prop: 5);

  // Twinkle: the quiet one who guides breathing. Was a fairy; now a kid
  // with a paper lantern, which suits a calm activity better than wings.
  void _twinkle(Canvas canvas) => _kid(canvas,
      skin: const Color(0xFFFFE0C4),
      hair: const Color(0xFFEE86B7),
      clothes: const Color(0xFF8EDCF5),
      hairStyle: 5,
      prop: 6,
      eyeY: 0.44);


  @override
  bool shouldRepaint(covariant CharacterPainter old) =>
      old.t != t ||
      old.blink != blink ||
      old.state != state ||
      old.id != id ||
      old.look.colorIndex != look.colorIndex ||
      old.look.accessoryIndex != look.accessoryIndex;
}
