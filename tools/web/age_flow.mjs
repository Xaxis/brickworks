// The ground rules (2026-10-18), in a real browser: the terms and the
// guidelines on every page, the age question on the site and in the app,
// and the guidelines beside Publish. Accounts are for 13 and over
// (2026-11-03): an answer under 13 deletes the account just made, with its
// address, and the browser keeps only that it was told; an answer of 13 or
// over lets them in.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 --static=build/web --trust-stand-in &
//   BW_STAND_IN=http://127.0.0.1:8790 node tools/web/age_flow.mjs --url=http://127.0.0.1:8790 --out=shots/age
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/age_flow.mjs --url=<deployment> --out=shots/age   # once trust.sql is applied
//
// --trust-stand-in answers supabase/trust.sql's five functions in the local
// server's own memory until the file is applied to the project
// (tools/web/trust_stand_in.mjs); with it applied, run it with no stand-in.
// Throwaway accounts at Resend test addresses, never asked their age
// beforehand (mintSession's age: false); the ones under 13 are deleted by
// the answer, the rest at the end with all of theirs:
//
//   1. The pages: /terms and /guidelines, and every page's footer naming
//      them; the operator's line on /terms and the copyright agent's on
//      /takedown marked for the owner; the counter-notice there; /terms,
//      /privacy and the FAQ saying accounts are for 13 and over. At 390
//      and 1280 px, nothing sideways.
//   2. On the site: /profile signed in asks "When were you born?" with no
//      word of 13 before the answer. Under 13: the dialog says accounts are
//      for 13 and over and to ask a parent or guardian; the account is gone
//      (its auth user and profile, read through the admin API), and no row
//      holds its address (the codes' count); its token saves nothing and
//      shares nothing, and a second answer brings nothing back; the browser
//      keeps "1" and no sign-in. A retry there: Sign in says so at once, and
//      a new account signed in there is not asked but deleted the same way.
//   3. Another account, 13 or over: asked the same, then a profile, a
//      public collection and a listing all go.
//   4. In the app: a third account is asked in the sign-in screen, under 13;
//      the account is gone, the screen back at the way in saying so, the
//      browser told; reloaded, it says so at once, and a new account is not
//      asked but deleted. A fourth, 13 or over, is let straight in, and its
//      Share has the box to tick, a name to show, and "Publishing means you
//      agree to the guidelines" just under Publish, which opens /guidelines.
import { clickStill, launch } from "./browser.mjs";
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
const youngAgain = `delivered+bw-age-again-${rand}@resend.dev`;
const grown = `delivered+bw-age-grown-${rand}@resend.dev`;
const appYoung = `delivered+bw-age-appyoung-${rand}@resend.dev`;
const appAgain = `delivered+bw-age-appagain-${rand}@resend.dev`;
const appGrown = `delivered+bw-age-appgrown-${rand}@resend.dev`;
// What somebody under 13 is told (api/_trust.js TOO_YOUNG), and the key the
// browser keeps that it was told under (web/account.js REFUSED).
const TOO_YOUNG = "Brickworks accounts are for 13 and over. Ask a parent or guardian to sign in with their own email "
  + "and build with you.";
const REFUSED = "brickworks.age_refused";
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

