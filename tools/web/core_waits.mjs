// How long the browser's threads on a point's way waited for a core on this
// box, at any moment of a run: the second field of each thread's
// /proc/<pid>/task/<tid>/schedstat (time runnable but not running), read
// every 10 ms. On a box at load 36 a page's thread that has its bytes can
// wait its turn for a core, which a person's own device does not add, as
// tests/fixtures/insights/frame_check.mjs judges a frame by its thread's CPU
// rather than the clock (smalls7, 2026-11-19). Linux only; elsewhere every
// wait reads 0.
//
//   const waits = await coreWaits({ guest: page2, owner: page1 });
//   waits.waited("guest", from, to)   // ms the guest page's main thread waited
//   waits.waited("network", from, to) // ms the network service's threads did
//   waits.stop()
import { readdirSync, readFileSync } from "node:fs";

const read = (file) => { try { return readFileSync(file, "utf8"); } catch { return ""; } };
const fields = (pid, tid) => read(`/proc/${pid}/task/${tid}/schedstat`).split(" ").map(Number);
const tasks = (pid) => { try { return readdirSync(`/proc/${pid}/task`); } catch { return []; } };

// Every process under [root], by its command line.
function family(root) {
  const parent = new Map();
  for (const pid of readdirSync("/proc").filter((name) => /^\d+$/.test(name))) {
    const stat = read(`/proc/${pid}/stat`);
    const close = stat.lastIndexOf(")");
    if (close > 0) parent.set(pid, stat.slice(close + 2).split(" ")[1]);
  }
  const mine = new Set([String(root)]);
  for (let grew = true; grew;) {
    grew = false;
    for (const [pid, ppid] of parent) if (!mine.has(pid) && mine.has(ppid)) { mine.add(pid); grew = true; }
  }
  return [...mine].map((pid) => ({ pid, cmd: read(`/proc/${pid}/cmdline`).replaceAll("\0", " ") }));
}

// The renderer whose main thread ran while [page] spun for 400 ms.
async function rendererOf(page, renderers) {
  const ran = () => renderers.map((pid) => fields(pid, pid)[0] || 0);
  const before = ran();
  await page.evaluate(() => { const end = performance.now() + 400; while (performance.now() < end); });
  const after = ran();
  let best = null;
  let most = 0;
  renderers.forEach((pid, i) => {
    const gained = (after[i] - before[i]) / 1e6;
    if (gained > most) { most = gained; best = pid; }
  });
  return most > 200 ? best : null;
}

// The browsers this process started are under it.
export async function coreWaits(pages) {
  const none = { waited: () => 0, stop() {}, found: {} };
  if (process.platform !== "linux") return none;
  const root = process.pid;
  const all = family(root);
  const renderers = all.filter((one) => /--type=renderer/.test(one.cmd)).map((one) => one.pid);
  const network = all.filter((one) => /NetworkService/.test(one.cmd)).map((one) => one.pid);
  // Threads to follow, by name: a page's main thread, and every thread of
  // the network service (or of the browser itself, where it runs there).
  const follow = {};
  for (const [name, page] of Object.entries(pages)) {
    const pid = await rendererOf(page, renderers);
    if (pid) follow[name] = [[pid, pid]];
  }
  const netPids = network.length ? network : [String(root)];
  follow.network = netPids.flatMap((pid) => tasks(pid).map((tid) => [pid, tid]));
  const series = Object.fromEntries(Object.keys(follow).map((name) => [name, []]));
  const sample = () => {
    const at = Date.now();
    for (const [name, threads] of Object.entries(follow)) {
      let waited = 0;
      for (const [pid, tid] of threads) waited += fields(pid, tid)[1] || 0;
      series[name].push([at, waited / 1e6]);
    }
  };
  sample();
  const timer = setInterval(sample, 10);
  // A series' value at [t]: the last sample at or before it.
  const at = (list, t) => {
    let lo = 0;
    let hi = list.length - 1;
    if (hi < 0 || list[0][0] > t) return list[0]?.[1] ?? 0;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (list[mid][0] <= t) lo = mid; else hi = mid - 1;
    }
    return list[lo][1];
  };
  return {
    found: Object.fromEntries(Object.entries(follow).map(([name, threads]) => [name, threads.length])),
    waited(name, from, to) {
      const list = series[name];
      if (!list || !Number.isFinite(from) || !Number.isFinite(to) || to <= from) return 0;
      return Math.round(at(list, to) - at(list, from));
    },
    stop() { clearInterval(timer); },
  };
}
