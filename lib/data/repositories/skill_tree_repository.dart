import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/models/skillNode.dart';
import 'package:household_rpg/features/skills/domain/node.dart';

class SkillTreeRepository {
  final FirebaseFirestore _db;
  const SkillTreeRepository(this._db);

  // skillKey = 'cooking', 'cleaning', ...
  Stream<List<SkillNode>> watchNodes(String skillKey) {
    return _db
        .collection('skilltrees/$skillKey/nodes')
        .orderBy('tier')
        .snapshots()
        .map((s) => s.docs.map((d) => SkillNode.fromMap(d.id, d.data())).toList());
  }

  String _skillKey(SkillType s) => s.name; // werkt in Dart 2.17+

// Ruwe (Map) collectie voor versie + skill
  CollectionReference<Map<String, dynamic>> _rawNodesCol({
    required String version,
    required SkillType skill,
  }) {
    final key = _skillKey(skill);
    // Pad: /skillNodes_v{version}/{skillKey}/{skillKey}
    // Voorbeeld: /skillNodes_v1/cooking/cooking/<nodeId>
    return _db.collection('skillNodes_$version').doc(key).collection(key);
  }

// Sterk getypte collectie m.b.v. withConverter
  CollectionReference<SkillNode> _nodesCol({
    required String version,
    required SkillType skill,
  }) {
    return _rawNodesCol(version: version, skill: skill).withConverter<SkillNode>(
      fromFirestore: (snap, _) => SkillNode.fromDoc(snap),
      toFirestore: (node, _) => node.toMap(),
    );
  }

  Future<List<SkillNode>> getNodes(String skillKey) async {
    final q = await _db.collection('skilltrees/$skillKey/nodes').orderBy('tier').get();
    return q.docs.map((d) => SkillNode.fromMap(d.id, d.data())).toList();
  }

  Future<void> ensureMeta({int currentVersion = 1}) async {
    final metaRef = _db.collection('configs').doc('skillNodesMeta');
    await _db.runTransaction((tx) async {
      final snap = await tx.get(metaRef);
      if (!snap.exists) {
        tx.set(metaRef, {
          'currentVersion': currentVersion,
          'updatedAt': FieldValue.serverTimestamp(),
          'notes': 'init seed',
        });
      }
    });
  }

  /// Handig als je een version bump wilt pushen vanuit een admin knop
  Future<void> setCurrentVersion(int v) async {
    final metaRef = _db.collection('configs').doc('skillNodesMeta');
    await metaRef.set({
      'currentVersion': v,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> getCurrentVersion() async {
    final snap = await _db.collection('configs').doc('skillNodesMeta').get();
    if (!snap.exists) return 1;
    final m = snap.data() ?? {};
    return (m['currentVersion'] ?? 1) as int;
  }

// ====== HELPERS ======
  Future<bool> _nodeExists({
    required String version,
    required SkillType skill,
    required String nodeId,
  }) async {
    final col = _nodesCol(version: version, skill: skill);
    final doc = await col.doc(nodeId).get();
    return doc.exists;
  }

  Future<void> _upsertNode({
    required String version,
    required SkillType skill,
    required String nodeId,
    required SkillNode payload,
  }) async {
    final col = _nodesCol(version: version, skill: skill);
    await col.doc(nodeId).set(payload, SetOptions(merge: true));
  }

// ====== PAKKETJE VOORBEELD-NODES ======
  List<Map<String, dynamic>> _exampleNodesFor(SkillType skill) {
    final key = _skillKey(skill); // bv "cooking", "cleaning"

    if (key == 'cooking') {
      return [
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
              "scope": "skill",
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
      ];
    }

    if (key == 'cleaning') {
      return [
        {
          "id": "clean_zone_method",
          "skill": "cleaning",
          "title": "Zone Method",
          "description": "Room-by-room focus; +1 streak per dag mogelijk.",
          "icon": "🧽",
          "type": "passive",
          "tier": 1,
          "cost": 1,
          "maxRank": 1,
          "prereq": [],
          "mutualExclusionGroup": null,
          "effects": [
            {"kind": "streak_boost", "op": "add", "value": 1, "scope": "task:cleaning"}
          ],
          "uiHints": {"badge": "Common"},
          "schemaVersion": 1
        },
        {
          "id": "clean_flow_state",
          "skill": "cleaning",
          "title": "Flow State",
          "description": "Streaks geven extra XP bij cleaning.",
          "icon": "🧹",
          "type": "passive",
          "tier": 2,
          "cost": 1,
          "maxRank": 2,
          "prereq": ["clean_zone_method"],
          "mutualExclusionGroup": null,
          "effects": [
            {"kind": "streak_boost", "op": "add", "value": 1, "scope": "task:cleaning"},
            {
              "kind": "xp_multiplier",
              "op": "mul",
              "value": 0.05,
              "cap": 0.20,
              "scope": "task:cleaning",
              "perRankScale": 0.05
            }
          ],
          "uiHints": {"badge": "Uncommon", "accentColor": "#D6B05F"},
          "schemaVersion": 1
        },
      ];
    }

    // default: leeg
    return const [];
  }

// ====== PUBLIEKE SEED-API (IDEMPOTENT) ======
  Future<void> seedSkillNodesIfMissing() async {
    // Zorg dat meta bestaat
    await ensureMeta(currentVersion: 1);

    final versionStr = await getCurrentVersion(); // bijv. "v1"
    // Seed alleen voor skills waar je nu nodes voor wilt hebben
    final skillsToSeed = <SkillType>[
      SkillType.cooking,
      SkillType.cleaning,
      // SkillType.fixing, ... later toevoegen
    ];

    for (final s in skillsToSeed) {
      final nodesMap = _exampleNodesFor(s);
      List<SkillNode> nodes = nodesMap.map((n) => SkillNode.fromMap(n['id'], n)).toList();
      for (SkillNode n in nodes) {
        final id = n.id;
        if (id.isEmpty) continue;

        final exists = await _nodeExists(version: versionStr.toString(), skill: s, nodeId: id);
        if (!exists) {
          await _upsertNode(version: versionStr.toString(), skill: s, nodeId: id, payload: n);
        }
      }
    }
  }
}
