import 'package:flutter/material.dart';

// enum SkillType { cooking, cleaning, fixing, laundry, admin }

enum Skill {
  cooking,
  cleaning,
  fixing,
  laundry,
  admin,
  upkeep,
  organization,
  petCare,
  wellbeing,
}

extension SkillUi on Skill {
  String get label => switch (this) {
        Skill.cooking => 'Cooking',
        Skill.cleaning => 'Cleaning',
        Skill.fixing => 'Fixing',
        Skill.laundry => 'Laundry',
        Skill.admin => 'Admin',
        Skill.upkeep => 'Upkeep',
        Skill.organization => 'Organization',
        Skill.petCare => 'Pet Care',
        Skill.wellbeing => 'Wellbeing',
      };

  String get icon => switch (this) {
        Skill.cooking => '🍳',
        Skill.cleaning => '🧹',
        Skill.fixing => '🔧',
        Skill.laundry => '🧺',
        Skill.admin => '🧾',
        Skill.upkeep => '🧰',
        Skill.organization => '🗂️',
        Skill.petCare => '🐾',
        Skill.wellbeing => '🕯️',
      };

  Color get color => switch (this) {
        Skill.cooking => Color(0xFFE8A34A),
        Skill.cleaning => Color(0xFF7CC6A6),
        Skill.fixing => Color(0xFF7FA1F7),
        Skill.laundry => Color(0xFFB68CF2),
        Skill.admin => Color(0xFFFFC857),
        Skill.upkeep => Color(0xFF8ED081),
        Skill.organization => Color(0xFF6EC1E4),
        Skill.petCare => Color(0xFFFF8FAB),
        Skill.wellbeing => Color(0xFFFFE9A7),
      };
}