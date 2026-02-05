# Structuur (huidige hoofdopzet)

## App bootstrap
- `lib/main.dart` → Firebase + Hive init, daarna app start.
- `lib/app.dart` → Home shell met tab navigatie (Quest, Shop, Profile, Pet).

## State/providing
- `lib/app/session_providers.dart`
  - Auth/session bootstrap
  - Current user + guild streams
  - Theme provider
  - Quest/shop/pet related providers

## Data laag
- `lib/data/models/` → domeinmodellen (quest, user, pet, shop, skills, etc.).
- `lib/data/repositories/` → Firestore/local data toegang.
- `lib/data/local/` → Hive box setup/persistente settings.

## Features
- `lib/features/quest/` → dailies/co-op board, cooldown, rewards.
- `lib/features/shop/` → shop-overzicht / aankopen.
- `lib/features/profile/` → profiel + instellingen.
- `lib/features/pet/` → pet-selectie, room game, inventory overlay.

## Nog aanwezig maar momenteel niet in hoofd-navigatie
- leaderboard, raid, loot, event, skills, tasks modules.
- Deze zijn kandidaat voor herintroductie of cleanup/archive.

## Aanbevolen toekomstige mappen
- `docs/` → roadmap + architectuur + productkeuzes.
- `lib/features/economy/` (optioneel) → centrale coin/inventory transactielogica.
- `lib/features/pet/progression/` (optioneel) → mood/progression/animatie regels.
