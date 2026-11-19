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

// The renderer whose main thread ran more while [page] spun for 600 ms
// than in the 600 ms before it: every studio page runs its frames all the
// while, so a renderer is told by what the spin added, at least 100 ms and
// twice what any other gained (on a box at load 58 a thread spinning 600 ms
// runs about 200 of them).
async function rendererOf(page, renderers) {
  const ran = () => renderers.map((pid) => fields(pid, pid)[0] || 0);
  const first = ran();
  await new Promise((done) => setTimeout(done, 600));
  const second = ran();
  await page.evaluate(() => { const end = performance.now() + 600; while (performance.now() < end); });
  const third = ran();
  const added = renderers.map((pid, i) => [pid, ((third[i] - second[i]) - (second[i] - first[i])) / 1e6])
    .sort((x, y) => y[1] - x[1]);
  const [best, next] = added;
  return best && best[1] >= 100 && (!next || best[1] >= 2 * Math.max(0, next[1])) ? best[0] : null;
}

// The browsers this process started are under it.
export async function coreWaits(pages) {
  const none = { waited: () => 0, ran: () => 0, stop() {}, found: {}, renderers: 0 };
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
      let ran = 0;
      for (const [pid, tid] of threads) {
        const [on, off] = fields(pid, tid);
        ran += on || 0;
        waited += off || 0;
      }
      series[name].push([at, waited / 1e6, ran / 1e6]);
    }
  };
  sample();
  const timer = setInterval(sample, 10);
  // A series' value at [t] (field 1 waited, 2 ran): the last sample at or
  // before it.
  const at = (list, t, field = 1) => {
    let lo = 0;
    let hi = list.length - 1;
    if (hi < 0 || list[0][0] > t) return list[0]?.[field] ?? 0;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (list[mid][0] <= t) lo = mid; else hi = mid - 1;
    }
    return list[lo][field];
  };
  return {
    found: Object.fromEntries(Object.entries(follow).map(([name, threads]) => [name, threads.length])),
    renderers: renderers.length,
    waited(name, from, to) {
      const list = series[name];
      if (!list || !Number.isFinite(from) || !Number.isFinite(to) || to <= from) return 0;
      return Math.round(at(list, to) - at(list, from));
    },
    // And how long its threads ran on a core meanwhile.
    ran(name, from, to) {
      const list = series[name];
      if (!list || !Number.isFinite(from) || !Number.isFinite(to) || to <= from) return 0;
      return Math.round(at(list, to, 2) - at(list, from, 2));
    },
    stop() { clearInterval(timer); },
  };
}
