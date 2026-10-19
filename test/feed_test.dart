import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/feed/feed_log_service.dart';
import 'package:mindy_app/feed/feed_planner.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/screens/feed_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<FeedItem> plan(int n, {EmotionState? e, int skips = 0}) {
  final shown = <FeedItem>[];
  for (var i = 0; i < n; i++) {
    shown.add(FeedPlanner.next(index: i, shown: shown, lastEmotion: e, skipStreak: skips));
  }
  return shown;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('planner', () {
    test('a scared or sad child only sees quiet games, at the easiest level', () {
      for (final e in [EmotionState.scared, EmotionState.sad]) {
        for (final it in plan(30, e: e)) {
          expect(it.kind, FeedKind.calmBreak);
          expect(AdaptiveGameEngine.calmPool.contains(it.game), isTrue, reason: it.game.id);
          expect(it.level, 1);
        }
      }
    });

    test('mixes challenge, fun and a quiet break every fourth card', () {
      final items = plan(12, e: EmotionState.happy);
      for (final it in items) {
        if (it.index % 4 == 3) {
          expect(it.kind, FeedKind.calmBreak);
        } else if (it.index.isEven) {
          expect(it.kind, FeedKind.challenge);
        } else {
          expect(it.kind, FeedKind.fun);
        }
      }
    });

    test('no game repeats inside the window', () {
      final items = plan(60, e: EmotionState.happy);
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length && j <= i + FeedPlanner.noRepeatWindow - 2; j++) {
          // Only games from the same pool can clash; windows are checked on
          // the whole list so a repeat inside the window must not happen.
          if (items[i].game == items[j].game) {
            fail('repeat of ${items[i].game.id} at $i and $j');
          }
        }
      }
    });

    test('three quick skips in a row offer a quiet game', () {
      final it = FeedPlanner.next(index: 4, shown: const [], lastEmotion: EmotionState.happy, skipStreak: 3);
      expect(it.kind, FeedKind.calmBreak);
      expect(it.reason, contains('swiped past'));
    });

    test('every card carries a plain reason', () {
      for (final it in plan(10, e: EmotionState.neutral)) {
        expect(it.reason.isNotEmpty, isTrue);
      }
    });
  });

  group('log', () {
    test('stats: play rate, quick skips and median dwell', () {
      final t = DateTime(2026, 1, 1);
      FeedView v(int d, bool p) => FeedView(
          at: t, index: 0, gameId: 'x', kind: 'fun', dwellMs: d, played: p);
      final s = FeedStats.of([v(1000, false), v(2000, false), v(9000, true), v(5000, false)]);
      expect(s.views, 4);
      expect(s.plays, 1);
      expect(s.quickSkips, 2);
      expect(s.medianDwellMs, 3500);
      expect(s.playRate, 0.25);
    });

    test('empty log gives no rates (no invented numbers)', () {
      final s = FeedStats.of(const []);
      expect(s.playRate, isNull);
      expect(s.quickSkipRate, isNull);
    });

    test('saved per child, survives reload, deleted with the child', () async {
      final l = FeedLogService.instance;
      await l.load('P-AAAAAA');
      await l.add(FeedView(at: DateTime(2026, 1, 1), index: 1, gameId: 'g', kind: 'calm', dwellMs: 4000, played: true));
      await l.load('P-BBBBBB');
      expect(l.views, isEmpty);
      await l.load('P-AAAAAA');
      expect(l.views.length, 1);
      expect(l.toCsv('P-AAAAAA'), contains('P-AAAAAA,2026-01-01'));
      await l.deleteForChild('P-AAAAAA');
      await l.load('P-AAAAAA');
      expect(l.views, isEmpty);
    });
  });

  testWidgets('feed shows a card and swipes up to the next one', (tester) async {
    await FeedLogService.instance.load('P-WIDGET');
    await tester.pumpWidget(const MaterialApp(home: FeedScreen()));
    await tester.pump();
    expect(find.byKey(const Key('feedCard_0')), findsOneWidget);
    expect(find.byKey(const Key('feedPlay_0')), findsOneWidget);
    await tester.fling(find.byKey(const Key('feedPager')), const Offset(0, -600), 2000);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('feedCard_1')), findsOneWidget);
  });
}
