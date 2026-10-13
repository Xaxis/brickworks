// How the gallery's list holds up when asked a lot: N requests to
// /api/share?op=list, a few at a time, each a question a person could ask
// (a search, a kind, a size, a sort, a later page), timed and counted.
//
//   node tools/web/list_load.mjs --url=<deployment> [--n=200] [--at-once=10] [--most-ms=2500]
//   (BW_BYPASS for a protected preview)
//
// Passes when every answer is a 200 with a list in it, and nine in ten
// came back within --most-ms. Prints the spread of the times, slowest
// question first, so a slow filter shows itself. Reads only: nothing is
// written by asking.
const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("list_load: --url=<deployment>");
  process.exit(2);
}
const base = String(args.url).replace(/\/+$/, "");
const total = Number(args.n || 200);
const atOnce = Number(args["at-once"] || 10);
const mostMs = Number(args["most-ms"] || 2500);
const headers = { accept: "application/json" };
if (process.env.BW_BYPASS) headers["x-vercel-protection-bypass"] = process.env.BW_BYPASS;

const QUESTIONS = [
  "", "&sort=views", "&sort=likes", "&sort=remixes", "&q=castle", "&q=car", "&q=tower%20wizard",
  "&kind=castle", "&kind=space", "&kind=vehicle&sort=views", "&size=small", "&size=large",
  "&instructions=1", "&technic=1", "&tag=castle", "&q=a%20small&size=medium", "&page=2",
  "&q=brickworks&sort=remixes", "&kind=town&instructions=1", "&q=zz",
];

const times = [];
const byQuestion = new Map();
const statuses = new Map();
let failures = 0;
let next = 0;

async function one() {
  while (next < total) {
    const n = next++;
    const question = QUESTIONS[n % QUESTIONS.length];
    const started = performance.now();
    let status = 0;
    try {
      const reply = await fetch(`${base}/api/share?op=list${question}`, { headers });
      status = reply.status;
      const body = await reply.json();
      if (status !== 200 || !Array.isArray(body.models)) failures += 1;
    } catch {
      failures += 1;
    }
    const ms = performance.now() - started;
    times.push(ms);
    statuses.set(status, (statuses.get(status) || 0) + 1);
    const seen = byQuestion.get(question) || [];
    seen.push(ms);
    byQuestion.set(question, seen);
  }
}

const began = performance.now();
await Promise.all(Array.from({ length: atOnce }, one));
const took = (performance.now() - began) / 1000;
times.sort((a, b) => a - b);
const at = (p) => Math.round(times[Math.min(times.length - 1, Math.floor(p * times.length))]);
console.log(`${total} requests to ${base}/api/share?op=list, ${atOnce} at a time, in ${took.toFixed(1)} s`);
console.log(`  answers: ${[...statuses].map(([s, c]) => `${c} x ${s || "none"}`).join(", ")}`);
console.log(`  times: fastest ${at(0)} ms, median ${at(0.5)} ms, 90% within ${at(0.9)} ms, `
  + `99% within ${at(0.99)} ms, slowest ${Math.round(times[times.length - 1])} ms`);
const slowest = [...byQuestion].map(([q, ms]) => [q || "(the first page)", ms.reduce((a, b) => a + b, 0) / ms.length])
  .sort((a, b) => b[1] - a[1]).slice(0, 5);
console.log(`  slowest questions, on average: ${slowest.map(([q, ms]) => `${q} ${Math.round(ms)} ms`).join("; ")}`);
const ok = failures === 0 && at(0.9) <= mostMs;
console.log(ok ? `list_load ok: no errors, 90% within ${at(0.9)} ms (at most ${mostMs})`
  : `list_load FAILED: ${failures} errors, 90% within ${at(0.9)} ms (at most ${mostMs})`);
process.exit(ok ? 0 : 1);
