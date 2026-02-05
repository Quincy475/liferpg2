# Project cleanup + roadmap (status → desired product)

Dit document geeft je een praktisch overzicht van:
1) wat nu actief is,
2) wat waarschijnlijk dode code is,
3) welke stappen logisch zijn richting jouw MVP,
4) extra ideeën met hoge impact.

## 1) Huidige status (wat werkt nu al)

### Actieve app-flow (op basis van `main.dart` en `app.dart`)
- App start met Firebase + Hive initialisatie.
- Home-shell toont op dit moment 4 tabs: **Quest**, **Shop**, **Profile**, **Pet**.
- Quest-flow gebruikt Firestore, user-session en quest-controller providers.
- Pet-flow heeft al een room game met inventory overlay en room/pet state streams.

### Kernfundament dat al goed staat
- **Session bootstrap**: anonymous auth + user document setup.
- **User stream + guild context** via providers.
- **Quest rewards + cooldowns** zitten al in repository/controller flow.
- **Shop + pet-room basis** is aanwezig als uitbreiding voor economy/game loop.

## 2) Opschonen: dode code en cleanup-kandidaten

Ik heb een statische import-analyse gedaan vanaf `lib/main.dart` als entrypoint.

### Automatisch gevonden “orphan files”
Bestanden die:
- niet bereikbaar zijn vanaf de app-entryflow,
- én geen inkomende imports hebben.

Kandidaten:
- `lib/core/env.dart`
- `lib/data/local/hive_adapters.dart`
- `lib/data/models/Badge.dart`
- `lib/data/models/roomState.dart`
- `lib/data/repositories/auth_repo.dart`
- `lib/features/event/event_page.dart`
- `lib/features/leaderboard/leaderboard_page.dart`
- `lib/features/loot/loot_page.dart`
- `lib/features/pet/data/window_config.dart`
- `lib/features/pet/data/window_providers.dart`
- `lib/features/pet/game/furniture/furniture_defs.dart`
- `lib/features/pet/pet_models.dart`
- `lib/features/pet/pet_page_oud.dart`
- `lib/features/quest/quets_lists.dart`
- `lib/features/raid/raid_page.dart`
- `lib/features/skills/skills_overview_page.dart`
- `lib/features/skills/skills_page.dart`
- `lib/features/tasks.dart`
- `lib/features/tasks/tasks_page.dart`
- `lib/widgets/glow_progress_bar.dart`
- `lib/widgets/neon_button.dart`
- `lib/widgets/particle_background.dart`

### Extra handmatige cleanup-opmerking
- `lib/features/quest/ui/daily_list,dart` lijkt een typefout in de bestandsnaam (komma i.p.v. punt) en wordt niet gebruikt.

### Veilig opschoonproces (aanrader)
1. Verplaats orphans eerst naar `archive/` of `legacy/` i.p.v. direct verwijderen.
2. Draai daarna een smoke test op je 4 actieve tabs.
3. Pas als alles stabiel is: definitief verwijderen.
4. Houd per cleanup-commit klein en thematisch (bijv. “remove old leaderboard module”).

## 3) Roadmap: waar je nu staat vs waar je heen wilt

## Fase A — Stabiliseren (nu)
Doel: sneller itereren zonder ruis.
- [x] Dode code opgeruimd en verplaatst naar `legacy/` map.
- [x] Documentatie geactualiseerd (roadmap + structuurbestand).
- [x] Naming cleanup gedaan: typo-bestanden/variabelen verbeterd en modelnamen consistenter gemaakt.

## Fase B — MVP economy loop
Doel: “tasks → coins/xp → shop → pet beleving”.
- [ ] Quest/task completion levert betrouwbaar **coins + xp** op.
- [ ] Shop ondersteunt **group-created offers** (bijv. “massage voor 3 coins”).
- [ ] Inventory koppelen aan plaatsbare room items.
- [ ] Basis pet feedback op voortgang (idle/mood animatie wissels).

## Fase C — USP petgame versterken
Doel: reden om dagelijks terug te komen.
- [ ] Pet mood wordt zichtbaar beïnvloed door takenritme.
- [ ] Furniture placement wordt core loop (koop → inventory → plaats → visueel effect).
- [ ] Kleine progressie per pet (cosmetics, animation unlocks, room style).

## Fase D — Uitbreiding na MVP
Doel: langere retentie + sociale fun.
- [ ] Skill tree activeren (XP als unlock-mechaniek).
- [ ] Co-op/guild doelen met seizoensbeloningen.
- [ ] Events/challenges met beperkte looptijd.

## 4) Minimaal 3 extra ideeën (niet door jou genoemd)

### Idee 1 — “Streak warmte” i.p.v. harde punishment
**Wat:** een zachte streakbonus (bijv. +10% coin op dag 3/5/7) zonder zware reset-straf.
**Waarom waardevol:** vergroot dagelijkse terugkeer zonder dat users afhaken na één gemiste dag.

### Idee 2 — “House mood meter” op groepsniveau
**Wat:** alle voltooide taken vullen een gezamenlijke house meter die wekelijkse cosmetic buffs geeft (lichtjes, room effects).
**Waarom waardevol:** versterkt samenwerking binnen huis/groep, niet alleen individuele progressie.

### Idee 3 — “Pet memory moments”
**Wat:** pet bewaart mini-herinneringen (“Vandaag 5 quests gedaan!”) als timeline cards.
**Waarom waardevol:** emotionele binding + deelbare momenten = hogere retentie.

### Bonus idee 4 — “Quick-win kaartjes”
**Wat:** elke dag 1–2 superkleine taken (“2 minuten opruimen”) met mini reward.
**Waarom waardevol:** verlaagt drempel op drukke dagen en houdt momentum in stand.

## 5) Hoe alles grofweg samenhangt

### Runtime architectuur (nu)
1. `main.dart` initialiseert Firebase/Hive.
2. `HouseholdRPGApp` bouwt theme + home-shell.
3. `session_providers.dart` verzorgt auth, current user, guild-data, quest/pet providers.
4. Feature pages lezen providers en renderen UI + acties.
5. Repositories praten met Firestore en schrijven quest/shop/pet data.

### Waar toekomstige features logisch landen
- **Tasks + beloningen:** `features/quest/` + `data/repositories/quest_repo.dart`
- **Coins economy + user offers:** `features/shop/` + `data/repositories/shop_repo.dart`
- **Pet USP + room state:** `features/pet/` + `data/repositories/pet_repo.dart`
- **Skills op XP:** `features/skills/` + skill repositories/providers

## 6) Concrete next sprint (7 dagen voorstel)

- Dag 1–2: cleanup sprint (orphans, typos, legacy map, docs).
- Dag 3–4: shop user-offers MVP (create/list/redeem flow).
- Dag 5: inventory → furniture placement stabiel maken.
- Dag 6: 3 pet mood animatie-triggers koppelen aan task activiteit.
- Dag 7: polish + mini playtest met 2–4 gebruikers in je groep.

---

Als je wilt, kan ik in de volgende stap een **“cleanup PR-serie plan”** maken met precies welke files je per commit veilig verwijdert/archivet.
