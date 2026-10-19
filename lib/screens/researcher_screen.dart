import 'package:flutter/material.dart';
import '../insights/data_quality.dart';
import 'package:flutter/services.dart';
import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../insights/chart_data.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import '../services/app_settings.dart';
import '../services/diagnostics_service.dart';
import '../services/emotion_signal_client.dart';
import '../services/export_service.dart';
import '../services/journey_controller.dart';
import '../services/reward_service.dart';
import '../services/session_repository.dart';
import '../services/sync_service.dart';
import '../widgets/line_chart.dart';
import 'rule_indicator_cards.dart';
import 'screening_report_screen.dart';
import '../games/models/game_difficulty.dart';

/// Researcher / staff dashboard. Raw, detailed, real data only.
class ResearcherScreen extends StatelessWidget {
  const ResearcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Researcher mode'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Sessions'),
              Tab(text: 'Why did Mindy choose this?'),
              Tab(text: 'Charts'),
              Tab(text: 'Data & export'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: SessionRepository.instance,
          builder: (context, _) {
            final list = SessionRepository.instance.allChronological;
            return TabBarView(children: [
              _SessionsTab(list),
              _DecisionsTab(list),
              _ChartsTab(list),
              const _DataTab(),
            ]);
          },
        ),
      ),
    );
  }
}

String _f(Object? v) => v == null ? '-' : v.toString();
String _ms(double? v) => v == null ? '-' : '${v.round()} ms';
String _pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';

// -------------------------------------------------------------- sessions

