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
// --pairs=N times them at the same moments instead (webstart10, 2026-11-16;
// memory same-moment-pairs): each pair starts every arm at once, each in a
// browser of its own, the second a quarter second after the first, which
// side goes first alternating by pair. In turn, on a box whose load swings
// with the release train's jobs, three runs a side landed on opposite modes
// and read a build 2.6x slower that pairs read 0.78x (kinefast, 2026-11-13).
// With --phone each pair runs again in a phone's window (load_check
// --phone), timed to its first frame. Each pair is a block of the pairing
// below, and each arm is said against webstart10's target (APP_UX9: the bin
// usable 12 s cold and 6.5 s warm, a phone's first frame 11 s cold): in how
// many pairs it met it. And the start's account of its files (load_check's
// startAccount), each arm's medians: what the engine, Main and nothing
// waited for, and when it came.
//
//   ~/.claude/claude-core/bin/heavy node tools/web/start_abba.mjs \
//     --arm=live=https://brickworks.diy/app --arm=mine=../snap/build/web \
//     --pairs=2 --phone --out=DIR
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
// webstart10's target (APP_UX9), in seconds: said beside each arm, in how
// many runs it was met, never judged (the ratio is).
const TARGET = { "bin usable": { cold: 12, warm: 6.5 }, "first frame": { cold: 11 } };
// What is judged, by window: [label, kind (cold/warm), the run's value]. A
// phone keeps the bin behind a button: its load is timed to its first frame.
const MEASURES = {
  desktop: [
    ["bin usable", "cold", (s) => s.interactive], ["bin usable", "warm", (s) => s.interactive],
    ["compile", "cold", (s) => s.split?.compile], ["compile", "warm", (s) => s.split?.compile],
  ],
  phone: [
    ["first frame", "cold", (s) => s.firstFrame], ["first frame", "warm", (s) => s.firstFrame],
    ["compile", "cold", (s) => s.split?.compile], ["compile", "warm", (s) => s.split?.compile],
  ],
};
const SHOWN = Object.fromEntries(Object.entries(MEASURES).map(([view, list]) =>
  [view, [...list, ["main thread", "cold", (s) => s.cpu], ["main thread", "warm", (s) => s.cpu]]]));

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

// Same-moment pairs: in each, every arm at once (the one asked first
// alternating), on the desktop's window and then, with [phone], a phone's.
export function pairs(names, count, phone = false) {
  const runs = [];
  for (let p = 1; p <= count; p++) {
    for (const view of phone ? ["desktop", "phone"] : ["desktop"]) {
      const first = names[(p - 1) % names.length];
      const together = [first, ...names.filter((x) => x !== first)];
      runs.push({ block: p, view, together });
    }
  }
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
  // A server left on the port by a run that crashed answers for this one,
  // whose own dies unbound, so the run would time what that one serves
  // (bootlook2, 2026-11-23: two left from a crash an hour before).
  if (await fetch(`http://127.0.0.1:${port}/`).then(async (r) => { await r.arrayBuffer(); return true; }).catch(() => false)) {
    throw new Error(`port ${port} is already served: stop what holds it, or give --port another`);
  }
  const parts = [join(arm.root || "", "assets/generated/parts"), join(ROOT, "assets/generated/parts")].find((p) => existsSync(p));
  const child = spawn("python3", [join(ROOT, "tools/web/serve.py"), arm.folder, String(port), "--parts", parts, "--delay", "0",
    "--accounts", "--compressed", "--cached"], { cwd: arm.root || ROOT, stdio: ["ignore", "ignore", "pipe"] });
  let said = "";
  child.stderr.on("data", (d) => { said = (said + d).slice(-2000); });
  for (let i = 0; i < 60; i++) {
    // Read to its end: the page left unread, then closed by serve.py, threw
    // inside node 24's fetch and ended the whole run (bootlook2, 2026-11-23).
    const up = await fetch(`http://127.0.0.1:${port}/index.html`).then(async (r) => { await r.arrayBuffer(); return r.ok; })
      .catch(() => false);
    if (up) return child;
    if (child.exitCode !== null) break;
    await new Promise((r) => setTimeout(r, 500));
  }
  child.kill();
  throw new Error(`serve.py did not answer on ${port} for ${arm.folder}: ${said.trim().split("\n").pop() || "no word"}`);
}

