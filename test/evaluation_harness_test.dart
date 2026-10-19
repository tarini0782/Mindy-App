import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';
import 'test_helpers.dart';

/// EVALUATION HARNESS - a generator, not a pass/fail test suite.
///
/// Run it on its own:
///     flutter test test/evaluation_harness_test.dart
///
/// It writes, into build/eval/ :
///     profiles.json        the 24 synthetic profiles and how each was built
///     recommendations.json every profile x condition, with the full trace
///     recommendations.csv  the same, flattened
///     rater_sheet.csv      BLINDED: no condition labels, order randomised
///     condition_key.csv    the key, to be kept away from the raters
///
/// Everything it writes is synthetic. No child produced any of it.
///
/// The seed is fixed, so re-running reproduces the identical set. Change
/// [kSeed] only if you intend to generate a different study.
const int kSeed = 20261018;

/// How many completed, high-accuracy sessions of one activity a "long"
/// history carries. The engine needs at least [AdaptiveGameEngine.evidenceNeeded]
/// banded sessions of the same activity before a level step can fire, so a
/// short history deliberately cannot trigger one and a long history can.
const int kLongRepeats = 4;

const String kSyntheticBanner =
    'SYNTHETIC / DEVELOPMENT DATA - NOT REAL PARTICIPANT DATA';

/// One synthetic child: a history plus the feeling they just reported.
class Profile {
  final String id;
  final EmotionState? checkIn;
  final String historyLength; // short | long
  final String trajectory; // improving | not_improving
  final List<GameSession> history;

  Profile(this.id, this.checkIn, this.historyLength, this.trajectory,
      this.history);

  String get checkInLabel => checkIn?.label ?? 'skipped';

  Map<String, dynamic> toJson() => {
        'profileId': id,
        'checkIn': checkInLabel,
        'historyLength': historyLength,
        'trajectory': trajectory,
        'sessionCount': history.length,
        'note': kSyntheticBanner,
        'history': [
          for (final s in history)
            {
              'activity': s.game.id,
              'level': s.level,
              'completed': s.completed,
              'emotionBefore': s.emotionBefore?.label,
              'emotionAfter': s.emotionAfter?.label,
              'performanceBand': s.performanceBand?.name,
            }
        ],
      };
}

List<Profile> buildProfiles() {
  const checkIns = <EmotionState?>[
    EmotionState.scared,
    EmotionState.sad,
    EmotionState.neutral,
    EmotionState.calm,
    EmotionState.happy,
    null, // skipped
  ];
  final out = <Profile>[];
  var n = 0;

  for (final emotion in checkIns) {
    for (final length in ['short', 'long']) {
      for (final trajectory in ['improving', 'not_improving']) {
        n++;
        final id = 'P${n.toString().padLeft(2, '0')}';
        final history = <GameSession>[];
        final base = DateTime(2026, 9, 1);

        // Trajectory controls how the child felt AFTER recent activities,
        // which the engine reads through recentMoodResponse / moodChange.
        final before =
            trajectory == 'improving' ? EmotionState.sad : EmotionState.neutral;
        final after = trajectory == 'improving'
            ? EmotionState.calm
            : EmotionState.neutral;

        if (length == 'short') {
          // Four mixed sessions: too few of any ONE activity to let a level
          // step fire, by design.
          const games = [
            GameType.bubbleValley,
            GameType.memoryCastle,
            GameType.rainbowPuzzle,
            GameType.breathingGarden,
          ];
          for (var i = 0; i < games.length; i++) {
            history.add(makeSession(
              games[i],
              level: 3,
              before: before,
              after: after,
              successes: 7,
              mistakes: 3, // accuracy 0.70 -> normal band
              at: base.add(Duration(days: i)),
            ));
          }
        } else {
          // Ten sessions, four of them the SAME activity at high accuracy,
          // so the "consistently smooth play" level step becomes reachable.
          for (var i = 0; i < kLongRepeats; i++) {
            history.add(makeSession(
              GameType.memoryCastle,
              level: 3,
              before: before,
              after: after,
              successes: 9,
              mistakes: 1, // accuracy 0.90 -> high band
              at: base.add(Duration(days: i)),
            ));
          }
          const rest = [
            GameType.bubbleValley,
            GameType.rainbowPuzzle,
            GameType.patternPower,
            GameType.breathingGarden,
            GameType.treasureJourney,
            GameType.teddyClinic,
          ];
          for (var i = 0; i < rest.length; i++) {
            history.add(makeSession(
              rest[i],
              level: 3,
              before: before,
              after: after,
              successes: 7,
              mistakes: 3,
              at: base.add(Duration(days: kLongRepeats + i)),
            ));
          }
        }
        out.add(Profile(id, emotion, length, trajectory, history));
      }
    }
  }
  return out;
}

String csvCell(Object? v) {
  final s = (v ?? '').toString().replaceAll('"', '""').replaceAll('\n', ' ');
  return '"$s"';
}

