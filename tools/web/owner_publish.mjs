// Publish models as a person, from the server's side: the house putting a
// person's own builds up for them when they asked it to, without ever
// signing in as them.
//
//   set -a; . ./.env; set +a      (SUPABASE_URL, SUPABASE_SECRET_KEY)
//   node tools/web/owner_publish.mjs --handle=NAME --dir=DIR [--only=A-B] [--dry]
//       [--photos] [--origin=https://brickworks.diy]
//   node tools/web/owner_publish.mjs --handle=NAME --remove=ID
//   (--account=UUID --email=ADDRESS in place of --handle: a test account,
//    whose address puts what it publishes in the test pool, as its own would)
//
// DIR holds what the app's Share panel sent for each model (src/dev/
// gallery_seed.gd, tools/house_models/preview.sh): <n>.json, each its LDraw,
// its pictures, its words, its kind and licence, and the app's Tested
// finding. Each is published through api/share.js publishModel, the code
// every publish runs, with the account's id where a signed-in publish has
// its token's: the same checks, the same limits (an hour's listings, a
// day's), the same rows and files, so its page, its card, the feed, its
// steps and the search all have it as theirs. The card the panel drew as a
// photograph once its publish answered (body.card, gallery_seed.gd) goes on
// the link as the panel's op=card puts it (keepCard). With --photos, each
// <n>-photo-<k>.png beside the body (at most three, MOST_ON_A_MODEL) is
// added as the owner's own picture of it through api/_builds.js, as the
// page's Add a picture does: started, sent to the upload bucket, kept as a
// JPEG made from its pixels alone, at the photo limit (people.js LIMITS).
// A model the account already shares under the same title is published
// again at its link, its next version, as the app's Publish does.
//
// --remove=ID takes the account's model at ID down (api/share.js
// unpublishModel, the code op=unpublish runs): out of the gallery, its
// files and versions gone, its link saying it was taken down. Nothing else
// of the account's is touched.
//
// Used by billbuilds (2026-11-24): the owner asked for original builds by
// brickmanbill, their own account, which this never signs in to.
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { randomBytes } from "node:crypto";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SECRET_KEY) {
  console.error("owner_publish: needs SUPABASE_URL and SUPABASE_SECRET_KEY (set -a; . ./.env; set +a)");
  process.exit(2);
}
if (!(args.handle || args.account) || !(args.dir || args.remove)) {
  console.error("owner_publish: --handle=NAME (or --account=UUID --email=ADDRESS) and --dir=DIR or --remove=ID");
  process.exit(2);
}

// Work a publish leaves for after its answer (api/_after.js), kept to the
// end of this run as Vercel's request context keeps it, not cut at 1.5 s.
const after = [];
globalThis[Symbol.for("@vercel/request-context")] = { get: () => ({ waitUntil: (done) => after.push(done) }) };

const { db } = await import("../../api/_db.js");
const { publishModel, unpublishModel, putCard, Refusal } = await import("../../api/share.js");
const { startPhoto, keepPhoto, putFile, UPLOADS, MOST_ON_A_MODEL, BuildRefusal } = await import("../../api/_builds.js");
const { publicTrouble } = await import("../../api/_trust.js");
const { LIMITS } = await import("../../api/people.js");

const origin = String(args.origin || "https://brickworks.diy").replace(/\/+$/, "");
const host = new URL(origin).host;
// The request a publish came in on, as far as publishModel reads one: its
// origin (its links) and its scope (where a first model is told of).
const request = { headers: { host, "x-forwarded-host": host, "x-forwarded-proto": new URL(origin).protocol.replace(":", "") } };

let account = args.account ? String(args.account) : null;
let name = null;
if (args.handle) {
  const rows = await db(`people?handle=eq.${encodeURIComponent(String(args.handle))}&select=account,name`);
  if (!rows[0]) {
    console.error(`owner_publish: nobody has the handle ${args.handle}`);
    process.exit(2);
  }
  ({ account, name } = rows[0]);
}
const claims = { sub: account, email: args.email ? String(args.email) : "" };
const said = (trouble) => (trouble instanceof Refusal || trouble instanceof BuildRefusal
  ? `${trouble.status || 400} ${trouble.message}` : String(trouble?.stack || trouble).slice(0, 400));

if (args.remove) {
  try {
    const gone = await unpublishModel(account, String(args.remove));
    console.log(`  ok    took ${gone.id} down (${gone.versions} versions' files), ${name || account}'s`);
    process.exit(0);
  } catch (trouble) {
    console.log(`  FAIL  ${args.remove}: ${said(trouble)}`);
    process.exit(1);
  }
}

const [least, most] = args.only ? String(args.only).split("-").map(Number) : [1, Infinity];
const numbers = readdirSync(args.dir).filter((f) => /^\d+\.json$/.test(f)).map((f) => parseInt(f, 10))
  .filter((n) => n >= least && n <= (Number.isFinite(most) ? most : Infinity)).sort((a, b) => a - b);
