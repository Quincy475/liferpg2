import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) return const Center(child: CircularProgressIndicator());

    final membersAsync = ref.watch(usersInMyGuildProvider);
    final eventsAsync = ref.watch(taskEventsProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: Text(me.name),
            subtitle: Text('UID: ${me.id}\nGuild: ${me.guildId ?? '-'}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editName(context, ref, me),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (me.guildId == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nog geen guild gekoppeld.'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _createGuild(context, ref, me.id),
                        child: const Text('Create guild'),
                      ),
                      OutlinedButton(
                        onPressed: () => _joinGuild(context, ref, me.id),
                        child: const Text('Join by code'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        Card(
          child: ListTile(
            title: const Text('Stats'),
            subtitle: Text('Coins: ${me.coins}\nWeekly points: ${me.weeklyPoints}'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Guild score deze week', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                membersAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Fout: $e'),
                  data: (members) {
                    if (members.isEmpty) return const Text('Nog geen leden zichtbaar.');
                    final sorted = [...members]
                      ..sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
                    return Column(
                      children: [
                        for (final m in sorted)
                          ListTile(
                            dense: true,
                            title: Text(m.name),
                            trailing: Text('${m.weeklyPoints}'),
                          ),
                      ],
                    );
                  },
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task activity feed', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                eventsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Fout: $e'),
                  data: (events) {
                    if (events.isEmpty) return const Text('Nog geen task events.');
                    final filtered = events
                        .where((e) => e.type == 'completed' || e.type == 'claimed' || e.type == 'missed')
                        .take(30)
                        .toList();
                    return Column(
                      children: [
                        for (final e in filtered)
                          ListTile(
                            dense: true,
                            title: Text('${e.type.toUpperCase()} • ${e.payload['title'] ?? e.instanceId}'),
                            subtitle: Text('door ${e.actorUserId} • ${e.at}'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, UserProfile me) async {
    final c = TextEditingController(text: me.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Naam wijzigen'),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(fsUserRepoProvider).updateName(me.id, c.text.trim());
    }
  }

  Future<void> _createGuild(BuildContext context, WidgetRef ref, String uid) async {
    final c = TextEditingController(text: 'Home Guild');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Create guild'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Guild name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Create')),
        ],
      ),
    );

    if (ok == true) {
      final gid = await ref.read(fsUserRepoProvider).createGuildAndJoin(ownerUid: uid, name: c.text.trim());
      await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guild aangemaakt.')));
      }
    }
  }

  Future<void> _joinGuild(BuildContext context, WidgetRef ref, String uid) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Join guild met code'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Invite code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Join')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(fsUserRepoProvider).joinByInviteCode(uid: uid, inviteCode: c.text.trim());
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Join mislukt: $e')));
        }
      }
    }
  }
}
