// hairreview (review of sitehair, 2026-11-25): concrete inputs against
// POST/GET /api/people?op=mould(s) through the app's own routes, on a relay
// at production Supabase, with throwaway accounts deleted at the end.
//
//   node --env-file=.env tools/web/relay_server.mjs 12170   (detached)
//   node --env-file=.env tools/web/hairreview_attack.mjs --url=http://127.0.0.1:12170 --mould=FILE [--probe]
//
// FILE is a mould the app made (sitehair's relay5/studio_mould.dat).
// A. A title whose 120th UTF-16 unit is half an emoji: the list name is cut
//    there, and the save is answered as if another save took the room.
// B. A worn 2 MB mould: what a signed-out stranger's read costs, uncached.
// C. 40 moulds: the 41st refused, and nothing removes one.
// --probe: D. src/dev/hairreview_carry_probe.gd, signed in as Ada and Cy.
import { deleteAccount, mintSession } from "./session.mjs";
import { idOf } from "../../api/_moulds.js";
import { encode } from "../../api/_jpeg.js";
import { PLAIN } from "../../web/minifig-parts.js";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const site = String(args.url || "").replace(/\/+$/, "");
const studio = readFileSync(path.resolve(String(args.mould)), "utf8");
const out = path.resolve(String(args.out || "."));
mkdirSync(out, { recursive: true });
const rand = randomBytes(4).toString("hex");
const said = [];
const log = (line) => { console.log(line); said.push(line); };

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = {};
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const t = Date.now();
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const raw = Buffer.from(await reply.arrayBuffer());
  let json = null;
  try { json = JSON.parse(raw.toString("utf8")); } catch { /* not json */ }
  return { status: reply.status, bytes: raw.length, ms: Date.now() - t, cache: reply.headers.get("cache-control") || "", json };
}

/// [text] (a mould with id [was]) given the first line [first] and an
/// optional comment [pad]: its new text and its own id, as the app names one.
function variant(text, was, first, pad = "") {
  const lines = text.split(was).join("\u0000").split("\n");
  lines[0] = first;
  if (pad) lines.splice(1, 0, pad);
  const holed = lines.join("\n");
  const id = idOf(holed.split("\u0000").join(""), "\u0000\u0000never\u0000", "3901");
  return { id, text: holed.split("\u0000").join(id) };
}
const studioId = /^0 Name: (\S+)\.dat$/m.exec(studio)[1];
// The smallest a mould may be: what the edge asks of one, and a triangle.
const tiny = (n) => {
  const hole = "\u0000";
  const holed = [`0 Minifig Hair Male, Custom Mould Try ${n}`, `0 Name: ${hole}.dat`, "0 // Moulded by Brickworks: from=3901 triangles=1",
    `3 16 0 0 0 ${n % 10} 1 0 0 0 1`, "0", ""].join("\n");
  const id = idOf(holed.split(hole).join(""), "\u0000\u0000never\u0000", "3901");
  return { id, text: holed.split(hole).join(id) };
};

const emails = { eve: `delivered+bw-hairreview-eve-${rand}@resend.dev`, ada: `delivered+bw-hairreview-ada-${rand}@resend.dev`,
  cy: `delivered+bw-hairreview-cy-${rand}@resend.dev` };
const who = {};
try {
  if (!args.onlyprobe) await attacks();
  if (args.probe || args.onlyprobe) await probe();
} finally {
  const ids = [];
  for (const [name, session] of Object.entries(who)) {
    if (!session) continue;
    ids.push(session.kept.user_id);
    log(`${name}'s account deleted: ${await deleteAccount(emails[name])}`);
  }
  if (ids.length && process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY) {
    const key = process.env.SUPABASE_SECRET_KEY;
    const left = await fetch(`${process.env.SUPABASE_URL}/rest/v1/own_moulds?account=in.(${ids.join(",")})&select=id`,
      { headers: { apikey: key, authorization: `Bearer ${key}` } }).then((a) => a.json()).catch(() => null);
    log(`own_moulds rows left of theirs: ${JSON.stringify(left)}`);
  }
  writeFileSync(path.join(out, args.onlyprobe ? "probe.txt" : "attack.txt"), `${said.join("\n")}\n`);
}

