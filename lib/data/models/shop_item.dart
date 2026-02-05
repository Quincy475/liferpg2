class ShopItem {
  final String id;
  final String name;
  final String description;        // korte tekst in de UI
  final String icon;               // emoji of icon code
  final int price;                 // aantal coins
  final bool isGuildItem;          // true = gedeelde upgrade
  final bool isSpecial;            // limited/rare items
  final String rarity;             // "common", "rare", "epic", "legendary"
  final String category;           // bijv. "decoration", "buff", "utility"
  final String? requiresTicketId;  // bijv. "golden_ticket" voor special unlocks

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.price,
    this.isGuildItem = false,
    this.isSpecial = false,
    this.rarity = 'common',
    this.category = 'general',
    this.requiresTicketId,
  });

  // 🧭 Factory: van Map naar model
  static ShopItem fromMap(Map<String, dynamic> m) => ShopItem(
        id: m['id'] ?? '',
        name: m['name'] ?? 'Unknown',
        description: m['description'] ?? '',
        icon: m['icon'] ?? '❔',
        price: m['price'] ?? 0,
        isGuildItem: m['isGuildItem'] ?? false,
        isSpecial: m['isSpecial'] ?? false,
        rarity: m['rarity'] ?? 'common',
        category: m['category'] ?? 'general',
        requiresTicketId: m['requiresTicketId'],
      );

  // 🔄 Map converter
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'price': price,
        'isGuildItem': isGuildItem,
        'isSpecial': isSpecial,
        'rarity': rarity,
        'category': category,
        'requiresTicketId': requiresTicketId,
      };

  // 🎨 Kleur-helpers voor UI
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
        return 0xFF64B5F6; // blauw
      case 'epic':
        return 0xFFAB47BC; // paars
      case 'legendary':
        return 0xFFFFC107; // goud
      default:
        return 0xFFBDBDBD; // grijs
    }
  }

  // 🧠 Logische helper
  bool canBeBoughtWith(String? ticketId) {
    if (requiresTicketId == null) return true;
    return requiresTicketId == ticketId;
  }
}
