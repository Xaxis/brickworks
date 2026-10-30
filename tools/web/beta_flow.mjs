// The beta (beta361, api/_beta.js, supabase/beta.sql), as a person and the
// owner meet it, in a real browser against a deployment and its live
// database:
//
//   tools/deploy.sh --unit --billing-stand-in --beta-open      the beta open, billing test (the stand-in)
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/beta_flow.mjs --url=<that preview> --out=DIR
//
// With the beta off (every release preview, and production until the
// owner says), it checks that: /beta says Coming soon with no form and no
// count, GET ?op=beta says off, and the API refuses an application. Open,
// with throwaway accounts at Resend test addresses, each deleted at the end
// whatever happened, and the site's checks' own pool of spots (accounts at
// resend.dev take none of the 100):
//
//   1. Signed out, at 1280: the spots left; Sign in to apply opens the
//      sign-in dialog; the API answers 401.
//   2. Signed in at 390: the form, filled and sent as a person would; the
//      page says Applied. A second application is refused (409).
//   3. The owner, on /beta-admin?tests=1 at 1280: the application with what
//      was read of it (email confirmed, the account's age, its domain, the
//      same inbox, models kept and shared, the form). Approve: the next
//      spot, and with billing test the month given at Admission's test
//      mode, the page then saying the month's days; or, before that, the
//      month pending.
//   4. The approved email: kept, and on a deployment with a mail key,
//      delivered to the throwaway's inbox (Resend's own word, last_event);
//      on a unit's preview, which has none, kept as dry.
//   5. A decline: emailed, and the page says when to apply again.
//   6. The spots left count down; two approvals at once at 99 given make
//      one spot 100 and one refusal; the page then says all are taken.
//   7. Deleting an account (POST /api/account?op=delete, the person's own
//      path) erases its application and its emails.
//
// Pictures in --out. It passes when it ends "beta: all ok".
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
  console.error("beta_flow: --url=<a deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/beta";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-beta-${who}-${rand}@resend.dev`;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const until = (page, test, arg = null, timeout = 20000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const shot = async (page, name, full = false) => {
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// One of supabase/beta.sql's functions, as the server calls it.
async function rpc(name, body) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const reply = await fetch(`${base}/rest/v1/rpc/${name}`, { method: "POST",
    headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" }, body: JSON.stringify(body) });
  if (!reply.ok) throw new Error(`rpc ${name}: ${reply.status}`);
  return reply.json();
}

/// Resend's word on an email it sent: its last event ("delivered"), or
/// "accepted" where this machine's key may only send (Resend answers 401
/// restricted_api_key to a read): Resend took it, with its id, for a test
/// inbox that takes everything, and that is all such a key can learn.
async function resendSaid(id) {
  const key = process.env.RESEND_API_KEY || "";
  if (!key) return "no RESEND_API_KEY here to ask";
  for (let tries = 0; tries < 10; tries += 1) {
    const reply = await fetch(`https://api.resend.com/emails/${id}`, { headers: { authorization: `Bearer ${key}` } });
    const said = await reply.json().catch(() => ({}));
    if (reply.status === 401 && said.name === "restricted_api_key") return "accepted";
    if (said.last_event && said.last_event !== "queued" && said.last_event !== "sent") return said.last_event;
    await new Promise((done) => setTimeout(done, 3000));
  }
  return "not delivered in 30 s";
}

const browser = await launch({ signedOut: true });

/// [pathname] at [width] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { width, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
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
  await page.goto(site + pathname, { waitUntil: "load", timeout: 60000 });
  return { page, context };
}

/// What /beta shows once drawn: the count, which part of the panel, its words.
async function betaSaid(page) {
  await until(page, () => document.getElementById("apply-wait")?.hidden === true);
  return page.evaluate(() => {
    const shown = ["apply-soon", "apply-out", "apply-form", "apply-status"].find((id) => !document.getElementById(id).hidden);
    return { spots: document.getElementById("spots").textContent.trim(), shown,
      words: shown ? document.getElementById(shown).innerText.replace(/\s+/g, " ").trim() : "",
      eyebrow: document.querySelector(".beta-head .eyebrow").innerText.trim(),
      sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 };
  });
}

