import '../services/language_service.dart';

/// The child's self-reported (or externally reported) emotional state.
/// Deliberately a simple, explainable enum: nothing is inferred from
/// sensors, camera or machine learning.
enum EmotionState { scared, sad, neutral, calm, happy }

extension EmotionStateX on EmotionState {
  /// Friendly label shown to the child.
  String get label {
    switch (this) {
      case EmotionState.scared:
        return 'Scared';
      case EmotionState.sad:
        return 'Sad';
      case EmotionState.neutral:
        return 'Okay';
      case EmotionState.calm:
        return 'Calm';
      case EmotionState.happy:
        return 'Happy';
    }
  }

  /// Child-facing label in the chosen app language (English fallback).
  /// Logs, exports and engine reasons keep using [label] (English).
  String get displayLabel => LanguageService.instance.tr('emotion.$name');

  /// Child-facing first-person line in the chosen app language.
  String get displaySentence => LanguageService.instance.tr('sentence.$name');

  /// Short first-person line, shown after the child picks a feeling.
  String get sentence {
    switch (this) {
      case EmotionState.scared:
        return "I'm feeling a little scared.";
      case EmotionState.sad:
        return "I'm feeling sad.";
      case EmotionState.neutral:
        return "I'm okay.";
      case EmotionState.calm:
        return "I'm calm.";
      case EmotionState.happy:
        return "I'm happy!";
    }
  }

  String get faceEmoji {
    switch (this) {
      case EmotionState.scared:
        return '\u{1F628}';
      case EmotionState.sad:
        return '\u{1F622}';
      case EmotionState.neutral:
        return '\u{1F610}';
      case EmotionState.calm:
        return '\u{1F60C}';
      case EmotionState.happy:
        return '\u{1F604}';
    }
  }

  /// 1 (scared) .. 5 (happy). An ORDINAL used only to compare self-reported
  /// feeling before and after an activity. It is not a validated scale and
  /// not a clinical score.
  int get moodScore => index + 1;

  /// Stable code stored in exports ("SCARED", "SAD", ...).
  String get code => name.toUpperCase();
}

EmotionState? emotionFromName(String? name) {
  if (name == null) return null;
  final n = name.toLowerCase();
  for (final e in EmotionState.values) {
    if (e.name == n) return e;
  }
  return null;
}

/// Self-reported emotional change between two answers.
/// Positive = the child reported a more positive feeling afterwards.
/// null when either answer is missing (never guessed).
int? computeMoodDelta(EmotionState? before, EmotionState? after) {
  if (before == null || after == null) return null;
  return after.moodScore - before.moodScore;
}

enum MoodChange { improved, unchanged, worsened, unknown }

MoodChange moodChangeOf(int? delta) {
  if (delta == null) return MoodChange.unknown;
  if (delta > 0) return MoodChange.improved;
  if (delta < 0) return MoodChange.worsened;
  return MoodChange.unchanged;
}
