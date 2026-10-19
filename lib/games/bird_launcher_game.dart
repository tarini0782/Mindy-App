import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// BIRD TARGET LAUNCHER (Lumi). Drag the little bird backwards and let go.
/// It flies in an arc and pops the balloon target. Original characters: a
/// round bird and balloon friends.
///
///   Level  balloons  balloon size  aim guide while dragging  wall
///   1      3         big           yes (whole path)          no
///   2      3         big           yes (short)               no
///   3      4         medium        no                        no
///   4      4         small         no                        yes
///   5      5         smallest      no                        yes
///
/// Logged: success (balloon popped), mistake (a miss; gentle), touch (each
/// launch), response (balloon appears -> launch), pull length / angle are in
/// the event stream as the response value of the shot.
class LauncherParams {
  final int balloons;
  final double radius; // design px
  final int guide; // 0 none, 1 short, 2 full
  final bool wall;
  const LauncherParams(this.balloons, this.radius, this.guide, this.wall);

  static LauncherParams forLevel(int level) => LauncherParams(
        pickByLevel(level, 3, 3, 4, 4, 5),
        pickByLevel(level, 44.0, 38.0, 32.0, 27.0, 23.0),
        pickByLevel(level, 2, 1, 0, 0, 0),
        level >= 4,
      );
}

class Shot {
  final double pull;
  final double angleDeg;
  const Shot(this.pull, this.angleDeg);
}

class LaunchPhysics {
  static const double gravity = 900; // design px / s^2
  static const double kV = 7; // launch speed per pixel of pull
  static const double maxPull = 100;

  /// Launch velocity for a pull of [pull] px at [angleDeg] above horizontal.
  static Offset velocity(double pull, double angleDeg) {
    final a = angleDeg * pi / 180;
    return Offset(cos(a), -sin(a)) * (pull * kV);
  }

  /// Points of the flight (every 1/60 s) until it leaves [bounds], hits a
  /// wall, or reaches [target]. [hit] says whether it reached the target.
  static ({List<Offset> points, bool hit}) simulate({
    required Offset home,
    required Offset v0,
    required Offset target,
    required double radius,
    required Rect bounds,
    Rect? wall,
    double birdRadius = 12,
  }) {
    final pts = <Offset>[];
    var p = home;
    var v = v0;
    const dt = 1 / 60.0;
    for (var i = 0; i < 360; i++) {
      v = Offset(v.dx, v.dy + gravity * dt);
      p = p + v * dt;
      pts.add(p);
      if ((p - target).distance <= radius + birdRadius) {
        return (points: pts, hit: true);
      }
      if (wall != null && wall.inflate(birdRadius * 0.5).contains(p)) {
        return (points: pts, hit: false);
      }
      if (p.dy > bounds.bottom || p.dx > bounds.right + 40 || p.dx < -40) {
        break;
      }
    }
    return (points: pts, hit: false);
  }

  /// Finds the gentlest working shot (smallest pull), or null if none works.
  static Shot? solve({
    required Offset home,
    required Offset target,
    required double radius,
    required Rect bounds,
    Rect? wall,
    double scale = 1,
  }) {
    Shot? best;
    for (var pull = 30.0 * scale; pull <= maxPull * scale; pull += 5 * scale) {
      for (var ang = 15.0; ang <= 80.0; ang += 2) {
        final r = simulate(
          home: home,
          v0: velocity(pull, ang),
          target: target,
          radius: radius,
          bounds: bounds,
          wall: wall,
        );
        if (r.hit && (best == null || pull < best.pull)) {
          best = Shot(pull, ang);
        }
      }
      if (best != null) return best;
    }
    return best;
  }
}

class BirdLauncherGame extends StatefulWidget {
  final GameSessionController controller;
  const BirdLauncherGame({super.key, required this.controller});

  @override
  State<BirdLauncherGame> createState() => _BirdLauncherGameState();
}

