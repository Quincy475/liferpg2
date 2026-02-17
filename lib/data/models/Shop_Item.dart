class ShopItem {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int price;
  final bool isGuildItem;
  final bool isSpecial;
  final String rarity;
  final String category;
  final String? requiresTicketId;
  final List<String> buyableFor;

  const ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.price,
    this.isGuildItem = false,
    this.isSpecial = false,
    this.rarity = 'common',
    this.category = 'general',
    this.requiresTicketId,
    this.buyableFor = const [],
  });

  String get name => title;

  static ShopItem fromMap(Map<String, dynamic> m) => ShopItem(
        id: m['id'] ?? '',
        title: (m['title'] ?? m['name'] ?? 'Unknown').toString(),
        description: m['description'] ?? '',
        icon: m['icon'] ?? '❔',
        price: (m['price'] as num?)?.toInt() ?? 0,
        isGuildItem: m['isGuildItem'] ?? false,
        isSpecial: m['isSpecial'] ?? false,
        rarity: m['rarity'] ?? 'common',
        category: m['category'] ?? 'general',
        requiresTicketId: m['requiresTicketId'],
        buyableFor: List<String>.from(m['buyableFor'] ?? const <String>[]),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'name': title,
        'description': description,
        'icon': icon,
        'price': price,
        'isGuildItem': isGuildItem,
        'isSpecial': isSpecial,
        'rarity': rarity,
        'category': category,
        'requiresTicketId': requiresTicketId,
        'buyableFor': buyableFor,
      };

  static String rarityLabel(String rarity) {
    switch (rarity) {
      case 'rare':
        return '💠 Rare';
      case 'epic':
        return '💎 Epic';
      case 'legendary':
        return '🔥 Legendary';
      default:
        return '🪶 Common';
    }
  }

  static int rarityColor(String rarity) {
    switch (rarity) {
      case 'rare':
        return 0xFF64B5F6;
      case 'epic':
        return 0xFFAB47BC;
      case 'legendary':
        return 0xFFFFC107;
      default:
        return 0xFFBDBDBD;
    }
  }

  bool canBeBoughtWith(String? ticketId) {
    if (requiresTicketId == null) return true;
    return requiresTicketId == ticketId;
  }
}
