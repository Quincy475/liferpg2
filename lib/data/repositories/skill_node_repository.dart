import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:household_rpg/data/models/enums.dart';
import 'package:household_rpg/data/models/skill_node.dart'; // bevat SkillType

// ---- Repo
class SkillNodeRepository {
  final FirebaseFirestore _db;
  SkillNodeRepository(this._db);
  String _skillKey(SkillType s) => s.name;

  CollectionReference<Map<String, dynamic>> _rawNodesCol({
    required String version,
    required SkillType skill,
  }) {
    final key = _skillKey(skill);
    return _db.collection('skillNodes_$version').doc(key).collection(key);
  }

  Future<bool> _nodeExists({
    required String version,
    required SkillType skill,
    required String nodeId,
  }) async {
    final doc = _rawNodesCol(version: version, skill: skill).doc(nodeId);
    final snap = await doc.get();
    return snap.exists;
  }

  Future<void> _upsertNode({
    required String version,
    required SkillType skill,
    required String nodeId,
    required Map<String, dynamic> payload,
  }) async {
    await _rawNodesCol(version: version, skill: skill)
        .doc(nodeId)
        .set(payload, SetOptions(merge: true));
  }

  Future<String> getCurrentVersion() async {
    // of haal 'm uit configs/skillNodesMeta.currentVersion → 'v1'
    // voor simpelheid:
    return 'v1';
  }

  // // === De coo
  // // Meta version
  // Future<String> getCurrentVersion() async {
  //   final snap = await _db.collection('configs').doc('skillNodesMeta').get();
  //   if (!snap.exists) return 'v1';
  //   final m = snap.data() ?? {};
  //   final cv = (m['currentVersion'] ?? 1) as int;
  //   return 'v$cv';
  // }

  // Path helper: /skillNodes_vX/{skill}
  CollectionReference<Map<String, dynamic>> _nodesCol({
    required String version,
    required SkillType skill,
  }) {
    final s = _skillKey(skill);
    return _db.collection('skillNodes_$version').doc(s).collection(s);
  }

  // WATCH
  Stream<List<SkillNode>> watchNodesForSkill({
    required String version,
    required SkillType skill,
  }) {
    final col = _nodesCol(version: version, skill: skill);
    return col.orderBy('tier').snapshots().map((snap) => snap.docs.map(SkillNode.fromDoc).toList());
    // (Je kunt ook .orderBy('title') toevoegen als secundair)
  }

  // GET once
  Future<List<SkillNode>> getNodesForSkill({
    required String version,
    required SkillType skill,
  }) async {
    final col = _nodesCol(version: version, skill: skill);
    final q = await col.orderBy('tier').get();
    return q.docs.map<SkillNode>((d) => SkillNode.fromDoc(d)).toList();
  }

