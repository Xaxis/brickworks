// A stranger's Open in Brickworks (firstminute, 2026-11-23; docs/MASTERPLAN.md
// row 11, "Open → change, for a stranger"), in a real browser, timed:
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/firstminute_flow.mjs --url=<deployment> --out=DIR
//   node tools/web/firstminute_flow.mjs --url=http://127.0.0.1:11520 --out=DIR   (relay_server --static)
//
// From a gallery model's page (/m/<id>), Open in Brickworks, signed out, as
// a stranger comes: what the studio shows behind its sign-in, the way in,
// and what is on the baseplate once they are in, at 1280 × 800 and at
// 390 × 844 by finger. Each way in with a throwaway address of its own
// (delivered+bw-firstminute-…@resend.dev, deleted after), the code minted
// with the admin API and typed as a person types the one emailed:
//
//   site       the press on the model's page: the site asks at once, over
//              the page (web/follow.js, sitewalk3: the studio had loaded
//              for 23 to 31 s to ask the same), and signed in there the
//              studio opens with the copy
//
// The other ways come by the studio's own link (/app?copy=…, as from a new
// tab or another site), to its own sign-in:
//
//   code       a new account by the studio's own sign-in: the code, the age
//              question, the beta's welcome (Not now), as a stranger meets them
//   returning  an account made before (password grant), by the code
//   reload     a new account, the page reloaded with the code typed and the
//              age question up
//   profile    the studio's own sign-in screen sends them to the site
//              (/profile?then=/app?copy=…&with=orangecheck, as its orangecheck
//              button does); signed in there by email, since orangecheck
//              finishes only on brickworks.diy, and back to the studio
//   tab2       signed in on the model's page in a second tab while the first
//              waits behind the sign-in screen, then back to the first
//
// Then, for each: the asked-for model on the baseplate (its name, credited
// to the model it came from), never the example car at any moment after the
// sign-in, framed, the three first acts offered (Recolour a part, Add a
// part, Build it), a change made and saved, timed from the press of Open in
// Brickworks (the bar: 180 s). Once per size the copy reloaded and opened
// again in a second tab: no second copy. And the acts gone after the edit
// and after Escape, and not offered to that account again.
//
// Pictures: <size>-<way>-<n>-<what>.png in --out; results in results.json.
// --ways=code,returning (default all), --sizes=1280,390, --id=<model id>
// (default: the gallery's first model under 400 parts), --before (an older
// build: the acts are not looked for, only recorded).
import { clickStill, launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = new URL(String(args.url || "http://127.0.0.1:11520")).origin;
const out = path.resolve(String(args.out || "shots/firstminute"));
const bypass = process.env.BW_BYPASS || "";
const SIZES = String(args.sizes || "1280,390").split(",").map(Number).filter(Boolean);
const WAYS = String(args.ways || "site,code,returning,reload,profile,tab2").split(",").filter(Boolean);
const before = Boolean(args.before);
const BAR_S = 180;
const SAMPLE = "Car";
mkdirSync(out, { recursive: true });

const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
let failed = 0;
const results = [];
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const rand = randomBytes(3).toString("hex");
const made = [];
const address = (tag) => `delivered+bw-firstminute-${tag}-${rand}@resend.dev`;

async function api(pathname) {
  const reply = await fetch(`${site}${pathname}`, { headers });
  return reply.ok ? reply.json().catch(() => ({})) : {};
}

// The model: one of the gallery's, small enough for a phone and a quick copy.
let id = String(args.id || "");
let modelName = "";
if (!id) {
  const listed = await api("/api/share?op=list&page=1");
  const pick = (listed.models || []).find((m) => m && m.id && Number(m.parts || 0) > 0 && Number(m.parts) <= 400)
    || (listed.models || [])[0];
  id = pick?.id || "";
  modelName = pick?.name || "";
}
if (!id) {
  console.log("no gallery model to open");
  process.exit(1);
}
if (!modelName) modelName = (await api(`/api/share?id=${id}`)).name || "";
console.log(`firstminute flow: ${site}, /m/${id} "${modelName}", ways ${WAYS.join(",")}, sizes ${SIZES.join(",")}${before ? " (before)" : ""}`);

const browser = await launch({ signedOut: true });

async function contextAt(width) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 800 },
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  // A code is "sent" here: the flow types the one it mints, as a person types
  // the one emailed, and no mail goes anywhere.
  await context.route("**/api/otp", (route) => route.fulfill({ status: 200, contentType: "application/json",
    body: JSON.stringify({ ok: true, expires_in_minutes: 10 }) }));
  // Every file the studio writes, kept across reloads and tabs of this
  // context: a copy saved twice is two files of the model's name.
  await context.addInitScript(() => {
    let inner;
    Object.defineProperty(window, "brickworksWrote", {
      configurable: true,
      get() {
        return inner ? (p, s) => {
          try {
            const kept = JSON.parse(localStorage.getItem("fm.writes") || "[]");
            kept.push(String(p));
            localStorage.setItem("fm.writes", JSON.stringify(kept.slice(-400)));
          } catch {}
          return inner(p, s);
        } : undefined;
      },
      set(v) { inner = v; },
    });
  });
  return { context, phone };
}

