// sireview (2026-11-15): signinux on a deployment (its preview), a throwaway
// test address. Made checks by sifix: the run exits 1 on any failure.
//   set -a; . .env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/sirev_deployed.mjs --url=<preview> --out=DIR [--merged=FILE] [--only=...]
// /api/otp is answered here (no send counted against the box's IP limit) and
// a code of 77777777 is answered with a new password-grant session for the
// address (a refresh token used twice ends a session); every other code goes
// to Supabase's own verify.
//
// real    a wrong code refused by Supabase, the right one pasted signs in.
// pages   the header's Sign in, in place, on eight pages, what was typed kept.
// profile /profile signed out opens no dialog; /profile?sign-in does.
// admin   /admin's bar has Sign in, signed in there in place, still on /admin.
// tabs    a sign-in in one tab is the other's avatar; a sign-out reaches it.
// consent the connector's sign-in page: boxes, a wrong code, Allow.
// scroll  signed in from the header, the page stays where it was scrolled.
import { launch } from "./browser.mjs";
import { mintCode, mintSession, deleteAccount } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "sirev_dep";
mkdirSync(out, { recursive: true });
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const only = args.only ? String(args.only).split(",") : null;
const want = (name) => !only || only.includes(name);
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const results = [];
let failed = 0;
const note = (what, ok, detail = "") => {
  results.push({ what, ok, detail });
  if (ok === false) failed += 1;
  console.log(`  ${ok === true ? "ok  " : ok === false ? "FAIL" : "info"}  ${what}${detail ? `: ${typeof detail === "string" ? detail : JSON.stringify(detail)}` : ""}`);
};
const until = (page, test, arg = null, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms, polling: 100 })
  .then(() => true, () => false);

const person = `delivered+bw-sirev-${randomBytes(4).toString("hex")}@resend.dev`;
/// A session for the address, new each time.
const minted = async () => {
  const made = await mintSession(person, { age: true, welcome: true });
  return { access_token: made.access_token, refresh_token: made.kept.refresh_token, expires_in: 3600,
    token_type: "bearer", user: { id: made.kept.user_id, email: person } };
};
await minted();
const FAKE = "77777777";
const verified = [];
const browser = await launch({ signedOut: true });

async function fresh(width = 1280, { touch = false } = {}) {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 },
    ...(touch ? { isMobile: true, hasTouch: true } : {}) });
  await context.route(`${site}/**`, (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/api/otp" && route.request().method() === "POST") {
      return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true, expires_in_minutes: 10, digits: 8 }) });
    }
    if (args.merged && url.pathname === "/authorize.js") {
      return route.fulfill({ status: 200, contentType: "text/javascript", body: readFileSync(args.merged, "utf8") });
    }
    return route.continue({ headers: { ...route.request().headers(), ...headers } });
  });
  await context.route("**/auth/v1/verify", async (route) => {
    const body = route.request().postDataJSON() || {};
    verified.push(body.token);
    if (body.token === FAKE) return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(await minted()) });
    return route.continue();
  });
  const page = await context.newPage();
  page.errors = [];
  page.on("pageerror", (e) => page.errors.push(String(e).slice(0, 160)));
  return { context, page };
}
async function headerSignIn(page) {
  if (await page.locator(".site-head .menu summary").isVisible()) {
    await page.locator(".site-head .menu summary").click();
    await page.locator(".site-head .menu a[data-account]").click();
  } else {
    await page.locator(".site-head .nav a[data-account]").click();
  }
  return until(page, () => document.querySelector("dialog.sign-in")?.open);
}
async function codeIn(page, code = FAKE) {
  await page.locator("dialog.sign-in input[type=email]").fill(person);
  await page.locator("dialog.sign-in form.by-email button[type=submit]").click();
  await until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, 20000);
  await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
  await page.keyboard.type(code);
  return until(page, () => !document.querySelector("dialog.sign-in"), null, 20000);
}
const state = (page) => page.evaluate(() => ({ url: location.pathname + location.search, kept: window.__kept === 1,
  avatar: [...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()),
  dialogs: [...document.querySelectorAll("dialog")].filter((d) => d.open).map((d) => d.className) }));

