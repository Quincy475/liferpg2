import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (me) {
            if (me == null) return const Center(child: Text('Geen user geladen'));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NameCard(me: me),
                const SizedBox(height: 12),
                _GuildCard(me: me),
                const SizedBox(height: 12),
                _StatsCard(me: me),
                const SizedBox(height: 12),
                if (me.guildId != null) _GuildLeaderboard(guildId: me.guildId!),
                const SizedBox(height: 12),
                if (me.guildId != null) _ActivityCard(guildId: me.guildId!),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NameCard extends ConsumerStatefulWidget {
  final UserProfile me;
  const _NameCard({required this.me});

  @override
  ConsumerState<_NameCard> createState() => _NameCardState();
}

class _NameCardState extends ConsumerState<_NameCard> {
  late final TextEditingController _c = TextEditingController(text: widget.me.name);
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _c,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
            ),
            const SizedBox(width: 8),
            _busy
                ? const CircularProgressIndicator()
                : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      setState(() => _busy = true);
                      await ref.read(fsUserRepoProvider).updateName(widget.me.id, _c.text.trim());
                      if (mounted) setState(() => _busy = false);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

class _GuildCard extends ConsumerWidget {
  final UserProfile me;
  const _GuildCard({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guild', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(me.guildId == null ? 'Nog geen guild' : 'Guild ID: ${me.guildId}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (me.guildId == null) ...[
                  FilledButton(
                    onPressed: () => _openCreateGuildDialog(context, ref, me),
                    child: const Text('Create guild'),
                  ),
                  OutlinedButton(
                    onPressed: () => _openJoinDialog(context, ref, me),
                    child: const Text('Join with invite'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => ref.read(fsUserRepoProvider).leaveGuild(me.id),
                    child: const Text('Leave guild'),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateGuildDialog(BuildContext context, WidgetRef ref, UserProfile me) async {
    if (me.guildId != null) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create guild'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Guild name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final gid = await ref.read(fsUserRepoProvider).createGuildAndJoin(ownerUid: me.id, name: c.text.trim());
    await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);
  }

  Future<void> _openJoinDialog(BuildContext context, WidgetRef ref, UserProfile me) async {
    if (me.guildId != null) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join guild'),
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Invite code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await ref.read(fsUserRepoProvider).joinByInviteCode(uid: me.id, inviteCode: c.text.trim().toUpperCase());
  }
}

class _StatsCard extends StatelessWidget {
  final UserProfile me;
  const _StatsCard({required this.me});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stats', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Total coins: ${me.coins}'),
            Text('Weekly points: ${me.weeklyPoints}'),
          ],
        ),
      ),
    );
  }
}

class _GuildLeaderboard extends ConsumerWidget {
  final String guildId;
  const _GuildLeaderboard({required this.guildId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersInMyGuildProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: usersAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (users) {
            final sorted = [...users]..sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly group ranking', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < sorted.length; i++)
                  ListTile(
                    dense: true,
                    title: Text(sorted[i].name),
                    trailing: Text('${sorted[i].weeklyPoints}'),
                    leading: Text('#${i + 1}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  final String guildId;
  const _ActivityCard({required this.guildId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_eventsProvider(guildId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: eventsAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (events) {
            final filtered = events.where((e) => ['completed', 'claimed', 'missed'].contains(e.type)).toList();
            if (filtered.isEmpty) return const Text('Nog geen task activity.');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent completed tasks / activity', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Text(_eventEmoji(e.type)),
                        title: Text(e.type),
                        subtitle: Text('by ${e.actorUserId} • ${DateFormat('dd MMM HH:mm').format(e.at)}'),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _eventEmoji(String t) {
    switch (t) {
      case 'completed':
        return '✅';
      case 'claimed':
        return '📌';
      case 'missed':
        return '⚠️';
      default:
        return '📝';
    }
  }
}

final _eventsProvider = StreamProvider.autoDispose.family<List<TaskEvent>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchRecentEvents(guildId: gid, limit: 80);
});
