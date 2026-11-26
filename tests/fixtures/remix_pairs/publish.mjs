// A remix published through the real handler (api/share.js), and what it
// counted (remixdiff, 2026-11-23): tests/test_remix_changes.py proves the
// count is kept, and right, and begun only once the answer is written;
// bench/results/remixdiff-*/ times it.
//
//   node tests/fixtures/remix_pairs/publish.mjs [--pair=09_mix_move_turn_recolour] [--n=1] [--lat=0]
//       [--parts=N] [--plain]
//
// Every Supabase call answers after --lat ms, in memory
// (tests/fixtures/billing/world.mjs signs the session): the original, its
// one version, its file (the pair's .was.ldr) and the remix_changes row
// kept. --parts=N publishes a model of N parts in place of the pair: the
// original N bricks in a grid, the remix with a tenth of them moved, a
// tenth recoloured and a twentieth taken away, and as many added. --plain
// publishes the same file as no remix (the publish without the count), to
// time against. Prints JSON: each publish's answered and returned ms, its
// status, the row kept, and whether any of the count's reads began before
// the answer was written.
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const LAT = Number(args.lat || 0);
const N = Number(args.n || 1);
const plain = Boolean(args.plain);
for (const level of ["log", "warn", "info"]) console[level] = () => {};
const troubles = [];
console.error = (...said) => troubles.push(said.join(" ").slice(0, 300));

const { SESSION_READS, SUPABASE_URL, world } = await import(path.join(root, "tests/fixtures/billing/world.mjs"));
const w = await world({});
const { useCurrent } = await import(path.join(root, "api/_parts.js"));
useCurrent(JSON.parse(readFileSync(path.join(here, "part_current.json"), "utf8")).parts);

/// A grid of [n] bricks, and a remix of it: (was, now).
function grid(n) {
  const side = Math.ceil(Math.sqrt(n));
  const at = (k) => [(k % side) * 40, -24 * Math.floor(k / (side * side)), Math.floor(k / side) % side * 40];
  const line = (colour, [x, y, z], part = "3001") => `1 ${colour} ${x} ${y} ${z} 1 0 0 0 1 0 0 0 1 ${part}.dat`;
  const was = [];
  const now = [];
  for (let k = 0; k < n; k += 1) {
    const [x, y, z] = at(k);
    was.push(line(4, [x, y, z]));
    if (k % 20 === 3) continue;                                  // a twentieth taken away
    if (k % 10 === 5) now.push(line(4, [x + 1000, y, z]));       // a tenth moved
    else if (k % 10 === 7) now.push(line(1, [x, y, z]));         // a tenth recoloured
    else now.push(line(4, [x, y, z]));
  }
  for (let k = 0; k < Math.floor(n / 20); k += 1) now.push(line(14, [k * 40, -400, 0], "3003"));
  const file = (lines) => `0 Grid\n0 Name: grid.ldr\n0 Author: Brickworks\n${lines.join("\n")}\n`;
  return [file(was), file(now)];
}

const pair = String(args.pair || "09_mix_move_turn_recolour");
const [wasText, nowText] = args.parts ? grid(Number(args.parts))
  : ["was", "now"].map((side) => readFileSync(path.join(here, `${pair}.${side}.ldr`), "utf8"));
const ORIGINAL = "CottageA01";
const kept = [];
let answeredAt = null;
const countReads = [];
const reply = (status, body) => new Response(body === undefined ? null : JSON.stringify(body), { status,
  headers: { "content-type": "application/json" } });
