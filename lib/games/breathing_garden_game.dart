import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'base/phase_timeline.dart';
import 'models/game_difficulty.dart';
import 'widgets/scene_art.dart';

/// WORLD 1 -- MAGIC GARDEN (Twinkle). Breathing / regulation.
///
/// A flower grows while the child breathes in, rests while they hold, and
/// shrinks while they breathe out; every finished breath makes another
/// flower bloom in the garden and the rainbow glow a little brighter.
///
/// No countdown, no scoring, no failure. Levels change how rich the world
/// is and how long the calm sequence lasts:
///   L1  slow, plain sky, 3 breaths        L4  longer breaths, 5 breaths,
///   L2  a few stars                           butterflies, sparkles to tap
///   L3  more movement, 4 breaths          L5  longest sequence, 6 breaths
/// Everything level/pace change in the Breathing Garden (testable).
class GardenParams {
  final double inhaleSec, holdSec, exhaleSec; // before pace scaling
  final int breaths;
  final int stars;
  final int particles;
  final int butterflies;
  final int clouds;
  final bool sparkleTaps;
  const GardenParams({
    required this.inhaleSec,
    required this.holdSec,
    required this.exhaleSec,
    required this.breaths,
    required this.stars,
    required this.particles,
    required this.butterflies,
    required this.clouds,
    required this.sparkleTaps,
  });

  /// How much richer / more interactive the world is (for tests).
  int get richness => stars + particles + butterflies + clouds + (sparkleTaps ? 5 : 0);

  static GardenParams forLevel(int level) => GardenParams(
        inhaleSec: pickByLevel(level, 4.0, 4.0, 4.0, 4.5, 4.5),
        holdSec: pickByLevel(level, 1.0, 1.0, 1.5, 2.0, 2.0),
        exhaleSec: pickByLevel(level, 5.0, 5.0, 5.0, 6.0, 6.0),
        breaths: pickByLevel(level, 3, 3, 4, 5, 6),
        stars: pickByLevel(level, 0, 5, 8, 12, 16),
        particles: pickByLevel(level, 0, 0, 6, 10, 14),
        butterflies: pickByLevel(level, 0, 0, 2, 3, 4),
        clouds: pickByLevel(level, 1, 2, 2, 3, 3),
        sparkleTaps: level >= 4,
      );
}

class BreathingGardenGame extends StatefulWidget {
  final GameSessionController controller;
  const BreathingGardenGame({super.key, required this.controller});

  @override
  State<BreathingGardenGame> createState() => _BreathingGardenGameState();
}

