import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import '../characters/mindy_character.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';

/// WORLD 6 -- DRAGON VALLEY (Pip): "CALM MAZE". Exploration / navigation,
/// the second emotion-regulation activity.
///
/// The child guides Pip (tap a spot, or drag) through a peaceful valley to
/// collect treasure. No enemies, no losing, no countdown, no hazards.
///
///   Level  map          guidance
///   1      small, one winding path     glowing trail to the next treasure
///   2      a bit longer                glowing trail
///   3      more turns                  small hint sparkles only
///   4      branching paths             no trail
///   5      many exploration choices    no trail
///
/// ---------------------------------------------------------------------------
/// v37 REBUILD. Three things were actually wrong, not just plain:
///
///   1. The visual language was inverted. Walls were drawn as bright green
///      mounds and the path as pale beige. Green reads as grass you may walk
///      on; the child could not tell route from obstacle at a glance.
///      Now: the path is a lit, CONNECTED ribbon and the walls are dark
///      woodland. Light on dark, and the route joins up instead of being a
///      row of separate tiles.
///   2. A real performance bug. `_trail()` ran a full breadth-first search
///      for EVERY uncollected treasure, inside `build`, and `onFrame` called
///      `setState` on every frame -- so at level 5 that was six BFS sweeps
///      sixty times a second. The trail is now cached and recomputed only
///      when Pip reaches a new cell or a treasure is collected.
///   3. Nothing in it was calming except the absence of a timer. There are
///      now drifting fireflies and a glow under each lantern.
///
/// NOT changed, deliberately: the maps, the level-to-guidance mapping, the
/// walking speed, the events recorded, or the activity's role. This is one
/// of only three `ActivityRole.regulation` activities, so it is what the
/// safety rule falls back to when a check-in is scared, sad or skipped, and
/// it is a member of the nine-activity study pool. Its slot has to stay.
class TreasureJourneyGame extends StatefulWidget {
  final GameSessionController controller;
  const TreasureJourneyGame({super.key, required this.controller});

  @override
  State<TreasureJourneyGame> createState() => _TreasureJourneyGameState();
}

/// Hand-authored maps, checked so every treasure is reachable.
///   S start   # hill (blocked)   . path   * star   r rainbow piece
///   g gem     f flower
class TreasureMaps {
  TreasureMaps._();

  static const Map<int, List<String>> maps = {
    1: [
      'S.*.#',
      '###.#',
      '#g..#',
      '#.###',
      '#.f.#',
      '#####',
    ],
    2: [
      'S.f.#',
      '###.#',
      '#*..#',
      '#.###',
      '#...#',
      '###r#',
      '#g..#',
    ],
    3: [
      'S.#.f.',
      '#.#.#.',
      '#.*.#g',
      '#.###.',
      '#.r...',
      '#.###.',
      '#..f.*',
    ],
    4: [
      'S..#...f',
      '#.#.#.##',
      '#.*.....',
      '#.###.#g',
      '#.#r..#.',
      '#.#.#.##',
      '#f..#*..',
      '###.##g.',
    ],
    5: [
      'S.....#.',
      '.###.#..',
      '.#*.*..#',
      '.#.###.r',
      'f..#g..#',
      '##.#.#.#',
      'g..*.#f.',
      '#.##....',
    ],
  };

  static List<String> forLevel(int level) => maps[level.clamp(1, 5).toInt()]!;

  static const String treasureChars = '*rgf';

  static const Map<String, String> emoji = {
    '*': '⭐',
    'r': '\u{1F308}',
    'g': '\u{1F48E}',
    'f': '\u{1F338}',
  };
}

class _Firefly {
  double x, y, phase, speed, size;
  _Firefly(this.x, this.y, this.phase, this.speed, this.size);
}

