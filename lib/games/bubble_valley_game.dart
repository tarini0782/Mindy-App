import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';
import 'models/game_pace.dart';

/// WORLD 2 -- BUBBLE VALLEY (Bubbles the bunny). Tap / catch.
///
/// Magical bubbles float up; the child taps them so Bubbles can fill the
/// basket. Each bubble holds a little treat (star, flower, strawberry,
/// rainbow, unicorn). NOT a reaction game: slow movement, no timers shown,
/// nothing is lost when a bubble floats away. Reaction time is stored as a
/// secondary indicator only.
///
///   Level  size  speed  bubbles at once  catches  extras
///   1      big   very slow  2            6        none
///   2      a bit smaller, more bubbles   8
///   3      moderate movement             10
///   4      smaller targets               12       a few sleepy clouds
///   5      wavier movement, more targets 14       a few sleepy clouds
/// Everything level/pace change in Bubble Valley (testable).
class BubbleParams {
  final double radius;
  final double riseSpeed; // px per second
  final int maxActive;
  final double spawnEvery; // seconds
  final int target;
  final double cloudChance;
  final double sway;
  final double drift;
  const BubbleParams({
    required this.radius,
    required this.riseSpeed,
    required this.maxActive,
    required this.spawnEvery,
    required this.target,
    required this.cloudChance,
    required this.sway,
    required this.drift,
  });

  static BubbleParams forLevel(int level, GamePace pace) => BubbleParams(
        radius: pickByLevel(level, 50.0, 44.0, 38.0, 32.0, 28.0),
        riseSpeed: pickByLevel(level, 26.0, 34.0, 44.0, 52.0, 60.0) * pace.speed,
        maxActive: pickByLevel(level, 2, 3, 4, 5, 6),
        spawnEvery: pickByLevel(level, 2.4, 2.0, 1.7, 1.5, 1.3) * pace.timeScale,
        target: pickByLevel(level, 6, 8, 10, 12, 14),
        cloudChance: pickByLevel(level, 0.0, 0.0, 0.0, 0.12, 0.18),
        sway: pickByLevel(level, 6.0, 8.0, 12.0, 14.0, 26.0),
        drift: pickByLevel(level, 0.0, 0.0, 0.0, 0.0, 14.0),
      );
}

class BubbleValleyGame extends StatefulWidget {
  final GameSessionController controller;
  const BubbleValleyGame({super.key, required this.controller});

  @override
  State<BubbleValleyGame> createState() => _BubbleValleyGameState();
}

class _Bubble {
  final int id;
  final double baseX;
  double y;
  final double phase;
  final bool cloud;
  final String icon;
  final double born; // game clock at spawn
  final double drift; // sideways drift speed (level 5)
  double? poppedAt;
  _Bubble(this.id, this.baseX, this.y, this.phase, this.cloud, this.icon,
      this.born, this.drift);
}

