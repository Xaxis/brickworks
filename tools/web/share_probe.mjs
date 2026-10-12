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
// Two throwaway accounts at Resend test addresses (no email is sent: the
// sessions are minted here), deleted at the end with every row of theirs.
// Every model this publishes is unpublished before that, so no file is
// left in the bucket.
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

async function cleanUp() {
  // Every model published here is taken down (the files go with that),
  // then both accounts, which takes their rows with them.
  const sessionA = await mintSession(emailA).catch(() => null);
  const sessionB = await mintSession(emailB).catch(() => null);
  for (const id of published) {
    for (const s of [sessionA, sessionB]) {
      if (s) await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: s.access_token }).catch(() => {});
    }
  }
  const goneA = await deleteAccount(emailA);
  const goneB = await deleteAccount(emailB);
  check(goneA && goneB, "both throwaway accounts deleted, and their rows with them");
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
