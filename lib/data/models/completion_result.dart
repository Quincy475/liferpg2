import 'enums.dart';

class CompletionResult {
  final int pointsGained;
  final int coinsGained;
  final Map<SkillType, double> skillXpGained;
  final bool lootDropped;
  final String? ticketId;

  CompletionResult({
    required this.pointsGained,
    required this.coinsGained,
    required this.skillXpGained,
    this.lootDropped = false,
    this.ticketId,
  });
}
