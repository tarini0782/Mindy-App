import 'dart:math';
import '../../models/decision_trace.dart';
import '../../models/emotion_state.dart';
import 'game_difficulty.dart';
import 'game_pace.dart';
import 'game_recommendation.dart';
import 'game_type.dart';

/// Engineering rule (NOT a clinical threshold) summarising how a session
/// went for pacing purposes. Used only as a bounded secondary modifier.
enum PerformanceBand { low, normal, high }

enum SyncStatus { pending, synced, failed }

/// One logged moment during play (event-level data for the research dataset).
///   success   a right moment (popped a bubble, matched a pair...)
///   mistake   a gentle "oops" (wrong card, a miss...)
///   touch     a neutral tap or drag
///   response  how long the child took to respond (valueMs)
/// [tMs] = milliseconds of ACTIVE play since the activity opened (pauses
/// excluded). Stored compactly as [tMs, typeCode, valueMs].
class TrialEvent {
  static const List<String> types = [
    'success',
    'mistake',
    'touch',
    'response',
    // v10 additions (appended, so old stored codes stay valid)
    'commission', // tapped when the rule said do NOT tap (Sleepy Fox)
    'perseveration', // error right after a rule change, matching the OLD rule
    'omission', // a go-item was missed
    'rule_change', // the game switched its rule
    'support', // support offered; valueMs = stage index (1 cue .. 5 break)
    'difficulty', // difficulty lowered during play; valueMs = new level
  ];
  final int tMs;
  final String type;
  final double? valueMs;
  const TrialEvent(this.tMs, this.type, [this.valueMs]);

  List<Object?> toList() => [tMs, types.indexOf(type), valueMs];

  static TrialEvent? fromList(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    final code = (raw[1] as num).toInt();
    if (code < 0 || code >= types.length) return null;
    return TrialEvent((raw[0] as num).toInt(), types[code],
        raw.length > 2 && raw[2] != null ? (raw[2] as num).toDouble() : null);
  }
}

enum EngagementLevel { low, medium, high }

/// Engagement indicator from participation only (engineering rule, to be
/// evaluated): finished with few pauses = high; barely started = low.
EngagementLevel computeEngagement({
  required bool completed,
  required double completionPercent,
  required int interactions,
  required int pausedCount,
}) {
  if (interactions == 0 || (!completed && completionPercent < 0.34)) {
    return EngagementLevel.low;
  }
  if (completed && pausedCount <= 2) return EngagementLevel.high;
  return EngagementLevel.medium;
}

/// One play session (finished OR abandoned). This is the research record.
/// Characters and story are presentation only; everything below is recorded
/// identically for every activity.
class GameSession {
  final String sessionId;
  final String anonymousChildId; // random code, never a name
  final GameType game;
  final int level; // 1..5
  final DifficultyLevel difficulty;
  final GamePace pace;
  final String condition; // ADAPTIVE | DIFFICULTY_ONLY | FIXED_BASELINE
  final DecisionTrace trace; // why Mindy chose this
  final DateTime startTime;

  final EmotionState? emotionBefore;
  final String emotionSource; // APP | KARA | KARA_SIMULATED
  final int checkInDurationMs;
  final EmotionState? previousEmotion;

  DateTime? endTime;
  int durationSeconds = 0; // active play time, pauses excluded
  int pausedCount = 0;
  bool completed = false;
  double completionPercent = 0; // 0..1
  int score = 0;
  int successes = 0;
  int mistakes = 0;
  int interactions = 0;
  int completedUnits = 0;
  int totalUnits = 0;
  double? avgResponseMs;
  double? responseTimeVariabilityMs; // standard deviation, ms
  int? loadTimeMs;

  EmotionState? emotionAfter;
  bool? playAgain;

  /// Optional child answers (null = skipped). 1..3 scales, never required.
  int? enjoyment; // 1 not fun, 2 okay, 3 fun
  int? perceivedDifficulty; // 1 too easy, 2 just right, 3 too hard
  bool? midGameEnjoying; // answered on the break screen, if at all
  int childEasierRequests = 0; // child tapped 'make it easier'
  SyncStatus syncStatus = SyncStatus.pending;

  /// Event-level log (capped) and the researcher-entered age in years.
  List<TrialEvent> events = [];
  int? participantAge;

  /// Support summary (see SupportEngine). Needing help is not a deficit.
  int supportCount = 0;
  int maxSupportStage = 0; // 0 none .. 5 break offer
  int attemptsAfterSupport = 0;
  int successesAfterSupport = 0;
  int difficultyAdjustments = 0;

