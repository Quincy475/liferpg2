import 'package:cloud_firestore/cloud_firestore.dart';

final _firestore = FirebaseFirestore.instance;

/// Run this once (bijv. vanuit een admin/debug scherm) om de furniture catalogus te seeden.


/// Beter: maak één centrale plek:
CollectionReference<Map<String, dynamic>> get furnitureConfigCol =>
    _firestore.collection('config_furniture');


Future<void> seedFurnitureConfig() async {
  // Optioneel: check of er al items bestaan
  final existing = await furnitureConfigCol.limit(1).get();
  if (existing.docs.isNotEmpty) {
    // al ge-seed, skip
    print('Furniture config already seeded, skipping.');
    return;
  }

  final batch = FirebaseFirestore.instance.batch();

  final items = <FurnitureConfig>[
    FurnitureConfig(
      id: 'bed_soft_blue',
      atlasKey: 'bed_soft_blue',
      displayName: 'Soft Blue Bed',
      description: 'A comfy blue bed for your pet.',
      price: 500,
      currency: 'coins',
      category: 'bed',
      rarity: 'rare',
      maxOwned: 1,
      isActive: true,
    ),
    FurnitureConfig(
      id: 'tower_beige',
      atlasKey: 'tower_beige',
      displayName: 'Beige Cat Tower',
      description: 'Tall scratching tower for your cat.',
      price: 750,
      currency: 'coins',
      category: 'tower',
      rarity: 'epic',
      maxOwned: 1,
      isActive: true,
    ),
    FurnitureConfig(
      id: 'tower_green',
      atlasKey: 'tower_beige',
      displayName: 'Beige Cat Tower',
      description: 'Tall scratching tower for your cat.',
      price: 750,
      currency: 'coins',
      category: 'tower',
      rarity: 'epic',
      maxOwned: 1,
      isActive: true,
    ),  FurnitureConfig(
      id: 'tower_green',
      atlasKey: 'tower_blue',
      displayName: 'Beige Cat Tower',
      description: 'Tall scratching tower for your cat.',
      price: 750,
      currency: 'coins',
      category: 'tower',
      rarity: 'epic',
      maxOwned: 1,
      isActive: true,
    ),
    FurnitureConfig(
      id: 'plant_small',
      atlasKey: 'plant_small',
      displayName: 'Small Plant',
      description: 'A cozy little house plant.',
      price: 200,
      currency: 'coins',
      category: 'decoration',
      rarity: 'common',
      maxOwned: null,
      isActive: true,
    ),
    // FurnitureConfig(
    //   id: 'poster_cat',
    //   atlasKey: 'poster_cat',
    //   displayName: 'Cat Poster',
    //   description: 'Cute cat poster for the wall.',
    //   price: 150,
    //   currency: 'coins',
    //   category: 'wall',
    //   rarity: 'common',
    //   maxOwned: null,
    //   isActive: true,
    // ),
    // voeg hier makkelijk meer toe als je atlas groeit
  ];

  for (final item in items) {
    final docRef = furnitureConfigCol.doc(item.id);
    batch.set(docRef, item.toJson());
  }

  await batch.commit();
  print('Furniture config seeded with ${items.length} items.');
}

class FurnitureConfig {
  final String id;
  final String atlasKey;
  final String displayName;
  final String? description;
  final int price;
  final String currency; // 'coins', 'gems', etc.
  final String category;
  final String rarity;
  final int? maxOwned;
  final bool isActive;

  FurnitureConfig({
    required this.id,
    required this.atlasKey,
    required this.displayName,
    this.description,
    required this.price,
    required this.currency,
    required this.category,
    required this.rarity,
    this.maxOwned,
    required this.isActive,
  });

  factory FurnitureConfig.fromJson(String id, Map<String, dynamic> json) {
    return FurnitureConfig(
      id: id,
      atlasKey: json['atlasKey'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toInt(),
      currency: (json['currency'] ?? 'coins') as String,
      category: json['category'] as String,
      rarity: (json['rarity'] ?? 'common') as String,
      maxOwned: json['maxOwned'] == null ? null : (json['maxOwned'] as num).toInt(),
      isActive: (json['isActive'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'atlasKey': atlasKey,
      'displayName': displayName,
      if (description != null) 'description': description,
      'price': price,
      'currency': currency,
      'category': category,
      'rarity': rarity,
      if (maxOwned != null) 'maxOwned': maxOwned,
      'isActive': isActive,
    };
  }
    factory FurnitureConfig.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return FurnitureConfig(
      id: data['id'] as String? ?? doc.id,
      displayName: data['displayName'] as String? ?? doc.id,
      atlasKey: data['atlasKey'] as String? ?? doc.id,
      category: data['category'] as String? ?? '',
      currency: data['currency'] as String? ?? 'coins',
      description: data['description'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      maxOwned: (data['maxOwned'] ?? 1) as int,
      price: (data['price'] ?? 0) as int,
      rarity: data['rarity'] as String? ?? 'common',
    );
  }

}

