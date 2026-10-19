import 'package:flutter/material.dart';
import '../characters/companion.dart';
import '../services/account_service.dart';
import '../services/app_settings.dart';
import '../services/insight_summary_service.dart';
import 'children_screen.dart';
import '../services/journey_controller.dart';
import '../services/language_service.dart';
import '../services/reward_service.dart';
import '../services/session_repository.dart';
import '../theme/app_theme.dart';
import 'character_creator_screen.dart';
import '../services/avatar_service.dart';
import 'researcher_screen.dart';

/// Grown-up settings (behind the grown-up check): sound, music, dress-up,
/// reset, and the PIN-protected researcher mode.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Researcher mode needs a signed-in account with the researcher role
  /// AND the password typed again. There is no PIN.
  Future<void> _openResearcher(BuildContext context) async {
    final acc = AccountService.instance;
    if (!acc.isResearcher) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Researcher mode needs a researcher account.')));
      return;
    }
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm your password'),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, acc.confirmPassword(c.text)),
              child: const Text('Open')),
        ],
      ),
    );
    c.dispose();
    if (ok == true && context.mounted) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResearcherScreen()));
    } else if (ok == false && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password is not right')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_rounded),
              title: const Text('Sound effects'),
              value: s.sfxOn,
              onChanged: s.setSfx,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.music_note_rounded),
              title: const Text('Background music'),
              subtitle: const Text('Calm for calming activities, light for others'),
              value: s.musicOn,
              onChanged: s.setMusic,
            ),
            ListTile(
              leading: const Icon(Icons.face_retouching_natural_rounded),
              title: const Text('My characters'),
              subtitle: const Text(
                  'Make and switch between characters. Free, nothing locked.'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyCharactersScreen())),
            ),
            // v39: "Dress up Kara" (CompanionScreen) was removed from the
            // app's navigation. It was a second character-customisation
            // system competing with AvatarService, which is what made the
            // app feel like different characters on different screens.
            // Nothing was lost: CompanionLook was never persisted, so there
            // is no saved data to migrate. The tile above ("My characters")
            // is now the single way in. The file itself is left in the repo
            // rather than deleted; CompanionService still tints the world
            // characters internally.
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Language / \u0DB7\u0DCF\u0DC2\u0DCF\u0DC0 / \u0BAE\u0BCA\u0BB4\u0BBF'),
              subtitle: Text('${LanguageService.instance.lang.nativeName}'
                  '  \u00B7  Sinhala and Tamil are drafts until a native speaker checks them'),
              onTap: () async {
                final l = await showDialog<AppLang>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Language'),
                    children: [
                      for (final x in AppLang.values)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, x),
                          child: Text(x.nativeName,
                              style: const TextStyle(fontSize: 18)),
                        ),
                    ],
                  ),
                );
                if (l != null) await LanguageService.instance.setLang(l);
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Smarter wording for the support plan'),
              subtitle: const Text(
                  'Off by default. When on, the Support plan screen may send its own '
                  'already-computed numbers (never a name or a raw session) to an AI '
                  'service to write one friendlier paragraph. The plain version is always '
                  'shown too. Needs a working backend address below.'),
              isThreeLine: true,
              value: s.aiInsightsEnabled,
              onChanged: (v) async {
                await s.setAiInsightsEnabled(v);
                if (!v) InsightSummaryService.instance.reset();
              },
            ),
            const Divider(),
            AnimatedBuilder(
              animation: AccountService.instance,
              builder: (context, _) {
                final a = AccountService.instance;
                return Column(children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('Signed in as ${a.user?.username ?? '-'}'),
                    subtitle: Text(a.isResearcher ? 'Researcher account' : 'Caregiver account'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.child_care),
                    title: const Text('Children, consent and data'),
                    subtitle: const Text('Switch child, change consent, delete data'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChildrenScreen(fromSettings: true))),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () => a.logout(),
                  ),
                ]);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('Researcher mode'),
              subtitle: const Text('Researcher account only: study condition, raw data, export'),
              onTap: () => _openResearcher(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Reset this child's progress",
                  style: TextStyle(color: Colors.red)),
              subtitle: const Text("Deletes this child's stored sessions and adventure"),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete all progress?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  final pid = AppSettings.instance.childId;
                  await SessionRepository.instance.deleteForChild(pid);
                  await JourneyController.instance.reset();
                  RewardService.instance.clear();
                  CompanionService.instance.reset();
                  // v28: the child's saved characters are their data too.
                  await AvatarService.instance.clearForChild(pid);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Mindy & this project'),
              subtitle: Text(
                  'Mindy is one research component of a larger student project. '
                  'Tap to read more.',
                  style: AppText.body.copyWith(fontSize: 13)),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('About Mindy & this project'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Mindy is a magical adventure that chooses activities using '
                      'how a child says they feel and simple gameplay indicators. '
                      'It is not a medical, psychological or diagnostic tool; '
                      'its effectiveness is being evaluated.\n\n'
                      'Mindy is the emotion-adaptive CBT mini-game part of a larger '
                      'final-year university project building an AI-driven '
                      'multiplatform pediatric healthcare assistance system. That '
                      'wider project is made up of several components, built by '
                      'different student researchers, that work alongside Mindy as '
                      'part of the same system. This app covers only the Mindy '
                      'component -- it is not the whole project.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
