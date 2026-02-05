import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/config/furniture.dart';
import 'package:household_rpg/data/models/user_profile.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/features/pet/data/furniture_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We werken met streams zodat alles realtime meeloopt
    final meAsync = ref.watch(currentUserProvider);

    return meAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (me) {
        if (me == null) {
          return const Center(child: Text('Geen gebruiker geladen.'));
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HeaderSection(me: me)),
            SliverToBoxAdapter(child: _StatsRow(me: me)),
            SliverToBoxAdapter(child: _SkillsSection(me: me)),
            SliverToBoxAdapter(child: _InventorySection(me: me)),
            SliverToBoxAdapter(child: _GuildSection(me: me)),
            SliverToBoxAdapter(child: _BadgesStreaksSection(me: me)),
            SliverToBoxAdapter(child: _SettingsSection()),
            SliverToBoxAdapter(child: _AccountLinkingSection()),
            if (_isDebugBuild) SliverToBoxAdapter(child: _DevToolsSection(me: me)),
            SliverToBoxAdapter(child: _HowItWorks()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

bool get _isDebugBuild {
  var inDebug = false;
  assert(inDebug = true);
  return inDebug;
}

/// ========== HEADER (avatar + naam) ==========
class _HeaderSection extends ConsumerWidget {
  final UserProfile me;
  const _HeaderSection({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(fsUserRepoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          // Avatar (placeholder, upload later met Firebase Storage)
          // CircleAvatar(
          //   radius: 30,
          //   // backgroundImage: (me.avatarUrl != null) ? NetworkImage(me.avatarUrl!) : null,
          //   child: (me.avatarUrl == null) ? const Icon(Icons.person, size: 30) : null,
          // ),
          const SizedBox(width: 16),
          Expanded(
            child: _EditableName(
              initial: me.name,
              onSubmit: (value) async => repo.updateName(me.id, value.trim()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Avatar wijzigen (koppelen aan opslag in volgende stap)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avatar upload komt in volgende stap.')),
              );
            },
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }
}

class _EditableName extends StatefulWidget {
  final String initial;
  final Future<void> Function(String) onSubmit;
  const _EditableName({required this.initial, required this.onSubmit});

  @override
  State<_EditableName> createState() => _EditableNameState();
}

class _EditableNameState extends State<_EditableName> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: _submit,
          ),
        ),
        const SizedBox(width: 8),
        _busy
            ? const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                tooltip: 'Opslaan',
                icon: const Icon(Icons.check),
                onPressed: () => _submit(_c.text),
              ),
      ],
    );
  }

  Future<void> _submit(String v) async {
    if (v.trim().isEmpty) return;
    setState(() => _busy = true);
    await widget.onSubmit(v);
    if (mounted) setState(() => _busy = false);
  }
}

/// ========== STATS ROW ==========
class _StatsRow extends StatelessWidget {
  final UserProfile me;
  const _StatsRow({required this.me});

  @override
  Widget build(BuildContext context) {
    final chipStyle = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _StatChip(icon: '🪙', label: '${me.coins}', style: chipStyle),
          _StatChip(icon: '⭐', label: '${me.weeklyPoints}', style: chipStyle),
          if (me.crown) _StatChip(icon: '👑', label: 'Crowned', style: chipStyle),
          if (me.guildId != null)
            _StatChip(icon: '🏰', label: 'Guild: ${me.guildId}', style: chipStyle),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final TextStyle? style;
  const _StatChip({required this.icon, required this.label, this.style});
  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$icon  $label', style: style));
  }
}

/// ========== SKILLS ==========
class _SkillsSection extends StatelessWidget {
  final UserProfile me;
  const _SkillsSection({required this.me});

  @override
  Widget build(BuildContext context) {
    return _CardBlock(
      title: 'Skills',
      trailing: FilledButton(
          onPressed: () {
            // open skill tree page (te bouwen)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Skill Tree komt in volgende stap.')),
            );
          },
          child: const Text('Open Skill Tree')),
      child: Column(
        children: [
          for (final s in SkillType.values)
            _SkillRow(
              label: s.name,
              xp: me.skillXp[s] ?? 0,
            ),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  final String label;
  final int xp;
  const _SkillRow({required this.label, required this.xp});

  @override
  Widget build(BuildContext context) {
    final level = _levelFromXp(xp);
    final pct = _pctToNextLevel(xp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: pct, minHeight: 10),
            ),
          ),
          const SizedBox(width: 8),
          Text('Lv $level'),
        ],
      ),
    );
  }
}

