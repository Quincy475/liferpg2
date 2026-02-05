// lib/features/pet/data/window_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WindowConfig {
  final String id;
  final String atlasKey;
  final String displayName;
  final String? description;
  final int price;
  final String currency; // 'coins'
  final String category; // 'window'
  final String rarity;
  final int? maxOwned;
  final bool isActive;

  WindowConfig({
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

  factory WindowConfig.fromJson(String id, Map<String, dynamic> json) {
    return WindowConfig(
      id: id,
      atlasKey: (json['atlasKey'] ?? id) as String,
      displayName: (json['displayName'] ?? id) as String,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] ?? 'coins') as String,
      category: (json['category'] ?? 'window') as String,
      rarity: (json['rarity'] ?? 'common') as String,
      maxOwned: json['maxOwned'] == null ? null : (json['maxOwned'] as num).toInt(),
      isActive: (json['isActive'] ?? true) as bool,
    );
  }

  factory WindowConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return WindowConfig.fromJson(doc.id, data);
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
}
