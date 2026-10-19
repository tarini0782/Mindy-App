import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/games/rule_shift_game.dart';
import 'package:mindy_app/games/sleepy_fox_game.dart';
import 'package:mindy_app/insights/rule_indicators.dart';
import 'package:mindy_app/models/emotion_state.dart';

import 'test_helpers.dart';

GameSession _shift(List<String> types, {int level = 3}) {
  final s = makeSession(GameType.ruleShift, level: level);
  var t = 0;
  s.events = [for (final x in types) TrialEvent(t += 500, x)];
  return s;
}

void main() {
  group('Sorting Stars logic', () {
    test('colour and shape rules point at different boxes', () {
      for (final c in const [SortCard(0, 1), SortCard(1, 0)]) {
        expect(SortLogic.isConflicting(c), isTrue);
        expect(SortLogic.correctSide(c, SortRule.colour) !=
            SortLogic.correctSide(c, SortRule.shape), isTrue);
      }
      expect(SortLogic.correctSide(const SortCard(0, 1), SortRule.colour), 0);
      expect(SortLogic.correctSide(const SortCard(0, 1), SortRule.shape), 1);
    });

    test('levels add rule changes and hide the cue later', () {
      final p = [for (var l = 1; l <= 5; l++) RuleShiftParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].blocks.length >= p[i - 1].blocks.length, isTrue);
        expect(p[i].totalCards >= p[i - 1].totalCards, isTrue);
      }
      expect(p[0].ruleAlwaysShown, isTrue);
      expect(p[4].ruleAlwaysShown, isFalse);
      expect(p[0].blocks.length, 2);
      expect(p[4].blocks.length, 4);
    });

    test('post-switch window is the first two cards after a change', () {
      expect(SortLogic.isPostSwitch(0, 0), isFalse);
      expect(SortLogic.isPostSwitch(1, 0), isTrue);
      expect(SortLogic.isPostSwitch(1, 1), isTrue);
      expect(SortLogic.isPostSwitch(1, 2), isFalse);
    });
  });

  group('Sleepy Fox logic', () {
    test('sequence: first two are friends, no 3 foxes in a row, right count', () {
      for (var l = 1; l <= 5; l++) {
        final p = FoxParams.forLevel(l);
        for (var seed = 0; seed < 25; seed++) {
          final seq = FoxLogic.sequence(p.items, p.foxShare, Random(seed));
          expect(seq.length, p.items);
          expect(seq[0] || seq[1], isFalse);
          expect(seq.where((x) => x).length, p.foxCount);
          var run = 0;
          for (final f in seq) {
            run = f ? run + 1 : 0;
            expect(run <= 2, isTrue);
          }
        }
      }
    });

    test('harder levels give less time to answer', () {
      for (var l = 2; l <= 5; l++) {
        expect(FoxParams.forLevel(l).stimSec < FoxParams.forLevel(l - 1).stimSec,
            isTrue);
      }
    });
  });

  group('event types', () {
    test('new markers survive a save/load round trip, old codes unchanged', () {
      expect(TrialEvent.types.sublist(0, 4),
          ['success', 'mistake', 'touch', 'response']);
      for (final t in ['commission', 'perseveration', 'omission', 'rule_change']) {
        final back = TrialEvent.fromList(TrialEvent(10, t).toList())!;
        expect(back.type, t);
      }
    });
  });

  group('rule-based indicators', () {
    test('switch stats count only the 2 answers after each change', () {
      final s = _shift(['success', 'success', 'rule_change', 'mistake',
        'mistake', 'success', 'success']);
      final st = RuleIndicators.switchStats(s);
      expect(st.postN, 2);
      expect(st.postErr, 2);
      expect(st.otherN, 4);
      expect(st.otherErr, 0);
    });

    test('too little data -> notEnoughData, never a verdict', () {
      for (final i in RuleIndicators.compute(const [])) {
        expect(i.level, IndicatorLevel.notEnoughInformation);
        expect(i.rule.isNotEmpty, isTrue);
      }
    });

    test('big switch cost -> worth reviewing; none -> nothing stood out', () {
      List<String> block(bool bad) => [
            'success', 'success', 'success', 'success',
            'rule_change', bad ? 'mistake' : 'success',
            bad ? 'mistake' : 'success', 'success', 'success'
          ];
      final bad = [for (var i = 0; i < 4; i++) _shift(block(true))];
      final good = [for (var i = 0; i < 4; i++) _shift(block(false))];
      expect(RuleIndicators.flexibility(bad).level, IndicatorLevel.worthReviewing);
      expect(RuleIndicators.flexibility(good).level, IndicatorLevel.noNotablePattern);
    });

    test('fox: tapping the sleeping fox -> worth reviewing', () {
      GameSession fox(int commissions) {
        final s = makeSession(GameType.sleepyFox, level: 3);
        s.events = [
          for (var i = 0; i < commissions; i++) TrialEvent(i * 100, 'commission')
        ];
        return s;
      }

      final p = FoxParams.forLevel(3);
      expect(p.foxCount, greaterThan(2));
      final many = [fox(p.foxCount), fox(p.foxCount)];
      final none = [fox(0), fox(0)];
      expect(RuleIndicators.stopping(many).level, IndicatorLevel.worthReviewing);
      expect(RuleIndicators.stopping(none).level, IndicatorLevel.noNotablePattern);
    });

    test('no indicator wording contains diagnosis language', () {
      final all = RuleIndicators.compute(const []);
      for (final i in all) {
        final t = '${i.headline} ${i.title}'.toLowerCase();
        for (final w in ['adhd', 'autis', 'disorder', 'diagnos', 'deficit', 'poor attention', 'inattent', 'impulsiv', 'anxi', 'depress']) {
          expect(t.contains(w), isFalse);
        }
      }
    });
  });

  group('adaptive engine safety with the new games', () {
    test('scared / sad / skipped are never offered Sorting Stars or Sleepy Fox', () {
      for (final e in [EmotionState.scared, EmotionState.sad, null]) {
        for (var i = 0; i < 6; i++) {
          final r = AdaptiveGameEngine.recommend(emotion: e, journeyStep: i);
          expect(r.gameType == GameType.ruleShift ||
              r.gameType == GameType.sleepyFox, isFalse);
        }
      }
    });
  });
}
