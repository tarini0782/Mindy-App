/// The three study arms (proposal evaluation design).
///
///  FIXED_BASELINE  activity sequence AND difficulty are predetermined;
///                  emotion never changes gameplay.
///  DIFFICULTY_ONLY activity sequence is fixed; only difficulty adapts.
///  ADAPTIVE        activity selection AND difficulty adapt.
enum StudyCondition { adaptive, difficultyOnly, fixedBaseline }

extension StudyConditionX on StudyCondition {
  String get code {
    switch (this) {
      case StudyCondition.adaptive:
        return 'ADAPTIVE';
      case StudyCondition.difficultyOnly:
        return 'DIFFICULTY_ONLY';
      case StudyCondition.fixedBaseline:
        return 'FIXED_BASELINE';
    }
  }

  String get label {
    switch (this) {
      case StudyCondition.adaptive:
        return 'Adaptive (activity + difficulty)';
      case StudyCondition.difficultyOnly:
        return 'Difficulty only (fixed sequence)';
      case StudyCondition.fixedBaseline:
        return 'Fixed baseline (no adaptation)';
    }
  }

  static StudyCondition fromCode(String? code) {
    for (final c in StudyCondition.values) {
      if (c.code == code) return c;
    }
    return StudyCondition.adaptive;
  }
}

/// Where an emotion report came from. If no external signal exists the
/// source is always APP. A simulated robot signal (test mode only) is
/// stored as KARA_SIMULATED so it can never be mistaken for the real robot.
enum EmotionSource { app, kara, karaSimulated }

extension EmotionSourceX on EmotionSource {
  String get code {
    switch (this) {
      case EmotionSource.app:
        return 'APP';
      case EmotionSource.kara:
        return 'KARA';
      case EmotionSource.karaSimulated:
        return 'KARA_SIMULATED';
    }
  }

  static EmotionSource fromCode(String? code) {
    for (final s in EmotionSource.values) {
      if (s.code == code) return s;
    }
    return EmotionSource.app;
  }
}
