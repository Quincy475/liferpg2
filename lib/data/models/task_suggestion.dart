import 'package:household_rpg/data/models/enums.dart';
import 'package:household_rpg/data/models/task_mvp.dart';

/// Een taak-suggestie die de AI teruggeeft, nog niet opgeslagen in Firestore.
class TaskSuggestion {
  final String title;
  final String description;
  final SkillType skill;
  final TaskScheduleType scheduleType;
  final int intervalValue;
  final DateTime? scheduledDate;
  final int dueHour;
  final int coinsBase;

  const TaskSuggestion({
    required this.title,
    required this.skill,
    required this.scheduleType,
    this.description = '',
    this.intervalValue = 1,
    this.scheduledDate,
    this.dueHour = 20,
    this.coinsBase = 5,
  });

  /// Zet de suggestie om naar een TaskTemplate klaar voor opslaan.
  TaskTemplate toTemplate() => TaskTemplate(
        id: '',
        title: title,
        description: description,
        coinsBase: coinsBase,
        isRepeatable: scheduleType != TaskScheduleType.custom,
        scheduleType: scheduleType,
        intervalValue: intervalValue,
        dueHour: dueHour,
        scheduledDate: scheduledDate,
      );

  /// Leesbare omschrijving van de herhaling voor in de UI.
  String get scheduleLabel {
    switch (scheduleType) {
      case TaskScheduleType.daily:
        return 'Elke dag';
      case TaskScheduleType.weekly:
        return 'Elke week';
      case TaskScheduleType.monthly:
        return 'Elke maand';
      case TaskScheduleType.everyXDays:
        return 'Elke $intervalValue dagen';
      case TaskScheduleType.custom:
        if (scheduledDate != null) {
          final d = scheduledDate!;
          return '${d.day}-${d.month}-${d.year}';
        }
        return 'Eenmalig';
    }
  }
}
