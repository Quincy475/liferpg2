import 'package:household_rpg/core/utils.dart';
import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/data/models/Raidgoal.dart';

class RaidRepository {
  static const String kRaidKey = 'activeRaid';

  Future<RaidGoal?> getRaid() async {
    final m = raidBox.get(kRaidKey);
    if (m == null) return null;
    return RaidGoal.fromMap(Map<String, dynamic>.from(m));
  }

  Future<void> setRaid(RaidGoal raid) async => raidBox.put(kRaidKey, raid.toMap());

  Future<void> seedDemoRaid() async {
    final now = DateTime.now();
    final raid = RaidGoal(
      id: 'r1',
      title: 'Weekly Team Goal',
      targetPoints: 600,
      currentPoints: 0,
      weekStart: startOfIsoWeek(now),
    );
    await setRaid(raid);
  }

  Future<void> addPoints(int points) async {
    final r = await getRaid();
    if (r == null) return;
    await setRaid(r.copyWith(currentPoints: r.currentPoints + points));
  }

  Future<void> maybeWeeklyResetRaid() async {
    final r = await getRaid();
    final now = DateTime.now();
    final week = startOfIsoWeek(now);
    if (r == null || startOfIsoWeek(r.weekStart) != week) {
      await seedDemoRaid();
    }
  }
}