try {
  // The real verify: a wrong code, then the right one minted.
  if (want("real")) {
    const { context, page } = await fresh();
    await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
    await page.evaluate(() => { window.__kept = 1; });
    await headerSignIn(page);
    await page.locator("dialog.sign-in input[type=email]").fill(person);
    await page.locator("dialog.sign-in form.by-email button[type=submit]").click();
    await until(page, () => document.querySelector("dialog.sign-in .code-boxes input")?.checkVisibility(), null, 20000);
    await page.locator("dialog.sign-in .code-boxes input >> nth=0").focus();
    await page.keyboard.type("00000000");
    await until(page, () => document.querySelector("dialog.sign-in form .said")?.dataset.tone === "bad", null, 20000);
    const wrong = await page.evaluate(() => ({ said: document.querySelector("dialog.sign-in form .said").textContent,
      values: [...document.querySelectorAll("dialog.sign-in .code-box")].map((b) => b.value).join(""),
      focus: [...document.querySelectorAll("dialog.sign-in .code-box")].indexOf(document.activeElement) }));
    note("real verify, wrong code: said, emptied, focus first", wrong.values === "" && wrong.focus === 0, wrong);
    const code = await mintCode(person);
    await page.evaluate((c) => {
      const data = new DataTransfer();
      data.setData("text/plain", `${c.slice(0, 4)} ${c.slice(4)}`);
      document.activeElement.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }));
    }, code);
    const gone = await until(page, () => !document.querySelector("dialog.sign-in"), null, 20000);
    await page.waitForTimeout(1500);
    note("real verify, the right code pasted: signed in, same page", gone && (await state(page)).kept && (await state(page)).avatar, await state(page));
    await context.close();
  }

  // In place, page by page: what was on the page kept.
  const pages = [
    ["/gallery", async (p) => { await p.locator("#q").fill("castle tower"); }, (p) => p.evaluate(() => ({ q: document.querySelector("#q")?.value,
      tabs: [...document.querySelectorAll("[role=tab], .tabs a, .tabs button")].map((t) => t.textContent.trim()).filter(Boolean).slice(0, 8) }))],
    ["MODEL", async (p) => { await p.locator("form.comment-new textarea").fill("half a comment"); },
      (p) => p.evaluate(() => ({ comment: document.querySelector("form.comment-new textarea")?.value,
        send: document.querySelector("form.comment-new button[type=submit]")?.textContent }))],
    ["/lists", null, (p) => p.evaluate(() => ({ lists: document.documentElement.dataset.lists, signedOutShown: !document.getElementById("signed-out")?.hidden }))],
    ["/challenge", null, (p) => p.evaluate(() => ({ text: document.querySelector("main")?.innerText.slice(0, 160) }))],
    ["/settings", null, (p) => p.evaluate(() => ({ settings: document.documentElement.dataset.settings, signedOutShown: !document.getElementById("signed-out")?.hidden }))],
    ["/notifications", null, (p) => p.evaluate(() => ({ n: document.documentElement.dataset.notifications }))],
    ["/feed", null, (p) => p.evaluate(() => ({ feed: document.documentElement.dataset.feed, signedOutShown: !document.getElementById("signed-out")?.hidden }))],
    ["/de/gallery", null, (p) => p.evaluate(() => ({ lang: document.documentElement.lang }))],
  ];
  if (want("pages")) {
    let model = null;
    for (const [at, before, read] of pages) {
      const { context, page } = await fresh();
      let where = at;
      if (at === "MODEL") {
        if (!model) {
          await page.goto(`${site}/gallery`, { waitUntil: "load", timeout: 120000 });
          await until(page, () => document.querySelector('a[href*="/m/"]'), null, 30000);
          model = await page.evaluate(() => new URL(document.querySelector('a[href*="/m/"]').href).pathname);
        }
        where = model;
      }
      await page.goto(`${site}${where}`, { waitUntil: "load", timeout: 120000 });
      await page.waitForTimeout(2500);
      await page.evaluate(() => { window.__kept = 1; });
      if (before) await before(page).catch((e) => note(`${where}: could not set up`, false, String(e).slice(0, 120)));
      const opened = await headerSignIn(page);
      const said = opened ? await page.evaluate(() => ({ title: document.querySelector("dialog.sign-in h2")?.textContent,
        go: document.querySelector("dialog.sign-in form.by-email button[type=submit]")?.textContent })) : null;
      const signed = opened && await codeIn(page);
      await page.waitForTimeout(3000);
      const now = await state(page);
      const kept = await read(page).catch(() => null);
      note(`${where}: header Sign in, in place`, opened && signed && now.kept && now.url.startsWith(where) && now.avatar,
        { ...now, kept, said, verifies: verified.length, errors: page.errors });
      await page.screenshot({ path: path.join(out, `inplace_${where.replace(/\W+/g, "_")}.png`) }).catch(() => null);
      await context.close();
    }
  }

  // /profile signed out shows its own Sign in and opens nothing by itself
  // (sifix: it opened the dialog at once after a sign-out); asked for
  // (/profile?sign-in, the header's link without scripts), it opens it.
  if (want("profile")) {
    const { context, page } = await fresh();
    await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 120000 });
    const auto = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 6000);
    const own = await page.evaluate(() => !document.getElementById("signed-out")?.hidden);
    note("/profile signed out: its own Sign in, no dialog by itself", !auto && own, { auto, own });
    await page.goto(`${site}/profile?sign-in`, { waitUntil: "load", timeout: 120000 });
    const asked = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 10000);
    note("/profile?sign-in opens the dialog, the ?sign-in gone from the address", asked && !/sign-in/.test(page.url()), page.url());
    const shell = await page.evaluate(() => [...document.querySelectorAll(".site-head a[data-account]")].map((a) => a.getAttribute("href")));
    note("the header's Sign in links to /profile?sign-in", shell.length > 0 && shell.every((href) => /\/profile\?sign-in$/.test(href)), shell);
    await context.close();
  }

  // /admin (sifix: no Sign in in its bar; its gate's went to /profile and
  // never came back): signed in there, in place. The test address is not
  // the owner: the gate then says so, still on /admin.
  if (want("admin")) {
    const { context, page } = await fresh();
    await page.goto(`${site}/admin#people`, { waitUntil: "load", timeout: 120000 });
    await until(page, () => !/Checking/.test(document.getElementById("gate-note")?.textContent || ""), null, 20000);
    await page.evaluate(() => { window.__kept = 1; });
    const bar = await page.evaluate(() => ({ shown: Boolean(document.getElementById("sign-in")?.checkVisibility()),
      gate: document.getElementById("gate-sign-in")?.getAttribute("href"), note: document.getElementById("gate-note")?.textContent }));
    note("/admin signed out: Sign in in its bar, the gate's to /profile?sign-in", bar.shown && bar.gate === "/profile?sign-in", bar);
    let signed = false;
    if (bar.shown) {
      await page.locator("#sign-in").click();
      signed = await until(page, () => document.querySelector("dialog.sign-in")?.open, null, 8000) && await codeIn(page);
    }
    const asked = signed && await until(page, () => /cannot see this page/.test(document.getElementById("gate-note")?.textContent || ""), null, 30000);
    const after = await page.evaluate(() => ({ url: location.pathname + location.hash, kept: window.__kept === 1,
      bar: Boolean(document.getElementById("sign-in")?.checkVisibility()), note: document.getElementById("gate-note")?.textContent }));
    note("/admin: signed in from its bar in place, asked again, still on /admin#people", asked && after.url === "/admin#people"
      && after.kept && !after.bar, after);
    await page.screenshot({ path: path.join(out, "admin_signed_in.png") }).catch(() => null);
    await context.close();
  }

  // Two tabs (sifix: tab B kept its avatar after tab A signed out): a
  // sign-in in A is B's avatar with no reload; a sign-out in A reaches B.
  if (want("tabs")) {
    const { context, page } = await fresh();
    await page.goto(`${site}/faq`, { waitUntil: "load", timeout: 120000 });
    const other = await context.newPage();
    await other.goto(`${site}/gallery-lists`, { waitUntil: "load", timeout: 120000 });
    await other.evaluate(() => { window.__kept = 1; });
    await headerSignIn(page);
    await codeIn(page);
    const inB = await until(other, () => [...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()), null, 15000);
    note("tab A signed in: tab B's header is the avatar, no reload", inB && (await state(other)).kept, await state(other));
    await page.locator(".site-head .account-menu summary").click();
    await Promise.all([page.waitForEvent("load", { timeout: 30000 }), page.locator(".site-head .account-menu button.sign-out").click()]);
    const outB = await until(other, () => [...document.querySelectorAll(".site-head a[data-account]")].some((o) => o.checkVisibility())
      && ![...document.querySelectorAll(".site-head .account-btn")].some((o) => o.checkVisibility()), null, 15000);
    note("tab A signed out: tab B signed out too, Sign in in its header", outB, { a: await state(page), b: await state(other) });
    await context.close();
  }

  // The merged consent page: Claude named at once, the code in boxes, signed in to Allow.
  if (want("consent")) {
    const { context, page } = await fresh();
    await context.route("https://claude.ai/**", (route) => route.fulfill({ status: 200, contentType: "text/html", body: "<p>claude.ai stood in</p>" }));
    const server = await (await fetch(`${site}/.well-known/oauth-authorization-server`, { headers })).json();
    const asked = new URL(server.authorization_endpoint);
    for (const [k, v] of Object.entries({ response_type: "code", client_id: "https://claude.ai/oauth/mcp-oauth-client-metadata",
      redirect_uri: "https://claude.ai/api/mcp/auth_callback", code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256", state: "sirev", scope: "build offline_access", resource: `${site}/api/mcp` })) asked.searchParams.set(k, v);
    const titles = [];
    page.on("domcontentloaded", async () => titles.push(await page.evaluate(() => document.querySelector("h1")?.textContent).catch(() => "")));
    await page.goto(asked.toString(), { waitUntil: "domcontentloaded", timeout: 120000 });
    titles.push(await page.evaluate(() => document.querySelector("h1")?.textContent));
    await page.waitForSelector("#email-step:not(.hide)", { timeout: 30000 });
    titles.push(await page.evaluate(() => document.querySelector("h1")?.textContent));
    note("consent page (merged): its title all along", titles.every((t) => /Claude/.test(t || "")), titles);
    await page.fill("#email", person);
    await page.click("#send");
    await page.waitForSelector("#code-step:not(.hide)", { timeout: 30000 });
    const row = await page.evaluate(() => ({ boxes: document.querySelectorAll("#code-step .code-box").length,
      first: document.activeElement?.id, otc: document.querySelector("#code-1")?.autocomplete }));
    note("consent page (merged): the code in boxes, the first focused", row.boxes === 8 && row.first === "code-1", row);
    await page.locator("#code-1").fill("00000000");
    await until(page, () => document.querySelector("#say")?.classList.contains("bad"), null, 20000);
    const wrong = await page.evaluate(() => ({ say: document.querySelector("#say")?.textContent, values: [...document.querySelectorAll("#code-step .code-box")].map((b) => b.value).join(""),
      focus: document.activeElement?.id }));
    note("consent page (merged): a wrong code refused, emptied", wrong.values === "", wrong);
    await page.locator("#code-1").fill(FAKE);
    const allow = await until(page, () => document.querySelector("#allow-step") && !document.querySelector("#allow-step").classList.contains("hide"), null, 60000);
    note("consent page (merged): signed in, Allow asked", allow, await page.evaluate(() => ({ step: ["checking", "refused", "email-step", "code-step", "allow-step", "leaving"]
      .find((id) => !document.getElementById(id)?.classList.contains("hide")), say: document.querySelector("#say")?.textContent, focus: document.activeElement?.id })));
    await page.screenshot({ path: path.join(out, "consent_allow.png") });
    note("consent page errors", page.errors.length === 0, page.errors);
    await context.close();
  }
  // After signing in from the header, where the page is: scrolled, at 1280 by mouse and 430 by finger.
  if (want("scroll")) {
    for (const [width, touch] of [[1280, false], [430, true]]) {
      const { context, page } = await fresh(width, { touch });
      await page.goto(`${site}/gallery`, { waitUntil: "load", timeout: 120000 });
      await until(page, () => document.querySelector('a[href*="/m/"]'), null, 30000);
      const model = await page.evaluate(() => new URL(document.querySelector('a[href*="/m/"]').href).pathname);
      await page.goto(`${site}${model}`, { waitUntil: "load", timeout: 120000 });
      await page.waitForTimeout(3000);
      await page.evaluate(() => { window.__kept = 1; document.getElementById("comments")?.scrollIntoView({ block: "start" }); });
      await page.waitForTimeout(800);
      const y0 = await page.evaluate(() => Math.round(scrollY));
      const press = async (selector) => {
        const b = await page.locator(selector).boundingBox();
        if (touch) await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2);
        else await page.mouse.click(b.x + b.width / 2, b.y + b.height / 2);
      };
      if (await page.locator(".site-head .menu summary").isVisible()) {
        await press(".site-head .menu summary");
        await page.locator(".site-head .menu a[data-account]").waitFor({ state: "visible", timeout: 5000 });
        await press(".site-head .menu a[data-account]");
      } else {
        await press(".site-head .nav a[data-account]");
      }
      await until(page, () => document.querySelector("dialog.sign-in")?.open);
      const y1 = await page.evaluate(() => Math.round(scrollY));
      const signed = await codeIn(page);
      const seen = [];
      for (const ms of [0, 500, 2500]) {
        await page.waitForTimeout(ms);
        seen.push(await page.evaluate(() => `${Math.round(scrollY)} ${document.activeElement?.tagName}.${document.activeElement?.className}`));
      }
      note(`${width}${touch ? " finger" : ""}: model page scrolled to its comments, header Sign in: scroll at open, then after signing in (y focus)`,
        signed && seen.every((one) => Math.abs(Number(one.split(" ")[0]) - y0) < 4), { model, y0, y1, seen });
      await page.screenshot({ path: path.join(out, `after_sign_in_${width}.png`) }).catch(() => null);
      await context.close();
    }
  }
} catch (trouble) {
  note(`ran to the end (${String(trouble).split("\n")[0]})`, false);
} finally {
  writeFileSync(path.join(out, "deployed.json"), JSON.stringify(results, null, 1));
  await browser.close();
  await deleteAccount(person).catch(() => null);
  console.log(`verifies sent to Supabase or stood in: ${JSON.stringify(verified)}`);
}
console.log(failed ? `sirev_deployed: ${failed} FAILED` : "sirev_deployed: all ok");
process.exit(failed ? 1 : 0);
