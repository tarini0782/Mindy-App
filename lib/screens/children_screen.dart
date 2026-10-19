import 'package:flutter/material.dart';
import '../services/account_service.dart';
import 'consent_screen.dart';

/// Caregiver's child profiles: add, select, edit, change consent, delete.
class ChildrenScreen extends StatelessWidget {
  final bool fromSettings;
  const ChildrenScreen({super.key, this.fromSettings = false});

  Future<void> _add(BuildContext context) async {
    final nick = TextEditingController();
    final year = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add a child'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nick,
                decoration: const InputDecoration(
                    labelText: 'Nickname (not shared)')),
            TextField(
                controller: year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Birth year, e.g. 2019')),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err!, style: const TextStyle(color: Colors.red)),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final e = await AccountService.instance.addChild(
                    nickname: nick.text, birthYear: int.tryParse(year.text.trim()));
                if (e != null) {
                  setS(() => err = e);
                } else if (ctx.mounted) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nick.dispose();
    year.dispose();
    // The sign-in gate (main.dart) shows the consent screen by itself as soon
    // as the active child has not answered consent yet.
    if (ok == true && fromSettings && context.mounted) Navigator.pop(context);
  }

  Future<void> _delete(BuildContext context, ChildProfile c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${c.nickname}?'),
        content: const Text(
            'This erases the profile and ALL of this child’s saved play data on this device. It cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await AccountService.instance.deleteChild(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final a = AccountService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who is playing?'),
        automaticallyImplyLeading: fromSettings,
        actions: [
          if (!fromSettings)
            TextButton(onPressed: a.logout, child: const Text('Sign out')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add child'),
      ),
      body: AnimatedBuilder(
        animation: a,
        builder: (context, _) {
          final kids = a.myChildren;
          if (kids.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No child profiles yet. Tap "Add child".',
                  textAlign: TextAlign.center),
            ));
          }
          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              for (final c in kids)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                        child: Text(c.nickname.isEmpty ? '?' : c.nickname[0].toUpperCase())),
                    title: Text(c.nickname),
                    subtitle: Text(
                        'Research data: ${c.researchEnabled ? 'ON' : 'OFF'}'
                        '${c.consentAnswered ? '' : ' (consent not answered yet)'}\n'
                        'Code ${c.participantId}'),
                    isThreeLine: true,
                    selected: a.activeChild?.id == c.id,
                    onTap: () async {
                      await a.selectChild(c.id);
                      if (fromSettings && context.mounted) Navigator.pop(context);
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'consent') {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ConsentScreen(child: c)));
                        } else if (v == 'delete') {
                          await _delete(context, c);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'consent', child: Text('Change consent')),
                        PopupMenuItem(value: 'delete', child: Text('Delete child and data')),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
