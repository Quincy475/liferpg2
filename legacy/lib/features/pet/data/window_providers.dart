// lib/features/pet/data/window_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserWindow {
  final String id;
  final bool owned;
  final bool equipped;

  UserWindow({required this.id, required this.owned, required this.equipped});

  factory UserWindow.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserWindow(
      id: doc.id,
      owned: data['owned'] == true,
      equipped: data['equipped'] == true,
    );
  }
}

final userWindowsProvider = StreamProvider.family<List<UserWindow>, String>((ref, uid) {
  final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('windows');
  return col.snapshots().map((s) => s.docs.map(UserWindow.fromDoc).toList());
});
