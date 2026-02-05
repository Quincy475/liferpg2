import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel
import 'package:household_rpg/data/models/User_profile.dart';
import 'package:household_rpg/data/models/enums.dart';

class SkillsPage extends ConsumerWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(fsUserRepoProvider).getActiveUser(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final user = snap.data as UserProfile?;
        if (user == null) return const Center(child: Text('Geen actieve gebruiker.'));
        final entries = user.skillXp.entries.toList()
          ..sort((a, b) => a.key.index.compareTo(b.key.index));
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Skills van ${user.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final e in entries) _SkillTile(skill: e.key, xp: e.value),
            const SizedBox(height: 16),
            const Text('Perks (simpel): elke 500 XP = +5% bonus tot max 25%.'),
          ],
        );
      },
    );
  }
}

class _SkillTile extends ConsumerWidget {
  final SkillType skill;
  final int xp;
  const _SkillTile({required this.skill, required this.xp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final tier = ref.read(fsUserRepoProvider).skillTier(xp);
    return Card(
      child: ListTile(
        title: Text('{skillName(skill)}'),
        subtitle: Text('XP: \$xp • Tier: \$tier/5 • Bonus: \${tier * 5}%'),
      ),
    );
  }
}
