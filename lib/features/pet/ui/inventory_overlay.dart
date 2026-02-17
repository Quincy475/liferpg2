// // lib/features/pet/ui/inventory_overlay.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:household_rpg/app/session_providers.dart';
// import 'package:household_rpg/features/pet/data/furniture_providers.dart';
// import 'package:household_rpg/features/pet/game/pet_room_game.dart';

// class InventoryOverlay extends ConsumerWidget {
//   final PetRoomGame game;
//   const InventoryOverlay({required this.game, super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final uid = ref.watch(currentUserIdProvider);
//     if (uid == null) {
//       return const SizedBox.shrink();
//     }

//     // simpele stream van owned furniture
//     final furnStream = ref.watch(userFurnitureProvider(uid)); // zie hieronder
// // 
//     return Align(
//       alignment: Alignment.bottomCenter,
//       child: Card(
//         margin: const EdgeInsets.all(12),
//         color: const Color(0xFF4B3A2A),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: SizedBox(
//           height: 220,
//           child: furnStream.when(
//             loading: () => const Center(child: CircularProgressIndicator()),
//             error: (e, _) => Center(child: Text('Error: $e')),
//             data: (items) {
//               if (items.isEmpty) {
//                 return const Center(
//                   child: Text(
//                     'No furniture yet',
//                     style: TextStyle(color: Colors.white70),
//                   ),
//                 );
//               }

//               return Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8),
//                     child: Row(
//                       children: [
//                         const Text(
//                           'Furniture',
//                           style: TextStyle(
//                             color: Color(0xFFFFEBC1),
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const Spacer(),
//                         IconButton(
//                           icon: const Icon(Icons.close, color: Colors.white70),
//                           onPressed: () => game.overlays.remove('inventory'),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const Divider(height: 1, color: Colors.black26),
//                   Expanded(
//                     child: GridView.count(
//                       crossAxisCount: 3,
//                       padding: const EdgeInsets.all(8),
//                       crossAxisSpacing: 8,
//                       mainAxisSpacing: 8,
//                       children: [
//                         for (final furn in items)
//                           _InventoryItemTile(
//                             game: game,
//                             uid: uid,
//                             furnitureId: furn.id,
//                             equipped: furn.equipped,
//                             ref: ref,
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _InventoryItemTile extends StatelessWidget {
//   final PetRoomGame game;
//   final WidgetRef ref;
//   final String uid;
//   final String furnitureId;
//   final bool equipped;

//   const _InventoryItemTile({
//     required this.game,
//     required this.ref,
//     required this.uid,
//     required this.furnitureId,
//     required this.equipped,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () async {
//         // 1) Firestore
//         await ref.read(furnitureRepoProvider).setActiveFurniture(
//               uid: uid,
//               furnitureId: furnitureId,
//             );
//         // 2) Game visueel bijwerken
//         await game.setActiveFurnitureLocally(furnitureId);

//         // 3) eventueel overlay sluiten
//         // game.overlays.remove('inventory');
//       },
//       child: Container(
//         decoration: BoxDecoration(
//           color: equipped ? const Color(0xFFD6B05F) : const Color(0xFF3B2F2F),
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: equipped ? Colors.amberAccent : Colors.white24,
//             width: 2,
//           ),
//         ),
//         padding: const EdgeInsets.all(8),
//         child: Center(
//           child: Text(
//             furnitureId,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: equipped ? Colors.black87 : Colors.white70,
//               fontSize: 12,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }