import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/scoring/scoring_enginge.dart' show kXpPerCoin;

final taskMvpRepoProvider = Provider<TaskMvpRepository>((ref) {
  return TaskMvpRepository(FirebaseFirestore.instance);
});

class TaskMvpRepository {
  final FirebaseFirestore _db;
  const TaskMvpRepository(this._db);

  CollectionReference<Map<String, dynamic>> _templates(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskTemplates');

  CollectionReference<Map<String, dynamic>> _instances(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskInstances');

  CollectionReference<Map<String, dynamic>> _events(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskEvents');

  CollectionReference<Map<String, dynamic>> _groups(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskGroups');

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  // ---- Coöp-quests (taakgroepen) -----------------------------------------
  Stream<List<TaskGroup>> watchGroups(String guildId) {
    return _groups(guildId)
        .orderBy('title')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskGroup.fromMap(d.id, d.data())).toList());
  }

  Future<String> createGroup({
    required String guildId,
    required TaskGroup input,
    required String actorUserId,
  }) async {
    final ref = _groups(guildId).doc();
    await ref.set({
      ...input.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'created_group',
      payload: {'title': input.title},
    );
    return ref.id;
  }

  Future<void> updateGroup({
    required String guildId,
    required TaskGroup input,
    required String actorUserId,
  }) async {
    await _groups(guildId).doc(input.id).set(input.toMap(), SetOptions(merge: true));
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'updated_group',
      payload: {'title': input.title},
    );
  }

  /// Verwijder een coöp-quest: archiveer de subtaak-templates, ruim open
  /// instances op en verwijder het groep-doc.
  Future<void> deleteGroup({
    required String guildId,
    required String groupId,
    required String actorUserId,
  }) async {
    final templates = await _templates(guildId).where('groupId', isEqualTo: groupId).get();
    for (final doc in templates.docs) {
      await removeOpenInstancesForTemplate(guildId: guildId, templateId: doc.id);
      await _templates(guildId).doc(doc.id).delete();
    }
    final snap = await _groups(guildId).doc(groupId).get();
    final title = (snap.data()?['title'] ?? '') as String;
    await _groups(guildId).doc(groupId).delete();
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'deleted_group',
      payload: {'title': title},
    );
  }

  Stream<List<TaskTemplate>> watchTemplates(String guildId) {
    return _templates(guildId)
        .where('active', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskTemplate.fromMap(d.id, d.data())).toList());
  }

  Future<void> createTemplate({
    required String guildId,
    required TaskTemplate input,
    required String actorUserId,
  }) async {
    final ref = _templates(guildId).doc();
    await ref.set({
      ...input.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'created_template',
      templateId: ref.id,
      payload: {'title': input.title},
    );
  }

  Future<void> updateTemplate({
    required String guildId,
    required TaskTemplate input,
    required String actorUserId,
  }) async {
    await _templates(guildId).doc(input.id).set(input.toMap(), SetOptions(merge: true));
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'updated_template',
      templateId: input.id,
      payload: {'title': input.title},
    );
  }