int _levelFromXp(int xp) => (xp / 200).floor(); // voorbeeld
double _pctToNextLevel(int xp) {
  final cur = xp % 200;
  return cur / 200.0;
}

/// ========== INVENTORY / LOOT ==========
class _InventorySection extends ConsumerWidget {
  final UserProfile me;
  const _InventorySection({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(userInventoryProvider);

    return _CardBlock(
      title: 'Inventory',
      trailing: TextButton(
        onPressed: () => _openPurchases(context, ref),
        child: const Text('Aankopen'),
      ),
      child: invAsync.when(
        loading: () =>
            const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),
        error: (e, _) => Text('Inventory error: $e'),
        data: (items) {
          if (items.isEmpty) return const Text('Leeg. Verdien loot door quests!');
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (e) => InputChip(
                    label: Text('${e.name} ×${e.quantity}'),
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('${e.name} gebruiken komt later.')));
                    },
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  void _openPurchases(BuildContext context, WidgetRef ref) async {
    final list = await ref.read(fsUserRepoProvider).getPurchases(me.id);
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Aankoopgeschiedenis', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final p in list)
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(p.itemId),
              subtitle: Text('€? • ${p.at}'), // at = DateTime
              trailing: Text('🪙 ${p.price}'),
            ),
        ],
      ),
    );
  }
}

/// ========== GUILD ==========
class _GuildSection extends ConsumerWidget {
  final UserProfile me;
  const _GuildSection({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (me.guildId == null) {
      return _CardBlock(
        title: 'Guild',
        child: Row(
          children: [
            const Expanded(child: Text('Nog geen guild. Sluit je aan of maak er één.')),
            FilledButton(
                onPressed: () => _showJoinGuildDialog(context, ref, me.id),
                child: const Text('Join')),
          ],
        ),
      );
    }

    final membersAsync = ref.watch(usersInMyGuildProvider);
    return _CardBlock(
      title: 'Guild',
      trailing: FilledButton.tonal(
        onPressed: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guild Shop volgt.'))),
        child: const Text('Guild Shop'),
      ),
      child: membersAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Guild error: $e'),
        data: (members) => Column(
          children: [
            for (final u in members)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(u.name),
                subtitle: Text('🪙 ${u.coins} • ⭐ ${u.weeklyPoints}'),
                trailing: (u.id == me.id) ? const Text('You') : null,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => ref.read(fsUserRepoProvider).leaveGuild(me.id),
                child: const Text('Leave guild'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showJoinGuildDialog(BuildContext context, WidgetRef ref, String uid) {
  final c = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Join guild'),
      content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Guild ID')),
      actions: [
        TextButton(
            onPressed: () async {
              await ref.read(fsUserRepoProvider).createGuildAndJoin(ownerUid: uid, name: 'TEMP');
            },
            child: const Text('Create guild')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(fsUserRepoProvider).joinGuild(uid, c.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Join'),
        ),
      ],
    ),
  );
}

/// ========== BADGES & STREAKS ==========
class _BadgesStreaksSection extends StatelessWidget {
  final UserProfile me;
  const _BadgesStreaksSection({required this.me});

  @override
  Widget build(BuildContext context) {
    final badges = me.badges.toList()..sort();
    final streaks = me.streaks.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return _CardBlock(
      title: 'Badges & Streaks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.isEmpty
                ? [const Text('Nog geen badges.')]
                : badges.map((b) => Chip(label: Text(b))).toList(),
          ),
          const SizedBox(height: 12),
          if (streaks.isEmpty)
            const Text('Nog geen streaks.')
          else
            ...streaks.take(3).map((e) => ListTile(
                  leading: const Icon(Icons.local_fire_department),
                  title: Text(e.key),
                  trailing: Text('${e.value}d'),
                )),
        ],
      ),
    );
  }
}

/// ========== INSTELLINGEN (thema reeds aanwezig) ==========
class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final controller = ref.read(themeProvider.notifier);

    final modes = const [
      {'label': 'Systeem', 'mode': ThemeMode.system},
      {'label': 'Licht', 'mode': ThemeMode.light},
      {'label': 'Donker', 'mode': ThemeMode.dark},
    ];

    final seeds = [
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.green,
      Colors.blue,
      Colors.deepPurple,
      Colors.orange,
      Colors.cyan,
      Colors.brown,
      Colors.red,
      Colors.lime,
    ];

    return _CardBlock(
      title: 'Instellingen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final selected = theme.mode == m['mode'];
              return ChoiceChip(
                label: Text(m['label'] as String),
                selected: selected,
                onSelected: (_) => controller.setMode(m['mode'] as ThemeMode),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: seeds.map((c) {
              final sel = theme.seedColor.value == c.value;
              return GestureDetector(
                onTap: () => controller.setSeed(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          sel ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.black12,
                      width: sel ? 3 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, spreadRadius: 0.5, color: Colors.black12)
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 28),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Daily reminders'),
            subtitle: const Text('Herinnering voor je dagelijkse quests'),
          ),
          SwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Co-op updates'),
            subtitle: const Text('Push bij co-op progressie'),
          ),
        ],
      ),
    );
  }
}

