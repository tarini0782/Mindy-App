import 'dart:math';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// TEDDY CLINIC (Kara). Pretend play: Teddy and friends come to the toy
/// clinic. Look at what the patient needs and pick the right helper from the
/// tray. At higher levels there are TWO steps and the ORDER matters.
/// This is play, not medical advice: the tools are friendly and nothing is
/// scary. It also familiarises children with ordinary clinic objects.
///
///   Level  patients  tools in tray  steps per patient
///   1      4         3              1
///   2      5         3              1
///   3      6         4              1
///   4      7         4              2
///   5      8         5              2
///
/// Logged: success (right tool at the right step), mistake (wrong tool or
/// wrong order), response time (previous tap or patient shown -> tap).
class Tool {
  final String id;
  final String emoji;
  final String label;
  const Tool(this.id, this.emoji, this.label);
}

const kTools = <Tool>[
  Tool('thermometer', '\u{1F321}\u{FE0F}', 'Thermometer'),
  Tool('plaster', '\u{1FA79}', 'Plaster'),
  Tool('stethoscope', '\u{1FA7A}', 'Listening tube'),
  Tool('toothbrush', '\u{1FAA5}', 'Toothbrush'),
  Tool('bed', '\u{1F6CF}\u{FE0F}', 'Cosy bed'),
  Tool('apple', '\u{1F34E}', 'Apple'),
  Tool('water', '\u{1F4A7}', 'Water'),
  Tool('soap', '\u{1F9FC}', 'Soap'),
];

class ClinicCase {
  final String patient; // emoji
  final String problem; // what the child sees / reads
  final List<String> steps1; // one-step plan
  final List<String> steps2; // two-step plan (order matters)
  const ClinicCase(this.patient, this.problem, this.steps1, this.steps2);
}

const kCases = <ClinicCase>[
  ClinicCase('\u{1F9F8}', 'Teddy feels warm.', ['thermometer'], ['thermometer', 'water']),
  ClinicCase('\u{1F430}', 'Bunny has a scraped paw.', ['plaster'], ['soap', 'plaster']),
  ClinicCase('\u{1F43B}', 'Bear wants a check-up.', ['stethoscope'], ['stethoscope', 'apple']),
  ClinicCase('\u{1F984}', 'Unicorn has sticky teeth.', ['toothbrush'], ['toothbrush', 'water']),
  ClinicCase('\u{1F43C}', 'Panda is very sleepy.', ['bed'], ['water', 'bed']),
  ClinicCase('\u{1F98A}', 'Fox has a rumbly tummy.', ['apple'], ['water', 'apple']),
];

class ClinicParams {
  final int patients;
  final int tools;
  final int steps;
  const ClinicParams(this.patients, this.tools, this.steps);

  static ClinicParams forLevel(int level) => ClinicParams(
        pickByLevel(level, 4, 5, 6, 7, 8),
        pickByLevel(level, 3, 3, 4, 4, 5),
        pickByLevel(level, 1, 1, 1, 2, 2),
      );
}

class ClinicLogic {
  static ClinicCase caseFor(int n) => kCases[n % kCases.length];

  static List<String> plan(ClinicCase c, int steps) =>
      steps >= 2 ? c.steps2 : c.steps1;

  /// The tray for the current step: every tool the plan needs next, padded
  /// with other tools. Always contains the correct tool.
  static List<Tool> tray(List<String> plan, int step, int size, Random r) {
    final need = kTools.firstWhere((t) => t.id == plan[step]);
    final others = kTools.where((t) => t.id != need.id).toList()..shuffle(r);
    final out = <Tool>[need, ...others.take(max(1, size - 1))]..shuffle(r);
    return out;
  }
}

class TeddyClinicGame extends StatefulWidget {
  final GameSessionController controller;
  const TeddyClinicGame({super.key, required this.controller});

  @override
  State<TeddyClinicGame> createState() => _TeddyClinicGameState();
}

class _TeddyClinicGameState extends State<TeddyClinicGame> {
  late final ClinicParams _p;
  final _rand = Random(29);
  int _patient = 0;
  int _step = 0;
  int _trayN = 3;
  late List<Tool> _tray;
  DateTime _since = DateTime.now();
  bool _better = false; // brief "all better" state
  bool _wrongFlash = false;

