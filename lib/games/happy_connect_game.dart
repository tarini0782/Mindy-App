import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/buddy.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// HAPPY CONNECT (Lumi). Tap two matching friends that can "see" each other.
///
/// Classic tile-connect, made gentle: two matching friends pair up when a path
/// of at most two bends runs between them through empty space. If the board
/// ever runs out of moves, the friends quietly shuffle themselves. After a
/// pause with no taps, a friendly glow shows a pair that can connect. No
/// timer, no lives, no penalty.
///
///   Level  board   friends
///   1      3 x 4   3 kinds
///   2      4 x 4   4 kinds
///   3      4 x 5   5 kinds
///   4      5 x 6   6 kinds
///   5      6 x 6   7 kinds (look-alike faces)
class ConnectParams {
  final int rows;
  final int cols;
  final int kinds;
  const ConnectParams(this.rows, this.cols, this.kinds);

  static ConnectParams forLevel(int level) => ConnectParams(
        pickByLevel(level, 3, 4, 4, 5, 6),
        pickByLevel(level, 4, 4, 5, 6, 6),
        pickByLevel(level, 3, 4, 5, 6, 7),
      );
}

/// Pure path logic (no Flutter) so it can be unit tested.
class ConnectLogic {
  ConnectLogic._();

  /// [g] is a PADDED board: row 0, last row, column 0 and last column are an
  /// empty border. 0 = empty, > 0 = friend kind.
  /// True if (r1,c1) and (r2,c2) are different tiles of the same kind that
  /// can be joined by a path with at most 2 turns through empty cells.
  static bool canConnect(List<List<int>> g, int r1, int c1, int r2, int c2) {
    if (r1 == r2 && c1 == c2) return false;
    if (g[r1][c1] <= 0 || g[r1][c1] != g[r2][c2]) return false;
    final rows = g.length, cols = g[0].length;
    const dr = [-1, 1, 0, 0];
    const dc = [0, 0, -1, 1];
    // best[r][c][dir] = fewest turns found so far
    final best = List.generate(
        rows, (_) => List.generate(cols, (_) => List<int>.filled(4, 99)));
    final queue = <List<int>>[];
    for (var d = 0; d < 4; d++) {
      queue.add([r1, c1, d, 0]);
      best[r1][c1][d] = 0;
    }
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final r = cur[0], c = cur[1], d = cur[2], t = cur[3];
      if (r == r2 && c == c2) return true;
      for (var nd = 0; nd < 4; nd++) {
        final nt = nd == d ? t : t + 1;
        if (nt > 2) continue;
        final nr = r + dr[nd], nc = c + dc[nd];
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final isTarget = nr == r2 && nc == c2;
        if (g[nr][nc] != 0 && !isTarget) continue;
        if (best[nr][nc][nd] <= nt) continue;
        best[nr][nc][nd] = nt;
        queue.add([nr, nc, nd, nt]);
      }
    }
    return false;
  }

  /// First connectable pair on the board, or null.
  static List<int>? findMove(List<List<int>> g) {
    final rows = g.length, cols = g[0].length;
    for (var r1 = 1; r1 < rows - 1; r1++) {
      for (var c1 = 1; c1 < cols - 1; c1++) {
        if (g[r1][c1] <= 0) continue;
        for (var r2 = r1; r2 < rows - 1; r2++) {
          for (var c2 = (r2 == r1 ? c1 + 1 : 1); c2 < cols - 1; c2++) {
            if (g[r2][c2] == g[r1][c1] && canConnect(g, r1, c1, r2, c2)) {
              return [r1, c1, r2, c2];
            }
          }
        }
      }
    }
    return null;
  }
}

class HappyConnectGame extends StatefulWidget {
  final GameSessionController controller;
  const HappyConnectGame({super.key, required this.controller});

  @override
  State<HappyConnectGame> createState() => _HappyConnectGameState();
}

