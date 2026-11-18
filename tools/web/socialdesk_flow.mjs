// The owner's social desk (web/admin.html › Social, web/admin-social.js,
// api/_social.js; docs/SOCIAL_DESK.md), in a real browser against a
// deployment, used as its owner uses it, in the checks' own pool
// (/admin?tests=1), whose Reddit is the stand-in (api/_social_mock.js):
// nothing here reaches reddit.com.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/socialdesk_flow.mjs --url=<deployment> --out=shots/socialdesk
//
//   1. The gate: every op of the desk answers 401 signed out and 404 to an
//      account that is not the owner's.
//   2. Before supabase/social.sql is applied the section says so, and its
//      Accounts still say what each network needs and costs; the rest waits
//      for the file. It ends "socialdesk: all ok (before the file)".
//   3. Connect: Connect Reddit, the stand-in's consent, Allow, back on the
//      console connected, with no code or state left in the address.
//   4. The inbox: Check now reads replies, mentions and messages, newest
//      first, each linking to Reddit; the filters; Mark read.
//   5. Reply from the inbox: the reply sheet shows the exact words; Send now.
//   6. A post: the community's rules beside the box, its draft kept with the
//      site's links tagged, nothing sent by keeping it; words changed behind
//      the open sheet refused at Send; Send now on the words shown.
//   7. Schedule from the sheet (a day and a quarter-hour), seen in Sent,
//      Unscheduled; one due in a minute sent by the cron's own call.
//   8. Results: each sent post's score and comments read again, over time
//      in its Details; a visit by its tagged link counted once, the tags
//      taken from the address the visitor sees.
//   9. Disconnect, and a post by hand: Reddit's own page offered (never
//      opened here) with the words, its address pasted back, counted; a
//      reply by hand to a comment by its pasted address (a Share link
//      refused), its own page offered, its reply's address kept.
//  10. Every tab at 390 and 1280, light and dark, never wider than the
//      phone, no button in Accounts shown off; no token in any answer,
//      page, storage or console line.
//  10b. With no Reddit app, as on brickworks.diy, at 390 and 1280, light
//      and dark: "Posting by hand" and why, no Connect at all and no button
//      shown off, How to connect later opening in place with the redirect
//      URI, Vercel's names and the redeploy, and Write a post working.
//
// The checks' pool is emptied of the desk's rows before and after (the
// secret key, test=true only), and the throwaway stranger deleted. It
// passes when it ends "socialdesk: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("socialdesk_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/socialdesk";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const CRON = process.env.CRON_SECRET || "";
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-socialdesk-${who}-${rand}@resend.dev`;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const answers = [];
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const shot = async (page, name, full = true) => {
  if (full) await page.evaluate(() => scrollTo(0, 0)).catch(() => {});
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body, bearer } = {}) {
  const sent = { ...headers };
  if (token || bearer) sent.authorization = `Bearer ${token || bearer}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  answers.push(text);
  let json = null;
  try {
    json = JSON.parse(text);
  } catch { /* not JSON */ }
  return { status: reply.status, json };
}

/// The checks' pool of the desk emptied (test=true rows only), where its
/// tables are on the project; a deployment holding them elsewhere keeps its own.
async function emptyPool() {
  if (!SUPABASE || !SECRET) return "no key";
  const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  const said = [];
  for (const table of ["social_tokens", "social_accounts", "social_items", "social_rules", "social_sends"]) {
    const reply = await fetch(`${SUPABASE}/rest/v1/${table}?test=eq.true`, { method: "DELETE", headers: secret }).catch(() => null);
    said.push(`${table} ${reply?.status ?? "-"}`);
  }
  return said.join(", ");
}

const browser = await launch({ signedOut: true });

// brickworks.diy today has no Reddit app. The checks' pool always has the
// stand-in's, so with [noApp] its read is answered as the owner's pool
// answers it (tests/fixtures/social/api_check.mjs real_later; test_social
// pins every field).
const NO_APP = { api: false, mock: false, account: null, route: "by_hand", missing: ["REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET"],
  env: ["REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET"], redirect: "https://brickworks.diy/admin?connected=reddit",
  scopes: ["identity", "history", "privatemessages", "read", "submit"] };
/// Each control a person sees in [scope] that is shown off (disabled).
const shownOff = (page, scope) => page.evaluate((at) => [...document.querySelectorAll(`${at} button, ${at} summary, ${at} a`)]
  .filter((one) => one.getClientRects().length > 0 && (one.matches(":disabled") || one.getAttribute("aria-disabled") === "true"))
  .map((one) => one.textContent.trim()), scope);

