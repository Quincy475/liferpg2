import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class UserProfile {
  final String id;
  final String name;
  final Map<SkillType, int> skillXp; // per skill XP
  final int coins;
  final int weeklyPoints;
  final Map<String, int> streaks; // taskId -> days
  final Set<String> badges; // badge ids (weekly, tijdelijk)
  final bool crown; // heeft current week crown?
  final DateTime? lastReset; // week reset marker
  final String? guildId;
   final Map<SkillType, List<String>> perks;

  UserProfile({
    required this.id,
    required this.name,
    required this.skillXp,
    this.coins = 0,
    this.weeklyPoints = 0,
    this.streaks = const {},
    this.badges = const {},
    this.crown = false,
    this.lastReset,
    this.guildId,
    this.perks = const {},
  });

  UserProfile copyWith({
    String? name,
    Map<SkillType, int>? skillXp,
    int? coins,
    int? weeklyPoints,
    Map<String, int>? streaks,
    Set<String>? badges,
    bool? crown,
    DateTime? lastReset,
    String? guildId,
    Map<SkillType, List<String>>? perks,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        skillXp: skillXp ?? this.skillXp,
        coins: coins ?? this.coins,
        weeklyPoints: weeklyPoints ?? this.weeklyPoints,
        streaks: streaks ?? this.streaks,
        badges: badges ?? this.badges,
        crown: crown ?? this.crown,
        lastReset: lastReset ?? this.lastReset,
        guildId: guildId ?? this.guildId,
        perks: perks ?? this.perks,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'skillXp': skillXp.map((k, v) => MapEntry(k.index.toString(), v)),
        'coins': coins,
        'weeklyPoints': weeklyPoints,
        'streaks': streaks,
        'badges': badges.toList(),
        'crown': crown,
        'lastReset': lastReset?.toIso8601String(),
        'guildId': guildId,
        'perks': perks.map((k, v) => MapEntry(k.index.toString(), v)),
      };

    static UserProfile fromMap(Map<String, dynamic> m) {
    // 🔹 Veilig ophalen met fallbacks
    final id = m['id']?.toString() ?? '';
    final name = m['name']?.toString() ?? m['displayName']?.toString() ?? 'Player';
    final coins = (m['coins'] ?? 0) as int;
    final weeklyPoints = (m['weeklyPoints'] ?? 0) as int;
    final crown = (m['crown'] ?? false) as bool;
    final guildId = m['guildId']?.toString();
    final lastResetRaw = m['lastReset'];

    // 🔹 SkillXP veilig mappen
    final skillXpRaw = Map<String, dynamic>.from(m['skillXp'] ?? {});
    final skillXp = <SkillType, int>{};
    for (final entry in skillXpRaw.entries) {
      final idx = int.tryParse(entry.key);
      if (idx != null && idx >= 0 && idx < SkillType.values.length) {
        skillXp[SkillType.values[idx]] = (entry.value ?? 0) as int;
      }
    }
    // vul ontbrekende skills met 0 (veilig)
    for (final s in SkillType.values) {
      skillXp.putIfAbsent(s, () => 0);
    }

    // 🔹 Streaks
    final streaksRaw = Map<String, dynamic>.from(m['streaks'] ?? {});
    final streaks = streaksRaw.map((k, v) => MapEntry(k.toString(), (v ?? 0) as int));

    // 🔹 Badges
    final badges = Set<String>.from((m['badges'] ?? const <String>[]) as List);

    // 🔹 lastReset kan String of Timestamp zijn
    DateTime? lastReset;
    if (lastResetRaw != null) {
      if (lastResetRaw is String) {
        lastReset = DateTime.tryParse(lastResetRaw);
      } else if (lastResetRaw is Timestamp) {
        lastReset = lastResetRaw.toDate();
      }
    }
 final perksRaw = Map<String, dynamic>.from(m['perks'] ?? {});
    final perks = <SkillType, List<String>>{};
    for (final entry in perksRaw.entries) {
      final idx = int.tryParse(entry.key);
      if (idx != null && idx >= 0 && idx < SkillType.values.length) {
        final list = List<String>.from(entry.value ?? const <String>[]);
        perks[SkillType.values[idx]] = list;
      }
    }
    // zorg dat alle skills een entry hebben
    for (final s in SkillType.values) {
      perks.putIfAbsent(s, () => <String>[]);
    }

    return UserProfile(
      id: id,
      name: name,
      skillXp: skillXp,
      coins: coins,
      weeklyPoints: weeklyPoints,
      streaks: streaks,
      badges: badges,
      crown: crown,
      lastReset: lastReset,
      guildId: guildId,
      perks: perks, // 🔹
    );
  }
}