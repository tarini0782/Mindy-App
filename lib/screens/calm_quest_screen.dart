import 'package:flutter/material.dart';
import '../games/engine/adaptive_game_engine.dart';
// These two carry the extensions used below: EmotionState.label/.faceEmoji
// and GameType.title. Without them the getters are undefined at compile time.
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';
import '../services/account_service.dart';
import '../services/journey_controller.dart';
import '../services/session_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/calm_ui.dart';
import 'calm_corner_screen.dart';
import 'play_flow.dart';
import 'worry_scale_screen.dart';

/// "Calm Quest": the therapeutic-gaming part of Mindy and the research
/// component. A short guided loop: say how you feel, Mindy picks a calming
/// activity that fits, play, then say how you feel now. The rest of the app
/// (free games, the feed, the grown-ups' area) sits around it.
class CalmQuestScreen extends StatelessWidget {
  const CalmQuestScreen({super.key});

  /// Opens the guided quest (check-in, game, check-in) on top of the hub.
  static void start(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        body: Stack(children: [
          const PlayFlow(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.white70,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Back to Calm Quest',
                  icon: const Icon(Icons.arrow_back_rounded, color: CalmColors.ink),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            JourneyController.instance,
            SessionRepository.instance,
            AccountService.instance,
          ]),
          builder: (context, _) {
            final name = AccountService.instance.activeChild?.nickname.trim() ?? '';
            final done = JourneyController.instance.completedCount;
            final total = AdaptiveGameEngine.journeyLength;
            final complete = JourneyController.instance.journeyComplete;
            final researchOn =
                AccountService.instance.activeChild?.researchEnabled ?? true;
            final adventure = SessionRepository.instance.chronological
                .where((s) => s.trigger == 'adventure')
                .toList();
            final last = adventure.isEmpty ? null : adventure.last;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: CalmColors.hero,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const PillBadge('Therapeutic gaming',
                        bg: Colors.white24, fg: Colors.white, icon: Icons.spa_rounded),
                    const SizedBox(height: 10),
                    const Text('Calm Quest',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                        name.isEmpty
                            ? 'Little games that help big feelings feel smaller.'
                            : 'Hi $name! Little games that help big feelings feel smaller.',
                        style: const TextStyle(fontSize: 15.5, color: Colors.white, height: 1.3)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, foregroundColor: CalmColors.teal),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(!researchOn
                            ? 'Quest is switched off'
                            : complete
                                ? 'See my quest'
                                : done == 0
                                    ? 'Start my quest'
                                    : 'Continue my quest'),
                        onPressed: researchOn ? () => start(context) : null,
                      ),
                    ),
                    if (!researchOn)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('A grown-up turned this off in Settings.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ),
                  ]),
                ),
                const SectionLabel('How it works'),
                CalmCard(
                  child: Column(children: const [
                    _Step('1', Icons.mood_rounded, 'Tell Mindy how you feel',
                        'Tap the face that matches. There is no wrong answer.'),
                    _Step('2', Icons.auto_awesome_rounded, 'Mindy picks a game for you',
                        'Scared or sad? You get a gentle, slow one. Feeling good? A livelier one.'),
                    _Step('3', Icons.sports_esports_rounded, 'Play at your own speed',
                        'Hints are friendly. You can ask for it to be easier any time.'),
                    _Step('4', Icons.favorite_rounded, 'Tell Mindy how you feel now',
                        'Mindy and your grown-up can see what helped.'),
                  ]),
                ),
                const SectionLabel('My quest'),
                CalmCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(complete ? 'Quest complete!' : '$done of $total games done',
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
                      ),
                      Text('$done/$total',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CalmColors.teal)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: CalmColors.tealSoft,
                        color: CalmColors.teal,
                      ),
                    ),
                    if (last != null && last.emotionBefore != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        last.emotionAfter == null
                            ? 'Last time you felt ${last.emotionBefore!.label.toLowerCase()} ${last.emotionBefore!.faceEmoji} and played ${last.game.title}.'
                            : 'Last time: ${last.emotionBefore!.faceEmoji} ${last.emotionBefore!.label}  →  ${last.emotionAfter!.faceEmoji} ${last.emotionAfter!.label}  after ${last.game.title}.',
                        style: const TextStyle(fontSize: 14.5, color: CalmColors.ink, height: 1.3),
                      ),
                    ],
                  ]),
                ),
                const SectionLabel('Quiet moments', sub: 'Always here, no games needed'),
                CalmCard(
                  onTap: () => _open(context, const CalmCornerScreen()),
                  child: const _Tile(Icons.air_rounded, CalmColors.teal, 'Calm Corner',
                      'Breathing and looking-around space. You choose when.'),
                ),
                CalmCard(
                  onTap: () => _open(context, const WorryScaleScreen()),
                  child: const _Tile(Icons.sentiment_satisfied_alt_rounded, CalmColors.periwinkle,
                      'Worry faces (with a grown-up)',
                      'Show how worried you feel before and after playing.'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final IconData icon;
  final String title;
  final String sub;
  const _Step(this.n, this.icon, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 20,
              backgroundColor: CalmColors.tealSoft,
              child: Icon(icon, color: CalmColors.teal, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$n. $title',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 13.5, color: CalmColors.inkSoft, height: 1.3)),
            ]),
          ),
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  const _Tile(this.icon, this.color, this.title, this.sub);
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 13.5, color: CalmColors.inkSoft, height: 1.3)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: CalmColors.inkSoft),
      ]);
}