class _SessionsTab extends StatelessWidget {
  final List<GameSession> list;
  const _SessionsTab(this.list);

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // v46: moved here from the caregiver full summary. Rule text,
        // thresholds and evidence counts belong in front of a researcher,
        // who can read "unvalidated cut-off, two sessions" and weigh it.
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Rule-based indicators',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        RuleIndicatorCards(sessions: SessionRepository.instance.chronological),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
                'Participant: ${s.exportParticipantId}\n'
                'Study condition: ${s.condition.code}\n'
                'Sessions stored: ${list.length}\n'
                'Journey: ${JourneyController.instance.completedCount} of '
                '6 finished in the current adventure'),
          ),
        ),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No sessions recorded yet. Nothing is shown until a '
                'child has played.'),
          ),
        for (final x in list.reversed)
          Card(
            child: ExpansionTile(
              title: Text(
                  '${x.game.emoji} ${x.game.title} \u00B7 L${x.level} ${x.difficulty.label} \u00B7 ${x.pace.name}'),
              subtitle: Text(
                  '${x.startTime.toString().substring(0, 16)}  '
                  '${x.emotionBefore?.faceEmoji ?? '?'} \u2192 ${x.emotionAfter?.faceEmoji ?? '?'}  '
                  '${x.completed ? 'finished' : 'left early'}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session ${x.sessionId}'),
                Text('Participant: ${x.anonymousChildId}  condition: ${x.condition}'),
                Text('Emotion before/after: ${x.emotionBefore?.code ?? '-'} / ${x.emotionAfter?.code ?? '-'}  '
                    '(source ${x.emotionSource}, check-in ${x.checkInDurationMs} ms)'),
                Text('Mood change (after - before, 1-5 ordinal): ${_f(x.moodDelta)}'),
                Text('Completed: ${x.completed} (${(x.completionPercent * 100).round()}%)  '
                    'duration ${x.durationSeconds}s  pauses ${x.pausedCount}  play again ${_f(x.playAgain)}'),
                Text('Successes ${x.successes}  mistakes ${x.mistakes}  accuracy ${_pct(x.accuracy)}  '
                    'interactions ${x.interactions}'),
                Text('Avg response ${_ms(x.avgResponseMs)}  variability (SD) ${_ms(x.responseTimeVariabilityMs)}'),
                Text('Engagement ${x.engagement.name}  band ${_f(x.performanceBand?.name)}  load ${_f(x.loadTimeMs)} ms'),
                Text('Sync: ${x.syncStatus.name}'),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- decisions

class _DecisionsTab extends StatelessWidget {
  final List<GameSession> list;
  const _DecisionsTab(this.list);

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No decisions recorded yet.')));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (var i = list.length - 1; i >= 0; i--) _DecisionCard(list[i]),
      ],
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final GameSession x;
  const _DecisionCard(this.x);

  @override
  Widget build(BuildContext context) {
    final t = x.trace;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${x.startTime.toString().substring(0, 16)}  \u00B7  step ${t.journeyStep + 1}  \u00B7  ${t.condition}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const Divider(),
            const Text('BASED ON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            Text('Emotion: ${t.emotion ?? 'SKIPPED'} (${t.emotionSource})'),
            Text('Previous activity: ${t.previousActivity ?? 'none'}'
                '${t.previousLevel == null ? '' : ' (level ${t.previousLevel})'}'),
            Text('Previous self-reported change: ${t.recentMoodChange}   engagement: ${t.engagement}'),
            Text('Performance evidence: ${t.performanceEvidence}'),
            const SizedBox(height: 6),
            const Text('WHAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            Text('${t.selectedActivity}  \u2192  level ${t.selectedLevel} (${t.selectedDifficulty}), ${t.selectedPace} pace'),
            Text('Rule ${t.ruleId}  \u00B7  baseline level ${t.baselineLevel}  \u00B7  modifier ${t.modifier} (${t.modifierReason})'
                '${t.recovery ? '  \u00B7  RECOVERY' : ''}'),
            const SizedBox(height: 6),
            const Text('WHY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            Text(t.humanReason),
            if (t.scores.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('SUITABILITY COMPONENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              for (final sc in t.scores)
                Text(
                  '${sc.activityId}${sc.allowed ? '' : ' (excluded by safety rule)'}: '
                  '${sc.allowed ? sc.total.toStringAsFixed(1) : '-'}'
                  '  ${sc.allowed ? sc.components.entries.where((e) => e.value != 0).map((e) => '${e.key}=${e.value}').join(', ') : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: sc.activityId == t.selectedActivity
                          ? FontWeight.w800
                          : FontWeight.w400),
                ),
            ],
            const SizedBox(height: 6),
            const Text('WHAT HAPPENED AFTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            Text('${x.completed ? 'Finished' : 'Left early'} \u00B7 '
                'after-feeling ${x.emotionAfter?.code ?? 'not given'} \u00B7 mood change ${_f(x.moodDelta)} \u00B7 '
                'engagement ${x.engagement.name}'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- charts

class _ChartsTab extends StatelessWidget {
  final List<GameSession> list;
  const _ChartsTab(this.list);

  Widget _card(String title, String hint, Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(hint, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Charts appear after sessions are recorded. '
                  'No sample data is ever shown.')));
    }
    final before = ChartData.emotionBefore(list);
    final after = ChartData.emotionAfter(list);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card('1. Emotion trajectory',
            'Self-reported feeling before each session (1 scared ... 5 happy), oldest to newest',
            SimpleLineChart(
              yMin: 1, yMax: 5, yLabelMin: '1', yLabelMax: '5',
              series: [ChartSeries('Before', MindyChartColors.coral, before)],
            )),
        _card('2. Pre/post emotional response',
            'Before vs after the same session (ordinal 1-5, not a clinical scale)',
            SimpleLineChart(
              yMin: 1, yMax: 5, yLabelMin: '1', yLabelMax: '5',
              series: [
                ChartSeries('Before', MindyChartColors.coral, before),
                ChartSeries('After', MindyChartColors.mint, after),
              ],
            )),
        _card('3. Activity sequence', 'Which activity was played, in order',
            _SequenceStrip(list)),
        _card('4. Difficulty progression', 'Level (1-5) of each session',
            SimpleLineChart(
              yMin: 1, yMax: 5, yLabelMin: 'L1', yLabelMax: 'L5',
              series: [ChartSeries('Level', MindyChartColors.purple, ChartData.level(list))],
            )),
        _card('5. Completion trend', 'Running completion rate (% finished so far)',
            SimpleLineChart(
              yMin: 0, yMax: 100, yLabelMin: '0%', yLabelMax: '100%',
              series: [ChartSeries('Completion', MindyChartColors.sky, ChartData.runningCompletionPercent(list))],
            )),
        _card('6. Response-time trend', 'Average response per session (only where the game measures it)',
            SimpleLineChart(
              yMin: 0,
              yMax: _maxResp(list),
              yLabelMin: '0 s',
              yLabelMax: '${(_maxResp(list) / 1000).toStringAsFixed(1)} s',
              series: [ChartSeries('Response', MindyChartColors.sun, ChartData.responseMs(list))],
            )),
        _card('7. Accuracy trend', 'Success rate where an activity has right/wrong moments',
            SimpleLineChart(
              yMin: 0, yMax: 100, yLabelMin: '0%', yLabelMax: '100%',
              series: [ChartSeries('Accuracy', MindyChartColors.sky, ChartData.accuracyPercent(list))],
            )),
        _card('8. Regulation-activity response',
            'Mood change (after - before) for finished calming activities; 0 = no change',
            SimpleLineChart(
              yMin: -4, yMax: 4, yLabelMin: '-4', yLabelMax: '+4',
              series: [ChartSeries('Mood change', MindyChartColors.mint, ChartData.regulationDelta(list))],
            )),
      ],
    );
  }

  double _maxResp(List<GameSession> l) {
    var m = 1000.0;
    for (final x in l) {
      if (x.avgResponseMs != null && x.avgResponseMs! > m) m = x.avgResponseMs!;
    }
    return m;
  }
}

class MindyChartColors {
  static const coral = Color(0xFFFF8FA3);
  static const mint = Color(0xFF3FBF94);
  static const purple = Color(0xFF8B5CF6);
  static const sky = Color(0xFF4FC3F7);
  static const sun = Color(0xFFE5A00D);
}

class _SequenceStrip extends StatelessWidget {
  final List<GameSession> list;
  const _SequenceStrip(this.list);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var i = 0; i < list.length; i++)
          Tooltip(
            message: '${i + 1}. ${list[i].game.title} L${list[i].level}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: list[i].completed
                    ? const Color(0xFFE5F7EC)
                    : const Color(0xFFFFEFE0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: list[i].completed
                        ? const Color(0xFF3FBF94)
                        : const Color(0xFFE5A00D)),
              ),
              child: Text('${i + 1} ${list[i].game.emoji} L${list[i].level}',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ data

class _DataTab extends StatefulWidget {
  const _DataTab();
  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  late final TextEditingController _pid =
      TextEditingController(text: AppSettings.instance.participantCode);
  late final TextEditingController _url =
      TextEditingController(text: AppSettings.instance.baseUrl);
  late final TextEditingController _pin = TextEditingController();
  late final TextEditingController _age = TextEditingController(
      text: AppSettings.instance.participantAge?.toString() ?? '');

  @override
  void dispose() {
    _pid.dispose();
    _url.dispose();
    _pin.dispose();
    _age.dispose();
    super.dispose();
  }

  void _show(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
              child: SelectableText(text,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Resolve the messenger BEFORE the await, so no BuildContext
              // is used after an async gap.
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: text));
              messenger.showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            },
            child: const Text('Copy all'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([s, SessionRepository.instance]),
      builder: (context, _) {
        final list = SessionRepository.instance.allChronological;
        final loads = [for (final x in list) if (x.loadTimeMs != null && x.loadTimeMs! > 0) x.loadTimeMs!];
        final avgLoad = loads.isEmpty ? null : loads.reduce((a, b) => a + b) / loads.length;
        final unsynced = SessionRepository.instance.unsynced.length;
        final d = DiagnosticsService.instance;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _Overview(list: list),
            const Divider(height: 28),
            const Text('Study', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ListTile(
              title: const Text('Study condition'),
              subtitle: const Text('Logged on every session. Takes effect at the next decision.'),
              trailing: DropdownButton<StudyCondition>(
                value: s.condition,
                onChanged: (v) {
                  if (v != null) s.setCondition(v);
                },
                items: [
                  for (final c in StudyCondition.values)
                    DropdownMenuItem(value: c, child: Text(c.code, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
            TextField(
              controller: _pid,
              decoration: const InputDecoration(
                  labelText: 'Participant code (anonymous, e.g. P001)'),
              onSubmitted: s.setParticipantCode,
              onEditingComplete: () => s.setParticipantCode(_pid.text),
            ),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Age in years (optional, whole number)'),
              onSubmitted: (v) => s.setParticipantAge(int.tryParse(v)),
              onEditingComplete: () => s.setParticipantAge(int.tryParse(_age.text)),
            ),
            Text('Random child id: ${s.childId}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const Divider(height: 28),
            const Text('Export', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text(
                'Includes research data and DecisionTrace. No names or personal details.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, children: [
              ElevatedButton(
                onPressed: () => _show('JSON export',
                    ExportService.toJson(list, ObservationRepository.instance.chronological)),
                child: const Text('JSON'),
              ),
              ElevatedButton(
                onPressed: () => _show('Sessions CSV', ExportService.toCsv(list)),
                child: const Text('Sessions CSV'),
              ),
              ElevatedButton(
                onPressed: () => _show('Events CSV (for machine learning)',
                    ExportService.toEventsCsv(list)),
                child: const Text('Events CSV'),
              ),
            ]),
            const SizedBox(height: 6),
            const Text(
                'For the ML pipeline: copy BOTH CSVs into mindy_ml/data/raw/ as '
                'sessions.csv and events.csv.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Behavioural Screening Summary'),
              subtitle: const Text('Show a report produced by the Python pipeline'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ScreeningReportScreen())),
            ),
            const Divider(height: 28),
            const Text('Performance & stability',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Average activity load time: ${avgLoad == null ? '-' : '${avgLoad.round()} ms'} (target < 2000 ms)'),
            Text('Uncaught errors captured: ${d.errorCount}  \u00B7  app launches: ${d.launchCount}'),
            Text('Sessions stored: ${list.length}'),
            if (d.lastErrors.isNotEmpty) Text('Last error: ${d.lastErrors.first}', style: const TextStyle(fontSize: 11)),
            const Text('Input latency is not instrumented.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
            const Divider(height: 28),
            const Text('Backend / KARA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            SwitchListTile(
              title: const Text('Use mock backend (offline)'),
              subtitle: const Text('Turn off to use the real API below (HTTPS only)'),
              value: s.useMockBackend,
              onChanged: s.setUseMock,
            ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(labelText: 'API base URL (https://...)'),
              onSubmitted: s.setBaseUrl,
              onEditingComplete: () => s.setBaseUrl(_url.text),
            ),
            if (s.useMockBackend)
              ListTile(
                title: const Text('Simulate a KARA check-in (test only)'),
                subtitle: const Text('Stored as KARA_SIMULATED, never as KARA'),
                trailing: DropdownButton<EmotionState?>(
                  value: s.simulatedKara,
                  onChanged: s.setSimulatedKara,
                  items: [
                    const DropdownMenuItem<EmotionState?>(value: null, child: Text('Off')),
                    for (final e in EmotionState.values)
                      DropdownMenuItem<EmotionState?>(value: e, child: Text('${e.faceEmoji} ${e.label}')),
                  ],
                ),
              ),
            Text('Sessions not yet synced: $unsynced  \u00B7  mock server received: ${EmotionSignalClient.mock.receivedSessions.length}'),
            const SizedBox(height: 6),
            Wrap(spacing: 10, children: [
              OutlinedButton(
                onPressed: () async {
                  await s.setBaseUrl(_url.text);
                  final ok = await EmotionSignalClient.current().ping();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Reachable (${EmotionSignalClient.current().name})' : 'Not reachable')));
                  }
                },
                child: const Text('Test connection'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final n = await SyncService.instance.trigger();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Uploaded $n session(s)')));
                  }
                },
                child: const Text('Sync now'),
              ),
            ]),
            const Divider(height: 28),
            const Text('Access to this screen requires a signed-in researcher account (see Account settings).',
                style: TextStyle(fontSize: 11.5, color: Colors.black54)),
            const Divider(height: 28),
            ListTile(
              title: const Text('Delete all local data', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Sessions, journey, caregiver observations. Cannot be undone.'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete everything?'),
                    content: const Text('This removes all stored sessions and observations on this device.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  await SessionRepository.instance.clear();
                  await ObservationRepository.instance.clear();
                  await JourneyController.instance.reset();
                  RewardService.instance.clear();
                }
              },
            ),
          ],
        );
      },
    );
  }
}


/// Real counts from stored sessions. Nothing here is a clinical result.
class _Overview extends StatelessWidget {
  final List<GameSession> list;
  const _Overview({required this.list});

  @override
  Widget build(BuildContext context) {
    final d = DataQuality.summarise(list);
    String top(Map<String, int> m) {
      final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      return e.isEmpty ? 'none yet' : e.map((x) => '${x.key} ${x.value}').join(', ');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Overview (this device, all children)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Sessions: ${d.sessions}  \u2022  finished: ${d.completed}  \u2022  stopped early: ${d.interrupted}'),
      Text('Games played: ${top(d.gameUse)}'),
      Text('Events: ${top(d.eventCounts)}'),
      Text('Sessions with Mindy help: ${d.sessionsWithSupport}  \u2022  offers: ${d.supportOffers}  \u2022  difficulty lowered: ${d.difficultyAdjustments}'),
      Text('After help: ${d.successesAfterSupport} right of ${d.attemptsAfterSupport} tries'),
      const SizedBox(height: 6),
      Text(d.issues.isEmpty
          ? 'Data checks: no issues found.'
          : 'Data checks: ${d.issues.length} issue(s)',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: d.issues.isEmpty ? Colors.green : Colors.orange)),
      for (final i in d.issues.take(8))
        Text('\u2022 ${i.code}: ${i.message} (${i.sessionId})',
            style: const TextStyle(fontSize: 12)),
      if (d.issues.length > 8)
        Text('...and ${d.issues.length - 8} more', style: const TextStyle(fontSize: 12)),
    ]);
  }
}
