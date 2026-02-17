import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/Shop_Item.dart';

class ShopRepository {
  final FirebaseFirestore _db;
  ShopRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  // Path: guilds/{guildId}/shopItems/{itemId}
  CollectionReference<Map<String, dynamic>> _guildShopCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('shopItems');

  /// Idempotente seed: zet alleen items die nog niet bestaan.
  Future<void> seedGuildShop({required String guildId}) async {
    final col = _guildShopCol(guildId);

    // 🔹 voorbeeld-set met variatie (prijzen, rarity, isGuildItem, requiresTicketId, category)
    final items = <ShopItem>[
      ShopItem(
        id: 'broom_upgrade_1',
        name: 'Broom Upgrade I',
        description: 'Lichtgewicht bezem — schoonmaken voelt soepeler.',
        icon: '🧹',
        price: 40,
        category: 'utility',
        rarity: 'common',
        isGuildItem: true,
      ),
      ShopItem(
        id: 'scented_candles',
        name: 'Scented Candles',
        description: 'Gezelligheid buff voor 24 uur. +5% Wellbeing.',
        icon: '🕯️',
        price: 60,
        category: 'buff',
        rarity: 'rare',
        isGuildItem: false,
      ),
      ShopItem(
        id: 'golden_sponge',
        name: 'Golden Sponge',
        description: 'Kans op extra loot bij Cleaning-tasks.',
        icon: '🧽',
        price: 120,
        category: 'buff',
        rarity: 'epic',
        isGuildItem: false,
      ),
      ShopItem(
        id: 'kitchen_deco_modern',
        name: 'Kitchen Decor (Modern)',
        description: 'Upgrade de keukenlook voor de hele guild.',
        icon: '🧺',
        price: 200,
        category: 'decoration',
        rarity: 'rare',
        isGuildItem: true,
      ),
      ShopItem(
        id: 'meal_prep_kit',
        name: 'Meal Prep Kit',
        description: 'Koken duurt “korter”: tijdelijke cooldown-reductie.',
        icon: '🍱',
        price: 90,
        category: 'utility',
        rarity: 'common',
        isGuildItem: false,
      ),
      ShopItem(
        id: 'golden_ticket_box',
        name: 'Golden Ticket Box',
        description: 'Mystery box — vereist golden ticket om te openen.',
        icon: '🎟️',
        price: 0,
        category: 'utility',
        rarity: 'legendary',
        isGuildItem: false,
        isSpecial: true,
        requiresTicketId: 'golden_ticket',
      ),
      ShopItem(
        id: 'laundry_turbo_caps',
        name: 'Laundry Turbo Caps',
        description: '+10% XP op Laundry voor 24 uur.',
        icon: '🧼',
        price: 75,
        category: 'buff',
        rarity: 'rare',
        isGuildItem: false,
      ),
      ShopItem(
        id: 'guild_banner',
        name: 'Guild Banner',
        description: 'Nieuwe banner: +1% guild morale.',
        icon: '🚩',
        price: 150,
        category: 'decoration',
        rarity: 'epic',
        isGuildItem: true,
      ),
      ShopItem(
        id: 'toolkit_plus',
        name: 'Toolkit+',
        description: 'Fixing checks voelen makkelijker. +5% coins op Fixing.',
        icon: '🧰',
        price: 110,
        category: 'buff',
        rarity: 'rare',
        isGuildItem: false,
      ),
      ShopItem(
        id: 'forest_aroma_diffuser',
        name: 'Forest Aroma Diffuser',
        description: 'Kleine wellbeing aura voor iedereen in de guild.',
        icon: '🌲',
        price: 220,
        category: 'decoration',
        rarity: 'epic',
        isGuildItem: true,
      ),
    ];
    print(guildId);
    // Idempotent: zet alleen als het niet bestaat
    final batch = _db.batch();
    for (final it in items) {
      final doc = col.doc(it.id);
      final snap = await doc.get();
      if (!snap.exists) {
        batch.set(doc, {
          ...it.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'active': true,
        });
      }
    }
    await batch.commit();
  }

  // (optioneel) handig om elders te gebruiken:
  Future<List<ShopItem>> getGuildShopItems(String guildId) async {
    final q = await _guildShopCol(guildId).orderBy('price').get();
    return q.docs.map((d) {
      final data = <String, dynamic>{...(d.data())};
      data['id'] = data['id'] ?? d.id;
      return ShopItem.fromMap(data);
    }).toList();
  }

  Stream<List<ShopItem>> watchGuildShopItems(String guildId) {
    return _guildShopCol(guildId).where('active', isEqualTo: true).orderBy('price').snapshots().map((snap) => snap.docs.map((d) {
          final data = <String, dynamic>{...(d.data())};
          data['id'] = data['id'] ?? d.id;
          return ShopItem.fromMap(data);
        }).toList());
  }


  Future<void> createGuildShopItem({required String guildId, required ShopItem item}) async {
    final doc = item.id.isEmpty ? _guildShopCol(guildId).doc() : _guildShopCol(guildId).doc(item.id);
    await doc.set({
      ...item.toMap(),
      'id': doc.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
  }

  Future<void> upsertGuildShopItem({required String guildId, required ShopItem item}) async {
    await _guildShopCol(guildId).doc(item.id).set({
      ...item.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'active': true,
    }, SetOptions(merge: true));
  }

  Future<void> archiveGuildShopItem({required String guildId, required String itemId}) async {
    await _guildShopCol(guildId).doc(itemId).set({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

}
