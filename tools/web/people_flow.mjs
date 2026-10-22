// People in the directory, in a real browser against a deployment: a
// visitor signs in from a model's Like button, likes it, keeps it, puts it
// in a collection of their own, chooses the name the gallery shows for
// them, makes the collection public; and the profile and collection pages
// show what they should, at a phone's width and a laptop's.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/people_flow.mjs --url=<deployment> --out=shots/people
//
// As a person does it, by pressing what the pages show:
//
//   1. An owner (a throwaway account, signed in on the test side) shares a
//      house with a picture, credited and listed, and makes a profile.
//   2. A visitor who has never signed in opens its page, presses Like: the
//      sign-in dialog, their address, Email me a code (one code sent to a
//      Resend test address that delivers nowhere; a fresh one minted on the
//      test side, as the tests sign in), the code, Sign in — and the like
//      goes through, the count with it. Favourite. Add to a collection, a
//      new one named, made and ticked.
//   3. /profile: their address said, no name yet; a name and a handle
//      chosen and saved; the house in their favourites; the collection,
//      made public, with a page of its own.
//   4. /c/<id>: the collection's page, the house in it, its maker's name.
//      /u/<owner>: the owner's profile, the house credited to them.
//   5. Each page at 390 and 1280 px: no console error, no refused request,
//      nothing scrolling sideways.
//   6. /profile again, as the home it is: their name and their page at the
//      top, its sections, the header saying Account; then Delete this
//      account, their address typed to confirm, and they are signed out and
//      gone from the sign-in service (api/account.js ?op=delete).
//
// The owner's account is deleted at the end, and everything of theirs with
// it; the house is taken down first, so no file is left. Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("people_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = args.out || "shots/people";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
// Never Vercel's preview toolbar, which it puts in a page for a browser that
// says it is a person's, and which the site's own policy refuses.
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const PERSON = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const rand = randomBytes(4).toString("hex");
const ownerEmail = `delivered+bw-people-owner-${rand}@resend.dev`;
const visitorEmail = `delivered+bw-people-visitor-${rand}@resend.dev`;
const ownerHandle = `flow-owner-${rand}`;
const visitorHandle = `flow-visitor-${rand}`;
const LIST = `Houses I like ${rand}`;

// Step 6 deletes the visitor's account from its own page.
let visitorId = "";
let deletedByPage = false;

/// Whether the sign-in service has an account at [email].
async function accountExists(email) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const listed = await (await fetch(`${base}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` } })).json();
  return (listed.users || []).some((u) => (u.email || "").toLowerCase() === email.toLowerCase());
}

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
    if (m.type() === "error" || /Content Security Policy|Refused to/.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
}
const shot = (page, name, full = true) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

async function sideways(page) {
  return page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
}

