// Put the project's own showcase models in the gallery, so it is not empty
// on its first day.
//
//   set -a; . ./.env; set +a
//   godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- --seed-list=SEEDS.json --seed-out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/gallery_seed.mjs --url=<deployment> --dir=DIR [--dry]
//     [--only=A-B] [--collection="NAME" --collection-about="WORDS"]
//
// DIR holds what the app's Share panel sent for each model (gallery_seed.gd):
// its LDraw, its picture, its title, its credit, listed. Each is published
// to <deployment>/api/share — the same endpoint, checks and limits as anyone's
// publish — as the project's own account (GALLERY_EMAIL, gallery@brickworks.diy
// unless said; signed in the way the tests are, a code minted with the secret
// key and sent nowhere). A model that account already shares under the same
// title is updated at its link rather than shared twice, so running it again
// changes those rows and no others, each its next version (and a note in
// the list is what that version changed; a first version has none). --dry
// says what it would do.
//
// --only=A-B publishes bodies A to B of DIR (1-6, 7-12, ...): the site lists
// six an hour and twenty a day from one account (supabase/gallery.sql
// may_list), so a longer shelf goes up a slice an hour. --collection puts
// each model published in the account's public collection of that name,
// made (with --collection-about as its words) when it has none: the shelf
// from the LDraw library is "From the LDraw library" (gallery261).
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url || !args.dir) {
  console.error("gallery_seed: --url=<deployment> --dir=DIR");
  process.exit(2);
}
const base = String(args.url).replace(/\/+$/, "");
const EMAIL = process.env.GALLERY_EMAIL || "gallery@brickworks.diy";
const headers = { "content-type": "application/json" };
if (process.env.BW_BYPASS) headers["x-vercel-protection-bypass"] = process.env.BW_BYPASS;

const [least, most] = args.only ? String(args.only).split("-").map(Number) : [1, Infinity];
if (!(least >= 1 && (most >= least || most === undefined))) {
  console.error("gallery_seed: --only=A-B, the bodies' numbers, from 1");
  process.exit(2);
}
const bodies = readdirSync(args.dir).filter((f) => /^\d+\.json$/.test(f))
  .map((f) => parseInt(f, 10)).filter((n) => n >= least && n <= (most ?? least))
  .sort((a, b) => a - b)
  .map((n) => JSON.parse(readFileSync(join(args.dir, `${n}.json`), "utf8")));
if (!bodies.length) {
  console.error(`gallery_seed: no bodies in ${args.dir} (src/dev/gallery_seed.gd writes them)`);
  process.exit(2);
}

const { access_token: token } = await mintSession(EMAIL);
const auth = { ...headers, authorization: `Bearer ${token}` };
const mine = await (await fetch(`${base}/api/share?op=mine`, { headers: auth })).json();
const byName = new Map((mine.shared || []).map((row) => [row.name, row.id]));

// The collection they go in, the account's own of that name, or one made.
let list = null;
if (args.collection) {
  const me = await (await fetch(`${base}/api/people?op=me`, { headers: auth })).json();
  list = (me.collections || []).find((one) => one.name === String(args.collection)) || null;
  if (!list && !args.dry) {
    const made = await fetch(`${base}/api/people?op=collection`, { method: "POST", headers: auth,
      body: JSON.stringify({ name: String(args.collection), description: String(args["collection-about"] || ""),
        public: true }) });
    list = await made.json().catch(() => null);
    if (made.status !== 200 || !list?.id) {
      console.error(`gallery_seed: could not make the collection: ${made.status} ${list?.error || ""}`);
      process.exit(1);
    }
    console.log(`  made the collection "${list.name}": ${list.url}`);
  }
  if (args.dry) console.log(`  would put them in ${list ? `the collection ${list.id}` : `a new collection "${args.collection}"`}`);
}

let failed = 0;
// The last first: the gallery is newest first, so it then shows them in
// the order given.
for (const body of [...bodies].reverse()) {
  const id = byName.get(body.name);
  const { note, ...rest } = body;
  const sending = { ...rest, listed: true, ...(id ? { id, ...(note ? { note } : {}) } : {}) };
  if (args.dry) {
    console.log(`  would ${id ? `update ${id}` : "publish"}: ${body.name}, by ${body.author}`
      + (sending.note ? `, "${sending.note}"` : "")
      + ` (${Math.round(Buffer.byteLength(body.model) / 1024)} KB of LDraw, `
      + `${Math.round(Buffer.from(body.image || "", "base64").length / 1024)} KB picture)`);
    continue;
  }
  const reply = await fetch(`${base}/api/share`, { method: "POST", headers: auth, body: JSON.stringify(sending) });
  const said = await reply.json().catch(() => ({}));
  let ok = (reply.status === 200 || reply.status === 201) && said.listed === true;
  if (ok && list) {
    const put = await fetch(`${base}/api/people?op=collect`, { method: "POST", headers: auth,
      body: JSON.stringify({ collection: list.id, model: said.id, on: true }) });
    ok = put.status === 200;
    if (!ok) console.log(`  FAIL  ${body.name}: not put in the collection (${put.status})`);
  }
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${body.name}: ${reply.status} ${said.url || said.error || ""}`
    + (ok ? ` (${said.parts} parts, ${said.updated ? `version ${said.version}` : "new"}, `
      + `${said.tested?.kept && said.tested.passed ? "Tested" : `not Tested${said.tested?.why ? `: ${said.tested.why}` : ""}`}`
      + `${said.modelled_by ? `, modelled by ${said.modelled_by.name}` : ""}, ${said.licence})` : ""));
  // Listed a second apart, so each has a time of its own in the gallery.
  await new Promise((done) => setTimeout(done, 1100));
}
console.log(failed ? `${failed} FAILED` : `${bodies.length} models in the gallery, shared by ${EMAIL}`
  + (list ? `, in ${list.url || `the collection ${list.id}`}` : ""));
process.exit(failed ? 1 : 0);
