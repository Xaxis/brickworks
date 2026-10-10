// api/mcp.js on this machine, for proving the connector without a deploy.
//
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 8790
//
// Wraps the real handler in the few response helpers Vercel gives it, and
// talks to the real queue (supabase/relay.sql), so what it proves is the
// code that ships. src/dev/connector_probe.gd drives it from both ends: a
// tab answering, and Claude asking.
import http from "node:http";
import handler from "../../api/mcp.js";

const port = Number(process.argv[2] || 8790);

http.createServer(async (incoming, outgoing) => {
  const url = new URL(incoming.url, "http://127.0.0.1");
  if (!url.pathname.startsWith("/api/mcp")) {
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
  console.log(`relay on http://127.0.0.1:${port}/api/mcp`);
});