class _BreathingGardenGameState extends State<BreathingGardenGame>
    with
        SingleTickerProviderStateMixin<BreathingGardenGame>,
        GameLoop<BreathingGardenGame> {
  static const int _in = 0, _hold = 1, _out = 2, _rest = 3;

  late final PhaseTimeline _timeline;
  late final int _totalBreaths;
  late final int _stars;
  late final int _butterflies;
  late final int _particles;
  late final bool _sparkles;
  int _breaths = 0;
  double _clock = 0;
  Size _size = const Size(360, 520);

  Offset? _sparkle;
  double _sparkleLeft = 0;
  final _rand = Random(11);

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    final s = c.timeScale;
    final gp = GardenParams.forLevel(c.level);
    final inSec = gp.inhaleSec * s;
    final holdSec = gp.holdSec * s;
    final outSec = gp.exhaleSec * s;
    _timeline = PhaseTimeline([
      Phase('Breathe in', inSec),
      Phase('Hold', holdSec),
      Phase('Breathe out', outSec),
      Phase('Rest', 1.6 * s),
    ]);
    _totalBreaths = gp.breaths;
    _stars = gp.stars;
    _particles = gp.particles;
    _butterflies = gp.butterflies;
    _sparkles = gp.sparkleTaps;
    c.totalUnits = _totalBreaths;
    c.setUnits(0, _totalBreaths);
    c.react(CharacterState.calm, CharacterLines.start(CharacterId.twinkle),
        ms: 3200);
    startLoop();
  }

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;
    if (_sparkleLeft > 0) {
      _sparkleLeft -= dt;
      if (_sparkleLeft <= 0) _sparkle = null;
    }

    if (_timeline.tick(dt)) {
      switch (_timeline.index) {
        case _in:
          // A full breath just finished (wrapped back to "in").
          _breaths++;
          c.setUnits(_breaths, _totalBreaths);
          GameAudio.success();
          if (_breaths >= _totalBreaths) {
            c.finishLine = CharacterLines.completion(CharacterId.twinkle);
            c.complete();
            stopLoop();
            setState(() {});
            return;
          }
          c.react(CharacterState.calm, CharacterLines.breatheIn.first,
              ms: (_timeline.current.seconds * 1000).round());
          break;
        case _hold:
          c.react(CharacterState.calm, CharacterLines.hold,
              ms: (_timeline.current.seconds * 1000).round());
          break;
        case _out:
          c.react(CharacterState.calm, CharacterLines.breatheOut,
              ms: (_timeline.current.seconds * 1000).round());
          break;
        case _rest:
          c.react(CharacterState.happy, CharacterLines.breathRest, ms: 1600);
          if (_sparkles) {
            _sparkle = Offset(
              _size.width * (0.18 + 0.64 * _rand.nextDouble()),
              _size.height * (0.12 + 0.2 * _rand.nextDouble()),
            );
            _sparkleLeft = 4.0;
          }
          break;
      }
    }
    setState(() {});
  }

  /// 0.35 (small) .. 1.0 (full) depending on where the breath is.
  double get _scale {
    final f = _timeline.fraction;
    switch (_timeline.index) {
      case _in:
        return 0.35 + 0.65 * Curves.easeInOut.transform(f);
      case _hold:
        return 1.0;
      case _out:
        return 1.0 - 0.65 * Curves.easeInOut.transform(f);
      default:
        return 0.35;
    }
  }

  void _tapSparkle() {
    final p = _sparkle;
    if (p == null) return;
    widget.controller.recordTouch();
    widget.controller.burst(p, '\u2728');
    GameAudio.tap();
    setState(() {
      _sparkle = null;
      _sparkleLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GardenPainter(
                clock: _clock,
                scale: _scale,
                breaths: _breaths,
                total: _totalBreaths,
                stars: _stars,
                particles: _particles,
                butterflies: _butterflies,
                clouds: GardenParams.forLevel(widget.controller.level).clouds,
              ),
            ),
          ),
          if (_sparkle != null)
            Positioned(
              left: _sparkle!.dx - 34,
              top: _sparkle!.dy - 34,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _tapSparkle(),
                child: const SizedBox(
                  width: 68,
                  height: 68,
                  child: Center(
                      child: Text('\u2728', style: TextStyle(fontSize: 44))),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _GardenPainter extends CustomPainter {
  final double clock;
  final double scale;
  final int breaths;
  final int total;
  final int stars;
  final int particles;
  final int butterflies;
  final int clouds;

  _GardenPainter({
    required this.clock,
    required this.scale,
    required this.breaths,
    required this.total,
    required this.stars,
    required this.particles,
    required this.butterflies,
    required this.clouds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final progress = total == 0 ? 0.0 : breaths / total;

    // rainbow gets brighter with every breath
    paintRainbow(canvas, Offset(w / 2, h * 0.62), min(w, h) * 0.62,
        0.20 + 0.65 * progress);

    // gentle clouds
    for (var i = 0; i < clouds; i++) {
      final x = ((clock * (6 + i * 3) + i * w * 0.4) % (w * 1.4)) - w * 0.2;
      paintCloud(canvas, Offset(x, h * (0.08 + 0.07 * i)), 80 + i * 18);
    }

    // twinkling stars
    final sr = Random(5);
    for (var i = 0; i < stars; i++) {
      final p = Offset(sr.nextDouble() * w, sr.nextDouble() * h * 0.38);
      final tw = 0.5 + 0.5 * sin(clock * 1.6 + i);
      paintStar(canvas, p, 4 + 4 * tw, Colors.white.withValues(alpha: 0.55 + 0.4 * tw));
    }

    // rising sparkles
    for (var i = 0; i < particles; i++) {
      final fx = (i * 0.137 + 0.08) % 1.0;
      final fy = 1.0 - ((clock * 0.05 + i * 0.173) % 1.0);
      canvas.drawCircle(Offset(fx * w, fy * h * 0.8), 3,
          Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: 0.8));
    }

    // ground
    final ground = Path()
      ..moveTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.5, h * 0.76, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF9ED98B));

    // one small flower blooms per finished breath
    for (var i = 0; i < breaths && i < total; i++) {
      final x = w * (0.12 + 0.76 * (total == 1 ? 0.5 : i / (total - 1)));
      paintFlower(canvas, Offset(x, h * 0.92), h * 0.16,
          _GardenPainterColors.petal(i), 1.0, petals: 6);
    }

    // the big breathing flower
    final fh = min(w, h) * 0.78;
    paintFlower(canvas, Offset(w / 2, h * 0.86), fh * (0.45 + 0.30 * scale),
        const Color(0xFFFF8AD0), scale,
        petals: 9);

    // butterflies
    for (var i = 0; i < butterflies; i++) {
      final a = clock * (0.5 + i * 0.12) + i * 1.7;
      final p = Offset(w * (0.5 + 0.38 * cos(a)), h * (0.42 + 0.14 * sin(a * 1.3 + i)));
      paintButterfly(canvas, p, 26, _GardenPainterColors.petal(i + 2),
          sin(clock * 9 + i));
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter old) => true;
}

class _GardenPainterColors {
  static const _c = [
    Color(0xFFFF8AD0),
    Color(0xFFFFB86B),
    Color(0xFFC79BFF),
    Color(0xFF6FC3FF),
    Color(0xFFFF6F91),
    Color(0xFFFFD166),
  ];
  static Color petal(int i) => _c[i % _c.length];
}
