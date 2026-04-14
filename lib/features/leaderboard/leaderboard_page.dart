import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/core/utils.dart';
import 'package:household_rpg/data/models/models.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersInMyGuildProvider);
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guild'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: _WeekHeader(),
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Geen guild leden gevonden.\nSluit je aan bij een guild.',
                textAlign: TextAlign.center,
              ),
            );
          }
          final sorted = [...users]
            ..sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final u = sorted[i];
              return _LeaderboardTile(
                rank: i + 1,
                user: u,
                isMe: me?.id == u.id,
                isCurrentLeader: i == 0 && u.weeklyPoints > 0,
                hadCrownLastWeek: u.crown,
              );
            },
          );
        },
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader();

  @override
  Widget build(BuildContext context) {
    final monday = startOfIsoWeek(DateTime.now());
    final sunday = monday.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'Week van ${fmt.format(monday)} – ${fmt.format(sunday)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final UserProfile user;
  final bool isMe;
  final bool isCurrentLeader;
  final bool hadCrownLastWeek;

  const _LeaderboardTile({
    required this.rank,
    required this.user,
    required this.isMe,
    required this.isCurrentLeader,
    required this.hadCrownLastWeek,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color? highlight = isCurrentLeader
        ? cs.tertiaryContainer.withOpacity(0.40)
        : isMe
            ? cs.primaryContainer.withOpacity(0.45)
            : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: _RankBadge(rank: rank, isCurrentLeader: isCurrentLeader),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: isMe
                    ? TextStyle(fontWeight: FontWeight.bold, color: cs.primary)
                    : null,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              Text('(jij)',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (hadCrownLastWeek) ...[
              const SizedBox(width: 4),
              const Tooltip(
                message: 'Vorige week winnaar',
                child: Icon(Icons.emoji_events, color: Colors.amber, size: 18),
              ),
            ],
          ],
        ),
        subtitle: Text('${user.weeklyPoints} punten deze week'),
        trailing: isCurrentLeader
            ? const Icon(Icons.star, color: Colors.amber)
            : null,
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool isCurrentLeader;

  const _RankBadge({required this.rank, required this.isCurrentLeader});

  @override
  Widget build(BuildContext context) {
    if (isCurrentLeader) {
      return CircleAvatar(
        backgroundColor: Colors.amber.shade700,
        child: Text(
          '#$rank',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        '#$rank',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