  GameSession({
    required this.sessionId,
    required this.anonymousChildId,
    required this.game,
    required this.level,
    required this.difficulty,
    required this.pace,
    required this.condition,
    required this.trace,
    required this.startTime,
    required this.emotionBefore,
    required this.emotionSource,
    required this.checkInDurationMs,
    required this.previousEmotion,
  });

  factory GameSession.fromRecommendation({
    required String sessionId,
    required String anonymousChildId,
    required EmotionState? emotion,
    required String emotionSource,
    required int checkInDurationMs,
    required EmotionState? previousEmotion,
    required GameRecommendation rec,
    required DateTime startTime,
  }) =>
      GameSession(
        sessionId: sessionId,
        anonymousChildId: anonymousChildId,
        game: rec.gameType,
        level: rec.level,
        difficulty: rec.difficulty,
        pace: rec.pace,
        condition: rec.trace.condition,
        trace: rec.trace,
        startTime: startTime,
        emotionBefore: emotion,
        emotionSource: emotionSource,
        checkInDurationMs: checkInDurationMs,
        previousEmotion: previousEmotion,
      );

  // ----------------------------------------------------------- derived

  /// How this session started: adventure | feed. (Free play is never stored.)
  String get trigger => trace.ruleId == 'FEED' ? 'feed' : 'adventure';

  int get attempts => successes + mistakes;

  /// successes / (successes + mistakes); null when the activity has no
  /// right/wrong moments (breathing, calm maze). A pacing signal only.
  double? get accuracy =>
      attempts == 0 ? null : (successes / attempts).clamp(0.0, 1.0).toDouble();

  /// After minus before on the 1-5 ordinal. null if either is missing.
  int? get moodDelta => moodDeltaValue(emotionBefore, emotionAfter);
  MoodChange get moodChange => moodChangeOf(moodDelta);

  static int? moodDeltaValue(EmotionState? b, EmotionState? a) =>
      computeMoodDelta(b, a);

  EngagementLevel get engagement => computeEngagement(
        completed: completed,
        completionPercent: completionPercent,
        interactions: interactions,
        pausedCount: pausedCount,
      );

  PerformanceBand? get performanceBand {
    // An activity with no right/wrong moments cannot have a performance
    // band, however many "successes" it logged. Without this, a calming
    // activity that only records successes scores 100% accuracy and can
    // push its own difficulty up. See GameTypeX.hasPerformanceData.
    if (!game.hasPerformanceData) return null;
    final acc = accuracy;
    if (acc == null || !completed) return null;
    if (acc < 0.5) return PerformanceBand.low;
    final mean = avgResponseMs;
    final sd = responseTimeVariabilityMs;
    final veryVariable =
        mean != null && sd != null && mean > 0 && (sd / mean) > 0.9;
    if (acc >= 0.85 && !veryVariable) return PerformanceBand.high;
    return PerformanceBand.normal;
  }

  String? get previousActivity => trace.previousActivity;
  int? get previousLevel => trace.previousLevel;

  /// Standard deviation of [values] (population), or null if < 3 values.
  static double? stdDev(List<int> values) {
    if (values.length < 3) return null;
    final mean = values.reduce((a, b) => a + b) / values.length;
    var sum = 0.0;
    for (final v in values) {
      sum += (v - mean) * (v - mean);
    }
    return sqrt(sum / values.length);
  }

