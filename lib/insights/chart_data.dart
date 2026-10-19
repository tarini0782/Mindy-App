import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';

/// Series for the researcher charts, computed ONLY from stored sessions.
/// Empty input gives empty series; nothing is ever invented.
class ChartData {
  ChartData._();

  /// Mood score (1-5) before each session, oldest -> newest. null = skipped.
  static List<double?> emotionBefore(List<GameSession> s) =>
      [for (final x in s) x.emotionBefore?.moodScore.toDouble()];

  static List<double?> emotionAfter(List<GameSession> s) =>
      [for (final x in s) x.emotionAfter?.moodScore.toDouble()];

  static List<double?> moodDelta(List<GameSession> s) =>
      [for (final x in s) x.moodDelta?.toDouble()];

  /// Difficulty level (1-5) per session.
  static List<double?> level(List<GameSession> s) =>
      [for (final x in s) x.level.toDouble()];

  /// Completion per session: 1 finished, 0 not finished.
  static List<double?> completion(List<GameSession> s) =>
      [for (final x in s) x.completed ? 1.0 : 0.0];

  /// Running completion rate (0-100 %) after each session.
  static List<double?> runningCompletionPercent(List<GameSession> s) {
    final out = <double?>[];
    var done = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i].completed) done++;
      out.add(100.0 * done / (i + 1));
    }
    return out;
  }

  static List<double?> responseMs(List<GameSession> s) =>
      [for (final x in s) x.avgResponseMs];

  static List<double?> accuracyPercent(List<GameSession> s) =>
      [for (final x in s) x.accuracy == null ? null : x.accuracy! * 100];

  /// Index of the activity in GameType order, for the sequence strip.
  static List<int> activitySequence(List<GameSession> s) =>
      [for (final x in s) GameType.values.indexOf(x.game)];

  /// For regulation sessions only: [mood delta] per session (null elsewhere).
  static List<double?> regulationDelta(List<GameSession> s) => [
        for (final x in s)
          (x.game.isRegulation && x.completed) ? x.moodDelta?.toDouble() : null,
      ];

  static bool hasValues(List<double?> v) => v.any((e) => e != null);
}
