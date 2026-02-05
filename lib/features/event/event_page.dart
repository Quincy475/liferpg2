import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel
import 'package:household_rpg/data/models/Event_card.dart';
import 'package:household_rpg/data/models/enums.dart';

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(eventRepoProvider).getAll(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final events = snap.data as List<EventCard>;
        if (events.isEmpty) {
          return const Center(
              child:
                  Text('Geen events. Voeg er een toe via Profile → Seed demo data (voegt 1 toe).'));
        }
        final now = DateTime.now();
        return ListView(
          children: events.map((e) {
            final active = now.isAfter(e.start) && now.isBefore(e.end);
            return Card(
              child: ListTile(
                title: Text(active
                    ? 'ACTIVE: +${e.xpMultiplierPct}% XP'
                    : 'Scheduled: +${e.xpMultiplierPct}% XP'),
                subtitle: Text('Scope: ${e.doubleXpFor?.name ?? "Global"}'
                    '\n${e.start} → ${e.end}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
