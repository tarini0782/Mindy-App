import 'dart:math';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// PUFFY'S DAY (Twinkle). A virtual pet. Puffy, a round fluffy creature of
/// Mindy's own, shows what it needs in a thought bubble. DRAG the right item
/// from the tray onto Puffy (or just tap the item). Puffy jumps for joy.
///
///   Level  care steps  items in tray
///   1      5           3
///   2      6           3
///   3      8           4
///   4      10          4
///   5      12          5
///
/// Logged: success (right item), mistake (wrong item), response time
/// (need shown -> item given).
class Need {
  final String id;
  final String bubble;
  final String item;
  final String label;
  const Need(this.id, this.bubble, this.item, this.label);
}

const kNeeds = <Need>[
  Need('hungry', '\u{1F37D}\u{FE0F}', '\u{1F34E}', 'Food'),
  Need('thirsty', '\u{1F4A7}', '\u{1F95B}', 'Drink'),
  Need('dirty', '\u{1FAE7}', '\u{1F9FC}', 'Soap'),
  Need('sleepy', '\u{1F634}', '\u{1F6CF}\u{FE0F}', 'Bed'),
  Need('bored', '\u{1F4A4}', '\u{26BD}', 'Ball'),
];

class PetParams {
  final int steps;
  final int tray;
  const PetParams(this.steps, this.tray);
  static PetParams forLevel(int level) => PetParams(
        pickByLevel(level, 5, 6, 8, 10, 12),
        pickByLevel(level, 3, 3, 4, 4, 5),
      );
}

class PetLogic {
  /// Next need: never the same as the previous one, so every round differs.
  static Need next(Random r, Need? previous) {
    final pool = kNeeds.where((n) => n.id != previous?.id).toList();
    return pool[r.nextInt(pool.length)];
  }

  static List<Need> tray(Need need, int size, Random r) {
    final others = kNeeds.where((n) => n.id != need.id).toList()..shuffle(r);
    return [need, ...others.take(max(1, size - 1))]..shuffle(r);
  }
}

class PetCareGame extends StatefulWidget {
  final GameSessionController controller;
  const PetCareGame({super.key, required this.controller});

  @override
  State<PetCareGame> createState() => _PetCareGameState();
}

class _PetCareGameState extends State<PetCareGame>
    with SingleTickerProviderStateMixin<PetCareGame> {
  late final PetParams _p;
  final _rand = Random(71);
  late Need _need;
  late List<Need> _tray;
  int _trayN = 3;
  int _done = 0;
  bool _happy = false;
  bool _shake = false;
  DateTime _since = DateTime.now();
  late final AnimationController _bounce;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = PetParams.forLevel(_c.level);
    _trayN = _p.tray;
    _need = PetLogic.next(_rand, null);
    _tray = PetLogic.tray(_need, _trayN, _rand);
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _c.setUnits(0, _p.steps);
    _c.hintText = () => 'Puffy wants the ${_need.label.toLowerCase()}.';
    _c.onDemonstrate = () {};
    _c.onEasier = () {
      _trayN = max(2, _trayN - 1);
      setState(() => _tray = PetLogic.tray(_need, _trayN, _rand));
    };
    _c.onHarder = () => _trayN = min(6, _trayN + 1); // applies from the next round
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, "Meet Puffy! Let's look after Puffy.",
        ms: 3000);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    _bounce.dispose();
    super.dispose();
  }

  void _give(Need item) {
    if (_c.completed || _happy) return;
    _c.recordTouch();
    _c.recordResponse(DateTime.now().difference(_since).inMilliseconds);
    _since = DateTime.now();
    if (item.id != _need.id) {
      _c.recordMistake();
      GameAudio.tap();
      setState(() => _shake = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shake = false);
      });
      _c.react(CharacterState.encouraging, 'Puffy wants something else.', ms: 1500);
      return;
    }
    _c.recordSuccess();
    GameAudio.success();
    _bounce.forward(from: 0);
    setState(() {
      _happy = true;
      _done++;
    });
    _c.setUnits(_done, _p.steps);
    _c.burst(const Offset(180, 200), '\u{1F49B}');
    if (_done >= _p.steps) {
      _c.finishLine = CharacterLines.completion(CharacterId.twinkle);
      _c.complete();
      return;
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || _c.completed) return;
      setState(() {
        _need = PetLogic.next(_rand, _need);
        _tray = PetLogic.tray(_need, _trayN, _rand);
        _happy = false;
        _since = DateTime.now();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        RuleChip(
          color: const Color(0xFFAB47BC),
          text: 'Drag it to Puffy',
          icons: const [Icon(Icons.pets_rounded, color: Colors.white)],
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DragTarget<String>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) =>
                  _give(kNeeds.firstWhere((n) => n.id == details.data)),
              builder: (context, cand, _) => AnimatedBuilder(
                animation: _bounce,
                builder: (context, _) {
                  final jump = -30 * sin(_bounce.value * pi);
                  final wob = _shake ? 8.0 : 0.0;
                  return Transform.translate(
                    offset: Offset(wob, jump),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(_happy ? '\u{1F496}' : _need.bubble,
                            style: const TextStyle(fontSize: 38)),
                      ),
                      const SizedBox(height: 6),
                      AnimatedScale(
                        scale: cand.isNotEmpty ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Sprite('puffy', width: 200, height: 200),
                      ),
                    ]),
                  );
                },
              ),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            for (final n in _tray)
              Draggable<String>(
                data: n.id,
                feedback: Material(
                    color: Colors.transparent,
                    child: Text(n.item, style: const TextStyle(fontSize: 56))),
                childWhenDragging: Opacity(opacity: 0.3, child: _chip(n, false)),
                child: GestureDetector(
                  key: Key('item_${n.id}'),
                  onTap: () => _give(n),
                  child: _chip(n, cue && n.id == _need.id),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _chip(Need n, bool cue) => CueRing(
        show: cue,
        size: 84,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(n.item, style: const TextStyle(fontSize: 36)),
            Text(n.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
