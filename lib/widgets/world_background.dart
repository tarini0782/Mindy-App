import 'package:flutter/material.dart';
import '../characters/character_assets.dart';
import 'sky_background.dart';

/// Sky gradient for a world, with optional replacement art from
/// assets/worlds/<worldKey>/background.png drawn on top if it exists.
class WorldBackground extends StatelessWidget {
  final String worldKey;
  final List<Color> colors;
  final bool showStars;
  final Widget child;

  const WorldBackground({
    super.key,
    required this.worldKey,
    required this.colors,
    required this.child,
    this.showStars = false,
  });

  @override
  Widget build(BuildContext context) {
    final art = CharacterAssets.worldBackground(worldKey);
    return SkyBackground(
      colors: colors,
      showStars: showStars,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (art != null) Image.asset(art, fit: BoxFit.cover),
          child,
        ],
      ),
    );
  }
}
