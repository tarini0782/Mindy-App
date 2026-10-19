import 'package:flutter/material.dart';
import '../games/models/game_session.dart';
import '../insights/rule_indicators.dart';

/// Caregiver cards for the rule-based indicators. Wording is always
/// "observed in play", never a diagnosis.
class RuleIndicatorCards extends StatelessWidget {
  final List<GameSession> sessions;
  const RuleIndicatorCards({super.key, required this.sessions});

  static const String disclaimer =
      'This application is a research prototype that records gameplay interactions '
      'and explores behavioural patterns. It does not provide a clinical diagnosis. '
      'These notes describe what happened in play ($kRuleVersion); the cut-offs are '
      'simple rules that have not been validated.';

  Color _colour(IndicatorLevel l) {
    switch (l) {
      case IndicatorLevel.noNotablePattern:
        return const Color(0xFF90A4AE);
      case IndicatorLevel.worthReviewing:
        return const Color(0xFF7986CB);
      case IndicatorLevel.notEnoughInformation:
        return const Color(0xFFCFD8DC);
    }
  }

  String _label(IndicatorLevel l) {
    switch (l) {
      case IndicatorLevel.noNotablePattern:
        return 'Nothing stood out';
      case IndicatorLevel.worthReviewing:
        return 'Worth looking at again';
      case IndicatorLevel.notEnoughInformation:
        return 'Not enough information';
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = RuleIndicators.compute(sessions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What was observed in play',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(disclaimer, style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        for (final i in list)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: ExpansionTile(
              leading: CircleAvatar(radius: 9, backgroundColor: _colour(i.level)),
              title: Text(i.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${_label(i.level)}. ${i.headline}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i.evidence.isNotEmpty)
                  Text('Evidence: ${i.evidence}',
                      style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text('Rule used: ${i.rule}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text('Other possible reasons: ${i.alternatives}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
      ],
    );
  }
}
