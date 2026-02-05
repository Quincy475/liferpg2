import 'package:cloud_firestore/cloud_firestore.dart';

enum PetSpecies { cat, dog, rabbit }

extension PetSpeciesX on PetSpecies {
  String get key => switch (this) {
    PetSpecies.cat => 'cat',
    PetSpecies.dog => 'dog',
    PetSpecies.rabbit => 'rabbit',
  };

  static PetSpecies from(String s) {
    switch (s) {
      case 'dog': return PetSpecies.dog;
      case 'rabbit': return PetSpecies.rabbit;
      default: return PetSpecies.cat;
    }
  }
}

class PetState {
  final PetSpecies species;
  final String skinId;
  final int hunger;      // 0..100
  final int energy;
  final int happiness;
  final int cleanliness;
  final String mood;     // 'idle' | 'eat' | 'sleep' | 'play'
  final DateTime updatedAt;

  const PetState({
    required this.species,
    this.skinId = 'default',
    this.hunger = 80,
    this.energy = 80,
    this.happiness = 80,
    this.cleanliness = 80,
    this.mood = 'idle',
    required this.updatedAt,
  });

  PetState copyWith({
    PetSpecies? species,
    String? skinId,
    int? hunger,
    int? energy,
    int? happiness,
    int? cleanliness,
    String? mood,
    DateTime? updatedAt,
  }) => PetState(
    species: species ?? this.species,
    skinId: skinId ?? this.skinId,
    hunger: hunger ?? this.hunger,
    energy: energy ?? this.energy,
    happiness: happiness ?? this.happiness,
    cleanliness: cleanliness ?? this.cleanliness,
    mood: mood ?? this.mood,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'species': species.key,
    'skinId': skinId,
    'hunger': hunger,
    'energy': energy,
    'happiness': happiness,
    'cleanliness': cleanliness,
    'mood': mood,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static PetState fromMap(Map<String, dynamic> m) {
    final ts = m['updatedAt'];
    return PetState(
      species: PetSpeciesX.from(m['species']?.toString() ?? 'cat'),
      skinId: (m['skinId'] ?? 'default').toString(),
      hunger: (m['hunger'] ?? 80) as int,
      energy: (m['energy'] ?? 80) as int,
      happiness: (m['happiness'] ?? 80) as int,
      cleanliness: (m['cleanliness'] ?? 80) as int,
      mood: (m['mood'] ?? 'idle').toString(),
      updatedAt: (ts is Timestamp) ? ts.toDate() : DateTime.now(),
    );
  }
}

class FurnitureItem {
  final String id;      // e.g. 'bowl' | 'bed'
  final String sprite;  // asset path
  final double x;
  final double y;

  const FurnitureItem({required this.id, required this.sprite, required this.x, required this.y});

  Map<String, dynamic> toMap() => {'id': id, 'sprite': sprite, 'x': x, 'y': y};

  static FurnitureItem fromMap(Map<String, dynamic> m) => FurnitureItem(
    id: (m['id'] ?? '').toString(),
    sprite: (m['sprite'] ?? '').toString(),
    x: (m['x'] ?? 0).toDouble(),
    y: (m['y'] ?? 0).toDouble(),
  );
}
enum PlacedKind { floor, decor, wall }

class PlacedItem {
  final String instanceId;
  final String itemId;
  final PlacedKind kind;
  final double x;      // 0..1
  final double y;      // 0..1
  final double scale;
  final bool locked;

  const PlacedItem({
    required this.instanceId,
    required this.itemId,
    required this.kind,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.locked = true,
  });

  Map<String, dynamic> toMap() => {
    'instanceId': instanceId,
    'itemId': itemId,
    'kind': kind.name,
    'x': x,
    'y': y,
    'scale': scale,
    'locked': locked,
  };

  static PlacedItem fromMap(Map<String, dynamic> m) => PlacedItem(
    instanceId: (m['instanceId'] ?? '').toString(),
    itemId: (m['itemId'] ?? '').toString(),
    kind: PlacedKind.values.firstWhere(
      (k) => k.name == (m['kind'] ?? 'floor'),
      orElse: () => PlacedKind.floor,
    ),
    x: (m['x'] ?? 0.5).toDouble(),
    y: (m['y'] ?? 0.9).toDouble(),
    scale: (m['scale'] ?? 1.0).toDouble(),
    locked: (m['locked'] ?? true) == true,
  );
}

class RoomLayout {
  final String background;
  final List<PlacedItem> placed;

  const RoomLayout({required this.background, required this.placed});

  Map<String, dynamic> toMap() => {
    'background': background,
    'placed': placed.map((p) => p.toMap()).toList(),
  };

  static RoomLayout fromMap(Map<String, dynamic> m) => RoomLayout(
    background: (m['background'] ?? '1.png').toString(),
    placed: (m['placed'] as List? ?? const [])
      .map((e) => PlacedItem.fromMap(Map<String, dynamic>.from(e)))
      .toList(),
  );
}
