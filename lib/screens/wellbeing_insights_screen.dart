import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../insights/parent_summary.dart';
import '../services/account_service.dart';
import '../models/caregiver_observation.dart';
import '../insights/insights_calculator.dart';
import '../services/session_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/adventure_mark.dart';
import '../widgets/calm_ui.dart';
import 'wellbeing_full_summary_screen.dart';

/// MINDY PARENT SUMMARY -- a short, plain-language first view. Every number
/// and sentence is computed from stored sessions and caregiver entries.
/// With too little data it says so ("Mindy is still learning") instead of
/// showing anything that looks like a trend.
///
/// The detailed, numbers-heavy breakdown (charts, per-window participation,
/// the adaptive journey, research indicators) lives one tap away, in
/// [WellbeingFullSummaryScreen] -- so the first thing a busy parent sees
/// is a few short sentences, not a wall of data.
class WellbeingInsightsScreen extends StatefulWidget {
  const WellbeingInsightsScreen({super.key});

  @override
  State<WellbeingInsightsScreen> createState() =>
      _WellbeingInsightsScreenState();
}

class _WellbeingInsightsScreenState extends State<WellbeingInsightsScreen> {
  ObservationType? _type;
  final _note = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _type;
    if (t == null) return;
    final id = '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    await ObservationRepository.instance.add(CaregiverObservation(
      id: id,
      timestamp: DateTime.now(),
      type: t,
      note: _note.text.trim(),
    ));
    if (!mounted) return;
    setState(() {
      _type = null;
      _note.clear();
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = AccountService.instance.activeChild?.nickname;
    return Scaffold(
      backgroundColor: CalmColors.mist,
      appBar: AppBar(title: const Text('Parent summary')),
      body: AnimatedBuilder(
        animation: Listenable.merge(
            [SessionRepository.instance, ObservationRepository.instance]),
        builder: (context, _) {
          final sessions = SessionRepository.instance.chronological;
          final ins = InsightsCalculator.compute(
            sessions, ObservationRepository.instance.chronological);
          final summary = ParentSummary.from(sessions, childName: name);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Row(children: [
                // v43: the purple mascot creature was the last one left in
                // the app. This is a caregiver screen, so it takes the
                // lantern -- the same mark as the sign-in -- rather than
                // the child's friend, which belongs on child-facing
                // screens. `glow: false` because the halo has nothing to
                // glow against on ivory.
                const AdventureMark(size: 56, glow: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ins.hasAnyData
                        ? '${ins.totalSessions} activities recorded so far'
                        : 'Mindy is still learning.',
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, color: CalmColors.ink),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (!ins.hasAnyData)
                const CalmCard(
                  child: Text(
                      'A few more sessions are needed before Mindy has anything to '
                      'say here. This will fill in after your child has played a bit.',
                      style: TextStyle(fontSize: 14.5, height: 1.4, color: CalmColors.ink)),
                )
              else
                _PlainSummaryCard(summary: summary),
              const SizedBox(height: 4),
              CalmCard(
                tint: CalmColors.periwinkleSoft,
                onTap: ins.hasAnyData
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const WellbeingFullSummaryScreen()))
                    : null,
                child: Row(children: [
                  const Icon(Icons.bar_chart_rounded, color: CalmColors.periwinkle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('See the full summary of how ${name ?? 'your child'} used Mindy',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: CalmColors.ink)),
                      const SizedBox(height: 2),
                      const Text(
                          'Activity-by-activity detail, charts and the research notes',
                          style: TextStyle(fontSize: 12.5, color: CalmColors.inkSoft)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: CalmColors.inkSoft),
                ]),
              ),
              const SizedBox(height: 10),
              _ObservationCard(
                ins: ins,
                selected: _type,
                note: _note,
                saved: _saved,
                onSelect: (t) => setState(() {
                  _type = t;
                  _saved = false;
                }),
                onSave: _save,
              ),
              const SizedBox(height: 10),
              const _Disclaimer(),
            ],
          );
        },
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) => CalmCard(
        tint: CalmColors.sunSoft,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: CalmColors.attentionInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(InsightsCalculator.disclaimer,
                style: const TextStyle(fontSize: 12.5, color: CalmColors.attentionInk, height: 1.35)),
          ),
        ]),
      );
}

/// The first thing a parent sees here: plain sentences, no jargon, no
/// scores. Everything below is optional, not required reading.
class _PlainSummaryCard extends StatelessWidget {
  final ParentSummary summary;
  const _PlainSummaryCard({required this.summary});

  Widget _section(String title, IconData icon, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: CalmColors.teal),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w800, color: CalmColors.ink))),
        ]),
        const SizedBox(height: 4),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 3),
            child: Text(i,
                style: const TextStyle(fontSize: 14.5, height: 1.35, color: CalmColors.ink)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      key: const Key('parentSummary'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(summary.headline,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: CalmColors.ink)),
        Align(
          alignment: Alignment.centerLeft,
          child: Builder(
            builder: (ctx) => TextButton.icon(
              key: const Key('copySummary'),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy summary to share'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: summary.toPlainText()));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Summary copied')));
                }
              },
            ),
          ),
        ),
        _section('What they enjoyed', Icons.favorite_rounded, summary.enjoyed),
        _section('What was tricky', Icons.extension_rounded, summary.tricky),
        _section('How they said they felt', Icons.emoji_emotions_rounded,
            summary.feelings),
        _section('Things you could try', Icons.lightbulb_rounded, summary.tryNext),
        if (summary.talkToSomeone != null)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CalmColors.sunSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(summary.talkToSomeone!,
                style: const TextStyle(
                    fontSize: 14, height: 1.35, color: CalmColors.attentionInk)),
          ),
        const SizedBox(height: 12),
        const Text(
          'Mindy is a play and research app. It cannot diagnose anything. '
          'This only repeats what your child did and said while playing.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: CalmColors.inkSoft),
        ),
      ]),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  final WellbeingInsights ins;
  final ObservationType? selected;
  final TextEditingController note;
  final bool saved;
  final ValueChanged<ObservationType> onSelect;
  final VoidCallback onSave;

  const _ObservationCard({
    required this.ins,
    required this.selected,
    required this.note,
    required this.saved,
    required this.onSelect,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return CalmCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note_rounded, color: CalmColors.periwinkle),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('What have you noticed recently?',
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          ),
          PillBadge(CaregiverObservation.sourceLabel,
              bg: CalmColors.periwinkleSoft, fg: CalmColors.ink),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in ObservationType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: selected == t,
                onSelected: (_) => onSelect(t),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: note,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Optional note',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          ElevatedButton(
              onPressed: selected == null ? null : onSave,
              child: const Text('Save observation')),
          const SizedBox(width: 10),
          if (saved)
            const Text('Saved.', style: TextStyle(color: CalmColors.goodInk)),
        ]),
        const SizedBox(height: 6),
        // v48: plainer wording. The substance stays, because it is a real
        // promise about what the app does with what you write here.
        const Text(
            'What you write stays yours. It is kept separate and never '
            'changes which activities Mindy offers.',
            style: TextStyle(fontSize: 11.5, color: CalmColors.inkSoft)),
      ]),
    );
  }
}