async function open(pathname, { width = 1280, theme = "light", who = null, label, noApp = false }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (noApp) {
    await context.route((url) => url.pathname === "/api/admin" && url.searchParams.get("op") === "social", async (route) => {
      const answer = await route.fetch();
      const json = await answer.json();
      if (Array.isArray(json?.networks)) json.networks = json.networks.map((one) => (one.id === "reddit" ? { ...one, ...NO_APP } : one));
      await route.fulfill({ response: answer, json });
    });
  }
  await context.route(/\/theme-account\.js(?:\?.*)?$/, (route) => route.fulfill({ status: 200,
    contentType: "text/javascript", body: "export async function follow() {}" }));
  // reddit.com is never reached from here: a link to it is read, not followed.
  await context.route(/^https:\/\/([a-z]+\.)?reddit\.com\//, (route) => route.abort());
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
    if (/mocktoken-/.test(m.text())) errors.push(`${label}: a token in the console`);
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  page.on("response", async (reply) => {
    if (!/\/api\/(admin|plans)\b/.test(reply.url())) return;
    answers.push(await reply.text().catch(() => ""));
  });
  page.on("dialog", (dialog) => dialog.accept());
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const go = async (page, hash) => {
  await page.evaluate((to) => { location.hash = to; }, hash);
  await page.waitForTimeout(300);
};
const sheet = "#social-sheet[open]";
const press = (page, scope, words) => page.locator(scope).getByRole("button", { name: words, exact: true }).first().click();
const rows = (page, id) => page.evaluate((body) => [...document.querySelectorAll(`#${body} tr:not(.none)`)].filter((row) => !row.hidden).length, id);

const made = [];
let owner = null;
try {
  // --- 1. The gate -------------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
  const OPS = [["social", "GET"], ["social_rules", "GET"], ["social_connect", "POST"], ["social_connected", "POST"],
    ["social_disconnect", "POST"], ["social_sync", "POST"], ["social_mark", "POST"], ["social_draft", "POST"], ["social_drop", "POST"],
    ["social_send", "POST"], ["social_unschedule", "POST"], ["social_posted", "POST"], ["social_notes", "POST"]];
  const body = { provider: "reddit", kind: "post", community: "lego", title: `A stranger's ${rand}`, body: "x", id: "abcdefghij",
    hash: "0".repeat(64), all: true };
  let gate = 0;
  for (const [op, method] of OPS) {
    const query = `/api/admin?op=${op}&tests=1&provider=reddit&community=lego`;
    const signedOut = await api(query, { method, body: method === "POST" ? body : undefined });
    const other = await api(query, { method, token: stranger.access_token, body: method === "POST" ? body : undefined });
    if (signedOut.status === 401 && other.status === 404) gate += 1;
    else console.log(`        ${method} ${op}: signed out ${signedOut.status}, anybody else ${other.status}`);
  }
  check(`each of the desk's ${OPS.length} ops: signed out 401, any other account 404 (${gate} of ${OPS.length})`, gate === OPS.length);

  const first = await as("/api/admin?op=social&tests=1");
  check(`the owner reads the desk: ${first.status}`, first.status === 200);
  const ready = first.json?.ready === true;
  console.log(`        emptied the checks' pool: ${await emptyPool()}`);

  if (!ready) {
    // --- 2. Before the file ------------------------------------------------------------
    console.log("2. Before supabase/social.sql");
    check(`the read says the file is missing: "${first.json?.said}"`, /social\.sql/.test(first.json?.said || ""));
    const draft = await as("/api/admin?op=social_draft&tests=1", { method: "POST", body: { provider: "reddit", kind: "post", title: "t" } });
    check(`a draft before it is refused as not yet there: ${draft.status}`, draft.status === 503);
    for (const width of [1280, 390]) {
      for (const theme of ["light", "dark"]) {
        const where = await open("/admin?tests=1#social/accounts", { width, theme, who: owner, label: `before ${width} ${theme}` });
        await shown(where.page);
        const said = await until(where.page, () => !document.getElementById("social-not-yet").hidden
          && /social\.sql/.test(document.getElementById("social-not-yet").textContent), null, 30000);
        const later = await where.page.evaluate(() => [...document.querySelectorAll("#networks li")].map((li) => li.textContent));
        check(`at ${width} ${theme}: says the file is not applied, and X, Facebook and Instagram are "not connected yet" with their costs`,
          said && ["X", "Facebook", "Instagram"].every((name) => later.some((one) => one.startsWith(name) && /Not connected yet/.test(one)
            && /Cost:/.test(one))));
        check(`...no wider than the screen at ${width}`, !(await sideways(where.page)));
        await shot(where.page, `0-before-${width}-${theme}.png`);
        await where.context.close();
      }
    }
  } else {
    const owned = await open("/admin?tests=1#social/accounts", { who: owner, label: "owner" });
    const page = owned.page;
    await shown(page);
    await until(page, () => document.querySelectorAll("#networks li").length === 4);

    // --- 3. Connect ----------------------------------------------------------------------
    console.log("3. Connect Reddit (the stand-in)");
    const card = await page.locator("#networks li").first().textContent();
    check(`Reddit not connected, the stand-in said: "${card.slice(0, 90)}…"`, /Not connected/.test(card) && /stand-in/.test(card));
    await press(page, "#networks", "Connect Reddit");
    const consent = await until(page, () => document.querySelector("#social-sheet[open]")?.textContent.includes("stand-in"), null, 30000);
    check(`the stand-in's consent, asking for its scopes: ${consent}`, consent
      && /identity, history, privatemessages, read, submit/.test(await page.locator(sheet).textContent()));
    await press(page, sheet, "Allow");
    const connected = await until(page, () => /Connected as u\/brickworks_checks/.test(document.getElementById("networks")?.textContent || ""),
      null, 60000);
    check(`back on the console, connected as u/brickworks_checks: ${connected}`, connected);
    const left = await page.evaluate(() => location.href);
    check(`no code or state left in the address: ${left.replace(site, "")}`, !/code=|state=/.test(left) && /#social\/accounts$/.test(left));

    // --- 4. The inbox ----------------------------------------------------------------------
    console.log("4. The inbox");
    await go(page, "social/inbox");
    await page.click("#inbox-check");
    await until(page, () => document.querySelectorAll("#inbox tr.unread").length >= 5, null, 60000);
    const kinds = await page.evaluate(() => [...document.querySelectorAll("#inbox tr")].map((row) => row.dataset.kind));
    check(`replies, mentions and messages in one list: ${kinds.join(", ")}`, ["reply", "mention", "message"].every((k) => kinds.includes(k)));
    const order = await page.evaluate(() => [...document.querySelectorAll("#inbox tr td.when")].map((td) => td.dataset.value));
    check("newest first", order.length >= 5 && order.every((at, i) => i === 0 || order[i - 1] >= at));
    const links = await page.evaluate(() => [...document.querySelectorAll("#inbox a")].map((a) => a.href));
    check(`each links to Reddit (${links.length})`, links.length >= 5 && links.every((href) => /^https:\/\/www\.reddit\.com\//.test(href)));
    const counted = {};
    for (const [value, name] of [["unread", "Unread"], ["reply", "Replies"], ["mention", "Mentions"], ["message", "Messages"], ["", "All"]]) {
      await press(page, "#inbox-kinds", name);
      counted[value || "all"] = await rows(page, "inbox");
    }
    check(`its filters: ${JSON.stringify(counted)}`, counted.all === 5 && counted.unread === 5 && counted.reply === 2 && counted.mention === 2
      && counted.message === 1);
    await page.locator("#inbox tr[data-kind='message']").getByRole("button", { name: "Mark read" }).click();
    check("Mark read: the message read, the others not",
      await until(page, () => document.querySelector("#inbox tr[data-kind='message']")?.dataset.read === "true"
        && document.querySelectorAll("#inbox tr.unread").length === 4));

    // --- 5. Reply ----------------------------------------------------------------------------
    console.log("5. Reply from the inbox");
    const before = (await as("/api/admin?op=social&tests=1")).json.sends.filter((one) => one.status === "sent").length;
    await page.locator("#inbox tr[data-kind='reply']").first().getByRole("button", { name: "Reply…" }).click();
    check("the reply box, saying what it answers", await until(page, () => !document.getElementById("social-replying").hidden
      && /Replying to u\//.test(document.getElementById("social-replying").textContent) && !document.querySelector("[data-tab='write']").hidden));
    const replyWords = `Thank you: it is free in the browser. ${rand}`;
    await page.fill("#social-form textarea[name='body']", replyWords);
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    check("the sheet shows the exact words before Send", (await page.locator(`${sheet} .words`).textContent()).includes(replyWords));
    await press(page, sheet, "Send now");
    const replied = await until(page, () => document.getElementById("social-sheet-title").textContent === "Sent", null, 30000);
    const afterReply = (await as("/api/admin?op=social&tests=1")).json.sends;
    const reply = afterReply.find((one) => one.kind === "reply" && one.body === replyWords);
    check(`Send now: the reply sent, pressed by the owner (${reply?.status}, ${reply?.pressed_by})`, replied && reply?.status === "sent"
      && reply.pressed_by === process.env.MASTER_EMAIL && afterReply.filter((one) => one.status === "sent").length === before + 1);
    await page.click("#social-sheet-close");

    // --- 6. A post ---------------------------------------------------------------------------
    console.log("6. A post, its community's rules beside the box");
    await page.click("#social-new");
    await page.fill("#social-community", "r/lego");
    await page.click("#social-rules-get");
    check("r/lego's rules beside the box", await until(page, () => document.querySelectorAll("#social-rules li").length >= 3
      && /r\/lego's rules/.test(document.getElementById("h-social-rules").textContent)));
    await page.fill("#social-rules-notes", "Self-promotion: one in ten, and say it is ours.");
    await page.click("#social-notes-keep");
    check("notes kept beside its rules", await until(page, () => /Kept for r\/lego/.test(document.getElementById("social-notes-said").textContent)));
    const title = `A free LEGO CAD in the browser ${rand}`;
    await page.fill("#social-form input[name='title']", title);
    await page.fill("#social-form textarea[name='body']", `Made with it: ${site}/gallery and more.`);
    await page.click("#social-form button[type='submit']");
    check("Keep the draft: kept, its link tagged", await until(page, () => /utm_campaign=bw-/.test(document.getElementById("social-note").textContent)
      && /utm_source=reddit&utm_medium=social&utm_campaign=bw-[a-z0-9]{10}/.test(document.querySelector("#social-form textarea").value)));
    const drafted = (await as("/api/admin?op=social&tests=1")).json.sends;
    const draft = drafted.find((one) => one.title === title);
    check(`...in Drafts, and nothing sent by keeping it (${draft?.status})`, draft?.status === "draft"
      && drafted.filter((one) => one.status === "sent").length === before + 1 && await rows(page, "drafts") >= 1);
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    await shot(page, "6-review-1280-light.png", false);
    // The words changed elsewhere while the sheet is open: its press is of the old ones.
    await as("/api/admin?op=social_draft&tests=1", { method: "POST", body: { id: draft.id, provider: "reddit", kind: "post", community: "lego",
      title, body: `${draft.body} Changed behind the sheet.` } });
    await press(page, sheet, "Send now");
    check("words changed since the sheet opened: refused, nothing sent",
      await until(page, () => /not the words you pressed Send on/.test(document.querySelector("#social-sheet[open]")?.textContent || "")));
    check("...still a draft", (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.id === draft.id)?.status === "draft");
    await page.click("#social-sheet-close");
    await page.evaluate(() => { location.hash = "#social/write"; });
    await page.locator("#drafts tr").filter({ hasText: title }).getByRole("button", { name: "Edit" }).click();
    await page.fill("#social-form textarea[name='body']", `Made with it: ${site}/gallery and more.`);
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    await press(page, sheet, "Send now");
    await until(page, () => document.getElementById("social-sheet-title").textContent === "Sent", null, 30000);
    const post = (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.id === draft.id);
    check(`Send now on the words shown: sent to r/lego, at ${post?.url}`, post?.status === "sent"
      && /^https:\/\/www\.reddit\.com\/r\/lego\/comments\//.test(post.url || "") && !/Changed behind/.test(post.body));
    await page.click("#social-sheet-close");

    // --- 7. Schedule ----------------------------------------------------------------------------
    console.log("7. Schedule");
    const later = `Next week's build ${rand}`;
    await page.fill("#social-community", "r/legodesign");
    await page.fill("#social-form input[name='title']", later);
    await page.fill("#social-form textarea[name='body']", "A tower, step by step.");
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    const selects = page.locator(`${sheet} .when-pair select`);
    await selects.nth(0).selectOption({ index: 2 });
    // Option 0 is the unchosen "Time"; option n is (n - 1) quarter-hours past midnight: 41 is 10:00.
    await selects.nth(1).selectOption({ index: 41 });
    await press(page, sheet, "Schedule");
    check("Schedule: tomorrow at 10:00, said", await until(page, () => /^Scheduled for /.test(document.getElementById("social-note").textContent)));
    await go(page, "social/sent");
    const row = page.locator("#sends tr").filter({ hasText: later });
    check("in Sent and scheduled, by the API", /Scheduled, by the API/.test(await row.textContent()));
    await row.getByRole("button", { name: "Unschedule" }).click();
    check("Unschedule: back among the drafts", await until(page, ([words]) => ![...document.querySelectorAll("#sends tr")]
      .some((one) => one.textContent.includes(words)), [later]));
    // A send due in a minute, pressed by the owner, sent by the cron's own call.
    const due = await as("/api/admin?op=social_draft&tests=1", { method: "POST", body: { provider: "reddit", kind: "post", community: "LegoMOC",
      title: `Due in a minute ${rand}`, body: "Words." } });
    const pressed = await as("/api/admin?op=social_send&tests=1", { method: "POST", body: { id: due.json.send.id, hash: due.json.send.hash,
      at: new Date(Date.now() + 65000).toISOString() } });
    check(`a send pressed for a minute from now: ${pressed.json?.outcome}`, pressed.json?.outcome === "scheduled");
    const notCron = await api("/api/plans?op=social_due");
    const early = await api("/api/plans?op=social_due", { bearer: CRON });
    check(`the cron: refused without its key (${notCron.status}); before the time, sends nothing (${early.json?.outcome})`, notCron.status === 401
      && early.status === 200 && /^0 sent|^nothing due/.test(early.json?.outcome || ""));
    await wait(70000);
    const ran = await api("/api/plans?op=social_due", { bearer: CRON });
    const dueRow = (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.id === due.json.send.id);
    check(`at its time, the cron sent it: "${ran.json?.outcome}", ${dueRow?.status}`, /^1 sent/.test(ran.json?.outcome || "")
      && dueRow?.status === "sent");

    // --- 8. Results -----------------------------------------------------------------------------
    console.log("8. Results and visits");
    const visitor = await open(`/gallery?utm_source=reddit&utm_medium=social&utm_campaign=bw-${post.id}`, { label: "visitor" });
    const stripped = await until(visitor.page, () => !/utm_/.test(location.search), null, 30000);
    check(`a visit by the post's link: its tags gone from the address the visitor sees (${stripped})`, stripped);
    await visitor.page.reload({ waitUntil: "load" });
    await visitor.context.close();
    let counted2 = null;
    for (let at = 0; at < 10 && !(counted2?.visits?.total >= 1); at += 1) {
      await wait(1500);
      counted2 = (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.id === post.id);
    }
    check(`...counted once: ${counted2?.visits?.total}`, counted2?.visits?.total === 1);
    await go(page, "social/inbox");
    await page.click("#inbox-check");
    await wait(2000);
    await go(page, "social/sent");
    await until(page, () => document.querySelectorAll("#sends tr").length >= 3);
    const sentRow = page.locator(`#send-${post.id}`);
    const cells = await sentRow.locator("td.n").allTextContents();
    check(`its score, comments and visits in Sent: ${cells.join(" / ")}`, Number(cells[0]) >= 1 && cells[2] === "1");
    await sentRow.getByRole("button", { name: "Details" }).click();
    check("its Details: the words, over time, the visits it brought", await until(page, () => {
      const text = document.querySelector("#social-sheet[open]")?.textContent || "";
      return /Over time/.test(text) && /Visits it brought: 1/.test(text) && /utm_campaign=bw-/.test(text);
    }));
    await shot(page, "8-details-1280-light.png", false);
    await page.click("#social-sheet-close");

    // --- 9. By hand ----------------------------------------------------------------------------
    console.log("9. Disconnect, and a post by hand");
    await go(page, "social/accounts");
    await press(page, "#networks", "Disconnect");
    check("Disconnect: not connected, its keys taken back", await until(page, () => /Disconnected/.test(document.getElementById("networks-note")
      .textContent) && /Not connected/.test(document.querySelector("#networks li").textContent)));
    await go(page, "social/write");
    await page.click("#social-new");
    // A link and words together: refused in the form's words, nothing kept.
    await page.fill("#social-community", "lego");
    await page.fill("#social-form input[name='title']", `Both ${rand}`);
    await page.fill("#social-form input[name='link']", `${site}/gallery`);
    await page.fill("#social-form textarea[name='body']", "Words about it.");
    await page.click("#social-form button[type='submit']");
    check("a link and words together: refused, nothing kept", await until(page, () => /a link or words, not both/
      .test(document.getElementById("social-note").textContent)) && !(await as("/api/admin?op=social&tests=1")).json.sends
      .some((one) => one.title === `Both ${rand}`));
    // A post too long for Reddit's address: said before the press, the page opened with the title alone.
    await page.click("#social-new");
    const longTitle = `Long by hand ${rand}`;
    await page.fill("#social-community", "lego");
    await page.fill("#social-form input[name='title']", longTitle);
    await page.fill("#social-form textarea[name='body']", "A long post. ".repeat(600).trim());
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    check("a long post by hand: the sheet says before the press that the words go by copying",
      /too long to go in Reddit's address/.test(await page.locator(sheet).textContent()));
    await press(page, sheet, "Post it on Reddit…");
    await until(page, () => document.getElementById("social-sheet-title").textContent === "Post it on Reddit");
    const longOff = await page.locator(`${sheet} a.cta`).getAttribute("href");
    check(`...Reddit's page with the title alone (${longOff.length} characters), Copy the words first`,
      longOff.length < 6000 && !/[?&]text=/.test(longOff)
      && (await page.locator(`${sheet} .row button, ${sheet} .row a`).first().textContent()) === "Copy the words");
    await page.click("#social-sheet-close");
    // Handed and not posted: back to the drafts, then thrown away.
    await go(page, "social/sent");
    const longRow = page.locator("#sends tr").filter({ hasText: longTitle });
    await longRow.getByRole("button", { name: "Back to drafts" }).click();
    check("a handed post taken back: a draft again", await until(page, ([t]) => [...document.querySelectorAll("#drafts tr")]
      .some((row) => row.textContent.includes(t)), [longTitle]));
    await go(page, "social/write");
    await page.locator("#drafts tr").filter({ hasText: longTitle }).getByRole("button", { name: "Drop" }).click();
    check("...and dropped", await until(page, ([t]) => ![...document.querySelectorAll("#drafts tr")]
      .some((row) => row.textContent.includes(t)), [longTitle]));
    await page.click("#social-new");
    const handTitle = `By hand ${rand}`;
    await page.fill("#social-community", "lego");
    await page.fill("#social-form input[name='title']", handTitle);
    await page.fill("#social-form textarea[name='body']", "Posted on Reddit's own page.");
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    check("not connected, the sheet says Reddit's page opens and nothing is posted until Post there",
      /Nothing is posted until you press Post there/.test(await page.locator(sheet).textContent()));
    await press(page, sheet, "Post it on Reddit…");
    await until(page, () => document.getElementById("social-sheet-title").textContent === "Post it on Reddit");
    check("...the pressed button gone with the old sheet, focus on the new one's name",
      await until(page, () => document.activeElement?.id === "social-sheet-title"));
    const handOff = await page.locator(`${sheet} a.cta`).getAttribute("href");
    check(`Reddit's own page with the words, offered, not opened: ${handOff.slice(0, 70)}…`,
      /^https:\/\/www\.reddit\.com\/r\/lego\/submit\?title=By\+hand\+/.test(handOff) && /selftext=true/.test(handOff));
    await page.fill(`${sheet} input[type='url']`, "https://www.reddit.com/r/lego/comments/abc123/by_hand/");
    await press(page, sheet, "It is posted");
    await until(page, () => !document.querySelector("#social-sheet[open]"));
    check("...focus back on Write's Review, not lost to the page, and what became of it said beside it",
      await until(page, () => document.activeElement?.id === "social-review"
        && /^Kept: the visits it brings/.test(document.getElementById("social-note").textContent)));
    const hand = (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.title === handTitle);
    check(`its address kept, counted from now: ${hand?.status} ${hand?.route} ${hand?.external_id}`, hand?.status === "sent"
      && hand.route === "by_hand" && hand.external_id === "t3_abc123");
    // A reply by hand to any post or comment, by its address: no inbox
    // without Reddit's API, and Reddit ended RSS on 13 November 2026.
    await page.click("#social-new-reply");
    check("New reply asks for the address it answers, with the focus in it", await until(page, () =>
      !document.getElementById("social-address-l").hidden && document.activeElement?.name === "address"
      && document.getElementById("social-form-h").textContent === "A new reply"));
    const thanks = `Thank you ${rand}`;
    await page.fill("#social-form input[name='address']", "https://www.reddit.com/r/lego/s/AbCdEf12");
    await page.fill("#social-form textarea[name='body']", thanks);
    await page.click("#social-form button[type='submit']");
    check("...a Share link refused, in words that say what to paste", await until(page, () =>
      /names nothing the desk can read/.test(document.getElementById("social-note").textContent)));
    await page.fill("#social-form input[name='address']", "https://old.reddit.com/r/lego/comments/abc777/a_castle/def888/?context=3");
    await page.click("#social-review");
    await until(page, () => document.querySelector("#social-sheet[open]"));
    const there = "https://www.reddit.com/r/lego/comments/abc777/a_castle/def888/";
    check("...kept answering the comment, in r/lego, its rules beside the box", await until(page, ([to]) =>
      document.getElementById("social-replying").textContent.includes(to) && document.querySelectorAll("#social-rules li").length >= 1,
    [there]));
    check("...the sheet says it opens on Reddit and nothing is sent until Reply there",
      /Nothing is sent until you press Reply there/.test(await page.locator(sheet).textContent()));
    await press(page, sheet, "Reply on Reddit…");
    await until(page, () => document.getElementById("social-sheet-title").textContent === "Reply on Reddit");
    const replyAt = await page.locator(`${sheet} a.cta`).getAttribute("href");
    check(`...Reply on Reddit offers that comment's own page, not opened here: ${replyAt}`, replyAt === there
      && (await page.locator(sheet).getByRole("button", { name: "Copy the words" }).count()) === 1);
    await page.fill(`${sheet} input[type='url']`, "https://www.reddit.com/r/lego/comments/abc777/a_castle/ghi999/");
    await press(page, sheet, "It is posted");
    await until(page, () => !document.querySelector("#social-sheet[open]"));
    const byHandReply = (await as("/api/admin?op=social&tests=1")).json.sends.find((one) => one.body === thanks);
    check(`...its reply's address kept: ${byHandReply?.status} ${byHandReply?.parent} ${byHandReply?.external_id}`, byHandReply?.status === "sent"
      && byHandReply.parent === "t1_def888" && byHandReply.external_id === "t1_ghi999" && byHandReply.link === there);
    const audit = await as("/api/admin?op=audit&tests=1&limit=60");
    const ops = new Set((audit.json?.rows || []).map((one) => one.op));
    check(`each act in the audit as a test's: ${[...ops].filter((op) => op.startsWith("social_")).sort().join(", ")}`,
      ["social_connected", "social_send", "social_draft", "social_disconnect", "social_posted"].every((op) => ops.has(op)));
    const kept = await page.evaluate(() => JSON.stringify({ ...localStorage }) + JSON.stringify({ ...sessionStorage })
      + document.documentElement.outerHTML);
    check("no token in the page or its storage", !/mocktoken-/.test(kept));
    await owned.context.close();

    // --- 10. Every tab, every size ------------------------------------------------------------
    console.log("10. Every tab at 390 and 1280, light and dark");
    for (const width of [1280, 390]) {
      for (const theme of ["light", "dark"]) {
        const where = await open("/admin?tests=1#social/inbox", { width, theme, who: owner, label: `${width} ${theme}` });
        await shown(where.page);
        await until(where.page, () => document.querySelectorAll("#inbox tr").length >= 5);
        let wide = false;
        for (const tab of ["inbox", "write", "sent", "accounts"]) {
          await go(where.page, `social/${tab}`);
          if (tab === "write") {
            await where.page.fill("#social-community", "lego");
            await where.page.click("#social-rules-get");
            await until(where.page, () => document.querySelectorAll("#social-rules li").length >= 1);
          }
          wide ||= await sideways(where.page);
          // Every act of a row within the screen: rows are cards on a phone.
          const off = await where.page.evaluate(() => [...document.querySelectorAll("td.acts button, td.acts a")]
            .filter((one) => one.offsetParent && one.getBoundingClientRect().right > innerWidth + 1).length);
          if (off) console.log(`        ${tab} at ${width}: ${off} of its rows' acts past the screen's edge`);
          wide ||= off > 0;
          if (tab === "accounts") {
            const offs = await shownOff(where.page, '[data-tab="accounts"]');
            check(`at ${width} ${theme}: no button in Accounts shown off: ${JSON.stringify(offs)}`, offs.length === 0);
          }
          await shot(where.page, `10-${tab}-${width}-${theme}.png`);
        }
        await go(where.page, "social/sent");
        await where.page.locator("#sends tr").first().getByRole("button", { name: "Details" }).click();
        await until(where.page, () => document.querySelector("#social-sheet[open]"));
        await shot(where.page, `10-details-${width}-${theme}.png`, false);
        check(`at ${width} ${theme}: every tab drawn, none wider than the screen, every row's acts on it`, !wide);
        await where.context.close();
      }
    }

    // --- 10b. No Reddit app, as on brickworks.diy ----------------------------------------------
    console.log("10b. No Reddit app (brickworks.diy today) at 390 and 1280, light and dark");
    for (const width of [1280, 390]) {
      for (const theme of ["light", "dark"]) {
        const where = await open("/admin?tests=1#social/accounts", { width, theme, who: owner, label: `no app ${width} ${theme}`, noApp: true });
        const p = where.page;
        await shown(p);
        const drawn = await until(p, () => /Posting by hand: Reddit takes no new API apps \(since 31 Oct 2026\)\./
          .test(document.getElementById("networks")?.textContent || ""), null, 30000);
        const card = p.locator("#networks li").first();
        const seen = await p.evaluate(() => {
          const li = document.querySelector("#networks li");
          const named = [...li.querySelectorAll("button, summary, a")].filter((one) => one.getClientRects().length > 0)
            .map((one) => one.textContent.trim());
          return { pill: li.querySelector(".pill")?.textContent, named, notice: li.querySelector("a[target=_blank]")?.href };
        });
        const offs = await shownOff(p, '[data-tab="accounts"]');
        check(`at ${width} ${theme}: "Posting by hand" and why, no Connect, no button shown off: ${JSON.stringify(seen.named)} off ${JSON.stringify(offs)}`,
          drawn && seen.pill === "Posting by hand" && !seen.named.some((one) => /Connect Reddit/.test(one)) && offs.length === 0
          && seen.named.includes("Write a post") && seen.named.includes("How to connect later")
          && seen.notice === "https://support.reddithelp.com/hc/en-us/articles/54353370049684");
        await card.locator("summary", { hasText: "How to connect later" }).click();
        const steps = (await card.locator("details.later ol").textContent()) || "";
        check(`...How to connect later opens in place: the redirect URI, Vercel's two names, the redeploy, the scopes`,
          /https:\/\/brickworks\.diy\/admin\?connected=reddit/.test(steps) && /REDDIT_CLIENT_ID/.test(steps)
          && /REDDIT_CLIENT_SECRET/.test(steps) && /Redeploy: Deployments/.test(steps) && /identity, history, privatemessages, read, submit/.test(steps));
        await card.getByRole("button", { name: "Copy the redirect URI" }).click();
        const copied = await until(p, () => /Copied the redirect URI|would not copy/.test(document.querySelector("#networks details.later")
          ?.textContent || ""));
        const offsOpen = await shownOff(p, '[data-tab="accounts"]');
        check(`...its Copy answers, and opened nothing is shown off, none wider than the screen: ${JSON.stringify(offsOpen)}`,
          copied && offsOpen.length === 0 && !(await sideways(p)));
        await shot(p, `10b-no-app-${width}-${theme}.png`);
        await card.getByRole("link", { name: "Write a post" }).click();
        check("...Write a post opens Write", await until(p, () => location.hash === "#social/write"
          && document.querySelector('[data-tab="write"]')?.hidden === false && !document.querySelector("#social-form [name=title]").disabled));
        await where.context.close();
      }
    }
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  await browser.close();
  if (owner) {
    // Disconnected and emptied, so the next run starts where this one did.
    await api("/api/admin?op=social_disconnect&tests=1", { method: "POST", token: owner.access_token, body: { provider: "reddit" } });
    console.log(`        emptied the checks' pool: ${await emptyPool()}`);
  }
  let gone = 0;
  for (const email of made) if (await deleteAccount(email).catch(() => false)) gone += 1;
  check(`the throwaway deleted (${gone} of ${made.length})`, gone === made.length);
}
const tokens = answers.filter((text) => /mocktoken-|"access_token"|"refresh_token"/.test(text)).length;
check(`no token in any of the ${answers.length} answers read`, tokens === 0);
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`socialdesk: ${passed} ok, ${failed} failed`);
const before = answers.length && failed === 0 && !answers.some((text) => /"ready":true/.test(text));
console.log(failed === 0 ? `socialdesk: all ok${before ? " (before the file)" : ""}` : "socialdesk: FAILED");
process.exit(failed === 0 ? 0 : 1);
