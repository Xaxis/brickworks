// Two or three web builds' first visits, timed in turn at the same moments,
// so a loaded box weighs on each alike: their ratio is the measure, not the
// seconds (memory: an ABBA at equal load).
//
//   set -a; . ./.env; set +a
//   ~/.claude/claude-core/bin/heavy node tools/web/start_abba.mjs \
//     --arm=m276=../webstart9-snapa/build/web --arm=pre261=../webstart9-snapb/build/web \
//     --blocks=4 --out=DIR [--bar=10] [--port=9930] [-- load_check's own arguments]
//   node tools/web/start_abba.mjs --summary --out=DIR      the table again, nothing run
//
// An arm is a build folder (tools/export.sh web), served on its own port by
// tools/web/serve.py as the deployment sends it (--accounts --compressed
// --cached), one at a time and only for its own run; or a URL (<origin>/app),
// live or a preview (BW_BYPASS for a preview). The first arm is the base.
// Each block runs the arms forward and back (A B B A; A B C C B A), so a
// load rising through a block costs each arm the same. Each run is one
// tools/web/load_check.mjs --runs=1 --warm: a fresh profile's cold visit,
// then the same profile's return, on broadband (20 Mbps, 40 ms), with the
// box's load read before and after it. Every arm is judged by this
// checkout's load_check and serve.py.
//
// Said for each run, then each arm (median and range): the bin usable,
// cold and warm; the scripts' compile (the engine's own start done to
// Main's "compiled"), cold and warm; the main thread's CPU before then
// (Chrome's ThreadTime, which the load stretches least); the bytes. Then
// each arm against the base, paired by block: the median of its block
// means over the base's. Over --bar per cent on the bin usable or the
// compile, cold or warm, is a FAIL (exit 1), and so is an arm with fewer
// than half its runs. A13's target (10 s cold, 4 s warm) is said beside,
// not judged: on this box it is out of reach at any load over ~10.
//
// For a build folder in a checkout, the first screen's source is said too
// (tools/web/start_closure.py, this checkout's reading of the arm's tree):
// the compile is about 0.37 s a MB of it (webstart2, 2026-11-05), so a
// slower compile with no more source is the box.
//
// Files: DIR/arms.json, DIR/runs.jsonl (a line a run: its arm, block, load
// before and after, exit), DIR/<n>_<arm>.log and DIR/<n>_<arm>/load.json
// (load_check's), DIR/summary.txt.
import { spawn, spawnSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "../..");
const TARGET = { cold: 10, warm: 4 };
// What is judged: [label, kind (cold/warm), the run's value].
const MEASURES = [
  ["bin usable", "cold", (s) => s.interactive], ["bin usable", "warm", (s) => s.interactive],
  ["compile", "cold", (s) => s.split?.compile], ["compile", "warm", (s) => s.split?.compile],
];
const SHOWN = [...MEASURES, ["main thread", "cold", (s) => s.cpu], ["main thread", "warm", (s) => s.cpu]];

let arms = [];
let opt = {};
let passed = [];
let out = "";
let bar = 10;
function parse(argv) {
  const cut = argv.indexOf("--");
  passed = cut < 0 ? [] : argv.slice(cut + 1);
  for (const a of cut < 0 ? argv : argv.slice(0, cut)) {
    const [k, ...rest] = a.replace(/^--/, "").split("=");
    if (k === "arm") {
      const [name, ...target] = rest;
      if (!name || !target.length) usage(`--arm=NAME=FOLDER|URL, not ${a}`);
      arms.push({ name, target: target.join("=") });
    } else opt[k] = rest.length ? rest.join("=") : true;
  }
  if (!opt.out || opt.out === true) usage("--out=DIR is required");
  out = resolve(String(opt.out));
  bar = opt.bar === undefined ? 10 : Number(opt.bar);
}

function usage(why) {
  console.error(`start_abba: ${why}`);
  process.exit(2);
}

const median = (xs) => {
  const v = xs.filter(Number.isFinite).sort((a, b) => a - b);
  if (!v.length) return NaN;
  const m = Math.floor(v.length / 2);
  return v.length % 2 ? v[m] : (v[m - 1] + v[m]) / 2;
};
const mean = (xs) => (xs.length ? xs.reduce((n, x) => n + x, 0) / xs.length : NaN);
const s2 = (ms) => (Number.isFinite(ms) ? (ms / 1000).toFixed(2) : "  -  ");

