// The deployment's functions on this machine, for proving them without a
// deploy: /api/<name> runs api/<name>.js.
//
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790
//
// Wraps the real handlers in the few response helpers Vercel gives them, and
// talks to the real database, so what it proves is the code that ships.
// src/dev/connector_probe.gd drives the relay (api/mcp.js) from both ends: a
// tab answering, and Claude asking. src/dev/account_probe.gd drives sign-in
// (api/account.js, api/otp.js, api/admin.js) from the app's side, with
// BRICKWORKS_API=http://127.0.0.1:8790. tools/web/oauth_probe.mjs drives
// Claude's sign-in (api/oauth.js).
//
// And the paths the deployment maps onto functions and pages (deploy.sh's
// routes), so Claude's sign-in is found here where it is found there: the
// OAuth metadata under /.well-known/, /oauth/register, /oauth/token and
// /oauth/revoke, and /oauth/authorize, which is the page web/authorize.html;
// and a shared model's /m/<id>, /m/<id>.png, /m/<id>.webp and /m/<id>/embed,
// and an older version's /m/<id>/v/<n> and /m/<id>/v/<n>.png
// (api/share.js), a profile's /u/<handle> and a collection's /c/<id>
// (api/people.js).
// Other files in web/ are served as they are.
//
// No client address is passed on, so api/otp.js's per-address limit has
// nothing to count here; its per-email limit, the one a probe checks, does.
//
// With --static=DIR it also serves a web export from DIR, with the two
// headers the threaded build needs, so a local build talks to these same
// functions as it would on Vercel: tools/web/freeze_check.mjs drives one
// over the connector this way.
//
//   node tools/web/relay_server.mjs 8790 --static=build/web
//
// --hold=model_builds,build_photos,report_photos holds supabase/builds.sql's
// tables and its two storage buckets here, and takes the upload a page sends
// straight to storage at /__held_storage/upload/... (tools/web/builds_flow.mjs).
//
// With --trust-stand-in it answers supabase/trust.sql's functions itself,
// in memory, until that file is applied to the project
// (tools/web/trust_stand_in.mjs): the age question and the report digest's
// dry run, for tools/web/age_flow.mjs and digest_flow.mjs.
//
// --hold=model_comments holds supabase/comments.sql the same way: its
// tables are reachable only through its functions, so those are what is
// answered here, and the column it adds to reports
// (tools/web/comments_stand_in.mjs), for tools/web/comments_flow.mjs.
//
// --hold=follows,model_comments holds supabase/follows.sql: its functions
// answered from memory, the feed read from what holds each thing, and the
// day's email telling of the feed (tools/web/follows_stand_in.mjs), for
// tools/web/follows_flow.mjs.
//
// --hold=gallery_picks holds supabase/discovery.sql: this week's pick, the
// owner's choices of it, and the gallery's Top builds, answered from memory
// over the real project's models and builds
// (tools/web/discovery_stand_in.mjs), for tools/web/discovery_flow.mjs.
//
// --hold=model_opens holds supabase/designers.sql: a designer's page and
// their own numbers, answered from the real project's models, builds,
// remixes, comments, photos and model_views (tools/web/designers_stand_in.mjs),
// for tools/web/designers_flow.mjs.
//
// --hold=profile_shows holds supabase/profile_shows.sql: what a profile
// shows besides its name (links, a banner, pinned models), its upserts and
// its refusals, for tools/web/profile_flow.mjs.
//
// --hold=challenges holds supabase/challenges.sql: its tables in memory and
// its functions answered over the real project's models, Tested marks and
// trust (tools/web/challenges_stand_in.mjs), for tools/web/challenges_flow.mjs.
//
// --hold=notifications holds supabase/notifications.sql: its marks in
// memory, its functions answered over the project's feed_rows and likes
// (tools/web/notifications_stand_in.mjs), for tools/web/notifications_flow.mjs
// and follows_flow.mjs as they will be once the file is applied.
//
// --hold=replies holds supabase/replies.sql: which comment each reply
// answers kept here, the replies written to the project as the comments
// they are, and the functions the API asks answered over the live ones
// (tools/web/replies_stand_in.mjs), for tools/web/comments_flow.mjs.
import http from "node:http";
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { standIn, standInRoute } from "./trust_stand_in.mjs";

