import 'package:flutter/material.dart';
import '../insights/screening_report.dart';
import '../theme/app_theme.dart';

/// Behavioural Screening Summary (researcher / caregiver-facing, never for
/// the child). It shows ONLY a report file produced by the Python pipeline.
/// Nothing on this screen is computed or invented by the app.
class ScreeningReportScreen extends StatefulWidget {
  const ScreeningReportScreen({super.key});

  @override
  State<ScreeningReportScreen> createState() => _ScreeningReportScreenState();
}

class _ScreeningReportScreenState extends State<ScreeningReportScreen> {
  final _text = TextEditingController();
  ScreeningReport? _report;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      final r = ScreeningReport.parse(_text.text);
      setState(() {
        _report = r;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _report = null;
        _error = e.message;
      });
    }
  }

  Color _color(String level) {
    switch (level) {
      case 'HIGH':
        return const Color(0xFFE59A1B);
      case 'MODERATE':
        return const Color(0xFF4F7CFF);
      default:
        return const Color(0xFF3FBF94);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Behavioural Screening Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r == null) ...[
            const Text(
                'Run the Python pipeline (predict.py), open outputs/report_<child>.json, '
                'copy everything and paste it here. The app only displays that file.',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 14,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), hintText: 'Paste report JSON here'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _parse, child: const Text('Show summary')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ] else ...[
            if (r.isSynthetic)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFE3E3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red)),
                child: Text(
                    r.warning ??
                        'SYNTHETIC / DEVELOPMENT DATA - NOT REAL PARTICIPANT DATA.',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w800)),
              ),
            Text('Participant ${r.childId}', style: AppText.heading),
            Text('Based on ${r.sessions} sessions and ${r.responseEvents} recorded responses.',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            for (final i in r.indicators)
              Card(
                child: ListTile(
                  title: Text(i.label),
                  subtitle: Text(i.method +
                      (i.confidence == null
                          ? ''
                          : '  \u00B7  model confidence ${(i.confidence! * 100).round()}%')),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _color(i.level),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(i.level,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('Observed gameplay patterns', style: AppText.subheading),
            for (final p in r.patterns)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('\u2022 $p'),
              ),
            const SizedBox(height: 14),
            Text('Recommendation', style: AppText.subheading),
            Text(r.recommendation),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.softLavender,
                  borderRadius: BorderRadius.circular(14)),
              child: const Text(ScreeningReport.fixedDisclaimer,
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => setState(() => _report = null),
              child: const Text('Paste another report'),
            ),
          ],
        ],
      ),
    );
  }
}
