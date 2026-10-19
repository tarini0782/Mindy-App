import 'dart:convert';
import '../games/models/game_session.dart';
import '../models/caregiver_observation.dart';
import 'app_settings.dart';
import '../models/study_condition.dart';
import '../models/emotion_state.dart';
import '../games/models/game_difficulty.dart';
import '../games/models/game_type.dart';

/// CSV and JSON export of the research data. Real data only.
///
/// Never exported: names, passwords, authentication data, contact details,
/// photos or free-text from the report screen. The child is identified only
/// by the anonymous code / researcher participant code.
class ExportService {
  ExportService._();

  /// Bump when a column is added, removed or changes meaning.
  static const String schemaVersion = 'mindy-export-v3';
  static const String appVersion = '11.0.0';

  static const List<String> csvColumns = [
    'sessionId',
    'anonymousChildId',
    'participantId',
    'participantAge',
    'timestamp',
    'durationSeconds',
    'emotionBefore',
    'emotionAfter',
    'emotionSource',
    'moodDelta',
    'activity',
    'level',
    'difficulty',
    'pace',
    'studyCondition',
    'completed',
    'completionPercentage',
    'pausedCount',
    'playAgain',
    'accuracy',
    'successes',
    'mistakes',
    'interactionCount',
    'averageResponseTimeMs',
    'responseTimeVariabilityMs',
    'previousActivity',
    'previousDifficulty',
    'engagement',
    'performanceBand',
    'supportCount',
    'maxSupportStage',
    'attemptsAfterSupport',
    'successesAfterSupport',
    'difficultyAdjustments',
    'enjoyment',
    'perceivedDifficulty',
    'midGameEnjoying',
    'childEasierRequests',
    'checkInDurationMs',
    'loadTimeMs',
    'ruleId',
    'modifier',
    'recovery',
    'recommendationReason',
    'syncStatus',
    'schemaVersion',
    'appVersion',
    'decisionTrace',
  ];

  static String _esc(Object? v) {
    final s = v == null ? '' : v.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// [sessions] in any order; exported chronologically.
  static String toCsv(List<GameSession> sessions, {String? participantId}) {
    final sorted = List<GameSession>.of(sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final b = StringBuffer()..writeln(csvColumns.join(','));
    for (final s in sorted) {
      final j = s.toJson();
      final eng = (j['engagementIndicators'] as Map)['engagement'];
      final band = (j['engagementIndicators'] as Map)['performanceBand'];
      final row = <Object?>[
        s.sessionId,
        s.anonymousChildId,
        participantId ?? s.anonymousChildId,
        s.participantAge,
        s.startTime.toIso8601String(),
        s.durationSeconds,
        s.emotionBefore?.code,
        s.emotionAfter?.code,
        s.emotionSource,
        s.moodDelta,
        s.game.id,
        s.level,
        s.difficulty.label,
        s.pace.name,
        s.condition,
        s.completed,
        (s.completionPercent * 100).round(),
        s.pausedCount,
        s.playAgain,
        s.accuracy,
        s.successes,
        s.mistakes,
        s.interactions,
        s.avgResponseMs,
        s.responseTimeVariabilityMs,
        s.previousActivity,
        s.previousLevel,
        eng,
        band,
        s.supportCount,
        s.maxSupportStage,
        s.attemptsAfterSupport,
        s.successesAfterSupport,
        s.difficultyAdjustments,
        s.enjoyment,
        s.perceivedDifficulty,
        s.midGameEnjoying,
        s.childEasierRequests,
        s.checkInDurationMs,
        s.loadTimeMs,
        s.trace.ruleId,
        s.trace.modifier,
        s.trace.recovery,
        s.trace.humanReason,
        s.syncStatus.name,
        schemaVersion,
        appVersion,
        jsonEncode(s.trace.toJson()),
      ];
      b.writeln(row.map(_esc).join(','));
    }
    return b.toString();
  }

  static const List<String> eventColumns = [
    'sessionId',
    'anonymousChildId',
    'participantId',
    'activity',
    'level',
    'studyCondition',
    'eventIndex',
    'tMs',
    'type',
    'valueMs',
  ];

  /// Event-level table for machine learning: one row per logged event.
  /// No names or personal details; same participant key as the sessions file.
  static String toEventsCsv(List<GameSession> sessions, {String? participantId}) {
    final sorted = List<GameSession>.of(sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final b = StringBuffer()..writeln(eventColumns.join(','));
    for (final s in sorted) {
      for (var i = 0; i < s.events.length; i++) {
        final e = s.events[i];
        final row = <Object?>[
          s.sessionId,
          s.anonymousChildId,
          participantId ?? s.anonymousChildId,
          s.game.id,
          s.level,
          s.condition,
          i,
          e.tMs,
          e.type,
          e.valueMs == null ? '' : e.valueMs!.round(),
        ];
        b.writeln(row.map(_esc).join(','));
      }
    }
    return b.toString();
  }

  static String toJson(
    List<GameSession> sessions,
    List<CaregiverObservation> observations, {
    String? participantId,
    DateTime? now,
  }) {
    final sorted = List<GameSession>.of(sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final data = <String, dynamic>{
      'export': {
        'app': 'Mindy',
        'format': schemaVersion,
        'appVersion': appVersion,
        'ruleVersion': 'rules-v2',
        'exportedAt': (now ?? DateTime.now()).toIso8601String(),
        'participantId': participantId,
        'participantIdNote': participantId ?? 'each session carries its own pseudonymous anonymousChildId',
        'studyCondition': AppSettings.instance.condition.code,
        'note': 'Non-diagnostic gameplay and self-report data. '
            'No names or contact details are included.',
      },
      'sessions': sorted.map((s) => s.toJson()).toList(),
      'caregiverObservations': [
        for (final o in observations)
          {
            ...o.toJson(),
            'label': CaregiverObservation.sourceLabel,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
