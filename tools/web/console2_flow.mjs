// The owner's console, part B (web/admin.html #plans, #mail, #connector,
// #site; docs/ADMIN.md), in a real browser against a deployment, used as
// its owner uses it.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/console2_flow.mjs --url=<deployment> --out=shots/console2
//
//   1. The gate: plans, mail, connector and site answer 401 signed out and
//      404 to an account that is not the owner's; Resend's op
//      (/api/otp?op=mail_event) refuses an event nobody signed.
//   2. Mail: playing Resend's part with this deployment's secret (a unit's
//      preview has the checks' own, which keeps only test inboxes' mail;
//      a release's, RESEND_WEBHOOK_SECRET from .env), a sign-in code sent
//      and delivered to delivered+…@resend.dev and a beta mail bounced at
//      bounced+…@resend.dev; another product's mail let go. The owner
//      (MASTER_EMAIL's session minted, never its sign-in) on /admin?tests=1
//      sees both in Mail, each with what became of it, and the days.
//   3. Connector: a throwaway C switches a tab on and lets a Claude in by
//      OAuth, as claude.ai does; its conversation calls twice. Connector
//      lists C working now with its calls, its conversation, and C's panel
//      (#connector/<id>), reached from C's account in People too.
//   4. Site: the live release and since when, the releases written down,
//      every cron's last runs, Supabase's auth, rest and storage answering.
//      The Overview's live release.
//   5. Plans: off where billing is off, said so; with billing on, the plans
//      and the customers from Admission.
//   6. Each of the four sections at 390 and 1280, light and dark, and C's
//      panel: pictures in --out, nothing sideways.
//
// Read only: nothing here acts on anybody's account or session. C's tab is
// closed and C deleted at the end with everything of theirs. It passes when
// it ends "console2: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { STAND_IN_MAIL_SECRET } from "../../api/_console_mail.js";
import { mkdirSync } from "node:fs";
import { createHash, createHmac, randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("console2_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/console2";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-console2-${who}-${rand}@resend.dev`;
const b64url = (bytes) => Buffer.from(bytes).toString("base64url");

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const shot = async (page, name, full = true) => {
  await page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body, raw, extra = {} } = {}) {
  const sent = { ...headers, ...extra };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined || raw !== undefined) sent["content-type"] = "application/json";
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: raw ?? (body === undefined ? undefined : JSON.stringify(body)) });
  return { status: reply.status, json: await reply.json().catch(() => null), headers: reply.headers };
}

/// Resend's event, signed with [secret] as Svix signs one, sent to this deployment.
function resend(secret, event) {
  const raw = JSON.stringify(event);
  const id = `msg_bwc2${randomBytes(9).toString("hex")}`;
  const at = Math.floor(Date.now() / 1000);
  const signature = createHmac("sha256", Buffer.from(secret.replace(/^whsec_/, ""), "base64")).update(`${id}.${at}.${raw}`).digest("base64");
  return api("/api/otp?op=mail_event", { method: "POST", raw,
    extra: { "svix-id": id, "svix-timestamp": String(at), "svix-signature": `v1,${signature}` } });
}
const mailEvent = (type, to, email, extra = {}) => ({ type: `email.${type}`, created_at: new Date().toISOString(),
  data: { email_id: email, from: extra.from || "Brickworks <noreply@brickworks.diy>", to: [to],
    subject: extra.subject || "123456 is your Brickworks sign-in code", tags: [{ name: "kind", value: extra.kind || "sign_in_code" }],
    ...(extra.data || {}) } });

// C's tab, as the app's connector is: says hello with its tools, and
// answers each call it is handed.
class Tab {
  constructor(session) {
    this.session = session;
    this.token = b64url(randomBytes(32));
    this.id = "consoletab";
    this.instance = `c2${b64url(randomBytes(9))}`;
    this.stopped = false;
    this.answering = null;
    this.answered = 0;
  }
  address(op) {
    return `${site}/api/mcp?t=${this.token}&i=${this.instance}&tab=${this.id}${op ? `&op=${op}` : ""}`;
  }
  async hello() {
    const answer = await fetch(this.address("hello"), { method: "POST",
      headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${this.session}` },
      body: JSON.stringify({ instructions: "The console's check.", model: "Console Lighthouse",
        tools: [{ name: "look_at_model", description: "What is on the baseplate.", inputSchema: { type: "object", properties: {} } }] }) });
    this.answering ||= this.answer();
    return answer.status;
  }
  async answer() {
    while (!this.stopped) {
      this.asking = new AbortController();
      const next = await fetch(this.address("next"), { method: "POST", headers, signal: this.asking.signal }).catch(() => null);
      if (!next || next.status !== 200) {
        if (next && next.status !== 204) await wait(500);
        continue;
      }
      const { id, request } = await next.json();
      if (request.id === undefined || request.id === null) continue;
      this.answered += 1;
      await fetch(`${this.address("answer")}&id=${id}`, { method: "POST", headers: { ...headers, "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: request.id, result: { content: [{ type: "text", text: "a lighthouse, 41 parts" }] } }) });
    }
  }
  async close() {
    this.stopped = true;
    if (this.asking) this.asking.abort();
    await this.answering;
    await fetch(this.address("close"), { method: "POST", headers }).catch(() => {});
  }
}

/// A Claude let into [session]'s account, as claude.ai is: its access token.
async function claudeToken(session) {
  const client = "https://claude.ai/oauth/mcp-oauth-client-metadata";
  const back = "https://claude.ai/api/mcp/auth_callback";
  const verifier = b64url(randomBytes(32));
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${site}/api/oauth?op=approve`, { method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${session}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back, code_challenge: challenge,
      code_challenge_method: "S256", state: "c2", resource: `${site}/api/mcp` }) })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes).slice(0, 200)}`);
  const tokens = await (await fetch(`${site}/oauth/token`, { method: "POST",
    headers: { ...headers, "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back, client_id: client,
      code_verifier: verifier, resource: `${site}/api/mcp` }).toString() })).json();
  return tokens.access_token || "";
}

