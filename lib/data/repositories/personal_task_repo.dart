import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/models.dart';

/// Beheert persoonlijke taken per gebruiker.
/// Opgeslagen onder users/{uid}/personalTaskTemplates/ en personalTaskInstances/.
/// Volledig privé — geen guild-zichtbaarheid.
class PersonalTaskRepository {
  final FirebaseFirestore _db;
  const PersonalTaskRepository(this._db);

  CollectionReference<Map<String, dynamic>> _templates(String uid) =>
      _db.collection('users').doc(uid).collection('personalTaskTemplates');

  CollectionReference<Map<String, dynamic>> _instances(String uid) =>
      _db.collection('users').doc(uid).collection('personalTaskInstances');

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  // ---- Templates ----------------------------------------------------------

  Stream<List<TaskTemplate>> watchTemplates(String uid) {
    return _templates(uid)
        .where('active', isEqualTo: true)
        .orderBy('title')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskTemplate.fromMap(d.id, d.data())).toList());
  }

  Future<void> createTemplate({required String uid, required TaskTemplate input}) async {
    final ref = _templates(uid).doc();
    await ref.set({
      ...input.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTemplate({required String uid, required TaskTemplate input}) async {
    await _templates(uid).doc(input.id).set(input.toMap(), SetOptions(merge: true));
  }

  Future<void> archiveTemplate({required String uid, required String templateId}) async {
    await _templates(uid).doc(templateId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Instances ----------------------------------------------------------

  Stream<List<TaskInstance>> watchWeekInstances({
    required String uid,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    final start = Timestamp.fromDate(weekStart);
    final end = Timestamp.fromDate(weekEnd);
    return _instances(uid)
        .where('scheduledFor', isGreaterThanOrEqualTo: start)
        .where('scheduledFor', isLessThanOrEqualTo: end)
        .orderBy('scheduledFor')
        .snapshots()
        .map((s) => s.docs.map((d) => TaskInstance.fromMap(d.id, d.data())).toList());
  }

  /// Genereert instanties voor de opgegeven periode op basis van actieve templates.
  /// Persoonlijke instanties worden direct op de user geclaimd.
  Future<void> ensureUpcomingInstances({
    required String uid,
    required DateTime from,
    required DateTime to,
  }) async {
    final templates = await _templates(uid).where('active', isEqualTo: true).get();
    final batch = _db.batch();

    for (final doc in templates.docs) {
      final t = TaskTemplate.fromMap(doc.id, doc.data());
      final generated = _generateDates(t, from, to);

      for (final scheduled in generated) {
        final instanceId = '${doc.id}_${scheduled.toUtc().toIso8601String()}';
        final iref = _instances(uid).doc(instanceId);
        final exists = await iref.get();
        if (exists.exists) continue;

        final dueAt = DateTime(scheduled.year, scheduled.month, scheduled.day, t.dueHour, 0);

        batch.set(iref, {
          'templateId': doc.id,
          'scheduledFor': Timestamp.fromDate(scheduled),
          'dueAt': Timestamp.fromDate(dueAt),
          'takeoverAllowedAt': Timestamp.fromDate(dueAt.add(const Duration(hours: 1))),
          'status': 'claimed', // persoonlijke taken zijn altijd voor jezelf
          'claimedByUserId': uid,
          'claimedAt': FieldValue.serverTimestamp(),
          'completedByUserId': null,
          'completedAt': null,
          'coinsAwarded': t.coinsBase,
          'bonusReason': null,
          'title': t.title,
          'description': t.description,
          'skillTypeIndex': t.skillType?.index,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  /// Voltooi een persoonlijke taakinstantie.
  /// Schrijft soloCoins en skillXp naar het gebruikersprofiel.
  Future<void> completeInstance({
    required String uid,
    required String instanceId,
  }) async {
    final ref = _instances(uid).doc(instanceId);
    final userRef = _userRef(uid);

    await _db.runTransaction((tx) async {
      final instanceSnap = await tx.get(ref);
      final userSnap = await tx.get(userRef);

      if (!instanceSnap.exists) throw StateError('Taakinstantie niet gevonden');
      final m = instanceSnap.data()!;
      final status = (m['status'] ?? 'open').toString();
      if (status == 'completed') throw StateError('Taak al voltooid');

      final total = ((m['coinsAwarded'] ?? 0) as num).toInt();
      final skillIdx = m['skillTypeIndex'] as int?;

      // Update instantie
      tx.set(ref, {
        'status': 'completed',
        'completedByUserId': uid,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update skillXp map (lees huidige waarden uit transactie)
      final userData = Map<String, dynamic>.from(userSnap.data() ?? {});
      final fsXpMap = Map<String, dynamic>.from(userData['skillXp'] ?? {});

      // Zorg dat alle skills aanwezig zijn
      for (final s in SkillType.values) {
        fsXpMap.putIfAbsent(s.index.toString(), () => 0);
      }

      if (skillIdx != null && skillIdx >= 0 && skillIdx < SkillType.values.length) {
        final key = skillIdx.toString();
        final cur = (fsXpMap[key] ?? 0) as int;
        fsXpMap[key] = cur + total;
      }

      // Schrijf soloCoins + bijgewerkte skillXp map
      tx.set(userRef, {
        'soloCoins': FieldValue.increment(total),
        'skillXp': fsXpMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> removeOpenInstancesForTemplate({
    required String uid,
    required String templateId,
  }) async {
    final q = await _instances(uid)
        .where('templateId', isEqualTo: templateId)
        .where('status', whereIn: ['open', 'claimed'])
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ---- Helpers ------------------------------------------------------------

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

    // custom (eenmalig)
    if (t.scheduledDate != null) {
      final d = t.scheduledDate!;
      out.add(DateTime(d.year, d.month, d.day));
    } else {
      out.add(start);
    }
    return out;
  }
}