class _TreasureJourneyGameState extends State<TreasureJourneyGame>
    with
        SingleTickerProviderStateMixin<TreasureJourneyGame>,
        GameLoop<TreasureJourneyGame> {
  late final List<String> _map;
  late final int _rows;
  late final int _cols;
  late final int _guidance; // 2 trail, 1 hints, 0 none
  late final double _walkSpeed; // cells per second
  late final Set<Point<int>> _treasures;
  late int _totalTreasures;
  int _collected = 0;

  // Pip's position in (fractional) cell coordinates: x = col, y = row.
  double _px = 0, _py = 0;
  final List<Point<int>> _path = [];
  bool _facingLeft = false;
  double _clock = 0;
  double _idle = 0; // seconds since the child last touched the screen
  bool _assisted = false; // gentle help is showing
  Size _size = const Size(300, 400);

  // Ambience. Positions are in fractions of the play area, so they survive
  // a resize without being recomputed.
  late final List<_Firefly> _flies;

  // Cached guidance trail. Recomputing this every frame was the old
  // performance bug; it is now rebuilt only when `_trailKey` changes.
  List<Point<int>> _trailCache = const [];
  Point<int>? _trailFrom;
  int _trailTreasures = -1;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _map = TreasureMaps.forLevel(c.level);
    _rows = _map.length;
    _cols = _map.first.length;
    _guidance = c.byLevel(2, 2, 1, 0, 0);
    _walkSpeed = 3.0 * c.speed;
    _treasures = {};
    for (var r = 0; r < _rows; r++) {
      for (var col = 0; col < _cols; col++) {
        final ch = _map[r][col];
        if (ch == 'S') {
          _px = col.toDouble();
          _py = r.toDouble();
        } else if (TreasureMaps.treasureChars.contains(ch)) {
          _treasures.add(Point(col, r));
        }
      }
    }
    _totalTreasures = _treasures.length;

    final rand = Random(19);
    _flies = [
      for (var i = 0; i < 14; i++)
        _Firefly(rand.nextDouble(), rand.nextDouble(),
            rand.nextDouble() * pi * 2, 0.12 + rand.nextDouble() * 0.18,
            1.6 + rand.nextDouble() * 1.8)
    ];

    c.setUnits(0, _totalTreasures);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.pip),
        ms: 3200);
    startLoop();
  }

  bool _walkable(int col, int row) =>
      row >= 0 && row < _rows && col >= 0 && col < _cols && _map[row][col] != '#';

  /// Breadth-first path from [from] to [to] (excluding [from]). Empty if
  /// unreachable.
  List<Point<int>> _bfs(Point<int> from, Point<int> to) {
    if (from == to) return [];
    final prev = <Point<int>, Point<int>>{};
    final seen = <Point<int>>{from};
    final q = Queue<Point<int>>()..add(from);
    while (q.isNotEmpty) {
      final p = q.removeFirst();
      for (final d in const [
        Point(1, 0),
        Point(-1, 0),
        Point(0, 1),
        Point(0, -1)
      ]) {
        final n = Point<int>(p.x + d.x, p.y + d.y);
        if (!_walkable(n.x, n.y) || seen.contains(n)) continue;
        seen.add(n);
        prev[n] = p;
        if (n == to) {
          final out = <Point<int>>[];
          Point<int>? cur = n;
          while (cur != null && cur != from) {
            out.add(cur);
            cur = prev[cur];
          }
          return out.reversed.toList();
        }
        q.add(n);
      }
    }
    return [];
  }

  void _target(Offset local, {bool fromDrag = false}) {
    final cs = _cellSize;
    final col = ((local.dx - _origin.dx) / cs).floor();
    final row = ((local.dy - _origin.dy) / cs).floor();
    if (!_walkable(col, row)) return;
    final here = _nearestCell();
    final p = _bfs(here, Point(col, row));
    if (p.isEmpty && here != Point(col, row)) return;
    _idle = 0;
    _assisted = false;
    if (!fromDrag) widget.controller.recordTouch();
    _path
      ..clear()
      ..addAll(p);
  }

  Point<int> _nearestCell() => Point(_px.round(), _py.round());

  double get _cellSize => min(_size.width / _cols, _size.height / _rows);
  Offset get _origin => Offset((_size.width - _cellSize * _cols) / 2,
      (_size.height - _cellSize * _rows) / 2);

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;
    _idle += dt;

    // Gentle assistance: if the child has not touched the screen for a
    // while, Pip suggests the way. Never a penalty, just a friendly nudge.
    if (_idle > 12 && !_assisted && _path.isEmpty) {
      _assisted = true;
      c.react(CharacterState.encouraging,
          "Let's follow the glowing path together.",
          ms: 3500);
    }

    if (_path.isNotEmpty) {
      final next = _path.first;
      final dx = next.x - _px, dy = next.y - _py;
      final dist = sqrt(dx * dx + dy * dy);
      final step = _walkSpeed * dt;
      if (dx.abs() > 0.01) _facingLeft = dx < 0;
      if (dist <= step) {
        _px = next.x.toDouble();
        _py = next.y.toDouble();
        _path.removeAt(0);
        _arrived(next);
      } else {
        _px += dx / dist * step;
        _py += dy / dist * step;
      }
    }
    setState(() {});
  }

  void _arrived(Point<int> cell) {
    if (!_treasures.remove(cell)) return;
    final c = widget.controller;
    _collected++;
    c.recordTouch();
    c.setUnits(_collected, _totalTreasures);
    final ch = _map[cell.y][cell.x];
    final cs = _cellSize;
    c.burst(
        Offset(_origin.dx + (cell.x + 0.5) * cs,
            _origin.dy + (cell.y + 0.5) * cs),
        TreasureMaps.emoji[ch] ?? '⭐');
    GameAudio.success();
    c.react(CharacterState.excited,
        CharacterLines.pipFind[_collected % CharacterLines.pipFind.length],
        ms: 1800);
    if (_collected >= _totalTreasures) {
      c.finishLine = CharacterLines.completion(CharacterId.pip);
      c.react(CharacterState.celebrating,
          CharacterLines.completion(CharacterId.pip),
          ms: 4000);
      c.complete();
      stopLoop();
      setState(() {});
    }
  }

  /// Nearest uncollected treasure by walking distance (for the glowing
  /// trail). Cached: this used to run once per treasure per frame.
  List<Point<int>> _trail() {
    final here = _nearestCell();
    if (_trailFrom == here && _trailTreasures == _treasures.length) {
      return _trailCache;
    }
    _trailFrom = here;
    _trailTreasures = _treasures.length;
    if (_treasures.isEmpty) {
      return _trailCache = const [];
    }
    List<Point<int>> best = const [];
    for (final t in _treasures) {
      final p = _bfs(here, t);
      if (p.isEmpty) continue;
      if (best.isEmpty || p.length < best.length) best = p;
    }
    return _trailCache = best;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final cs = _cellSize;
      final o = _origin;
      final guidance = _assisted ? 2 : _guidance;
      final trail = guidance == 0 ? const <Point<int>>[] : _trail();
      final shown = guidance == 2
          ? trail
          : (guidance == 1 ? trail.take(2).toList() : const <Point<int>>[]);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _target(d.localPosition),
        onPanUpdate: (d) => _target(d.localPosition, fromDrag: true),
        child: Stack(
          children: [
            // The valley itself: backdrop, connected path ribbon, woodland.
            // Static, so it repaints only when the layout changes.
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ValleyPainter(map: _map, cell: cs, origin: o),
                ),
              ),
            ),
            // Soft pools of light under the lanterns still to be found.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlowPainter(
                      treasures: _treasures.toList(growable: false),
                      cell: cs,
                      origin: o,
                      clock: _clock),
                ),
              ),
            ),
            // glowing guidance
            for (final p in shown)
              Positioned(
                left: o.dx + (p.x + 0.5) * cs - 7,
                top: o.dy + (p.y + 0.5) * cs - 7,
                child: IgnorePointer(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFE066).withValues(
                          alpha:
                              0.55 + 0.35 * sin(_clock * 3 + p.x + p.y)),
                    ),
                  ),
                ),
              ),
            // treasures
            for (final t in _treasures)
              Positioned(
                left: o.dx + t.x * cs,
                top: o.dy + t.y * cs - 2 * sin(_clock * 3 + t.x),
                width: cs,
                height: cs,
                child: IgnorePointer(
                  child: Center(
                    child: Text(TreasureMaps.emoji[_map[t.y][t.x]] ?? '⭐',
                        style: TextStyle(fontSize: cs * 0.62, height: 1.0)),
                  ),
                ),
              ),
            // Pip
            Positioned(
              left: o.dx + _px * cs - cs * 0.1,
              top: o.dy + _py * cs - cs * 0.28,
              width: cs * 1.2,
              height: cs * 1.3,
              child: IgnorePointer(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(_facingLeft ? -1.0 : 1.0, 1.0, 1.0, 1.0),
                  child: MindyCharacter(
                    id: CharacterId.pip,
                    state:
                        _path.isEmpty ? CharacterState.idle : CharacterState.happy,
                    size: cs * 1.2,
                  ),
                ),
              ),
            ),
            // Fireflies drift over everything. Ambience only -- nothing here
            // is a target and nothing here can be tapped.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FireflyPainter(flies: _flies, clock: _clock),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// The valley floor.
