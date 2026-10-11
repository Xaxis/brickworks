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
// BRICKWORKS_API=http://127.0.0.1:8790.
//
// No client address is passed on, so api/otp.js's per-address limit has
// nothing to count here; its per-email limit, the one a probe checks, does.
import http from "node:http";
import { existsSync } from "node:fs";

const port = Number(process.argv[2] || 8790);
const routes = new Map();

async function route(name) {
  if (!/^[a-z]+$/.test(name)) return null;
  if (!routes.has(name)) {
    const file = new URL(`../../api/${name}.js`, import.meta.url);
    routes.set(name, existsSync(file) ? (await import(file)).default : null);
  }
  return routes.get(name);
}

http.createServer(async (incoming, outgoing) => {
  const url = new URL(incoming.url, "http://127.0.0.1");
  const found = /^\/api\/([a-z]+)\/?$/.exec(url.pathname);
  const handler = found ? await route(found[1]) : null;
  if (!handler) {
    outgoing.writeHead(404);
    return outgoing.end();
  }
  const chunks = [];
  for await (const chunk of incoming) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString();
  let body;
  try {
    body = raw ? JSON.parse(raw) : undefined;
  } catch {
    body = raw;
  }
  const request = {
    method: incoming.method,
    query: Object.fromEntries(url.searchParams),
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
