// The ground rules (2026-10-18), in a real browser: the terms and the
// guidelines on every page, the age question on the site and in the app,
// what an answer under 13 refuses and an answer of 13 or over allows, and
// the guidelines beside Publish.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 --static=build/web --trust-stand-in &
//   BW_STAND_IN=http://127.0.0.1:8790 node tools/web/age_flow.mjs --url=http://127.0.0.1:8790 --out=shots/age
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/age_flow.mjs --url=<deployment> --out=shots/age   # once trust.sql is applied
//
// --trust-stand-in answers supabase/trust.sql's five functions in the local
// server's own memory until the file is applied to the project
// (tools/web/trust_stand_in.mjs); with it applied, run it with no stand-in.
// Four throwaway accounts at Resend test addresses, never asked their age
// beforehand (mintSession's age: false), deleted at the end with all of
// theirs:
//
//   1. The pages: /terms and /guidelines, and every page's footer naming
//      them; the operator's line on /terms and the copyright agent's on
//      /takedown marked for the owner; the counter-notice there. At 390
//      and 1280 px, nothing sideways.
//   2. On the site: /profile signed in asks "When were you born?" with no
//      word of 13 before the answer. Under 13: said after, the profile form
//      off; and the server refuses a profile, a public collection, a
//      listing and a credit, in words, while sharing by link goes. A second
//      answer changes nothing.
//   3. Another account, 13 or over: asked the same, then a profile, a
//      public collection and a listing all go.
//   4. In the app: a third account is asked in the sign-in screen, under 13;
//      the screen says what that means, Start building lets them in, and
//      Share has List it in the gallery and Show who made it off, a line
//      why, and "Publishing means you agree to the guidelines", which opens
//      /guidelines. A fourth, 13 or over, is let straight in, and its Share
//      has the box to tick.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("age_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = args.out || "shots/age";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const young = `delivered+bw-age-young-${rand}@resend.dev`;
const grown = `delivered+bw-age-grown-${rand}@resend.dev`;
const appYoung = `delivered+bw-age-appyoung-${rand}@resend.dev`;
const appGrown = `delivered+bw-age-appgrown-${rand}@resend.dev`;
const now = new Date();
const thisYear = now.getUTCFullYear();
const thisMonth = now.getUTCMonth() + 1;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });
const shared = [];
const sessions = {};

