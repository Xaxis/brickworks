// Feedback (beta374, api/_feedback.js, supabase/feedback.sql), as the people
// who send it and the owner who reads it meet it, in a real browser:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/feedback_flow.mjs --url=<deployment> --out=DIR
//
// Before supabase/feedback.sql is applied (every preview until the lead
// applies it), it checks what can be checked without it: the /feedback
// page, the footer's and the account menu's Send feedback, the dialog on the
// site (kinds, words, the address asked only signed out, a picture chosen,
// shown, removed and chosen again, the details tick) and in the app (Help,
// Send feedback…), each sent and answered "not open here yet" in words; the
// edge's refusals; the settings page and the beta hub saying so too.
//
// With it applied, the whole of it. Held on this machine before then:
//
//   set -a; . ./.env; set +a
//   BRICKWORKS_BETA=open MASTER_EMAIL=delivered+bw-feedback-owner@resend.dev \
//     node tools/web/relay_server.mjs 9060 --static=build/web --hold=feedback &
//   node tools/web/feedback_flow.mjs --url=http://127.0.0.1:9060 \
//     --owner=delivered+bw-feedback-owner@resend.dev --out=DIR
//
// (tools/web/feedback_stand_in.mjs: the SQL files themselves in a Postgres
// of this machine's own.) --owner names the address that server takes for
// its owner; the flow signs in as that throwaway, never as the site's real
// owner, so on a deployment, whose owner is the real one, the inbox is
// checked only as refused to anybody else.
//
//   1. Signed out at 1280, from /faq's footer: an idea, an address, a
//      picture chosen, removed and chosen again, the details ticked; sent.
//   2. Throwaway A at 390, from the account menu: a bug, no address asked;
//      /settings#feedback lists it, Received.
//   3. A in the app (the web build at /app): Help, Send feedback…, the
//      window's picture attached, the version ticked; sent, and the server
//      kept a JPEG and the details.
//   4. Throwaway B applies to the beta and the owner approves it (the beta
//      open): B's account menu has Beta hub, /beta-hub draws what's new, the
//      known issues and the early features, and B's report is a tester's.
//      A, not a tester, is told the hub is for testers; signed out, asked to
//      sign in. Anybody but the owner asking for the inbox gets a 404.
//   5. The owner's inbox (/admin?tests=1#feedback): every report, the
//      filters, the picture shown; A's bug planned with a note, and an
//      answer emailed to A's test inbox. A's settings then say Planned and
//      show the answer, never the note.
//   6. Throwaways deleted the person's own way (POST /api/account?op=delete),
//      and their reports and files with them.
//
// Pictures in --out. It passes when it ends "feedback: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("feedback_flow: --url=<a deployment> [--owner=<its owner's test address>] [--out=DIR] [--app=off]");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/feedback";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-feedback-${who}-${rand}@resend.dev`;
const ownerAddress = typeof args.owner === "string" ? args.owner.trim().toLowerCase() : "";
const NOT_YET = "Feedback is not open here yet. Try again soon.";
// Never the site's real owner: a test inbox the local server was told is
// its owner, or nobody.
if (ownerAddress && (!/@resend\.dev$/.test(ownerAddress)
  || ownerAddress === String(process.env.MASTER_EMAIL || "").trim().toLowerCase())) {
  console.error("feedback_flow: --owner is a resend.dev test address the server was given as MASTER_EMAIL, never the real owner");
  process.exit(2);
}

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

/// What the stand-in holds (tools/web/feedback_stand_in.mjs), or null on a
/// deployment, which has no such thing.
async function held() {
  const reply = await fetch(`${site}/__held/feedback`, { headers }).catch(() => null);
  if (!reply || !reply.ok) return null;
  return reply.json().catch(() => null);
}

const browser = await launch({ signedOut: true });

/// [pathname] at [width] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { width, theme = "light", who = null, label, height }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: height || (phone ? 844 : 900) }, colorScheme: theme,
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

