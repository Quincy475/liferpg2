import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/data/models/quest.dart';
import 'package:household_rpg/data/models/models.dart';

/// Gooi deze in dezelfde file of apart.
/// Belangrijk: controller kan dit catchen zonder UI error state.
class QuestCooldownException implements Exception {
  final DateTime cooldownUntil;
  QuestCooldownException(this.cooldownUntil);

  @override
  String toString() => 'Quest is on cooldown until $cooldownUntil';
}

abstract class QuestRepository {
  Future<List<Quest>> getDailyQuests(UserProfile user);
  Future<List<Quest>> getCoopQuests(UserProfile user);

  Future<void> completeDaily({required String questId, required UserProfile user});

  Future<void> contributeCoop({
    required String questId,
    required UserProfile user,
    required double delta,
  });

  Future<void> claimCoop({required String questId, required UserProfile user});
}

final questRepoProvider = Provider<QuestRepository>((ref) {
  return _QuestRepository();
});

class _QuestRepository implements QuestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _guildQuestsCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('quests');

  void _ensureGuild(UserProfile u) {
    final gid = u.guildId;
    if (gid == null || gid.isEmpty) throw StateError('User has no guild.');
  }

  ({int xp, int coins}) _applyMultipliers({
    required int baseXp,
    required int baseCoins,
    required UserProfile user,
    required int skillIndex,
  }) {
    // voorlopig geen boosts
    return (xp: baseXp, coins: baseCoins);
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  // ✅ Read completion doc voor 1 quest + user
  Future<Map<String, dynamic>?> _getCompletionForUser({
    required DocumentReference<Map<String, dynamic>> questRef,
    required String uid,
  }) async {
    final snap = await questRef.collection('completions').doc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  @override
  Future<List<Quest>> getDailyQuests(UserProfile user) async {
    _ensureGuild(user);

    // Pak alleen dailies
    final q = await _guildQuestsCol(user.guildId!)
        .where('type', isEqualTo: 'daily')
        .orderBy('createdAt', descending: false)
        .get();

    // Voor elke daily: completion ophalen en cooldownUntil mergen
    final futures = q.docs.map((doc) async {
      final questRef = doc.reference;
      final base = <String, dynamic>{...doc.data(), 'id': doc.id};

      final completion = await _getCompletionForUser(questRef: questRef, uid: user.id);
      if (completion != null) {
        final cooldownUntil = _toDateTime(completion['cooldownUntil']);

        // completed is “recent completed” als cooldown actief is (handig voor UI bar)
        final now = DateTime.now();
        final onCooldown = cooldownUntil != null && now.isBefore(cooldownUntil);

        base['cooldownUntil'] = cooldownUntil; // ✅ Quest.fromMap pakt dit op
        base['completed'] = onCooldown; // ✅ quick win: voelt logisch in UI
      } else {
        base['cooldownUntil'] = null;
        base['completed'] = false;
      }

      return Quest.fromMap(base);
    }).toList();

    return Future.wait(futures);
  }

  @override
  Future<List<Quest>> getCoopQuests(UserProfile user) async {
    _ensureGuild(user);

    final q = await _guildQuestsCol(user.guildId!)
        .where('type', isEqualTo: 'coop')
        .orderBy('createdAt', descending: false)
        .get();

    return q.docs.map((d) => Quest.fromMap({...d.data(), 'id': d.id})).toList();
  }

  @override
  Future<void> completeDaily({
    required String questId,
    required UserProfile user,
  }) async {
    _ensureGuild(user);

    final questRef = _guildQuestsCol(user.guildId!).doc(questId);
    final compRef = questRef.collection('completions').doc(user.id);
    final userRef = _userRef(user.id);

    await _db.runTransaction((tx) async {
      final questSnap = await tx.get(questRef);
      if (!questSnap.exists) throw StateError('Quest not found.');

      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('User doc missing.');

      final compSnap = await tx.get(compRef);
      final quest = questSnap.data()!;

      // --- Quest fields ---
      final rewardXp = (quest['rewardXp'] is num) ? (quest['rewardXp'] as num).toInt() : 0;
      final rewardCoins = (quest['rewardCoins'] is num) ? (quest['rewardCoins'] as num).toInt() : 0;
      final skillIndex = (quest['skill'] is num) ? (quest['skill'] as num).toInt() : 0;
      final cooldownMin =
          (quest['cooldownMinutes'] is num) ? (quest['cooldownMinutes'] as num).toInt() : 0;

      // --- Cooldown check ---
      DateTime? cooldownUntil;
      if (compSnap.exists) {
        final m = compSnap.data()!;
        cooldownUntil = _toDateTime(m['cooldownUntil']);
      }

      final now = DateTime.now();
      if (cooldownUntil != null && now.isBefore(cooldownUntil!)) {
        // ✅ geef datum mee zodat UI/controller kan tonen "nog 12m"
        throw QuestCooldownException(cooldownUntil!);
      }

      final adjusted = _applyMultipliers(
        baseXp: rewardXp,
        baseCoins: rewardCoins,
        user: user,
        skillIndex: skillIndex,
      );

      final newCooldownUntil = cooldownMin > 0 ? now.add(Duration(minutes: cooldownMin)) : null;

      // --- completion doc ---
      tx.set(
        compRef,
        {
          'userId': user.id,
          'completedAt': FieldValue.serverTimestamp(),
          if (newCooldownUntil != null)
            'cooldownUntil': Timestamp.fromDate(newCooldownUntil), // ✅ consistent
          'times': FieldValue.increment(1),
          'lastRewardXp': adjusted.xp,
          'lastRewardCoins': adjusted.coins,
        },
        SetOptions(merge: true),
      );

      // --- log ---
      final logRef = compRef.collection('log').doc();
      tx.set(logRef, {
        'userId': user.id,
        'questId': questId,
        'at': FieldValue.serverTimestamp(),
        'deltaXp': adjusted.xp,
        'deltaCoins': adjusted.coins,
        'skill': skillIndex,
        'reason': 'complete',
      });

      // --- user updates ---
      final skillKey = skillIndex.toString();
      tx.update(userRef, {
        'coins': FieldValue.increment(adjusted.coins),
        'weeklyPoints': FieldValue.increment(adjusted.xp),
        'updatedAt': FieldValue.serverTimestamp(),
        'skillXp.$skillKey': FieldValue.increment(adjusted.xp),
      });
    });
  }

  @override
  Future<void> contributeCoop({
    required String questId,
    required UserProfile user,
    required double delta,
  }) async {
    _ensureGuild(user);
    final questRef = _guildQuestsCol(user.guildId!).doc(questId);

    await _db.runTransaction((tx) async {
      final qSnap = await tx.get(questRef);
      if (!qSnap.exists) return;

      final cur = (qSnap.data()?['progress'] ?? 0.0) as num;
      final goal = (qSnap.data()?['goal'] ?? 100.0) as num;

      final next = (cur.toDouble() + delta).clamp(0.0, goal.toDouble());
      tx.update(questRef, {
        'progress': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // optioneel: per-user log
      final contribRef = questRef.collection('contrib').doc();
      tx.set(contribRef, {
        'userId': user.id,
        'delta': delta,
        'at': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> claimCoop({required String questId, required UserProfile user}) async {
    _ensureGuild(user);

    final questRef = _guildQuestsCol(user.guildId!).doc(questId);
    final claimRef = questRef.collection('claims').doc(user.id);

    await _db.runTransaction((tx) async {
      final qSnap = await tx.get(questRef);
      if (!qSnap.exists) return;

      final progress = (qSnap.data()?['progress'] ?? 0.0) as num;
      final goal = (qSnap.data()?['goal'] ?? 100.0) as num;
      if (progress.toDouble() < goal.toDouble()) {
        throw StateError('Quest nog niet voltooid.');
      }

      final already = await tx.get(claimRef);
      if (already.exists) return;

      tx.set(claimRef, {
        'userId': user.id,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      // coins/xp claim beloning kan je later hier toevoegen
    });
  }
}
