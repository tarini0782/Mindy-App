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

/// FRUIT SLICE PARTY (Nova). Fruit flies up from the bottom. SWIPE a finger
/// across it to slice it. Stinky socks are obstacles: do not slice them!
/// A snowflake slows time for a few seconds. Nothing ever ends the game
/// early: a sock just breaks the combo.
///
///   Level  fruit to slice  at once  sock share  launch gap (s)
///   1      8               1        0%          1.6
///   2      10              2        12%         1.4
///   3      12              2        20%         1.2
///   4      14              3        28%         1.0
///   5      16              4        35%         0.9
///
/// Logged: success (fruit sliced), mistake (sock sliced), omission (fruit
/// fell), response time (launch -> sliced).
class SliceParams {
  final int fruit;
  final int atOnce;
  final double sockShare;
  final double gap;
  const SliceParams(this.fruit, this.atOnce, this.sockShare, this.gap);

  static SliceParams forLevel(int level) => SliceParams(
        pickByLevel(level, 8, 10, 12, 14, 16),
        pickByLevel(level, 1, 2, 2, 3, 4),
        pickByLevel(level, 0.0, 0.12, 0.20, 0.28, 0.35),
        pickByLevel(level, 1.6, 1.4, 1.2, 1.0, 0.9),
      );
}

class SliceLogic {
  /// Shortest distance from point [p] to the segment [a]-[b].
  static double distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  static bool sliced(Offset center, double radius, Offset a, Offset b) =>
      distToSegment(center, a, b) <= radius;

  /// Launch speed that makes an item peak at [peak] design pixels above its
  /// start under gravity [g].
  static double launchSpeed(double peak, double g) => sqrt(2 * g * peak);

  /// The first item and any time no fruit is flying is always a fruit, so
  /// the game never fills with obstacles only.
  static bool nextIsSock(Random r, double share, {required bool fruitFlying}) =>
      fruitFlying && r.nextDouble() < share;
}

enum _Kind { fruit, sock, freeze }

class _Flyer {
  double x, y, vx, vy;
  final _Kind kind;
  final String emoji;
  double age = 0;
  _Flyer(this.x, this.y, this.vx, this.vy, this.kind, this.emoji);
}

const _kFruit = ['watermelon', 'orange', 'strawberry', 'apple'];

class FruitSliceGame extends StatefulWidget {
  final GameSessionController controller;
  const FruitSliceGame({super.key, required this.controller});

  @override
  State<FruitSliceGame> createState() => _FruitSliceGameState();
}