/// The open feedback dialog, as a person reads it.
const dialogSaid = (page) => page.evaluate(() => {
  const dialog = [...document.querySelectorAll("dialog.feedback")].find((d) => d.open);
  if (!dialog) return null;
  const address = dialog.querySelector('input[name="email"]');
  const figure = dialog.querySelector("figure.attached");
  return { kinds: [...dialog.querySelectorAll('input[name="kind"]')].map((k) => `${k.value}${k.checked ? "*" : ""}`),
    asked: Boolean(address && !address.closest("label").hidden && !address.disabled),
    picture: Boolean(figure && !figure.hidden && figure.querySelector("canvas")),
    caption: figure?.querySelector("figcaption")?.textContent || "",
    status: dialog.querySelector('[role="status"]')?.textContent || "",
    said: dialog.querySelector("p")?.textContent || "",
    sent: dialog.dataset.sent || "", reports: Boolean(dialog.querySelector('a[href="/settings#feedback"]')),
    sideways: dialog.scrollWidth > dialog.clientWidth + 1 };
});

/// Send what is filled in, and wait for the answer: sent, or said why not.
async function sendIt(page) {
  await page.locator("dialog.feedback[open] button[type=submit]").click();
  await until(page, () => {
    const dialog = [...document.querySelectorAll("dialog.feedback")].find((d) => d.open);
    const status = dialog?.querySelector('[role="status"]')?.textContent || "";
    return !dialog || dialog.dataset.sent || (status && status !== "Sending…");
  }, null, 60000);
  return dialogSaid(page);
}

const made = [];
const sessions = {};
async function throwaway(who) {
  const email = address(who);
  made.push(email);
  const session = await mintSession(email);
  sessions[email] = session;
  return session;
}

