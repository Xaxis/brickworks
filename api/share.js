// Sharing a model by link (2026-10-12).
//
// Someone signed in publishes the model they have open, from File ›
// Share… in the app, and gets https://brickworks.diy/m/<id>. Anyone may
// open that link without an account: the app in a read-only mode
// (/app?view=<id>) with the model, its steps, its booklet and its parts
// list, and Open in Brickworks to copy it into their own account.
//
//   GET  ?id=X               the model, as the viewer loads it: name,
//                            author, part count and the .mpd itself
//   GET  ?op=page&id=X       /m/X: the link's own page — a title and a
//                            picture for anything that previews links,
//                            and then the viewer
//   GET  ?op=image&id=X      /m/X.png: that picture, rendered by the app
//                            when it published
//   GET  ?op=embed&id=X      /m/X/embed: a card for a blog or a forum to
//                            put in an iframe
//   POST                     publish, with the session: {name, author?,
//                            model, image?, id?}. With an id, the owner's
//                            own link is updated in place.
//   POST ?op=unpublish&id=X  the owner takes it down
//   GET  ?op=mine            the session's own links
//
// Where it is kept and who may touch it is in supabase/shared_models.sql.
// In short: a visitor's read goes through the publishable key, so row
// security is what decides that a row is published, and the files are
// read with the secret key only after that. Every write is here, after
// the session has been verified and the row found to be the caller's.
//
// The upload is checked at this edge, before anything is stored: LDraw
// text only (every line one of LDraw's six kinds, well formed, at least
// one part), at most 2 MB, a PNG picture of at most 600 KB, and a name.
// The part count is the server's own, counted here, not the client's.

import { randomBytes } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { originOf } from "./_oauth.js";

