// A car's parts fetched as fast as the page can, in a real browser (APP_UX7
// #6 fetchparts).
//
//   tools/export.sh web
//   node tools/web/play_flow.mjs --write-house=/tmp/house.mpd
//   tools/web/serve.py build/web 9821 --parts assets/generated/parts --delay 0 --compressed \
//       --share F3tchP4rts=vendor/omr/files/42022-1_Rally-Racer.mpd --share H0useFl0w=/tmp/house.mpd
//   node tools/web/fetchparts_flow.mjs --url=http://127.0.0.1:9821 --house=H0useFl0w --out=DIR
//
// And against the build before, ABBA: the same served from a second export
// (pre261's, say) on another port, --base=http://127.0.0.1:9822, --rounds=2
// (A B B A: the base, then this, then this, then the base, so a busy box
// weighs on both alike; the load said before each run).
//
// The car is LEGO's 42022 Rally Racer (vendor/omr/files, 382 parts): a real
// set, opened by its link (/m/<id>, serve.py --share) as a person opens one
// sent to them. Its parts are not the web build's own: of its 71 shapes 47
// come over the network as it opens (the car in models/, whose 26 are all in
// the pack the start waits for, fetches none). At each size:
//
//   laptop  1280 x 800 at 1x, broadband (20 Mbps down, 5 up, 40 ms)
//   phone   390 x 844 at 3x, touch, a phone's network (5 Mbps, 1 up, 100 ms)
//
// held by Chromium's own throttling from the first byte. The CPU is the
// box's: CDP's CPU throttle spins a thread for as long as the clock says,
// so a slowed frame grows with the box's load (play_flow.mjs), and the
// longest frame is judged as a person's here.
//
// With --house=<id>, each run opens playweb's house too (1484-1 with its
// motions, play_flow.mjs --write-house), the model the longest frame's bar
// was measured on: before playweb merged, the mean of its runs' longest task
// as the house opened was 506 ms on a laptop and 564 on a phone
// (bench/results/playweb-2026-11-07/final, A2 A3 A5 A8), with it 718 and
// 1,014. The car's frames are said beside the base's, not judged against
// those: on SwiftShader a frame of the whole car is SwiftShader drawing 374
// parts, 0.6 to 2 s at a load of 20 to 35 in any build (its trace: 90% of
// the page's thread in glCheckFramebufferStatus and the frame's blit).
//
// Judged, for this build:
//   1. Every part file the app asks for (a part's geometry .lbm, its exact
//      shape .bwx) is fetched by the page, none by the engine's HTTPRequest:
//      a fetch carrying the engine's own options (Godot's HTTPClient sends
//      its method and headers; the page's own fetch sends none), counted by
//      a wrapper on window.fetch put in before anything runs.
//   2. The car comes whole: every part here (brickworksState.awaited 0),
//      as many parts standing as the file has, nothing said lost.
//   3. The house's longest frame while it opens (the car's without
//      --house), from the first part file asked for until 3 s after every
//      part is here: the page's longest task (the browser's own
//      PerformanceObserver, the same for any build), the mean of the runs at
//      most --max-laptop (506) and --max-phone (564) ms, as playweb's were.
//   4. With --base: its shapes all in, the viewer's own phases from the
//      model's file in hand ("fetched") to every part here ("parts"), in
//      half the base's time or less, medians of each side's runs.
// Said, not judged: each run's network time for the part files (first asked
// to last answered, by the page's clock), the open's phases, and the base's
// counts. The engine's frames run as promise reactions, as load_check.mjs
// runs them, so a file the engine does not find costs what it costs a person
// rather than the inspector's 300 us (lazycompile).
//
// Pictures in --out: <side>_<size>_r<N>.png, the car once every part is
// here; each run's numbers in runs.jsonl.
import { launch } from "./browser.mjs";
import { appendFileSync, closeSync, mkdirSync, openSync, readFileSync, writeFileSync, writeSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9821").replace(/\/$/, "");
const base = args.base && args.base !== true ? String(args.base).replace(/\/$/, "") : "";
const out = String(args.out || "shots/fetchparts_web");
const id = String(args.id || "F3tchP4rts");
const house = args.house && args.house !== true ? String(args.house) : "";
const rounds = Number(args.rounds || (base ? 2 : 1));
const wanted = String(args.sizes || "laptop,phone").split(",");
// --trace=DIR: a Chrome trace of each run of this build (V8's sampled CPU
// profile of every thread, its GC, the page's tasks) to DIR/<size>_r<N>.json,
// its page clock found as load_check's is (tools/web/trace_window.py).
const traceDir = args.trace && args.trace !== true ? String(args.trace) : "";
if (traceDir) mkdirSync(traceDir, { recursive: true });
const TRACED = ["-*", "devtools.timeline", "disabled-by-default-devtools.timeline", "toplevel", "blink.user_timing",
  "blink.console", "v8", "v8.execute", "disabled-by-default-v8.cpu_profiler", "disabled-by-default-v8.gc", "gpu"];
const MAX = { laptop: Number(args["max-laptop"] || 506), phone: Number(args["max-phone"] || 564) };
const SIZES = {
  laptop: { shape: { viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 },
    net: { down: 20, up: 5, rtt: 40 }, said: "broadband" },
  phone: { shape: { viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true },
    net: { down: 5, up: 1, rtt: 100 }, said: "a phone's network" },
};
mkdirSync(out, { recursive: true });

let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);
const load = () => {
  try {
    return readFileSync("/proc/loadavg", "utf8").split(" ")[0];
  } catch {
    return "?";
  }
};
const median = (xs) => {
  const s = xs.filter((x) => Number.isFinite(x)).sort((a, b) => a - b);
  if (!s.length) return NaN;
  return s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2;
};

