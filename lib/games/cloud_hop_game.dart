import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import '../characters/mindy_character.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';
import 'widgets/scene_art.dart';

/// CLOUD HOP (Pip the baby dragon). One-tap hopping from cloud to cloud.
///
/// A little star floats back and forth showing how far Pip's next hop will
/// go. Tap to hop; if the star is over the next cloud, Pip lands on it. If it
/// is not, Pip lands in a soft bubble that floats him gently back, and he
/// simply tries again. Nothing is lost and nobody falls.
///
/// The star moves slowly on purpose. This is a calm timing game, not a
/// reflex game.
///
///   Level  clouds   cloud size   star speed   glow on next cloud
///   1      5 hops   largest      slowest      yes
///   2      6                                  yes
///   3      7                                  no
///   4      8
///   5      9 hops   smallest      fastest (still gentle)
class HopParams {
  final int hops;
  final double cloudWidth; // design pixels (360 wide design)
  final double periodSec; // seconds for the star to sweep there and back
  final bool showTargetGlow;
  final double gapMin;
  final double gapMax;

  const HopParams(this.hops, this.cloudWidth, this.periodSec,
      this.showTargetGlow, this.gapMin, this.gapMax);

  static HopParams forLevel(int level) => HopParams(
        pickByLevel(level, 5, 6, 7, 8, 9),
        pickByLevel(level, 150.0, 132.0, 116.0, 100.0, 88.0),
        pickByLevel(level, 3.6, 3.2, 2.8, 2.5, 2.2),
        level <= 2,
        pickByLevel(level, 150.0, 160.0, 170.0, 180.0, 190.0),
        pickByLevel(level, 190.0, 210.0, 230.0, 250.0, 270.0),
      );

  /// Hop distance the star can show: always covers every possible gap.
  double get minHop => gapMin - 50;
  double get maxHop => gapMax + 60;

  /// A hop from [from] lands on a cloud centred at [cloudX] if it ends within
  /// half a cloud width of its centre.
  bool lands(double from, double hopDistance, double cloudX) =>
      ((from + hopDistance) - cloudX).abs() <= cloudWidth / 2;
}

class CloudHopGame extends StatefulWidget {
  final GameSessionController controller;
  const CloudHopGame({super.key, required this.controller});

  @override
  State<CloudHopGame> createState() => _CloudHopGameState();
}

enum _HopState { aiming, jumping, floatingBack, celebrating }