export const MAX_MODEL_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 600 * 1024;
const MAX_NAME = 80;
const MAX_AUTHOR = 60;
const BUCKET = "shared-models";
const ID = /^[A-Za-z0-9]{10}$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
// What a visitor's key may read: the columns supabase/shared_models.sql
// grants, which are all of them but the owner.
const PUBLIC = "id,name,author,parts,bytes,has_image,published,updated_at";
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function project() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// Ten characters from an alphabet without the ones people misread
/// (0/O, 1/l/I): about 58 bits, so a link cannot be guessed.
function newId() {
  const bytes = randomBytes(10);
  let id = "";
  for (const byte of bytes) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

// ---------------------------------------------------------------------------
// The model's text, checked.

const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
const COLOUR = /^(\d+|0x[0-9A-Fa-f]{7})$/;
// How many numbers follow the line type and colour for each kind of line.
const COORDS = { 2: 6, 3: 9, 4: 12, 5: 12 };

export class Refusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/// Whether [text] is an LDraw model, and how many parts it has.
///
/// Every line must be one of LDraw's six kinds: 0 a comment or meta
/// command, 1 a part or submodel placed with a colour and a matrix, 2 to 5
/// lines and faces. That is what an .ldr, a .dat and an .mpd are, prints,
/// stickers and custom parts included — those travel inside the .mpd as
/// `0 FILE` sections and `0 !DATA` blocks, which are type 0 lines. A JSON
/// file, a picture or a script fails on its first line.
///
/// Parts are counted through the model's own submodels: a submodel
/// placed three times is its parts three times. A `0 FILE` whose name
/// ends .dat is a part (LDraw's own convention, and how the app writes a
/// custom part), so it counts once wherever it is placed.
export function checkModel(text) {
  if (typeof text !== "string" || text.trim() === "") {
    throw new Refusal("there is no model to share");
  }
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > MAX_MODEL_BYTES) {
    throw new Refusal(`that model is ${(bytes / 1048576).toFixed(1)} MB, and a shared model can be at most 2 MB`, 413);
  }
  // Control characters other than tab, line feed and carriage return
  // have no place in LDraw, and NUL is how a binary file gives itself away.
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) {
    throw new Refusal("that is not LDraw text: it has binary in it", 415);
  }

  const files = new Map();
  const order = [];
  let current = { name: "", placed: [], isPart: false };
  let inData = false;
  let lineNo = 0;
  // A file is known once it has a name or places something: an .ldr
  // has no 0 FILE line, and an .mpd starts with one.
  const keep = () => {
    if (!files.has(current.name)) {
      files.set(current.name, current);
      order.push(current.name);
    }
  };
  const start = (name) => {
    current = { name: name.toLowerCase(), placed: [], isPart: /\.dat$/i.test(name) };
    keep();
  };

  for (const raw of text.replace(/^﻿/, "").split(/\r?\n/)) {
    lineNo += 1;
    const line = raw.trim();
    if (line === "") continue;
    const tokens = line.split(/\s+/);
    const kind = tokens[0];
    if (!/^[0-5]$/.test(kind)) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} does not start with an LDraw line type`, 415);
    }
    if (kind === "0") {
      const meta = (tokens[1] || "").toUpperCase();
      if (meta === "FILE") {
        start(line.replace(/^0\s+FILE\s+/i, "").trim());
        inData = false;
      } else if (meta === "!DATA") {
        // An embedded picture: base64 in `0 !:` lines, not a model.
        inData = true;
        current = { name: "", placed: [], isPart: true };
      } else if (meta === "NOFILE") {
        inData = false;
      } else if (meta === "!LDRAW_ORG" && /part|shortcut|primitive|subpart/i.test(tokens[2] || "")) {
        current.isPart = true;
      }
      continue;
    }
    if (inData) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} is inside a 0 !DATA block`, 415);
    }
    if (kind === "1") {
      if (tokens.length < 15 || !COLOUR.test(tokens[1]) || !tokens.slice(2, 14).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed part line`, 415);
      }
      keep();
      current.placed.push(line.split(/\s+/).slice(14).join(" ").toLowerCase());
    } else {
      const need = COORDS[kind];
      if (tokens.length !== need + 2 || !COLOUR.test(tokens[1]) || !tokens.slice(2).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed type ${kind} line`, 415);
      }
    }
  }

  // The first file is the model; the rest are what it places.
  const counted = new Map();
  const visiting = new Set();
  const count = (name) => {
    const file = files.get(name);
    if (!file) return 1;
    if (file.isPart) return 1;
    if (counted.has(name)) return counted.get(name);
    if (visiting.has(name)) throw new Refusal("that model places itself inside itself", 415);
    visiting.add(name);
    let total = 0;
    for (const ref of file.placed) total += files.has(ref) ? count(ref) : 1;
    visiting.delete(name);
    counted.set(name, total);
    return total;
  };
  const main = order.find((name) => !files.get(name).isPart);
  const parts = main === undefined ? 0 : count(main);
  if (parts < 1) throw new Refusal("that model has no parts in it", 415);
  if (parts > 200000) throw new Refusal("that model has more parts than a shared model can have", 413);
  return { parts, bytes };
}

/// The picture, from the base64 the app sends, or null for none.
export function checkImage(given) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal("the picture is not readable", 415);
  }
  const bytes = Buffer.from(given, "base64");
  if (bytes.length > MAX_IMAGE_BYTES) throw new Refusal("the picture is too large", 413);
  if (bytes.length < PNG.length || !bytes.subarray(0, PNG.length).equals(PNG)) {
    throw new Refusal("the picture is not a PNG", 415);
  }
  return bytes;
}

/// A name for a link: one line, printable, trimmed to its limit.
function cleanText(given, limit) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, limit).trim();
}

// ---------------------------------------------------------------------------
// The database and the bucket.

/// A published row, read as a visitor reads it: through the publishable
/// key, so row security is what says it is published.
async function publishedRow(id) {
  if (!ID.test(id || "")) return null;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  const answer = await fetch(`${project()}/rest/v1/shared_models?id=eq.${id}&select=${PUBLIC}`, {
    headers: { apikey: key },
    signal: AbortSignal.timeout(10000),
  });
  if (!answer.ok) throw new Error(`database GET shared_models: ${answer.status}`);
  const rows = await answer.json();
  return rows[0] || null;
}

/// Whether a link that is not published ever was: "taken down" and "no
/// such link" are different things to tell somebody.
async function wasShared(id) {
  if (!ID.test(id || "")) return false;
  const rows = await db(`shared_models?id=eq.${id}&select=id`);
  return rows.length > 0;
}

