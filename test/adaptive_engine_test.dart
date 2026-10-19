import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_pace.dart';
import 'package:mindy_app/games/models/game_recommendation.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/adaptive_state.dart';
import 'package:mindy_app/models/decision_trace.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';
import 'test_helpers.dart';

GameRecommendation rec(
  EmotionState? e, {
  StudyCondition c = StudyCondition.adaptive,
  List<GameSession> h = const [],
  int step = 0,
}) =>
    AdaptiveGameEngine.recommend(
        emotion: e, condition: c, history: h, journeyStep: step);

void main() {
  group('safety: emotion overrides performance', () {
    test('scared -> regulation activity, level 1 (EASY), slow', () {
      final r = rec(EmotionState.scared);
      expect(r.gameType.isRegulation, isTrue);
      expect(r.level, 1);
      expect(r.pace, GamePace.slow);
      expect(r.trace.ruleId, 'S1');
    });

    test('sad -> regulation or supportive activity, level 1, slow', () {
      final r = rec(EmotionState.sad);
      expect(
          [GameType.breathingGarden, GameType.treasureJourney, GameType.bubbleValley]
              .contains(r.gameType),
          isTrue);
      expect(r.level, 1);
      expect(r.pace, GamePace.slow);
    });

    test('a six-step adventure for a scared child never repeats an activity', () {
      final played = <GameType>[];
      final avoid = <String>{};
      for (var i = 0; i < AdaptiveGameEngine.journeyLength; i++) {
        final r = AdaptiveGameEngine.recommend(
            emotion: EmotionState.scared, avoidIds: avoid, journeyStep: i);
        expect(AdaptiveGameEngine.calmPool.contains(r.gameType), isTrue);
        expect(r.level, 1);
        played.add(r.gameType);
        avoid.add(r.gameType.id);
      }
      expect(played.toSet().length, AdaptiveGameEngine.journeyLength);
    });

    test('a six-step adventure for a sad child never repeats an activity', () {
      final avoid = <String>{};
      final played = <GameType>[];
      for (var i = 0; i < AdaptiveGameEngine.journeyLength; i++) {
        final r = AdaptiveGameEngine.recommend(
            emotion: EmotionState.sad, avoidIds: avoid, journeyStep: i);
        played.add(r.gameType);
        avoid.add(r.gameType.id);
      }
      expect(played.toSet().length, AdaptiveGameEngine.journeyLength);
    });

    test('neutral adventure: no repeats either', () {
      final avoid = <String>{};
      final played = <GameType>[];
      for (var i = 0; i < AdaptiveGameEngine.journeyLength; i++) {
        final r = AdaptiveGameEngine.recommend(
            emotion: EmotionState.neutral, avoidIds: avoid, journeyStep: i);
        played.add(r.gameType);
        avoid.add(r.gameType.id);
      }
      expect(played.toSet().length, AdaptiveGameEngine.journeyLength);
    });

    test('skipped check-in fails safe to calm', () {
      final r = rec(null);
      expect(r.gameType.isRegulation, isTrue);
      expect(r.level, 1);
      expect(r.pace, GamePace.slow);
      expect(r.trace.ruleId, 'S0');
    });

    test('scared/sad never get a standard or engaging activity', () {
      for (final e in [EmotionState.scared, EmotionState.sad, null]) {
        for (var n = 0; n < 12; n++) {
          final h = <GameSession>[];
          // Even after lots of excellent play and improved moods.
          for (var i = 0; i < n; i++) {
            h.add(makeSession(GameType.patternPower,
                before: EmotionState.happy,
                after: EmotionState.happy,
                successes: 10,
                mistakes: 0));
          }
          final r = rec(e, h: h);
          expect(r.level, 1, reason: 'emotion $e after $n sessions');
          expect(r.trace.modifier, 0);
          expect(
              [GameType.memoryCastle, GameType.patternPower, GameType.rainbowPuzzle]
                  .contains(r.gameType),
              isFalse);
        }
      }
    });

    test('neutral starts at medium, calm/happy start at medium', () {
      expect(rec(EmotionState.neutral).level, 3);
      expect(rec(EmotionState.calm).level, 3);
      expect(rec(EmotionState.happy).level, 3);
      expect(rec(EmotionState.neutral).pace, GamePace.normal);
    });

    test('happy with no history -> an engaging activity', () {
      expect(rec(EmotionState.happy).gameType, GameType.patternPower);
    });

    test('emotion source is recorded and does not change the decision', () {
      for (final e in EmotionState.values) {
        final a = AdaptiveGameEngine.recommend(emotion: e, source: EmotionSource.app);
        final k = AdaptiveGameEngine.recommend(
            emotion: e, source: EmotionSource.karaSimulated);
        expect(k.gameType, a.gameType);
        expect(k.level, a.level);
        expect(k.trace.emotionSource, 'KARA_SIMULATED');
        expect(a.trace.emotionSource, 'APP');
      }
    });
  });

  group('layer 2: difficulty (bounded performance modifier)', () {
    // DIFFICULTY_ONLY with step 3 always selects Pattern Power, so these
    // tests isolate the level logic.
    GameRecommendation level(EmotionState e, List<GameSession> h) =>
        rec(e, c: StudyCondition.difficultyOnly, h: h, step: 3);

    GameSession pat(int lvl, {required bool good}) => makeSession(
        GameType.patternPower,
        level: lvl,
        before: EmotionState.happy,
        successes: good ? 10 : 2,
        mistakes: good ? 0 : 8);

    test('one smooth session does not raise the level', () {
      final r = level(EmotionState.happy, [pat(3, good: true)]);
      expect(r.level, 3);
      expect(r.trace.modifier, 0);
    });

    test('two consistent smooth sessions raise it by exactly one', () {
      final r = level(EmotionState.happy, [pat(3, good: true), pat(3, good: true)]);
      expect(r.level, 4);
      expect(r.trace.modifier, 1);
    });

    test('one tricky session does not lower the level', () {
      final r = level(EmotionState.neutral, [pat(3, good: false)]);
      expect(r.level, 3);
    });

    test('two consistent tricky sessions lower it by one (neutral)', () {
      final r = level(EmotionState.neutral, [pat(3, good: false), pat(3, good: false)]);
      expect(r.level, 2);
      expect(r.trace.modifier, -1);
    });

    test('mixed sessions change nothing', () {
      final r = level(EmotionState.happy, [pat(3, good: true), pat(3, good: false)]);
      expect(r.level, 3);
    });

    test('clamped: never above 5, never below the emotion floor', () {
      final top = level(EmotionState.happy, [pat(5, good: true), pat(5, good: true)]);
      expect(top.level, 5);
      final floor = level(EmotionState.happy, [pat(3, good: false), pat(3, good: false)]);
      expect(floor.level, 3); // calm/happy floor is medium
    });

    test('over a long simulated history the level never jumps by more than 1', () {
      final h = <GameSession>[];
      var last = 3;
      for (var i = 0; i < 40; i++) {
        final r = level(EmotionState.happy, h);
        expect((r.level - last).abs() <= 1, isTrue, reason: 'step $i');
        last = r.level;
        final good = (i ~/ 3).isEven; // alternating runs of good / tricky
        h.add(pat(r.level, good: good));
      }
    });

    test('Easy never jumps straight to Hard', () {
      // A scared session then a happy one: the happy one starts at medium.
      final h = [
        makeSession(GameType.patternPower,
            level: 1, before: EmotionState.scared, successes: 10, mistakes: 0),
        makeSession(GameType.patternPower,
            level: 1, before: EmotionState.scared, successes: 10, mistakes: 0),
      ];
      final r = level(EmotionState.happy, h);
      expect(r.level <= 3, isTrue);
    });
  });

  group('layer 1: activity selection', () {
    test('does not repeat the previous activity immediately', () {
      for (final e in [EmotionState.neutral, EmotionState.calm, EmotionState.happy]) {
        final h = <GameSession>[];
        GameType? prev;
        for (var i = 0; i < 12; i++) {
          final r = rec(e, h: h);
          if (prev != null) expect(r.gameType == prev, isFalse, reason: '$e step $i');
          prev = r.gameType;
          h.add(makeSession(r.gameType, level: r.level, before: e, after: e));
        }
      }
    });

    test('spec example: sad, breathing helped -> gentle Bubble Valley, easy', () {
      final h = [
        makeSession(GameType.breathingGarden,
            level: 1,
            before: EmotionState.sad,
            after: EmotionState.calm,
            successes: 0,
            mistakes: 0),
      ];
      final r = rec(EmotionState.sad, h: h);
      expect(r.gameType, GameType.bubbleValley);
      expect(r.level, 1);
      expect(r.pace, GamePace.slow);
      expect(r.trace.humanReason.contains('gentle'), isTrue);
    });

    test('suitability components are recorded for every activity', () {
      final r = rec(EmotionState.neutral);
      expect(r.trace.scores.length, GameType.values.length);
      final scared = rec(EmotionState.scared);
      final allowed = scared.trace.scores.where((s) => s.allowed).map((s) => s.activityId).toSet();
      expect(allowed.length, 9); // 9 since Firefly Jar joined the calm pool (v27)
      expect(allowed, AdaptiveGameEngine.calmPool.map((g) => g.id).toSet());
    });

    test('mood response raises suitability of an activity that helped', () {
      final h = [
        makeSession(GameType.rainbowPuzzle,
            before: EmotionState.neutral, after: EmotionState.happy),
        makeSession(GameType.bubbleValley,
            before: EmotionState.neutral, after: EmotionState.neutral),
      ];
      final r = rec(EmotionState.neutral, h: h);
      final comps = r.trace.scores
          .firstWhere((s) => s.activityId == GameType.rainbowPuzzle.id)
          .components;
      expect(comps['recentMoodResponse']! > 0, isTrue);
    });
  });

  group('adaptive recovery', () {
    test('a poor response is not blindly repeated', () {
      final poor = makeSession(GameType.bubbleValley,
          before: EmotionState.neutral,
          after: EmotionState.neutral,
          completed: false,
          interactions: 1);
      final r = rec(EmotionState.neutral, h: [poor]);
      expect(r.gameType == GameType.bubbleValley, isFalse);
      expect(r.trace.recovery, isTrue);
      expect(r.trace.humanReason.contains('did not go well'), isTrue);
    });

    test('after two difficult sessions a calming activity is favoured', () {
      final h = [
        makeSession(GameType.memoryCastle,
            before: EmotionState.neutral,
            after: EmotionState.neutral,
            completed: false,
            interactions: 1),
        makeSession(GameType.patternPower,
            before: EmotionState.neutral,
            after: EmotionState.neutral,
            completed: false,
            interactions: 1),
      ];
      final r = rec(EmotionState.neutral, h: h);
      final reg = r.trace.scores
          .firstWhere((s) => s.activityId == GameType.breathingGarden.id)
          .components['regulationNeed']!;
      expect(reg > 0, isTrue);
    });

    test('a good response is allowed to continue to a different activity', () {
      final good = makeSession(GameType.bubbleValley,
          before: EmotionState.neutral, after: EmotionState.happy);
      final r = rec(EmotionState.neutral, h: [good]);
      expect(r.trace.recovery, isFalse);
    });
  });

  group('study conditions', () {
    test('FIXED_BASELINE ignores emotion: same order and level for all', () {
      for (var step = 0; step < 6; step++) {
        final outs = <String>{};
        for (final e in [...EmotionState.values, null]) {
          final r = rec(e, c: StudyCondition.fixedBaseline, step: step);
          outs.add('${r.gameType.id}/${r.level}/${r.pace.name}');
          expect(r.level, AdaptiveGameEngine.fixedLevel);
          expect(r.trace.ruleId, 'F1');
        }
        expect(outs.length, 1, reason: 'step $step');
      }
    });

    test('FIXED_BASELINE visits all six activities in the fixed order', () {
      final seen = [
        for (var s = 0; s < 6; s++)
          rec(null, c: StudyCondition.fixedBaseline, step: s).gameType
      ];
      expect(seen, AdaptiveGameEngine.fixedSequence);
      expect(seen.toSet().length, 6);
    });

    test('DIFFICULTY_ONLY: sequence fixed, difficulty still follows emotion', () {
      for (var step = 0; step < 6; step++) {
        final scared = rec(EmotionState.scared, c: StudyCondition.difficultyOnly, step: step);
        final happy = rec(EmotionState.happy, c: StudyCondition.difficultyOnly, step: step);
        expect(scared.gameType, AdaptiveGameEngine.fixedSequence[step]);
        expect(happy.gameType, scared.gameType);
        expect(scared.level, 1);
        expect(happy.level, 3);
        expect(scared.pace, GamePace.slow);
      }
    });

    test('condition codes round trip', () {
      for (final c in StudyCondition.values) {
        expect(StudyConditionX.fromCode(c.code), c);
      }
      expect(StudyCondition.fixedBaseline.code, 'FIXED_BASELINE');
    });
  });

  group('DecisionTrace', () {
    test('is fully populated and explains the decision', () {
      for (final c in StudyCondition.values) {
        for (final e in [...EmotionState.values, null]) {
          final r = rec(e, c: c);
          final t = r.trace;
          expect(t.humanReason.isNotEmpty, isTrue);
          expect(t.ruleId.isNotEmpty, isTrue);
          expect(t.condition, c.code);
          expect(t.selectedActivity, r.gameType.id);
          expect(t.selectedLevel, r.level);
          expect(t.selectedPace, r.pace.name);
          expect(t.humanReason.contains(r.gameType.title), isTrue);
          expect(t.emotion, e?.code);
        }
      }
    });

    test('records previous activity, difficulty, mood change and engagement', () {
      final h = [
        makeSession(GameType.memoryCastle,
            level: 4, before: EmotionState.calm, after: EmotionState.happy),
      ];
      final t = rec(EmotionState.happy, h: h).trace;
      expect(t.previousActivity, GameType.memoryCastle.id);
      expect(t.previousLevel, 4);
      expect(t.recentMoodChange, 'improved');
      expect(t.engagement, 'high');
    });

    test('JSON round trip keeps everything', () {
      final h = [makeSession(GameType.breathingGarden, level: 1,
          before: EmotionState.sad, after: EmotionState.calm, successes: 0, mistakes: 0)];
      final t = rec(EmotionState.sad, h: h).trace;
      final back = DecisionTrace.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(t.toJson())) as Map));
      expect(back.humanReason, t.humanReason);
      expect(back.scores.length, t.scores.length);
      expect(back.selectedActivity, t.selectedActivity);
      expect(back.recentMoodChange, t.recentMoodChange);
    });

    test('is deterministic: same inputs, same trace', () {
      final h = [makeSession(GameType.bubbleValley, after: EmotionState.happy)];
      final now = DateTime(2026, 5, 5);
      final a = AdaptiveGameEngine.recommend(
          emotion: EmotionState.calm, history: h, now: now);
      final b = AdaptiveGameEngine.recommend(
          emotion: EmotionState.calm, history: h, now: now);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    });
  });

  group('AdaptiveChildState', () {
    test('empty history gives an empty, safe state', () {
      final s = AdaptiveChildState.fromHistory(const [], EmotionState.sad);
      expect(s.sessionCount, 0);
      expect(s.previousActivity, isNull);
      expect(s.recentAccuracy, isNull);
      expect(s.emotionalComfort, EmotionalComfort.needsSupport);
    });

    test('computes real values from the history', () {
      final h = [
        makeSession(GameType.breathingGarden,
            level: 1, before: EmotionState.sad, after: EmotionState.calm,
            successes: 0, mistakes: 0, playAgain: true),
        makeSession(GameType.bubbleValley,
            level: 1, before: EmotionState.calm, after: EmotionState.happy,
            successes: 8, mistakes: 2, playAgain: false, avgMs: 2000, sdMs: 500),
      ];
      final s = AdaptiveChildState.fromHistory(h, EmotionState.happy);
      expect(s.sessionCount, 2);
      expect(s.previousActivity, GameType.bubbleValley.id);
      expect(s.previousEmotion, EmotionState.happy);
      expect(s.recentAccuracy, closeTo(0.8, 1e-9));
      expect(s.recentResponseTimeMs, 2000);
      expect(s.responseTimeVariabilityMs, 500);
      expect(s.completionRate, 1.0);
      expect(s.regulationActivitiesCompleted, 1);
      expect(s.replayRate, 0.5);
      expect(s.consecutiveSuccessfulSessions, 2);
      expect(s.recentMoodChange, MoodChange.improved);
      expect(s.activityHistory, [GameType.breathingGarden.id, GameType.bubbleValley.id]);
      expect(s.emotionalComfort, EmotionalComfort.comfortable);
    });

    test('difficult streak counts unfinished sessions', () {
      final h = [
        makeSession(GameType.memoryCastle, completed: false, interactions: 1),
        makeSession(GameType.patternPower, completed: false, interactions: 1),
      ];
      expect(AdaptiveChildState.fromHistory(h, null).consecutiveDifficultSessions, 2);
    });
  });

  test('journey has six steps and six distinct fixed activities', () {
    expect(AdaptiveGameEngine.journeyLength, 6);
    expect(AdaptiveGameEngine.fixedSequence.toSet().length, 6);
  });
}
