# Household RPG MCP-server

Beheer de app via chat (Claude Code / Claude Desktop): taken, coop-quests en shop-items in bulk.
De server schrijft rechtstreeks naar dezelfde Firestore als de app, met dezelfde veldvormen
(`TaskTemplate.toMap`, `ShopItem.toMap`). De app pikt wijzigingen live op via de bestaande streams.

> Gebruikt firebase-admin → **omzeilt Firestore-rules**. Draai hem alleen lokaal en deel de sleutel nooit.

## Setup (eenmalig)

1. Firebase console → Project settings → Service accounts → *Generate new private key*.
   Bewaar het JSON-bestand **buiten de repo** (bijv. `~/.secrets/liferpg-sa.json`).
2. `cd tools/mcp && npm install`
3. Zet de variabele in je shell-profiel:
   ```bash
   export HOUSEHOLD_RPG_SERVICE_ACCOUNT=~/.secrets/liferpg-sa.json
   ```
4. Claude Code in de repo-root leest `.mcp.json` automatisch (keur de server goed bij de prompt).
   Claude Desktop: voeg hetzelfde blok toe aan `claude_desktop_config.json` met een absoluut pad naar `src/index.js`.

Optioneel: `RPG_ACTOR_UID` (wie in de activiteitenlog staat, standaard `mcp`).

## Tools

| Tool | Doet |
|------|------|
| `list_households` | guilds + leden (voor het `guildId`) |
| `list_tasks` / `create_tasks` / `update_tasks` / `delete_tasks` | taak-templates, bulk aanmaken (dubbele titels worden overgeslagen) en gedeeltelijk wijzigen |
| `create_quest` | coop-quest met subtaken + bonus |
| `list_shop_items` / `create_shop_items` / `archive_shop_items` | shop in bulk |

Alle schrijf-tools hebben `dryRun` om eerst te previewen.

## Voorbeeldprompts

- "Maak voor huishouden X deze taken: stofzuigen (15 coins, wekelijks, cleaning), wc schoonmaken (20, wekelijks), prullenbak (5, dagelijks, admin). Doe eerst een dry run."
- "Voeg 10 shop-items toe met een gezellig thema, prijzen tussen 30 en 250, mix van rarities."
- "Maak een quest 'Voorjaarsschoonmaak' met 6 subtaken en 50 bonus coins."

## Nieuwe tools toevoegen

1. Veld-mapping/validatie in `src/mapping.js` (pure functies + test in `test/`).
2. Firestore-logica in `src/firestore.js`.
3. `server.registerTool(...)` in `src/index.js`.

`SKILLS` in `mapping.js` moet gelijk blijven aan `SkillType` in `lib/data/models/enums.dart` (index-volgorde!).

## Tests

```bash
npm test
```
Dekt de mapping/validatie. De Firestore-laag is niet getest tegen een echte database.
