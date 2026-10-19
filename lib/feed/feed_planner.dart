import '../games/engine/adaptive_game_engine.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';

/// Why a card is in the feed.
enum FeedKind { calmBreak, challenge, fun }

extension FeedKindX on FeedKind {
  String get label {
    switch (this) {
      case FeedKind.calmBreak:
        return 'Quiet break';
      case FeedKind.challenge:
        return 'Brain boost';
      case FeedKind.fun:
        return 'Just for fun';
    }
  }

  String get code {
    switch (this) {
      case FeedKind.calmBreak:
        return 'calm';
      case FeedKind.challenge:
        return 'challenge';
      case FeedKind.fun:
        return 'fun';
    }
  }
}

class FeedItem {
  final int index;
  final GameType game;
  final int level; // 1..5
  final FeedKind kind;
  final String reason; // plain language, stored with the session
  const FeedItem({
    required this.index,
    required this.game,
    required this.level,
    required this.kind,
    required this.reason,
  });
}

/// Decides what the swipe feed shows next. Pure and deterministic.
///
/// The feed is a *discovery* surface: it is not the adventure and it never
/// shows a decision as a diagnosis. Its job is (1) to let a child pick games
/// the way they already browse short videos, (2) to mix game types so a
/// range of behaviours is seen, and (3) to be kind: a child who said they felt
/// scared or sad, or who keeps skipping, is shown quiet games only.
class FeedPlanner {
  FeedPlanner._();

  /// Games meant to sample attention, rule following, flexibility and memory
  /// (design intent only; no validity is claimed, see docs/PANEL_QA.md).
  static const List<GameType> challengePool = [
    GameType.heroShield, // rule following / inhibition
    GameType.ruleShift, // flexibility after a rule change
    GameType.carrotCatch, // sustained attention
    GameType.patternPower, // pattern memory
    GameType.memoryQuest, // working memory
    GameType.cloudHop, // timing
    GameType.skyFlight, // steering / attention
    GameType.turboCar, // steering / attention
  ];

  static const List<GameType> funPool = [
    GameType.fruitSlice,
    GameType.danceParty,
    GameType.birdLauncher,
    GameType.cloudBounce,
    GameType.dinoDash,
    GameType.bubbleShooter,
    GameType.jellyfishCatcher,
    GameType.happyConnect,
    GameType.rainbowPuzzle,
    GameType.memoryCastle,
  ];

  /// A card is not repeated within this many cards.
  static const int noRepeatWindow = 8;
  static const int skipStreakForCalm = 3;
  static const int quickSkipMs = 3000;

  static bool isLow(EmotionState? e) =>
      e == EmotionState.scared || e == EmotionState.sad;

  static FeedItem next({
    required int index,
    required List<FeedItem> shown,
    EmotionState? lastEmotion,
    int skipStreak = 0,
  }) {
    FeedKind kind;
    String reason;
    if (isLow(lastEmotion)) {
      kind = FeedKind.calmBreak;
      reason = 'Feed card $index: the last feeling picked was '
          '"${lastEmotion!.label.toLowerCase()}", so only quiet games are shown.';
    } else if (skipStreak >= skipStreakForCalm) {
      kind = FeedKind.calmBreak;
      reason = 'Feed card $index: $skipStreak cards in a row were swiped past '
          'quickly, so a quiet game is offered.';
    } else if (index % 4 == 3) {
      kind = FeedKind.calmBreak;
      reason = 'Feed card $index: a quiet break after every three games.';
    } else if (index % 2 == 0) {
      kind = FeedKind.challenge;
      reason = 'Feed card $index: a game that samples attention, rules or memory.';
    } else {
      kind = FeedKind.fun;
      reason = 'Feed card $index: a just-for-fun game.';
    }

    final List<GameType> pool;
    switch (kind) {
      case FeedKind.calmBreak:
        pool = AdaptiveGameEngine.calmPool.toList();
        break;
      case FeedKind.challenge:
        pool = challengePool;
        break;
      case FeedKind.fun:
        pool = funPool;
        break;
    }
    final recent = <String>{
      for (final s in shown.reversed.take(noRepeatWindow)) s.game.id,
    };
    GameType? pick;
    for (var k = 0; k < pool.length; k++) {
      final g = pool[(index * 3 + k) % pool.length];
      if (!recent.contains(g.id)) {
        pick = g;
        break;
      }
    }
    // Pool exhausted inside the window: take the one shown longest ago.
    pick ??= _longestAgo(pool, shown);
    final level = kind == FeedKind.calmBreak ? 1 : 2;
    return FeedItem(index: index, game: pick, level: level, kind: kind, reason: reason);
  }

  static GameType _longestAgo(List<GameType> pool, List<FeedItem> shown) {
    GameType best = pool.first;
    var bestAge = -1;
    for (final g in pool) {
      var age = 1 << 20; // never shown
      for (var i = shown.length - 1; i >= 0; i--) {
        if (shown[i].game == g) {
          age = shown.length - i;
          break;
        }
      }
      if (age > bestAge) {
        bestAge = age;
        best = g;
      }
    }
    return best;
  }
}
