import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// BUBBLE POP SHOOTER (Bubbles the bunny). Aim, shoot, match 3 or more.
///
/// A cute, gentle take on the classic bubble shooter: drag to aim, let go to
/// shoot. Matching three or more of the same colour pops them, and anything
/// left hanging falls. There is NO losing: the bubbles never creep down, the
/// next bubble is always a colour that is still on the board, and the round
/// simply ends when the board is clear.
///
/// Gameplay indicators: shots (touches), bubbles cleared (units) and the time
/// to take each shot. Accuracy is deliberately NOT recorded: not every shot
/// can pop, and that must never look like "poor performance".
class ShooterParams {
  final int colors;
  final int rows;
  final int cols;
  final double guideFraction; // how much of the aim line is shown
  final int shotCap; // safety net: the round ends happily after this many

  const ShooterParams(
      this.colors, this.rows, this.cols, this.guideFraction, this.shotCap);

  static ShooterParams forLevel(int level) => ShooterParams(
        pickByLevel(level, 3, 3, 4, 4, 5),
        pickByLevel(level, 3, 4, 4, 5, 6),
        pickByLevel(level, 6, 6, 7, 7, 7),
        pickByLevel(level, 1.0, 1.0, 1.0, 0.6, 0.45),
        pickByLevel(level, 40, 45, 50, 55, 60),
      );
}

/// Pure hex-grid logic (no Flutter) so it can be unit tested.
/// Even rows have [cols] cells; odd rows have [cols] - 1 cells shifted by
/// half a cell. -1 means empty, otherwise the colour index.
class HexGrid {
  final int rows;
  final int cols;
  final List<List<int>> cells;

  HexGrid(this.rows, this.cols)
      : cells = List.generate(
            rows, (r) => List<int>.filled(r.isEven ? cols : cols - 1, -1));

  int colsIn(int r) => r.isEven ? cols : cols - 1;
  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < colsIn(r);
  bool isFilled(int r, int c) => inBounds(r, c) && cells[r][c] >= 0;

  List<List<int>> neighbors(int r, int c) {
    final List<List<int>> raw = r.isEven
        ? [
            [r, c - 1], [r, c + 1],
            [r - 1, c - 1], [r - 1, c],
            [r + 1, c - 1], [r + 1, c],
          ]
        : [
            [r, c - 1], [r, c + 1],
            [r - 1, c], [r - 1, c + 1],
            [r + 1, c], [r + 1, c + 1],
          ];
    return [
      for (final n in raw)
        if (inBounds(n[0], n[1])) n,
    ];
  }

  int get filledCount {
    var n = 0;
    for (final row in cells) {
      for (final v in row) {
        if (v >= 0) n++;
      }
    }
    return n;
  }

  Set<int> get colorsPresent {
    final s = <int>{};
    for (final row in cells) {
      for (final v in row) {
        if (v >= 0) s.add(v);
      }
    }
    return s;
  }

  /// All cells connected to (r, c) that share its colour.
  List<List<int>> cluster(int r, int c) {
    final color = cells[r][c];
    if (color < 0) return [];
    final seen = <int>{r * 100 + c};
    final out = <List<int>>[];
    final stack = <List<int>>[
      [r, c]
    ];
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      out.add(cur);
      for (final n in neighbors(cur[0], cur[1])) {
        if (cells[n[0]][n[1]] == color && seen.add(n[0] * 100 + n[1])) {
          stack.add(n);
        }
      }
    }
    return out;
  }

  /// Filled cells that are no longer connected to the top row.
  List<List<int>> floating() {
    final anchored = <int>{};
    final stack = <List<int>>[];
    for (var c = 0; c < colsIn(0); c++) {
      if (cells[0][c] >= 0) {
        anchored.add(c);
        stack.add([0, c]);
      }
    }
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      for (final n in neighbors(cur[0], cur[1])) {
        if (cells[n[0]][n[1]] >= 0 && anchored.add(n[0] * 100 + n[1])) {
          stack.add(n);
        }
      }
    }
    final out = <List<int>>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < colsIn(r); c++) {
        if (cells[r][c] >= 0 && !anchored.contains(r == 0 ? c : r * 100 + c)) {
          out.add([r, c]);
        }
      }
    }
    return out;
  }
}

class BubbleShooterGame extends StatefulWidget {
  final GameSessionController controller;
  const BubbleShooterGame({super.key, required this.controller});

  @override
  State<BubbleShooterGame> createState() => _BubbleShooterGameState();
}

const List<Color> _shooterColors = [
  Color(0xFFFF8AB0), // pink
  Color(0xFF6FC3FF), // sky
  Color(0xFF6FDD9C), // mint
  Color(0xFFFFD166), // sun
  Color(0xFFB98CFF), // lilac
];

class _Fx {
  Offset pos;
  final Color color;
  double age = 0;
  final bool falling;
  double vy = 0;
  _Fx(this.pos, this.color, this.falling);
}