async function ownRow(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&select=id,owner,published`);
  return rows[0] || null;
}

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

async function putFile(name, body, type) {
  const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}/${name}`, {
    method: "POST",
    headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body,
    signal: AbortSignal.timeout(20000),
  });
  if (!answer.ok) throw new Error(`storage POST ${name.split(".").pop()}: ${answer.status}`);
}

async function getFile(name) {
  const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}/${name}`, {
    headers: storageHeaders(),
    signal: AbortSignal.timeout(20000),
  });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`storage GET ${name.split(".").pop()}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

async function deleteFiles(names) {
  const answer = await fetch(`${project()}/storage/v1/object/${BUCKET}`, {
    method: "DELETE",
    headers: storageHeaders({ "content-type": "application/json" }),
    body: JSON.stringify({ prefixes: names }),
    signal: AbortSignal.timeout(20000),
  });
  if (!answer.ok) throw new Error(`storage DELETE: ${answer.status}`);
}

async function mayPublish(owner) {
  const allowed = await db("rpc/may_publish", { method: "POST", body: { account: owner } });
  return allowed === true;
}

// ---------------------------------------------------------------------------
// What a link answers.

function links(origin, id) {
  const url = `${origin}/m/${id}`;
  return {
    url,
    image: `${url}.png`,
    viewer: `${origin}/app?view=${id}`,
    embed: `<iframe src="${url}/embed" width="560" height="420" style="border:0;max-width:100%" `
      + `title="A Brickworks model" loading="lazy"></iframe>`,
  };
}

function describe(row) {
  const parts = `${row.parts.toLocaleString("en-US")} part${row.parts === 1 ? "" : "s"}`;
  return row.author ? `${parts}, by ${row.author}` : parts;
}

const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

const PAGE_STYLE = `
  :root { color-scheme: light dark; --ink: #1d232b; --soft: #5b6573; --card: #fff; --page: #eef0f3; --accent: #c8102e; }
  @media (prefers-color-scheme: dark) { :root { --ink: #e8ebef; --soft: #a3adba; --card: #1f252d; --page: #13171c; } }
  * { box-sizing: border-box; }
  body { margin: 0; font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; color: var(--ink); background: var(--page); }
  main { max-width: 760px; margin: 0 auto; padding: 24px 16px 40px; }
  .card { background: var(--card); border-radius: 14px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
  .card img { display: block; width: 100%; height: auto; aspect-ratio: 1200 / 630; object-fit: cover; background: #d9dce1; }
  .body { padding: 16px 20px 20px; }
  h1 { font-size: 1.5rem; margin: 0 0 4px; overflow-wrap: anywhere; }
  p { margin: 0 0 14px; color: var(--soft); }
  .actions { display: flex; flex-wrap: wrap; gap: 10px; }
  a.button { display: inline-block; padding: 10px 16px; border-radius: 9px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; }
  a.button.quiet { background: transparent; color: var(--ink); border: 1px solid currentColor; }
  footer { margin-top: 18px; font-size: .9rem; color: var(--soft); }
  footer a { color: inherit; }`;

function pageHead(origin, row, id, title) {
  const link = links(origin, id);
  const description = row
    ? `${describe(row)}. Turn it in 3D, step through the build, and get its booklet and parts list.`
    : "A model built in Brickworks, the LEGO CAD app in your browser.";
  const image = row && row.has_image ? link.image : `${origin}/share.png`;
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(link.url)}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(description)}">
<meta name="twitter:image" content="${escapeHtml(image)}">
<link rel="icon" href="/favicon-32.png">
<style>${PAGE_STYLE}</style>`;
}

/// /m/X: what a link preview reads, and for a person, the viewer. The
/// script (web/share-page.js) goes straight on to the viewer; without
/// scripts the page itself has the picture and the way in.
function sharePage(origin, id, row) {
  const link = links(origin, id);
  const title = `${row.name} — a Brickworks model`;
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, row, id, title)}
<script src="/share-page.js" defer></script>
</head>
<body data-viewer="${escapeHtml(`/app?view=${id}`)}">
<main>
  <div class="card">
    ${row.has_image ? `<img src="/m/${id}.png" alt="${escapeHtml(row.name)}" width="1200" height="630">` : ""}
    <div class="body">
      <h1>${escapeHtml(row.name)}</h1>
      <p>${escapeHtml(describe(row))}</p>
      <div class="actions">
        <a class="button" href="/app?view=${id}">Open the 3D viewer</a>
        <a class="button quiet" href="/app?copy=${id}">Open in Brickworks</a>
      </div>
    </div>
  </div>
  <footer>Shared from <a href="/">Brickworks</a>. Link: ${escapeHtml(link.url)}</footer>
</main>
</body>
</html>`;
}

