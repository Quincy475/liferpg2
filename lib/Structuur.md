# Structuur (huidige hoofdopzet)

## App bootstrap
- `lib/main.dart` → Firebase + Hive init, daarna app start.
- `lib/app.dart` → Home shell met tab navigatie (Quest, Shop, Profile, Pet).

## State/providing
- `lib/app/session_providers.dart`
  - Auth/session bootstrap
  - Current user + guild streams
  - Theme provider
  - Quest/shop/pet-gerelateerde providers

## Data laag
- `lib/data/models/` → domeinmodellen (snake_case bestandsnamen).
- `lib/data/repositories/` → Firestore/local data toegang.
- `lib/data/local/` → Hive box setup/persistente settings.

## Features (actief in hoofd-navigatie)
- `lib/features/quest/` → dailies/co-op board, cooldown, rewards.
- `lib/features/shop/` → shop-overzicht / aankopen.
- `lib/features/profile/` → profiel + instellingen.
- `lib/features/pet/` → pet-selectie, room game, inventory overlay.

## Legacy code
- Niet-gebruikte bestanden staan onder `legacy/lib/...` met originele structuur.
- Doel: ruis uit actieve code houden, terwijl oude implementaties bewaard blijven.

## Naming conventies (Fase A)
- Bestandsnamen in `snake_case.dart`.
- Modellen in `PascalCase` classnamen, bestand in snake_case.
- Providers/variabelen met duidelijke, foutloze namen (bijv. `furnitureRepoProvider`).
