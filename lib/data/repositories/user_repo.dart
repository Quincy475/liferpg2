import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_rpg/data/models/models.dart';

/// Firestore-backed repository voor UserProfile.
/// - Houdt je model aan (id, name, Map<SkillType,int> skillXp, coins, weeklyPoints, etc.)
/// - Gebruikt ISO8601-string voor lastReset (past bij je model)
/// - Schrijft timestamps met FieldValue.serverTimestamp()
class UserRepository {
  final FirebaseFirestore _db;
  const UserRepository(this._db);

  // ---- Refs ---------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> userRef(String uid) => _db.collection('users').doc(uid);

// ====== Refs ======
  CollectionReference<Map<String, dynamic>> inventoryRef(String uid) =>
      userRef(uid).collection('inventory');
  CollectionReference<Map<String, dynamic>> purchasesRef(String uid) =>
      userRef(uid).collection('purchases');

  CollectionReference<Map<String, dynamic>> get _guildsCol => _db.collection('guilds');
  DocumentReference<Map<String, dynamic>> guildRef(String gid) => _guildsCol.doc(gid);
  CollectionReference<Map<String, dynamic>> membersCol(String gid) =>
      guildRef(gid).collection('members');
  DocumentReference<Map<String, dynamic>> memberRef(String gid, String uid) =>
      membersCol(gid).doc(uid);

// ====== Inventory API ======
  Stream<List<InventoryItem>> watchInventory(String uid) {
    return inventoryRef(uid)
        .snapshots()
        .map((snap) => snap.docs.map(InventoryItem.fromDoc).toList());
  }

  Future<List<InventoryItem>> getInventory(String uid) async {
    final q = await inventoryRef(uid).get();
    return q.docs.map(InventoryItem.fromDoc).toList();
  }

  Future<void> incrementInventoryItem(String uid,
      {required String itemId, required String name, int delta = 1}) async {
    final ref = inventoryRef(uid).doc(itemId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final cur = (snap.data()?['quantity'] ?? 0) as int;
      tx.set(ref, {'name': name, 'quantity': cur + delta}, SetOptions(merge: true));
    });
  }

