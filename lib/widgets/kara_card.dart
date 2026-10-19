import 'package:flutter/material.dart';
import '../services/kara_status.dart';

/// Honest KARA status card: never claims a real connection unless one exists.
class KaraCard extends StatelessWidget {
  const KaraCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: KaraStatusService.instance,
      builder: (context, _) {
        final link = KaraStatusService.instance.link;
        String text;
        Color color;
        switch (link) {
          case KaraLink.connected:
            text = 'KARA robot: connected';
            color = const Color(0xFF2E9E75);
            break;
          case KaraLink.simulated:
            text = 'KARA robot: simulated signal (test mode)';
            color = const Color(0xFFE59A1B);
            break;
          case KaraLink.notConnected:
            text = 'KARA robot: not connected';
            color = Colors.black45;
            break;
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Text('\u{1F916}', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ]),
        );
      },
    );
  }
}
