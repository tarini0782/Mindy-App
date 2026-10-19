import 'dart:math';
import 'package:flutter/material.dart';
import '../../characters/character_id.dart';
import '../../characters/character_lines.dart';
import '../../characters/friend_view.dart';
import '../../characters/mindy_character.dart';
import '../../models/emotion_state.dart';
import '../../services/app_settings.dart';
import '../../services/account_service.dart';
import '../../services/journey_controller.dart';
import '../../services/music_service.dart';
import '../../services/reward_service.dart';
import '../../services/session_repository.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/emotion_picker.dart';
import '../../widgets/world_background.dart';
import '../models/game_recommendation.dart';
import '../models/game_session.dart';
import '../models/game_type.dart';
import '../widgets/game_header.dart';
import '../widgets/positive_feedback.dart';
import 'game_audio.dart';
import 'game_factory.dart';
import 'game_session_controller.dart';
import '../../models/study_condition.dart';

typedef GameBodyBuilder = Widget Function(
    BuildContext context, GameSessionController controller);

/// The shared frame around every activity. It owns session logging so no
/// game ever has to:
///
///   TOP     back, activity name, small progress bar
///   CENTER  the game itself
///   STRIP   the world's character + what they are saying
///   BOTTOM  one visual instruction + pause
///   PAUSE   Keep playing / Leave (pause freezes game timers and animation)
///   DONE    celebration -> "Mindy learned from your play" -> "How do you
///           feel now?" -> "Let's see what's next!"
///
/// Leaving early logs an INCOMPLETE session and never punishes the child.
class GameShell extends StatefulWidget {
  final GameType type;
  final GameLaunchInfo info;
  final GameRecommendation recommendation;
  final GameBodyBuilder bodyBuilder;

  const GameShell({
    super.key,
    required this.type,
    required this.info,
    required this.recommendation,
    required this.bodyBuilder,
  });

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final GameSessionController _c;
  late final DateTime _runStart;
  DateTime? _pauseStart;
  Duration _pausedTotal = Duration.zero;
  int _pausedCount = 0;
  final Stopwatch _loadWatch = Stopwatch()..start();
  int? _loadTimeMs;
  DateTime? _cardShownAt;

  GameSession? _session;
  RewardGrant? _grant;
  bool _paused = false;
  bool _decided = false; // the next activity has been chosen
  bool _leaving = false;
  bool? _midEnjoying;

