import 'package:flutter/material.dart';
import '../insights/condition_compare.dart';
import '../insights/worry_scale.dart';
import '../services/session_repository.dart';
import '../services/worry_service.dart';

/// Adaptive vs fixed, side by side. Descriptive only: no significance claims.
class ConditionCompareScreen extends StatelessWidget {
  const ConditionCompareScreen({super.key});

  static String _name(String c) {
    switch (c) {
      case 'ADAPTIVE':
        return 'Adaptive';
      case 'DIFFICULTY_ONLY':
        return 'Difficulty only';
      case 'FIXED_BASELINE':
        return 'Fixed baseline';
    }
    return c;
  }

  static String _num(double? v, [int d = 2]) =>
      v == null ? '-' : v.toStringAsFixed(d);
  static String _pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adaptive vs fixed')),
      body: AnimatedBuilder(
        animation: SessionRepository.instance,
        builder: (context, _) {
          final all = SessionRepository.instance.allChronological;
          final stats = compareByCondition(all);
          final demo = all.any((s) => s.anonymousChildId.startsWith('DEMO-'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (demo)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  color: const Color(0xFFFFE082),
                  child: const Text(
                      'DEMO / DEVELOPMENT DATA – NOT REAL PARTICIPANT DATA is included below.',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              const Text(
                  'Each column is one study condition from the proposal. These are plain '
                  'averages of what was recorded. With a small pilot sample they show '
                  'what the data looks like, not proof that one condition is better.'),
              const SizedBox(height: 12),
              if (stats.isEmpty)
                const Text('No adventure sessions yet. Play a few adventure steps first.')
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Measure')),
                      for (final s in stats) DataColumn(label: Text(_name(s.condition))),
                    ],
                    rows: [
                      _row('Sessions', stats, (s) => '${s.sessions}'),
                      _row('Children', stats, (s) => '${s.children}'),
                      _row('Mood change after play (after minus before, 5 faces)', stats,
                          (s) => '${_num(s.meanMoodChange)} (n=${s.moodSessions})'),
                      _row('Finished the activity', stats, (s) => _pct(s.completionRate)),
                      _row('Hints / support per session', stats,
                          (s) => _num(s.meanSupportCount)),
                      _row('Game load time (ms)', stats,
                          (s) => _num(s.meanLoadMs, 0)),
                      _row('Loaded in under 3 s', stats, (s) => _pct(s.loadUnder3sRate)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: WorryService.instance,
                builder: (context, _) {
                  final w = WorryService.instance.entries;
                  final n = worryChanges(w).length;
                  final m = meanWorryChange(w);
                  return Text(
                      n == 0
                          ? 'Worry picture scale (this child): no before/after pair yet.'
                          : 'Worry picture scale (this child): $n pair(s), average change '
                              '${m!.toStringAsFixed(2)} (negative = less worried).',
                      style: const TextStyle(fontWeight: FontWeight.w700));
                },
              ),
              const SizedBox(height: 14),
              const Text(
                  'Reading this: mood change is a simple 5-face self-report, not a '
                  'validated anxiety scale. Compare conditions only with enough children '
                  'in each (ask your supervisor for the number) and report effect sizes '
                  'with intervals, not "significant" claims.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          );
        },
      ),
    );
  }

  DataRow _row(String label, List<ConditionStats> stats,
          String Function(ConditionStats) f) =>
      DataRow(cells: [
        DataCell(SizedBox(width: 220, child: Text(label))),
        for (final s in stats) DataCell(Text(f(s))),
      ]);
}
