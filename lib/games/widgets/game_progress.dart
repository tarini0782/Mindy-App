import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/foundation.dart';

/// Small rounded progress bar with a star at the end. Non-readers can
/// follow it at a glance; it only ever goes up.
class GameProgressBar extends StatelessWidget {
  final ValueListenable<double> progress;
  const GameProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, value, _) {
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Container(
                  height: 12,
                  color: Colors.white.withValues(alpha: 0.65),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value.clamp(0.02, 1.0).toDouble(),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.meadowGreen, AppColors.skyBlue],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.star_rounded,
              size: 24,
              color: value >= 1.0
                  ? AppColors.sunshineYellow
                  : Colors.white.withValues(alpha: 0.85),
            ),
          ],
        );
      },
    );
  }
}
