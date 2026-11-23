// world.mjs over HTTP, for the studio's probe (src/dev/suggest_probe.gd):
// /api/share and /api/people answered by the real handlers, and a few
// routes of the probe's own to act as Ann and read what was kept.
//
//   node tests/fixtures/suggest/serve.mjs PORT
//
//   GET  /probe/tokens   {dee, ann}: their sessions
//   POST /probe/send     Ann sends her remix's change: the handler's answer
//   POST /probe/remix2   Ann's remix gets a version 2 (the rear brick green)
//   GET  /probe/state    {suggestions, versions, model}: what is kept

import http from "node:http";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
for (const level of ["log", "warn", "info"]) console[level] = () => {};
const port = Number(process.argv[2] || 11791);
const { suggestWorld } = await import(path.join(here, "world.mjs"));
const mine = readFileSync(path.join(here, "car.mine.ldr"), "utf8");
const theirs = readFileSync(path.join(here, "car.theirs.ldr"), "utf8");
const w = await suggestWorld({ mine, theirs });
const ROUTES = new Set(["share", "people"]);

const send = (response, status, body) => {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(JSON.stringify(body));
};

http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://127.0.0.1:${port}`);
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  const raw = Buffer.concat(chunks).toString("utf8");
  try {
    if (url.pathname === "/probe/tokens") return send(response, 200, w.tokens);
    if (url.pathname === "/probe/send") {
      const said = await w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
        body: { remix: w.REMIX, note: "Wider wheels, and a spoiler" } });
      return send(response, said.status, said.body);
    }
    if (url.pathname === "/probe/remix2") {
      w.versions.push({ model: w.REMIX, n: 2, at: new Date().toISOString(), parts: 10, bytes: 1 });
      w.files.set(`${w.REMIX}.v1.mpd`, w.files.get(`${w.REMIX}.mpd`));
      w.files.set(`${w.REMIX}.mpd`, Buffer.from(w.files.get(`${w.MODEL}.mpd`).toString("utf8")
        .replace("1 4 -60 -24 0", "1 2 -60 -24 0")));
      return send(response, 200, { n: 2 });
    }
    if (url.pathname === "/probe/state") {
      return send(response, 200, { suggestions: w.suggestions, versions: w.versions.filter((v) => v.model === w.MODEL),
        model: w.files.get(`${w.MODEL}.mpd`)?.toString("utf8") ?? null });
    }
    const route = /^\/api\/([a-z_]+)$/.exec(url.pathname)?.[1];
    if (!route || !ROUTES.has(route)) return send(response, 404, { error: "not here" });
    let body;
    try {
      body = raw ? JSON.parse(raw) : undefined;
    } catch {
      body = undefined;
    }
    const as = Object.entries(w.tokens).find(([, token]) => request.headers.authorization === `Bearer ${token}`)?.[0];
    const said = await w.ask(route, { method: request.method, query: Object.fromEntries(url.searchParams), body, as });
    return send(response, said.status, said.body ?? null);
  } catch (trouble) {
    return send(response, 500, { error: String(trouble?.message || trouble).slice(0, 300) });
  }
}).listen(port, "127.0.0.1", () => process.stdout.write(`serving on ${port}\n`));
