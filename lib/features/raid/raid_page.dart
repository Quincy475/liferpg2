import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../core/utils.dart';
import 'package:household_rpg/data/models/Raidgoal.dart';

class RaidPage extends ConsumerWidget {
  const RaidPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(raidRepoProvider).getRaid(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final raid = snap.data as RaidGoal?;
        if (raid == null) return const Center(child: Text('Geen actieve raid.'));
        double pct = (raid.currentPoints / raid.targetPoints).clamp(0, 1.0);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(raid.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: pct),
              const SizedBox(height: 8),
              Text('${raid.currentPoints} / ${raid.targetPoints} punten'),
              const SizedBox(height: 24),
              Text('Week start: ${fmtDate(raid.weekStart)}'),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  // simulate team reward claim info
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text(pct >= 1 ? 'Team goal gehaald! 🎉' : 'Nog even knallen samen!')),
                  );
                },
                icon: const Icon(Icons.groups),
                label: const Text('Team status'),
              ),
            ],
          ),
        );
      },
    );
  }
}