  // ------------------------------------------------------------- JSON

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'anonymousChildId': anonymousChildId,
        'timestamp': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationSeconds': durationSeconds,
        'activity': game.id,
        'gameId': game.id,
        'world': game.worldKey,
        'character': game.character.name,
        'role': game.role.name,
        'level': level,
        'difficulty': difficulty.label,
        'pace': pace.name,
        'studyCondition': condition,
        'emotionBefore': emotionBefore?.code,
        'emotionAfter': emotionAfter?.code,
        'previousEmotion': previousEmotion?.code,
        'emotionSource': emotionSource,
        'checkInDurationMs': checkInDurationMs,
        'moodDelta': moodDelta,
        'completed': completed,
        'completionPercentage': (completionPercent * 100).round(),
        'pausedCount': pausedCount,
        'playAgain': playAgain,
        'enjoyment': enjoyment,
        'perceivedDifficulty': perceivedDifficulty,
        'midGameEnjoying': midGameEnjoying,
        'childEasierRequests': childEasierRequests,
        'accuracy': accuracy,
        'successes': successes,
        'mistakes': mistakes,
        'interactionCount': interactions,
        'completedUnits': completedUnits,
        'totalUnits': totalUnits,
        'averageResponseTimeMs': avgResponseMs,
        'responseTimeVariabilityMs': responseTimeVariabilityMs,
        'loadTimeMs': loadTimeMs,
        'recommendationReason': trace.humanReason,
        'trigger': trigger,
        'previousActivity': previousActivity,
        'previousDifficulty': previousLevel,
        'engagementIndicators': {
          'engagement': engagement.name,
          'performanceBand': performanceBand?.name,
        },
        'syncStatus': syncStatus.name,
        'participantAge': participantAge,
        'supportCount': supportCount,
        'maxSupportStage': maxSupportStage,
        'attemptsAfterSupport': attemptsAfterSupport,
        'successesAfterSupport': successesAfterSupport,
        'difficultyAdjustments': difficultyAdjustments,
        'events': events.map((e) => e.toList()).toList(),
        'decisionTrace': trace.toJson(),
      };

  factory GameSession.fromJson(Map<String, dynamic> j) {
    GameType game = GameType.breathingGarden;
    for (final t in GameType.values) {
      if (t.id == (j['activity'] ?? j['gameId'])) game = t;
    }
    final level = ((j['level'] as num?)?.toInt() ?? 1).clamp(kMinLevel, kMaxLevel).toInt();
    GamePace pace = GamePace.slow;
    for (final p in GamePace.values) {
      if (p.name == j['pace']) pace = p;
    }
    final s = GameSession(
      sessionId: (j['sessionId'] as String?) ?? '',
      anonymousChildId: (j['anonymousChildId'] as String?) ?? 'unknown',
      game: game,
      level: level,
      difficulty: levelToDifficulty(level),
      pace: pace,
      condition: (j['studyCondition'] as String?) ?? 'ADAPTIVE',
      trace: DecisionTrace.fromJson(
          Map<String, dynamic>.from((j['decisionTrace'] as Map?) ?? {})),
      startTime: DateTime.tryParse((j['timestamp'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      emotionBefore: emotionFromName(j['emotionBefore'] as String?),
      emotionSource: (j['emotionSource'] as String?) ?? 'APP',
      checkInDurationMs: (j['checkInDurationMs'] as num?)?.toInt() ?? 0,
      previousEmotion: emotionFromName(j['previousEmotion'] as String?),
    );
    s.endTime = DateTime.tryParse((j['endTime'] as String?) ?? '');
    s.durationSeconds = (j['durationSeconds'] as num?)?.toInt() ?? 0;
    s.pausedCount = (j['pausedCount'] as num?)?.toInt() ?? 0;
    s.completed = (j['completed'] as bool?) ?? false;
    s.completionPercent =
        ((j['completionPercentage'] as num?)?.toDouble() ?? 0) / 100.0;
    s.successes = (j['successes'] as num?)?.toInt() ?? 0;
    s.mistakes = (j['mistakes'] as num?)?.toInt() ?? 0;
    s.interactions = (j['interactionCount'] as num?)?.toInt() ?? 0;
    s.completedUnits = (j['completedUnits'] as num?)?.toInt() ?? 0;
    s.totalUnits = (j['totalUnits'] as num?)?.toInt() ?? 0;
    s.avgResponseMs = (j['averageResponseTimeMs'] as num?)?.toDouble();
    s.responseTimeVariabilityMs =
        (j['responseTimeVariabilityMs'] as num?)?.toDouble();
    s.loadTimeMs = (j['loadTimeMs'] as num?)?.toInt();
    s.emotionAfter = emotionFromName(j['emotionAfter'] as String?);
    s.playAgain = j['playAgain'] as bool?;
    int? scale(Object? v) {
      final n = (v as num?)?.toInt();
      return (n != null && n >= 1 && n <= 3) ? n : null;
    }
    s.enjoyment = scale(j['enjoyment']);
    s.perceivedDifficulty = scale(j['perceivedDifficulty']);
    s.midGameEnjoying = j['midGameEnjoying'] as bool?;
    s.childEasierRequests = (j['childEasierRequests'] as num?)?.toInt() ?? 0;
    for (final st in SyncStatus.values) {
      if (st.name == j['syncStatus']) s.syncStatus = st;
    }
    s.participantAge = (j['participantAge'] as num?)?.toInt();
    s.supportCount = (j['supportCount'] as num?)?.toInt() ?? 0;
    s.maxSupportStage = (j['maxSupportStage'] as num?)?.toInt() ?? 0;
    s.attemptsAfterSupport = (j['attemptsAfterSupport'] as num?)?.toInt() ?? 0;
    s.successesAfterSupport = (j['successesAfterSupport'] as num?)?.toInt() ?? 0;
    s.difficultyAdjustments = (j['difficultyAdjustments'] as num?)?.toInt() ?? 0;
    s.events = [
      for (final raw in (j['events'] as List? ?? const []))
        if (TrialEvent.fromList(raw) != null) TrialEvent.fromList(raw)!,
    ];
    return s;
  }
}
