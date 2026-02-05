import 'enums.dart';

class EventCard {
  final String id;
  final DateTime start;
  final DateTime end;
  final SkillType? doubleXpFor; // null => global
  final int xpMultiplierPct;    // e.g., +100 = double

  EventCard({
    required this.id,
    required this.start,
    required this.end,
    this.doubleXpFor,
    this.xpMultiplierPct = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'doubleXpFor': doubleXpFor?.index,
    'xpMultiplierPct': xpMultiplierPct,
  };

  static EventCard fromMap(Map m) => EventCard(
    id: m['id'],
    start: DateTime.parse(m['start']),
    end: DateTime.parse(m['end']),
    doubleXpFor: m['doubleXpFor'] != null ? SkillType.values[m['doubleXpFor']] : null,
    xpMultiplierPct: m['xpMultiplierPct'] ?? 0,
  );
}
