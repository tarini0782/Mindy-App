import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/buddy.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';
import 'models/game_pace.dart';

/// WORLD 3 -- MEMORY CASTLE (Lumi the princess). Memory matching.
///
/// Flip two magic cards to find a pair. No timer, no punishment: a wrong
/// pair simply flips back and Lumi says "Almost! Let's look again."
///
/// The cards are the feeling creatures (Happy, Sad, Calm, Scared, Worried,
/// Excited, Okay). Not a memory test: gameplay indicators only.
///
///   Level  pairs  grid   preview     extras
///   1      3      3 x 2  long        -
///   2      4      4 x 2              -
///   3      5      4 x 3              -
///   4      6      4 x 3  shorter     all six main feelings
///   5      7      4 x 4  shortest    adds look-alike "Okay"; soft sparkles
/// Everything level/pace change in Feelings Memory (testable).
class MemoryParams {
  final int pairs;
  final int columns;
  final double previewSec;
  final bool sparkles;
  final bool lookAlikes; // adds the "Okay" creature
  const MemoryParams({
    required this.pairs,
    required this.columns,
    required this.previewSec,
    required this.sparkles,
    required this.lookAlikes,
  });

  static MemoryParams forLevel(int level, GamePace pace) => MemoryParams(
        pairs: pickByLevel(level, 3, 4, 5, 6, 7),
        columns: pickByLevel(level, 3, 4, 4, 4, 4),
        previewSec: pickByLevel(level, 3.2, 2.8, 2.4, 2.0, 1.8) * pace.timeScale,
        sparkles: level >= 5,
        lookAlikes: level >= 5,
      );
}

class MemoryCastleGame extends StatefulWidget {
  final GameSessionController controller;
  const MemoryCastleGame({super.key, required this.controller});

  @override
  State<MemoryCastleGame> createState() => _MemoryCastleGameState();
}

class _CardArt {
  final BuddyKind kind;
  final String label;
  final Color color;
  const _CardArt(this.kind, this.label, this.color);
}

/// Feelings the cards teach (not a test of anything): Happy, Sad, Calm,
/// Scared, Angry/Worried, Excited, plus Okay as a look-alike for level 5.
const List<_CardArt> _castleCards = [
  _CardArt(BuddyKind.happy, 'Happy', Color(0xFFFFF4B8)),
  _CardArt(BuddyKind.sad, 'Sad', Color(0xFFDCEBFF)),
  _CardArt(BuddyKind.calm, 'Calm', Color(0xFFEAE2FF)),
  _CardArt(BuddyKind.scared, 'Scared', Color(0xFFD9F6EE)),
  _CardArt(BuddyKind.worried, 'Worried', Color(0xFFFFDDD6)),
  _CardArt(BuddyKind.excited, 'Excited', Color(0xFFFFD9EC)),
  _CardArt(BuddyKind.neutral, 'Okay', Color(0xFFE6F6CF)),
];

class _MemoryCastleGameState extends State<MemoryCastleGame> {
  late final int _pairs;
  late final int _cols;
  late final double _previewSec;
  late final bool _sparkles;
  late final List<int> _cards;
  late final List<bool> _up;
  late final List<bool> _matched;
  int? _first;
  bool _locked = true;
  Timer? _timer;
  int _matches = 0;
  final Stopwatch _think = Stopwatch();
  bool _thinkStarted = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    final mp = MemoryParams.forLevel(c.level, c.pace);
    _pairs = mp.pairs;
    _cols = mp.columns;
    _previewSec = mp.previewSec;
    _sparkles = mp.sparkles;