class _BubbleValleyGameState extends State<BubbleValleyGame>
    with
        SingleTickerProviderStateMixin<BubbleValleyGame>,
        GameLoop<BubbleValleyGame> {
  static const _icons = [
    '\u2B50', // star
    '\u{1F338}', // flower
    '\u{1F353}', // strawberry
    '\u{1F308}', // rainbow
    '\u{1F984}', // unicorn
  ];

  late final double _radius;
  late final double _speed;
  late final int _maxActive;
  late final double _spawnEvery;
  late final int _target;
  late final double _cloudChance;
  late final double _sway;
  late final double _drift;

  final _rand = Random();
  final List<_Bubble> _bubbles = [];
  Size _size = const Size(360, 520);
  double _clock = 0;
  double _sinceSpawn = 99;
  int _nextId = 0;
  int _caught = 0;
  int _lastCheer = -1;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    final bp = BubbleParams.forLevel(c.level, c.pace);
    _radius = bp.radius;
    _speed = bp.riseSpeed;
    _maxActive = bp.maxActive;
    _spawnEvery = bp.spawnEvery;
    _target = bp.target;
    _cloudChance = bp.cloudChance;
    _sway = bp.sway;
    _drift = bp.drift;
    c.setUnits(0, _target);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.bubbles),
        ms: 3200);
    startLoop();
  }

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;
    _sinceSpawn += dt;

    for (final b in _bubbles) {
      if (b.poppedAt == null) b.y -= _speed * dt;
    }
    _bubbles.removeWhere((b) {
      if (b.poppedAt != null) return _clock - b.poppedAt! > 0.3;
      if (b.y < -_radius * 2) {
        // A bubble floated away: data only, no penalty or message.
        if (!b.cloud) c.recordMistake();
        return true;
      }
      return false;
    });

    final active = _bubbles.where((b) => b.poppedAt == null).length;
    if (active < _maxActive && _sinceSpawn >= _spawnEvery) {
      _sinceSpawn = 0;
      final w = _size.width;
      final x = _radius + 14 + _rand.nextDouble() * max(1.0, w - 2 * (_radius + 14));
      _bubbles.add(_Bubble(
        _nextId++,
        x,
        _size.height + _radius,
        _rand.nextDouble() * 6.28,
        _rand.nextDouble() < _cloudChance,
        _icons[_rand.nextInt(_icons.length)],
        _clock,
        _drift == 0 ? 0 : (_rand.nextBool() ? 1 : -1) * _drift * _rand.nextDouble(),
      ));
    }

    // Gentle safety net: a very long session ends happily instead of
    // dragging on (no timer is ever shown).
    if (_clock > 240 && !c.completed) {
      _finish();
      return;
    }
    setState(() {});
  }

  void _finish() {
    final c = widget.controller;
    c.finishLine = CharacterLines.completion(CharacterId.bubbles);
    c.react(CharacterState.celebrating, CharacterLines.completion(CharacterId.bubbles),
        ms: 4000);
    c.complete();
    stopLoop();
    setState(() {});
  }

  void _tap(_Bubble b) {
    if (b.poppedAt != null) return;
    final c = widget.controller;
    if (b.cloud) {
      // A sleepy cloud: harmless, just a soft sound. Logged as a mistake
      // for the researchers only.
      c.recordMistake();
      GameAudio.tap();
      c.react(CharacterState.encouraging, CharacterLines.encourage(CharacterId.bubbles),
          ms: 1800);
      return;
    }
    b.poppedAt = _clock;
    _caught++;
    c.recordSuccess();
    c.recordResponse(((_clock - b.born) * 1000).round());
    c.setUnits(_caught, _target);
    c.burst(Offset(b.baseX, b.y), b.icon);
    GameAudio.success();
    if (_caught != _lastCheer) {
      _lastCheer = _caught;
      c.react(
        CharacterState.excited,
        CharacterLines.bubblesCatch[_caught % CharacterLines.bubblesCatch.length],
        ms: 1600,
      );
    }
    if (_caught >= _target) _finish();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return Stack(
        children: [
          // a soft valley floor
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFB9F0D2).withValues(alpha: 0.0),
                    const Color(0xFFB9F0D2).withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          for (final b in _bubbles) _bubbleWidget(b),
        ],
      );
    });
  }

  Widget _bubbleWidget(_Bubble b) {
    final r = _radius;
    final age = _clock - b.born;
    final x = b.baseX + sin(age * 1.3 + b.phase) * _sway + b.drift * sin(age * 0.6);
    final popping = b.poppedAt != null;
    final t = popping ? ((_clock - b.poppedAt!) / 0.3).clamp(0.0, 1.0).toDouble() : 0.0;
    return Positioned(
      left: x - r,
      top: b.y - r,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(b),
        child: Opacity(
          opacity: popping ? 1 - t : 1.0,
          child: Transform.scale(
            scale: popping ? 1 + 0.5 * t : 1.0,
            child: Container(
              width: r * 2,
              height: r * 2,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: b.cloud
                    ? const RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [Color(0xFFEDEBF6), Color(0xFFBDB9D6)])
                    : const RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        colors: [Color(0xCCFFFFFF), Color(0x887FD3FF)]),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x2200A0D0), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Text(b.cloud ? '\u2601\uFE0F' : b.icon,
                  style: TextStyle(fontSize: r * 0.95, height: 1.0)),
            ),
          ),
        ),
      ),
    );
  }
}
