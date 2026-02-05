import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel
import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/data/models/models.dart';

class LootPage extends ConsumerWidget {
  const LootPage({super.key});

  Future<({UserProfile? user, List<Map> logs})> _load(WidgetRef ref) async {
    final user = await ref.read(fsUserRepoProvider).getActiveUser();
    // pak laatste 50 logs, newest first
    final logsRaw = completionsBox.values.where((e) => e is Map).map((e) => e as Map).toList();
    logsRaw.sort((a, b) => (b['ts'] as String).compareTo(a['ts'] as String));
    return (user: user, logs: logsRaw.take(50).toList());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<({UserProfile? user, List<Map> logs})>(
      future: _load(ref),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final data = snap.data!;
        final user = data.user;
        final logs = data.logs;

        if (user == null) return const Center(child: Text('Geen actieve gebruiker.'));

        final badges = user.badges;
        final hasGolden = badges.contains('golden_ticket');
        final hasLootStar = badges.contains('loot_star');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Mijn Loot', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _lootChip('Golden Ticket',
                  hasGolden ? Icons.confirmation_num : Icons.confirmation_num_outlined, hasGolden),
              _lootChip('Loot Star', hasLootStar ? Icons.star : Icons.star_border, hasLootStar),
              // Voeg hier eenvoudig andere tokens/badges toe als je wilt
            ]),
            const SizedBox(height: 20),
            Text('Recente drops', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (logs.isEmpty) const Text('Nog geen loot-geschiedenis.'),
            if (logs.isNotEmpty)
              ...logs.where((m) => (m['loot'] == true) || m['ticketId'] != null).map((m) {
                final when = DateTime.tryParse(m['ts'] as String? ?? '');
                final title = m['taskTitle'] ?? m['taskId'];
                final ticket = m['ticketId'];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: Icon(ticket != null ? Icons.confirmation_num : Icons.card_giftcard),
                    title: Text(ticket != null ? '🎟️ $ticket' : '🎁 Loot drop'),
                    subtitle: Text('${title ?? "Taak"} • ${when ?? ""}'),
                    trailing: Text('+${m['points'] ?? 0} pts'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _lootChip(String label, IconData icon, bool active) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: active ? null : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: active ? Colors.transparent : Colors.black12)),
    );
  }
}
