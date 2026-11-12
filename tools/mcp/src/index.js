#!/usr/bin/env node
// Household RPG MCP-server (stdio). Schrijft rechtstreeks naar dezelfde Firestore
// als de app (firebase-admin, dus Firestore-rules worden omzeild: alleen lokaal draaien).
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { SKILLS, shopItemSchema, taskSchema, taskUpdateSchema } from "./mapping.js";
import * as fs from "./firestore.js";

const server = new McpServer({ name: "household-rpg", version: "0.1.0" });

const guildId = z.string().min(1).describe("Guild/huishouden-id uit list_households.");
const dryRun = z.boolean().default(false)
  .describe("true = alleen laten zien wat er aangemaakt zou worden, niets schrijven.");

const ok = (data) => ({ content: [{ type: "text", text: JSON.stringify(data, null, 2) }] });
const fail = (e) => ({ isError: true, content: [{ type: "text", text: `Fout: ${e instanceof Error ? e.message : String(e)}` }] });
const run = (fn) => async (args) => {
  try {
    return ok(await fn(args));
  } catch (e) {
    return fail(e);
  }
};

const READ = { readOnlyHint: true };
const WRITE = { readOnlyHint: false, destructiveHint: false, idempotentHint: false };
const DESTRUCTIVE = { readOnlyHint: false, destructiveHint: true, idempotentHint: true };

server.registerTool("list_households", {
  title: "Huishoudens tonen",
  description: "Lijst alle guilds (huishoudens/duo's) met leden. Start hier om het guildId te vinden.",
  inputSchema: {},
  annotations: READ,
}, run(() => fs.listHouseholds()));

server.registerTool("list_tasks", {
  title: "Taken tonen",
  description: "Toont alle actieve taak-templates van een huishouden (id, titel, coins, schema, quest).",
  inputSchema: { guildId },
  annotations: READ,
}, run(({ guildId }) => fs.listTasks(guildId)));

server.registerTool("create_tasks", {
  title: "Taken in bulk aanmaken",
  description:
    `Maakt meerdere taken tegelijk aan in een huishouden. Titels die al bestaan worden overgeslagen. ` +
    `Skills: ${SKILLS.join(", ")}. Tip: roep eerst aan met dryRun=true om te laten controleren.`,
  inputSchema: {
    guildId,
    tasks: z.array(taskSchema).min(1).max(200),
    allowDuplicates: z.boolean().default(false),
    dryRun,
  },
  annotations: WRITE,
}, run((a) => fs.createTasks(a)));

server.registerTool("update_tasks", {
  title: "Taken wijzigen",
  description:
    "Wijzigt bestaande taken op id (titel, coins, skill, schema, deadline-uur). Alleen meegegeven velden veranderen. " +
    "Bij een ander schema of deadline worden open instances opnieuw door de app aangemaakt.",
  inputSchema: { guildId, updates: z.array(taskUpdateSchema).min(1).max(200), dryRun },
  annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
}, run((a) => fs.updateTasks(a)));

server.registerTool("create_quest", {
  title: "Coop-quest aanmaken",
  description:
    "Maakt een coop-quest (grote klus) met subtaken. Als alle subtaken klaar zijn krijgt iedereen de bonus. " +
    "Subtaken erven de skill van de quest.",
  inputSchema: {
    guildId,
    title: z.string().trim().min(1).max(120),
    description: z.string().max(500).default(""),
    skill: z.enum(SKILLS).optional(),
    bonusCoins: z.number().int().min(0).max(100000).default(0),
    subtasks: z.array(taskSchema).min(1).max(100),
    dryRun,
  },
  annotations: WRITE,
}, run((a) => fs.createQuest(a)));

server.registerTool("delete_tasks", {
  title: "Taken verwijderen",
  description: "Verwijdert taak-templates (en hun open instances) op id. Niet terug te draaien; gebruik eerst dryRun.",
  inputSchema: { guildId, templateIds: z.array(z.string().min(1)).min(1).max(200), dryRun },
  annotations: DESTRUCTIVE,
}, run((a) => fs.deleteTasks(a)));

server.registerTool("list_shop_items", {
  title: "Shop-items tonen",
  description: "Toont alle actieve shop-items van een huishouden, gesorteerd op prijs.",
  inputSchema: { guildId },
  annotations: READ,
}, run(({ guildId }) => fs.listShopItems(guildId)));

server.registerTool("create_shop_items", {
  title: "Shop-items in bulk aanmaken",
  description:
    "Maakt meerdere shop-items tegelijk aan. Items met dezelfde naam of id worden overgeslagen, " +
    "tenzij overwrite=true. Rarity: common, rare, epic, legendary.",
  inputSchema: {
    guildId,
    items: z.array(shopItemSchema).min(1).max(200),
    overwrite: z.boolean().default(false),
    dryRun,
  },
  annotations: WRITE,
}, run((a) => fs.createShopItems(a)));

server.registerTool("archive_shop_items", {
  title: "Shop-items archiveren",
  description: "Verbergt shop-items (active=false) op id. Terug te zetten met create_shop_items overwrite=true.",
  inputSchema: { guildId, itemIds: z.array(z.string().min(1)).min(1).max(200), dryRun },
  annotations: DESTRUCTIVE,
}, run((a) => fs.archiveShopItems(a)));

await server.connect(new StdioServerTransport());
console.error("household-rpg MCP-server draait (stdio).");
