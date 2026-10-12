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
// and a shared model's /m/<id>, /m/<id>.png and /m/<id>/embed (api/share.js).
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
import http from "node:http";
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const port = Number(process.argv[2] || 8790);
const site = (process.argv.find((a) => a.startsWith("--static=")) || "").slice(9);
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
  [/^\/m\/([A-Za-z0-9]{10})\/embed\/?$/, "share", "embed"],
  // The daily cron's clean-up of files no published row owns.
  [/^\/api\/share\/sweep$/, "share", "sweep"],
];
const PAGES = [[/^\/oauth\/authorize\/?$/, "authorize.html"]];
const TYPES = { html: "text/html; charset=utf-8", js: "text/javascript", svg: "image/svg+xml",
  png: "image/png", json: "application/json", css: "text/css" };

const FILE_TYPES = {
  ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm",
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
  const name = named ? named[1] : pathname.slice(1);
  if (!/^[a-z0-9_-]+\.[a-z]+$/.test(name)) return null;
  const file = new URL(name, web);
  if (!existsSync(file)) return null;
  return { body: readFileSync(file), type: TYPES[name.split(".").pop()] || "application/octet-stream" };
}

http.createServer(async (incoming, outgoing) => {
  const url = new URL(incoming.url, "http://127.0.0.1");
  const query = Object.fromEntries(url.searchParams);
  let handler = null;
  const found = /^\/api\/([a-z]+)\/?$/.exec(url.pathname);
  if (found) handler = await route(found[1]);
  const mapped = MAPPED.find(([pattern]) => pattern.test(url.pathname));
  if (mapped) {
    handler = await route(mapped[1]);
    query.op = mapped[2];
    const captured = mapped[0].exec(url.pathname);
    if (captured[1] && mapped[1] === "share") query.id = captured[1];
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
