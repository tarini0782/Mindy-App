import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/decision_explanation.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';
import 'test_helpers.dart';

/// v29 audit fixes. Each group below corresponds to a weakness found by
/// inspecting the engine source; see docs/ENGINE_AUDIT.md.
void main() {
  group('W1: a calming activity cannot earn a performance band', () {
    // Regulation activities follow the calm-pool rule that nothing can be
    // failed, so they never record a mistake. Before this fix their accuracy
    // was always 1.0, which produced PerformanceBand.high and could raise
    // the difficulty OF A CALMING ACTIVITY.
    test('regulation activities report no performance data', () {
      for (final g in GameType.values.where((g) => g.isRegulation)) {
        expect(g.hasPerformanceData, isFalse, reason: '${g.id} is regulation');
      }
      expect(GameType.fireflyJar.hasPerformanceData, isFalse);
      expect(GameType.breathingGarden.hasPerformanceData, isFalse);
      expect(GameType.treasureJourney.hasPerformanceData, isFalse);
    });

    test('a flawless calming session still yields a null band', () {
      final s = makeSession(GameType.fireflyJar,
          successes: 9, mistakes: 0, completed: true);
      expect(s.accuracy, 1.0, reason: 'the raw accuracy is still 100%');
      expect(s.performanceBand, isNull,
          reason: 'but it must not count as "consistently smooth play"');
    });

    test('an ordinary activity is unaffected', () {
      final good = makeSession(GameType.memoryCastle,
          successes: 9, mistakes: 1, completed: true);
      final poor = makeSession(GameType.memoryCastle,
          successes: 3, mistakes: 7, completed: true);
      expect(good.performanceBand, PerformanceBand.high);
      expect(poor.performanceBand, PerformanceBand.low);
    });

    test('repeated flawless calming sessions do not raise the level', () {
      // Four completed Firefly Jar sessions at level 1, all perfect. Under
      // the old behaviour this was "consistently smooth play" twice over.
      final history = [
        for (var i = 0; i < 4; i++)
          makeSession(GameType.fireflyJar,
              level: 1, successes: 9, mistakes: 0, completed: true,
              before: EmotionState.calm, after: EmotionState.calm),
      ];
      final r = AdaptiveGameEngine.recommend(
        emotion: EmotionState.calm,
        history: history,
        pool: const [GameType.fireflyJar],
      );
      expect(r.gameType, GameType.fireflyJar);
      expect(r.trace.modifier, 0,
          reason: 'no performance evidence exists for a calming activity, '
              'so there is nothing to step on: ${r.trace.modifierReason}');
    });
  });

  group('W2: a fallback can never leave the candidate pool', () {
    test('every condition stays inside a pool that excludes the fail-safe', () {
      // Breathing Garden is the hard-coded fail-safe, so a pool WITHOUT it
      // is exactly the case that used to escape.
      const pool = [GameType.memoryCastle, GameType.rainbowPuzzle];
      for (final c in StudyCondition.values) {
        for (final e in [
          null,
          EmotionState.scared,
          EmotionState.sad,
          EmotionState.neutral,
          EmotionState.happy,
        ]) {
          final r = AdaptiveGameEngine.recommend(
            emotion: e,
            condition: c,
            pool: pool,
            equalSafetyFloor: true,
          );
          expect(pool.contains(r.gameType), isTrue,
              reason: '${c.code} with emotion $e escaped the pool via '
                  '${r.gameType.id}');
        }
      }
    });
  });

  group('W3: the decision can be explained from its own trace', () {
    test('explains the winner against the real runner-up', () {
      final r = AdaptiveGameEngine.recommend(emotion: EmotionState.happy);
      final x = DecisionExplanation(r.trace);

      expect(x.winner, isNotNull);
      expect(x.winner!.activityId, r.trace.selectedActivity);
      expect(x.runnerUp, isNotNull);
      expect(x.runnerUp!.activityId, isNot(r.trace.selectedActivity));
      expect(x.eligibleCount, greaterThan(1));

      // The winner must not score below the runner-up.
      expect(x.winner!.total, greaterThanOrEqualTo(x.runnerUp!.total));

      // Whatever decided it must be a component that genuinely differs.
      for (final d in x.decidingComponents()) {
        expect(d.diff, isNot(0));
        expect(d.winnerValue - d.rivalValue, closeTo(d.diff, 0.0001));
      }
    });

    test('caregiver lines never leak scores or internal component names', () {
      final r = AdaptiveGameEngine.recommend(emotion: EmotionState.sad);
      final text = DecisionExplanation(r.trace).caregiverLines().join(' ');
      for (final internal in [
        'emotionalCompatibility',
        'repetitionAvoidance',
        'recoveryPenalty',
        'alreadyThisAdventure',
        'total',
      ]) {
        expect(text.contains(internal), isFalse,
            reason: '"$internal" reached a caregiver');
      }
      expect(text, isNotEmpty);
    });

    test('a restricted check-in is explained as comfort-first', () {
      final r = AdaptiveGameEngine.recommend(emotion: EmotionState.scared);
      final x = DecisionExplanation(r.trace);
      expect(x.caregiverLines().join(' ').toLowerCase(), contains('scared'));
      expect(x.whatWouldChangeNext().toLowerCase(),
          contains('easiest level'));
    });

    test('the fixed condition is described as fixed, not as a choice', () {
      final r = AdaptiveGameEngine.recommend(
          emotion: EmotionState.happy, condition: StudyCondition.fixedBaseline);
      final lines = DecisionExplanation(r.trace).caregiverLines().join(' ');
      expect(lines.toLowerCase(), contains('decided in advance'));
    });

    test('an empty score list is reported as a gap, not papered over', () {
      final r = AdaptiveGameEngine.recommend(
          emotion: EmotionState.happy, condition: StudyCondition.fixedBaseline);
      final gaps = DecisionExplanation(r.trace).traceGaps();
      expect(gaps.any((g) => g.contains('No candidate scores')), isTrue);
    });

    test('researcher rows rank eligible candidates above excluded ones', () {
      final r = AdaptiveGameEngine.recommend(emotion: EmotionState.scared);
      final rows = DecisionExplanation(r.trace).researcherRows();
      expect(rows.length, GameType.values.length);
      final firstExcluded = rows.indexWhere((x) => !x.allowed);
      final lastAllowed = rows.lastIndexWhere((x) => x.allowed);
      expect(lastAllowed, lessThan(firstExcluded));
      expect(rows.first.selected, isTrue,
          reason: 'the selected activity should top the eligible ranking');
    });
  });

  group('determinism still holds after these changes', () {
    test('identical inputs give an identical decision', () {
      final history = [
        makeSession(GameType.memoryCastle, before: EmotionState.neutral),
        makeSession(GameType.bubbleValley, before: EmotionState.calm),
      ];
      final a = AdaptiveGameEngine.recommend(
          emotion: EmotionState.calm, history: history, journeyStep: 2);
      final b = AdaptiveGameEngine.recommend(
          emotion: EmotionState.calm, history: history, journeyStep: 2);
      expect(a.gameType, b.gameType);
      expect(a.level, b.level);
      expect(a.trace.humanReason, b.trace.humanReason);
    });
  });
}
