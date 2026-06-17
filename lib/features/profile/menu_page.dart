import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                _CoupleCard(me: me),
                const SizedBox(height: 12),
                _AccountCard(me: me),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final UserProfile me;
  const _AccountCard({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnon = ref.watch(isFirebaseAnonymousProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            if (isAnon) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Beveilig je voortgang: voeg een e-mail toe. Zonder e-mail is '
                      'je account aan dit toestel gebonden.',
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _openLinkEmailDialog(context, ref),
                      icon: const Icon(Icons.alternate_email),
                      label: const Text('Voeg e-mail toe'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Uitloggen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLinkEmailDialog(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-mail koppelen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Wachtwoord (min. 8 tekens)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Koppel')),
        ],
      ),
    );
    if (ok != true) return;

    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) || pass.length < 8) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geldige e-mail en wachtwoord (min. 8) vereist.')),
        );
      }
      return;
    }

    try {
      await ref.read(authRepoProvider).linkEmailPassword(email: email, password: pass);
      await ref.read(fsUserRepoProvider).userRef(me.id).set(
        {
          'email': email,
          'authProvider': 'password',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail gekoppeld. Je voortgang is nu veilig.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        final msg = e.code == 'email-already-in-use'
            ? 'Dit e-mailadres is al in gebruik.'
            : (e.message ?? 'Koppelen mislukt (${e.code}).');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Koppelen mislukt: $e')));
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final isAnon = ref.read(isFirebaseAnonymousProvider);
    final warning = isAnon
        ? 'Let op: dit account heeft geen e-mail. Na uitloggen kun je er niet meer bij. '
            'Voeg eerst een e-mail toe als je je voortgang wilt bewaren.'
        : 'Terug naar het welkomscherm?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uitloggen'),
        content: Text(warning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uitloggen')),
        ],
      ),
    );
    if (ok != true) return;
    // Onboarding opnieuw tonen na uitloggen (er wordt direct weer anoniem ingelogd).
    await ref.read(onboardingDoneProvider.notifier).reset();
    await ref.read(authRepoProvider).signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Uitgelogd.')));
    }
  }
}

class _CoupleCard extends ConsumerWidget {
  final UserProfile me;
  const _CoupleCard({required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProvider);
    final coupled = me.guildId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Jullie koppel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!coupled)
              const Text('Nog niet gekoppeld. Maak een koppel of gebruik een koppelcode.')
            else ...[
              Row(
                children: [
                  const Icon(Icons.favorite, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      partner == null
                          ? 'Wacht op je partner…'
                          : 'Samen met ${partner.name}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, dynamic>?>(
                future: ref.read(fsUserRepoProvider).getGuild(me.guildId!),
                builder: (context, snap) {
                  final invite = snap.data?['inviteCode'] as String?;
                  if (invite == null || invite.isEmpty) return const SizedBox.shrink();
                  return _InviteRow(invite: invite);
                },
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!coupled) ...[
                  FilledButton(
                    onPressed: () => _openCreateDialog(context, ref),
                    child: const Text('Koppel starten'),
                  ),
                  OutlinedButton(
                    onPressed: () => _openJoinDialog(context, ref),
                    child: const Text('Koppelen met code'),
                  ),
                ] else
                  TextButton(
                    onPressed: () => _confirmUncouple(context, ref, me.id),
                    child: const Text('Ontkoppelen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: 'Ons huishouden');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koppel starten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Naam van jullie koppel'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Maak aan')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      final gid = await ref
          .read(fsUserRepoProvider)
          .createGuildAndJoin(ownerUid: me.id, name: controller.text.trim());
      await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Koppel aangemaakt.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Koppel maken mislukt: $e')));
      }
    }
  }

  Future<void> _openJoinDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koppelen met code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Koppelcode'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Koppel')),
        ],
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;
    try {
      await ref
          .read(fsUserRepoProvider)
          .joinByInviteCode(uid: me.id, inviteCode: controller.text.trim().toUpperCase());
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gekoppeld! 🎉')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Koppelen mislukt: $e')));
      }
    }
  }

  Future<void> _confirmUncouple(BuildContext context, WidgetRef ref, String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ontkoppelen'),
        content: const Text('Weet je zeker dat je het koppel wilt verlaten?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleer')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ontkoppel')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(fsUserRepoProvider).leaveGuildSafely(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ontkoppeld.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ontkoppelen mislukt: $e')));
      }
    }
  }
}

class _InviteRow extends StatelessWidget {
  final String invite;
  const _InviteRow({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Koppelcode: ', style: Theme.of(context).textTheme.bodyMedium),
        SelectableText(
          invite,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2),
        ),
        IconButton(
          tooltip: 'Kopieer koppelcode',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Koppelcode gekopieerd.')),
              );
            }
          },
          icon: const Icon(Icons.copy),
        ),
      ],
    );
  }
}