const port = Number(process.argv[2] || 8790);
const site = (process.argv.find((a) => a.startsWith("--static=")) || "").slice(9);
// Tables the live project does not have yet, kept in this process
// (tools/web/held_tables.mjs): --hold=share_versions proves the code that
// uses supabase/versions.sql before the file is applied. What they hold is
// at /__held/<table>, on this machine only.
const holding = (process.argv.find((a) => a.startsWith("--hold=")) || "").slice(7).split(",").filter(Boolean);
const tables = holding.filter((name) => !["model_comments", "follows", "gallery_picks", "model_opens", "challenges",
  "notifications", "replies"].includes(name));
const heldTables = tables.length ? await import("./held_tables.mjs") : null;
if (heldTables) {
  heldTables.hold(tables, { origin: `http://127.0.0.1:${port}` });
  console.log(`holding ${tables.join(", ")} here, not in the project`);
}
// Inside the trust stand-in, so a report's digest reads which comment it
// names through it.
const heldComments = holding.includes("model_comments") ? await import("./comments_stand_in.mjs") : null;
if (heldComments) heldComments.hold();
// Inside the trust stand-in too, and outside the comments it reads.
const heldFollows = holding.includes("follows") ? await import("./follows_stand_in.mjs") : null;
if (heldFollows) heldFollows.hold(heldComments);
// Outermost: its Top builds asks the list of whatever is held inside it.
const heldDiscovery = holding.includes("gallery_picks") ? await import("./discovery_stand_in.mjs") : null;
if (heldDiscovery) heldDiscovery.hold();
// Outside them all: a designer's numbers read what every one of them holds.
const heldDesigners = holding.includes("model_opens") ? await import("./designers_stand_in.mjs") : null;
if (heldDesigners) heldDesigners.hold();
// And the challenges, which read only the project's own tables.
const heldChallenges = holding.includes("challenges") ? await import("./challenges_stand_in.mjs") : null;
if (heldChallenges) heldChallenges.hold();
// Outermost: it reads the project's feed_rows and likes, and asks no other.
const heldNotifications = holding.includes("notifications") ? await import("./notifications_stand_in.mjs") : null;
if (heldNotifications) heldNotifications.hold();
// Outermost of all: it reads the project's comments and notifications.
const heldReplies = holding.includes("replies") ? await import("./replies_stand_in.mjs") : null;
if (heldReplies) heldReplies.hold();
const stoodIn = process.argv.includes("--trust-stand-in");
if (stoodIn) standIn();
const routes = new Map();
const web = new URL("../../web/", import.meta.url);

// As deploy.sh writes them for Vercel.
const MAPPED = [
  [/^\/\.well-known\/oauth-protected-resource(\/.*)?$/, "oauth", "resource"],
  [/^\/\.well-known\/oauth-authorization-server(\/.*)?$/, "oauth", "metadata"],
  [/^\/oauth\/register\/?$/, "oauth", "register"],
  [/^\/oauth\/token\/?$/, "oauth", "token"],
  [/^\/oauth\/revoke\/?$/, "oauth", "revoke"],
  // A shared model's link, its picture and its card, as /m/<id>.
  [/^\/m\/([A-Za-z0-9]{10})\/?$/, "share", "page"],
  [/^\/m\/([A-Za-z0-9]{10})[.]png$/, "share", "image"],
  [/^\/m\/([A-Za-z0-9]{10})[.]cutout[.]png$/, "share", "cutout"],
  [/^\/m\/([A-Za-z0-9]{10})[.]webp$/, "share", "thumb"],
  [/^\/m\/([A-Za-z0-9]{10})\/embed\/?$/, "share", "embed"],
  // An older version of it, and that version's picture.
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})\/?$/, "share", "page"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})[.]png$/, "share", "image"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})[.]cutout[.]png$/, "share", "cutout"],
  // A person's profile and a public collection (api/people.js).
  [/^\/u\/([a-z0-9-]{3,24})\/?$/, "people", "page"],
  [/^\/c\/([A-Za-z0-9]{10})\/?$/, "people", "list_page"],
  // The sitemap, with every listed model in it (api/share.js).
  [/^\/sitemap\.xml$/, "share", "sitemap"],
  // The daily cron's clean-up of files no published row owns.
  [/^\/api\/share\/sweep$/, "share", "sweep"],
];
// And the site's pages at their bare names, as deploy.sh serves them.
const PAGES = [[/^\/oauth\/authorize\/?$/, "authorize.html"], [/^\/gallery\/?$/, "gallery.html"],
  [/^\/profile\/?$/, "profile.html"], [/^\/settings\/?$/, "settings.html"]];
// .mjs as the host serves it: a module script, which a browser refuses as
// anything else (orangecheck's button, web/oc-button.mjs).
const TYPES = { html: "text/html; charset=utf-8", js: "text/javascript", mjs: "text/javascript", svg: "image/svg+xml",
  png: "image/png", json: "application/json", css: "text/css" };

const FILE_TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".wasm": "application/wasm",
  ".pck": "application/octet-stream", ".png": "image/png", ".json": "application/json",
  ".svg": "image/svg+xml", ".ico": "image/x-icon", ".css": "text/css",
};

// A file of the export, or false when there is none by that name.
function serveFile(pathname, outgoing) {
  if (!site) return false;
  const file = normalize(join(site, decodeURIComponent(pathname === "/" ? "/index.html" : pathname)));
  if (!file.startsWith(normalize(site)) || !existsSync(file) || !statSync(file).isFile()) return false;
  outgoing.writeHead(200, {
    "content-type": FILE_TYPES[extname(file)] || "application/octet-stream",
    "cross-origin-opener-policy": "same-origin",
    "cross-origin-embedder-policy": "require-corp",
    "cache-control": "no-store",
  });
  outgoing.end(readFileSync(file));
  return true;
}

async function route(name) {
  if (!/^[a-z]+$/.test(name)) return null;
  if (!routes.has(name)) {
    const file = new URL(`../../api/${name}.js`, import.meta.url);
    routes.set(name, existsSync(file) ? (await import(file)).default : null);
  }
  return routes.get(name);
}

/// A file of web/, or null.
function page(pathname) {
  const named = PAGES.find(([pattern]) => pattern.test(pathname));
  // Any other page at its bare name, as deploy.sh serves them: /admin,
  // /takedown, /download.
  const bare = /^\/([a-z0-9-]+)\/?$/.exec(pathname);
  const name = named ? named[1] : bare && existsSync(new URL(`${bare[1]}.html`, web)) ? `${bare[1]}.html`
    : pathname.slice(1);
  if (!/^[a-z0-9_-]+\.[a-z]+$/.test(name)) return null;
  const file = new URL(name, web);
  if (!existsSync(file)) return null;
  return { body: readFileSync(file), type: TYPES[name.split(".").pop()] || "application/octet-stream" };
}

