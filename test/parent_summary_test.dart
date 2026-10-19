import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/parent_summary.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'test_helpers.dart';

void main() {
  test('too little play: says so and gives no judgement', () {
    final s = ParentSummary.from([makeSession(GameType.petCare)], childName: 'Mia');
    expect(s.enoughData, isFalse);
    expect(s.enjoyed, isEmpty);
    expect(s.talkToSomeone, isNull);
    expect(s.headline, contains('Mia'));
  });

  test('summarises enjoyment, tricky games and feelings in plain words', () {
    final a = makeSession(GameType.carrotCatch,
        before: EmotionState.neutral, after: EmotionState.happy)
      ..enjoyment = 3;
    final b = makeSession(GameType.teddyClinic,
        before: EmotionState.scared, after: EmotionState.calm, completed: false)
      ..perceivedDifficulty = 3
      ..supportCount = 3;
    final c = makeSession(GameType.carrotCatch,
        before: EmotionState.calm, after: EmotionState.calm)
      ..playAgain = true;
    final s = ParentSummary.from([a, b, c], childName: 'Mia');
    expect(s.enoughData, isTrue);
    expect(s.enjoyed.join(' '), contains('Carrot Catch'));
    expect(s.tricky.join(' '), contains('Teddy Clinic'));
    expect(s.feelings.join(' '), contains('higher'));
    expect(s.tryNext, isNotEmpty);
  });

  test('never uses diagnostic or risk language', () {
    final list = [
      for (var i = 0; i < 6; i++)
        makeSession(GameType.sleepyFox,
            before: EmotionState.sad, after: EmotionState.scared, completed: false)
          ..perceivedDifficulty = 3
          ..supportCount = 4
    ];
    final s = ParentSummary.from(list, childName: 'Mia');
    final all = [
      s.headline, ...s.enjoyed, ...s.tricky, ...s.feelings, ...s.tryNext,
      s.talkToSomeone ?? '',
    ].join(' ').toLowerCase();
    for (final banned in ['diagnos', 'disorder', 'adhd', 'autis', 'anxiety', 'depress', 'at risk', 'symptom']) {
      // the one allowed mention is the sentence that says it is NOT a diagnosis
      final cleaned = all.replaceAll('this is not a finding', '');
      expect(cleaned.contains(banned), isFalse, reason: banned);
    }
  });
}
