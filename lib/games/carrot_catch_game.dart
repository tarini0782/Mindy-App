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

/// CARROT CATCH (Bubbles the bunny). Slide the basket left and right with a
/// finger (drag, or tap where you want it). Catch the yummy things that fall;
/// let the rocks drop. A continuous-movement game: no tapping on targets.
///
///   Level  to catch  fall speed  on screen  rocks
///   1      6         110         1          0%
///   2      8         130         2          15%
///   3      10        150         2          25%
///   4      12        175         3          30%
///   5      14        200         3          35%
///
/// Logged: success (good item caught), mistake (rock caught = commission),
/// omission (good item hit the ground), response time (spawn -> caught).
class CarrotParams {
  final int toCatch;
  final double speed;
  final int maxItems;
  final double rockChance;
  const CarrotParams(this.toCatch, this.speed, this.maxItems, this.rockChance);

  static CarrotParams forLevel(int level) => CarrotParams(
        pickByLevel(level, 6, 8, 10, 12, 14),
        pickByLevel(level, 110.0, 130.0, 150.0, 175.0, 200.0),
        pickByLevel(level, 1, 2, 2, 3, 3),
        pickByLevel(level, 0.0, 0.15, 0.25, 0.30, 0.35),
      );
}

class CarrotLogic {
  /// True when an item at [itemX] is inside a basket centred at [basketX].
  static bool caught(double itemX, double basketX, double basketWidth) =>
      (itemX - basketX).abs() <= basketWidth / 2 + 8;

  /// The first spawn is never a rock and at least one good item is always
  /// falling, so the game cannot stall.
  static bool nextIsRock(Random r, double chance, {required bool needGood}) =>
      !needGood && r.nextDouble() < chance;
}

class _Faller {
  double x, y;
  final bool rock;
  final String emoji;
  double age = 0;
  _Faller(this.x, this.y, this.rock, this.emoji);
}

const _kGood = ['carrot', 'apple', 'strawberry', 'orange'];

class CarrotCatchGame extends StatefulWidget {
  final GameSessionController controller;
  const CarrotCatchGame({super.key, required this.controller});

  @override
  State<CarrotCatchGame> createState() => _CarrotCatchGameState();
}

class _CarrotCatchGameState extends State<CarrotCatchGame>
    with
        SingleTickerProviderStateMixin<CarrotCatchGame>,
        GameLoop<CarrotCatchGame> {
  late final CarrotParams _p;
  final _rand = Random(17);
  final List<_Faller> _items = [];
  Size _size = const Size(360, 520);
  double _basketX = 180;
  double _targetX = 180;
  double _spawnIn = 0.5;
  double _speedScale = 1;
  int _maxItems = 1;
  int _caught = 0;
  double _clock = 0;
  double _demoUntil = 0;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = CarrotParams.forLevel(_c.level);
    _maxItems = _p.maxItems;
    _c.setUnits(0, _p.toCatch);
    _c.hintText = () => 'Slide the basket under the yummy food.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _speedScale = max(0.6, _speedScale * 0.8);
      _maxItems = max(1, _maxItems - 1);
    };
    _c.onHarder = () {
      _speedScale = min(1.5, _speedScale * 1.15);
      _maxItems = min(4, _maxItems + 1);
    };
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.bubbles),
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

  void _spawn() {
    final needGood = !_items.any((i) => !i.rock);
    final rock = CarrotLogic.nextIsRock(_rand, _p.rockChance, needGood: needGood);
    final k = _size.width / 360.0;
    final x = 30 * k + _rand.nextDouble() * (_size.width - 60 * k);
    _items.add(_Faller(x, -30, rock,
        rock ? 'rock' : _kGood[_rand.nextInt(_kGood.length)]));
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _clock += dt;
    // the basket glides to where the finger last was
    _basketX += (_targetX - _basketX) * min(1.0, dt * 12);
    _spawnIn -= dt;
    if (_spawnIn <= 0 && _items.length < _maxItems) {
      _spawn();
      _spawnIn = 0.9 + _rand.nextDouble() * 0.8;
    }
    final k = _size.width / 360.0;
    final basketTop = _size.height - 96 * k;
    final basketW = 96 * k;
    final done = <_Faller>[];
    for (final it in _items) {
      it.y += _p.speed * _c.speed * _speedScale * k * dt;
      it.age += dt;
      if (it.y >= basketTop && it.y <= basketTop + 40 * k &&
          CarrotLogic.caught(it.x, _basketX, basketW)) {
        done.add(it);
        _onCaught(it);
      } else if (it.y > _size.height + 20) {
        done.add(it);
        if (!it.rock) _c.recordTagged('omission');
      }
    }
    _items.removeWhere(done.contains);
    if (!_c.completed) setState(() {});
  }

  void _onCaught(_Faller it) {
    _c.recordTouch();
    if (it.rock) {
      _c.recordMistake();
      GameAudio.tap();
      _c.react(CharacterState.encouraging, 'Oops, a rock! Let it drop.', ms: 1500);
      return;
    }
    _c.recordResponse((it.age * 1000).round());
    _c.recordSuccess();
    GameAudio.success();
    _c.burst(Offset(it.x, it.y), '\u{2B50}');
    _caught++;
    _c.setUnits(_caught, _p.toCatch);
    if (_caught >= _p.toCatch) {
      _c.finishLine = CharacterLines.completion(CharacterId.bubbles);
      _c.complete();
      stopLoop();
    }
  }

  void _moveTo(double x) => _targetX = x.clamp(30.0, max(30.0, _size.width - 30.0));

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final k = _size.width / 360.0;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _moveTo(d.localPosition.dx),
        onPanUpdate: (d) => _moveTo(d.localPosition.dx),
        child: Stack(children: [
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: RuleChip(
                color: const Color(0xFFEF6C00),
                text: 'Catch the food, not the rocks',
                icons: [Sprite('carrot', width: 22, height: 22)],
              ),
            ),
          ),
          for (final it in _items)
            Positioned(
              left: it.x - 26 * k,
              top: it.y - 26 * k,
              child: CueRing(
                show: cue && !it.rock,
                size: 52 * k,
                child: Sprite(it.emoji,
                    width: 46 * k, height: 46 * k, angle: it.age * 2.0 * (it.rock ? 0.4 : 0.3)),
              ),
            ),
          Positioned(
            left: _basketX - 48 * k,
            top: _size.height - 96 * k,
            child: SizedBox(
              width: 96 * k,
              height: 96 * k,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                    left: 24 * k, top: 0,
                    child: Sprite('host_bubbles', width: 48 * k, height: 48 * k)),
                Positioned(
                    left: 0, top: 30 * k,
                    child: Sprite('basket', width: 96 * k, height: 66 * k)),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}