  // Seeden van voorbeelden (alleen voor admin tooling / dev)
  Future<void> seedExampleNodes() async {
    final version = await getCurrentVersion();
    final skill = SkillType.cooking;
    final List<Map<String, dynamic>> nodes = [
      // plak hier de 10 JSON nodes uit het blok hierboven,
      // of laad ze vanuit een const list buiten de methode
      {
        "id": "cook_knife_1",
        "skill": "cooking",
        "title": "Knife Skills I",
        "description": "Sneller prepwerk, minder frictie.",
        "icon": "🔪",
        "type": "passive",
        "tier": 1,
        "cost": 1,
        "maxRank": 2,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "cooldown_reduce",
            "op": "mul",
            "value": 0.05,
            "cap": 0.20,
            "scope": "task:cooking",
            "perRankScale": 0.05
          }
        ],
        "uiHints": {"badge": "Common", "accentColor": "#7FB77E"},
        "schemaVersion": 1
      },
      {
        "id": "cook_prep_flow",
        "skill": "cooking",
        "title": "Prep Flow",
        "description": "Betere timing geeft +5% XP op cooking taken.",
        "icon": "⏱️",
        "type": "passive",
        "tier": 1,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "xp_multiplier",
            "op": "mul",
            "value": 0.05,
            "cap": 0.10,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Common"},
        "schemaVersion": 1
      },
      {
        "id": "cook_spice_sense",
        "skill": "cooking",
        "title": "Spice Sense",
        "description": "Kleine kans op extra loot bij koken.",
        "icon": "🧂",
        "type": "passive",
        "tier": 1,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "loot_chance_add",
            "op": "add",
            "value": 0.02,
            "cap": 0.06,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Common"},
        "schemaVersion": 1
      },
      {
        "id": "cook_mise_en_place",
        "skill": "cooking",
        "title": "Mise en Place",
        "description": "Beter ritme: +1 streak groei bij cooking taken.",
        "icon": "📦",
        "type": "passive",
        "tier": 1,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {"kind": "streak_boost", "op": "add", "value": 1, "scope": "task:cooking"}
        ],
        "uiHints": {"badge": "Common"},
        "schemaVersion": 1
      },
      {
        "id": "cook_knife_2",
        "skill": "cooking",
        "title": "Knife Skills II",
        "description": "Vervolg: nóg efficiënter snijden.",
        "icon": "🗡️",
        "type": "passive",
        "tier": 2,
        "cost": 1,
        "maxRank": 2,
        "prereq": ["cook_knife_1"],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "cooldown_reduce",
            "op": "mul",
            "value": 0.05,
            "cap": 0.25,
            "scope": "task:cooking",
            "perRankScale": 0.05
          }
        ],
        "uiHints": {"badge": "Uncommon", "accentColor": "#5D9C59"},
        "schemaVersion": 1
      },
      {
        "id": "cook_heat_control",
        "skill": "cooking",
        "title": "Heat Control",
        "description": "Precieze hitte = +7% XP op cooking.",
        "icon": "🔥",
        "type": "passive",
        "tier": 2,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "xp_multiplier",
            "op": "mul",
            "value": 0.07,
            "cap": 0.20,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Uncommon"},
        "schemaVersion": 1
      },
      {
        "id": "cook_batch_cooking",
        "skill": "cooking",
        "title": "Batch Cooking",
        "description": "Slim plannen: +5% coins op cooking.",
        "icon": "🍲",
        "type": "passive",
        "tier": 2,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "coins_multiplier",
            "op": "mul",
            "value": 0.05,
            "cap": 0.15,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Uncommon"},
        "schemaVersion": 1
      },
      {
        "id": "cook_flavor_pairing",
        "skill": "cooking",
        "title": "Flavor Pairing",
        "description": "Beter combineren = iets meer loot-kans.",
        "icon": "🥘",
        "type": "passive",
        "tier": 2,
        "cost": 1,
        "maxRank": 1,
        "prereq": [],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "loot_chance_add",
            "op": "add",
            "value": 0.03,
            "cap": 0.08,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Uncommon"},
        "schemaVersion": 1
      },
      {
        "id": "cook_master_timing",
        "skill": "cooking",
        "title": "Master Timing",
        "description": "Perfecte timing: duidelijke cooldown-reductie (met cap).",
        "icon": "⏳",
        "type": "passive",
        "tier": 3,
        "cost": 2,
        "maxRank": 1,
        "prereq": ["cook_prep_flow", "cook_heat_control"],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "cooldown_reduce",
            "op": "mul",
            "value": 0.12,
            "cap": 0.30,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Rare", "accentColor": "#D6B05F"},
        "schemaVersion": 1
      },
      {
        "id": "cook_chefs_special",
        "skill": "cooking",
        "title": "Chef’s Special",
        "description": "All-round bonus: kleine XP + Coins boost.",
        "icon": "⭐",
        "type": "passive",
        "tier": 3,
        "cost": 2,
        "maxRank": 1,
        "prereq": ["cook_batch_cooking", "cook_flavor_pairing"],
        "mutualExclusionGroup": null,
        "effects": [
          {
            "kind": "xp_multiplier",
            "op": "mul",
            "value": 0.05,
            "cap": 0.15,
            "scope": "task:cooking"
          },
          {
            "kind": "coins_multiplier",
            "op": "mul",
            "value": 0.05,
            "cap": 0.15,
            "scope": "task:cooking"
          }
        ],
        "uiHints": {"badge": "Rare"},
        "schemaVersion": 1
      }
    ];

    for (final n in nodes) {
      final id = (n['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final exists = await _nodeExists(version: version, skill: skill, nodeId: id);
      if (!exists) {
        await _upsertNode(version: version, skill: skill, nodeId: id, payload: n);
      }
    }
  }
}

// helper
String _skillKey(SkillType s) => s.name; // "cooking", "cleaning", ...
