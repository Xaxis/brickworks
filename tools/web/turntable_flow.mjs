// The model turns in its link's preview (unit turntable, docs/SOCIAL.md
// "The units, in waves", rank 2): Discord, Slack and X play a model's clip
// where they showed a still picture.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/turntable_flow.mjs --url=<a preview> --out=DIR
//
// Against a deployment's real functions, database and bucket, with
// throwaway accounts at Resend test addresses (sessions minted, no email
// sent), every model unpublished and every account deleted at the end:
//
//   1. A designer shares a model as the app does (the API). Its page is
//      today's picture card: og:image, a summary_large_image card, no
//      og:video; its embed with ?autoplay=1 is the picture.
//   2. Their first visit to its page (Chromium on SwiftShader, 1280, signed
//      in): within that visit <html data-clip> says made, timed, recorded
//      in a worker from version 1's own scene (data-clip-of).
//   3. /m/X.mp4 (or .webm where this browser cannot record MP4) at the
//      address its page names (?v=1&c=): two cold bytes=0- asks, the first
//      reaching the function and the next a 206 the CDN cut from its copy
//      (x-vercel-cache HIT); then 200, its type, at most 1.5 MB, 4 s or
//      less (api/_clip.js reads it), kept in DIR; decoded with ffmpeg, it
//      turns (half a turn on, it looks unlike its first frame) and loops
//      with no seam (its last frame is no further from its first than one
//      frame is from the next); Safari's bytes=0-1 a 206 HIT.
//   4. Fetched as Discordbot, Slackbot and Twitterbot, the page answers
//      with og:video (type, width, height, secure_url), X's
//      summary_large_image card with the player's tags beside it (its
//      twitter:player the embed with ?autoplay=1), and the clip with 200.
//   5. That embed in a blog's page plays the clip muted, looping, its time
//      going on; Pause stops it and Play starts it again; for a person who
//      asks for less motion it waits for Play. Pictures at 390, 768 and
//      1280, light and dark. Nothing refused by its policy.
//   6. Their second visit records nothing (data-clip kept). Republished
//      while the CDN still keeps version 1's unversioned scene, their next
//      visit records version 2 from version 2's own scene.
//   7. The clip's refusals: no session 401, somebody else's model 403, not
//      a video 415, longer than 4 s 415, larger than 1.5 MB 413, a version
//      that is not the newest 409, the newest's number with another
//      version's time 409.
//   8. Unpublished, its clip is gone from storage (asked with the secret
//      key) and the address its page named answers 404 past the CDN.
//
// Storage: the parts' geometry comes through this machine's mirror
// (browser.mjs); the clip is read from the bucket once a run.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, signInContext } from "./session.mjs";
import { readClip, MAX_CLIP_BYTES } from "../../api/_clip.js";
import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "").replace(/\/+$/, "").replace(/\/app$/, "");
if (!base) {
  console.error("turntable_flow: --url=<a deployment>");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/turntable"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(4).toString("hex");
const designer = `delivered+bw-turn-a-${rand}@resend.dev`;
const stranger = `delivered+bw-turn-b-${rand}@resend.dev`;
const FIXTURES = new URL("../../tests/fixtures/clip/", import.meta.url);
// The robots that read a link pasted into each, as they name themselves.
const ROBOTS = {
  Discordbot: "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)",
  Slackbot: "Slackbot-LinkExpanding 1.0 (+https://api.slack.com/robots)",
  Twitterbot: "Twitterbot/1.0",
};

// What <html data-clip> says when the designer's page is done with it.
const ENDED = /^(made|refused|failed|cannot|not-open|save-data|kept|slow|stale|tried)/;

let failures = 0;
let checks = 0;
const check = (ok, what) => {
  checks += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

let asked = 0;
/// [where] on the deployment, past the CDN unless [cached]: {status,
/// headers, text, bytes, json}.
async function call(where, { method = "GET", token = "", body, agent = "", cached = false, range = "" } = {}) {
  let url = where.startsWith("http") ? where : base + where;
  if (method === "GET" && !cached) url += `${url.includes("?") ? "&" : "?"}fresh=${Date.now().toString(36)}${(asked += 1).toString(36)}`;
  const headers = { ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}),
    ...(body !== undefined ? { "content-type": "application/json" } : {}), ...(agent ? { "user-agent": agent } : {}),
    ...(range ? { range } : {}) };
  const reply = await fetch(url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), redirect: "manual" });
  const bytes = Buffer.from(await reply.arrayBuffer());
  const text = bytes.toString("utf8");
  let json = null;
  try { json = JSON.parse(text); } catch { /* not JSON */ }
  return { status: reply.status, headers: reply.headers, text, bytes, json };
}