class _CloudHopGameState extends State<CloudHopGame>
    with
        SingleTickerProviderStateMixin<CloudHopGame>,
        GameLoop<CloudHopGame> {
  late final HopParams _p;
  final _rand = Random(7);
  late final List<double> _clouds; // centre x in design units
  Size _size = const Size(360, 520);
  double get _k => _size.width / 360.0; // design -> screen scale

  int _cur = 0; // index of the cloud Pip stands on
  _HopState _state = _HopState.aiming;
  double _phase = 0;
  double _clock = 0;
  double _readySince = 0;
  double _t = 0; // animation progress for jump / float back
  double _hopDist = 0;
  double _fromX = 0;
  bool _hit = false;
  double _camX = 0;
  int _done = 0;

  double get _marker => _p.minHop + (_p.maxHop - _p.minHop) * (0.5 + 0.5 * sin(_phase));

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _p = HopParams.forLevel(c.level);
    _clouds = [0];
    for (var i = 0; i < _p.hops; i++) {
      final gap = _p.gapMin + _rand.nextDouble() * (_p.gapMax - _p.gapMin);
      _clouds.add(_clouds.last + gap);
    }
    c.setUnits(0, _p.hops);
    c.react(CharacterState.excited, CharacterLines.start(CharacterId.pip), ms: 3000);
    startLoop();
  }

  void _hop() {
    if (_state != _HopState.aiming || widget.controller.completed) return;
    final c = widget.controller;
    c.recordTouch();
    c.recordResponse(((_clock - _readySince) * 1000).round());
    _hopDist = _marker;
    _fromX = _clouds[_cur];
    _hit = _p.lands(_fromX, _hopDist, _clouds[_cur + 1]);
    _state = _HopState.jumping;
    _t = 0;
    GameAudio.tap();
  }

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;

    switch (_state) {
      case _HopState.aiming:
        _phase += (2 * pi / _p.periodSec) * min(1.2, c.speed) * dt;
        break;
      case _HopState.jumping:
        _t += dt / 0.7;
        if (_t >= 1) {
          _t = 0;
          if (_hit) {
            _cur++;
            _done++;
            c.recordSuccess();
            c.setUnits(_done, _p.hops);
            GameAudio.success();
            c.burst(Offset(_size.width * 0.3, _size.height * 0.45), '\u2B50');
            c.react(CharacterState.celebrating,
                CharacterLines.pipFind[_done % CharacterLines.pipFind.length],
                ms: 1600);
            if (_done >= _p.hops) {
              c.finishLine = CharacterLines.completion(CharacterId.pip);
              c.complete();
              stopLoop();
              return;
            }
            _state = _HopState.aiming;
            _readySince = _clock;
          } else {
            c.recordMistake();
            c.react(CharacterState.encouraging, 'Almost! Try again.', ms: 1800);
            _state = _HopState.floatingBack;
          }
        }
        break;
      case _HopState.floatingBack:
        _t += dt / 0.9;
        if (_t >= 1) {
          _t = 0;
          _state = _HopState.aiming;
          _readySince = _clock;
        }
        break;
      case _HopState.celebrating:
        break;
    }

    // smooth camera follow
    final target = _clouds[_cur] - 70;
    _camX += (target - _camX) * min(1.0, dt * 4);
    setState(() {});
  }

  /// Pip's design-space position and height lift for the current state.
  (double, double) _pipPos() {
    switch (_state) {
      case _HopState.aiming:
      case _HopState.celebrating:
        return (_clouds[_cur], 0);
      case _HopState.jumping:
        final land = _hit ? _clouds[_cur + 1] : _fromX + _hopDist;
        final x = _fromX + (land - _fromX) * Curves.easeInOut.transform(_t);
        return (x, sin(pi * _t) * 110);
      case _HopState.floatingBack:
        final land = _fromX + _hopDist;
        final x = land + (_clouds[_cur] - land) * Curves.easeInOut.transform(_t);
        return (x, 28 + sin(pi * _t) * 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final k = _k;
      final groundY = _size.height * 0.68;
      final (px, lift) = _pipPos();
      final pipScreenX = (px - _camX) * k + 40 * k;
      final pipY = groundY - 60 * k - lift * k;
      final markerX = (_clouds[_cur] + _marker - _camX) * k + 40 * k;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _hop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HopPainter(
                  clouds: _clouds,
                  camX: _camX,
                  k: k,
                  groundY: groundY,
                  cloudW: _p.cloudWidth,
                  cur: _cur,
                  showGlow: _p.showTargetGlow,
                  aiming: _state == _HopState.aiming,
                  markerX: markerX,
                  clock: _clock,
                  floatingBack: _state == _HopState.floatingBack,
                  pipX: pipScreenX,
                  pipY: pipY,
                ),
              ),
            ),
            Positioned(
              left: pipScreenX - 40 * k,
              top: pipY - 52 * k,
              width: 80 * k,
              height: 88 * k,
              child: IgnorePointer(
                child: MindyCharacter(
                  id: CharacterId.pip,
                  state: _state == _HopState.jumping
                      ? CharacterState.excited
                      : CharacterState.happy,
                  size: 80 * k,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _HopPainter extends CustomPainter {
  final List<double> clouds;
  final double camX, k, groundY, cloudW, markerX, clock, pipX, pipY;
  final int cur;
  final bool showGlow, aiming, floatingBack;

  _HopPainter({
    required this.clouds,
    required this.camX,
    required this.k,
    required this.groundY,
    required this.cloudW,
    required this.cur,
    required this.showGlow,
    required this.aiming,
    required this.markerX,
    required this.clock,
    required this.floatingBack,
    required this.pipX,
    required this.pipY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // far, slow background clouds
    for (var i = 0; i < 4; i++) {
      final x = ((i * 190.0 - camX * 0.25) % (size.width + 240)) - 120;
      paintCloud(canvas, Offset(x, size.height * (0.12 + 0.07 * (i % 3))),
          90.0 + 20 * (i % 2), opacity: 0.55);
    }

    // stepping clouds
    for (var i = 0; i < clouds.length; i++) {
      final x = (clouds[i] - camX) * k + 40 * k;
      if (x < -200 || x > size.width + 200) continue;
      paintCloud(canvas, Offset(x, groundY), cloudW * k, opacity: 0.97);
      // a little star on clouds not yet visited
      if (i > cur) {
        paintStar(canvas, Offset(x, groundY - 26 * k), 9 * k,
            const Color(0xFFFFD166));
      }
      if (showGlow && i == cur + 1 && aiming) {
        final pulse = 0.5 + 0.5 * sin(clock * 3);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x, groundY),
                width: cloudW * k * 1.15,
                height: cloudW * k * 0.62),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = const Color(0xFFFFE066).withValues(alpha: 0.5 + 0.35 * pulse));
      }
    }

    // aiming star + dotted hop arc
    if (aiming) {
      final x0 = pipX;
      final x1 = markerX;
      for (var i = 1; i <= 8; i++) {
        final t = i / 9;
        final x = x0 + (x1 - x0) * t;
        final y = groundY - 60 * k - sin(pi * t) * 110 * k;
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      paintStar(canvas, Offset(x1, groundY - 20 * k), 14 * k, const Color(0xFFFF8AD0));
    }

    // soft bubble while floating back
    if (floatingBack) {
      canvas.drawCircle(
          Offset(pipX, pipY + 6 * k),
          46 * k,
          Paint()
            ..color = const Color(0x55BFE3FF)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(pipX, pipY + 6 * k),
          46 * k,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(covariant _HopPainter old) => true;
}
