// Moderation, in a real browser against a deployment: a visitor reports a
// model from its page, a rights holder sends a takedown request, and the
// site's owner acts on both from the admin page — the model out of the
// gallery for good, then its account out whole and let back in.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/moderation_flow.mjs --url=<deployment> --out=shots/moderation
//
// As people do it, by pressing what the pages show:
//
//   1. An owner (a throwaway account, on the test side) lists two models
//      and has a profile.
//   2. A visitor who never signed in opens the first one's page and presses
//      Report it: the dialog, a reason, a note, a way to reach them, Send,
//      and thanks.
//   3. /takedown: the page's address, what is wrong, what is theirs, how to
//      reach them, Send, and "Sent".
//   4. The site's owner (MASTER_EMAIL, signed in as the tests are) opens
//      /admin: both reports, with what was said and the owner's account.
//      Take out: the model leaves the gallery, its reports leave the queue.
//      The second model reported; Take out the account: it leaves too, the
//      profile is gone, the account is listed as taken out; Let back in.
//   5. /takedown and the report dialog at 390 and 1280 px: nothing
//      sideways; no console error or refused request anywhere.
//
// The owner's account is deleted at the end with everything of theirs, its
// models taken down first and what moderation kept of them removed.
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
  console.error("moderation_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = args.out || "shots/moderation";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
// A person's browser, one of its own each run: reports are counted by the
// browser and the address, a few an hour.
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${randomBytes(3).toString("hex")}`;
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(4).toString("hex");
const ownerEmail = `delivered+bw-moderation-${rand}@resend.dev`;
const handle = `moderated-${rand}`;

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
    if (m.type() === "error" || /Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
  page.on("dialog", (d) => d.accept());
}
const shot = (page, name, full = true) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
let asked = 0;
async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  // Reads past the CDN, which keeps pages and the list for up to a minute.
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
// With tests=1: the flow's account is a test's, and its models are in no
// visitor's gallery at all (api/share.js); asked, they are, until taken out.
const inList = async (id) => ((await api(`/api/share?op=list&page=1&tests=1&q=${rand}`)).json?.models || []).some((m) => m.id === id);

const ids = [];
const browser = await launch({ signedOut: true });
try {
  // --- 1. The owner lists two models and has a profile.
  console.log("an owner lists two models");
  const owner = await mintSession(ownerEmail);
  const house = readFileSync(new URL("../../models/house.ldr", import.meta.url), "utf8");
  const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
  for (const [name, text] of [[`Moderated House ${rand}`, house], [`Moderated Shed ${rand}`, `0 Shed ${rand}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n`]]) {
    const r = await api("/api/share", { method: "POST", token: owner.access_token,
      body: { name, author: "Moderated Owner", model: text, image: picture, listed: true } });
    if (r.json?.id) ids.push(r.json.id);
  }
  const r = await api("/api/people?op=profile", { method: "POST", token: owner.access_token, body: { handle, name: "Moderated Owner" } });
  check(`two models listed and a profile (${ids.join(", ")}, /u/${r.json?.handle})`, ids.length === 2 && r.status === 200);
  const [house1, shed] = ids;

  // --- 2. A visitor reports the house from its page.
  console.log("a visitor reports it from its page");
  for (const [width, height, label] of [[1280, 900, "laptop"], [390, 844, "phone"]]) {
    const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, userAgent: PERSON });
    const page = await context.newPage();
    listen(page, `visitor ${label}`);
    await page.goto(`${site}/m/${house1}`, { waitUntil: "load", timeout: 60000 });
    await page.waitForSelector('button[data-report]:not([hidden])', { timeout: 20000 });
    // Report it is in the action bar's More (web/model-page.js).
    await page.click("#more > summary");
    await page.click('button[data-report]');
    await page.waitForSelector("dialog.report[open]", { timeout: 15000 });
    await page.check('dialog.report input[value="copied"]');
    await page.fill("dialog.report textarea", `My own house, built in 2019 (${label}).`);
    await page.fill('dialog.report input[type="email"]', "rights@example.com");
    check(`the report dialog at ${label} width: nothing sideways`, !(await sideways(page)));
    await shot(page, `1_report-${label}.png`, false);
    await page.click('dialog.report button[type="submit"]');
    await page.waitForFunction(() => /Thank you/.test(document.querySelector("dialog.report p")?.textContent || "")
      || /did not go|lot of that/.test(document.querySelector("dialog.report .said")?.textContent || ""), null, { timeout: 20000 }).catch(() => {});
    const said = await page.textContent("dialog.report p").catch(() => "");
    check(`sent: "${said.slice(0, 50)}"`, /Thank you/.test(said));
    await context.close();
  }

  // --- 3. A takedown request.
  console.log("a takedown request");
  for (const [width, height, label] of [[1280, 900, "laptop"], [390, 844, "phone"]]) {
    const context = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, userAgent: PERSON });
    const page = await context.newPage();
    listen(page, `takedown ${label}`);
    await page.goto(`${site}/takedown`, { waitUntil: "load", timeout: 60000 });
    check(`/takedown at ${label} width: nothing sideways`, !(await sideways(page)));
    if (label === "laptop") {
      await page.fill("#where", `${site}/m/${house1}`);
      await page.selectOption("#why", "trademark");
      await page.fill("#what", "The picture on its sign is my logo.");
      await page.fill("#contact", "marks@example.com");
      await page.click("#send");
      await page.waitForFunction(() => /Sent|not|said/.test(document.getElementById("said").textContent), null, { timeout: 20000 }).catch(() => {});
      check(`sent: "${await page.textContent("#said")}"`, /^Sent\./.test(await page.textContent("#said")));
    }
    await shot(page, `2_takedown-${label}.png`);
    await context.close();
  }

  // --- 4. The site's owner.
  console.log("the site's owner acts on them");
  const master = await mintSession(process.env.MASTER_EMAIL);
  const admin = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  await admin.addInitScript(([name, value]) => { try { localStorage.setItem(name, value); } catch {} },
    [STORAGE_KEY, JSON.stringify(master.kept)]);
  const page = await admin.newPage();
  listen(page, "admin");
  await page.goto(`${site}/admin`, { waitUntil: "load", timeout: 60000 });
  await page.waitForSelector("#reports tr", { timeout: 30000 });
  const rows = () => page.evaluate((id) => [...document.querySelectorAll("#reports tr")]
    .filter((row) => row.querySelector(`a[href="/m/${id}"]`)).map((row) => row.innerText), house1);
  let mine = await rows();
  check(`the queue has both, with what was said and whose it is (${mine.length})`, mine.length >= 3
    && mine.some((t) => /copied/.test(t) && /rights@example\.com/.test(t) && t.includes(ownerEmail))
    && mine.some((t) => /trademark/.test(t) && /marks@example\.com/.test(t)));
  await shot(page, "3_admin_queue.png");
  const row = page.locator("#reports tr").filter({ has: page.locator(`a[href="/m/${house1}"]`) }).first();
  await row.locator("button", { hasText: /^Take out$/ }).click();
  await page.waitForFunction(() => /Taken out/.test(document.getElementById("reports-note").textContent), null, { timeout: 30000 }).catch(() => {});
  mine = await rows();
  check(`Take out: its reports off the queue (${mine.length} left)`, mine.length === 0);
  check("and the model out of the gallery", !(await inList(house1)));
  await api("/api/people?op=report", { method: "POST", body: { model: shed, reason: "spam" } });
  await page.click("#again");
  await page.waitForFunction((id) => [...document.querySelectorAll("#reports a")].some((a) => a.getAttribute("href") === `/m/${id}`),
    shed, { timeout: 30000 }).catch(() => {});
  const shedRow = page.locator("#reports tr").filter({ has: page.locator(`a[href="/m/${shed}"]`) }).first();
  await shedRow.locator("button", { hasText: "Take out the account" }).click();
  await page.waitForFunction(() => /account is out/.test(document.getElementById("reports-note").textContent), null, { timeout: 30000 }).catch(() => {});
  const barredRow = page.locator("#barred tr").filter({ hasText: ownerEmail });
  check("Take out the account: listed as taken out", (await barredRow.count()) === 1);
  check("its other model out of the gallery", !(await inList(shed)));
  check("its profile gone", (await api(`/u/${handle}`)).status === 404);
  const relist = await api("/api/share", { method: "POST", token: owner.access_token,
    body: { name: `Moderated New ${rand}`, model: `0 New ${rand}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n`, listed: true } });
  check(`its owner listing anything new: ${relist.status} "${relist.json?.error}"`, relist.status === 409);
  await shot(page, "4_admin_barred.png");
  await barredRow.locator("button", { hasText: "Let back in" }).click();
  await page.waitForFunction(() => /Let back in/.test(document.getElementById("barred-note").textContent), null, { timeout: 30000 }).catch(() => {});
  check("Let back in: no longer listed as taken out", (await page.locator("#barred tr").filter({ hasText: ownerEmail }).count()) === 0);
  await admin.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const line of errors.slice(0, 6)) console.log(`        ${line}`);
  await browser.close();
  const again = await mintSession(ownerEmail).catch(() => null);
  const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
  if (again) {
    for (const id of ids) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: again.access_token });
    await fetch(`${SUPABASE}/rest/v1/act_log?who=eq.${again.kept.user_id}`, { method: "DELETE", headers: secret }).catch(() => {});
  }
  if (ids.length) {
    await fetch(`${SUPABASE}/rest/v1/barred_models?model=in.(${ids.join(",")})`, { method: "DELETE", headers: secret }).catch(() => {});
  }
  await fetch(`${SUPABASE}/rest/v1/reports?handle=eq.${handle}`, { method: "DELETE", headers: secret }).catch(() => {});
  check("the owner's account deleted, and everything of theirs with it", await deleteAccount(ownerEmail));
}
console.log(failed ? `${failed} FAILED` : "a model can be reported, asked to be taken down, and taken out with its account");
process.exit(failed ? 1 : 0);
