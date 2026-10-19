import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import 'emotion_state.dart';

/// How comfortable the child's reported feeling suggests they are.
/// A gameplay-adaptation label, not a clinical judgement.
enum EmotionalComfort { needsSupport, steady, comfortable }

EmotionalComfort comfortOf(EmotionState? e) {
  switch (e) {
    case null:
    case EmotionState.scared:
    case EmotionState.sad:
      return EmotionalComfort.needsSupport;
    case EmotionState.neutral:
      return EmotionalComfort.steady;
    case EmotionState.calm:
    case EmotionState.happy:
      return EmotionalComfort.comfortable;
  }
}

/// One past attempt of one activity, as the engine remembers it.
class ActivityResponse {
  final bool completed;
  final int? moodDelta;
  final int level;
  final PerformanceBand? band;
  final bool? playAgain;
  final EngagementLevel engagement;
  final int? perceivedDifficulty; // child's answer: 1 easy, 2 right, 3 hard
  const ActivityResponse({
    required this.completed,
    required this.moodDelta,
    required this.level,
    required this.band,
    required this.playAgain,
    required this.engagement,
    this.perceivedDifficulty,
  });

  /// "Poor response": the attempt was low-engagement or unfinished AND the
  /// self-reported feeling afterwards was unchanged, worse or not given.
  bool get poor =>
      (!completed || engagement == EngagementLevel.low) &&
      (moodDelta == null || moodDelta! <= 0);
}

/// The adaptation state the engine reasons over. It is rebuilt
/// deterministically from the stored session history every time, so the
/// same history always gives the same state. It is a GAMEPLAY/ADAPTATION
/// state, NOT a medical or psychological record.
class AdaptiveChildState {
  final EmotionState? currentEmotion;
  final EmotionState? previousEmotion;
  final EmotionalComfort emotionalComfort;

  final String? currentActivity; // set by the engine after selection
  final String? previousActivity;
  final int? currentDifficulty; // level of the previous session (1..5)

  final double? recentAccuracy; // mean of the last up to 3 sessions
  final double? recentResponseTimeMs;
  final double? responseTimeVariabilityMs;
  final double? completionRate; // last up to 5 sessions, 0..1
  final EngagementLevel? engagementLevel; // of the last session
  final MoodChange recentMoodChange; // of the last session

  final int consecutiveSuccessfulSessions;
  final int consecutiveDifficultSessions;
  final int regulationActivitiesCompleted;
  final double? replayRate; // yes answers / answered, 0..1

  final List<String> activityHistory; // chronological ids, last 10
  final Map<String, List<ActivityResponse>> activityResponseHistory;

  final int sessionCount;

  const AdaptiveChildState({
    required this.currentEmotion,
    required this.previousEmotion,
    required this.emotionalComfort,
    required this.currentActivity,
    required this.previousActivity,
    required this.currentDifficulty,
    required this.recentAccuracy,
    required this.recentResponseTimeMs,
    required this.responseTimeVariabilityMs,
    required this.completionRate,
    required this.engagementLevel,
    required this.recentMoodChange,
    required this.consecutiveSuccessfulSessions,
    required this.consecutiveDifficultSessions,
    required this.regulationActivitiesCompleted,
    required this.replayRate,
    required this.activityHistory,
    required this.activityResponseHistory,
    required this.sessionCount,
  });

  static const AdaptiveChildState empty = AdaptiveChildState(
    currentEmotion: null,
    previousEmotion: null,
    emotionalComfort: EmotionalComfort.needsSupport,
    currentActivity: null,
    previousActivity: null,
    currentDifficulty: null,
    recentAccuracy: null,
    recentResponseTimeMs: null,
    responseTimeVariabilityMs: null,
    completionRate: null,
    engagementLevel: null,
    recentMoodChange: MoodChange.unknown,
    consecutiveSuccessfulSessions: 0,
    consecutiveDifficultSessions: 0,
    regulationActivitiesCompleted: 0,
    replayRate: null,
    activityHistory: [],
    activityResponseHistory: {},
    sessionCount: 0,
  );

