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
// Throwaway accounts at Resend test addresses (no email is sent: the
// sessions are minted here), deleted at the end with every row of theirs.
// Every model this publishes is unpublished or swept before that, so no
// file is left in the bucket.
import { randomBytes } from "node:crypto";
import { deleteAccount, mintSession } from "./session.mjs";

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

async function call(path, { method = "GET", token, body, raw } = {}) {
  const headers = {};
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
  const reply = await fetch(path.startsWith("http") ? path : base + path, {
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

const rand = randomBytes(4).toString("hex");
const emailA = `delivered+bw-share-a-${rand}@resend.dev`;
const emailB = `delivered+bw-share-b-${rand}@resend.dev`;
const emailC = `delivered+bw-share-c-${rand}@resend.dev`;
// The gallery's: one who remixes, one who lists too much.
const emailD = `delivered+bw-share-d-${rand}@resend.dev`;
const emailE = `delivered+bw-share-e-${rand}@resend.dev`;
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
  check(r.text.includes("9 parts, by Probe Builder"), "it says the part count and who made it");
  check(r.text.includes(`data-viewer="/app?view=${id}"`) && r.text.includes('<script src="/share-page.js"'),
    "a person goes on to the viewer, /app?view=<id>");
  check(/frame-ancestors 'none'/.test(r.headers.get("content-security-policy") || ""), "the page is not frameable");

  r = await call(`/m/${id}.png`);
  check(r.status === 200 && r.headers.get("content-type") === "image/png" && r.bytes.equals(Buffer.from(PICTURE, "base64")),
    `its picture: 200 image/png, the bytes published (${r.status} ${r.headers.get("content-type")})`);
  check(r.headers.get("cross-origin-resource-policy") === "cross-origin", "the picture may be shown on any site");

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
  const list = () => call("/api/share?op=list&page=1");
  const inList = (l, id) => (l.json?.models || []).some((m) => m.id === id);
  const d = await mintSession(emailD);
  const tokenD = d.access_token;

  let r = await call("/api/share", { method: "POST", token: tokenA,
    body: { name: "Probe Gallery", author: "Probe Builder", model: MODEL, image: PICTURE, listed: true } });
  const listedId = r.json?.id || "";
  if (listedId) published.add(listedId);
  check(r.status === 201 && r.json?.listed === true && r.json?.gallery === `${base}/gallery`,
    `published with listed: true (${r.status}, listed ${r.json?.listed}, ${r.json?.gallery})`);
  let l = await list();
  const card = l.json?.models?.[0] || {};
  check(l.status === 200 && card.id === listedId && card.name === "Probe Gallery" && card.author === "Probe Builder"
    && card.parts === 9 && card.url === `${base}/m/${listedId}` && card.image === `${base}/m/${listedId}.png`,
    `?op=list has it first, with its name, author, part count, link and picture (${l.status}, ${card.id})`);
  check(!("owner" in card) && l.json?.per_page === 24 && typeof l.json?.more === "boolean",
    "...no owner, and a page of 24 that says whether there is another");
  check(!inList(l, unlistedId), "a model shared without the box ticked is not in it");
  check(/no-cache|no-store/.test(l.headers.get("cache-control") || ""),
    `the list is asked again each time (${l.headers.get("cache-control")})`);
  const pages = [];
  for (const bad of ["0", "-1", "x", "1.5", "401"]) pages.push((await call(`/api/share?op=list&page=${bad}`)).status);
  check(pages.every((s) => s === 400), `a page that is not 1 to 400: 400 (${pages.join(", ")})`);
  r = await call("/api/share", { method: "POST", token: tokenA, body: { name: "Listed?", model: MODEL, listed: "yes" } });
  check(r.status === 400, `listed that is not true or false: 400 (${r.status}) "${r.json?.error}"`);

  // A name that is markup, listed by somebody else, later: first now.
  const MARKUP = `<img src=x onerror="alert(1)">Probe & "Co"`;
  r = await call("/api/share", { method: "POST", token: tokenD, body: { name: MARKUP, model: SMALL, listed: true } });
  const markupId = r.json?.id || "";
  if (markupId) published.add(markupId);
  l = await list();
  check(l.json?.models?.[0]?.id === markupId && l.json?.models?.[1]?.id === listedId,
    "newest first: one listed later is ahead of it");
  check(l.json?.models?.[0]?.name === MARKUP, "the list gives a name as the text it is, for the page to show as text");
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

async function cleanUp() {
  // Every model published here is taken down (the files go with that),
  // then every account, which takes their rows with them.
  const sessions = [];
  for (const email of [emailA, emailB, emailD, emailE]) {
    sessions.push(await mintSession(email).catch(() => null));
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
  check(goneA && goneB && goneD && goneE, "every throwaway account deleted, and their rows with them");
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
