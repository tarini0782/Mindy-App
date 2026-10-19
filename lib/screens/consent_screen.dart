import 'package:flutter/material.dart';
import '../characters/friend_view.dart';
import '../services/account_service.dart';

/// Two short steps: (1) caregiver consent, (2) a child-friendly "is it OK?"
/// assent screen. Saying no to research never blocks play: the child can use
/// the Games tab and nothing is saved for research.
///
/// THE WORDING BELOW IS A PLACEHOLDER FOR THE TEAM'S ETHICS-APPROVED TEXT.
/// Replace it with the approved information sheet before any real child
/// takes part.
class ConsentScreen extends StatefulWidget {
  final ChildProfile child;
  const ConsentScreen({super.key, required this.child});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _isGuardian = false;
  bool? _agree;
  int _step = 0;

  Future<void> _finish({required bool childYes}) async {
    await AccountService.instance.recordConsent(widget.child.id,
        caregiverAgrees: _agree == true, childAgrees: childYes);
    // When this screen is the app's home (first-run gate) there is nothing to
    // pop: the gate switches screens by itself.
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consent'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: _step == 0 ? _caregiver(context) : _child(context),
      ),
    );
  }

  Widget _caregiver(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('For ${widget.child.nickname}’s grown-up',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Mindy is a university research prototype. It is not a medical or '
              'diagnostic tool and does not tell you whether your child has any condition.'),
          const SizedBox(height: 10),
          const Text('If you agree, while your child plays the "Adventure" the app saves on THIS device:\n'
              '• which games were played, and how (taps, right and wrong moves, how long responses took, '
              'whether help was used);\n'
              '• the feeling your child picked before and after playing;\n'
              '• a random code (like P-7K3F9A) instead of your child’s name.\n\n'
              'Not collected: photos, voice, video, location, contacts, or your child’s full birth date. '
              'The nickname stays on this device and is never part of an export.'),
          const SizedBox(height: 10),
          const Text('You can say no and your child can still play every game in the Games tab. '
              'You can stop at any time and delete your child’s saved data from Settings.'),
          const SizedBox(height: 14),
          CheckboxListTile(
            value: _isGuardian,
            onChanged: (v) => setState(() => _isGuardian = v ?? false),
            title: const Text('I am this child’s parent or legal guardian'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isGuardian
                ? () => setState(() {
                      _agree = true;
                      _step = 1;
                    })
                : null,
            child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Yes, save research play data')),
          ),
          OutlinedButton(
            onPressed: _isGuardian
                ? () {
                    _agree = false;
                    _finish(childYes: false);
                  }
                : null,
            child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No, play without saving research data')),
          ),
          const SizedBox(height: 10),
          Text('Wording version: $kConsentVersion (placeholder until ethics-approved text is added)',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      );

  Widget _child(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The child's own friend asks, not a unicorn: this is the
            // assent screen, and it should be the same face that guides
            // every other child-facing screen.
            const Center(child: FriendView(size: 110)),
            const SizedBox(height: 10),
            Text('Hi ${widget.child.nickname}!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text(
                'Mindy would like to watch how you play, so grown-ups can learn about games. '
                'You can say no. You can stop any time. Nobody will be cross.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => _finish(childYes: true),
              child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('\u{1F44D} Yes, let’s play!', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _finish(childYes: false),
              child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Not now', style: TextStyle(fontSize: 20))),
            ),
          ],
        ),
      );
}
