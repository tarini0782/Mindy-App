import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'sprite_data.dart';

/// One piece of Mindy artwork (vector, so it is sharp at every size).
///
/// FACING RULE: every directional sprite is drawn facing RIGHT (the car faces
/// UP). Pass [faceRight] = false to mirror it so it looks the way it is
/// moving. Never use emoji for anything that has a front and a back, because
/// emoji face different ways on different phones.
class Sprite extends StatelessWidget {
  final String name;
  final double width;
  final double? height;
  final bool faceRight;
  final double angle; // tilt in radians
  final double opacity;

  const Sprite(
    this.name, {
    super.key,
    required this.width,
    this.height,
    this.faceRight = true,
    this.angle = 0,
    this.opacity = 1,
  });

  static bool has(String name) => kSpriteSvg.containsKey(name);

  /// Emoji used in older code -> sprite name (items that do not face a way).
  static const Map<String, String> fromEmoji = {
    '\u{1F955}': 'carrot',
    '\u{1F34E}': 'apple',
    '\u{1F34A}': 'orange',
    '\u{1F353}': 'strawberry',
    '\u{1F349}': 'watermelon',
    '\u{1F9E6}': 'sock',
    '\u{1FAA8}': 'rock',
    '⭐': 'star',
    '❄️': 'snowflake',
    '⛈️': 'storm',
    '\u{1F9F8}': 'teddy',
  };

  @override
  Widget build(BuildContext context) {
    final svg = kSpriteSvg[name];
    if (svg == null) {
      return SizedBox(width: width, height: height ?? width);
    }
    Widget w = SvgPicture.string(svg,
        width: width, height: height ?? width, fit: BoxFit.contain);
    if (!faceRight) {
      w = Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(-1, 1, 1),
          child: w);
    }
    if (angle != 0) w = Transform.rotate(angle: angle, child: w);
    if (opacity < 1) w = Opacity(opacity: opacity, child: w);
    return w;
  }
}
