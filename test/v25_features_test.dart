import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/insights/worry_scale.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/language_service.dart';
import 'package:mindy_app/services/worry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('language', () {
    test('English is the default and display labels match the English labels', () {
      expect(LanguageService.instance.lang, AppLang.en);
      for (final e in EmotionState.values) {
        expect(e.displayLabel, e.label);
        expect(e.displaySentence, e.sentence);
      }
    });
    test('every key exists in Sinhala and Tamil and differs from English', () {
      for (final key in [
        'nav.home', 'nav.feed', 'nav.adventure', 'nav.games', 'nav.grownups',
        'greeting', 'checkin.thatsMe', 'checkin.pickAgain', 'checkin.rather', 'tap',
        for (final e in EmotionState.values) ...['emotion.${e.name}', 'sentence.${e.name}'],
      ]) {
        final en = LanguageService.translate(key, AppLang.en);
        expect(LanguageService.translate(key, AppLang.si), isNot(en), reason: 'si $key');
        expect(LanguageService.translate(key, AppLang.ta), isNot(en), reason: 'ta $key');
      }
    });
    test('unknown key falls back to the key itself', () {
      expect(LanguageService.translate('no.such.key', AppLang.si), 'no.such.key');
    });
    test('choice is saved and reloaded', () async {
      await LanguageService.instance.setLang(AppLang.ta);
      await LanguageService.instance.load();
      expect(LanguageService.instance.lang, AppLang.ta);
      await LanguageService.instance.setLang(AppLang.en);
    });
  });

  group('worry scale', () {
    final t = DateTime(2026, 1, 1, 10);
    test('pairs each before with the next after', () {
      final c = worryChanges([
        WorryEntry(t, WorryPhase.before, 3),
        WorryEntry(t.add(const Duration(minutes: 5)), WorryPhase.after, 1),
        WorryEntry(t.add(const Duration(minutes: 20)), WorryPhase.before, 2),
        WorryEntry(t.add(const Duration(minutes: 25)), WorryPhase.after, 2),
      ]);
      expect(c, [-2, 0]);
    });
    test('an after with no before is ignored, a newer before replaces an unpaired one', () {
      final c = worryChanges([
        WorryEntry(t, WorryPhase.after, 0),
        WorryEntry(t.add(const Duration(minutes: 1)), WorryPhase.before, 4),
        WorryEntry(t.add(const Duration(minutes: 2)), WorryPhase.before, 2),
        WorryEntry(t.add(const Duration(minutes: 3)), WorryPhase.after, 1),
      ]);
      expect(c, [-1]);
    });
    test('mean is null with no pairs', () {
      expect(meanWorryChange(const []), isNull);
    });
    test('rejects out-of-range levels when loading', () {
      expect(WorryEntry.fromJson({'at': t.toIso8601String(), 'phase': 'before', 'level': 7}), isNull);
    });
    test('stores per child', () async {
      await WorryService.instance.load('P-AAA111');
      expect(await WorryService.instance.add(WorryPhase.before, 3), isTrue);
      expect(await WorryService.instance.add(WorryPhase.before, 9), isFalse);
      await WorryService.instance.load('P-BBB222');
      expect(WorryService.instance.entries, isEmpty);
      await WorryService.instance.load('P-AAA111');
      expect(WorryService.instance.entries.length, 1);
    });
  });
}
