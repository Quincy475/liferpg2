import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/data/models/models.dart';

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

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

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
