import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { en, si, ta }

extension AppLangX on AppLang {
  String get nativeName {
    switch (this) {
      case AppLang.en:
        return 'English';
      case AppLang.si:
        return 'සිංහල';
      case AppLang.ta:
        return 'தமிழ்';
    }
  }
}

/// Child-facing text in English, Sinhala and Tamil.
///
/// IMPORTANT: the Sinhala and Tamil strings are a DRAFT written without a
/// native-speaker review. Have a fluent speaker (ideally one who works with
/// children) check every line before a child sees it. A missing key or
/// language always falls back to English, so the app never shows a blank.
/// Only the child-facing check-in, the tab names and a few buttons are
/// translated; exports and research logs stay in English.
class LanguageService extends ChangeNotifier {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  AppLang lang = AppLang.en;
  static const _k = 'appLang';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_k);
      for (final l in AppLang.values) {
        if (l.name == v) lang = l;
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLang(AppLang l) async {
    lang = l;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, l.name);
    } catch (_) {}
    notifyListeners();
  }

  String tr(String key) => translate(key, lang);

  static String translate(String key, AppLang lang) {
    final en = _en[key] ?? key;
    switch (lang) {
      case AppLang.en:
        return en;
      case AppLang.si:
        return _si[key] ?? en;
      case AppLang.ta:
        return _ta[key] ?? en;
    }
  }

  static const Map<String, String> _en = {
    'nav.home': 'Home',
    'nav.feed': 'Feed',
    'nav.adventure': 'Adventure',
    'nav.games': 'Games',
    'nav.grownups': 'Grown-ups',
    'greeting': "Hi! I'm Mindy ✨\nHow are you feeling today?",
    'emotion.scared': 'Scared',
    'emotion.sad': 'Sad',
    'emotion.neutral': 'Okay',
    'emotion.calm': 'Calm',
    'emotion.happy': 'Happy',
    'sentence.scared': "I'm feeling a little scared.",
    'sentence.sad': "I'm feeling sad.",
    'sentence.neutral': "I'm okay.",
    'sentence.calm': "I'm calm.",
    'sentence.happy': "I'm happy!",
    'checkin.thatsMe': "That's me!",
    'checkin.pickAgain': 'Pick again',
    'checkin.rather': "I'd rather not say",
    'tap': 'Tap',
  };

  static const Map<String, String> _si = {
    'nav.home': '\u0DB8\u0DD4\u0DBD\u0DCA \u0DB4\u0DD2\u0DA7\u0DD4\u0DC0',
    'nav.feed': 'ෆීඩ්',
    'nav.adventure': 'චාරිකාව',
    'nav.games': 'ක්‍රීඩා',
    'nav.grownups': 'වැඩිහිටියන්',
    'greeting': 'හායි! මම මින්ඩි ✨\nඔයාට අද දැනෙන්නේ කොහොමද?',
    'emotion.scared': 'බයයි',
    'emotion.sad': 'දුකයි',
    'emotion.neutral': 'හොඳයි',
    'emotion.calm': 'සන්සුන්යි',
    'emotion.happy': 'සතුටුයි',
    'sentence.scared': 'මට ටිකක් බයයි.',
    'sentence.sad': 'මට දුකයි.',
    'sentence.neutral': 'මම හොඳින්.',
    'sentence.calm': 'මම සන්සුන්.',
    'sentence.happy': 'මම සතුටුයි!',
    'checkin.thatsMe': 'ඔව්, ඒ මමයි!',
    'checkin.pickAgain': 'ආයෙත් තෝරන්න',
    'checkin.rather': 'කියන්න ඕනේ නැහැ',
    'tap': 'ඔබන්න',
  };

  static const Map<String, String> _ta = {
    'nav.home': 'முகப்பு',
    'nav.feed': 'ஃபீட்',
    'nav.adventure': 'சாகசம்',
    'nav.games': 'விளையாட்டுகள்',
    'nav.grownups': 'பெரியவர்கள்',
    'greeting': 'ஹாய்! நான் மைண்டி ✨\nஇன்று நீ எப்படி உணர்கிறாய்?',
    'emotion.scared': 'பயம்',
    'emotion.sad': 'சோகம்',
    'emotion.neutral': 'நலம்',
    'emotion.calm': 'அமைதி',
    'emotion.happy': 'மகிழ்ச்சி',
    'sentence.scared': 'எனக்கு கொஞ்சம் பயமாக இருக்கிறது.',
    'sentence.sad': 'எனக்கு சோகமாக இருக்கிறது.',
    'sentence.neutral': 'நான் நலமாக இருக்கிறேன்.',
    'sentence.calm': 'நான் அமைதியாக இருக்கிறேன்.',
    'sentence.happy': 'நான் மகிழ்ச்சியாக இருக்கிறேன்!',
    'checkin.thatsMe': 'ஆமாம், அதுதான் நான்!',
    'checkin.pickAgain': 'மீண்டும் தேர்ந்தெடு',
    'checkin.rather': 'சொல்ல விரும்பவில்லை',
    'tap': 'தொடு',
  };
}