/// The <meta> tags of a page, by property or name: {name: content}.
function metas(html) {
  const found = {};
  for (const tag of html.match(/<meta\s[^>]*>/g) || []) {
    const key = /(?:property|name)="([^"]+)"/.exec(tag)?.[1];
    const value = /content="([^"]*)"/.exec(tag)?.[1];
    if (key && value !== undefined && !(key in found)) found[key] = value.replace(/&amp;/g, "&");
  }
  return found;
}

/// The names storage has for [id] in the clips' bucket, asked with the
/// secret key (a list: no file's bytes come with it).
async function stored(id) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/list/shared-clips`, { method: "POST",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
    body: JSON.stringify({ prefix: id, limit: 10, offset: 0 }) });
  return reply.ok ? (await reply.json()).map((file) => file.name) : [`(storage answered ${reply.status})`];
}

const MODEL = ["0 FILE main.ldr", "0 Turntable", "0 Name: main.ldr", "0 Author: Brickworks",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 14 20 -48 0 1 0 0 0 1 0 0 0 1 3003.dat", "1 2 -30 -48 10 0 0 1 0 1 0 -1 0 0 3004.dat",
  "1 15 0 -72 0 1 0 0 0 1 0 0 0 1 3062b.dat", "0 NOFILE", ""].join("\r\n");
const published = [];
const sessions = new Map();

/// A picture at [width] in [theme] of the embed with ?autoplay=1 in a
/// blog's page, as its code puts it there: {frame, page, context}.
async function blogWith(browser, embedAt, { width, height, theme, phone = false, still = false }) {
  // A preview's functions sit behind Vercel's login: the bypass goes with
  // every request the frame makes, as embed_flow sends it.
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme,
    reducedMotion: still ? "reduce" : "no-preference", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}),
    extraHTTPHeaders: bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {} });
  await context.route((url) => url.origin === "http://blog.test", (route) => route.fulfill({ contentType: "text/html; charset=utf-8",
    body: `<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="margin:16px;font-family:sans-serif;background:${theme === "dark" ? "#15181d;color:#eee" : "#f6f3ec"}">
      <h2>My new build</h2><p>It turns:</p>
      <iframe src="${embedAt}" width="560" height="420" style="border:0;max-width:100%" title="A Brickworks model" allowfullscreen></iframe>
      <p>More of the post.</p></body></html>` }));
  await context.addInitScript(() => {
    window.refused = [];
    document.addEventListener("securitypolicyviolation", (e) => window.refused.push(`${e.violatedDirective} ${e.blockedURI}`));
  });
  const page = await context.newPage();
  await page.goto("http://blog.test/post", { waitUntil: "load", timeout: 120000 });
  const element = await page.waitForSelector("iframe", { timeout: 60000 });
  let frame = null;
  for (let n = 0; n < 120 && !frame; n++) {
    frame = await element.contentFrame();
    if (!frame || !(await frame.$(".embed a.picture").catch(() => null))) { frame = null; await page.waitForTimeout(500); }
  }
  await frame.waitForFunction(() => document.readyState === "complete", null, { timeout: 120000 });
  return { frame, page, context };
}

async function main() {
  const a = await mintSession(designer);
  const b = await mintSession(stranger);
  sessions.set(designer, a);
  sessions.set(stranger, b);

  console.log("1. shared, with no clip yet");
  let r = await call("/api/share", { method: "POST", token: a.access_token, body: { name: "Turntable test", model: MODEL } });
  const id = r.json?.id || "";
  if (id) published.push(id);
  check(r.status === 201 && /^[A-Za-z0-9]{10}$/.test(id), `the designer shares a model: ${r.status} ${id}`);
  r = await call(`/m/${id}`, { agent: ROBOTS.Discordbot });
  let tags = metas(r.text);
  check(r.status === 200 && tags["twitter:card"] === "summary_large_image" && Boolean(tags["og:image"]) && !tags["og:video"],
    `its page is today's picture card: ${tags["twitter:card"]}, og:image, no og:video`);
  r = await call(`/m/${id}/embed?autoplay=1`);
  check(r.status === 200 && /<img src="\/(m\/\w+\.png|share\.png)"/.test(r.text) && !/<video/.test(r.text),
    "its embed with ?autoplay=1 is the picture, with no clip to play");

  console.log("2. the designer's first visit records it");
  const browser = await launch({ signedOut: true });
  try {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await signInContext(context, designer);
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    const sends = [];
    page.on("request", (one) => { if (/op=clip(&|$)/.test(one.url()) && one.method() === "POST") sends.push(one.url()); });
    const first = `${base}/m/${id}${bypass ? `?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true` : ""}`;
    const t0 = Date.now();
    await page.goto(first, { waitUntil: "load", timeout: 180000 });
    let how = "";
    for (let i = 0; i < 1200 && !ENDED.test(how); i++) {
      how = await page.evaluate(() => document.documentElement.dataset.clip || "").catch(() => "");
      if (!ENDED.test(how)) await page.waitForTimeout(500);
    }
    const took = (Date.now() - t0) / 1000;
    check(how === "made", `within the visit, its clip is recorded and kept: data-clip ${how || "(nothing)"} in ${took.toFixed(1)} s`);
    const drewOf = await page.evaluate(() => document.documentElement.dataset.clipOf || "").catch(() => "");
    check(drewOf === `m:${id}:1`, `it drew version 1's own scene: ${drewOf || "(none said)"}`);
    check(errors.length === 0, `no script errors on the page${errors.length ? `: ${errors[0]}` : ""}`);
    await page.screenshot({ path: path.join(out, "1_designer_page_1280.png") });

    console.log("3. its clip");
    r = await call(`/api/share?op=clip_need&id=${id}`, { token: a.access_token });
    const kind = r.json?.clip?.kind || "";
    check(r.status === 200 && r.json?.mine === true && r.json?.clip?.version === r.json?.version,
      `its row: a ${kind} of version ${r.json?.clip?.version}, the newest (${r.json?.version})`);
    // At its own address, as the page names it (og:video) and the CDN
    // keeps it: the bucket read once a run, not once a fetch.
    const named = metas((await call(`/m/${id}`)).text)["og:video"] || "";
    const clipAt = named ? new URL(named).pathname + new URL(named).search : `/m/${id}.${kind}?v=${r.json?.clip?.version}`;
    check(new RegExp(`^/m/${id}\\.${kind}\\?v=1&c=[0-9a-z]+$`).test(clipAt), `its page names it at its own address: ${clipAt}`);
    // Cold, as a browser plays it (Chrome and Firefox ask bytes=0- of
    // every <video>): the first from the function, the second from the
    // CDN, a 206 it cut from the copy it kept (ttreview F1: the function's
    // own 206 was kept by no CDN, and every play reached it).
    const ranged = [];
    for (let n = 0; n < 6; n++) {
      const one = await call(clipAt, { range: "bytes=0-", cached: true });
      ranged.push({ status: one.status, cache: one.headers.get("x-vercel-cache"), range: one.headers.get("content-range"),
        size: one.bytes.length });
      if (n > 0 && one.headers.get("x-vercel-cache") === "HIT") break;
      await new Promise((done) => setTimeout(done, 1000));
    }
    const [cold, warm] = [ranged[0], ranged[ranged.length - 1]];
    check(cold.cache !== "HIT" && (cold.status === 200 || cold.status === 206),
      `a cold bytes=0- reaches the function: ${cold.status} ${cold.cache}`);
    check(ranged.length > 1 && warm.cache === "HIT" && warm.status === 206 && warm.size === cold.size
      && warm.range === `bytes 0-${cold.size - 1}/${cold.size}`,
      `the next bytes=0- is the CDN's: ${warm.status} ${warm.cache} ${warm.range} (${ranged.length} asked)`);
    writeFileSync(path.join(out, "ranges.json"), JSON.stringify(ranged, null, 1));
    r = await call(clipAt, { cached: true });
    const facts = readClip(r.bytes);
    const file = path.join(out, `clip.${kind || "bin"}`);
    writeFileSync(file, r.bytes);
    check(r.status === 200 && r.headers.get("content-type") === (kind === "mp4" ? "video/mp4" : "video/webm"),
      `/m/${id}.${kind}: ${r.status} ${r.headers.get("content-type")}`);
    check(r.bytes.length > 0 && r.bytes.length <= MAX_CLIP_BYTES, `at most 1.5 MB: ${(r.bytes.length / 1024).toFixed(0)} KB`);
    check(!facts.error && facts.ms <= 4000, `4 s or less: ${facts.error || `${facts.ms} ms, ${facts.frames} frames, ${facts.width}x${facts.height} ${facts.codec}`}`);
    // Decoded small and grey, frame by frame.
    const W = 192;
    const H = 108;
    let raw = Buffer.alloc(0);
    try {
      raw = execFileSync("ffmpeg", ["-v", "error", "-i", file, "-vf", `scale=${W}:${H}`, "-pix_fmt", "gray", "-f", "rawvideo", "-"],
        { maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "pipe"] });
    } catch (trouble) {
      check(false, `ffmpeg decodes it: ${String(trouble.stderr || trouble.message).slice(0, 200)}`);
    }
    const n = Math.floor(raw.length / (W * H));
    const at = (k) => raw.subarray(k * W * H, (k + 1) * W * H);
    const apart = (p, q) => { let sum = 0; for (let k = 0; k < p.length; k++) sum += Math.abs(p[k] - q[k]); return sum / p.length; };
    if (n >= 8) {
      const steps = [];
      for (let k = 0; k + 1 < n; k++) steps.push(apart(at(k), at(k + 1)));
      const step = [...steps].sort((p, q) => p - q)[Math.floor(steps.length / 2)];
      const seam = apart(at(n - 1), at(0));
      const half = apart(at(Math.floor(n / 2)), at(0));
      check(half > step * 3, `it turns: half a turn on it is ${half.toFixed(2)} from its first frame, a frame ${step.toFixed(2)} from the next`);
      check(seam <= step * 1.5 + 0.5, `it loops with no seam: its last frame is ${seam.toFixed(2)} from its first, a frame ${step.toFixed(2)} from the next (${n} frames)`);
      writeFileSync(path.join(out, "loop.json"), JSON.stringify({ frames: n, step, seam, half, kind, bytes: r.bytes.length, facts, took }, null, 1));
    } else {
      check(false, `ffmpeg decodes its frames: ${n}`);
    }
    r = await call(clipAt, { range: "bytes=0-1", cached: true });
    check(r.status === 206 && r.bytes.length === 2 && /^bytes 0-1\//.test(r.headers.get("content-range") || "")
      && r.headers.get("x-vercel-cache") === "HIT",
      `a range of it, as Safari asks first, from the CDN: ${r.status} ${r.headers.get("content-range")} ${r.headers.get("x-vercel-cache")}`);

    console.log("4. as Discord, Slack and X read it");
    let player = "";
    let video = "";
    for (const [name, agent] of Object.entries(ROBOTS)) {
      r = await call(`/m/${id}`, { agent });
      tags = metas(r.text);
      // X's card stays the large picture (ttreview F5), the player's tags
      // beside it.
      const ok = r.status === 200 && /\/m\/\w{10}\.(mp4|webm)\?v=\d+&c=[0-9a-z]+$/.test(tags["og:video"] || "")
        && tags["og:video:secure_url"] === tags["og:video"] && /^https:/.test(tags["og:video:secure_url"] || "x")
        && tags["og:video:type"] === (kind === "mp4" ? "video/mp4" : "video/webm")
        && Number(tags["og:video:width"]) === facts.width && Number(tags["og:video:height"]) === facts.height
        && tags["twitter:card"] === "summary_large_image" && tags["twitter:player"] === `${base}/m/${id}/embed?autoplay=1`
        && Boolean(tags["og:image"]);
      check(ok, `${name}: og:video ${tags["og:video"]} (${tags["og:video:type"]}, ${tags["og:video:width"]}x${tags["og:video:height"]}), `
        + `secure_url, twitter:card ${tags["twitter:card"]}, twitter:player ${tags["twitter:player"]}`);
      const clip = await call(tags["og:video"] || `/m/${id}.${kind}`, { agent, cached: true });
      check(clip.status === 200 && clip.bytes.length > 0, `${name}: the clip ${clip.status}, ${clip.bytes.length} bytes`);
      player = tags["twitter:player"] || player;
      video = tags["og:video"] || video;
    }
    writeFileSync(path.join(out, "head.json"), JSON.stringify(tags, null, 1));

    console.log("5. the embed plays it");
    const sizes = [[390, 844, true], [768, 1024, false], [1280, 900, false]];
    for (const theme of ["light", "dark"]) {
      for (const [width, height, phone] of sizes) {
        const { frame, page: blog, context: c } = await blogWith(browser, player || `${base}/m/${id}/embed?autoplay=1`, { width, height, theme, phone });
        const played = await frame.waitForFunction(() => {
          const v = document.querySelector(".embed a.picture video");
          return v && !v.paused && v.currentTime > 0.5 ? { muted: v.muted, loop: v.loop, t: v.currentTime } : null;
        }, null, { timeout: 120000 }).then((h) => h.jsonValue()).catch(() => null);
        if (theme === "light" && width === 1280) {
          check(Boolean(played && played.muted && played.loop), `the embed plays it, muted and looping: ${JSON.stringify(played)}`);
          const later = await frame.waitForFunction(() => {
            const v = document.querySelector(".embed a.picture video");
            return v && (v.currentTime < 0.5 || v.currentTime > 3.2) ? v.currentTime : null;
          }, null, { timeout: 60000, polling: 50 }).then((h) => h.jsonValue()).catch(() => null);
          check(later !== null, `...its time going on round the loop: ${later}`);
          const toggle = await frame.$("[data-clip-toggle]");
          check(Boolean(toggle) && (await toggle.getAttribute("aria-label")) === "Pause", "Pause in its corner");
          await toggle.click();
          const paused = await frame.evaluate(() => document.querySelector(".embed a.picture video").paused);
          const label = await toggle.getAttribute("aria-label");
          check(paused && label === "Play", `Pause stops it, and the button says ${label}`);
          await toggle.click();
          await frame.waitForTimeout(400);
          check(!(await frame.evaluate(() => document.querySelector(".embed a.picture video").paused)), "Play starts it again");
        } else {
          check(Boolean(played), `${width} ${theme}: it plays`);
        }
        const refused = await frame.evaluate(() => window.refused);
        check(refused.length === 0, `${width} ${theme}: nothing refused by its policy${refused.length ? `: ${refused[0]}` : ""}`);
        await blog.screenshot({ path: path.join(out, `embed_${width}_${theme}.png`) });
        await c.close();
      }
    }
    const { frame: stillFrame, context: stillContext } = await blogWith(browser, player || `${base}/m/${id}/embed?autoplay=1`,
      { width: 1280, height: 900, theme: "light", still: true });
    await stillFrame.waitForTimeout(2500);
    const waits = await stillFrame.evaluate(() => {
      const v = document.querySelector(".embed a.picture video");
      return { paused: v ? v.paused : null, label: document.querySelector("[data-clip-toggle]")?.getAttribute("aria-label") };
    });
    check(waits.paused === true && waits.label === "Play", `for less motion it waits for Play: ${JSON.stringify(waits)}`);
    await stillContext.close();

    console.log("6. the designer's second visit");
    sends.length = 0;
    await page.reload({ waitUntil: "load", timeout: 180000 });
    let again = "";
    for (let i = 0; i < 120 && !again; i++) {
      again = await page.evaluate(() => document.documentElement.dataset.clip || "").catch(() => "");
      if (!again) await page.waitForTimeout(500);
    }
    check(again === "kept" && sends.length === 0, `records nothing: data-clip ${again}, ${sends.length} sent`);

    console.log("6b. republished within the CDN's minute, it records the new version's own scene");
    // ttreview F2: /m/X/scene.json, unversioned, is kept by the CDN 30 s
    // and 30 s more stale; a recorder that drew it stored version 1's model
    // as version 2's clip, and every later visit said kept.
    const warmed = await call(`/m/${id}/scene.json`, { cached: true });
    r = await call("/api/share", { method: "POST", token: a.access_token, body: { name: "Turntable test", id,
      model: MODEL.replace("0 NOFILE", "1 4 40 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 NOFILE") } });
    check(r.status === 200 && r.json?.version === 2, `republished: ${r.status} version ${r.json?.version}`);
    const stale = await call(`/m/${id}/scene.json`, { cached: true });
    const staleOf = stale.json?.of || "";
    sends.length = 0;
    await page.evaluate(() => { delete document.documentElement.dataset.clip; delete document.documentElement.dataset.clipOf; });
    await page.goto(`${base}/m/${id}?again=${rand}`, { waitUntil: "load", timeout: 180000 });
    how = "";
    for (let i = 0; i < 1200 && !ENDED.test(how); i++) {
      how = await page.evaluate(() => document.documentElement.dataset.clip || "").catch(() => "");
      if (!ENDED.test(how)) await page.waitForTimeout(500);
    }
    const drew = await page.evaluate(() => document.documentElement.dataset.clipOf || "").catch(() => "");
    const kept2 = (await call(`/api/share?op=clip_need&id=${id}`, { token: a.access_token })).json;
    check(how === "made" && drew === `m:${id}:2` && kept2?.clip?.version === 2 && sends.length === 1,
      `data-clip ${how}, drew ${drew || "(none said)"}, kept as version ${kept2?.clip?.version}, ${sends.length} sent `
      + `(the CDN's unversioned scene said ${staleOf || "nothing"}, warmed ${warmed.json?.of || warmed.status})`);
    await context.close();
  } finally {
    await browser.close();
  }

  console.log("7. what a clip is refused for");
  const fixture = (name) => readFileSync(new URL(name, FIXTURES)).toString("base64");
  const need = (await call(`/api/share?op=clip_need&id=${id}`, { token: a.access_token })).json || {};
  const newest = need.version || 1;
  const at = need.at || "";
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", body: { version: newest, at, clip: fixture("turn.webm") } });
  check(r.status === 401, `no session: ${r.status}`);
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: b.access_token, body: { version: newest, at, clip: fixture("turn.webm") } });
  check(r.status === 403, `somebody else's model: ${r.status}`);
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: a.access_token,
    body: { version: newest, at, clip: Buffer.from("not a video at all").toString("base64") } });
  check(r.status === 415, `not a video: ${r.status} ${r.json?.error}`);
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: a.access_token, body: { version: newest, at, clip: fixture("long.mp4") } });
  check(r.status === 415, `longer than 4 s: ${r.status} ${r.json?.error}`);
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: a.access_token,
    body: { version: newest, at, clip: randomBytes(1600 * 1024).toString("base64") } });
  check(r.status === 413, `larger than 1.5 MB: ${r.status} ${r.json?.error}`);
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: a.access_token, body: { version: newest + 1, at, clip: fixture("turn.webm") } });
  check(r.status === 409, `a version that is not the newest: ${r.status} ${r.json?.error}`);
  // ttreview F3: the newest number made at another time is another
  // version of it (a model published again after an unpublish).
  r = await call(`/api/share?op=clip&id=${id}`, { method: "POST", token: a.access_token,
    body: { version: newest, at: "2026-01-01T00:00:00+00:00", clip: fixture("turn.webm") } });
  check(r.status === 409, `the newest version's number with another version's time: ${r.status} ${r.json?.error}`);
  r = await call(`/api/share?op=clip_need&id=${id}`, { token: b.access_token });
  check(r.status === 200 && r.json?.mine === false && !("clip" in r.json), `somebody else asking what it needs is told only it is not theirs`);

  console.log("8. unpublished, its clip goes");
  // The address its page names now (version 2's clip, 6b).
  const latest = metas((await call(`/m/${id}`)).text)["og:video"] || "";
  const before = await stored(id);
  check(before.length === 1, `in storage while it is shared: ${before.join(", ")}`);
  r = await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: a.access_token });
  check(r.status === 200, `unpublished: ${r.status}`);
  published.splice(published.indexOf(id), 1);
  const after = await stored(id);
  check(after.length === 0, `its clip is gone from storage: ${after.join(", ") || "nothing left"}`);
  // Its own address, as the page named it, asked past the CDN (fresh=):
  // the function forgets it at once. The CDN's copy goes within its ten
  // minutes (CLIP_CACHE).
  const own = latest ? new URL(latest).pathname + new URL(latest).search : "";
  r = await call(own || `/m/${id}.webm`);
  check(Boolean(own) && r.status === 404, `its address answers 404: ${own} ${r.status}`);
}

async function cleanUp() {
  for (const id of published) {
    await call(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: sessions.get(designer)?.access_token }).catch(() => {});
  }
  const accounts = [...sessions.values()].map((one) => one.kept.user_id).filter(Boolean);
  if (accounts.length) {
    await fetch(`${SUPABASE}/rest/v1/act_log?who=in.(${accounts.join(",")})`, { method: "DELETE",
      headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } }).catch(() => {});
  }
  const gone = [await deleteAccount(designer).catch(() => false), await deleteAccount(stranger).catch(() => false)];
  console.log(`  (throwaway accounts ${gone.every(Boolean) ? "removed" : "not all found to remove"})`);
}

try {
  await main();
} catch (trouble) {
  failures += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  await cleanUp();
}
console.log(failures === 0 ? `a model's link turns in its preview (${checks} checks)` : `${failures} of ${checks} checks FAILED`);
process.exit(failures === 0 ? 0 : 1);
