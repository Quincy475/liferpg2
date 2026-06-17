import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/features/profile/auth_gate_page.dart';
import 'package:household_rpg/features/profile/menu_page.dart';
import 'package:household_rpg/features/profile/profile_page.dart';
import 'package:household_rpg/features/shop/shop_page.dart';
import 'package:household_rpg/features/tasks/tasks_page.dart';
import 'package:household_rpg/theme/app_theme.dart';

class HouseholdRPGApp extends ConsumerWidget {
  const HouseholdRPGApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Household RPG MVP',
      themeMode: theme.mode,
      theme: buildRpgLightTheme(theme.seedColor),
      darkTheme: buildRpgTheme(theme.seedColor),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends ConsumerStatefulWidget {
  const _HomeShell();

  @override
  ConsumerState<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<_HomeShell> {
  int _index = 0;

  final _pages = const [
    TasksPage(),
    ShopPage(),
    ProfilePage(),
    MenuPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Zorgt dat er altijd (anoniem) ingelogd is — geen inlogscherm meer.
    final signIn = ref.watch(ensureSignedInProvider);
    final boot = ref.watch(sessionBootstrapProvider);
    final uid = ref.watch(currentUserIdProvider);

    if (signIn.hasError) {
      return _SplashScaffold(error: signIn.error.toString());
    }

    // Bezig met aanmaken sessie / user-doc → korte splash.
    if (uid == null || signIn.isLoading || boot.isLoading) {
      return const _SplashScaffold();
    }

    // Eenmalig welkom-/koppelscherm.
    final onboarded = ref.watch(onboardingDoneProvider);
    if (!onboarded) {
      return const OnboardingPage(key: ValueKey('onboarding-page'));
    }

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Menu'),
        ],
      ),
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  final String? error;
  const _SplashScaffold({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 40),
                    const SizedBox(height: 12),
                    Text('Kon geen sessie starten:\n$error',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
      ),
    );
  }
}
