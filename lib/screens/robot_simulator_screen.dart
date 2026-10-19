import 'package:flutter/material.dart';
import '../models/emotion_state.dart';
import '../services/app_settings.dart';

/// Pretend the KARA robot sent a check-in, to demonstrate the integration
/// without the real robot. The signal is always stored as KARA_SIMULATED so
/// it can never be mistaken for the real robot.
class RobotSimulatorScreen extends StatelessWidget {
  const RobotSimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Robot (KARA) simulator')),
      body: AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                color: const Color(0xFFFFE082),
                child: const Text('SIMULATION – no real robot is connected.',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              const Text(
                  'Choose what the "robot" says the child feels. The next time the '
                  'child opens the check-in, a card appears: "KARA noticed you might '
                  'feel ...". The child can accept it or pick their own feeling. '
                  'Without a robot signal the app always shows its normal check-in.'),
              const SizedBox(height: 12),
              if (!s.useMockBackend)
                const Text(
                    'The simulator only works while the offline mock backend is on '
                    '(Researcher mode > Data). It is off now.',
                    style: TextStyle(color: Colors.red)),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in EmotionState.values)
                    ChoiceChip(
                      label: Text('${e.faceEmoji} ${e.label}'),
                      selected: s.simulatedKara == e,
                      onSelected: s.useMockBackend
                          ? (_) => s.setSimulatedKara(e)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: s.simulatedKara == null ? null : () => s.setSimulatedKara(null),
                child: const Text('Stop simulating'),
              ),
              const SizedBox(height: 12),
              Text(s.simulatedKara == null
                  ? 'Status: no simulated robot signal.'
                  : 'Status: robot says "${s.simulatedKara!.label}" (simulated, valid for 15 minutes from each check).'),
            ],
          );
        },
      ),
    );
  }
}