// The arms forward and back in each block: A B B A, or A B C C B A.
export function order(names, blocks) {
  const runs = [];
  for (let b = 1; b <= blocks; b++) for (const name of [...names, ...[...names].reverse()]) runs.push({ block: b, arm: name });
  return runs.map((r, i) => ({ n: i + 1, ...r }));
}

function load() {
  const [one, five, fifteen, runnable] = readFileSync("/proc/loadavg", "utf8").trim().split(/\s+/);
  return { one: Number(one), five: Number(five), fifteen: Number(fifteen), runnable: runnable.split("/")[0] };
}

// The first screen's source in the arm's checkout, as this checkout reads it.
function closureOf(folder) {
  const top = spawnSync("git", ["-C", folder, "rev-parse", "--show-toplevel"], { encoding: "utf8" });
  if (top.status !== 0) return null;
  const root = top.stdout.trim();
  const sha = spawnSync("git", ["-C", root, "rev-parse", "--short=9", "HEAD"], { encoding: "utf8" }).stdout.trim();
  const py = `import sys, json
sys.path.insert(0, ${JSON.stringify(join(ROOT, "tools/web"))})
import start_closure as s
from pathlib import Path
r = Path(sys.argv[1])
c = s.closure(r)
every = s.scripts(r)
print(json.dumps({"scripts": len(c), "of": len(every), "bytes": sum(len(every[p].encode()) for p in c if p in every)}))`;
  const got = spawnSync("python3", ["-c", py, root], { encoding: "utf8" });
  const closure = got.status === 0 ? JSON.parse(got.stdout) : { why: got.stderr.trim().split("\n").pop() };
  return { root, sha, closure };
}

async function serve(arm, port) {
  const parts = [join(arm.root || "", "assets/generated/parts"), join(ROOT, "assets/generated/parts")].find((p) => existsSync(p));
  const child = spawn("python3", [join(ROOT, "tools/web/serve.py"), arm.folder, String(port), "--parts", parts, "--delay", "0",
    "--accounts", "--compressed", "--cached"], { cwd: arm.root || ROOT, stdio: ["ignore", "ignore", "pipe"] });
  let said = "";
  child.stderr.on("data", (d) => { said = (said + d).slice(-2000); });
  for (let i = 0; i < 60; i++) {
    const up = await fetch(`http://127.0.0.1:${port}/index.html`).then((r) => r.ok).catch(() => false);
    if (up) return child;
    if (child.exitCode !== null) break;
    await new Promise((r) => setTimeout(r, 500));
  }
  child.kill();
  throw new Error(`serve.py did not answer on ${port} for ${arm.folder}: ${said.trim().split("\n").pop() || "no word"}`);
}

function loadCheck(url, dir, log, preview) {
  const env = { ...process.env };
  if (!preview) delete env.BW_BYPASS;
  const args = [join(ROOT, "tools/web/load_check.mjs"), `--url=${url}`, "--runs=1", "--warm", `--out=${dir}`, ...passed];
  return new Promise((done) => {
    const child = spawn("node", args, { cwd: ROOT, env, stdio: ["ignore", "pipe", "pipe"] });
    const chunks = [];
    child.stdout.on("data", (d) => chunks.push(d));
    child.stderr.on("data", (d) => chunks.push(d));
    const timer = setTimeout(() => child.kill("SIGKILL"), 600_000);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      writeFileSync(log, Buffer.concat(chunks));
      done(signal ? `killed (${signal}, 600 s)` : code);
    });
  });
}