const wait = (ms) => (ms > 0 ? new Promise((resolve) => setTimeout(resolve, ms)) : Promise.resolve());
const worldFetch = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(String(input.url || input));
  if (url.origin !== SUPABASE_URL) return worldFetch(input, init);
  const method = String(init.method || "GET").toUpperCase();
  const p = url.pathname;
  const q = url.searchParams;
  await wait(LAT);
  if (p === "/auth/v1/.well-known/jwks.json" || SESSION_READS.has(p)) return worldFetch(input, init);
  // The original: published, CC BY, Robin's.
  // The count's own reads (api/_remix.js countRemix) are told by what they
  // select: the publish's own read of the original asks id,owner,licence.
  const counting = (q.get("select") === "id,updated_at" || q.get("select") === "n,at");
  if (counting) countReads.push(performance.now());
  if (p === "/rest/v1/shared_models" && method === "GET" && q.get("id") === `eq.${ORIGINAL}`) {
    return reply(200, [{ id: ORIGINAL, owner: "robin", licence: "cc-by-4.0", updated_at: "2026-10-01T00:00:00Z", published: true }]);
  }
  if (p === "/rest/v1/share_versions" && method === "GET" && q.get("model") === `eq.${ORIGINAL}`) {
    return reply(200, [{ n: 1, at: "2026-10-01T00:00:00Z", parts: 42, bytes: wasText.length, has_image: true,
      changes: null, first_changed: null, remixed_from_version: null }]);
  }
  if (p === `/storage/v1/object/shared-models/${ORIGINAL}.mpd` && method === "GET") {
    if (answeredAt === null) troubles.push("the original's file was read before the answer");
    return new Response(wasText, { status: 200, headers: { "content-type": "text/plain" } });
  }
  if (p === "/rest/v1/remix_changes" && method === "POST") {
    kept.push({ at: performance.now(), row: JSON.parse(String(init.body || "{}")) });
    return new Response(null, { status: 201 });
  }
  if (p === "/rest/v1/remix_changes") return new Response(null, { status: 204 });
  if (p === "/rest/v1/rpc/may_publish" || p === "/rest/v1/rpc/may_list") return reply(200, true);
  if (p === "/rest/v1/rpc/is_barred") return reply(200, false);
  if (p === "/rest/v1/shared_models" && method === "HEAD") {
    return new Response(null, { status: 200, headers: { "content-range": "*/0" } });
  }
  if (p.startsWith("/storage/v1/")) return reply(200, {});
  if (p.startsWith("/rest/v1/rpc/")) return reply(200, null);
  if (p.startsWith("/rest/v1/")) return method === "GET" ? reply(200, []) : new Response(null, { status: 201 });
  return worldFetch(input, init);
};

const { default: handle } = await import(path.join(root, "api/share.js"));
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]).toString("base64");

async function publish(k) {
  const token = await w.signIn({ sub: `00000000-0000-4000-8000-${String(k).padStart(12, "0")}`, email: `remix${k}@example.com` });
  const response = { statusCode: 200, headers: {}, body: undefined, ended: null,
    status(code) { this.statusCode = code; return this; },
    setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; return this; },
    json(value) { this.body = value; this.ended = performance.now(); answeredAt = this.ended; return this; },
    send(value) { this.body = value; this.ended = performance.now(); answeredAt = this.ended; return this; },
    end() { this.ended = performance.now(); answeredAt = this.ended; return this; } };
  const body = { name: "Cottage with a Garden", image: PNG, model: nowText,
    ...(plain ? {} : { remixed_from: ORIGINAL, remixed_from_version: 1 }) };
  const request = { method: "POST", query: {}, headers: { host: "brickworks.diy", authorization: `Bearer ${token}` }, body };
  answeredAt = null;
  countReads.length = 0;
  const before = kept.length;
  const t0 = performance.now();
  let threw = null;
  try {
    await handle(request, response);
  } catch (trouble) {
    threw = String(trouble?.stack || trouble).slice(0, 400);
  }
  const returned = performance.now() - t0;
  // The count, after the answer: waited for here (api/_after.js BOUND).
  for (let n = 0; n < 300 && kept.length === before && !plain; n += 1) await wait(10);
  const row = kept.length > before ? kept[kept.length - 1] : null;
  return { status: response.statusCode, threw, answered: response.ended === null ? null : response.ended - t0, returned,
    error: response.body?.error || null, kept: row ? row.row : null,
    counted_after_answer: row ? row.at - (response.ended ?? 0) : null,
    count_reads: countReads.length,
    reads_before_answer: countReads.filter((at) => response.ended === null || at < response.ended).length };
}

await publish(0); // the imports and the catalogue's tables, warmed
const runs = [];
for (let k = 1; k <= N; k += 1) runs.push(await publish(k));
const pct = (xs, q) => {
  const s = xs.filter((x) => x !== null).sort((a, b) => a - b);
  return s.length ? Math.round(s[Math.min(s.length - 1, Math.floor(q * s.length))] * 10) / 10 : null;
};
process.stdout.write(`${JSON.stringify({ pair: args.parts ? `grid of ${args.parts}` : pair, plain, lat: LAT, n: N,
  answered_p50: pct(runs.map((r) => r.answered), 0.5), answered_p95: pct(runs.map((r) => r.answered), 0.95),
  returned_p95: pct(runs.map((r) => r.returned), 0.95),
  counted_p50: pct(runs.map((r) => r.counted_after_answer), 0.5), counted_p95: pct(runs.map((r) => r.counted_after_answer), 0.95),
  reads_before_answer: runs.reduce((n, r) => n + r.reads_before_answer, 0), runs: N <= 3 ? runs : runs.slice(0, 1),
  statuses: runs.reduce((m, r) => ({ ...m, [r.status]: (m[r.status] || 0) + 1 }), {}),
  kept: runs.filter((r) => r.kept).length, troubles: troubles.slice(0, 5) })}\n`);
process.exit(0);