const look = (page) => page.evaluate(() => ({
  account: window.brickworksAccount || {}, share: window.brickworksShare || {},
  bricks: (window.brickworksState || {}).bricks, history: (window.brickworksState || {}).history,
  selected: (window.brickworksState || {}).selected, colours: (window.brickworksState || {}).selected_colours,
  said: (window.brickworksState || {}).said, url: location.pathname + location.search,
  writes: (() => { try { return JSON.parse(localStorage.getItem("fm.writes") || "[]"); } catch { return []; } })(),
})).catch(() => ({ account: {}, share: {}, writes: [] }));

async function until(page, test, seconds, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) return null;
    await page.waitForTimeout(400);
  }
}

function presser(page, phone) {
  const act = phone ? (at) => page.touchscreen.tap(at.x, at.y) : (at) => page.mouse.click(at.x, at.y);
  return (name, seconds = 60, optional = false) => clickStill(page, name, { seconds, optional, act, after: 400 });
}

async function typeInto(page, press, name, text) {
  await press(name);
  await page.keyboard.press("Control+A").catch(() => {});
  await page.keyboard.type(text, { delay: 25 });
}

// The studio's own sign-in: the address, Email me a code, the code typed.
async function codeInStudio(page, press, email) {
  await typeInto(page, press, "signin_email", email);
  await press("signin_send");
  await clickStill(page, "signin_code", { seconds: 60, act: () => Promise.resolve(), optional: true });
  const code = await mintCode(email, { welcome: false });
  await typeInto(page, press, "signin_code", code);
  // Goes by itself once full; Sign in pressed if it is still there.
  await page.waitForTimeout(1500);
  await press("signin_go", 3, true);
}

// When the deployment last said who this is to the studio (GET
// /api/account with its token: Account._ask_who), since the page last
// loaded. The age question and the beta's welcome come from that answer,
// so they can follow the studio saying it is signed in and ungated: a
// sign-in heard from another tab lets it in at once and asks who after
// (tab2, nightly 2026-11-24: the age question came over the copy after
// answerStudio had returned, and no change could be made).
const whoHeard = new WeakMap();
function hearWho(page) {
  if (whoHeard.has(page)) return;
  whoHeard.set(page, 0);
  // A new document asked for (a load, a reload), not a change of address
  // within one: the studio writes its own address as it goes.
  page.on("request", (asked) => {
    if (asked.isNavigationRequest() && asked.frame() === page.mainFrame()) whoHeard.set(page, 0);
  });
  page.on("requestfinished", async (asked) => {
    const at = new URL(asked.url());
    if (at.pathname !== "/api/account" || at.search || asked.method() !== "GET") return;
    const told = await asked.allHeaders().catch(() => ({}));
    if (/^Bearer /.test(told.authorization || "")) whoHeard.set(page, Date.now());
  });
}

