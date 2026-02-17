import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskInstanceStatus { open, claimed, completed, missed, expired }

class TaskInstance {
  final String id;
  final String templateId;
  final String title;
  final String description;
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

  const TaskInstance({
    required this.id,
    required this.templateId,
    required this.title,
    required this.description,
    required this.scheduledFor,
    required this.dueAt,
    required this.takeoverAllowedAt,
    this.status = TaskInstanceStatus.open,
    this.claimedByUserId,
    this.claimedAt,
    this.completedByUserId,
    this.completedAt,
    this.coinsAwarded = 0,
    this.bonusReason,
  });

  bool get isOverdue => DateTime.now().isAfter(dueAt) && status != TaskInstanceStatus.completed;

  Map<String, dynamic> toMap() => {
        'id': id,
        'templateId': templateId,
        'title': title,
        'description': description,
        'scheduledFor': Timestamp.fromDate(scheduledFor),
        'dueAt': Timestamp.fromDate(dueAt),
        'takeoverAllowedAt': Timestamp.fromDate(takeoverAllowedAt),
        'status': status.name,
        'claimedByUserId': claimedByUserId,
        'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
        'completedByUserId': completedByUserId,
        'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'coinsAwarded': coinsAwarded,
        'bonusReason': bonusReason,
      };

  static TaskInstance fromMap(Map<String, dynamic> map) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    DateTime? readNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final statusString = (map['status'] ?? 'open').toString();
    final status = TaskInstanceStatus.values.firstWhere(
      (s) => s.name == statusString,
      orElse: () => TaskInstanceStatus.open,
    );

    return TaskInstance(
      id: (map['id'] ?? '').toString(),
      templateId: (map['templateId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      scheduledFor: readDate(map['scheduledFor']),
      dueAt: readDate(map['dueAt']),
      takeoverAllowedAt: readDate(map['takeoverAllowedAt']),
      status: status,
      claimedByUserId: map['claimedByUserId']?.toString(),
      claimedAt: readNullableDate(map['claimedAt']),
      completedByUserId: map['completedByUserId']?.toString(),
      completedAt: readNullableDate(map['completedAt']),
      coinsAwarded: (map['coinsAwarded'] as num?)?.toInt() ?? 0,
      bonusReason: map['bonusReason']?.toString(),
    );
  }
}
