# CLAUDE.md — Household RPG (liferpg2)

Guidelines for AI assistants working on this codebase. Read this before making changes.

---

## Project Overview

**Household RPG** is a Flutter-based cooperative mobile app where household members complete real-world tasks, gain skill XP, earn coins, and collaborate on quests. It targets Android, iOS, macOS, Linux, Windows, and Web.

- **Package name:** `household_rpg`
- **Dart SDK:** >=3.1.0
- **Flutter channel:** stable
- **Firebase Project:** `liferpg-2f2ae`

---

## Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Run linter (flutter_lints 6.0.0)
flutter test             # Run widget tests (test/widget_test.dart)
flutter run              # Run on connected device/emulator
flutter build apk        # Build Android APK
flutter build ios        # Build iOS IPA
```

There are no custom build scripts. Use standard Flutter CLI commands.

---

## Architecture

### Directory Structure

```
lib/
  main.dart                      # Entry: Firebase init, Hive init, ProviderScope
  app.dart                       # Root MaterialApp + _HomeShell (bottom nav)
  app/
    session_providers.dart       # Central Riverpod provider registry (all app-wide providers)
  core/
    env.dart                     # Environment config
    utils.dart                   # Date/math utilities
  config/
    furniture.dart               # Furniture config for pet room
  data/
    models/                      # Immutable domain models (16 files)
    repositories/                # Firestore + Hive abstractions (11 files)
    local/
      hive_boxes.dart            # Hive box declarations + openAppBoxes()
      hive_adapters.dart
  features/                      # Feature modules (page + state + ui)
    tasks/
    quest/
    shop/
    profile/
    pet/                         # Flame 2D game for the pet room
    skills/
    event/
    raid/
    loot/
    leaderboard/
  scoring/
    scoring_enginge.dart         # Reward calculation (XP, coins, loot drops)
  theme/
    app_theme.dart               # Material 3 theme builder + design system
  widgets/                       # Shared reusable widgets
```

### State Management (Riverpod)

All providers live in `lib/app/session_providers.dart`. Key patterns:

- `StreamProvider` — real-time Firestore listeners (users, quests, inventory)
- `StateNotifierProvider` — interactive state (`QuestController`, `ThemeController`)
- `FutureProvider` — one-off async fetches (skill node versions)
- `.family` modifier — parameterized providers (e.g., per skill type)

When adding a new feature that needs shared state, register its provider in `session_providers.dart`.

### Data Layer

**Firestore schema:**
```
users/{uid}
  inventory/        (InventoryItem)
  purchases/        (PurchaseEntry)
guilds/{guildId}
  members/{uid}
  quests/{questId}
    completions/{uid}
skillNodes/         (versioned skill tree)
shopItems/          (guild-specific shop)
```

**Hive local boxes** (opened via `openAppBoxes()` in `main.dart`):
`users`, `tasks`, `shop`, `events`, `raid`, `completions`, `app`

Theme state (`theme_mode`, `theme_seed`) persists in the `app` Hive box.

---

## Key Conventions

### Naming

| Context | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `UserProfile`, `QuestController` |
| Files (models) | PascalCase with underscore | `User_profile.dart`, `Shop_Item.dart` |
| Files (repos/pages) | snake_case | `user_repo.dart`, `tasks_page.dart` |
| Variables/methods | camelCase | `watchUsersByGuild`, `completeDaily` |

Note: Two existing typos to be aware of — do NOT fix them without updating all references:
- `scoring_enginge.dart` (not "engine")
- `features/quest/ui/proress_bar.dart` (not "progress")

### Models

All domain models follow these patterns:
- Constructor with named parameters
- `copyWith()` for immutable updates
- `fromMap(Map<String, dynamic>)` / `toMap()` for Firestore serialization
- Use `Equatable` where value equality matters (not universally applied)

### Error Handling

- Use `QuestCooldownException` for domain-specific quest errors
- No silent failures — surface errors via `AsyncValue` in Riverpod or log them
- Do not use bare `try/catch` that swallows exceptions without logging

### UI

- All pages that consume providers extend `ConsumerStatefulWidget` or `ConsumerWidget`
- Use `Theme.of(context)` for colors and typography — do not hardcode values
- Material 3 only — do not use deprecated Material 2 APIs
- Seed color theming via `ThemeController`; user can change it in the menu

### Comments

- Comments in this codebase are often written in **Dutch** — this is intentional
- Emoji markers in comments are acceptable (`// ✅ Read completion doc`)
- Do not add comments for self-explanatory code

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod ^3.3.1` | State management |
| `cloud_firestore ^5.6.12` | Cloud database + real-time listeners |
| `firebase_auth ^5.7.0` | Auth (anonymous, Google, Apple) |
| `hive ^2.2.3` + `hive_flutter ^1.1.0` | Local storage |
| `flame ^1.15.0` | 2D game engine (pet room) |
| `flame_audio ^2.1.8` | Audio for pet game |
| `equatable ^2.0.7` | Value equality for models |
| `intl ^0.20.2` | Date formatting + i18n |

**Important:** Do NOT add an explicit `collection` dependency — it causes pin conflicts with `flutter_test` (see comment in `pubspec.yaml`).

---

## Firebase Configuration

`lib/firebase_options.dart` is auto-generated by FlutterFire CLI. Do not edit it manually. It selects the correct Firebase config per platform at runtime via `DefaultFirebaseOptions.currentPlatform`.

---

## Domain Concepts

- **SkillType** (enum): `cooking`, `cleaning`, `fixing`, `laundry`, `admin`, `organization`, `wellbeing`
- **QuestType** (enum): `daily`, `coop`
- **Quest cooldowns**: After completing a daily quest, `cooldownUntil` is set; the `QuestCooldownException` guards re-completion
- **Weekly points**: Reset on a schedule; tracked separately from total XP
- **Scoring**: `ScoringEngine` in `lib/scoring/scoring_enginge.dart` applies streak/skill/event multipliers to base task points

---

## Testing

The test suite is minimal (`test/widget_test.dart` is mostly template). When adding tests:
- Use `flutter_test` SDK
- Mock Firestore interactions rather than hitting live Firebase
- Run `flutter analyze` before committing to catch lint errors

---

## Git Workflow

- Default development branch for Claude: `claude/add-claude-documentation-aH10Q`
- Commit messages should be lowercase and descriptive (e.g., `fix quest cooldown logic`)
- Do not amend commits unless explicitly requested
- Never use `git reset --hard` or `git checkout --` without user confirmation
- Do not revert unrelated changes in a dirty worktree

---

## What to Avoid

- Do not add new top-level dependencies without checking for pin conflicts
- Do not use `as` casts — prefer type guards and parsing functions
- Do not hardcode colors or font sizes — use the theme system
- Do not split providers out of `session_providers.dart` without good reason
- Do not use Material 2 widgets or `ThemeData` patterns
- Do not fix the two known filename typos (`enginge`, `proress`) without updating all imports
