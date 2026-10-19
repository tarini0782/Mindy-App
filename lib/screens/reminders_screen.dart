import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class Reminder {
  final String title;
  final TimeOfDay time;
  Reminder({required this.title, required this.time});
}

/// FR5: medication & appointment reminders.
/// v1 scope: reminders are stored in memory and fired via device-local
/// notifications a few seconds after being added (so you can actually
/// demo one firing), not scheduled for a real future time via a
/// server. Real server-side scheduling (Firebase Cloud Messaging) is
/// documented as deferred -- see notification_service.dart.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final List<Reminder> _reminders = [];
  final _titleController = TextEditingController();
  TimeOfDay _pickedTime = TimeOfDay.now();

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _pickedTime);
    if (t != null) setState(() => _pickedTime = t);
  }

  void _addReminder() {
    if (_titleController.text.trim().isEmpty) return;
    final reminder = Reminder(
      title: _titleController.text.trim(),
      time: _pickedTime,
    );
    setState(() => _reminders.add(reminder));
    _titleController.clear();

    // Demo firing: shows a real notification a few seconds later so you
    // can prove the mechanism works end-to-end during a demo.
    //
    // The time string is formatted NOW, not inside the callback: the
    // callback runs five seconds later, by which point this screen may be
    // gone, and using its BuildContext then would throw.
    final whenText = reminder.time.format(context);
    Future.delayed(const Duration(seconds: 5), () {
      NotificationService.instance.showNow(
        title: 'Reminder: ${reminder.title}',
        body: 'Scheduled for $whenText',
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Reminder (e.g. "Evening medication")',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Time: ${_pickedTime.format(context)}')),
                TextButton(onPressed: _pickTime, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _addReminder,
              child: const Text('Add reminder'),
            ),
            const Divider(height: 32),
            Expanded(
              child: _reminders.isEmpty
                  ? const Center(child: Text('No reminders yet.'))
                  : ListView.builder(
                      itemCount: _reminders.length,
                      itemBuilder: (context, i) {
                        final r = _reminders[i];
                        return ListTile(
                          leading: const Icon(Icons.alarm),
                          title: Text(r.title),
                          subtitle: Text(r.time.format(context)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
