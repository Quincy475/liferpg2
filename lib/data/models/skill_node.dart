import 'package:cloud_firestore/cloud_firestore.dart';

class SkillNode {
  final String id;
  final String skill; // "cooking", "cleaning", ...
  final String title;
  final String? description;
  final String? icon;
  final String type; // "passive" | "active" | "gate"
  final int tier;
  final int cost;
  final int maxRank;
  final List<String> prereq;
  final String? mutualExclusionGroup;
  final List<Map<String, dynamic>> effects; // e.g. [{kind, op, value, scope, cap, perRankScale}]
  final Map<String, dynamic>? uiHints;
  final int schemaVersion;

  SkillNode({
    required this.id,
    required this.skill,
    required this.title,
    required this.type,
    required this.tier,
    required this.cost,
    required this.maxRank,
    required this.prereq,
    required this.effects,
    this.description,
    this.icon,
    this.mutualExclusionGroup,
    this.uiHints,
    this.schemaVersion = 1,
  });

  /// Robuuste parser voor Firestore snapshots (werkt voor zowel DocumentSnapshot als QueryDocumentSnapshot)
  factory SkillNode.fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final raw = snap.data() ?? const <String, dynamic>{};
    return SkillNode.fromMap(snap.id, raw);
  }

  /// Losse map-parser (handig voor tests of withConverter)
  factory SkillNode.fromMap(String fallbackId, Map<String, dynamic> m) {
    // Strings
    final id = (m['id'] ?? fallbackId).toString();
    final skill = (m['skill'] ?? '').toString();
    final title = (m['title'] ?? '').toString();
    final description = (m['description'] is String) ? m['description'] as String : null;
    final icon = (m['icon'] is String) ? m['icon'] as String : null;
    final type = (m['type'] ?? 'passive').toString();

    // Ints (forceer naar int waar mogelijk)
    int _asInt(dynamic v, {int def = 0}) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? def;
      return def;
    }

    final tier = _asInt(m['tier'], def: 1);
    final cost = _asInt(m['cost'], def: 1);
    final maxRank = _asInt(m['maxRank'], def: 1);
    final schemaVersion = _asInt(m['schemaVersion'], def: 1);

    // Lists
    final prereq = List<String>.from(m['prereq'] ?? const <String>[]);
    final mutualExclusionGroup = (m['mutualExclusionGroup'] is String) ? m['mutualExclusionGroup'] as String : null;

    // effects: List<Map<String,dynamic>>
    final effectsRaw = m['effects'];
    final effects = (effectsRaw is List)
        ? effectsRaw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    // uiHints: Map<String,dynamic>
    final uiHints = (m['uiHints'] is Map<String, dynamic>) ? Map<String, dynamic>.from(m['uiHints']) : null;

    return SkillNode(
      id: id,
      skill: skill,
      title: title,
      description: description,
      icon: icon,
      type: type,
      tier: tier,
      cost: cost,
      maxRank: maxRank,
      prereq: prereq,
      mutualExclusionGroup: mutualExclusionGroup,
      effects: effects,
      uiHints: uiHints,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'skill': skill,
        'title': title,
        'description': description,
        'icon': icon,
        'type': type,
        'tier': tier,
        'cost': cost,
        'maxRank': maxRank,
        'prereq': prereq,
        'mutualExclusionGroup': mutualExclusionGroup,
        'effects': effects,
        'uiHints': uiHints,
        'schemaVersion': schemaVersion,
      };
}