function loadCheck(url, dir, log, preview, view = "desktop") {
  const env = { ...process.env };
  if (!preview) delete env.BW_BYPASS;
  const args = [join(ROOT, "tools/web/load_check.mjs"), `--url=${url}`, "--runs=1", "--warm", `--out=${dir}`,
    ...(view === "phone" ? ["--phone"] : []), ...passed];
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
  if (opt.pairs) return runPairs(Number(opt.pairs));
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

// Each pair: every arm served and its load_check begun at once (the next a
// quarter second after), each in a browser of its own; a line a run.
async function runPairs(count) {
  const plan = pairs(arms.map((a) => a.name), count, Boolean(opt.phone));
  writeFileSync(join(out, "arms.json"), JSON.stringify({ arms, blocks: count, bar, passed, plan, together: true }, null, 1));
  writeFileSync(join(out, "runs.jsonl"), "");
  sayArms(arms);
  for (const step of plan) {
    const before = load();
    const started = new Date().toISOString();
    const servers = [];
    const exits = {};
    try {
      for (const arm of arms) if (arm.folder) servers.push(await serve(arm, arm.port));
      await Promise.all(step.together.map((name, i) => new Promise((r) => setTimeout(r, i * 250)).then(() => {
        const arm = arms.find((a) => a.name === name);
        return loadCheck(arm.url, join(out, `${step.n}_${name}`), join(out, `${step.n}_${name}.log`), arm.preview, step.view)
          .then((exit) => { exits[name] = exit; });
      })));
    } catch (trouble) {
      for (const name of step.together) exits[name] ??= String(trouble.message || trouble).slice(0, 300);
    } finally {
      for (const server of servers) {
        server.kill();
        await new Promise((r) => (server.exitCode !== null ? r() : server.once("exit", r)));
      }
    }
    const after = load();
    for (const name of step.together) {
      const line = { n: step.n, block: step.block, arm: name, view: step.view, first: name === step.together[0], started, before, after, exit: exits[name] };
      appendFileSync(join(out, "runs.jsonl"), `${JSON.stringify(line)}\n`);
    }
    const said = step.together.map((name) => {
      const got = readRun({ n: step.n, arm: name, view: step.view });
      const f = step.view === "phone" ? (x) => x?.firstFrame : (x) => x?.interactive;
      return `${name} ${got ? `cold ${s2(f(got.cold))} warm ${s2(f(got.warm))}` : `no result (exit ${exits[name]})`}`;
    });
    console.log(`  pair ${step.block} ${step.view.padEnd(7)} load ${before.one.toFixed(1)} -> ${after.one.toFixed(1)}  ${said.join("  |  ")}`);
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
  const done = step.view === "phone" ? (x) => x && Number.isFinite(x.firstFrame) : (x) => x && Number.isFinite(x.interactive);
  const cold = s["broadband cold"];
  if (!done(cold)) return null;
  const warm = done(s["broadband warm"]) ? s["broadband warm"] : null;
  return { cold, warm };
}

function summarise() {
  const { arms: list, bar: barWas, together } = JSON.parse(readFileSync(join(out, "arms.json"), "utf8"));
  const limit = opt.bar === undefined ? barWas : bar;
  const steps = readFileSync(join(out, "runs.jsonl"), "utf8").trim().split("\n").filter(Boolean).map((l) => JSON.parse(l));
  for (const step of steps) step.view ||= "desktop";
  const lines = [];
  const say = (s) => { lines.push(s); console.log(s); };
  say(`start_abba: ${list.slice(1).map((a) => a.name).join(" and ")} against ${list[0].name}, ${steps.length} runs`
    + (together ? `, ${new Set(steps.map((x) => x.block)).size} same-moment pairs` : ""));
  for (const a of list) {
    const c = a.closure;
    say(`  ${a.name}: ${a.target}${a.sha ? ` at ${a.sha}` : ""}${c && c.bytes ? `, first screen ${(c.bytes / 1e6).toFixed(2)} MB of source in ${c.scripts} of ${c.of} scripts` : ""}`);
  }
  const views = [...new Set(steps.map((x) => x.view))];
  const runs = [];
  for (const view of views) {
    const goal = view === "phone" ? "first frame" : "usable";
    const at = view === "phone" ? (x) => x?.firstFrame : (x) => x?.interactive;
    say("");
    say(`${together ? "pair" : "  n"}  arm         ${together ? "  " : "block"}  load (1 min)    cold: ${goal}  compile  main  |  warm: ${goal}  compile  main  |  MB cold   (${view})`);
    for (const step of steps.filter((x) => x.view === view)) {
      const got = readRun(step);
      const loadSaid = `${step.before.one.toFixed(1).padStart(5)} -> ${step.after.one.toFixed(1).padStart(5)}`;
      const tag = together ? `${String(step.block).padStart(3)} ${step.first ? "*" : " "}` : `${String(step.n).padStart(3)} `;
      if (!got) {
        say(`${tag} ${step.arm.padEnd(11)} ${together ? "" : String(step.block).padStart(3)}    ${loadSaid}   no result: exit ${step.exit}`);
        continue;
      }
      runs.push({ ...step, ...got });
      const { cold, warm } = got;
      say(`${tag} ${step.arm.padEnd(11)} ${together ? "  " : String(step.block).padStart(3)}    ${loadSaid}   `
        + `${s2(at(cold)).padStart(11)}  ${s2(cold.split?.compile).padStart(7)}  ${s2(cold.cpu).padStart(5)}  |  `
        + `${s2(at(warm)).padStart(12)}  ${s2(warm?.split?.compile).padStart(7)}  ${s2(warm?.cpu).padStart(5)}  |  ${(cold.bytes / 1e6).toFixed(2)}`);
    }
  }
  if (together) say("  (* the arm begun first in its pair)");
  const value = (r, kind, f) => (r[kind] ? f(r[kind]) : NaN);
  let failed = false;
  for (const a of list) {
    say("");
    const planned = steps.filter((x) => x.arm === a.name).length;
    const mine = runs.filter((r) => r.arm === a.name);
    const loads = steps.filter((x) => x.arm === a.name).map((x) => (x.before.one + x.after.one) / 2);
    say(`${a.name}: ${mine.length} of ${planned} runs, load ${Math.min(...loads).toFixed(0)} to ${Math.max(...loads).toFixed(0)} (median ${median(loads).toFixed(1)})`);
    for (const view of views) {
      const these = mine.filter((r) => r.view === view);
      for (const [label, kind, f] of SHOWN[view]) {
        const v = these.map((r) => value(r, kind, f)).filter(Number.isFinite);
        const target = TARGET[label]?.[kind];
        const met = target ? v.filter((x) => x <= target * 1000).length : 0;
        say(`  ${`${label}, ${kind}${views.length > 1 ? ` (${view})` : ""}`.padEnd(29)} ${s2(median(v))} s (${s2(Math.min(...v))} to ${s2(Math.max(...v))})`
          + (target ? `  target ${target} s: met in ${met} of ${v.length}` : ""));
      }
    }
    sayAccount(a.name, mine.filter((r) => r.view === "desktop"), say);
    if (mine.length * 2 < planned) {
      say(`  FAIL ${a.name}: ${mine.length} of ${planned} runs gave a result`);
      failed = true;
    }
  }
  const base = list[0].name;
  for (const a of list.slice(1)) {
    say("");
    say(`${a.name} against ${base}, paired by ${together ? "pair" : "block"} (each ${together ? "pair's" : "block's mean"} over the base's), then the plain medians:`);
    for (const view of views) {
      for (const [label, kind, f] of SHOWN[view]) {
        const ratios = [];
        const inView = runs.filter((r) => r.view === view);
        for (const block of [...new Set(inView.map((r) => r.block))]) {
          const mineB = inView.filter((r) => r.block === block && r.arm === a.name).map((r) => value(r, kind, f)).filter(Number.isFinite);
          const baseB = inView.filter((r) => r.block === block && r.arm === base).map((r) => value(r, kind, f)).filter(Number.isFinite);
          if (mineB.length && baseB.length) ratios.push(mean(mineB) / mean(baseB));
        }
        const paired = median(ratios);
        const plain = median(inView.filter((r) => r.arm === a.name).map((r) => value(r, kind, f)))
          / median(inView.filter((r) => r.arm === base).map((r) => value(r, kind, f)));
        const judged = MEASURES[view].some(([l, k]) => l === label && k === kind) && limit > 0;
        const over = judged && !(paired <= 1 + limit / 100);
        failed ||= over;
        say(`  ${judged ? (over ? "FAIL" : "ok  ") : "    "} ${`${label}, ${kind}${views.length > 1 ? ` (${view})` : ""}`.padEnd(29)} x${Number.isFinite(paired) ? paired.toFixed(3) : "-"}`
          + ` (${together ? "pairs" : "blocks"} ${ratios.map((x) => x.toFixed(2)).join(", ") || "none"}; medians x${Number.isFinite(plain) ? plain.toFixed(3) : "-"})`
          + (judged ? `, bar x${(1 + limit / 100).toFixed(2)}` : ""));
      }
    }
  }
  say(failed ? "start_abba: FAIL" : "start_abba: ok");
  writeFileSync(join(out, "summary.txt"), `${lines.join("\n")}\n`);
  return failed;
}

// The start's account of its files (load_check's startAccount), the arm's
// medians cold and warm: each kind's bytes, when it came, and what waited.
function sayAccount(name, runs, say) {
  for (const kind of ["cold", "warm"]) {
    const these = runs.map((r) => r[kind]?.start).filter(Boolean);
    if (!these.length) continue;
    const m = (f) => median(these.map(f));
    const mb = (b) => (Number.isFinite(b) ? (b / 1e6).toFixed(2) : "-");
    say(`  what the start waited for, ${kind}: the engine's files ${mb(m((a) => a.engine.bytes))} MB to ${s2(m((a) => a.engine.to))} s, banner ${s2(m((a) => a.banner))} s; `
      + `the data pack ${mb(m((a) => a.data.bytes))} MB ${s2(m((a) => a.data.from))}-${s2(m((a) => a.data.to))} s, handed ${s2(m((a) => a.data.handed))} s, Main waited ${s2(m((a) => a.data.waited))} s; `
      + `the rest of the parts ${mb(m((a) => a.parts.bytes))} MB to ${s2(m((a) => a.parts.to))} s; the rest ${mb(m((a) => a.rest.bytes))} MB`);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  parse(process.argv.slice(2));
  if (!opt.summary) await run();
  process.exit(summarise() ? 1 : 0);
}
