import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/caregiver_observation.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/export_service.dart';
import 'test_helpers.dart';

/// Minimal CSV parser (handles quotes) so the test checks real structure.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if (c == '\n') {
      row.add(cell.toString());
      cell = StringBuffer();
      rows.add(row);
      row = <String>[];
    } else if (c != '\r') {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

void collectKeys(dynamic v, Set<String> out) {
  if (v is Map) {
    for (final e in v.entries) {
      out.add(e.key.toString());
      collectKeys(e.value, out);
    }
  } else if (v is List) {
    for (final e in v) {
      collectKeys(e, out);
    }
  }
}

void main() {
  final sessions = [
    makeSession(GameType.breathingGarden,
        level: 1,
        before: EmotionState.sad,
        after: EmotionState.calm,
        successes: 0,
        mistakes: 0,
        playAgain: true),
    makeSession(GameType.bubbleValley,
        level: 1,
        before: EmotionState.calm,
        after: EmotionState.happy,
        avgMs: 1800,
        sdMs: 400),
  ];

  group('CSV', () {
    test('header lists every research field', () {
      final rows = parseCsv(ExportService.toCsv(sessions, participantId: 'P001'));
      expect(rows.first, ExportService.csvColumns);
      for (final needed in [
        'sessionId', 'anonymousChildId', 'timestamp', 'duration' 'Seconds',
        'emotionBefore', 'emotionAfter', 'emotionSource', 'moodDelta',
        'activity', 'level', 'difficulty', 'pace', 'studyCondition',
        'completed', 'completionPercentage', 'pausedCount', 'playAgain',
        'accuracy', 'successes', 'mistakes', 'interactionCount',
        'averageResponseTimeMs', 'responseTimeVariabilityMs',
        'recommendationReason', 'previousActivity', 'previousDifficulty',
        'syncStatus', 'decisionTrace',
      ]) {
        expect(ExportService.csvColumns.contains(needed), isTrue, reason: needed);
      }
    });

    test('one row per session, every row has all columns (commas/quotes safe)', () {
      final rows = parseCsv(ExportService.toCsv(sessions, participantId: 'P001'));
      expect(rows.length, 1 + sessions.length);
      for (final r in rows) {
        expect(r.length, ExportService.csvColumns.length);
      }
      final idx = {for (var i = 0; i < ExportService.csvColumns.length; i++) ExportService.csvColumns[i]: i};
      final first = rows[1];
      expect(first[idx['participantId']!], 'P001');
      expect(first[idx['emotionBefore']!], 'SAD');
      expect(first[idx['emotionAfter']!], 'CALM');
      expect(first[idx['moodDelta']!], '2');
      expect(first[idx['activity']!], 'breathing_garden');
      // The embedded DecisionTrace JSON survives CSV quoting.
      final trace = jsonDecode(first[idx['decisionTrace']!]) as Map;
      expect(trace.containsKey('humanReason'), isTrue);
    });

    test('empty export is just the header (no invented rows)', () {
      final rows = parseCsv(ExportService.toCsv(const [], participantId: 'P001'));
      expect(rows.length, 1);
    });
  });

  group('JSON', () {
    test('contains sessions, traces and caregiver observations (labelled)', () {
      final obs = [
        CaregiverObservation(
            id: 'o1',
            timestamp: DateTime(2026, 2, 3),
            type: ObservationType.comfortable,
            note: 'calm evening'),
      ];
      final text = ExportService.toJson(sessions, obs,
          participantId: 'P001', now: DateTime(2026, 2, 4));
      final j = jsonDecode(text) as Map<String, dynamic>;
      expect((j['export'] as Map)['participantId'], 'P001');
      expect((j['sessions'] as List).length, 2);
      final s0 = (j['sessions'] as List).first as Map;
      expect(s0['decisionTrace'], isA<Map>());
      expect(s0['emotionAfter'], 'CALM');
      expect(s0['moodDelta'], 2);
      final o0 = (j['caregiverObservations'] as List).first as Map;
      expect(o0['label'], 'Caregiver-reported observation');
      expect(o0['source'], 'caregiver_reported');
    });

    test('never exports names, contact details or credentials', () {
      final text = ExportService.toJson(sessions, const [], participantId: 'P001');
      final keys = <String>{};
      collectKeys(jsonDecode(text), keys);
      for (final forbidden in [
        'name', 'childName', 'firstName', 'lastName', 'password', 'email',
        'phone', 'address', 'token', 'photo', 'image',
      ]) {
        expect(keys.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('no sessions -> no sessions in the file', () {
      final j = jsonDecode(ExportService.toJson(const [], const [], participantId: 'P')) as Map;
      expect(j['sessions'], isEmpty);
    });
  });

  group('export schema version', () {
    test('csv carries schemaVersion and appVersion columns', () {
      expect(ExportService.csvColumns, containsAll(['schemaVersion', 'appVersion']));
      expect(ExportService.schemaVersion, 'mindy-export-v3');
    });
  });
}
