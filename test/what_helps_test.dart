import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/what_helps.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'test_helpers.dart';

void main() {
  test('no data: no findings, no invented claims', () {
    final w = WhatHelps.from(const [], childName: 'Tee');
    expect(w.enoughData, isFalse);
    expect(w.lines, isEmpty);
  });

  test('names the activity type that followed the best change when low', () {
    final list = [
      makeSession(GameType.breathingGarden, before: EmotionState.sad, after: EmotionState.calm),
      makeSession(GameType.breathingGarden, before: EmotionState.scared, after: EmotionState.calm),
      makeSession(GameType.fruitSlice, before: EmotionState.sad, after: EmotionState.sad),
      makeSession(GameType.fruitSlice, before: EmotionState.scared, after: EmotionState.scared),
    ];
    final w = WhatHelps.from(list, childName: 'Tee');
    expect(w.enoughData, isTrue);
    final t = w.lines.first.title;
    expect(t, contains('calming activities'));
    expect(w.lines.first.evidence, contains('4'));
  });

  test('similar change across types: says nothing stood out', () {
    final list = [
      makeSession(GameType.breathingGarden, before: EmotionState.sad, after: EmotionState.neutral),
      makeSession(GameType.breathingGarden, before: EmotionState.sad, after: EmotionState.neutral),
      makeSession(GameType.fruitSlice, before: EmotionState.sad, after: EmotionState.neutral),
      makeSession(GameType.fruitSlice, before: EmotionState.sad, after: EmotionState.neutral),
    ];
    final w = WhatHelps.from(list);
    expect(w.lines.first.title, contains('No activity type stood out'));
  });

  test('one low start only: asks for more, does not compare', () {
    final list = [
      makeSession(GameType.breathingGarden, before: EmotionState.sad, after: EmotionState.calm),
      makeSession(GameType.fruitSlice, before: EmotionState.happy, after: EmotionState.happy),
    ];
    final w = WhatHelps.from(list);
    expect(w.lines.first.title, contains('Not enough'));
  });

  test('hint trend needs enough activities and compares halves', () {
    final list = [
      for (var i = 0; i < 6; i++)
        makeSession(GameType.carrotCatch)..supportCount = i < 3 ? 3 : 0,
    ];
    final w = WhatHelps.from(list, childName: 'Tee');
    final hint = w.lines.firstWhere((l) => l.title == 'Hints over time');
    expect(hint.detail, contains('fewer hints'));
    final few = WhatHelps.from(list.take(4).toList());
    expect(few.lines.where((l) => l.title == 'Hints over time'), isEmpty);
  });

  test('wording stays non-diagnostic', () {
    final list = [
      for (var i = 0; i < 6; i++)
        makeSession(GameType.carrotCatch, before: EmotionState.sad, after: EmotionState.happy)
          ..supportCount = i
          ..perceivedDifficulty = 2,
    ];
    final w = WhatHelps.from(list, childName: 'Tee');
    final all = [...w.lines.map((l) => '${l.title} ${l.detail}'), w.caution].join(' ').toLowerCase();
    for (final b in ['diagnos', 'disorder', 'adhd', 'autis', 'depress', 'anxiety', 'symptom', 'at risk']) {
      expect(all.contains(b), isFalse, reason: b);
    }
  });
}
