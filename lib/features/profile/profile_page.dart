import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/features/skills/skill_tree_page.dart';
import 'package:household_rpg/theme/app_theme.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profiel')),
      body: AtmosphereBackground(
        child: SafeArea(
            child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (me) {
            if (me == null) return const Center(child: Text('Geen user geladen'));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EnterMotion(delayMs: 20, child: _NameCard(me: me)),
                const SizedBox(height: 12),
                EnterMotion(delayMs: 100, child: _StatsCard(me: me)),
                const SizedBox(height: 12),
                EnterMotion(delayMs: 120, child: _SkillXpCard(me: me)),
                const SizedBox(height: 12),
                const EnterMotion(delayMs: 140, child: _ThemeCard()),
                const SizedBox(height: 12),
                if (me.guildId != null)
                  EnterMotion(delayMs: 180, child: _GuildLeaderboard(guildId: me.guildId!)),
                const SizedBox(height: 12),
                if (me.guildId != null)
                  EnterMotion(delayMs: 220, child: _ActivityCard(guildId: me.guildId!)),
              ],
            );
          },
        )),
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

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
        content:
            TextField(controller: c, decoration: const InputDecoration(labelText: 'Guild name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final gid =
        await ref.read(fsUserRepoProvider).createGuildAndJoin(ownerUid: me.id, name: c.text.trim());
    await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);
  }

  Future<void> _openJoinDialog(BuildContext context, WidgetRef ref, UserProfile me) async {
    if (me.guildId != null) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join guild'),
        content:
            TextField(controller: c, decoration: const InputDecoration(labelText: 'Invite code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    await ref
        .read(fsUserRepoProvider)
        .joinByInviteCode(uid: me.id, inviteCode: c.text.trim().toUpperCase());
  }
}

class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeProvider);
    final ctrl = ref.read(themeProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {state.mode},
              onSelectionChanged: (s) => ctrl.setMode(s.first),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in [
                  Colors.teal,
                  Colors.orange,
                  Colors.cyan,
                  Colors.green,
                  Colors.indigo,
                  Colors.red,
                  Colors.pink,
                  Colors.lime,
                  Colors.blueGrey,
                  Colors.amber,
                ])
                  GestureDetector(
                    onTap: () => ctrl.setSeed(c),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: c,
                      child: state.seedColor.value == c.value
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
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
            Text('Guild coins: ${me.coins} 🪙'),
            Text('Solo coins: ${me.soloCoins} 🌟'),
            Text('Weekly points: ${me.weeklyPoints}'),
          ],
        ),
      ),
    );
  }
}

class _SkillXpCard extends StatelessWidget {
  final UserProfile me;
  const _SkillXpCard({required this.me});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vaardigheden', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Verdien XP via persoonlijke taken. Tik op een skill voor de skill tree.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final skill in SkillType.values) ...[
              _SkillRow(
                skill: skill,
                xp: me.skillXp[skill] ?? 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SkillTreePage(skill: skill)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final SkillType skill;
  final int xp;
  final VoidCallback onTap;
  const _SkillRow({required this.skill, required this.xp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final level = (xp / 200).floor();
    final xpInLevel = xp % 200;
    final progress = xpInLevel / 200.0;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: Text(
                skill.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Lv $level', style: Theme.of(context).textTheme.bodySmall),
            const Icon(Icons.chevron_right, size: 16),
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
            final together =
                users.fold<int>(0, (sum, u) => sum + u.weeklyPoints);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Samen deze week', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('$together punten samen',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                for (final u in users)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.favorite, size: 18),
                    title: Text(u.name),
                    trailing: Text('${u.weeklyPoints} pt'),
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

  static const _showTypes = {
    'completed',
    'purchased_item',
    'group_completed',
    // 'claimed',
    // 'unclaimed',
    // 'claimed_all_future',
    // 'unclaimed_all_future',
    // 'created_template',
    // 'updated_template',
    // 'deleted_template',
    // 'missed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_eventsProvider(guildId));
    final usersAsync = ref.watch(usersInMyGuildProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: eventsAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
          data: (events) {
            final users = usersAsync.value ?? const <UserProfile>[];
            final nameById = <String, String>{for (final u in users) u.id: u.name};
            final filtered = events.where((e) => _showTypes.contains(e.type)).toList();
            if (filtered.isEmpty) return const Text('Nog geen activiteit samen.');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jullie activiteit', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Text(_eventEmoji(e.type), style: const TextStyle(fontSize: 18)),
                        title: Text(_eventLine(e, nameById)),
                        subtitle: Text(DateFormat('dd MMM HH:mm').format(e.at)),
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

  String _eventLine(TaskEvent e, Map<String, String> nameById) {
    final actor = nameById[e.actorUserId] ?? e.actorUserId;
    final title = (e.payload['title'] as String?) ?? '?';
    final coins = e.payload['coins'];
    switch (e.type) {
      case 'completed':
        return '$actor voltooide "$title" en kreeg $coins 🪙';
      case 'claimed':
        return '$actor claimde "$title"';
      case 'unclaimed':
        return '$actor unclaimde "$title"';
      case 'claimed_all_future':
        return '$actor claimde alle toekomstige "$title" taken';
      case 'unclaimed_all_future':
        return '$actor unclaimde alle toekomstige "$title" taken';
      case 'created_template':
        return '$actor maakte template "$title" aan';
      case 'updated_template':
        return '$actor paste template "$title" aan';
      case 'deleted_template':
        return '$actor verwijderde template "$title"';
      case 'missed':
        return '"$title" is gemist';
      case 'purchased_item':
        return '$actor kocht "$title" voor $coins 🪙';
      case 'group_completed':
        return 'Coöp-quest "$title" samen afgerond! +$coins 🪙 voor allebei';
      default:
        return '$actor: ${e.type}';
    }
  }

  String _eventEmoji(String t) => switch (t) {
    'completed'            => '✅',
    'claimed'              => '📌',
    'unclaimed'            => '📤',
    'claimed_all_future'   => '📌',
    'unclaimed_all_future' => '📤',
    'created_template'     => '➕',
    'updated_template'     => '✏️',
    'deleted_template'     => '🗑️',
    'missed'               => '⚠️',
    'purchased_item'       => '🛍️',
    'group_completed'      => '🎉',
    _                      => '📝',
  };
}

final _eventsProvider = StreamProvider.autoDispose.family<List<TaskEvent>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchRecentEvents(guildId: gid, limit: 80);
});
