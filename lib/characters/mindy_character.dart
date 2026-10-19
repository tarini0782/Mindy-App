import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'character_assets.dart';
import 'character_id.dart';
import '../art/sprites.dart';
import 'companion.dart';

/// One Mindy character with simple animation states:
/// idle, happy, excited, calm, encouraging, celebrating.
///
/// Uses optional replacement art from assets/characters/<id>/<state>.png
/// when present; otherwise draws the built-in vector character. Game logic
/// never touches character graphics -- it only says which character and
/// which state.
class MindyCharacter extends StatefulWidget {
  final CharacterId id;
  final CharacterState state;
  final double size;

  /// false = a still picture (used for small map badges).
  final bool animated;

  const MindyCharacter({
    super.key,
    required this.id,
    this.state = CharacterState.idle,
    this.size = 96,
    this.animated = true,
  });

  @override
  State<MindyCharacter> createState() => _MindyCharacterState();
}

class _MindyCharacterState extends State<MindyCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    if (widget.animated) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant MindyCharacter old) {
    super.didUpdateWidget(old);
    if (widget.animated && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animated && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // dy (fraction of size, upwards) and tilt (radians) for each state.
  (double, double) _motion(double t) {
    switch (widget.state) {
      case CharacterState.idle:
        return (sin(t * 2 * pi) * 0.03, 0.0);
      case CharacterState.calm:
        return (sin(t * 2 * pi) * 0.02, 0.0);
      case CharacterState.happy:
        return ((sin(t * 4 * pi)).abs() * 0.06, 0.0);
      case CharacterState.excited:
        return ((sin(t * 8 * pi)).abs() * 0.18, sin(t * 8 * pi) * 0.04);
      case CharacterState.encouraging:
        return (sin(t * 2 * pi) * 0.025, sin(t * 4 * pi) * 0.07);
      case CharacterState.celebrating:
        return ((sin(t * 6 * pi)).abs() * 0.14, sin(t * 6 * pi) * 0.14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final imagePath =
        CharacterAssets.characterImage(widget.id, widget.state);

    return SizedBox(
      width: size,
      height: size * 1.1,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, CompanionService.instance]),
        builder: (context, _) {
          final t = widget.animated ? _c.value : 0.0;
          final m = widget.animated ? _motion(t) : (0.0, 0.0);
          final Widget art = imagePath != null
              ? Image.asset(imagePath,
                  width: size, height: size * 1.1, fit: BoxFit.contain)
              : Sprite('host_${widget.id.name}',
                  width: size, height: size * 1.1);
          return Transform.translate(
            offset: Offset(0, -m.$1 * size),
            child: Transform.rotate(angle: m.$2, child: art),
          );
        },
      ),
    );
  }
}

/// Friendly speech bubble used by every character.
class MindySpeechBubble extends StatelessWidget {
  final String text;
  final Color color;
  final double maxWidth;
  final double fontSize;

  const MindySpeechBubble({
    super.key,
    required this.text,
    this.color = Colors.white,
    this.maxWidth = 280,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.soft,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.subheading.copyWith(fontSize: fontSize),
      ),
    );
  }
}

/// A character standing next to what they are saying.
class CharacterSays extends StatelessWidget {
  final CharacterId id;
  final CharacterState state;
  final String text;
  final double avatarSize;

  const CharacterSays({
    super.key,
    required this.id,
    required this.text,
    this.state = CharacterState.happy,
    this.avatarSize = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MindyCharacter(id: id, state: state, size: avatarSize),
        const SizedBox(width: 8),
        Flexible(child: MindySpeechBubble(text: text)),
      ],
    );
  }
}
