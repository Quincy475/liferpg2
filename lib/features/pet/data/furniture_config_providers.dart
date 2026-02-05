import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/config/furniture.dart';

// <-- pas pad aan naar waar jouw FurnitureConfig + furnitureConfigCol staan

// Als furnitureConfigCol in hetzelfde bestand als FurnitureConfig staat, importeer dat bestand
// en gebruik gewoon de getter daar.

// Als je de getter hier wilt hebben, kan ook:
//
// CollectionReference<Map<String, dynamic>> get furnitureConfigCol =>
//     FirebaseFirestore.instance.collection('config_furniture');

final furnitureConfigsProvider =
    StreamProvider<List<FurnitureConfig>>((ref) {
  final col = furnitureConfigCol; // jouw getter uit de seeder-file

  return col.snapshots().map(
        (snap) => snap.docs
            .map(FurnitureConfig.fromDoc)
            .where((cfg) => cfg.isActive)
            .toList(),
      );
});
