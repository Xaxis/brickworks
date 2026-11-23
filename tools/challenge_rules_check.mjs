// The site's check of a challenge's rules, on 30 published models under three
// rules (most_parts, a set, Tested), written out for the studio's to be
// compared with (src/dev/challenge_rules_probe.gd, unit challengestudio): the
// studio ticks a challenge's rules on the model as it is built
// (src/net/challenge_rules.gd), and its tick must be the site's answer.
//
//   set -a; . ./.env; set +a
//   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/challenge_rules_check.mjs --out=DIR
//   ~/.claude/claude-core/bin/heavy godot --headless --path . --script src/dev/challenge_rules_probe.gd -- --fixtures=DIR
//
// The site's answer is supabase/challenges.sql challenge_check itself, run on
// the live project inside a transaction that is rolled back: three test
// challenges made in it (nothing kept), each model checked against each.
// Two ways, both written:
//
//   stored     the models as the database keeps them: their parts, their
//              needs (model_needs) as they were counted at their publish
//   published  each model's needs and parts as a publish today counts its
//              file (api/share.js checkModel, api/_owned.js keyed: the same
//              code a publish runs), kept in the transaction first. This is
//              what the site would say of the model published now, which is
//              what the studio's tick promises; a stored count made by an
//              older publish (an older catalogue, an older checkModel) can
//              differ from it, and says so
//
// The rules: at most the median of the 30 models' parts (about half pass); a
// set whose lots are the needs of the first ten models, each as many as the
// most any of them needs, less one of the lot the eleventh needs most (some
// pass, some are one lot short, most are many short); and Tested. The models:
// the 15 newest published that are marked Tested and the 15 newest that are
// not, none a test account's, each of at most 2,500 parts so the probe's
// Tested runs end in minutes, in the order they were published.
//
// Reads the live database and the models' files; writes nothing that stays.

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { checkModel } from "../api/share.js";
import { keyed, ownedFacts } from "../api/_owned.js";

const out = (process.argv.find((a) => a.startsWith("--out=")) || "").slice(6);
if (!out) {
  console.error("challenge_rules_check: say where: --out=DIR");
  process.exit(2);
}
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET || !process.env.PG_MODULE) {
  console.error("challenge_rules_check: needs SUPABASE_URL, SUPABASE_SECRET_KEY and PG_MODULE");
  process.exit(2);
}
const MODELS = 30;
mkdirSync(join(out, "models"), { recursive: true });

const pg = (await import(process.env.PG_MODULE)).default;
const client = new pg.Client({ host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD, database: "postgres",
  ssl: { rejectUnauthorized: false } });
await client.connect();
const q = async (sql, args = []) => (await client.query(sql, args)).rows;

async function file(id) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${id}.mpd`, {
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` }, signal: AbortSignal.timeout(30000) });
  return reply.ok ? reply.text() : null;
}

const facts = ownedFacts();
console.log(`the catalogue's facts: ${facts.known ? facts.known.size : 0} parts known, ${facts.moved.size} moved, `
  + `${facts.plain.size} plain colours`);