async function attacks() {
  who.eve = await mintSession(emails.eve);
  const eve = who.eve.access_token;
  let r = await api("/api/people?op=profile", { method: "POST", token: eve, body: { handle: `hairrev-${rand}`, name: "Eve Review" } });
  log(`Eve's profile: ${r.status}`);

  log("\nA. a title whose 120th UTF-16 unit is half an emoji");
  const prefix = "0 Minifig Hair Male, Custom Mould ";
  for (const k of [86, 87]) {
    const title = `${"a".repeat(k)}\u{1F525} quiff`;
    const one = variant(studio, studioId, prefix + title);
    const name = `${prefix.slice(2)}${title}`;
    r = await api("/api/people?op=mould", { method: "POST", token: eve, body: { id: one.id, slot: "headwear", text: one.text } });
    const listed = (await api("/api/people?op=moulds", { token: eve })).json?.moulds || [];
    const lone = /[\ud800-\udbff]$/.test(name.slice(0, 120));
    log(`  title of ${k} letters and an emoji (the name cut at 120 ${lone ? "splits the emoji" : "keeps it whole"}): `
      + `${r.status} ${JSON.stringify(r.json)}; the account lists ${listed.length}`);
  }

  log("\nB. a worn mould of 2 MB, read by a stranger signed out");
  const big = variant(studio, studioId, `${prefix}Heavy`, `0 // ${"x".repeat(2 * 1024 * 1024 - studio.length - 200)}`);
  r = await api("/api/people?op=mould", { method: "POST", token: eve, body: { id: big.id, slot: "headwear", text: big.text } });
  log(`  kept, ${Buffer.byteLength(big.text)} bytes: ${r.status} ${JSON.stringify(r.json)}`);
  const picture = Buffer.from(encode({ data: new Uint8Array(320 * 320 * 4).fill(180), width: 320, height: 320 }, 85).data);
  r = await api("/api/people?op=avatar", { method: "POST", token: eve,
    body: { picture: picture.toString("base64"), type: "image/jpeg", minifig: { ...PLAIN, hd: big.id } } });
  log(`  worn as her avatar's hair: ${r.status} ${r.json?.error || ""}`);
  for (const tail of ["", "&v=1", "&v=2"]) {
    r = await api(`/api/people?op=mould&id=${big.id}${tail}`);
    log(`  GET ?op=mould&id=…${tail} signed out: ${r.status}, ${r.bytes} bytes in ${r.ms} ms, cache-control "${r.cache}"`);
  }

  log("\nC. forty moulds, then one more");
  let kept = 0;
  for (let n = 0; n < 39; n++) {
    const one = tiny(n);
    r = await api("/api/people?op=mould", { method: "POST", token: eve, body: { id: one.id, slot: "headwear", text: one.text } });
    if (r.status === 200) kept += 1;
    else log(`  try ${n}: ${r.status} ${JSON.stringify(r.json)}`);
  }
  const listed = (await api("/api/people?op=moulds", { token: eve })).json?.moulds || [];
  log(`  39 more kept: ${kept}; the account lists ${listed.length}`);
  const more = tiny(99);
  r = await api("/api/people?op=mould", { method: "POST", token: eve, body: { id: more.id, slot: "headwear", text: more.text } });
  log(`  the 41st: ${r.status} ${JSON.stringify(r.json)}`);
  for (const op of ["mould_remove", "mould_delete", "moulds_remove"]) {
    r = await api(`/api/people?op=${op}`, { method: "POST", token: eve, body: { id: listed[0]?.id } });
    log(`  POST ?op=${op}: ${r.status} ${JSON.stringify(r.json)}`);
  }
  r = await api(`/api/people?op=mould&id=${listed[0]?.id}`, { method: "DELETE", token: eve });
  log(`  DELETE ?op=mould: ${r.status} ${JSON.stringify(r.json)}`);
  r = await api("/api/people?op=avatar_remove", { method: "POST", token: eve, body: {} });
  log(`  her avatar taken off (cleanup): ${r.status}`);
}

async function probe() {
  log("\nD. the studio: a carried mould, and a shared device (src/dev/hairreview_carry_probe.gd)");
  who.ada = await mintSession(emails.ada);
  who.cy = await mintSession(emails.cy);
  const carried = path.join(out, "bo_mould.dat");
  writeFileSync(carried, studio);
  const ran = spawnSync("bash", ["tools/probe.sh", "hairreview_carry_probe"], { cwd: root, encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"], env: { ...process.env, BRICKWORKS_API: site,
      BW_PROBE_TOKEN: who.ada.access_token, BW_PROBE_USER: who.ada.kept.user_id,
      BW_PROBE_TOKEN2: who.cy.access_token, BW_PROBE_USER2: who.cy.kept.user_id, BW_CARRIED: carried, PROBE_TIMEOUT: "900" } });
  writeFileSync(path.join(out, "carry_probe.log"), `${ran.stdout}\n${ran.stderr}`);
  for (const line of String(ran.stdout).split("\n").filter((l) => /^(SEEN|FINDING|CLEAN|hairreview)/.test(l))) log(`  ${line}`);
  log(`  probe exit ${ran.status}`);
}
