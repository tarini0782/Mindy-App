import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/characters/character_id.dart';
import 'package:mindy_app/characters/character_lines.dart';
import 'package:mindy_app/games/base/game_session_controller.dart';
import 'package:mindy_app/games/breathing_garden_game.dart';
import 'package:mindy_app/games/bubble_shooter_game.dart';
import 'package:mindy_app/games/cloud_hop_game.dart';
import 'package:mindy_app/games/happy_connect_game.dart';
import 'package:mindy_app/games/peekaboo_pals_game.dart';
import 'package:mindy_app/games/bubble_valley_game.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/memory_castle_game.dart';
import 'package:mindy_app/games/models/game_difficulty.dart';
import 'package:mindy_app/games/models/game_pace.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/games/pattern_power_game.dart';
import 'package:mindy_app/games/rainbow_puzzle_game.dart';
import 'package:mindy_app/games/treasure_journey_game.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';
import 'package:mindy_app/services/app_settings.dart';
import 'package:mindy_app/services/emotion_signal_client.dart';
import 'package:mindy_app/services/kara_status.dart';
import 'package:mindy_app/services/physiological_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('worlds, roles and characters', () {
    test('twenty-seven activities, six host characters, matching roles', () {
      expect(GameType.values.length, 27);
      expect(GameType.values.map((t) => t.character).toSet().length, 6);
      expect(GameType.values.where((t) => t.isRegulation).length, 3); // +Firefly Jar
      expect(GameType.breathingGarden.character, CharacterId.twinkle);
      expect(GameType.treasureJourney.title, 'Calm Maze');
      expect(GameType.memoryCastle.title, 'Feelings Memory');
      expect(GameType.bubbleValley.role, ActivityRole.supportive);
      expect(GameType.values.map((t) => t.worldKey).toSet().length, 18); // +firefly_meadow
      expect(GameType.values.map((t) => t.id).toSet().length, 27); // +firefly_jar
    });

    test('levels map to easy / medium / hard', () {
      expect(levelToDifficulty(1), DifficultyLevel.easy);
      expect(levelToDifficulty(2), DifficultyLevel.easy);
      expect(levelToDifficulty(3), DifficultyLevel.medium);
      expect(levelToDifficulty(4), DifficultyLevel.hard);
      expect(levelToDifficulty(5), DifficultyLevel.hard);
      expect(pickByLevel(0, 'a', 'b', 'c', 'd', 'e'), 'a');
      expect(pickByLevel(9, 'a', 'b', 'c', 'd', 'e'), 'e');
    });
  });

  group('game difficulty really changes gameplay (5 levels)', () {
    test('Breathing Garden gets richer and longer', () {
      final r = [for (var l = 1; l <= 5; l++) GardenParams.forLevel(l).richness];
      for (var i = 1; i < 5; i++) {
        expect(r[i] > r[i - 1], isTrue, reason: 'level ${i + 1}');
      }
      expect(GardenParams.forLevel(5).breaths > GardenParams.forLevel(1).breaths, isTrue);
    });

    test('Bubble Valley: smaller, faster, more targets; clouds only at 4-5', () {
      final p = [for (var l = 1; l <= 5; l++) BubbleParams.forLevel(l, GamePace.normal)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].radius < p[i - 1].radius, isTrue);
        expect(p[i].riseSpeed > p[i - 1].riseSpeed, isTrue);
        expect(p[i].target > p[i - 1].target, isTrue);
      }
      expect(p[2].cloudChance, 0.0);
      expect(p[3].cloudChance > 0, isTrue);
      expect(BubbleParams.forLevel(3, GamePace.slow).riseSpeed <
          BubbleParams.forLevel(3, GamePace.normal).riseSpeed, isTrue);
    });

    test('Feelings Memory: 3,4,5,6,7 pairs, shorter preview, look-alikes at 5', () {
      final m = [for (var l = 1; l <= 5; l++) MemoryParams.forLevel(l, GamePace.normal)];
      expect(m.map((e) => e.pairs).toList(), [3, 4, 5, 6, 7]);
      for (var i = 1; i < 5; i++) {
        expect(m[i].previewSec < m[i - 1].previewSec, isTrue);
      }
      expect(m[4].lookAlikes, isTrue);
      expect(m[3].lookAlikes, isFalse);
    });

    test('Pattern Power templates: AB, AAB, ABC, ABBC, longer', () {
      expect(PatternLogic.unitFor(1), [0, 1]);
      expect(PatternLogic.unitFor(2), [0, 0, 1]);
      expect(PatternLogic.unitFor(3), [0, 1, 2]);
      expect(PatternLogic.unitFor(4), [0, 1, 1, 2]);
      expect(PatternLogic.unitFor(5).length > 4, isTrue);
      for (var l = 1; l <= 5; l++) {
        final slots = {for (var r = 0; r < 6; r++) PatternLogic.answerSlot(l, round: r)};
        expect(slots.length > 1, isTrue, reason: 'answer moves at level $l');
      }
    });

    test('Rainbow Puzzle piece counts grow 3,4,5,6,8', () {
      expect([1, 2, 3, 4, 5].map(PuzzleScenes.pieceCount).toList(), [3, 4, 5, 6, 8]);
      for (var l = 1; l <= 5; l++) {
        expect(PuzzleScenes.forLevel(l).length, PuzzleScenes.pieceCount(l));
      }
    });

    test('Calm Maze: every treasure reachable; maps grow with level', () {
      int cells(List<String> m) => m.length * m.first.length;
      for (var l = 1; l <= 5; l++) {
        final m = TreasureMaps.forLevel(l);
        expect(m.every((r) => r.length == m.first.length), isTrue);
        // flood fill from S
        final rows = m.length, cols = m.first.length;
        var start = const [0, 0];
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if (m[r][c] == 'S') start = [r, c];
          }
        }
        final seen = <int>{start[0] * cols + start[1]};
        final stack = [start[0] * cols + start[1]];
        while (stack.isNotEmpty) {
          final cur = stack.removeLast();
          final r = cur ~/ cols, c = cur % cols;
          for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            final nr = r + d[0], nc = c + d[1];
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            if (m[nr][nc] == '#') continue;
            if (seen.add(nr * cols + nc)) stack.add(nr * cols + nc);
          }
        }
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            if ('*rgf'.contains(m[r][c])) {
              expect(seen.contains(r * cols + c), isTrue, reason: 'level $l');
            }
          }
        }
        if (l > 1) {
          expect(cells(m) >= cells(TreasureMaps.forLevel(l - 1)), isTrue);
        }
      }
    });
  });


  group('cute arcade-style games (shooter, connect, hop, peekaboo)', () {
    test('new activities are standard/engaging/supportive, never regulation', () {
      for (final t in [
        GameType.bubbleShooter,
        GameType.happyConnect,
        GameType.cloudHop,
        GameType.peekaboo,
      ]) {
        expect(t.isRegulation, isFalse);
      }
      expect(GameType.peekaboo.role, ActivityRole.supportive);
      expect(GameType.cloudHop.role, ActivityRole.engaging);
    });

    test('scared and sad are never offered the arcade-style games', () {
      for (final e in [EmotionState.scared, EmotionState.sad, null]) {
        for (var i = 0; i < 6; i++) {
          final r = AdaptiveGameEngine.recommend(emotion: e, journeyStep: i);
          expect([
            GameType.bubbleShooter,
            GameType.happyConnect,
            GameType.cloudHop,
          ].contains(r.gameType), isFalse, reason: '$e step $i');
        }
      }
    });

    test('Bubble Pop Shooter: more colours and rows, shorter guide with level', () {
      final p = [for (var l = 1; l <= 5; l++) ShooterParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].colors >= p[i - 1].colors, isTrue);
        expect(p[i].rows >= p[i - 1].rows, isTrue);
        expect(p[i].guideFraction <= p[i - 1].guideFraction, isTrue);
      }
      expect(p[4].colors > p[0].colors, isTrue);
      expect(p[4].guideFraction < p[0].guideFraction, isTrue);
    });

    test('HexGrid: neighbours are symmetric and clusters / floaters are found', () {
      final g = HexGrid(8, 6);
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.colsIn(r); c++) {
          for (final n in g.neighbors(r, c)) {
            final back = g.neighbors(n[0], n[1]);
            expect(back.any((b) => b[0] == r && b[1] == c), isTrue);
          }
        }
      }
      // three same-colour bubbles in a row on the top line
      g.cells[0][0] = 1;
      g.cells[0][1] = 1;
      g.cells[0][2] = 1;
      g.cells[0][3] = 2;
      expect(g.cluster(0, 0).length, 3);
      expect(g.floating(), isEmpty);
      // a bubble hanging with nothing above it is floating
      g.cells[3][2] = 4;
      expect(g.floating().length, 1);
      expect(g.filledCount, 5);
      expect(g.colorsPresent, {1, 2, 4});
    });

    test('Happy Connect: board grows; path rules (at most two bends)', () {
      final p = [for (var l = 1; l <= 5; l++) ConnectParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].rows * p[i].cols >= p[i - 1].rows * p[i - 1].cols, isTrue);
        expect(p[i].kinds >= p[i - 1].kinds, isTrue);
      }
      for (final q in p) {
        expect((q.rows * q.cols) % 2, 0, reason: 'needs an even tile count');
      }
      // padded 3x4 board (border of zeros)
      List<List<int>> board() => List.generate(5, (_) => List<int>.filled(6, 0));
      var g = board();
      g[1][1] = 1;
      g[1][4] = 1;
      expect(ConnectLogic.canConnect(g, 1, 1, 1, 4), isTrue);
      // different kinds never connect
      g[1][4] = 2;
      expect(ConnectLogic.canConnect(g, 1, 1, 1, 4), isFalse);
      // same tile never connects to itself
      expect(ConnectLogic.canConnect(g, 1, 1, 1, 1), isFalse);
      // tiles can go around blockers through the empty border
      g = board();
      g[2][1] = 1;
      g[2][4] = 1;
      g[2][2] = 3;
      g[2][3] = 3;
      expect(ConnectLogic.canConnect(g, 2, 1, 2, 4), isTrue);
      // a fully packed board forces three bends: not allowed
      g = board();
      for (var r = 1; r <= 3; r++) {
        for (var c = 1; c <= 4; c++) {
          g[r][c] = 5;
        }
      }
      g[1][1] = 1;
      g[3][4] = 1;
      expect(ConnectLogic.canConnect(g, 1, 1, 3, 4), isFalse);
      expect(ConnectLogic.findMove(g), isNotNull,
          reason: 'identical neighbours (kind 5) can still connect');
    });

    test('Cloud Hop: clouds shrink, star speeds up, glow only at levels 1-2', () {
      final p = [for (var l = 1; l <= 5; l++) HopParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].cloudWidth < p[i - 1].cloudWidth, isTrue);
        expect(p[i].periodSec < p[i - 1].periodSec, isTrue);
        expect(p[i].hops >= p[i - 1].hops, isTrue);
      }
      expect(p[0].showTargetGlow, isTrue);
      expect(p[1].showTargetGlow, isTrue);
      expect(p[2].showTargetGlow, isFalse);
      // still gentle: even the fastest sweep takes about two seconds
      expect(p[4].periodSec >= 2.0, isTrue);
    });

    test('Cloud Hop: a hop lands only if it ends on the cloud', () {
      final p = HopParams.forLevel(1);
      expect(p.lands(0, 200, 200), isTrue);
      expect(p.lands(0, 200 + p.cloudWidth / 2 - 1, 200), isTrue);
      expect(p.lands(0, 200 + p.cloudWidth / 2 + 5, 200), isFalse);
      // the star can show every needed distance
      for (var l = 1; l <= 5; l++) {
        final q = HopParams.forLevel(l);
        expect(q.minHop < q.gapMin && q.maxHop > q.gapMax, isTrue);
      }
    });

    test('Peekaboo Pals: shorter stays, more burrows and pals; sleepy from level 4', () {
      final p = [for (var l = 1; l <= 5; l++) PeekParams.forLevel(l)];
      for (var i = 1; i < 5; i++) {
        expect(p[i].lifetime < p[i - 1].lifetime, isTrue);
        expect(p[i].hellos > p[i - 1].hellos, isTrue);
        expect(p[i].rows * p[i].cols >= p[i - 1].rows * p[i - 1].cols, isTrue);
      }
      expect(p[2].sleepyChance, 0.0);
      expect(p[3].sleepyChance > 0, isTrue);
      // nothing is twitchy: even the shortest stay is over two seconds
      expect(p[4].lifetime >= 2.0, isTrue);
    });
  });

  group('pause / resume freezes game timers', () {
    testWidgets('a scheduled action does not fire while paused', (tester) async {
      final rec = AdaptiveGameEngine.recommend(emotion: EmotionState.neutral);
      final c = GameSessionController(recommendation: rec);
      var fired = 0;
      c.schedule(500, () => fired++);

      c.paused = true;
      await tester.pump(const Duration(seconds: 3));
      expect(fired, 0, reason: 'frozen while paused');

      c.paused = false;
      await tester.pump(const Duration(milliseconds: 300));
      expect(fired, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fired, 1);
      c.dispose();
    });

    testWidgets('disposing the controller cancels pending actions', (tester) async {
      final rec = AdaptiveGameEngine.recommend(emotion: EmotionState.neutral);
      final c = GameSessionController(recommendation: rec);
      var fired = 0;
      c.schedule(200, () => fired++);
      c.dispose();
      await tester.pump(const Duration(seconds: 2));
      expect(fired, 0);
    });

    test('controller reports statistics and response variability', () {
      final rec = AdaptiveGameEngine.recommend(emotion: EmotionState.neutral);
      final c = GameSessionController(recommendation: rec);
      c.recordSuccess();
      c.recordSuccess();
      c.recordMistake();
      for (final ms in [1000, 2000, 3000]) {
        c.recordResponse(ms);
      }
      expect(c.accuracy, closeTo(2 / 3, 1e-9));
      expect(c.avgResponseMs, 2000);
      expect(c.responseVariabilityMs, isNotNull);
      expect(c.responseVariabilityMs! > 0, isTrue);
      c.dispose();
    });
  });

  group('post-session emotion and incomplete sessions', () {
    test('mood change is after minus before, and never guessed', () {
      expect(computeMoodDelta(EmotionState.sad, EmotionState.calm), 2);
      expect(computeMoodDelta(EmotionState.happy, EmotionState.sad), -3);
      expect(computeMoodDelta(EmotionState.calm, EmotionState.calm), 0);
      expect(computeMoodDelta(null, EmotionState.calm), isNull);
      expect(computeMoodDelta(EmotionState.sad, null), isNull);
      expect(moodChangeOf(2), MoodChange.improved);
      expect(moodChangeOf(0), MoodChange.unchanged);
      expect(moodChangeOf(-1), MoodChange.worsened);
      expect(moodChangeOf(null), MoodChange.unknown);
    });

    test('leaving early is recorded as incomplete with low engagement', () {
      final s = makeSession(GameType.memoryCastle,
          completed: false, interactions: 1);
      expect(s.completed, isFalse);
      expect(s.engagement, EngagementLevel.low);
      expect(s.performanceBand, isNull); // no band for unfinished play
    });

    test('engagement rule: finished with few pauses is high', () {
      expect(
          computeEngagement(
              completed: true, completionPercent: 1, interactions: 9, pausedCount: 1),
          EngagementLevel.high);
      expect(
          computeEngagement(
              completed: true, completionPercent: 1, interactions: 9, pausedCount: 5),
          EngagementLevel.medium);
      expect(
          computeEngagement(
              completed: false, completionPercent: 0.1, interactions: 4, pausedCount: 0),
          EngagementLevel.low);
    });

    test('session JSON round trip keeps indicators', () {
      final s = makeSession(GameType.bubbleValley,
          before: EmotionState.sad,
          after: EmotionState.calm,
          avgMs: 1200,
          sdMs: 300,
          playAgain: true);
      final back = GameSession.fromJson(s.toJson());
      expect(back.moodDelta, 2);
      expect(back.avgResponseMs, 1200);
      expect(back.responseTimeVariabilityMs, 300);
      expect(back.playAgain, true);
      expect(back.trace.ruleId, s.trace.ruleId);
    });
  });

  group('KARA / external signal is never faked', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
      await AppSettings.instance.setUseMock(true);
      await AppSettings.instance.setSimulatedKara(null);
    });

    test('by default there is no robot signal and the link says so', () async {
      final c = await KaraStatusService.instance.fetchRecent();
      expect(c, isNull);
      expect(KaraStatusService.instance.link, KaraLink.notConnected);
    });

    test('a test signal is labelled KARA_SIMULATED, never KARA', () async {
      await AppSettings.instance.setSimulatedKara(EmotionState.sad);
      final c = await KaraStatusService.instance.fetchRecent();
      expect(c, isNotNull);
      expect(c!.simulated, isTrue);
      expect(c.source, EmotionSource.karaSimulated);
      expect(KaraStatusService.instance.link, KaraLink.simulated);
      await AppSettings.instance.setSimulatedKara(null);
    });

    test('a stale signal is ignored', () async {
      await AppSettings.instance.setSimulatedKara(EmotionState.sad);
      final later = DateTime.now().add(const Duration(hours: 2));
      final c = await KaraStatusService.instance.fetchRecent(now: later);
      expect(c, isNull);
      await AppSettings.instance.setSimulatedKara(null);
    });

    test('the real client refuses non-HTTPS addresses', () async {
      final r = RemoteEmotionSignalClient('http://insecure.example');
      expect(await r.ping(), isFalse);
      expect(await r.latestRobotCheckin('x'), isNull);
    });

    test('no physiological data is ever produced', () async {
      const src = NoPhysiologicalDataSource();
      expect(src.isAvailable, isFalse);
      expect(await src.latest(), isNull);
    });
  });

  group('child-facing language is gentle and metric-free', () {
    const banned = [
      'fail', 'wrong', 'bad', 'stupid', 'lose', 'lost', 'worse', 'sick',
      'diagnos', 'disorder', 'score', 'accuracy', 'percent', 'level ',
    ];

    test('no shaming, clinical or research words in any child line', () {
      final lines = <String>[
        CharacterLines.mindyGreeting,
        CharacterLines.celebrate,
        CharacterLines.learned,
        CharacterLines.whatsNext,
        CharacterLines.journeyDone,
        CharacterLines.lumiMiss,
        CharacterLines.novaTryAgain,
        CharacterLines.karaTryAgain,
        CharacterLines.hold,
        CharacterLines.breatheOut,
        CharacterLines.breathRest,
        ...CharacterLines.bubblesCatch,
        ...CharacterLines.lumiMatch,
        ...CharacterLines.novaCorrect,
        ...CharacterLines.karaPlace,
        ...CharacterLines.pipFind,
        ...CharacterLines.breatheIn,
      ];
      for (final id in CharacterId.values) {
        lines
          ..add(CharacterLines.start(id))
          ..add(CharacterLines.encourage(id))
          ..add(CharacterLines.completion(id));
      }
      for (final e in <EmotionState?>[null, ...EmotionState.values]) {
        lines
          ..add(CharacterLines.mindyIntro(e))
          ..add(CharacterLines.mindyIntro(e, recovery: true))
          ..add(CharacterLines.mindyIntro(e, afterRegulation: true));
        for (final a in EmotionState.values) {
          lines.add(CharacterLines.moodReaction(e, a));
        }
      }
      for (final e in EmotionState.values) {
        lines.add(e.sentence);
      }
      for (final t in GameType.values) {
        lines..add(t.invite)..add(t.tagline)..add(t.instruction);
      }
      for (final l in lines) {
        final lower = l.toLowerCase();
        expect(lower.trim().isNotEmpty, isTrue);
        for (final b in banned) {
          expect(lower.contains(b), isFalse, reason: '"$l" contains "$b"');
        }
      }
    });

    test('every recommendation hands the child friendly messages only', () {
      for (final c in StudyCondition.values) {
        for (final e in <EmotionState?>[null, ...EmotionState.values]) {
          final r = AdaptiveGameEngine.recommend(emotion: e, condition: c);
          final text = '${r.childMessage} ${r.hostMessage}'.toLowerCase();
          for (final b in banned) {
            expect(text.contains(b), isFalse, reason: '$c $e: $text');
          }
        }
      }
    });
  });
}
