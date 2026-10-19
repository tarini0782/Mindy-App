import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';

/// Numbers behind the charts on the parent page. Pure functions of the
/// stored sessions, so they can be tested without a screen.
class DayBar {
  final DateTime day;
  final int sessions;
  final double minutes;
  const DayBar(this.day, this.sessions, this.minutes);
}

class GameRow {
  final GameType game;
  final int plays;
  final int finished;
  final double? fun; // average of 1..3, null = never answered
  final int saidHard;
  final int needsHelp; // sessions with 2 or more hints
  const GameRow(this.game, this.plays, this.finished, this.fun, this.saidHard, this.needsHelp);
  double get finishedShare => plays == 0 ? 0 : finished / plays;
}

class InsightDashboard {
  final List<DayBar> week; // oldest first, 7 entries ending today
  final Map<EmotionState, int> before;
  final Map<EmotionState, int> after;
  final List<GameRow> games; // most played first
  final int totalSessions;
  final double totalMinutes;
  final int daysPlayedThisWeek;

  const InsightDashboard({
    required this.week,
    required this.before,
    required this.after,
    required this.games,
    required this.totalSessions,
    required this.totalMinutes,
    required this.daysPlayedThisWeek,
  });

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static InsightDashboard from(List<GameSession> sessions, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final count = {for (final d in days) d: 0};
    final mins = {for (final d in days) d: 0.0};
    final before = {for (final e in EmotionState.values) e: 0};
    final after = {for (final e in EmotionState.values) e: 0};
    final byGame = <GameType, List<GameSession>>{};
    var total = 0.0;
    for (final s in sessions) {
      final d = _day(s.startTime);
      if (count.containsKey(d)) {
        count[d] = count[d]! + 1;
        mins[d] = mins[d]! + s.durationSeconds / 60.0;
      }
      total += s.durationSeconds / 60.0;
      if (s.emotionBefore != null) before[s.emotionBefore!] = before[s.emotionBefore!]! + 1;
      if (s.emotionAfter != null) after[s.emotionAfter!] = after[s.emotionAfter!]! + 1;
      byGame.putIfAbsent(s.game, () => []).add(s);
    }
    final rows = <GameRow>[];
    byGame.forEach((g, list) {
      final fun = [for (final s in list) if (s.enjoyment != null) s.enjoyment!];
      rows.add(GameRow(
        g,
        list.length,
        list.where((s) => s.completed).length,
        fun.isEmpty ? null : fun.reduce((a, b) => a + b) / fun.length,
        list.where((s) => s.perceivedDifficulty == 3).length,
        list.where((s) => s.supportCount >= 2).length,
      ));
    });
    rows.sort((a, b) => b.plays.compareTo(a.plays));
    return InsightDashboard(
      week: [for (final d in days) DayBar(d, count[d]!, mins[d]!)],
      before: before,
      after: after,
      games: rows,
      totalSessions: sessions.length,
      totalMinutes: total,
      daysPlayedThisWeek: days.where((d) => count[d]! > 0).length,
    );
  }
}