// ====== Purchases API ======
  Future<List<PurchaseEntry>> getPurchases(String uid) async {
    final q = await purchasesRef(uid).orderBy('at', descending: true).limit(50).get();
    return q.docs.map(PurchaseEntry.fromDoc).toList();
  }

  Future<void> logPurchase(String uid, {required String itemId, required int price}) async {
    final doc = purchasesRef(uid).doc();
    await doc.set({
      'itemId': itemId,
      'price': price,
      'at': FieldValue.serverTimestamp(),
    });
  }
  // ---- Helpers: skillXp conversies ---------------------------------------

  /// Maakt een lege Firestore skill-map: { "0":0, "1":0, ... }
  Map<String, int> _emptySkillXpMap() {
    final m = <String, int>{};
    for (final s in SkillType.values) {
      m[s.index.toString()] = 0;
    }
    return m;
  }

  /// Converteer Firestore map -> Map<SkillType,int>
  Map<SkillType, int> _skillMapFromFs(Map? raw) {
    final map = <SkillType, int>{};
    final input = Map<String, dynamic>.from(raw ?? {});
    for (final e in input.entries) {
      final idx = int.tryParse(e.key);
      if (idx == null || idx < 0 || idx >= SkillType.values.length) continue;
      map[SkillType.values[idx]] = (e.value as num?)?.toInt() ?? 0;
    }
    // vul ontbrekende keys aan met 0
    for (final s in SkillType.values) {
      map.putIfAbsent(s, () => 0);
    }
    return map;
  }

  /// Converteer Map<SkillType,int> -> Firestore map met string keys
  Map<String, int> _skillMapToFs(Map<SkillType, int> src) {
    final out = <String, int>{};
    for (final s in SkillType.values) {
      out[s.index.toString()] = src[s] ?? 0;
    }
    return out;
  }

  Future<UserProfile?> getActiveUser() async {
    print('test');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    print(uid);
    if (uid == null) return null;
    final snap = await userRef(uid).get();
    print(snap);
    if (!snap.exists) {
      print('fail');
      return null;
    }
    final data = <String, dynamic>{...(snap.data() ?? {})};
    print('DATAA:$data');
    data['id'] = data['id'] ?? snap.id;
    final user = UserProfile.fromMap(data);
    print('USER: $user');
    return user;
  }

  // ---- Read / Watch -------------------------------------------------------

  /// Live user-profiel stream. Injecteert docId als 'id' als veld ontbreekt.
  Stream<UserProfile?> watchUser(String uid) {
    return userRef(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = <String, dynamic>{...(snap.data() ?? {})};
      data['id'] = data['id'] ?? snap.id;
      return UserProfile.fromMap(data);
    });
  }

  /// Eenmalig lezen
  // Future<UserProfile?> getUser(String uid) async {
  //   print('tt $user');
  //   return user;
  // }

  /// Meerdere users in één keer ophalen (handig voor guild members)
  Future<List<UserProfile>> getUsersgetUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    final chunks = <List<String>>[];
    const maxIn = 10; // Firestore whereIn max
    for (var i = 0; i < uids.length; i += maxIn) {
      chunks.add(uids.sublist(i, i + maxIn > uids.length ? uids.length : i + maxIn));
    }
    final results = <UserProfile>[];
    for (final c in chunks) {
      final q = await _db.collection('users').where(FieldPath.documentId, whereIn: c).get();
      for (final d in q.docs) {
        final data = <String, dynamic>{...(d.data())};
        data['id'] = data['id'] ?? d.id;
        results.add(UserProfile.fromMap(data));
      }
    }
    return results;
  }

  Future<List<UserProfile>> getUsersByGuild(String guildId) async {
    final q = await _db.collection('users').where('guildId', isEqualTo: guildId).get();

    return q.docs.map((d) {
      final data = <String, dynamic>{...(d.data())};
      data['id'] = data['id'] ?? d.id;
      return UserProfile.fromMap(data);
    }).toList();
  }

  /// Live stream (realtime updates) van users in een guild
  Stream<List<UserProfile>> watchUsersByGuild(String guildId) {
    return _db
        .collection('users')
        .where('guildId', isEqualTo: guildId)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = <String, dynamic>{...(d.data())};
              data['id'] = data['id'] ?? d.id;
              return UserProfile.fromMap(data);
            }).toList());
  }

  // ---- Create / Ensure ----------------------------------------------------

  /// Zorgt dat users/{uid} bestaat met default velden (merge-safe)
  Future<void> ensureUserDoc(String uid, {String defaultName = 'Player'}) async {
    final ref = userRef(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'id': uid,
        'name': defaultName,
        'skillXp': _emptySkillXpMap(),
        'coins': 0,
        'soloCoins': 0,
        'weeklyPoints': 0,
        'streaks': <String, int>{},
        'badges': <String>[],
        'crown': false,
        'lastReset': null,
        'guildId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // backfill ontbrekende keys in skillXp
      final data = snap.data() ?? {};
      final current = Map<String, dynamic>.from(data['skillXp'] ?? {});
      bool needsUpdate = false;
      for (final s in SkillType.values) {
        final k = s.index.toString();
        if (!current.containsKey(k)) {
          current[k] = 0;
          needsUpdate = true;
        }
      }
      if (needsUpdate) {
        await ref.update({'skillXp': current, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
  }

  // ---- Profile updates ----------------------------------------------------

  Future<void> updateName(String uid, String name) async {
    await userRef(uid).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAvatarUrl(String uid, String? url) async {
    await userRef(uid).update({
      'avatarUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Coins / Points / Skills -------------------------------------------

  Future<void> addCoins(String uid, int delta) async {
    await userRef(uid).update({
      'coins': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addWeeklyPoints(String uid, int delta) async {
    await userRef(uid).update({
      'weeklyPoints': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Voegt XP toe aan een skill + telt weeklyPoints mee (zoals je score-engine doet)
  Future<void> addSkillXp(String uid, SkillType skill, int delta) async {
    final ref = userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final fsMap = Map<String, dynamic>.from(data['skillXp'] ?? {});
      final key = skill.index.toString();
      final cur = (fsMap[key] ?? 0) as int;
      fsMap[key] = cur + delta;
      tx.update(ref, {
        'skillXp': fsMap,
        'weeklyPoints': FieldValue.increment(delta),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  int _levelFromXp(int xp) => (xp / 200).floor();
  int _pointsEarnedFromXp(int xp) => _levelFromXp(xp) ~/ 2; // 1 punt per 2 levels

  Future<void> unlockPerk({
    required String uid,
    required SkillType skill,
    required String perkId,
    int cost = 1,
  }) async {
    final ref = userRef(uid);
    final key = skill.index.toString(); // <-- string key "0","1",...

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});

      // XP & earned points (keys zijn strings in Firestore)
      final sx = Map<String, dynamic>.from(data['skillXp'] ?? {});
      final xp = (sx[key] as num?)?.toInt() ?? 0; // num -> int veilig
      final earnedPoints = _pointsEarnedFromXp(xp);

      // perks map (string index -> List<String>)
      final perksMap = Map<String, dynamic>.from(data['perks'] ?? {});
      final currentList = List<String>.from(perksMap[key] as List? ?? const <String>[]);

      // al unlocked?
      if (currentList.contains(perkId)) {
        return; // niets te doen
      }

      // punten controleren
      final spent = currentList.length;
      final available = earnedPoints - spent;
      if (available < cost) {
        throw StateError('Not enough skill points');
      }

      currentList.add(perkId);
      perksMap[key] = currentList;

      tx.update(ref, {
        'perks': perksMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> respecAllInSkill({
    required String uid,
    required SkillType skill,
  }) async {
    final key = skill.index.toString(); // <-- string key
    await userRef(uid).update({
      'perks.$key': <String>[],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Streaks / Badges / Crown / Reset ----------------------------------

  /// Verhoog streak voor taskId met 1 (zonder logica voor “gebroken streak”)
  Future<void> incrementStreak(String uid, String taskId) async {
    final ref = userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final streaks = Map<String, dynamic>.from(data['streaks'] ?? {});
      final cur = (streaks[taskId] ?? 0) as int;
      streaks[taskId] = cur + 1;
      tx.update(ref, {
        'streaks': streaks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addBadge(String uid, String badgeId) async {
    await userRef(uid).update({
      'badges': FieldValue.arrayUnion([badgeId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeBadge(String uid, String badgeId) async {
    await userRef(uid).update({
      'badges': FieldValue.arrayRemove([badgeId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCrown(String uid, bool value) async {
    await userRef(uid).update({
      'crown': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Markeer week-reset moment (ISO-string, sluit aan op je model)
  Future<void> setLastReset(String uid, DateTime when) async {
    await userRef(uid).update({
      'lastReset': when.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// (Optioneel) Zet weeklyPoints=0 en crown=false bij reset
  Future<void> weeklyHardReset(String uid) async {
    await userRef(uid).update({
      'weeklyPoints': 0,
      'crown': false,
      'lastReset': DateTime.now().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Guild --------------------------------------------------------------
  String _randomInviteCode({int len = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Zet guildId rechtstreeks (client-side). Voor echte co-op: beheer via Cloud Functions + rules.
  Future<void> setGuild(String uid, String? guildId) async {
    await userRef(uid).update({
      'guildId': guildId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGuild(String uid, String guildId) => setGuild(uid, guildId);
  Future<void> leaveGuild(String uid) => setGuild(uid, null);

  Future<void> leaveGuildSafely(String uid) async {
    await _db.runTransaction((tx) async {
      final uRef = userRef(uid);
      final userSnap = await tx.get(uRef);
      final userData = userSnap.data() ?? <String, dynamic>{};
      final guildId = userData['guildId'] as String?;
      if (guildId == null) {
        throw StateError('Je zit niet in een guild.');
      }

      final memberSnap = await tx.get(memberRef(guildId, uid));
      final role = memberSnap.data()?['role'] as String? ?? 'member';
      if (role == 'owner') {
        final owners = await membersCol(guildId).where('role', isEqualTo: 'owner').get();
        if (owners.docs.length <= 1) {
          throw StateError('Je bent de enige owner. Draag eerst ownership over.');
        }
      }

      tx.set(
          uRef,
          {
            'guildId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      tx.delete(memberRef(guildId, uid));
    });
  }

  Future<String> createGuildAndJoin({
    required String ownerUid,
    required String name,
    String emoji = '🏰',
    String colorHex = '#D6B05F',
  }) async {
    final gid = _guildsCol.doc().id; // eigen id, zodat we het binnen de tx kunnen gebruiken
    final inviteCode = _randomInviteCode();

    await _db.runTransaction((tx) async {
      final gRef = guildRef(gid);
      final mRef = memberRef(gid, ownerUid);
      final uRef = userRef(ownerUid);

      // 1) Guild doc
      tx.set(gRef, {
        'name': name,
        'emoji': emoji,
        'color': colorHex,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': ownerUid,
        'inviteCode': inviteCode,
        'settings': {},
      });

      // 2) Member doc (owner)
      tx.set(mRef, {
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 3) User → guildId
      tx.set(
          uRef,
          {
            'guildId': gid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return gid;
  }

  /// Join met inviteCode
  Future<String> joinByInviteCode({required String uid, required String inviteCode}) async {
    final q = await _guildsCol.where('inviteCode', isEqualTo: inviteCode).limit(1).get();
    if (q.docs.isEmpty) {
      throw StateError('Ongeldige invite code');
    }
    final gid = q.docs.first.id;

    await _db.runTransaction((tx) async {
      final mRef = memberRef(gid, uid);
      final uRef = userRef(uid);

      // voeg toe als member (als bestaat: merge)
      tx.set(
          mRef,
          {
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      tx.set(
          uRef,
          {
            'guildId': gid,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    return gid;
  }

  /// (Optioneel) Leden opvragen
  Future<List<Map<String, dynamic>>> getMembers(String gid) async {
    final snap = await membersCol(gid).get();
    return snap.docs.map((d) => {'uid': d.id, ...(d.data())}).toList();
  }

  /// (Optioneel) Guild details
  Future<Map<String, dynamic>?> getGuild(String gid) async {
    final snap = await guildRef(gid).get();
    return snap.data();
  }

/// Koop een shop item:
/// - controleert coins
/// - trekt coins af
/// - logt aankoop in users/{uid}/purchases
/// - (nog) geen effecten; inventory doe je na de transactie (UI-keuze)
Future<bool> purchaseItem({
  required String userId,
  required ShopItem item,
}) async {
  final ref = userRef(userId);

  try {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('User not found');
      }
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final currentCoins = (data['coins'] ?? 0) as int;

      if (currentCoins < item.price) {
        throw StateError('Not enough coins');
      }

      // trek coins af
      tx.update(ref, {
        'coins': currentCoins - item.price,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // log aankoop
      final pRef = ref.collection('purchases').doc();
      tx.set(pRef, {
        'itemId': item.id,
        'itemName': item.name,
        'price': item.price,
        'isGuildItem': item.isGuildItem,
        'isSpecial': item.isSpecial,
        'rarity': item.rarity,
        'category': item.category,
        'requiresTicketId': item.requiresTicketId,
        'at': FieldValue.serverTimestamp(),
      });
    });

    return true;
  } on FirebaseException catch (e) {
    // bv. ABORTED / FAILED_PRECONDITION
    // print('purchaseItem FirebaseException: ${e.message}');
    return false;
  } catch (_) {
    return false;
  }
}

/// Voeg (of verhoog) een item in de inventory van de user
Future<void> addToInventory({
  required String userId,
  required String itemId,
  required String itemName,
  int delta = 1,
}) async {
  final ref = userRef(userId).collection('inventory').doc(itemId);
  await _db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final cur = (snap.data()?['quantity'] ?? 0) as int;
    tx.set(ref, {
      'name': itemName,
      'quantity': cur + delta,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}
  /// Logt een aankoop in /users/{uid}/purchases (optioneel; voor historie)

  // ---- Gecombineerde helper voor task-completion (optioneel) --------------

  /// Combineert coins + skill XP + weekly points in één flow.
  /// Handig als je rechtstreeks je scoring-resultaat wilt toepassen.
  Future<void> applyTaskResult({
    required String uid,
    required SkillType skill,
    required int xpDelta,
    required int coinsDelta,
    String? streakTaskId,
    String? badgeToAddIfAny,
  }) async {
    final ref = userRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});

      // coins
      final coins = (data['coins'] ?? 0) as int;

      // skill xp
      final fsMap = Map<String, dynamic>.from(data['skillXp'] ?? _emptySkillXpMap());
      final key = skill.index.toString();
      final curXp = (fsMap[key] ?? 0) as int;
      fsMap[key] = curXp + xpDelta;

      // weekly points
      final weekly = (data['weeklyPoints'] ?? 0) as int;

      // streaks
      final streaks = Map<String, dynamic>.from(data['streaks'] ?? {});
      if (streakTaskId != null) {
        final cur = (streaks[streakTaskId] ?? 0) as int;
        streaks[streakTaskId] = cur + 1;
      }

      // badges
      final badges = List<String>.from(data['badges'] ?? const <String>[]);
      if (badgeToAddIfAny != null && !badges.contains(badgeToAddIfAny)) {
        badges.add(badgeToAddIfAny);
      }

      tx.update(ref, {
        'coins': coins + coinsDelta,
        'skillXp': fsMap,
        'weeklyPoints': weekly + xpDelta,
        'streaks': streaks,
        'badges': badges,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class InventoryItem {
  final String id; // doc id
  final String name; // redundante naam; handig voor UI
  final int quantity;

  const InventoryItem({required this.id, required this.name, required this.quantity});

  static InventoryItem fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return InventoryItem(
      id: d.id,
      name: (m['name'] ?? d.id) as String,
      quantity: (m['quantity'] ?? 0) as int,
    );
  }
}

class PurchaseEntry {
  final String id;
  final String itemId;
  final int price;
  final DateTime at;

  const PurchaseEntry(
      {required this.id, required this.itemId, required this.price, required this.at});

  static PurchaseEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final ts = m['at'];
    return PurchaseEntry(
      id: d.id,
      itemId: (m['itemId'] ?? '') as String,
      price: (m['price'] ?? 0) as int,
      at: (ts is Timestamp)
          ? ts.toDate()
          : DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
