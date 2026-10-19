import '../../characters/character_lines.dart';
import '../../models/adaptive_state.dart';
import '../../models/decision_trace.dart';
import '../../models/emotion_state.dart';
import '../../models/study_condition.dart';
import '../models/game_difficulty.dart';
import '../models/game_pace.dart';
import '../models/game_recommendation.dart';
import '../models/game_session.dart';
import '../models/game_type.dart';

/// THE adaptive decision engine. Pure Dart: no Flutter, no storage, no
/// randomness, no clock except the [now] it is given. The same inputs
/// always give the same decision, and every decision explains itself.
///
///   SENSE   child self-report (emotion)  -> [recommend] input
///   DECIDE  this class (two layers, below)
///   PLAY    child plays the selected activity
///   LEARN   the session is stored; [AdaptiveChildState] is rebuilt from
///           the stored history before the next decision
///
/// LAYER 1 -- WHAT activity?
///   A deterministic suitability score per activity:
///     emotionalCompatibility + recentMoodResponse + engagementHistory
///     + performanceFit + regulationNeed + gentleStepUp
///     - previousActivity - repetition - recoveryPenalty
///   limited first by SAFETY RULES (scared/sad only get calm activities).
///
/// LAYER 2 -- HOW difficult (level 1-5)?
///   The emotion sets an allowed level range (comfort first). Inside it the
///   activity's own previous level is nudged by at most ONE step, and only
///   from consistent evidence over several recent sessions (never mid-session,
///   never for scared/sad).
///
/// All thresholds below are ENGINEERING RULES to be evaluated in the study.
/// They are not clinical thresholds and are not validated norms.
class AdaptiveGameEngine {
  AdaptiveGameEngine._();

  /// Activities in one journey ("adventure").
  static const int journeyLength = 6;

  /// Predetermined order used by FIXED_BASELINE and DIFFICULTY_ONLY.
  /// The activities a scared, skipped or sad check-in may receive.
  static Set<GameType> get calmPool => _compat['calmOnly']!.keys.toSet();

  static const List<GameType> fixedSequence = [
    GameType.bubbleValley,
    GameType.memoryCastle,
    GameType.breathingGarden,
    GameType.patternPower,
    GameType.rainbowPuzzle,
    GameType.treasureJourney,
  ];

  static const int fixedLevel = 3; // "medium"

  /// EVALUATION ONLY (docs/RESEARCH_REPORT.md section 7). The nine activities
  /// the rater study draws from, in all three conditions, so that a measured
  /// difference cannot be explained by one condition having a larger or more
  /// varied library than another.
  ///
  /// Why nine and not the six of [fixedSequence]: those six contain NO
  /// medical-familiarisation activity (Teddy Clinic is not among them) and
  /// only three calm-pool members, so a restricted check-in would face the
  /// same three options in every condition. Teddy Clinic, Firefly Jar and
  /// Sleepy Fox are added to fix both.
  ///
  /// This list is never used by normal play; it is passed explicitly.
  static const List<GameType> studyPool = [
    GameType.bubbleValley,
    GameType.memoryCastle,
    GameType.breathingGarden,
    GameType.patternPower,
    GameType.rainbowPuzzle,
    GameType.treasureJourney,
    GameType.teddyClinic,
    GameType.fireflyJar,
    GameType.sleepyFox,
  ];

  /// Sessions that must agree before a performance step is applied.
  static const int evidenceNeeded = 2;

  // ----------------------------------------------------------- tables

