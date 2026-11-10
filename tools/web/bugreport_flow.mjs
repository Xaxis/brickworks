// Report a bug (bugreport, 2026-11-09: web/bugreport.js, web/feedback.js's
// report mode, the app's top bar), as a beta tester meets it, in a real
// browser:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/bugreport_flow.mjs --url=<deployment> --out=DIR [--app=off]
//
// On a unit's preview with the beta open (tools/deploy.sh --unit --beta-open)
// the whole of it; on one with the beta shut, as every release's is, the site
// half and the app's top bar without its button.
//
//   1. Signed out, window.brickworksReportBug asks for a sign-in, with why.
//   2. A throwaway at 390 x 844 (dark, /faq) and at 1280 x 800 (light,
//      /gallery): brickworksReportBug() opens the report over the page, the
//      page where it was (no navigation), a bug chosen, the page's picture
//      attached and drawn (not blank); a drag on it draws a box, said in the
//      line of what will be sent; sent, it says its number and offers Your
//      reports. The picture kept for the owner's inbox has the box, red,
//      where it was drawn (each edge within 2 pixels), and its details the
//      box; what was expected kept with the words.
//   3. Your reports (/settings#feedback) lists each, its number and where it
//      stands (Received).
//   4. Escape and Cancel put it away with nothing sent.
//   5. The app (the web build at /app, 1400 x 900): with the beta open,
//      Report a bug beside Account; one click opens the report over the
//      model with the window's picture; a box drawn; sent and kept with the
//      box where it was drawn. With it shut, no Report a bug in the top bar.
//   6. The throwaway deleted the person's own way, its reports with it.
//
// Pictures in --out. It passes when it ends "bugreport: all ok".
import { clickStill, launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("bugreport_flow: --url=<a deployment> [--out=DIR] [--app=off]");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/bugreport_web";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const SUPABASE = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const skip = (what) => console.log(`  --    ${what}`);
const errors = [];
const until = (page, test, arg = null, timeout = 20000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const shot = async (page, name) => {
  // A dialog's rise ended (site.css), so the picture is what a person sees.
  await page.evaluate(() => Promise.race([new Promise((done) => setTimeout(done, 1500)),
    Promise.all(document.getAnimations().filter((one) => one.effect?.getComputedTiming().iterations !== Infinity)
      .map((one) => one.finished.catch(() => null)))])).catch(() => null);
  await page.screenshot({ path: path.join(out, name), timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// What the owner's inbox reads of report [id]: its row, and its picture as
/// base64 (the bucket's, by the project's secret key, as the inbox's signed
/// link serves it).
async function kept(id) {
  if (!SUPABASE || !SECRET) return null;
  const auth = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  // As the inbox reads one (api/admin.js): the table is the functions' alone.
  const one = await fetch(`${SUPABASE}/rest/v1/rpc/feedback_one`, { method: "POST",
    headers: { ...auth, "content-type": "application/json" }, body: JSON.stringify({ p_id: id }) });
  const row = one.ok ? await one.json().catch(() => null) : null;
  if (!row || !row.id) return { row: null, picture: "" };
  let picture = "";
  if (row.picture) {
    const file = await fetch(`${SUPABASE}/storage/v1/object/feedback/${row.picture}`, { headers: auth });
    if (file.ok) picture = Buffer.from(await file.arrayBuffer()).toString("base64");
  }
  return { row, picture };
}

// In the page: the box drawn into a JPEG, near [region] ({x, y, w, h} in
// its pixels, looked in 8 px round): the bounds of its mark-red that the
// picture had not before its marks (window.__bwBefore, the unmarked
// picture's red grown 2 px, where there is one), and how much of those
// bounds' edge is red (a box drawn, not a red thing of the page).
const RED_BOX = async ([data, region]) => {
  const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
  const bitmap = await createImageBitmap(new Blob([bytes], { type: "image/jpeg" }));
  const { width: w, height: h } = bitmap;
  const canvas = new OffscreenCanvas(w, h);
  const drawn = canvas.getContext("2d");
  drawn.drawImage(bitmap, 0, 0);
  const px = drawn.getImageData(0, 0, w, h).data;
  const before = window.__bwBefore;
  const same = Boolean(before && before.w === w && before.h === h);
  const red = (x, y) => {
    const i = (y * w + x) * 4;
    return px[i] >= 170 && px[i + 1] <= 110 && px[i + 2] <= 110 && !(same && before.red[y * w + x]);
  };
  const from = { x: Math.max(0, region.x - 8), y: Math.max(0, region.y - 8) };
  const to = { x: Math.min(w, region.x + region.w + 8), y: Math.min(h, region.y + region.h + 8) };
  let x0 = Infinity; let y0 = Infinity; let x1 = -1; let y1 = -1;
  for (let y = from.y; y < to.y; y++) {
    for (let x = from.x; x < to.x; x++) {
      if (!red(x, y)) continue;
      x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y);
    }
  }
  if (x1 < 0) return { size: [w, h], same, box: null, edge: 0 };
  // A box's sides are red end to end; red of the picture's own beside it
  // (a red brick in the bin) is not, so the bounds are its outermost rows
  // and columns red most of the way along, twice over.
  const along = (fixed, lo, hi, isRow) => {
    let on = 0;
    for (let n = lo; n <= hi; n++) on += (isRow ? red(n, fixed) : red(fixed, n)) ? 1 : 0;
    return on / Math.max(1, hi - lo + 1);
  };
  for (let pass = 0; pass < 2; pass++) {
    const rows = []; const cols = [];
    for (let y = y0; y <= y1; y++) if (along(y, x0, x1, true) >= 0.85) rows.push(y);
    if (rows.length) { y0 = rows[0]; y1 = rows[rows.length - 1]; }
    for (let x = x0; x <= x1; x++) if (along(x, y0, y1, false) >= 0.85) cols.push(x);
    if (cols.length) { x0 = cols[0]; x1 = cols[cols.length - 1]; }
  }
  // The ring 1 px in from the bounds' own edge: red all round, a box's.
  let on = 0; let all = 0;
  for (let x = x0 + 1; x < x1; x++) for (const y of [y0 + 1, y1 - 1]) { all += 1; on += red(x, y) ? 1 : 0; }
  for (let y = y0 + 1; y < y1; y++) for (const x of [x0 + 1, x1 - 1]) { all += 1; on += red(x, y) ? 1 : 0; }
  return { size: [w, h], same, box: { x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 }, edge: all ? on / all : 0 };
};
// In the page: the red of a picture before its marks, grown 2 px: the
// report's canvas as it is now ([selector]), or a PNG of the window
// ([png], base64), for the app, whose picture is the window's own.
const KEEP_RED = async ({ selector, png }) => {
  let canvas = selector ? document.querySelector(selector) : null;
  if (png) {
    const bytes = Uint8Array.from(atob(png), (c) => c.charCodeAt(0));
    const bitmap = await createImageBitmap(new Blob([bytes], { type: "image/png" }));
    canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    canvas.getContext("2d").drawImage(bitmap, 0, 0);
  }
  const { width: w, height: h } = canvas;
  const px = canvas.getContext("2d").getImageData(0, 0, w, h).data;
  const red = new Uint8Array(w * h);
  const colours = new Set();
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4;
      if (x % 7 === 0 && y % 7 === 0) colours.add((px[i] >> 3) << 10 | (px[i + 1] >> 3) << 5 | px[i + 2] >> 3);
      if (px[i] < 150 || px[i + 1] > 130 || px[i + 2] > 130) continue;
      for (let dy = -2; dy <= 2; dy++) {
        for (let dx = -2; dx <= 2; dx++) {
          const xx = x + dx; const yy = y + dy;
          if (xx >= 0 && yy >= 0 && xx < w && yy < h) red[yy * w + xx] = 1;
        }
      }
    }
  }
  window.__bwBefore = { w, h, red };
  return { w, h, colours: colours.size };
};
const near = (a, b, within) => a && b && Math.abs(a.x - b.x) <= within && Math.abs(a.y - b.y) <= within
  && Math.abs(a.x + a.w - b.x - b.w) <= within && Math.abs(a.y + a.h - b.y - b.h) <= within;
const boxWords = (box) => `${box.x},${box.y},${box.w},${box.h}`;
const boxOf = (words) => {
  const [x, y, w, h] = String(words || "").split(";")[0].split(",").map(Number);
  return Number.isFinite(h) ? { x, y, w, h } : null;
};

const browser = await launch({ signedOut: true });

/// [pathname] at [width] x [height] in [theme], signed in as [who] (a
/// mintSession) or out.
async function open(pathname, { width, height, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (who) {
    const access = JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000, email: who.kept.email });
    await context.addInitScript(([key, value, token]) => {
      try {
        if (!localStorage.getItem(key)) {
          localStorage.setItem(key, value);
          sessionStorage.setItem("brickworks.access", token);
        }
      } catch { /* a browser that keeps nothing */ }
    }, [STORAGE_KEY, JSON.stringify(who.kept), access]);
  }
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}

/// Report a bug, as the beta bar's entry asks for it (web/betabar.js loads
/// web/bugreport.js on its first press and calls this).
const ask = (page) => page.evaluate(async () => {
  if (!window.brickworksReportBug) await import("/bugreport.js");
  window.brickworksReportBug({ source: "site" });
});

/// The open report, as a person reads it.
const reportSaid = (page) => page.evaluate(() => {
  const dialog = document.querySelector("dialog.feedback.report[open]");
  if (!dialog) return null;
  const canvas = dialog.querySelector("canvas.marking");
  return { title: dialog.querySelector("h2")?.textContent || "", said: dialog.querySelector("p")?.textContent || "",
    kinds: [...dialog.querySelectorAll('input[name="kind"]')].map((k) => `${k.value}${k.checked ? "*" : ""}`),
    picture: canvas && !canvas.hidden ? [canvas.width, canvas.height] : null,
    marks: dialog.querySelector("figure.marked figcaption")?.textContent || "",
    sends: dialog.querySelector(".sends")?.textContent || "",
    status: dialog.querySelector('[role="status"]')?.textContent || "",
    sent: dialog.dataset.sent || "",
    reports: dialog.querySelector('a.cta[href$="/settings#feedback"]')?.getAttribute("href") || "",
    send: dialog.querySelector("button[type=submit]")?.getBoundingClientRect().bottom <= innerHeight
      || Boolean(dialog.dataset.sent),
    sideways: dialog.scrollWidth > dialog.clientWidth + 1 || document.documentElement.scrollWidth > innerWidth + 1 };
});

/// A drag on the open report's picture, from [a] to [b] (its fractions):
/// the box it should make, in the picture's pixels.
async function drawBox(page, a, b) {
  const rect = await page.evaluate(() => {
    const canvas = document.querySelector("dialog.feedback.report[open] canvas.marking");
    canvas.scrollIntoView({ block: "center" });
    // The picture as drawn: inside the canvas's border.
    const r = canvas.getBoundingClientRect();
    return { left: r.left + canvas.clientLeft, top: r.top + canvas.clientTop, width: canvas.clientWidth,
      height: canvas.clientHeight, w: canvas.width, h: canvas.height };
  });
  const from = { x: rect.left + rect.width * a[0], y: rect.top + rect.height * a[1] };
  const to = { x: rect.left + rect.width * b[0], y: rect.top + rect.height * b[1] };
  await page.mouse.move(from.x, from.y);
  await page.mouse.down();
  for (let n = 1; n <= 8; n++) await page.mouse.move(from.x + (to.x - from.x) * n / 8, from.y + (to.y - from.y) * n / 8);
  await page.mouse.up();
  const sx = rect.w / rect.width; const sy = rect.h / rect.height;
  const x0 = Math.round((from.x - rect.left) * sx); const y0 = Math.round((from.y - rect.top) * sy);
  const x1 = Math.round((to.x - rect.left) * sx); const y1 = Math.round((to.y - rect.top) * sy);
  return { x: Math.min(x0, x1), y: Math.min(y0, y1), w: Math.abs(x1 - x0), h: Math.abs(y1 - y0) };
}

let R = null;
const email = `delivered+bw-bugreport-${rand}@resend.dev`;
const sent = [];
try {
  R = await mintSession(email);
  const who = await api("/api/account", { token: R.access_token });
  const open_ = Boolean(who.json?.beta?.open);
  console.log(`bugreport flow: ${site} (the beta ${open_ ? "open" : "shut"})`);
  check(`/api/account says whether the beta is open: ${JSON.stringify(who.json?.beta)}`, who.status === 200
    && typeof who.json?.beta?.open === "boolean");

  // --- 1. Signed out ---------------------------------------------------------------
  console.log("1. Signed out");
  {
    const { page, context } = await open("/faq", { width: 1280, height: 800, label: "signed out" });
    await ask(page);
    const asked = await until(page, () => [...document.querySelectorAll("dialog[open]")]
      .some((d) => /Sign in to report a bug/.test(d.textContent)), null, 15000);
    check("brickworksReportBug asks for a sign-in, saying why, and opens no report", asked
      && !(await page.evaluate(() => document.querySelector("dialog.feedback[open]"))));
    await shot(page, "1-signed-out.png");
    await context.close();
  }

  // --- 2 and 4. A throwaway, at a phone's width and a laptop's ------------------------
  for (const [width, height, theme, where] of [[390, 844, "dark", "/faq"], [1280, 800, "light", "/gallery"]]) {
    console.log(`2. Signed in at ${width} x ${height}, ${theme}, on ${where}`);
    const { page, context } = await open(where, { width, height, theme, who: R, label: `${width}` });
    await until(page, () => document.querySelector(".site-foot"), null, 30000);
    await page.waitForTimeout(1500);
    const was = page.url();
    const started = Date.now();
    await ask(page);
    const up = await until(page, () => document.querySelector("dialog.feedback.report[open] canvas.marking"), null, 20000);
    const took = Date.now() - started;
    let state = await reportSaid(page);
    if (!check(`${width}: it opens the report over the page in ${took} ms: "${state?.title}"`, up && state?.title === "Report a bug")) {
      await shot(page, `2-${width}-never.png`);
      await context.close();
      continue;
    }
    check(`${width}: the page where it was (${page.url() === was ? "same address" : page.url()}), nothing sideways`,
      page.url() === was && !state.sideways);
    check(`${width}: a bug chosen (${state.kinds.join(", ")}), Send on the screen`, state.kinds.includes("bug*") && state.send);
    const wide = await page.evaluate(() => document.documentElement.clientWidth || innerWidth);
    const ratio = await page.evaluate((across) => Math.min(devicePixelRatio || 1, 2, 1600 / across), wide);
    const before = await page.evaluate(KEEP_RED, { selector: "dialog.feedback.report[open] canvas.marking" });
    check(`${width}: the page's picture attached, ${state.picture.join(" x ")} (the page ${wide} wide at ${ratio.toFixed(2)}),`
      + ` drawn (${before.colours} colours)`, Math.abs(state.picture[0] - Math.round(wide * ratio)) <= 1 && before.colours >= 12);
    check(`${width}: it says what will be sent: "${state.sends}"`, /^What you wrote · the picture · this page and your browser$/.test(state.sends));
    await shot(page, `2-${width}-${theme}-report.png`);

    const expect = await drawBox(page, [0.22, 0.30], [0.71, 0.58]);
    state = await reportSaid(page);
    check(`${width}: a drag on it draws a box: "${state.marks}" / "${state.sends}"`, state.marks.startsWith("1 mark.")
      && state.sends.includes("the picture, with 1 mark"));
    await shot(page, `2-${width}-${theme}-marked.png`);
    const dialog = page.locator("dialog.feedback.report[open]");
    const words = `The second brick floats after an undo. (bugreport flow ${rand} ${width})`;
    await dialog.locator('textarea[name="words"]').fill(words);
    await dialog.locator('textarea[name="expected"]').fill("It sits back on the first.");
    await dialog.locator("button[type=submit]").click();
    await until(page, () => {
      const open = document.querySelector("dialog.feedback.report[open]");
      const status = open?.querySelector('[role="status"]')?.textContent || "";
      return open?.dataset.sent || (status && status !== "Sending…");
    }, null, 60000);
    state = await reportSaid(page);
    const id = Number(state.sent);
    if (!check(`${width}: sent: "${state.title}" "${state.said}"`, id > 0 && state.title === `Thank you. Report #${id} is in.`
      && /Follow it, and our answer, in Your reports\./.test(state.said) && state.reports === "/settings#feedback")) {
      console.log(`        (it said "${state.status}")`);
    }
    await shot(page, `2-${width}-${theme}-thanks.png`);
    if (id > 0) {
      sent.push(id);
      const inbox = await kept(id);
      if (!inbox) skip("no SUPABASE_URL / SUPABASE_SECRET_KEY: the kept picture is not read");
      else {
        check(`${width}: kept, the site's: its words and what was expected, from the bar's call`, inbox.row?.source === "site"
          && inbox.row.words === `${words}\n\nExpected: It sits back on the first.` && inbox.row.details?.from === "bar");
        const found = inbox.picture ? await page.evaluate(RED_BOX, [inbox.picture, expect]) : null;
        check(`${width}: the picture in the owner's inbox (${found?.size?.join(" x ")}) has the box, red, where it was drawn:`
          + ` found ${JSON.stringify(found?.box)}, drawn ${JSON.stringify(expect)} (each edge within 2 px; its edge`
          + ` ${Math.round((found?.edge || 0) * 100)}% red)`, found?.same && near(found.box, expect, 2) && found.edge >= 0.9);
        check(`${width}: ...and its details say it: ${inbox.row?.details?.marks}`, near(boxOf(inbox.row?.details?.marks), expect, 1));
      }
    }
    await page.keyboard.press("Escape");

    // Escape and Cancel: nothing sent.
    console.log(`4. Escape and Cancel at ${width}`);
    const mine = async () => ((await api("/api/plans?op=feedback", { token: R.access_token })).json?.reports || []).length;
    const count = await mine();
    await ask(page);
    await until(page, () => document.querySelector("dialog.feedback.report[open] canvas.marking"));
    await page.locator('dialog.feedback.report[open] textarea[name="words"]').fill("Typed, then thought better of.");
    await page.keyboard.press("Escape");
    const goneEscape = await until(page, () => !document.querySelector("dialog.feedback[open]"), null, 5000);
    await ask(page);
    await until(page, () => document.querySelector("dialog.feedback.report[open] canvas.marking"));
    await page.locator('dialog.feedback.report[open] textarea[name="words"]').fill("Typed, then thought better of.");
    await page.locator("dialog.feedback.report[open] button", { hasText: "Cancel" }).click();
    const goneCancel = await until(page, () => !document.querySelector("dialog.feedback[open]"), null, 5000);
    await page.waitForTimeout(1500);
    check(`${width}: Escape and Cancel each put it away, and nothing more is sent (${count} → ${await mine()})`,
      goneEscape && goneCancel && (await mine()) === count);
    await context.close();
  }

  // --- 3. Your reports --------------------------------------------------------------
  console.log("3. Your reports");
  {
    const { page, context } = await open("/settings#feedback", { width: 1280, height: 800, who: R, label: "your reports" });
    const listed = await until(page, (ids) => ids.every((id) => document.getElementById(`report-${id}`)), sent, 30000);
    const said = await page.evaluate((ids) => ({ head: document.querySelector("#feedback h2")?.textContent || "",
      items: ids.map((id) => document.getElementById(`report-${id}`)?.querySelector(".marks")?.textContent || "") }), sent);
    check(`${said.head} lists each, its number and where it stands: ${said.items.map((t) => `"${t.replace(/\s+/g, " ").trim()}"`).join(", ")}`,
      listed && sent.length === 2 && said.head === "Your reports"
      && said.items.every((t, n) => t.includes(`#${sent[n]}`) && /Received/.test(t)));
    // The section itself: the page's own scrolling settles after the shot.
    await page.locator("#feedback").screenshot({ path: path.join(out, "3-your-reports.png"), timeout: 60000 })
      .catch((trouble) => console.log(`  --    no picture 3-your-reports.png: ${String(trouble).split("\n")[0]}`));
    await context.close();
  }

  // --- 5. The app --------------------------------------------------------------------
  console.log("5. The app at 1400 x 900");
  const app = await fetch(`${site}/app`, { headers }).catch(() => null);
  if (args.app === "off" || !app?.ok) {
    skip(`no app at ${site}/app (${app?.status ?? "unreachable"})`);
  } else {
    const { page, context } = await open("/app", { width: 1400, height: 900, who: R, label: "app" });
    const signedIn = await until(page, () => (window.brickworksAccount || {}).state === "signed_in", null, 240000);
    check("the app is up, signed in", signedIn);
    await until(page, () => Boolean((window.brickworksControls || {}).account), null, 120000);
    // The button comes when the account says the beta is open, the
    // account's answer seconds in on a busy box: it is waited for, and
    // with the beta shut, given as long not to come.
    if (open_) await until(page, () => Boolean((window.brickworksControls || {}).report_bug), null, 60000);
    else await page.waitForTimeout(15000);
    const button = await page.evaluate(() => (window.brickworksControls || {}).report_bug || null);
    if (!open_) {
      check(`the beta shut: no Report a bug in the top bar (${JSON.stringify(button)})`, !button);
      await shot(page, "5-app-beta-shut.png");
    } else if (check(`the beta open: Report a bug in the top bar, beside Account (${JSON.stringify(button)})`, Boolean(button))) {
      // The window as the report will take it: its red (the bin's red
      // bricks) is not a box's.
      const plain = await page.screenshot({ type: "png", timeout: 60000 }).catch(() => null);
      await clickStill(page, "report_bug", { seconds: 30 });
      const up = await until(page, () => (window.brickworksState?.feedback || {}).reporting === true
        && Boolean((window.brickworksControls || {}).report_picture), null, 30000);
      let state = await page.evaluate(() => window.brickworksState?.feedback || {});
      check(`one click opens the report over the model, from the bar, the window's picture in it (${JSON.stringify(state.picture_size)})`,
        up && state.from === "bar" && state.picture && state.title === "Report a bug");
      await shot(page, "5-app-report.png");
      const at = await page.evaluate(() => window.brickworksControls.report_picture);
      await page.mouse.move(at.x - at.w * 0.2, at.y - at.h * 0.2);
      await page.mouse.down();
      for (let n = 1; n <= 10; n++) await page.mouse.move(at.x - at.w * 0.2 + at.w * 0.3 * n / 10, at.y - at.h * 0.2 + at.h * 0.32 * n / 10);
      await page.mouse.up();
      await until(page, () => (window.brickworksState?.feedback || {}).marks, null, 10000);
      state = await page.evaluate(() => window.brickworksState?.feedback || {});
      const marked = boxOf(state.marks);
      check(`a drag on it draws a box (${state.marks}): "${state.sends}"`, Boolean(marked) && /with 1 mark/.test(state.sends));
      await clickStill(page, "feedback_words", { seconds: 10 });
      await page.keyboard.type(`The bin's search forgets its word. (bugreport flow ${rand} app)`, { delay: 15 });
      await shot(page, "5-app-marked.png");
      await clickStill(page, "feedback_send", { seconds: 10 });
      await until(page, () => (window.brickworksState?.feedback || {}).sent === true
        || /(did not|not open|Try again)/.test((window.brickworksState?.feedback || {}).status || ""), null, 60000);
      state = await page.evaluate(() => window.brickworksState?.feedback || {});
      const id = Number(state.answer?.id);
      check(`sent from the app: "${state.said}" "${state.status}"`, state.sent && id > 0 && state.said === `Thank you. Report #${id} is in.`);
      await shot(page, "5-app-thanks.png");
      if (id > 0) {
        sent.push(id);
        const inbox = await kept(id);
        if (inbox) {
          check(`kept, the app's, from the bar, its box in its details (${inbox.row?.details?.marks})`, inbox.row?.source === "app"
            && inbox.row.details?.from === "bar" && inbox.row.details?.marks === state.marks);
          // The app's picture before its marks is the window as it was
          // pressed: the box is read near where the app says it is, as a
          // red edge all round, apart from the red the window had.
          await page.evaluate(() => { window.__bwBefore = null; });
          if (plain) await page.evaluate(KEEP_RED, { png: plain.toString("base64") });
          const found = inbox.picture && marked ? await page.evaluate(RED_BOX, [inbox.picture, marked]) : null;
          check(`the picture in the owner's inbox (${found?.size?.join(" x ")}) has the box, red, where it was drawn:`
            + ` found ${JSON.stringify(found?.box)}, marked ${JSON.stringify(marked)} (each edge within 2 px; its edge`
            + ` ${Math.round((found?.edge || 0) * 100)}% red)`, near(found?.box, marked, 2) && found.edge >= 0.9);
        }
      }
    }
    await context.close();
  }

  // --- 6. Deleted the person's own way -------------------------------------------------
  console.log("6. Deleting the throwaway");
  const gone = await api("/api/account?op=delete", { method: "POST", token: R.access_token, body: { confirm: R.kept.email } });
  check(`deleted: ${gone.status}`, gone.status === 200);
  if (SUPABASE && SECRET && sent.length) {
    const left = await Promise.all(sent.map(async (id) => (await kept(id))?.row));
    check(`its reports gone with it (${left.filter(Boolean).length} left)`, left.every((row) => !row));
  }
  writeFileSync(path.join(out, "sent.json"), JSON.stringify({ sent }, null, 1));
} catch (trouble) {
  check(`ran to the end: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  await deleteAccount(email).catch(() => false);
  await browser.close();
}

check(`no page errors${errors.length ? `: ${errors.slice(0, 4).join(" | ")}` : ""}`, errors.length === 0);
console.log(failed ? `bugreport: ${failed} FAILED, ${passed} ok` : "bugreport: all ok");
process.exit(failed ? 1 : 0);