// A browser whose sign-ins are put in by hand, so that one deleted stays
// gone: an account under 13 is signed out by its answer, and a session an
// init script put back at every page would be its again.
async function plainContext(width = 1280, height = 900) {
  return browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers });
}
// [email]'s session put where this browser keeps one: asked for by its
// code first, as a person signs in, so the codes' count holds its address.
async function signIn(page, email) {
  const asked = await api("/api/otp", { method: "POST", body: { email } });
  const made = await mintSession(email, { age: false });
  sessions[email] = made;
  await page.evaluate(([name, value]) => {
    sessionStorage.clear();
    localStorage.setItem(name, value);
  }, [STORAGE_KEY, JSON.stringify(made.kept)]);
  return asked.status;
}
// What is left of an account, read through the admin API: its auth user
// (200, or 404 gone), its profile's rows, and the rows of the codes' count
// that hold its address (api/otp.js may_ask_for_code).
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const ADMIN = { apikey: process.env.SUPABASE_SECRET_KEY, authorization: `Bearer ${process.env.SUPABASE_SECRET_KEY}` };
async function leftOf(email) {
  const id = sessions[email]?.kept?.user_id;
  const user = await fetch(`${SUPABASE}/auth/v1/admin/users/${id}`, { headers: ADMIN });
  const profile = await (await fetch(`${SUPABASE}/rest/v1/profiles?id=eq.${id}&select=id`, { headers: ADMIN })).json();
  const codes = await (await fetch(`${SUPABASE}/rest/v1/otp_requests?email=eq.${encodeURIComponent(email)}&select=asked_at`,
    { headers: ADMIN })).json();
  return { user: user.status, profiles: Array.isArray(profile) ? profile.length : -1, codes: Array.isArray(codes) ? codes.length : -1 };
}
const gone = (left) => left.user === 404 && left.profiles === 0 && left.codes === 0;
const kept = (page) => page.evaluate(([flag, session]) => ({ flag: localStorage.getItem(flag),
  session: localStorage.getItem(session) }), [REFUSED, STORAGE_KEY]);

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
  check("/terms: accounts are for 13 and over, an answer under 13 deletes the account, and the LEGO Group's disclaimer",
    /accounts are for people 13 and over/.test(terms) && /Under 13, the account just made is deleted at once/.test(terms)
      && !/Under 13, you can build/.test(terms)
      && /not made, sponsored, authorised or endorsed by the LEGO Group/.test(terms));
  await look.goto(`${site}/privacy`, { waitUntil: "load" });
  check("/privacy: Children, accounts for 13 and over, nothing kept of anyone under 13",
    /Brickworks accounts are for people 13 and over, and Brickworks keeps no personal information about anyone under 13/
      .test(await look.textContent("#children + p").catch(() => "")));
  await look.goto(`${site}/faq`, { waitUntil: "load" });
  check("/faq: Can children use Brickworks? With a parent or guardian",
    /With a parent or guardian\. Brickworks accounts are for people 13 and over/.test(await look.textContent("#age").catch(() => "")));
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
  const kid = await plainContext(1280, 900);
  const kidPage = await kid.newPage();
  listen(kidPage, "site, under 13");
  await kidPage.goto(`${site}/terms`, { waitUntil: "load" });
  const asked = await signIn(kidPage, young);
  check(`a code asked for first, as a person signs in: ${asked}`, asked === 200);
  check(`before the answer the account is there (${JSON.stringify(await leftOf(young))})`, (await leftOf(young)).user === 200);
  await kidPage.goto(`${site}/profile`, { waitUntil: "load" });
  await kidPage.waitForSelector("dialog.age[open]", { timeout: 30000 });
  // What a visitor reads: the dialog's words without its lists' options,
  // which hold every year (2013 among them) and are not read out at once.
  const question = await kidPage.evaluate(() => {
    const copy = document.querySelector("dialog.age").cloneNode(true);
    for (const option of copy.querySelectorAll("option:not([hidden])")) option.remove();
    return copy.textContent;
  });
  check(`asked "${(await kidPage.textContent("dialog.age p")).trim()}"`, /When were you born\?/.test(question));
  check("nothing about 13, or any age, before the answer", !/13|thirteen|old enough|must be/i.test(question));
  await shot(kidPage, "2_site_question.png");
  await kidPage.selectOption("#age-month", String(thisMonth));
  await kidPage.selectOption("#age-year", String(thisYear - 10));
  await kidPage.click("#age-go");
  await kidPage.waitForSelector("#age-done", { timeout: 30000 });
  const told = await kidPage.textContent("dialog.age");
  check(`after the answer: "${(await kidPage.textContent("#age-refused")).trim()}"`,
    (await kidPage.textContent("#age-refused")).trim() === TOO_YOUNG && /Accounts are for 13 and over/.test(told)
      && /The account is deleted, with your email address\. The date was never kept\./.test(told));
  check("...and nothing says what is open on the account", !/share them by link|Carry on|You can build here/.test(told));
  await shot(kidPage, "2_site_under_13.png");
  const left = await leftOf(young);
  check(`the account is gone: auth user ${left.user}, ${left.profiles} profile rows, ${left.codes} rows holding its address`, gone(left));
  const browserKept = await kept(kidPage);
  check(`the browser keeps that it was told ("${browserKept.flag}"), and no sign-in (${browserKept.session ? "one left" : "none"})`,
    browserKept.flag === "1" && !browserKept.session);
  const kidToken = sessions[young].access_token;
  const house64 = (await import("node:zlib")).gzipSync(Buffer.from(house)).toString("base64");
  let r = await api("/api/models", { method: "POST", token: kidToken, body: { name: `Age flow ${rand}`, base: 0, model: house64 } });
  check(`its token saves nothing to an account: ${r.status}`, r.status !== 200);
  r = await publish(kidToken, {});
  if (r.json?.id) shared.push([young, r.json.id]);
  check(`...and shares nothing by link: ${r.status}`, r.status !== 201);
  r = await api("/api/account?op=age", { method: "POST", token: kidToken, body: { month: 1, year: 1990 } });
  check(`answered again as grown up: nothing comes back (${r.status})`, !(r.status === 200 && r.json?.age?.over_13 === true));
  check(`...and still nothing is kept (${JSON.stringify(await leftOf(young))})`, gone(await leftOf(young)));
  await kidPage.click("#age-done");
  await kidPage.waitForFunction(() => document.documentElement.dataset.profile === "signed-out", null, { timeout: 30000 });
  check("closed, the page is signed out", await kidPage.isVisible("#signed-out"));
  // A retry in the same browser: told at once, before an address is typed.
  await kidPage.click("#sign-in");
  await kidPage.waitForSelector("dialog.sign-in[open] #age-refused", { timeout: 30000 });
  check(`a retry here is told at once: "${(await kidPage.textContent("dialog.sign-in #age-refused")).trim().slice(0, 60)}…"`,
    (await kidPage.textContent("dialog.sign-in #age-refused")).trim() === TOO_YOUNG
      && await kidPage.isVisible("dialog.sign-in input[type=email]"));
  await shot(kidPage, "2_site_retry.png");
  await kidPage.keyboard.press("Escape");
  // And a new account signed in here is not asked again, but goes the same way.
  await signIn(kidPage, youngAgain);
  await kidPage.goto(`${site}/profile`, { waitUntil: "load" });
  await kidPage.waitForSelector("#age-done", { timeout: 30000 });
  check("a new account signed in here is not asked: no question, the refusal at once",
    !(await kidPage.isVisible("#age-go")) && (await kidPage.textContent("#age-refused")).trim() === TOO_YOUNG);
  const again = await leftOf(youngAgain);
  check(`...and it is gone too: auth user ${again.user}, ${again.profiles} profile rows, ${again.codes} rows holding its address`, gone(again));
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
  const appKid = await plainContext(1400, 900);
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
  const press = (name, page = app) => clickStill(page, name, { seconds: 60, after: 400 });
  await app.goto(`${site}/terms`, { waitUntil: "load" });
  await signIn(app, appYoung);
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
  const after = await until(() => {
    const a = window.brickworksAccount || {};
    return a.state === "signed_out" && a.refused === true && a.refused_now === true && a.gated ? a : null;
  }, "the way in again, told", 60);
  check(`under 13: signed out at the way in, told (${JSON.stringify({ state: after.state, refused: after.refused, gated: after.gated })})`, true);
  await until(() => Object.keys(window.brickworksControls || {}).includes("signin_email"), "the form, for a parent", 60);
  check("...with the form there for a parent, and no question", !Object.keys(await controls()).includes("age_go"));
  await shot(app, "4_app_under_13.png");
  const appLeft = await leftOf(appYoung);
  check(`the account is gone: auth user ${appLeft.user}, ${appLeft.profiles} profile rows, ${appLeft.codes} rows holding its address`, gone(appLeft));
  const appKept = await kept(app);
  check(`the browser keeps that it was told ("${appKept.flag}"), and no sign-in (${appKept.session ? "one left" : "none"})`,
    appKept.flag === "1" && !appKept.session);
  // A retry: the app opened again here says so at once.
  await app.reload({ waitUntil: "load", timeout: 120000 });
  const retry = await until(() => {
    const a = window.brickworksAccount || {};
    return a.state === "signed_out" && a.refused === true && a.gated ? a : null;
  }, "the way in, told at once", 240);
  check(`opened again, the way in says so at once (refused ${retry.refused}, the account just deleted ${retry.refused_now})`,
    retry.refused === true && retry.refused_now === false);
  await shot(app, "4_app_retry.png");
  // And a new account signed in here is not asked, but deleted the same way.
  await signIn(app, appAgain);
  await app.reload({ waitUntil: "load", timeout: 120000 });
  let askedAgain = false;
  await until(() => {
    const a = window.brickworksAccount || {};
    return a.state === "signed_out" && a.refused_now === true ? a : null;
  }, "the new account refused", 240).catch(() => null);
  askedAgain = Object.keys(await controls()).includes("age_go");
  const appAgainLeft = await leftOf(appAgain);
  check(`a new account signed in here is not asked (${askedAgain ? "asked" : "not asked"}), and is gone: auth user ${appAgainLeft.user}, `
    + `${appAgainLeft.profiles} profile rows, ${appAgainLeft.codes} rows holding its address`, !askedAgain && gone(appAgainLeft));
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
  const beside = await until2(() => Object.keys(window.brickworksControls || {}).includes("share_guidelines"),
    "the guidelines beside Publish", 60).catch(() => false);
  const placed = await app2.evaluate(() => window.brickworksControls || {});
  const [publishAt, agreeAt, nameAt] = [placed.share_publish, placed.share_guidelines, placed.share_name];
  check(`"Publishing means you agree to the guidelines" just under Publish (${open.guidelines}; at ${agreeAt?.y}, Publish ${publishAt?.y})`,
    Boolean(beside) && /\/guidelines$/.test(open.guidelines || "") && publishAt && agreeAt
    && agreeAt.y > publishAt.y && agreeAt.y - publishAt.y < 60);
  check("the rest of the panel laid out above it as before", Boolean(nameAt) && nameAt.y < publishAt.y);
  await shot(app2, "4_app_share_13_or_over.png");
  const opened = appAdult.waitForEvent("page", { timeout: 30000 }).catch(() => null);
  await press("share_guidelines", app2);
  const tab = await opened;
  if (tab) await tab.waitForLoadState("load").catch(() => {});
  check(`pressed, it opens the guidelines (${tab ? tab.url() : "nothing opened"})`,
    Boolean(tab) && /\/guidelines$/.test(tab.url()) && /Community guidelines/.test(await tab.textContent("h1").catch(() => "")));
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
  // Those under 13 went with their answer; the rest go now.
  const answered = [young, youngAgain, appYoung, appAgain];
  let deleted = 0;
  const made = Object.keys(sessions).filter((email) => !answered.includes(email));
  for (const email of made) if (await deleteAccount(email)) deleted += 1;
  const left = (await Promise.all(Object.keys(sessions).filter((email) => answered.includes(email))
    .map((email) => deleteAccount(email)))).filter(Boolean).length;
  check(`the accounts made deleted, and everything of theirs with them (${deleted} of ${made.length}; `
    + `${left} under 13 left to delete)`, deleted === made.length && left === 0);
}
console.log(failed ? `${failed} FAILED` : "the age question is asked neutrally; under 13 nothing is kept, and 13 or over holds on the site, in the app and on the server");
process.exit(failed ? 1 : 0);
