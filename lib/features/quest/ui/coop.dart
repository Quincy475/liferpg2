import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/Quest.dart';
import 'package:household_rpg/data/models/Skill.dart';
import 'package:household_rpg/features/quest/quest_page.dart';
import 'package:household_rpg/features/quest/ui/member_row.dart';
import 'package:household_rpg/features/quest/ui/perkament_card.dart';
import 'package:household_rpg/features/quest/ui/proress_bar.dart';

/// ---------------------------------------------------------------------------
/// CO-OP LIST + CARD
/// ---------------------------------------------------------------------------

class CoopList extends ConsumerWidget {
  const CoopList({super.key, required this.coops});
  final List<Quest> coops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coops.isEmpty) {
      return const CircularProgressIndicator();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: coops.length,
      itemBuilder: (c, i) => _CoopCard(q: coops[i]),
    );
  }
}

class _CoopCard extends ConsumerWidget {
  const _CoopCard({required this.q});
  final Quest q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = q.overallProgress;

    return PerkamentCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TitleRow(title: q.title, color: q.skill.color, icon: q.skill.icon),
            const SizedBox(height: 6),
            Text(q.description, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            MemberRow(memberIds: q.memberIds, contributions: q.contributions),
            const SizedBox(height: 10),
            ProgressBar(value: progress),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(questControllerProvider.notifier)
                      .contribute(q.id, 0.25), // demo: +25%
                  style: const ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(
                      Color(0xFFD6B05F),
                    ),
                    foregroundColor: MaterialStatePropertyAll(Colors.black),
                  ),
                  child: const Text('Contribute +25%'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: q.claimable
                      ? () => ref.read(questControllerProvider.notifier).claim(q.id)
                      : null,
                  child: const Text('Claim'),
                ),
              ],
            ),
            RewardRow(xp: q.rewardXp, coins: q.rewardCoins),
          ],
        ),
      ),
    );
  }
}
