// Put the project's own showcase models in the gallery, so it is not empty
// on its first day.
//
//   set -a; . ./.env; set +a
//   godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- --seed-list=SEEDS.json --seed-out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/gallery_seed.mjs --url=<deployment> --dir=DIR [--dry]
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

const bodies = readdirSync(args.dir).filter((f) => /^\d+\.json$/.test(f))
  .sort((a, b) => parseInt(a, 10) - parseInt(b, 10))
  .map((f) => JSON.parse(readFileSync(join(args.dir, f), "utf8")));
if (!bodies.length) {
  console.error(`gallery_seed: no bodies in ${args.dir} (src/dev/gallery_seed.gd writes them)`);
  process.exit(2);
}

const { access_token: token } = await mintSession(EMAIL);
const auth = { ...headers, authorization: `Bearer ${token}` };
const mine = await (await fetch(`${base}/api/share?op=mine`, { headers: auth })).json();
const byName = new Map((mine.shared || []).map((row) => [row.name, row.id]));

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
  const ok = (reply.status === 200 || reply.status === 201) && said.listed === true;
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${body.name}: ${reply.status} ${said.url || said.error || ""}`
    + (ok ? ` (${said.parts} parts, ${said.updated ? `version ${said.version}` : "new"}, `
      + `${said.tested?.kept && said.tested.passed ? "Tested" : `not Tested${said.tested?.why ? `: ${said.tested.why}` : ""}`})` : ""));
  // Listed a second apart, so each has a time of its own in the gallery.
  await new Promise((done) => setTimeout(done, 1100));
}
console.log(failed ? `${failed} FAILED` : `${bodies.length} models in the gallery, shared by ${EMAIL}`);
process.exit(failed ? 1 : 0);
