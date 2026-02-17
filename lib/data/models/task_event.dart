import 'package:cloud_firestore/cloud_firestore.dart';

class TaskEvent {
  final String id;
  final String type;
  final String templateId;
  final String instanceId;
  final String actorUserId;
  final DateTime at;
  final Map<String, dynamic> payload;

  const TaskEvent({
    required this.id,
    required this.type,
    required this.templateId,
    required this.instanceId,
    required this.actorUserId,
    required this.at,
    this.payload = const {},
  });

  static TaskEvent fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawAt = data['at'];
    final date = rawAt is Timestamp
        ? rawAt.toDate()
        : DateTime.tryParse(rawAt?.toString() ?? '') ?? DateTime.now();

    return TaskEvent(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      templateId: (data['templateId'] ?? '').toString(),
      instanceId: (data['instanceId'] ?? '').toString(),
      actorUserId: (data['actorUserId'] ?? '').toString(),
      at: date,
      payload: Map<String, dynamic>.from(data['payload'] ?? const <String, dynamic>{}),
    );
  }
}
