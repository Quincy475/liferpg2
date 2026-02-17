import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/Shop_Item.dart';

class ShopRepository {
  final FirebaseFirestore _db;
  ShopRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _guildShopCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('shopItems');

  Future<void> upsertItem({required String guildId, required ShopItem item}) async {
    final doc = item.id.isEmpty ? _guildShopCol(guildId).doc() : _guildShopCol(guildId).doc(item.id);
    await doc.set({
      ...item.toMap(),
      'id': doc.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> archiveItem({required String guildId, required String itemId}) async {
    await _guildShopCol(guildId).doc(itemId).set({
      'archived': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> seedGuildShop({required String guildId}) async {
    final items = <ShopItem>[
      const ShopItem(
        id: 'coffee_voucher',
        title: 'Coffee Voucher',
        description: 'Een avond geen afwas hoeven doen.',
        icon: '☕',
        price: 50,
        category: 'reward',
      ),
      const ShopItem(
        id: 'movie_night',
        title: 'Movie Night Pick',
        description: 'Jij kiest de film vanavond.',
        icon: '🎬',
        price: 120,
        category: 'reward',
      ),
    ];

    for (final item in items) {
      final snap = await _guildShopCol(guildId).doc(item.id).get();
      if (!snap.exists) {
        await upsertItem(guildId: guildId, item: item);
      }
    }
  }

  Future<List<ShopItem>> getGuildShopItems(String guildId) async {
    final q = await _guildShopCol(guildId).where('archived', isNotEqualTo: true).orderBy('price').get();
    return q.docs.map((d) {
      final data = <String, dynamic>{...(d.data())};
      data['id'] = data['id'] ?? d.id;
      return ShopItem.fromMap(data);
    }).toList();
  }

  Stream<List<ShopItem>> watchGuildShopItems(String guildId) {
    return _guildShopCol(guildId)
        .where('archived', isNotEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = <String, dynamic>{...(d.data())};
              data['id'] = data['id'] ?? d.id;
              return ShopItem.fromMap(data);
            }).toList());
  }
}
