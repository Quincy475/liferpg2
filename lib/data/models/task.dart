import 'enums.dart';

class Task {
  final String id;
  final String title;
  final SkillType skill;
  final double basePoints;
  final bool canStreak;
  final int cooldownMinutes;
  final bool isCoop;

  Task({
    required this.id,
    required this.title,
    required this.skill,
    required this.basePoints,
    this.canStreak = true,
    this.cooldownMinutes = 0,
    this.isCoop = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'skill': skill.index,
        'basePoints': basePoints,
        'canStreak': canStreak,
        'cooldownMinutes': cooldownMinutes,
        'isCoop': isCoop,
      };

  static Task fromMap(Map m) => Task(
        id: m['id'],
        title: m['title'],
        skill: SkillType.values[m['skill']],
        basePoints: m['basePoints'],
        canStreak: m['canStreak'] ?? true,
        cooldownMinutes: m['cooldownMinutes'] ?? 0,
        isCoop: m['isCoop'] ?? true,
      );
}
