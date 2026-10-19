import 'package:flutter/material.dart';
import '../../models/emotion_state.dart';
import '../../models/study_condition.dart';
import '../breathing_garden_game.dart';
import '../carrot_catch_game.dart';
import '../cloud_bounce_game.dart';
import '../dance_party_game.dart';
import '../fruit_slice_game.dart';
import '../pet_care_game.dart';
import '../sky_flight_game.dart';
import '../teddy_clinic_game.dart';
import '../bee_collector_game.dart';
import '../bird_launcher_game.dart';
import '../dino_dash_game.dart';
import '../hero_shield_game.dart';
import '../jellyfish_catcher_game.dart';
import '../memory_quest_game.dart';
import '../rule_shift_game.dart';
import '../turbo_car_game.dart';
import '../sleepy_fox_game.dart';
import '../bubble_shooter_game.dart';
import '../cloud_hop_game.dart';
import '../happy_connect_game.dart';
import '../peekaboo_pals_game.dart';
import '../bubble_valley_game.dart';
import '../memory_castle_game.dart';
import '../models/game_recommendation.dart';
import '../models/game_type.dart';
import '../pattern_power_game.dart';
import '../rainbow_puzzle_game.dart';
import '../treasure_journey_game.dart';
import '../firefly_jar_game.dart';
import 'game_session_controller.dart';
import 'game_shell.dart';

/// Maps a [GameType] to its play area. The ONE place that knows which
/// widget is which game -- everything else works with GameType.
Widget buildGameBody(GameType type, GameSessionController c) {
  switch (type) {
    case GameType.breathingGarden:
      return BreathingGardenGame(controller: c);
    case GameType.bubbleValley:
      return BubbleValleyGame(controller: c);
    case GameType.memoryCastle:
      return MemoryCastleGame(controller: c);
    case GameType.patternPower:
      return PatternPowerGame(controller: c);
    case GameType.rainbowPuzzle:
      return RainbowPuzzleGame(controller: c);
    case GameType.treasureJourney:
      return TreasureJourneyGame(controller: c);
    case GameType.bubbleShooter:
      return BubbleShooterGame(controller: c);
    case GameType.happyConnect:
      return HappyConnectGame(controller: c);
    case GameType.cloudHop:
      return CloudHopGame(controller: c);
    case GameType.peekaboo:
      return PeekabooPalsGame(controller: c);
    case GameType.ruleShift:
      return RuleShiftGame(controller: c);
    case GameType.sleepyFox:
      return SleepyFoxGame(controller: c);
    case GameType.jellyfishCatcher:
      return JellyfishCatcherGame(controller: c);
    case GameType.heroShield:
      return HeroShieldGame(controller: c);
    case GameType.memoryQuest:
      return MemoryQuestGame(controller: c);
    case GameType.turboCar:
      return TurboCarGame(controller: c);
    case GameType.dinoDash:
      return DinoDashGame(controller: c);
    case GameType.beeCollector:
      return BeeCollectorGame(controller: c);
    case GameType.birdLauncher:
      return BirdLauncherGame(controller: c);
    case GameType.carrotCatch:
      return CarrotCatchGame(controller: c);
    case GameType.teddyClinic:
      return TeddyClinicGame(controller: c);
    case GameType.skyFlight:
      return SkyFlightGame(controller: c);
    case GameType.petCare:
      return PetCareGame(controller: c);
    case GameType.cloudBounce:
      return CloudBounceGame(controller: c);
    case GameType.fruitSlice:
      return FruitSliceGame(controller: c);
    case GameType.danceParty:
      return DancePartyGame(controller: c);
    case GameType.fireflyJar:
      return FireflyJarGame(controller: c);
  }
}

/// Everything the shell must record about HOW this session started.
class GameLaunchInfo {
  final EmotionState? emotion;
  final EmotionSource source;
  final int checkInMs;
  final EmotionState? previousEmotion;
  /// True = free play from the Games library. Practice is NEVER stored in the
  /// research record and never changes the journey.
  final bool practice;
  /// True = opened from the swipe feed. The session IS stored (it is real
  /// play) and synced, but it does not count as an adventure step and the
  /// adaptive journey is not advanced by it.
  final bool feed;
  const GameLaunchInfo({
    this.practice = false,
    this.feed = false,
    required this.emotion,
    required this.source,
    required this.checkInMs,
    required this.previousEmotion,
  });
}

/// Wraps a recommendation in the shared shell (header, host character,
/// pause, logging, completion card) around the right game.
Widget launchGame(GameRecommendation rec, GameLaunchInfo info) {
  return GameShell(
    type: rec.gameType,
    info: info,
    recommendation: rec,
    bodyBuilder: (context, controller) =>
        buildGameBody(rec.gameType, controller),
  );
}
