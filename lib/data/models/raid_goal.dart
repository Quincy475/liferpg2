class RaidGoal {
  final String id;
  final String title;
  final int targetPoints;
  final int currentPoints;
  final DateTime weekStart;

  RaidGoal({
    required this.id,
    required this.title,
    required this.targetPoints,
    required this.currentPoints,
    required this.weekStart,
  });

  double get progress => (currentPoints / targetPoints).clamp(0, 1);

  RaidGoal copyWith({
    String? title,
    int? targetPoints,
    int? currentPoints,
    DateTime? weekStart,
  }) => RaidGoal(
    id: id,
    title: title ?? this.title,
    targetPoints: targetPoints ?? this.targetPoints,
    currentPoints: currentPoints ?? this.currentPoints,
    weekStart: weekStart ?? this.weekStart,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'targetPoints': targetPoints,
    'currentPoints': currentPoints,
    'weekStart': weekStart.toIso8601String(),
  };

  static RaidGoal fromMap(Map m) => RaidGoal(
    id: m['id'],
    title: m['title'],
    targetPoints: m['targetPoints'],
    currentPoints: m['currentPoints'] ?? 0,
    weekStart: DateTime.parse(m['weekStart']),
  );
}
