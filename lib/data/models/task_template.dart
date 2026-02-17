import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskScheduleType { daily, weekly, monthly, everyXDays, custom }

enum CarryOverPolicy { none, doubleNextSuccess }

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
  final CarryOverPolicy carryOverPolicy;
  final bool active;

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
    this.carryOverPolicy = CarryOverPolicy.none,
    this.active = true,
  });

  TaskTemplate copyWith({
    String? id,
    String? title,
    String? description,
    int? coinsBase,
    bool? isRepeatable,
    TaskScheduleType? scheduleType,
    int? intervalValue,
    String? defaultAssigneeUserId,
    List<String>? claimableByUserIds,
    int? takeoverAfterMinutes,
    CarryOverPolicy? carryOverPolicy,
    bool? active,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coinsBase: coinsBase ?? this.coinsBase,
      isRepeatable: isRepeatable ?? this.isRepeatable,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalValue: intervalValue ?? this.intervalValue,
      defaultAssigneeUserId: defaultAssigneeUserId ?? this.defaultAssigneeUserId,
      claimableByUserIds: claimableByUserIds ?? this.claimableByUserIds,
      takeoverAfterMinutes: takeoverAfterMinutes ?? this.takeoverAfterMinutes,
      carryOverPolicy: carryOverPolicy ?? this.carryOverPolicy,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'coinsBase': coinsBase,
        'isRepeatable': isRepeatable,
        'scheduleType': scheduleType.name,
        'intervalValue': intervalValue,
        'defaultAssigneeUserId': defaultAssigneeUserId,
        'claimableByUserIds': claimableByUserIds,
        'takeoverAfterMinutes': takeoverAfterMinutes,
        'carryOverPolicy': carryOverPolicy.name,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static TaskTemplate fromMap(Map<String, dynamic> map) {
    TaskScheduleType parseSchedule(dynamic raw) {
      final asString = (raw ?? '').toString();
      return TaskScheduleType.values.firstWhere(
        (e) => e.name == asString,
        orElse: () => TaskScheduleType.daily,
      );
    }

    CarryOverPolicy parseCarry(dynamic raw) {
      final asString = (raw ?? '').toString();
      return CarryOverPolicy.values.firstWhere(
        (e) => e.name == asString,
        orElse: () => CarryOverPolicy.none,
      );
    }

    return TaskTemplate(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coinsBase: (map['coinsBase'] as num?)?.toInt() ?? 0,
      isRepeatable: (map['isRepeatable'] ?? true) == true,
      scheduleType: parseSchedule(map['scheduleType']),
      intervalValue: (map['intervalValue'] as num?)?.toInt() ?? 1,
      defaultAssigneeUserId: map['defaultAssigneeUserId']?.toString(),
      claimableByUserIds: List<String>.from(map['claimableByUserIds'] ?? const <String>[]),
      takeoverAfterMinutes: (map['takeoverAfterMinutes'] as num?)?.toInt() ?? 0,
      carryOverPolicy: parseCarry(map['carryOverPolicy']),
      active: (map['active'] ?? true) == true,
    );
  }
}