  static const Map<String, Map<GameType, double>> _compat = {
    // Low-arousal pool for scared / skipped / sad check-ins: no timers, no
    // hazards, no competing. Eight activities so a six-step adventure never
    // has to repeat one. (Chosen by role and design; to be reviewed by the
    // clinical supervisor before any study.)
    'calmOnly': {
      GameType.breathingGarden: 4,
      GameType.fireflyJar: 4, // second ACTIVE regulation option, v27
      GameType.treasureJourney: 2, // was 3: deprioritised, see docs/IMPLEMENTATION_REPORT.md v27
      GameType.sleepyFox: 3,
      GameType.petCare: 3,
      GameType.teddyClinic: 2,
      GameType.peekaboo: 2,
      GameType.bubbleValley: 2,
      GameType.beeCollector: 2,
    },
    'sad': {
      GameType.breathingGarden: 3,
      GameType.fireflyJar: 3,
      GameType.treasureJourney: 2, // was 3: deprioritised, see docs/IMPLEMENTATION_REPORT.md v27
      GameType.bubbleValley: 4, // gentle supportive step after regulation (spec example)
      GameType.sleepyFox: 3,
      GameType.petCare: 3,
      GameType.teddyClinic: 2,
      GameType.peekaboo: 2,
      GameType.beeCollector: 2,
    },
    'neutral': {
      GameType.bubbleValley: 3,
      GameType.memoryCastle: 3,
      GameType.rainbowPuzzle: 3,
      GameType.patternPower: 2,
      GameType.treasureJourney: 1,
      GameType.breathingGarden: 1,
      GameType.fireflyJar: 1,
      GameType.bubbleShooter: 3,
      GameType.happyConnect: 3,
      GameType.peekaboo: 3,
      GameType.cloudHop: 2,
      GameType.ruleShift: 1,
      GameType.sleepyFox: 3,
      GameType.jellyfishCatcher: 3,
      GameType.heroShield: 2,
      GameType.memoryQuest: 3,
      GameType.turboCar: 2,
      GameType.dinoDash: 2,
      GameType.beeCollector: 3,
      GameType.birdLauncher: 3,
      GameType.carrotCatch: 3,
      GameType.teddyClinic: 3,
      GameType.skyFlight: 2,
      GameType.petCare: 3,
      GameType.cloudBounce: 3,
      GameType.fruitSlice: 3,
      GameType.danceParty: 3,
    },
    'calm': {
      GameType.patternPower: 3,
      GameType.memoryCastle: 3,
      GameType.rainbowPuzzle: 3,
      GameType.bubbleValley: 2,
      GameType.treasureJourney: 2,
      GameType.breathingGarden: 1,
      GameType.fireflyJar: 1,
      GameType.bubbleShooter: 3,
      GameType.happyConnect: 3,
      GameType.cloudHop: 3,
      GameType.peekaboo: 2,
      GameType.ruleShift: 3,
      GameType.sleepyFox: 3,
      GameType.jellyfishCatcher: 3,
      GameType.heroShield: 3,
      GameType.memoryQuest: 3,
      GameType.turboCar: 3,
      GameType.dinoDash: 3,
      GameType.beeCollector: 3,
      GameType.birdLauncher: 3,
      GameType.carrotCatch: 3,
      GameType.teddyClinic: 3,
      GameType.skyFlight: 3,
      GameType.petCare: 3,
      GameType.cloudBounce: 2,
      GameType.fruitSlice: 2,
      GameType.danceParty: 3,
    },
    'happy': {
      GameType.patternPower: 4,
      GameType.bubbleValley: 3,
      GameType.rainbowPuzzle: 3,
      GameType.memoryCastle: 3,
      GameType.treasureJourney: 1,
      GameType.breathingGarden: 0,
      GameType.fireflyJar: 0,
      GameType.bubbleShooter: 3,
      GameType.happyConnect: 2,
      GameType.cloudHop: 3,
      GameType.peekaboo: 3,
      GameType.ruleShift: 4,
      GameType.sleepyFox: 3,
      GameType.jellyfishCatcher: 3,
      GameType.heroShield: 4,
      GameType.memoryQuest: 3,
      GameType.turboCar: 3,
      GameType.dinoDash: 3,
      GameType.beeCollector: 2,
      GameType.birdLauncher: 3,
      GameType.carrotCatch: 3,
      GameType.teddyClinic: 3,
      GameType.skyFlight: 3,
      GameType.petCare: 2,
      GameType.cloudBounce: 4,
      GameType.fruitSlice: 4,
      GameType.danceParty: 3,
    },
  };