let code = 0;
await client.query("begin");
try {
  const half = (marked) => q(`select m.id, m.parts, m.created_at from public.shared_models m
     where m.published and not m.test and m.parts <= 2500 and public.model_tested(m.id) = $2
     order by m.updated_at desc limit $1`, [MODELS / 2, marked]);
  const rows = [...await half(true), ...await half(false)]
    .sort((a, b) => String(a.created_at.toISOString()).localeCompare(b.created_at.toISOString()));
  const models = [];
  for (const row of rows) {
    const text = await file(row.id);
    if (!text) throw new Error(`${row.id}: its file is not there`);
    const counted = checkModel(text);
    const needs = keyed(counted.needs);
    writeFileSync(join(out, "models", `${row.id}.mpd`), text);
    models.push({ id: row.id, stored_parts: Number(row.parts), parts: counted.parts, needs });
  }
  if (models.length < MODELS) throw new Error(`only ${models.length} models to check`);

  // The rules.
  const sorted = models.map((one) => one.parts).sort((a, b) => a - b);
  const most = sorted[Math.floor(sorted.length / 2)];
  const lots = new Map();
  for (const one of models.slice(0, 10)) {
    for (const lot of one.needs) {
      const key = `${lot.part}/${lot.colour}`;
      lots.set(key, { ...lot, qty: Math.max(lot.qty, lots.get(key)?.qty || 0) });
    }
  }
  // The eleventh's biggest lot, one short.
  const eleventh = [...models[10].needs].sort((a, b) => b.qty - a.qty)[0];
  for (const lot of models[10].needs) {
    const key = `${lot.part}/${lot.colour}`;
    const qty = Math.max(lot.qty, lots.get(key)?.qty || 0);
    lots.set(key, { ...lot, qty: key === `${eleventh.part}/${eleventh.colour}` ? Math.max(1, lot.qty - 1) : qty });
  }
  const setLots = [...lots.values()];
  // Any test challenge a flow left open is ended first: nothing here is kept.
  await q("update public.challenges set ended_at = now() where test and ended_at is null and kind = 'month'");
  const made = async (title, rules) => (await q(`insert into public.challenges (title, brief, starts_on, ends_on,
      most_parts, set_number, set_name, tested, test)
    values ($1, 'The studio check', current_date - 1, current_date + 5, $2, $3, $4, $5, true) returning id`,
  [title, rules.most_parts ?? null, rules.set_number ?? null, rules.set_name ?? null, rules.tested === true]))[0].id;
  const challenges = [
    { kind: "parts", id: await made("Studio check: parts", { most_parts: most }),
      rules: { most_parts: most, set: null, tested: false } },
    { kind: "set", id: await made("Studio check: a set", { set_number: "31009-1", set_name: "The studio check's set" }),
      rules: { most_parts: null, set: { number: "31009-1", name: "The studio check's set",
        lots: setLots.map((lot) => [lot.part, lot.colour, lot.qty]) }, tested: false } },
    { kind: "tested", id: await made("Studio check: Tested", { tested: true }),
      rules: { most_parts: null, set: null, tested: true } },
  ];
  for (const lot of setLots) {
    await q("insert into public.challenge_set_parts (challenge, part, colour, qty) values ($1, $2, $3, $4)",
      [challenges[1].id, lot.part, lot.colour, lot.qty]);
  }
  // The set's lots as the studio is given them (challenge_set_lots, when
  // supabase/challenge_studio.sql is applied).
  const asKept = await q("select to_regprocedure('public.challenge_set_lots(bigint)') is not null as there");
  if (asKept[0].there) {
    const kept = (await q("select public.challenge_set_lots($1) as lots", [challenges[1].id]))[0].lots;
    challenges[1].rules.set.lots = kept.map((one) => [one.part, one.colour, one.qty]);
  }

  const checkAll = async () => {
    const said = {};
    for (const one of models) {
      said[one.id] = {};
      for (const c of challenges) {
        said[one.id][c.kind] = (await q("select public.challenge_check($1, $2) as c", [c.id, one.id]))[0].c;
      }
    }
    return said;
  };
  const tested = {};
  for (const one of models) tested[one.id] = (await q("select public.model_tested($1) as t", [one.id]))[0].t === true;
  const stored = await checkAll();
  // As a publish today counts each file.
  for (const one of models) {
    await q("select public.owned_keep_needs($1, $2::jsonb)", [one.id, JSON.stringify(one.needs)]);
    await q("update public.shared_models set parts = $2 where id = $1", [one.id, one.parts]);
  }
  const published = await checkAll();
  writeFileSync(join(out, "site.json"), `${JSON.stringify({
    at: new Date().toISOString(), most_parts: most, set_lots: setLots.length,
    challenges: challenges.map((c) => ({ kind: c.kind, rules: c.rules })),
    models: models.map((one) => ({ id: one.id, parts: one.parts, stored_parts: one.stored_parts, lots: one.needs.length,
      tested: tested[one.id] })),
    stored, published }, null, 1)}\n`);
  const passes = (said, kind) => models.filter((one) => said[one.id][kind]?.ok === true).length;
  console.log(`${models.length} models; most_parts ${most}: ${passes(published, "parts")} pass; the set's ${setLots.length} lots: `
    + `${passes(published, "set")} pass; Tested: ${passes(published, "tested")} pass`);
  const moved = models.filter((one) => JSON.stringify(stored[one.id]) !== JSON.stringify(published[one.id]));
  console.log(`stored and published counts answer differently for ${moved.length}: ${moved.map((one) => one.id).join(" ")}`);
} catch (trouble) {
  console.error(`challenge_rules_check: ${trouble.stack || trouble}`);
  code = 1;
} finally {
  await client.query("rollback");
  await client.end();
}
console.log(`rolled back: nothing kept; written to ${out}`);
process.exit(code);
