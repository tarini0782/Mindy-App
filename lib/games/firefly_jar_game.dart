import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// FIREFLY JAR (Twinkle). World 7, a second regulation/calming activity
/// alongside Breathing Garden and Calm Maze -- but ACTIVE rather than a
/// passive walk: the child taps softly glowing fireflies to gently guide
/// them into a jar, at their own pace, while a large ring behind the jar
/// breathes in and out (purely visual, matching a slow breath).
///
/// Calm-pool design rules, same family as Treasure Journey and Breathing
/// Garden: no timer, no hazards, nothing ever disappears or "escapes" --
/// a lit firefly waits for the child for as long as it takes. A tap
/// anywhere else is just a soft ripple, never a mistake.
///
///   Level  fireflies to catch  lit at once  pause between new fireflies
///   1      5                  1            slow (child sets the pace)
///   2      6                  1            slow
///   3      7                  2            medium
///   4      8                  2            medium
///   5      9                  3            a little quicker, still gentle
class FireflyParams {
  final int toCatch;
  final int maxLit;
  final int spawnPauseMs;
  const FireflyParams(this.toCatch, this.maxLit, this.spawnPauseMs);

  static FireflyParams forLevel(int level) => FireflyParams(
        pickByLevel(level, 5, 6, 7, 8, 9),
        pickByLevel(level, 1, 1, 2, 2, 3),
        pickByLevel(level, 2200, 1900, 1600, 1300, 1000),
      );
}

class _Firefly {
  final int id;
  final double dx; // 0..1 across the play area
  final double dy; // 0..1 down the play area
  const _Firefly(this.id, this.dx, this.dy);
}

class FireflyJarGame extends StatefulWidget {
  final GameSessionController controller;
  const FireflyJarGame({super.key, required this.controller});

  @override
  State<FireflyJarGame> createState() => _FireflyJarGameState();
}

class _FireflyJarGameState extends State<FireflyJarGame>
    with SingleTickerProviderStateMixin {
  late final FireflyParams _p;
  final _rand = Random();
  final List<_Firefly> _lit = [];
  int _nextId = 0;
  int _caught = 0;
  Timer? _spawnTimer;
  late final AnimationController _breath;
  DateTime _since = DateTime.now();

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = FireflyParams.forLevel(_c.level);
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _c.setUnits(0, _p.toCatch);
    _c.hintText = () => 'Tap a glowing firefly when you are ready.';
    _c.onDemonstrate = () {};
    _c.onEasier = () {};
    _c.react(CharacterState.calm, CharacterLines.start(CharacterId.twinkle),
        ms: 3000);
    // Populate the first fireflies directly (NOT via _spawnOne/setState --
    // initState runs during the parent's build phase, so calling setState
    // here would throw; mutating the field directly is safe and shows up
    // in this widget's own first build).
    for (var i = 0; i < _p.maxLit && _lit.length < _p.toCatch; i++) {
      _lit.add(_Firefly(_nextId++, _spacedCoord(), _spacedCoord()));
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  double _spacedCoord() => 0.12 + _rand.nextDouble() * 0.76;

  void _spawnOne() {
    if (!mounted || _caught + _lit.length >= _p.toCatch) return;
    setState(() {
      _lit.add(_Firefly(_nextId++, _spacedCoord(), _spacedCoord()));
    });
  }

  void _catch(_Firefly f) {
    if (_c.completed) return;
    _c.recordTouch();
    final ms = DateTime.now().difference(_since).inMilliseconds;
    _c.recordResponse(ms);
    _since = DateTime.now();
    _c.recordSuccess();
    GameAudio.success();
    setState(() {
      _lit.removeWhere((x) => x.id == f.id);
      _caught++;
      _c.setUnits(_caught, _p.toCatch);
    });
    if (_caught >= _p.toCatch) {
      _c.finishLine = CharacterLines.completion(CharacterId.twinkle);
      _c.complete();
      return;
    }
    _c.react(CharacterState.happy, 'One more in the jar!', ms: 900);
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _p.spawnPauseMs), _spawnOne);
  }

  void _missTap() {
    if (_c.completed) return;
    _c.recordTouch(); // a quiet tap on empty sky. Never a mistake.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('\u{1FA99} ', style: TextStyle(fontSize: 18)),
            Text('$_caught of ${_p.toCatch} fireflies',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF151A3D), Color(0xFF2A1F54)],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _missTap(),
                    child: Stack(children: [
                      // Decorative, fixed, non-interactive little stars.
                      for (final s in _kStars)
                        Positioned(
                          left: s.dx * box.maxWidth,
                          top: s.dy * box.maxHeight,
                          child: const Icon(Icons.star_rounded,
                              size: 7, color: Colors.white38),
                        ),
                      // The slow breathing ring, purely visual.
                      Center(
                        child: AnimatedBuilder(
                          animation: _breath,
                          builder: (context, _) {
                            final scale = 0.85 + _breath.value * 0.3;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      width: 2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      for (final f in _lit)
                        Positioned(
                          left: f.dx * box.maxWidth - 28,
                          top: f.dy * box.maxHeight - 28,
                          child: GestureDetector(
                            onTap: () => _catch(f),
                            child: const _GlowingFirefly(),
                          ),
                        ),
                      Positioned(
                        bottom: 10,
                        right: 14,
                        child: Opacity(
                          opacity: 0.9,
                          child: Text('\u{1FEE9}',
                              style: TextStyle(
                                  fontSize: 40 + (_caught / _p.toCatch) * 10)),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

const _kStars = [
  Offset(0.08, 0.1), Offset(0.85, 0.08), Offset(0.3, 0.05),
  Offset(0.65, 0.18), Offset(0.92, 0.4), Offset(0.06, 0.45),
  Offset(0.5, 0.06), Offset(0.15, 0.7), Offset(0.78, 0.65),
];

/// A soft pulsing firefly, built from plain widgets (no image assets).
class _GlowingFirefly extends StatefulWidget {
  const _GlowingFirefly();
  @override
  State<_GlowingFirefly> createState() => _GlowingFireflyState();
}

class _GlowingFireflyState extends State<_GlowingFirefly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final glow = 0.6 + _c.value * 0.4;
        return SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Container(
              width: 24 + _c.value * 6,
              height: 24 + _c.value * 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE27A).withValues(alpha: glow),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFFE27A).withValues(alpha: glow * 0.7),
                      blurRadius: 22,
                      spreadRadius: 6),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
