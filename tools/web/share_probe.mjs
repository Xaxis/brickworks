// Does sharing a model by link work, and refuse what it should?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 &
//   node tools/web/share_probe.mjs --url=http://127.0.0.1:8790
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/share_probe.mjs --url=<a preview>
//
// Plays both sides against the real functions, database and bucket
// (api/share.js, supabase/shared_models.sql): an owner publishing, reading
// back, updating and unpublishing; a visitor with no account reading the
// model, its page, its picture and its card; and the refusals — no
// session, somebody else's link, too big, not LDraw, not a PNG, no name,
// taken down, never there, too many in an hour. And the database itself,
// asked directly with the key every page has: no owner column, no
// unpublished row, no write, no file.
//
// And the daily sweep (CRON_SECRET from .env): a third account publishes
// and is deleted with its model still up, as the dashboard deletes one,
// and the sweep takes its files away and leaves a published model's.
//
// And the gallery (supabase/gallery.sql): listed, a model is in
// ?op=list, newest first, with its picture; unticked, unpublished or taken
// out by the site's owner it is not; a name that is markup is shown as
// text; a copy shared again says what it was remixed from; listing is
// limited like publishing. With --master the owner's account (MASTER_EMAIL,
// a session minted as for any test) takes one out (api/admin.js), which
// nobody else can, and its owner cannot list it again.
//
// And the directory (supabase/directory.sql, api/_directory.js): what an
// owner says about a model (a description, tags, a kind, a licence) cleaned
// and refused at the edge; its steps and whether it is Technic counted from
// the file; the gallery searched, filtered and sorted; the model's page
// with its words escaped, its licence, its counts and its remix tree; a
// licence a remix has to keep; and a view counted once a day per visitor,
// never for a robot, a headless browser or another site's page.
//
// And people (supabase/people.sql, api/people.js): a profile by a name its
// owner chooses, its handle checked and kept unique, listing only what was
// listed and credited; likes counted once per account; favourites and
// private lists their owner's alone, a private list answering anybody
// else as one that does not exist; a public list's page; and every table
// of it closed to the key every page has.
//
// And moderation (supabase/moderation.sql, api/_names.js, api/admin.js):
// abuse and somebody else's names refused in titles, tags, credits,
// handles and names; a report from anybody, limited; the site's owner
// seeing the queue, letting one go, taking a model out so the same file is
// refused at any other link, and taking an account out so nothing of it is
// shown and nothing new listed, then letting it back; twenty collections an
// hour; the sitemap with every listed model; the CDN keeping the list and
// the pages (on a deployment); and the new tables and functions closed to
// the key every page has.
//
// And test models (supabase/test_models.sql): every model this publishes is
// a test account's, so it is marked a test and no visitor is shown it — not
// in the gallery, a profile, a collection or the sitemap, asked past the
// CDN or through it — while its own link works. Every list this checks is
// asked with tests=1, which nobody else asks, and that answer is never kept
// by the CDN; the list a visitor gets is checked beside it.
//
// Throwaway accounts at Resend test addresses (no email is sent: the
// sessions are minted here), deleted at the end with every row of theirs.
// Every model this publishes is unpublished or swept before that, so no
// file is left in the bucket.
import { randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import { deleteAccount, mintSession } from "./session.mjs";
import { placed } from "./gallery_order.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:8790").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const PUBLISHABLE = process.env.SUPABASE_PUBLISHABLE_KEY || "";

let failures = 0;
let checks = 0;
const check = (ok, what) => {
  checks += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

let asked = 0;
async function call(path, { method = "GET", token, body, raw, headers: more = {}, cached = false } = {}) {
  const headers = { ...more };
  if (bypass) headers["x-vercel-protection-bypass"] = bypass;
  if (token) headers.authorization = `Bearer ${token}`;
  let payload;
  if (raw !== undefined) {
    headers["content-type"] = "application/json";
    payload = raw;
  } else if (body !== undefined) {
    headers["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  // Asked past the CDN, which keeps pages, pictures and the list for up to
  // a minute (api/share.js SHARED_CACHE): every read here checks what was
  // just done. What the CDN keeps is checked on its own (cached: true).
  let where = path.startsWith("http") ? path : base + path;
  if ((method === "GET" || method === "HEAD") && !cached) {
    where += `${where.includes("?") ? "&" : "?"}fresh=${Date.now().toString(36)}${(asked += 1).toString(36)}`;
  }
  const reply = await fetch(where, {
    method, headers, body: payload, redirect: "manual",
  });
  const bytes = Buffer.from(await reply.arrayBuffer());
  const text = bytes.toString("utf8");
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: reply.status, headers: reply.headers, json, text, bytes };
}

// A model the way the app writes one: a sub-model placed twice, two loose
// bricks, a part made in the app carried as `0 FILE <id>.dat`, and a
// sticker's picture carried as `0 !DATA`. Nine parts: 3 + 3 + 2 + 1.
const PIXEL = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
const MODEL = [
  "0 FILE main.ldr",
  "0 Probe Tower",
  "0 Name: main.ldr",
  "0 Author: Brickworks",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 tower.ldr",
  "1 4 80 0 0 1 0 0 0 1 0 0 0 1 tower.ldr",
  "1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "0 STEP",
  "1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat",
  "1 14 40 -48 0 1 0 0 0 1 0 0 0 1 bw-probe.dat",
  "0 NOFILE",
  "0 FILE tower.ldr",
  "0 Tower",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "0 NOFILE",
  "0 FILE bw-probe.dat",
  "0 Brick 1 x 1 made for the probe",
  "0 Name: bw-probe.dat",
  "0 !LDRAW_ORG Unofficial_Part",
  "4 16 -10 0 -10 10 0 -10 10 0 10 -10 0 10",
  "2 24 -10 0 -10 10 0 -10",
  "1 16 0 0 0 1 0 0 0 1 0 0 0 1 stud.dat",
  "0 NOFILE",
  "0 !DATA probe-sticker.png",
  `0 !: ${PIXEL}`,
  "",
].join("\r\n");
// A PNG, which is all the picture has to be.
const PICTURE = PIXEL;
// And a WebP, the small picture's: one pixel.
const THUMB = "UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==";

const rand = randomBytes(4).toString("hex");
const emailA = `delivered+bw-share-a-${rand}@resend.dev`;
const emailB = `delivered+bw-share-b-${rand}@resend.dev`;
const emailC = `delivered+bw-share-c-${rand}@resend.dev`;
// The gallery's: one who remixes, one who lists too much.
const emailD = `delivered+bw-share-d-${rand}@resend.dev`;
const emailE = `delivered+bw-share-e-${rand}@resend.dev`;
// The directory's: one who shares a model with steps of its own, a gear
// train, and a remix.
const emailF = `delivered+bw-share-f-${rand}@resend.dev`;
// People's: one with a profile, credited and not, liked, kept and listed.
const emailG = `delivered+bw-share-g-${rand}@resend.dev`;
// Moderation's: a bad actor taken out, and an account that copies them.
const emailH = `delivered+bw-share-h-${rand}@resend.dev`;
const emailI = `delivered+bw-share-i-${rand}@resend.dev`;
const SMALL = "0 Small\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n";
const ID = /^[A-Za-z0-9]{10}$/;
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const CRON = process.env.CRON_SECRET || "";

/// A file in the bucket, asked for with the secret key: its status.
async function fileStatus(name) {
  const answer = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${name}`, {
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` },
  });
  return answer.status;
}
const published = new Set();

