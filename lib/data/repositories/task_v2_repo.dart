import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/task_event.dart';
import 'package:household_rpg/data/models/task_instance.dart';
import 'package:household_rpg/data/models/task_template.dart';

class TaskV2Repository {
  final FirebaseFirestore _db;
  TaskV2Repository(this._db);

  CollectionReference<Map<String, dynamic>> _templatesCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskTemplates');

  CollectionReference<Map<String, dynamic>> _instancesCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskInstances');

  CollectionReference<Map<String, dynamic>> _eventsCol(String guildId) =>
      _db.collection('guilds').doc(guildId).collection('taskEvents');

  DocumentReference<Map<String, dynamic>> _userRef(String userId) => _db.collection('users').doc(userId);

  Stream<List<TaskTemplate>> watchTemplates(String guildId) {
    return _templatesCol(guildId)
        .where('active', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaskTemplate.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<TaskInstance>> watchInstancesInRange({
    required String guildId,
    required DateTime start,
    required DateTime end,
  }) {
    return _instancesCol(guildId)
        .where('scheduledFor', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledFor', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('scheduledFor')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TaskInstance.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<TaskEvent>> watchRecentEvents(String guildId, {int limit = 80}) {
    return _eventsCol(guildId)
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TaskEvent.fromDoc).toList());
  }

  Future<void> upsertTemplate({required String guildId, required TaskTemplate template}) async {
    final doc = template.id.isEmpty ? _templatesCol(guildId).doc() : _templatesCol(guildId).doc(template.id);
    await doc.set({
      ...template.copyWith(id: doc.id).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _eventsCol(guildId).add({
      'type': 'created_template',
      'templateId': doc.id,
      'instanceId': '',
      'actorUserId': template.defaultAssigneeUserId ?? 'system',
      'at': FieldValue.serverTimestamp(),
      'payload': {'title': template.title},
    });
  }

  Future<void> archiveTemplate({required String guildId, required String templateId}) async {
    await _templatesCol(guildId).doc(templateId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureInstancesHorizon({
    required String guildId,
    required DateTime from,
    int horizonDays = 7,
  }) async {
    final templatesSnap = await _templatesCol(guildId).where('active', isEqualTo: true).get();
    final until = from.add(Duration(days: horizonDays));

    for (final doc in templatesSnap.docs) {
      final template = TaskTemplate.fromMap({...doc.data(), 'id': doc.id});
      if (!template.isRepeatable) continue;

      for (final date in _generateSlots(template, from, until)) {
        final key = '${template.id}_${date.toUtc().toIso8601String()}';
        final instanceRef = _instancesCol(guildId).doc(key);
        final existing = await instanceRef.get();
        if (existing.exists) continue;

        final dueAt = _calculateDueAt(template, date);
        final takeoverAt = dueAt.add(Duration(minutes: template.takeoverAfterMinutes));

        await instanceRef.set({
          'id': key,
          'templateId': template.id,
          'title': template.title,
          'description': template.description,
          'scheduledFor': Timestamp.fromDate(date),
          'dueAt': Timestamp.fromDate(dueAt),
          'takeoverAllowedAt': Timestamp.fromDate(takeoverAt),
          'status': TaskInstanceStatus.open.name,
          'coinsAwarded': template.coinsBase,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
      }
    }
  }

  Future<void> markMissedAndApplyCarryover({
    required String guildId,
    required DateTime now,
  }) async {
    final overdue = await _instancesCol(guildId)
        .where('status', whereIn: [TaskInstanceStatus.open.name, TaskInstanceStatus.claimed.name])
        .where('takeoverAllowedAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (final doc in overdue.docs) {
      final instance = TaskInstance.fromMap({...doc.data(), 'id': doc.id});
      await doc.reference.update({
        'status': TaskInstanceStatus.missed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _eventsCol(guildId).add({
        'type': 'missed',
        'templateId': instance.templateId,
        'instanceId': instance.id,
        'actorUserId': instance.claimedByUserId ?? 'system',
        'at': FieldValue.serverTimestamp(),
        'payload': {'title': instance.title},
      });

      final templateSnap = await _templatesCol(guildId).doc(instance.templateId).get();
      if (!templateSnap.exists) continue;
      final template = TaskTemplate.fromMap({...templateSnap.data()!, 'id': templateSnap.id});
      if (template.carryOverPolicy != CarryOverPolicy.doubleNextSuccess) continue;

      final nextSnap = await _instancesCol(guildId)
          .where('templateId', isEqualTo: instance.templateId)
          .where('scheduledFor', isGreaterThan: Timestamp.fromDate(instance.scheduledFor))
          .orderBy('scheduledFor')
          .limit(1)
          .get();
      if (nextSnap.docs.isEmpty) continue;
      await nextSnap.docs.first.reference.set({
        'bonusReason': 'carryover_from_${instance.id}',
      }, SetOptions(merge: true));
    }
  }

  Future<void> claimInstance({
    required String guildId,
    required String instanceId,
    required String userId,
  }) async {
    final ref = _instancesCol(guildId).doc(instanceId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Task instance not found');

      final data = snap.data()!;
      final status = (data['status'] ?? TaskInstanceStatus.open.name).toString();
      final claimedBy = data['claimedByUserId']?.toString();

      if (status == TaskInstanceStatus.completed.name) {
        throw StateError('Task already completed');
      }

      if (claimedBy != null && claimedBy.isNotEmpty && claimedBy != userId) {
        throw StateError('Task already claimed by another member');
      }

      tx.update(ref, {
        'status': TaskInstanceStatus.claimed.name,
        'claimedByUserId': userId,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(_eventsCol(guildId).doc(), {
        'type': 'claimed',
        'templateId': (data['templateId'] ?? '').toString(),
        'instanceId': instanceId,
        'actorUserId': userId,
        'at': FieldValue.serverTimestamp(),
        'payload': {'title': (data['title'] ?? '').toString()},
      });
    });
  }

  Future<void> completeInstance({
    required String guildId,
    required String instanceId,
    required String userId,
  }) async {
    final instanceRef = _instancesCol(guildId).doc(instanceId);
    final userRef = _userRef(userId);

    await _db.runTransaction((tx) async {
      final instanceSnap = await tx.get(instanceRef);
      if (!instanceSnap.exists) throw StateError('Task instance not found');
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw StateError('User not found');

      final data = instanceSnap.data()!;
      final status = (data['status'] ?? TaskInstanceStatus.open.name).toString();
      if (status == TaskInstanceStatus.completed.name) {
        throw StateError('Task already completed');
      }

      final claimedBy = data['claimedByUserId']?.toString();
      if (claimedBy != null && claimedBy.isNotEmpty && claimedBy != userId) {
        throw StateError('Task claimed by another member');
      }

      final baseCoins = (data['coinsAwarded'] as num?)?.toInt() ?? 0;
      final fallbackBase = 10;
      final withFallback = baseCoins > 0 ? baseCoins : fallbackBase;
      final bonusReason = data['bonusReason']?.toString();
      final awarded = bonusReason != null && bonusReason.isNotEmpty ? withFallback * 2 : withFallback;

      tx.update(instanceRef, {
        'status': TaskInstanceStatus.completed.name,
        'claimedByUserId': userId,
        'completedByUserId': userId,
        'completedAt': FieldValue.serverTimestamp(),
        'coinsAwarded': awarded,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        'coins': FieldValue.increment(awarded),
        'weeklyPoints': FieldValue.increment(awarded),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(_eventsCol(guildId).doc(), {
        'type': 'completed',
        'templateId': (data['templateId'] ?? '').toString(),
        'instanceId': instanceId,
        'actorUserId': userId,
        'at': FieldValue.serverTimestamp(),
        'payload': {
          'title': (data['title'] ?? '').toString(),
          'coinsAwarded': awarded,
          if (bonusReason != null) 'bonusReason': bonusReason,
        },
      });
    });
  }

  List<DateTime> _generateSlots(TaskTemplate template, DateTime from, DateTime until) {
    final out = <DateTime>[];
    var cursor = DateTime(from.year, from.month, from.day, 8);

    while (!cursor.isAfter(until)) {
      switch (template.scheduleType) {
        case TaskScheduleType.daily:
          out.add(cursor);
          cursor = cursor.add(Duration(days: template.intervalValue.clamp(1, 365)));
          break;
        case TaskScheduleType.everyXDays:
          out.add(cursor);
          cursor = cursor.add(Duration(days: template.intervalValue.clamp(1, 365)));
          break;
        case TaskScheduleType.weekly:
          out.add(cursor);
          cursor = cursor.add(Duration(days: 7 * template.intervalValue.clamp(1, 52)));
          break;
        case TaskScheduleType.monthly:
          out.add(cursor);
          cursor = DateTime(cursor.year, cursor.month + template.intervalValue.clamp(1, 12), cursor.day, 8);
          break;
        case TaskScheduleType.custom:
          out.add(cursor);
          cursor = cursor.add(const Duration(days: 1));
          break;
      }
    }

    return out;
  }

  DateTime _calculateDueAt(TaskTemplate template, DateTime scheduledFor) {
    switch (template.scheduleType) {
      case TaskScheduleType.daily:
      case TaskScheduleType.everyXDays:
      case TaskScheduleType.custom:
        return DateTime(scheduledFor.year, scheduledFor.month, scheduledFor.day, 21, 0);
      case TaskScheduleType.weekly:
        return scheduledFor.add(const Duration(days: 6, hours: 12));
      case TaskScheduleType.monthly:
        return DateTime(scheduledFor.year, scheduledFor.month + 1, scheduledFor.day, 12);
    }
  }
}
