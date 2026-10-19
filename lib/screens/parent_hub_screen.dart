import 'package:flutter/material.dart';
import '../services/account_service.dart';
import '../services/demo_seeder.dart';
import '../theme/app_theme.dart';
import '../widgets/calm_ui.dart';
import 'compare_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'robot_simulator_screen.dart';
import 'settings_screen.dart';
import 'support_plan_screen.dart';
import 'usability_screen.dart';
import 'wellbeing_insights_screen.dart';
import 'worry_scale_screen.dart';

/// The grown-ups' area, opened behind the grown-up check. It leads with the
/// Support plan (what to do), then the detail screens, then study tools.
class ParentHubScreen extends StatelessWidget {
  const ParentHubScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, Color c, String title, String sub, Widget page) =>
        CalmCard(
          onTap: () => _open(context, page),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            CircleAvatar(
                radius: 22,
                backgroundColor: c.withValues(alpha: 0.14),
                child: Icon(icon, color: c, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: CalmColors.ink)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 13, color: CalmColors.inkSoft, height: 1.25)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: CalmColors.inkSoft),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('For grown-ups')),
      body: AnimatedBuilder(
        animation: supportPlanInputs,
        builder: (context, _) {
          final plan = currentSupportPlan();
          final top = plan.actions.isEmpty ? null : plan.actions.first;
          final isDemo = AccountService.instance.activeChild?.isDemo ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: () => _open(context, const SupportPlanScreen()),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: CalmColors.hero,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const PillBadge('Support plan',
                        bg: Colors.white24, fg: Colors.white, icon: Icons.favorite_rounded),
                    const SizedBox(height: 10),
                    Text(plan.headline,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(plan.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, color: Colors.white, height: 1.3)),
                    if (top != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Suggested: ${top.title}',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Row(children: [
                      Text('Open the full plan',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(
                    'Everything here comes from what your child tapped in Mindy. '
                    'Mindy cannot diagnose anything.',
                    style: TextStyle(fontSize: 12.5, color: CalmColors.inkSoft)),
              ),
              if (isDemo) ...[
                const SectionLabel('Demo tools',
                    sub: 'Sample history so the plan can be shown now. Invented, not real data.'),
                CalmCard(
                  tint: CalmColors.sunSoft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SYNTHETIC / DEVELOPMENT DATA – NOT REAL PARTICIPANT DATA',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800, color: CalmColors.attentionInk)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () => _seed(context, DemoScenario.settlingIn),
                          child: const Text('Settling in', textAlign: TextAlign.center),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () => _seed(context, DemoScenario.stillWorried),
                          child: const Text('Still worried', textAlign: TextAlign.center),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ],
              const SectionLabel('Understand'),
              tile(Icons.insights_rounded, CalmColors.teal, 'Parent summary',
                  'A few plain sentences first -- the full detail is one tap away',
                  const WellbeingInsightsScreen()),
              tile(Icons.sentiment_satisfied_alt_rounded, CalmColors.periwinkle, 'Worry picture scale',
                  'Ask before and after play (simple faces, not a validated test)',
                  const WorryScaleScreen()),
              tile(Icons.description_rounded, CalmColors.periwinkle, 'Reports',
                  'Ask about a report, X-ray or skin photo', const ReportScreen()),
              const SectionLabel('Look after'),
              tile(Icons.alarm_rounded, const Color(0xFFE58A5B), 'Reminders',
                  'Gentle play-time reminders', const RemindersScreen()),
              tile(Icons.settings_rounded, CalmColors.teal, 'Settings',
                  'Profile, language, privacy, data and export', const SettingsScreen()),
              const SectionLabel('Study tools', sub: 'For the research project'),
              tile(Icons.compare_arrows_rounded, CalmColors.periwinkle, 'Adaptive vs fixed',
                  'Study conditions side by side (descriptive only)',
                  const ConditionCompareScreen()),
              tile(Icons.fact_check_rounded, CalmColors.teal, 'Usability questionnaire',
                  'Grown-up SUS form, score above 68 is the usual benchmark',
                  const UsabilityScreen()),
              tile(Icons.smart_toy_rounded, const Color(0xFFE58A5B), 'Robot (KARA) simulator',
                  'Demo the robot check-in without a real robot',
                  const RobotSimulatorScreen()),
            ],
          );
        },
      ),
    );
  }

  Future<void> _seed(BuildContext context, DemoScenario sc) async {
    final err = await DemoSeeder.seed(sc);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Sample history loaded. Open the Support plan to see it.')));
  }
}
