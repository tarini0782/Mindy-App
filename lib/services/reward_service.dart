import 'dart:async';
import 'package:flutter/foundation.dart';
import '../games/models/game_session.dart';
import '../games/models/game_type.dart';

class RewardGrant {
  final int stars;
  final String collectibleEmoji;
  final String collectibleName;
  final String? decoration;
  const RewardGrant({
    required this.stars,
    required this.collectibleEmoji,
    required this.collectibleName,
    this.decoration,
  });
}

/// Stars, flowers, butterflies, gems, rainbow pieces and garden surprises.
///
/// Rewards depend on PARTICIPATION and COMPLETION only, never speed or
/// accuracy, and are DERIVED from the stored sessions (see [rebuild]) so
/// they survive restarts without a second store. Nothing is ever lost.
class RewardService extends ChangeNotifier {
  RewardService._();
  static final RewardService instance = RewardService._();

  int stars = 0;
  int rainbowPieces = 0;
  int gems = 0;
  int flowers = 0;
  int butterflies = 0;
  final Map<String, int> _completions = {};
  final List<String> _decorations = [];

  static const List<int> _decorationAt = [1, 3, 6, 10, 15];
  static const List<String> _decorationEmoji = [
    '\u{1F3E1}',
    '\u{1F333}',
    '\u26F2',
    '\u{1F3A0}',
    '\u{1FA81}',
  ];

  List<String> get decorations => List.unmodifiable(_decorations);
  int get totalCompletions => _completions.values.fold<int>(0, (a, b) => a + b);

  void _notify() => scheduleMicrotask(notifyListeners);

  RewardGrant _apply(GameSession s) {
    if (!s.completed) {
      final st = s.interactions >= 3 ? 1 : 0; // trying counts
      stars += st;
      return RewardGrant(stars: st, collectibleEmoji: '', collectibleName: '');
    }
    final first = (_completions[s.game.id] ?? 0) == 0;
    final earned = 3 + (first ? 1 : 0);
    stars += earned;
    _completions[s.game.id] = (_completions[s.game.id] ?? 0) + 1;

    late String emoji, name;
    switch (s.game) {
      case GameType.breathingGarden:
        flowers++;
        emoji = '\u{1F338}';
        name = 'Flower';
        break;
      case GameType.bubbleValley:
      case GameType.bubbleShooter:
      case GameType.peekaboo:
      case GameType.sleepyFox:
      case GameType.beeCollector:
      case GameType.jellyfishCatcher:
      case GameType.petCare:
      case GameType.fireflyJar:
        butterflies++;
        emoji = '\u{1F98B}';
        name = 'Butterfly';
        break;
      case GameType.memoryCastle:
      case GameType.treasureJourney:
      case GameType.happyConnect:
      case GameType.memoryQuest:
      case GameType.birdLauncher:
      case GameType.teddyClinic:
      case GameType.danceParty:
        gems++;
        emoji = '\u{1F48E}';
        name = 'Magic Gem';
        break;
      case GameType.patternPower:
      case GameType.rainbowPuzzle:
      case GameType.cloudHop:
      case GameType.ruleShift:
      case GameType.heroShield:
      case GameType.turboCar:
      case GameType.dinoDash:
      case GameType.carrotCatch:
      case GameType.skyFlight:
      case GameType.cloudBounce:
      case GameType.fruitSlice:
        rainbowPieces++;
        emoji = '\u{1F308}';
        name = 'Rainbow Piece';
        break;
    }
    String? deco;
    final total = totalCompletions;
    for (var d = 0; d < _decorationAt.length; d++) {
      if (total == _decorationAt[d] && _decorations.length == d) {
        deco = _decorationEmoji[d];
        _decorations.add(deco);
      }
    }
    return RewardGrant(
        stars: earned,
        collectibleEmoji: emoji,
        collectibleName: name,
        decoration: deco);
  }

  /// Gives the reward for one session just finished.
  RewardGrant award(GameSession s) {
    final g = _apply(s);
    _notify();
    return g;
  }

  /// Recomputes everything from stored sessions (chronological).
  void rebuild(List<GameSession> sessions) {
    stars = rainbowPieces = gems = flowers = butterflies = 0;
    _completions.clear();
    _decorations.clear();
    for (final s in sessions) {
      _apply(s);
    }
    _notify();
  }

  void clear() => rebuild(const []);
}