// In the page before anything of its own runs: who fetches each part file
// and when, the page's long tasks, and the viewer's phases by the page's
// clock as each is first seen in a frame.
function instrument() {
  const at = { files: [], longtasks: [], phases: {} };
  window.__fetchparts = at;
  console.timeStamp(`load_check zero ${performance.now()}`);
  const pageFetch = window.fetch.bind(window);
  window.fetch = function (input, init) {
    const url = String(input && input.url ? input.url : input);
    const kind = /\.(lbm|bwx)(\?|$)/.exec(url);
    if (!kind) return pageFetch(input, init);
    // Godot's HTTPClient (its library_godot_fetch.js) always passes the
    // method and its headers as pairs; the page's own fetch passes nothing.
    const engine = Boolean(init && typeof init.method === "string" && Array.isArray(init.headers));
    const one = { kind: kind[1], engine, asked: performance.now(), answered: 0, status: 0 };
    if (at.files.length < 5000) at.files.push(one);
    return pageFetch(input, init).then((answer) => {
      one.status = answer.status;
      one.answered = performance.now();
      return answer;
    });
  };
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) at.longtasks.push([e.startTime, e.duration]);
    }).observe({ type: "longtask", buffered: true });
  } catch {}
  const frame = window.requestAnimationFrame.bind(window);
  // The engine's frames as promise reactions (load_check.mjs, lazycompile).
  window.requestAnimationFrame = (callback) => frame((time) => {
    Promise.resolve(time).then(callback).catch((e) => setTimeout(() => { throw e; }));
  });
  const tick = () => {
    const opened = (window.brickworksShare || {}).opened || {};
    for (const phase of Object.keys(opened)) if (!(phase in at.phases)) at.phases[phase] = performance.now();
    frame(tick);
  };
  frame(tick);
}

async function until(page, test, what, seconds, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(250);
  }
}

// How many parts the link's model stands, its sub-models' parts counted as
// often as each is used: what the viewer stands as bricks.
async function served(origin, id) {
  const body = await fetch(`${origin}/api/share?id=${id}`).then((r) => r.json());
  const files = new Map();
  let first = "";
  let lines = null;
  for (const line of String(body.model || "").split(/\r?\n/)) {
    const named = /^\s*0\s+FILE\s+(.+?)\s*$/i.exec(line);
    if (named) {
      lines = [];
      files.set(named[1].toLowerCase(), lines);
      first ||= named[1].toLowerCase();
      continue;
    }
    const part = /^\s*1(?:\s+\S+){13}\s+(.+?)\s*$/.exec(line);
    if (part) (lines || (files.set("", lines = []), lines)).push(part[1].toLowerCase());
  }
  const count = (name, depth) => (files.get(name) || []).reduce((n, used) =>
    n + (files.has(used) && depth < 20 ? count(used, depth + 1) : 1), 0);
  return count(first, 0);
}

globalThis.carId = id;
const browser = await launch({ signedOut: true });
const runs = [];