// [n] of the studio's tellings to the page (a new window.brickworksAccount
// each), or 5 s for each that does not come.
async function tellings(page, n) {
  for (let k = 0; k < n; k++) {
    await page.evaluate(() => { window.fmToldBefore = window.brickworksAccount; }).catch(() => {});
    await page.waitForFunction(() => window.brickworksAccount !== window.fmToldBefore, null, { timeout: 5000, polling: 100 })
      .catch(() => {});
  }
}

// The age question and the beta's welcome, in the studio, as a stranger
// answers them: born in 1990, and Not now. Answered once the studio is in,
// ungated and asks nothing, three tellings after it heard who this is.
async function answerStudio(page, press) {
  hearWho(page);
  const end = Date.now() + 120000;
  while (Date.now() < end) {
    const s = await look(page);
    const named = await page.evaluate(() => window.brickworksControls || {}).catch(() => ({}));
    const asks = named.age_go || named.beta_not_now || named.beta_start;
    if (s.account.state === "signed_in" && !s.account.gated && !asks && whoHeard.get(page)) {
      const heard = whoHeard.get(page);
      await tellings(page, 3);
      const after = await look(page);
      if (after.account.state === "signed_in" && !after.account.gated && whoHeard.get(page) === heard) return true;
      continue;
    }
    if (named.age_go) {
      // Read again if it goes before it is answered, as a person answers
      // what is shown: at 1280 after a reload mid-check (the code still
      // Checking at 60 s) the question was told once and then the beta's
      // welcome stood there instead, and a press that waited a minute for
      // the month failed the way (nightreds unit preview, 2026-11-24).
      // Never answerable, the loop still ends unanswered at two minutes.
      if (!await press("age_month_3", 10, true)) {
        console.log("  --    the age question went before it was answered; read again");
        continue;
      }
      await typeInto(page, press, "age_year", "1990");
      await press("age_go");
    } else if (named.beta_not_now || named.beta_start) {
      // The same for the beta's welcome: at 390 back from the site's sign-in
      // it was told once and then gone, the studio signed in and let in
      // (nightreds unit preview 2, 2026-11-24).
      const name = named.beta_not_now ? "beta_not_now" : "beta_start";
      if (!await press(name, 10, true)) console.log(`  --    ${name} went before it was pressed; read again`);
    }
    await page.waitForTimeout(800);
  }
  return false;
}

// The site's sign-in dialog, by email, and whatever a new account is asked
// after it there (the age question, the beta's welcome, First steps).
// [leaves]: the press goes on from the model's page once all that is
// answered (the site way), so a moment with no dialog between the sign-in's
// and the age question's is not the end: done only when the page has left
// /m/ (its first unit preview, 2026-11-26, read that moment as done and
// left the age question open over the page for 60 s).
async function codeOnSite(page, email, { leaves = false } = {}) {
  await page.locator("dialog.sign-in[open]").waitFor({ state: "visible", timeout: 30000 });
  await page.fill("dialog.sign-in input[type=email], dialog.sign-in input", email);
  await page.click('dialog.sign-in button[type="submit"]');
  await page.waitForFunction(() => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, { timeout: 30000 });
  const code = await mintCode(email, { welcome: false });
  await page.fill("dialog.sign-in .code-boxes input:first-child", code);
  const end = Date.now() + 90000;
  while (Date.now() < end) {
    if (!page.url().includes("/profile") && !page.url().includes("/m/")) return true;
    const open = await page.evaluate(() => (document.querySelector("dialog.age[open]") ? "age"
      : document.querySelector("dialog.beta-welcome[open]") ? "welcome"
        : document.querySelector("dialog.first-steps[open]") ? "steps"
          : document.querySelector("dialog.sign-in[open]") ? "signin" : "")).catch(() => "");
    if (open === "age") {
      await page.selectOption("#age-month", { index: 3 }).catch(() => {});
      await page.selectOption("#age-year", "1990").catch(() => {});
      await page.click("#age-go").catch(() => {});
    } else if (open === "welcome") {
      await page.click("#beta-not-now").catch(() => {});
    } else if (open === "steps") {
      // Skipped to the end, as a person in a hurry to get back does.
      const skip = page.locator("dialog.first-steps[open] button", { hasText: /Skip|Not now|Done|Close|Back to/i }).last();
      await skip.click().catch(() => page.keyboard.press("Escape"));
    } else if (!open && page.url().includes("/m/") && !leaves) {
      return true;
    }
    await page.waitForTimeout(700);
  }
  return false;
}

