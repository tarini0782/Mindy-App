import 'dart:async';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/friend_view.dart';
import '../characters/mindy_character.dart';
import '../games/base/game_factory.dart';
import '../games/models/game_recommendation.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/world_background.dart';
import '../games/models/game_type.dart';

/// The short, friendly moment between "how are you feeling?" and the game.
///
///   1. The CHILD'S OWN FRIEND answers the feeling
///      ("Hey... let's take a gentle moment together.")
///   2. The world's character invites the child
///      ("Come with me to the magical garden.")
///   3. The game opens.
///
/// Only child-friendly wording is shown here -- never the technical reason
/// string (that goes to the session log for the researchers). A tap moves
/// on faster.
class GameTransitionScreen extends StatefulWidget {
  final GameRecommendation recommendation;
  final GameLaunchInfo info;

  const GameTransitionScreen({
    super.key,
    required this.recommendation,
    required this.info,
  });

  @override
  State<GameTransitionScreen> createState() => _GameTransitionScreenState();
}

class _GameTransitionScreenState extends State<GameTransitionScreen> {
  Timer? _timer;
  int _step = 0; // 0 = Kara, 1 = host character
  bool _went = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2400), _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_went || !mounted) return;
    _timer?.cancel();
    if (_step == 0) {
      setState(() => _step = 1);
      _timer = Timer(const Duration(milliseconds: 2400), _next);
      return;
    }
    _went = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => launchGame(widget.recommendation, widget.info),
      ),
    );
  }

  Future<void> _why() async {
    _timer?.cancel();
    final r = widget.recommendation;
    final emotion = r.trace.emotion ?? 'skipped';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why this game? (for grown-ups)'),
        content: SingleChildScrollView(
          child: Text('Feeling reported: $emotion\n'
              'Game: ${r.gameType.title}, level ${r.level}, ${r.pace.name} pace\n'
              'Study condition: ${r.trace.condition}\n\n'
              '${r.reason}\n\n'
              'Mindy picks the game from the child\'s own feeling check-in and '
              'recent play. It does not diagnose anything.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
    if (mounted && !_went) {
      _timer = Timer(const Duration(milliseconds: 2400), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    final type = rec.gameType;
    final calm = type.category == GameCategory.calming;
    final isGreeting = _step == 0; // step 0 = the child's own friend
    final who = type.character;
    final text = isGreeting ? rec.childMessage : rec.hostMessage;
    final state = isGreeting
        ? (calm ? CharacterState.calm : CharacterState.happy)
        : (calm ? CharacterState.calm : CharacterState.excited);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: WorldBackground(
          worldKey: type.worldKey,
          colors: isGreeting
              ? (calm ? AppColors.skyMorning : AppColors.rainbowSky)
              : type.background,
          showStars: calm,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  child: Column(
                    key: ValueKey(_step),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step 0 is the greeting -- the child's own friend,
                      // because this is the app speaking to the child.
                      // Step 1 is the game's own invite ("Pip is going for a
                      // gentle walk"), which names its world character, so
                      // that character shows itself.
                      if (isGreeting)
                        const FriendView(size: 150)
                      else
                        MindyCharacter(id: who, state: state, size: 150),
                      const SizedBox(height: 14),
                      MindySpeechBubble(text: text, fontSize: 19),
                      const SizedBox(height: 26),
                      if (!isGreeting) ...[
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: 1.0),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, t, child) =>
                              Transform.scale(scale: t, child: child),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: type.nodeGradient,
                              ),
                              border: Border.all(color: Colors.white, width: 6),
                              boxShadow: AppShadows.soft,
                            ),
                            alignment: Alignment.center,
                            child: Text(type.worldEmoji,
                                style: const TextStyle(fontSize: 56, height: 1.0)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(type.worldName, style: AppText.heading),
                        const SizedBox(height: 4),
                        Text(type.title,
                            style: AppText.subheading.copyWith(
                                color: AppColors.inkNavy.withValues(alpha: 0.65))),
                      ],
                      const SizedBox(height: 18),
                      Text('\u{1F446} ${LanguageService.instance.tr('tap')}',
                          style: AppText.subheading.copyWith(
                              color: AppColors.inkNavy.withValues(alpha: 0.55))),
                      TextButton(
                        onPressed: _why,
                        child: const Text('Why this game? (grown-ups)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