///
/// Walkable cells are painted as one CONNECTED ribbon: each cell is drawn,
/// then a bridge is drawn into its walkable right and lower neighbours, so
/// the route joins into a continuous lit path instead of a grid of separate
/// tiles. Blocked cells become dark woodland drawn on top, so their canopies
/// overlap the path edge and the two layers read as foreground and
/// background rather than as two kinds of tile.
class _ValleyPainter extends CustomPainter {
  final List<String> map;
  final double cell;
  final Offset origin;
  _ValleyPainter({required this.map, required this.cell, required this.origin});

  bool _open(int r, int c) =>
      r >= 0 && r < map.length && c >= 0 && c < map[r].length && map[r][c] != '#';

  Rect _rect(int r, int c) =>
      Rect.fromLTWH(origin.dx + c * cell, origin.dy + r * cell, cell, cell);

  /// One pass of the ribbon: every open cell plus bridges to its open right
  /// and lower neighbours, at the given inset.
  void _ribbon(Canvas canvas, double inset, double radius, Paint paint) {
    for (var r = 0; r < map.length; r++) {
      for (var c = 0; c < map[r].length; c++) {
        if (!_open(r, c)) continue;
        final here = _rect(r, c);
        canvas.drawRRect(
            RRect.fromRectAndRadius(here.deflate(inset), Radius.circular(radius)),
            paint);
        if (_open(r, c + 1)) {
          canvas.drawRect(
              Rect.fromLTRB(here.center.dx, here.top + inset,
                  here.right + cell / 2, here.bottom - inset),
              paint);
        }
        if (_open(r + 1, c)) {
          canvas.drawRect(
              Rect.fromLTRB(here.left + inset, here.center.dy,
                  here.right - inset, here.bottom + cell / 2),
              paint);
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;

    // Dusk wash behind the whole play area.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B4F49), Color(0xFF1E3B39)],
        ).createShader(full),
    );

    // The path: a warm edge, then a lit core inside it.
    _ribbon(canvas, cell * 0.10, cell * 0.30,
        Paint()..color = const Color(0xFFC9A96B));
    _ribbon(canvas, cell * 0.17, cell * 0.26,
        Paint()..color = const Color(0xFFF4DFB0));

    // Woodland over the blocked cells.
    final trunk = Paint()..color = const Color(0xFF1B3A38);
    final canopy = Paint()..color = const Color(0xFF2F6B55);
    final canopyLit = Paint()..color = const Color(0xFF3E8566);
    for (var r = 0; r < map.length; r++) {
      for (var c = 0; c < map[r].length; c++) {
        if (_open(r, c)) continue;
        final rect = _rect(r, c);
        final ctr = rect.center;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                rect.inflate(cell * 0.02), Radius.circular(cell * 0.22)),
            trunk);
        canvas.drawCircle(
            ctr.translate(-cell * 0.16, cell * 0.10), cell * 0.27, canopy);
        canvas.drawCircle(
            ctr.translate(cell * 0.18, cell * 0.14), cell * 0.23, canopy);
        canvas.drawCircle(
            ctr.translate(cell * 0.02, -cell * 0.14), cell * 0.28, canopyLit);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ValleyPainter old) =>
      old.cell != cell || old.origin != origin || old.map != map;
}

/// A slow pool of lantern light under every treasure still to be found.
class _GlowPainter extends CustomPainter {
  final List<Point<int>> treasures;
  final double cell;
  final Offset origin;
  final double clock;
  _GlowPainter(
      {required this.treasures,
      required this.cell,
      required this.origin,
      required this.clock});

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in treasures) {
      final c = Offset(
          origin.dx + (t.x + 0.5) * cell, origin.dy + (t.y + 0.5) * cell);
      final pulse = 0.78 + 0.22 * sin(clock * 1.6 + t.x * 1.3 + t.y);
      final radius = cell * 0.78 * pulse;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0x59FFE9A8), Color(0x00FFE9A8)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.clock != clock ||
      old.cell != cell ||
      old.origin != origin ||
      old.treasures.length != treasures.length;
}

/// Drifting fireflies. Ambience only; they are never targets.
class _FireflyPainter extends CustomPainter {
  final List<_Firefly> flies;
  final double clock;
  _FireflyPainter({required this.flies, required this.clock});

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in flies) {
      final x = (f.x + sin(clock * f.speed + f.phase) * 0.06) * size.width;
      final y = (f.y + cos(clock * f.speed * 0.8 + f.phase) * 0.05) *
          size.height;
      final a = 0.30 + 0.45 * (0.5 + 0.5 * sin(clock * 2.1 + f.phase));
      final p = Offset(x, y);
      canvas.drawCircle(
          p, f.size * 2.6, Paint()..color = Color.fromRGBO(255, 240, 170, a * 0.22));
      canvas.drawCircle(
          p, f.size, Paint()..color = Color.fromRGBO(255, 247, 200, a));
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter old) => old.clock != clock;
}
