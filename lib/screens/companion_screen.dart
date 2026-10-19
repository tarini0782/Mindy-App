import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/companion.dart';
import '../characters/mindy_character.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sky_background.dart';

/// Optional: dress up Kara. Free, no purchases, nothing is locked and
/// nothing here affects games or research data.
class CompanionScreen extends StatelessWidget {
  const CompanionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        colors: AppColors.rainbowSky,
        showStars: false,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: CompanionService.instance,
            builder: (context, _) {
              final look = CompanionService.instance.look;
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(Icons.arrow_back_rounded,
                                color: AppColors.inkNavy),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Dress up Kara', style: AppText.heading),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: MindyCharacter(
                        id: CharacterId.kara,
                        state: CharacterState.happy,
                        size: 190),
                  ),
                  const SizedBox(height: 10),
                  Text('Colour', style: AppText.subheading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < CompanionLook.colors.length; i++)
                        _Swatch(
                          selected: look.colorIndex == i,
                          onTap: () => CompanionService.instance
                              .setLook(look.copyWith(colorIndex: i)),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: CompanionLook.colors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.black12, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Extras', style: AppText.subheading),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < CompanionLook.accessoryNames.length; i++)
                        _Swatch(
                          selected: look.accessoryIndex == i,
                          onTap: () => CompanionService.instance
                              .setLook(look.copyWith(accessoryIndex: i)),
                          child: SizedBox(
                            width: 64,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(CompanionLook.accessoryEmoji[i],
                                    style: const TextStyle(fontSize: 30)),
                                Text(CompanionLook.accessoryNames[i],
                                    style: AppText.body.copyWith(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('Kara\'s garden surprises', style: AppText.subheading),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: RewardService.instance,
                    builder: (context, _) {
                      final d = RewardService.instance.decorations;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: d.isEmpty
                            ? Text('Finish adventures to find surprises here!',
                                style: AppText.body)
                            : Wrap(
                                spacing: 10,
                                children: [
                                  for (final e in d)
                                    Text(e, style: const TextStyle(fontSize: 40)),
                                ],
                              ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _Swatch(
      {required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? AppColors.grapePurple : Colors.transparent,
            width: 3,
          ),
        ),
        child: child,
      ),
    );
  }
}