async function run() {
  if (arms.length < 2 || arms.length > 3) usage("two or three --arm=NAME=FOLDER|URL, the base first");
  if (new Set(arms.map((a) => a.name)).size !== arms.length || arms.some((a) => !/^[\w.-]+$/.test(a.name))) usage("each arm a name of its own, letters, digits, . _ -");
  const port = Number(opt.port || 9930);
  for (const [i, arm] of arms.entries()) {
    if (/^https?:\/\//.test(arm.target)) {
      arm.url = arm.target;
      arm.preview = /\.vercel\.app$/.test(new URL(arm.target).host);
      continue;
    }
    arm.folder = resolve(arm.target);
    if (!existsSync(join(arm.folder, "index.html"))) usage(`${arm.name}: no index.html in ${arm.folder} (tools/export.sh web)`);
    arm.port = port + i;
    arm.url = `http://127.0.0.1:${arm.port}/index.html`;
    arm.built = statSync(join(arm.folder, "index.pck")).mtime.toISOString();
    Object.assign(arm, closureOf(arm.folder) || {});
  }
  if (!process.env.SUPABASE_URL) console.log("start_abba: no SUPABASE_URL in the environment (. ./.env): each visitor is shown the sign-in, not the app");
  mkdirSync(out, { recursive: true });
  const blocks = Number(opt.blocks || 4);
  const plan = order(arms.map((a) => a.name), blocks);
  writeFileSync(join(out, "arms.json"), JSON.stringify({ arms, blocks, bar, passed, plan }, null, 1));
  writeFileSync(join(out, "runs.jsonl"), "");
  sayArms(arms);
  for (const step of plan) {
    const arm = arms.find((a) => a.name === step.arm);
    const before = load();
    const started = new Date().toISOString();
    let server = null;
    let exit;
    try {
      if (arm.folder) server = await serve(arm, arm.port);
      exit = await loadCheck(arm.url, join(out, `${step.n}_${arm.name}`), join(out, `${step.n}_${arm.name}.log`), arm.preview);
    } catch (trouble) {
      exit = String(trouble.message || trouble).slice(0, 300);
    } finally {
      if (server) {
        server.kill();
        await new Promise((r) => (server.exitCode !== null ? r() : server.once("exit", r)));
      }
    }
    const line = { ...step, started, before, after: load(), exit };
    appendFileSync(join(out, "runs.jsonl"), `${JSON.stringify(line)}\n`);
    const got = readRun(step);
    console.log(`  ${String(step.n).padStart(2)} ${arm.name.padEnd(10)} block ${step.block}  load ${before.one.toFixed(1)} -> ${line.after.one.toFixed(1)}  `
      + (got ? `cold ${s2(got.cold.interactive)} (compile ${s2(got.cold.split?.compile)})  warm ${s2(got.warm?.interactive)} (compile ${s2(got.warm?.split?.compile)})`
        : `no result (exit ${exit})`));
  }
}

function sayArms(list) {
  for (const a of list) {
    const c = a.closure;
    console.log(`  ${a.name}: ${a.url}${a.sha ? ` (${a.sha}, exported ${a.built.slice(0, 16)}Z)` : ""}`
      + (c && c.bytes ? `; the first screen's source ${(c.bytes / 1e6).toFixed(2)} MB in ${c.scripts} of ${c.of} scripts` : c?.why ? `; its source not read: ${c.why}` : ""));
  }
}

function readRun(step) {
  const path = join(out, `${step.n}_${step.arm}`, "load.json");
  if (!existsSync(path)) return null;
  const s = JSON.parse(readFileSync(path, "utf8")).summary || {};
  const cold = s["broadband cold"];
  if (!cold || !Number.isFinite(cold.interactive)) return null;
  const warm = s["broadband warm"] && Number.isFinite(s["broadband warm"].interactive) ? s["broadband warm"] : null;
  return { cold, warm };
}

