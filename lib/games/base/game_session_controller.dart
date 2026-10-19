import 'dart:async';
import 'package:flutter/material.dart';
import '../../characters/character_id.dart';
import '../models/game_difficulty.dart';
import '../models/game_pace.dart';
import '../models/game_session.dart';
import '../models/game_recommendation.dart';
import '../support/support_engine.dart';
import '../models/game_type.dart';
import '../models/mood_presentation.dart';

/// A short floating emoji ("+star") shown where something good happened.
class FeedbackBurst {
  final int id;
  final Offset position; // in the game area's own coordinates
  final String emoji;
  const FeedbackBurst({
    required this.id,
    required this.position,
    required this.emoji,
  });
}

/// What a character is currently saying / doing inside a game.
class CharacterSay {
  /// null means THE CHILD'S OWN FRIEND is speaking -- the companion they
  /// made in the character creator, which is the guide across the whole app.
  ///
  /// A non-null id means a game deliberately named one of its own world
  /// characters, because that character is part of the game itself (Pip
  /// walking the maze, say) rather than the voice guiding the child.
  ///
  /// Guide lines are written in the first person and never name a character
  /// (see CharacterLines.start / encourage), so they read correctly in the
  /// friend's voice. Keep it that way: a line that names a world character
  /// must pass `who` explicitly or it will be spoken by the wrong face.
  final CharacterId? who;
  final CharacterState state;
  final String text;
  const CharacterSay(this.who, this.state, this.text);
}