  GameSessionController get _c => widget.controller;
  ClinicCase get _case => ClinicLogic.caseFor(_patient);
  List<String> get _plan => ClinicLogic.plan(_case, _p.steps);
  String get _need => _plan[_step];

  @override
  void initState() {
    super.initState();
    _p = ClinicParams.forLevel(_c.level);
    _trayN = _p.tools;
    _tray = ClinicLogic.tray(_plan, _step, _trayN, _rand);
    _c.setUnits(0, _p.patients);
    _c.hintText = () {
      final t = kTools.firstWhere((t) => t.id == _need);
      return 'Try the ${t.label.toLowerCase()}.';
    };
    _c.onDemonstrate = () {};
    _c.onEasier = () {
      _trayN = max(2, _trayN - 1);
      setState(() => _tray = ClinicLogic.tray(_plan, _step, _trayN, _rand));
    };
    _c.onHarder = () => _trayN = min(6, _trayN + 1); // applies from the next step
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, 'The toy clinic is open!', ms: 3000);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    super.dispose();
  }

  void _pick(Tool t) {
    if (_c.completed || _better) return;
    _c.recordTouch();
    _c.recordResponse(DateTime.now().difference(_since).inMilliseconds);
    _since = DateTime.now();
    if (t.id != _need) {
      _c.recordMistake();
      GameAudio.tap();
      setState(() => _wrongFlash = true);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _wrongFlash = false);
      });
      _c.react(CharacterState.encouraging,
          _p.steps > 1 ? 'Hmm, think about the order.' : 'Not that one. Try another!',
          ms: 1600);
      return;
    }
    _c.recordSuccess();
    GameAudio.success();
    if (_step + 1 < _plan.length) {
      setState(() {
        _step++;
        _tray = ClinicLogic.tray(_plan, _step, _trayN, _rand);
      });
      _c.react(CharacterState.happy, 'Good! What comes next?', ms: 1400);
      return;
    }
    // patient treated
    setState(() => _better = true);
    _c.burst(const Offset(180, 160), '\u{1F49A}');
    final done = _patient + 1;
    _c.setUnits(done, _p.patients);
    if (done >= _p.patients) {
      _c.finishLine = CharacterLines.completion(CharacterId.kara);
      _c.complete();
      return;
    }
    _c.react(CharacterState.celebrating, 'All better! Thank you, doctor!', ms: 1300);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || _c.completed) return;
      setState(() {
        _patient++;
        _step = 0;
        _better = false;
        _tray = ClinicLogic.tray(_plan, _step, _trayN, _rand);
        _since = DateTime.now();
      });
    });
  }

  Widget _patientView(String emoji, bool better) {
    final sprite = Sprite.fromEmoji[emoji] ??
        (emoji == '\u{1F430}' ? 'host_bubbles' : emoji == '\u{1F984}' ? 'host_kara' : null);
    return AnimatedScale(
      scale: better ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: sprite != null
          ? Sprite(sprite, width: 110, height: 110)
          : Text(emoji, style: const TextStyle(fontSize: 84)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value);
    final c = _case;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        RuleChip(
          color: const Color(0xFF26A69A),
          text: _p.steps > 1
              ? 'Step ${_step + 1} of ${_plan.length}'
              : 'Help the patient',
          icons: const [Icon(Icons.local_hospital_rounded, color: Colors.white)],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _better
                    ? const Color(0xFFC8E6C9)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: _wrongFlash ? Colors.orange : Colors.transparent,
                    width: 4),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _patientView(c.patient, _better),
                const SizedBox(height: 6),
                Text(_better ? 'All better!' : c.problem,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                if (_p.steps > 1 && !_better)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'Plan: ${_plan.map((id) => kTools.firstWhere((t) => t.id == id).emoji).join('  \u{2192}  ')}',
                        style: const TextStyle(fontSize: 22)),
                  ),
              ]),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in _tray)
              GestureDetector(
                key: Key('tool_${t.id}'),
                onTap: () => _pick(t),
                child: CueRing(
                  show: cue && t.id == _need,
                  size: 92,
                  child: Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 38)),
                      Text(t.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}
