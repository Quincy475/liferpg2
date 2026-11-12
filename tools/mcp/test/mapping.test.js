import { test } from "node:test";
import assert from "node:assert/strict";
import { SKILLS, chunk, normTitle, shopItemSchema, taskSchema, toShopData, toTemplateData } from "../src/mapping.js";

test("skill-volgorde komt overeen met SkillType-enum in de app", () => {
  assert.deepEqual(SKILLS, ["cooking", "cleaning", "fixing", "laundry", "admin"]);
});

test("taak: defaults + mapping naar TaskTemplate-velden", () => {
  const t = taskSchema.parse({ title: " Afwas ", skill: "cleaning", coins: 8 });
  const d = toTemplateData(t);
  assert.equal(d.title, "Afwas");
  assert.equal(d.coinsBase, 8);
  assert.equal(d.scheduleType, "daily");
  assert.equal(d.isRepeatable, true);
  assert.equal(d.skillTypeIndex, 1);
  assert.equal(d.dueHour, 22);
  assert.equal(d.takeoverAfterMinutes, 60);
  assert.equal(d.groupId, null);
});

test("taak: once wordt custom/niet-herhaalbaar en vereist date", () => {
  const t = taskSchema.parse({ title: "Kast", schedule: "once", date: "2026-12-01" });
  const d = toTemplateData(t, { groupId: "g1" });
  assert.equal(d.scheduleType, "custom");
  assert.equal(d.isRepeatable, false);
  assert.equal(d.scheduledDate, "2026-12-01");
  assert.equal(d.groupId, "g1");
  assert.throws(() => toTemplateData(taskSchema.parse({ title: "x", schedule: "once" })), /date/);
});

test("taak: ongeldige input wordt geweigerd", () => {
  assert.throws(() => taskSchema.parse({ title: "" }));
  assert.throws(() => taskSchema.parse({ title: "a", skill: "gaming" }));
  assert.throws(() => taskSchema.parse({ title: "a", dueHour: 24 }));
});

test("shop: defaults + mapping", () => {
  const i = shopItemSchema.parse({ name: "Kaars", price: 60, rarity: "rare" });
  const d = toShopData(i);
  assert.equal(d.icon, "🛍️");
  assert.equal(d.category, "general");
  assert.equal(d.isGuildItem, false);
  assert.equal(d.requiresTicketId, null);
  assert.equal(d.active, true);
  assert.throws(() => shopItemSchema.parse({ name: "x", price: -1 }));
});

test("helpers", () => {
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assert.equal(normTitle("  Was   Draaien "), "was draaien");
});
