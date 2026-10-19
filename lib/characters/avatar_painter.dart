import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'avatar.dart';

/// Draws a [MindyAvatar] from plain shapes. No image assets, no network,
/// no external artwork.
///
/// v41: REDRAWN. The old version laid the character out in a 100x120 box
/// with a 38x40 head, thin rectangle limbs and dot eyes, which is why it
/// read as a blob at any size. This one uses a 200x300 box with storybook
/// proportions — the head is about a third of the height, the eyes carry
/// highlights, the brows and blush do real work, and the outfit has
/// shoulders and a taper instead of being a rounded rectangle.
///
/// Geometry here matches the approved character sheet exactly, so what the
/// app draws is what was signed off rather than an approximation of it.
///
/// Everything is expressed in the 200x300 space and scaled to whatever
/// size the widget is given, so the same character is correct as a 28px
/// chip and as a 240px portrait.
class AvatarPainter extends CustomPainter {
  final MindyAvatar a;

  /// 0..1, a gentle idle bob. Pass 0 for a still picture.
  final double bob;

  const AvatarPainter(this.a, {this.bob = 0});

  static const double _w = 200;
  static const double _h = 300;

  /// The box ratio a caller should use so the figure is not letterboxed.
  static const double aspect = _h / _w; // 1.5

  // ---- the palette the drawing leans on -------------------------------
  static const Color _ink = Color(0xFF2A2233);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _gold = Color(0xFFFFD166);
  static const Color _goldDeep = Color(0xFFF2C14E);
  static const Color _blush = Color(0xFFF4694F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate(
      (size.width - _w * s) / 2,
      (size.height - _h * s) / 2 + math.sin(bob * math.pi * 2) * 3 * s,
    );
    canvas.scale(s);

    final skin = AvatarOptions.skins[a.skin.clamp(0, AvatarOptions.skins.length - 1).toInt()];
    final hair = AvatarOptions.hairColors[a.hairColor.clamp(0, AvatarOptions.hairColors.length - 1).toInt()];
    final cloth = AvatarOptions.outfitColors[a.outfitColor.clamp(0, AvatarOptions.outfitColors.length - 1).toInt()];
    final clothDark = Color.lerp(cloth, _ink, 0.22)!;

    _shadow(canvas);
    _wings(canvas);
    _hairBack(canvas, hair);
    _legs(canvas, skin, cloth);
    _outfit(canvas, cloth, clothDark);
    _arms(canvas, skin, cloth);
    _head(canvas, skin);
    _face(canvas, skin);
    _hairFront(canvas, hair);
    _headwear(canvas);
    _extras(canvas, skin);

    canvas.restore();
  }

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Builds a path from a compact list of moves. Keeps the long shapes
  /// below readable instead of forty chained calls.
  Path _p(void Function(Path p) build) {
    final p = Path();
    build(p);
    return p;
  }