  /// [history] must be CHRONOLOGICAL (oldest first).
  factory AdaptiveChildState.fromHistory(
      List<GameSession> history, EmotionState? currentEmotion) {
    if (history.isEmpty) {
      return AdaptiveChildState(
        currentEmotion: currentEmotion,
        previousEmotion: null,
        emotionalComfort: comfortOf(currentEmotion),
        currentActivity: null,
        previousActivity: null,
        currentDifficulty: null,
        recentAccuracy: null,
        recentResponseTimeMs: null,
        responseTimeVariabilityMs: null,
        completionRate: null,
        engagementLevel: null,
        recentMoodChange: MoodChange.unknown,
        consecutiveSuccessfulSessions: 0,
        consecutiveDifficultSessions: 0,
        regulationActivitiesCompleted: 0,
        replayRate: null,
        activityHistory: const [],
        activityResponseHistory: const {},
        sessionCount: 0,
      );
    }
    final last = history.last;

    double? mean(Iterable<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

    final recent3 = history.length > 3 ? history.sublist(history.length - 3) : history;
    final recent5 = history.length > 5 ? history.sublist(history.length - 5) : history;

    final accs = <double>[
      for (final s in recent3)
        if (s.accuracy != null) s.accuracy!,
    ];
    final rts = <double>[
      for (final s in recent3)
        if (s.avgResponseMs != null) s.avgResponseMs!,
    ];
    final vars = <double>[
      for (final s in recent3)
        if (s.responseTimeVariabilityMs != null) s.responseTimeVariabilityMs!,
    ];

    // Trailing streaks.
    var successStreak = 0;
    for (var i = history.length - 1; i >= 0; i--) {
      final s = history[i];
      final band = s.performanceBand;
      final ok = s.completed &&
          (band == null
              ? s.moodChange != MoodChange.worsened
              : band != PerformanceBand.low);
      if (!ok) break;
      successStreak++;
    }
    var difficultStreak = 0;
    for (var i = history.length - 1; i >= 0; i--) {
      final s = history[i];
      final hard = !s.completed ||
          s.performanceBand == PerformanceBand.low ||
          s.moodChange == MoodChange.worsened;
      if (!hard) break;
      difficultStreak++;
    }

    final answered = history.where((s) => s.playAgain != null).toList();
    final yes = answered.where((s) => s.playAgain == true).length;

    final responses = <String, List<ActivityResponse>>{};
    for (final s in history) {
      responses.putIfAbsent(s.game.id, () => []).add(ActivityResponse(
            completed: s.completed,
            moodDelta: s.moodDelta,
            level: s.level,
            band: s.performanceBand,
            playAgain: s.playAgain,
            engagement: s.engagement,
            perceivedDifficulty: s.perceivedDifficulty,
          ));
    }

    final hist = history.map((s) => s.game.id).toList();
    final lastIds = hist.length > 10 ? hist.sublist(hist.length - 10) : hist;

    return AdaptiveChildState(
      currentEmotion: currentEmotion,
      previousEmotion: last.emotionAfter ?? last.emotionBefore,
      emotionalComfort: comfortOf(currentEmotion),
      currentActivity: null,
      previousActivity: last.game.id,
      currentDifficulty: last.level,
      recentAccuracy: mean(accs),
      recentResponseTimeMs: mean(rts),
      responseTimeVariabilityMs: mean(vars),
      completionRate:
          recent5.where((s) => s.completed).length / recent5.length,
      engagementLevel: last.engagement,
      recentMoodChange: last.moodChange,
      consecutiveSuccessfulSessions: successStreak,
      consecutiveDifficultSessions: difficultStreak,
      regulationActivitiesCompleted:
          history.where((s) => s.completed && s.game.isRegulation).length,
      replayRate: answered.isEmpty ? null : yes / answered.length,
      activityHistory: lastIds,
      activityResponseHistory: responses,
      sessionCount: history.length,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentEmotion': currentEmotion?.code,
        'previousEmotion': previousEmotion?.code,
        'emotionalComfort': emotionalComfort.name,
        'previousActivity': previousActivity,
        'currentDifficulty': currentDifficulty,
        'recentAccuracy': recentAccuracy,
        'recentResponseTimeMs': recentResponseTimeMs,
        'responseTimeVariabilityMs': responseTimeVariabilityMs,
        'completionRate': completionRate,
        'engagementLevel': engagementLevel?.name,
        'recentMoodChange': recentMoodChange.name,
        'consecutiveSuccessfulSessions': consecutiveSuccessfulSessions,
        'consecutiveDifficultSessions': consecutiveDifficultSessions,
        'regulationActivitiesCompleted': regulationActivitiesCompleted,
        'replayRate': replayRate,
        'activityHistory': activityHistory,
        'sessionCount': sessionCount,
      };
}