  static String _bucket(EmotionState? e) {
    switch (e) {
      case null:
      case EmotionState.scared:
        return 'calmOnly';
      case EmotionState.sad:
        return 'sad';
      case EmotionState.neutral:
        return 'neutral';
      case EmotionState.calm:
        return 'calm';
      case EmotionState.happy:
        return 'happy';
    }
  }

  /// Safety rule: scared / sad / skipped may only be offered calm activities.
  static bool _restricted(EmotionState? e) =>
      e == null || e == EmotionState.scared || e == EmotionState.sad;

  /// Allowed level range for the emotion (comfort first).
  static (int, int) levelRange(EmotionState? e) {
    switch (e) {
      case null:
      case EmotionState.scared:
      case EmotionState.sad:
        return (1, 1); // EASY
      case EmotionState.neutral:
        return (2, 3); // easy-to-medium, starts at medium
      case EmotionState.calm:
      case EmotionState.happy:
        return (3, 5); // medium to hard depending on evidence
    }
  }

  static String ruleIdFor(EmotionState? e) {
    switch (e) {
      case null:
        return 'S0';
      case EmotionState.scared:
        return 'S1';
      case EmotionState.sad:
        return 'S2';
      case EmotionState.neutral:
        return 'N1';
      case EmotionState.calm:
        return 'C1';
      case EmotionState.happy:
        return 'H1';
    }
  }

  // --------------------------------------------------------- recommend

  /// [history] must be chronological (oldest first).
  static GameRecommendation recommend({
    required EmotionState? emotion,
    EmotionSource source = EmotionSource.app,
    StudyCondition condition = StudyCondition.adaptive,
    List<GameSession> history = const [],
    int journeyStep = 0,
    Set<String> avoidIds = const {}, // activities already played in this adventure
    DateTime? now,
    // ---- EVALUATION PARAMETERS. Both default to the shipped behaviour, so
    // normal play and every existing test are unaffected when they are
    // omitted. They exist so the rater study can make a fair comparison
    // (docs/RESEARCH_REPORT.md section 7).
    //
    // [pool] restricts which activities may be selected, in EVERY condition.
    // [equalSafetyFloor] applies the scared/sad/skipped restriction (calm
    // activities only, lowest level, slow pace) in EVERY condition, not just
    // ADAPTIVE. Without it the baseline is both a confound and an ethics
    // problem, because it is deliberately less responsive to distress.
    List<GameType>? pool,
    bool equalSafetyFloor = false,
  }) {
    final when = now ?? DateTime.now();
    final state = AdaptiveChildState.fromHistory(history, emotion);

    // A restricted check-in under [equalSafetyFloor]: every condition draws
    // from the calm pool at the emotion's floor level and slow pace. The
    // non-adaptive conditions still do not adapt -- they cycle the safe
    // activities in a fixed order by journey step, so the only thing that
    // differs between conditions is HOW the safe options are chosen.
    final floored = equalSafetyFloor && _restricted(emotion);
    if (floored && condition != StudyCondition.adaptive) {
      final safe = <GameType>[
        for (final g in (pool ?? GameType.values))
          if (calmPool.contains(g)) g,
      ];
      // Fail-safe: a calm activity that is ALSO inside the pool, because a
      // restricted pool must never be violated -- not even by a fallback.
      final game = safe.isEmpty
          ? ((pool == null || pool.contains(GameType.breathingGarden))
              ? GameType.breathingGarden
              : pool.first)
          : safe[journeyStep % safe.length];
      final floor = levelRange(emotion).$1;
      return _build(
        when: when,
        condition: condition,
        step: journeyStep,
        emotion: emotion,
        source: source,
        state: state,
        game: game,
        level: floor,
        baseline: floor,
        modifier: 0,
        modifierReason: 'none (shared safety floor)',
        pace: GamePace.slow,
        ruleId: condition == StudyCondition.fixedBaseline ? 'F1S' : 'D1S',
        scores: const [],
        recovery: false,
        reasons: [
          'Shared safety floor: a '
              '${emotion?.label.toLowerCase() ?? 'skipped'} check-in receives a '
              'calm activity at the easiest level and slow pace in every study '
              'condition. Within that restriction this condition does not '
              'adapt: it takes the next safe activity in a fixed order.'
        ],
      );
    }

    // ---- FIXED_BASELINE: nothing adapts ------------------------------
    if (condition == StudyCondition.fixedBaseline) {
      final seq = pool ?? fixedSequence;
      final game = seq[journeyStep % seq.length];
      return _build(
        when: when,
        condition: condition,
        step: journeyStep,
        emotion: emotion,
        source: source,
        state: state,
        game: game,
        level: fixedLevel,
        baseline: fixedLevel,
        modifier: 0,
        modifierReason: 'none (fixed baseline)',
        pace: GamePace.normal,
        ruleId: 'F1',
        scores: const [],
        recovery: false,
        reasons: [
          'Fixed baseline condition: the activity order and difficulty are '
              'predetermined and the reported feeling does not change them.'
        ],
      );
    }

    // ---- LAYER 1: which activity? ------------------------------------
    final scores = _scoreAll(emotion, state, history, avoidIds, pool);
    GameType game;
    var ruleId = ruleIdFor(emotion);
    var reasons = <String>[];
    var recovery = false;

    if (condition == StudyCondition.difficultyOnly) {
      final seq = pool ?? fixedSequence;
      game = seq[journeyStep % seq.length];
      ruleId = 'D1';
      reasons = [
        'Difficulty-only condition: the activity order is fixed; only the '
            'level adapts to the reported feeling.'
      ];
    } else {
      final pick = _select(scores, history, pool);
      game = pick;
      final comps = scores.firstWhere((s) => s.activityId == game.id).components;
      recovery = _lastWasPoor(state) &&
          state.previousActivity != null &&
          game.id != state.previousActivity;
      reasons = _reasonsFor(emotion, state, game, comps, recovery);
    }

    // ---- LAYER 2: how difficult? -------------------------------------
    final lv = _levelFor(game, emotion, state, history);
    final slow = _restricted(emotion) || lv.level <= 2;

    return _build(
      when: when,
      condition: condition,
      step: journeyStep,
      emotion: emotion,
      source: source,
      state: state,
      game: game,
      level: lv.level,
      baseline: lv.baseline,
      modifier: lv.modifier,
      modifierReason: lv.reason,
      pace: slow ? GamePace.slow : GamePace.normal,
      ruleId: ruleId,
      scores: scores,
      recovery: recovery,
      reasons: [
        ...reasons,
        if (lv.modifier != 0) 'Level step: ${lv.reason}.',
      ],
    );
  }