class _FruitSliceGameState extends State<FruitSliceGame>
    with
        SingleTickerProviderStateMixin<FruitSliceGame>,
        GameLoop<FruitSliceGame> {
  late final SliceParams _p;
  final _rand = Random(23);
  final List<_Flyer> _fly = [];
  final List<Offset> _trail = [];
  static const double _w = 360, _g = 520;
  double _h = 520, _k = 1;
  double _spawnIn = 0.4;
  double _gap = 1.6;
  double _sockShare = 0;
  int _atOnce = 1;
  double _slow = 1; // 1 normal, <1 during snowflake
  double _slowUntil = 0;
  double _clock = 0;
  double _demoUntil = 0;
  int _sliced = 0;
  int _combo = 0;
  Offset? _last;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = SliceParams.forLevel(_c.level);
    _gap = _p.gap;
    _sockShare = _p.sockShare;
    _atOnce = _p.atOnce;
    _c.setUnits(0, _p.fruit);
    _c.hintText = () => 'Swipe across the fruit. Keep away from the socks.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _gap *= 1.25;
      _sockShare *= 0.5;
      _atOnce = max(1, _atOnce - 1);
    };
    _c.onHarder = () {
      _gap = max(0.7, _gap * 0.9);
      _sockShare = min(0.45, _sockShare + 0.06);
      _atOnce = min(5, _atOnce + 1);
    };
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, "Fruit party! Swipe the fruit!", ms: 2600);
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
    final fruitFlying = _fly.any((f) => f.kind == _Kind.fruit);
    final roll = _rand.nextDouble();
    _Kind kind;
    if (SliceLogic.nextIsSock(_rand, _sockShare, fruitFlying: fruitFlying)) {
      kind = _Kind.sock;
    } else if (fruitFlying && roll > 0.93) {
      kind = _Kind.freeze;
    } else {
      kind = _Kind.fruit;
    }
    final x = 50 + _rand.nextDouble() * (_w - 100);
    final peak = _h * (0.55 + _rand.nextDouble() * 0.3);
    final vy = -SliceLogic.launchSpeed(peak, _g);
    final vx = (_w / 2 - x) * 0.25 + (_rand.nextDouble() - 0.5) * 60;
    final emoji = kind == _Kind.sock
        ? 'sock'
        : kind == _Kind.freeze
            ? 'snowflake'
            : _kFruit[_rand.nextInt(_kFruit.length)];
    _fly.add(_Flyer(x, _h + 30, vx, vy, kind, emoji));
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _clock += dt;
    if (_clock > _slowUntil) _slow = 1;
    final sdt = dt * _slow * _c.speed.clamp(0.7, 1.0);
    _spawnIn -= sdt;
    if (_spawnIn <= 0 && _fly.length < _atOnce + 1) {
      _spawn();
      _spawnIn = _gap * (0.8 + _rand.nextDouble() * 0.4);
    }
    final gone = <_Flyer>[];
    for (final f in _fly) {
      f.age += sdt;
      f.vy += _g * sdt;
      f.x += f.vx * sdt;
      f.y += f.vy * sdt;
      if (f.y > _h + 40 && f.vy > 0) {
        gone.add(f);
        if (f.kind == _Kind.fruit) {
          _combo = 0;
          _c.recordTagged('omission');
        }
      }
    }
    _fly.removeWhere(gone.contains);
    // the swipe trail fades
    if (_trail.isNotEmpty) _trail.removeAt(0);
    if (!_c.completed) setState(() {});
  }

  void _swipe(Offset p) {
    if (_c.completed) return;
    final d = Offset(p.dx / _k, p.dy / _k);
    final a = _last ?? d;
    _last = d;
    _trail.add(d);
    if (_trail.length > 14) _trail.removeAt(0);
    final hit = <_Flyer>[];
    for (final f in _fly) {
      if (SliceLogic.sliced(Offset(f.x, f.y), 30, a, d)) hit.add(f);
    }
    for (final f in hit) {
      _fly.remove(f);
      _onSlice(f);
      if (_c.completed) return;
    }
  }

  void _onSlice(_Flyer f) {
    _c.recordTouch();
    final at = Offset(f.x * _k, f.y * _k);
    switch (f.kind) {
      case _Kind.sock:
        _combo = 0;
        _c.recordMistake();
        GameAudio.tap();
        _c.burst(at, '\u{1F4A8}');
        _c.react(CharacterState.encouraging, 'Pee-yew! A stinky sock!', ms: 1500);
        break;
      case _Kind.freeze:
        _slow = 0.4;
        _slowUntil = _clock + 3.0;
        _c.burst(at, '\u{2744}\u{FE0F}');
        _c.react(CharacterState.happy, 'Time slows down!', ms: 1500);
        break;
      case _Kind.fruit:
        _combo++;
        _c.recordResponse((f.age * 1000).round());
        _c.recordSuccess(points: 1 + min(_combo, 6) ~/ 2);
        GameAudio.success();
        _c.burst(at, '\u{1F4A6}');
        _sliced++;
        _c.setUnits(_sliced, _p.fruit);
        if (_combo == 3 || _combo == 6) {
          _c.react(CharacterState.celebrating, 'Combo x$_combo! Yum!', ms: 1500);
        }
        if (_sliced >= _p.fruit) {
          _c.finishLine = CharacterLines.completion(CharacterId.nova);
          _c.complete();
          stopLoop();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _k = box.maxWidth / _w;
      _h = box.maxHeight / _k;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          _last = Offset(d.localPosition.dx / _k, d.localPosition.dy / _k);
          _swipe(d.localPosition);
        },
        onPanUpdate: (d) => _swipe(d.localPosition),
        onPanEnd: (_) => _last = null,
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(painter: _TrailPainter(List.of(_trail), _k, _slow < 1)),
          ),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: RuleChip(
                color: const Color(0xFFE53935),
                text: 'Swipe fruit. Skip the socks!',
                icons: [Sprite('watermelon', width: 28, height: 22)],
              ),
            ),
          ),
          for (final f in _fly)
            Positioned(
              left: (f.x - 30) * _k,
              top: (f.y - 30) * _k,
              child: CueRing(
                show: cue && f.kind == _Kind.fruit,
                size: 60 * _k,
                child: Sprite(f.emoji,
                    width: 56 * _k, height: 56 * _k, angle: f.age * 3.0),
              ),
            ),
          if (_combo >= 2)
            Positioned(
              top: 48,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
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

class _TrailPainter extends CustomPainter {
  final List<Offset> pts;
  final double k;
  final bool frozen;
  _TrailPainter(this.pts, this.k, this.frozen);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: frozen
            ? const [Color(0xFFB3E5FC), Color(0xFFE1F5FE)]
            : const [Color(0xFFFFF59D), Color(0xFFFFCCBC)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    for (var i = 1; i < pts.length; i++) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: i / pts.length)
        ..strokeWidth = 2 + 8 * i / pts.length
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(pts[i - 1] * k, pts[i] * k, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}
