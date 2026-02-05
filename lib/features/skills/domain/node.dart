
// import 'package:equatable/equatable.dart';

// class SkillNode extends Equatable {
//   final String id;
//   final String title;
//   final String type; // 'passive' | 'active' | 'utility'
//   final int tier;    // 1..N
//   final int cost;    // skill point cost, meestal 1
//   final int maxRank; // meestal 1
//   final List<String> prereq; // ids die eerst moeten
//   final String? mutualExclusionGroup; // bv. "pathA"
//   final List<Map<String, dynamic>> effects; // [{"kind":"xp_multiplier","value":0.05}, ...]

//   const SkillNode({
//     required this.id,
//     required this.title,
//     required this.type,
//     required this.tier,
//     required this.cost,
//     required this.maxRank,
//     required this.prereq,
//     required this.effects,
//     this.mutualExclusionGroup,
//   });

//   factory SkillNode.fromMap(String id, Map<String, dynamic> m) {
//     return SkillNode(
//       id: id,
//       title: (m['title'] ?? id) as String,
//       type: (m['type'] ?? 'passive') as String,
//       tier: (m['tier'] ?? 1) as int,
//       cost: (m['cost'] ?? 1) as int,
//       maxRank: (m['maxRank'] ?? 1) as int,
//       prereq: List<String>.from(m['prereq'] ?? const <String>[]),
//       mutualExclusionGroup: m['mutualExclusionGroup'] as String?,
//       effects: List<Map<String, dynamic>>.from(m['effects'] ?? const <Map<String, dynamic>>[]),
//     );
//   }

//   @override
//   List<Object?> get props => [id, title, type, tier, cost, maxRank, prereq, effects, mutualExclusionGroup];
// }
