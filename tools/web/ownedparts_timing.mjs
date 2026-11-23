// How long a gallery page of 24 cards takes to answer someone signed in
// with a collection (op=list&mine=1, each card's share of it counted), on
// two deployments of the same database at the same moment: --a the one to
// beat (a pre261 preview), --b this unit's. A round asks both at once, the
// one asked first by turns; two rounds to warm them are not counted, then
// [--rounds] (16). The bar (ownedparts): b no more than 50 ms slower than a
// at the median of the rounds' differences.
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/ownedparts_timing.mjs \
//     --a=https://<pre261 preview> --b=https://<unit preview> --out=DIR
//
// One throwaway account, its collection kept as a person keeps it (three
// sets and some loose parts), deleted at the end with everything of its.
import { deleteAccount, mintSession } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const sites = { a: String(args.a || "").replace(/\/+$/, ""), b: String(args.b || "").replace(/\/+$/, "") };
if (!sites.a || !sites.b) {
  console.log("usage: ownedparts_timing.mjs --a=URL --b=URL [--rounds=16] [--out=DIR]");
  process.exit(2);
}
const rounds = Math.max(4, Number(args.rounds) || 16);
const out = args.out ? path.resolve(String(args.out)) : null;
if (out) mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const email = `delivered+bw-ownedtime-${randomBytes(4).toString("hex")}@resend.dev`;

async function timed(site, pathname, token) {
  const at = performance.now();
  const reply = await fetch(`${site}${pathname}`, { headers: { ...headers, authorization: `Bearer ${token}` } });
  const body = await reply.json().catch(() => ({}));
  return { ms: performance.now() - at, status: reply.status, cards: (body.models || []).length,
    shared: (body.models || []).filter((one) => one.owned).length };
}

const median = (list) => {
  const sorted = [...list].sort((x, y) => x - y);
  const half = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[half] : (sorted[half - 1] + sorted[half]) / 2;
};

let failed = 0;
let who = null;
const rows = [];
try {
  who = await mintSession(email);
  const keep = (body) => fetch(`${sites.b}/api/collection`, { method: "POST",
    headers: { ...headers, authorization: `Bearer ${who.access_token}`, "content-type": "application/json" },
    body: JSON.stringify(body) }).then((reply) => reply.status);
  const kept = [];
  for (const [set, qty] of [["6541-1", 1], ["6596-1", 2], ["10497-1", 1]]) kept.push(await keep({ op: "own", set, was: 0, qty }));
  kept.push(await keep({ op: "lots", id: `time-${Date.now()}`, add: [{ part: "3001", colour: 4, qty: 40 }, { part: "3020", colour: 15, qty: 12 }] }));
  console.log(`a ${sites.a}\nb ${sites.b}\nthe collection kept: ${kept.join(" ")}`);
  for (let n = 0; n < rounds + 2; n++) {
    const pathname = `/api/share?op=list&page=1&mine=1&r=${n}`;
    const order = n % 2 ? ["b", "a"] : ["a", "b"];
    const [first, second] = await Promise.all(order.map((side) => timed(sites[side], pathname, who.access_token)));
    const got = { [order[0]]: first, [order[1]]: second };
    if (n < 2) continue;
    rows.push({ round: n - 1, first: order[0], a: Math.round(got.a.ms), b: Math.round(got.b.ms), diff: Math.round(got.b.ms - got.a.ms),
      cards: `${got.a.cards}/${got.b.cards}`, shared: `${got.a.shared}/${got.b.shared}`, status: `${got.a.status}/${got.b.status}` });
    console.log(`  round ${n - 1}: a ${Math.round(got.a.ms)} ms, b ${Math.round(got.b.ms)} ms (${order[0]} asked first), `
      + `${got.a.cards}/${got.b.cards} cards, ${got.a.shared}/${got.b.shared} with a share`);
    await new Promise((done) => setTimeout(done, 500));
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await deleteAccount(email).catch(() => {});
}
const good = rows.filter((row) => row.status === "200/200" && row.cards === "24/24");
const diff = good.length ? median(good.map((row) => row.diff)) : NaN;
const summary = { rounds: good.length, a_median: median(good.map((row) => row.a)), b_median: median(good.map((row) => row.b)),
  diff_median: diff, b_slower_in: good.filter((row) => row.diff > 0).length };
console.log(`${good.length} rounds of 24 cards: a ${summary.a_median} ms, b ${summary.b_median} ms at the median; `
  + `b - a ${diff} ms at the median (b slower in ${summary.b_slower_in} of ${good.length})`);
const ok = !failed && good.length === rounds && good.every((row) => row.shared.split("/")[0] === row.shared.split("/")[1])
  && diff <= 50;
if (out) writeFileSync(path.join(out, "ownedparts_timing.json"), `${JSON.stringify({ sites, summary, rows }, null, 1)}\n`);
console.log(ok ? "  ok    within 50 ms of a" : "  FAIL  not within 50 ms of a, or rounds missing");
process.exit(ok ? 0 : 1);
