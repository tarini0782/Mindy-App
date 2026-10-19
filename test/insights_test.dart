import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/chart_data.dart';
import 'package:mindy_app/insights/insights_calculator.dart';
import 'package:mindy_app/models/caregiver_observation.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'test_helpers.dart';

void main() {
  group('data sufficiency (no fake patterns)', () {
    test('no data: everything says "still learning" and nothing is invented', () {
      final ins = InsightsCalculator.compute(const [], const []);
      expect(ins.hasAnyData, isFalse);
      expect(ins.journey, isEmpty);
      for (final w in ins.windows) {
        expect(w.level, EvidenceLevel.insufficient);
        expect(w.statements, isEmpty);
        expect(w.participation.started, 0);
        expect(w.participation.completionRate, isNull);
        expect(w.behaviour.meanAccuracy, isNull);
      }
    });

    test('1-2 sessions are still insufficient', () {
      for (var n = 1; n <= 2; n++) {
        final s = [for (var i = 0; i < n; i++) makeSession(GameType.bubbleValley)];
        final ins = InsightsCalculator.compute(s, const []);
        for (final w in ins.windows) {
          expect(w.level, EvidenceLevel.insufficient, reason: '$n sessions');
          expect(w.statements, isEmpty);
        }
      }
    });

    test('3 sessions: a current observation only, never a pattern', () {
      final s = [for (var i = 0; i < 3; i++) makeSession(GameType.bubbleValley)];
      final ins = InsightsCalculator.compute(s, const []);
      for (final w in ins.windows) {
        expect(w.level, EvidenceLevel.currentObservation);
        expect(w.statements.any((t) => t.contains('current observation only')) ||
            w.requestedSize == 3, isTrue);
      }
      expect(ins.windows[1].emotional.mostFrequent, isNull);
    });

    test('7 sessions: developing window becomes an emerging pattern', () {
      final s = [for (var i = 0; i < 7; i++) makeSession(GameType.bubbleValley)];
      final ins = InsightsCalculator.compute(s, const []);
      expect(ins.windows[0].level, EvidenceLevel.currentObservation);
      expect(ins.windows[1].level, EvidenceLevel.emergingPattern);
      expect(ins.windows[2].level, EvidenceLevel.emergingPattern);
    });

    test('30 sessions: longer-term view appears', () {
      final s = [for (var i = 0; i < 30; i++) makeSession(GameType.bubbleValley)];
      final ins = InsightsCalculator.compute(s, const []);
      expect(ins.windows[2].level, EvidenceLevel.longerTerm);
    });

    test('evidenceLevelFor table', () {
      expect(evidenceLevelFor(3, 2), EvidenceLevel.insufficient);
      expect(evidenceLevelFor(3, 3), EvidenceLevel.currentObservation);
      expect(evidenceLevelFor(7, 6), EvidenceLevel.currentObservation);
      expect(evidenceLevelFor(7, 7), EvidenceLevel.emergingPattern);
      expect(evidenceLevelFor(30, 29), EvidenceLevel.emergingPattern);
      expect(evidenceLevelFor(30, 30), EvidenceLevel.longerTerm);
    });
  });

  group('statements are generated from the stored data only', () {
    test('regulation response counts match the sessions', () {
      final s = <GameSession>[];
      // 6 finished breathing sessions: 4 improved, 2 not.
      for (var i = 0; i < 6; i++) {
        s.add(makeSession(GameType.breathingGarden,
            level: 1,
            before: EmotionState.sad,
            after: i < 4 ? EmotionState.calm : EmotionState.sad,
            successes: 0,
            mistakes: 0));
      }
      final ins = InsightsCalculator.compute(s, const []);
      final w = ins.windows[1]; // last 7 (6 available)
      expect(w.regulation.completedWithPair, 6);
      expect(w.regulation.improved, 4);
      expect(w.statements.any((t) => t.contains('in 4 of 6 finished sessions')), isTrue);
      expect(w.statements.any((t) => t.contains('more positive afterwards 4 times')), isTrue);
    });

    test('too few before/after pairs: says so instead of summarising', () {
      final s = [
        for (var i = 0; i < 3; i++)
          makeSession(GameType.bubbleValley, before: EmotionState.neutral, after: null)
      ];
      final w = InsightsCalculator.compute(s, const []).windows[0];
      expect(w.emotional.pairs, 0);
      expect(w.statements.any((t) => t.contains('cannot be summarised yet')), isTrue);
    });

    test('most-frequent feeling only with enough evidence', () {
      final few = [
        for (var i = 0; i < 5; i++) makeSession(GameType.bubbleValley, before: EmotionState.calm)
      ];
      expect(InsightsCalculator.compute(few, const []).windows[1].emotional.mostFrequent, isNull);
      final many = [
        for (var i = 0; i < 7; i++) makeSession(GameType.bubbleValley, before: EmotionState.calm)
      ];
      final w = InsightsCalculator.compute(many, const []).windows[1];
      expect(w.emotional.mostFrequent, 'Calm');
      expect(w.emotional.mostFrequentCount, 7);
    });

    test('participation numbers are exact', () {
      final s = [
        makeSession(GameType.bubbleValley, completed: true, pauses: 1, playAgain: true),
        makeSession(GameType.memoryCastle, completed: false, interactions: 2, pauses: 2, playAgain: false),
        makeSession(GameType.rainbowPuzzle, completed: true, playAgain: true),
      ];
      final p = InsightsCalculator.compute(s, const []).windows[0].participation;
      expect(p.started, 3);
      expect(p.completed, 2);
      expect(p.abandoned, 1);
      expect(p.completionRate, closeTo(2 / 3, 1e-9));
      expect(p.totalPauses, 3);
      expect(p.playAgainYes, 2);
      expect(p.playAgainAnswered, 3);
    });

    test('response-time wording is descriptive, never evaluative', () {
      final steady = [for (var i = 0; i < 3; i++) makeSession(GameType.bubbleValley, avgMs: 1000)];
      final varied = [
        makeSession(GameType.bubbleValley, avgMs: 400),
        makeSession(GameType.bubbleValley, avgMs: 3000),
        makeSession(GameType.bubbleValley, avgMs: 900),
      ];
      expect(InsightsCalculator.compute(steady, const []).windows[0].behaviour.variabilityNote,
          contains('steady'));
      expect(InsightsCalculator.compute(varied, const []).windows[0].behaviour.variabilityNote,
          contains('varied'));
      final all = [
        ...InsightsCalculator.compute(varied, const []).windows[0].statements,
      ].join(' ').toLowerCase();
      for (final bad in ['attention', 'poor', 'disorder', 'diagnos', 'adhd', 'anxiety']) {
        expect(all.contains(bad), isFalse, reason: bad);
      }
      expect(InsightsCalculator.disclaimer.contains('not a'), isTrue);
    });

    test('adaptive journey list uses the stored reasons and counts transitions', () {
      final s = [
        makeSession(GameType.bubbleValley, level: 2),
        makeSession(GameType.bubbleValley, level: 3),
        makeSession(GameType.memoryCastle, level: 3),
      ];
      final ins = InsightsCalculator.compute(s, const []);
      expect(ins.journey.length, 3);
      expect(ins.journey.first.activityId, GameType.memoryCastle.id); // newest first
      expect(ins.repeatedActivityTransitions, 1);
      expect(ins.difficultyChanges, 1);
    });
  });

  group('caregiver observations stay separate and labelled', () {
    test('counted only within the last 30 days and never mixed into sessions', () {
      final now = DateTime(2026, 6, 30);
      final obs = [
        CaregiverObservation(
            id: 'a', timestamp: DateTime(2026, 6, 20), type: ObservationType.comfortable),
        CaregiverObservation(
            id: 'b', timestamp: DateTime(2026, 6, 25), type: ObservationType.comfortable, note: 'x'),
        CaregiverObservation(
            id: 'c', timestamp: DateTime(2026, 3, 1), type: ObservationType.worried),
      ];
      final ins = InsightsCalculator.compute(const [], obs, now: now);
      expect(ins.observationCounts['comfortable'], 2);
      expect(ins.observationCounts.containsKey('worried'), isFalse);
      expect(ins.totalSessions, 0);
      expect(CaregiverObservation.sourceLabel, 'Caregiver-reported observation');
      expect(obs.first.toJson()['source'], 'caregiver_reported');
    });

    test('observation JSON round trip', () {
      final o = CaregiverObservation(
          id: 'z', timestamp: DateTime(2026, 1, 2, 3, 4), type: ObservationType.withdrawn, note: 'quiet today');
      final back = CaregiverObservation.fromJson(o.toJson());
      expect(back.type, ObservationType.withdrawn);
      expect(back.note, 'quiet today');
      expect(back.timestamp, o.timestamp);
    });
  });

  group('chart data comes only from sessions', () {
    test('empty input gives no values', () {
      expect(ChartData.hasValues(ChartData.emotionBefore(const [])), isFalse);
      expect(ChartData.runningCompletionPercent(const []), isEmpty);
    });

    test('series match the stored values and keep gaps as null', () {
      final s = [
        makeSession(GameType.breathingGarden,
            level: 1, before: EmotionState.sad, after: EmotionState.calm, successes: 0, mistakes: 0),
        makeSession(GameType.bubbleValley,
            level: 2, before: EmotionState.neutral, after: null, completed: false, interactions: 2),
      ];
      expect(ChartData.emotionBefore(s), [2.0, 3.0]);
      expect(ChartData.emotionAfter(s), [4.0, null]);
      expect(ChartData.moodDelta(s), [2.0, null]);
      expect(ChartData.level(s), [1.0, 2.0]);
      expect(ChartData.runningCompletionPercent(s), [100.0, 50.0]);
      expect(ChartData.regulationDelta(s), [2.0, null]);
      expect(ChartData.accuracyPercent(s)[0], isNull); // breathing: no right/wrong
    });
  });
}