/// The one object a game talks to. It carries the engine's decision
/// (level / pace) IN and the session statistics OUT, so games never touch
/// logging, navigation, pause or the completion screen.
class GameSessionController extends ChangeNotifier {
  GameSessionController({
    required this.recommendation,
    bool allowDifficultyChange = true,
    SupportConfig supportConfig = const SupportConfig(),
  }) : _allowChange = allowDifficultyChange,
        support = SupportEngine(
            config: supportConfig, allowDifficultyChange: allowDifficultyChange) {
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _paused || completed) return;
      _idleSec++;
      if (_idleSec >= support.config.idleSeconds) {
        _idleSec = 0;
        _handleSupport(support.onIdle());
      }
    });
  }

  final GameRecommendation recommendation;

  // ---- hint and support ladder (shared by every game) -----------------
  final SupportEngine support;

  /// Current stage; games listen to it to highlight the target (visualCue)
  /// or to show a demonstration. Returns to `independent` after a success.
  final ValueNotifier<SupportStage> supportCue =
      ValueNotifier<SupportStage>(SupportStage.independent);

  /// Each game fills these in. All are optional.
  String Function()? hintText; // "Find the blue jellyfish"
  VoidCallback? onDemonstrate; // replay the sequence / show the move
  VoidCallback? onEasier; // lower ONE real difficulty parameter
  VoidCallback? onHarder; // raise ONE real difficulty parameter

  // ---- in-game flow adaptation -----------------------------------------
  // After [streakForHarder] successes in a row with no help in between, a
  // game that supports it gets a little harder (at most [maxHarder] times
  // per session). Not in the fixed-baseline arm. Logged as a 'difficulty'
  // event whose value is level + number of harder steps so far.
  static const int streakForHarder = 5;
  static const int maxHarder = 3;
  final bool _allowChange;
  int _streak = 0;
  int harderSteps = 0;

  int difficultyAdjustments = 0;
  int childEasierRequests = 0;

  /// The CHILD asked for an easier game (from the break screen). Always
  /// honoured when the game can do it, even in the fixed-baseline arm,
  /// because a child's request overrides the study design. Logged as a
  /// difficulty event and counted separately from automatic changes.
  bool get canMakeEasier => onEasier != null;
  bool requestEasier() {
    if (onEasier == null || _disposed) return false;
    onEasier!.call();
    childEasierRequests++;
    difficultyAdjustments++;
    _log('difficulty', level.toDouble());
    return true;
  }
  int _idleSec = 0;
  Timer? _idleTimer;

  /// The child tapped the light-bulb.
  void requestHelp() => _handleSupport(support.request());

  void _handleSupport(SupportEvent? e) {
    if (e == null || _disposed) return;
    _log('support', e.stage.index.toDouble());
    supportCue.value = e.stage;
    switch (e.stage) {
      case SupportStage.independent:
        break;
      case SupportStage.visualCue:
        react(CharacterState.encouraging, 'Look closely. Can you spot it?',
            ms: 2600);
        break;
      case SupportStage.smallHint:
        react(CharacterState.encouraging, hintText?.call() ?? 'Take your time!',
            ms: 3600);
        break;
      case SupportStage.demonstration:
        react(CharacterState.calm, 'Let me show you.', ms: 3000);
        onDemonstrate?.call();
        break;
      case SupportStage.easier:
        if (onEasier != null) {
          onEasier!.call();
          difficultyAdjustments++;
          _log('difficulty', level.toDouble());
          react(CharacterState.calm, "Let's make it a little easier.", ms: 3000);
        }
        break;
      case SupportStage.breakOffer:
        react(CharacterState.calm,
            'Want a little break? Tap the pause button any time.',
            ms: 4500);
        break;
    }
  }

  void _afterAttempt(bool ok) {
    _idleSec = 0;
    if (!ok) {
      _streak = 0;
    } else if (supportCue.value == SupportStage.independent) {
      _streak++;
      if (_streak >= streakForHarder &&
          _allowChange &&
          onHarder != null &&
          harderSteps < maxHarder &&
          !completed) {
        _streak = 0;
        harderSteps++;
        difficultyAdjustments++;
        onHarder!.call();
        _log('difficulty', (level + harderSteps).toDouble());
        react(CharacterState.excited, "You're on fire! Let's try something trickier!",
            ms: 2600);
      }
    } else {
      _streak = 0; // a success that needed help does not count
    }
    final e = support.onAttempt(ok: ok);
    if (ok && supportCue.value != SupportStage.independent) {
      supportCue.value = SupportStage.independent;
    }
    _handleSupport(e);
  }

  /// The character who lives in this world.
  CharacterId get host => recommendation.gameType.character;

  /// 1..5 -- read your tuning table with [byLevel].
  int get level => recommendation.level;
  DifficultyLevel get difficulty => recommendation.difficulty;
  GamePace get pace => recommendation.pace;

  /// Movement-speed multiplier from the pace (0.75 / 1.0 / 1.3).
  double get speed => pace.speed;

  /// Duration multiplier from the pace (1.33 / 1.0 / 0.77).
  double get timeScale => pace.timeScale;

  /// How the check-in feeling changes the way this game is PRESENTED —
  /// motion, decoration, target size, response room, how soon help is
  /// offered. Separate from [level] and [pace], which the engine already
  /// sets from the same feeling.
  ///
  /// Read it in a game: `if (c.mood.reducedMotion) ...`.
  MoodPresentation get mood =>
      MoodPresentation.forEmotion(recommendation.emotion);

  /// Touch-target multiplier for this session. Apply to hit areas, not to
  /// the number of targets or how fast they move.
  double get targetScale => mood.targetScale;

  /// Response-window multiplier for THIS activity.
  ///
  /// Always 1.0 for Sleepy Fox and Sorting Stars: their timing is the
  /// research measure, so it is never stretched for comfort. Everywhere
  /// else a worried child gets a little longer.
  double get windowScale => mood.windowScaleFor(recommendation.gameType);

  /// One value per level: `c.byLevel(6, 8, 10, 12, 14)`.
  T byLevel<T>(T l1, T l2, T l3, T l4, T l5) =>
      pickByLevel<T>(level, l1, l2, l3, l4, l5);

  // ---- statistics (written by games, read by the shell) --------------
  int successes = 0;
  int mistakes = 0;
  int touches = 0;
  int score = 0;
  int completedUnits = 0;
  int totalUnits = 0;
  bool completed = false;
  final List<int> responseTimesMs = [];

  /// Short line shown on the completion card (host character).
  String? finishLine;

  int get attempts => successes + mistakes;
  int get interactions => touches + successes + mistakes;

  double? get accuracy => attempts == 0
      ? null
      : (successes / attempts).clamp(0.0, 1.0).toDouble();

  double? get avgResponseMs => responseTimesMs.isEmpty
      ? null
      : responseTimesMs.reduce((a, b) => a + b) / responseTimesMs.length;

  /// 0..1, drives the small progress bar in the header.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// The current character line (null = nothing to say right now).
  final ValueNotifier<CharacterSay?> say = ValueNotifier<CharacterSay?>(null);
  Timer? _sayTimer;
  bool _disposed = false;

  /// Set by the shell while the pause screen is open. Games that use
  /// [schedule] are frozen automatically, and the event clock stops.
  bool _paused = false;
  bool get paused => _paused;
  set paused(bool v) {
    if (v == _paused) return;
    _paused = v;
    if (v) {
      _clock.stop();
    } else {
      _clock.start();
    }
  }

  /// Event-level log for the research dataset (capped to stay small).
  static const int maxEvents = 600;
  final List<TrialEvent> events = [];
  final Stopwatch _clock = Stopwatch()..start();

  void _log(String type, [double? value]) {
    if (events.length >= maxEvents) return;
    events.add(TrialEvent(_clock.elapsedMilliseconds, type, value));
  }
  final List<Timer> _timers = [];

  /// Like Timer(), but the delay only counts while the game is NOT paused,
  /// so a pause freezes it. Cancelled automatically when the game ends.
  Timer schedule(int ms, VoidCallback callback) {
    var remaining = ms;
    late Timer t;
    t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_disposed) {
        t.cancel();
        return;
      }
      if (paused) return;
      remaining -= 50;
      if (remaining <= 0) {
        t.cancel();
        _timers.remove(t);
        callback();
      }
    });
    _timers.add(t);
    return t;
  }

  /// Standard deviation of response times in ms (null if fewer than 3).
  double? get responseVariabilityMs => GameSession.stdDev(responseTimesMs);

  final List<FeedbackBurst> bursts = [];
  int _nextBurstId = 0;

  /// A right moment (caught a bubble, matched a pair, correct answer).
  void recordSuccess({int points = 1}) {
    successes++;
    score += points;
    _log('success');
    _afterAttempt(true);
  }

  /// A gentle "oops" (wrong card, bubble floated away). Data only -- the
  /// child never sees a penalty for it.
  void recordMistake() {
    mistakes++;
    _log('mistake');
    _afterAttempt(false);
  }

  /// A neutral touch that is neither right nor wrong (a drag step, a
  /// tap in a breathing game).
  void recordTouch() {
    touches++;
    _log('touch');
  }

  /// Adds a labelled marker event (commission, perseveration, omission,
  /// rule_change) WITHOUT changing the success/mistake counters. Pair it with
  /// [recordMistake] when the marker is also an error.
  void recordTagged(String type) {
    assert(TrialEvent.types.contains(type));
    _log(type);
  }

  /// Time a child took to respond to something (secondary indicator).
  void recordResponse(int ms) {
    if (ms <= 0 || ms > 600000) return;
    responseTimesMs.add(ms);
    _log('response', ms.toDouble());
  }

  /// Tracks "3 of 8 pairs" style progress and updates the header bar.
  void setUnits(int done, int total) {
    completedUnits = done;
    totalUnits = total;
    setProgress(total <= 0 ? 0.0 : done / total);
  }

  void setProgress(double value) {
    final v = value.clamp(0.0, 1.0).toDouble();
    if ((v - progress.value).abs() < 0.002) return;
    progress.value = v;
  }

  /// Make a character speak / react.
  ///
  /// Defaults to THE CHILD'S OWN FRIEND, not the world's host: the companion
  /// the child made is the one voice that follows them through every screen.
  /// Pass `who` only when the line belongs to a game's own character.
  void react(CharacterState state, String text,
      {CharacterId? who, int ms = 2600}) {
    if (_disposed) return;
    say.value = CharacterSay(who, state, text);
    _sayTimer?.cancel();
    _sayTimer = Timer(Duration(milliseconds: ms), () {
      if (!_disposed) say.value = null;
    });
  }

  /// The game is finished. The shell logs the session and shows the
  /// completion screen.
  void complete() {
    if (completed) return;
    completed = true;
    progress.value = 1;
    notifyListeners();
  }

  void burst(Offset position, String emoji) {
    bursts.add(FeedbackBurst(
      id: _nextBurstId++,
      position: position,
      emoji: emoji,
    ));
    // Never let a runaway game pile up dozens of floating emoji.
    if (bursts.length > 12) bursts.removeAt(0);
    notifyListeners();
  }

  void removeBurst(int id) {
    bursts.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    supportCue.dispose();
    _sayTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    progress.dispose();
    say.dispose();
    super.dispose();
  }
}
