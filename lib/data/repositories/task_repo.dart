import 'package:collection/collection.dart';
import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/data/models/task.dart';
import 'package:household_rpg/data/models/enums.dart';

class TaskRepository {
  Future<List<Task>> getAll() async {
    return tasksBox.values.map((e) => Task.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> upsert(Task t) async {
    await tasksBox.put(t.id, t.toMap());
  }

  Future<void> delete(String id) async => tasksBox.delete(id);

  Future<void> seedDemoTasks() async {
    final items = <Task>[
      Task(
          id: 't1',
          title: 'Koken (avondeten)',
          skill: SkillType.cooking,
          basePoints: 25,
          canStreak: true),
      Task(
          id: 't2',
          title: 'Afwas/vaatwasser',
          skill: SkillType.cleaning,
          basePoints: 18,
          canStreak: true),
      Task(
          id: 't3',
          title: 'Stofzuigen',
          skill: SkillType.cleaning,
          basePoints: 15,
          canStreak: false),
      Task(
          id: 't4',
          title: 'Was draaien',
          skill: SkillType.laundry,
          basePoints: 20,
          canStreak: true),
      Task(
          id: 't5',
          title: 'Prullenbak buiten',
          skill: SkillType.admin,
          basePoints: 12,
          canStreak: false),
      Task(
          id: 't6',
          title: 'Kast repareren',
          skill: SkillType.fixing,
          basePoints: 40,
          canStreak: false),
    ];
    for (final t in items) {
      await upsert(t);
    }
  }

  Future<void> addToRaid(String raidId, int points) async {
    // handled in raid repo normally; left for compatibility
  }

  Future<Task?> getUser(String id) async {
    final m = tasksBox.get(id);
    return m != null ? Task.fromMap(Map<String, dynamic>.from(m)) : null;
  }

  Future<Task?> byTitle(String title) async {
    final all = await getAll();
    return all.firstWhereOrNull((t) => t.title == title);
  }
}
