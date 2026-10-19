import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../insights/support_plan.dart';
import '../services/account_service.dart';
import '../services/calm_service.dart';
import '../services/session_repository.dart';
import '../services/support_plan_service.dart';
import '../services/insight_summary_service.dart';
import '../services/worry_service.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/calm_ui.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _d(DateTime t) => '${t.day} ${_months[t.month - 1]}';
const _wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Builds the plan from everything the app stores for the active child.
SupportPlan currentSupportPlan({DateTime? now}) {
  final child = AccountService.instance.activeChild;
  return SupportPlan.build(
    sessions: SessionRepository.instance.chronological,
    worry: WorryService.instance.entries,
    calm: CalmService.instance.visits,
    now: now ?? DateTime.now(),
    childName: child?.nickname,
    tryingSince: SupportPlanService.instance.tryingSince,
  );
}

Listenable get supportPlanInputs => Listenable.merge([
      SessionRepository.instance,
      WorryService.instance,
      CalmService.instance,
      SupportPlanService.instance,
      AccountService.instance,
      InsightSummaryService.instance,
    ]);

/// The caregiver's main screen: how the last two weeks looked, what was
/// noticed, and things they could try. Every suggestion can be accepted or
/// set aside. Nothing here is a diagnosis.
class SupportPlanScreen extends StatefulWidget {
  const SupportPlanScreen({super.key});

  @override
  State<SupportPlanScreen> createState() => _SupportPlanScreenState();
}

class _SupportPlanScreenState extends State<SupportPlanScreen> {
  @override
  void initState() {
    super.initState();
    if (AppSettings.instance.aiInsightsEnabled) {
      InsightSummaryService.instance.refresh(currentSupportPlan());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support plan')),
      body: AnimatedBuilder(
        animation: supportPlanInputs,
        builder: (context, _) {
          final plan = currentSupportPlan();
          final name = AccountService.instance.activeChild?.nickname;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              if (AppSettings.instance.aiInsightsEnabled) _AiInsightCard(plan: plan),
              _Hero(plan: plan),
              if (plan.signals.isNotEmpty) ...[
                const SectionLabel('What we noticed',
                    sub: 'From what your child tapped in Mindy'),
                for (final s in plan.signals) _SignalCard(signal: s),
              ],
              SectionLabel('Things you could try',
                  sub: 'Your choice. Try one, or set it aside for now.'),
              for (final a in plan.actions) _ActionCard(action: a),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy this plan to share'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text: plan.toPlainText(childLabel: name, now: DateTime.now())));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Copied. You can paste it into a message or show it to a doctor.')));
                  }
                },
              ),
              const SizedBox(height: 12),
              CalmCard(
                tint: CalmColors.sunSoft,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: CalmColors.attentionInk),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(plan.caution,
                          style: const TextStyle(
                              fontSize: 13, height: 1.35, color: CalmColors.attentionInk))),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shown only when the caregiver opted in (Settings). Always sits ABOVE the
/// rule-based hero summary below it -- it never replaces it, and if nothing
/// comes back (off, no network, backend down, failed safety check) this
/// card just shows nothing, silently.
class _AiInsightCard extends StatelessWidget {
  final SupportPlan plan;
  const _AiInsightCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final svc = InsightSummaryService.instance;
    if (svc.loading) {
      return const CalmCard(
        tint: CalmColors.periwinkleSoft,
        child: Row(children: [
          SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4)),
          SizedBox(width: 12),
          Expanded(child: Text('Writing a friendlier summary\u2026',
              style: TextStyle(fontSize: 13.5, color: CalmColors.inkSoft))),
        ]),
      );
    }
    final text = svc.text;
    if (text == null) return const SizedBox.shrink(); // silent fallback
    return CalmCard(
      tint: CalmColors.periwinkleSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: CalmColors.periwinkle),
          SizedBox(width: 6),
          Text('WRITTEN WITH AI HELP, FROM THE NUMBERS BELOW',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, color: CalmColors.periwinkle,
                  letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 15, height: 1.4, color: CalmColors.ink)),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final SupportPlan plan;
  const _Hero({required this.plan});

  @override
  Widget build(BuildContext context) {
    final icon = switch (plan.band) {
      StateBand.settled => Icons.wb_sunny_rounded,
      StateBand.mixed => Icons.cloud_queue_rounded,
      StateBand.unsettled => Icons.favorite_rounded,
      StateBand.notEnough => Icons.hourglass_empty_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: CalmColors.hero,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(plan.headline,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(plan.summary,
            style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.35)),
        const SizedBox(height: 14),
        FeelingStrip(days: plan.days),
        const SizedBox(height: 10),
        Text(plan.confidence,
            style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
      ]),
    );
  }
}

