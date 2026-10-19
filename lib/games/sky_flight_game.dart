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

/// SKY FLIGHT (Pip the baby dragon). A side-scrolling flight: the sky and
/// hills scroll past on their own. Slide a finger up and down to steer Pip.
/// Fly through stars; steer around storm clouds.
///
///   Level  stars  scroll speed  cloud share
///   1      8      90            20%
///   2      10     105           30%
///   3      12     120           35%
///   4      14     140           40%
///   5      16     160           45%
///
/// Logged: success (star), mistake (cloud bump = commission), omission
/// (a star passed by), response time (star appears -> collected).
class SkyParams {
  final int stars;
  final double speed;
  final double cloudShare;
  const SkyParams(this.stars, this.speed, this.cloudShare);

  static SkyParams forLevel(int level) => SkyParams(
        pickByLevel(level, 8, 10, 12, 14, 16),
        pickByLevel(level, 90.0, 105.0, 120.0, 140.0, 160.0),
        pickByLevel(level, 0.20, 0.30, 0.35, 0.40, 0.45),
      );
}

class SkyLogic {
  static bool hit(double dx, double dy, double radius) =>
      dx * dx + dy * dy <= radius * radius;

  /// The next object is a star unless the cloud roll wins AND a star is
  /// already on its way (so the sky never fills with clouds only).
  static bool nextIsCloud(Random r, double share, {required bool starOnScreen}) =>
      starOnScreen && r.nextDouble() < share;
}

class _Thing {
  double x, y;
  final bool cloud;
  double age = 0;
  _Thing(this.x, this.y, this.cloud);
}

class SkyFlightGame extends StatefulWidget {
  final GameSessionController controller;
  const SkyFlightGame({super.key, required this.controller});

  @override
  State<SkyFlightGame> createState() => _SkyFlightGameState();
}

class _SkyFlightGameState extends State<SkyFlightGame>
    with
        SingleTickerProviderStateMixin<SkyFlightGame>,
        GameLoop<SkyFlightGame> {
  late final SkyParams _p;
  final _rand = Random(53);
  final List<_Thing> _things = [];
  Size _size = const Size(360, 520);
  double _y = 260;
  double _targetY = 260;
  double _scroll = 0;
  double _spawnIn = 0.4;
  double _speedScale = 1;
  double _cloudScale = 1;
  double _bumpUntil = 0;
  double _clock = 0;
  double _demoUntil = 0;
  int _got = 0;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = SkyParams.forLevel(_c.level);
    _c.setUnits(0, _p.stars);
    _c.hintText = () => 'Slide up or down to fly through the stars.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _speedScale = max(0.6, _speedScale * 0.8);
      _cloudScale = max(0.3, _cloudScale * 0.6);
    };
    _c.onHarder = () {
      _speedScale = min(1.5, _speedScale * 1.15);
      _cloudScale = min(1.6, _cloudScale * 1.25);
    };
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

  void _steer(double y) => _targetY = y.clamp(40.0, max(40.0, _size.height - 40.0));

  void _spawn() {
    final k = _size.width / 360.0;
    final starOn = _things.any((t) => !t.cloud);
    final cloud = SkyLogic.nextIsCloud(_rand, _p.cloudShare * _cloudScale,
        starOnScreen: starOn);
    final y = 50 + _rand.nextDouble() * max(10.0, _size.height - 100);
    _things.add(_Thing(_size.width + 40 * k, y, cloud));
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _clock += dt;
    final k = _size.width / 360.0;
    final v = _p.speed * _c.speed * _speedScale * k;
    _scroll += v * dt;
    _y += (_targetY - _y) * min(1.0, dt * 8);
    _spawnIn -= dt;
    if (_spawnIn <= 0 && _things.length < 6) {
      _spawn();
      _spawnIn = 0.9 + _rand.nextDouble() * 0.7;
    }
    final px = 70 * k;
    final gone = <_Thing>[];
    for (final t in _things) {
      t.x -= v * dt;
      t.age += dt;
      if (SkyLogic.hit(t.x - px, t.y - _y, 34 * k)) {
        gone.add(t);
        _onTouch(t);
      } else if (t.x < -50 * k) {
        gone.add(t);
        if (!t.cloud) _c.recordTagged('omission');
      }
    }
    _things.removeWhere(gone.contains);
    if (!_c.completed) setState(() {});
  }

  void _onTouch(_Thing t) {
    _c.recordTouch();
    if (t.cloud) {
      _c.recordMistake();
      _bumpUntil = _clock + 0.5;
      GameAudio.tap();
      _c.react(CharacterState.encouraging, 'Bump! Go around the clouds.', ms: 1500);
      return;
    }
    _c.recordResponse((t.age * 1000).round());
    _c.recordSuccess();
    GameAudio.success();
    _c.burst(Offset(70, t.y), '\u{2728}');
    _got++;
    _c.setUnits(_got, _p.stars);
    if (_got >= _p.stars) {
      _c.finishLine = CharacterLines.completion(CharacterId.pip);
      _c.complete();
      stopLoop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final k = _size.width / 360.0;
      // nearest star ahead gets the visual cue
      _Thing? nearest;
      for (final t in _things) {
        if (!t.cloud && (nearest == null || t.x < nearest.x)) nearest = t;
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _steer(d.localPosition.dy),
        onPanUpdate: (d) => _steer(d.localPosition.dy),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(painter: _SkyPainter(_scroll)),
          ),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: RuleChip(
                color: const Color(0xFF5C6BC0),
                text: 'Slide to fly: stars yes, clouds no',
                icons: [Sprite('star', width: 24, height: 24)],
              ),
            ),
          ),
          for (final t in _things)
            Positioned(
              left: t.x - 28 * k,
              top: t.y - 28 * k,
              child: CueRing(
                show: cue && identical(t, nearest),
                size: 56 * k,
                child: Sprite(t.cloud ? 'storm' : 'star',
                    width: 52 * k, height: 52 * k,
                    angle: t.cloud ? 0 : sin(t.age * 3) * 0.2),
              ),
            ),
          Positioned(
            left: 70 * k - 30 * k,
            top: _y - 30 * k,
            child: Opacity(
              opacity: _clock < _bumpUntil ? 0.5 : 1,
              child: Sprite('dragon_side',
                  width: 66 * k, height: 66 * k, angle: (_targetY - _y).clamp(-80.0, 80.0) / 400),
            ),
          ),
        ]),
      );
    });
  }
}

/// Parallax: far clouds move slowly, near hills move faster.
class _SkyPainter extends CustomPainter {
  final double scroll;
  _SkyPainter(this.scroll);

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 6; i++) {
      final w = size.width + 160;
      final x = ((i * 190.0) - scroll * 0.25) % w - 80;
      final y = 60.0 + (i * 53) % (size.height * 0.5);
      canvas.drawOval(Rect.fromLTWH(x, y, 90, 30), cloud);
      canvas.drawOval(Rect.fromLTWH(x + 25, y - 14, 60, 30), cloud);
    }
    final hill = Paint()..color = const Color(0xFF81C784);
    final hill2 = Paint()..color = const Color(0xFF66BB6A);
    for (var layer = 0; layer < 2; layer++) {
      final p = layer == 0 ? hill : hill2;
      final f = layer == 0 ? 0.5 : 0.9;
      final base = size.height - (layer == 0 ? 50.0 : 22.0);
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width + 8; x += 8) {
        path.lineTo(x, base - 18 * sin((x + scroll * f) / 55.0 + layer));
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.scroll != scroll;
}