function summarise() {
  const { arms: list, bar: barWas } = JSON.parse(readFileSync(join(out, "arms.json"), "utf8"));
  const limit = opt.bar === undefined ? barWas : bar;
  const steps = readFileSync(join(out, "runs.jsonl"), "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const lines = [];
  const say = (s) => { lines.push(s); console.log(s); };
  say(`start_abba: ${list.slice(1).map((a) => a.name).join(" and ")} against ${list[0].name}, ${steps.length} runs`);
  for (const a of list) {
    const c = a.closure;
    say(`  ${a.name}: ${a.target}${a.sha ? ` at ${a.sha}` : ""}${c && c.bytes ? `, first screen ${(c.bytes / 1e6).toFixed(2)} MB of source in ${c.scripts} of ${c.of} scripts` : ""}`);
  }
  say("");
  say(" n  arm         block  load (1 min)    cold: usable  compile  main  |  warm: usable  compile  main  |  MB cold");
  const runs = [];
  for (const step of steps) {
    const got = readRun(step);
    const loadSaid = `${step.before.one.toFixed(1).padStart(5)} -> ${step.after.one.toFixed(1).padStart(5)}`;
    if (!got) {
      say(`${String(step.n).padStart(2)}  ${step.arm.padEnd(11)} ${String(step.block).padStart(3)}    ${loadSaid}   no result: exit ${step.exit}`);
      continue;
    }
    runs.push({ ...step, ...got });
    const { cold, warm } = got;
    say(`${String(step.n).padStart(2)}  ${step.arm.padEnd(11)} ${String(step.block).padStart(3)}    ${loadSaid}   `
      + `${s2(cold.interactive).padStart(11)}  ${s2(cold.split?.compile).padStart(7)}  ${s2(cold.cpu).padStart(5)}  |  `
      + `${s2(warm?.interactive).padStart(12)}  ${s2(warm?.split?.compile).padStart(7)}  ${s2(warm?.cpu).padStart(5)}  |  ${(cold.bytes / 1e6).toFixed(2)}`);
  }
  say("");
  const value = (r, kind, f) => (r[kind] ? f(r[kind]) : NaN);
  let failed = false;
  for (const a of list) {
    const mine = runs.filter((r) => r.arm === a.name);
    const planned = steps.filter((s) => s.arm === a.name).length;
    const loads = steps.filter((s) => s.arm === a.name).map((s) => (s.before.one + s.after.one) / 2);
    say(`${a.name}: ${mine.length} of ${planned} runs, load ${Math.min(...loads).toFixed(0)} to ${Math.max(...loads).toFixed(0)} (median ${median(loads).toFixed(1)})`);
    for (const [label, kind, f] of SHOWN) {
      const v = mine.map((r) => value(r, kind, f)).filter(Number.isFinite);
      const target = label === "bin usable" ? ` (A13's target ${TARGET[kind]} s)` : "";
      say(`  ${`${label}, ${kind}`.padEnd(19)} ${s2(median(v))} s (${s2(Math.min(...v))} to ${s2(Math.max(...v))})${target}`);
    }
    if (mine.length * 2 < planned) {
      say(`  FAIL ${a.name}: ${mine.length} of ${planned} runs gave a result`);
      failed = true;
    }
  }
  const base = list[0].name;
  for (const a of list.slice(1)) {
    say("");
    say(`${a.name} against ${base}, paired by block (each block's mean over the base's), then the plain medians:`);
    for (const [label, kind, f] of SHOWN) {
      const ratios = [];
      for (const block of [...new Set(runs.map((r) => r.block))]) {
        const mineB = runs.filter((r) => r.block === block && r.arm === a.name).map((r) => value(r, kind, f)).filter(Number.isFinite);
        const baseB = runs.filter((r) => r.block === block && r.arm === base).map((r) => value(r, kind, f)).filter(Number.isFinite);
        if (mineB.length && baseB.length) ratios.push(mean(mineB) / mean(baseB));
      }
      const paired = median(ratios);
      const plain = median(runs.filter((r) => r.arm === a.name).map((r) => value(r, kind, f)))
        / median(runs.filter((r) => r.arm === base).map((r) => value(r, kind, f)));
      const judged = MEASURES.some(([l, k]) => l === label && k === kind) && limit > 0;
      const over = judged && !(paired <= 1 + limit / 100);
      failed ||= over;
      say(`  ${judged ? (over ? "FAIL" : "ok  ") : "    "} ${`${label}, ${kind}`.padEnd(19)} x${Number.isFinite(paired) ? paired.toFixed(3) : "-"}`
        + ` (blocks ${ratios.map((x) => x.toFixed(2)).join(", ") || "none"}; medians x${Number.isFinite(plain) ? plain.toFixed(3) : "-"})`
        + (judged ? `, bar x${(1 + limit / 100).toFixed(2)}` : ""));
    }
  }
  say(failed ? "start_abba: FAIL" : "start_abba: ok");
  writeFileSync(join(out, "summary.txt"), `${lines.join("\n")}\n`);
  return failed;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  parse(process.argv.slice(2));
  if (!opt.summary) await run();
  process.exit(summarise() ? 1 : 0);
}
