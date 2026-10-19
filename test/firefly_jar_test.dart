import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/firefly_jar_game.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/screens/game_library_screen.dart';

void main() {
  group('Firefly Jar is registered correctly', () {
    test('unique id, in GameType.values, counted once', () {
      expect(GameType.fireflyJar.id, 'firefly_jar');
      expect(GameType.values.contains(GameType.fireflyJar), isTrue);
      expect(GameType.values.map((t) => t.id).toSet().length, GameType.values.length);
      expect(GameType.values.length, 27);
    });

    test('is a regulation activity and in the calm pool', () {
      expect(GameType.fireflyJar.isRegulation, isTrue);
      expect(AdaptiveGameEngine.calmPool.contains(GameType.fireflyJar), isTrue);
    });

    test('a scared check-in can recommend it, and it stays in the calm pool', () {
      // Run many times: the engine may pick either regulation game, but
      // whichever it picks must be a calm-pool member, every time.
      for (var i = 0; i < 20; i++) {
        final r = AdaptiveGameEngine.recommend(emotion: EmotionState.scared);
        expect(AdaptiveGameEngine.calmPool.contains(r.gameType), isTrue);
      }
    });
  });

  group('FireflyParams.forLevel', () {
    test('more fireflies to catch at higher levels', () {
      expect(FireflyParams.forLevel(1).toCatch, lessThan(FireflyParams.forLevel(5).toCatch));
    });
    test('more fireflies can be lit at once at higher levels', () {
      expect(FireflyParams.forLevel(1).maxLit, lessThanOrEqualTo(FireflyParams.forLevel(5).maxLit));
      expect(FireflyParams.forLevel(5).maxLit, greaterThan(1));
    });
    test('the pause between new fireflies shortens as level rises, never rushed', () {
      expect(FireflyParams.forLevel(5).spawnPauseMs, lessThan(FireflyParams.forLevel(1).spawnPauseMs));
      expect(FireflyParams.forLevel(5).spawnPauseMs, greaterThanOrEqualTo(1000));
    });
    test('out-of-range levels clamp instead of crashing', () {
      expect(() => FireflyParams.forLevel(0), returnsNormally);
      expect(() => FireflyParams.forLevel(99), returnsNormally);
    });
  });

  group('Firefly Jar plays without crashing and completes', () {
    testWidgets('tapping every lit firefly reaches completion, never a mistake',
        (tester) async {
      final rec = practiceRecommendation(GameType.fireflyJar, 1); // level 1: 5 to catch
      final c = GameSessionController(recommendation: rec);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: FireflyJarGame(controller: c),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      var guard = 0;
      while (!c.completed && guard < 60) {
        final glow = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_GlowingFirefly');
        if (glow.evaluate().isNotEmpty) {
          await tester.tap(glow.first);
          await tester.pump(const Duration(milliseconds: 50));
        } else {
          await tester.pump(const Duration(milliseconds: 300));
        }
        guard++;
      }

      expect(c.completed, isTrue, reason: 'should finish well within the loop guard');
      expect(c.mistakes, 0, reason: 'tapping a glowing firefly is always a success here');
      expect(c.successes, 5);

      // The controller owns a 1s periodic timer and a 3s speech timer, and
      // it was created here rather than by the widget, so the widget's own
      // dispose does not end them. This must happen INSIDE the test body:
      // the framework checks for pending timers before addTearDown runs.
      await tester.pumpWidget(const SizedBox.shrink()); // unmount the game
      c.dispose();
    });

    testWidgets('tapping empty sky logs a touch, never a mistake, never crashes',
        (tester) async {
      final rec = practiceRecommendation(GameType.fireflyJar, 1);
      final c = GameSessionController(recommendation: rec);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 360, height: 640, child: FireflyJarGame(controller: c)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap a corner far from where a 56x56 firefly is likely centred.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.mistakes, 0);
      expect(c.completed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink()); // unmount the game
      c.dispose(); // see the note in the test above
    });
  });
}
