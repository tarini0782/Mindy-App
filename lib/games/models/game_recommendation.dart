import '../../models/decision_trace.dart';
import '../../models/emotion_state.dart';
import '../../models/study_condition.dart';
import 'game_difficulty.dart';
import 'game_pace.dart';
import 'game_type.dart';

/// The output of ONE adaptive decision: which activity, which level, which
/// pace, plus the full [trace] and the only words a child ever sees about it.
class GameRecommendation {
  final GameType gameType;
  final int level; // 1..5
  final GamePace pace;
  final DecisionTrace trace;

  /// Mindy's friendly line on the transition screen.
  final String childMessage;

  /// The host character's invitation.
  final String hostMessage;

  const GameRecommendation({
    required this.gameType,
    required this.level,
    required this.pace,
    required this.trace,
    required this.childMessage,
    required this.hostMessage,
  });

  DifficultyLevel get difficulty => levelToDifficulty(level);
  bool get adaptive => trace.condition != StudyCondition.fixedBaseline.code;
  String get reason => trace.humanReason;
  EmotionState? get emotion => emotionFromName(trace.emotion);

  Map<String, dynamic> toJson() => {
        'game': gameType.id,
        'level': level,
        'pace': pace.name,
        'childMessage': childMessage,
        'hostMessage': hostMessage,
        'trace': trace.toJson(),
      };

  static GameRecommendation? fromJson(Map<String, dynamic> j) {
    GameType? type;
    for (final t in GameType.values) {
      if (t.id == j['game']) type = t;
    }
    if (type == null) return null;
    GamePace pace = GamePace.slow;
    for (final p in GamePace.values) {
      if (p.name == j['pace']) pace = p;
    }
    return GameRecommendation(
      gameType: type,
      level: ((j['level'] as num?)?.toInt() ?? 1).clamp(kMinLevel, kMaxLevel).toInt(),
      pace: pace,
      childMessage: (j['childMessage'] as String?) ?? '',
      hostMessage: (j['hostMessage'] as String?) ?? '',
      trace: DecisionTrace.fromJson(
          Map<String, dynamic>.from((j['trace'] as Map?) ?? {})),
    );
  }
}
