import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/enums.dart';

enum TaskScheduleType { daily, weekly, monthly, everyXDays, custom }

enum TaskInstanceStatus { open, claimed, completed, missed, expired }

class TaskTemplate {
  final String id;
  final String title;
  final String description;
  final int coinsBase;
  final bool isRepeatable;
  final TaskScheduleType scheduleType;
  final int intervalValue;
  final String? defaultAssigneeUserId;
  final List<String> claimableByUserIds;
  final int takeoverAfterMinutes;
  final String carryOverPolicy;
  final bool active;
  final int dueHour;
  final DateTime? scheduledDate;
  final SkillType? skillType;

  /// Coöp-quest groepering: taken met dezelfde groupId horen bij één grote klus.
  final String? groupId;

  const TaskTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.coinsBase,
    required this.isRepeatable,
    required this.scheduleType,
    required this.intervalValue,
    this.defaultAssigneeUserId,
    this.claimableByUserIds = const [],
    this.takeoverAfterMinutes = 0,
    this.carryOverPolicy = 'none',
    this.active = true,
    this.dueHour = 22,
    this.scheduledDate,
    this.skillType,
    this.groupId,
  });

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static TaskTemplate fromMap(String id, Map<String, dynamic> m) {
    final scheduleRaw = m['scheduleType']?.toString() ?? 'daily';
    final schedule = TaskScheduleType.values.firstWhere(
      (e) => e.name == scheduleRaw,
      orElse: () => TaskScheduleType.daily,
    );

    final skillIdx = m['skillTypeIndex'] as int?;
    final skillType = (skillIdx != null && skillIdx >= 0 && skillIdx < SkillType.values.length)
        ? SkillType.values[skillIdx]
        : null;

    return TaskTemplate(
      id: id,
      title: (m['title'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      coinsBase: ((m['coinsBase'] ?? 0) as num).toInt(),
      isRepeatable: (m['isRepeatable'] ?? true) as bool,
      scheduleType: schedule,
      intervalValue: ((m['intervalValue'] ?? 1) as num).toInt(),
      defaultAssigneeUserId: m['defaultAssigneeUserId'] as String?,
      claimableByUserIds: List<String>.from(m['claimableByUserIds'] ?? const []),
      takeoverAfterMinutes: ((m['takeoverAfterMinutes'] ?? 0) as num).toInt(),
      carryOverPolicy: (m['carryOverPolicy'] ?? 'none') as String,
      active: (m['active'] ?? true) as bool,
      dueHour: ((m['dueHour'] ?? 22) as num).toInt(),
      scheduledDate: _dt(m['scheduledDate']),
      skillType: skillType,
      groupId: m['groupId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'coinsBase': coinsBase,
        'isRepeatable': isRepeatable,
        'scheduleType': scheduleType.name,
        'intervalValue': intervalValue,
        'defaultAssigneeUserId': defaultAssigneeUserId,
        'claimableByUserIds': claimableByUserIds,
        'takeoverAfterMinutes': takeoverAfterMinutes,
        'carryOverPolicy': carryOverPolicy,
        'active': active,
        'dueHour': dueHour,
        'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
        'skillTypeIndex': skillType?.index,
        'groupId': groupId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class TaskInstance {
  final String id;
  final String templateId;
  final DateTime scheduledFor;
  final DateTime dueAt;
  final DateTime takeoverAllowedAt;
  final TaskInstanceStatus status;
  final String? claimedByUserId;
  final DateTime? claimedAt;
  final String? completedByUserId;
  final DateTime? completedAt;
  final int coinsAwarded;
  final String? bonusReason;
  final String title;
  final String description;
  final String? groupId;

  const TaskInstance({
    required this.id,
    required this.templateId,
    required this.scheduledFor,
    required this.dueAt,
    required this.takeoverAllowedAt,
    required this.status,
    required this.coinsAwarded,
    required this.title,
    required this.description,
    this.claimedByUserId,
    this.claimedAt,
    this.completedByUserId,
    this.completedAt,
    this.bonusReason,
    this.groupId,
  });

  static DateTime _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static TaskInstance fromMap(String id, Map<String, dynamic> m) {
    final statusRaw = m['status']?.toString() ?? 'open';
    final status = TaskInstanceStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => TaskInstanceStatus.open,
    );

    return TaskInstance(
      id: id,
      templateId: (m['templateId'] ?? '') as String,
      scheduledFor: _dt(m['scheduledFor']),
      dueAt: _dt(m['dueAt']),
      takeoverAllowedAt: _dt(m['takeoverAllowedAt']),
      status: status,
      claimedByUserId: m['claimedByUserId'] as String?,
      claimedAt: m['claimedAt'] != null ? _dt(m['claimedAt']) : null,
      completedByUserId: m['completedByUserId'] as String?,
      completedAt: m['completedAt'] != null ? _dt(m['completedAt']) : null,
      coinsAwarded: ((m['coinsAwarded'] ?? 0) as num).toInt(),
      bonusReason: m['bonusReason'] as String?,
      title: (m['title'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      groupId: m['groupId'] as String?,
    );
  }
}

class TaskEvent {
  final String id;
  final String type;
  final String? templateId;
  final String? instanceId;
  final String actorUserId;
  final DateTime at;
  final Map<String, dynamic> payload;

  const TaskEvent({
    required this.id,
    required this.type,
    required this.actorUserId,
    required this.at,
    required this.payload,
    this.templateId,
    this.instanceId,
  });

  static DateTime _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  static TaskEvent fromMap(String id, Map<String, dynamic> m) {
    return TaskEvent(
      id: id,
      type: (m['type'] ?? '') as String,
      templateId: m['templateId'] as String?,
      instanceId: m['instanceId'] as String?,
      actorUserId: (m['actorUserId'] ?? '') as String,
      at: _dt(m['at']),
      payload: Map<String, dynamic>.from(m['payload'] ?? const {}),
    );
  }
}

/// Een coöp-quest: een grote klus (bv. "Huis vegen") die uit meerdere subtaken
/// (TaskTemplates met dezelfde groupId) bestaat.
class TaskGroup {
  final String id;
  final String title;
  final String description;
  final SkillType? skillType;
  final int bonusCoins;

  const TaskGroup({
    required this.id,
    required this.title,
    this.description = '',
    this.skillType,
    this.bonusCoins = 0,
  });

  static TaskGroup fromMap(String id, Map<String, dynamic> m) {
    final skillIdx = m['skillTypeIndex'] as int?;
    final skillType = (skillIdx != null && skillIdx >= 0 && skillIdx < SkillType.values.length)
        ? SkillType.values[skillIdx]
        : null;
    return TaskGroup(
      id: id,
      title: (m['title'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      skillType: skillType,
      bonusCoins: ((m['bonusCoins'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'skillTypeIndex': skillType?.index,
        'bonusCoins': bonusCoins,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}