  // ----------------------------------------------------------- shadow
  void _shadow(Canvas c) {
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(100, 286), width: 104, height: 14),
        _fill(const Color(0xFF25354A).withValues(alpha: 0.07)));
  }

  // ------------------------------------------------------------ wings
  void _wings(Canvas c) {
    if (a.wings == 0) return;
    switch (a.wings) {
      case 1: // butterfly: an upper and a lower lobe each side
        for (final d in [-1.0, 1.0]) {
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 26, 150)
                ..cubicTo(100 + d * 56, 118, 100 + d * 84, 126, 100 + d * 82, 156)
                ..cubicTo(100 + d * 80, 184, 100 + d * 52, 190, 100 + d * 26, 174)
                ..close()),
              _fill(const Color(0xFFCDE8F7)));
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 26, 176)
                ..cubicTo(100 + d * 50, 194, 100 + d * 68, 212, 100 + d * 58, 228)
                ..cubicTo(100 + d * 48, 242, 100 + d * 28, 230, 100 + d * 22, 204)
                ..close()),
              _fill(const Color(0xFFE7D6FA)));
          c.drawCircle(Offset(100 + d * 54, 146), 5, _fill(const Color(0x99FFFFFF)));
        }
        break;
      case 2: // fairy: one long teardrop each side, with veins
        for (final d in [-1.0, 1.0]) {
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 24, 158)
                ..cubicTo(100 + d * 44, 110, 100 + d * 86, 92, 100 + d * 94, 126)
                ..cubicTo(100 + d * 102, 162, 100 + d * 64, 196, 100 + d * 24, 180)
                ..close()),
              _fill(const Color(0xE6E7D6FA)));
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 24, 158)
                ..cubicTo(100 + d * 44, 130, 100 + d * 66, 116, 100 + d * 80, 126)),
              _line(const Color(0xFFB8A4F5), 2.6));
        }
        break;
      default: // dragon: soft scallops, no spikes
        for (final d in [-1.0, 1.0]) {
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 24, 164)
                ..lineTo(100 + d * 82, 122)
                ..cubicTo(100 + d * 92, 116, 100 + d * 96, 128, 100 + d * 92, 140)
                ..lineTo(100 + d * 84, 156)
                ..cubicTo(100 + d * 94, 154, 100 + d * 96, 166, 100 + d * 88, 172)
                ..lineTo(100 + d * 70, 184)
                ..cubicTo(100 + d * 76, 190, 100 + d * 68, 198, 100 + d * 58, 194)
                ..lineTo(100 + d * 24, 182)
                ..close()),
              _fill(const Color(0xFF8FD08A)));
          c.drawPath(
              _p((p) => p
                ..moveTo(100 + d * 26, 168)
                ..lineTo(100 + d * 74, 134)
                ..moveTo(100 + d * 26, 176)
                ..lineTo(100 + d * 80, 160)),
              _line(const Color(0xFF6FAE76), 2.2));
        }
    }
  }

  // ------------------------------------------------------------- hair
  Path get _hairLong => _p((p) => p
    ..moveTo(100, 30)
    ..cubicTo(138, 30, 162, 58, 162, 98)
    ..lineTo(162, 186)
    ..cubicTo(162, 193, 154, 196, 149, 191)
    ..lineTo(144, 124)
    ..cubicTo(140, 82, 126, 66, 100, 66)
    ..cubicTo(74, 66, 60, 82, 56, 124)
    ..lineTo(51, 191)
    ..cubicTo(46, 196, 38, 193, 38, 186)
    ..lineTo(38, 98)
    ..cubicTo(38, 58, 62, 30, 100, 30)
    ..close());

  Path get _hairBob => _p((p) => p
    ..moveTo(100, 30)
    ..cubicTo(138, 30, 162, 58, 162, 98)
    ..lineTo(162, 150)
    ..cubicTo(162, 157, 154, 160, 149, 155)
    ..lineTo(144, 118)
    ..cubicTo(140, 82, 126, 66, 100, 66)
    ..cubicTo(74, 66, 60, 82, 56, 118)
    ..lineTo(51, 155)
    ..cubicTo(46, 160, 38, 157, 38, 150)
    ..lineTo(38, 98)
    ..cubicTo(38, 58, 62, 30, 100, 30)
    ..close());

  /// The swoopy fringe used by every long-ish style.
  Path get _fringe => _p((p) => p
    ..moveTo(100, 34)
    ..cubicTo(130, 34, 152, 56, 153, 86)
    ..cubicTo(147, 72, 133, 64, 117, 63)
    ..cubicTo(113, 52, 104, 47, 95, 50)
    ..cubicTo(85, 54, 79, 63, 75, 71)
    ..cubicTo(64, 75, 53, 82, 47, 92)
    ..cubicTo(45, 58, 70, 34, 100, 34)
    ..close());

  /// A close cap, for the short style.
  Path get _cap => _p((p) => p
    ..moveTo(100, 32)
    ..cubicTo(132, 32, 158, 58, 158, 94)
    ..cubicTo(154, 84, 148, 78, 142, 74)
    ..cubicTo(128, 60, 112, 56, 100, 56)
    ..cubicTo(88, 56, 72, 60, 58, 74)
    ..cubicTo(52, 78, 46, 84, 42, 94)
    ..cubicTo(42, 58, 68, 32, 100, 32)
    ..close());

  void _hairBack(Canvas c, Color hair) {
    final p = _fill(hair);
    switch (a.hairStyle) {
      case 1: // bob
        c.drawPath(_hairBob, p);
        break;
      case 2: // long
        c.drawPath(_hairLong, p);
        break;
      case 3: // curly: a cloud of volume behind the head
        for (final o in const [
          Offset(62, 68),
          Offset(86, 52),
          Offset(114, 52),
          Offset(138, 68),
          Offset(100, 74),
        ]) {
          c.drawCircle(o, o.dx == 100 ? 28 : 22, p);
        }
        break;
      case 4: // two buns
        c.drawPath(_hairBob, p);
        c.drawCircle(const Offset(42, 62), 17, p);
        c.drawCircle(const Offset(158, 62), 17, p);
        c.drawCircle(const Offset(38, 57), 6,
            _fill(Color.lerp(hair, _white, 0.28)!));
        c.drawCircle(const Offset(154, 57), 6,
            _fill(Color.lerp(hair, _white, 0.28)!));
        break;
      case 5: // ponytail
        c.drawPath(_hairBob, p);
        c.drawPath(
            _p((p2) => p2
              ..moveTo(156, 66)
              ..cubicTo(184, 70, 194, 102, 184, 132)
              ..cubicTo(178, 150, 156, 156, 150, 142)
              ..cubicTo(166, 122, 166, 86, 150, 72)
              ..close()),
            p);
        c.drawCircle(const Offset(154, 70), 7, _fill(_gold));
        break;
      case 6: // braids: a bob plus a tapering plait down each side
        c.drawPath(_hairBob, p);
        for (final d in [-1.0, 1.0]) {
          c.drawPath(
              _p((p2) => p2
                ..moveTo(100 + d * 56, 104)
                ..cubicTo(100 + d * 70, 128, 100 + d * 66, 162, 100 + d * 54, 186)
                ..cubicTo(100 + d * 48, 198, 100 + d * 32, 194, 100 + d * 36, 182)
                ..cubicTo(100 + d * 44, 158, 100 + d * 44, 128, 100 + d * 40, 112)
                ..close()),
              p);
          c.drawCircle(Offset(100 + d * 45, 188), 7, _fill(_gold));
        }
        break;
      case 10: // afro: a big soft cloud, drawn behind and in front
        for (final o in const [
          Offset(56, 62),
          Offset(82, 42),
          Offset(118, 42),
          Offset(144, 62),
          Offset(100, 60),
        ]) {
          c.drawCircle(o, o.dx == 100 ? 34 : 26, p);
        }
        break;
      case 12: // mohawk: close sides, the strip is drawn in front
        c.drawPath(_cap, _fill(Color.lerp(hair, _ink, 0.25)!));
        break;
      case 13: // wavy: shoulder length
        c.drawPath(
            _p((p2) => p2
              ..moveTo(100, 30)
              ..cubicTo(138, 30, 162, 58, 162, 98)
              ..lineTo(162, 164)
              ..cubicTo(162, 171, 154, 174, 149, 169)
              ..lineTo(144, 120)
              ..cubicTo(140, 82, 126, 66, 100, 66)
              ..cubicTo(74, 66, 60, 82, 56, 120)
              ..lineTo(51, 169)
              ..cubicTo(46, 174, 38, 171, 38, 164)
              ..lineTo(38, 98)
              ..cubicTo(38, 58, 62, 30, 100, 30)
              ..close()),
            p);
        break;
    }
  }

  void _hairFront(Canvas c, Color hair) {
    final p = _fill(hair);
    switch (a.hairStyle) {
      case 0: // short
        c.drawPath(_cap, p);
        break;
      case 3: // curly
        for (final o in const [
          Offset(64, 66),
          Offset(86, 54),
          Offset(114, 55),
          Offset(136, 65),
        ]) {
          c.drawCircle(o, 18, p);
        }
        break;
      case 7: // crew cut: a close cap that hugs the skull
        c.drawPath(
            _p((p2) => p2
              ..moveTo(100, 34)
              ..cubicTo(134, 34, 156, 58, 156, 88)
              ..cubicTo(152, 76, 146, 70, 140, 66)
              ..cubicTo(126, 56, 112, 54, 100, 54)
              ..cubicTo(88, 54, 74, 56, 60, 66)
              ..cubicTo(54, 70, 48, 76, 44, 88)
              ..cubicTo(44, 58, 66, 34, 100, 34)
              ..close()),
            p);
        break;
      case 8: // spiky
        final spikes = Path()..moveTo(44, 90);
        const tips = [
          [51, 44],
          [63, 72],
          [74, 34],
          [86, 68],
          [100, 28],
          [113, 68],
          [125, 34],
          [136, 72],
          [149, 44],
        ];
        for (final t in tips) {
          spikes.lineTo(t[0].toDouble(), t[1].toDouble());
        }
        spikes
          ..lineTo(156, 90)
          ..cubicTo(148, 72, 128, 62, 100, 62)
          ..cubicTo(72, 62, 52, 72, 44, 90)
          ..close();
        c.drawPath(spikes, p);
        break;
      case 9: // side part: a swept fringe with a visible parting
        c.drawPath(
            _p((p2) => p2
              ..moveTo(100, 32)
              ..cubicTo(136, 32, 156, 58, 156, 92)
              ..cubicTo(150, 76, 140, 68, 126, 64)
              ..cubicTo(112, 52, 72, 52, 60, 68)
              ..cubicTo(52, 74, 46, 82, 44, 92)
              ..cubicTo(44, 58, 64, 32, 100, 32)
              ..close()),
            p);
        c.drawPath(
            _p((p2) => p2
              ..moveTo(60, 68)
              ..cubicTo(82, 50, 128, 54, 148, 76)
              ..cubicTo(128, 62, 84, 66, 60, 88)
              ..close()),
            _fill(Color.lerp(hair, _ink, 0.22)!));
        break;
      case 10: // afro: a smaller front cluster over the big back cloud
        for (final o in const [
          Offset(60, 60),
          Offset(84, 44),
          Offset(116, 44),
          Offset(140, 60),
        ]) {
          c.drawCircle(o, 22, p);
        }
        break;
      case 11: // buzz cut: a tight shadow over the scalp
        c.drawPath(
            _p((p2) => p2
              ..moveTo(100, 40)
              ..cubicTo(130, 40, 152, 60, 152, 90)
              ..cubicTo(142, 74, 126, 68, 100, 68)
              ..cubicTo(74, 68, 58, 74, 48, 90)
              ..cubicTo(48, 60, 70, 40, 100, 40)
              ..close()),
            _fill(hair.withValues(alpha: 0.88)));
        break;
      case 12: // mohawk: the strip
        c.drawPath(
            _p((p2) => p2
              ..moveTo(82, 72)
              ..cubicTo(82, 40, 90, 18, 100, 10)
              ..cubicTo(110, 18, 118, 40, 118, 72)
              ..cubicTo(112, 64, 88, 64, 82, 72)
              ..close()),
            p);
        break;
      default:
        c.drawPath(_fringe, p);
    }
  }

  // ------------------------------------------------------- legs, shoes
  void _legs(Canvas c, Color skin, Color cloth) {
    // Trousers on the hoodie and space suit; bare legs otherwise.
    final legColor = (a.outfit == 1 || a.outfit == 4) ? cloth : skin;
    c.drawRRect(
        RRect.fromLTRBR(85, 204, 98, 248, const Radius.circular(6.5)),
        _fill(legColor));
    c.drawRRect(
        RRect.fromLTRBR(102, 204, 115, 248, const Radius.circular(6.5)),
        _fill(legColor));

    _shoes(c, cloth);
  }

  /// Shoes. A real choice since v42 rather than a tint of the outfit.
  void _shoes(Canvas c, Color cloth) {
    // Each pair is drawn twice, mirrored, from one description.
    void pair(void Function(double left) draw) {
      draw(72);
      draw(98);
    }

    switch (a.shoes) {
      case 1: // boots: a taller shaft with a dark sole and a gold strap
        pair((x) {
          c.drawRRect(
              RRect.fromLTRBR(x, 228, x + 30, 256, const Radius.circular(7)),
              _fill(const Color(0xFF8A5A36)));
          c.drawRRect(
              RRect.fromLTRBR(x - 2, 252, x + 32, 264, const Radius.circular(6)),
              _fill(const Color(0xFF3F2A18)));
          c.drawLine(Offset(x + 4, 238), Offset(x + 26, 238),
              _line(const Color(0xFFC9A96B), 3.4));
        });
        break;
      case 2: // party shoes: rounded, with a buckle
        pair((x) {
          c.drawRRect(
              RRect.fromLTRBR(x, 244, x + 30, 260, const Radius.circular(9)),
              _fill(const Color(0xFFEE86B7)));
          c.drawRRect(
              RRect.fromLTRBR(x - 2, 256, x + 32, 265, const Radius.circular(5)),
              _fill(const Color(0xFFD96FA0)));
          c.drawCircle(Offset(x + 9, 249), 5, _fill(_gold));
        });
        break;
      case 3: // sandals: a sole and two straps
        pair((x) {
          c.drawRRect(
              RRect.fromLTRBR(x - 2, 252, x + 32, 263, const Radius.circular(6)),
              _fill(const Color(0xFFC9A96B)));
          c.drawPath(
              _p((p) => p
                ..moveTo(x + 4, 252)
                ..lineTo(x + 15, 238)
                ..lineTo(x + 26, 252)),
              _line(const Color(0xFF8A5A36), 5));
          c.drawCircle(Offset(x + 15, 240), 4.4, _fill(const Color(0xFF7FC25C)));
        });
        break;
      case 4: // royal shoes: deep blue with a gold rosette
        pair((x) {
          c.drawRRect(
              RRect.fromLTRBR(x, 244, x + 30, 260, const Radius.circular(9)),
              _fill(const Color(0xFF3E4AB8)));
          c.drawRRect(
              RRect.fromLTRBR(x - 2, 256, x + 32, 265, const Radius.circular(5)),
              _fill(const Color(0xFF2F3A96)));
          c.drawCircle(Offset(x + 10, 249), 5.5, _fill(_gold));
        });
        break;
      default: // trainers: white with a coloured sole and a stripe
        pair((x) {
          c.drawRRect(
              RRect.fromLTRBR(x, 244, x + 30, 258, const Radius.circular(8)),
              _fill(const Color(0xFFFFFFFF)));
          c.drawRRect(
              RRect.fromLTRBR(x - 2, 254, x + 32, 264, const Radius.circular(5)),
              _fill(Color.lerp(cloth, _ink, 0.08)!));
          c.drawLine(Offset(x + 6, 248), Offset(x + 18, 254),
              _line(_blush, 3.2));
        });
    }
  }

  // ----------------------------------------------------------- outfit
  void _outfit(Canvas c, Color cloth, Color clothDark) {
    // A cape goes behind everything else on the body.
    if (a.outfit == 5) {
      c.drawPath(
          _p((p) => p
            ..moveTo(72, 140)
            ..lineTo(128, 140)
            ..lineTo(154, 240)
            ..cubicTo(124, 252, 76, 252, 46, 240)
            ..close()),
          _fill(const Color(0xFFF4694F)));
    }

    switch (a.outfit) {
      case 2: // dress: the A-line from the sheet
        c.drawPath(
            _p((p) => p
              ..moveTo(74, 142)
              ..lineTo(126, 142)
              ..cubicTo(133, 142, 137, 147, 139, 156)
              ..lineTo(152, 214)
              ..cubicTo(153, 220, 149, 224, 143, 224)
              ..lineTo(57, 224)
              ..cubicTo(51, 224, 47, 220, 48, 214)
              ..lineTo(61, 156)
              ..cubicTo(63, 147, 67, 142, 74, 142)
              ..close()),
            _fill(cloth));
        // hem shadow, so the skirt reads as a skirt
        c.drawPath(
            _p((p) => p
              ..moveTo(50, 205)
              ..cubicTo(82, 216, 118, 216, 150, 205)
              ..lineTo(152, 214)
              ..cubicTo(153, 220, 149, 224, 143, 224)
              ..lineTo(57, 224)
              ..cubicTo(51, 224, 47, 220, 48, 214)
              ..close()),
            _fill(clothDark));
        break;
      default: // top + hem, shared by tee / hoodie / dungarees / suit / cape
        c.drawPath(
            _p((p) => p
              ..moveTo(76, 140)
              ..lineTo(124, 140)
              ..cubicTo(130, 140, 134, 145, 135, 152)
              ..lineTo(139, 204)
              ..cubicTo(140, 211, 136, 215, 130, 215)
              ..lineTo(70, 215)
              ..cubicTo(64, 215, 60, 211, 61, 204)
              ..lineTo(65, 152)
              ..cubicTo(66, 145, 70, 140, 76, 140)
              ..close()),
            _fill(cloth));
        c.drawRect(const Rect.fromLTWH(61, 204, 78, 11), _fill(clothDark));
    }

    // collar notch: the small V that makes a top look worn, not painted on
    if (a.outfit != 1 && a.outfit != 4) {
      c.drawPath(
          _p((p) => p
            ..moveTo(88, 141)
            ..quadraticBezierTo(100, 153, 112, 141)),
          _line(clothDark, 4));
    }

    switch (a.outfit) {
      case 1: // hoodie: hood behind the neck, drawstrings, pocket
        c.drawPath(
            _p((p) => p
              ..moveTo(82, 138)
              ..quadraticBezierTo(100, 162, 118, 138)
              ..cubicTo(112, 130, 88, 130, 82, 138)
              ..close()),
            _fill(clothDark));
        c.drawLine(const Offset(100, 158), const Offset(100, 180),
            _line(const Color(0x99FFFFFF), 3));
        c.drawRRect(
            RRect.fromLTRBR(82, 176, 118, 198, const Radius.circular(6)),
            _fill(const Color(0x22000000)));
        break;
      case 3: // dungarees: straps and a front pocket
        c.drawLine(const Offset(84, 142), const Offset(84, 170),
            _line(cloth, 9));
        c.drawLine(const Offset(116, 142), const Offset(116, 170),
            _line(cloth, 9));
        c.drawRRect(
            RRect.fromLTRBR(84, 162, 116, 186, const Radius.circular(5)),
            _fill(clothDark));
        c.drawCircle(const Offset(84, 160), 4, _fill(_gold));
        c.drawCircle(const Offset(116, 160), 4, _fill(_gold));
        break;
      case 4: // space suit: chest panel and a belt
        c.drawRRect(
            RRect.fromLTRBR(84, 160, 116, 184, const Radius.circular(6)),
            _fill(const Color(0x66FFFFFF)));
        c.drawCircle(const Offset(92, 172), 3.4, _fill(_blush));
        c.drawCircle(const Offset(108, 172), 3.4, _fill(const Color(0xFF7FC25C)));
        break;
      case 5: // cape top: a star badge
        _star(c, const Offset(100, 172), 16, _gold);
        break;
      case 6: // shirt and shorts
        c.drawPath(
            _p((p) => p
              ..moveTo(66, 200)
              ..lineTo(134, 200)
              ..lineTo(136, 226)
              ..cubicTo(124, 231, 114, 231, 106, 226)
              ..lineTo(100, 214)
              ..lineTo(94, 226)
              ..cubicTo(86, 231, 76, 231, 64, 226)
              ..close()),
            _fill(const Color(0xFF4E7CB8)));
        break;
      case 7: // prince tunic: sash and belt
        c.drawPath(
            _p((p) => p
              ..moveTo(78, 142)
              ..lineTo(96, 142)
              ..lineTo(128, 215)
              ..lineTo(108, 215)
              ..close()),
            _fill(_gold));
        c.drawRRect(
            RRect.fromLTRBR(61, 196, 139, 210, const Radius.circular(4)),
            _fill(_gold));
        c.drawRRect(
            RRect.fromLTRBR(92, 194, 108, 212, const Radius.circular(4)),
            _fill(_goldDeep));
        break;
      case 8: // armour: a plate over the top, with bands
        c.drawPath(
            _p((p) => p
              ..moveTo(74, 140)
              ..lineTo(126, 140)
              ..cubicTo(133, 140, 137, 147, 137, 155)
              ..lineTo(137, 192)
              ..cubicTo(137, 208, 120, 218, 100, 218)
              ..cubicTo(80, 218, 63, 208, 63, 192)
              ..lineTo(63, 155)
              ..cubicTo(63, 147, 67, 140, 74, 140)
              ..close()),
            _fill(const Color(0xFFC3D1DE)));
        c.drawRRect(
            RRect.fromLTRBR(63, 140, 137, 158, const Radius.circular(6)),
            _fill(const Color(0xFF9FB0C4)));
        c.drawLine(const Offset(67, 176), const Offset(133, 176),
            _line(const Color(0xFF9FB0C4), 3.4));
        c.drawLine(const Offset(70, 194), const Offset(130, 194),
            _line(const Color(0xFF9FB0C4), 3.4));
        _star(c, const Offset(100, 166), 13, _gold);
        break;
      case 9: // hero suit: emblem and belt
        _star(c, const Offset(100, 172), 17, _gold);
        c.drawRRect(
            RRect.fromLTRBR(61, 198, 139, 210, const Radius.circular(4)),
            _fill(_gold));
        break;
      case 10: // explorer vest: open front and two pockets
        c.drawLine(const Offset(84, 142), const Offset(84, 212),
            _line(Color.lerp(cloth, const Color(0xFF7FC25C), 0.8)!, 11));
        c.drawLine(const Offset(116, 142), const Offset(116, 212),
            _line(Color.lerp(cloth, const Color(0xFF7FC25C), 0.8)!, 11));
        c.drawRRect(
            RRect.fromLTRBR(68, 174, 88, 194, const Radius.circular(4)),
            _fill(clothDark));
        c.drawRRect(
            RRect.fromLTRBR(112, 174, 132, 194, const Radius.circular(4)),
            _fill(clothDark));
        break;
    }
  }

  void _star(Canvas c, Offset o, double r, Color col) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.44;
      final ang = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(o.dx + math.cos(ang) * rad, o.dy + math.sin(ang) * rad);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    c.drawPath(p, _fill(col));
  }

  // ------------------------------------------------------------- arms
  void _arms(Canvas c, Color skin, Color cloth) {
    final sleeved = a.outfit == 1 || a.outfit == 4;
    final armColor = sleeved ? cloth : skin;
    for (final d in [-1.0, 1.0]) {
      final pivot = Offset(100 + d * 47, 150);
      c.save();
      c.translate(pivot.dx, pivot.dy);
      c.rotate(d * 0.16);
      c.translate(-pivot.dx, -pivot.dy);
      c.drawRRect(
          RRect.fromLTRBR(pivot.dx - 6.5, 150, pivot.dx + 6.5, 198,
              const Radius.circular(6.5)),
          _fill(armColor));
      if (sleeved) c.drawCircle(Offset(pivot.dx, 199), 8, _fill(skin));
      c.restore();
    }
  }

  // ------------------------------------------------------------- head
  void _head(Canvas c, Color skin) {
    c.drawOval(
        Rect.fromCenter(center: const Offset(46, 98), width: 14, height: 18),
        _fill(skin));
    c.drawOval(
        Rect.fromCenter(center: const Offset(154, 98), width: 14, height: 18),
        _fill(skin));
    c.drawPath(
        _p((p) => p
          ..moveTo(100, 38)
          ..cubicTo(129, 38, 153, 60, 153, 92)
          ..cubicTo(153, 124, 130, 144, 100, 144)
          ..cubicTo(70, 144, 47, 124, 47, 92)
          ..cubicTo(47, 60, 71, 38, 100, 38)
          ..close()),
        _fill(skin));
  }

  // ------------------------------------------------------------- face
  void _face(Canvas c, Color skin) {
    const browCol = Color(0xFFC98BA4);
    // Sad and scared angle their own brows -- that angle is most of what
    // says "sad" or "scared" -- so they skip the shared pair rather than
    // ending up with two sets.
    final ownBrows = a.face == 4 || a.face == 5;
    // brows: lifted for the big smile, level otherwise
    final browY = a.face == 1 ? 73.0 : 82.0;
    final browLift = a.face == 1 ? 67.0 : 77.0;
    if (!ownBrows) {
      c.drawPath(
          _p((p) => p
            ..moveTo(72, browY)
            ..quadraticBezierTo(82, browLift, 92, browY)),
          _line(browCol, 3.4));
      c.drawPath(
          _p((p) => p
            ..moveTo(128, browY)
            ..quadraticBezierTo(118, browLift, 108, browY)),
          _line(browCol, 3.4));
    }

    switch (a.face) {
      case 1: // big smile: eyes squeezed shut upward, open grin
        c.drawPath(
            _p((p) => p
              ..moveTo(71, 102)
              ..quadraticBezierTo(81, 90, 91, 102)),
            _line(_ink, 4));
        c.drawPath(
            _p((p) => p
              ..moveTo(109, 102)
              ..quadraticBezierTo(119, 90, 129, 102)),
            _line(_ink, 4));
        c.drawPath(
            _p((p) => p
              ..moveTo(84, 117)
              ..quadraticBezierTo(100, 136, 116, 117)
              ..close()),
            _fill(_ink));
        c.drawPath(
            _p((p) => p
              ..moveTo(89, 126)
              ..quadraticBezierTo(100, 134, 111, 126)
              ..close()),
            _fill(_blush));
        _cheeks(c, 0.42, 10, 6);
        break;
      case 2: // calm: lids curving down, soft smile
        c.drawPath(
            _p((p) => p
              ..moveTo(71, 99)
              ..quadraticBezierTo(81, 107, 91, 99)),
            _line(_ink, 3.6));
        c.drawPath(
            _p((p) => p
              ..moveTo(109, 99)
              ..quadraticBezierTo(119, 107, 129, 99)),
            _line(_ink, 3.6));
        c.drawPath(
            _p((p) => p
              ..moveTo(93, 120)
              ..quadraticBezierTo(100, 126, 107, 120)),
            _line(_ink, 3.2));
        _cheeks(c, 0.26, 9, 5.5);
        break;
      case 3: // surprised: wide round eyes, small open mouth
        c.drawOval(
            Rect.fromCenter(center: const Offset(81, 99), width: 20, height: 23),
            _fill(_white));
        c.drawOval(
            Rect.fromCenter(center: const Offset(119, 99), width: 20, height: 23),
            _fill(_white));
        c.drawCircle(const Offset(81, 100), 6.6, _fill(_ink));
        c.drawCircle(const Offset(119, 100), 6.6, _fill(_ink));
        c.drawCircle(const Offset(78.6, 97), 2.5, _fill(_white));
        c.drawCircle(const Offset(116.6, 97), 2.5, _fill(_white));
        c.drawOval(
            Rect.fromCenter(center: const Offset(100, 122), width: 14, height: 17),
            _fill(_ink));
        _cheeks(c, 0.3, 8, 5);
        break;
      case 4: // sad: inner brows up, heavy lids, a tear, mouth turned down
        c.drawPath(
            _p((p) => p
              ..moveTo(70, 80)
              ..quadraticBezierTo(81, 70, 92, 78)),
            _line(browCol, 3.6));
        c.drawPath(
            _p((p) => p
              ..moveTo(130, 80)
              ..quadraticBezierTo(119, 70, 108, 78)),
            _line(browCol, 3.6));
        c.drawOval(
            Rect.fromCenter(center: const Offset(81, 100), width: 16, height: 18),
            _fill(_ink));
        c.drawOval(
            Rect.fromCenter(center: const Offset(119, 100), width: 16, height: 18),
            _fill(_ink));
        c.drawCircle(const Offset(78.5, 97), 2.8, _fill(_white));
        c.drawCircle(const Offset(116.5, 97), 2.8, _fill(_white));
        // The lid is painted in skin, which is what makes the eye look
        // half closed without having to clip anything.
        c.drawPath(
            _p((p) => p
              ..moveTo(72, 94)
              ..quadraticBezierTo(81, 88, 90, 94)),
            _line(skin, 7));
        c.drawPath(
            _p((p) => p
              ..moveTo(110, 94)
              ..quadraticBezierTo(119, 88, 128, 94)),
            _line(skin, 7));
        c.drawPath(
            _p((p) => p
              ..moveTo(126, 110)
              ..cubicTo(126, 110, 132, 120, 132, 124)
              ..cubicTo(132, 129, 120, 129, 120, 124)
              ..cubicTo(120, 120, 126, 110, 126, 110)
              ..close()),
            _fill(const Color(0xFF8FB8E0)));
        c.drawPath(
            _p((p) => p
              ..moveTo(90, 126)
              ..quadraticBezierTo(100, 117, 110, 126)),
            _line(_ink, 3.4));
        _cheeks(c, 0.2, 8, 5);
        break;
      case 5: // scared: brows up, wide round eyes, small open mouth
        c.drawPath(
            _p((p) => p
              ..moveTo(70, 74)
              ..quadraticBezierTo(80, 66, 92, 72)),
            _line(browCol, 3.6));
        c.drawPath(
            _p((p) => p
              ..moveTo(130, 74)
              ..quadraticBezierTo(120, 66, 108, 72)),
            _line(browCol, 3.6));
        c.drawOval(
            Rect.fromCenter(center: const Offset(81, 99), width: 20, height: 23),
            _fill(_white));
        c.drawOval(
            Rect.fromCenter(center: const Offset(119, 99), width: 20, height: 23),
            _fill(_white));
        c.drawCircle(const Offset(81, 100), 6.6, _fill(_ink));
        c.drawCircle(const Offset(119, 100), 6.6, _fill(_ink));
        c.drawCircle(const Offset(78.6, 97), 2.5, _fill(_white));
        c.drawCircle(const Offset(116.6, 97), 2.5, _fill(_white));
        c.drawOval(
            Rect.fromCenter(center: const Offset(100, 122), width: 14, height: 17),
            _fill(_ink));
        c.drawOval(
            Rect.fromCenter(center: const Offset(100, 125), width: 8, height: 9),
            _fill(const Color(0xFFD96FA0)));
        // Cool cheeks rather than warm ones: the blood leaves the face.
        c.drawOval(
            Rect.fromCenter(center: const Offset(62, 112), width: 16, height: 10),
            _fill(const Color(0xFF8FB8E0).withValues(alpha: 0.4)));
        c.drawOval(
            Rect.fromCenter(center: const Offset(138, 112), width: 16, height: 10),
            _fill(const Color(0xFF8FB8E0).withValues(alpha: 0.4)));
        break;
      case 6: // okay: settled. Open eyes, a level mouth, nothing claimed.
        c.drawOval(
            Rect.fromCenter(center: const Offset(81, 98), width: 16, height: 19),
            _fill(_ink));
        c.drawOval(
            Rect.fromCenter(center: const Offset(119, 98), width: 16, height: 19),
            _fill(_ink));
        c.drawCircle(const Offset(78.4, 94.6), 3, _fill(_white));
        c.drawCircle(const Offset(116.4, 94.6), 3, _fill(_white));
        c.drawCircle(const Offset(83.6, 101.6), 1.6,
            _fill(_white.withValues(alpha: 0.85)));
        c.drawCircle(const Offset(121.6, 101.6), 1.6,
            _fill(_white.withValues(alpha: 0.85)));
        c.drawLine(const Offset(91, 121), const Offset(109, 121),
            _line(_ink, 3.4));
        _cheeks(c, 0.26, 8.5, 5);
        break;
      default: // smile: open eyes with highlights
        c.drawOval(
            Rect.fromCenter(center: const Offset(82, 98), width: 15, height: 18),
            _fill(_ink));
        c.drawOval(
            Rect.fromCenter(center: const Offset(118, 98), width: 15, height: 18),
            _fill(_ink));
        c.drawCircle(const Offset(79.5, 94.5), 2.9, _fill(_white));
        c.drawCircle(const Offset(115.5, 94.5), 2.9, _fill(_white));
        c.drawCircle(const Offset(84.5, 101.5), 1.5,
            _fill(_white.withValues(alpha: 0.85)));
        c.drawCircle(const Offset(120.5, 101.5), 1.5,
            _fill(_white.withValues(alpha: 0.85)));
        c.drawPath(
            _p((p) => p
              ..moveTo(92, 116)
              ..quadraticBezierTo(100, 124, 108, 116)),
            _line(_ink, 3));
        _cheeks(c, 0.3, 9, 5.5);
    }
  }

  void _cheeks(Canvas c, double alpha, double rx, double ry) {
    // Stronger when the child picked rosy cheeks.
    final a2 = a.extra == 3 ? math.min(alpha + 0.26, 0.6) : alpha;
    final paint = _fill(_blush.withValues(alpha: a2));
    c.drawOval(
        Rect.fromCenter(center: Offset(100 - 38, 112), width: rx * 2, height: ry * 2),
        paint);
    c.drawOval(
        Rect.fromCenter(center: Offset(100 + 38, 112), width: rx * 2, height: ry * 2),
        paint);
  }

  // --------------------------------------------------------- headwear
  void _headwear(Canvas c) {
    switch (a.headwear) {
      case 1: // crown
        c.drawPath(
            _p((p) => p
              ..moveTo(66, 48)
              ..lineTo(66, 26)
              ..lineTo(80, 38)
              ..lineTo(93, 20)
              ..lineTo(107, 20)
              ..lineTo(120, 38)
              ..lineTo(134, 26)
              ..lineTo(134, 48)
              ..close()),
            _fill(_gold));
        c.drawRRect(
            RRect.fromLTRBR(64, 46, 136, 57, const Radius.circular(5)),
            _fill(_goldDeep));
        c.drawCircle(const Offset(66, 24), 5, _fill(_blush));
        c.drawCircle(const Offset(134, 24), 5, _fill(_blush));
        c.drawCircle(const Offset(100, 18), 5.5, _fill(const Color(0xFFCDE8F7)));
        break;
      case 2: // party hat
        c.drawPath(
            _p((p) => p
              ..moveTo(100, 8)
              ..lineTo(126, 64)
              ..lineTo(74, 64)
              ..close()),
            _fill(const Color(0xFFB8A4F5)));
        c.drawLine(const Offset(84, 44), const Offset(116, 44),
            _line(_gold, 5));
        c.drawLine(const Offset(78, 58), const Offset(122, 58),
            _line(const Color(0xFF7FC25C), 5));
        c.drawCircle(const Offset(100, 8), 8, _fill(_blush));
        break;
      case 3: // cap
        c.drawPath(
            _p((p) => p
              ..moveTo(50, 60)
              ..cubicTo(50, 32, 72, 18, 100, 18)
              ..cubicTo(128, 18, 150, 32, 150, 60)
              ..close()),
            _fill(const Color(0xFF4E7CB8)));
        c.drawPath(
            _p((p) => p
              ..moveTo(48, 56)
              ..lineTo(160, 56)
              ..cubicTo(166, 56, 166, 66, 158, 70)
              ..cubicTo(140, 78, 60, 78, 48, 70)
              ..close()),
            _fill(const Color(0xFF3A5F92)));
        c.drawCircle(const Offset(100, 20), 7, _fill(_gold));
        break;
      case 4: // flower band
        c.drawPath(
            _p((p) => p
              ..moveTo(52, 70)
              ..quadraticBezierTo(100, 36, 148, 70)),
            _line(const Color(0xFF7FC25C), 7));
        const spots = [
          Offset(64, 62),
          Offset(84, 48),
          Offset(106, 46),
          Offset(128, 54),
          Offset(142, 68),
        ];
        for (var i = 0; i < spots.length; i++) {
          final r = i.isEven ? 8.5 : 9.5;
          c.drawCircle(spots[i], r,
              _fill(i.isEven ? const Color(0xFFFFF2D6) : _white));
          c.drawCircle(spots[i], r * 0.42,
              _fill(i.isEven ? _gold : const Color(0xFFFFB44D)));
        }
        break;
      case 5: // wizard hat (was a unicorn horn: the unicorn is gone)
        c.drawPath(
            _p((p) => p
              ..moveTo(100, 2)
              ..cubicTo(118, 24, 130, 48, 138, 68)
              ..cubicTo(120, 76, 80, 76, 62, 68)
              ..cubicTo(70, 48, 82, 24, 100, 2)
              ..close()),
            _fill(const Color(0xFF4E7CB8)));
        c.drawPath(
            _p((p) => p
              ..moveTo(56, 66)
              ..cubicTo(78, 78, 122, 78, 144, 66)
              ..cubicTo(150, 64, 152, 72, 148, 76)
              ..cubicTo(126, 88, 74, 88, 52, 76)
              ..cubicTo(48, 72, 50, 64, 56, 66)
              ..close()),
            _fill(const Color(0xFF3A5F92)));
        _star(c, const Offset(100, 36), 11, _gold);
        break;
      case 6: // tiara
        c.drawPath(
            _p((p) => p
              ..moveTo(70, 52)
              ..lineTo(82, 30)
              ..lineTo(92, 44)
              ..lineTo(100, 18)
              ..lineTo(108, 44)
              ..lineTo(118, 30)
              ..lineTo(130, 52)
              ..close()),
            _fill(_gold));
        c.drawRRect(
            RRect.fromLTRBR(68, 49, 132, 58, const Radius.circular(4.5)),
            _fill(_goldDeep));
        c.drawCircle(const Offset(100, 26), 5, _fill(const Color(0xFFEE86B7)));
        c.drawCircle(const Offset(82, 38), 3.6, _fill(const Color(0xFFCDE8F7)));
        c.drawCircle(const Offset(118, 38), 3.6, _fill(const Color(0xFFCDE8F7)));
        break;
      case 7: // bow, worn to one side
        c.drawPath(
            _p((p) => p
              ..moveTo(128, 48)
              ..cubicTo(112, 32, 98, 30, 98, 44)
              ..cubicTo(98, 56, 112, 58, 126, 54)
              ..close()),
            _fill(const Color(0xFFEE86B7)));
        c.drawPath(
            _p((p) => p
              ..moveTo(134, 50)
              ..cubicTo(150, 34, 164, 34, 164, 48)
              ..cubicTo(164, 60, 150, 60, 136, 56)
              ..close()),
            _fill(const Color(0xFFEE86B7)));
        c.drawOval(
            Rect.fromCenter(
                center: const Offset(131, 51), width: 16, height: 18),
            _fill(const Color(0xFFD96FA0)));
        break;
      case 8: // knight helmet, with a plume and a visor slot
        c.drawPath(
            _p((p) => p
              ..moveTo(100, 6)
              ..cubicTo(118, -4, 134, 2, 132, 18)
              ..cubicTo(130, 32, 114, 34, 106, 28)
              ..close()),
            _fill(_blush));
        c.drawPath(
            _p((p) => p
              ..moveTo(46, 92)
              ..cubicTo(46, 58, 70, 36, 100, 36)
              ..cubicTo(130, 36, 154, 58, 154, 92)
              ..lineTo(154, 100)
              ..lineTo(46, 100)
              ..close()),
            _fill(const Color(0xFFC3D1DE)));
        c.drawRRect(
            RRect.fromLTRBR(46, 96, 154, 116, const Radius.circular(5)),
            _fill(const Color(0xFF9FB0C4)));
        c.drawLine(const Offset(100, 38), const Offset(100, 96),
            _line(const Color(0xFFE6EDF3), 7));
        for (final x in const [64.0, 92.0, 120.0]) {
          c.drawRRect(
              RRect.fromLTRBR(x, 102, x + 16, 110, const Radius.circular(4)),
              _fill(const Color(0xFF6E7F93)));
        }
        break;
      case 9: // baseball cap
        c.drawPath(
            _p((p) => p
              ..moveTo(50, 62)
              ..cubicTo(50, 34, 72, 20, 100, 20)
              ..cubicTo(128, 20, 150, 34, 150, 62)
              ..close()),
            _fill(const Color(0xFF4E7CB8)));
        c.drawPath(
            _p((p) => p
              ..moveTo(50, 50)
              ..cubicTo(70, 42, 130, 42, 150, 50)
              ..lineTo(150, 62)
              ..lineTo(50, 62)
              ..close()),
            _fill(const Color(0xFF3A5F92)));
        c.drawPath(
            _p((p) => p
              ..moveTo(148, 58)
              ..lineTo(180, 58)
              ..cubicTo(188, 58, 188, 72, 180, 76)
              ..cubicTo(168, 82, 152, 82, 148, 80)
              ..close()),
            _fill(const Color(0xFF3A5F92)));
        c.drawCircle(const Offset(100, 22), 7, _fill(_gold));
        break;
      case 10: // beanie
        c.drawPath(
            _p((p) => p
              ..moveTo(50, 66)
              ..cubicTo(50, 34, 72, 22, 100, 22)
              ..cubicTo(128, 22, 150, 34, 150, 66)
              ..close()),
            _fill(const Color(0xFF7FC25C)));
        c.drawRRect(
            RRect.fromLTRBR(44, 60, 156, 80, const Radius.circular(10)),
            _fill(const Color(0xFF5FA543)));
        c.drawCircle(const Offset(100, 18), 10, _fill(const Color(0xFFFFF2D6)));
        break;
      case 11: // pirate hat
        c.drawPath(
            _p((p) => p
              ..moveTo(26, 74)
              ..cubicTo(26, 44, 58, 24, 100, 24)
              ..cubicTo(142, 24, 174, 44, 174, 74)
              ..cubicTo(142, 84, 58, 84, 26, 74)
              ..close()),
            _fill(const Color(0xFF2A2233)));
        c.drawPath(
            _p((p) => p
              ..moveTo(26, 74)
              ..cubicTo(58, 84, 142, 84, 174, 74)
              ..cubicTo(174, 82, 158, 92, 100, 92)
              ..cubicTo(42, 92, 26, 82, 26, 74)
              ..close()),
            _fill(const Color(0xFF3B3346)));
        c.drawCircle(const Offset(100, 52), 9, _fill(const Color(0xFFFFF2D6)));
        c.drawCircle(const Offset(96, 50), 2.4, _fill(_ink));
        c.drawCircle(const Offset(104, 50), 2.4, _fill(_ink));
        c.drawLine(const Offset(88, 66), const Offset(112, 66),
            _line(const Color(0xFFFFF2D6), 4.5));
        break;
      case 12: // explorer hat
        c.drawOval(
            Rect.fromCenter(
                center: const Offset(100, 76), width: 128, height: 30),
            _fill(const Color(0xFFC9A96B)));
        c.drawPath(
            _p((p) => p
              ..moveTo(66, 74)
              ..cubicTo(66, 40, 80, 26, 100, 26)
              ..cubicTo(120, 26, 134, 40, 134, 74)
              ..close()),
            _fill(const Color(0xFFA98849)));
        c.drawRRect(
            RRect.fromLTRBR(64, 62, 136, 76, const Radius.circular(6)),
            _fill(const Color(0xFF5C3A22)));
        c.drawCircle(const Offset(124, 69), 5, _fill(_gold));
        break;
    }
  }

  // ----------------------------------------------------------- extras
  void _extras(Canvas c, Color skin) {
    switch (a.extra) {
      case 1: // glasses
        final g = _line(const Color(0xFF3B3346), 3.2);
        c.drawCircle(const Offset(82, 98), 15, g);
        c.drawCircle(const Offset(118, 98), 15, g);
        c.drawLine(const Offset(97, 98), const Offset(103, 98), g);
        c.drawLine(const Offset(67, 96), const Offset(52, 94), g);
        c.drawLine(const Offset(133, 96), const Offset(148, 94), g);
        break;
      case 2: // freckles
        final f = _fill(Color.lerp(skin, _ink, 0.3)!.withValues(alpha: 0.5));
        for (final o in const [
          Offset(66, 110),
          Offset(73, 114),
          Offset(60, 116),
          Offset(134, 110),
          Offset(127, 114),
          Offset(140, 116),
        ]) {
          c.drawCircle(o, 2, f);
        }
        break;
      case 4: // scarf
        c.drawRRect(
            RRect.fromLTRBR(74, 136, 126, 152, const Radius.circular(8)),
            _fill(_blush));
        c.drawRRect(
            RRect.fromLTRBR(110, 148, 124, 184, const Radius.circular(7)),
            _fill(_blush));
        c.drawRRect(
            RRect.fromLTRBR(110, 178, 124, 186, const Radius.circular(4)),
            _fill(Color.lerp(_blush, _ink, 0.2)!));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) =>
      old.a != a || old.bob != bob;
}

/// Drop-in avatar widget. Use this everywhere a character should appear.
///
/// The box is [size] wide and `size * AvatarPainter.aspect` tall. Giving
/// it any other ratio letterboxes the figure, which is what made the
/// character look small inside its own card before v41.
class AvatarView extends StatelessWidget {
  final MindyAvatar avatar;
  final double size;
  final bool animate;

  const AvatarView(this.avatar,
      {super.key, this.size = 96, this.animate = false});

  @override
  Widget build(BuildContext context) {
    final picture = CustomPaint(
      size: Size(size, size * AvatarPainter.aspect),
      painter: AvatarPainter(avatar),
      isComplex: true,
      willChange: false,
    );
    if (!animate) return picture;
    return _Bobbing(avatar: avatar, size: size);
  }
}

class _Bobbing extends StatefulWidget {
  final MindyAvatar avatar;
  final double size;
  const _Bobbing({required this.avatar, required this.size});

  @override
  State<_Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<_Bobbing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, widget.size * AvatarPainter.aspect),
          painter: AvatarPainter(widget.avatar, bob: _c.value),
          isComplex: true,
        ),
      );
}
