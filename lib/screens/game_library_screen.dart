import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../games/base/game_factory.dart';
import '../games/models/game_difficulty.dart';
import '../games/models/game_pace.dart';
import '../games/models/game_recommendation.dart';
import '../games/models/game_type.dart';
import '../models/decision_trace.dart';
import '../models/study_condition.dart';
import '../services/app_settings.dart';

/// The Games tab: every game in one scrollable list, always playable.
/// Games here are PRACTICE: nothing is stored in the research record, the
/// adventure is not changed, and there is no check-in. The journey tab is
/// where the study data comes from.
class GameLibraryScreen extends StatefulWidget {
  const GameLibraryScreen({super.key});

  /// The action-packed games are shown first, with a NEW tag.
  static const List<GameType> featured = [
    GameType.cloudBounce,
    GameType.fruitSlice,
    GameType.danceParty,
    GameType.skyFlight,
    GameType.carrotCatch,
    GameType.teddyClinic,
    GameType.petCare,
  ];

  /// Pure filter, kept static so it can be unit tested.
  static List<GameType> filterGames(
    Iterable<GameType> all, {
    String query = '',
    GameCategory? category,
    bool onlyFavourites = false,
    Set<String> favourites = const {},
  }) {
    final q = query.trim().toLowerCase();
    final out = all.where((g) {
      if (category != null && g.category != category) return false;
      if (onlyFavourites && !favourites.contains(g.id)) return false;
      if (q.isEmpty) return true;
      return g.title.toLowerCase().contains(q) ||
          g.tagline.toLowerCase().contains(q);
    }).toList();
    int rank(GameType g) {
      final i = featured.indexOf(g);
      return i < 0 ? 1000 + g.index : i;
    }
    out.sort((a, b) => rank(a).compareTo(rank(b)));
    return out;
  }

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen> {
  int _level = 1;
  String _query = '';
  GameCategory? _category; // null = all
  bool _onlyFavourites = false;
  final Set<String> _favourites = {};
  static const _favKey = 'mindy.practice.favourites';

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  // Favourites are a per-device convenience. If storage is unavailable the
  // list simply starts empty; nothing breaks.
  Future<void> _loadFavourites() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getStringList(_favKey) ?? const <String>[];
      if (mounted) setState(() => _favourites.addAll(saved));
    } catch (_) {}
  }

  Future<void> _toggleFavourite(GameType g) async {
    setState(() {
      if (!_favourites.remove(g.id)) _favourites.add(g.id);
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_favKey, _favourites.toList());
    } catch (_) {}
  }

  void _play(GameType t) => launchPractice(context, t, _level);

  @override
  Widget build(BuildContext context) {
    final games = GameLibraryScreen.filterGames(GameType.values,
        query: _query,
        category: _category,
        onlyFavourites: _onlyFavourites,
        favourites: _favourites);
    return Scaffold(
      appBar: AppBar(title: const Text('All the games')),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text('Just for fun. These do not change your adventure.',
                    style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('gameSearch'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Find a game',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null && !_onlyFavourites,
                    onSelected: (_) => setState(() {
                      _category = null;
                      _onlyFavourites = false;
                    }),
                  ),
                  for (final c in GameCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  FilterChip(
                    key: const Key('favouritesFilter'),
                    avatar: const Icon(Icons.favorite, size: 16),
                    label: const Text('Favourites'),
                    selected: _onlyFavourites,
                    onSelected: (v) => setState(() => _onlyFavourites = v),
                  ),
                ]),
                Row(children: [
                  const Text('Level  ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Slider(
                      value: _level.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_level',
                      onChanged: (v) => setState(() => _level = v.round()),
                    ),
                  ),
                  Text('$_level'),
                ]),
                if (games.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        key: Key('noGames'),
                        child: Text('No games match. Try another word or filter.')),
                  ),
              ]),
            ),
          ),
          // Responsive grid: 1 column on phones, more on tablets / desktop.
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 92,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _tile(games[i]),
                childCount: games.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(GameType g) {
    final fav = _favourites.contains(g.id);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: Key('game_${g.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _play(g),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              g.nodeGradient.first.withValues(alpha: 0.35),
              g.nodeGradient.last.withValues(alpha: 0.35),
            ]),
          ),
          child: Row(children: [
            Text(g.emoji, style: const TextStyle(fontSize: 38)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    if (GameLibraryScreen.featured.contains(g))
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFF4081),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('NEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900)),
                      ),
                  ]),
                  Text(g.tagline, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(
              key: Key('fav_${g.id}'),
              tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
              onPressed: () => _toggleFavourite(g),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A practice run of any game: free play, never stored, adventure untouched.
GameRecommendation practiceRecommendation(GameType t, int level) {
  final trace = DecisionTrace(
    timestamp: DateTime.now(),
    condition: StudyCondition.fixedBaseline.code,
    journeyStep: 0,
    emotion: null,
    emotionSource: 'APP',
    previousActivity: null,
    previousLevel: null,
    recentMoodChange: 'unknown',
    engagement: 'unknown',
    performanceEvidence: 'practice',
    selectedActivity: t.id,
    selectedLevel: level,
    selectedDifficulty: levelToDifficulty(level).label,
    selectedPace: GamePace.normal.name,
    ruleId: 'PRACTICE',
    baselineLevel: level,
    modifier: 0,
    modifierReason: 'practice play',
    recovery: false,
    humanReason: 'Chosen by the child in free play.',
    scores: const [],
    stateSnapshot: const {},
  );
  return GameRecommendation(
    gameType: t,
    level: level,
    pace: GamePace.normal,
    trace: trace,
    childMessage: 'Let\u2019s play!',
    hostMessage: t.invite,
  );
}

/// A run opened from the swipe feed (see lib/feed). Stored as real play.
GameRecommendation feedRecommendation(GameType t, int level, String reason) {
  final trace = DecisionTrace(
    timestamp: DateTime.now(),
    condition: AppSettings.instance.condition.code,
    journeyStep: 0,
    emotion: null,
    emotionSource: 'APP',
    previousActivity: null,
    previousLevel: null,
    recentMoodChange: 'unknown',
    engagement: 'unknown',
    performanceEvidence: 'feed play',
    selectedActivity: t.id,
    selectedLevel: level,
    selectedDifficulty: levelToDifficulty(level).label,
    selectedPace: GamePace.normal.name,
    ruleId: 'FEED',
    baselineLevel: level,
    modifier: 0,
    modifierReason: 'feed play',
    recovery: false,
    humanReason: reason,
    scores: const [],
    stateSnapshot: const {},
  );
  return GameRecommendation(
    gameType: t,
    level: level,
    pace: level <= 1 ? GamePace.slow : GamePace.normal,
    trace: trace,
    childMessage: 'Let\u2019s play!',
    hostMessage: t.invite,
  );
}

void launchPractice(BuildContext context, GameType t, [int level = 2]) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => launchGame(
      practiceRecommendation(t, level),
      const GameLaunchInfo(
        practice: true,
        emotion: null,
        source: EmotionSource.app,
        checkInMs: 0,
        previousEmotion: null,
      ),
    ),
  ));
}
