import '../games/models/game_session.dart';
import '../games/models/game_type.dart';

/// Checks stored research records and summarises them for the researcher
/// dashboard. Pure Dart. Real stored data only: nothing here invents values.
class QualityIssue {
  final String sessionId;
  final String code;
  final String message;
  const QualityIssue(this.sessionId, this.code, this.message);
}

class DashboardSummary {
  final int sessions;
  final int completed;
  final int interrupted;
  final Map<String, int> gameUse; // game id -> sessions
  final Map<String, int> eventCounts; // event type -> count
  final int sessionsWithSupport;
  final int supportOffers;
  final int difficultyAdjustments;
  final int attemptsAfterSupport;
  final int successesAfterSupport;
  final List<QualityIssue> issues;
  const DashboardSummary({
    required this.sessions,
    required this.completed,
    required this.interrupted,
    required this.gameUse,
    required this.eventCounts,
    required this.sessionsWithSupport,
    required this.supportOffers,
    required this.difficultyAdjustments,
    required this.attemptsAfterSupport,
    required this.successesAfterSupport,
    required this.issues,
  });
}

class DataQuality {
  DataQuality._();

  static List<QualityIssue> check(List<GameSession> list) {
    final issues = <QualityIssue>[];
    final seen = <String>{};
    for (final s in list) {
      if (!seen.add(s.sessionId)) {
        issues.add(QualityIssue(s.sessionId, 'DUPLICATE_SESSION',
            'Session id appears more than once.'));
      }
      if (s.durationSeconds < 0) {
        issues.add(QualityIssue(s.sessionId, 'NEGATIVE_DURATION',
            'Duration is negative.'));
      }
      if (s.endTime != null && s.endTime!.isBefore(s.startTime)) {
        issues.add(QualityIssue(s.sessionId, 'END_BEFORE_START',
            'End time is before start time.'));
      }
      var last = -1;
      for (final e in s.events) {
        if (e.tMs < last) {
          issues.add(QualityIssue(s.sessionId, 'EVENTS_OUT_OF_ORDER',
              'Event times go backwards.'));
          break;
        }
        last = e.tMs;
      }
      for (final e in s.events) {
        if (e.type == 'response' && (e.valueMs ?? 0) <= 0) {
          issues.add(QualityIssue(s.sessionId, 'BAD_RESPONSE_TIME',
              'A response time is missing or not positive.'));
          break;
        }
      }
      if (s.events.length >= 600) {
        issues.add(QualityIssue(s.sessionId, 'EVENT_CAP_REACHED',
            'Event log hit the 600-event cap; later events are missing.'));
      }
      if (s.interactions > 0 && s.events.isEmpty) {
        issues.add(QualityIssue(s.sessionId, 'NO_EVENT_LOG',
            'Interactions were counted but no events were stored.'));
      }
      if (s.completed && s.interactions == 0) {
        issues.add(QualityIssue(s.sessionId, 'COMPLETED_WITHOUT_INTERACTION',
            'Marked complete with zero interactions.'));
      }
      if (s.emotionBefore == null) {
        issues.add(QualityIssue(s.sessionId, 'NO_PRE_CHECKIN',
            'No feeling picked before play (skipped).'));
      }
    }
    return issues;
  }

  static DashboardSummary summarise(List<GameSession> list) {
    final use = <String, int>{};
    final ev = <String, int>{};
    var sup = 0, offers = 0, adj = 0, att = 0, succ = 0, done = 0;
    for (final s in list) {
      use[s.game.id] = (use[s.game.id] ?? 0) + 1;
      for (final e in s.events) {
        ev[e.type] = (ev[e.type] ?? 0) + 1;
      }
      if (s.completed) done++;
      if (s.supportCount > 0) sup++;
      offers += s.supportCount;
      adj += s.difficultyAdjustments;
      att += s.attemptsAfterSupport;
      succ += s.successesAfterSupport;
    }
    return DashboardSummary(
      sessions: list.length,
      completed: done,
      interrupted: list.length - done,
      gameUse: use,
      eventCounts: ev,
      sessionsWithSupport: sup,
      supportOffers: offers,
      difficultyAdjustments: adj,
      attemptsAfterSupport: att,
      successesAfterSupport: succ,
      issues: check(list),
    );
  }
}
