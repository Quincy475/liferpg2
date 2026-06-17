import 'dart:math';
import 'package:household_rpg/data/models/Task.dart';
import 'package:household_rpg/data/models/User_profile.dart';
import 'package:household_rpg/data/models/Completion_result.dart';

class ScoringEngine {
  final Random _rng;
  ScoringEngine(this._rng);

  int _streakBonusPct(int streakDays) {
    if (streakDays >= 10) return 50;
    if (streakDays >= 5) return 25;
    if (streakDays >= 2) return 10;
    return 0;
  }

  int _skillBonusPct(int skillXp) {
    final tiers = (skillXp / 500).floor();
    return (min(tiers * 5, 25)); // max 25%
  }

  bool _rollLoot(double chance) => _rng.nextDouble() < chance;

  CompletionResult completeTask({
    required Task task,
    required UserProfile user,
  }) {
    final streakDays = user.streaks[task.id] ?? 0;
    final streakPct = task.canStreak ? _streakBonusPct(streakDays) : 0;
    final skillXpCurrent = user.skillXp[task.skill] ?? 0;
    final skillPct = _skillBonusPct(skillXpCurrent);

    final totalPct = 100 + streakPct + skillPct;
    final points = ((task.basePoints * totalPct) / 100).round();
    final coins = (points / 5).round();

    double skillXp = task.basePoints;
    if (streakDays >= 5) skillXp = (skillXp * 1.1);

    double lootChance = 0.12;
    if (skillPct >= 15) lootChance += 0.05;
    final loot = _rollLoot(lootChance);

    String? ticketId;
    if (loot && _rng.nextDouble() < 0.08) ticketId = "golden_ticket";

    return CompletionResult(
      pointsGained: points,
      coinsGained: coins,
      skillXpGained: {task.skill: skillXp},
      lootDropped: loot,
      ticketId: ticketId,
    );
  }
}
