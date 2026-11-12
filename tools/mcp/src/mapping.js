// Pure mapping/validatie-laag: zet tool-input om naar exact dezelfde veldvormen
// als de Flutter-app (TaskTemplate.toMap / ShopItem.toMap). Geen Firebase-import,
// zodat dit zonder credentials te testen is.
import { z } from "zod";

// LET OP: de app slaat skills op als index in deze volgorde (enums.dart).
// Alleen achteraan toevoegen, nooit herschikken.
export const SKILLS = ["cooking", "cleaning", "fixing", "laundry", "admin"];
export const SCHEDULES = ["once", "daily", "weekly", "monthly", "everyXDays"];
export const RARITIES = ["common", "rare", "epic", "legendary"];

export const taskSchema = z.object({
  title: z.string().trim().min(1).max(120),
  coins: z.number().int().min(0).max(100000).default(5)
    .describe("Coins die de taak oplevert (xp volgt hieruit)."),
  description: z.string().max(500).default(""),
  skill: z.enum(SKILLS).optional().describe("Skill die XP krijgt."),
  schedule: z.enum(SCHEDULES).default("daily")
    .describe("once = eenmalig (gebruik date), daily/weekly/monthly, of everyXDays (gebruik intervalDays)."),
  intervalDays: z.number().int().min(1).max(365).default(1),
  dueHour: z.number().int().min(0).max(23).default(22).describe("Deadline-uur (0-23)."),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "verwacht YYYY-MM-DD").optional()
    .describe("Alleen voor schedule=once."),
});

export const shopItemSchema = z.object({
  name: z.string().trim().min(1).max(80),
  price: z.number().int().min(0).max(1000000),
  description: z.string().max(300).default(""),
  icon: z.string().max(8).default("🛍️").describe("Eén emoji."),
  category: z.string().max(40).default("general").describe("bv. decoration, buff, utility."),
  rarity: z.enum(RARITIES).default("common"),
  isGuildItem: z.boolean().default(false).describe("true = gedeelde upgrade voor het hele huishouden."),
  isSpecial: z.boolean().default(false),
  requiresTicketId: z.string().optional(),
  id: z.string().regex(/^[a-z0-9_]{1,60}$/).optional()
    .describe("Optioneel vaste slug-id (a-z, 0-9, _). Weglaten = automatisch id."),
});

/** Eén taak → template-velden zoals TaskTemplate.toMap (zonder timestamps). */
export function toTemplateData(t, { groupId = null } = {}) {
  const once = t.schedule === "once";
  if (once && !t.date) {
    throw new Error(`Taak "${t.title}": schedule "once" vereist een date (YYYY-MM-DD).`);
  }
  return {
    title: t.title,
    description: t.description,
    coinsBase: t.coins,
    isRepeatable: !once,
    scheduleType: once ? "custom" : t.schedule,
    intervalValue: t.schedule === "everyXDays" ? t.intervalDays : 1,
    defaultAssigneeUserId: null,
    claimableByUserIds: [],
    takeoverAfterMinutes: t.schedule === "weekly" ? WEEKLY_TAKEOVER_MINUTES : 60, // anders: default van de taakdialoog
    carryOverPolicy: "double_next_success",
    active: true,
    dueHour: t.dueHour,
    scheduledDate: once ? t.date : null, // firestore-laag maakt hier een Timestamp van
    skillTypeIndex: t.skill ? SKILLS.indexOf(t.skill) : null,
    groupId,
  };
}

/** Eén shop-item → velden zoals ShopItem.toMap (+ active). */
export function toShopData(i) {
  return {
    name: i.name,
    description: i.description,
    icon: i.icon,
    price: i.price,
    isGuildItem: i.isGuildItem,
    isSpecial: i.isSpecial,
    rarity: i.rarity,
    category: i.category,
    requiresTicketId: i.requiresTicketId ?? null,
    active: true,
  };
}

/** Splits in stukken (Firestore-batches max 500 writes). */
export function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// Een wekelijkse instance staat op maandag (deadline dueHour). Met de standaard 60 minuten
// marktovername markeert de app hem op dinsdag al als "missed" en verdwijnt hij uit beeld.
// Voor "ergens deze week" blijft hij daarom open tot zondag 23:00.
export const WEEKLY_TAKEOVER_MINUTES = 8700;

export const normTitle = (s) => s.trim().toLowerCase().replace(/\s+/g, " ");
