import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/screening_report.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/export_service.dart';
import 'test_helpers.dart';

GameSessionController _controller() => GameSessionController(
    recommendation: AdaptiveGameEngine.recommend(emotion: EmotionState.neutral));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('event-level logging (the raw material for machine learning)', () {
    test('every recorded moment becomes an ordered event', () {
      final c = _controller();
      c.recordTouch();
      c.recordResponse(1200);
      c.recordSuccess();
      c.recordResponse(900);
      c.recordMistake();
      expect(c.events.map((e) => e.type).toList(),
          ['touch', 'response', 'success', 'response', 'mistake']);
      expect(c.events[1].valueMs, 1200);
      expect(c.events[3].valueMs, 900);
      for (var i = 1; i < c.events.length; i++) {
        expect(c.events[i].tMs >= c.events[i - 1].tMs, isTrue);
      }
      // the event log agrees with the summary counters
      expect(c.events.where((e) => e.type == 'success').length, c.successes);
      expect(c.events.where((e) => e.type == 'mistake').length, c.mistakes);
      expect(c.events.where((e) => e.type == 'response').length,
          c.responseTimesMs.length);
      c.dispose();
    });

    test('impossible response times are not logged', () {
      final c = _controller();
      c.recordResponse(0);
      c.recordResponse(-5);
      c.recordResponse(999999999);
      expect(c.events, isEmpty);
      c.dispose();
    });

    test('the log is capped so storage stays small', () {
      final c = _controller();
      for (var i = 0; i < GameSessionController.maxEvents + 100; i++) {
        c.recordTouch();
      }
      expect(c.events.length, GameSessionController.maxEvents);
      expect(c.touches, GameSessionController.maxEvents + 100,
          reason: 'counters keep counting even when the log is full');
      c.dispose();
    });

    test('pausing stops the event clock', () async {
      final c = _controller();
      c.recordTouch();
      c.paused = true;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      c.paused = false;
      c.recordTouch();
      final gap = c.events[1].tMs - c.events[0].tMs;
      expect(gap < 120, isTrue, reason: 'paused time must not count (gap $gap ms)');
      c.dispose();
    });
  });

  group('events survive storage and export', () {
    GameSession withEvents() {
      final s = makeSession(GameType.bubbleValley,
          before: EmotionState.sad, after: EmotionState.calm);
      s.participantAge = 8;
      s.events = const [
        TrialEvent(500, 'touch'),
        TrialEvent(900, 'response', 850),
        TrialEvent(905, 'success'),
        TrialEvent(1800, 'response', 1100.4),
        TrialEvent(1805, 'mistake'),
      ];
      return s;
    }

    test('JSON round trip keeps events and age', () {
      final back = GameSession.fromJson(
          jsonDecode(jsonEncode(withEvents().toJson())) as Map<String, dynamic>);
      expect(back.participantAge, 8);
      expect(back.events.length, 5);
      expect(back.events[1].type, 'response');
      expect(back.events[1].valueMs, 850);
      expect(back.events[4].type, 'mistake');
      expect(back.events[0].valueMs, isNull);
    });

    test('events CSV: header, one row per event, anonymous keys only', () {
      final csv = ExportService.toEventsCsv([withEvents()], participantId: 'C007');
      final lines = csv.trim().split('\n');
      expect(lines.first.split(','), ExportService.eventColumns);
      expect(lines.length, 1 + 5);
      expect(lines[2], contains('C007'));
      expect(lines[2], contains(',response,850'));
      for (final banned in ['name', 'phone', 'address', 'school', 'email']) {
        expect(lines.first.toLowerCase().contains(banned), isFalse);
      }
    });

    test('events CSV is empty (header only) when nothing was logged', () {
      final s = makeSession(GameType.memoryCastle);
      final csv = ExportService.toEventsCsv([s], participantId: 'C001');
      expect(csv.trim().split('\n').length, 1);
    });

    test('sessions CSV carries the participant age and the participant code', () {
      final csv = ExportService.toCsv([withEvents()], participantId: 'C007');
      final lines = csv.trim().split('\n');
      final header = lines.first.split(',');
      expect(header, contains('participantAge'));
      expect(header, contains('participantId'));
      expect(lines[1], contains('C007'));
    });
  });

  group('screening report display never invents results', () {
    const good = '''
{
  "child_id": "C001",
  "data_origin": "SYNTHETIC_DEVELOPMENT",
  "WARNING": "SYNTHETIC / DEVELOPMENT DATA - NOT REAL PARTICIPANT DATA.",
  "evidence": {"sessions": 6, "response_events": 80},
  "indicators": {
    "attention_related_indicator": {"label": "Attention-related indicator", "level": "MODERATE", "confidence": 0.55, "method": "random_forest (machine learning)"},
    "engagement_consistency": {"label": "Engagement consistency", "level": "HIGH", "method": "descriptive rule"}
  },
  "observed_patterns": ["Response speed varied more than most children in the reference group."],
  "recommendation": "Further observation may be appropriate."
}''';

    test('a valid report is read exactly as written', () {
      final r = ScreeningReport.parse(good);
      expect(r.childId, 'C001');
      expect(r.isSynthetic, isTrue);
      expect(r.sessions, 6);
      expect(r.indicators.length, 2);
      expect(r.indicators.first.level, 'MODERATE');
      expect(r.indicators.first.confidence, 0.55);
      expect(r.recommendation, 'Further observation may be appropriate.');
    });

    test('anything that is not a proper report is rejected, not guessed', () {
      expect(() => ScreeningReport.parse('hello'), throwsFormatException);
      expect(() => ScreeningReport.parse('[1,2,3]'), throwsFormatException);
      expect(() => ScreeningReport.parse('{"indicators": {}}'), throwsFormatException);
      expect(
          () => ScreeningReport.parse(
              '{"indicators": {"a": {"label": "x", "level": "SEVERE"}}}'),
          throwsFormatException);
    });

    test('the disclaimer is fixed text, independent of the pasted file', () {
      expect(ScreeningReport.fixedDisclaimer,
          'This system is a research screening prototype and does not provide a clinical diagnosis.');
      final r = ScreeningReport.parse(
          '{"indicators": {"a": {"label": "x", "level": "LOW"}}}');
      expect(r.isSynthetic, isFalse);
      expect(r.dataOrigin, 'UNKNOWN');
    });
  });
}
