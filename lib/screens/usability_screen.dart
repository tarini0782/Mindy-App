import 'package:flutter/material.dart';
import '../insights/sus.dart';
import '../services/usability_service.dart';

/// Grown-up usability questionnaire (System Usability Scale).
class UsabilityScreen extends StatefulWidget {
  const UsabilityScreen({super.key});

  @override
  State<UsabilityScreen> createState() => _UsabilityScreenState();
}

class _UsabilityScreenState extends State<UsabilityScreen> {
  final List<int?> _a = List<int?>.filled(10, null);
  double? _last;

  bool get _complete => _a.every((x) => x != null);

  Future<void> _save() async {
    final score = await UsabilityService.instance.add([for (final x in _a) x!]);
    if (!mounted) return;
    setState(() {
      _last = score;
      for (var i = 0; i < 10; i++) {
        _a[i] = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usability questionnaire')),
      body: AnimatedBuilder(
        animation: UsabilityService.instance,
        builder: (context, _) {
          final hist = UsabilityService.instance.entries;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                  'For a parent, nurse or other grown-up after using the app. '
                  '1 = strongly disagree, 5 = strongly agree. Answers stay on this device.'),
              const SizedBox(height: 10),
              for (var i = 0; i < 10; i++) ...[
                Text('${i + 1}. ${kSusStatements[i]}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var v = 1; v <= 5; v++)
                      Expanded(
                        child: Column(children: [
                          Radio<int>(
                            value: v,
                            groupValue: _a[i],
                            onChanged: (x) => setState(() => _a[i] = x),
                          ),
                          Text('$v'),
                        ]),
                      ),
                  ],
                ),
              ],
              ElevatedButton(
                onPressed: _complete ? _save : null,
                child: const Padding(
                    padding: EdgeInsets.all(10), child: Text('Save and score')),
              ),
              if (_last != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                      'Score: ${_last!.toStringAsFixed(1)} / 100. About 68 is the usual '
                      'average; your proposal sets a target above it.',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 16),
              Text('Saved results (${hist.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              for (final e in hist.reversed)
                Text('${e.at.toString().substring(0, 16)}  →  ${e.score.toStringAsFixed(1)}'),
              const SizedBox(height: 8),
              const Text(
                  'SUS: Brooke, J. (1996). SUS: a quick and dirty usability scale. '
                  'In Usability Evaluation in Industry. One grown-up score is not a '
                  'usability study; collect several respondents.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          );
        },
      ),
    );
  }
}