/// Fourteen soft dots, one per day, coloured by that day's average feeling.
class FeelingStrip extends StatelessWidget {
  final List<DayFeeling> days;
  const FeelingStrip({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in days)
            Column(children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d.mean == null ? Colors.white24 : feelingColor(d.mean!),
                  border: d.mean == null
                      ? Border.all(color: Colors.white38)
                      : Border.all(color: Colors.white, width: 1.5),
                ),
              ),
              const SizedBox(height: 3),
              Text(_wd[d.day.weekday - 1],
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ]),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 2, children: const [
        _Key(Color(0xFFF4A3B0), 'scared'),
        _Key(Color(0xFF9AA3F0), 'sad'),
        _Key(Color(0xFFF2D7A0), 'okay'),
        _Key(Color(0xFF8FD9C4), 'calm'),
        _Key(Color(0xFFFFC95C), 'happy'),
        _Key(Colors.white24, 'no check-in'),
      ]),
    ]);
  }
}

class _Key extends StatelessWidget {
  final Color c;
  final String t;
  const _Key(this.c, this.t);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
      ]);
}

class _SignalCard extends StatelessWidget {
  final PlanSignal signal;
  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData ic, String label) = switch (signal.tone) {
      SignalTone.good => (CalmColors.goodSoft, CalmColors.goodInk, Icons.check_circle_rounded, 'Looks good'),
      SignalTone.attention => (CalmColors.attentionSoft, CalmColors.attentionInk, Icons.visibility_rounded, 'Worth watching'),
      SignalTone.neutral => (CalmColors.periwinkleSoft, CalmColors.ink, Icons.insights_rounded, 'For your info'),
    };
    return CalmCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PillBadge(label, bg: bg, fg: fg, icon: ic),
        const SizedBox(height: 8),
        Text(signal.title,
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: CalmColors.ink)),
        const SizedBox(height: 4),
        Text(signal.detail,
            style: const TextStyle(fontSize: 14.5, height: 1.35, color: CalmColors.ink)),
        const SizedBox(height: 6),
        Text(signal.evidence,
            style: const TextStyle(fontSize: 12, color: CalmColors.inkSoft)),
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final PlanAction action;
  const _ActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final svc = SupportPlanService.instance;
    final choice = svc.choiceFor(action.id);
    final decision = svc.decisions[action.id];
    final consider = action.kind == ActionKind.consider;
    final (String kindLabel, Color kb, Color kf) = switch (action.kind) {
      ActionKind.now => ('Do now', CalmColors.tealSoft, CalmColors.teal),
      ActionKind.thisWeek => ('This week', CalmColors.periwinkleSoft, CalmColors.ink),
      ActionKind.consider => ('Worth considering', CalmColors.considerSoft, CalmColors.considerInk),
    };
    return Opacity(
      opacity: choice == PlanChoice.notNow ? 0.6 : 1,
      child: CalmCard(
        tint: consider ? const Color(0xFFFFF8F9) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PillBadge(kindLabel, bg: kb, fg: kf),
            const Spacer(),
            if (choice == PlanChoice.trying)
              const PillBadge('Trying', bg: CalmColors.goodSoft, fg: CalmColors.goodInk, icon: Icons.favorite_rounded),
            if (choice == PlanChoice.notNow)
              const PillBadge('Set aside', bg: Color(0xFFEDEDED), fg: CalmColors.inkSoft),
          ]),
          const SizedBox(height: 8),
          Text(action.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CalmColors.ink)),
          const SizedBox(height: 4),
          Text('Why: ${action.why}',
              style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: CalmColors.inkSoft, height: 1.3)),
          const SizedBox(height: 8),
          for (var i = 0; i < action.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: const BoxDecoration(color: CalmColors.tealSoft, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CalmColors.teal)),
                ),
                Expanded(
                    child: Text(action.steps[i],
                        style: const TextStyle(fontSize: 14.5, height: 1.35, color: CalmColors.ink))),
              ]),
            ),
          if (choice == PlanChoice.trying && decision != null) ...[
            const SizedBox(height: 4),
            Text('You chose to try this on ${_d(decision.at)}.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalmColors.goodInk)),
            if (action.followUp != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(action.followUp!,
                    style: const TextStyle(fontSize: 13, color: CalmColors.ink, height: 1.3)),
              ),
          ],
          const SizedBox(height: 8),
          Row(children: [
            if (choice == null) ...[
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => svc.set(action.id, PlanChoice.trying),
                  child: const Text("I'll try this"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => svc.set(action.id, PlanChoice.notNow),
                  child: const Text('Not now'),
                ),
              ),
            ] else
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => svc.clear(action.id),
                  child: Text(choice == PlanChoice.trying ? 'Stop tracking this' : 'Bring it back'),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