/// One conversation of that Claude: initialize, then [calls] tool calls.
async function converse(access, calls) {
  let session = "";
  let n = 0;
  const said = [];
  const ask = async (method, params = {}) => {
    const reply = await fetch(`${site}/api/mcp`, { method: "POST",
      headers: { ...headers, "content-type": "application/json", accept: "application/json, text/event-stream",
        authorization: `Bearer ${access}`, ...(session ? { "mcp-session-id": session } : {}) },
      body: JSON.stringify({ jsonrpc: "2.0", ...(method.startsWith("notifications/") ? {} : { id: ++n }), method, params }) });
    session ||= reply.headers.get("mcp-session-id") || "";
    const text = await reply.text();
    return { status: reply.status, text };
  };
  said.push((await ask("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "console2-flow", version: "1" } })).status);
  await ask("notifications/initialized");
  for (let i = 0; i < calls; i += 1) {
    const one = await ask("tools/call", { name: "look_at_model", arguments: {} });
    said.push(/a lighthouse, 41 parts/.test(one.text) ? "answered" : `${one.status} ${one.text.slice(0, 120)}`);
  }
  return { session, said };
}

const browser = await launch({ signedOut: true });

/// [pathname] at [width] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { width = 1280, theme = "light", who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  // The owner's account keeps a theme of its own (web/theme-account.js):
  // kept from here, so each picture is in the theme it is named for.
  await context.route(/\/theme-account\.js(?:\?.*)?$/, (route) => route.fulfill({ status: 200,
    contentType: "text/javascript", body: "export async function follow() {}" }));
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
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const go = async (page, hash) => {
  await page.evaluate((to) => { location.hash = to; }, hash);
  await page.waitForTimeout(300);
};

const made = [];
let tab = null;
try {
  // --- 1. The gate -----------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  for (const op of ["plans", "mail", "connector", "site"]) {
    const signedOut = await api(`/api/admin?op=${op}`);
    const other = await api(`/api/admin?op=${op}`, { token: stranger.access_token });
    check(`GET ${op}: signed out ${signedOut.status}, anybody else ${other.status}`, signedOut.status === 401 && other.status === 404);
  }
  const unsigned = await api("/api/otp?op=mail_event", { method: "POST", body: mailEvent("delivered", address("x"), "em_unsigned") });
  check(`Resend's op, unsigned: ${unsigned.status} "${unsigned.json?.error}"`, [401, 404].includes(unsigned.status));

  const owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname) => api(pathname, { token: owner.access_token });

  // --- 2. Mail ---------------------------------------------------------------------
  console.log("2. Mail, as Resend tells of it");
  const before = (await as("/api/admin?op=mail&tests=1")).json || {};
  const secret = before.checks_secret ? STAND_IN_MAIL_SECRET : String(process.env.RESEND_WEBHOOK_SECRET || "");
  check(`the webhook here: ${before.webhook ? before.checks_secret ? "the checks' own secret" : "Resend's" : "none"}; Mail ready ${before.ready}`,
    before.ready === true && before.webhook === true && Boolean(secret));
  const code = `bwc2${rand}code`;
  const bounce = `bwc2${rand}beta`;
  const toCode = address("mail");
  const toBounce = `bounced+bw-console2-${rand}@resend.dev`;
  const told = [
    await resend(secret, mailEvent("sent", toCode, code)),
    await resend(secret, mailEvent("delivered", toCode, code)),
    await resend(secret, mailEvent("sent", toBounce, bounce, { subject: "You're in the Brickworks beta", kind: "beta" })),
    await resend(secret, mailEvent("bounced", toBounce, bounce, { subject: "You're in the Brickworks beta", kind: "beta",
      data: { bounce: { type: "Permanent", subType: "General", message: "The console's check: no such mailbox" } } })),
  ];
  check(`sent and delivered, sent and bounced: ${told.map((one) => `${one.status} ${one.json?.kept}`).join(", ")}`,
    told.every((one) => one.status === 200 && one.json?.kept === true));
  const foreign = await resend(secret, mailEvent("delivered", address("other"), `bwc2${rand}other`, { from: "Other <hi@other.example>" }));
  check(`another product's mail let go: ${foreign.status} ${foreign.json?.why}`, foreign.status === 200 && foreign.json?.kept === false);
  const forged = await resend(`whsec_${Buffer.from("not this deployment's secret").toString("base64")}`, mailEvent("complained", toCode, code));
  check(`signed with another secret: ${forged.status}`, forged.status === 401);
  const after = (await as("/api/admin?op=mail&tests=1")).json || {};
  const mine = (id) => (after.mails || []).find((one) => one.id === id);
  check(`op=mail: the code ${mine(code)?.states?.join("+")}, the beta mail ${mine(bounce)?.states?.join("+")} (${mine(bounce)?.detail})`,
    mine(code)?.states?.includes("delivered") && mine(bounce)?.states?.includes("bounced") && /no such mailbox/.test(mine(bounce)?.detail || ""));
  const live = (await as("/api/admin?op=mail")).json || {};
  check("...and none of it among the owner's real mail", !(live.mails || []).some((one) => [code, bounce].includes(one.id)));

  const { page, context } = await open("/admin?tests=1#mail", { width: 1280, who: owner, label: "mail" });
  await shown(page);
  check("Mail: the code delivered, the beta mail bounced with why", await until(page, ([a, b]) => {
    const row = (id) => document.querySelector(`#mail-list tr[data-mail="${id}"]`);
    return row(a) && /Delivered/.test(row(a).textContent) && row(b) && /Bounced/.test(row(b).textContent)
      && /no such mailbox/.test(row(b).textContent);
  }, [code, bounce]));
  check("...the days counted", await until(page, () => document.querySelectorAll("#mail-days tr").length > 0
    && Number(document.getElementById("n-mail-bounced").textContent) >= 1));
  await page.click('[data-filter="mail-state"] button[data-value="trouble"]').catch(() => {});
  check("...Trouble alone: the bounce, not the delivered", await until(page, ([a, b]) => {
    const row = (id) => document.querySelector(`#mail-list tr[data-mail="${id}"]`);
    return row(b) && !row(b).hidden && row(a) && row(a).hidden;
  }, [code, bounce], 10000));
  await shot(page, "2-mail-1280.png", false);

  // --- 3. Connector ----------------------------------------------------------------
  console.log("3. Connector: a tab, a Claude, a conversation");
  const c = await mintSession(address("c"), { welcome: false });
  made.push(address("c"));
  tab = new Tab(c.access_token);
  check(`C's tab says hello: ${await tab.hello()}`, true);
  const access = await claudeToken(c.access_token);
  check(`a Claude let into C's account by OAuth: ${access ? "a token" : "none"}`, Boolean(access));
  const talk = await converse(access, 2);
  check(`its conversation calls twice, the tab answering: ${talk.said.join(", ")}`, talk.said[0] === 200
    && talk.said.slice(1).every((one) => one === "answered"));
  const cx = (await as("/api/admin?op=connector&tests=1")).json || {};
  const cRow = (cx.accounts || []).find((one) => one.account === c.kept.user_id);
  check(`op=connector: C ${cRow?.state}, ${cRow?.claudes?.length} Claude, ${cRow?.live_tabs} tab on, calls today ${cRow?.calls?.today}, last ${cRow?.last?.tool}`,
    cRow?.state === "working" && cRow?.claudes?.length === 1 && cRow?.live_tabs === 1 && cRow?.calls?.today >= 2
      && cRow?.last?.tool === "look_at_model");
  const cSession = (cx.sessions || []).find((one) => one.account === c.kept.user_id);
  check(`...its conversation: ${cSession?.chat}, ${cSession?.calls} calls, ${cSession?.live ? "working now" : "not live"}`,
    cSession?.calls === 2 && cSession?.live === true);
  check("...and no account outside the checks' own on ?tests=1", (cx.accounts || []).every((one) => /@resend\.dev$/i.test(one.email || "")));
  await go(page, "connector");
  await page.click("#again").catch(() => {});
  check("Connector: C working now, its conversation listed", await until(page, (id) => {
    const row = document.querySelector(`#cx-accounts tr[data-account="${id}"]`);
    return row && /Working now/.test(row.textContent) && document.querySelector(`#cx-sessions tr[data-account="${id}"]`);
  }, c.kept.user_id));
  await page.click(`#cx-accounts tr[data-account="${c.kept.user_id}"] a`);
  check("C's panel: its calls, its Claude, its tab, its conversation; read only", await until(page, () => {
    const t = document.getElementById("sheet-body")?.textContent || "";
    return document.querySelector("dialog.sheet[open]") && /2 today/.test(t) && /Claudes let in \(1\)/.test(t) && /Tabs \(1\)/.test(t)
      && /Conversations \(1\)/.test(t) && /Read only/.test(t) && !document.querySelector("#sheet-body button");
  }));
  check(`...at its own address: ${await page.evaluate(() => location.hash)}`, await page.evaluate((id) => location.hash === `#connector/${id}`, c.kept.user_id));
  await shot(page, "3-connector-panel-1280.png", false);
  // Each panel opens the other on the same account (each once kept the
  // other's open, as though it were already showing).
  await page.click(`#sheet-body a[href="#people/${c.kept.user_id}"]`);
  check("C's panel links to its account in People, which opens", await until(page, (email) =>
    document.querySelector("dialog.sheet[open]")?.dataset.kind === "person"
    && document.getElementById("sheet-title").textContent === email, c.kept.email));
  await page.keyboard.press("Escape");
  await go(page, `people/${c.kept.user_id}`);
  check("C's account in People links to its connector", await until(page, (id) => document.querySelector("dialog.sheet[open]")
    && document.querySelector(`#sheet-body a[href="#connector/${id}"]`), c.kept.user_id));
  await page.click(`#sheet-body a[href="#connector/${c.kept.user_id}"]`);
  check("...and the link opens C's connector", await until(page, () => document.querySelector("dialog.sheet[open]")?.dataset.kind === "connector"
    && /Conversations \(1\)/.test(document.getElementById("sheet-body")?.textContent || "")));
  await page.keyboard.press("Escape");

  // --- 4. Site ---------------------------------------------------------------------
  console.log("4. Site");
  const s = (await as("/api/admin?op=site")).json || {};
  check(`op=site: ${s.releases?.length} releases (latest ${s.releases?.[0]?.tag}, since ${s.releases?.[0]?.live_at}), `
    + `${s.crons?.length} crons, Supabase ${s.health?.ok ? "answering" : s.health?.fix}`,
  s.releases?.length > 0 && /^rel-m\d+$/.test(s.releases[0].tag) && s.crons?.length === 5 && s.health?.ok === true);
  await go(page, "site");
  check("Site: the live line, health answering, every cron, the releases", await until(page, () =>
    document.getElementById("site-live-h").textContent.length > 1
    && document.querySelectorAll("#health tr").length === 3 && [...document.querySelectorAll("#health tr")].every((tr) => /Answers/.test(tr.textContent))
    && document.querySelectorAll("#crons tr[data-job]").length === 5 && document.querySelectorAll("#releases tr[data-release]").length > 0));
  // Each release's words at the table's own size: its cell once took the
  // site's .title, a section heading's size.
  const sizes = await page.evaluate(() => {
    const row = document.querySelector("#releases tr[data-release]");
    return row ? [...row.querySelectorAll("td")].map((one) => getComputedStyle(one).fontSize) : [];
  });
  check(`...a release's row at one size: ${[...new Set(sizes)].join(", ")}`, sizes.length > 3 && new Set(sizes).size === 1);
  const liveLine = await page.textContent("#site-live-said");
  check(`...the live line says: "${liveLine.slice(0, 140)}"`, /rel-m\d+|commit/.test(liveLine));
  await go(page, "overview");
  check("the Overview: the live release", await until(page, () => /^rel-m\d+$/.test(document.getElementById("n-release").textContent)));

  // --- 5. Plans --------------------------------------------------------------------
  console.log("5. Plans and revenue");
  const p = (await as("/api/admin?op=plans")).json || {};
  await go(page, "plans");
  if (p.billing === "off") {
    check(`billing off here (${p.key ? "a key" : "no key"}): Plans says so and asks Admission nothing`, p.plans === null && await until(page, () =>
      !document.getElementById("plans-off").hidden && /BRICKWORKS_BILLING is off/.test(document.getElementById("plans-off").textContent)));
  } else {
    check(`billing ${p.billing}: ${p.plans?.length} plans, ${p.customers?.length ?? "no"} customers, read token ${p.read}`,
      p.plans?.length > 0 && await until(page, () => document.querySelectorAll("#plan-list tr[data-plan]").length > 0));
  }
  check("...each part says where it is changed: Admission", await page.evaluate(() =>
    ["at-product", "at-customers", "at-revenue", "at-audit"].every((id) => /^https:\/\/admission\.sh/.test(document.getElementById(id).href))));
  await context.close();

  // --- 6. Pictures -----------------------------------------------------------------
  console.log("6. Pictures");
  const SECTIONS = [["plans", () => document.getElementById("plans-setup").children.length > 0],
    ["mail", () => document.querySelectorAll("#mail-list tr[data-mail]").length > 0],
    ["connector", () => document.querySelectorAll("#cx-accounts tr[data-account]").length > 0],
    ["site", () => document.querySelectorAll("#crons tr[data-job]").length > 0],
    ["overview", () => document.getElementById("n-release").textContent !== "—"]];
  for (const [width, theme] of [[1280, "light"], [1280, "dark"], [390, "light"], [390, "dark"]]) {
    const where = await open("/admin?tests=1", { width, theme, who: owner, label: `pictures ${width} ${theme}` });
    await shown(where.page);
    for (const [hash, ready] of SECTIONS) {
      await go(where.page, hash);
      const drawn = await until(where.page, ready);
      const wide = await sideways(where.page);
      check(`${hash} at ${width} ${theme}: drawn, nothing sideways`, drawn && !wide);
      await shot(where.page, `6-${hash}-${width}-${theme}.png`);
    }
    await go(where.page, `connector/${c.kept.user_id}`);
    check(`C's panel at ${width} ${theme}`, await until(where.page, () => /Conversations/.test(document.getElementById("sheet-body")?.textContent || "")));
    await shot(where.page, `6-connector-panel-${width}-${theme}.png`, false);
    await where.context.close();
  }
} catch (trouble) {
  check(`the flow ran: ${String(trouble?.stack || trouble).slice(0, 400)}`, false);
} finally {
  if (tab) await tab.close();
  await browser.close();
  let gone = 0;
  for (const email of made) if (await deleteAccount(email).catch(() => false)) gone += 1;
  check(`the throwaways deleted, with their tab, Claude and calls (${gone} of ${made.length})`, gone === made.length);
}
check(`no page errors: ${errors.join(" | ") || "none"}`, errors.length === 0);
console.log(`console2: ${passed} ok, ${failed} failed`);
console.log(failed === 0 ? "console2: all ok" : "console2: FAILED");
process.exit(failed === 0 ? 0 : 1);