async function run(side, origin, size, round, model = "car") {
  const id = model === "house" ? house : globalThis.carId;
  const { shape, net, said } = SIZES[size];
  const context = await browser.newContext(shape);
  await context.addInitScript(instrument);
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
  });
  const cdp = await context.newCDPSession(page);
  await cdp.send("Network.enable");
  await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: net.rtt,
    downloadThroughput: (net.down * 1e6) / 8, uploadThroughput: (net.up * 1e6) / 8 });
  const tracing = traceDir && side === "this" && model === "car";
  if (tracing) {
    await cdp.send("Tracing.start", { transferMode: "ReturnAsStream", streamFormat: "json",
      traceConfig: { recordMode: "recordAsMuchAsPossible", includedCategories: TRACED } });
  }
  const loadAt = load();
  console.log(`\n${side} ${size} r${round} ${model}, ${said}, load ${loadAt}: ${origin}/m/${id}`);
  const began = Date.now();
  await page.goto(`${origin}/m/${id}`, { waitUntil: "domcontentloaded", timeout: 300000 });
  const line = { side, size, round, model, load: Number(loadAt) };
  try {
    await until(page, () => ((window.brickworksShare || {}).opened || {}).parts !== undefined, "every part here", 900);
    // 3 s more, as the frames after every part came are its opening too.
    await page.waitForTimeout(3000);
    await until(page, () => (window.brickworksState || {}).awaited === 0, "nothing awaited", 60);
    const seen = await page.evaluate(() => ({ at: window.__fetchparts, share: window.brickworksShare || {},
      state: window.brickworksState || {}, later: window.brickworksLater || {} }));
    const files = seen.at.files;
    const lbm = files.filter((f) => f.kind === "lbm");
    const first = files.length ? Math.min(...files.map((f) => f.asked)) : NaN;
    const partsSeen = Number(seen.at.phases.parts);
    const answered = files.map((f) => f.answered).filter((t) => t > 0);
    const phases = seen.share.opened || {};
    const windowEnd = partsSeen + 3000;
    const long = seen.at.longtasks.filter(([start, ms]) => start + ms >= first && start <= windowEnd);
    const longest = long.reduce((a, b) => (b[1] > a[1] ? b : a), [0, 0]);
    Object.assign(line, {
      engine_lbm: lbm.filter((f) => f.engine).length,
      engine_bwx: files.filter((f) => f.kind === "bwx" && f.engine).length,
      page_lbm: lbm.filter((f) => !f.engine).length,
      page_bwx: files.filter((f) => f.kind === "bwx" && !f.engine).length,
      failed_files: files.filter((f) => f.answered && f.status !== 200).length,
      shapes_ms: Number(phases.parts) - Number(phases.fetched),
      parts_ms: Number(phases.parts), drawn_ms: Number(phases.drawn), fetched_ms: Number(phases.fetched),
      net_ms: answered.length ? Math.round(Math.max(...answered) - first) : NaN,
      longest_ms: Math.round(longest[1]), longest_at: Math.round(longest[0] - first),
      long_tasks: long.length, in_app_longest: phases.longest || null,
      bricks: Number(seen.state.bricks), awaited: Number(seen.state.awaited), lines: await served(origin, id),
      said: String(seen.state.said || ""), wall_s: Math.round((Date.now() - began) / 100) / 10, errors,
      // By the page's clock from the first part file asked: each file
      // [kind, by the engine, asked, answered], each long task [start, ms],
      // and when each of the viewer's phases was first seen in a frame.
      detail: {
        first_at: Math.round(first),
        files: files.map((f) => [f.kind, f.engine ? 1 : 0, Math.round(f.asked - first), f.answered ? Math.round(f.answered - first) : -1]),
        long: seen.at.longtasks.map(([start, ms]) => [Math.round(start - first), Math.round(ms)]),
        seen: Object.fromEntries(Object.entries(seen.at.phases).map(([k, t]) => [k, Math.round(t - first)])),
        later: Object.fromEntries(["asked", "came", "written"].map((k) => [k, seen.later[k] ? Math.round(seen.later[k] - first) : null])),
        phases,
      },
    });
  } catch (trouble) {
    line.trouble = String(trouble.message || trouble).slice(0, 300);
    line.errors = errors;
  }
  if (tracing) {
    const file = path.join(traceDir, `${size}_r${round}.json`);
    const complete = new Promise((resolve) => cdp.once("Tracing.tracingComplete", resolve));
    await cdp.send("Tracing.end");
    const { stream } = await complete;
    const fd = openSync(file, "w");
    for (;;) {
      const { data, eof, base64Encoded } = await cdp.send("IO.read", { handle: stream, size: 1 << 22 });
      if (data) writeSync(fd, base64Encoded ? Buffer.from(data, "base64") : data);
      if (eof) break;
    }
    closeSync(fd);
    await cdp.send("IO.close", { handle: stream }).catch(() => {});
    writeFileSync(file.replace(/\.json$/, ".marks.json"), JSON.stringify({ label: `${size} r${round}`, marks: {} }));
    console.log(`        trace: ${file}`);
  }
  const picture = path.join(out, `${side}_${size}_r${round}${model === "car" ? "" : `_${model}`}.png`);
  await page.screenshot({ path: picture, timeout: 180000 })
    .then(() => console.log(`        picture: ${picture}`))
    .catch((trouble) => say(`no picture: ${String(trouble).split("\n")[0]}`));
  await context.close();
  appendFileSync(path.join(out, "runs.jsonl"), JSON.stringify(line) + "\n");
  if (line.trouble) {
    check(`${side} ${size}: the ${model} opened (${line.trouble})`, false);
  } else {
    say(`part files: ${line.page_lbm} geometry and ${line.page_bwx} exact shapes by the page, `
      + `${line.engine_lbm} and ${line.engine_bwx} by the engine's HTTPRequest; ${line.failed_files} not 200`);
    say(`its shapes all in ${line.shapes_ms} ms after its file was in hand (fetched ${line.fetched_ms}, `
      + `drawn ${line.drawn_ms}, every part ${line.parts_ms} ms in the viewer's phases); the part files' network `
      + `${line.net_ms} ms; the longest frame ${line.longest_ms} ms at ${line.longest_at} ms of ${line.long_tasks} `
      + `long tasks (in the app's own words ${JSON.stringify(line.in_app_longest)}); ${line.wall_s} s in all`);
  }
  runs.push(line);
  return line;
}

