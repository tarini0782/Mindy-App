import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/bee_collector_game.dart';
import 'package:mindy_app/games/bird_launcher_game.dart';
import 'package:mindy_app/games/dino_dash_game.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/hero_shield_game.dart';
import 'package:mindy_app/games/jellyfish_catcher_game.dart';
import 'package:mindy_app/games/memory_quest_game.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/games/support/support_engine.dart';
import 'package:mindy_app/games/turbo_car_game.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/export_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupportEngine ladder', () {
    test('one or two mistakes never trigger support', () {
      final e = SupportEngine();
      expect(e.onAttempt(ok: false), isNull);
      expect(e.onAttempt(ok: false), isNull);
      expect(e.offers, 0);
    });

    test('3 -> cue, 4 -> hint, 5 -> demo, 6 -> easier, 8 -> break', () {
      final e = SupportEngine();
      final got = <SupportStage>[];
      for (var i = 0; i < 8; i++) {
        final r = e.onAttempt(ok: false);
        if (r != null) got.add(r.stage);
      }
      expect(got, [
        SupportStage.visualCue,
        SupportStage.smallHint,
        SupportStage.demonstration,
        SupportStage.easier,
        SupportStage.breakOffer,
      ]);
      expect(e.highest, SupportStage.breakOffer);
    });

    test('fixed mode (no difficulty change) never offers "easier"', () {
      final e = SupportEngine(allowDifficultyChange: false);
      final got = <SupportStage>[];
      for (var i = 0; i < 9; i++) {
        final r = e.onAttempt(ok: false);
        if (r != null) got.add(r.stage);
      }
      expect(got.contains(SupportStage.easier), isFalse);
      expect(got.last, SupportStage.breakOffer);
    });

    test('a success resets the ladder and counts success after support', () {
      final e = SupportEngine();
      for (var i = 0; i < 3; i++) {
        e.onAttempt(ok: false);
      }
      expect(e.current, SupportStage.visualCue);
      e.onAttempt(ok: true);
      expect(e.current, SupportStage.independent);
      expect(e.consecutiveErrors, 0);
      expect(e.attemptsAfterSupport, 1);
      expect(e.successesAfterSupport, 1);
    });

    test('child request goes to hint first, then demonstration', () {
      final e = SupportEngine();
      expect(e.request()!.stage, SupportStage.smallHint);
      expect(e.request()!.stage, SupportStage.demonstration);
      expect(e.request()!.stage, SupportStage.demonstration);
      expect(e.history.every((x) => x.trigger == SupportTrigger.requested), isTrue);
    });

    test('idle gives only the gentlest cue, once', () {
      final e = SupportEngine();
      expect(e.onIdle()!.stage, SupportStage.visualCue);
      expect(e.onIdle(), isNull);
    });

    test('automatic offers are capped', () {
      final e = SupportEngine(config: const SupportConfig(maxAutomatic: 2));
      var n = 0;
      for (var i = 0; i < 30; i++) {
        if (i % 4 == 0) e.onAttempt(ok: true);
        if (e.onAttempt(ok: false) != null) n++;
      }
      expect(e.automaticOffers <= 2, isTrue);
      expect(n <= 2, isTrue);
    });
  });

  group('support inside a real controller', () {
    GameSessionController make({bool allowChange = true}) =>
        GameSessionController(
          recommendation:
              AdaptiveGameEngine.recommend(emotion: EmotionState.neutral),
          allowDifficultyChange: allowChange,
        );

    test('errors log support events and call onEasier once in adaptive mode', () {
      final c = make();
      var easier = 0;
      c.onEasier = () => easier++;
      for (var i = 0; i < 6; i++) {
        c.recordMistake();
      }
      final stages = c.events
          .where((e) => e.type == 'support')
          .map((e) => e.valueMs!.round())
          .toList();
      expect(stages, [1, 2, 3, 4]);
      expect(easier, 1);
      expect(c.difficultyAdjustments, 1);
      expect(c.events.where((e) => e.type == 'difficulty').length, 1);
      c.dispose();
    });

    test('fixed mode never adjusts difficulty', () {
      final c = make(allowChange: false);
      var easier = 0;
      c.onEasier = () => easier++;
      for (var i = 0; i < 9; i++) {
        c.recordMistake();
      }
      expect(easier, 0);
      expect(c.difficultyAdjustments, 0);
      expect(c.events.where((e) => e.type == 'difficulty'), isEmpty);
      c.dispose();
    });

    test('success returns the cue to independent', () {
      final c = make();
      for (var i = 0; i < 3; i++) {
        c.recordMistake();
      }
      expect(c.supportCue.value, SupportStage.visualCue);
      c.recordSuccess();
      expect(c.supportCue.value, SupportStage.independent);
      c.dispose();
    });

    test('help button: hint text is spoken and logged as requested support', () {
      final c = make();
      c.hintText = () => 'Find the blue one';
      c.requestHelp();
      expect(c.say.value!.text, 'Find the blue one');
      expect(c.events.last.type, 'support');
      c.dispose();
    });
  });

  group('session record keeps support summary', () {
    test('JSON round trip and CSV columns', () {
      final s = makeSession(GameType.jellyfishCatcher);
      s.supportCount = 3;
      s.maxSupportStage = 3;
      s.attemptsAfterSupport = 4;
      s.successesAfterSupport = 3;
      s.difficultyAdjustments = 1;
      final back = GameSession.fromJson(s.toJson());
      expect(back.supportCount, 3);
      expect(back.maxSupportStage, 3);
      expect(back.attemptsAfterSupport, 4);
      expect(back.successesAfterSupport, 3);
      expect(back.difficultyAdjustments, 1);
      for (final col in [
        'supportCount',
        'maxSupportStage',
        'attemptsAfterSupport',
        'successesAfterSupport',
        'difficultyAdjustments'
      ]) {
        expect(ExportService.csvColumns.contains(col), isTrue, reason: col);
      }
      final header = ExportService.toCsv([s], participantId: 'P1').split('\n').first;
      expect(header.split(',').length, ExportService.csvColumns.length);
    });
  });

  group('Jellyfish Catcher', () {
    test('levels: more targets, faster, rule changes at spread points', () {
      final p = [for (var l = 1; l <= 5; l++) JellyParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].targets >= p[i - 1].targets, isTrue);
        expect(p[i].speed > p[i - 1].speed, isTrue);
      }
      expect(p[0].changePoints, isEmpty);
      expect(p[4].changePoints.length, 2);
      expect(p[4].changePoints.every((x) => x > 0 && x < p[4].targets), isTrue);
    });

    test('rules pick different jellyfish; there is always a target to catch', () {
      expect(JellyLogic.isTarget(JellyRule.blue, 1, false), isTrue);
      expect(JellyLogic.isTarget(JellyRule.blue, 0, true), isFalse);
      expect(JellyLogic.isTarget(JellyRule.spots, 0, true), isTrue);
      expect(JellyLogic.ruleAfterChanges(0), JellyRule.blue);
      expect(JellyLogic.ruleAfterChanges(1), JellyRule.spots);
      for (final rule in JellyRule.values) {
        for (var seed = 0; seed < 30; seed++) {
          final (c, s) =
              JellyLogic.make(rule, Random(seed), needTarget: true);
          expect(JellyLogic.isTarget(rule, c, s), isTrue);
        }
      }
    });
  });

  group('Hero Shield', () {
    test('match and swap rules', () {
      expect(ShieldLogic.correctShield(0, ShieldRule.match), 0);
      expect(ShieldLogic.correctShield(1, ShieldRule.match), 1);
      expect(ShieldLogic.correctShield(0, ShieldRule.swap), 1);
      expect(ShieldLogic.correctShield(1, ShieldRule.swap), 0);
      expect(ShieldLogic.correctShield(2, ShieldRule.swap), 2);
    });

    test('rule flips at the switch points, harder levels switch more', () {
      expect(ShieldLogic.ruleAt(0, [5]), ShieldRule.match);
      expect(ShieldLogic.ruleAt(5, [5]), ShieldRule.swap);
      expect(ShieldLogic.ruleAt(9, [5, 8]), ShieldRule.match);
      expect(ShieldParams.forLevel(1).switchAt, isEmpty);
      expect(ShieldParams.forLevel(5).switchAt.length, 3);
      expect(ShieldParams.forLevel(5).fallSec < ShieldParams.forLevel(1).fallSec,
          isTrue);
    });
  });

  group('Rainbow Memory Quest', () {
    test('sequences are reproducible, right length, no triple repeats', () {
      final a = SequenceLogic.make(7, 6, Random(5));
      final b = SequenceLogic.make(7, 6, Random(5));
      expect(a, b);
      expect(a.length, 7);
      for (var i = 2; i < a.length; i++) {
        expect(a[i] == a[i - 1] && a[i] == a[i - 2], isFalse);
      }
    });

    test('correctness check and growth with level', () {
      expect(SequenceLogic.isCorrect([2, 1], 1, 1), isTrue);
      expect(SequenceLogic.isCorrect([2, 1], 1, 2), isFalse);
      expect(SequenceLogic.isCorrect([2, 1], 5, 2), isFalse);
      for (var l = 2; l <= 5; l++) {
        final prev = QuestParams.forLevel(l - 1);
        final cur = QuestParams.forLevel(l);
        final maxPrev = prev.lengthForRound(prev.rounds - 1);
        final maxCur = cur.lengthForRound(cur.rounds - 1);
        expect(maxCur >= maxPrev, isTrue);
      }
      expect(QuestParams.forLevel(5).lengthForRound(3), 7);
    });
  });

  group('Turbo Car', () {
    test('a row never blocks all three lanes; at least one lane is clear', () {
      for (var l = 1; l <= 5; l++) {
        final p = CarParams.forLevel(l);
        for (var seed = 0; seed < 60; seed++) {
          final b = LaneLogic.blockedLanes(Random(seed), p.maxBlocked);
          expect(b.length <= 2 && b.isNotEmpty, isTrue);
          expect(LaneLogic.clearLanes(b), isNotEmpty);
          if (p.maxBlocked == 1) expect(b.length, 1);
        }
      }
    });

    test('collision rule and lane clamping; harder levels are faster', () {
      expect(LaneLogic.collides({1}, 1), isTrue);
      expect(LaneLogic.collides({1}, 0), isFalse);
      expect(LaneLogic.clampLane(-1), 0);
      expect(LaneLogic.clampLane(3), 2);
      expect(CarParams.forLevel(5).rowsPerSec > CarParams.forLevel(1).rowsPerSec,
          isTrue);
    });
  });

  group('Dino Dash', () {
    test('jump arc and hit rules (jump cactus, stay low for birds)', () {
      expect(DashLogic.height(0), 0);
      expect(DashLogic.height(DashLogic.jumpSec / 2), closeTo(DashLogic.peak, 1e-6));
      expect(DashLogic.height(2), 0);
      expect(DashLogic.hits(Obstacle.cactus, 0), isTrue);
      expect(DashLogic.hits(Obstacle.cactus, 80), isFalse);
      expect(DashLogic.hits(Obstacle.bird, 0), isFalse);
      expect(DashLogic.hits(Obstacle.bird, 80), isTrue);
    });

    test('birds only from level 3, never in the first two obstacles', () {
      expect(DashParams.forLevel(2).birds, isFalse);
      expect(DashParams.forLevel(3).birds, isTrue);
      final seq = DashLogic.sequence(16, true, Random(3));
      expect(seq.take(2).every((o) => o == Obstacle.cactus), isTrue);
      expect(DashLogic.sequence(16, false, Random(3)).contains(Obstacle.bird),
          isFalse);
    });
  });

  group('Honey Bee Collector', () {
    test('required colour follows the rule and switches halfway', () {
      final p = BeeParams.forLevel(3); // [[0,1],[2,3]]
      expect(BeeLogic.needed(p, 0), 0);
      expect(BeeLogic.needed(p, 1), 1);
      expect(BeeLogic.needed(p, 2), 0);
      expect(BeeLogic.needed(p, p.switchAt), 2);
      expect(BeeLogic.needed(p, p.switchAt + 1), 3);
    });

    test('the needed colour is always available on the grid', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = List<int>.filled(9, 1);
        BeeLogic.ensureAvailable(g, 3, Random(seed));
        expect(g.contains(3), isTrue);
      }
    });
  });

  group('Bird Launcher physics', () {
    const bounds = Rect.fromLTWH(0, 0, 360, 520);
    const home = Offset(65, 343);

    test('a solution exists for typical targets and it really hits', () {
      for (final t in const [Offset(250, 150), Offset(300, 220), Offset(280, 300)]) {
        final shot = LaunchPhysics.solve(
            home: home, target: t, radius: 30, bounds: bounds);
        expect(shot, isNotNull, reason: '$t');
        final r = LaunchPhysics.simulate(
          home: home,
          v0: LaunchPhysics.velocity(shot!.pull, shot.angleDeg),
          target: t,
          radius: 30,
          bounds: bounds,
        );
        expect(r.hit, isTrue);
      }
    });

    test('a wall can block, a harder level has a smaller balloon', () {
      final wall = Rect.fromLTWH(170, 260, 14, 104);
      final miss = LaunchPhysics.simulate(
        home: home,
        v0: LaunchPhysics.velocity(40, 5),
        target: const Offset(300, 340),
        radius: 20,
        bounds: bounds,
        wall: wall,
      );
      expect(miss.hit, isFalse);
      expect(LauncherParams.forLevel(5).radius < LauncherParams.forLevel(1).radius,
          isTrue);
      expect(LauncherParams.forLevel(4).wall, isTrue);
      expect(LauncherParams.forLevel(1).wall, isFalse);
    });
  });

  group('adaptive engine safety, all games', () {
    test('scared / sad / skipped only ever get the calm activities', () {
      for (final e in [EmotionState.scared, EmotionState.sad, null]) {
        for (var i = 0; i < 6; i++) {
          final r = AdaptiveGameEngine.recommend(emotion: e, journeyStep: i);
          expect(r.gameType == GameType.breathingGarden ||
              r.gameType == GameType.treasureJourney ||
              r.gameType == GameType.bubbleValley, isTrue,
              reason: '$e step $i -> ${r.gameType}');
        }
      }
    });

    test('every game has a role, a title, a character and is registered', () {
      expect(GameType.values.length, 27);
      for (final t in GameType.values) {
        expect(t.title.isNotEmpty, isTrue);
        expect(t.instruction.isNotEmpty, isTrue);
        expect(t.role, isNotNull);
      }
    });
  });
}