if (!numbers.length) {
  console.error(`owner_publish: no bodies in ${args.dir} (src/dev/gallery_seed.gd writes them)`);
  process.exit(2);
}
const mine = await db(`shared_models?owner=eq.${account}&published=is.true&select=id,name`);
const byName = new Map(mine.map((row) => [row.name, row.id]));

// What people.js asks of a photo, start and keep: 13 or over, and the hour's
// and the day's photos (may_act).
const oldEnough = async () => {
  const young = await publicTrouble(account, { photo: true });
  if (young) throw new Refusal(young, 422);
};
const counted = async () => {
  const [hour, day] = LIMITS.photo;
  const allowed = await db("rpc/may_act", { method: "POST", body: { actor: account, act: "photo", per_hour: hour, per_day: day } });
  if (allowed !== true) throw new Refusal("that is a lot of that in a short time: try again in an hour", 429);
};

let failed = 0;
const published = [];
// The last first: the gallery is newest first, so it then shows them in the
// order given (as gallery_seed.mjs does).
for (const n of [...numbers].reverse()) {
  const body = JSON.parse(readFileSync(join(args.dir, `${n}.json`), "utf8"));
  const { card, card_kind: cardKind, note, ...rest } = body;
  const id = byName.get(body.name);
  const sending = { ...rest, ...(id ? { id, ...(note ? { note } : {}) } : {}) };
  const photos = args.photos ? [1, 2, 3].map((k) => join(args.dir, `${n}-photo-${k}.png`)).filter(existsSync) : [];
  if (args.dry) {
    console.log(`  would ${id ? `update ${id}` : "publish"}: ${body.name}, as ${name || account}, ${sending.listed ? "listed" : "not listed"}`
      + ` (${Math.round(Buffer.byteLength(body.model) / 1024)} KB of LDraw, card ${card ? cardKind : "none"},`
      + ` ${photos.length} photos, tested ${body.tested ? "sent" : "none"})`);
    continue;
  }
  let answer;
  try {
    ({ answer } = await publishModel(claims, sending, request));
  } catch (trouble) {
    failed += 1;
    console.log(`  FAIL  ${body.name}: ${said(trouble)}`);
    continue;
  }
  const tested = answer.tested?.kept && answer.tested.passed ? "Tested" : `not Tested (${JSON.stringify(answer.tested)?.slice(0, 200)})`;
  console.log(`  ok    ${body.name}: ${answer.url} (${answer.parts} parts, ${answer.steps} steps, `
    + `${answer.updated ? `version ${answer.version}` : "new"}, ${answer.listed ? "listed" : "not listed"}, ${tested})`);
  // Its card as a photograph, as the panel's op=card puts it once a publish answers.
  if (card) {
    try {
      const put = await putCard(account, answer.id, card, cardKind, origin);
      console.log(`        its card, ${put.kind || "kind not said"}, ${Math.round(Buffer.from(card, "base64").length / 1024)} KB`);
    } catch (trouble) {
      failed += 1;
      console.log(`  FAIL  ${body.name}: its card was not put: ${said(trouble)}`);
    }
  }
  for (const [k, file] of photos.entries()) {
    const words = existsSync(file.replace(/\.png$/, ".txt")) ? readFileSync(file.replace(/\.png$/, ".txt"), "utf8").trim() : null;
    const bytes = readFileSync(file);
    try {
      if (k >= MOST_ON_A_MODEL) throw new Refusal(`at most ${MOST_ON_A_MODEL} on a model`);
      const started = await startPhoto(account, answer.id, { type: "image/png", size: bytes.length }, async () => {
        await oldEnough();
        await counted();
      });
      // Where the phone's upload goes (the URL signed for it), sent with the
      // server's own key instead: the same file at the same name.
      await putFile(UPLOADS, `${account}/${started.ticket}`, bytes, "image/png");
      const kept = await keepPhoto(account, answer.id, started.ticket, words, oldEnough);
      console.log(`        a picture of it, ${kept.width}x${kept.height}: ${origin}/m/${answer.id}#photo-${kept.id}`);
    } catch (trouble) {
      failed += 1;
      console.log(`  FAIL  ${body.name}: a picture was not added: ${said(trouble)}`);
    }
  }
  published.push({ n, id: answer.id, name: body.name, url: answer.url });
  // Listed a second apart, so each has a time of its own in the gallery.
  await new Promise((done) => setTimeout(done, 1100));
}
await Promise.allSettled(after);
for (const one of published) {
  console.log(`PUBLISHED ${one.id} ${one.url} "${one.name}"  remove: node tools/web/owner_publish.mjs `
    + `${args.handle ? `--handle=${args.handle}` : `--account=${account}`} --remove=${one.id}`);
}
console.log(failed ? `${failed} FAILED` : `${published.length} ${args.dry ? "to publish" : "published"} as ${name || account}`);
process.exit(failed ? 1 : 0);
