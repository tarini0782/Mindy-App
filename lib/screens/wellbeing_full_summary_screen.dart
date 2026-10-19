import 'package:flutter/material.dart';
import 'insight_charts.dart';
import '../insights/insight_dashboard.dart';
import '../games/models/game_type.dart';
import '../insights/caregiver_summary.dart';
import '../insights/insights_calculator.dart';
import '../insights/what_helps.dart';
// MoodChange lives here. It was imported by the screen this file was split
// out of, and the import did not come with it.
import '../models/emotion_state.dart';
import '../services/account_service.dart';
import '../services/calm_service.dart';
import '../services/session_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/calm_ui.dart';

/// The FULL summary of how a child used Mindy -- everything the "Parent
/// summary" screen keeps one tap away: charts, activity-by-activity detail,
/// the adaptive journey, and the research indicators. Reached only by
/// choosing to see it; nothing here is required reading, and none of it is
/// a diagnosis.
class WellbeingFullSummaryScreen extends StatelessWidget {
  const WellbeingFullSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final name = AccountService.instance.activeChild?.nickname;
    return Scaffold(
      backgroundColor: CalmColors.mist,
      appBar: AppBar(
        title: Text('Full summary${name == null ? '' : ' – $name'}'),
      ),
      body: AnimatedBuilder(
        animation: SessionRepository.instance,
        builder: (context, _) {
          final sessions = SessionRepository.instance.chronological;
          final ins = InsightsCalculator.compute(sessions, const []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                    'This is the detailed, activity-by-activity view. The short '
                    'plain-language summary is on the previous screen.',
                    style: TextStyle(fontSize: 13, color: CalmColors.inkSoft, height: 1.3)),
              ),
              _WhatHelpsCard(data: WhatHelps.from(sessions, childName: name)),
              const SectionLabel('Charts'),
              InsightCharts(d: InsightDashboard.from(sessions)),
              _ObservedCard(summary: CaregiverSummary.from(sessions)),
              AnimatedBuilder(
                animation: CalmService.instance,
                builder: (context, _) => CalmCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Calm Corner',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: CalmColors.ink)),
                    const SizedBox(height: 6),
                    Text(CalmService.instance.caregiverLine(DateTime.now()),
                        key: const Key('calmLine'),
                        style: const TextStyle(fontSize: 14, height: 1.35, color: CalmColors.ink)),
                  ]),
                ),
              ),
              if (ins.hasAnyData) ...[
                const SectionLabel('Window by window'),
                for (final w in ins.windows) _WindowCard(w: w),
                _JourneyCard(ins: ins),
              ],
              // v46: the research indicator cards used to sit here, in a
              // CAREGIVER screen, with their rule text and cut-offs on
              // show. They have been moved to Researcher mode.
              //
              // Why: the indicator names map almost one-to-one onto
              // clinical symptom language -- inhibition, attention
              // lapses, set-shifting -- and the cards label a child
              // "worth reviewing" from as few as two sessions against
              // cut-offs that are explicitly unvalidated. A parent
              // reading "Tapping when asked to wait: worth looking at
              // again, 50%" reads a diagnosis, whatever the fine print
              // underneath says. That is the one thing this project must
              // not do.
              //
              // Parents keep the plain-language summary above, which is
              // descriptive: what was played, what helped, how the mood
              // moved. Researchers keep the indicators, in full.
            ],
          );
        },
      ),
    );
  }
}

String _pct(double? v) => v == null ? '-' : '${(v * 100).round()}%';

class _WindowCard extends StatelessWidget {
  final WindowInsights w;
  const _WindowCard({required this.w});

  @override
  Widget build(BuildContext context) {
    final title = '${w.name} (last ${w.requestedSize} activities)';
    if (w.level == EvidenceLevel.insufficient) {
      return CalmCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader(title: title, badge: w.level.label),
          const SizedBox(height: 6),
          Text(
              'Only ${w.sessionsInWindow} activit${w.sessionsInWindow == 1 ? 'y' : 'ies'} so far. '
              'More sessions are needed before meaningful patterns can be shown.',
              style: const TextStyle(color: CalmColors.ink)),
        ]),
      );
    }
    final p = w.participation;
    final e = w.emotional;
    final r = w.regulation;
    final b = w.behaviour;
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: title, badge: w.level.label),
          const SizedBox(height: 8),
          for (final s in w.statements)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $s', style: const TextStyle(color: CalmColors.ink)),
            ),
          const Divider(),
          const Text('Emotional response',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final seq in e.recentSequence)
              Chip(
                  label: Text(seq, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 4),
          const Text('Before → after, oldest to newest. "?" = no answer given.',
              style: TextStyle(fontSize: 11.5, color: CalmColors.inkSoft)),
          const Divider(),
          const Text('Participation',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          Text('Started ${p.started} · finished ${p.completed} '
              '(${_pct(p.completionRate)}) · left early ${p.abandoned}',
              style: const TextStyle(color: CalmColors.ink)),
          Text('Average time ${p.avgDurationSeconds == null ? '-' : '${p.avgDurationSeconds!.round()} s'} '
              '· pauses ${p.totalPauses}',
              style: const TextStyle(color: CalmColors.ink)),
          Text(
              p.playAgainAnswered == 0
                  ? 'Play-again answers: none yet'
                  : 'Would play again: ${p.playAgainYes} of ${p.playAgainAnswered} answers',
              style: const TextStyle(color: CalmColors.ink)),
          if (r.completedWithPair > 0) ...[
            const Divider(),
            const Text('Calming activities',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CalmColors.ink)),
            for (final en in r.perActivity.entries)
              Text('${en.key}: more positive afterwards in ${en.value[0]} of ${en.value[1]} finished sessions',
                  style: const TextStyle(color: CalmColors.ink)),
          ],
          if (b.sessionsWithAccuracy > 0 || b.sessionsWithResponse > 0) ...[
            const Divider(),
            const Text('Gameplay behaviour',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CalmColors.ink)),
            if (b.meanAccuracy != null)
              Text('Average success in activities with right/wrong moments: ${_pct(b.meanAccuracy)} '
                  '(${b.sessionsWithAccuracy} sessions)',
                  style: const TextStyle(color: CalmColors.ink)),
            if (b.meanResponseMs != null)
              Text('Average time to respond: ${(b.meanResponseMs! / 1000).toStringAsFixed(1)} s '
                  '(${b.sessionsWithResponse} sessions)',
                  style: const TextStyle(color: CalmColors.ink)),
            if (b.variabilityNote != null)
              Text(b.variabilityNote!, style: const TextStyle(color: CalmColors.ink)),
            const Text(
                'These describe how the child interacted with the games. '
                'They say nothing about attention, memory or ability.',
                style: TextStyle(fontSize: 11.5, color: CalmColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  final String title;
  final String? badge;
  const _CardHeader({required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink))),
        if (badge != null)
          PillBadge(badge!, bg: CalmColors.periwinkleSoft, fg: CalmColors.ink),
      ]);
}

