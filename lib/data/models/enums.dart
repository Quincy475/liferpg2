enum SkillType { cooking, cleaning, fixing, laundry, admin /* ... */ }
enum QuestType { daily, coop }
enum AppMode { guild, personal }

extension SkillTypeKey on SkillType {
  String get key {
    switch (this) {
      case SkillType.cooking: return 'cooking';
      case SkillType.cleaning: return 'cleaning';
      case SkillType.fixing:   return 'fixing';
      case SkillType.laundry:  return 'laundry';
      case SkillType.admin:    return 'admin';
    }
  }

  String get label {
    switch (this) {
      case SkillType.cooking: return 'Cooking';
      case SkillType.cleaning: return 'Cleaning';
      case SkillType.fixing:   return 'Fixing';
      case SkillType.laundry:  return 'Laundry';
      case SkillType.admin:    return 'Admin';
    }
  }
}
