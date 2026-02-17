import 'package:flutter/material.dart';
import 'package:household_rpg/features/profile/profile_page.dart';
import 'package:household_rpg/features/shop/shop_page.dart';
import 'package:household_rpg/features/tasks/tasks_page.dart';

class HouseholdRPGApp extends StatefulWidget {
  const HouseholdRPGApp({super.key});

  @override
  State<HouseholdRPGApp> createState() => _HouseholdRPGAppState();
}

class _HouseholdRPGAppState extends State<HouseholdRPGApp> {
  int _pageIndex = 0;

  static const _pages = [
    TasksPage(),
    ShopPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Household RPG MVP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Scaffold(
        appBar: AppBar(title: const Text('Household RPG MVP')),
        body: _pages[_pageIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _pageIndex,
          onDestinationSelected: (i) => setState(() => _pageIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
            NavigationDestination(icon: Icon(Icons.store), label: 'Shop'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