async function signedInContext(email, width = 1280, height = 900) {
  const made = await mintSession(email, { age: false });
  sessions[email] = made;
  const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
  await context.addInitScript(([name, value]) => {
    try {
      if (!localStorage.getItem(name)) localStorage.setItem(name, value);
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(made.kept)]);
  return context;
}

// A file of its own: the moderation flow bars house.ldr's fingerprint while it
// runs, and a flow beside it listing the same file would be refused for that.
const house = `${readFileSync(new URL("../../models/house.ldr", import.meta.url), "utf8").trimEnd()}\r\n0 // age flow ${rand}\r\n`;
const publish = (token, extra) => api("/api/share", { method: "POST", token,
  body: { name: `Age flow ${rand}`, model: house, ...extra } });

try {
  // --- 1. The pages.
  console.log("the pages");
  // The landing page is the app's own page on a local server with --static,
  // so it is read from the file; the rest as they are served.
  const landing = readFileSync(new URL("../../web/index.html", import.meta.url), "utf8").split("<footer")[1] || "";
  check("the landing page's footer links the terms and the guidelines",
    landing.includes('href="/terms"') && landing.includes('href="/guidelines"'));
  const pages = ["/gallery", "/faq", "/download", "/changelog", "/compare", "/privacy", "/takedown",
    "/profile", "/terms", "/guidelines"];
  const plain = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  const look = await plain.newPage();
  listen(look, "pages");
  const unlinked = [];
  for (const where of pages) {
    await look.goto(`${site}${where}`, { waitUntil: "load", timeout: 60000 });
    const links = await look.evaluate(() => [...document.querySelectorAll("footer a")].map((a) => a.getAttribute("href")));
    if (!links.includes("/terms") || !links.includes("/guidelines")) unlinked.push(where);
  }
  check(`every page's footer links the terms and the guidelines (${pages.length} pages${unlinked.length ? `; not ${unlinked.join(", ")}` : ""})`,
    unlinked.length === 0);
  await look.goto(`${site}/terms`, { waitUntil: "load" });
  const terms = await look.textContent("main");
  check("/terms: a contact for questions, and no blank left showing",
    /Questions about these terms/.test(terms) && !/\[the operator’s legal name\]|To be filled in/.test(terms));
  check("/terms: says the under-13 rule and the LEGO Group's disclaimer",
    /13 or over/.test(terms) && /not made, sponsored, authorised or endorsed by the LEGO Group/.test(terms));
  await look.goto(`${site}/guidelines`, { waitUntil: "load" });
  const rules = await look.textContent("main");
  for (const [what, pattern] of [["credit", /credit/i], ["the three licences", /CC BY 4\.0[\s\S]*CC BY-SA 4\.0[\s\S]*All rights reserved/],
    ["no copying passed off", /No copying passed off as yours/], ["takedowns", /takedown requests/i],
    ["no personal photos of children", /No personal photos of children/], ["AI designer and Brickify labelled", /AI designer or with Brickify are labelled/],
    ["LEGO® only as an adjective", /as an adjective/], ["what gets a model or an account taken out", /What gets a model or an account taken out/]]) {
    check(`/guidelines: ${what}`, pattern.test(rules));
  }
  await shot(look, "1_guidelines.png", true);
  await look.goto(`${site}/takedown`, { waitUntil: "load" });
  check("/takedown: a counter-notice form, and who answers notices, with no blank left showing",
    await look.isVisible("#counter") && /reach the site's owner/.test(await look.textContent("#agent"))
      && !/To be filled in|\[name\]/.test(await look.textContent("main")));
  await look.selectOption("#why", "copied");
  check("/takedown: a copy's claim asks for a signature and the two statements", await look.isVisible("#signature")
    && await look.isVisible("#good-faith") && await look.isVisible("#accurate"));
  await shot(look, "1_takedown.png", true);
  await plain.close();
  for (const [width, height, label] of [[390, 844, "phone"], [1280, 900, "laptop"]]) {
    const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
    const page = await context.newPage();
    listen(page, `pages ${label}`);
    const wide = [];
    for (const where of ["/terms", "/guidelines", "/takedown"]) {
      await page.goto(`${site}${where}`, { waitUntil: "load" });
      if (await sideways(page)) wide.push(where);
    }
    check(`/terms, /guidelines and /takedown at ${label} width: nothing sideways${wide.length ? ` (${wide.join(", ")})` : ""}`, wide.length === 0);
    if (label === "phone") await shot(page, "1_takedown-phone.png", true);
    await context.close();
  }

  // --- 2. Under 13, on the site.
  console.log("under 13, on the site");
  const kid = await signedInContext(young, 1280, 900);
  const kidPage = await kid.newPage();
  listen(kidPage, "site, under 13");
  await kidPage.goto(`${site}/profile`, { waitUntil: "load" });
  await kidPage.waitForSelector("dialog.age[open]", { timeout: 30000 });
  // What a visitor reads: the dialog's words without its lists' options,
  // which hold every year (2013 among them) and are not read out at once.
  const asked = await kidPage.evaluate(() => {
    const copy = document.querySelector("dialog.age").cloneNode(true);
    for (const option of copy.querySelectorAll("option:not([hidden])")) option.remove();
    return copy.textContent;
  });
  check(`asked "${(await kidPage.textContent("dialog.age p")).trim()}"`, /When were you born\?/.test(asked));
  check("nothing about 13, or any age, before the answer", !/13|thirteen|old enough|must be/i.test(asked));
  await shot(kidPage, "2_site_question.png");
  await kidPage.selectOption("#age-month", String(thisMonth));
  await kidPage.selectOption("#age-year", String(thisYear - 10));
  await kidPage.click("#age-go");
  await kidPage.waitForSelector("#age-done", { timeout: 20000 });
  const after = await kidPage.textContent("dialog.age");
  check("after the answer, it says what is open and what is for 13 and over",
    /share them by link/.test(after) && /13 and over/.test(after));
  await shot(kidPage, "2_site_under_13.png");
  await kidPage.click("#age-done");
  await kidPage.waitForFunction(() => document.documentElement.dataset.profile === "ready", null, { timeout: 30000 });
  check("/profile: the profile form off, and why", await kidPage.isVisible("#young") && await kidPage.isDisabled("#save"));
  await shot(kidPage, "2_site_profile_off.png");
  const kidToken = sessions[young].access_token;
  let r = await api("/api/people?op=profile", { method: "POST", token: kidToken, body: { handle: `young-${rand}`, name: "Young Builder" } });
  check(`the server refuses a profile: ${r.status} "${r.json?.error}"`, r.status === 422 && /13 and over/.test(r.json?.error || ""));
  r = await api("/api/people?op=collection", { method: "POST", token: kidToken, body: { name: "My towers", public: true } });
  check(`a public collection: ${r.status} "${r.json?.error}"`, r.status === 422 && /13 and over/.test(r.json?.error || ""));
  r = await api("/api/people?op=collection", { method: "POST", token: kidToken, body: { name: "My towers", public: false } });
  check(`a private one goes: ${r.status}`, r.status === 200);
  r = await publish(kidToken, { listed: true });
  check(`listing a model: ${r.status} "${r.json?.error}"`, r.status === 422 && /gallery is for people 13 and over/.test(r.json?.error || ""));
  r = await publish(kidToken, { author: "Young Builder" });
  check(`a name on its link: ${r.status} "${r.json?.error}"`, r.status === 422 && /13 and over/.test(r.json?.error || ""));
  r = await publish(kidToken, {});
  if (r.json?.id) shared.push([young, r.json.id]);
  check(`shared by link, unlisted and uncredited: ${r.status}`, r.status === 201 && r.json?.listed === false);
  r = await api("/api/account?op=age", { method: "POST", token: kidToken, body: { month: 1, year: 1990 } });
  check(`answered again as grown up: the first answer stands (${JSON.stringify(r.json?.age)})`, r.status === 200 && r.json?.age?.over_13 === false);
  await kid.close();

  // --- 3. 13 or over, on the site.
  console.log("13 or over, on the site");
  const adult = await signedInContext(grown, 390, 844);
  const adultPage = await adult.newPage();
  listen(adultPage, "site, 13 or over");
  await adultPage.goto(`${site}/profile`, { waitUntil: "load" });
  await adultPage.waitForSelector("dialog.age[open]", { timeout: 30000 });
  check("asked the same question, at a phone's width, nothing sideways", /When were you born\?/.test(await adultPage.textContent("dialog.age"))
    && !(await sideways(adultPage)));
  await shot(adultPage, "3_site_question_phone.png");
  await adultPage.selectOption("#age-month", "3");
  await adultPage.selectOption("#age-year", String(thisYear - 30));
  await adultPage.click("#age-go");
  // 13 or over: First steps next (docs/SOCIAL.md U10), every one skippable;
  // tools/web/first_steps_flow.mjs is about them. Skipped here, to the page.
  const steps = await adultPage.waitForSelector("dialog.first-steps[open]", { timeout: 30000 }).then(() => true).catch(() => false);
  check("then First steps, nothing about age in them", steps && !/13|born/.test(await adultPage.textContent("dialog.first-steps")));
  for (const step of ["profile", "kinds"]) {
    await adultPage.waitForFunction((want) => document.querySelector("dialog.first-steps")?.dataset.step === want, step, { timeout: 30000 })
      .catch(() => {});
    if (await adultPage.isVisible("#first-skip")) await adultPage.click("#first-skip");
  }
  await adultPage.waitForSelector("#first-done", { timeout: 30000 }).then(() => adultPage.click("#first-done")).catch(() => {});
  await adultPage.waitForFunction(() => document.documentElement.dataset.profile === "ready", null, { timeout: 30000 });
  check("let straight on: no dialog, the profile form on", !(await adultPage.isVisible("dialog.age"))
    && !(await adultPage.isVisible("dialog.first-steps"))
    && !(await adultPage.isVisible("#young")) && !(await adultPage.isDisabled("#save")));
  await adultPage.fill("#name", "Grown Builder");
  await adultPage.fill("#handle", `grown-${rand}`);
  await adultPage.click("#save");
  await adultPage.waitForFunction(() => /Saved|not|refused|13/.test(document.getElementById("profile-said").textContent), null, { timeout: 20000 }).catch(() => {});
  check(`a profile saved from the page: "${await adultPage.textContent("#profile-said")}"`, /Saved/.test(await adultPage.textContent("#profile-said")));
  const grownToken = sessions[grown].access_token;
  r = await api("/api/people?op=collection", { method: "POST", token: grownToken, body: { name: "Towers", public: true } });
  check(`a public collection: ${r.status}`, r.status === 200 && r.json?.public === true);
  r = await publish(grownToken, { listed: true, author: "Grown Builder" });
  if (r.json?.id) shared.push([grown, r.json.id]);
  check(`listed and credited: ${r.status}`, r.status === 201 && r.json?.listed === true && r.json?.author === "Grown Builder");
  await adult.close();

  // --- 4. In the app.
  console.log("in the app");
  const appKid = await signedInContext(appYoung, 1400, 900);
  const app = await appKid.newPage();
  listen(app, "app, under 13");
  const controls = () => app.evaluate(() => window.brickworksControls || {});
  const until = async (test, what, seconds = 240, arg = null) => {
    const end = Date.now() + seconds * 1000;
    for (;;) {
      const value = await app.evaluate(test, arg).catch(() => null);
      if (value) return value;
      if (Date.now() > end) {
        // What the app said, and a picture, so a timeout says why.
        const said = await app.evaluate(() => JSON.stringify({ account: window.brickworksAccount,
          controls: Object.keys(window.brickworksControls || {}).slice(0, 12) })).catch((e) => String(e));
        await shot(app, `timeout_${what.replace(/\W+/g, "_").slice(0, 40)}.png`).catch(() => {});
        throw new Error(`${what}: not within ${seconds} s; the app said ${said}`);
      }
      await app.waitForTimeout(500);
    }
  };
  const press = async (name, page = app) => {
    const end = Date.now() + 60000;
    for (;;) {
      let at = (await page.evaluate(() => window.brickworksControls || {}))[name];
      for (let n = 0; at && n < 6; n += 1) {
        await page.waitForTimeout(550);
        const again = (await page.evaluate(() => window.brickworksControls || {}))[name];
        if (again && again.x === at.x && again.y === at.y) break;
        at = again;
      }
      if (at) {
        await page.mouse.click(at.x, at.y);
        await page.waitForTimeout(400);
        return at;
      }
      if (Date.now() > end) throw new Error(`no ${name} on the page`);
      await page.waitForTimeout(500);
    }
  };
  await app.goto(`${site}/app`, { waitUntil: "load", timeout: 120000 });
  await until(() => (window.brickworksAccount || {}).age_ask === true && window.brickworksAccount.gated, "the age question in the sign-in screen");
  // The page is told where a control is once two of the app's reports agree.
  await until(() => Object.keys(window.brickworksControls || {}).includes("age_go"), "the question's controls", 60);
  const gateControls = Object.keys(await controls());
  check(`the sign-in screen asks it, and only it can be pressed (${gateControls.length} controls)`,
    gateControls.includes("age_month_1") && gateControls.includes("age_year") && gateControls.includes("age_go")
    && !gateControls.includes("tool_share"));
  await shot(app, "4_app_question.png");
  await press(`age_month_${thisMonth}`);
  await press("age_year");
  await app.keyboard.type(String(thisYear - 9), { delay: 30 });
  // Keys reach the field a frame at a time; a click straight after can land first.
  await app.waitForTimeout(1500);
  await press("age_go");
  await until(() => Object.keys(window.brickworksControls || {}).includes("age_done"), "what under 13 means", 60);
  await shot(app, "4_app_under_13.png");
  await press("age_done");
  await until(() => !(window.brickworksAccount || {}).gated && window.brickworksAccount.over_13 === false, "let in", 60);
  check("Start building lets them in, kept under 13", true);
  await press("tool_share");
  await until(() => ((window.brickworksShare || {}).panel || {}).open, "the Share panel", 60);
  const panel = await app.evaluate(() => window.brickworksShare.panel);
  check(`Share: List it in the gallery and Show who made it off, with a line why (${JSON.stringify({
    list: panel.list_disabled, credit: panel.credit_disabled, young: panel.young })})`,
    panel.list_disabled === true && panel.credit_disabled === true && panel.young === true);
  const beside = await until(() => Object.keys(window.brickworksControls || {}).includes("share_guidelines"),
    "the guidelines beside Publish", 60).catch(() => false);
  const placed = await controls();
  const [publishAt, agreeAt, nameAt] = [placed.share_publish, placed.share_guidelines, placed.share_name];
  check(`"Publishing means you agree to the guidelines" just under Publish (${panel.guidelines}; at ${agreeAt?.y}, Publish ${publishAt?.y})`,
    Boolean(beside) && /\/guidelines$/.test(panel.guidelines || "") && publishAt && agreeAt
    && agreeAt.y > publishAt.y && agreeAt.y - publishAt.y < 60);
  check("the rest of the panel laid out above it as before", Boolean(nameAt) && nameAt.y < publishAt.y);
  await shot(app, "4_app_share_under_13.png");
  const opened = appKid.waitForEvent("page", { timeout: 30000 }).catch(() => null);
  await press("share_guidelines");
  const tab = await opened;
  if (tab) await tab.waitForLoadState("load").catch(() => {});
  check(`pressed, it opens the guidelines (${tab ? tab.url() : "nothing opened"})`,
    Boolean(tab) && /\/guidelines$/.test(tab.url()) && /Community guidelines/.test(await tab.textContent("h1").catch(() => "")));
  await appKid.close();

  const appAdult = await signedInContext(appGrown, 1400, 900);
  const app2 = await appAdult.newPage();
  listen(app2, "app, 13 or over");
  await app2.goto(`${site}/app`, { waitUntil: "load", timeout: 120000 });
  const until2 = async (test, what, seconds = 240) => {
    const end = Date.now() + seconds * 1000;
    for (;;) {
      const value = await app2.evaluate(test).catch(() => null);
      if (value) return value;
      if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
      await app2.waitForTimeout(500);
    }
  };
  await until2(() => (window.brickworksAccount || {}).age_ask === true, "the age question");
  await press("age_month_6", app2);
  await press("age_year", app2);
  await app2.keyboard.type(String(thisYear - 40), { delay: 30 });
  await app2.waitForTimeout(1500);
  await press("age_go", app2);
  await until2(() => !(window.brickworksAccount || {}).gated && window.brickworksAccount.over_13 === true, "let in", 60);
  check("13 or over: let straight in, nothing more said", true);
  await press("tool_share", app2);
  await until2(() => ((window.brickworksShare || {}).panel || {}).open, "the Share panel", 60);
  const open = await app2.evaluate(() => window.brickworksShare.panel);
  check(`Share: the box to tick, and a name to show (${JSON.stringify({ list: open.list_disabled, credit: open.credit_disabled, young: open.young })})`,
    open.list_disabled === false && open.credit_disabled === false && open.young === false);
  await shot(app2, "4_app_share_13_or_over.png");
  await appAdult.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const line of errors.slice(0, 6)) console.log(`        ${line}`);
  await browser.close();
  for (const [email, id] of shared) {
    const token = sessions[email]?.access_token;
    if (token) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token });
  }
  let gone = 0;
  const made = Object.keys(sessions);
  for (const email of made) if (await deleteAccount(email)) gone += 1;
  check(`the accounts made deleted, and everything of theirs with them (${gone} of ${made.length})`, gone === made.length);
}
console.log(failed ? `${failed} FAILED` : "the age question is asked neutrally, and what it answers holds on the site, in the app and on the server");
process.exit(failed ? 1 : 0);
