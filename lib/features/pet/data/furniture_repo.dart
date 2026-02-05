// lib/features/pet/data/furniture_repo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/config/furniture.dart';

class FurnitureRepo {
  final FirebaseFirestore _db;
  FurnitureRepo({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _windowConfigCol =>
      _db.collection('config_windows');

  CollectionReference<Map<String, dynamic>> _userWindowsCol(String uid) =>
      _db.collection('users').doc(uid).collection('windows');

  DocumentReference<Map<String, dynamic>> _roomDoc(String uid) => _db.collection('rooms').doc(uid);

  /// Zet 1 furniture item actief voor een user.
  /// - checkt eerst of de user het item bezit (owned == true)
  /// - zet alle andere equipped-items op false
  /// - zet dit item op equipped = true
  /// - updatet rooms/{uid}.activeFurnitureId = furnitureId
  ///
  ///
  ///
  Future<bool> buyFurniture({
    required String uid,
    required String furnitureId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final configRef = _db.collection('config_furniture').doc(furnitureId);
    final userFurnRef = userRef.collection('furniture').doc(furnitureId);

    try {
      await _db.runTransaction((tx) async {
        // 1) config + user + eventueel bestaande furniture lezen
        final configSnap = await tx.get(configRef);
        if (!configSnap.exists) {
          throw StateError('Furniture config $furnitureId not found');
        }
        final cfg = FurnitureConfig.fromDoc(configSnap);

        if (!cfg.isActive) {
          throw StateError('Furniture is not active');
        }
        if (cfg.currency != 'coins') {
          throw StateError('Unsupported currency: ${cfg.currency}');
        }

        final userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw StateError('User $uid not found');
        }
        final userData = userSnap.data() ?? {};
        final currentCoins = (userData['coins'] ?? 0) as int;

        if (currentCoins < cfg.price) {
          throw StateError('Not enough coins');
        }

        final userFurnSnap = await tx.get(userFurnRef);
        final alreadyOwned = userFurnSnap.exists && (userFurnSnap.data()?['owned'] == true);

        // nu: maxOwned = 1 → al owned = niet opnieuw kopen
        if (alreadyOwned && cfg.maxOwned! <= 1) {
          throw StateError('Already owned');
        }

        // 2) coins aftrekken
        tx.update(userRef, {
          'coins': currentCoins - cfg.price,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3) furniture markeren als owned
        tx.set(
          userFurnRef,
          {
            'owned': true,
            'equipped': alreadyOwned ? (userFurnSnap.data()?['equipped'] ?? false) : false,
            'acquiredAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // (optioneel) aankoophistorie loggen:
        final purchasesRef = userRef.collection('purchases').doc();
        tx.set(purchasesRef, {
          'type': 'furniture',
          'furnitureId': furnitureId,
          'price': cfg.price,
          'currency': cfg.currency,
          'at': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setActiveFurniture({
    required String uid,
    required String furnitureId,
  }) async {
    final userFurnCol = _db.collection('users').doc(uid).collection('furniture');
    final roomDoc = _db.collection('rooms').doc(uid);

    await _db.runTransaction((tx) async {
      // 1) Check: user moet het item bezitten
      final furnRef = userFurnCol.doc(furnitureId);
      final furnSnap = await tx.get(furnRef);

      if (!furnSnap.exists || (furnSnap.data()?['owned'] != true)) {
        throw Exception(
          'User $uid bezit furniture "$furnitureId" niet (owned != true).',
        );
      }

      // 2) Alle huidige equipped items uitzetten
      final equippedQuery = await userFurnCol.where('equipped', isEqualTo: true).get();
      for (final doc in equippedQuery.docs) {
        tx.update(doc.reference, {'equipped': false});
      }

      // 3) Gewenste furniture equippen
      tx.update(furnRef, {
        'equipped': true,
        'equippedAt': FieldValue.serverTimestamp(),
      });

      // 4) Room-updates
      tx.set(
        roomDoc,
        {
          'activeFurnitureId': furnitureId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Alles uitzetten (geen actieve furniture meer)
  Future<void> clearActiveFurniture({required String uid}) async {
    final userFurnCol = _db.collection('users').doc(uid).collection('furniture');
    final roomDoc = _db.collection('rooms').doc(uid);

    await _db.runTransaction((tx) async {
      final equippedQuery = await userFurnCol.where('equipped', isEqualTo: true).get();
      for (final doc in equippedQuery.docs) {
        tx.update(doc.reference, {'equipped': false});
      }

      tx.set(
        roomDoc,
        {
          'activeFurnitureId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> seedFurnitureForUser(String uid) async {
    // Pas deze IDs aan naar de keys in jouw furniture_atlas.json
    const furnitureIds = <String>[
      'tower_beige',
      'tower_grey',
      'tower_blue',
    ];

    final batch = _db.batch();

    for (var i = 0; i < furnitureIds.length; i++) {
      final id = furnitureIds[i];

      final furnRef = _db.collection('users').doc(uid).collection('furniture').doc(id);

      batch.set(
        furnRef,
        {
          'owned': true,
          'equipped': i == 0, // eerste item is actief
          'equippedAt': i == 0 ? FieldValue.serverTimestamp() : null,
        },
        SetOptions(merge: true),
      );
    }

    // rooms/{uid} krijgt de eerste furniture als actief
    final roomRef = _db.collection('rooms').doc(uid);

    batch.set(
      roomRef,
      {
        'activeFurnitureId': furnitureIds.first,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> seedWindowConfig() async {
    final existing = await _windowConfigCol.limit(1).get();
    if (existing.docs.isNotEmpty) {
      // al ge-seed
      return;
    }

    // ⚠️ atlasKey hoeft nog niet te bestaan in je atlas.
    // we renderen in-game voorlopig als debug-rectangle met label.
    final items = [
      {
        'id': 'window_basic',
        'atlasKey': 'window_basic',
        'displayName': 'Basic Window',
        'description': 'A simple window.',
        'price': 300,
        'currency': 'coins',
        'category': 'window',
        'rarity': 'common',
        'maxOwned': 1,
        'isActive': true,
      },
      {
        'id': 'window_round',
        'atlasKey': 'window_round',
        'displayName': 'Round Window',
        'description': 'A cozy round window.',
        'price': 600,
        'currency': 'coins',
        'category': 'window',
        'rarity': 'rare',
        'maxOwned': 1,
        'isActive': true,
      },
    ];

    final batch = _db.batch();
    for (final m in items) {
      final id = m['id'] as String;
      batch.set(_windowConfigCol.doc(id), m);
    }
    await batch.commit();
  }

  /// Seed windows owned voor user + equip er 1 (idempotent merge)
  Future<void> seedWindowsForUser(String uid) async {
    const windowIds = <String>[
      'window_gray',
      'window_white',
      'window_brown',
      'window_wood',
    ];

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    for (var i = 0; i < windowIds.length; i++) {
      final id = windowIds[i];
      final ref = _userWindowsCol(uid).doc(id);

      batch.set(
        ref,
        {
          'owned': true,
          'equipped': i == 0, // alleen de eerste actief
          'acquiredAt': now,
          if (i == 0) 'equippedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    // actieve window opslaan op room-level (los van furniture)
    batch.set(
      _roomDoc(uid),
      {
        'activeWindowId': windowIds.first,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// Equip 1 window (los van furniture)
  Future<void> setActiveWindow({
    required String uid,
    required String windowId,
  }) async {
    final col = _userWindowsCol(uid);
    final roomDoc = _roomDoc(uid);

    await _db.runTransaction((tx) async {
      final wRef = col.doc(windowId);
      final wSnap = await tx.get(wRef);

      if (!wSnap.exists || (wSnap.data()?['owned'] != true)) {
        throw Exception('User $uid bezit window "$windowId" niet (owned != true).');
      }

      // alle andere windows unequip
      final equippedQuery = await col.where('equipped', isEqualTo: true).get();
      for (final doc in equippedQuery.docs) {
        tx.update(doc.reference, {'equipped': false});
      }

      tx.set(
        wRef,
        {
          'equipped': true,
          'equippedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.set(
        roomDoc,
        {
          'activeWindowId': windowId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> clearActiveWindow({required String uid}) async {
    final col = _userWindowsCol(uid);
    final roomDoc = _roomDoc(uid);

    await _db.runTransaction((tx) async {
      final equippedQuery = await col.where('equipped', isEqualTo: true).get();
      for (final doc in equippedQuery.docs) {
        tx.update(doc.reference, {'equipped': false});
      }

      tx.set(
        roomDoc,
        {
          'activeWindowId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }
}
