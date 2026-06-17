import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel

/// "Samen"-overzicht voor het duo i.p.v. een competitieve ranglijst.
class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final partner = ref.watch(partnerProvider);
    final together = me.weeklyPoints + (partner?.weeklyPoints ?? 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Samen deze week'),
                const SizedBox(height: 6),
                Text('$together punten',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PersonCard(user: me, subtitle: 'Jij'),
        const SizedBox(height: 8),
        if (partner != null)
          _PersonCard(user: partner, subtitle: 'Je partner')
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.favorite_border, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Nog geen partner gekoppeld. Deel jullie koppelcode via het Menu '
                    'om samen aan de slag te gaan.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Punten tellen samen op — het draait om wat jullie samen voor elkaar krijgen. 💞',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final UserProfile user;
  final String subtitle;
  const _PersonCard({required this.user, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
        ),
        title: Text(user.name),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${user.weeklyPoints} pt',
                style: Theme.of(context).textTheme.titleMedium),
            Text('🪙 ${user.coins}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
