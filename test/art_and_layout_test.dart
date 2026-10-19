import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/art/sprite_data.dart';
import 'package:mindy_app/art/sprites.dart';
import 'package:mindy_app/games/base/game_shell.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/insight_dashboard.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'test_helpers.dart';

void main() {
  group('artwork', () {
    test('every sprite is a well-formed svg with a viewBox', () {
      for (final e in kSpriteSvg.entries) {
        expect(e.value.startsWith('<svg'), isTrue, reason: e.key);
        expect(e.value.trim().endsWith('</svg>'), isTrue, reason: e.key);
        expect(e.value.contains('viewBox'), isTrue, reason: e.key);
      }
    });

    test('each of the six hosts has front-view art', () {
      for (final n in ['kara', 'nova', 'lumi', 'bubbles', 'pip', 'twinkle']) {
        expect(Sprite.has('host_$n'), isTrue, reason: n);
      }
    });

    test('every sprite name used in the source exists', () {
      final used = RegExp(r"Sprite\(\s*'([a-z_]+)'");
      final missing = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        for (final m in used.allMatches(src)) {
          if (!Sprite.has(m.group(1)!)) missing.add('${f.path}: ${m.group(1)}');
        }
      }
      expect(missing, isEmpty);
    });

    test('vehicles and animals are never drawn with emoji in game files', () {
      // emoji face different ways on different phones; use Sprite instead
      final banned = ['1F697', '1F996', '1F985', '1F432', '1F984'];
      final offenders = <String>[];
      for (final name in ['turbo_car_game', 'dino_dash_game', 'sky_flight_game',
          'cloud_bounce_game']) {
        final src = File('lib/games/$name.dart').readAsStringSync();
        for (final b in banned) {
          if (RegExp("Text\\([^)]*$b").hasMatch(src)) offenders.add('$name $b');
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('play area fits any window', () {
    test('wide window: field is phone-shaped and fits the height', () {
      final w = PlayArea.widthFor(1400, 700);
      expect(w, closeTo(504, 0.01)); // 72% of height
      expect(w <= 1400, isTrue);
    });
    test('narrow phone: uses the full width', () {
      expect(PlayArea.widthFor(360, 640), 360);
    });
    test('tiny window never gives a negative or oversized field', () {
      expect(PlayArea.widthFor(200, 300), 200);
      expect(PlayArea.widthFor(500, 200), 280);
    });
  });

  group('parent dashboard numbers', () {
    test('empty history', () {
      final d = InsightDashboard.from(const <GameSession>[]);
      expect(d.week.length, 7);
      expect(d.totalSessions, 0);
      expect(d.games, isEmpty);
    });

    test('counts per day, feelings and games', () {
      final now = DateTime(2026, 10, 14, 12);
      final a = makeSession(GameType.cloudBounce,
          before: EmotionState.sad, after: EmotionState.happy, at: now)
        ..durationSeconds = 120
        ..enjoyment = 3;
      final b = makeSession(GameType.cloudBounce,
          before: EmotionState.calm, after: EmotionState.calm,
          at: now.subtract(const Duration(days: 2)), completed: false)
        ..durationSeconds = 60
        ..perceivedDifficulty = 3;
      final old = makeSession(GameType.fruitSlice,
          at: now.subtract(const Duration(days: 30)))
        ..durationSeconds = 600;
      final d = InsightDashboard.from([old, b, a], now: now);
      expect(d.week.last.sessions, 1);
      expect(d.week.last.minutes, closeTo(2, 0.01));
      expect(d.week[4].sessions, 1);
      expect(d.daysPlayedThisWeek, 2);
      expect(d.before[EmotionState.sad], 1);
      expect(d.after[EmotionState.happy], 1);
      final row = d.games.firstWhere((g) => g.game == GameType.cloudBounce);
      expect(row.plays, 2);
      expect(row.finished, 1);
      expect(row.fun, 3);
      expect(row.saidHard, 1);
      expect(d.totalMinutes, closeTo(13, 0.01)); // all-time includes old session
    });
  });
}
