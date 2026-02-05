import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/features/quest/quest_page.dart';
import 'features/shop/shop_page.dart';
import 'features/profile/profile_page.dart';
import 'features/pet/pet_page.dart';
import 'providers.dart';

class HouseholdRPGApp extends ConsumerWidget {
  const HouseholdRPGApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Weekly reset check on app start
    // ref.read(appLifecycleProvider.notifier).maybeResetWeek();
    final theme = ref.watch(themeProvider); // ← haalt ThemeMode & seedColor op
    return MaterialApp(
      title: 'Household RPG',
      themeMode: theme.mode,
      theme: ThemeData(
          colorSchemeSeed: theme.seedColor, useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: theme.seedColor, useMaterial3: true, brightness: Brightness.dark),
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  late final PageController _controller;
  int _pageIndex = 0;

  final _pages = const [
    // TasksPage(),
    QuestPage(),
    ShopPage(),
    // LeaderboardPage(),
    // RaidPage(),
    // SkillsOverviewPage(),
    // EventsPage(),
    // LootPage(),
    ProfilePage(),
    PetPage(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _pageIndex);

    // ✅ Update navbar óók tijdens drag/vegen (realtime)
    _controller.addListener(() {
      final p = _controller.page;
      if (p == null) return;
      final idx = p.round();
      if (idx != _pageIndex) {
        setState(() => _pageIndex = idx);
      }
    });
  }

  Future<void> _onNavTap(int i) async {
    if (i == _pageIndex) return;
    await _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
    // onPageChanged + listener houden _pageIndex in sync
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Household RPG')),
      body: PageView(
        controller: _controller,
        // ✅ zorgt dat swipen mogelijk blijft
        physics: const PageScrollPhysics(),
        // ✅ vuurt na voltooien swipe/animatie
        onPageChanged: (i) => setState(() => _pageIndex = i),
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        // ✅ altijd afgeleid van controller/state
        selectedIndex: _pageIndex,
        onDestinationSelected: _onNavTap,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Shop'),
          // NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Ranks'),
          // NavigationDestination(icon: Icon(Icons.groups), label: 'Raid'),
          // NavigationDestination(icon: Icon(Icons.forest), label: 'Skills'),
          // NavigationDestination(icon: Icon(Icons.bolt), label: 'Events'),
          // NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Loot'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.pets), label: 'Pet'),
        ],
      ),
    );
  }
}
