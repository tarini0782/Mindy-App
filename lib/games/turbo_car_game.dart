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

/// TURBO CAR ADVENTURE (Pip). Three lanes. Rows of rocks and cones come down
/// the road. Steer left or right (tap the left or right half of the screen,
/// or the arrow buttons) so the car's lane is clear when the row arrives.
/// Every row always has at least one clear lane.
///
///   Level  rows  speed (rows/s)  blocked lanes per row (max)  star bonus
///   1      10    0.35            1                            yes
///   2      12    0.42            1                            yes
///   3      14    0.50            2                            yes
///   4      16    0.58            2                            no
///   5      18    0.66            2                            no
///
/// Logged: success (row passed clear), mistake (bumped a rock; gentle,
/// the rock pops away), touch (every steering move), rule: none.
class CarParams {
  final int rows;
  final double rowsPerSec;
  final int maxBlocked;
  final bool bonusStars;
  const CarParams(this.rows, this.rowsPerSec, this.maxBlocked, this.bonusStars);

  static CarParams forLevel(int level) => CarParams(
        pickByLevel(level, 10, 12, 14, 16, 18),
        pickByLevel(level, 0.35, 0.42, 0.50, 0.58, 0.66),
        pickByLevel(level, 1, 1, 2, 2, 2),
        level <= 3,
      );
}

class LaneLogic {
  /// Lanes (0..2) blocked in one row. Never all three.
  static Set<int> blockedLanes(Random r, int maxBlocked) {
    final n = 1 + (maxBlocked > 1 ? r.nextInt(maxBlocked) : 0);
    final lanes = [0, 1, 2]..shuffle(r);
    return lanes.take(min(n, 2)).toSet();
  }

  static bool collides(Set<int> blocked, int carLane) => blocked.contains(carLane);

  static int clampLane(int lane) => lane < 0 ? 0 : (lane > 2 ? 2 : lane);

  static List<int> clearLanes(Set<int> blocked) =>
      [for (var l = 0; l < 3; l++) if (!blocked.contains(l)) l];
}

class _Row {
  double y; // 0 = top of the road, 1 = the car's line
  final Set<int> blocked;
  final int? star; // lane with a bonus star or null
  bool judged = false;
  bool hit = false;
  _Row(this.y, this.blocked, this.star);
}

class TurboCarGame extends StatefulWidget {
  final GameSessionController controller;
  const TurboCarGame({super.key, required this.controller});

  @override
  State<TurboCarGame> createState() => _TurboCarGameState();
}

class _TurboCarGameState extends State<TurboCarGame>
    with SingleTickerProviderStateMixin<TurboCarGame>, GameLoop<TurboCarGame> {
  late final CarParams _p;
  final _rand = Random(71);
  final List<_Row> _rows = [];
  int _lane = 1;
  int _spawned = 0;
  int _judged = 0;
  double _spawnIn = 0.8;
  double _speedScale = 1;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = CarParams.forLevel(_c.level);
    _c.setUnits(0, _p.rows);
    _c.hintText = () => 'Move to a lane with no rocks.';
    _c.onDemonstrate = () {};
    _c.onEasier = () => _speedScale = max(0.6, _speedScale * 0.8);
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

  double get _rate => _p.rowsPerSec * _c.speed * _speedScale;

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    // A row needs ~1/ _rate seconds to cross the road.
    for (final r in _rows) {
      r.y += dt * _rate;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0 && _spawned < _p.rows) {
      final blocked = LaneLogic.blockedLanes(_rand, _p.maxBlocked);
      final clear = LaneLogic.clearLanes(blocked);
      final star = (_p.bonusStars && _rand.nextInt(3) == 0)
          ? clear[_rand.nextInt(clear.length)]
          : null;
      _rows.add(_Row(0, blocked, star));
      _spawned++;
      _spawnIn = 0.7 / _rate;
    }
    for (final r in _rows) {
      if (!r.judged && r.y >= 1.0) {
        r.judged = true;
        _judged++;
        if (LaneLogic.collides(r.blocked, _lane)) {
          r.hit = true;
          _c.recordMistake();
          GameAudio.tap();
          _c.react(CharacterState.encouraging, 'Bump! No worries. Keep going!',
              ms: 1400);
        } else {
          _c.recordSuccess(points: r.star == _lane ? 2 : 1);
          if (r.star == _lane) _c.burst(Offset(_laneX(_lane), 300), '⭐');
        }
        _c.setUnits(_judged, _p.rows);
      }
    }
    _rows.removeWhere((r) => r.judged && r.y > 1.25);
    if (_judged >= _p.rows) {
      _c.finishLine = CharacterLines.completion(CharacterId.pip);
      _c.complete();
      stopLoop();
      return;
    }
    setState(() {});
  }

  double _roadW = 300;
  double _laneX(int l) => _roadW * (0.2 + 0.3 * l);

  void _steer(int dir) {
    if (_c.completed) return;
    final next = LaneLogic.clampLane(_lane + dir);
    if (next != _lane) {
      _c.recordTouch();
      _lane = next;
      GameAudio.tap();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      _roadW = w;
      final carY = h * 0.80;
      final top = 10.0;
      double yOf(double f) => top + (carY - top) * f;
      // the next unjudged row, for the visual cue
      _Row? next;
      for (final r in _rows) {
        if (!r.judged) {
          next = r;
          break;
        }
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _steer(d.localPosition.dx < w / 2 ? -1 : 1),
        child: Stack(children: [
          Positioned.fill(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFF546E7A),
                    borderRadius: BorderRadius.circular(18))),
          ),
          for (var i = 1; i < 3; i++)
            Positioned(
              left: w * 0.05 + w * 0.3 * i - 2,
              top: 10,
              bottom: 10,
              child: Container(width: 4, color: Colors.white54),
            ),
          for (final r in _rows) ...[
            for (final l in r.blocked)
              Positioned(
                left: _laneX(l) - 28,
                top: yOf(r.y) - 28,
                child: Opacity(
                  opacity: r.hit ? 0.25 : 1,
                  child: const Sprite('rock', width: 54, height: 54),
                ),
              ),
            if (r.star != null && !r.judged)
              Positioned(
                left: _laneX(r.star!) - 20,
                top: yOf(r.y) - 22,
                child: const Sprite('star', width: 42, height: 42),
              ),
          ],
          if (cue && next != null)
            for (final l in LaneLogic.clearLanes(next.blocked))
              Positioned(
                left: _laneX(l) - 36,
                top: carY + 40,
                child: const Icon(Icons.keyboard_arrow_up_rounded,
                    color: Color(0xFFFFC107), size: 72),
              ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 140),
            left: _laneX(_lane) - 30,
            top: carY - 30,
            child: const Sprite('car_up', width: 66, height: 66), // bonnet points up, the way the car drives
          ),
          Positioned(
            left: 14,
            bottom: 6,
            child: _Arrow(icon: Icons.arrow_back_rounded, onTap: () => _steer(-1)),
          ),
          Positioned(
            right: 14,
            bottom: 6,
            child: _Arrow(icon: Icons.arrow_forward_rounded, onTap: () => _steer(1)),
          ),
        ]),
      );
    });
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Arrow({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
              color: Colors.white70, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: const Color(0xFF37474F)),
        ),
      );
}
