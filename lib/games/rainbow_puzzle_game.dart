import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';

/// WORLD 5 -- RAINBOW KINGDOM (Kara). Drag / arrange.
///
/// A magical scene has empty spots. The child drags pieces from the tray
/// into the right spots. Calm problem solving: no timer, no penalty. A
/// piece dropped in the wrong spot just slides back to the tray.
///
///   Level  pieces  extras
///   1      3       -
///   2      4       -
///   3      5       -
///   4      6       two clouds (either cloud fits either spot)
///   5      8       look-alike pieces (flower/blossom, star/glow star)
class RainbowPuzzleGame extends StatefulWidget {
  final GameSessionController controller;
  const RainbowPuzzleGame({super.key, required this.controller});

  @override
  State<RainbowPuzzleGame> createState() => _RainbowPuzzleGameState();
}

class PuzzleSlot {
  final String emoji;
  final double x; // 0..1 across the scene
  final double y; // 0..1 down the scene
  final double scale;
  const PuzzleSlot(this.emoji, this.x, this.y, {this.scale = 1.0});
}

/// Pure data (testable): the scene for each level.
class PuzzleScenes {
  PuzzleScenes._();

  static const List<PuzzleSlot> _master = [
    PuzzleSlot('\u{1F308}', 0.50, 0.20, scale: 1.5), // rainbow
    PuzzleSlot('\u2601\uFE0F', 0.18, 0.13), // cloud
    PuzzleSlot('\u{1F984}', 0.50, 0.62, scale: 1.3), // unicorn
    PuzzleSlot('\u{1F338}', 0.20, 0.72), // flower
    PuzzleSlot('\u2B50', 0.84, 0.12), // star
    PuzzleSlot('\u2601\uFE0F', 0.82, 0.34), // second cloud
    PuzzleSlot('\u{1F33C}', 0.80, 0.74), // blossom (looks like the flower)
    PuzzleSlot('\u{1F31F}', 0.50, 0.42), // glow star (looks like the star)
  ];

  static int pieceCount(int level) {
    switch (level) {
      case 1:
        return 3;
      case 2:
        return 4;
      case 3:
        return 5;
      case 4:
        return 6;
      default:
        return 8;
    }
  }

  static List<PuzzleSlot> forLevel(int level) =>
      _master.take(pieceCount(level)).toList();
}

class _RainbowPuzzleGameState extends State<RainbowPuzzleGame> {
  late final List<PuzzleSlot> _slots;
  late final List<bool> _filled; // slot filled?
  late List<int> _tray; // indices of pieces still in the tray
  final Map<int, int> _placedBy = {}; // slot -> piece
  int _placed = 0;
  final Stopwatch _think = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _slots = PuzzleScenes.forLevel(c.level);
    _filled = List<bool>.filled(_slots.length, false);
    // Tray order is a fixed scramble so runs are reproducible.
    final order = List<int>.generate(_slots.length, (i) => i);
    order.sort((a, b) => ((a * 7 + 3) % 11).compareTo((b * 7 + 3) % 11));
    _tray = order;
    c.setUnits(0, _slots.length);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.kara), ms: 3000);
  }

  /// A piece fits a spot when the emoji is the same and the spot is free.
  bool _fits(int piece, int slot) =>
      !_filled[slot] && _slots[piece].emoji == _slots[slot].emoji;

  void _drop(int piece, int slot) {
    final c = widget.controller;
    c.recordTouch();
    if (_fits(piece, slot)) {
      setState(() {
        _filled[slot] = true;
        _placedBy[slot] = piece;
        _tray.remove(piece);
        _placed++;
      });
      final ms = _think.elapsedMilliseconds;
      if (ms < 60000) c.recordResponse(ms);
      _think
        ..reset()
        ..start();
      c.recordSuccess();
      c.setUnits(_placed, _slots.length);
      GameAudio.success();
      c.react(
        CharacterState.celebrating,
        CharacterLines.karaPlace[_placed % CharacterLines.karaPlace.length],
        ms: 1800,
      );
      if (_placed >= _slots.length) {
        c.finishLine = CharacterLines.completion(CharacterId.kara);
        c.schedule(1000, () {
          if (mounted) c.complete();
        });
      }
    } else {
      c.recordMistake();
      GameAudio.tap();
      c.react(CharacterState.encouraging, CharacterLines.karaTryAgain, ms: 2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final many = _slots.length >= 6;
    final slotSize = many ? 64.0 : 78.0;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFD7ECFF), Color(0xFFFFE3F3), Color(0xFFCBF1D0)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: LayoutBuilder(builder: (context, box) {
              return Stack(
                children: [
                  for (var s = 0; s < _slots.length; s++)
                    Positioned(
                      left: _slots[s].x * box.maxWidth - slotSize * _slots[s].scale / 2,
                      top: _slots[s].y * box.maxHeight - slotSize * _slots[s].scale / 2,
                      child: _slotWidget(s, slotSize),
                    ),
                ],
              );
            }),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final p in _tray) _pieceWidget(p, many ? 56.0 : 66.0),
              if (_tray.isEmpty)
                Text('\u{1F308} Complete!', style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
        SizedBox(height: c.level >= 4 ? 2 : 6),
      ],
    );
  }

  Widget _slotWidget(int s, double size) {
    final slot = _slots[s];
    final box = size * slot.scale;
    return DragTarget<int>(
      onAcceptWithDetails: (details) => _drop(details.data, s),
      builder: (context, candidate, rejected) {
        final hover = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _filled[s]
                ? Colors.transparent
                : (hover ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF)),
            borderRadius: BorderRadius.circular(box * 0.28),
            border: _filled[s]
                ? null
                : Border.all(
                    color: hover ? const Color(0xFFBA68C8) : Colors.white,
                    width: 3,
                  ),
          ),
          child: _filled[s]
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, t, child) =>
                      Transform.scale(scale: t, child: child),
                  child: Text(slot.emoji,
                      style: TextStyle(fontSize: box * 0.72, height: 1.0)),
                )
              : Opacity(
                  opacity: 0.22,
                  child: Text(slot.emoji,
                      style: TextStyle(fontSize: box * 0.62, height: 1.0)),
                ),
        );
      },
    );
  }

  Widget _pieceWidget(int piece, double size) {
    final emoji = _slots[piece].emoji;
    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBA68C8), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x22BA68C8), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.6, height: 1.0)),
    );
    return Draggable<int>(
      data: piece,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(scale: 1.25, child: face),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: face),
      child: face,
    );
  }
}