let applied = false;
const sentIds = {};
let A = null;
let B = null;
let owner = null;
let chosen = "";
try {
  A = await throwaway("a");
  const mine = await api("/api/plans?op=feedback", { token: A.access_token });
  applied = mine.status === 200;
  console.log(`feedback flow: ${site} (${applied ? "feedback.sql applied" : `not applied: ${mine.status} ${mine.json?.error || ""}`})`);
  check(`GET your reports answers, or says it is not open yet: ${mine.status}`, applied
    ? Array.isArray(mine.json?.reports) && mine.json.reports.length === 0
    : mine.status === 503 && mine.json?.error === NOT_YET);
  check("signed out, your reports ask for a sign-in (401)", (await api("/api/plans?op=feedback")).status === 401);

  // --- The edge's refusals, before anything is kept -------------------------------
  console.log("The refusals");
  const refusals = [
    ["no kind", { words: "Something floats.", email: address("edge") }, /Choose what it is/],
    ["no words", { kind: "bug", words: "  ", email: address("edge") }, /Say what happened/],
    ["too many words", { kind: "bug", words: "x".repeat(4001), email: address("edge") }, /At most 4000/],
    ["signed out with no address", { kind: "idea", words: "A ramp part." }, /Give an email address/],
    ["a picture that is not one", { kind: "bug", words: "A picture.", email: address("edge"),
      picture: { type: "image/png", data: Buffer.from("not a picture at all").toString("base64") } }, /picture/i],
  ];
  for (const [what, body, words] of refusals) {
    const r = await api("/api/plans?op=feedback", { method: "POST", body });
    check(`${what}: 422 "${r.json?.error}"`, r.status === 422 && words.test(String(r.json?.error || "")));
  }

  // --- The /feedback page, and the footer's link -----------------------------------
  console.log("The /feedback page");
  for (const [width, theme] of [[390, "dark"], [1280, "light"]]) {
    const { page, context } = await open("/feedback", { width, theme, label: `page ${width}` });
    const said = await page.evaluate(() => ({ buttons: [...document.querySelectorAll("a.cta[data-feedback]")].map((a) => a.dataset.feedback),
      footer: Boolean(document.querySelector('.site-foot a[href="/feedback"][data-feedback]')),
      sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }));
    check(`${width}: three ways in (${said.buttons.join(", ")}), the footer's link, nothing sideways`,
      said.buttons.join() === "bug,idea,question" && said.footer && !said.sideways);
    await page.locator('a.cta[data-feedback="question"]').click();
    const dialog = await until(page, () => document.querySelector("dialog.feedback[open]"));
    const state = await dialogSaid(page);
    check(`${width}: A question opens the dialog with A question chosen, an address asked`,
      dialog && state?.kinds.includes("question*") && state.asked && !state.sideways);
    await shot(page, `page-${width}-${theme}.png`);
    await context.close();
  }

  // --- 1. Signed out, from the footer ----------------------------------------------
  console.log("1. Signed out, from /faq's footer");
  {
    const { page, context } = await open("/faq", { width: 1280, label: "signed out" });
    // A picture to choose, as a person has one: this page, as it is.
    chosen = path.resolve(out, "chosen.png");
    writeFileSync(chosen, await page.screenshot());
    await page.locator('.site-foot a[href="/feedback"][data-feedback]').click();
    check("the footer's Send feedback opens the dialog on the page, nothing chosen",
      await until(page, () => document.querySelector("dialog.feedback[open]"))
      && (await dialogSaid(page)).kinds.every((k) => !k.endsWith("*")));
    const dialog = page.locator("dialog.feedback[open]");
    await dialog.locator('input[name="kind"][value="idea"]').check();
    await dialog.locator('textarea[name="words"]').fill(`A rack for every road plate in the bin. (feedback flow ${rand})`);
    await dialog.locator('input[name="email"]').fill(address("visitor"));
    const choose = async () => {
      const [chooser] = await Promise.all([page.waitForEvent("filechooser"), dialog.getByRole("button", { name: "Choose a picture…" }).click()]);
      await chooser.setFiles(chosen);
      return until(page, () => document.querySelector("dialog.feedback[open] figure.attached:not([hidden]) canvas"));
    };
    const shown = await choose();
    const caption = (await dialogSaid(page))?.caption || "";
    check(`Choose a picture… shows it, small, with its size ("${caption}")`, shown && /\d+ × \d+, \d+ kB/.test(caption));
    await shot(page, "1-signed-out-picture.png");
    await dialog.getByRole("button", { name: "Remove the picture" }).click();
    check("Remove the picture takes it off", !(await dialogSaid(page)).picture);
    check("chosen again, it is back", await choose());
    await dialog.locator('input[name="details"]').check();
    const said = await sendIt(page);
    if (applied) {
      sentIds.visitor = Number(said?.sent);
      check(`sent, and thanked with how we answer: "${said?.said}"`, sentIds.visitor > 0 && /answer by email/.test(said.said)
        && !said.reports);
    } else {
      check(`said, in words, that it is not open yet: "${said?.status}"`, said?.status === NOT_YET && !said.sent);
    }
    await shot(page, "1-signed-out-sent.png");
    await context.close();
    const kept = await held();
    if (applied && kept) {
      const row = kept.reports.find((one) => one.id === sentIds.visitor);
      const file = kept.files.find((one) => one.name === row?.picture);
      check(`kept: an idea, the address, the page, no account (${JSON.stringify(row && { kind: row.kind, page: row.page, test: row.test })})`,
        row?.kind === "idea" && row.email === address("visitor") && !row.account && row.page === "/faq" && row.source === "site"
        && row.test === true);
      check(`the picture kept as a JPEG in the private bucket (${file?.name}, ${file?.size} bytes)`,
        file?.type === "image/jpeg" && file.size > 2000);
    }
  }

  // --- 2. A, signed in, from the account menu --------------------------------------
  console.log("2. A at 390, from the account menu");
  {
    const { page, context } = await open("/gallery", { width: 390, theme: "dark", who: A, label: "A menu" });
    await until(page, () => document.querySelector(".site-head .menu summary.account-btn"), null, 30000);
    await page.locator(".site-head .menu summary").click();
    const link = page.locator('.site-head .menu [data-place="feedback"]');
    check("the account menu has Send feedback", await link.isVisible().catch(() => false));
    check("and no Beta hub for an account that is not a tester",
      !(await page.locator('.site-head [data-place="beta-hub"]').count()));
    await link.click();
    check("it opens the dialog, with no address asked", await until(page, () => document.querySelector("dialog.feedback[open]"))
      && !(await dialogSaid(page)).asked);
    const dialog = page.locator("dialog.feedback[open]");
    await dialog.locator('input[name="kind"][value="bug"]').check();
    await dialog.locator('textarea[name="words"]').fill(`The second brick floats after an undo. (feedback flow ${rand})`);
    await shot(page, "2-a-phone-dialog.png");
    const said = await sendIt(page);
    if (applied) {
      sentIds.a = Number(said?.sent);
      check(`sent; the answer points at the settings page: "${said?.said}"`, sentIds.a > 0 && /settings page/.test(said.said)
        && said.reports);
    } else {
      check(`said that it is not open yet: "${said?.status}"`, said?.status === NOT_YET && !said.sent);
    }
    await page.goto(`${site}/settings#feedback`, { waitUntil: "load" });
    // Drawn once the server has answered, and shown with the rest of the
    // page: the list, or the words saying why not.
    await until(page, () => document.getElementById("signed-in")?.hidden === false
      && (document.querySelectorAll("#reports li.report").length > 0
      || /not open|did not load|Nothing sent/.test(document.getElementById("feedback-said")?.textContent || "")), null, 60000);
    await page.locator("#feedback").scrollIntoViewIfNeeded().catch(() => {});
    const listed = await page.evaluate(() => ({ said: document.getElementById("feedback-said").textContent,
      shown: document.getElementById("signed-in").hidden === false,
      reports: [...document.querySelectorAll("#reports li.report")].map((li) => li.innerText.replace(/\s+/g, " ")) }));
    if (applied) {
      check(`/settings#feedback lists it: something wrong, Received (${listed.reports[0]?.slice(0, 80)})`, listed.shown
        && listed.reports.length === 1
        && /Something wrong/.test(listed.reports[0]) && /Received/.test(listed.reports[0]) && listed.reports[0].includes(rand));
    } else {
      check(`/settings#feedback says it is not open yet: "${listed.said}"`, listed.shown && /not open here yet/.test(listed.said));
    }
    await shot(page, "2-a-settings.png");
    await context.close();
  }

  // --- 3. A, in the app -----------------------------------------------------------
  console.log("3. A in the app: Help, Send feedback…");
  const app = await fetch(`${site}/app`, { headers }).catch(() => null);
  if (args.app === "off" || !app?.ok) {
    skip(`no app at ${site}/app (${app?.status ?? "unreachable"}): run the local server with --static=build/web`);
  } else {
    const { page, context } = await open("/app", { width: 1400, height: 900, who: A, label: "app" });
    const named = () => page.evaluate(() => window.brickworksControls || {});
    const press = async (name) => {
      const end = Date.now() + 60000;
      for (;;) {
        let at = (await named())[name];
        for (let n = 0; at && n < 6; n += 1) {
          await page.waitForTimeout(550);
          const again = (await named())[name];
          if (again && again.x === at.x && again.y === at.y) break;
          at = again;
        }
        if (at) {
          await page.mouse.click(at.x, at.y);
          await page.waitForTimeout(400);
          return true;
        }
        if (Date.now() > end) return false;
        await page.waitForTimeout(500);
      }
    };
    const signedIn = await until(page, () => (window.brickworksAccount || {}).state === "signed_in", null, 240000);
    check("the app is up, signed in as A", signedIn);
    check("A's early features: none", await page.evaluate(() => (window.brickworksAccount?.early || []).length === 0));
    const helpUp = await until(page, () => Boolean((window.brickworksControls || {}).menu_help), null, 120000);
    if (check("Help is on the page", helpUp)) {
      await press("menu_help");
      await page.waitForTimeout(1200);
      await page.keyboard.type("Send", { delay: 120 });
      await page.waitForTimeout(600);
      await page.keyboard.press("Enter");
      const up = await until(page, () => Boolean((window.brickworksControls || {}).feedback_words), null, 30000);
      const state = () => page.evaluate(() => window.brickworksState?.feedback || {});
      const first = await state();
      check(`the dialog is up, the window's picture attached (${JSON.stringify(first.picture_size)}), no address asked`,
        up && first.open && first.picture && !first.email_asked);
      await press("feedback_bug");
      await press("feedback_words");
      await page.keyboard.type(`The booklet skips step 4. (feedback flow ${rand})`, { delay: 15 });
      await press("feedback_version");
      await shot(page, "3-app-dialog.png");
      await press("feedback_send");
      await until(page, () => {
        const status = window.brickworksState?.feedback?.status || "";
        return status && status !== "Sending…";
      }, null, 60000);
      const after = await state();
      if (applied) {
        sentIds.app = Number(after.answer?.id);
        check(`sent from the app, the answer said: "${after.status}"`, after.sent && sentIds.app > 0 && /settings page/.test(after.status));
      } else {
        check(`the app says it is not open yet: "${after.status}"`, after.status === NOT_YET && !after.sent);
      }
      await shot(page, "3-app-sent.png");
      const kept = await held();
      if (applied && kept) {
        const row = kept.reports.find((one) => one.id === sentIds.app);
        const file = kept.files.find((one) => one.name === row?.picture);
        check(`kept: the app's, on the web, A's, the window's picture (${file?.size} bytes)`, row?.source === "app"
          && row.page === "web" && row.account === A.kept.user_id && file?.type === "image/jpeg" && file.size > 5000);
      }
    }
    await context.close();
  }

  // --- 4. The beta hub, and a tester's report ---------------------------------------
  console.log("4. The beta hub");
  {
    const { page, context } = await open("/beta-hub", { width: 1280, label: "hub signed out" });
    check("signed out, the hub asks for a sign-in", await until(page, () => document.getElementById("signed-out")?.hidden === false));
    await context.close();
  }
  {
    const { page, context } = await open("/beta-hub", { width: 1280, who: A, label: "hub A" });
    const shown = await until(page, () => document.getElementById("state")?.textContent
      && (document.getElementById("not-tester")?.hidden === false || /not open|did not load/i.test(document.getElementById("state").textContent)), null, 30000);
    if (applied) {
      check("A, not a tester, is told the hub is for testers, and how to tell us anyway",
        shown && await page.evaluate(() => document.getElementById("not-tester").hidden === false
          && Boolean(document.querySelector('#not-tester a[data-feedback]'))));
    } else {
      check(`A is told the hub did not load: "${await page.locator("#state").textContent()}"`, shown);
    }
    await shot(page, "4-hub-not-tester.png");
    await context.close();
  }
  const beta = await api("/api/plans?op=beta");
  if (!applied) {
    skip("a tester's hub and report: once feedback.sql is applied");
  } else if (beta.json?.beta !== "open" || !ownerAddress) {
    skip(`a tester's hub and report: needs the beta open (${beta.json?.beta}) and --owner`);
  } else {
    owner = await mintSession(ownerAddress);
    made.push(ownerAddress);
    B = await throwaway("b");
    const form = { build: "A Technic tower crane with a working slewing ring and a two-speed winch.", ai: "claude",
      background: "lego", background_line: "Ten years of Technic", link: "https://rebrickable.com/", terms: true, emails: true };
    const applying = await api("/api/plans?op=beta", { method: "POST", token: B.access_token, body: form });
    check(`B applies to the beta: ${applying.status}`, applying.status === 200);
    const decided = await api(`/api/admin?op=beta_decide&account=${B.kept.user_id}`, { method: "POST", token: owner.access_token,
      body: { decision: "approve" } });
    check(`the owner approves B: ${decided.status} ${decided.json?.error || ""}`, decided.status === 200);
    const who = await api("/api/account", { token: B.access_token });
    check(`B's account says tester, with the beta hub early (${JSON.stringify(who.json?.beta)})`,
      who.json?.beta?.tester === true && who.json.beta.early.includes("beta_hub"));
    const { page, context } = await open("/beta-hub", { width: 1280, theme: "dark", who: B, label: "hub B" });
    check("B's hub draws what's new, the known issues and the early features", await until(page, () =>
      document.getElementById("hub")?.hidden === false && document.querySelectorAll("#new li").length > 0
      && document.querySelectorAll("#known li").length > 0 && document.querySelectorAll("#early li").length > 0, null, 30000));
    await page.locator(".site-head .account-menu summary").click();
    check("B's account menu has Beta hub", await until(page, () =>
      Boolean(document.querySelector('.site-head .account-menu [data-place="beta-hub"]')), null, 15000));
    await shot(page, "4-hub-tester.png", true);
    await page.keyboard.press("Escape");
    await page.locator('#hub a.cta[data-feedback="bug"]').click();
    await until(page, () => document.querySelector("dialog.feedback[open]"));
    const dialog = page.locator("dialog.feedback[open]");
    await dialog.locator('textarea[name="words"]').fill(`Snapping a hinge plate rotates the wrong way. (feedback flow ${rand})`);
    const said = await sendIt(page);
    sentIds.b = Number(said?.sent);
    check("the hub's Send feedback sends B's bug", sentIds.b > 0);
    await context.close();
    const mineB = await api("/api/plans?op=feedback", { token: B.access_token });
    check("B's report is marked a tester's", mineB.json?.beta === true && mineB.json.reports?.[0]?.beta === true);
  }

  // --- 5. The owner's inbox ---------------------------------------------------------
  console.log("5. The owner's inbox");
  const refused = await api("/api/admin?op=feedback", { token: A.access_token });
  // 404, as for any admin op: a 403 would tell anybody signed in there is one.
  check(`anybody else is refused the inbox: ${refused.status}`, refused.status === 404);
  if (!applied || !ownerAddress) {
    skip(applied ? "the inbox itself: needs --owner (never the site's real owner)" : "the inbox itself: once feedback.sql is applied");
  } else {
    owner ??= await mintSession(ownerAddress);
    if (!made.includes(ownerAddress)) made.push(ownerAddress);
    const { page, context } = await open("/admin?tests=1#feedback", { width: 1280, who: owner, label: "inbox" });
    const listed = () => page.evaluate(() => [...document.querySelectorAll("#fb-list > li")].map((li) => ({
      id: Number(li.dataset.report), status: li.dataset.status, text: li.innerText.replace(/\s+/g, " ") })));
    await until(page, () => document.querySelectorAll("#fb-list > li").length > 0, null, 30000);
    let cards = await listed();
    const ids = Object.values(sentIds);
    check(`every report of this run is there (${ids.join(", ")})`, ids.every((id) => cards.some((c) => c.id === id)));
    const visitor = cards.find((c) => c.id === sentIds.visitor);
    check("the visitor's: an idea, their address, signed out", /Idea/.test(visitor?.text) && visitor.text.includes(address("visitor"))
      && /signed out/.test(visitor.text));
    if (sentIds.b) check("B's is marked Beta tester", /Beta tester/.test(cards.find((c) => c.id === sentIds.b)?.text));
    await page.locator('#fb-filters [data-filter="kind"] button[data-value="bug"]').click();
    await page.waitForTimeout(1500);
    cards = await listed();
    check(`Bugs shows bugs alone (${cards.length})`, cards.length > 0 && cards.every((c) => /^Bug/.test(c.text))
      && !cards.some((c) => c.id === sentIds.visitor));
    if (sentIds.b) {
      await page.locator('#fb-filters [data-filter="beta"] button[data-value="1"]').click();
      await page.waitForTimeout(1500);
      cards = await listed();
      check(`Testers shows testers' alone (${cards.map((c) => c.id).join(", ")})`, cards.some((c) => c.id === sentIds.b)
        && !cards.some((c) => c.id === sentIds.a));
      await page.locator('#fb-filters [data-filter="beta"] button[data-value=""]').click();
    }
    await page.locator('#fb-filters [data-filter="kind"] button[data-value=""]').click();
    await page.waitForTimeout(1500);
    const card = (id) => page.locator(`#feedback-${id}`);
    await card(sentIds.visitor).getByRole("button", { name: "Show the picture" }).click();
    check("Show the picture shows it", await until(page, (id) => {
      const img = document.querySelector(`#feedback-${id} img.picture`);
      return img && img.complete && img.naturalWidth > 100;
    }, sentIds.visitor));
    await card(sentIds.a).locator("select").selectOption("planned");
    await card(sentIds.a).locator("form textarea").first().fill(`A note for the owner alone ${rand}`);
    await card(sentIds.a).getByRole("button", { name: "Save" }).click();
    check("A's bug planned, with a note", await until(page, (id) => document.getElementById(`feedback-${id}`)?.dataset.status === "planned"
      && /Saved/.test(document.getElementById(`feedback-${id}`).innerText), sentIds.a));
    await card(sentIds.a).locator('textarea[aria-label^="Your answer"]').fill(`Thanks: it is planned for the next release. (${rand})`);
    await card(sentIds.a).getByRole("button", { name: "Send the answer" }).click();
    check("the answer sent, and kept with the report", await until(page, (id) => {
      const text = document.getElementById(`feedback-${id}`)?.innerText || "";
      return /Emailed\.|Kept: a test inbox/.test(text) && /planned for the next release/.test(text);
    }, sentIds.a, 60000));
    const kept = await held();
    if (kept) {
      const reply = kept.replies.find((one) => one.feedback === sentIds.a);
      check(`the answer kept: mail ${reply?.mail}`, reply && ["sent", "dry"].includes(reply.mail));
    }
    await page.locator("#fb-list").screenshot({ path: path.join(out, "5-inbox.png") }).catch(() => {});
    await context.close();

    const back = await open("/settings#feedback", { width: 1280, who: A, label: "A after" });
    await until(back.page, () => document.getElementById("signed-in")?.hidden === false
      && document.querySelectorAll("#reports li.report").length > 0, null, 60000);
    await back.page.locator("#feedback").scrollIntoViewIfNeeded().catch(() => {});
    const seen = await back.page.evaluate((id) => document.querySelector(`#reports li[data-report="${id}"]`)?.innerText || "", sentIds.a);
    const shown = await back.page.evaluate(() => document.getElementById("signed-in").hidden === false);
    check("A's settings: Planned, with our answer, and never the note", shown && /Planned/.test(seen) && /Our answer/.test(seen)
      && /planned for the next release/.test(seen) && !seen.includes("A note for the owner"));
    await shot(back.page, "5-a-settings-after.png");
    await back.context.close();
  }

  // --- 6. Deleted the person's own way ---------------------------------------------
  console.log("6. Deleting the throwaways");
  for (const [who, session] of [["A", A], ["B", B]]) {
    if (!session) continue;
    const gone = await api("/api/account?op=delete", { method: "POST", token: session.access_token, body: { confirm: session.kept.email } });
    check(`${who} deleted: ${gone.status}`, gone.status === 200);
  }
  const kept = await held();
  if (applied && kept) {
    const left = kept.reports.filter((one) => [sentIds.a, sentIds.app, sentIds.b].includes(one.id));
    const files = kept.files.filter((one) => [sentIds.a, sentIds.app, sentIds.b].some((id) => one.name.startsWith(`${id}/`)));
    check(`their reports and files gone with them (${left.length} reports, ${files.length} files left)`, !left.length && !files.length);
  }
} catch (trouble) {
  check(`ran to the end: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  for (const email of made) await deleteAccount(email).catch(() => false);
  await browser.close();
}

check(`no page errors${errors.length ? `: ${errors.slice(0, 4).join(" | ")}` : ""}`, errors.length === 0);
console.log(failed ? `feedback: ${failed} FAILED, ${passed} ok` : "feedback: all ok");
process.exit(failed ? 1 : 0);