// The first moment after the sign-in that the baseplate holds the asked-for
// model, watching every look in between for the example car.
// [madeBefore]: the copy was made, and its acts offered, before a reload: the
// page after it has the copy open with nothing of this run's making to say
// so (copied.made is the tab's), so the copy is known by its name and the
// link it came from.
async function watchCopy(page, seconds, madeBefore = false) {
  const end = Date.now() + seconds * 1000;
  let car = 0;
  let last = null;
  while (Date.now() < end) {
    const s = await look(page);
    last = s;
    if (s.account.state === "signed_in" && !s.account.gated) {
      if (s.share.title === SAMPLE) car += 1;
      const named = String(s.share.title || "");
      if (named && named !== SAMPLE && (named === modelName || named.startsWith(`${modelName} (`))
        && !s.url.includes("copy=") && (before || s.share.copied?.made
          || (madeBefore && s.share.copied?.from === id))) {
        return { ok: true, car, s };
      }
    }
    await page.waitForTimeout(400);
  }
  return { ok: false, car, s: last };
}

// A change, as a person makes one: a part selected and recoloured (the
// first act's way), or one taken off when every part tried is the colour in
// hand; then saved (Save on the toolbar, or More's Save on a phone).
async function changeAndSave(page, press, phone) {
  const box = await page.evaluate(() => {
    const c = document.querySelector("canvas");
    const r = c ? c.getBoundingClientRect() : { left: 0, top: 0, width: innerWidth, height: innerHeight };
    return { x: r.left, y: r.top, w: r.width, h: r.height };
  });
  const s0 = await look(page);
  const history0 = (s0.history || [0])[0];
  let changed = false;
  // Parts where the app says they are drawn (brickworksLayout's targets, as
  // centre_check clicks them), then points of the canvas: at 1280 the
  // canvas's middle is beside the model, framed whole right of the parts
  // column, and no click there found a part, on pre261 too (fmfin).
  await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; }).catch(() => {});
  const layout = await until(page, () => window.brickworksLayout || null, 15);
  const points = (layout?.targets || []).map((t) => ({ x: t.x, y: t.y }));
  for (const [fx, fy] of [[0.5, 0.5], [0.55, 0.45], [0.45, 0.55], [0.5, 0.4], [0.6, 0.55], [0.4, 0.45]]) {
    points.push({ x: box.x + box.w * fx, y: box.y + box.h * (phone ? fy * 0.9 + 0.03 : fy) });
  }
  for (const at of points) {
    if (phone) await page.touchscreen.tap(at.x, at.y);
    else await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(900);
    const s = await look(page);
    if (!s.selected) continue;
    const red = (s.colours || []).includes(4);
    if (phone) {
      await press("phone_colour", 20, true);
      await press(`phone_swatch_${red ? 1 : 4}`, 20, true);
    } else if (!red) {
      await page.keyboard.press("c");
    } else {
      await page.keyboard.press("Delete");
    }
    await page.waitForTimeout(1200);
    const after = await look(page);
    if ((after.history || [0])[0] > history0) {
      changed = true;
      break;
    }
  }
  if (phone) await press("phone_sheet_colours_done", 5, true);
  const writes0 = (await look(page)).writes.length;
  if (phone) {
    await press("phone_more", 20, true);
    await press("phone_quick_save", 20, true);
  } else {
    await press("save", 20, true);
  }
  const saved = await until(page, (n) => {
    try {
      const kept = JSON.parse(localStorage.getItem("fm.writes") || "[]");
      return kept.slice(n).some((p) => /\/models\//.test(p)) ? kept.slice(n) : null;
    } catch { return null; }
  }, 60, writes0);
  return { changed, saved: Boolean(saved), wrote: saved || [] };
}