try {
  for (let round = 1; round <= rounds; round += 1) {
    const sides = base ? (round % 2 ? [["base", base], ["this", site]] : [["this", site], ["base", base]])
      : [["this", site]];
    for (const [side, origin] of sides) {
      for (const size of wanted) {
        await run(side, origin, size, round);
        if (house) await run(side, origin, size, round, "house");
      }
    }
  }
} finally {
  await browser.close();
}

console.log("\nfetchparts: judged");
const mean = (xs) => Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);
for (const size of wanted) {
  const of = (side, model) => runs.filter((r) => r.side === side && r.size === size && r.model === model && !r.trouble);
  const mine = of("this", "car");
  const theirs = of("base", "car");
  const all = runs.filter((r) => r.side === "this" && r.size === size);
  const homes = of("this", "house");
  const framed = house ? homes : mine;
  const framedBase = house ? of("base", "house") : theirs;
  check(`${size}: every model opened in every run (${mine.length + homes.length} of ${all.length})`,
    mine.length + homes.length === all.length && mine.length > 0);
  if (!mine.length) continue;
  const both = [...mine, ...homes];
  check(`${size}: no part file by the engine's HTTPRequest: ${both.map((r) => r.engine_lbm + r.engine_bwx).join(", ")} `
    + `(the page fetched ${both.map((r) => `${r.page_lbm} + ${r.page_bwx}`).join(", ")})`,
    both.every((r) => r.engine_lbm + r.engine_bwx === 0) && mine.every((r) => r.page_lbm > 0));
  check(`${size}: whole: ${both.map((r) => `the ${r.model} ${r.bricks} of ${r.lines} standing, ${r.awaited} awaited`).join("; ")}`,
    both.every((r) => r.awaited === 0 && r.bricks === r.lines && r.failed_files === 0 && !/could not be loaded/.test(r.said)));
  if (framed.length) {
    check(`${size}: the ${house ? "house's" : "car's"} longest frame while it opens, the mean of its runs, at most ${MAX[size]} ms: `
      + `${mean(framed.map((r) => r.longest_ms))} (${framed.map((r) => r.longest_ms).join(", ")})`
      + (framedBase.length ? `; the base's ${mean(framedBase.map((r) => r.longest_ms))} (${framedBase.map((r) => r.longest_ms).join(", ")})` : ""),
      mean(framed.map((r) => r.longest_ms)) <= MAX[size]);
  }
  if (house) {
    say(`${size}: the car's longest frame ${mean(mine.map((r) => r.longest_ms))} (${mine.map((r) => r.longest_ms).join(", ")})`
      + (theirs.length ? `; the base's ${mean(theirs.map((r) => r.longest_ms))} (${theirs.map((r) => r.longest_ms).join(", ")})` : ""));
  }
  if (theirs.length) {
    const a = median(theirs.map((r) => r.shapes_ms));
    const b = median(mine.map((r) => r.shapes_ms));
    say(`${size}: the base's part files by the engine ${theirs.map((r) => r.engine_lbm + r.engine_bwx).join(", ")}, `
      + `by the page ${theirs.map((r) => r.page_lbm + r.page_bwx).join(", ")}; loads ${runs.filter((r) => r.size === size)
        .map((r) => `${r.side} ${r.model} ${r.load}`).join(", ")}`);
    check(`${size}: its shapes all in within half the base's time: ${b} ms against ${a} (${(b / a).toFixed(2)}x; `
      + `this ${mine.map((r) => r.shapes_ms).join(", ")}, the base ${theirs.map((r) => r.shapes_ms).join(", ")})`,
      Number.isFinite(a) && Number.isFinite(b) && b <= a / 2);
  }
}
console.log(failed ? `\nfetchparts: ${failed} FAILED` : "\nfetchparts: ok");
process.exit(failed ? 1 : 0);
