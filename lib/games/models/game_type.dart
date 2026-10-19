import 'package:flutter/material.dart';
import '../../characters/character_id.dart';

/// Which kind of experience a world offers.
enum GameCategory { calming, standard, energetic }

extension GameCategoryX on GameCategory {
  String get label {
    switch (this) {
      case GameCategory.calming:
        return 'calming';
      case GameCategory.standard:
        return 'standard';
      case GameCategory.energetic:
        return 'energetic';
    }
  }
}

/// The six Mindy worlds. One character, one mechanic, five levels each.
///
///   World             Character  Game              Mechanic
///   Magic Garden      Twinkle    Breathing Garden  breathing / regulation
///   Bubble Valley     Bubbles    Bubble Adventure  tap / catch
///   Memory Castle     Lumi       Magic Memory      memory matching
///   Superhero Academy Nova       Pattern Power     pattern completion
///   Rainbow Kingdom   Kara       Rainbow Puzzle    drag / arrange
///   Dragon Valley     Pip        Treasure Journey  exploration / navigation
enum GameType {
  breathingGarden,
  bubbleValley,
  memoryCastle,
  patternPower,
  rainbowPuzzle,
  treasureJourney,
  // Cute arcade-style additions (original games inspired by classic
  // pet-app mini-games: bubble shooter, tile connect, hopping, peekaboo).
  bubbleShooter,
  happyConnect,
  cloudHop,
  peekaboo,
  // v10: two classic child-development task designs wrapped in cute games
  ruleShift, // rule switching (sort by colour, then by shape)
  sleepyFox, // go / no-go (tap friends, not the sleepy fox)
  // v11: challenge games with hints (see docs/CHALLENGE_DESIGN.md)
  jellyfishCatcher,
  heroShield,
  memoryQuest,
  turboCar,
  dinoDash,
  beeCollector,
  birdLauncher,
  // v15: four different mechanics - drag, pretend-play steps, side-scroll, virtual pet
  carrotCatch, // drag a basket
  teddyClinic, // pretend-play helper + ordered steps
  skyFlight, // side-scrolling steering
  petCare, // virtual pet, drag items to Puffy
  // v16: action-packed games with obstacles, combos and power-ups
  cloudBounce, // bounce up clouds, springs, storm obstacles
  fruitSlice, // swipe to slice fruit, avoid socks, freeze power-up
  danceParty, // rhythm lanes, quiet notes are obstacles
  // v27: a second ACTIVE calming activity (World 7) -- Calm Maze is a slow
  // walk with little to do; this is tap-based and paced by the child.
  fireflyJar, // tap glowing fireflies into a jar, breathing ring behind it
}

class _Meta {
  final String id;
  final String title;
  final String worldName;
  final String worldKey; // asset folder: assets/worlds/<worldKey>/
  final String emoji;
  final String worldEmoji;
  final String tagline;
  final GameCategory category;
  final CharacterId character;
  final List<Color> nodeGradient;
  final List<Color> background;
  final String instruction; // one short visual hint, no reading needed
  final String invite; // what the host character says before the game

  const _Meta({
    required this.id,
    required this.title,
    required this.worldName,
    required this.worldKey,
    required this.emoji,
    required this.worldEmoji,
    required this.tagline,
    required this.category,
    required this.character,
    required this.nodeGradient,
    required this.background,
    required this.instruction,
    required this.invite,
  });
}

