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

/// CLOUD BOUNCE (Kara the unicorn). Kara bounces up from cloud to cloud.
/// Slide a finger left and right to steer. Collect stars, hit springs for a
/// super jump, and steer around grumpy storm clouds (obstacles). Falling off
/// the bottom is never "game over": a friendly bubble bounces Kara back up.
///
///   Level  stars  cloud gap  storm chance  cloud width
///   1      8      70         0%            110
///   2      10     80         12%           100
///   3      12     88         20%           92
///   4      14     96         28%           84
///   5      16     104        35%           78
///
/// All distances are in a 360-wide design space (scaled to the screen).
/// Logged: success (star), mistake (storm hit or a fall), omission (a star
/// scrolled away), response time (star appears -> collected).
class BounceParams {
  final int stars;
  final double gap;
  final double stormChance;
  final double cloudWidth;
  const BounceParams(this.stars, this.gap, this.stormChance, this.cloudWidth);

  static BounceParams forLevel(int level) => BounceParams(
        pickByLevel(level, 8, 10, 12, 14, 16),
        pickByLevel(level, 70.0, 80.0, 88.0, 96.0, 104.0),
        pickByLevel(level, 0.0, 0.12, 0.20, 0.28, 0.35),
        pickByLevel(level, 110.0, 100.0, 92.0, 84.0, 78.0),
      );
}

class BounceLogic {
  static const double jumpV = -520; // design px / s (up is negative)
  static const double springV = -820;
  static const double gravity = 1100;

  /// Highest a normal jump can climb. Cloud gaps must stay below this or
  /// the level would be impossible.
  static double get jumpHeight => (jumpV * jumpV) / (2 * gravity);

  static bool gapReachable(double gap) => gap < jumpHeight - 10;

  /// True when a falling player's feet cross a cloud's top this frame.
  static bool lands({
    required double prevFoot,
    required double foot,
    required double cloudY,
    required double px,
    required double cloudX,
    required double cloudW,
    required double vy,
  }) =>
      vy > 0 &&
      prevFoot <= cloudY &&
      foot >= cloudY &&
      (px - cloudX).abs() <= cloudW / 2 + 12;
}

class _Cloud {
  double x, y, w;
  bool spring;
  _Cloud(this.x, this.y, this.w, this.spring);
}

class _Item {
  double x, y;
  final bool storm;
  double age = 0;
  _Item(this.x, this.y, this.storm);
}

class CloudBounceGame extends StatefulWidget {
  final GameSessionController controller;
  const CloudBounceGame({super.key, required this.controller});

  @override
  State<CloudBounceGame> createState() => _CloudBounceGameState();
}