/// ========== ACCOUNT LINKING ==========
class _AccountLinkingSection extends StatelessWidget {
  const _AccountLinkingSection();

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    final isAnon = u?.isAnonymous ?? true;

    return _CardBlock(
      title: 'Account',
      child: Row(
        children: [
          Icon(isAnon ? Icons.question_mark : Icons.verified_user),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isAnon
                ? 'Je gebruikt nu een anonieme account. Koppel voor veilige opslag & multi-device.'
                : 'Account gekoppeld — je voortgang is veilig.'),
          ),
          if (isAnon)
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Koppelen (Google/Apple) komt in volgende stap.')),
                );
              },
              child: const Text('Koppel'),
            ),
        ],
      ),
    );
  }
}

/// ========== DEV TOOLS ==========
class _DevToolsSection extends ConsumerWidget {
  final UserProfile me;
  const _DevToolsSection({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CardBlock(
      title: 'Dev Tools',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: () => ref.read(fsUserRepoProvider).addCoins(me.id, 5000),
            child: const Text('+5000 Coins'),
          ),
          FilledButton(
            onPressed: () => ref.read(fsUserRepoProvider).addSkillXp(me.id, SkillType.cleaning, 50),
            child: const Text('+50 XP Cleaning'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(taskRepoProvider).seedDemoTasks();
              await ref.read(eventRepoProvider).seedDemoEvents();
              await ref.read(raidRepoProvider).seedDemoRaid();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Demo data toegevoegd.')),
                );
              }
            },
            child: const Text('Seed demo data'),
          ),
          ElevatedButton(
            onPressed: () async {
              final uid = ref.read(currentUserIdProvider);
              if (uid == null) return;

              final repo = ref.read(furnitureRepoProvider);
              // final game = ref.read(petRoomGameProvider); // of waar je game instance zit

              // 1) config
              await repo.seedWindowConfig();

              // 2) user
              await repo.seedWindowsForUser(uid);

              // 3) local render (debug zichtbaar)
              // await game.setActiveWindowLocally('window_basic');

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Windows seeded & activated')),
              );
            },
            child: const Text('🪟 Seed Windows (DEBUG)'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(furnitureRepoProvider).seedFurnitureForUser(me.id);
            },
            child: const Text('Seed furniture config'),
          )
        ],
      ),
    );
  }
}

/// ========== HOW IT WORKS ==========
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('How it works (short)'),
      children: const [
        ListTile(
            title: Text('• Taken geven punten en coins; events/skills/streaks geven multipliers.')),
        ListTile(
            title: Text('• Loot kans 12% (+5% bij hogere skill tiers). Golden ticket zeldzaam.')),
        ListTile(title: Text('• Weekly reset → crown naar #1, raid goal reset.')),
        ListTile(title: Text('• Shop: Me & Guild; sommige items vereisen golden ticket.')),
      ],
    );
  }
}

/// ========== Card helper ==========
class _CardBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _CardBlock({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