const Map<GameType, _Meta> _meta = {
  GameType.breathingGarden: _Meta(
    id: 'breathing_garden',
    title: 'Breathing Garden',
    worldName: 'Magic Garden',
    worldKey: 'magic_garden',
    emoji: '\u{1F338}',
    worldEmoji: '\u{1F338}',
    tagline: "Help Kara's garden bloom",
    category: GameCategory.calming,
    character: CharacterId.twinkle,
    nodeGradient: [Color(0xFFF8BBD0), Color(0xFF7CC576)],
    background: [Color(0xFFFFF1F8), Color(0xFFE6F6E4), Color(0xFFBFE8B8)],
    instruction: '\u{1F440} Breathe with the flower',
    invite: 'Come with me to the magical garden.',
  ),
  GameType.bubbleValley: _Meta(
    id: 'bubble_valley',
    title: 'Bubble Valley',
    worldName: 'Bubble Valley',
    worldKey: 'bubble_valley',
    emoji: '\u{1FAE7}',
    worldEmoji: '\u{1FAE7}',
    tagline: 'Help Bubbles collect bubbles',
    category: GameCategory.calming,
    character: CharacterId.bubbles,
    nodeGradient: [Color(0xFF80DEEA), Color(0xFF0288D1)],
    background: [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF81D4FA)],
    instruction: '\u{1F446} Tap the bubbles',
    invite: 'Bubbles has a little adventure waiting for you!',
  ),
  GameType.memoryCastle: _Meta(
    id: 'memory_castle',
    title: 'Feelings Memory',
    worldName: 'Memory Castle',
    worldKey: 'memory_castle',
    emoji: '\u{1F3F0}',
    worldEmoji: '\u{1F3F0}',
    tagline: 'Find the matching feelings',
    category: GameCategory.standard,
    character: CharacterId.lumi,
    nodeGradient: [Color(0xFFE1BEE7), Color(0xFF8E24AA)],
    background: [Color(0xFFFFF0FA), Color(0xFFF1E0FF), Color(0xFFD7C4F5)],
    instruction: '\u{1F446} Flip two cards',
    invite: "Lumi's castle has feeling cards to find!",
  ),
  GameType.patternPower: _Meta(
    id: 'pattern_power',
    title: 'Pattern Power',
    worldName: 'Superhero Academy',
    worldKey: 'superhero_academy',
    emoji: '\u26A1',
    worldEmoji: '\u26A1',
    tagline: "Nova's power patterns",
    category: GameCategory.energetic,
    character: CharacterId.nova,
    nodeGradient: [Color(0xFF82B1FF), Color(0xFF3D5AFE)],
    background: [Color(0xFFE3F0FF), Color(0xFFC9DCFF), Color(0xFFB3C8FF)],
    instruction: '\u{1F446} What comes next?',
    invite: 'Nova needs your help with Power Patterns!',
  ),
  GameType.rainbowPuzzle: _Meta(
    id: 'rainbow_puzzle',
    title: 'Rainbow Puzzle',
    worldName: 'Rainbow Kingdom',
    worldKey: 'rainbow_kingdom',
    emoji: '\u{1F308}',
    worldEmoji: '\u{1F308}',
    tagline: "Finish Kara's rainbow scene",
    category: GameCategory.standard,
    character: CharacterId.kara,
    nodeGradient: [Color(0xFFFFAB91), Color(0xFFBA68C8)],
    background: [Color(0xFFFFE3F1), Color(0xFFE5DAFF), Color(0xFFD0ECFF)],
    instruction: '\u{1F449} Drag to the right spot',
    invite: "Kara's rainbow needs some missing pieces!",
  ),
  GameType.treasureJourney: _Meta(
    id: 'calm_maze',
    title: 'Calm Maze',
    worldName: 'Dragon Valley',
    worldKey: 'dragon_valley',
    emoji: '\u{1F409}',
    worldEmoji: '\u{1F409}',
    tagline: 'Walk Pip through the gentle maze',
    category: GameCategory.calming,
    character: CharacterId.pip,
    nodeGradient: [Color(0xFFA5D6A7), Color(0xFFFFB74D)],
    background: [Color(0xFFFFF8E1), Color(0xFFE8F5D0), Color(0xFFC5E1A5)],
    instruction: '\u{1F446} Tap or drag to walk',
    invite: 'Pip is going for a gentle walk. Come along!',
  ),
  GameType.bubbleShooter: _Meta(
    id: 'bubble_shooter',
    title: 'Bubble Pop Shooter',
    worldName: 'Bubble Bay',
    worldKey: 'bubble_bay',
    emoji: '\u{1F3AF}',
    worldEmoji: '\u{1F42C}',
    tagline: 'Aim, pop and match the bubbles',
    category: GameCategory.standard,
    character: CharacterId.bubbles,
    nodeGradient: [Color(0xFF80F0E0), Color(0xFF00A8C8)],
    background: [Color(0xFFD6FBFF), Color(0xFFA6EDF7), Color(0xFF7DD8F0)],
    instruction: '\u{1F446} Drag to aim, let go to shoot',
    invite: 'Bubbles found a bay full of bubbles. Want to pop them?',
  ),
  GameType.happyConnect: _Meta(
    id: 'happy_connect',
    title: 'Happy Connect',
    worldName: 'Friendship Garden',
    worldKey: 'friendship_garden',
    emoji: '\u{1F517}',
    worldEmoji: '\u{1F33B}',
    tagline: 'Connect the matching friends',
    category: GameCategory.standard,
    character: CharacterId.lumi,
    nodeGradient: [Color(0xFFFFE082), Color(0xFFFF8A65)],
    background: [Color(0xFFFFF6DB), Color(0xFFFFE6C2), Color(0xFFFFD2B8)],
    instruction: '\u{1F446} Tap two matching friends',
    invite: "Lumi's garden friends want to say hello to each other!",
  ),
  GameType.cloudHop: _Meta(
    id: 'cloud_hop',
    title: 'Cloud Hop',
    worldName: 'Sky Meadow',
    worldKey: 'sky_meadow',
    emoji: '\u2601\uFE0F',
    worldEmoji: '\u{1F324}\uFE0F',
    tagline: 'Hop from cloud to cloud',
    category: GameCategory.energetic,
    character: CharacterId.pip,
    nodeGradient: [Color(0xFF90CAF9), Color(0xFF7E57C2)],
    background: [Color(0xFFDDF1FF), Color(0xFFBFE3FF), Color(0xFFE3D9FF)],
    instruction: '\u{1F446} Tap to hop',
    invite: 'Pip wants to hop across the clouds. Can you help?',
  ),
  GameType.peekaboo: _Meta(
    id: 'peekaboo',
    title: 'Peekaboo Pals',
    worldName: 'Pal Playground',
    worldKey: 'pal_playground',
    emoji: '\u{1F44B}',
    worldEmoji: '\u{1F3A0}',
    tagline: 'Say hello to the peeking pals',
    category: GameCategory.standard,
    character: CharacterId.kara,
    nodeGradient: [Color(0xFFC5E1A5), Color(0xFFFFB74D)],
    background: [Color(0xFFEAF8D4), Color(0xFFD7F0B5), Color(0xFFFFEFC2)],
    instruction: '\u{1F446} Tap a pal to say hi',
    invite: 'Kara says some shy pals are peeking out. Say hi!',
  ),
  GameType.ruleShift: _Meta(
    id: 'rule_shift',
    title: 'Sorting Stars',
    worldName: 'Sorting Academy',
    worldKey: 'superhero_academy',
    emoji: '\u{1F31F}',
    worldEmoji: '\u{1F9B8}',
    tagline: "Nova's sorting rules change!",
    category: GameCategory.standard,
    character: CharacterId.nova,
    nodeGradient: [Color(0xFFFFE082), Color(0xFF7C4DFF)],
    background: [Color(0xFFEDE7FF), Color(0xFFD9CCFF), Color(0xFFFFF1C9)],
    instruction: '\u{1F446} Follow the rule, tap the box',
    invite: 'Nova has a sorting game, and the rule might change!',
  ),
  GameType.sleepyFox: _Meta(
    id: 'sleepy_fox',
    title: 'Sleepy Fox',
    worldName: 'Quiet Meadow',
    worldKey: 'friendship_garden',
    emoji: '\u{1F98A}',
    worldEmoji: '\u{1F319}',
    tagline: "Wake the friends, not the fox",
    category: GameCategory.standard,
    character: CharacterId.lumi,
    nodeGradient: [Color(0xFFFFCC80), Color(0xFF5C6BC0)],
    background: [Color(0xFFE8EAF6), Color(0xFFD1D9FF), Color(0xFFFFE9C7)],
    instruction: '\u{1F446} Tap friends. Let the fox sleep!',
    invite: 'Lumi says: tap the friends, but let the sleepy fox snooze.',
  ),
  GameType.jellyfishCatcher: _Meta(
    id: 'jellyfish_catcher',
    title: 'Jellyfish Catcher',
    worldName: 'Bubble Bay',
    worldKey: 'bubble_bay',
    emoji: '\u{1FAE7}',
    worldEmoji: '\u{1F30A}',
    tagline: 'Catch the right jellyfish',
    category: GameCategory.standard,
    character: CharacterId.bubbles,
    nodeGradient: [Color(0xFFF8BBD0), Color(0xFF29B6F6)],
    background: [Color(0xFFD6FBFF), Color(0xFFA6EDF7), Color(0xFF7DD8F0)],
    instruction: '\u{1F446} Tap the right jellyfish',
    invite: 'Bubbles needs help catching jellyfish!',
  ),
  GameType.heroShield: _Meta(
    id: 'hero_shield',
    title: 'Hero Shield',
    worldName: 'Superhero Academy',
    worldKey: 'superhero_academy',
    emoji: '\u{1F6E1}\uFE0F',
    worldEmoji: '\u26A1',
    tagline: 'Protect bunny with the right shield',
    category: GameCategory.energetic,
    character: CharacterId.nova,
    nodeGradient: [Color(0xFF82B1FF), Color(0xFF7C4DFF)],
    background: [Color(0xFFE3F0FF), Color(0xFFC9DCFF), Color(0xFFB3C8FF)],
    instruction: '\u{1F446} Tap the right shield',
    invite: 'Nova needs a shield hero. That is you!',
  ),
  GameType.memoryQuest: _Meta(
    id: 'memory_quest',
    title: 'Rainbow Memory Quest',
    worldName: 'Rainbow Kingdom',
    worldKey: 'rainbow_kingdom',
    emoji: '\u{1F48E}',
    worldEmoji: '\u{1F984}',
    tagline: 'Remember the magic gems',
    category: GameCategory.standard,
    character: CharacterId.kara,
    nodeGradient: [Color(0xFFFFAB91), Color(0xFFBA68C8)],
    background: [Color(0xFFFFE3F1), Color(0xFFE5DAFF), Color(0xFFD0ECFF)],
    instruction: '\u{1F446} Copy the gem order',
    invite: 'Kara\u2019s gems are twinkling. Can you remember the order?',
  ),
  GameType.turboCar: _Meta(
    id: 'turbo_car',
    title: 'Turbo Car',
    worldName: 'Sky Meadow',
    worldKey: 'sky_meadow',
    emoji: '\u{1F697}',
    worldEmoji: '\u{1F6E3}\uFE0F',
    tagline: 'Steer around the rocks',
    category: GameCategory.energetic,
    character: CharacterId.pip,
    nodeGradient: [Color(0xFF90CAF9), Color(0xFFFF7043)],
    background: [Color(0xFFDDF1FF), Color(0xFFBFE3FF), Color(0xFFE3D9FF)],
    instruction: '\u{1F446} Tap left or right to steer',
    invite: 'Pip is ready to drive. Buckle up!',
  ),
  GameType.dinoDash: _Meta(
    id: 'dino_dash',
    title: 'Dino Dash',
    worldName: 'Dragon Valley',
    worldKey: 'dragon_valley',
    emoji: '\u{1F996}',
    worldEmoji: '\u{1F30B}',
    tagline: 'Jump the cactus, not the bird',
    category: GameCategory.energetic,
    character: CharacterId.pip,
    nodeGradient: [Color(0xFFA5D6A7), Color(0xFFFFB74D)],
    background: [Color(0xFFFFF8E1), Color(0xFFE8F5D0), Color(0xFFC5E1A5)],
    instruction: '\u{1F446} Tap to jump',
    invite: 'Pip\u2019s dino friend loves to run!',
  ),
  GameType.beeCollector: _Meta(
    id: 'bee_collector',
    title: 'Honey Bee',
    worldName: 'Magic Garden',
    worldKey: 'magic_garden',
    emoji: '\u{1F41D}',
    worldEmoji: '\u{1F33C}',
    tagline: 'Collect the right flowers',
    category: GameCategory.standard,
    character: CharacterId.twinkle,
    nodeGradient: [Color(0xFFFFF59D), Color(0xFFFFB300)],
    background: [Color(0xFFFFF1F8), Color(0xFFE6F6E4), Color(0xFFBFE8B8)],
    instruction: '\u{1F446} Tap the flower on the card',
    invite: 'Twinkle\u2019s bee wants flowers. Check the card!',
  ),
  GameType.birdLauncher: _Meta(
    id: 'bird_launcher',
    title: 'Bird Launcher',
    worldName: 'Pal Playground',
    worldKey: 'pal_playground',
    emoji: '\u{1F426}',
    worldEmoji: '\u{1F388}',
    tagline: 'Launch the bird at the balloons',
    category: GameCategory.standard,
    character: CharacterId.lumi,
    nodeGradient: [Color(0xFFC5E1A5), Color(0xFFEF5350)],
    background: [Color(0xFFEAF8D4), Color(0xFFD7F0B5), Color(0xFFFFEFC2)],
    instruction: '\u{1F446} Drag back, let go',
    invite: 'Lumi\u2019s bird wants to pop balloons!',
  ),
  GameType.carrotCatch: _Meta(
    id: 'carrot_catch',
    title: 'Carrot Catch',
    worldName: 'Sunny Farm',
    worldKey: 'carrot_farm',
    emoji: '\u{1F955}',
    worldEmoji: '\u{1F33E}',
    tagline: 'Slide the basket and catch the food',
    category: GameCategory.energetic,
    character: CharacterId.bubbles,
    nodeGradient: [Color(0xFFFFCC80), Color(0xFF8BC34A)],
    background: [Color(0xFFFFF8E1), Color(0xFFDCEDC8), Color(0xFFAED581)],
    instruction: '\u{1F449} Slide the basket',
    invite: 'Bubbles dropped the picnic! Can you catch it?',
  ),
  GameType.teddyClinic: _Meta(
    id: 'teddy_clinic',
    title: 'Teddy Clinic',
    worldName: 'Toy Clinic',
    worldKey: 'toy_clinic',
    emoji: '\u{1FA7A}',
    worldEmoji: '\u{1F9F8}',
    tagline: 'Be the doctor for your toy friends',
    category: GameCategory.standard,
    character: CharacterId.kara,
    nodeGradient: [Color(0xFFB2DFDB), Color(0xFF80CBC4)],
    background: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
    instruction: '\u{1F446} Pick the right helper',
    invite: 'Kara needs a doctor for the toy clinic. That is you!',
  ),
  GameType.skyFlight: _Meta(
    id: 'sky_flight',
    title: 'Sky Flight',
    worldName: 'Star Sky',
    worldKey: 'sky_trail',
    emoji: '\u{1F432}',
    worldEmoji: '\u2B50',
    tagline: 'Fly Pip through the stars',
    category: GameCategory.energetic,
    character: CharacterId.pip,
    nodeGradient: [Color(0xFF81D4FA), Color(0xFF7E57C2)],
    background: [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF81D4FA)],
    instruction: '\u{1F446} Slide up and down to fly',
    invite: 'Pip wants to fly through the stars with you!',
  ),
  GameType.petCare: _Meta(
    id: 'pet_care',
    title: "Puffy's Day",
    worldName: "Puffy's Home",
    worldKey: 'puffy_home',
    emoji: '\u{1F9F6}',
    worldEmoji: '\u{1F3E0}',
    tagline: 'Look after your fluffy pet Puffy',
    category: GameCategory.calming,
    character: CharacterId.twinkle,
    nodeGradient: [Color(0xFFFFE0B2), Color(0xFFF48FB1)],
    background: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCCBC)],
    instruction: '\u{1F449} Drag it to Puffy',
    invite: 'Twinkle has a fluffy friend who needs you!',
  ),
  GameType.cloudBounce: _Meta(
    id: 'cloud_bounce',
    title: 'Cloud Bounce',
    worldName: 'Cloud Castle',
    worldKey: 'cloud_castle',
    emoji: '\u{1F984}',
    worldEmoji: '\u2601\uFE0F',
    tagline: 'Bounce up the clouds to the stars',
    category: GameCategory.energetic,
    character: CharacterId.kara,
    nodeGradient: [Color(0xFFB39DDB), Color(0xFFF8BBD0)],
    background: [Color(0xFFEDE7F6), Color(0xFFF8BBD0), Color(0xFFFFF3E0)],
    instruction: '\u{1F449} Slide to steer Kara',
    invite: 'Kara is bouncing to the stars. Come bounce too!',
  ),
  GameType.fruitSlice: _Meta(
    id: 'fruit_slice',
    title: 'Fruit Slice Party',
    worldName: 'Fruit Party',
    worldKey: 'fruit_party',
    emoji: '\u{1F349}',
    worldEmoji: '\u{1F389}',
    tagline: 'Swipe the fruit, skip the stinky socks',
    category: GameCategory.energetic,
    character: CharacterId.nova,
    nodeGradient: [Color(0xFFFF8A65), Color(0xFFFFEE58)],
    background: [Color(0xFFFFF9C4), Color(0xFFFFE0B2), Color(0xFFFFCCBC)],
    instruction: '\u{1F449} Swipe across the fruit',
    invite: 'Nova is throwing a fruit party! Swipe to slice!',
  ),
  GameType.fireflyJar: _Meta(
    id: 'firefly_jar',
    title: 'Firefly Jar',
    worldName: 'Firefly Meadow',
    worldKey: 'firefly_meadow',
    emoji: '\u{1FAB0}',
    worldEmoji: '\u{1F319}',
    tagline: 'Catch fireflies, breathe easy',
    category: GameCategory.calming,
    character: CharacterId.twinkle,
    nodeGradient: [Color(0xFF2A1F54), Color(0xFFFFE27A)],
    background: [Color(0xFF151A3D), Color(0xFF2A1F54), Color(0xFF3B2E6E)],
    instruction: '\u{1F446} Tap a glowing firefly, any time you like',
    invite: 'Twinkle\u2019s fireflies are waking up. Help them into the jar!',
  ),
  GameType.danceParty: _Meta(
    id: 'dance_party',
    title: 'Dance Party',
    worldName: 'Disco Castle',
    worldKey: 'dance_floor',
    emoji: '\u{1F483}',
    worldEmoji: '\u{1F3B6}',
    tagline: 'Tap the notes and dance with Lumi',
    category: GameCategory.standard,
    character: CharacterId.lumi,
    nodeGradient: [Color(0xFF7E57C2), Color(0xFFEC407A)],
    background: [Color(0xFFD1C4E9), Color(0xFFF48FB1), Color(0xFFCE93D8)],
    instruction: '\u{1F446} Tap when the note glows',
    invite: 'Lumi is dancing. Tap the music notes with her!',
  ),
};