class _CloudBounceGameState extends State<CloudBounceGame>
    with
        SingleTickerProviderStateMixin<CloudBounceGame>,
        GameLoop<CloudBounceGame> {
  late final BounceParams _p;
  final _rand = Random(97);
  final List<_Cloud> _clouds = [];
  final List<_Item> _items = [];
  static const double _w = 360;
  double _h = 520;
  double _k = 1;
  double _px = 180, _py = 400, _vy = -520, _targetX = 180;
  double _gap = 70, _stormChance = 0, _cloudW = 100;
  double _scrolled = 0;
  double _clock = 0;
  double _hurtUntil = 0;
  double _demoUntil = 0;
  int _got = 0;
  int _combo = 0;
  bool _ready = false;
  bool _faceRight = true;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = BounceParams.forLevel(_c.level);
    _gap = _p.gap;
    _stormChance = _p.stormChance;
    _cloudW = _p.cloudWidth;
    _c.setUnits(0, _p.stars);
    _c.hintText = () => 'Slide to steer Kara onto the clouds and into the stars.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _gap = max(60.0, _gap - 12);
      _stormChance *= 0.5;
      _cloudW = min(130.0, _cloudW + 14);
    };
    _c.onHarder = () {
      _gap = min(BounceLogic.jumpHeight - 14, _gap + 8);
      _stormChance = min(0.5, _stormChance + 0.08);
      _cloudW = max(70.0, _cloudW - 8);
    };
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, 'Boing! Up we go!', ms: 2600);
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

  void _setup() {
    _clouds.clear();
    _items.clear();
    // a wide first cloud right under Kara, then clouds up the screen
    _clouds.add(_Cloud(_w / 2, _h - 60, 160, false));
    _py = _h - 90;
    _px = _w / 2;
    _targetX = _px;
    _vy = BounceLogic.jumpV;
    var y = _h - 60 - _gap;
    while (y > -60) {
      _addCloud(y);
      y -= _gap;
    }
    _ready = true;
  }

  void _addCloud(double y) {
    final x = _cloudW / 2 + _rand.nextDouble() * (_w - _cloudW);
    final spring = _rand.nextDouble() < 0.12;
    _clouds.add(_Cloud(x, y, _cloudW, spring));
    if (_rand.nextDouble() < 0.55) {
      _items.add(_Item(x + (_rand.nextDouble() - 0.5) * 40, y - 46, false));
    }
    if (_stormChance > 0 && _rand.nextDouble() < _stormChance) {
      final sx = 30 + _rand.nextDouble() * (_w - 60);
      _items.add(_Item(sx, y + _gap / 2, true));
    }
  }

  void _steer(double screenX) {
    _targetX = (screenX / _k).clamp(20.0, _w - 20.0);
  }

  @override
  void onFrame(double dt) {
    if (_c.completed || !_ready) return;
    _clock += dt;
    if ((_targetX - _px).abs() > 6) _faceRight = _targetX > _px; // face the way we move
    _px += (_targetX - _px) * min(1.0, dt * 10);
    final prevFoot = _py + 26;
    _vy += BounceLogic.gravity * _c.speed.clamp(0.7, 1.0) * dt;
    _py += _vy * dt;
    final foot = _py + 26;

    // landing
    for (final cl in _clouds) {
      if (BounceLogic.lands(
          prevFoot: prevFoot, foot: foot, cloudY: cl.y, px: _px,
          cloudX: cl.x, cloudW: cl.w, vy: _vy)) {
        _vy = cl.spring ? BounceLogic.springV : BounceLogic.jumpV;
        _py = cl.y - 26;
        if (cl.spring) {
          _c.burst(Offset(_px * _k, cl.y * _k), '\u{1F4A5}');
        }
        break;
      }
    }

    // scroll the world down when Kara climbs above 40% of the screen
    final limit = _h * 0.4;
    if (_py < limit) {
      final d = limit - _py;
      _py = limit;
      _scrolled += d;
      for (final cl in _clouds) {
        cl.y += d;
      }
      for (final it in _items) {
        it.y += d;
      }
    }
    var top = _clouds.map((c) => c.y).reduce(min);
    while (top > -60) {
      top -= _gap;
      _addCloud(top);
    }

    // items
    final used = <_Item>[];
    for (final it in _items) {
      it.age += dt;
      final dx = it.x - _px, dy = it.y - _py;
      if (dx * dx + dy * dy < 30 * 30) {
        used.add(it);
        _touch(it);
      } else if (it.y > _h + 40) {
        used.add(it);
        if (!it.storm) _c.recordTagged('omission');
      }
    }
    _items.removeWhere(used.contains);
    _clouds.removeWhere((c) => c.y > _h + 80);

    // fell off the bottom: a friendly bubble bounces Kara up again
    if (_py > _h + 40) {
      final safe = _clouds.where((c) => c.y < _h - 20).toList();
      if (safe.isNotEmpty) {
        safe.sort((a, b) => b.y.compareTo(a.y));
        final cl = safe.first;
        _px = cl.x;
        _targetX = cl.x;
        _py = cl.y - 26;
        _vy = BounceLogic.jumpV;
      } else {
        _py = _h - 90;
        _vy = BounceLogic.jumpV;
      }
      _combo = 0;
      _c.recordMistake();
      _c.react(CharacterState.encouraging, 'Whoops! A bubble catches you!', ms: 1800);
    }
    if (!_c.completed) setState(() {});
  }

  void _touch(_Item it) {
    _c.recordTouch();
    if (it.storm) {
      _vy = 260; // knocked downwards a little
      _combo = 0;
      _hurtUntil = _clock + 0.6;
      _c.recordMistake();
      GameAudio.tap();
      _c.react(CharacterState.encouraging, 'Grumpy cloud! Go around it.', ms: 1500);
      return;
    }
    _combo++;
    _c.recordResponse((it.age * 1000).round());
    _c.recordSuccess(points: 1 + min(_combo, 5) ~/ 2);
    GameAudio.success();
    _c.burst(Offset(it.x * _k, it.y * _k), _combo >= 3 ? '\u{1F308}' : '\u{2B50}');
    _got++;
    _c.setUnits(_got, _p.stars);
    if (_combo == 3 || _combo == 6) {
      _c.react(CharacterState.celebrating, 'Combo x$_combo! Amazing!', ms: 1500);
    }
    if (_got >= _p.stars) {
      _c.finishLine = CharacterLines.completion(CharacterId.kara);
      _c.complete();
      stopLoop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _k = box.maxWidth / _w;
      final newH = box.maxHeight / _k;
      if (!_ready || (newH - _h).abs() > 1) {
        _h = newH;
        if (!_ready) _setup();
      }
      // nearest star above Kara gets the cue
      _Item? target;
      for (final it in _items) {
        if (!it.storm && it.y < _py + 20 &&
            (target == null || (it.y - _py).abs() < (target.y - _py).abs())) {
          target = it;
        }
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _steer(d.localPosition.dx),
        onPanUpdate: (d) => _steer(d.localPosition.dx),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _CloudSky(_scrolled))),
          for (final cl in _clouds)
            Positioned(
              left: (cl.x - cl.w / 2) * _k,
              top: cl.y * _k,
              child: SizedBox(
                width: cl.w * _k,
                height: cl.w * _k * 0.5,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      child: Sprite('cloud', width: cl.w * _k, height: cl.w * _k * 0.6)),
                  if (cl.spring)
                    Positioned(
                      left: cl.w * _k / 2 - 14 * _k,
                      top: -16 * _k,
                      child: Sprite('spring', width: 28 * _k, height: 28 * _k),
                    ),
                ]),
              ),
            ),
          for (final it in _items)
            Positioned(
              left: (it.x - 24) * _k,
              top: (it.y - 24) * _k,
              child: CueRing(
                show: cue && identical(it, target),
                size: 48 * _k,
                child: Sprite(it.storm ? 'storm' : 'star',
                    width: 44 * _k,
                    height: 44 * _k,
                    angle: it.storm ? 0 : sin(it.age * 3) * 0.2),
              ),
            ),
          Positioned(
            left: (_px - 28) * _k,
            top: (_py - 30) * _k,
            child: Opacity(
              opacity: _clock < _hurtUntil ? 0.5 : 1,
              child: Sprite('unicorn_side',
                  width: 62 * _k, height: 62 * _k, faceRight: _faceRight),
            ),
          ),
          if (_combo >= 2)
            Positioned(
              top: 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF4081),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('x$_combo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
      );
    });
  }
}

class _CloudSky extends CustomPainter {
  final double scrolled;
  _CloudSky(this.scrolled);

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB39DDB), Color(0xFFF8BBD0), Color(0xFFFFF3E0)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    final star = Paint()..color = Colors.white.withValues(alpha: 0.8);
    for (var i = 0; i < 14; i++) {
      final x = (i * 97.0) % size.width;
      final y = ((i * 61.0) + scrolled * 0.2) % size.height;
      canvas.drawCircle(Offset(x, y), 1.8 + (i % 3), star);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudSky old) => old.scrolled != scrolled;
}
