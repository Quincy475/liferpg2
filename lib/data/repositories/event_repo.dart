

import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/data/models/event_card.dart';

class EventRepository {
  Future<List<EventCard>> activeEvents() async {
    final now = DateTime.now();
    return eventsBox.values
        .map((e) => EventCard.fromMap(Map<String, dynamic>.from(e)))
        .where((e) => now.isAfter(e.start) && now.isBefore(e.end))
        .toList();
  }

  Future<List<EventCard>> getAll() async {
    return eventsBox.values.map((e) => EventCard.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> upsert(EventCard e) async => eventsBox.put(e.id, e.toMap());

  Future<void> delete(String id) async => eventsBox.delete(id);

  Future<void> seedDemoEvents() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final e1 = EventCard(
      id: 'e1',
      start: todayStart,
      end: todayEnd,
      doubleXpFor: null,//SkillType.cleaning,
      xpMultiplierPct: 100, // double XP cleaning today
    );
    await upsert(e1);
  }

  Future<void> clearAll() async => eventsBox.clear();
}
