import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});
 Future<(List<UserProfile>, UserProfile?)> _load(WidgetRef ref) async {
    final repo = ref.read(fsUserRepoProvider);

    final active = await repo.getActiveUser(); // FirebaseAuth -> Firestore
    if (active == null || active.guildId == null) {
      return (<UserProfile>[], active);
    }

    final users = await repo.getUsersByGuild(active.guildId!);
    return (users, active);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: _load(ref),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final users = snap.data! as List<UserProfile>;
        users.sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));

        if (users.isEmpty) return const Center(child: Text('Geen gebruikers.'));
        return ListView(
          children: [
            const SizedBox(height: 12),
            for (final u in users)
              ListTile(
                leading: u.crown
                    ? const Icon(Icons.emoji_events, color: Colors.amber)
                    : const Icon(Icons.person),
                title: Text(u.name),
                subtitle: Text('Weekly: ${u.weeklyPoints} • Coins: ${u.coins}'),
                trailing: Wrap(spacing: 6, children: [
                  for (final b in u.badges.take(3)) Chip(label: Text(b)),
                ]),
              ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Crown wordt elke week toegekend aan #1 en geeft een kleine perk.'),
            ),
          ],
        );
      },
    );
  }
}
