import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';

class MenuPage extends ConsumerWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fout: $e')),
          data: (me) {
            if (me == null) return const Center(child: Text('Geen actieve gebruiker'));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(me.name),
                    subtitle: Text('ID: ${me.id}'),
                  ),
                ),
                const SizedBox(height: 12),
                _GuildCard(me: me),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Account', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        FilledButton.icon(
                          onPressed: () => _confirmLogout(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('Uitloggen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uitloggen'),
        content: const Text('Terug naar het login-scherm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uitloggen')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authRepoProvider).signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Uitgelogd.')));
    }
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
            if (me.guildId != null)
              FutureBuilder<Map<String, dynamic>?>(
                future: ref.read(fsUserRepoProvider).getGuild(me.guildId!),
                builder: (context, snap) {
                  final invite = snap.data?['inviteCode'] as String?;
                  if (invite == null || invite.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Invite code: $invite'),
                        IconButton(
                          tooltip: 'Kopieer invite code',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: invite));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invite code gekopieerd.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (me.guildId == null) ...[
                  FilledButton(
                    onPressed: () => _openCreateGuildDialog(context, ref, me),
                    child: const Text('Guild maken'),
                  ),
                  OutlinedButton(
                    onPressed: () => _openJoinDialog(context, ref, me),
                    child: const Text('Join met invite'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => _confirmLeaveGuild(context, ref, me.id),
                    child: const Text('Guild verlaten'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateGuildDialog(BuildContext context, WidgetRef ref, UserProfile me) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guild maken'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Guild naam'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Maak aan')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) {
      if (context.mounted && ok == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guild naam is verplicht.')));
      }
      return;
    }
    try {
      final gid = await ref
          .read(fsUserRepoProvider)
          .createGuildAndJoin(ownerUid: me.id, name: controller.text.trim());
      await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guild aangemaakt.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Guild maken mislukt: $e')));
      }
    }
  }

  Future<void> _openJoinDialog(BuildContext context, WidgetRef ref, UserProfile me) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join guild'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) {
      if (context.mounted && ok == true) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invite code is verplicht.')));
      }
      return;
    }

    try {
      await ref
          .read(fsUserRepoProvider)
          .joinByInviteCode(uid: me.id, inviteCode: controller.text.trim().toUpperCase());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Je bent gejoined.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Join mislukt: $e')));
      }
    }
  }

  Future<void> _confirmLeaveGuild(BuildContext context, WidgetRef ref, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guild verlaten'),
        content: const Text('Weet je zeker dat je de guild wilt verlaten?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Verlaat')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(fsUserRepoProvider).leaveGuildSafely(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Guild verlaten.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verlaten mislukt: $e')));
      }
    }
  }
}
