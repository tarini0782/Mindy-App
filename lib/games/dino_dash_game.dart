import 'dart:math';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// DINO DASH ADVENTURE (Pip). The little dino runs. Tap to jump over
/// cactuses. Careful: flying birds are high up, so DON'T jump for a bird,
/// stay low and let it pass. Each obstacle is judged once, when it reaches
/// the dino.
///
///   Level  obstacles  speed px/s  gap (s)  birds
///   1      8          140         2.2      no
///   2      10         160         2.0      no
///   3      12         180         1.8      yes
///   4      14         205         1.5      yes
///   5      16         230         1.3      yes
///
/// Logged: success (cleared), mistake (hit one; gentle, it pops away),
/// touch (jump taps), response (tap time before the obstacle arrives).
enum Obstacle { cactus, bird }

class DashParams {
  final int obstacles;
  final double speed;
  final double gapSec;
  final bool birds;
  const DashParams(this.obstacles, this.speed, this.gapSec, this.birds);

  static DashParams forLevel(int level) => DashParams(
        pickByLevel(level, 8, 10, 12, 14, 16),
        pickByLevel(level, 140.0, 160.0, 180.0, 205.0, 230.0),
        pickByLevel(level, 2.2, 2.0, 1.8, 1.5, 1.3),
        level >= 3,
      );
}

class DashLogic {
  static const double jumpSec = 0.75;
  static const double peak = 90;

  /// Height above the ground [t] seconds after a jump started.
  static double height(double t) =>
      (t < 0 || t > jumpSec) ? 0 : sin(pi * t / jumpSec) * peak;

  /// Cactus: you must be in the air. Bird (flies high): you must be low.
  static bool hits(Obstacle o, double h) =>
      o == Obstacle.cactus ? h < 38 : h > 12;

  static List<Obstacle> sequence(int n, bool birds, Random r) => [
        for (var i = 0; i < n; i++)
          (birds && i >= 2 && r.nextInt(3) == 0) ? Obstacle.bird : Obstacle.cactus
      ];
}

class _Ob {
  double x;
  final Obstacle kind;
  bool judged = false;
  bool hit = false;
  _Ob(this.x, this.kind);
}

class DinoDashGame extends StatefulWidget {
  final GameSessionController controller;
  const DinoDashGame({super.key, required this.controller});

  @override
  State<DinoDashGame> createState() => _DinoDashGameState();
}

class _DinoDashGameState extends State<DinoDashGame>
    with SingleTickerProviderStateMixin<DinoDashGame>, GameLoop<DinoDashGame> {
  late final DashParams _p;
  late final List<Obstacle> _plan;
  final _rand = Random(79);
  final List<_Ob> _obs = [];
  int _spawned = 0;
  int _judged = 0;
  double _spawnIn = 1.2;
  double _jumpT = -1; // <0 = on the ground
  double _speedScale = 1;
  double _width = 360;

  static const double _dinoX = 70;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = DashParams.forLevel(_c.level);
    _plan = DashLogic.sequence(_p.obstacles, _p.birds, _rand);
    _c.setUnits(0, _p.obstacles);
    _c.hintText = () => 'Jump for cactuses. Stay low for birds.';
    _c.onDemonstrate = () {};
    _c.onEasier = () => _speedScale = max(0.6, _speedScale * 0.85);
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.pip),
        ms: 3000);
    startLoop();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    super.dispose();
  }

  void _jump() {
    if (_c.completed || _jumpT >= 0) return;
    _jumpT = 0;
    _c.recordTouch();
    GameAudio.tap();
  }

  double get _speed => _p.speed * _c.speed * _speedScale;

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    if (_jumpT >= 0) {
      _jumpT += dt;
      if (_jumpT > DashLogic.jumpSec) _jumpT = -1;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0 && _spawned < _p.obstacles) {
      _obs.add(_Ob(_width + 40, _plan[_spawned]));
      _spawned++;
      _spawnIn = _p.gapSec / _speedScale;
    }
    final h = DashLogic.height(_jumpT);
    for (final o in _obs) {
      o.x -= _speed * dt;
      if (!o.judged && o.x <= _dinoX + 20) {
        o.judged = true;
        _judged++;
        if (DashLogic.hits(o.kind, h)) {
          o.hit = true;
          _c.recordMistake();
          _c.react(CharacterState.encouraging, 'Bonk! Try the next one.',
              ms: 1400);
        } else {
          _c.recordSuccess();
          GameAudio.success();
        }
        _c.setUnits(_judged, _p.obstacles);
      }
    }
    _obs.removeWhere((o) => o.x < -60);
    if (_judged >= _p.obstacles) {
      _c.finishLine = CharacterLines.completion(CharacterId.pip);
      _c.complete();
      stopLoop();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value);
    return LayoutBuilder(builder: (context, box) {
      _width = box.maxWidth;
      final groundY = box.maxHeight * 0.72;
      final h = DashLogic.height(_jumpT);
      _Ob? next;
      for (final o in _obs) {
        if (!o.judged) {
          next = o;
          break;
        }
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _jump(),
        child: Stack(children: [
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: RuleChip(
                color: const Color(0xFF558B2F),
                text: _p.birds ? 'Jump cactus. Stay low for birds' : 'Tap to jump the cactus',
                icons: const [Icon(Icons.touch_app_rounded, color: Colors.white)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: groundY + 30,
            child: Container(height: 8, color: const Color(0xFF8D6E63)),
          ),
          for (final o in _obs)
            Positioned(
              left: o.x - 24,
              top: o.kind == Obstacle.cactus ? groundY - 8 : groundY - 70,
              child: Opacity(
                opacity: o.hit ? 0.25 : 1,
                // the dino runs RIGHT, obstacles come from the right and fly LEFT
                child: o.kind == Obstacle.cactus
                    ? Sprite('cactus', width: 52, height: 62)
                    : Sprite('eagle_side', width: 62, height: 62, faceRight: false),
              ),
            ),
          if (cue && next != null)
            Positioned(
              left: next.x - 20,
              top: groundY - 74,
              child: Text(
                next.kind == Obstacle.cactus ? 'JUMP!' : 'STAY LOW',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF9A825),
                    fontSize: 18),
              ),
            ),
          Positioned(
            left: _dinoX - 28,
            top: groundY - 12 - h,
            child: const Sprite('dino_side', width: 64, height: 64),
          ),
        ]),
      );
    });
  }
}
