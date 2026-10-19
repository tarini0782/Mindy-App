import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_difficulty.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';

int _n = 0;

/// Builds a stored-style session for tests. [at] defaults to an increasing
/// clock so history is chronological.
GameSession makeSession(
  GameType game, {
  int level = 3,
  EmotionState? before = EmotionState.neutral,
  EmotionState? after,
  bool completed = true,
  int successes = 8,
  int mistakes = 2,
  int interactions = 10,
  int pauses = 0,
  bool? playAgain,
  double? avgMs,
  double? sdMs,
  DateTime? at,
  String condition = 'ADAPTIVE',
}) {
  _n++;
  final rec = AdaptiveGameEngine.recommend(emotion: before);
  final s = GameSession(
    sessionId: 's$_n',
    anonymousChildId: 'child-test',
    game: game,
    level: level,
    difficulty: levelToDifficulty(level),
    pace: rec.pace,
    condition: condition,
    trace: rec.trace,
    startTime: at ?? DateTime(2026, 1, 1).add(Duration(minutes: _n * 10)),
    emotionBefore: before,
    emotionSource: 'APP',
    checkInDurationMs: 1500,
    previousEmotion: null,
  )
    ..completed = completed
    ..completionPercent = completed ? 1.0 : 0.2
    ..successes = successes
    ..mistakes = mistakes
    ..interactions = interactions
    ..pausedCount = pauses
    ..durationSeconds = 90
    ..emotionAfter = after
    ..playAgain = playAgain
    ..avgResponseMs = avgMs
    ..responseTimeVariabilityMs = sdMs
    ..loadTimeMs = 600;
  return s;
}

/// Same as [makeSession] but for a specific child code (to test scoping).
GameSession makeSessionFor(String childId, GameType game,
    {bool completed = true}) {
  final s = makeSession(game, completed: completed);
  return GameSession.fromJson({...s.toJson(), 'anonymousChildId': childId});
}
