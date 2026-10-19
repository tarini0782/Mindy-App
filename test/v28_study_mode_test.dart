import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_pace.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';

/// v28: the two evaluation parameters added to AdaptiveGameEngine.recommend
/// so the rater study can make a FAIR comparison between conditions
/// (docs/RESEARCH_REPORT.md section 7).
///
/// The first group is the important one: both parameters default to the
/// shipped behaviour, so normal play and every pre-existing test are
/// unaffected.
void main() {
  const restrictedEmotions = <EmotionState?>[
    null, // skipped
    EmotionState.scared,
    EmotionState.sad,
  ];

  group('defaults preserve the shipped behaviour', () {
    test('fixed baseline still ignores the feeling when not floored', () {
      for (final e in restrictedEmotions) {
        final r = AdaptiveGameEngine.recommend(
          emotion: e,
          condition: StudyCondition.fixedBaseline,
        );
        // Unchanged from before v28: level 3, straight off the fixed sequence.
        expect(r.level, AdaptiveGameEngine.fixedLevel);
        expect(AdaptiveGameEngine.fixedSequence.contains(r.gameType), isTrue);
      }
    });

    test('adaptive with no pool can still reach outside the study pool', () {
      // Over many happy check-ins the engine should at some point choose an
      // activity that is NOT in the nine-item study pool, proving the pool
      // is not being applied when it was not asked for.
      final seen = <GameType>{};
      for (var step = 0; step < 12; step++) {
        final r = AdaptiveGameEngine.recommend(
          emotion: EmotionState.happy,
          journeyStep: step,
          avoidIds: seen.map((g) => g.id).toSet(),
        );
        seen.add(r.gameType);
      }
      expect(seen.any((g) => !AdaptiveGameEngine.studyPool.contains(g)), isTrue,
          reason: 'without a pool the whole library must stay reachable');
    });
  });

  group('the study pool itself', () {
    test('has nine activities and fixes both defects found in fixedSequence', () {
      const pool = AdaptiveGameEngine.studyPool;
      expect(pool.length, 9);
      expect(pool.toSet().length, 9, reason: 'no duplicates');

      // Defect 1: the six-item fixedSequence has no medical content.
      expect(AdaptiveGameEngine.fixedSequence.contains(GameType.teddyClinic),
          isFalse);
      expect(pool.contains(GameType.teddyClinic), isTrue);

      // Defect 2: only three of the six were calm-pool members.
      final calmInFixed = AdaptiveGameEngine.fixedSequence
          .where(AdaptiveGameEngine.calmPool.contains)
          .length;
      final calmInPool =
          pool.where(AdaptiveGameEngine.calmPool.contains).length;
      expect(calmInFixed, 3);
      expect(calmInPool, greaterThanOrEqualTo(5),
          reason: 'restricted check-ins need real choice in every condition');
    });
  });

  group('pool restriction applies in every condition', () {
    test('no condition can select outside the pool', () {
      const pool = AdaptiveGameEngine.studyPool;
      for (final c in StudyCondition.values) {
        for (final e in [
          null,
          EmotionState.scared,
          EmotionState.sad,
          EmotionState.neutral,
          EmotionState.calm,
          EmotionState.happy,
        ]) {
          for (var step = 0; step < 9; step++) {
            final r = AdaptiveGameEngine.recommend(
              emotion: e,
              condition: c,
              journeyStep: step,
              pool: pool,
              equalSafetyFloor: true,
            );
            expect(pool.contains(r.gameType), isTrue,
                reason: 'condition ${c.code}, emotion $e, step $step '
                    'chose ${r.gameType.id}, which is outside the pool');
          }
        }
      }
    });
  });

  group('equal safety floor', () {
    test('every condition gives a restricted check-in a calm activity '
        'at the floor level and slow pace', () {
      for (final c in StudyCondition.values) {
        for (final e in restrictedEmotions) {
          for (var step = 0; step < 6; step++) {
            final r = AdaptiveGameEngine.recommend(
              emotion: e,
              condition: c,
              journeyStep: step,
              pool: AdaptiveGameEngine.studyPool,
              equalSafetyFloor: true,
            );
            expect(AdaptiveGameEngine.calmPool.contains(r.gameType), isTrue,
                reason: '${c.code} offered ${r.gameType.id} to a distressed '
                    'check-in');
            expect(r.level, AdaptiveGameEngine.levelRange(e).$1);
            expect(r.pace, GamePace.slow);
          }
        }
      }
    });

    test('the non-adaptive conditions still do not adapt under the floor', () {
      // Same profile, same step, run twice: a non-adaptive condition must be
      // deterministic and must not consult history.
      for (final c in [
        StudyCondition.fixedBaseline,
        StudyCondition.difficultyOnly,
      ]) {
        final a = AdaptiveGameEngine.recommend(
          emotion: EmotionState.scared,
          condition: c,
          journeyStep: 2,
          pool: AdaptiveGameEngine.studyPool,
          equalSafetyFloor: true,
        );
        final b = AdaptiveGameEngine.recommend(
          emotion: EmotionState.scared,
          condition: c,
          journeyStep: 2,
          pool: AdaptiveGameEngine.studyPool,
          equalSafetyFloor: true,
        );
        expect(a.gameType, b.gameType);
        expect(a.trace.ruleId, endsWith('S'),
            reason: 'the shared-floor path records its own rule id');
      }
    });

    test('an unrestricted check-in is NOT floored', () {
      final r = AdaptiveGameEngine.recommend(
        emotion: EmotionState.happy,
        condition: StudyCondition.fixedBaseline,
        pool: AdaptiveGameEngine.studyPool,
        equalSafetyFloor: true,
      );
      expect(r.pace, GamePace.normal);
      expect(r.level, AdaptiveGameEngine.fixedLevel);
    });
  });

  group('every decision still explains itself', () {
    test('a reason is recorded in every condition and every emotion', () {
      for (final c in StudyCondition.values) {
        for (final e in [null, EmotionState.scared, EmotionState.happy]) {
          final r = AdaptiveGameEngine.recommend(
            emotion: e,
            condition: c,
            pool: AdaptiveGameEngine.studyPool,
            equalSafetyFloor: true,
          );
          expect(r.trace.humanReason, isNotEmpty);
          expect(r.trace.selectedActivity, r.gameType.id);
          expect(r.trace.selectedLevel, r.level);
        }
      }
    });
  });
}