/// What an activity is FOR in the adaptive framework.
///  regulation  calming, paced activities (breathing, calm maze)
///  supportive  gentle, forgiving interactive activity (a soft step up)
///  standard    ordinary play
///  engaging    richer, more energetic play
enum ActivityRole { regulation, supportive, standard, engaging }

const Map<GameType, ActivityRole> _roles = {
  GameType.breathingGarden: ActivityRole.regulation,
  GameType.treasureJourney: ActivityRole.regulation,
  GameType.fireflyJar: ActivityRole.regulation,
  GameType.bubbleValley: ActivityRole.supportive,
  GameType.memoryCastle: ActivityRole.standard,
  GameType.rainbowPuzzle: ActivityRole.standard,
  GameType.patternPower: ActivityRole.engaging,
  GameType.bubbleShooter: ActivityRole.standard,
  GameType.happyConnect: ActivityRole.standard,
  GameType.cloudHop: ActivityRole.engaging,
  GameType.peekaboo: ActivityRole.supportive,
  GameType.ruleShift: ActivityRole.engaging,
  GameType.sleepyFox: ActivityRole.standard,
  GameType.jellyfishCatcher: ActivityRole.standard,
  GameType.heroShield: ActivityRole.engaging,
  GameType.memoryQuest: ActivityRole.standard,
  GameType.turboCar: ActivityRole.engaging,
  GameType.dinoDash: ActivityRole.engaging,
  GameType.beeCollector: ActivityRole.supportive,
  GameType.birdLauncher: ActivityRole.standard,
  GameType.carrotCatch: ActivityRole.engaging,
  GameType.teddyClinic: ActivityRole.standard,
  GameType.skyFlight: ActivityRole.engaging,
  GameType.petCare: ActivityRole.supportive,
  GameType.cloudBounce: ActivityRole.engaging,
  GameType.fruitSlice: ActivityRole.engaging,
  GameType.danceParty: ActivityRole.engaging,
};

