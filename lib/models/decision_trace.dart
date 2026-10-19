/// One candidate activity and how it scored (researcher view only).
class ActivityScoreTrace {
  final String activityId;
  final bool allowed; // false = excluded by a safety rule
  final double total;
  final Map<String, double> components;

  const ActivityScoreTrace({
    required this.activityId,
    required this.allowed,
    required this.total,
    required this.components,
  });

  Map<String, dynamic> toJson() => {
        'activity': activityId,
        'allowed': allowed,
        'total': total,
        'components': components,
      };

  factory ActivityScoreTrace.fromJson(Map<String, dynamic> j) =>
      ActivityScoreTrace(
        activityId: (j['activity'] as String?) ?? '',
        allowed: (j['allowed'] as bool?) ?? true,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        components: {
          for (final e in ((j['components'] as Map?) ?? {}).entries)
            e.key.toString(): (e.value as num).toDouble(),
        },
      );
}

/// Why Mindy chose an activity, difficulty and pace. Stored with every
/// session. Shown ONLY to researchers/staff, never to the child.
///
/// Answers: WHAT was selected, WHY, based on WHAT variables, WHAT changed.
/// ("What happened after?" is the session's own after-emotion and indicators,
/// stored on the session that follows this decision.)
class DecisionTrace {
  final DateTime timestamp;
  final String condition; // ADAPTIVE | DIFFICULTY_ONLY | FIXED_BASELINE
  final int journeyStep; // 0-based position in the journey

  // Inputs
  final String? emotion; // SCARED ... or null when skipped
  final String emotionSource; // APP | KARA | KARA_SIMULATED
  final String? previousActivity;
  final int? previousLevel;
  final String recentMoodChange; // improved | unchanged | worsened | unknown
  final String engagement; // low | medium | high | unknown
  final String performanceEvidence; // plain-language summary

  // Outputs
  final String selectedActivity;
  final int selectedLevel; // 1..5
  final String selectedDifficulty; // Easy | Medium | Hard
  final String selectedPace; // slow | normal

  // Rules
  final String ruleId;
  final int baselineLevel;
  final int modifier; // -1, 0, +1 performance step actually applied
  final String modifierReason;
  final bool recovery; // true = chosen after a poor response
  final String humanReason;

  final List<ActivityScoreTrace> scores;
  final Map<String, dynamic> stateSnapshot;

  const DecisionTrace({
    required this.timestamp,
    required this.condition,
    required this.journeyStep,
    required this.emotion,
    required this.emotionSource,
    required this.previousActivity,
    required this.previousLevel,
    required this.recentMoodChange,
    required this.engagement,
    required this.performanceEvidence,
    required this.selectedActivity,
    required this.selectedLevel,
    required this.selectedDifficulty,
    required this.selectedPace,
    required this.ruleId,
    required this.baselineLevel,
    required this.modifier,
    required this.modifierReason,
    required this.recovery,
    required this.humanReason,
    required this.scores,
    required this.stateSnapshot,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'condition': condition,
        'journeyStep': journeyStep,
        'emotion': emotion,
        'emotionSource': emotionSource,
        'previousActivity': previousActivity,
        'previousLevel': previousLevel,
        'recentMoodChange': recentMoodChange,
        'engagement': engagement,
        'performanceEvidence': performanceEvidence,
        'selectedActivity': selectedActivity,
        'selectedLevel': selectedLevel,
        'selectedDifficulty': selectedDifficulty,
        'selectedPace': selectedPace,
        'ruleId': ruleId,
        'baselineLevel': baselineLevel,
        'modifier': modifier,
        'modifierReason': modifierReason,
        'recovery': recovery,
        'humanReason': humanReason,
        'scores': scores.map((s) => s.toJson()).toList(),
        'stateSnapshot': stateSnapshot,
      };

  factory DecisionTrace.fromJson(Map<String, dynamic> j) => DecisionTrace(
        timestamp: DateTime.tryParse((j['timestamp'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        condition: (j['condition'] as String?) ?? 'ADAPTIVE',
        journeyStep: (j['journeyStep'] as num?)?.toInt() ?? 0,
        emotion: j['emotion'] as String?,
        emotionSource: (j['emotionSource'] as String?) ?? 'APP',
        previousActivity: j['previousActivity'] as String?,
        previousLevel: (j['previousLevel'] as num?)?.toInt(),
        recentMoodChange: (j['recentMoodChange'] as String?) ?? 'unknown',
        engagement: (j['engagement'] as String?) ?? 'unknown',
        performanceEvidence: (j['performanceEvidence'] as String?) ?? '',
        selectedActivity: (j['selectedActivity'] as String?) ?? '',
        selectedLevel: (j['selectedLevel'] as num?)?.toInt() ?? 1,
        selectedDifficulty: (j['selectedDifficulty'] as String?) ?? 'Easy',
        selectedPace: (j['selectedPace'] as String?) ?? 'slow',
        ruleId: (j['ruleId'] as String?) ?? '?',
        baselineLevel: (j['baselineLevel'] as num?)?.toInt() ?? 1,
        modifier: (j['modifier'] as num?)?.toInt() ?? 0,
        modifierReason: (j['modifierReason'] as String?) ?? '',
        recovery: (j['recovery'] as bool?) ?? false,
        humanReason: (j['humanReason'] as String?) ?? '',
        scores: ((j['scores'] as List?) ?? [])
            .map((e) => ActivityScoreTrace.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
        stateSnapshot:
            Map<String, dynamic>.from((j['stateSnapshot'] as Map?) ?? {}),
      );
}
