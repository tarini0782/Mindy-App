import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/vqa_client.dart';

/// Ask a question about a skin photo, X-ray or lab report. The picture goes to
/// the project's AI service; this screen only shows what comes back, with its
/// confidence and a clear "ask a doctor" message. If no service is
/// connected it says so and shows nothing invented.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  VqaModality _modality = VqaModality.lab;
  File? _image;
  List<int>? _bytes;
  String _name = 'picture.jpg';
  final TextEditingController _q =
      TextEditingController(text: 'What does this show, in simple words?');
  bool _busy = false;
  VqaOutcome? _outcome;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final picked = await ImagePicker().pickImage(source: src, maxWidth: 2048);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = File(picked.path);
        _bytes = bytes;
        _name = picked.name;
        _outcome = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open the picture.')));
    }
  }

  Future<void> _ask() async {
    final client = RemoteVqaClient.fromSettings();
    if (client == null) {
      setState(() => _outcome = const VqaOutcome.failed(
          'No analysis service is connected yet. Ask your clinician about this '
          'picture. (Researchers: set the https backend address in Settings.)'));
      return;
    }
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final r = await client.ask(
      modality: _modality,
      question: _q.text,
      imageBytes: _bytes ?? const [],
      filename: _name,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _outcome;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask about a report or picture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('1. What is the picture?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final m in VqaModality.values)
              ChoiceChip(
                key: Key('vqa_${m.code}'),
                label: Text(m.label),
                selected: _modality == m,
                onSelected: (_) => setState(() => _modality = m),
              ),
          ]),
          const SizedBox(height: 14),
          const Text('2. Choose the picture',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('vqa_camera'),
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Take a photo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('vqa_gallery'),
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('From gallery'),
              ),
            ),
          ]),
          if (_image != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 200, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 14),
          const Text('3. Your question',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          TextField(
            key: const Key('vqa_question'),
            controller: _q,
            maxLines: 2,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('vqa_ask'),
            onPressed: (_busy || _bytes == null) ? null : _ask,
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Ask'),
          ),
          const SizedBox(height: 4),
          const Text(
              'Only the picture and your question are sent. No name, child code or age.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          if (o != null) ...[
            const SizedBox(height: 16),
            if (!o.ok)
              _Box(
                  key: const Key('vqa_error'),
                  color: const Color(0xFFFFF3E0),
                  child: Text(o.error ?? 'Something went wrong.'))
            else
              _AnswerView(a: o.answer!),
          ],
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Box({super.key, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: child,
      );
}

class _AnswerView extends StatelessWidget {
  final VqaAnswer a;
  const _AnswerView({required this.a});

  @override
  Widget build(BuildContext context) {
    final pct = (a.confidence * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (a.showDoctorWarning)
        _Box(
          key: const Key('vqa_doctor'),
          color: const Color(0xFFFFEBEE),
          child: const Text(
              'Please show this to a doctor. The AI is not sure enough, or asked '
              'for a clinician to check.',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      const SizedBox(height: 10),
      _Box(
        key: const Key('vqa_answer'),
        color: const Color(0xFFE8F5E9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.answer, style: const TextStyle(fontSize: 16, height: 1.35)),
          const SizedBox(height: 10),
          Text('Confidence: $pct%', style: const TextStyle(fontWeight: FontWeight.w700)),
          LinearProgressIndicator(value: a.confidence),
          for (final f in a.findings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${f.label}: ${(f.probability * 100).round()}%'),
            ),
          if (a.heatmapUrl != null) ...[
            const SizedBox(height: 10),
            const Text('Where the AI looked', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Image.network(a.heatmapUrl!, height: 180, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text('(picture not available)')),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      Text(a.disclaimer, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
      if (a.modelVersion != null)
        Text('Model: ${a.modelVersion}', style: const TextStyle(fontSize: 11)),
    ]);
  }
}