extension GameTypeX on GameType {
  ActivityRole get role => _roles[this]!;
  bool get isRegulation => role == ActivityRole.regulation;
  /// Whether this activity has right/wrong moments at all.
  ///
  /// v29 fix. This used to exclude Breathing Garden by name, which was wrong
  /// in a way that mattered: EVERY regulation activity follows the calm-pool
  /// rule that nothing can be failed, so none of them ever calls
  /// recordMistake(). Firefly Jar, for instance, records only successes, so
  /// its accuracy was always 1.0, which produced PerformanceBand.high on
  /// every completed session -- and two of those are "consistently smooth
  /// play", which could raise the DIFFICULTY of a calming activity.
  ///
  /// Keying this off the role means any future regulation activity is
  /// excluded automatically instead of having to be remembered here.
  bool get hasPerformanceData => !isRegulation;

  String get id => _meta[this]!.id;
  String get title => _meta[this]!.title;
  String get worldName => _meta[this]!.worldName;
  String get worldKey => _meta[this]!.worldKey;
  String get emoji => _meta[this]!.emoji;
  String get worldEmoji => _meta[this]!.worldEmoji;
  String get tagline => _meta[this]!.tagline;
  GameCategory get category => _meta[this]!.category;
  CharacterId get character => _meta[this]!.character;
  List<Color> get nodeGradient => _meta[this]!.nodeGradient;
  List<Color> get background => _meta[this]!.background;
  String get instruction => _meta[this]!.instruction;
  String get invite => _meta[this]!.invite;
}
