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
    ref.watch(sessionBootstrapProvider);
    final isSignedOut = ref.watch(isAnonymousSessionProvider);
    if (isSignedOut) {
      return const AuthGatePage(key: ValueKey('auth-gate-page'));
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
