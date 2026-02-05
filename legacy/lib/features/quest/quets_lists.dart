// // ---------------------------------------------------------------------------
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:household_rpg/data/models/Quest.dart';
// import 'package:household_rpg/data/models/Skill.dart';
// import 'package:household_rpg/data/models/models.dart'; // barrel
// import 'package:household_rpg/features/quest/widgets.dart';

// /// DAILY LIST + CARD
// /// ---------------------------------------------------------------------------

// class _DailyList extends ConsumerWidget {
//   const _DailyList({required this.dailies});
//   final List<Quest> dailies;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     if (dailies.isEmpty) {
//       return const _EmptyState(text: 'Geen dagelijkse quests. Kom later terug!');
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(12),
//       itemCount: dailies.length,
//       itemBuilder: (c, i) => _DailyCard(q: dailies[i]),
//     );
//   }
// }

// class _DailyCard extends ConsumerWidget {
//   const _DailyCard({required this.q});
//   final Quest q;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return _PerkamentCard(
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(q.skill.icon, style: const TextStyle(fontSize: 28)),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _TitleRow(title: q.title, color: q.skill.color),
//                   const SizedBox(height: 4),
//                   Text(
//                     q.description,
//                     style: const TextStyle(color: Colors.white70),
//                   ),
//                   const SizedBox(height: 8),
//                   _RewardRow(xp: q.rewardXp, coins: q.rewardCoins),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 8),
//             _RightActions(
//               completed: q.completed,
//               progress: q.completed ? 1 : 0,
//               onStart: () => ref.read(questControllerProvider.notifier).refresh(),
//               onComplete: q.completed
//                   ? null
//                   : () => ref
//                       .read(questControllerProvider.notifier)
//                       .completeDaily(q.id),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// ---------------------------------------------------------------------------
// /// CO-OP LIST + CARD
// /// ---------------------------------------------------------------------------

// class _CoopList extends ConsumerWidget {
//   const _CoopList({required this.coops});
//   final List<Quest> coops;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     if (coops.isEmpty) {
//       return const _EmptyState(text: 'Nog geen co-op quests. Nodig je guild uit!');
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(12),
//       itemCount: coops.length,
//       itemBuilder: (c, i) => _CoopCard(q: coops[i]),
//     );
//   }
// }

// class _CoopCard extends ConsumerWidget {
//   const _CoopCard({required this.q});
//   final Quest q;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final progress = q.overallProgress;

//     return _PerkamentCard(
//       child: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _TitleRow(title: q.title, color: q.skill.color, icon: q.skill.icon),
//             const SizedBox(height: 6),
//             Text(q.description, style: const TextStyle(color: Colors.white70)),
//             const SizedBox(height: 10),
//             _MemberRow(memberIds: q.memberIds, contributions: q.contributions),
//             const SizedBox(height: 10),
//             _ProgressBar(value: progress),
//             const SizedBox(height: 10),
//             Row(
//               children: [
//                 _RewardRow(xp: q.rewardXp, coins: q.rewardCoins),
//                 const Spacer(),
//                 FilledButton.tonal(
//                   onPressed: () => ref
//                       .read(questControllerProvider.notifier)
//                       .contribute(q.id, 0.25), // demo: +25%
//                   style: ButtonStyle(
//                     backgroundColor: MaterialStatePropertyAll(
//                       const Color(0xFFD6B05F),
//                     ),
//                     foregroundColor:
//                         const MaterialStatePropertyAll(Colors.black),
//                   ),
//                   child: const Text('Contribute +25%'),
//                 ),
//                 const SizedBox(width: 8),
//                 FilledButton(
//                   onPressed: q.claimable
//                       ? () => ref
//                           .read(questControllerProvider.notifier)
//                           .claim(q.id)
//                       : null,
//                   child: const Text('Claim'),
//                 ),
//               ],
//             )
//           ],
//         ),
//       ),
//     );
//   }
// }