  @override
  void initState() {
    super.initState();
    _c = GameSessionController(
      recommendation: widget.recommendation,
      // Fixed research mode never changes difficulty silently.
      allowDifficultyChange:
          widget.recommendation.trace.condition != 'FIXED_BASELINE',
    )..addListener(_onControllerChanged);
    _runStart = DateTime.now();
    MusicService.instance.playBackgroundLoop(
        widget.type.category == GameCategory.calming
            ? 'audio/calm_loop.wav'
            : 'audio/light_loop.wav');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTimeMs ??= _loadWatch.elapsedMilliseconds;
      _session?.loadTimeMs ??= _loadTimeMs;
    });
  }

  void _onControllerChanged() {
    if (_c.completed && _session == null && mounted) {
      setState(() {
        _finish(completed: true);
        _cardShownAt = DateTime.now();
      });
    }
  }

  String _newId() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(1 << 30).toRadixString(16)}';
  }

  /// Builds and stores this run's session. Safe to call from dispose().
  void _finish({required bool completed}) {
    if (_session != null) return;
    final now = DateTime.now();
    final active = now.difference(_runStart) -
        _pausedTotal -
        (_pauseStart != null ? now.difference(_pauseStart!) : Duration.zero);
    final info = widget.info;

    final s = GameSession.fromRecommendation(
      sessionId: _newId(),
      anonymousChildId: AppSettings.instance.childId,
      emotion: info.emotion,
      emotionSource: info.source.code,
      checkInDurationMs: info.checkInMs,
      previousEmotion: info.previousEmotion,
      rec: widget.recommendation,
      startTime: _runStart,
    )
      ..endTime = now
      ..durationSeconds = active.inSeconds < 0 ? 0 : active.inSeconds
      ..pausedCount = _pausedCount
      ..completed = completed
      ..completionPercent = completed ? 1.0 : _c.progress.value
      ..score = _c.score
      ..successes = _c.successes
      ..mistakes = _c.mistakes
      ..interactions = _c.interactions
      ..completedUnits = _c.completedUnits
      ..totalUnits = _c.totalUnits
      ..avgResponseMs = _c.avgResponseMs
      ..responseTimeVariabilityMs = _c.responseVariabilityMs
      ..loadTimeMs = _loadTimeMs
      ..events = List.of(_c.events)
      ..participantAge = _childAge()
      ..supportCount = _c.support.offers
      ..maxSupportStage = _c.support.highest.index
      ..attemptsAfterSupport = _c.support.attemptsAfterSupport
      ..successesAfterSupport = _c.support.successesAfterSupport
      ..difficultyAdjustments = _c.difficultyAdjustments
      ..midGameEnjoying = _midEnjoying
      ..childEasierRequests = _c.childEasierRequests;

    _session = s;
    if (widget.info.practice) {
      // Free play: nothing is stored, no stars saved, the journey is untouched.
      if (completed) GameAudio.complete();
      _decided = true;
      return;
    }
    SessionRepository.instance.add(s);
    _grant = RewardService.instance.award(s);
    if (widget.info.feed) {
      // Feed play: stored and synced, adventure untouched.
      if (completed) GameAudio.complete();
      _decided = true;
      SyncService.instance.trigger();
      return;
    }
    if (completed) {
      GameAudio.complete();
      JourneyController.instance.recordCompletion(s);
    } else {
      JourneyController.instance.recordAbandon(s);
    }
    SyncService.instance.trigger();
  }

  /// Approximate age in whole years from the active child's birth YEAR.
  int? _childAge() {
    final c = AccountService.instance.activeChild;
    if (c == null) return AppSettings.instance.participantAge;
    final age = DateTime.now().year - c.birthYear;
    return (age < 2 || age > 18) ? null : age;
  }

  void _pause() {
    if (_paused || _c.completed) return;
    setState(() {
      _paused = true;
      _c.paused = true;
      _pausedCount++;
      _pauseStart = DateTime.now();
    });
  }

  void _resume() {
    if (!_paused) return;
    setState(() {
      if (_pauseStart != null) {
        _pausedTotal += DateTime.now().difference(_pauseStart!);
      }
      _pauseStart = null;
      _paused = false;
      _c.paused = false;
    });
  }

  /// Leaves the screen. If the child has not finished, the session is logged
  /// as incomplete and the engine chooses a new activity (recovery).
  Future<void> _leave({EmotionState? after}) async {
    if (_leaving) return;
    _leaving = true;
    if (_session == null) {
      if (_c.interactions > 0 || _c.progress.value > 0) {
        _finish(completed: false);
      } else {
        // Nothing happened: still counts as an (incomplete) session so the
        // research record is honest, but with zero interactions.
        _finish(completed: false);
      }
    }
    await _decideNext(after: after);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _decideNext({EmotionState? after}) async {
    final s = _session;
    if (s == null || _decided) return;
    _decided = true;
    var ms = 0;
    if (_cardShownAt != null) {
      ms = DateTime.now().difference(_cardShownAt!).inMilliseconds;
    }
    await JourneyController.instance
        .decideNext(session: s, after: after ?? s.emotionAfter, checkInMs: ms);
  }

  void _onFeeling(EmotionState e) {
    final s = _session;
    if (s == null) return;
    setState(() => s.emotionAfter = e);
    if (!widget.info.practice) SessionRepository.instance.update(s);
  }

  void _onEnjoyment(int v) {
    final s = _session;
    if (s == null) return;
    setState(() => s.enjoyment = s.enjoyment == v ? null : v);
    if (!widget.info.practice) SessionRepository.instance.update(s);
  }

  void _onPerceivedDifficulty(int v) {
    final s = _session;
    if (s == null) return;
    setState(() => s.perceivedDifficulty = s.perceivedDifficulty == v ? null : v);
    if (!widget.info.practice) SessionRepository.instance.update(s);
  }

  void _onPlayAgain(bool v) {
    final s = _session;
    if (s == null) return;
    setState(() => s.playAgain = v);
    if (!widget.info.practice) SessionRepository.instance.update(s);
  }

  @override
  void dispose() {
    // Any exit path (system back, app killed screen) still saves the data.
    if (_session == null) _finish(completed: false);
    if (!_decided && _session != null) {
      _decided = true;
      JourneyController.instance.decideNext(
          session: _session!, after: _session!.emotionAfter, checkInMs: 0);
    }
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final done = _c.completed && _session != null;

    // PopScope, not WillPopScope: the old widget breaks Android's predictive
    // back gesture. canPop stays false because a child must never leave an
    // activity by a stray back swipe -- leaving always goes through _leave()
    // or the pause sheet, so the session is recorded either way.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (done) {
          await _leave(after: _session?.emotionAfter);
        } else {
          _pause();
        }
      },
      child: Scaffold(
        body: WorldBackground(
          worldKey: type.worldKey,
          colors: type.background,
          // v47: the check-in feeling reaches the presentation of every
          // game through here. A scared, sad or skipped check-in turns
          // off the drifting background decoration, so the task is the
          // only thing moving on screen (rule ATT-05).
          showStars: type.category == GameCategory.calming &&
              !_c.mood.reducedMotion,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    GameHeader(
                      title: type.title,
                      emoji: type.emoji,
                      progress: _c.progress,
                      onBack: _pause,
                      actions: [
                        _RoundButton(
                            label: 'Help',
                            icon: Icons.lightbulb_rounded,
                            color: const Color(0xFFFFF3C4),
                            iconColor: const Color(0xFFF9A825),
                            onTap: _c.requestHelp),
                        const SizedBox(width: 8),
                        _RoundButton(
                            label: 'Pause',
                            icon: Icons.pause_rounded,
                            color: Colors.white,
                            iconColor: AppColors.inkNavy,
                            onTap: _pause),
                      ],
                    ),
                    Expanded(
                      child: ClipRect(
                        child: TickerMode(
                          enabled: !_paused && !done,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: PlayArea(
                                  child: widget.bodyBuilder(context, _c),
                                ),
                              ),
                              Positioned.fill(
                                child: FeedbackLayer(controller: _c),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                bottom: 6,
                                child: IgnorePointer(
                                    child: _CharacterStrip(controller: _c)),
                              ),
                              Positioned(
                                top: 2,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                    child: _InstructionChip(text: type.instruction)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_paused)
                  _PauseOverlay(
                    host: type.character,
                    onResume: _resume,
                    onExit: () => _leave(),
                    enjoying: _midEnjoying,
                    onEnjoying: (v) => setState(() => _midEnjoying = v),
                    onEasier: _c.canMakeEasier
                        ? () {
                            _c.requestEasier();
                            _resume();
                          }
                        : null,
                  ),
                if (done)
                  _CompletionCard(
                    session: _session!,
                    grant: _grant,
                    onFeeling: _onFeeling,
                    onPlayAgain: _onPlayAgain,
                    onEnjoyment: _onEnjoyment,
                    onDifficulty: _onPerceivedDifficulty,
                    onNext: () => _leave(after: _session!.emotionAfter),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps every game inside a phone-shaped play field, centred, whatever the
/// window is. Games scale from the width they are given, so on a wide window
/// (desktop, web, tablet landscape) they would otherwise stretch and spill off
/// the bottom. The field is never wider than 72% of its height and never
/// narrower than 280 logical pixels when there is room.
class PlayArea extends StatelessWidget {
  final Widget child;
  const PlayArea({super.key, required this.child});

  /// Width of the play field for a given space.
  static double widthFor(double maxWidth, double maxHeight) {
    final byHeight = maxHeight * 0.72;
    final w = maxWidth < byHeight ? maxWidth : byHeight;
    return w < 280 ? (maxWidth < 280 ? maxWidth : 280) : w;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = widthFor(box.maxWidth, box.maxHeight);
      return Center(
        child: ClipRect(
          child: SizedBox(width: w, height: box.maxHeight, child: child),
        ),
      );
    });
  }
}

class _CharacterStrip extends StatelessWidget {
  final GameSessionController controller;
  const _CharacterStrip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CharacterSay?>(
      valueListenable: controller.say,
      builder: (context, say, _) {
        final state = say?.state ?? CharacterState.idle;
        // Only shown while the character is speaking, so the play area keeps
        // the whole screen the rest of the time.
        if (say == null) return const SizedBox(height: 0);
        return Row(
          children: [
            // The child's own friend speaks unless the game named one of its
            // own world characters. This is the single place that decides
            // whose face appears beside an in-game line, in all 27 games.
            if (say.who == null)
              const FriendView(size: 56, animate: false)
            else
              MindyCharacter(id: say.who!, state: state, size: 56),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: MindySpeechBubble(
                  text: say.text,
                  fontSize: 15,
                  maxWidth: 280,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small round button used in the top bar (help, pause).
class _RoundButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ),
        ),
      );
}

/// The one-line instruction, shown for a few seconds then faded away so it
/// never takes space from the game.
class _InstructionChip extends StatefulWidget {
  final String text;
  const _InstructionChip({required this.text});

  @override
  State<_InstructionChip> createState() => _InstructionChipState();
}

class _InstructionChipState extends State<_InstructionChip> {
  bool _show = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: _show ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: AppShadows.soft,
            ),
            child: Text(widget.text,
                textAlign: TextAlign.center,
                style: AppText.subheading.copyWith(fontSize: 15)),
          ),
        ),
      );
}

class _PauseOverlay extends StatelessWidget {
  final CharacterId host;
  final VoidCallback onResume;
  final VoidCallback onExit;
  final bool? enjoying;
  final ValueChanged<bool> onEnjoying;
  final VoidCallback? onEasier; // null when this game cannot get easier
  const _PauseOverlay({
    required this.host,
    required this.onResume,
    required this.onExit,
    required this.enjoying,
    required this.onEnjoying,
    required this.onEasier,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black38,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(28),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                boxShadow: AppShadows.soft,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Taking a break is a moment between the child and their
                  // own friend, not the game's world character.
                  const FriendView(size: 84),
                  const SizedBox(height: 8),
                  Text('Taking a break \u{1F499}',
                      style: AppText.heading.copyWith(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(CharacterLines.encourage(host),
                      textAlign: TextAlign.center, style: AppText.body),
                  const SizedBox(height: 12),
                  Text('Are you enjoying this game? (you can skip)',
                      textAlign: TextAlign.center, style: AppText.body),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Thumb(
                          emoji: '\u{1F44D}',
                          label: 'Yes',
                          selected: enjoying == true,
                          onTap: () => onEnjoying(true)),
                      const SizedBox(width: 14),
                      _Thumb(
                          emoji: '\u{1F44E}',
                          label: 'Not really',
                          selected: enjoying == false,
                          onTap: () => onEnjoying(false)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (onEasier != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('makeItEasier'),
                        onPressed: onEasier,
                        icon: const Icon(Icons.spa_rounded),
                        label: const Text('Make it easier'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text('Keep playing'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: onExit,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.exit_to_app_rounded),
                      label: const Text("I'm done for now"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reward + "Mindy learned from your play" + "How do you feel now?".
/// Children never see percentages, times, mood numbers or any research term.
class _CompletionCard extends StatefulWidget {
  final GameSession session;
  final RewardGrant? grant;
  final ValueChanged<EmotionState> onFeeling;
  final ValueChanged<bool> onPlayAgain;
  final ValueChanged<int> onEnjoyment;
  final ValueChanged<int> onDifficulty;
  final VoidCallback onNext;

  const _CompletionCard({
    required this.session,
    required this.grant,
    required this.onFeeling,
    required this.onPlayAgain,
    required this.onEnjoyment,
    required this.onDifficulty,
    required this.onNext,
  });

  @override
  State<_CompletionCard> createState() => _CompletionCardState();
}

class _CompletionCardState extends State<_CompletionCard> {
  // v45: ONE QUESTION AT A TIME.
  //
  // This card used to show the celebration plus four rating questions at
  // once -- feeling (5 options), fun (3), easy/hard (3) and play again (2)
  // -- on a single scrolling panel, after every session. Thirteen targets,
  // every game, for children as young as three.
  //
  // That is a data-quality problem before it is a layout one: a child who
  // is asked four questions in a row starts tapping the same position to
  // get through them (straight-lining), and the self-report measures this
  // project depends on are the first thing that corrupts.
  //
  // NOTHING WAS DROPPED. All four answers are still collected, because
  // all four are used: `emotionAfter` feeds the mood change and the
  // caregiver report, `enjoyment` feeds the summaries, `playAgain` feeds
  // the engine's engagement score, and `perceivedDifficulty` feeds the
  // level step in `_levelFor`. Removing any of them is a research-design
  // decision, not a tidy-up -- see docs for the recommendation.
  //
  // What changed is the pacing: one question per step, a big skip, and a
  // tap advances automatically, so answering all four is four taps and no
  // scrolling. Skipping is one.
  int _step = 0;

  static const int _lastStep = 3;

  void _advance() {
    if (!mounted) return;
    if (_step >= _lastStep) {
      widget.onNext();
      return;
    }
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final grant = widget.grant;
    final stars = grant?.stars ?? 3;
    final after = s.emotionAfter;

    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            margin: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- the header shrinks once the questions start ----
                  if (_step == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // The child's friend celebrates beside the game's
                        // own character.
                        const FriendView(size: 74),
                        MindyCharacter(
                            id: s.game.character,
                            state: CharacterState.celebrating,
                            size: 74),
                      ],
                    ),
                    Text(CharacterLines.celebrate,
                        textAlign: TextAlign.center,
                        style: AppText.heading.copyWith(
                            color: AppColors.grapePurple, fontSize: 21)),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < stars; i++)
                          const Icon(Icons.star_rounded,
                              color: AppColors.sunshineYellow, size: 32),
                      ],
                    ),
                    if (grant != null && grant.collectibleEmoji.isNotEmpty)
                      Text(
                          'You found a ${grant.collectibleName} '
                          '${grant.collectibleEmoji}',
                          textAlign: TextAlign.center,
                          style: AppText.body),
                    const SizedBox(height: 4),
                    // Kept: this is the one line that tells the child the
                    // app pays attention to how they played.
                    Text(CharacterLines.learned,
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: CalmColors.inkSoft)),
                  ] else
                    const FriendView(size: 56),

                  const SizedBox(height: 14),

                  // ---- one question ----------------------------------
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _question(s, after),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ---- progress dots and the way out -----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i <= _lastStep; i++)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= _step
                                ? AppColors.grapePurple
                                : AppColors.softLavender,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _advance,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(_step >= _lastStep
                          ? 'Next adventure'
                          : 'Skip this'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The one question for the current step. Each option advances on tap,
  /// so a child never has to find a separate "next" after answering.
  Widget _question(GameSession s, EmotionState? after) {
    switch (_step) {
      case 1:
        return _Ask(
          title: 'Was it fun?',
          children: [
            _Thumb(
                emoji: '\u{1F641}',
                label: 'Not fun',
                selected: s.enjoyment == 1,
                onTap: () {
                  widget.onEnjoyment(1);
                  _advance();
                }),
            _Thumb(
                emoji: '\u{1F610}',
                label: 'Okay',
                selected: s.enjoyment == 2,
                onTap: () {
                  widget.onEnjoyment(2);
                  _advance();
                }),
            _Thumb(
                emoji: '\u{1F604}',
                label: 'Fun!',
                selected: s.enjoyment == 3,
                onTap: () {
                  widget.onEnjoyment(3);
                  _advance();
                }),
          ],
        );
      case 2:
        return _Ask(
          title: 'Was it easy or hard?',
          children: [
            _Thumb(
                emoji: '\u{1F60C}',
                label: 'Easy',
                selected: s.perceivedDifficulty == 1,
                onTap: () {
                  widget.onDifficulty(1);
                  _advance();
                }),
            _Thumb(
                emoji: '\u{1F44C}',
                label: 'Just right',
                selected: s.perceivedDifficulty == 2,
                onTap: () {
                  widget.onDifficulty(2);
                  _advance();
                }),
            _Thumb(
                emoji: '\u{1F625}',
                label: 'Hard',
                selected: s.perceivedDifficulty == 3,
                onTap: () {
                  widget.onDifficulty(3);
                  _advance();
                }),
          ],
        );
      case 3:
        return _Ask(
          title: 'Play this again some day?',
          children: [
            _Thumb(
                emoji: '\u{1F44D}',
                label: 'Yes',
                selected: s.playAgain == true,
                onTap: () {
                  widget.onPlayAgain(true);
                  _advance();
                }),
            _Thumb(
                emoji: '\u{1F44E}',
                label: 'Not now',
                selected: s.playAgain == false,
                onTap: () {
                  widget.onPlayAgain(false);
                  _advance();
                }),
          ],
        );
      default:
        return _Ask(
          title: 'How do you feel now?',
          children: const [],
          below: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmotionPicker(
                compact: true,
                selected: after,
                onSelected: (e) {
                  widget.onFeeling(e);
                  _advance();
                },
              ),
              if (after != null) ...[
                const SizedBox(height: 8),
                // v49: this line answers how the CHILD feels, so it is
                // the child's friend who says it, not the game's
                // character. Drawn as the friend plus a bubble rather
                // than CharacterSays, which only takes a CharacterId.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FriendView(size: 56, animate: false),
                    const SizedBox(width: 6),
                    Flexible(
                      child: MindySpeechBubble(
                        text: CharacterLines.moodReaction(
                            s.emotionBefore, after),
                        fontSize: 15,
                        maxWidth: 250,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// One question: a title and a row of choices, centred, with room to
/// breathe. Replaces four stacked blocks on one panel.
class _Ask extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? below;
  const _Ask({required this.title, required this.children, this.below});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: AppText.heading
                  .copyWith(fontSize: 20, color: CalmColors.ink)),
          const SizedBox(height: 12),
          if (children.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: children,
            ),
          if (below != null) below!,
        ],
      );
}

class _Thumb extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Thumb(
      {required this.emoji,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.softLavender : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? AppColors.grapePurple : Colors.transparent,
              width: 3),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            Text(label, style: AppText.body.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