class _BirdLauncherGameState extends State<BirdLauncherGame>
    with
        SingleTickerProviderStateMixin<BirdLauncherGame>,
        GameLoop<BirdLauncherGame> {
  late final LauncherParams _p;
  final _rand = Random(97);
  Size _size = const Size(360, 520);
  Offset _home = const Offset(70, 330);
  Offset? _target;
  Rect? _wall;
  double _radius = 40;
  int _stage = 0;
  Offset? _drag; // pulled-back position
  Offset? _bird; // flying bird position, null when waiting
  Offset _vel = Offset.zero;
  double _flightT = 0;
  List<Offset> _demo = const [];
  double _demoUntil = 0;
  double _clock = 0;
  double _sinceAppear = 0;

  GameSessionController get _c => widget.controller;
  double get _k => _size.width / 360.0;

  @override
  void initState() {
    super.initState();
    _p = LauncherParams.forLevel(_c.level);
    _radius = _p.radius;
    _c.setUnits(0, _p.balloons);
    _c.hintText = () => 'Pull the bird back further to fly farther.';
    _c.onDemonstrate = _showDemo;
    _c.onEasier = () => _radius *= 1.25;
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.lumi),
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

  void _placeTarget() {
    final w = _size.width, h = _size.height;
    _home = Offset(w * 0.18, h * 0.66);
    for (var attempt = 0; attempt < 30; attempt++) {
      final t = Offset(w * (0.55 + _rand.nextDouble() * 0.35),
          h * (0.22 + _rand.nextDouble() * 0.38));
      Rect? wall;
      if (_p.wall) {
        wall = Rect.fromLTWH(w * 0.47, h * 0.5, 14 * _k, h * 0.2);
      }
      final shot = LaunchPhysics.solve(
        home: _home,
        target: t,
        radius: _radius,
        bounds: Offset.zero & _size,
        wall: wall,
        scale: _k,
      );
      if (shot != null) {
        _target = t;
        _wall = wall;
        _sinceAppear = 0;
        return;
      }
    }
    _target = Offset(w * 0.75, h * 0.4);
    _wall = null;
    _sinceAppear = 0;
  }

  void _showDemo() {
    final t = _target;
    if (t == null) return;
    final shot = LaunchPhysics.solve(
      home: _home,
      target: t,
      radius: _radius,
      bounds: Offset.zero & _size,
      wall: _wall,
      scale: _k,
    );
    if (shot == null) return;
    final r = LaunchPhysics.simulate(
      home: _home,
      v0: LaunchPhysics.velocity(shot.pull, shot.angleDeg),
      target: t,
      radius: _radius,
      bounds: Offset.zero & _size,
      wall: _wall,
    );
    _demo = [for (var i = 0; i < r.points.length; i += 5) r.points[i]];
    _demoUntil = _clock + 4;
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _clock += dt;
    if (_target == null) _placeTarget();
    if (_bird == null) {
      _sinceAppear += dt;
    } else {
      _flightT += dt;
      _vel = Offset(_vel.dx, _vel.dy + LaunchPhysics.gravity * dt);
      _bird = _bird! + _vel * dt;
      final b = _bird!;
      final t = _target!;
      if ((b - t).distance <= _radius + 12) {
        _onHit();
      } else if ((_wall != null && _wall!.contains(b)) ||
          b.dy > _size.height ||
          b.dx > _size.width + 40 ||
          _flightT > 6) {
        _onMiss();
      }
    }
    setState(() {});
  }

  void _onHit() {
    _bird = null;
    _c.recordSuccess();
    GameAudio.success();
    _c.burst(_target!, '\u{1F389}');
    _stage++;
    _c.setUnits(_stage, _p.balloons);
    if (_stage >= _p.balloons) {
      _c.finishLine = CharacterLines.completion(CharacterId.lumi);
      _c.complete();
      stopLoop();
      return;
    }
    _target = null;
    _demo = const [];
  }

  void _onMiss() {
    _bird = null;
    _c.recordMistake();
    _c.react(CharacterState.encouraging, 'So close! Try again.', ms: 1600);
  }

  void _panStart(DragStartDetails d) {
    if (_bird != null || _c.completed) return;
    if ((d.localPosition - _home).distance < 70 * _k) _drag = d.localPosition;
  }

  void _panUpdate(DragUpdateDetails d) {
    if (_drag == null) return;
    var v = d.localPosition - _home;
    final maxP = LaunchPhysics.maxPull * _k;
    if (v.distance > maxP) v = v / v.distance * maxP;
    setState(() => _drag = _home + v);
  }

  void _panEnd(DragEndDetails d) {
    final dr = _drag;
    _drag = null;
    if (dr == null || _bird != null) return;
    final pull = _home - dr;
    if (pull.distance < 12 * _k) return;
    _c.recordTouch();
    _c.recordResponse((_sinceAppear * 1000).round());
    _vel = pull * LaunchPhysics.kV;
    _bird = _home;
    _flightT = 0;
    GameAudio.tap();
  }

  List<Offset> _guide() {
    final dr = _drag;
    if (dr == null || _p.guide == 0) return const [];
    final pull = _home - dr;
    final r = LaunchPhysics.simulate(
      home: _home,
      v0: pull * LaunchPhysics.kV,
      target: const Offset(-999, -999),
      radius: 1,
      bounds: Offset.zero & _size,
      wall: _wall,
    );
    final every = 4;
    final limit = _p.guide == 1 ? 14 : 40;
    final out = <Offset>[];
    for (var i = 0; i < r.points.length && out.length < limit; i += every) {
      out.add(r.points[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final cue = cueActive(_c.supportCue.value);
      final showDemo = _clock < _demoUntil;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _panStart,
        onPanUpdate: _panUpdate,
        onPanEnd: _panEnd,
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LauncherPainter(
                home: _home,
                target: _target,
                radius: _radius,
                wall: _wall,
                drag: _drag,
                bird: _bird,
                guide: _guide(),
                demo: showDemo ? _demo : const [],
                cue: cue,
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _LauncherPainter extends CustomPainter {
  final Offset home;
  final Offset? target;
  final double radius;
  final Rect? wall;
  final Offset? drag;
  final Offset? bird;
  final List<Offset> guide;
  final List<Offset> demo;
  final bool cue;
  _LauncherPainter({
    required this.home,
    required this.target,
    required this.radius,
    required this.wall,
    required this.drag,
    required this.bird,
    required this.guide,
    required this.demo,
    required this.cue,
  });

  void _emoji(Canvas c, String s, Offset at, double size) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()..color = const Color(0x3366BB6A);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.78, size.width, size.height * 0.22),
        ground);
    if (wall != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(wall!, const Radius.circular(6)),
          Paint()..color = const Color(0xFF8D6E63));
    }
    // slingshot post
    canvas.drawLine(home + const Offset(0, 14), home + const Offset(0, 80),
        Paint()
          ..color = const Color(0xFF6D4C41)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round);
    final t = target;
    if (t != null) {
      if (cue) {
        canvas.drawCircle(
            t,
            radius + 12,
            Paint()
              ..color = const Color(0xFFFFC107)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5);
      }
      canvas.drawCircle(t, radius, Paint()..color = const Color(0xFFEF5350));
      canvas.drawCircle(
          t, radius * 0.55, Paint()..color = Colors.white.withValues(alpha: 0.85));
      canvas.drawCircle(t, radius * 0.2, Paint()..color = const Color(0xFFEF5350));
    }
    final dot = Paint()..color = const Color(0xAA3D5AFE);
    for (final g in guide) {
      canvas.drawCircle(g, 4, dot);
    }
    final demoDot = Paint()..color = const Color(0xCCFFC107);
    for (final g in demo) {
      canvas.drawCircle(g, 5, demoDot);
    }
    if (drag != null) {
      final band = Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = 4;
      canvas.drawLine(home + const Offset(0, 14), drag!, band);
    }
    final b = bird ?? drag ?? home;
    _emoji(canvas, '\u{1F426}', b, 38);
  }

  @override
  bool shouldRepaint(covariant _LauncherPainter old) => true;
}
