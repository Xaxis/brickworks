// The counter and the owner's Analytics (web/tally.js, web/counting.js,
// web/counting-ask.js, api/_analytics.js, web/admin-analytics.js;
// docs/ANALYTICS.md), in real browsers against a deployment. Never against
// brickworks.diy: a check is counted only as the checks' own (test), and
// none of this is a visitor's.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/insights_flow.mjs --url=<deployment> --out=shots/insights [--no-studio]
//
//   1. The gate: the owner's read answers 401 signed out and 404 to an
//      account that is not the owner's; the beacon's route answers a GET 405
//      and any POST 204, saying nothing back.
//   2. Nothing sent, nothing started: with Do Not Track, with Global Privacy
//      Control, after No, and in a driven browser that did not ask to be
//      counted, each after the counter loaded; the same page with the
//      check's own ask sends (so the first four mean something).
//   3. A visit counted: three site pages by a tagged link, each beacon read
//      as sent: a 16-letter visit, its source the link's, every name a row
//      may hold, and no address, IP address, typed word or page text in any.
//   4. The ask, on a European clock at 430x932: the card in German on /de,
//      its words and buttons in view, nothing sent before the answer; Yes,
//      and the beacon carries the yes. No elsewhere: kept, nothing sent.
//   5. Off in Settings › Privacy (signed in): the box unticked, said, and
//      nothing sent from that browser after.
//   6. The server's own drop: beacons posted with Sec-GPC and DNT kept
//      nowhere; a plain one kept.
//   7. The studio (not with --no-studio): /app signed in, a beacon of the
//      studio's with its view and the account's id (the server hashes it).
//   8. The rows (once supabase/analytics.sql is applied; before it the
//      section says so and this ends "insights: all ok (before the file)"):
//      the owner's read of the checks' own shows this run's tagged source
//      and pages, never the dropped beacons' sources, and no address or IP
//      address anywhere in it.
//   9. /admin › Analytics at 1280 and 390, light and dark: every tab drawn,
//      never wider than the window, a number's name lighting its
//      definition; no page error.
//
// Beacons' sizes and events are written to <out>/beacons.json for the
// doc's cost table. The throwaway stranger is deleted after. It passes
// when it ends "insights: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { nameKnown, namesKnown } from "../../api/_analytics.js";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("insights_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
if (/^https?:\/\/(www\.)?brickworks\.diy$/i.test(site)) {
  console.error("insights_flow: never on brickworks.diy (its visitors' counts are theirs); give a preview");
  process.exit(2);
}
const out = args.out || "shots/insights";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-insights-${who}-${rand}@resend.dev`;
const TAG = `flowcheck-${rand}`;
const NAME = /^[a-z0-9_:/#.-]{1,60}$/;
const IP = /\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){7}\b/i;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const shot = (page, name) => page.screenshot({ path: path.join(out, name), fullPage: false, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

let asked = 0;
async function api(pathname, { method = "GET", token, body, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: reply.status, json, text };
}

const visitId = () => randomBytes(12).toString("hex").replace(/[^a-z0-9]/g, "").slice(0, 16).padEnd(16, "a");
const browser = await launch({ signedOut: true });
const beacons = [];

/// A context as a visitor's: [zone] its clock, [counted] the check's own
/// ask to be counted, [said] this browser's kept choice, [dnt]/[gpc] the
/// browser's own, [who] signed in. Every beacon it sends is kept in
/// [sent], with its body as sent.
async function visitor({ zone = "America/New_York", counted = true, said = null, dnt = false, gpc = false, who = null,
  width = 1280, height = 900, theme = "light", label }) {
  const phone = width < 600;
  const extra = { ...headers, ...(dnt ? { dnt: "1" } : {}), ...(gpc ? { "sec-gpc": "1" } : {}) };
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme, timezoneId: zone,
    locale: zone.startsWith("Europe/") ? "de-DE" : "en-US", extraHTTPHeaders: extra,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await context.route(/\/theme-account\.js(?:\?.*)?$/, (route) => route.fulfill({ status: 200,
    contentType: "text/javascript", body: "export async function follow() {}" }));
  await context.addInitScript(([check, choice, noTrack, privacy, session, sessionKey]) => {
    try {
      if (noTrack) Object.defineProperty(Navigator.prototype, "doNotTrack", { get: () => "1", configurable: true });
      if (privacy) Object.defineProperty(Navigator.prototype, "globalPrivacyControl", { get: () => true, configurable: true });
      if (check) localStorage.setItem("brickworks.counting.check", "1");
      if (choice && !localStorage.getItem("brickworks.counting")) localStorage.setItem("brickworks.counting", choice);
      if (session && !localStorage.getItem(sessionKey)) {
        localStorage.setItem(sessionKey, session.kept);
        sessionStorage.setItem("brickworks.access", session.access);
      }
    } catch { /* a browser that keeps nothing */ }
  }, [counted, said, dnt, gpc, who ? { kept: JSON.stringify(who.kept),
    access: JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000, email: who.kept.email }) } : null, STORAGE_KEY]);
  const sent = [];
  const loaded = [];
  context.on("request", (request) => {
    const url = request.url();
    if (/\/api\/plans\?op=tally(?:&|$)/.test(url) && request.method() === "POST") {
      const body = request.postData() || "";
      sent.push(body);
      beacons.push({ label, bytes: Buffer.byteLength(body), body });
    }
    if (/\/tally\.js(?:\?|$)/.test(url)) loaded.push(url);
  });
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /SyntaxError|TypeError|ReferenceError|Content Security Policy/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  return { context, page, sent, loaded };
}
const go = (page, pathname) => page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
/// The page left as a tab is: what the counter holds goes by sendBeacon.
const leave = (page) => page.evaluate(() => {
  dispatchEvent(new Event("pagehide"));
}).catch(() => {});
const started = (page) => page.evaluate(() => Boolean(window.brickworksTallying)).catch(() => false);
const bodies = (sent) => sent.map((text) => {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
});

const made = [];
let owner = null;
let stranger = null;
let ready = false;
try {
  // --- 1. The gate -----------------------------------------------------------------------
  console.log("1. The gate");
  // Its age and the beta's welcome answered, so the studio is up for it.
  stranger = await mintSession(address("x"));
  made.push(address("x"));
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const signedOut = await api("/api/admin?op=analytics&tests=1");
  const other = await api("/api/admin?op=analytics&tests=1", { token: stranger.access_token });
  const mine = await api("/api/admin?op=analytics&tests=1", { token: owner.access_token });
  check(`the read: signed out ${signedOut.status}, a stranger ${other.status}, the owner ${mine.status}`,
    signedOut.status === 401 && other.status === 404 && mine.status === 200);
  ready = mine.json?.ready === true;
  console.log(`  --    supabase/analytics.sql ${ready ? "applied here" : "not applied here"}`);
  const get = await api("/api/plans?op=tally");
  const junk = await api("/api/plans?op=tally", { method: "POST", body: { v: "not a visit" } });
  check(`the beacon's route: GET ${get.status}, a junk POST ${junk.status} with nothing said back`,
    get.status === 405 && junk.status === 204 && junk.text === "");

  // --- 2. Nothing sent -------------------------------------------------------------------
  console.log("2. Nothing sent where nothing may be");
  for (const [label, how] of [["do not track", { dnt: true }], ["gpc", { gpc: true }], ["said no", { said: "no" }],
    ["driven, not asked", { counted: false }], ["the check's own ask", {}]]) {
    const one = await visitor({ ...how, label });
    await go(one.page, "/gallery");
    const came = await until(one.page, () => performance.getEntriesByType("resource").some((r) => /\/tally\.js/.test(r.name)),
      null, 30000);
    await wait(1500);
    const on = await started(one.page);
    await leave(one.page);
    await go(one.page, "/plans");
    await wait(2500);
    await leave(one.page);
    await wait(1500);
    if (label === "the check's own ask") {
      check(`${label}: the counter loaded (${came}), started (${on}), ${one.sent.length} beacons sent`, came && on && one.sent.length >= 1);
    } else {
      check(`${label}: the counter loaded (${came}) and did nothing: started ${on}, ${one.sent.length} beacons`,
        came && !on && one.sent.length === 0);
    }
    await one.context.close();
  }

  // --- 3. A visit counted ----------------------------------------------------------------
  console.log("3. A visit counted, each beacon read as sent");
  const counted = await visitor({ label: "visit" });
  await go(counted.page, `/gallery?utm_source=${TAG}&utm_medium=check&utm_campaign=insights`);
  // Each page left as a tab is hidden, while it is still there: a beacon
  // sent as a page unloads is not always seen by the browser's driver.
  for (const next of ["/plans", "/counting", null]) {
    await until(counted.page, () => Boolean(window.brickworksTallying), null, 30000);
    await leave(counted.page);
    await wait(1500);
    if (next) await go(counted.page, next);
  }
  await wait(1000);
  const read = bodies(counted.sent);
  check(`${read.length} beacons over three pages, each JSON`, read.length >= 2 && read.every(Boolean));
  const visits = new Set(read.map((b) => b?.v));
  check(`one visit, a 16-letter id: ${[...visits].join(", ")}`, visits.size === 1 && /^[a-z0-9]{16}$/.test([...visits][0] || ""));
  check(`its source the link's: ${read[0]?.about?.source}, ${read[0]?.about?.medium}, ${read[0]?.about?.campaign}`,
    read.every((b) => b?.about?.source === TAG && b?.about?.campaign === "insights"));
  const names = read.flatMap((b) => [...(b?.e || []).map((e) => e[2]), ...(b?.seen || [])]);
  const viewsSent = read.flatMap((b) => (b?.e || []).filter((e) => e[1] === "view").map((e) => e[2]));
  check(`the pages by template: ${[...new Set(viewsSent)].join(", ")}`, ["/gallery", "/plans", "/counting"].every((p) => viewsSent.includes(p)));
  check(`every name one a row may hold (${names.length})`, names.every((name) => NAME.test(String(name))));
  // And one the server keeps: a name the code has (api/_insights_names.js).
  // One it does not is a count the console never shows.
  const sets = await namesKnown();
  const unknown = (beacons) => beacons.flatMap((b) => [...(b?.e || []).filter((e) => !nameKnown(sets, e[0], e[1], e[2]))
    .map((e) => `${e[0]}:${e[1]}:${e[2]}`), ...(b?.seen || []).filter((n) => !nameKnown(sets, "studio", "press", n))]);
  const siteUnknown = unknown(read);
  check(`every name one the server keeps (${siteUnknown.length} not${siteUnknown.length ? `: ${siteUnknown.slice(0, 5).join(", ")}` : ""})`,
    siteUnknown.length === 0);
  // Every word a beacon carries is a name a row may hold (no capital, no
  // space, so no sentence of the page), its visit or the account's id; no @
  // and no IP address anywhere in it.
  const leaves = (value) => (value && typeof value === "object" ? Object.values(value).flatMap(leaves)
    : typeof value === "string" ? [value] : []);
  const odd = read.flatMap((b) => leaves(b).filter((word) => !NAME.test(word) && !/^[a-z0-9]{16}$/.test(word)));
  const leaks = counted.sent.filter((text) => /@/.test(text) || IP.test(text));
  check(`no address, IP address or page text in any beacon (${leaks.length + odd.length}${odd.length ? `: ${odd.slice(0, 3).map((w) => JSON.stringify(w.slice(0, 40))).join(", ")}` : ""})`,
    leaks.length === 0 && odd.length === 0);
  check("each marked the check's own (check: true)", read.every((b) => b?.check === true));
  await counted.context.close();

  // --- 4. The ask --------------------------------------------------------------------------
  console.log("4. The ask, on a European clock at 430x932");
  const asking = await visitor({ zone: "Europe/Berlin", width: 430, height: 932, label: "ask" });
  await go(asking.page, "/de/gallery");
  const card = await until(asking.page, () => document.querySelector(".count-ask.shown"), null, 30000);
  const words = card ? await asking.page.locator(".count-ask").innerText() : "";
  check(`the card, in German: "${words.replace(/\s+/g, " ").slice(0, 70)}…"`, /Darf Brickworks zählen/.test(words));
  const inView = await asking.page.evaluate(() => [...document.querySelectorAll(".count-ask p, .count-ask button")].every((one) => {
    const r = one.getBoundingClientRect();
    return r.width > 0 && r.top >= 0 && r.bottom <= innerHeight && r.left >= 0 && r.right <= innerWidth;
  }));
  check("its words and buttons in view", inView);
  await shot(asking.page, "ask_430_de.png");
  await wait(2000);
  check(`nothing sent before the answer (${asking.sent.length}), nothing started`, asking.sent.length === 0 && !(await started(asking.page)));
  await asking.page.locator(".count-ask").getByRole("button", { name: "Ja, zählen" }).click();
  check("Yes: the card gone, the counter started", await until(asking.page, () => !document.querySelector(".count-ask")
    && window.brickworksTallying === true, null, 15000));
  await leave(asking.page);
  await wait(2500);
  const yes = bodies(asking.sent);
  check(`the beacon carries the yes (${yes.length})`, yes.length >= 1 && yes.every((b) => b?.consent === true && b?.about?.lang === "de"));
  await asking.context.close();
  const declining = await visitor({ zone: "Europe/Paris", label: "ask no" });
  await go(declining.page, "/fr/gallery");
  await until(declining.page, () => document.querySelector(".count-ask.shown"), null, 30000);
  await declining.page.locator(".count-ask").getByRole("button", { name: "Non", exact: true }).click();
  await go(declining.page, "/fr/plans");
  await wait(2500);
  await leave(declining.page);
  await wait(1500);
  const kept = await declining.page.evaluate(() => localStorage.getItem("brickworks.counting"));
  check(`No: kept (${kept}), asked no more, nothing sent (${declining.sent.length})`, kept === "no" && declining.sent.length === 0
    && !(await declining.page.locator(".count-ask").count()));
  await declining.context.close();

  // --- 5. Off in Settings ------------------------------------------------------------------
  console.log("5. Off in Settings › Privacy");
  const settled = await visitor({ who: stranger, label: "settings" });
  await go(settled.page, "/settings#privacy-part");
  const box = settled.page.locator("#counting-on");
  const shown = await box.waitFor({ state: "visible", timeout: 60000 }).then(() => true, () => false);
  check(`the choice shown, ticked: ${shown && await box.isChecked()}`, shown && await box.isChecked());
  const before = settled.sent.length;
  if (shown) await box.click();
  const saidOff = await settled.page.locator("#counting-said").innerText().catch(() => "");
  check(`unticked, said: "${saidOff}"`, !(await box.isChecked()) && /Not counted/.test(saidOff));
  await go(settled.page, "/gallery");
  await wait(3000);
  await leave(settled.page);
  await wait(1500);
  check(`nothing sent after (${settled.sent.length - before} since)`, settled.sent.length === before);
  await settled.context.close();

  // --- 6. The server's own drop ------------------------------------------------------------
  console.log("6. The server drops what the browser asked not to send");
  const beacon = (source) => ({ v: visitId(), about: { landing: "/gallery", source, channel: "referral" },
    e: [["site", "view", "/gallery", 1, null, null]], seen: [], seconds: 5, check: true });
  const sends = [
    await api("/api/plans?op=tally", { method: "POST", body: beacon(`flowgpc-${rand}`), extra: { "sec-gpc": "1" } }),
    await api("/api/plans?op=tally", { method: "POST", body: beacon(`flowdnt-${rand}`), extra: { dnt: "1" } }),
    await api("/api/plans?op=tally", { method: "POST", body: beacon(`flowdirect-${rand}`) }),
  ];
  check(`each answered 204 and nothing more: ${sends.map((s) => s.status).join(", ")}`, sends.every((s) => s.status === 204 && !s.text));

  // --- 7. The studio -----------------------------------------------------------------------
  if (!args["no-studio"]) {
    console.log("7. The studio");
    const building = await visitor({ who: stranger, label: "studio" });
    await go(building.page, "/app");
    const came = await until(building.page, () => Boolean(window.brickworksTallying), null, 6 * 60 * 1000);
    const deadline = Date.now() + 60000;
    while (Date.now() < deadline && !bodies(building.sent).some((b) => b?.about?.studio === true)) await wait(1000);
    if (!bodies(building.sent).some((b) => b?.about?.studio === true)) await leave(building.page);
    await wait(2500);
    const told = bodies(building.sent).filter((b) => b?.about?.studio === true);
    const events = told.flatMap((b) => b.e || []);
    check(`the studio's counter started (${came}) and sent ${told.length}: ${events.slice(0, 6).map((e) => `${e[1]}:${e[2]}`).join(", ")}`,
      came && told.length >= 1 && events.some((e) => e[0] === "studio" && e[1] === "view" && e[2] === "/app"));
    // The server takes the account only from the sign-in's own token, which
    // it checks and lets go; a beacon's word for whose it is counts for nothing.
    check("the account told by its sign-in's token, never its id or its address",
      told.every((b) => b.bearer === stranger.access_token && b.who === undefined) && !building.sent.some((text) => text.includes("@")));
    const studioUnknown = unknown(told);
    check(`every studio name one the server keeps (${studioUnknown.length} not${studioUnknown.length ? `: ${studioUnknown.slice(0, 8).join(", ")}` : ""})`,
      studioUnknown.length === 0);
    await building.context.close();
  }

  // --- 8. The rows -------------------------------------------------------------------------
  const today = new Date().toISOString().slice(0, 10);
  if (!ready) {
    console.log("8. The rows: supabase/analytics.sql is not applied here, so nothing is kept yet");
  } else {
    console.log("8. The rows, in the owner's read of the checks' own");
    let answer = null;
    const deadline = Date.now() + 90000;
    while (Date.now() < deadline) {
      answer = await api(`/api/admin?op=analytics&tests=1&plan=all&from=${today}&to=${today}`, { token: owner.access_token });
      const sources = (answer.json?.sources?.sources || []).map((s) => s.source);
      if (sources.includes(TAG) && sources.includes(`flowdirect-${rand}`)) break;
      await wait(5000);
    }
    const sources = (answer?.json?.sources?.sources || []).map((s) => s.source);
    check(`this run's sources kept: ${TAG} ${sources.includes(TAG)}, flowdirect ${sources.includes(`flowdirect-${rand}`)}`,
      sources.includes(TAG) && sources.includes(`flowdirect-${rand}`));
    check("the dropped beacons' sources nowhere", !sources.includes(`flowgpc-${rand}`) && !sources.includes(`flowdnt-${rand}`));
    const pages = JSON.stringify(answer?.json?.pages || answer?.json?.used || {});
    check("its pages by template", ["/gallery", "/plans", "/counting"].every((p) => pages.includes(`"${p}"`)));
    const text = answer?.text || "";
    check(`no address or IP address in the read (${text.length} bytes)`, !/@/.test(text) && !IP.test(text)
      && !text.includes(stranger.kept.user_id));
  }

  // --- 9. The console ----------------------------------------------------------------------
  console.log("9. /admin › Analytics at 1280 and 390, light and dark");
  for (const width of [1280, 390]) {
    for (const theme of ["light", "dark"]) {
      const label = `admin ${width} ${theme}`;
      const one = await visitor({ who: owner, width, height: width < 600 ? 844 : 900, theme, counted: false, label });
      await go(one.page, "/admin?tests=1#analytics/overview");
      const up = await until(one.page, () => !document.querySelector('[data-section="analytics"]')?.hidden
        && (/\(UTC\)/.test(document.getElementById("an-said")?.textContent || "")
          || /not applied/.test(document.getElementById("an-not-yet")?.textContent || "")), null, 90000);
      const note = await one.page.locator("#an-not-yet").isVisible().catch(() => false);
      check(`${label}: the section up, ${ready ? "its numbers read" : "saying the file is not applied"}`, up && note === !ready);
      const drawn = [];
      for (const tab of ["overview", "funnels", "retention", "pages", "studio", "sources", "speed", "errors", "claude", "definitions"]) {
        await one.page.evaluate((to) => { location.hash = `analytics/${to}`; }, tab);
        await one.page.waitForTimeout(250);
        const state = await one.page.evaluate((to) => {
          const pane = document.querySelector(`[data-section="analytics"] [data-tab="${to}"]`);
          return { shown: Boolean(pane && !pane.hidden), sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 };
        }, tab);
        if (!state.shown || state.sideways) drawn.push(`${tab}${state.sideways ? " (wider than the window)" : " (not shown)"}`);
        if (tab === "overview" || tab === "studio") await shot(one.page, `admin_${width}_${theme}_${tab}.png`);
      }
      check(`${label}: every tab shown, none wider than the window${drawn.length ? `: ${drawn.join(", ")}` : ""}`, drawn.length === 0);
      if (ready && width === 1280 && theme === "light") {
        await one.page.evaluate(() => { location.hash = "analytics/overview"; });
        const term = one.page.locator('[data-section="analytics"] a.term').first();
        if (await term.count()) {
          await term.click();
          check("a number's name lights its definition", await until(one.page, () => document.querySelector("dt.lit")
            && location.hash === "#analytics/definitions", null, 10000));
        } else check("a number's name links to its definition", false);
      }
      await one.context.close();
    }
  }
} catch (trouble) {
  check(`ran through: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  for (const one of made) await deleteAccount(one).catch(() => {});
  await browser.close().catch(() => {});
}

const sizes = beacons.map((b) => b.bytes).sort((a, b) => a - b);
const rowsOf = (b) => {
  try {
    const json = JSON.parse(b.body);
    return (json.e || []).length + (json.seen || []).length;
  } catch {
    return 0;
  }
};
writeFileSync(path.join(out, "beacons.json"), `${JSON.stringify({ beacons: beacons.length,
  bytes: sizes.length ? { least: sizes[0], median: sizes[Math.floor(sizes.length / 2)], most: sizes.at(-1) } : null,
  rows: beacons.map(rowsOf), each: beacons.map((b) => ({ label: b.label, bytes: b.bytes, rows: rowsOf(b) })) }, null, 1)}\n`);
console.log(`  --    ${beacons.length} beacons, ${sizes.length ? `${sizes[0]}-${sizes.at(-1)} bytes, median ${sizes[Math.floor(sizes.length / 2)]}` : "none"}`);
check(`no page error (${errors.length})${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`, errors.length === 0);
console.log(`insights: ${passed} passed, ${failed} failed`);
console.log(failed ? "insights: FAIL" : `insights: all ok${ready ? "" : " (before the file)"}`);
process.exit(failed ? 1 : 0);