  // ----------------------------------------------------- layer 2: level

  static _LevelDecision _levelFor(GameType game, EmotionState? emotion,
      AdaptiveChildState state, List<GameSession> history) {
    final range = levelRange(emotion);
    final floor = range.$1, ceil = range.$2;

    final past = state.activityResponseHistory[game.id] ?? const [];
    int defaultStart;
    switch (emotion) {
      case null:
      case EmotionState.scared:
      case EmotionState.sad:
        defaultStart = 1;
        break;
      default:
        defaultStart = 3;
    }
    final prev = past.isEmpty ? null : past.last.level;
    var base = (prev ?? defaultStart).clamp(floor, ceil).toInt();

    var modifier = 0;
    var reason = 'none';
    final rangeShifted = prev != null && (prev < floor || prev > ceil);
    final eligible = !_restricted(emotion) && floor != ceil && !rangeShifted;
    if (!eligible) {
      if (_restricted(emotion)) {
        reason = 'comfort first: no performance change';
      } else if (rangeShifted) {
        reason = 'level range changed with the reported feeling: no extra '
            'performance step this time';
      }
    } else {
      // Evidence: this activity's last 2 banded sessions, else the last 3
      // banded sessions overall. Never a single session.
      final own = [
        for (final r in past)
          if (r.completed && r.band != null) r.band!,
      ];
      List<PerformanceBand> bands;
      int needed;
      String scope;
      if (own.length >= evidenceNeeded) {
        bands = own.sublist(own.length - evidenceNeeded);
        needed = evidenceNeeded;
        scope = 'the last $evidenceNeeded sessions of this activity';
      } else {
        final overall = [
          for (final s in history)
            if (s.performanceBand != null) s.performanceBand!,
        ];
        bands = overall.length > 3 ? overall.sublist(overall.length - 3) : overall;
        needed = 3;
        scope = 'the last 3 sessions overall';
      }
      if (bands.length < needed) {
        reason = 'not enough recent sessions yet';
      } else if (bands.every((b) => b == PerformanceBand.high)) {
        if (base < ceil) {
          modifier = 1;
          reason = 'consistently smooth play over $scope';
        } else {
          reason = 'already at the highest level for this feeling';
        }
      } else if (bands.every((b) => b == PerformanceBand.low)) {
        if (base > floor) {
          modifier = -1;
          reason = 'consistently tricky play over $scope';
        } else {
          reason = 'already at the lowest level for this feeling';
        }
      } else {
        reason = 'recent sessions mixed: no change';
      }
    }
    // The child's own words about the LAST session of this activity. They are
    // only used to step down (or up) by one and never go outside the range.
    if (eligible && modifier == 0 && past.isNotEmpty) {
      final said = past.last.perceivedDifficulty;
      if (said == 3 && base > floor) {
        modifier = -1;
        reason = 'the child said the last one felt hard';
      } else if (said == 1 && past.last.completed && base < ceil) {
        modifier = 1;
        reason = 'the child said the last one felt easy';
      }
    }
    var level = (base + modifier).clamp(floor, ceil).toInt();
    // Never jump from Easy straight to Hard: relative to this activity's
    // previous level the new level may rise by at most one step, unless the
    // emotion itself moved the allowed range (then it may only reach the
    // bottom of that range).
    if (prev != null) {
      final cap = (prev + 1) > floor ? (prev + 1) : floor;
      if (level > cap) {
        level = cap;
        reason = 'step limited: the level may not jump from Easy straight to Hard';
      }
    }
    return _LevelDecision(level, base, level - base, reason);
  }