void main() {
  test('generate the blinded rater materials from the real engine', () {
    final profiles = buildProfiles();
    expect(profiles.length, 24,
        reason: '6 check-ins x 2 history lengths x 2 trajectories');

    final dir = Directory('build/eval');
    dir.createSync(recursive: true);

    final rows = <Map<String, dynamic>>[];
    for (final p in profiles) {
      for (final c in StudyCondition.values) {
        final rec = AdaptiveGameEngine.recommend(
          emotion: p.checkIn,
          condition: c,
          history: p.history,
          journeyStep: 0,
          pool: AdaptiveGameEngine.studyPool,
          equalSafetyFloor: true,
          now: DateTime(2026, 10, 18, 9),
        );
        rows.add({
          'profileId': p.id,
          'checkIn': p.checkInLabel,
          'historyLength': p.historyLength,
          'trajectory': p.trajectory,
          'condition': c.code,
          'activityId': rec.gameType.id,
          'activityTitle': rec.gameType.title,
          'level': rec.level,
          'difficulty': rec.trace.selectedDifficulty,
          'pace': rec.pace.name,
          'ruleId': rec.trace.ruleId,
          'humanReason': rec.trace.humanReason,
        });
      }
    }
    expect(rows.length, 72, reason: '24 profiles x 3 conditions');

    // Every recommendation must respect the study pool and, for a
    // restricted check-in, the shared safety floor. If this fails, do not
    // send the sheets to raters.
    for (final r in rows) {
      final inPool = AdaptiveGameEngine.studyPool
          .any((g) => g.id == r['activityId']);
      expect(inPool, isTrue, reason: 'outside the pool: ${r['activityId']}');
      if (['Scared', 'Sad', 'skipped'].contains(r['checkIn'])) {
        final calm = AdaptiveGameEngine.calmPool
            .any((g) => g.id == r['activityId']);
        expect(calm, isTrue,
            reason: 'distressed check-in offered ${r['activityId']} '
                'in ${r['condition']}');
      }
    }

    File('build/eval/profiles.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
      'banner': kSyntheticBanner,
      'seed': kSeed,
      'generated': DateTime.now().toIso8601String(),
      'profiles': [for (final p in profiles) p.toJson()],
    }));

    File('build/eval/recommendations.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ')
            .convert({'banner': kSyntheticBanner, 'rows': rows}));

    final head = rows.first.keys.toList();
    final csv = StringBuffer()
      ..writeln(head.map(csvCell).join(','));
    for (final r in rows) {
      csv.writeln(head.map((k) => csvCell(r[k])).join(','));
    }
    File('build/eval/recommendations.csv').writeAsStringSync(csv.toString());

    // ---- blinded rater sheet -------------------------------------------
    // Per profile the three recommendations are shuffled, labelled A/B/C,
    // and the condition is written only to the separate key file.
    final rng = Random(kSeed);
    final sheet = StringBuffer()
      ..writeln([
        'profileId',
        'checkIn',
        'historyLength',
        'trajectory',
        'option',
        'activity',
        'level',
        'pace',
        'whyThisWasChosen',
        'q1_activity_suits_feeling_1to5',
        'q2_level_suits_history_1to5',
        'q3_caregiver_comfortable_1to5',
        'mostAppropriateOption_A_B_C',
      ].map(csvCell).join(','));
    final key = StringBuffer()
      ..writeln(['profileId', 'option', 'condition'].map(csvCell).join(','));

    for (final p in profiles) {
      final mine = rows.where((r) => r['profileId'] == p.id).toList()
        ..shuffle(rng);
      for (var i = 0; i < mine.length; i++) {
        final label = ['A', 'B', 'C'][i];
        final r = mine[i];
        sheet.writeln([
          p.id,
          p.checkInLabel,
          p.historyLength,
          p.trajectory,
          label,
          r['activityTitle'],
          r['level'],
          r['pace'],
          // The trace is deliberately TRIMMED to the "Why:" clause. The full
          // adaptive trace is longer than the baselines' and would unblind
          // the condition immediately.
          _whyOnly(r['humanReason'] as String),
          '', '', '', // rater fills these
          i == 0 ? '' : '', // forced choice: one answer per profile
        ].map(csvCell).join(','));
        key.writeln([p.id, label, r['condition']].map(csvCell).join(','));
      }
    }
    File('build/eval/rater_sheet.csv').writeAsStringSync(sheet.toString());
    File('build/eval/condition_key.csv').writeAsStringSync(key.toString());

    // The key must never be derivable from the sheet.
    final sheetText = File('build/eval/rater_sheet.csv').readAsStringSync();
    for (final c in StudyCondition.values) {
      expect(sheetText.contains(c.code), isFalse,
          reason: 'the blinded sheet leaks the condition name ${c.code}');
    }

    // ignore: avoid_print
    print('Wrote build/eval/ : profiles.json, recommendations.{json,csv}, '
        'rater_sheet.csv, condition_key.csv  [$kSyntheticBanner]');
  });
}

/// Keeps only the explanation clause, so sheet length cannot identify the
/// condition.
String _whyOnly(String humanReason) {
  const marker = 'Why: ';
  final i = humanReason.indexOf(marker);
  return i < 0 ? humanReason : humanReason.substring(i + marker.length);
}