  Future<void> archiveTemplate({
    required String guildId,
    required String templateId,
    required String actorUserId,
  }) async {
    final snap = await _templates(guildId).doc(templateId).get();
    final title = (snap.data()?['title'] ?? '') as String;
    await _templates(guildId).doc(templateId).delete();
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'deleted_template',
      templateId: templateId,
      payload: {'title': title},
    );
  }

  Stream<List<TaskInstance>> watchWeekInstances({
    required String guildId,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final start = Timestamp.fromDate(weekStart);
    final end = Timestamp.fromDate(weekEnd);
    return _instances(guildId)
        .where('scheduledFor', isGreaterThanOrEqualTo: start)
        .where('scheduledFor', isLessThanOrEqualTo: end)
        .orderBy('scheduledFor')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskInstance.fromMap(d.id, d.data())).toList());
  }

  Stream<List<TaskEvent>> watchRecentEvents({required String guildId, int limit = 60}) {
    return _events(guildId)
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => TaskEvent.fromMap(d.id, d.data())).toList());
  }

  Future<void> ensureUpcomingInstances({
    required String guildId,
    required DateTime from,
    required DateTime to,
  }) async {
    final templates = await _templates(guildId).where('active', isEqualTo: true).get();
    final batch = _db.batch();

    for (final doc in templates.docs) {
      final t = TaskTemplate.fromMap(doc.id, doc.data());
      final generated = _generateDates(t, from, to);

      for (final scheduled in generated) {
        final instanceId = '${doc.id}_${scheduled.toUtc().toIso8601String()}';
        final iref = _instances(guildId).doc(instanceId);
        final exists = await iref.get();
        if (exists.exists) continue;

        final dueAt = _defaultDueAt(t, scheduled);
        final takeover = dueAt.add(Duration(minutes: t.takeoverAfterMinutes));

        batch.set(iref, {
          'templateId': doc.id,
          'scheduledFor': Timestamp.fromDate(scheduled),
          'dueAt': Timestamp.fromDate(dueAt),
          'takeoverAllowedAt': Timestamp.fromDate(takeover),
          'status': 'open',
          'claimedByUserId': null,
          'claimedAt': null,
          'completedByUserId': null,
          'completedAt': null,
          'coinsAwarded': t.coinsBase,
          'bonusReason': null,
          'title': t.title,
          'description': t.description,
          'groupId': t.groupId,
          'skillTypeIndex': t.skillType?.index,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> markOverdueAsMissed({required String guildId}) async {
    final now = Timestamp.fromDate(DateTime.now());
    final q = await _instances(guildId)
        .where('status', whereIn: ['open', 'claimed'])
        .where('takeoverAllowedAt', isLessThanOrEqualTo: now)
        .get();

    final batch = _db.batch();
    for (final d in q.docs) {
      batch.set(
          d.reference,
          {
            'status': 'missed',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      final data = d.data();
      if ((data['bonusReason'] ?? '').toString().isNotEmpty) continue;
      batch.set(
          d.reference,
          {
            'bonusReason': 'missed',
          },
          SetOptions(merge: true));
    }
    if (q.docs.isNotEmpty) await batch.commit();
  }

  Future<void> claimInstance({
    required String guildId,
    required String instanceId,
    required String userId,
  }) async {
    final ref = _instances(guildId).doc(instanceId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Task instance not found');
      final m = snap.data()!;
      final status = (m['status'] ?? 'open').toString();
      if (status == 'completed' || status == 'missed' || status == 'expired') {
        throw StateError('Task can no longer be claimed');
      }

      tx.set(
          ref,
          {
            'status': 'claimed',
            'claimedByUserId': userId,
            'claimedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    final snap2 = await _instances(guildId).doc(instanceId).get();
    await _logEvent(
      guildId: guildId,
      actorUserId: userId,
      type: 'claimed',
      instanceId: instanceId,
      payload: {'title': (snap2.data()?['title'] ?? '') as String},
    );
  }

  Future<void> unclaimInstance({
    required String guildId,
    required String instanceId,
    required String userId,
  }) async {
    final ref = _instances(guildId).doc(instanceId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Task instance not found');
      final m = snap.data()!;
      final status = (m['status'] ?? 'open').toString();
      final claimedBy = (m['claimedByUserId'] ?? '').toString();
      if (status == 'completed' || status == 'missed' || status == 'expired') {
        throw StateError('Task can no longer be unclaimed');
      }
      if (claimedBy != userId) {
        throw StateError('Only the claimer can unclaim this task');
      }

      tx.set(
          ref,
          {
            'status': 'open',
            'claimedByUserId': null,
            'claimedAt': null,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    final snap2 = await _instances(guildId).doc(instanceId).get();
    await _logEvent(
      guildId: guildId,
      actorUserId: userId,
      type: 'unclaimed',
      instanceId: instanceId,
      payload: {'title': (snap2.data()?['title'] ?? '') as String},
    );
  }

  Future<void> completeInstance({
    required String guildId,
    required String instanceId,
    required String userId,
  }) async {
    final ref = _instances(guildId).doc(instanceId);
    final userRef = _user(userId);
    String instanceTitle = '';
    int coinsTotal = 0;
    String? groupId;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Task instance not found');
      final m = snap.data()!;
      final status = (m['status'] ?? 'open').toString();
      if (status == 'completed' || status == 'missed' || status == 'expired') {
        throw StateError('Task already closed');
      }

      final base = ((m['coinsAwarded'] ?? 0) as num).toInt();
      final bonus = (m['bonusReason'] == 'carry_over_double') ? base : 0;
      final total = base + bonus;
      instanceTitle = (m['title'] ?? '') as String;
      coinsTotal = total;
      groupId = m['groupId'] as String?;

      // Skill-XP proportioneel met de uitgekeerde coins (subtaken variëren in omvang).
      final skillIdx = m['skillTypeIndex'] as int?;
      final xp = (total * kXpPerCoin).round();

      tx.set(
          ref,
          {
            'status': 'completed',
            'completedByUserId': userId,
            'completedAt': FieldValue.serverTimestamp(),
            'claimedByUserId': userId,
            'updatedAt': FieldValue.serverTimestamp(),
            'coinsAwarded': total,
          },
          SetOptions(merge: true));

      tx.set(
          userRef,
          {
            'coins': FieldValue.increment(total),
            'weeklyPoints': FieldValue.increment(total),
            if (skillIdx != null && xp > 0) 'skillXp.$skillIdx': FieldValue.increment(xp),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    await _logEvent(
      guildId: guildId,
      actorUserId: userId,
      type: 'completed',
      instanceId: instanceId,
      payload: {'title': instanceTitle, 'coins': coinsTotal},
    );

    // Coöp-quest afgerond? Keer dan de gezamenlijke bonus uit.
    final gid = groupId;
    if (gid != null && gid.isNotEmpty) {
      await _maybeAwardGroupBonus(guildId: guildId, groupId: gid);
    }
  }

  /// Keert de gezamenlijke bonus uit zodra alle (huidige) instances van een groep
  /// voltooid zijn. Idempotent via `bonusPaidForGroups` op het user-doc.
  Future<void> _maybeAwardGroupBonus({
    required String guildId,
    required String groupId,
  }) async {
    final instSnap = await _instances(guildId).where('groupId', isEqualTo: groupId).get();
    if (instSnap.docs.isEmpty) return;

    // Alleen niet-gemiste/verlopen instances tellen mee voor "klaar".
    final relevant = instSnap.docs.where((d) {
      final s = (d.data()['status'] ?? 'open').toString();
      return s != 'missed' && s != 'expired';
    }).toList();
    if (relevant.isEmpty) return;
    final allDone = relevant.every((d) => (d.data()['status'] ?? '') == 'completed');
    if (!allDone) return;

    final groupSnap = await _groups(guildId).doc(groupId).get();
    final bonus = ((groupSnap.data()?['bonusCoins'] ?? 0) as num).toInt();
    final title = (groupSnap.data()?['title'] ?? '') as String;

    final members = await _db.collection('users').where('guildId', isEqualTo: guildId).get();
    final periodKey = '${groupId}_${relevant.length}'; // wisselt als de groep groeit/krimpt

    for (final mdoc in members.docs) {
      final paid = List<String>.from(mdoc.data()['bonusPaidForGroups'] ?? const []);
      if (paid.contains(periodKey)) continue;
      await mdoc.reference.set({
        if (bonus > 0) 'coins': FieldValue.increment(bonus),
        if (bonus > 0) 'weeklyPoints': FieldValue.increment(bonus),
        'bonusPaidForGroups': FieldValue.arrayUnion([periodKey]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _logEvent(
      guildId: guildId,
      actorUserId: 'system',
      type: 'group_completed',
      payload: {'title': title, 'coins': bonus},
    );
  }

  Future<void> removeOpenInstancesForTemplate({
    required String guildId,
    required String templateId,
  }) async {
    final q = await _instances(guildId)
        .where('templateId', isEqualTo: templateId)
        .where('status', whereIn: ['open', 'claimed'])
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> syncTemplateToOpenInstances({
    required String guildId,
    required String templateId,
    required String newTitle,
    required int newCoins,
  }) async {
    final q = await _instances(guildId)
        .where('templateId', isEqualTo: templateId)
        .where('status', whereIn: ['open', 'claimed'])
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.set(doc.reference, {
        'title': newTitle,
        'coinsAwarded': newCoins,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> claimAllFutureInstances({
    required String guildId,
    required String templateId,
    required String userId,
  }) async {
    final n = DateTime.now();
    final todayStart = Timestamp.fromDate(DateTime(n.year, n.month, n.day));
    final q = await _instances(guildId)
        .where('templateId', isEqualTo: templateId)
        .where('scheduledFor', isGreaterThanOrEqualTo: todayStart)
        .where('status', whereIn: ['open', 'claimed'])
        .get();

    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.set(doc.reference, {
        'status': 'claimed',
        'claimedByUserId': userId,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    final tmplSnap = await _templates(guildId).doc(templateId).get();
    final tmplTitle = (tmplSnap.data()?['title'] ?? '') as String;
    await _logEvent(
      guildId: guildId,
      actorUserId: userId,
      type: 'claimed_all_future',
      templateId: templateId,
      payload: {'title': tmplTitle},
    );
  }

  Future<void> unclaimAllFutureInstances({
    required String guildId,
    required String templateId,
    required String userId,
  }) async {
    final n = DateTime.now();
    final todayStart = Timestamp.fromDate(DateTime(n.year, n.month, n.day));
    final q = await _instances(guildId)
        .where('templateId', isEqualTo: templateId)
        .where('scheduledFor', isGreaterThanOrEqualTo: todayStart)
        .where('claimedByUserId', isEqualTo: userId)
        .where('status', whereIn: ['open', 'claimed'])
        .get();

    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.set(doc.reference, {
        'status': 'open',
        'claimedByUserId': null,
        'claimedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    final tmplSnap = await _templates(guildId).doc(templateId).get();
    final tmplTitle = (tmplSnap.data()?['title'] ?? '') as String;
    await _logEvent(
      guildId: guildId,
      actorUserId: userId,
      type: 'unclaimed_all_future',
      templateId: templateId,
      payload: {'title': tmplTitle},
    );
  }

  Future<void> logShopPurchase({
    required String guildId,
    required String actorUserId,
    required String itemName,
    required int price,
  }) async {
    await _logEvent(
      guildId: guildId,
      actorUserId: actorUserId,
      type: 'purchased_item',
      payload: {'title': itemName, 'coins': price},
    );
  }

  Future<void> _logEvent({
    required String guildId,
    required String actorUserId,
    required String type,
    String? templateId,
    String? instanceId,
    Map<String, dynamic> payload = const {},
  }) async {
    await _events(guildId).add({
      'type': type,
      'templateId': templateId,
      'instanceId': instanceId,
      'actorUserId': actorUserId,
      'at': FieldValue.serverTimestamp(),
      'payload': payload,
    });
  }

  DateTime _defaultDueAt(TaskTemplate t, DateTime scheduled) {
    return DateTime(scheduled.year, scheduled.month, scheduled.day, t.dueHour, 0);
  }

  List<DateTime> _generateDates(TaskTemplate t, DateTime from, DateTime to) {
    final out = <DateTime>[];
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);

    if (t.scheduleType == TaskScheduleType.daily) {
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        out.add(d);
      }
      return out;
    }

    if (t.scheduleType == TaskScheduleType.everyXDays) {
      final step = t.intervalValue <= 0 ? 1 : t.intervalValue;
      for (var d = start; !d.isAfter(end); d = d.add(Duration(days: step))) {
        out.add(d);
      }
      return out;
    }

    if (t.scheduleType == TaskScheduleType.weekly) {
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 7))) {
        out.add(d);
      }
      return out;
    }

    if (t.scheduleType == TaskScheduleType.monthly) {
      var d = DateTime(start.year, start.month, 1);
      while (!d.isAfter(end)) {
        out.add(d);
        d = DateTime(d.year, d.month + 1, 1);
      }
      return out;
    }

    // custom (one-time): gebruik scheduledDate indien aanwezig, anders start
    if (t.scheduledDate != null) {
      final d = t.scheduledDate!;
      out.add(DateTime(d.year, d.month, d.day));
    } else {
      out.add(start);
    }
    return out;
  }
}