async function anonRest(path, { method = "GET", body } = {}) {
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, {
    method,
    headers: { apikey: PUBLISHABLE, "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch { json = null; }
  return { status: reply.status, json };
}

/// Whether these rows are marked a test, read with the secret key: {id: test}.
async function marked(ids) {
  const answer = await fetch(`${SUPABASE}/rest/v1/shared_models?id=in.(${ids.join(",")})&select=id,test`,
    { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  return Object.fromEntries((await answer.json()).map((row) => [row.id, row.test]));
}

/// What a visitor's gallery holds of [ids], the first page newest first:
/// asked past the CDN and as the CDN gives it (the address /gallery asks).
async function visitorSees(ids) {
  const past = await call("/api/share?op=list&page=1");
  const kept = await call("/api/share?op=list&page=1", { cached: true });
  const shown = [...(past.json?.models || []), ...(kept.json?.models || [])].map((m) => m.id);
  return { past, kept, found: ids.filter((id) => shown.includes(id)) };
}

async function main() {
  console.log(`sharing a model by link, against ${base}`);
  const a = await mintSession(emailA);
  const b = await mintSession(emailB);
  const tokenA = a.access_token;
  const tokenB = b.access_token;

  // --- Publish
  console.log("publish");
  let r = await call("/api/share", { method: "POST", body: { name: "Probe Tower", model: MODEL } });
  check(r.status === 401, `no session: 401 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: "not.a.token", body: { name: "Probe Tower", model: MODEL } });
  check(r.status === 401, `a made-up session: 401 (${r.status})`);

  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { name: "  Probe Tower ", author: "Probe Builder", model: MODEL, image: PICTURE } });
  const id = r.json?.id || "";
  if (id) published.add(id);
  check(r.status === 201 && /^[A-Za-z0-9]{10}$/.test(id), `published: 201, a ten-character id (${r.status} ${id})`);
  check(r.json?.parts === 9, `the part count is the server's own: 9 (${r.json?.parts}) — two copies of a sub-model, a made part, a sticker's picture not counted`);
  check(r.json?.name === "Probe Tower", `the name is trimmed (${JSON.stringify(r.json?.name)})`);
  check(r.json?.url === `${base}/m/${id}`, `the link is ${base}/m/<id> (${r.json?.url})`);
  check(String(r.json?.embed || "").startsWith(`<iframe src="${base}/m/${id}/embed"`), "an embed snippet: an iframe of the link's card");

  // --- Read, as somebody with no account
  console.log("read, signed out");
  r = await call(`/api/share?id=${id}`);
  check(r.status === 200, `the model: 200 (${r.status})`);
  check(r.json?.model === MODEL, "the .mpd comes back byte for byte, its made part and sticker inside it");
  check(r.json?.name === "Probe Tower" && r.json?.author === "Probe Builder" && r.json?.parts === 9,
    `name, author and part count (${r.json?.name}, ${r.json?.author}, ${r.json?.parts})`);
  check(!("owner" in (r.json || {})), "no owner in what a visitor is given");
  check(r.headers.get("cache-control") === "no-store", `not cached (${r.headers.get("cache-control")})`);

  r = await call(`/m/${id}`);
  check(r.status === 200 && r.headers.get("content-type")?.startsWith("text/html"), `the link's page: 200 HTML (${r.status})`);
  check(r.text.includes('<meta property="og:title" content="Probe Tower — a Brickworks model">'), "its og:title names the model");
  check(r.text.includes(`<meta property="og:image" content="${base}/m/${id}.png">`), "its og:image is the model's picture");
  check(r.text.includes('<li class="pill">9 parts</li>') && r.text.includes("<b>Probe Builder</b>"),
    "it says the part count and who made it");
  check(r.text.includes(`<a class="cta" href="/app?view=${id}" `) && r.text.includes(">Build it</a>")
    && r.text.includes('<script src="/share-page.js"') && r.text.includes(`data-viewer="/app?view=${id}"`),
  "a person goes on to the viewer, /app?view=<id>, with Build it");
  check(/frame-ancestors 'none'/.test(r.headers.get("content-security-policy") || ""), "the page is not frameable");

  r = await call(`/m/${id}.png`);
  check(r.status === 200 && r.headers.get("content-type") === "image/png" && r.bytes.equals(Buffer.from(PICTURE, "base64")),
    `its picture: 200 image/png, the bytes published (${r.status} ${r.headers.get("content-type")})`);
  check(r.headers.get("cross-origin-resource-policy") === "cross-origin", "the picture may be shown on any site");
  const heads = [(await call(`/m/${id}`, { method: "HEAD" })).status, (await call(`/m/${id}.png`, { method: "HEAD" })).status];
  check(heads.every((s) => s === 200), `the page and its picture asked with HEAD, as a link checker asks: 200 (${heads.join(", ")})`);

  r = await call(`/m/${id}/embed`);
  check(r.status === 200 && r.text.includes(`href="${base}/m/${id}"`) && r.text.includes('target="_blank"'),
    `the card for an iframe: 200, opening the link in a tab (${r.status})`);
  check(/frame-ancestors \*/.test(r.headers.get("content-security-policy") || ""), "the card may be framed anywhere");

  // --- Refusals at the edge
  console.log("refused at the edge");
  const big = `0 Big\r\n${"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n".repeat(58000)}`;
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Big", model: big } });
  check(r.status === 413, `over 2 MB: 413 (${r.status}, ${(Buffer.byteLength(big) / 1048576).toFixed(2)} MB) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "JSON", model: JSON.stringify({ bricks: [1, 2] }) } });
  check(r.status === 415, `JSON is not LDraw: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { name: "Binary", model: Buffer.from(PICTURE, "base64").toString("latin1") } });
  check(r.status === 415, `a binary file is not LDraw: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Script", model: "<script>alert(1)</script>" } });
  check(r.status === 415, `HTML is not LDraw: 415 (${r.status})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Broken", model: "0 Broken\r\n1 4 0 0 0 1 0 0 3001.dat\r\n" } });
  check(r.status === 415, `a part line cut short: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Nothing", model: "0 Nothing\r\n0 Author: nobody\r\n" } });
  check(r.status === 415, `no parts: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Loop",
    model: "0 FILE a.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 b.ldr\r\n0 FILE b.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 a.ldr\r\n" } });
  check(r.status === 415, `a model inside itself: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { name: "Bad picture", model: MODEL, image: Buffer.from("GIF89a....").toString("base64") } });
  check(r.status === 415, `a picture that is not a PNG: 415 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "   ", model: MODEL } });
  check(r.status === 400, `no name: 400 (${r.status}) "${r.json?.error}"`);

  // --- Update: the same link
  console.log("update");
  const MODEL2 = MODEL.replace("1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n1 2 0 -72 0 1 0 0 0 1 0 0 0 1 3005.dat");
  r = await call("/api/share", { method: "POST", token: tokenA, body: { id, name: "Probe Tower, taller", model: MODEL2 } });
  check(r.status === 200 && r.json?.id === id && r.json?.updated === true && r.json?.parts === 10,
    `republished: 200, the same id, 10 parts (${r.status} ${r.json?.id} ${r.json?.parts})`);
  r = await call(`/api/share?id=${id}`);
  check(r.json?.name === "Probe Tower, taller" && r.json?.model === MODEL2 && r.json?.author === null,
    `the link now has the new model and name, and no author (${r.json?.name}, ${r.json?.author})`);
  r = await call(`/m/${id}.png`);
  check(r.status === 404, `republished without a picture: the old one is gone (${r.status})`);
  r = await call(`/m/${id}`);
  check(r.text.includes("/share.png"), "and the page falls back to the site's own picture");

  r = await call("/api/share", { method: "POST", token: tokenB, body: { id, name: "Mine now", model: MODEL } });
  check(r.status === 403, `somebody else updating it: 403 (${r.status}) "${r.json?.error}"`);
  r = await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: tokenB });
  check(r.status === 403, `somebody else unpublishing it: 403 (${r.status})`);
  r = await call(`/api/share?op=unpublish&id=${id}`, { method: "POST" });
  check(r.status === 401, `unpublishing signed out: 401 (${r.status})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { id: "ZZZZZZZZZZ", name: "Nowhere", model: MODEL } });
  check(r.status === 404, `updating a link that does not exist: 404 (${r.status})`);
  r = await call(`/api/share?id=${id}`);
  check(r.json?.name === "Probe Tower, taller", "the refused writes changed nothing");

  r = await call("/api/share?op=mine", { token: tokenA });
  check(r.status === 200 && r.json?.shared?.length === 1 && r.json.shared[0].id === id, `the owner's own links (${r.json?.shared?.length})`);
  r = await call("/api/share?op=mine", { token: tokenB });
  check(r.status === 200 && r.json?.shared?.length === 0, "and nobody else's");
  r = await call("/api/share?op=mine");
  check(r.status === 401, `the list signed out: 401 (${r.status})`);

  await theGallery(tokenA, tokenB, id);
  await theDirectory(tokenA);
  await thePeople(tokenA, tokenB);
  await theModeration(tokenA);

  // --- The database, asked directly with the publishable key
  console.log("the database, with the key every page has");
  let d = await anonRest(`shared_models?id=eq.${id}&select=id,name,parts`);
  check(d.status === 200 && d.json?.length === 1, `a published row is readable (${d.status}, ${d.json?.length})`);
  d = await anonRest(`shared_models?id=eq.${id}&select=owner`);
  check(d.status === 401 || d.status === 403, `its owner is not (${d.status})`);
  d = await anonRest("shared_models", { method: "POST", body: { id: "AAAAAAAAAA", owner: a.kept.user_id, name: "x", parts: 1, bytes: 1 } });
  check(d.status === 401 || d.status === 403, `a row cannot be written (${d.status})`);
  d = await anonRest(`shared_models?id=eq.${id}`, { method: "PATCH", body: { name: "defaced" } });
  check(d.status === 401 || d.status === 403, `a row cannot be changed (${d.status})`);
  d = await anonRest("share_publishes?select=id");
  check(d.status === 401 || d.status === 403, `the publish log is closed (${d.status})`);
  d = await anonRest("share_listings?select=id");
  check(d.status === 401 || d.status === 403, `so is the listing log (${d.status})`);
  d = await anonRest(`shared_models?id=eq.${id}&select=listed,listed_at,remixed_from`);
  check(d.status === 200 && d.json?.length === 1, `whether it is listed, and what it was remixed from, are readable (${d.status})`);
  d = await anonRest(`shared_models?id=eq.${id}&select=barred`);
  check(d.status === 401 || d.status === 403, `whether the site's owner barred it is not (${d.status})`);
  d = await anonRest("rpc/may_list", { method: "POST", body: { account: a.kept.user_id } });
  check(d.status >= 400, `the listing limit cannot be called with it (${d.status})`);
  const file = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${id}.mpd`, { headers: { apikey: PUBLISHABLE } });
  check(file.status >= 400, `the file is not in a public bucket (${file.status})`);
  const filePublic = await fetch(`${SUPABASE}/storage/v1/object/public/shared-models/${id}.mpd`);
  check(filePublic.status >= 400, `nor at a public address (${filePublic.status})`);
  r = await call(`/api/share?id=${id}`);
  check(r.json?.name === "Probe Tower, taller", "and the row is as it was");

  // --- Unpublish
  console.log("unpublish");
  r = await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: tokenA });
  check(r.status === 200 && r.json?.published === false, `the owner takes it down: 200 (${r.status})`);
  r = await call(`/api/share?id=${id}`);
  check(r.status === 410 && r.json?.unpublished === true, `the model: 410, taken down (${r.status}) "${r.json?.error}"`);
  r = await call(`/m/${id}`);
  check(r.status === 410 && r.text.includes("This model is no longer shared"), `the link's page says so: 410 (${r.status})`);
  check(!r.text.includes("Probe Tower"), "and no longer names it");
  r = await call(`/m/${id}.png`);
  check(r.status === 404, `no picture (${r.status})`);
  r = await call(`/m/${id}/embed`);
  check(r.status === 410, `the card says so too (${r.status})`);
  d = await anonRest(`shared_models?id=eq.${id}&select=id`);
  check(d.status === 200 && d.json?.length === 0, "the row is not readable with the publishable key");
  r = await call("/api/share?id=QQQQQQQQQQ");
  check(r.status === 404 && r.json?.unpublished === false, `a link that never was: 404 (${r.status}) "${r.json?.error}"`);
  r = await call("/m/QQQQQQQQQQ");
  check(r.status === 404 && r.text.includes("There is no model at this link"), `and its page (${r.status})`);
  r = await call("/api/share?id=../../etc");
  check(r.status === 404, `an id that is not one: 404 (${r.status})`);

  // --- Republish: the same link back
  console.log("republish");
  r = await call("/api/share", { method: "POST", token: tokenA, body: { id, name: "Probe Tower", model: MODEL, image: PICTURE } });
  check(r.status === 200 && r.json?.id === id, `republishing a link that was taken down brings back the same link (${r.status})`);
  r = await call(`/api/share?id=${id}`);
  check(r.status === 200 && r.json?.model === MODEL, "the link works again");

  // --- The sweep: what a deleted account leaves in the bucket
  console.log("the sweep");
  r = await call("/api/share/sweep");
  check(r.status === 401, `the sweep with no secret: 401 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share/sweep", { token: "not-the-cron" });
  check(r.status === 401, `with the wrong one: 401 (${r.status})`);
  const c = await mintSession(emailC);
  r = await call("/api/share", { method: "POST", token: c.access_token,
    body: { name: "Left Behind", model: MODEL, image: PICTURE } });
  const idC = r.json?.id || "";
  check(r.status === 201 && ID.test(idC), `a third account publishes (${r.status} ${idC})`);
  check(await deleteAccount(emailC), "and is deleted with its model still up, as the dashboard deletes one");
  r = await call(`/api/share?id=${idC}`);
  check(r.status === 404, `its row went with it (${r.status})`);
  const before = [await fileStatus(`${idC}.mpd`), await fileStatus(`${idC}.png`)];
  check(before.every((s) => s === 200), `but its files are still in the bucket (${before.join(", ")})`);
  r = await call(`/api/share/sweep?only=${id},${idC}`, { token: CRON });
  const removed = (r.json?.removed || []).slice().sort().join(", ");
  check(r.status === 200 && removed === `${idC}.mpd, ${idC}.png`,
    `the sweep takes those two and nothing of the published one (${r.status}: ${removed || r.json?.error})`);
  const after = [await fileStatus(`${idC}.mpd`), await fileStatus(`${idC}.png`)];
  check(after.every((s) => s === 400 || s === 404), `they are gone from the bucket (${after.join(", ")})`);
  r = await call(`/api/share?id=${id}`);
  check(r.status === 200 && r.json?.model === MODEL, "the published model is as it was");
  r = await call("/api/share/sweep", { token: CRON });
  check(r.status === 200 && Number.isInteger(r.json?.looked_at) && !(r.json?.removed || []).some((n) => n.startsWith(id)),
    `the whole bucket swept: ${r.json?.looked_at} files an hour old or more, ${r.json?.removed?.length} removed, none of a published model's`);

  r = await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: tokenA });
  check(r.status === 200, "taken down again");

  // --- The limit on publishing
  console.log("too many");
  const small = "0 Small\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n";
  let first = await call("/api/share", { method: "POST", token: tokenB, body: { name: "Small", model: small } });
  const idB = first.json?.id;
  if (idB) published.add(idB);
  let allowed = first.status === 201 ? 1 : 0;
  let refused = null;
  for (let n = 0; n < 25 && !refused; n += 1) {
    r = await call("/api/share", { method: "POST", token: tokenB, body: { id: idB, name: `Small ${n}`, model: small } });
    if (r.status === 200) allowed += 1;
    else refused = r;
  }
  check(allowed === 20 && refused?.status === 429, `twenty publishes an hour, then 429 (${allowed} allowed, then ${refused?.status}) "${refused?.json?.error}"`);
  r = await call(`/api/share?id=${idB}`);
  check(r.json?.name === "Small 18", `the refused one changed nothing (${r.json?.name})`);
  r = await call(`/api/share?op=unpublish&id=${idB}`, { method: "POST", token: tokenB });
  check(r.status === 200, "taken down");
}