    final rand = Random();
    final poolSize = mp.lookAlikes ? _castleCards.length : 6;
    final pool = List<int>.generate(poolSize, (i) => i)..shuffle(rand);
    final chosen = pool.take(_pairs).toList();
    _cards = [...chosen, ...chosen]..shuffle(rand);
    _up = List<bool>.filled(_cards.length, true); // preview: all face up
    _matched = List<bool>.filled(_cards.length, false);
    c.setUnits(0, _pairs);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.lumi),
        ms: 3000);
    _timer = c.schedule((_previewSec * 1000).round(), _endPreview);
  }

  void _endPreview() {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _up.length; i++) {
        _up[i] = false;
      }
      _locked = false;
    });
    widget.controller.react(CharacterState.encouraging, "Now find the pairs!",
        ms: 2000);
  }

  void _tap(int i) {
    if (_locked || _matched[i] || _up[i]) return;
    final c = widget.controller;
    GameAudio.tap();
    if (!_thinkStarted) {
      _think
        ..reset()
        ..start();
      _thinkStarted = true;
    }
    setState(() => _up[i] = true);

    if (_first == null) {
      _first = i;
      return;
    }

    final a = _first!;
    _first = null;
    if (_think.isRunning) {
      final ms = _think.elapsedMilliseconds;
      if (ms < 30000) c.recordResponse(ms); // ignore long pauses/breaks
      _think.stop();
    }
    _thinkStarted = false;

    if (_cards[a] == _cards[i]) {
      _matches++;
      _matched[a] = true;
      _matched[i] = true;
      c.recordSuccess();
      c.setUnits(_matches, _pairs);
      GameAudio.success();
      final box = context.findRenderObject() as RenderBox?;
      final mid = box == null ? const Offset(120, 120) : Offset(box.size.width / 2, box.size.height / 3);
      c.burst(mid, '\u2728');
      c.react(
        CharacterState.celebrating,
        CharacterLines.lumiMatch[_matches % CharacterLines.lumiMatch.length],
        ms: 1800,
      );
      if (_matches >= _pairs) {
        _locked = true;
        c.finishLine = CharacterLines.completion(CharacterId.lumi);
        _timer = c.schedule(900, () {
          if (mounted) c.complete();
        });
      }
    } else {
      c.recordMistake();
      _locked = true;
      c.react(CharacterState.encouraging, CharacterLines.lumiMiss, ms: 2000);
      _timer = c.schedule((1100 * c.timeScale).round(), () {
        if (!mounted) return;
        setState(() {
          _up[a] = false;
          _up[i] = false;
          _locked = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final rows = (_cards.length / _cols).ceil();
      const gap = 10.0;
      final w = (box.maxWidth - gap * (_cols + 1)) / _cols;
      final h = (box.maxHeight - gap * (rows + 1)) / rows;
      final size = max(40.0, min(min(w, h), 140.0));
      return Stack(
        children: [
          if (_sparkles)
            const Positioned.fill(child: IgnorePointer(child: _SoftSparkles())),
          Center(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _cards.length; i++)
                  _FlipCard(
                    size: size,
                    faceUp: _up[i] || _matched[i],
                    matched: _matched[i],
                    art: _castleCards[_cards[i]],
                    onTap: () => _tap(i),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _FlipCard extends StatelessWidget {
  final double size;
  final bool faceUp;
  final bool matched;
  final _CardArt art;
  final VoidCallback onTap;

  const _FlipCard({
    required this.size,
    required this.faceUp,
    required this.matched,
    required this.art,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: faceUp ? 1 : 0),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOut,
          builder: (context, t, _) {
            final showFront = t > 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(pi * t),
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _front(),
                    )
                  : _back(),
            );
          },
        ),
      ),
    );
  }

  Widget _back() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB57BFF), Color(0xFF7D5BDB)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: Text('\u{1F3F0}', style: TextStyle(fontSize: size * 0.42)),
      );

  Widget _front() => Container(
        decoration: BoxDecoration(
          color: matched ? const Color(0xFFE3F6E5) : art.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: matched ? const Color(0xFF66BB6A) : Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: BuddyWidget(
                      kind: art.kind, size: 100, animated: false),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(art.label,
                  style: TextStyle(
                      fontSize: (size * 0.16).clamp(10.0, 16.0).toDouble(),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2B2350))),
            ),
          ],
        ),
      );
}

/// Harmless drifting sparkles (decoration only) for level 5.
class _SoftSparkles extends StatefulWidget {
  const _SoftSparkles();

  @override
  State<_SoftSparkles> createState() => _SoftSparklesState();
}

class _SoftSparklesState extends State<_SoftSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(painter: _SparklePainter(_c.value)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double t;
  _SparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final x = ((i * 0.173 + 0.05) % 1.0) * size.width;
      final y = (1.0 - ((t + i * 0.097) % 1.0)) * size.height;
      canvas.drawCircle(Offset(x, y), 3.5,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
