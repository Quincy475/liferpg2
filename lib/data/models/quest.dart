import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:household_rpg/data/models/skill.dart';
import 'package:household_rpg/data/models/models.dart';

// enum SkillType { cooking, cleaning, fixing, laundry, admin }
class RaidGoal {
  final String id;
  final String title;
  final int targetPoints; // bv. 600
  final int currentPoints; // som van coop-eligible tasks
  final DateTime weekStart; // voor reset
  RaidGoal({
    required this.id,
    required this.title,
    required this.targetPoints,
    required this.currentPoints,
    required this.weekStart,
  });

  double get progress => (currentPoints / targetPoints).clamp(0, 1);
}

class CompletionResult {
  final int pointsGained;
  final int coinsGained;
  final Map<SkillType, int> skillXpGained;
  final bool lootDropped;
  final String? ticketId; // bv. "golden_ticket"
  CompletionResult({
    required this.pointsGained,
    required this.coinsGained,
    required this.skillXpGained,
    this.lootDropped = false,
    this.ticketId,
  });
}

class Quest {
  final String id;
  final QuestType type;
  final Skill skill;
  final String title;
  final String description;
  final int rewardXp;
  final int rewardCoins;
  final DateTime? deadline; // voor daily, reset elders
  final List<String> memberIds; // voor coop
  final Map<String, double> contributions; // userId -> progress 0..1
  final bool completed; // voor solo
  final bool claimable; // voor coop: kan de beloning geclaimd worden?
final DateTime? cooldownUntil;
  const Quest({
    required this.id,
    required this.type,
    required this.skill,
    required this.title,
    required this.description,
    required this.rewardXp,
    required this.rewardCoins,
    this.deadline,
    this.memberIds = const [],
    this.contributions = const {},
    this.completed = false,
    this.claimable = false,
     this.cooldownUntil,
  });

  double get overallProgress {
    if (type == QuestType.daily) {
      return completed ? 1.0 : 0.0;
    }
    if (memberIds.isEmpty) return 0.0;
    double sum = 0;
    for (final m in memberIds) {
      sum += (contributions[m] ?? 0.0).clamp(0.0, 1.0);
    }
    return (sum / memberIds.length).clamp(0.0, 1.0);
  }

  // ---------- fromMap ----------
  static Quest fromMap(Map<String, dynamic> m) {
    String _str(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
    int _int(dynamic v, [int fb = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      final p = int.tryParse(v?.toString() ?? '');
      return p ?? fb;
    }

    double _dbl(dynamic v, [double fb = 0.0]) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      final p = double.tryParse(v?.toString() ?? '');
      return p ?? fb;
    }

    DateTime? _dt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    QuestType _qType(dynamic v) {
      if (v is int && v >= 0 && v < QuestType.values.length) return QuestType.values[v];
      final s = v?.toString().toLowerCase();
      switch (s) {
        case 'daily':
          return QuestType.daily;
        case 'coop':
          return QuestType.coop;
        default:
          return QuestType.daily; // default fail-safe
      }
    }

    Skill _skill(dynamic v) {
      if (v is int && v >= 0 && v < Skill.values.length) return Skill.values[v];
      final s = v?.toString().toLowerCase();
      // Map string keys naar enum namen
      for (final sk in Skill.values) {
        if (sk.name.toLowerCase() == s) return sk;
      }
      // Backwards compatibele aliassen
      switch (s) {
        case 'cooking':
          return Skill.cooking;
        case 'cleaning':
          return Skill.cleaning;
        case 'fixing':
          return Skill.fixing;
        case 'laundry':
          return Skill.laundry;
        case 'admin':
          return Skill.admin;
        // case 'maintenance':  return Skill.maintenance;
        case 'organization':
          return Skill.organization;
        // case 'petcare':      return Skill.petcare;
        case 'wellbeing':
          return Skill.wellbeing;
        default:
          return Skill.cooking;
      }
    }

    final id = _str(m['id']); // laat leeg als je doc.id elders injecteert
    final type = _qType(m['type']);
    final skill = _skill(m['skill']);
    final title = _str(m['title']);
    final description = _str(m['description']);
    final rewardXp = _int(m['rewardXp']);
    final rewardCoins = _int(m['rewardCoins']);
    final deadline = _dt(m['deadline']);
    final memberIds = List<String>.from((m['memberIds'] ?? const <String>[]) as List);
    final completed = (m['completed'] ?? false) == true;
    final claimable = (m['claimable'] ?? false) == true;

    // contributions: Map<String, double> (values kunnen int/double/string zijn)
    final contribRaw = Map<String, dynamic>.from(m['contributions'] ?? const <String, dynamic>{});
    final contributions = <String, double>{};
    contribRaw.forEach((k, v) => contributions[k] = _dbl(v, 0.0).clamp(0.0, 1.0));

    return Quest(
      id: id,
      type: type,
      skill: skill,
      title: title,
      description: description,
      rewardXp: rewardXp,
      rewardCoins: rewardCoins,
      deadline: deadline,
      memberIds: memberIds,
      contributions: contributions,
      completed: completed,
      claimable: claimable,
    );
  }
}