class _BubbleShooterGameState extends State<BubbleShooterGame>
    with
        SingleTickerProviderStateMixin<BubbleShooterGame>,
        GameLoop<BubbleShooterGame> {
  late final ShooterParams _p;
  late final HexGrid _grid;
  final _rand = Random();

  Size _size = const Size(360, 560);
  double _clock = 0;
  double _readySince = 0;

  double _aim = -pi / 2; // straight up
  int _nextColor = 0;
  bool _flying = false;
  Offset _ball = Offset.zero;
  Offset _vel = Offset.zero;
  int _ballColor = 0;

  int _total = 0;
  int _cleared = 0;
  int _shots = 0;
  final List<_Fx> _fx = [];

  double get _d => _size.width / _p.cols;
  double get _rowH => _d * 0.866;
  double get _r => _d * 0.46;
  Offset get _shooter => Offset(_size.width / 2, _size.height - _d * 0.9);

  Offset _center(int r, int c) =>
      Offset((c + (r.isEven ? 0.5 : 1.0)) * _d, r * _rowH + _d / 2 + 6);

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _p = ShooterParams.forLevel(c.level);
    _grid = HexGrid(_p.rows + 8, _p.cols);
    for (var r = 0; r < _p.rows; r++) {
      for (var col = 0; col < _grid.colsIn(r); col++) {
        _grid.cells[r][col] = _rand.nextInt(_p.colors);
      }
    }
    _total = _grid.filledCount;
    c.setUnits(0, _total);
    _pickNext();
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.bubbles),
        ms: 3000);
    startLoop();
  }

  void _pickNext() {
    final present = _grid.colorsPresent.toList();
    _nextColor = present.isEmpty ? 0 : present[_rand.nextInt(present.length)];
    _readySince = _clock;
  }

  void _setAim(Offset p) {
    if (_flying) return;
    final s = _shooter;
    final dx = p.dx - s.dx;
    final dy = p.dy - s.dy;
    var a = atan2(dy, dx);
    a = a.clamp(-pi + 0.2, -0.2).toDouble();
    setState(() => _aim = a);
  }

  void _shoot() {
    if (_flying || widget.controller.completed) return;
    final c = widget.controller;
    _shots++;
    c.recordTouch();
    c.recordResponse(((_clock - _readySince) * 1000).round());
    final speed = 780.0 * min(1.2, c.speed);
    _flying = true;
    _ball = _shooter;
    _ballColor = _nextColor;
    _vel = Offset(cos(_aim) * speed, sin(_aim) * speed);
    GameAudio.tap();
  }

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;

    // effects
    for (final f in _fx) {
      f.age += dt;
      if (f.falling) {
        f.vy += 900 * dt;
        f.pos = f.pos.translate(0, f.vy * dt);
      }
    }
    _fx.removeWhere((f) => f.age > (f.falling ? 0.9 : 0.35));

    if (_flying) {
      // two sub-steps so a fast ball can never skip through a bubble
      for (var i = 0; i < 2 && _flying; i++) {
        _ball = _ball + _vel * (dt / 2);
        if (_ball.dx < _r) {
          _ball = Offset(_r, _ball.dy);
          _vel = Offset(-_vel.dx, _vel.dy);
        } else if (_ball.dx > _size.width - _r) {
          _ball = Offset(_size.width - _r, _ball.dy);
          _vel = Offset(-_vel.dx, _vel.dy);
        }
        var hit = _ball.dy <= _r + 6;
        if (!hit) {
          outer:
          for (var r = 0; r < _grid.rows && !hit; r++) {
            for (var col = 0; col < _grid.colsIn(r); col++) {
              if (_grid.cells[r][col] >= 0 &&
                  (_center(r, col) - _ball).distance < _d * 0.86) {
                hit = true;
                break outer;
              }
            }
          }
        }
        if (hit) _land();
      }
    }
    setState(() {});
  }

  void _land() {
    _flying = false;
    final c = widget.controller;

    // nearest empty cell that touches the top or another bubble
    int? br, bc;
    var best = double.infinity;
    for (var r = 0; r < _grid.rows; r++) {
      for (var col = 0; col < _grid.colsIn(r); col++) {
        if (_grid.cells[r][col] >= 0) continue;
        final touches = r == 0 ||
            _grid.neighbors(r, col).any((n) => _grid.cells[n[0]][n[1]] >= 0);
        if (!touches) continue;
        final dist = (_center(r, col) - _ball).distance;
        if (dist < best) {
          best = dist;
          br = r;
          bc = col;
        }
      }
    }
    if (br == null || bc == null) {
      _afterShot();
      return;
    }
    _grid.cells[br][bc] = _ballColor;

    final group = _grid.cluster(br, bc);
    if (group.length >= 3) {
      for (final g in group) {
        _fx.add(_Fx(_center(g[0], g[1]), _shooterColors[_grid.cells[g[0]][g[1]]], false));
        _grid.cells[g[0]][g[1]] = -1;
      }
      var popped = group.length;
      for (final f in _grid.floating()) {
        _fx.add(_Fx(_center(f[0], f[1]), _shooterColors[_grid.cells[f[0]][f[1]]], true));
        _grid.cells[f[0]][f[1]] = -1;
        popped++;
      }
      _cleared = min(_total, _cleared + popped);
      c.setUnits(_cleared, _total);
      c.burst(_center(br, bc), popped >= 6 ? '\u{1F308}' : '\u2728');
      GameAudio.success();
      c.react(
        popped >= 5 ? CharacterState.excited : CharacterState.happy,
        CharacterLines.bubblesCatch[_shots % CharacterLines.bubblesCatch.length],
        ms: 1600,
      );
    }
    _afterShot();
  }

  void _afterShot() {
    final c = widget.controller;
    if (_grid.filledCount == 0 || _shots >= _p.shotCap) {
      c.finishLine = CharacterLines.completion(CharacterId.bubbles);
      c.react(CharacterState.celebrating,
          CharacterLines.completion(CharacterId.bubbles), ms: 4000);
      c.complete();
      stopLoop();
      return;
    }
    _pickNext();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _setAim(d.localPosition),
        onPanUpdate: (d) => _setAim(d.localPosition),
        onPanEnd: (_) => _shoot(),
        onTapDown: (d) => _setAim(d.localPosition),
        onTapUp: (_) => _shoot(),
        child: CustomPaint(
          size: _size,
          painter: _ShooterPainter(this),
        ),
      );
    });
  }
}

