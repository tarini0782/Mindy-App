import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/friend_view.dart';
import '../characters/mindy_character.dart';
import '../services/avatar_service.dart';
import '../games/base/game_factory.dart';
import '../games/engine/adaptive_game_engine.dart';
import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';
import '../services/app_settings.dart';
import '../services/journey_controller.dart';
import '../services/music_service.dart';
import '../services/reward_service.dart';
import '../services/session_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/kara_card.dart';
import '../widgets/sky_background.dart';
import 'character_creator_screen.dart';
import 'game_transition_screen.dart';

/// "Today's Mindy Adventure": a winding path from START up to a final star.
///
///   completed   shown with a check and a star; tap for a friendly recap
///   current     the ONE playable activity, chosen by the adaptive engine
///   locked      mystery stops: the child cannot open or skip ahead
///
/// The child never picks an activity; Mindy does.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  String? _line;

  @override
  void initState() {
    super.initState();
    _music();
  }

  void _music() {
    final rec = JourneyController.instance.pending;
    final calm = rec?.gameType.category == GameCategory.calming;
    MusicService.instance
        .playBackgroundLoop(calm ? 'audio/calm_loop.wav' : 'audio/light_loop.wav');
  }

  void _playCurrent() {
    final j = JourneyController.instance;
    final s = j.state;
    final rec = j.pending;
    if (s == null || rec == null) return;
    final info = GameLaunchInfo(
      emotion: s.pendingEmotion,
      source: s.pendingSource,
      checkInMs: s.pendingCheckInMs,
      previousEmotion: s.pendingPreviousEmotion,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameTransitionScreen(recommendation: rec, info: info),
    ));
  }

  void _locked() {
    setState(() => _line = 'Mindy is choosing your next adventure. '
        'Finish this one first!');
  }

  void _recap(GameSession s) {
    final before = s.emotionBefore?.faceEmoji ?? '\u2753';
    final after = s.emotionAfter?.faceEmoji ?? '\u2753';
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [
          Text(s.game.worldEmoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(width: 10),
          Expanded(child: Text(s.game.title, style: AppText.heading)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MindyCharacter(
                id: s.game.character,
                state: CharacterState.celebrating,
                size: 90),
            const SizedBox(height: 6),
            Text('You played with ${s.game.character.displayName}!',
                style: AppText.subheading, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$before  \u2192  $after', style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 8),
            const Text('\u2B50\u2B50\u2B50', style: TextStyle(fontSize: 26)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        colors: AppColors.rainbowSky,
        showStars: true,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              JourneyController.instance,
              SessionRepository.instance,
              RewardService.instance,
              AppSettings.instance,
            ]),
            builder: (context, _) {
              final j = JourneyController.instance;
              final rec = j.pending;
              final completedIds = j.state?.completedSessionIds ?? const <String>[];
              final byId = {
                for (final s in SessionRepository.instance.chronological)
                  s.sessionId: s,
              };
              final done = [
                for (final id in completedIds)
                  if (byId[id] != null) byId[id]!,
              ];
              final line = _line ??
                  (rec == null
                      ? 'Mindy is getting your adventure ready!'
                      : rec.childMessage);

              return Column(
                children: [
                  _TopBar(),
                  const _CollectionBar(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // The child's own friend guides the journey map, and
                        // tapping them opens the one character system
                        // (AvatarService), not the old Kara dress-up screen.
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    AvatarService.instance.hasChosen
                                        ? const MyCharactersScreen()
                                        : const CharacterCreatorScreen()),
                          ),
                          child: const FriendView(size: 66),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: MindySpeechBubble(
                                text: line, fontSize: 15, maxWidth: 300),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _Path(
                        done: done,
                        current: rec,
                        onPlay: _playCurrent,
                        onLocked: _locked,
                        onRecap: _recap,
                      ),
                    ),
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

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('\u{1F308} Mindy\'s Adventure',
              style: AppText.heading.copyWith(fontSize: 20)),
          Row(children: [
            _RoundIcon(
              icon: Icons.smart_toy_outlined,
              label: 'KARA status',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const Scaffold(body: SafeArea(child: KaraCard())))),
            ),
            const SizedBox(width: 8),
            _RoundIcon(
              icon: s.musicOn ? Icons.music_note : Icons.music_off,
              label: 'Music',
              onTap: () => s.setMusic(!s.musicOn),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: AppColors.inkNavy, size: 22),
          ),
        ),
      ),
    );
  }
}

class _CollectionBar extends StatelessWidget {
  const _CollectionBar();

