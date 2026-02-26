import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/theme/app_theme.dart';

class AuthGatePage extends ConsumerStatefulWidget {
  const AuthGatePage({super.key});

  @override
  ConsumerState<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends ConsumerState<AuthGatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPassword = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AtmosphereBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welkom terug', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text(
                          'Log in met e-mail en wachtwoord. Je account bewaart je voortgang, guild en shop data.',
                        ),
                        const SizedBox(height: 16),
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'Inloggen'),
                            Tab(text: 'Registreren'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 320,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildLoginTab(context),
                              _buildRegisterTab(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_busy) const LinearProgressIndicator(),
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

  Widget _buildLoginTab(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: _loginEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _loginPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Wachtwoord'),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _login,
          icon: const Icon(Icons.login),
          label: const Text('Inloggen'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _forgotPassword,
          child: const Text('Wachtwoord vergeten?'),
        ),
      ],
    );
  }

  Widget _buildRegisterTab(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: _registerName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _registerEmail,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _registerPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Wachtwoord'),
        ),
        const SizedBox(height: 8),
        _PasswordStrengthHint(password: _registerPassword.text),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _register,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Account aanmaken'),
        ),
      ],
    );
  }

  Future<void> _login() async {
    final email = _loginEmail.text.trim();
    final password = _loginPassword.text;
    if (!_looksLikeEmail(email) || password.isEmpty) {
      _notify('Vul een geldig e-mailadres en wachtwoord in.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepoProvider).signInWithEmailAndPassword(email: email, password: password);
      _notify('Succesvol ingelogd.');
    } on FirebaseAuthException catch (e) {
      _notify(_authError(e));
    } catch (e) {
      _notify('Inloggen mislukt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final name = _registerName.text.trim();
    final email = _registerEmail.text.trim();
    final password = _registerPassword.text;

    if (name.isEmpty) {
      _notify('Naam is verplicht.');
      return;
    }
    if (!_looksLikeEmail(email)) {
      _notify('Vul een geldig e-mailadres in.');
      return;
    }
    if (password.length < 8) {
      _notify('Wachtwoord moet minimaal 8 tekens zijn.');
      return;
    }

    setState(() => _busy = true);
    try {
      final cred = await ref
          .read(authRepoProvider)
          .registerWithEmailAndPassword(email: email, password: password);
      await ref.read(authRepoProvider).updateDisplayName(name: name);
      final uid = cred.user!.uid;
      await ref.read(fsUserRepoProvider).ensureUserDoc(uid, defaultName: name);
      await ref.read(fsUserRepoProvider).updateName(uid, name);
      await ref.read(fsUserRepoProvider).userRef(uid).set(
        {
          'email': email,
          'authProvider': 'password',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _notify('Account aangemaakt. Welkom $name!');
    } on FirebaseAuthException catch (e) {
      _notify(_authError(e));
    } catch (e) {
      _notify('Registreren mislukt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _loginEmail.text.trim();
    if (!_looksLikeEmail(email)) {
      _notify('Vul eerst je e-mail in bij Inloggen.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authRepoProvider).sendPasswordResetEmail(email: email);
      _notify('Reset-link verstuurd naar $email.');
    } on FirebaseAuthException catch (e) {
      _notify(_authError(e));
    } catch (e) {
      _notify('Reset versturen mislukt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _looksLikeEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
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
      case 'email-already-in-use':
        return 'Dit e-mailadres is al in gebruik.';
      case 'weak-password':
        return 'Wachtwoord is te zwak.';
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

class _PasswordStrengthHint extends StatelessWidget {
  final String password;
  const _PasswordStrengthHint({required this.password});

  @override
  Widget build(BuildContext context) {
    final score = _score(password);
    final labels = ['Zeer zwak', 'Zwak', 'Ok', 'Sterk'];
    final colors = [Colors.red, Colors.orange, Colors.amber, Colors.green];
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: score / 4,
            color: colors[max(0, score - 1)],
          ),
        ),
        const SizedBox(width: 10),
        Text(labels[max(0, score - 1)]),
      ],
    );
  }

  int _score(String value) {
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score.clamp(1, 4);
  }
}