http.createServer(async (incoming, outgoing) => {
  const url = new URL(incoming.url, "http://127.0.0.1");
  const asked = (heldTables || heldComments || heldFollows || heldDiscovery || heldDesigners || heldChallenges
    || heldNotifications || heldReplies) && /^\/__held\/([a-z_]+)$/.exec(url.pathname);
  if (asked) {
    const rows = heldTables?.rowsOf(asked[1]) ?? heldComments?.rowsOf(asked[1]) ?? heldFollows?.rowsOf(asked[1])
      ?? heldDiscovery?.rowsOf(asked[1]) ?? heldDesigners?.rowsOf(asked[1]) ?? heldChallenges?.rowsOf(asked[1])
      ?? heldNotifications?.rowsOf(asked[1]) ?? heldReplies?.rowsOf(asked[1]) ?? null;
    outgoing.writeHead(rows ? 200 : 404, { "content-type": "application/json" });
    return outgoing.end(JSON.stringify(rows));
  }
  // The held buckets (supabase/builds.sql): a page's signed upload, and
  // what a check reads of them.
  if (heldTables && url.pathname.startsWith("/__held_storage/")) {
    const chunks = [];
    for await (const chunk of incoming) chunks.push(chunk);
    const said = heldTables.storageRoute(url, incoming.method, incoming.headers, Buffer.concat(chunks));
    if (said) {
      // A page sends the upload with headers of its own, as to Supabase.
      outgoing.writeHead(said.status, { "content-type": said.type, "cache-control": "no-store" });
      return outgoing.end(said.body);
    }
  }
  const query = Object.fromEntries(url.searchParams);
  if (stoodIn && url.pathname.startsWith("/__stand_in/")) {
    const chunks = [];
    for await (const chunk of incoming) chunks.push(chunk);
    let body = {};
    try {
      body = JSON.parse(Buffer.concat(chunks).toString() || "{}");
    } catch {
      body = {};
    }
    const said = (await standInRoute(url, incoming.method, body)) || { status: 404, value: { error: "not found" } };
    outgoing.writeHead(said.status, { "content-type": "application/json" });
    return outgoing.end(JSON.stringify(said.value));
  }
  let handler = null;
  const found = /^\/api\/([a-z]+)\/?$/.exec(url.pathname);
  if (found) handler = await route(found[1]);
  const mapped = MAPPED.find(([pattern]) => pattern.test(url.pathname));
  if (mapped) {
    handler = await route(mapped[1]);
    query.op = mapped[2];
    const captured = mapped[0].exec(url.pathname);
    if (captured[1] && mapped[1] === "share") query.id = captured[1];
    if (captured[2] && mapped[1] === "share") query.v = captured[2];
    if (captured[1] && mapped[2] === "page" && mapped[1] === "people") query.handle = captured[1];
    if (captured[1] && mapped[2] === "list_page") query.id = captured[1];
  }
  // The app is at /app, which the deployment sends on to the build with
  // its query (?view=<id>, ?copy=<id>) intact.
  if (site && /^\/app\/?$/.test(url.pathname)) {
    outgoing.writeHead(302, { location: `/${url.search}` });
    return outgoing.end();
  }
  if (!handler && !found && !mapped && serveFile(url.pathname, outgoing)) return;
  if (!handler) {
    const file = incoming.method === "GET" ? page(url.pathname) : null;
    if (!file) {
      outgoing.writeHead(404);
      return outgoing.end();
    }
    outgoing.writeHead(200, { "content-type": file.type, "cache-control": "no-store" });
    return outgoing.end(file.body);
  }
  const chunks = [];
  for await (const chunk of incoming) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString();
  // Parsed as Vercel parses it: JSON and form bodies become objects.
  let body;
  const type = String(incoming.headers["content-type"] || "");
  if (type.includes("application/x-www-form-urlencoded")) {
    body = Object.fromEntries(new URLSearchParams(raw));
  } else {
    try {
      body = raw ? JSON.parse(raw) : undefined;
    } catch {
      body = raw;
    }
  }
  const request = {
    method: incoming.method,
    query,
    headers: incoming.headers,
    body,
  };

  const response = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    setHeader(name, value) { outgoing.setHeader(name, value); return this; },
    json(value) {
      outgoing.writeHead(this.statusCode, { "content-type": "application/json" });
      outgoing.end(JSON.stringify(value));
      return this;
    },
    end(text) {
      outgoing.writeHead(this.statusCode);
      outgoing.end(text);
      return this;
    },
  };
  try {
    await handler(request, response);
  } catch (trouble) {
    outgoing.writeHead(500);
    outgoing.end(String(trouble));
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`the deployment's functions on http://127.0.0.1:${port}/api/`);
});