class _ShooterPainter extends CustomPainter {
  final _BubbleShooterGameState s;
  _ShooterPainter(this.s);

  void _bubble(Canvas canvas, Offset c, double r, Color color,
      {double scale = 1.0, double opacity = 1.0}) {
    final rr = r * scale;
    final rect = Rect.fromCircle(center: c, radius: rr);
    canvas.drawCircle(
      c,
      rr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [
            Colors.white.withValues(alpha: 0.95 * opacity),
            color.withValues(alpha: opacity),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.8 * opacity));
    // cute face
    final ink = Paint()..color = const Color(0xFF3B2F63).withValues(alpha: opacity);
    canvas.drawCircle(c.translate(-rr * 0.30, -rr * 0.05), rr * 0.09, ink);
    canvas.drawCircle(c.translate(rr * 0.30, -rr * 0.05), rr * 0.09, ink);
    canvas.drawArc(
        Rect.fromCenter(
            center: c.translate(0, rr * 0.18), width: rr * 0.46, height: rr * 0.30),
        0.2,
        pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rr * 0.08
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3B2F63).withValues(alpha: opacity));
    canvas.drawCircle(c.translate(-rr * 0.38, rr * 0.22), rr * 0.08,
        Paint()..color = const Color(0x66FF6FA5).withValues(alpha: 0.5 * opacity));
    canvas.drawCircle(c.translate(rr * 0.38, rr * 0.22), rr * 0.08,
        Paint()..color = const Color(0x66FF6FA5).withValues(alpha: 0.5 * opacity));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = s._r;

    // board bubbles
    for (var row = 0; row < s._grid.rows; row++) {
      for (var col = 0; col < s._grid.colsIn(row); col++) {
        final v = s._grid.cells[row][col];
        if (v >= 0) _bubble(canvas, s._center(row, col), r, _shooterColors[v]);
      }
    }

    // pop / fall effects
    for (final f in s._fx) {
      if (f.falling) {
        final o = (1 - f.age / 0.9).clamp(0.0, 1.0).toDouble();
        _bubble(canvas, f.pos, r, f.color, opacity: o);
      } else {
        final t = (f.age / 0.35).clamp(0.0, 1.0).toDouble();
        canvas.drawCircle(
            f.pos,
            r * (1 + 0.9 * t),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * (1 - t)
              ..color = f.color.withValues(alpha: 1 - t));
        _bubble(canvas, f.pos, r, f.color, scale: 1 - 0.8 * t, opacity: 1 - t);
      }
    }

    final sh = s._shooter;

    // aim guide
    if (!s._flying && !s.widget.controller.completed) {
      final len = size.height * 0.8 * s._p.guideFraction;
      final dir = Offset(cos(s._aim), sin(s._aim));
      for (var i = 1; i * 22 < len; i++) {
        var p = sh + dir * (i * 22.0);
        // fold the guide off the side walls so it matches the real bounce
        var x = p.dx;
        final w = size.width;
        final period = 2 * (w - 2 * r);
        var m = (x - r) % period;
        if (m < 0) m += period;
        x = r + (m <= w - 2 * r ? m : period - m);
        p = Offset(x, p.dy);
        canvas.drawCircle(
            p, 3.2, Paint()..color = Colors.white.withValues(alpha: 0.85 - i * 0.02));
      }
    }

    // flying ball
    if (s._flying) _bubble(canvas, s._ball, r, _shooterColors[s._ballColor]);

    // shooter base + next bubble
    canvas.drawCircle(sh, r * 1.25, Paint()..color = Colors.white.withValues(alpha: 0.6));
    if (!s._flying) _bubble(canvas, sh, r, _shooterColors[s._nextColor]);
  }

  @override
  bool shouldRepaint(covariant _ShooterPainter old) => true;
}