const copiesOf = (writes) => new Set(writes.filter((p) => /\/models\//.test(p)
  && path.basename(p).startsWith(modelName.replace(/[\\/:*?"<>|]/g, "_"))).map((p) => path.basename(p))).size;

async function walk(width, way) {
  const tag = `${width}-${way}`;
  console.log(`\n${tag}`);
  // The whole way's name: by its first letter, returning and reload shared
  // one account, so reload's copy met returning's Garden shed in the cloud
  // and was kept beside it as "Garden shed 2" (nightly 2026-11-24).
  const email = address(`${way}${width}`);
  made.push(email);
  if (way === "returning") await mintSession(email, { age: true, welcome: true });
  const { context, phone } = await contextAt(width);
  const press = (page) => presser(page, phone);
  const page = await context.newPage();
  hearWho(page);
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  let n = 0;
  const shot = async (p, what) => {
    n += 1;
    await p.screenshot({ path: path.join(out, `${tag}-${String(n).padStart(2, "0")}-${what}.png`), timeout: 90000 })
      .catch((e) => console.log(`  --    no picture ${what}: ${String(e).split("\n")[0]}`));
  };
  const result = { width, way, email: email.replace(/\+.*@/, "+…@") };
  try {
    await page.goto(`${site}/m/${id}`, { waitUntil: "load", timeout: 120000 });
    await shot(page, "model-page");
    const open = page.locator(`a.cta[href*="/app?copy=${id}"]`).first();
    const t0 = Date.now();
    if (way === "site") {
      // Pressed on the page, signed out: the site asks at once, over the
      // model's page (web/follow.js, sitewalk3), where the studio used to
      // load for 23 to 31 s to ask the same; signed in there, the press goes
      // on to the studio with the copy.
      if (phone) await open.tap();
      else await open.click();
      const asked = await page.locator("dialog.sign-in[open]").waitFor({ state: "visible", timeout: 10000 })
        .then(() => Date.now() - t0, () => null);
      result.ask_ms = asked;
      const lead = await page.locator("dialog.sign-in[open] .lead").textContent().catch(() => "");
      check(`${tag}: Open in the studio asks on the page in ${asked} ms, the page still the model's (${new URL(page.url()).pathname}): "${lead}"`,
        asked !== null && asked < 2000 && new URL(page.url()).pathname === `/m/${id}` && /own copy in the studio/.test(lead || ""));
      await shot(page, "site-asks");
      result.answered = await codeOnSite(page, email, { leaves: true });
      await page.locator("dialog[open] button", { hasText: /Open it anyway/ }).click({ timeout: 4000 }).catch(() => {});
      await page.waitForURL(/\/app\?/, { timeout: 60000 }).catch(() => {});
      check(`${tag}: signed in, on to the studio with the copy (${new URL(page.url()).pathname}${new URL(page.url()).search})`,
        page.url().includes(`/app?copy=${id}`) || page.url().includes("/app"));
      result.gate_s = Math.round((Date.now() - t0) / 1000);
    } else {
      // The studio's own sign-in, for a stranger who comes by the studio's
      // link itself (a new tab, a link from elsewhere): the press on the
      // page asks there first since sitewalk3, so the link is opened.
      await page.goto(`${site}/app?copy=${id}`, { waitUntil: "domcontentloaded", timeout: 120000 });
    }
    const gated = way === "site" ? true : await until(page, () => (window.brickworksAccount || {}).gated === true, 240);
    if (way !== "site") {
      result.gate_s = Math.round((Date.now() - t0) / 1000);
      const behind = await look(page);
      result.behind = behind.share.title || "";
      check(`the sign-in screen, ${result.gate_s} s after the press, over "${result.behind}"`, Boolean(gated));
      await page.waitForTimeout(2500);
      await shot(page, "sign-in");
      if (!before) check(`behind it, the model asked for, not the example car: "${(await look(page)).share.title}"`,
        (await look(page)).share.title === modelName);
    }
    const p = press(page);
    const into = page;
    if (way === "site") {
      result.answered_studio = await answerStudio(page, p);
    } else if (way === "code" || way === "returning") {
      await codeInStudio(page, p, email);
      await shot(page, "code-typed");
      result.answered = await answerStudio(page, p);
    } else if (way === "reload") {
      await codeInStudio(page, p, email);
      result.age_asked = Boolean(await until(page, () => (window.brickworksControls || {}).age_go, 60));
      await shot(page, "age-question");
      // No age question asked (an account the admin API mints is not), the
      // copy is made and its acts offered before the reload: after it they
      // are not offered again, the copy open as it was (fmfin, 2026-11-23).
      const pre = await look(page);
      result.made_before_reload = Boolean(pre.share.copied?.made);
      result.acts_before_reload = Boolean(pre.share.acts?.shown);
      await page.reload({ waitUntil: "domcontentloaded" });
      result.after_reload = (await look(page)).url;
      result.answered = await answerStudio(page, p);
    } else if (way === "profile") {
      await p("signin_orangecheck", 60);
      await page.waitForURL(/\/profile\?then=/, { timeout: 60000 });
      const then = new URL(page.url()).searchParams.get("then") || "";
      result.then = then;
      check(`to the site's sign-in with the model kept: then=${then}`, then.includes(`copy=${id}`));
      await shot(page, "profile-sign-in");
      result.answered = await codeOnSite(page, email);
      await page.waitForURL(/\/app\?/, { timeout: 60000 }).catch(() => {});
      check(`back to the studio: ${new URL(page.url()).pathname}${new URL(page.url()).search}`, page.url().includes("/app"));
      // And what the studio asks a new account there, the beta's welcome
      // over the copy: never answered, no change could be made (nightly
      // 2026-11-24, 1280-profile-05).
      result.answered_studio = await answerStudio(page, p);
    } else if (way === "tab2") {
      const second = await context.newPage();
      await second.goto(`${site}/m/${id}`, { waitUntil: "load", timeout: 120000 });
      await second.locator("header a, header button", { hasText: /^Sign in$/ }).first().click({ timeout: 20000 })
        .catch(() => second.goto(`${site}/profile?sign-in`, { waitUntil: "load" }));
      result.answered = await codeOnSite(second, email);
      await shot(second, "second-tab-signed-in");
      await second.close();
      await page.bringToFront();
      // The first tab hears the sign-in; on an older build it needs a reload.
      const heard = await until(page, () => (window.brickworksAccount || {}).state === "signed_in", 30);
      result.heard_without_reload = Boolean(heard);
      if (!heard) await page.reload({ waitUntil: "domcontentloaded" });
      await answerStudio(page, p);
    }
    const t1 = Date.now();
    const got = await watchCopy(into, 240, Boolean(result.made_before_reload));
    result.copy_s = Math.round((Date.now() - t0) / 1000);
    result.copy_after_signin_s = Math.round((Date.now() - t1) / 1000);
    result.title = got.s?.share?.title;
    result.cars_after_signin = got.car;
    result.copied = got.s?.share?.copied || null;
    check(`${tag}: the asked-for model on the baseplate, "${result.title}", ${result.copy_s} s from the press`, got.ok);
    check(`${tag}: never the example car after the sign-in (${got.car} looks)`, got.car === 0);
    await into.waitForTimeout(1500);
    await shot(into, "copy");
    if (!before) {
      const acts = await until(into, () => (window.brickworksShare || {}).acts?.shown ? window.brickworksShare.acts : null, 30);
      result.acts = acts;
      if (result.acts_before_reload) {
        check(`${tag}: the acts offered before the reload, and not again after it: ${JSON.stringify(acts?.acts || [])}`, !acts);
      } else {
        check(`${tag}: the three first acts offered: ${JSON.stringify(acts?.acts || [])}`, Boolean(acts) && acts.acts?.length === 3);
      }
      check(`${tag}: credited to the original (${got.s?.share?.copied?.from})`, got.s?.share?.copied?.from === id);
    }
    const change = await changeAndSave(into, press(into), phone);
    result.changed = change.changed;
    result.saved = change.saved;
    result.saved_s = Math.round((Date.now() - t0) / 1000);
    await shot(into, "changed-and-saved");
    check(`${tag}: a change made (${change.changed}) and saved (${change.saved}), ${result.saved_s} s from Open in Brickworks (bar ${BAR_S} s)`,
      change.changed && change.saved && result.saved_s <= BAR_S);
    if (!before) {
      const gone = await look(into);
      check(`${tag}: the acts gone after the edit`, !gone.share.acts?.shown);
    }
    // Once a size: the copy again by reload and by a second tab: never a second.
    if (way === "code") {
      await into.goto(`${site}/app?copy=${id}`, { waitUntil: "domcontentloaded" });
      await until(into, () => (window.brickworksAccount || {}).state === "signed_in" && !location.search.includes("copy="), 180);
      await into.waitForTimeout(8000);
      const third = await context.newPage();
      await third.goto(`${site}/app?copy=${id}`, { waitUntil: "domcontentloaded" });
      await until(third, () => (window.brickworksAccount || {}).state === "signed_in" && !location.search.includes("copy="), 180);
      await third.waitForTimeout(8000);
      const s = await look(third);
      result.copies = copiesOf(s.writes);
      result.acts_again = s.share.acts?.shown || false;
      await shot(third, "second-tab-same-link");
      check(`${tag}: the same link again in this tab and a second: ${result.copies} copy (${[...new Set(s.writes.filter((w) => /\/models\//.test(w)).map((w) => path.basename(w)))].join(", ")})`,
        result.copies === 1);
      if (!before) check(`${tag}: the acts not offered again`, !result.acts_again);
      await third.close();
    }
  } catch (e) {
    check(`${tag}: ${String(e).split("\n")[0]}`, false);
    await shot(page, "trouble");
  }
  result.errors = errors.slice(0, 5);
  results.push(result);
  await context.close().catch(() => {});
}
try {
  for (const width of SIZES) {
    for (const way of WAYS) await walk(width, way);
  }
} finally {
  for (const email of made) await deleteAccount(email).catch(() => {});
  await browser.close().catch(() => {});
}
const asked = results.filter((r) => r.title && (r.title === modelName || String(r.title).startsWith(`${modelName} (`))).length;
const cars = results.reduce((a, r) => a + (r.cars_after_signin || 0), 0);
const quick = results.filter((r) => r.saved && r.changed && r.saved_s <= BAR_S).length;
const summary = { site, id, name: modelName, before, ways: WAYS, sizes: SIZES,
  asked_for_on_baseplate: `${asked} of ${results.length}`, example_cars_after_signin: cars,
  saved_change_within_bar: `${quick} of ${results.length}`,
  copies_on_again: results.filter((r) => r.copies !== undefined).map((r) => r.copies), results };
writeFileSync(path.join(out, "results.json"), `${JSON.stringify(summary, null, 1)}\n`);
console.log(`\nthe asked-for model after sign-in: ${summary.asked_for_on_baseplate}; example cars: ${cars}; `
  + `a saved change within ${BAR_S} s: ${summary.saved_change_within_bar}; copies on opening again: ${summary.copies_on_again.join(",")}`);
console.log(failed ? `${failed} failed` : "all passed");
process.exit(failed ? 1 : 0);
