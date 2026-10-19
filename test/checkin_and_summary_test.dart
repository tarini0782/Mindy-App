import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/caregiver_summary.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/export_service.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('optional child answers', () {
    test('survive JSON round trip; skipped answers stay null', () {
      final s = makeSession(GameType.memoryCastle)
        ..enjoyment = 3
        ..perceivedDifficulty = 2
        ..midGameEnjoying = false
        ..childEasierRequests = 1;
      final b = GameSession.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(b.enjoyment, 3);
      expect(b.perceivedDifficulty, 2);
      expect(b.midGameEnjoying, false);
      expect(b.childEasierRequests, 1);
      final skipped = GameSession.fromJson(jsonDecode(
          jsonEncode(makeSession(GameType.memoryCastle).toJson())) as Map<String, dynamic>);
      expect(skipped.enjoyment, isNull);
      expect(skipped.perceivedDifficulty, isNull);
      expect(skipped.midGameEnjoying, isNull);
    });

    test('out-of-range stored values are ignored, not trusted', () {
      final j = makeSession(GameType.memoryCastle).toJson()
        ..['enjoyment'] = 9
        ..['perceivedDifficulty'] = 0;
      final b = GameSession.fromJson(j);
      expect(b.enjoyment, isNull);
      expect(b.perceivedDifficulty, isNull);
    });

    test('export has the new columns', () {
      expect(ExportService.csvColumns,
          containsAll(['enjoyment', 'perceivedDifficulty', 'midGameEnjoying', 'childEasierRequests']));
      final s = makeSession(GameType.memoryCastle)..enjoyment = 2;
      final row = ExportService.toCsv([s]).trim().split('\n');
      expect(row.first.split(',').length, ExportService.csvColumns.length);
    });
  });

  group('child asks for an easier game', () {
    GameSessionController ctl(String cond) => GameSessionController(
        recommendation: AdaptiveGameEngine.recommend(emotion: EmotionState.neutral),
        allowDifficultyChange: cond != 'FIXED_BASELINE');

    test('not possible when the game has no easier option', () {
      final c = ctl('ADAPTIVE');
      expect(c.canMakeEasier, isFalse);
      expect(c.requestEasier(), isFalse);
      expect(c.childEasierRequests, 0);
      c.dispose();
    });

    test('honoured even in the fixed baseline arm, counted and logged', () {
      final c = ctl('FIXED_BASELINE');
      var called = 0;
      c.onEasier = () => called++;
      expect(c.requestEasier(), isTrue);
      expect(called, 1);
      expect(c.childEasierRequests, 1);
      expect(c.events.map((e) => e.type), contains('difficulty'));
      c.dispose();
    });
  });

  group('caregiver summary reports observations only', () {
    test('empty history gives no lines', () {
      expect(CaregiverSummary.from(const []).lines, isEmpty);
    });

    test('counts what happened and nothing else', () {
      final a = makeSession(GameType.bubbleValley,
          before: EmotionState.scared, after: EmotionState.calm, pauses: 0)
        ..pausedCount = 2
        ..childEasierRequests = 1
        ..enjoyment = 3
        ..perceivedDifficulty = 3;
      final b = makeSession(GameType.memoryCastle,
          before: EmotionState.happy, after: EmotionState.happy, completed: false);
      final sm = CaregiverSummary.from([a, b]);
      expect(sm.sessions, 2);
      expect(sm.finished, 1);
      expect(sm.scaredOrSadBefore, 1);
      expect(sm.breaksTaken, 2);
      expect(sm.easierRequests, 1);
      expect(sm.enjoyedYes, 1);
      expect(sm.feltHard, 1);
      expect(sm.feelingBetter, 1);
      expect(sm.feelingSame, 1);
      final text = sm.lines.join(' ').toLowerCase();
      for (final banned in ['anxi', 'depress', 'disorder', 'risk', 'diagnos', 'adhd']) {
        expect(text.contains(banned), isFalse);
      }
    });

    test('skipped answers are not counted as answers', () {
      final s = makeSession(GameType.bubbleValley);
      final sm = CaregiverSummary.from([s]);
      expect(sm.enjoyedYes + sm.enjoyedOk + sm.enjoyedNo, 0);
      expect(sm.lines.join(' ').contains('Said the game was fun'), isFalse);
    });
  });
}