  // ------------------------------------------------ layer 1: suitability

  static List<ActivityScoreTrace> _scoreAll(EmotionState? emotion,
      AdaptiveChildState state, List<GameSession> history,
      [Set<String> avoidIds = const {}, List<GameType>? pool]) {
    final bucket = _bucket(emotion);
    final restricted = _restricted(emotion);
    final compat = _compat[bucket]!;
    final out = <ActivityScoreTrace>[];

    final lastIds = history.map((s) => s.game.id).toList();
    final recent4 = lastIds.length > 4
        ? lastIds.sublist(lastIds.length - 4, lastIds.length - 1)
        : (lastIds.isEmpty ? <String>[] : lastIds.sublist(0, lastIds.length - 1));

    for (final g in GameType.values) {
      // An activity outside the study pool is never allowed, in any
      // condition. With no pool (normal play) nothing is excluded here.
      final allowed = compat.containsKey(g) && (pool == null || pool.contains(g));
      final comps = <String, double>{};
      comps['emotionalCompatibility'] = compat[g] ?? 0;

      final past = state.activityResponseHistory[g.id] ?? const [];
      final last3 = past.length > 3 ? past.sublist(past.length - 3) : past;

      // recentMoodResponse: how the child felt after this activity before.
      final deltas = [
        for (final r in last3)
          if (r.moodDelta != null) r.moodDelta!.toDouble(),
      ];
      comps['recentMoodResponse'] = deltas.isEmpty
          ? 0
          : (deltas.reduce((a, b) => a + b) / deltas.length)
              .clamp(-2.0, 2.0)
              .toDouble();

      // engagementHistory
      var eng = 0.0;
      if (last3.isNotEmpty) {
        final rate = last3.where((r) => r.completed).length / last3.length;
        if (rate >= 0.67) {
          eng += 1;
        } else if (rate <= 0.34 && last3.length >= 2) {
          eng -= 1;
        }
        if (last3.any((r) => r.playAgain == true)) eng += 0.5;
      }
      comps['engagementHistory'] = eng;

      // performanceFit (never used to override comfort)
      var fit = 0.0;
      if (!restricted) {
        PerformanceBand? band;
        for (final r in last3) {
          if (r.band != null) band = r.band;
        }
        if (band == PerformanceBand.normal) fit = 1;
        if (band == PerformanceBand.high) fit = 0.5;
        if (band == PerformanceBand.low) fit = -1;
      }
      comps['performanceFit'] = fit;

      // regulationNeed
      var need = 0.0;
      if (!restricted && g.isRegulation) {
        if (state.consecutiveDifficultSessions >= 2) need += 2;
        if (state.recentMoodChange == MoodChange.worsened) {
          need += 2;
        } else if (state.recentMoodChange == MoodChange.unchanged &&
            state.previousActivity != null) {
          final prevType = _typeOf(state.previousActivity!);
          if (prevType != null && !prevType.isRegulation) need += 1;
        }
      }
      comps['regulationNeed'] = need;

      // gentleStepUp: a soft interactive step after a regulation activity
      // helped a sad child feel better.
      var step = 0.0;
      if (emotion == EmotionState.sad &&
          g.role == ActivityRole.supportive &&
          state.recentMoodChange == MoodChange.improved &&
          state.previousActivity != null &&
          (_typeOf(state.previousActivity!)?.isRegulation ?? false)) {
        step = 2;
      }
      comps['gentleStepUp'] = step;

      // previousActivity + repetition avoidance
      comps['previousActivity'] =
          (state.previousActivity == g.id) ? -4 : 0;
      comps['repetitionAvoidance'] =
          -1.0 * recent4.where((id) => id == g.id).length;

      // recoveryPenalty: the last attempt of this activity went poorly.
      comps['recoveryPenalty'] =
          (past.isNotEmpty && past.last.poor) ? -3 : 0;

      // Variety: an activity already played in THIS adventure is strongly
      // discouraged (only chosen if nothing else is allowed), and an
      // activity never tried gets a small bonus so every child sees the
      // whole library over time.
      comps['alreadyThisAdventure'] = avoidIds.contains(g.id) ? -10 : 0;
      comps['novelty'] = past.isEmpty ? 1 : 0;

      final total = comps.values.fold<double>(0, (a, b) => a + b);
      out.add(ActivityScoreTrace(
        activityId: g.id,
        allowed: allowed,
        total: total,
        components: comps,
      ));
    }
    return out;
  }

