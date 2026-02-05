// lib/features/pet/data/furniture_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/userfurniture.dart';
import 'furniture_repo.dart';

final furnitureRepoProvider = Provider<FurnitureRepo>((ref) {
  return FurnitureRepo(db: FirebaseFirestore.instance);
});

final userFurnitureProvider =
    StreamProvider.family<List<UserFurniture>, String>((ref, uid) {
  final col = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('furniture');

  return col.snapshots().map(
        (snap) => snap.docs.map(UserFurniture.fromDoc).toList(),
      );
});