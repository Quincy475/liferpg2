import 'package:flutter/material.dart';

// class _CoinsHeader extends StatelessWidget {
//   const _CoinsHeader({required this.guildCoins, required this.personalCoins});
//   final int guildCoins;
//   final int personalCoins;

//   @override
//   Widget build(BuildContext context) {
//     Widget chip(String emoji, int v) => Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//           margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
//           decoration: BoxDecoration(
//             color: const Color(0xFF4B3A2A),
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
//           ),
//           child: Row(
//             children: [
//               Text(emoji),
//               const SizedBox(width: 6),
//               Text(
//                 '$v',
//                 style: const TextStyle(
//                   color: Color(0xFFFFEBC1),
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         );

//     return Row(children: [
//       chip('💰', guildCoins),
//       chip('🪙', personalCoins),
//     ]);
//   }
// }
class CoinsHeader extends StatelessWidget {
  const CoinsHeader({required this.guildCoins, required this.personalCoins});
  final int guildCoins;
  final int personalCoins;

  @override
  Widget build(BuildContext context) {
    Widget chip(String emoji, int v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4B3A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
          ),
          child: Row(
            children: [
              Text(emoji),
              const SizedBox(width: 6),
              Text(
                '$v',
                style: const TextStyle(
                  color: Color(0xFFFFEBC1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

    return Row(children: [
      chip('💰', guildCoins),
      chip('🪙', personalCoins),
    ]);
  }
}
