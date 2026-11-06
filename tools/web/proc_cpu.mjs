// The CPU Chromium spends, as the kernel counts it (/proc), for the checks
// that ask what a page costs: idle_check.mjs (the whole browser by kind of
// process, and no worker spinning standing still) and thread_cpu.mjs (each
// thread of the page's renderer).
//
// Chromium is started by Playwright as a child of the script's own process,
// so everything it runs is the tree under process.pid: no search of other
// programs' command lines.
//
// Why not a trace: V8's sampled profile counts a worker parked in a futex
// wait (Atomics.wait) as busy in the wasm function that waits, so every
// engine worker looked 100% busy in lazycompile's traces (2026-11-05). The
// kernel counts only what ran.
import { readFileSync, readdirSync } from "node:fs";

// utime + stime are in clock ticks: 100 a second on Linux.
const TICK = 100;

function stat(path) {
  const s = readFileSync(path, "utf8");
  const f = s.slice(s.lastIndexOf(")") + 2).split(" ");
  return { ppid: Number(f[1]), cpu: Number(f[11]) + Number(f[12]) };
}

/// Every process under [root], however deep.
export function descendants(root = process.pid) {
  const kids = new Map();
  for (const name of readdirSync("/proc")) {
    if (!/^\d+$/.test(name)) continue;
    try {
      const { ppid } = stat(`/proc/${name}/stat`);
      if (!kids.has(ppid)) kids.set(ppid, []);
      kids.get(ppid).push(Number(name));
    } catch { /* gone */ }
  }
  const all = [];
  const walk = (pid) => { for (const k of kids.get(pid) || []) { all.push(k); walk(k); } };
  walk(root);
  return all;
}

/// A Chromium process's kind: "renderer", "gpu-process", "utility"..., or
/// "browser" for the one with no --type.
export function kind(pid) {
  try {
    const m = /--type=([a-z-]+)/.exec(readFileSync(`/proc/${pid}/cmdline`, "utf8"));
    return m ? m[1] : "browser";
  } catch { return "gone"; }
}

/// CPU seconds spent so far by Chromium's processes, by kind, and "all".
export function chromiumCpu(root = process.pid) {
  const by = {};
  for (const pid of descendants(root)) {
    try { const k = kind(pid); by[k] = (by[k] || 0) + stat(`/proc/${pid}/stat`).cpu / TICK; } catch { /* gone */ }
  }
  by.all = Object.values(by).reduce((sum, v) => sum + v, 0);
  return by;
}

/// Each thread of [pid]: its kernel name (Chromium's workers are all
/// "DedicatedWorker"; the main thread's tid is the pid) and its ticks.
export function threads(pid) {
  const by = {};
  for (const tid of readdirSync(`/proc/${pid}/task`)) {
    try {
      by[tid] = { comm: readFileSync(`/proc/${pid}/task/${tid}/comm`, "utf8").trim(),
        cpu: stat(`/proc/${pid}/task/${tid}/stat`).cpu };
    } catch { /* gone */ }
  }
  return by;
}

/// The page's renderer: of the browser's renderers, the one with workers
/// (the engine's threads are workers). 0 if there is none.
export function pageRenderer(root = process.pid) {
  let best = 0;
  let most = -1;
  for (const pid of descendants(root)) {
    if (kind(pid) !== "renderer") continue;
    try {
      const n = Object.values(threads(pid)).filter((t) => t.comm === "DedicatedWorker").length;
      if (n > most) { most = n; best = pid; }
    } catch { /* gone */ }
  }
  return best;
}

/// What a window of time is measured from: Chromium's processes by kind,
/// and the page's renderer thread by thread, in ticks.
export function snapshot(renderer, root = process.pid) {
  const procs = {};
  for (const pid of descendants(root)) {
    try { const k = kind(pid); procs[k] = (procs[k] || 0) + stat(`/proc/${pid}/stat`).cpu; } catch { /* gone */ }
  }
  let rows = {};
  try { rows = renderer ? threads(renderer) : {}; } catch { /* gone */ }
  return { at: Date.now(), procs, threads: rows };
}

/// Between two snapshots: each thread's and each kind of process's CPU, in
/// % of one core.
export function spent(a, b) {
  const s = (b.at - a.at) / 1000;
  const pct = (ticks) => Math.round(1000 * ticks / TICK / s) / 10;
  const threads = Object.entries(b.threads).map(([tid, t]) => ({
    tid: Number(tid), comm: t.comm, pct: pct(t.cpu - (a.threads[tid] ? a.threads[tid].cpu : 0)) }));
  const procs = Object.fromEntries(Object.entries(b.procs).map(([k, v]) => [k, pct(v - (a.procs[k] || 0))]));
  return { seconds: Math.round(s * 10) / 10, threads, procs };
}
