import 'package:flutter/material.dart';
import '../insights/worry_scale.dart';
import '../services/worry_service.dart';

/// Before/after "how worried are you?" picture scale. Ask it before the
/// child plays (BEFORE) and again afterwards (AFTER).
class WorryScaleScreen extends StatefulWidget {
  const WorryScaleScreen({super.key});

  @override
  State<WorryScaleScreen> createState() => _WorryScaleScreenState();
}

class _WorryScaleScreenState extends State<WorryScaleScreen> {
  WorryPhase _phase = WorryPhase.before;
  String? _msg;

  static const _icons = [
    Icons.sentiment_very_satisfied_rounded,
    Icons.sentiment_satisfied_rounded,
    Icons.sentiment_neutral_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_very_dissatisfied_rounded,
  ];
  static const _colors = [
    Color(0xFF2E9E5B),
    Color(0xFF8BC34A),
    Color(0xFFFFC107),
    Color(0xFFFF9800),
    Color(0xFFE53935),
  ];

  Future<void> _pick(int level) async {
    final ok = await WorryService.instance.add(_phase, level);
    if (!mounted) return;
    setState(() => _msg = ok
        ? 'Saved (${_phase.name}): ${kWorryLabels[level]}'
        : 'Choose a child profile first.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worry picture scale')),
      body: AnimatedBuilder(
        animation: WorryService.instance,
        builder: (context, _) {
          final entries = WorryService.instance.entries;
          final changes = worryChanges(entries);
          final mean = meanWorryChange(entries);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                  'Ask the child: "How worried do you feel right now?" and let them '
                  'point to a face. Ask once BEFORE play and once AFTER. '
                  'This is a simple prototype scale, not a validated test.'),
              const SizedBox(height: 12),
              SegmentedButton<WorryPhase>(
                segments: const [
                  ButtonSegment(value: WorryPhase.before, label: Text('Before play')),
                  ButtonSegment(value: WorryPhase.after, label: Text('After play')),
                ],
                selected: {_phase},
                onSelectionChanged: (s) => setState(() => _phase = s.first),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < 5; i++)
                    InkWell(
                      onTap: () => _pick(i),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: _colors[i], width: 3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          Icon(_icons[i], size: 56, color: _colors[i]),
                          Text(kWorryLabels[i],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                    ),
                ],
              ),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_msg!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              const Divider(height: 28),
              Text(
                  changes.isEmpty
                      ? 'No complete before/after pair yet.'
                      : 'Pairs: ${changes.length}. Average change (after minus before): '
                          '${mean!.toStringAsFixed(2)} (negative = less worried afterwards).',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final e in entries.reversed.take(12))
                Text('${e.at.toString().substring(0, 16)}  ${e.phase.name}: ${kWorryLabels[e.level]}'),
            ],
          );
        },
      ),
    );
  }
}