const form = { build: "A Technic tower crane with a working slewing ring and a two-speed winch.", ai: "claude",
  background: "lego", background_line: "Ten years of Technic", link: "https://rebrickable.com/", terms: true, emails: true };
const made = [];
let deletedA = false;
let owner = null;
try {
  const off = await api("/api/plans?op=beta");
  const on = off.status === 200 && off.json?.beta === "open";
  console.log(`beta flow: ${site} (beta ${on ? "open" : off.json?.beta || off.status})`);

  if (!on) {
    console.log("The beta off: coming soon, and nothing taken");
    check(`GET ?op=beta says off: ${off.status} ${JSON.stringify(off.json)}`, off.status === 200 && off.json?.beta === "off");
    const someone = await mintSession(address("off"));
    made.push(address("off"));
    const r = await api("/api/plans?op=beta", { method: "POST", token: someone.access_token, body: form });
    check(`POST an application is refused: ${r.status} ${r.json?.error}`, r.status === 403 && r.json?.beta === "off");
    for (const [width, theme] of [[390, "dark"], [1280, "light"]]) {
      const { page, context } = await open("/beta", { width, theme, label: `off ${width}` });
      const said = await betaSaid(page);
      check(`${width}: Coming soon, no form, no count: ${said.shown}, "${said.spots}"`, said.shown === "apply-soon"
        && /Coming soon/.test(said.eyebrow) && /Coming soon/.test(said.spots) && !said.sideways);
      check(`${width}: no Apply button`, await page.evaluate(() => document.getElementById("to-apply").hidden));
      await shot(page, `beta-off-${width}-${theme}.png`, true);
      await context.close();
    }
  } else {
    // --- 1. Signed out ---------------------------------------------------------
    console.log("1. Signed out: the spots, and sign in to apply");
    // The checks' pool, three from the end.
    await rpc("beta_test_pool", { p_given: 97 });
    let { page, context } = await open("/beta", { width: 1280, label: "signed out" });
    let said = await betaSaid(page);
    check(`the spots left: "${said.spots}"`, /^\d+ of \d+ spots left$|^All \d+ spots are taken/.test(said.spots));
    check(`Sign in to apply: ${said.shown}`, said.shown === "apply-out");
    await page.click("#sign-in");
    check("Sign in to apply opens the sign-in dialog", await until(page, () => document.querySelector("dialog.sign-in[open]")));
    await shot(page, "beta-signed-out-1280.png");
    await context.close();
    let r = await api("/api/plans?op=beta", { method: "POST", body: form });
    check(`POST signed out: ${r.status}`, r.status === 401);

    // --- 2. Applying -------------------------------------------------------------
    console.log("2. Applying, once");
    const a = await mintSession(address("a"));
    made.push(address("a"));
    ({ page, context } = await open("/beta", { width: 390, theme: "dark", who: a, label: "apply 390" }));
    said = await betaSaid(page);
    check(`signed in: the form, and the checks' spots: "${said.spots}"`, said.shown === "apply-form" && said.spots === "3 of 100 spots left");
    await page.click("#apply-send");
    check("sent empty: the page says what to fix", await until(page, () => /at least 20/.test(document.getElementById("apply-said").textContent)));
    await page.fill("#f-build", form.build);
    await page.selectOption("#f-ai", "claude");
    await page.selectOption("#f-background", "lego");
    await page.fill("#f-line", form.background_line);
    await page.fill("#f-link", "rebrickable.com/users/someone/mocs/");
    await page.check("#f-terms");
    await page.check("#f-emails");
    await shot(page, "beta-form-390-dark.png", true);
    await page.click("#apply-send");
    said = await until(page, () => !document.getElementById("apply-status").hidden) ? await betaSaid(page) : said;
    check(`applied: "${said.words.slice(0, 80)}"`, said.shown === "apply-status" && /^Applied/.test(said.words) && !said.sideways);
    await shot(page, "beta-applied-390-dark.png");
    await context.close();
    r = await api("/api/plans?op=beta", { method: "POST", token: a.access_token, body: form });
    check(`a second application is refused: ${r.status} ${r.json?.error}`, r.status === 409);
    const aId = a.kept.user_id;

    // --- 3. The owner ------------------------------------------------------------
    console.log("3. The owner's queue, and an approval");
    owner = await mintSession(process.env.MASTER_EMAIL, { age: false });
    ({ page, context } = await open("/beta-admin?tests=1", { width: 1280, who: owner, label: "queue" }));
    check("the queue shown to the owner", await until(page, () => document.getElementById("view")?.hidden === false, null, 30000));
    const card = page.locator("li.app", { hasText: address("a") });
    const read = (await card.innerText().catch(() => "")).replace(/\s+/g, " ");
    for (const signal of ["Email confirmed", "Account 0 days old", "Email domain: resend.dev", "Same inbox as",
      "Has not kept or shared a model yet", "The form: 14 words, nothing odd"]) {
      check(`the signals say "${signal}"`, read.includes(signal));
    }
    check("its answers: what, AI, background, link", read.includes(form.build) && read.includes("Claude")
      && read.includes("Builds LEGO® models: Ten years of Technic") && read.includes("https://rebrickable.com/users/someone/mocs/"));
    await shot(page, "beta-queue-1280.png", true);
    await card.locator("input[name=note]").fill("Flow approval");
    await card.getByRole("button", { name: `Approve ${address("a")}` }).click();
    const approved = await until(page, () => /approved, spot/.test(document.getElementById("said").textContent), null, 30000);
    const queueSaid = await page.evaluate(() => document.getElementById("said").textContent);
    check(`approved from the queue: "${queueSaid}"`, approved && /spot 98/.test(queueSaid));
    await context.close();
    const status = (await api("/api/plans?op=beta", { token: a.access_token })).json;
    const app = status?.application;
    check(`spot 98, approved: ${app?.status} ${app?.spot}`, app?.status === "approved" && app?.spot === 98);
    check(`the spots left count down: ${status?.pool?.left}`, status?.pool?.left === 2);
    const granted = app?.comp === "granted" && Date.parse(app.month_ends_at) - Date.parse(app.month_starts_at) === 30 * 86400000;
    check(`the month: ${app?.comp} ${app?.month_starts_at || ""} to ${app?.month_ends_at || ""}`
      + `${granted ? " (given at Admission's test mode)" : " (pending)"}`, granted || app?.comp === "pending");
    ({ page, context } = await open("/beta", { width: 1280, who: a, label: "approved" }));
    said = await betaSaid(page);
    check(`the page: "${said.words.slice(0, 110)}"`, /You are in: spot 98 of 100/.test(said.words)
      && (granted ? /Your month of Pro runs from/.test(said.words) : /starts the day Pro launches/.test(said.words)));
    check(`and counts it: "${said.spots}"`, said.spots === "2 of 100 spots left");
    await shot(page, "beta-approved-1280.png");
    await context.close();

    // --- 4. The approved email ----------------------------------------------------
    console.log("4. The emails");
    const mail = await rpc("beta_mail_of", { p_account: aId });
    const kinds = mail.map((one) => `${one.kind}:${one.state}`);
    check(`kept: ${kinds.join(", ")}`, kinds.includes("received:sent") || kinds.includes("received:dry"));
    const sent = mail.find((one) => one.kind === "approved");
    if (sent?.state === "sent") {
      const word = await resendSaid(sent.sent_id);
      check(`approved email to ${address("a")}, Resend ${sent.sent_id}: ${word}`, ["delivered", "accepted"].includes(word));
    } else {
      check(`approved email kept as ${sent?.state} (no mail key on this deployment: a unit's preview)`, sent?.state === "dry");
    }
    check(`its subject: "${sent?.subject}"`, sent?.subject === "You're in: spot 98 of 100 in the Brickworks beta");

    // --- 5. A decline -------------------------------------------------------------
    console.log("5. A decline");
    const b = await mintSession(address("b"));
    made.push(address("b"));
    r = await api("/api/plans?op=beta", { method: "POST", token: b.access_token, body: form });
    check(`B applied: ${r.status}`, r.status === 200);
    r = await api(`/api/admin?op=beta_decide&account=${b.kept.user_id}`, { method: "POST", token: owner.access_token,
      body: { decision: "decline", note: "Flow decline" } });
    check(`declined: ${r.status} ${r.json?.application?.status}, email ${r.json?.mail}`, r.status === 200
      && r.json?.application?.status === "declined" && ["sent", "dry"].includes(r.json?.mail));
    const declinedMail = (await rpc("beta_mail_of", { p_account: b.kept.user_id })).find((one) => one.kind === "declined");
    check(`the decline's email kept: ${declinedMail?.state} "${declinedMail?.subject}"`, Boolean(declinedMail));
    if (declinedMail?.state === "sent") {
      const word = await resendSaid(declinedMail.sent_id);
      check(`and Resend says: ${word}`, ["delivered", "accepted"].includes(word));
    }
    ({ page, context } = await open("/beta", { width: 390, who: b, label: "declined" }));
    said = await betaSaid(page);
    check(`the page: "${said.words.slice(0, 100)}"`, /Not this time/.test(said.words) && /apply again from/.test(said.words));
    await context.close();

    // --- 6. The last spots ----------------------------------------------------------
    console.log("6. Two approvals at once at 99 given");
    const c = await mintSession(address("c"));
    const d = await mintSession(address("d"));
    made.push(address("c"), address("d"));
    for (const one of [c, d]) await api("/api/plans?op=beta", { method: "POST", token: one.access_token, body: form });
    await rpc("beta_test_pool", { p_given: 99 });
    const both = await Promise.all([c, d].map((one) => api(`/api/admin?op=beta_decide&account=${one.kept.user_id}`,
      { method: "POST", token: owner.access_token, body: { decision: "approve" } })));
    const spots = both.map((one) => one.json?.application?.spot ?? one.json?.refused ?? one.status);
    check(`one spot 100 and one refusal: ${JSON.stringify(spots)}`, spots.filter((s) => s === 100).length === 1
      && both.filter((one) => one.status === 409 && one.json?.refused === "full").length === 1);
    ({ page, context } = await open("/beta", { width: 1280, who: a, label: "full" }));
    said = await betaSaid(page);
    check(`the page says all are taken: "${said.spots}"`, /^All 100 spots are taken/.test(said.spots));
    await context.close();

    // --- 7. Deleting an account -------------------------------------------------------
    console.log("7. Deleting the account erases its application");
    r = await api("/api/account?op=delete", { method: "POST", token: a.access_token, body: { confirm: address("a") } });
    check(`A deleted itself: ${r.status}`, r.status === 200);
    deletedA = r.status === 200;
    const queue = await rpc("beta_queue", { p_status: null, p_tests: true, p_limit: 500 });
    check("its application is gone from the queue", !queue.applications.some((one) => one.email === address("a")));
    check(`and its emails: ${(await rpc("beta_mail_of", { p_account: aId })).length}`,
      (await rpc("beta_mail_of", { p_account: aId })).length === 0);
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  for (const email of made) {
    if (email === address("a") && deletedA) continue;
    await deleteAccount(email).catch(() => {});
  }
  await rpc("beta_test_pool", { p_given: 0 }).catch(() => {});
  await browser.close();
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`beta: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "beta: all ok" : "beta: FAILED");
process.exit(failed === 0 ? 0 : 1);