class _JourneyCard extends StatelessWidget {
  final WellbeingInsights ins;
  const _JourneyCard({required this.ins});

  String _short(String reason) {
    final i = reason.indexOf('Why: ');
    return i < 0 ? reason : reason.substring(i + 5);
  }

  String _moodText(MoodChange m) {
    switch (m) {
      case MoodChange.improved:
        return 'felt more positive afterwards';
      case MoodChange.unchanged:
        return 'felt about the same afterwards';
      case MoodChange.worsened:
        return 'felt less positive afterwards';
      case MoodChange.unknown:
        return 'no after-feeling recorded';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adaptive journey',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          const SizedBox(height: 6),
          Text('Repeated activity in a row: ${ins.repeatedActivityTransitions} '
              '· level changes: ${ins.difficultyChanges} '
              '· different-activity choices after a tricky session: ${ins.recoveryDecisions}',
              style: const TextStyle(fontSize: 12.5, color: CalmColors.inkSoft)),
          const SizedBox(height: 8),
          for (final j in ins.journey)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CalmColors.periwinkleSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_gameEmoji(j.activityId)} ${j.activityTitle} · Level ${j.level} (${j.difficulty}) · '
                      '${j.completed ? 'finished' : 'left early'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: CalmColors.ink)),
                  Text('The child ${_moodText(j.moodChange)}.',
                      style: const TextStyle(fontSize: 12.5, color: CalmColors.ink)),
                  Text('Why Mindy chose it: ${_short(j.reason)}',
                      style: const TextStyle(fontSize: 12.5, color: CalmColors.inkSoft)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _gameEmoji(String id) {
    for (final t in GameType.values) {
      if (t.id == id) return t.emoji;
    }
    return '';
  }
}

/// Observed events only. Says what happened, not what it means.
class _ObservedCard extends StatelessWidget {
  final CaregiverSummary summary;
  const _ObservedCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final lines = summary.lines;
    return CalmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What happened (observed)',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          const SizedBox(height: 6),
          if (lines.isEmpty)
            const Text('Nothing recorded yet.', style: TextStyle(color: CalmColors.ink))
          else
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $l', style: const TextStyle(color: CalmColors.ink)),
              ),
          const SizedBox(height: 8),
          const Text(
            'These are counts of what the child did or chose. They are not a '
            'diagnosis and do not say how the child is doing overall. '
            'Skipped questions are not counted.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CalmColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Mindy's personal pattern report for this child (see WhatHelps).
class _WhatHelpsCard extends StatelessWidget {
  final WhatHelps data;
  const _WhatHelpsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      key: const Key('whatHelps'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.auto_awesome_rounded, color: CalmColors.periwinkle),
          SizedBox(width: 8),
          Expanded(
              child: Text('What seems to help',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: CalmColors.ink))),
        ]),
        const SizedBox(height: 6),
        if (!data.enoughData)
          const Text('Mindy compares activities after your child has played '
              'a few times and shared how they feel. Nothing to show yet.',
              style: TextStyle(color: CalmColors.ink)),
        for (final l in data.lines)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
              const SizedBox(height: 2),
              Text(l.detail, style: const TextStyle(height: 1.35, color: CalmColors.ink)),
              Text(l.evidence,
                  style: const TextStyle(fontSize: 12, color: CalmColors.inkSoft)),
            ]),
          ),
        if (data.engineReasons.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Why Mindy chose the latest activities',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          for (final r in data.engineReasons)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('• $r', style: const TextStyle(height: 1.3, color: CalmColors.ink)),
            ),
        ],
        const SizedBox(height: 12),
        Text(data.caution,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CalmColors.inkSoft)),
      ]),
    );
  }
}