/// The gallery: listing and the list, a name that is markup, a remix, the
/// site's owner taking one out, and the limit on listing.
async function theGallery(tokenA, tokenB, unlistedId) {
  console.log("the gallery");
  const list = () => call("/api/share?op=list&page=1&tests=1");
  const inList = (l, id) => (l.json?.models || []).some((m) => m.id === id);
  const d = await mintSession(emailD);
  const tokenD = d.access_token;

  const listing = Date.now();
  let r = await call("/api/share", { method: "POST", token: tokenA,
    body: { name: "Probe Gallery", author: "Probe Builder", model: MODEL, image: PICTURE, listed: true } });
  const listedId = r.json?.id || "";
  if (listedId) published.add(listedId);
  check(r.status === 201 && r.json?.listed === true && r.json?.gallery === `${base}/gallery`,
    `published with listed: true (${r.status}, listed ${r.json?.listed}, ${r.json?.gallery})`);
  let l = await list();
  // Ahead of everything listed before it; another flow's test model,
  // listed after it while the release runs two at once, may be ahead.
  let stands = placed(l.json?.models || [], listedId, { since: listing });
  const card = (l.json?.models || []).find((m) => m.id === listedId) || {};
  check(l.status === 200 && stands.ok && card.name === "Probe Gallery" && card.author === "Probe Builder"
    && card.parts === 9 && card.url === `${base}/m/${listedId}` && card.image === `${base}/m/${listedId}.png`,
    `?op=list has it newest first, ${stands.said}, with its name, author, part count, link and picture (${l.status}, ${card.id})`);
  check(!("owner" in card) && l.json?.per_page === 24 && typeof l.json?.more === "boolean",
    "...no owner, and a page of 24 that says whether there is another");
  check(!inList(l, unlistedId), "a model shared without the box ticked is not in it");

  // A test account's model: marked so, and no visitor is shown it.
  console.log("test models");
  const marks = await marked([listedId, unlistedId]);
  check(marks[listedId] === true && marks[unlistedId] === true,
    `published by a test account (a resend.dev address): marked a test (${JSON.stringify(marks)})`);
  let seen = await visitorSees([listedId]);
  check(seen.past.status === 200 && seen.kept.status === 200 && seen.found.length === 0,
    `a visitor's list, past the CDN and through it, leaves it out (${seen.past.status}, ${seen.kept.status}, `
    + `${(seen.past.json?.models || []).length} models, ${seen.found.length} of the probe's)`);
  check(l.json?.tests === true && l.headers.get("cache-control") === "private, no-store",
    `asked with tests=1, it is in the list, and that answer is never kept (${l.headers.get("cache-control")})`);
  r = await call("/api/share?op=list&page=1&tests=maybe");
  check(r.status === 400, `tests that is not 1: 400 (${r.status}) "${r.json?.error}"`);
  // Vercel's CDN keeps s-maxage for itself and hands a browser what is
  // left; on a deployment, the CDN answering a second asking is the proof.
  const local = /127\.0\.0\.1|localhost/.test(base);
  const kept = seen.past.headers.get("cache-control") || "";
  check(/public/.test(kept) && /max-age=0/.test(kept) && (!local || /s-maxage=30/.test(kept)),
    `a visitor's list is kept by the CDN for half a minute, not by a browser (${kept})`);
  if (!/127\.0\.0\.1|localhost/.test(base)) {
    const same = `/api/share?op=list&page=1&kind=castle&sort=views&cdn=${rand}`;
    await call(same, { cached: true });
    const again = await call(same, { cached: true });
    check(/HIT|STALE/.test(again.headers.get("x-vercel-cache") || ""),
      `the same question again is answered by the CDN (${again.headers.get("x-vercel-cache")})`);
    const tested = `/api/share?op=list&page=1&tests=1&cdn=${rand}`;
    await call(tested, { cached: true });
    const testedAgain = await call(tested, { cached: true });
    check(!/HIT|STALE/.test(testedAgain.headers.get("x-vercel-cache") || "") && inList(testedAgain, listedId),
      `asked with tests=1 again, the function answers, not the CDN (${testedAgain.headers.get("x-vercel-cache")})`);
    const page = `/m/${listedId}`;
    await call(page, { cached: true });
    const pageAgain = await call(page, { cached: true });
    check(/HIT|STALE/.test(pageAgain.headers.get("x-vercel-cache") || ""),
      `and so is a model's page asked again (${pageAgain.headers.get("x-vercel-cache")})`);
  }
  const pages = [];
  for (const bad of ["0", "-1", "x", "1.5", "401"]) pages.push((await call(`/api/share?op=list&page=${bad}`)).status);
  check(pages.every((s) => s === 400), `a page that is not 1 to 400: 400 (${pages.join(", ")})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Listed?", model: MODEL, listed: "yes" } });
  check(r.status === 400, `listed that is not true or false: 400 (${r.status}) "${r.json?.error}"`);

  // A name that is markup, listed by somebody else, later: ahead of it now.
  const MARKUP = `<img src=x onerror="alert(1)">Probe & "Co"`;
  const later = Date.now();
  r = await call("/api/share", { method: "POST", token: tokenD, body: { name: MARKUP, model: SMALL, listed: true } });
  const markupId = r.json?.id || "";
  if (markupId) published.add(markupId);
  l = await list();
  stands = placed(l.json?.models || [], markupId, { since: later });
  const behind = placed(l.json?.models || [], listedId);
  check(stands.ok && behind.ok && behind.at > stands.at,
    `newest first: one listed later is ahead of it (${stands.said}; the first ${behind.said})`);
  check((l.json?.models || []).find((m) => m.id === markupId)?.name === MARKUP,
    "the list gives a name as the text it is, for the page to show as text");
  seen = await visitorSees([markupId, listedId]);
  check(seen.found.length === 0, `and a visitor's list has neither, past the CDN or through it (${seen.found.join(", ") || "none"})`);
  r = await call(`/m/${markupId}`);
  check(r.status === 200 && !r.text.includes("<img src=x")
    && r.text.includes("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;Probe &amp; &quot;Co&quot;"),
    `and its page escapes it (${r.status})`);

  // A copy of the listed one, shared by the one who copied it.
  r = await call("/api/share", { method: "POST", token: tokenD,
    body: { name: "Probe Remix", model: MODEL, remixed_from: listedId } });
  const remixId = r.json?.id || "";
  if (remixId) published.add(remixId);
  check(r.status === 201 && r.json?.remixed_from === listedId && r.json?.listed === false,
    `a copy shared again records what it was remixed from, unlisted (${r.status}, ${r.json?.remixed_from})`);
  r = await call(`/m/${remixId}`);
  check(r.text.includes(`Remixed from <a href="/m/${listedId}">Probe Gallery</a>`), "its page says remixed from, with a link");
  r = await call(`/api/share?id=${remixId}`);
  check(r.json?.remixed_from?.id === listedId && r.json.remixed_from.name === "Probe Gallery"
    && r.json.remixed_from.url === `${base}/m/${listedId}`, "and so does what the viewer reads");
  r = await call("/api/share", { method: "POST", token: tokenD, body: { id: remixId, name: "Probe Remix", model: MODEL } });
  check(r.status === 200 && r.json?.remixed_from === listedId, "republished without saying so, it still knows");
  r = await call("/api/share", { method: "POST", token: tokenD, body: { name: "Bad remix", model: SMALL, remixed_from: "../../x" } });
  check(r.status === 400, `remixed_from that is not a link: 400 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenD, body: { name: "Lost remix", model: SMALL, remixed_from: "QQQQQQQQQQ" } });
  if (r.json?.id) published.add(r.json.id);
  check(r.status === 201 && r.json?.remixed_from === null, `one from a link that never was: shared, remixed from nothing (${r.status})`);

  // Unticked, and published again: out of the gallery, still at its link.
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { id: listedId, name: "Probe Gallery", model: MODEL, image: PICTURE, listed: false } });
  l = await list();
  check(r.status === 200 && r.json?.listed === false && !inList(l, listedId), "unticked and published again: out of the gallery");
  check((await call(`/m/${listedId}`)).status === 200, "...and still shared at its link");
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { id: listedId, name: "Probe Gallery", model: MODEL, image: PICTURE, listed: true } });
  check(r.status === 200 && inList(await list(), listedId), "ticked again: back in");

  // Taken down: out of the gallery, and a remix of it no longer names it.
  r = await call(`/api/share?op=unpublish&id=${listedId}`, { method: "POST", token: tokenA });
  l = await list();
  check(r.status === 200 && !inList(l, listedId), "unpublished: out of the gallery");
  r = await call(`/m/${remixId}`);
  check(r.status === 200 && !r.text.includes("Remixed from"), "and the remix's page no longer names a model taken down");
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { id: listedId, name: "Probe Gallery", model: MODEL, image: PICTURE } });
  check(r.status === 200 && r.json?.listed === false && !inList(await list(), listedId),
    "published again without the box: shared, not listed");
  r = await call("/api/share", { method: "POST", token: tokenA,
    body: { id: listedId, name: "Probe Gallery", model: MODEL, image: PICTURE, listed: true } });
  check(inList(await list(), listedId), "listed again");

  // The site's owner takes it out.
  r = await call(`/api/admin?op=unlist&id=${listedId}`, { method: "POST", token: tokenD });
  check(r.status === 404, `anybody else asking to take it out: 404, as for a page that is not there (${r.status})`);
  r = await call(`/api/admin?op=unlist&id=${listedId}`, { method: "POST" });
  check(r.status === 401, `signed out: 401 (${r.status})`);
  check(inList(await list(), listedId), "...and it is still in the gallery");
  if (args.master) {
    const m = await mintSession(process.env.MASTER_EMAIL);
    r = await call("/api/admin", { token: m.access_token });
    const row = (r.json?.gallery || []).find((g) => g.id === listedId);
    check(r.status === 200 && row?.name === "Probe Gallery" && row?.email === emailA,
      `the owner's page lists what is in the gallery, and whose (${r.status}, ${row?.email})`);
    r = await call(`/api/admin?op=unlist&id=${listedId}`, { method: "POST", token: m.access_token });
    check(r.status === 200 && r.json?.barred === true, `the site's owner takes it out: 200 (${r.status})`);
    check(!inList(await list(), listedId), "out of the gallery");
    check((await call(`/m/${listedId}`)).status === 200, "its link still works");
    r = await call("/api/share", { method: "POST", token: tokenA,
      body: { id: listedId, name: "Probe Gallery", model: MODEL, listed: true } });
    check(r.status === 409 && !inList(await list(), listedId),
      `its owner cannot list it again: 409 (${r.status}) "${r.json?.error}"`);
    r = await call("/api/share", { method: "POST", token: tokenA, body: { id: listedId, name: "Probe Gallery", model: MODEL } });
    check(r.status === 200, `but can still publish it unlisted (${r.status})`);
    r = await call("/api/admin?op=unlist&id=QQQQQQQQQQ", { method: "POST", token: m.access_token });
    check(r.status === 404, `a link that never was: 404 (${r.status})`);
    r = await call("/api/admin?op=unlist&id=../x", { method: "POST", token: m.access_token });
    check(r.status === 400, `an id that is not one: 400 (${r.status})`);
  } else {
    console.log("  --    the site's owner taking a model out: with --master");
  }

  // Listing, counted.
  const e = await mintSession(emailE);
  let allowed = 0;
  let refused = null;
  let firstOfE = "";
  for (let n = 0; n < 9 && !refused; n += 1) {
    r = await call("/api/share", { method: "POST", token: e.access_token, body: { name: `Listed ${n}`, model: SMALL, listed: true } });
    if (r.status === 201) {
      allowed += 1;
      published.add(r.json.id);
      firstOfE = firstOfE || r.json.id;
    } else refused = r;
  }
  check(allowed === 6 && refused?.status === 429, `six listings an hour, then 429 (${allowed} allowed, then ${refused?.status}) "${refused?.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: e.access_token, body: { id: firstOfE, name: "Listed 0", model: SMALL, listed: true } });
  check(r.status === 200 && r.json?.listed === true, `staying listed is not a listing: republished, still in (${r.status})`);
  r = await call("/api/share", { method: "POST", token: e.access_token, body: { name: "Unlisted", model: SMALL } });
  if (r.json?.id) published.add(r.json.id);
  check(r.status === 201, `and publishing unlisted is not held up by it (${r.status})`);
}

/// The directory (supabase/directory.sql, api/_directory.js): what an owner
/// says about a model, what the server counts from its file, the gallery's
/// search, filters and sorts, a model's page with its licence, counts and
/// remix tree, and a view counted once per visitor per day and never for a
/// robot.
async function theDirectory(tokenA) {
  console.log("the directory");
  const f = await mintSession(emailF);
  const tokenF = f.access_token;
  const word = `zebrafinch${rand}`;
  // A file of its own: the gallery's part, as the site's owner, took the
  // probe's model out, and with it that very file at any other link.
  const GATE = MODEL.replace("0 Probe Tower", `0 Probe Gate ${rand}`);
  const list = (query = "") => call(`/api/share?op=list&page=1&tests=1${query}`);
  const ids = (l) => (l.json?.models || []).map((m) => m.id);

  // The kinds the gallery offers are the ones the Share panel guesses from.
  const gd = readFileSync(new URL("../../src/net/model_kinds.gd", import.meta.url), "utf8");
  const block = gd.slice(gd.indexOf("const KINDS"), gd.indexOf("\n]\n", gd.indexOf("const KINDS")));
  const app = [...block.matchAll(/\["([a-z]+)", "([^"]+)"\]/g)].map((m) => `${m[1]}=${m[2]}`);
  let l = await list();
  const site = (l.json?.kinds || []).map((k) => `${k.id}=${k.label}`);
  check(app.length >= 10 && app.join("|") === site.join("|"),
    `the gallery's kinds are the app's, in its order (${site.length} and ${app.length})`);

  // What an owner says, cleaned at the edge.
  const ABOUT = `A gatehouse with a ${word} on the wall.\u0007\r\n\r\n\r\n\r\nIt <b>opens</b> & "closes".`;
  let r = await call("/api/share", { method: "POST", token: tokenA, body: {
    name: "Probe Directory Gate", author: "Probe Builder", model: GATE, image: PICTURE, thumb: THUMB,
    listed: true, description: ABOUT, tags: "Castle, Tower!!, tower, <b>gate</b>, x",
    kind: "castle", licence: "cc-by-sa-4.0" } });
  const gate = r.json?.id || "";
  if (gate) published.add(gate);
  check(r.status === 201 && r.json?.description === `A gatehouse with a ${word} on the wall.\n\nIt <b>opens</b> & "closes".`,
    `published with a description, control characters out and blank lines one (${r.status}) ${JSON.stringify(r.json?.description)}`);
  check(JSON.stringify(r.json?.tags) === JSON.stringify(["castle", "tower", "b gate b"]),
    `tags in lower case, the same one once, the too short left out (${JSON.stringify(r.json?.tags)})`);
  check(r.json?.kind === "castle" && r.json?.licence === "cc-by-sa-4.0", `its kind and licence (${r.json?.kind}, ${r.json?.licence})`);
  check(r.json?.steps === 2 && r.json?.own_steps === false && r.json?.technic === false,
    `counted from the file: 2 steps, Brickworks's own, not Technic (${r.json?.steps}, ${r.json?.own_steps}, ${r.json?.technic})`);

  for (const [what, body, status] of [
    ["a description over 1000 characters", { description: "x".repeat(1001) }, 400],
    ["nine tags", { tags: "aa,bb,cc,dd,ee,ff,gg,hh,ii" }, 400],
    ["tags that are not words", { tags: [1, 2] }, 400],
    ["a kind that is not one", { kind: "spaceship" }, 400],
    ["a licence that is not one", { licence: "mit" }, 400],
    ["a small picture that is not a WebP", { thumb: PICTURE }, 415],
    ["a small picture over 64 KB", { thumb: Buffer.concat([Buffer.from(THUMB, "base64"), Buffer.alloc(70000)]).toString("base64") }, 413],
  ]) {
    r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Refused", model: SMALL, ...body } });
    check(r.status === status, `${what}: ${status} (${r.status}) "${r.json?.error}"`);
  }

  // Its own steps, and Technic: counted from the file, not said by it.
  const OWN = MODEL.replace("0 Author: Brickworks", "0 Author: Probe Person");
  r = await call("/api/share", { method: "POST", token: tokenF, body: { name: "Probe Own Steps", model: OWN, listed: true,
    kind: "castle", tags: "castle" } });
  const own = r.json?.id || "";
  if (own) published.add(own);
  check(r.status === 201 && r.json?.own_steps === true && r.json?.steps === 2,
    `a file not written by Brickworks, with steps: its builder's own (${r.status}, ${r.json?.own_steps})`);
  const GEARS = ["0 Probe Gears", "1 71 0 0 0 1 0 0 0 1 0 0 0 1 3743.dat", "1 71 40 0 0 1 0 0 0 1 0 0 0 1 3647.dat",
    "1 71 80 0 0 1 0 0 0 1 0 0 0 1 3648.dat", "1 15 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", ""].join("\r\n");
  r = await call("/api/share", { method: "POST", token: tokenF, body: { name: "Probe Gear Train", model: GEARS,
    listed: true, kind: "mechanism", licence: "all-rights-reserved" } });
  const gears = r.json?.id || "";
  if (gears) published.add(gears);
  check(r.status === 201 && r.json?.technic === true && r.json?.own_steps === false && r.json?.steps === 1,
    `three gears (one by its old number) and a brick: Technic or a mechanism; no steps, so one (${r.json?.technic}, ${r.json?.steps})`);

  // The list: asked, filtered, sorted.
  console.log("the gallery's search, filters and sorts");
  l = await list();
  const card = (l.json?.models || []).find((m) => m.id === gate) || {};
  check(card.kind === "castle" && JSON.stringify(card.tags) === JSON.stringify(["castle", "tower", "b gate b"])
    && card.licence === "cc-by-sa-4.0" && card.steps === 2 && card.own_steps === false && card.views === 0
    && card.likes === 0 && card.remixes === 0 && !("owner" in card) && !("description" in card),
    "a card: kind, tags, licence, steps, counts; no owner, no description");
  check(String(card.thumb || "").startsWith(`${base}/m/${gate}.webp?v=`) && card.image === `${base}/m/${gate}.png`,
    `and its small picture, by a versioned address (${card.thumb})`);
  // Asked at the versioned address the gallery's cards use: its v is the
  // upload's, not a version of the model (supabase/versions.sql).
  r = await call(`/m/${gate}.webp${new URL(card.thumb || "http://x/").search}`);
  check(r.status === 200 && r.headers.get("content-type") === "image/webp" && r.bytes.equals(Buffer.from(THUMB, "base64")),
    `the small picture at that address: 200 image/webp, the bytes published (${r.status})`);
  r = await call(`/api/share?id=${gate}`);
  check(r.json?.description?.startsWith("A gatehouse") && r.json?.tags?.length === 3 && r.json?.kind === "castle"
    && r.json?.licence === "cc-by-sa-4.0",
    "what the viewer and a session's gallery tool read carries what its owner said: description, tags, kind, licence");
  for (const [what, query, wanted, unwanted] of [
    ["a word of its description", `&q=${word}`, [gate], [own, gears]],
    ["a word's start, any case", `&q=${word.slice(0, 8).toUpperCase()}`, [gate], []],
    ["its name, two words", "&q=directory%20gate", [gate], [own]],
    ["a plural of its tag", "&q=towers", [gate], []],
    ["its credit", "&q=probe%20builder", [gate], [own]],
    ["a tag", "&tag=tower", [gate], [own, gears]],
    ["a kind", "&kind=castle", [gate, own], [gears]],
    ["another kind", "&kind=mechanism", [gears], [gate, own]],
    ["small", "&size=small", [gate, own, gears], []],
    ["large", "&size=large", [], [gate, own, gears]],
    ["has instructions", "&instructions=1", [own], [gate, gears]],
    ["Technic or mechanism", "&technic=1", [gears], [gate, own]],
    ["two at once", "&kind=castle&instructions=1", [own], [gate]],
    ["a word nothing has", `&q=nothing${rand}x`, [], [gate, own, gears]],
  ]) {
    const got = await list(query);
    const found = ids(got);
    check(got.status === 200 && wanted.every((id) => found.includes(id)) && !unwanted.some((id) => found.includes(id)),
      `${what} (${query}): ${wanted.length} wanted found, none unwanted (${got.status}, ${found.length})`);
  }
  for (const [what, query] of [["a search over 100 characters", `&q=${"x".repeat(101)}`], ["a kind that is not one", "&kind=boat"],
    ["a size that is not one", "&size=huge"], ["instructions=maybe", "&instructions=maybe"], ["a sort that is not one", "&sort=best"],
    ["a one-letter tag", "&tag=a"]]) {
    const got = await list(query);
    check(got.status === 400, `${what}: 400 (${got.status}) "${got.json?.error}"`);
  }
  l = await list("&q=%3Cscript%3E%20%27%20%26%20%7C%20!%20(");
  check(l.status === 200, `a search of nothing but punctuation and markup asks nothing of the database's syntax (${l.status})`);

  // A view, counted once a day per visitor, never a robot's.
  console.log("views");
  const PERSON = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
  const look = (id, headers) => call(`/api/share?op=seen&id=${id}`, { method: "POST", body: {}, headers });
  const asPerson = { "user-agent": PERSON, "sec-fetch-site": "same-origin" };
  r = await look(own, asPerson);
  check(r.status === 200 && r.json?.counted === true, `a person's first look: counted (${r.status}, ${r.json?.counted})`);
  r = await look(own, asPerson);
  check(r.json?.counted === false, "the same person again today: not counted");
  r = await look(own, { ...asPerson, "user-agent": PERSON.replace("Linux x86_64", "Macintosh; Intel Mac OS X 10_15_7") });
  check(r.json?.counted === true, "another person: counted");
  for (const [what, headers] of [
    ["a crawler", { "user-agent": "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)", "sec-fetch-site": "same-origin" }],
    ["a headless browser", { "user-agent": PERSON.replace("Chrome/", "HeadlessChrome/"), "sec-fetch-site": "same-origin" }],
    ["a link preview", { "user-agent": "facebookexternalhit/1.1", "sec-fetch-site": "same-origin" }],
    ["curl", { "user-agent": "curl/8.5.0" }],
    ["a page on another site", { "user-agent": PERSON, "sec-fetch-site": "cross-site" }],
    ["no Fetch Metadata", { "user-agent": PERSON }],
  ]) {
    r = await look(own, headers);
    check(r.status === 200 && r.json?.counted === false, `${what}: not counted`);
  }
  r = await look("QQQQQQQQQQ", asPerson);
  check(r.json?.counted === false, "a link that never was: nothing counted");
  r = await look("../x", asPerson);
  check(r.status === 400, `an id that is not one: 400 (${r.status})`);
  l = await list("&sort=views");
  const viewed = (l.json?.models || []).map((m) => m.views);
  check(viewed.every((n, k) => k === 0 || n <= viewed[k - 1])
    && (l.json?.models || []).find((m) => m.id === own)?.views === 2,
    `most viewed first, and the one looked at by two people says 2 (${viewed.slice(0, 4).join(", ")})`);

  // A remix, its licence, and the tree on both pages.
  console.log("remixes and licences");
  r = await call("/api/share", { method: "POST", token: tokenF, body: { name: "Probe Gate Remix", model: SMALL,
    remixed_from: gate, listed: true, licence: "cc-by-4.0" } });
  check(r.status === 422, `a version of a CC BY-SA model under CC BY: 422, never 403 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenF, body: { name: "Probe Gate Remix", model: SMALL,
    remixed_from: gate, listed: true, licence: "cc-by-sa-4.0", tags: "gate" } });
  const remix = r.json?.id || "";
  if (remix) published.add(remix);
  check(r.status === 201 && r.json?.remixed_from === gate, `under CC BY-SA too: shared and listed (${r.status})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Probe Gear Copy", model: SMALL,
    remixed_from: gears, listed: true, licence: "cc-by-4.0" } });
  check(r.status === 422, `a version of an all-rights-reserved model, listed: 422 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Probe Gear Copy", model: SMALL,
    remixed_from: gears, licence: "cc-by-4.0" } });
  if (r.json?.id) published.add(r.json.id);
  const byLink = r.json?.id || "";
  check(r.status === 201, `...shared by link only: allowed (${r.status})`);
  l = await list("&sort=remixes");
  const remixed = (l.json?.models || []).map((m) => m.remixes);
  check(remixed.every((n, k) => k === 0 || n <= remixed[k - 1]) && remixed[0] >= 1
    && (l.json?.models || []).find((m) => m.id === gate)?.remixes === 1,
    `most remixed first, the gate's one remix counted (${remixed.slice(0, 4).join(", ")})`);

  r = await call(`/m/${gate}`);
  const page = r.text;
  check(r.status === 200 && page.includes(`<p class="description">A gatehouse with a ${word} on the wall.\n\nIt &lt;b&gt;opens&lt;/b&gt; &amp; &quot;closes&quot;.</p>`),
    "its page: the description, escaped, its lines kept");
  // A tag is drawn as the kit's pill (site.css .pill.tag), so its link has a
  // class: the check is its address and its words, whatever it is styled as.
  check(page.includes('href="/gallery?tag=castle">castle</a>') && page.includes('href="/gallery?tag=b%20gate%20b">b gate b</a>'),
    "its tags, each a link to the gallery filtered by it");
  check(page.includes('<a href="/gallery?kind=castle">Castles and fantasy</a>'), "its kind, a link to the gallery's");
  check(page.includes("<b>CC BY-SA 4.0.</b>") && page.includes('href="https://creativecommons.org/licenses/by-sa/4.0/"')
    && page.includes("credit Probe Builder"), "its licence, with whom to credit and the licence itself");
  // A count is said once there is one: no "0 views" (docs/SOCIAL.md).
  check(page.includes("2 steps") && !page.includes("0 views") && page.includes(">1 remix<"),
    "its steps and counts: 2 steps, no views said, 1 remix");
  check(page.includes(`href="/m/${remix}"`) && page.includes("Probe Gate Remix"), "what was remixed from it, a card linking its page");
  check(page.includes('<link rel="stylesheet" href="/site.css">') && page.includes('class="site-head"')
    && page.includes('class="site-foot"') && /LEGO® is a trademark of the LEGO Group/.test(page),
    "a page of the site: its stylesheet, header and footer, with the notice");
  check(page.includes(`<link rel="canonical" href="${base}/m/${gate}">`) && page.includes("og:description")
    && page.includes(`content="A gatehouse with a ${word}`), "a canonical link, and the description in the card a link preview shows");
  check(/connect-src 'self'/.test(r.headers.get("content-security-policy") || "")
    && /style-src 'self' 'unsafe-inline'/.test(r.headers.get("content-security-policy") || ""),
    "its policy lets it load the site's stylesheet and talk to this site, and nowhere else");
  r = await call(`/m/${remix}`);
  check(r.text.includes(`Remixed from <a href="/m/${gate}">Probe Directory Gate</a>, by Probe Builder`)
    && r.text.includes("<h3>It came from</h3>"), "the remix's page names what it came from, and its line");
  r = await call(`/m/${byLink}`);
  check(r.text.includes(`href="/m/${gears}"`) && r.text.includes("Probe Gear Train"),
    "a copy of a listed model, itself shared by link, names the listed one");
  // Unlisted, the one it came from is no longer named.
  r = await call("/api/share", { method: "POST", token: tokenA, body: { id: gate, name: "Probe Directory Gate",
    author: "Probe Builder", model: GATE, listed: false } });
  check(r.status === 200 && r.json?.description === `A gatehouse with a ${word} on the wall.\n\nIt <b>opens</b> & "closes".`
    && r.json?.licence === "cc-by-sa-4.0" && r.json?.kind === "castle" && r.json?.tags?.length === 3,
    "republished saying nothing about it: what it said is kept");
  r = await call(`/m/${remix}`);
  check(r.text.includes("Remixed from a model shared by link") && !r.text.includes(`/m/${gate}"`),
    "unlisted, the model it came from is a model shared by link, not named or linked");
  r = await call(`/api/share?id=${remix}`);
  check(r.json?.remixed_from === null, "...nor in what the viewer reads");
  r = await call(`/m/${gate}.webp`);
  check(r.status === 404, `republished without a small picture: the old one is gone (${r.status})`);
  const thumbFile = await fetch(`${SUPABASE}/storage/v1/object/shared-thumbs/${gate}.webp`,
    { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  check(thumbFile.status === 400 || thumbFile.status === 404, `...from its bucket too (${thumbFile.status})`);
  const thumbPublic = await fetch(`${SUPABASE}/storage/v1/object/public/shared-thumbs/${own}.webp`);
  check(thumbPublic.status >= 400, `the small pictures' bucket is not public (${thumbPublic.status})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { id: gate, name: "Probe Directory Gate",
    model: GATE, description: "", tags: "", kind: "" } });
  check(r.status === 200 && r.json?.description === null && r.json?.tags?.length === 0 && r.json?.kind === null
    && r.json?.licence === "cc-by-sa-4.0", "emptied, they are emptied; the licence, not said, is kept");
  r = await call("/api/share?op=mine", { token: tokenF });
  const mineRow = (r.json?.shared || []).find((m) => m.id === own) || {};
  check(mineRow.kind === "castle" && Array.isArray(mineRow.tags) && "licence" in mineRow && "description" in mineRow,
    "the owner's own list has what each says, for the Share panel to show");

  // The database, with the key every page has.
  let d = await anonRest(`shared_models?id=eq.${own}&select=description,tags,licence,kind,steps,own_steps,technic,has_thumb`);
  check(d.status === 200 && d.json?.length === 1, `what a model says about itself is readable with the publishable key (${d.status})`);
  d = await anonRest(`shared_models?id=eq.${own}&select=search`);
  check(d.status === 401 || d.status === 403, `its search words are not (${d.status})`);
  d = await anonRest(`shared_models?id=eq.${own}&select=test`);
  check(d.status === 401 || d.status === 403, `nor whether it is a test (${d.status})`);
  for (const table of ["model_stats", "model_views"]) {
    d = await anonRest(`${table}?select=*`);
    check(d.status === 401 || d.status === 403, `${table} is closed (${d.status})`);
  }
  for (const [fn, args] of [["directory_models", { query: {} }], ["directory_model", { model_id: own }],
    ["count_view", { model_id: own, visitor_key: "0".repeat(32) }]]) {
    d = await anonRest(`rpc/${fn}`, { method: "POST", body: args });
    check(d.status >= 400, `${fn} cannot be called with it (${d.status})`);
  }
}

/// People (supabase/people.sql, api/people.js): a profile by a name its
/// owner chooses, listing only what they listed and are credited for;
/// likes counted on the model; favourites and private lists their owner's
/// alone; public lists with pages of their own.
async function thePeople(tokenA, tokenB) {
  console.log("people: profiles, likes, favourites and collections");
  const g = await mintSession(emailG);
  const tokenG = g.access_token;
  const handle = `probe-${rand}`;
  const NAME = `<b>Probe</b> & "Maker"`;

  let r = await call("/api/people?op=me");
  check(r.status === 401, `who am I, signed out: 401 (${r.status})`);
  r = await call("/api/people?op=me", { token: tokenG });
  check(r.status === 200 && r.json?.profile === null && Array.isArray(r.json?.collections) && r.json.collections.length === 0,
    "a new account has no profile and no lists: nothing is made from its address");
  for (const [what, body, status] of [
    ["a handle of two letters", { handle: "ab", name: "x" }, 400],
    ["a handle with a capital in a symbol", { handle: "a!b", name: "x" }, 400],
    ["a handle ending in a hyphen", { handle: "abc-", name: "x" }, 400],
    ["a handle with two hyphens together", { handle: "a--b", name: "x" }, 400],
    ["a handle of 25", { handle: "a".repeat(25), name: "x" }, 400],
    ["a handle kept for the site", { handle: "brickworks", name: "x" }, 409],
    ["no name", { handle, name: "   " }, 400],
    ["about you over 300", { handle, name: "x", bio: "y".repeat(301) }, 400],
  ]) {
    r = await call("/api/people?op=profile", { method: "POST", token: tokenG, body });
    check(r.status === status, `${what}: ${status} (${r.status}) "${r.json?.error}"`);
  }
  r = await call("/api/people?op=profile", { method: "POST", body: { handle, name: "x" } });
  check(r.status === 401, `a profile, signed out: 401 (${r.status})`);
  r = await call("/api/people?op=profile", { method: "POST", token: tokenG,
    body: { handle: handle.toUpperCase(), name: `${NAME}\u0007`, bio: "Builds\r\n\r\n\r\nthings." } });
  check(r.status === 200 && r.json?.handle === handle && r.json?.name === NAME && r.json?.bio === "Builds\n\nthings."
    && r.json?.url === `${base}/u/${handle}`, `made: its handle in lower case, the name cleaned (${r.status} ${r.json?.handle})`);
  r = await call("/api/people?op=profile", { method: "POST", token: tokenA, body: { handle, name: "Somebody else" } });
  check(r.status === 409, `somebody else taking the same handle: 409 (${r.status}) "${r.json?.error}"`);

  // What the profile lists: listed and credited, nothing else.
  const publish = async (body) => {
    const reply = await call("/api/share", { method: "POST", token: tokenG, body: { model: SMALL, ...body } });
    if (reply.json?.id) published.add(reply.json.id);
    return reply.json?.id || "";
  };
  const credited = await publish({ name: "Probe Credited", author: "Probe Maker", listed: true, kind: "castle" });
  const nameless = await publish({ name: "Probe Nameless", listed: true });
  const byLink = await publish({ name: "Probe By Link", author: "Probe Maker" });
  r = await call(`/api/people?op=profile&handle=${handle}&tests=1`);
  const shown = (r.json?.models || []).map((m) => m.id);
  check(r.status === 200 && r.json?.name === NAME && r.json?.models_count === 1 && shown.includes(credited)
    && !shown.includes(nameless) && !shown.includes(byLink) && !("account" in (r.json || {})),
    `its profile lists what it listed and is credited for, and nothing shared without a name or only by link (${shown.length})`);
  check(r.headers.get("cache-control") === "private, no-store", `asked with tests=1, never kept (${r.headers.get("cache-control")})`);
  r = await call(`/api/people?op=profile&handle=${handle}`);
  check(r.status === 200 && r.json?.models_count === 0 && (r.json?.models || []).length === 0,
    `as a visitor sees it, none of its models: they are tests (${r.json?.models_count}, ${(r.json?.models || []).length})`);
  r = await call(`/u/${handle}`);
  // It says so in words: a count of none is not shown (design_flow).
  check(r.status === 200 && !r.text.includes(`/m/${credited}`) && r.text.includes("Nothing in the gallery yet."),
    `and its page shows none (${r.status})`);
  r = await call(`/u/${handle}?tests=1`);
  check(r.status === 200 && r.text.includes("&lt;b&gt;Probe&lt;/b&gt; &amp; &quot;Maker&quot;") && !r.text.includes("<b>Probe</b>")
    && r.text.includes(`href="/m/${credited}"`) && !r.text.includes(`/m/${nameless}`) && !r.text.includes(`/m/${byLink}`)
    && r.text.includes(`<link rel="canonical" href="${base}/u/${handle}">`) && r.text.includes('class="site-head"'),
    `/u/${handle}: its name escaped, its credited model's card, nothing else, a page of the site (${r.status})`);
  r = await call("/u/nobody-has-this");
  check(r.status === 404, `a handle nobody has: 404 (${r.status})`);
  r = await call(`/m/${credited}`);
  check(r.text.includes(`<a class="who" href="/u/${handle}">`) && r.text.includes("<b>&lt;b&gt;Probe&lt;/b&gt;"),
    "the credited model's page links its profile");
  // Its page may end on the credited one's card, which names its designer
  // (More in the gallery): the page itself, above those rows, credits none.
  r = await call(`/m/${nameless}`);
  check(r.status === 200 && !r.text.split('<section class="next"')[0].includes(`/u/${handle}`)
    && !r.text.includes('<div class="shared-by">'), "the one shared without a name does not");
  let l = await call(`/api/share?op=list&page=1&tests=1&q=probe%20credited`);
  const card = (l.json?.models || []).find((m) => m.id === credited) || {};
  check(card.by?.handle === handle && (l.json?.models || []).find((m) => m.id === nameless)?.by == null,
    "a card says who shared it, by handle, only when credited");

  // A credit is the profile (walk180, 2026-10-23): an app before m157
  // offered a name made from the address ("Delivered+walk 180 Web"), and
  // the page credited it under a head saying the profile. Sent so, it
  // credits the profile's name and handle everywhere it is said, and no
  // part of the address is anywhere a visitor reads.
  const local = emailG.split("@")[0];
  const fromAddress = local.replace(/[-_.]/g, " ").replace(/\b[a-z]/g, (c) => c.toUpperCase());
  const leaks = (text) => [local, fromAddress, "Delivered+bw", "delivered+bw", emailG].filter((one) => text.includes(one));
  r = await call("/api/share", { method: "POST", token: tokenG, body: { model: SMALL, name: "Probe From Address", author: fromAddress } });
  const addressed = r.json?.id || "";
  if (addressed) published.add(addressed);
  check([200, 201].includes(r.status) && r.json?.author === NAME,
    `published with a credit made from its address ("${fromAddress}"), it credits the profile's name (${r.status}, ${r.json?.author})`);
  r = await call(`/api/share?id=${addressed}`);
  check(r.json?.author === NAME && !leaks(r.text).length, `the viewer's answer says the profile's name, nothing of the address (${r.json?.author}; ${leaks(r.text)})`);
  r = await call(`/m/${addressed}`);
  const ld = JSON.parse((r.text.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/) || [])[1] || "{}");
  const escapedName = "&lt;b&gt;Probe&lt;/b&gt; &amp; &quot;Maker&quot;";
  check(r.status === 200 && r.text.includes(`they credit ${escapedName} (<a href="/u/${handle}">@${handle}</a>)`)
    && r.text.includes(`<meta name="description" content="1 part, by ${escapedName}.`)
    && ld.author?.name === NAME && ld.author?.url === `${base}/u/${handle}` && !leaks(r.text).length,
    `its page's licence credits the profile's name and @handle, as its head, description and data do; nothing of the address (${leaks(r.text)})`);
  r = await call(`/m/${addressed}/embed`);
  check(r.status === 200 && r.text.includes(`by ${escapedName} · Brickworks`) && !leaks(r.text).length,
    `its card for a blog credits the profile's name (${r.status}; ${leaks(r.text)})`);
  r = await call("/api/share?op=mine", { token: tokenG });
  check(r.json?.credit?.name === NAME && r.json?.credit?.handle === handle,
    `the app is told whom Show who made it credits: the profile (${JSON.stringify(r.json?.credit)})`);
  // With no profile, a name made from the address is refused in words.
  r = await call("/api/people?op=me", { token: tokenA });
  const bare = r.json?.profile === null;
  const localA = emailA.split("@")[0];
  r = await call("/api/share", { method: "POST", token: tokenA, body: { model: SMALL, name: "Probe Addressed",
    author: localA.replace(/[-_.]/g, " ").replace(/\b[a-z]/g, (c) => c.toUpperCase()) } });
  if (r.json?.id) published.add(r.json.id);
  check(bare && r.status === 422 && /address you sign in with/.test(r.json?.error || ""),
    `no profile, and a credit made from the address: 422 (${bare ? "no profile" : "a profile"}, ${r.status}) "${r.json?.error}"`);
  r = await call("/api/share?op=mine", { token: tokenA });
  check(r.status === 200 && r.json?.credit === null, `with no profile, the app is offered nobody to credit (${JSON.stringify(r.json?.credit)})`);

  // Likes.
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", body: { on: true } });
  check(r.status === 401, `a like, signed out: 401 (${r.status})`);
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", token: tokenA, body: { on: "yes" } });
  check(r.status === 400, `on that is not true or false: 400 (${r.status})`);
  r = await call("/api/people?op=like&id=QQQQQQQQQQ", { method: "POST", token: tokenA, body: { on: true } });
  check(r.status === 404, `a like of a link that never was: 404 (${r.status})`);
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", token: tokenA, body: { on: true } });
  check(r.status === 200 && r.json?.liked === true && r.json?.likes === 1, `liked: 1 like (${r.json?.likes})`);
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", token: tokenA, body: { on: true } });
  check(r.json?.likes === 1, "liked again by the same account: still 1");
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", token: tokenB, body: { on: true } });
  check(r.json?.likes === 2, `another account: 2 (${r.json?.likes})`);
  r = await call(`/api/people?op=like&id=${credited}`, { method: "POST", token: tokenB, body: { on: false } });
  check(r.json?.likes === 1 && r.json?.liked === false, "unliked: 1");
  r = await call(`/m/${credited}`);
  check(r.text.includes('aria-label="Like, 1 like"') && r.text.includes('<span class="n" aria-hidden="true">1</span>'),
    "its page counts it, on its Like");
  l = await call("/api/share?op=list&page=1&tests=1&sort=likes");
  const liked = (l.json?.models || []).map((m) => m.likes);
  check(liked.every((n, k) => k === 0 || n <= liked[k - 1]) && (l.json?.models || []).find((m) => m.id === credited)?.likes === 1,
    `most liked first (${liked.slice(0, 4).join(", ")})`);
  r = await call(`/api/people?op=marks&id=${credited}`, { token: tokenA });
  check(r.status === 200 && r.json?.liked === true && r.json?.favourite === false, "what the account did to it: liked, not kept");

  // Favourites: the owner's alone, one shared by link included.
  r = await call(`/api/people?op=favourite&id=${byLink}`, { method: "POST", token: tokenA, body: { on: true } });
  check(r.status === 200 && r.json?.favourite === true, `kept a model shared by link (${r.status})`);
  r = await call("/api/people?op=favourites&page=1", { token: tokenA });
  check(r.status === 200 && (r.json?.models || []).some((m) => m.id === byLink), "it is in their favourites");
  r = await call("/api/people?op=favourites&page=1", { token: tokenB });
  check(!(r.json?.models || []).some((m) => m.id === byLink), "and in nobody else's");
  r = await call("/api/people?op=favourites&page=1");
  check(r.status === 401, `favourites signed out: 401 (${r.status})`);

  // Lists.
  r = await call("/api/people?op=collection", { method: "POST", token: tokenA, body: { name: "<i>Castles</i> I like", public: false } });
  const list = r.json?.id || "";
  check(r.status === 200 && ID.test(list) && r.json?.public === false, `a list made, private (${r.status} ${list})`);
  for (const model of [credited, byLink]) {
    r = await call("/api/people?op=collect", { method: "POST", token: tokenA, body: { collection: list, model, on: true } });
  }
  check(r.status === 200 && r.json?.has === true, "two models put in it");
  r = await call("/api/people?op=collect", { method: "POST", token: tokenB, body: { collection: list, model: credited, on: false } });
  check(r.status === 404, `somebody else changing it: 404 (${r.status})`);
  r = await call(`/api/people?op=collection&id=${list}`, { token: tokenB });
  check(r.status === 404, `somebody else asking for a private list: 404, as for none (${r.status})`);
  r = await call(`/c/${list}`);
  check(r.status === 404, `nor has it a page (${r.status})`);
  r = await call(`/api/people?op=collection&id=${list}`, { token: tokenA });
  check(r.status === 200 && r.json?.mine === true && r.json?.count === 2 && (r.json?.models || []).length === 2,
    "its owner sees both, the one shared by link too");
  r = await call("/api/people?op=collection", { method: "POST", token: tokenA, body: { id: list, name: "<i>Castles</i> I like", public: true } });
  check(r.status === 200 && r.json?.public === true, "made public");
  r = await call(`/api/people?op=collection&id=${list}&tests=1`);
  check(r.status === 200 && r.json?.count === 1 && (r.json?.models || []).map((m) => m.id).join() === credited,
    "anybody now sees it, with only the listed model in it");
  r = await call(`/c/${list}?tests=1`);
  check(r.status === 200 && r.text.includes("&lt;i&gt;Castles&lt;/i&gt; I like") && r.text.includes(`href="/m/${credited}"`)
    && !r.text.includes(`/m/${byLink}`), `its page: its name escaped, the listed model and not the other (${r.status})`);
  r = await call(`/api/people?op=collection&id=${list}`);
  const page = await call(`/c/${list}`);
  check(r.status === 200 && r.json?.count === 0 && (r.json?.models || []).length === 0 && page.status === 200
    && !page.text.includes(`/m/${credited}`),
    `as a visitor sees it and its page, without the test model (${r.json?.count}, ${page.status})`);
  r = await call(`/api/people?op=marks&id=${credited}`, { token: tokenA });
  check((r.json?.collections || []).some((c) => c.id === list && c.has === true), "the model's marks say which list has it");
  r = await call(`/api/people?op=uncollection&id=${list}`, { method: "POST", token: tokenB });
  check(r.status === 404, `somebody else deleting it: 404 (${r.status})`);
  r = await call(`/api/people?op=uncollection&id=${list}`, { method: "POST", token: tokenA });
  check(r.status === 200 && (await call(`/c/${list}`)).status === 404, "deleted by its owner, its page gone");

  // The database, with the key every page has.
  for (const table of ["people", "model_likes", "model_favourites", "model_collections", "model_collection_items"]) {
    const d = await anonRest(`${table}?select=*`);
    check(d.status === 401 || d.status === 403, `${table} is closed to it (${d.status})`);
  }
  const d = await anonRest("rpc/profile_page", { method: "POST", body: { wanted: handle } });
  check(d.status >= 400, `profile_page cannot be called with it (${d.status})`);
  const p = await anonRest(`profiles?select=email&limit=1`);
  check(p.status === 401 || p.status === 403 || (p.status === 200 && (p.json || []).length === 0),
    `schema.sql's profiles, with addresses, as closed as before (${p.status})`);
}

/// Moderation (supabase/moderation.sql, api/_names.js, api/admin.js): what
/// the gallery will not show in a name, a report from anybody, the site's
/// owner taking a model out at every link and an account out whole, how
/// often a person may do each thing, and the sitemap.
async function theModeration(tokenA) {
  console.log("moderation: names, reports, taking out, limits, the sitemap");
  const h = await mintSession(emailH);
  const tokenH = h.access_token;
  const i = await mintSession(emailI);
  const tokenI = i.access_token;
  const publish = async (token, body) => {
    const reply = await call("/api/share", { method: "POST", token, body: { model: SMALL, ...body } });
    if (reply.json?.id) published.add(reply.json.id);
    return reply;
  };

  // Names.
  for (const [what, body] of [
    ["a name with abuse in it, spelt round", { name: "my sh1t castle" }],
    ["a name that is the LEGO Group's", { name: "My LEGO castle" }],
    ["a licensed name, run together", { name: "StarWars cruiser" }],
    ["a tag that is a licensed name", { name: "A cruiser", tags: "space, star wars" }],
    ["a credit with abuse in it", { name: "A cruiser", author: "f u c k" }],
    ["a description with a slur in it", { name: "A cruiser", description: "for you, n1gger" }],
  ]) {
    const r = await publish(tokenH, body);
    check(r.status === 400, `${what}: 400 (${r.status}) "${r.json?.error}"`);
  }
  let r = await publish(tokenH, { name: "A starfighter", description: "Inspired by Star Wars, in my own colours." });
  check(r.status === 201, `a description may say what inspired it (${r.status})`);
  r = await call("/api/people?op=profile", { method: "POST", token: tokenH, body: { handle: `lego-fan-${rand}`, name: "x" } });
  check(r.status === 409, `a handle with the LEGO Group's mark in it: 409 (${r.status}) "${r.json?.error}"`);
  r = await call("/api/people?op=profile", { method: "POST", token: tokenH, body: { handle: `maker-${rand}`, name: "Batman" } });
  check(r.status === 400, `a profile's name that is a licensed one: 400 (${r.status})`);
  r = await call("/api/people?op=collection", { method: "POST", token: tokenH, body: { name: "Shit I like" } });
  check(r.status === 400, `a collection's name with abuse in it: 400 (${r.status})`);

  // A bad actor, as the gallery sees them: a profile, a listed model, a
  // public collection.
  const handle = `bad-actor-${rand}`;
  r = await call("/api/people?op=profile", { method: "POST", token: tokenH, body: { handle, name: "Bad Actor" } });
  check(r.status === 200, `the bad actor's profile (${r.status})`);
  const BAD = MODEL.replace("0 Probe Tower", `0 Probe Bad ${rand}`);
  r = await publish(tokenH, { name: "Probe Bad Model", author: "Bad Actor", model: BAD, listed: true });
  const bad = r.json?.id || "";
  check(r.status === 201, `their model, listed (${r.status} ${bad})`);
  r = await publish(tokenH, { name: "Probe Bad Second", author: "Bad Actor", listed: true });
  const second = r.json?.id || "";
  r = await call("/api/people?op=collection", { method: "POST", token: tokenH, body: { name: "Probe bad list", public: true } });
  const badList = r.json?.id || "";
  await call("/api/people?op=collect", { method: "POST", token: tokenH, body: { collection: badList, model: second, on: true } });

  // Reports, signed out and signed in.
  const visitor = { "user-agent": `share-probe-${rand}` };
  const report = (body, token) => call("/api/people?op=report", { method: "POST", token, body, headers: visitor });
  r = await report({ model: bad, reason: "copied", note: "Copied from my own <b>castle</b>.", contact: "owner@example.com" });
  check(r.status === 200 && r.json?.reported === true, `a model reported, signed out (${r.status})`);
  for (const [what, body, status] of [
    ["a reason that is not one", { model: bad, reason: "boring" }, 400],
    ["two things at once", { model: bad, handle, reason: "spam" }, 400],
    ["nothing named", { reason: "spam" }, 400],
    ["a link that never was", { model: "QQQQQQQQQQ", reason: "spam" }, 404],
    ["a note over 1000", { model: bad, reason: "other", note: "x".repeat(1001) }, 400],
  ]) {
    r = await report(body);
    check(r.status === status, `a report of ${what}: ${status} (${r.status})`);
  }
  r = await report({ handle, reason: "offensive" }, tokenA);
  check(r.status === 200, `a profile reported, signed in (${r.status})`);
  r = await report({ collection: badList, reason: "spam" });
  check(r.status === 200, `a public collection reported (${r.status})`);
  let limited = null;
  for (let n = 0; n < 6 && !limited; n += 1) {
    r = await report({ model: second, reason: "spam" });
    if (r.status !== 200) limited = r;
  }
  check(limited?.status === 429, `six reports an hour from one visitor, then 429 (${limited?.status}) "${limited?.json?.error}"`);

  // The site's owner.
  if (args.master) {
    const m = await mintSession(process.env.MASTER_EMAIL);
    const master = m.access_token;
    r = await call("/api/admin", { token: master });
    const mine = (r.json?.reports || []).filter((one) => one.model === bad || one.handle === handle || one.collection === badList);
    const first = mine.find((one) => one.model === bad && one.reason === "copied") || {};
    check(r.status === 200 && first.name === "Probe Bad Model" && first.note === "Copied from my own <b>castle</b>."
      && first.contact === "owner@example.com" && first.email === emailH && !("reporter" in first) && !("visitor" in first),
      `the owner's page has the reports, what was said, the way to reach them and the account; never who reported (${mine.length})`);
    const profileReport = mine.find((one) => one.handle === handle);
    r = await call(`/api/admin?op=dismiss&report=${profileReport?.id}`, { method: "POST", token: master });
    check(r.status === 200, `a report let go (${r.status})`);
    r = await call("/api/admin", { token: master });
    check(!(r.json?.reports || []).some((one) => one.id === profileReport?.id), "and it is off the queue");
    r = await call(`/api/admin?op=dismiss&report=${profileReport?.id}`, { method: "POST", token: tokenA });
    check(r.status === 404, `anybody else letting one go: 404 (${r.status})`);

    // Out by model: at this link and at any other.
    r = await call(`/api/admin?op=unlist&id=${bad}`, { method: "POST", token: master });
    check(r.status === 200 && r.json?.file_barred === true, `the model taken out, and its file barred (${r.status})`);
    r = await call("/api/admin", { token: master });
    check(!(r.json?.reports || []).some((one) => one.model === bad), "its reports settled");
    r = await publish(tokenH, { name: "Probe Bad Again", author: "Bad Actor", model: BAD, listed: true });
    check(r.status === 409, `the same file published again at a new link, listed: 409 (${r.status}) "${r.json?.error}"`);
    r = await publish(tokenI, { name: "Probe Bad Copy", model: BAD.replace(/\r\n/g, "\n") + "\n\n", listed: true });
    check(r.status === 409, `by another account, its line endings changed: 409 (${r.status})`);
    r = await publish(tokenH, { name: "Probe Bad Again", model: BAD });
    check(r.status === 201, `shared by link only: allowed (${r.status})`);
    r = await publish(tokenH, { name: "Probe Changed", author: "Bad Actor", model: BAD.replace("3003.dat", "3004.dat"), listed: true });
    check(r.status === 201, `a model that is not the same file: listed (${r.status})`);
    const changed = r.json?.id || "";

    // Out by account.
    r = await call(`/api/admin?op=bar&id=${second}`, { method: "POST", token: master, body: { reason: "probe" } });
    check(r.status === 200 && r.json?.barred === true && r.json?.unlisted >= 2,
      `the account taken out by one of its models: ${r.json?.unlisted} unlisted, ${r.json?.files_barred} files barred`);
    let l = await call("/api/share?op=list&page=1&tests=1&q=probe%20bad");
    check(![second, changed].some((id) => (l.json?.models || []).some((one) => one.id === id)), "every model of it out of the gallery");
    r = await call(`/u/${handle}?tests=1`);
    check(r.status === 404, `its profile gone (${r.status})`);
    r = await call(`/c/${badList}?tests=1`);
    check(r.status === 404, `its public collection gone (${r.status})`);
    r = await publish(tokenH, { name: "Probe New Link", author: "Bad Actor", model: SMALL.replace("3001", "3002"), listed: true });
    check(r.status === 409, `anything new it lists: 409 (${r.status}) "${r.json?.error}"`);
    r = await publish(tokenH, { name: "Probe New Link", model: SMALL.replace("3001", "3002") });
    check(r.status === 201, `by link only: allowed (${r.status})`);
    r = await call("/api/admin", { token: master });
    const out = (r.json?.barred || []).find((one) => one.email === emailH);
    check(Boolean(out) && out.reason === "probe", "the owner's page lists the account, and why");
    r = await call(`/api/admin?op=bar&id=${second}`, { method: "POST", token: tokenA });
    check(r.status === 404, `anybody else taking an account out: 404 (${r.status})`);
    r = await call(`/api/admin?op=unbar&account=${out?.account}`, { method: "POST", token: master });
    check(r.status === 200, `let back in (${r.status})`);
    r = await publish(tokenH, { name: "Probe Back", author: "Bad Actor", model: SMALL.replace("3001", "3005"), listed: true });
    check(r.status === 201, `and it may list again (${r.status})`);
  } else {
    console.log("  --    the site's owner taking out a model and an account: with --master");
  }

  // How often: twenty lists an hour.
  let made = 0;
  let refused = null;
  for (let n = 0; n < 22 && !refused; n += 1) {
    r = await call("/api/people?op=collection", { method: "POST", token: tokenI, body: { name: `Probe list ${n}` } });
    if (r.status === 200) made += 1;
    else refused = r;
  }
  check(made === 20 && refused?.status === 429, `twenty collections an hour, then 429 (${made}, ${refused?.status})`);

  // The sitemap. Pages are cached for 30 s and served stale for 30 more
  // (api/share.js), so a model taken out a moment ago may still be listed:
  // ask again until the minute has passed.
  let locs = [];
  let listed = [];
  for (let tries = 0; tries < 8; tries += 1) {
    r = await call("/sitemap.xml");
    locs = [...r.text.matchAll(/<loc>([^<]+)<\/loc>/g)].map((one) => one[1]);
    listed = (await call("/api/share?op=list&page=1")).json?.models || [];
    if (listed.every((one) => locs.includes(`${base}/m/${one.id}`)) && !(args.master && locs.includes(`${base}/m/${bad}`))) break;
    await new Promise((done) => setTimeout(done, 10000));
  }
  check(r.status === 200 && /xml/.test(r.headers.get("content-type") || "") && locs.some((loc) => loc.endsWith("/gallery"))
    && locs.some((loc) => loc.endsWith("/takedown")) && listed.every((one) => locs.includes(`${base}/m/${one.id}`))
    // Only the owner (--master) takes the bad actor's model out.
    && !(args.master && locs.includes(`${base}/m/${bad}`)),
    `/sitemap.xml: the site's pages and every listed model (${locs.length} pages), none taken out`
    + ` [missing: ${listed.filter((one) => !locs.includes(`${base}/m/${one.id}`)).map((one) => `${one.id} ${one.name}`).join(", ") || "none"};`
    + ` taken out still there: ${locs.includes(`${base}/m/${bad}`)}; gallery: ${locs.some((loc) => loc.endsWith("/gallery"))}; takedown: ${locs.some((loc) => loc.endsWith("/takedown"))}; status ${r.status}]`);
  const tests = [...published].filter((id) => locs.includes(`${base}/m/${id}`));
  check(tests.length === 0 && !locs.some((loc) => /\/u\/(probe|bad-actor)-/.test(loc)),
    `...and none of the probe's: a test model, or a profile with nothing else, is never in it (${tests.join(", ") || "none"})`);

  // The database, with the key every page has.
  for (const table of ["reports", "barred_accounts", "barred_models", "act_log"]) {
    const d = await anonRest(`${table}?select=*`);
    check(d.status === 401 || d.status === 403, `${table} is closed to it (${d.status})`);
  }
  for (const [fn, args] of [["may_act", { actor: "x", act: "report", per_hour: 9, per_day: 9 }],
    ["is_barred", { account: h.kept.user_id }], ["sitemap_pages", {}]]) {
    const d = await anonRest(`rpc/${fn}`, { method: "POST", body: args });
    check(d.status >= 400, `${fn} cannot be called with it (${d.status})`);
  }
}

async function cleanUp() {
  // What moderation keeps that does not go with an account: the files the
  // site's owner barred, and reports of a profile by its handle. How often
  // each account did things goes below; a signed-out visitor's counts go
  // with the daily sweep, a day on.
  const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  const ids = [...published];
  for (let at = 0; at < ids.length; at += 50) {
    await fetch(`${SUPABASE}/rest/v1/barred_models?model=in.(${ids.slice(at, at + 50).join(",")})`,
      { method: "DELETE", headers: secret }).catch(() => {});
  }
  await fetch(`${SUPABASE}/rest/v1/reports?handle=in.(probe-${rand},bad-actor-${rand})`,
    { method: "DELETE", headers: secret }).catch(() => {});
  // Every model published here is taken down (the files go with that),
  // then every account, which takes their rows with them.
  const sessions = [];
  for (const email of [emailA, emailB, emailD, emailE, emailF, emailG, emailH, emailI]) {
    sessions.push(await mintSession(email).catch(() => null));
  }
  const accounts = sessions.filter(Boolean).map((one) => one.kept.user_id).filter(Boolean);
  if (accounts.length) {
    await fetch(`${SUPABASE}/rest/v1/act_log?who=in.(${accounts.join(",")})`, { method: "DELETE", headers: secret })
      .catch(() => {});
  }
  for (const id of published) {
    for (const s of sessions) {
      if (s) await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: s.access_token }).catch(() => {});
    }
  }
  await deleteAccount(emailC).catch(() => false);
  const goneA = await deleteAccount(emailA);
  const goneB = await deleteAccount(emailB);
  const goneD = await deleteAccount(emailD);
  const goneE = await deleteAccount(emailE);
  const goneF = await deleteAccount(emailF);
  const goneG = await deleteAccount(emailG);
  const goneH = await deleteAccount(emailH);
  const goneI = await deleteAccount(emailI);
  check(goneA && goneB && goneD && goneE && goneF && goneG && goneH && goneI,
    "every throwaway account deleted, and their rows with them");
  const left = await call(`/api/share?id=${[...published][0] || "QQQQQQQQQQ"}`);
  check(left.status === 404, `nothing left behind: the link is gone with the account (${left.status})`);
}

try {
  await main();
} catch (trouble) {
  failures += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  await cleanUp();
}
console.log(failures === 0
  ? `a model can be shared by link, and nothing else can be done with one (${checks} checks)`
  : `${failures} of ${checks} checks FAILED`);
process.exit(failures === 0 ? 0 : 1);