let modelId = "";
let owner = null;
const browser = await launch({ signedOut: true });
try {
  // --- 1. The owner shares a house, credited and listed, and has a profile.
  console.log("the owner shares a house and has a profile");
  owner = await mintSession(ownerEmail);
  const house = readFileSync(new URL("../../models/house.ldr", import.meta.url), "utf8");
  const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
  let r = await api("/api/share", { method: "POST", token: owner.access_token, body: { name: `Flow House ${rand}`,
    author: "Flow Owner", model: house, image: picture, listed: true, kind: "town", tags: "house, flow test",
    description: "A small house, shared by the people flow.", licence: "cc-by-4.0" } });
  modelId = r.json?.id || "";
  check(`shared and listed: ${r.status} ${modelId}`, r.status === 201 && /^[A-Za-z0-9]{10}$/.test(modelId));
  r = await api("/api/people?op=profile", { method: "POST", token: owner.access_token,
    body: { handle: ownerHandle, name: "Flow Owner", bio: "Builds houses for the people flow." } });
  check(`the owner's profile: /u/${r.json?.handle}`, r.status === 200 && r.json?.handle === ownerHandle);

  // --- 2. A visitor, signed out, likes it from its page.
  console.log("a visitor likes it from its page, signing in on the way");
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers,
    userAgent: PERSON });
  const page = await context.newPage();
  listen(page, "visitor");
  await page.goto(`${site}/m/${modelId}`, { waitUntil: "load", timeout: 60000 });
  await page.waitForSelector("#marks:not([hidden])", { timeout: 20000 });
  const shared = await page.evaluate(() => (document.querySelector(".shared-by a") || {}).getAttribute?.("href") || "");
  check(`the page says who shared it, a link to their profile (${shared})`, shared === `/u/${ownerHandle}`);
  await page.click('[data-mark="like"]');
  await page.waitForSelector("dialog.sign-in[open]", { timeout: 15000 });
  await shot(page, "1_sign_in_dialog.png", false);
  await page.fill("dialog.sign-in input", visitorEmail);
  await page.click('dialog.sign-in button[type="submit"]');
  await page.waitForFunction(() => /The code sent to/.test(document.querySelector("dialog.sign-in label")?.textContent || "")
    || /Too many|Could not|not/.test(document.querySelector("dialog.sign-in .said")?.textContent || ""), null, { timeout: 30000 });
  const asked = await page.evaluate(() => ({ label: document.querySelector("dialog.sign-in label")?.textContent || "",
    said: document.querySelector("dialog.sign-in .said")?.textContent || "" }));
  check(`a code asked for: "${asked.label.slice(0, 60)}" ${asked.said}`, asked.label.includes(visitorEmail));
  // As the tests sign in: the code minted here, replacing the one sent.
  const code = await mintCode(visitorEmail);
  await page.fill("dialog.sign-in input", code);
  await page.click('dialog.sign-in button[type="submit"]');
  // Once supabase/trust.sql is applied, a new account is asked its age once
  // after signing in (web/account.js), before the like goes: 13 or over here
  // (tools/web/age_flow.mjs is about the question itself).
  if (await page.waitForSelector("dialog.age[open]", { timeout: 8000 }).then(() => true).catch(() => false)) {
    await page.selectOption("#age-month", "3");
    // The year is a dropdown, as the month is (c98af5bd).
    await page.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
    await page.click("#age-go");
    check("asked its age once, after signing in", true);
  }
  await page.waitForFunction(() => document.querySelector('[data-mark="like"]')?.getAttribute("aria-pressed") === "true",
    null, { timeout: 30000 }).catch(() => {});
  let state = await page.evaluate(() => ({
    like: document.querySelector('[data-mark="like"]').textContent,
    pressed: document.querySelector('[data-mark="like"]').getAttribute("aria-pressed"),
    likes: document.querySelector('[data-count="likes"]').textContent,
    dialog: Boolean(document.querySelector("dialog.sign-in")),
    kept: Boolean(JSON.parse(localStorage.getItem("brickworks.session") || "null")?.refresh_token),
  }));
  check(`signed in, and the like went through: ${state.like}, ${state.likes}`,
    !state.dialog && state.pressed === "true" && state.likes === "1 like" && state.kept);
  await page.click('[data-mark="favourite"]');
  await page.waitForFunction(() => document.querySelector('[data-mark="favourite"]')?.getAttribute("aria-pressed") === "true",
    null, { timeout: 15000 }).catch(() => {});
  check("kept in their favourites", (await page.textContent('[data-mark="favourite"]')) === "In your favourites");
  await page.click("details.collect summary");
  await page.fill("form.collect-new input", LIST);
  await page.click('form.collect-new button[type="submit"]');
  await page.waitForFunction((name) => [...document.querySelectorAll(".collect-list label")]
    .some((l) => l.textContent.includes(name) && l.querySelector("input").checked), LIST, { timeout: 15000 }).catch(() => {});
  const listed = await page.evaluate(() => [...document.querySelectorAll(".collect-list label")]
    .map((l) => `${l.querySelector("span").textContent}:${l.querySelector("input").checked}`));
  check(`a collection made and the house in it: ${listed.join(", ")}`, listed.includes(`${LIST}:true`));
  check("the collection panel open at 1280 px: nothing sideways", !(await sideways(page)));
  await shot(page, "2_model_marked-laptop.png", false);

  // --- 3. /profile
  console.log("their profile page");
  await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 60000 });
  await page.waitForFunction(() => document.documentElement.dataset.profile, null, { timeout: 30000 }).catch(() => {});
  state = await page.evaluate(() => ({ ready: document.documentElement.dataset.profile,
    who: document.getElementById("who").textContent, name: document.getElementById("name").value,
    favourites: [...document.querySelectorAll("#favourites a.model")].map((a) => a.dataset.id),
    lists: [...document.querySelectorAll("#lists .list-mine input:not([type=checkbox])")].map((i) => i.value) }));
  check(`signed in there too, its address said and no name made from it (${state.who.slice(0, 50)}, "${state.name}")`,
    state.ready === "ready" && state.who.includes(visitorEmail) && state.name === "");
  check(`the house in their favourites, and their collection (${state.favourites.length}, ${state.lists.join(", ")})`,
    state.favourites.includes(modelId) && state.lists.includes(LIST));
  await page.fill("#name", "Flow Visitor");
  await page.fill("#handle", visitorHandle);
  await page.fill("#bio", "Looks at houses.");
  await page.click("#save");
  await page.waitForFunction(() => /Saved|handle|name/.test(document.getElementById("profile-said").textContent), null, { timeout: 15000 }).catch(() => {});
  check(`a name and a handle saved: "${await page.textContent("#profile-said")}"`,
    (await page.textContent("#profile-said")) === "Saved." && (await page.getAttribute("#view", "href")) === `/u/${visitorHandle}`);
  const listId = await page.evaluate((name) => [...document.querySelectorAll("#lists .list-mine")]
    .find((one) => one.querySelector(".list-top input").value === name)?.dataset.id || "", LIST);
  const row = page.locator(`#lists .list-mine[data-id="${listId}"]`);
  await row.locator('input[type="checkbox"]').check();
  await row.locator("button", { hasText: "Save" }).click();
  await page.waitForFunction(() => /Saved/.test(document.getElementById("lists-said").textContent), null, { timeout: 15000 }).catch(() => {});
  check(`the collection made public, with a page: /c/${listId}`, /^[A-Za-z0-9]{10}$/.test(listId || "")
    && !(await row.locator("a", { hasText: "Its page" }).isHidden()));
  await shot(page, "3_profile-laptop.png");

  // --- 4. The pages anybody sees. Asked with tests=1: the owner signed in
  // at a test address, so the house is a test model, which a page shows
  // nobody who does not ask (api/people.js).
  console.log("the collection's page and the owner's profile, signed out");
  const stranger = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  const look = await stranger.newPage();
  listen(look, "stranger");
  await look.goto(`${site}/c/${listId}?tests=1`, { waitUntil: "load", timeout: 60000 });
  state = await look.evaluate(() => ({ title: document.querySelector("h1")?.textContent,
    by: document.querySelector(".handle")?.textContent, cards: [...document.querySelectorAll("a.model")].map((a) => a.dataset.id) }));
  check(`/c/${listId}: "${state.title}", ${state.by}, the house in it`, state.title === LIST && state.cards.includes(modelId)
    && /Flow Visitor/.test(state.by || ""));
  await shot(look, "4_collection-laptop.png");
  await look.goto(`${site}/u/${ownerHandle}?tests=1`, { waitUntil: "load", timeout: 60000 });
  state = await look.evaluate(() => ({ title: document.querySelector("h1")?.textContent,
    cards: [...document.querySelectorAll("a.model")].map((a) => a.dataset.id) }));
  check(`/u/${ownerHandle}: "${state.title}", the house credited to them`, state.title === "Flow Owner" && state.cards.includes(modelId));
  await shot(look, "5_profile_public-laptop.png");
  // Nothing of theirs in the gallery, a public list: their page opens on
  // its Collections tab, and its Models tab says what goes there.
  await look.goto(`${site}/u/${visitorHandle}`, { waitUntil: "load", timeout: 60000 });
  state = await look.evaluate(() => ({ lists: [...document.querySelectorAll(".list-card b")].map((b) => b.textContent),
    tab: document.querySelector(".tabs [aria-current=page]")?.dataset.tab || "" }));
  await look.click('.tabs a[data-tab="models"]');
  await look.waitForLoadState("load");
  state.none = await look.evaluate(() => document.querySelector(".tab-panel .state")?.textContent || "");
  check(`/u/${visitorHandle}: their public collection (the ${state.tab} tab), and nothing of theirs in the gallery yet`,
    state.tab === "collections" && state.lists.includes(LIST) && /Nothing in the gallery/.test(state.none));

  // --- 5. At a phone's width.
  console.log("at 390 px");
  const phone = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2,
    extraHTTPHeaders: headers, userAgent: PERSON });
  const kept = await page.evaluate(() => localStorage.getItem("brickworks.session"));
  await phone.addInitScript((value) => { try { localStorage.setItem("brickworks.session", value); } catch {} }, kept);
  const small = await phone.newPage();
  listen(small, "phone");
  for (const [where, name] of [[`/m/${modelId}`, "model"], ["/profile", "profile"], [`/c/${listId}?tests=1`, "collection"],
    [`/u/${ownerHandle}?tests=1`, "profile_public"]]) {
    await small.goto(site + where, { waitUntil: "load", timeout: 60000 });
    await small.waitForTimeout(1500);
    if (name === "model") await small.click("details.collect summary").catch(() => {});
    check(`${where} at 390 px: nothing sideways`, !(await sideways(small)));
    await shot(small, `6_${name}-phone.png`);
  }
  await phone.close();

  // --- 6. The account page as a home, then the account deleted from it.
  console.log("their account page, and deleting the account from it");
  await page.goto(`${site}/profile`, { waitUntil: "load", timeout: 60000 });
  await page.waitForFunction(() => document.documentElement.dataset.profile === "ready", null, { timeout: 30000 }).catch(() => {});
  state = await page.evaluate(() => ({ title: document.getElementById("title").textContent,
    page: document.querySelector("#handle-line a")?.getAttribute("href") || "",
    rail: [...document.querySelectorAll(".subnav a")].map((a) => a.textContent),
    following: document.getElementById("following-said").textContent,
    owned: document.getElementById("owned-said").textContent,
    claude: document.getElementById("claude-said").textContent,
    favourites: [...document.querySelectorAll("#favourites a.model")].map((a) => a.dataset.id),
    nav: document.querySelector(".site-head .nav a[data-account]")?.firstChild?.textContent.trim() || "" }));
  check(`one page that is theirs: "${state.title}", ${state.page}, ${state.rail.join(" · ")}`,
    state.title === "Flow Visitor" && state.page === `/u/${visitorHandle}` && state.rail.length === 7);
  check(`its sections drawn: the house kept; following "${state.following.slice(0, 30)}"; sets "${state.owned.slice(0, 30)}"; `
    + `Claude "${state.claude.slice(0, 30)}"`, state.favourites.includes(modelId) && /^Nobody yet/.test(state.following)
    && /^Tell Brickworks what you own/.test(state.owned) && /^Not connected/.test(state.claude));
  check(`the header says Account while signed in: "${state.nav}"`, state.nav === "Account");
  await shot(page, "7_account-laptop.png");
  visitorId = await page.evaluate(() => {
    try {
      return JSON.parse(localStorage.getItem("brickworks.session") || "{}").user_id || "";
    } catch {
      return "";
    }
  });
  page.once("dialog", (dialog) => dialog.accept());
  await page.click("#delete-part summary");
  await page.fill("#delete-confirm", visitorEmail);
  await page.click("#delete-go");
  await page.waitForFunction(() => document.documentElement.dataset.deleted === "yes", null, { timeout: 30000 }).catch(() => {});
  state = await page.evaluate(() => ({ deleted: document.documentElement.dataset.deleted === "yes",
    out: !document.getElementById("signed-out").hidden, said: document.querySelector("#signed-out .lede").textContent,
    kept: localStorage.getItem("brickworks.session"),
    nav: document.querySelector(".site-head .nav a[data-account]")?.textContent.trim() || "" }));
  check(`deleted from its own page: signed out, the header says "${state.nav}", "${state.said.slice(0, 40)}"`,
    state.deleted && state.out && !state.kept && state.nav === "Sign in" && /deleted/.test(state.said));
  deletedByPage = state.deleted && !(await accountExists(visitorEmail));
  check("and gone from the sign-in service", deletedByPage);
  await shot(page, "8_account_deleted-laptop.png");
  await stranger.close();
  await context.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const line of errors.slice(0, 6)) console.log(`        ${line}`);
  await browser.close();
  if (modelId && owner) {
    const again = await mintSession(ownerEmail).catch(() => null);
    if (again) await api(`/api/share?op=unpublish&id=${modelId}`, { method: "POST", token: again.access_token });
  }
  // How often each did things (supabase/moderation.sql act_log), which does
  // not go with an account.
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  // The visitor deleted their own (step 6): never minted again, which would
  // make the account anew.
  const ids = [];
  for (const email of deletedByPage ? [ownerEmail] : [ownerEmail, visitorEmail]) {
    const one = await mintSession(email).catch(() => null);
    if (one && one.kept.user_id) ids.push(one.kept.user_id);
  }
  if (deletedByPage && visitorId) ids.push(visitorId);
  for (const id of ids) {
    await fetch(`${String(process.env.SUPABASE_URL || "").replace(/\/+$/, "")}/rest/v1/act_log?who=eq.${id}`,
      { method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` } }).catch(() => {});
  }
  const gone = [await deleteAccount(ownerEmail), deletedByPage || await deleteAccount(visitorEmail)];
  check("both throwaway accounts deleted, and everything of theirs with them", gone.every(Boolean));
}
console.log(failed ? `${failed} FAILED` : "people can sign in from a model, like it, keep it, collect it and be found by name");
process.exit(failed ? 1 : 0);