const List<BuddyKind> _friendKinds = [
  BuddyKind.happy,
  BuddyKind.calm,
  BuddyKind.excited,
  BuddyKind.neutral,
  BuddyKind.mindy,
  BuddyKind.sad,
  BuddyKind.worried,
];
const List<Color> _friendTints = [
  Color(0xFFFFF4B8),
  Color(0xFFEAE2FF),
  Color(0xFFFFD9EC),
  Color(0xFFE6F6CF),
  Color(0xFFE0DAFF),
  Color(0xFFDCEBFF),
  Color(0xFFFFDDD6),
];

class _HappyConnectGameState extends State<HappyConnectGame>
    with
        SingleTickerProviderStateMixin<HappyConnectGame>,
        GameLoop<HappyConnectGame> {
  late final ConnectParams _p;
  late List<List<int>> _g; // padded logic board (0 = empty)
  late List<List<bool>> _leaving; // visual: friend is waving goodbye
  final _rand = Random();

  int? _sr, _sc; // selected tile (padded coordinates)
  List<int>? _hint;
  double _idle = 0;
  double _clock = 0;
  double _sinceResolved = 0;
  int _pairsDone = 0;
  late int _pairsTotal;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _p = ConnectParams.forLevel(c.level);
    _pairsTotal = (_p.rows * _p.cols) ~/ 2;
    _g = List.generate(_p.rows + 2, (_) => List<int>.filled(_p.cols + 2, 0));
    _leaving = List.generate(
        _p.rows + 2, (_) => List<bool>.filled(_p.cols + 2, false));

    final kinds = <int>[
      for (var i = 0; i < _pairsTotal; i++) ...[(i % _p.kinds) + 1, (i % _p.kinds) + 1],
    ]..shuffle(_rand);
    var k = 0;
    for (var r = 1; r <= _p.rows; r++) {
      for (var col = 1; col <= _p.cols; col++) {
        _g[r][col] = kinds[k++];
      }
    }
    _ensureMove(announce: false);
    c.setUnits(0, _pairsTotal);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.lumi), ms: 3000);
    startLoop();
  }

  /// Reshuffle the remaining friends until at least one pair can connect.
  void _ensureMove({required bool announce}) {
    if (ConnectLogic.findMove(_g) != null) return;
    final cells = <List<int>>[];
    final values = <int>[];
    for (var r = 1; r <= _p.rows; r++) {
      for (var col = 1; col <= _p.cols; col++) {
        if (_g[r][col] > 0) {
          cells.add([r, col]);
          values.add(_g[r][col]);
        }
      }
    }
    if (cells.length < 2) return;
    for (var attempt = 0; attempt < 80; attempt++) {
      values.shuffle(_rand);
      for (var i = 0; i < cells.length; i++) {
        _g[cells[i][0]][cells[i][1]] = values[i];
      }
      if (ConnectLogic.findMove(_g) != null) break;
    }
    _sr = _sc = null;
    if (announce) {
      widget.controller.react(
          CharacterState.encouraging, 'The friends are mixing places!',
          ms: 2200);
    }
  }

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;
    _idle += dt;
    _sinceResolved += dt;
    // Gentle assistance after a quiet moment.
    if (_idle > 10 && _hint == null && _pairsDone < _pairsTotal) {
      _hint = ConnectLogic.findMove(_g);
    }
    setState(() {});
  }

  void _tap(int r, int col) {
    final c = widget.controller;
    if (_g[r][col] <= 0 || c.completed) return;
    _idle = 0;
    _hint = null;
    GameAudio.tap();

    if (_sr == null) {
      setState(() {
        _sr = r;
        _sc = col;
      });
      return;
    }
    final r1 = _sr!, c1 = _sc!;
    if (r1 == r && c1 == col) {
      setState(() => _sr = _sc = null); // tap again to put it down
      return;
    }

    if (ConnectLogic.canConnect(_g, r1, c1, r, col)) {
      c.recordSuccess();
      c.recordResponse((_sinceResolved * 1000).round());
      _sinceResolved = 0;
      _leaving[r1][c1] = true;
      _leaving[r][col] = true;
      _g[r1][c1] = 0;
      _g[r][col] = 0;
      _sr = _sc = null;
      _pairsDone++;
      c.setUnits(_pairsDone, _pairsTotal);
      GameAudio.success();
      c.burst(Offset(_tileCenterX(col), _tileCenterY(r)), '\u{1F49B}');
      c.react(
        CharacterState.celebrating,
        CharacterLines.lumiMatch[_pairsDone % CharacterLines.lumiMatch.length],
        ms: 1600,
      );
      c.schedule(450, () {
        if (!mounted) return;
        setState(() {
          _leaving[r1][c1] = false;
          _leaving[r][col] = false;
        });
      });
      if (_pairsDone >= _pairsTotal) {
        c.finishLine = CharacterLines.completion(CharacterId.lumi);
        c.schedule(900, () {
          if (mounted) c.complete();
        });
      } else {
        _ensureMove(announce: true);
      }
      setState(() {});
    } else {
      c.recordMistake();
      c.react(CharacterState.encouraging, 'Almost! Try another friend.', ms: 1800);
      setState(() {
        _sr = r;
        _sc = col;
      });
    }
  }

  // Approximate burst position (set properly in build via _tile geometry).
  double _tile = 60;
  double _padX = 0, _padY = 0;
  double _tileCenterX(int col) => _padX + (col - 1) * _tile + _tile / 2;
  double _tileCenterY(int r) => _padY + (r - 1) * _tile + _tile / 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 6.0;
      final w = (box.maxWidth - 24 - gap * (_p.cols - 1)) / _p.cols;
      final h = (box.maxHeight - 16 - gap * (_p.rows - 1)) / _p.rows;
      final t = max(36.0, min(min(w, h), 96.0));
      _tile = t + gap;
      _padX = (box.maxWidth - (_p.cols * _tile - gap)) / 2;
      _padY = (box.maxHeight - (_p.rows * _tile - gap)) / 2;
      final pulse = 0.5 + 0.5 * sin(_clock * 4);

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 1; r <= _p.rows; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r == _p.rows ? 0 : gap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var col = 1; col <= _p.cols; col++)
                      Padding(
                        padding: EdgeInsets.only(right: col == _p.cols ? 0 : gap),
                        child: _tileWidget(r, col, t, pulse),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _tileWidget(int r, int col, double size, double pulse) {
    final kind = _g[r][col];
    final leaving = _leaving[r][col];
    if (kind <= 0 && !leaving) {
      return SizedBox(width: size, height: size);
    }
    final selected = _sr == r && _sc == col;
    final hinted = _hint != null &&
        ((_hint![0] == r && _hint![1] == col) ||
            (_hint![2] == r && _hint![3] == col));
    // A leaving tile remembers nothing about its kind, so show a sparkle.
    if (kind <= 0) {
      return SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: const Duration(milliseconds: 400),
          builder: (_, v, __) => Opacity(
            opacity: v,
            child: Transform.scale(
              scale: 1 + (1 - v) * 0.6,
              child: const Center(
                  child: Text('\u2728', style: TextStyle(fontSize: 30))),
            ),
          ),
        ),
      );
    }
    final idx = (kind - 1) % _friendKinds.length;
    return GestureDetector(
      onTap: () => _tap(r, col),
      child: AnimatedScale(
        scale: selected ? 1.12 : (hinted ? 1.0 + 0.06 * pulse : 1.0),
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _friendTints[idx],
            borderRadius: BorderRadius.circular(size * 0.26),
            border: Border.all(
              color: selected
                  ? const Color(0xFF2B2350)
                  : (hinted ? const Color(0xFFFFB300) : Colors.white),
              width: selected || hinted ? 4 : 3,
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: FittedBox(
              fit: BoxFit.contain,
              child: BuddyWidget(
                  kind: _friendKinds[idx], size: 100, animated: false),
            ),
          ),
        ),
      ),
    );
  }
}
