import 'package:cloud_firestore/cloud_firestore.dart';

class UserFurniture {
  final String id;
  final bool owned;
  final bool equipped;
  final DateTime? acquiredAt;

  UserFurniture({
    required this.id,
    required this.owned,
    required this.equipped,
    this.acquiredAt,
  });

  factory UserFurniture.fromJson(String id, Map<String, dynamic> json) {
    return UserFurniture(
      id: id,
      owned: (json['owned'] ?? false) as bool,
      equipped: (json['equipped'] ?? false) as bool,
      acquiredAt: (json['acquiredAt'] as Timestamp?)?.toDate(),
    );
  }
  factory UserFurniture.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return UserFurniture(
      id: doc.id,
      owned: data['owned'] == true,
      equipped: data['equipped'] == true,
      acquiredAt: (data['acquiredAt'] as Timestamp?)?.toDate(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owned': owned,
      'equipped': equipped,
      if (acquiredAt != null) 'acquiredAt': Timestamp.fromDate(acquiredAt!),
    };
  }
}