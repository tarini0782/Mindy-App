/// Coarse difficulty label (kept for logs and the Progress screen).
/// The REAL tuning value is the 1-5 level (see [levelToDifficulty]); each
/// game reads its own parameter table from `controller.level`.
enum DifficultyLevel { easy, medium, hard }

const int kMinLevel = 1;
const int kMaxLevel = 5;

/// Level 1-2 = easy, 3 = medium, 4-5 = hard.
DifficultyLevel levelToDifficulty(int level) {
  if (level <= 2) return DifficultyLevel.easy;
  if (level == 3) return DifficultyLevel.medium;
  return DifficultyLevel.hard;
}

extension DifficultyLevelX on DifficultyLevel {
  String get label {
    switch (this) {
      case DifficultyLevel.easy:
        return 'Easy';
      case DifficultyLevel.medium:
        return 'Medium';
      case DifficultyLevel.hard:
        return 'Hard';
    }
  }

  T pick<T>(T easy, T medium, T hard) {
    switch (this) {
      case DifficultyLevel.easy:
        return easy;
      case DifficultyLevel.medium:
        return medium;
      case DifficultyLevel.hard:
        return hard;
    }
  }

  int get tier => index;
}

/// Picks one of five values by level (1..5, clamped).
T pickByLevel<T>(int level, T l1, T l2, T l3, T l4, T l5) {
  switch (level < kMinLevel ? kMinLevel : (level > kMaxLevel ? kMaxLevel : level)) {
    case 1:
      return l1;
    case 2:
      return l2;
    case 3:
      return l3;
    case 4:
      return l4;
    default:
      return l5;
  }
}