  @override
  Widget build(BuildContext context) {
    final r = RewardService.instance;
    Widget chip(String e, int n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Text('$e $n',
              style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          chip('\u2B50', r.stars),
          chip('\u{1F308}', r.rainbowPieces),
          chip('\u{1F48E}', r.gems),
          chip('\u{1F338}', r.flowers),
          chip('\u{1F98B}', r.butterflies),
          for (final d in r.decorations)
            Text(d, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}

const double _nodeH = 172;

class _Path extends StatelessWidget {
  final List<GameSession> done;
  final dynamic current; // GameRecommendation?
  final VoidCallback onPlay;
  final VoidCallback onLocked;
  final void Function(GameSession) onRecap;

  const _Path({
    required this.done,
    required this.current,
    required this.onPlay,
    required this.onLocked,
    required this.onRecap,
  });

  @override
  Widget build(BuildContext context) {
    const n = AdaptiveGameEngine.journeyLength;
    final stops = n + 2; // + final star + START
    final height = _nodeH * stops + 40;
    final doneCount = done.length;

    // Node i (0 = first activity, bottom) counted from START.
    Widget node(int i) {
      if (i < doneCount) {
        return _Node.completed(session: done[i], onTap: () => onRecap(done[i]));
      }
      if (i == doneCount && current != null) {
        return _Node.current(type: current.gameType as GameType, onTap: onPlay);
      }
      return _Node.locked(index: i + 1, onTap: onLocked);
    }

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PathPainter(count: stops))),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(child: _FinalStar(unlocked: doneCount >= n)),
          ),
          for (var i = 0; i < n; i++)
            Positioned(
              top: 20 + (n - i) * _nodeH,
              left: (i).isOdd ? 16 : null,
              right: (i).isEven ? 16 : null,
              child: node(i),
            ),
          Positioned(
            top: 20 + (stops - 1) * _nodeH + 20,
            left: 0,
            right: 0,
            child: const Center(child: _Start()),
          ),
        ],
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start();
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('\u{1F6A9}', style: TextStyle(fontSize: 44)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.pill)),
          child: Text('START',
              style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _FinalStar extends StatelessWidget {
  final bool unlocked;
  const _FinalStar({required this.unlocked});
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: unlocked
                  ? const [Color(0xFFFFF59D), Color(0xFFFFB300)]
                  : [Colors.grey.shade300, Colors.grey.shade400],
            ),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: AppShadows.soft,
          ),
          alignment: Alignment.center,
          child: Text(unlocked ? '\u{1F31F}' : '\u{1F512}',
              style: const TextStyle(fontSize: 46)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppShadows.soft),
          child: Text('Journey Complete',
              style: AppText.body.copyWith(fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _PathPainter extends CustomPainter {
  final int count;
  _PathPainter({required this.count});

  double _x(int i, Size s) {
    if (i == 0 || i == count - 1) return s.width * 0.5;
    return i.isOdd ? s.width * 0.74 : s.width * 0.26;
  }

  double _y(int i) => 20 + i * _nodeH + 60;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 1; i < count; i++) {
      final px = _x(i - 1, size), py = _y(i - 1);
      final x = _x(i, size), y = _y(i);
      path.moveTo(px, py);
      path.cubicTo(px, py + _nodeH * 0.5, x, y - _nodeH * 0.5, x, y);
    }
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final next = d + 10.0;
        canvas.drawPath(
            m.extractPath(d, next.clamp(0, m.length).toDouble()), paint);
        d = next + 8.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => false;
}

enum _NodeKind { completed, current, locked }

class _Node extends StatefulWidget {
  final _NodeKind kind;
  final GameSession? session;
  final GameType? type;
  final int index;
  final VoidCallback onTap;

  const _Node._(this.kind, this.session, this.type, this.index, this.onTap);

  factory _Node.completed(
          {required GameSession session, required VoidCallback onTap}) =>
      _Node._(_NodeKind.completed, session, session.game, 0, onTap);
  factory _Node.current({required GameType type, required VoidCallback onTap}) =>
      _Node._(_NodeKind.current, null, type, 0, onTap);
  factory _Node.locked({required int index, required VoidCallback onTap}) =>
      _Node._(_NodeKind.locked, null, null, index, onTap);

  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.kind == _NodeKind.current) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final type = widget.type;
    final unlocked = k != _NodeKind.locked;

    final circle = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? type!.nodeGradient
              : [Colors.grey.shade300, Colors.grey.shade400],
        ),
        shape: BoxShape.circle,
        border: Border.all(
            color: k == _NodeKind.current ? AppColors.sunshineYellow : Colors.white,
            width: k == _NodeKind.current ? 7 : 5),
        boxShadow: AppShadows.soft,
      ),
      alignment: Alignment.center,
      child: unlocked
          ? Text(type!.worldEmoji, style: const TextStyle(fontSize: 46))
          : const Text('?',
              style: TextStyle(
                  fontSize: 46, color: Colors.white, fontWeight: FontWeight.w900)),
    );

    final semantic = k == _NodeKind.locked
        ? 'Locked adventure'
        : (k == _NodeKind.current ? 'Play today\'s adventure' : 'Finished adventure');

    return Semantics(
      button: true,
      label: semantic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 156,
          child: Column(
            children: [
              if (k == _NodeKind.current)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sunshineYellow,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text('\u2B50 Play me!',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (k == _NodeKind.current)
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                          scale: 1.0 + 0.06 * _pulse.value, child: child),
                      child: circle,
                    )
                  else
                    circle,
                  if (unlocked)
                    Positioned(
                      right: -26,
                      bottom: -8,
                      child: MindyCharacter(
                          id: type!.character,
                          state: CharacterState.idle,
                          size: 54,
                          animated: false),
                    ),
                  if (k == _NodeKind.completed)
                    const Positioned(
                      left: -2,
                      top: -2,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.meadowGreen,
                        child: Icon(Icons.check_rounded, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: AppShadows.soft,
                ),
                child: Text(
                  unlocked ? type!.worldName : 'Mystery ${widget.index}',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
