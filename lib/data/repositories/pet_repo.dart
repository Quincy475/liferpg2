import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/Pet.dart';

class PetRepository {
  final FirebaseFirestore _db;
  PetRepository(this._db);

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) =>
      _db.collection('users').doc(uid).collection('pet').doc('state');

  DocumentReference<Map<String, dynamic>> _roomRef(String uid) =>
      _db.collection('users').doc(uid).collection('pet').doc('room');

  /// Stream van PetState (null als doc nog niet bestaat)
  Stream<PetState?> watchState(String uid) {
    return _stateRef(uid).snapshots().map(
      (s) => s.exists ? PetState.fromMap(s.data()!) : null,
    );
  }

  Future<PetState?> getState(String uid) async {
    final s = await _stateRef(uid).get();
    if (!s.exists) return null;
    return PetState.fromMap(s.data()!);
  }

  Stream<RoomLayout?> watchRoom(String uid) {
    return _roomRef(uid).snapshots().map(
      (s) => s.exists ? RoomLayout.fromMap(s.data()!) : null,
    );
  }

  Future<void> createDefaultProfile({
    required String uid,
    required PetSpecies species,
  }) async {
    final now = DateTime.now();

    final state = PetState(species: species, updatedAt: now);
    final room = RoomLayout(
      background: '1.png',
      placed: const [
        // FurnitureItem(id: 'bowl', sprite: 'furnitures/bowl_full.png', x: 100, y: 260),
        // FurnitureItem(id: 'bed',  sprite: 'furnitures/bed.png',       x: 280, y: 250),
      ],
    );

    await _db.runTransaction((tx) async {
      tx.set(_stateRef(uid), state.toMap());
      tx.set(_roomRef(uid), room.toMap());
    });
  }

  // ----- Actions -----

Future<void> upsertPlacedItem(String uid, PlacedItem item) async {
  final ref = _roomRef(uid);
  await _db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final data = snap.data() ?? {};
    final room = snap.exists ? RoomLayout.fromMap(data) : RoomLayout(background: '1.png', placed: []);

    final idx = room.placed.indexWhere((p) => p.instanceId == item.instanceId);
    final next = [...room.placed];
    if (idx >= 0) next[idx] = item;
    else next.add(item);

    tx.set(ref, {
      'background': room.background,
      'placed': next.map((p) => p.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

  Future<void> feed(String uid) async {
    await _db.runTransaction((tx) async {
      final ref = _stateRef(uid);
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final st = snap.exists ? PetState.fromMap(data) : null;
      final now = DateTime.now();

      final next = (st ?? PetState(species: PetSpecies.cat, updatedAt: now)).copyWith(
        hunger: _cap((st?.hunger ?? 70) + 20),
        happiness: _cap((st?.happiness ?? 70) + 5),
        mood: 'eat',
        updatedAt: now,
      );
      tx.set(ref, next.toMap());
    });
  }

  Future<void> play(String uid) async {
    await _db.runTransaction((tx) async {
      final ref = _stateRef(uid);
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final st = snap.exists ? PetState.fromMap(data) : null;
      final now = DateTime.now();

      final next = (st ?? PetState(species: PetSpecies.cat, updatedAt: now)).copyWith(
        happiness: _cap((st?.happiness ?? 70) + 15),
        energy: _cap((st?.energy ?? 70) - 10),
        mood: 'play',
        updatedAt: now,
      );
      tx.set(ref, next.toMap());
    });
  }

  Future<void> sleep(String uid) async {
    await _db.runTransaction((tx) async {
      final ref = _stateRef(uid);
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final st = snap.exists ? PetState.fromMap(data) : null;
      final now = DateTime.now();

      final next = (st ?? PetState(species: PetSpecies.cat, updatedAt: now)).copyWith(
        energy: _cap((st?.energy ?? 70) + 25),
        mood: 'sleep',
        updatedAt: now,
      );
      tx.set(ref, next.toMap());
    });
  }

  int _cap(int v) => v.clamp(0, 100);
}

