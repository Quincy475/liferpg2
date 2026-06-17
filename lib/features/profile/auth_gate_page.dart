import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/theme/app_theme.dart';

/// Eenmalig welkom-/koppelscherm. Er is altijd al (anoniem) ingelogd, dus dit
/// gaat niet over "inloggen" maar over je naam kiezen en evt. koppelen aan je partner.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _name = TextEditingController();
  bool _busy = false;
  bool _showLogin = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _uid => ref.read(currentUserIdProvider);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welkom 👋',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text(
                          'Doe taken samen, verzamel coins en groei samen. '
                          'Kies een naam en koppel daarna met je partner.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Jouw naam',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _createCouple,
                          icon: const Icon(Icons.favorite_outline),
                          label: const Text('Maak een koppel'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _joinCouple,
                          icon: const Icon(Icons.link),
                          label: const Text('Koppelen met code'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _continueSolo,
                          child: const Text('Ga solo verder'),
                        ),
                        const Divider(height: 28),
                        TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _showLogin = !_showLogin),
                          icon: Icon(_showLogin
                              ? Icons.expand_less
                              : Icons.expand_more),
                          label: const Text('Heb je al een account? Log in met e-mail'),
                        ),
                        if (_showLogin) _LoginForm(onBusy: _setBusy),
                        if (_busy) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setBusy(bool v) {
    if (mounted) setState(() => _busy = v);
  }

  Future<bool> _saveName() async {
    final uid = _uid;
    final name = _name.text.trim();
    if (uid == null) {
      _notify('Geen sessie. Probeer opnieuw.');
      return false;
    }
    if (name.isEmpty) {
      _notify('Vul eerst je naam in.');
      return false;
    }
    await ref.read(fsUserRepoProvider).updateName(uid, name);
    try {
      await ref.read(authRepoProvider).updateDisplayName(name: name);
    } catch (_) {
      // displayName is best-effort; user-doc is leidend.
    }
    return true;
  }

  Future<void> _continueSolo() async {
    setState(() => _busy = true);
    try {
      if (!await _saveName()) return;
      await ref.read(onboardingDoneProvider.notifier).complete();
    } catch (e) {
      _notify('Mislukt: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _createCouple() async {
    setState(() => _busy = true);
    try {
      if (!await _saveName()) return;
      final coupleName = await _askText(
        title: 'Naam van jullie koppel',
        label: 'Bijv. "Ons huishouden"',
        initial: 'Ons huishouden',
      );
      if (coupleName == null || coupleName.trim().isEmpty) return;

      final uid = _uid!;
      final gid = await ref
          .read(fsUserRepoProvider)
          .createGuildAndJoin(ownerUid: uid, name: coupleName.trim());
      await ref.read(shopRepoProvider).seedGuildShop(guildId: gid);

      final invite = (await ref.read(fsUserRepoProvider).getGuild(gid))?['inviteCode']
          as String?;
      if (mounted && invite != null) {
        await _showInviteDialog(invite);
      }
      await ref.read(onboardingDoneProvider.notifier).complete();
    } catch (e) {
      _notify('Koppel maken mislukt: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _joinCouple() async {
    setState(() => _busy = true);
    try {
      if (!await _saveName()) return;
      final code = await _askText(
        title: 'Koppelen met code',
        label: 'Koppelcode',
      );
      if (code == null || code.trim().isEmpty) return;

      await ref.read(fsUserRepoProvider).joinByInviteCode(
            uid: _uid!,
            inviteCode: code.trim().toUpperCase(),
          );
      await ref.read(onboardingDoneProvider.notifier).complete();
      _notify('Gekoppeld! 🎉');
    } catch (e) {
      _notify('Koppelen mislukt: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _showInviteDialog(String invite) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jullie koppelcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Deel deze code met je partner om te koppelen:'),
            const SizedBox(height: 12),
            SelectableText(
              invite,
              style: Theme.of(ctx)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(letterSpacing: 4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Klaar'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askText({
    required String title,
    required String label,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuleer')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Oké'),
          ),
        ],
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Mini-loginformulier voor wie al een account heeft (bv. tweede toestel).
class _LoginForm extends ConsumerStatefulWidget {
  final void Function(bool) onBusy;
  const _LoginForm({required this.onBusy});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Wachtwoord'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _login,
            icon: const Icon(Icons.login),
            label: const Text('Inloggen'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) || password.isEmpty) {
      _notify('Vul een geldig e-mailadres en wachtwoord in.');
      return;
    }
    widget.onBusy(true);
    try {
      await ref
          .read(authRepoProvider)
          .signInWithEmailAndPassword(email: email, password: password);
      await ref.read(onboardingDoneProvider.notifier).complete();
      _notify('Ingelogd.');
    } on FirebaseAuthException catch (e) {
      _notify(_authError(e));
    } catch (e) {
      _notify('Inloggen mislukt: $e');
    } finally {
      widget.onBusy(false);
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Geen account gevonden voor dit e-mailadres.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail of wachtwoord klopt niet.';
      case 'invalid-email':
        return 'Ongeldig e-mailadres.';
      case 'too-many-requests':
        return 'Te veel pogingen. Probeer later opnieuw.';
      default:
        return e.message ?? 'Authenticatie mislukt (${e.code}).';
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