  static GameType? _typeOf(String id) {
    for (final t in GameType.values) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Highest total among allowed activities; ties go to the activity played
  /// least so far, then to the fixed order. Fully deterministic.
  static GameType _select(List<ActivityScoreTrace> scores,
      List<GameSession> history, List<GameType>? pool) {
    final plays = <String, int>{};
    for (final s in history) {
      plays[s.game.id] = (plays[s.game.id] ?? 0) + 1;
    }
    GameType? best;
    double bestTotal = -1e9;
    int bestPlays = 1 << 30;
    for (final g in GameType.values) {
      final sc = scores.firstWhere((s) => s.activityId == g.id);
      if (!sc.allowed) continue;
      final p = plays[g.id] ?? 0;
      if (sc.total > bestTotal || (sc.total == bestTotal && p < bestPlays)) {
        best = g;
        bestTotal = sc.total;
        bestPlays = p;
      }
    }
    // Fail-safe when nothing scored as allowed. It must respect the pool:
    // returning Breathing Garden from outside a restricted pool would break
    // the guarantee the study comparison depends on.
    if (best != null) return best;
    if (pool == null || pool.contains(GameType.breathingGarden)) {
      return GameType.breathingGarden;
    }
    return pool.first;
  }

  static bool _lastWasPoor(AdaptiveChildState state) {
    final id = state.previousActivity;
    if (id == null) return false;
    final r = state.activityResponseHistory[id];
    return r != null && r.isNotEmpty && r.last.poor;
  }

  // ------------------------------------------------------------ wording

  static List<String> _reasonsFor(EmotionState? emotion,
      AdaptiveChildState state, GameType game, Map<String, double> comps,
      bool recovery) {
    final r = <String>[];
    if (_restricted(emotion)) {
      r.add('Emotion comes first: a ${emotion?.label.toLowerCase() ?? 'skipped'} '
          'check-in only receives a calm activity at the easiest level and '
          'slow pace.');
    } else {
      r.add('The activity suits how the child said they feel.');
    }
    if ((comps['gentleStepUp'] ?? 0) > 0) {
      r.add('Feeling improved after a regulation activity, so a gentle '
          'interactive activity was selected.');
    }
    if (recovery) {
      r.add('The previous activity did not go well (unfinished or no more '
          'positive feeling afterwards), so a different activity was chosen '
          'instead of repeating it.');
    } else if ((comps['regulationNeed'] ?? 0) > 0) {
      r.add('A calming activity was selected to support the child after a '
          'difficult recent session.');
    }
    if ((comps['recentMoodResponse'] ?? 0) > 0) {
      r.add('The child has tended to feel better after this activity.');
    }
    if ((comps['previousActivity'] ?? 0) == 0 &&
        state.previousActivity != null &&
        state.previousActivity != game.id) {
      r.add('It differs from the previous activity.');
    }
    return r;
  }

  static GameRecommendation _build({
    required DateTime when,
    required StudyCondition condition,
    required int step,
    required EmotionState? emotion,
    required EmotionSource source,
    required AdaptiveChildState state,
    required GameType game,
    required int level,
    required int baseline,
    required int modifier,
    required String modifierReason,
    required GamePace pace,
    required String ruleId,
    required List<ActivityScoreTrace> scores,
    required bool recovery,
    required List<String> reasons,
  }) {
    final diff = levelToDifficulty(level);
    final prevId = state.previousActivity;
    final prevType = prevId == null ? null : _typeOf(prevId);
    final mood = state.recentMoodChange.name;
    final eng = state.engagementLevel?.name ?? 'unknown';

    final evidence = state.recentAccuracy == null
        ? 'No accuracy evidence yet (or the recent activities have no '
            'right/wrong moments).'
        : 'Recent accuracy ${(state.recentAccuracy! * 100).round()}% '
            '(engagement indicator over the last up to 3 sessions); '
            'completion ${((state.completionRate ?? 0) * 100).round()}% '
            'over the last up to 5 sessions.';

    final human = StringBuffer()
      ..write('Emotion: ${emotion?.label.toUpperCase() ?? 'SKIPPED'} '
          '(${source.code}). ')
      ..write(prevType == null
          ? 'Previous activity: none. '
          : 'Previous activity: ${prevType.title} (level ${state.currentDifficulty}); '
              'self-reported feeling change: $mood; engagement: $eng. ')
      ..write('Selected: ${game.title} at level $level (${diff.label}), '
          '${pace.name} pace. ')
      ..write('Why: ${reasons.join(' ')}');

    final trace = DecisionTrace(
      timestamp: when,
      condition: condition.code,
      journeyStep: step,
      emotion: emotion?.code,
      emotionSource: source.code,
      previousActivity: prevId,
      previousLevel: state.currentDifficulty,
      recentMoodChange: mood,
      engagement: eng,
      performanceEvidence: evidence,
      selectedActivity: game.id,
      selectedLevel: level,
      selectedDifficulty: diff.label,
      selectedPace: pace.name,
      ruleId: ruleId,
      baselineLevel: baseline,
      modifier: modifier,
      modifierReason: modifierReason,
      recovery: recovery,
      humanReason: human.toString(),
      scores: scores,
      stateSnapshot: state.toJson(),
    );

    return GameRecommendation(
      gameType: game,
      level: level,
      pace: pace,
      trace: trace,
      childMessage: CharacterLines.mindyIntro(emotion,
          recovery: recovery, afterRegulation: _afterRegulationImproved(state)),
      hostMessage: game.invite,
    );
  }

  static bool _afterRegulationImproved(AdaptiveChildState state) {
    final id = state.previousActivity;
    if (id == null) return false;
    final t = _typeOf(id);
    return t != null &&
        t.isRegulation &&
        state.recentMoodChange == MoodChange.improved;
  }
}

class _LevelDecision {
  final int level;
  final int baseline;
  final int modifier;
  final String reason;
  const _LevelDecision(this.level, this.baseline, this.modifier, this.reason);
}
