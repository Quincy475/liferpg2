import { readFileSync } from "node:fs";
import { initializeApp, cert, applicationDefault, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { SKILLS, chunk, normTitle, toShopData, toTemplateData } from "./mapping.js";

const ACTOR = process.env.RPG_ACTOR_UID || "mcp";
const BATCH = 200; // ruim onder de 500-writes-limiet (docs + events)

let _db;
function db() {
  if (_db) return _db;
  if (!getApps().length) {
    const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    initializeApp({
      credential: keyPath ? cert(JSON.parse(readFileSync(keyPath, "utf8"))) : applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || "liferpg-2f2ae",
    });
  }
  _db = getFirestore();
  return _db;
}

const guild = (id) => db().collection("guilds").doc(id);

async function assertGuild(guildId) {
  const snap = await guild(guildId).get();
  if (!snap.exists) throw new Error(`Huishouden/guild "${guildId}" bestaat niet. Gebruik list_households.`);
  return snap;
}

const eventDoc = (guildId, type, extra) => ({
  type,
  templateId: null,
  instanceId: null,
  actorUserId: ACTOR,
  at: FieldValue.serverTimestamp(),
  payload: {},
  ...extra,
});

// ---------------------------------------------------------------- households
export async function listHouseholds() {
  const gs = await db().collection("guilds").get();
  const out = [];
  for (const g of gs.docs) {
    const members = await db().collection("users").where("guildId", "==", g.id).get();
    out.push({
      guildId: g.id,
      name: g.data().name ?? null,
      members: members.docs.map((m) => ({ uid: m.id, name: m.data().name ?? null })),
    });
  }
  return out;
}

// --------------------------------------------------------------------- tasks
export async function listTasks(guildId) {
  await assertGuild(guildId);
  const [tpl, groups] = await Promise.all([
    guild(guildId).collection("taskTemplates").where("active", "==", true).get(),
    guild(guildId).collection("taskGroups").get(),
  ]);
  const groupName = new Map(groups.docs.map((g) => [g.id, g.data().title]));
  return tpl.docs
    .map((d) => {
      const m = d.data();
      return {
        id: d.id,
        title: m.title,
        coins: m.coinsBase,
        schedule: m.scheduleType,
        skillTypeIndex: m.skillTypeIndex ?? null,
        quest: m.groupId ? groupName.get(m.groupId) ?? m.groupId : null,
      };
    })
    .sort((a, b) => a.title.localeCompare(b.title));
}

/**
 * Maakt task-templates aan. Slaat titels over die al bestaan (tenzij allowDuplicates).
 * De app genereert de instances zelf zodra de taken-pagina opent.
 */
export async function createTasks({ guildId, tasks, groupId = null, allowDuplicates = false, dryRun = false }) {
  await assertGuild(guildId);
  const col = guild(guildId).collection("taskTemplates");

  const existing = new Set();
  if (!allowDuplicates) {
    const snap = await col.where("active", "==", true).get();
    snap.docs.forEach((d) => existing.add(normTitle(d.data().title ?? "")));
  }

  const toCreate = [];
  const skipped = [];
  for (const t of tasks) {
    const key = normTitle(t.title);
    if (existing.has(key)) {
      skipped.push(t.title);
      continue;
    }
    existing.add(key); // ook dubbelen binnen dezelfde batch voorkomen
    toCreate.push({ t, data: toTemplateData(t, { groupId }) });
  }

  const created = [];
  if (!dryRun) {
    for (const part of chunk(toCreate, BATCH)) {
      const batch = db().batch();
      for (const { t, data } of part) {
        const ref = col.doc();
        batch.set(ref, {
          ...data,
          scheduledDate: data.scheduledDate ? Timestamp.fromDate(new Date(`${data.scheduledDate}T00:00:00`)) : null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        batch.set(
          guild(guildId).collection("taskEvents").doc(),
          eventDoc(guildId, "created_template", { templateId: ref.id, payload: { title: t.title } }),
        );
        created.push({ id: ref.id, title: t.title });
      }
      await batch.commit();
    }
  } else {
    toCreate.forEach(({ t }) => created.push({ id: "(dry-run)", title: t.title }));
  }
  return { dryRun, created, skippedAsDuplicate: skipped };
}

export async function createQuest({ guildId, title, description = "", skill, bonusCoins = 0, subtasks, dryRun = false }) {
  await assertGuild(guildId);
  let groupId = "(dry-run)";
  if (!dryRun) {
    const ref = guild(guildId).collection("taskGroups").doc();
    await ref.set({
      title,
      description,
      skillTypeIndex: skill ? SKILLS.indexOf(skill) : null,
      bonusCoins,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await guild(guildId).collection("taskEvents").add(eventDoc(guildId, "created_group", { payload: { title } }));
    groupId = ref.id;
  }
  const res = await createTasks({
    guildId,
    // subtaken erven de skill van de quest als ze er zelf geen hebben
    tasks: subtasks.map((s) => ({ ...s, skill: s.skill ?? skill })),
    groupId: dryRun ? null : groupId,
    allowDuplicates: true,
    dryRun,
  });
  return { groupId, quest: title, ...res };
}

/** Verwijdert templates + hun open instances (zoals de app: archiveTemplate). */
export async function deleteTasks({ guildId, templateIds, dryRun = false }) {
  await assertGuild(guildId);
  const col = guild(guildId).collection("taskTemplates");
  const deleted = [];
  const notFound = [];
  for (const id of templateIds) {
    const snap = await col.doc(id).get();
    if (!snap.exists) {
      notFound.push(id);
      continue;
    }
    deleted.push({ id, title: snap.data().title });
    if (dryRun) continue;
    const open = await guild(guildId)
      .collection("taskInstances")
      .where("templateId", "==", id)
      .where("status", "in", ["open", "claimed"])
      .get();
    const batch = db().batch();
    open.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(snap.ref);
    batch.set(
      guild(guildId).collection("taskEvents").doc(),
      eventDoc(guildId, "deleted_template", { templateId: id, payload: { title: snap.data().title } }),
    );
    await batch.commit();
  }
  return { dryRun, deleted, notFound };
}

// ---------------------------------------------------------------------- shop
export async function listShopItems(guildId) {
  await assertGuild(guildId);
  const snap = await guild(guildId).collection("shopItems").orderBy("price").get();
  return snap.docs
    .filter((d) => (d.data().active ?? true) === true)
    .map((d) => ({ id: d.id, ...pick(d.data(), ["name", "price", "icon", "rarity", "category", "isGuildItem", "isSpecial", "description"]) }));
}

const pick = (o, keys) => Object.fromEntries(keys.map((k) => [k, o[k] ?? null]));

export async function createShopItems({ guildId, items, overwrite = false, dryRun = false }) {
  await assertGuild(guildId);
  const col = guild(guildId).collection("shopItems");

  const created = [];
  const skipped = [];
  const plan = [];

  // bestaande namen om dubbelen te voorkomen (naast vaste id's)
  const existingNames = new Set();
  const snap = await col.get();
  snap.docs.forEach((d) => {
    if ((d.data().active ?? true) === true) existingNames.add(normTitle(d.data().name ?? ""));
  });

  for (const i of items) {
    const ref = i.id ? col.doc(i.id) : col.doc();
    const nameKey = normTitle(i.name);
    const idExists = i.id ? (await ref.get()).exists : false;
    if (!overwrite && (idExists || existingNames.has(nameKey))) {
      skipped.push(i.name);
      continue;
    }
    existingNames.add(nameKey);
    plan.push({ i, ref });
  }

  for (const part of chunk(plan, BATCH)) {
    const batch = db().batch();
    for (const { i, ref } of part) {
      if (!dryRun) {
        batch.set(
          ref,
          {
            ...toShopData(i),
            id: ref.id, // de app leest ook het id-veld
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      created.push({ id: dryRun ? "(dry-run)" : ref.id, name: i.name, price: i.price });
    }
    if (!dryRun) await batch.commit();
  }
  return { dryRun, created, skippedAsDuplicate: skipped };
}

export async function archiveShopItems({ guildId, itemIds, dryRun = false }) {
  await assertGuild(guildId);
  const col = guild(guildId).collection("shopItems");
  const archived = [];
  const notFound = [];
  const batch = db().batch();
  for (const id of itemIds) {
    const snap = await col.doc(id).get();
    if (!snap.exists) {
      notFound.push(id);
      continue;
    }
    archived.push({ id, name: snap.data().name });
    batch.set(snap.ref, { active: false, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  if (!dryRun && archived.length) await batch.commit();
  return { dryRun, archived, notFound };
}
