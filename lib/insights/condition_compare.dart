import '../games/models/game_session.dart';

/// Descriptive statistics for ONE study condition. No significance testing:
/// with a small pilot sample, report these numbers and their n, nothing more.
class ConditionStats {
  final String condition;
  final int sessions;
  final int children;
  final double? meanMoodChange; // mean of (after - before), 5-face ordinal
  final int moodSessions; // sessions that had both before and after
  final double completionRate; // 0..1
  final double meanSupportCount;
  final double? meanLoadMs;
  final double? loadUnder3sRate; // proposal NFR: load < 3 s

  const ConditionStats({
    required this.condition,
    required this.sessions,
    required this.children,
    required this.meanMoodChange,
    required this.moodSessions,
    required this.completionRate,
    required this.meanSupportCount,
    required this.meanLoadMs,
    required this.loadUnder3sRate,
  });
}

const List<String> kConditionOrder = [
  'ADAPTIVE',
  'DIFFICULTY_ONLY',
  'FIXED_BASELINE',
];

/// Groups adventure sessions by study condition. Feed sessions are excluded
/// because they are browsing, not part of the adaptive journey.
List<ConditionStats> compareByCondition(Iterable<GameSession> sessions) {
  final by = <String, List<GameSession>>{};
  for (final s in sessions) {
    if (s.trigger == 'feed') continue;
    by.putIfAbsent(s.condition, () => []).add(s);
  }
  final keys = [
    ...kConditionOrder.where(by.containsKey),
    ...by.keys.where((k) => !kConditionOrder.contains(k)),
  ];
  return [
    for (final k in keys) _stats(k, by[k]!),
  ];
}

ConditionStats _stats(String condition, List<GameSession> list) {
  final deltas = [
    for (final s in list)
      if (s.moodDelta != null) s.moodDelta!.toDouble(),
  ];
  final loads = [
    for (final s in list)
      if (s.loadTimeMs != null) s.loadTimeMs!,
  ];
  return ConditionStats(
    condition: condition,
    sessions: list.length,
    children: list.map((s) => s.anonymousChildId).toSet().length,
    meanMoodChange: deltas.isEmpty
        ? null
        : deltas.reduce((a, b) => a + b) / deltas.length,
    moodSessions: deltas.length,
    completionRate: list.where((s) => s.completed).length / list.length,
    meanSupportCount:
        list.fold<int>(0, (a, s) => a + s.supportCount) / list.length,
    meanLoadMs: loads.isEmpty
        ? null
        : loads.reduce((a, b) => a + b) / loads.length,
    loadUnder3sRate: loads.isEmpty
        ? null
        : loads.where((l) => l < 3000).length / loads.length,
  );
}
