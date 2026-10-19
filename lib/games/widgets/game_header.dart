import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'game_progress.dart';

/// TOP of every game: back button, title and a small progress bar.
class GameHeader extends StatelessWidget {
  final String title;
  final String emoji;
  final ValueListenable<double> progress;
  final VoidCallback onBack;
  final List<Widget> actions;

  const GameHeader({
    super.key,
    required this.title,
    required this.emoji,
    required this.progress,
    required this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_rounded,
                    color: AppColors.inkNavy, size: 26),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$emoji  $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subheading.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                GameProgressBar(progress: progress),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
