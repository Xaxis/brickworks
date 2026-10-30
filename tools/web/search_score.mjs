// How well the library's search finds what a builder means (search,
// 2026-10-30): tests/search_queries.tsv's searches, each passing when one of
// its sets is in the first three answered.
//
//   node tools/web/search_score.mjs                 this checkout's api/_sets.js over the whole catalogue
//   node tools/web/search_score.mjs --url=https://brickworks.diy   a deployment's /api/share?op=library
//   ... --json                                      one line of JSON: {rate, passed, of, misses, ms}
//
// In the checkout it also times each search as the server runs it (askSets
// and searchCatalog, after one warm-up round), ten rounds, and says the 50th
// and 95th percentiles. Exits 1 below --bar (0.95 unless given).
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [key, value] = a.replace(/^--/, "").split("=");
  return [key, value ?? "1"];
}));
const bar = Number(args.bar ?? 0.95);

/// The table: [{q, want, kind}].
export function queries(file = path.join(ROOT, "tests/search_queries.tsv")) {
  return readFileSync(file, "utf8").split("\n").filter((line) => line.trim() && !line.startsWith("#"))
    .map((line) => {
      const [q, want, kind] = line.split("\t");
      return { q, want: want.trim().split(/\s+/), kind: (kind || "").trim() };
    });
}

/// The first three set numbers a deployment answers [q] with.
async function asked(url, q) {
  const reply = await fetch(`${url}/api/share?op=library&q=${encodeURIComponent(q)}`, {
    headers: { accept: "application/json", ...(process.env.BW_BYPASS ? { "x-vercel-protection-bypass": process.env.BW_BYPASS } : {}) },
  });
  if (reply.status !== 200) throw new Error(`${q}: ${reply.status}`);
  const body = await reply.json();
  return { top: (body.models || []).slice(0, 3).map((one) => one.library?.set || ""),
    themes: (body.models || []).slice(0, 3).map((one) => one.library?.theme || ""), total: body.total };
}

const table = queries();
const answers = [];
let ms = null;
if (args.url) {
  const url = args.url.replace(/\/$/, "");
  // Four at a time: the deployment is the site people use.
  for (let at = 0; at < table.length; at += 4) {
    answers.push(...await Promise.all(table.slice(at, at + 4).map((one) => asked(url, one.q))));
  }
} else {
  const sets = await import(path.join(ROOT, "api/_sets.js"));
  const catalogue = sets.setCatalog();
  if (!catalogue) throw new Error("no assets/generated/set_catalog.json: run tools/set_catalog.py");
  const run = (q) => sets.searchCatalog(catalogue.sets, sets.askSets({ q }));
  for (const one of table) {
    const found = run(one.q);
    answers.push({ top: found.sets.slice(0, 3).map((entry) => entry.set), themes: found.sets.slice(0, 3).map((entry) => entry.theme[0] || ""),
      total: found.total, meant: found.meant || "" });
  }
  const times = [];
  for (let round = 0; round < 10; round += 1) {
    for (const one of table) {
      const from = process.hrtime.bigint();
      run(one.q);
      times.push(Number(process.hrtime.bigint() - from) / 1e6);
    }
  }
  times.sort((a, b) => a - b);
  const at = (p) => Math.round(times[Math.min(times.length - 1, Math.floor(p * times.length))] * 10) / 10;
  ms = { p50: at(0.5), p95: at(0.95), most: at(1) };
}

const misses = [];
/// Whether [want] (a set's number, or theme:X for any set of top theme X) is in the answer's first three.
const has = (answer, want) => (want.startsWith("theme:") ? answer.themes.includes(want.slice(6)) : answer.top.includes(want));
table.forEach((one, i) => {
  if (!one.want.some((want) => has(answers[i], want))) {
    misses.push({ q: one.q, kind: one.kind, want: one.want, top: answers[i].top, total: answers[i].total });
  }
});
const passed = table.length - misses.length;
const rate = Math.round((passed / table.length) * 1000) / 1000;
if (args.json) {
  console.log(JSON.stringify({ rate, passed, of: table.length, misses, ms }));
} else {
  for (const miss of misses) {
    console.log(`MISS ${miss.q.padEnd(24)} [${miss.kind}] wanted ${miss.want.join(" ")}; got ${miss.top.join(" ") || "nothing"} of ${miss.total}`);
  }
  console.log(`${passed} of ${table.length} found in the first three: ${(rate * 100).toFixed(1)}%`
    + (ms ? `; server time p50 ${ms.p50} ms, p95 ${ms.p95} ms, most ${ms.most} ms` : ""));
}
process.exit(rate >= bar ? 0 : 1);