/// /m/X/embed: a card sized for an iframe. The app itself cannot run in
/// somebody else's page — its threaded engine needs the page to be
/// cross-origin isolated, which only the top window can ask for — so the
/// card opens the viewer in a tab of its own.
function embedCard(origin, id, row) {
  const link = links(origin, id);
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, row, id, `${row.name} — a Brickworks model`)}
<style>
  body { background: var(--card); }
  a.whole { display: flex; flex-direction: column; height: 100vh; color: inherit; text-decoration: none; }
  a.whole img { flex: 1; min-height: 0; width: 100%; object-fit: cover; background: #d9dce1; }
  .bar { display: flex; align-items: center; gap: 12px; padding: 10px 14px; }
  .bar div { flex: 1; min-width: 0; }
  .bar b { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .bar span { color: var(--soft); font-size: .9rem; }
  .bar em { font-style: normal; font-weight: 600; color: #fff; background: var(--accent); padding: 7px 12px; border-radius: 8px; white-space: nowrap; }
</style>
</head>
<body>
<a class="whole" href="${escapeHtml(link.url)}" target="_blank" rel="noopener">
  ${row.has_image ? `<img src="/m/${id}.png" alt="${escapeHtml(row.name)}">` : `<img src="/share.png" alt="">`}
  <span class="bar"><div><b>${escapeHtml(row.name)}</b><span>${escapeHtml(describe(row))} · Brickworks</span></div><em>View in 3D</em></span>
</a>
</body>
</html>`;
}

function gonePage(origin, id, existed) {
  const title = existed ? "This model is no longer shared" : "There is no model at this link";
  const said = existed
    ? "Whoever shared it has taken it down. If they share it again, this link will work again."
    : "The link may be mistyped, or cut short.";
  return `<!doctype html>
<html lang="en">
<head>
${pageHead(origin, null, id, title)}
<meta name="robots" content="noindex">
</head>
<body>
<main>
  <div class="card"><div class="body">
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(said)}</p>
    <div class="actions"><a class="button" href="/">Go to Brickworks</a></div>
  </div></div>
</main>
</body>
</html>`;
}

const PAGE_CSP = "default-src 'none'; script-src 'self'; img-src 'self'; style-src 'unsafe-inline'; "
  + "base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
const EMBED_CSP = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; "
  + "base-uri 'none'; form-action 'none'; frame-ancestors *";

function html(response, status, body, { embed = false } = {}) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", embed ? EMBED_CSP : PAGE_CSP);
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  // Never kept by the CDN, so a model taken down is gone at once.
  response.setHeader("Cache-Control", "no-cache");
  return response.status(status).end(body);
}

/// A link that does not answer with a model: taken down (410) or never
/// there (404).
async function missing(id) {
  const existed = await wasShared(id);
  return existed
    ? { status: 410, error: "This model is no longer shared: whoever shared it has taken it down.", unpublished: true }
    : { status: 404, error: "There is no model at this link.", unpublished: false };
}

// ---------------------------------------------------------------------------

async function read(request, response) {
  const op = String(request.query?.op || "");
  const id = String(request.query?.id || "");
  const origin = originOf(request);

  if (op === "mine") return mine(request, response, origin);

  const row = await publishedRow(id);

  if (op === "page" || op === "embed") {
    if (!row) {
      const gone = await missing(id);
      return html(response, gone.status, gonePage(origin, id, gone.unpublished), { embed: op === "embed" });
    }
    return html(response, 200, op === "page" ? sharePage(origin, id, row) : embedCard(origin, id, row),
      { embed: op === "embed" });
  }

  if (op === "image") {
    const picture = row && row.has_image ? await getFile(`${id}.png`) : null;
    if (!picture) return response.status(404).setHeader("Cache-Control", "no-store").end("");
    response.setHeader("Content-Type", "image/png");
    // A link preview on any site may show it.
    response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    response.setHeader("Cache-Control", "public, max-age=60");
    return response.status(200).end(picture);
  }


  if (op !== "") return response.status(400).json({ error: `unknown op ${op}` });

  // The viewer's one request: what the model is, and the model.
  response.setHeader("Cache-Control", "no-store");
  if (!row) {
    const gone = await missing(id);
    return response.status(gone.status).json({ error: gone.error, unpublished: gone.unpublished });
  }
  const model = await getFile(`${id}.mpd`);
  if (!model) return response.status(410).json({ error: "This model is no longer shared.", unpublished: true });
  return response.status(200).json({
    id,
    name: row.name,
    author: row.author,
    parts: row.parts,
    updated_at: row.updated_at,
    ...links(origin, id),
    model: model.toString("utf8"),
  });
}

async function signedIn(request) {
  const claims = await verify(bearer(request));
  return claims.sub;
}

async function mine(request, response, origin) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const rows = await db(`shared_models?owner=eq.${owner}&select=${PUBLIC}&order=updated_at.desc`);
  return response.status(200).json({
    shared: rows.map((row) => ({ ...row, ...links(origin, row.id) })),
  });
}

async function publish(request, response) {
  const owner = await signedIn(request);
  const body = request.body && typeof request.body === "object" ? request.body : {};

  // Everything about the upload is checked before anything is counted
  // or stored, so a refused upload costs nobody a publish.
  const { parts, bytes } = checkModel(body.model);
  const picture = checkImage(body.image);
  const name = cleanText(body.name, MAX_NAME);
  if (!name) throw new Refusal("give the model a name to share it under");
  const author = cleanText(body.author, MAX_AUTHOR) || null;

  let id = body.id === undefined || body.id === null || body.id === "" ? "" : String(body.id);
  let existing = null;
  if (id) {
    existing = await ownRow(id);
    if (!existing) throw new Refusal("there is no shared model at that link to update", 404);
    if (existing.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  }

  if (!(await mayPublish(owner))) {
    throw new Refusal("you have published a lot in a short time: try again in an hour", 429);
  }

  if (!id) id = newId();
  await putFile(`${id}.mpd`, body.model, "text/plain");
  if (picture) await putFile(`${id}.png`, picture, "image/png");
  else if (existing) await deleteFiles([`${id}.png`]).catch(() => {});

  const row = { name, author, parts, bytes, has_image: Boolean(picture), published: true,
    updated_at: new Date().toISOString() };
  if (existing) {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: row });
  } else {
    await db("shared_models", { method: "POST", body: { id, owner, ...row } });
  }

  const origin = originOf(request);
  return response.status(existing ? 200 : 201).json({
    id, name, author, parts, bytes, published: true, updated: Boolean(existing), ...links(origin, id),
  });
}

async function unpublish(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || request.body?.id || "");
  const row = await ownRow(id);
  if (!row) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, {
    method: "PATCH", body: { published: false, updated_at: new Date().toISOString() } });
  // The row stays, so the link can say it was taken down, and a
  // republish from the same model keeps the same link. The files go.
  await deleteFiles([`${id}.mpd`, `${id}.png`]);
  return response.status(200).json({ id, published: false });
}

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  // The desktop app publishes from no page at all; a browser on another
  // site gains nothing from a session it does not have.
  response.setHeader("Access-Control-Allow-Origin", "*");

  if (!dbConfigured() || !process.env.SUPABASE_PUBLISHABLE_KEY) {
    return response.status(503).json({ error: "sharing is not set up on this deployment" });
  }

  try {
    if (request.method === "GET") return await read(request, response);
    if (request.method !== "POST") return response.status(405).json({ error: "GET or POST" });
    response.setHeader("Cache-Control", "no-store");
    const op = String(request.query?.op || "");
    if (op === "unpublish") return await unpublish(request, response);
    if (op === "") return await publish(request, response);
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    if (trouble instanceof Refusal) return response.status(trouble.status).json({ error: trouble.message });
    console.error("share:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}
