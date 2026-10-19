import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../feed/feed_log_service.dart';
import '../feed/feed_planner.dart';
import '../games/base/game_factory.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import '../services/session_repository.dart';
import 'game_library_screen.dart';

/// Mindy Feed: swipe up to discover short games, the way children already
/// browse short videos. Each card is one game; tap Play to start it.
///
/// What it records (browsing behaviour only, per child, on the device):
/// how long each card was looked at, whether it was played, and quick
/// swipe-aways. Played games are stored like any other session and are
/// marked trigger = "feed".
class FeedScreen extends StatefulWidget {
  /// False while another tab is showing, so time away is not counted.
  final bool active;
  const FeedScreen({super.key, this.active = true});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pc = PageController();
  final List<FeedItem> _items = [];
  int _page = 0;
  DateTime _shownAt = DateTime.now();
  bool _skipNextLog = false;
  int _skipStreak = 0;

  EmotionState? get _lastEmotion {
    final l = SessionRepository.instance.last;
    return l == null ? null : (l.emotionAfter ?? l.emotionBefore);
  }

  FeedItem _item(int i) {
    while (_items.length <= i) {
      _items.add(FeedPlanner.next(
        index: _items.length,
        shown: _items,
        lastEmotion: _lastEmotion,
        skipStreak: _skipStreak,
      ));
    }
    return _items[i];
  }

  void _logView(int page, {required bool played}) {
    if (_items.length <= page) return;
    final it = _items[page];
    final dwell = DateTime.now().difference(_shownAt).inMilliseconds;
    final v = FeedView(
      at: _shownAt,
      index: it.index,
      gameId: it.game.id,
      kind: it.kind.code,
      dwellMs: dwell,
      played: played,
    );
    FeedLogService.instance.add(v);
    _skipStreak = v.quickSkip ? _skipStreak + 1 : 0;
  }

  void _onPage(int i) {
    if (_skipNextLog) {
      _skipNextLog = false;
    } else {
      _logView(_page, played: false);
    }
    _page = i;
    _shownAt = DateTime.now();
  }

  @override
  void didUpdateWidget(FeedScreen old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) {
      _logView(_page, played: false);
      _skipNextLog = false;
    } else if (!old.active && widget.active) {
      _shownAt = DateTime.now();
    }
  }

  Future<void> _play(FeedItem it) async {
    _logView(_page, played: true);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => launchGame(
        feedRecommendation(it.game, it.level, it.reason),
        const GameLaunchInfo(
          feed: true,
          emotion: null,
          source: EmotionSource.app,
          checkInMs: 0,
          previousEmotion: null,
        ),
      ),
    ));
    // Back from the game: time away is not browsing time.
    _skipNextLog = true;
    _shownAt = DateTime.now();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.active && !_skipNextLog) _logView(_page, played: false);
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        key: const Key('feedPager'),
        controller: _pc,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPage,
        itemBuilder: (context, i) => _FeedCard(
          item: _item(i),
          onPlay: () => _play(_item(i)),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onPlay;
  const _FeedCard({required this.item, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final g = item.game;
    final colors = g.nodeGradient;
    return Container(
      key: Key('feedCard_${item.index}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.first, colors.last],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final sprite = (box.maxHeight * 0.30).clamp(90.0, 240.0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(item.kind.label,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Sprite('host_${g.character.name}', width: sprite, height: sprite),
                    const SizedBox(height: 12),
                    Text(g.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
                    const SizedBox(height: 6),
                    Text(g.invite,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 220,
                      height: 60,
                      child: ElevatedButton(
                        key: Key('feedPlay_${item.index}'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF5B34C9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30))),
                        onPressed: onPlay,
                        child: const Text('Play',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 34),
              const Text('Swipe up for another game',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          );
        }),
      ),
    );
  }
}
