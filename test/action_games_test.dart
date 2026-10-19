import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/cloud_bounce_game.dart';
import 'package:mindy_app/games/dance_party_game.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/fruit_slice_game.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/screens/game_library_screen.dart';
import 'test_helpers.dart';

GameSessionController _ctl({bool allow = true}) => GameSessionController(
    recommendation: AdaptiveGameEngine.recommend(emotion: EmotionState.happy),
    allowDifficultyChange: allow);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Bounce', () {
    test('every level has reachable cloud gaps', () {
      for (var l = 1; l <= 5; l++) {
        expect(BounceLogic.gapReachable(BounceParams.forLevel(l).gap), isTrue, reason: 'level $l');
      }
    });
    test('landing only when falling through the cloud top', () {
      bool land(double v, double prev, double foot) => BounceLogic.lands(
          prevFoot: prev, foot: foot, cloudY: 100, px: 50, cloudX: 50, cloudW: 100, vy: v);
      expect(land(200, 95, 105), isTrue);
      expect(land(-200, 95, 105), isFalse, reason: 'rising');
      expect(land(200, 110, 120), isFalse, reason: 'already below');
    });
    test('level 1 has no storm obstacles, level 5 has them', () {
      expect(BounceParams.forLevel(1).stormChance, 0);
      expect(BounceParams.forLevel(5).stormChance > 0, isTrue);
    });
  });

  group('Fruit Slice', () {
    test('segment distance', () {
      expect(SliceLogic.distToSegment(const Offset(5, 5), const Offset(0, 0), const Offset(10, 0)), 5);
      expect(SliceLogic.distToSegment(const Offset(20, 0), const Offset(0, 0), const Offset(10, 0)), 10);
      expect(SliceLogic.distToSegment(const Offset(1, 1), const Offset(3, 3), const Offset(3, 3)) > 2, isTrue);
    });
    test('a swipe through the middle slices; one that misses does not', () {
      expect(SliceLogic.sliced(const Offset(50, 50), 30, const Offset(0, 50), const Offset(100, 50)), isTrue);
      expect(SliceLogic.sliced(const Offset(50, 150), 30, const Offset(0, 50), const Offset(100, 50)), isFalse);
    });
    test('launch speed reaches the chosen peak', () {
      final v = SliceLogic.launchSpeed(300, 520);
      expect(v * v / (2 * 520), closeTo(300, 0.001));
    });
    test('no socks when no fruit is flying; none at level 1', () {
      final r = Random(4);
      for (var i = 0; i < 50; i++) {
        expect(SliceLogic.nextIsSock(r, 1.0, fruitFlying: false), isFalse);
      }
      expect(SliceParams.forLevel(1).sockShare, 0);
    });
  });

  group('Dance Party', () {
    test('timing window and error', () {
      expect(DanceLogic.inWindow(100, 120, 46), isTrue);
      expect(DanceLogic.inWindow(30, 120, 46), isFalse);
      expect(DanceLogic.timingErrorMs(130, 100, 150), 200);
    });
    test('lanes grow with level; level 1 has no quiet notes', () {
      expect(DanceParams.forLevel(1).lanes, 3);
      expect(DanceParams.forLevel(5).lanes, 4);
      expect(DanceParams.forLevel(1).quietShare, 0);
    });
    test('no quiet note without a real note on screen', () {
      final r = Random(8);
      for (var i = 0; i < 50; i++) {
        expect(DanceLogic.nextIsQuiet(r, 1.0, realOnScreen: false), isFalse);
      }
    });
  });

  group('in-game flow adaptation (harder after a run of successes)', () {
    test('five clean successes raise difficulty once, and log it', () {
      final c = _ctl();
      var harder = 0;
      c.onHarder = () => harder++;
      for (var i = 0; i < GameSessionController.streakForHarder; i++) {
        c.recordSuccess();
      }
      expect(harder, 1);
      expect(c.harderSteps, 1);
      expect(c.events.map((e) => e.type), contains('difficulty'));
      c.dispose();
    });
    test('a mistake resets the streak', () {
      final c = _ctl();
      var harder = 0;
      c.onHarder = () => harder++;
      for (var i = 0; i < 4; i++) {
        c.recordSuccess();
      }
      c.recordMistake();
      c.recordSuccess();
      expect(harder, 0);
      c.dispose();
    });
    test('never in the fixed baseline arm; capped per session', () {
      final fixed = _ctl(allow: false);
      var n = 0;
      fixed.onHarder = () => n++;
      for (var i = 0; i < 30; i++) {
        fixed.recordSuccess();
      }
      expect(n, 0);
      fixed.dispose();
      final c = _ctl();
      var m = 0;
      c.onHarder = () => m++;
      for (var i = 0; i < 60; i++) {
        c.recordSuccess();
      }
      expect(m, GameSessionController.maxHarder);
      c.dispose();
    });
  });

  group('child feedback changes the next level', () {
    test('"it felt hard" steps down by one; never below the floor', () {
      final past = makeSession(GameType.cloudBounce, level: 4,
          before: EmotionState.happy, after: EmotionState.happy)
        ..perceivedDifficulty = 3;
      final rec = AdaptiveGameEngine.recommend(
          emotion: EmotionState.happy, history: [past]);
      if (rec.gameType == GameType.cloudBounce) {
        expect(rec.level, lessThan(4));
      }
      expect(rec.level >= 3, isTrue, reason: 'happy range floor is 3');
    });
  });

  group('library shows the action games first', () {
    test('featured games lead the list', () {
      final r = GameLibraryScreen.filterGames(GameType.values);
      expect(r.first, GameType.cloudBounce);
      expect(r.length, GameType.values.length);
    });
  });
}
