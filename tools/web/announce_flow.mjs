// The owner's announcements (announce, docs/ANNOUNCE.md, /admin ›
// Announcements) in a real browser, as the owner and the people they reach:
//
//   node --env-file=.env tools/web/announce_flow.mjs --url=<a deployment> --out=DIR
//
// Never on brickworks.diy: its visitors would see the check's notice. On a
// preview, and on this machine's server, everything here is the checks' own
// pool: an announcement reaches only throwaways at resend.dev and mails
// nobody, and each deployment counts its own (supabase/announce.sql scope).
// Before supabase/announce.sql is applied (or with the stand-in,
// tools/web/announce_stand_in.mjs, when it is not):
//
//   1. Every op refused signed out (401) and to anybody else (404).
//   2. Before the file: the section says so and its buttons are off; the
//      Settings news choice is hidden; nothing else is asked. Stops there.
//   3. A throwaway (Ann) turns on Brickworks news in Settings (off until
//      then), kept across a reload; Bea, another, leaves it off.
//   4. The owner in the console: the day's most set to 3; an announcement
//      written for Ann by handle, its preview drawn by the page's own code
//      (the group and the menu line, shadowed) and its reach of 1; Review,
//      then Enter twice on Send now: one send, one row, reach 1.
//   5. Ann's Notifications: the group by its title and words, her menu's
//      count; its link followed: read and clicked, counted in Sent.
//   6. Edited for everyone (look, then change): Ann's says edited.
//   7. A second scheduled for tomorrow, then changed: a draft again. Today's
//      most at 1: Send now refused with words, still a draft. Dropped.
//   8. The first withdrawn: gone from Ann's Notifications.
//   9. The console's Write and Sent at 1280, 390 and 430x932, light and
//      dark, with nothing sideways; every control in the section has a name
//      a screen reader says; the form is walked by Tab alone; the
//      console's first screen never asks admin-announce.js; and at 430x932
//      New keeps what was typed as a draft, saying so where it can be seen.
//  10. The site notice with an end: Ann hides it and it stays hidden in a
//      browser of hers that never saw it; Bea still sees it. Cleared after.
//
// Throwaways deleted after; announcements left in the pool are its own.
// Prints "announce: all ok".
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
  console.error("announce_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const host = new URL(site).host;
if (/^(?:www\.)?brickworks\.diy$/.test(host)) {
  console.error("announce_flow: never on brickworks.diy (a notice there is seen by everyone)");
  process.exit(2);
}
const out = args.out || "shots/announce";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-announce-${who}-${rand}@resend.dev`;
const HANDLE = `an-${rand}`;

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
const shot = async (page, name) => {
  await page.screenshot({ path: path.join(out, name), fullPage: false, timeout: 60000 })
    .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
};

let asked = 0;
async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const where = method === "GET" ? `${pathname}${pathname.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}` : pathname;
  const reply = await fetch(site + where, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });
const SIZES = { laptop: { width: 1280, height: 900 }, phone: { width: 390, height: 844 }, tall: { width: 430, height: 932 } };

/// [pathname] in a browser of its own at [size] in [theme], signed in as [who] (a mintSession) or out.
async function open(pathname, { size = "laptop", theme = "light", who = null, label, requests = null }) {
  const view = SIZES[size];
  const phone = view.width < 600;
  const context = await browser.newContext({ viewport: view, colorScheme: theme, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  // The owner's account keeps a theme of its own: kept from here, so each
  // picture is in the theme it is named for.
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
  if (requests) page.on("request", (one) => requests.push(one.url().replace(/^https?:\/\/[^/]+/, "")));
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${label}: ${m.text().slice(0, 220)}`);
    }
  });
  page.on("dialog", (dialog) => dialog.accept());
  await page.goto(site + pathname, { waitUntil: "load", timeout: 120000 });
  return { page, context };
}
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const shown = (page) => until(page, () => document.getElementById("view")?.hidden === false, null, 60000);
const section = '[data-section="announcements"]';
const textOf = (page, selector) => page.evaluate((s) => document.querySelector(s)?.textContent.replace(/\s+/g, " ").trim() || "", selector);

/// The owner's console, opened at [hash], its section drawn.
async function console_(hash, options) {
  const at = await open(`/admin${hash}`, options);
  await shown(at.page);
  await until(at.page, (s) => {
    const part = document.querySelector(s);
    return part && !part.hidden && (document.getElementById("announce-today")?.textContent || document.getElementById("announce-not-yet")?.textContent);
  }, section, 60000);
  return at;
}

// --- the names a screen reader says (as tools/web/a11y_flow.mjs reads them) --
const ACTED = new Set(["link", "button", "textbox", "searchbox", "combobox", "checkbox", "radio", "menuitem", "tab", "switch",
  "slider", "spinbutton", "listbox", "PopUpButton", "DisclosureTriangle", "ToggleButton"]);
/// Each control a person acts on in [scope] whose name says nothing: [{role, name}].
async function nameless(page, scope) {
  const session = await page.context().newCDPSession(page);
  try {
    const { nodes } = await session.send("Accessibility.getFullAXTree");
    const { root } = await session.send("DOM.getDocument", { depth: -1, pierce: true });
    const { nodeId } = await session.send("DOM.querySelector", { nodeId: root.nodeId, selector: scope });
    const inside = new Set();
    const gather = (node, under) => {
      const now = under || node.nodeId === nodeId;
      if (now) inside.add(node.backendNodeId);
      for (const child of [...(node.children || []), ...(node.shadowRoots || [])]) gather(child, now);
    };
    if (nodeId) gather(root, false);
    return nodes.filter((one) => !one.ignored && ACTED.has(one.role?.value) && inside.has(one.backendDOMNodeId))
      .map((one) => ({ role: one.role.value, name: String(one.name?.value || "").replace(/\s+/g, " ").trim() }))
      .filter((one) => !one.name || /^[\d\s.,·:;!?()+\-–—#×✓…]*$/.test(one.name) || /^(button|link|icon|undefined|null)$/i.test(one.name));
  } finally {
    await session.detach().catch(() => {});
  }
}

const made = [];
let owner = null;
let noticeSet = false;
const ids = [];
try {
  // --- 1. The gate -------------------------------------------------------------
  console.log("1. The gate");
  const stranger = await mintSession(address("x"), { welcome: false });
  made.push(address("x"));
  owner = await mintSession(process.env.MASTER_EMAIL, { age: false, welcome: false });
  const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
  for (const [op, method] of [["announce", "GET"], ["announce_preview", "GET"], ["announce_keep", "POST"], ["announce_send", "POST"],
    ["announce_withdraw", "POST"], ["announce_limit", "POST"]]) {
    const body = method === "POST" ? { title: "Never", audience: { kind: "everyone" } } : undefined;
    const out1 = await api(`/api/admin?op=${op}`, { method, body });
    const theirs = await api(`/api/admin?op=${op}`, { method, body, token: stranger.access_token });
    check(`${method} ${op}: signed out ${out1.status}, anybody else ${theirs.status}`, out1.status === 401 && theirs.status === 404);
  }
  const desk = await as("/api/admin?op=announce");
  check(`the owner's desk answers: ${desk.status}`, desk.status === 200);
  const ready = desk.json?.ready === true;
  console.log(`  --    supabase/announce.sql ${ready ? "applied (or stood in for)" : "not applied"}; test pool ${desk.json?.test}`);
  check("everything here is the checks' own pool", desk.json?.test === true);

  // The console's first screen never asks the section's code.
  {
    const requests = [];
    const { page, context } = await open("/admin", { label: "first screen", who: owner, requests });
    await shown(page);
    await page.waitForTimeout(1500);
    check(`the console's first screen never asks admin-announce.js (${requests.filter((p) => p.split("?")[0].endsWith(".js")).length} scripts)`,
      !requests.some((p) => p.split("?")[0].endsWith("/admin-announce.js")));
    await page.evaluate(() => { location.hash = "#announcements"; });
    check("opening Announcements asks it", await until(page, () => performance.getEntriesByType("resource")
      .some((one) => one.name.includes("/admin-announce.js")), null, 30000));
    await context.close();
  }

  const ann = await mintSession(address("ann"));
  made.push(address("ann"));
  const bea = await mintSession(address("bea"));
  made.push(address("bea"));
  const profile = await api("/api/people?op=profile", { method: "POST", token: ann.access_token, body: { handle: HANDLE, name: "Ann Announce" } });
  check(`Ann's handle @${HANDLE}: ${profile.status}`, profile.status === 200);

  if (!ready) {
    // --- 2. Before the file ------------------------------------------------------
    console.log("2. Before supabase/announce.sql");
    for (const [size, theme] of [["laptop", "light"], ["phone", "dark"]]) {
      const { page, context } = await console_("#announcements/write", { size, theme, who: owner, label: `console ${size}` });
      const said = await textOf(page, "#announce-not-yet");
      const off = await page.evaluate(() => [...document.querySelectorAll("#announce-form button")].every((b) => b.disabled));
      check(`${size} ${theme}: says "${said.slice(0, 70)}", its buttons off, nothing sideways`,
        /announce\.sql/.test(said) && off && !(await sideways(page)));
      await shot(page, `before_${size}_${theme}.png`);
      await context.close();
    }
    const { page, context } = await open("/settings", { who: ann, label: "settings before" });
    await until(page, () => document.getElementById("who")?.textContent, null, 30000);
    await page.waitForTimeout(800);
    check("Settings' news choice hidden until the file", await page.evaluate(() => document.getElementById("news-choice")?.hidden === true));
    await context.close();
  } else {
    // --- 3. Ann asks for news; Bea does not --------------------------------------
    console.log("3. Settings › Email › Brickworks news");
    {
      const { page, context } = await open("/settings#email-part", { who: ann, label: "settings ann" });
      const offered = await until(page, () => document.getElementById("news-choice")?.hidden === false, null, 30000);
      const before = await page.evaluate(() => document.getElementById("mail-news").checked);
      check(`offered, and off until chosen: shown ${offered}, on ${before}`, offered && before === false);
      await page.click("#mail-news");
      const said = await until(page, () => /^On:/.test(document.getElementById("mail-said")?.textContent || ""), null, 15000);
      await page.reload({ waitUntil: "load" });
      await until(page, () => document.getElementById("news-choice")?.hidden === false, null, 30000);
      check(`turned on, said so (${said}) and kept across a reload`, said && await page.evaluate(() => document.getElementById("mail-news").checked));
      await context.close();
      const theirs = await open("/settings", { size: "phone", theme: "dark", who: bea, label: "settings bea" });
      await until(theirs.page, () => document.getElementById("news-choice")?.hidden === false, null, 30000);
      await theirs.page.locator("#news-choice").scrollIntoViewIfNeeded().catch(() => {});
      check("Bea's is off, at 390 in dark, nothing sideways", !(await theirs.page.evaluate(() => document.getElementById("mail-news").checked))
        && !(await sideways(theirs.page)));
      await shot(theirs.page, "settings_news_390_dark.png");
      await theirs.context.close();
    }

    // --- 4. Written, looked at, sent once ----------------------------------------
    console.log("4. Write, Review, Send now");
    const title = `Flow ${rand}: new parts in the bin`;
    const words = "Two hundred new parts.\nEach one at true size.";
    const { page, context } = await console_("#announcements/settings", { who: owner, label: "console" });
    await page.fill('#announce-most-form [name="most"]', "3");
    await page.press('#announce-most-form [name="most"]', "Enter");
    const most3 = await until(page, () => /at most 3 a day/.test(document.getElementById("announce-most-note")?.textContent || ""), null, 15000);
    check(`the day's most set: "${await textOf(page, "#announce-most-note")}"`, most3);
    await page.evaluate(() => { location.hash = "#announcements/write"; });
    await page.fill('#announce-form [name="title"]', title);
    await page.fill('#announce-form [name="body"]', words);
    await page.fill('#announce-form [name="link"]', "/gallery");
    await page.selectOption("#announce-kind", "person");
    await page.fill('#announce-form [name="handle"]', `@${HANDLE}`);
    const counted = await until(page, () => /^Reaches 1 person/.test(document.getElementById("announce-count")?.textContent || ""), null, 20000);
    check(`its reach before it goes: "${await textOf(page, "#announce-count")}"`, counted);
    const drawn = await page.evaluate(() => {
      const roots = [...document.querySelectorAll("#announce-shown *")].map((el) => el.shadowRoot).filter(Boolean);
      const text = roots.map((r) => r.textContent.replace(/\s+/g, " ")).join(" | ");
      return { roots: roots.length, text, sheets: roots.flatMap((r) => [...r.querySelectorAll('link[rel="stylesheet"]')].map((l) => l.getAttribute("href"))) };
    });
    check(`the preview drawn by the site's own styles: ${drawn.roots} places, ${drawn.sheets.join(" ")}`,
      drawn.roots >= 2 && drawn.sheets.includes("/site.css") && drawn.text.includes(title) && drawn.text.includes("Two hundred new parts.")
      && /Notifications\s*1/.test(drawn.text));
    const names = await nameless(page, section);
    check(`every control in Write has a name: ${names.length ? JSON.stringify(names.slice(0, 5)) : "all"}`, names.length === 0);
    // By keyboard alone: from the title to Review and send.
    await page.focus('#announce-form [name="title"]');
    let reached = false;
    for (let at = 0; at < 25 && !reached; at += 1) {
      await page.keyboard.press("Tab");
      reached = await page.evaluate(() => document.activeElement?.id === "announce-review");
    }
    check("Tab alone walks the form to Review and send", reached);
    for (const [size, theme] of [["laptop", "light"]]) await shot(page, `write_${size}_${theme}.png`);
    await page.keyboard.press("Enter");
    const opened = await until(page, () => document.getElementById("announce-sheet")?.open === true
      && /Send now/.test(document.getElementById("announce-sheet-body")?.textContent || ""), null, 20000);
    // Its words and the group drawn in its own place (a shadow root) too.
    const sheetSays = await page.evaluate(() => {
      const body = document.getElementById("announce-sheet-body");
      const shadows = [...(body?.querySelectorAll("*") || [])].map((el) => el.shadowRoot?.textContent || "").join(" ");
      return `${body?.textContent || ""} ${shadows}`.replace(/\s+/g, " ").trim();
    });
    check(`Review shows it, for 1 person: "${sheetSays.slice(0, 80)}"`, opened && /Reaches 1 person/.test(sheetSays) && sheetSays.includes(title));
    const sheetNames = await nameless(page, "#announce-sheet");
    check(`every control in the sheet has a name: ${sheetNames.length ? JSON.stringify(sheetNames.slice(0, 5)) : "all"}`, sheetNames.length === 0);
    await shot(page, "review_laptop_light.png");
    await page.getByRole("button", { name: "Send now" }).focus();
    await page.keyboard.press("Enter");
    await page.keyboard.press("Enter");
    const sentSaid = await until(page, () => /^Sent to 1 person/.test(document.getElementById("announce-note")?.textContent || ""), null, 30000);
    check(`Enter twice on Send now: "${await textOf(page, "#announce-note")}"`, sentSaid);
    const list = (await as("/api/admin?op=announce")).json?.announcements || [];
    const mine = list.filter((one) => one.title === title);
    check(`one sent, reach 1: ${mine.map((one) => `${one.status}/${one.reach}`).join(", ")}`,
      mine.length === 1 && mine[0].status === "sent" && mine[0].reach === 1);
    const first = mine[0];
    if (first) ids.push(first.id);

    // --- 5. Ann's Notifications --------------------------------------------------
    console.log("5. Ann's Notifications");
    {
      // Her avatar counts it on any page, before she opens her Notifications.
      const before = await open("/gallery", { who: ann, label: "ann gallery" });
      const counted = await until(before.page, () => Number(document.querySelector(".site-head .nav .account-menu summary .count")?.textContent) >= 1,
        null, 30000);
      check(`her avatar counts it: "${await textOf(before.page, ".site-head .nav .account-menu summary .count")}"`, counted);
      await before.context.close();
      const at = await open("/notifications", { who: ann, label: "ann notifications" });
      const there = await until(at.page, (id) => Boolean(document.getElementById(`announcement-${id}`)), first?.id, 30000);
      const group = await at.page.evaluate((id) => {
        const item = document.getElementById(`announcement-${id}`);
        return { text: item?.textContent.replace(/\s+/g, " ") || "", unread: item?.classList.contains("unread") };
      }, first?.id);
      check(`there by its title and words, unread: ${there}, ${group.unread}`, there && group.text.includes(title)
        && group.text.includes("Each one at true size.") && group.unread === true);
      const names = await nameless(at.page, `#announcement-${first?.id}`);
      check(`its links have names: ${names.length ? JSON.stringify(names) : "all"}`, names.length === 0);
      await shot(at.page, "notifications_laptop_light.png");
      await at.page.locator(`#announcement-${first?.id} .lines a`).first().click();
      await at.page.waitForTimeout(1500);
      await at.context.close();
      let counts = null;
      for (let at2 = 0; at2 < 10 && !(counts?.read >= 1 && counts?.clicked >= 1); at2 += 1) {
        counts = ((await as("/api/admin?op=announce")).json?.announcements || []).find((one) => one.id === first?.id);
        if (!(counts?.read >= 1 && counts?.clicked >= 1)) await new Promise((done) => setTimeout(done, 1000));
      }
      check(`followed: read ${counts?.read}, clicked ${counts?.clicked}, seen ${counts?.seen}`, counts?.read === 1 && counts?.clicked === 1);
      for (const [size, theme] of [["phone", "dark"], ["tall", "light"]]) {
        const phone = await open("/notifications", { size, theme, who: ann, label: `ann ${size}` });
        await until(phone.page, (id) => Boolean(document.getElementById(`announcement-${id}`)), first?.id, 30000);
        check(`${SIZES[size].width}x${SIZES[size].height} ${theme}: there, nothing sideways`, !(await sideways(phone.page)));
        await shot(phone.page, `notifications_${size}_${theme}.png`);
        await phone.context.close();
      }
    }

    // --- 6. Edited for everyone ---------------------------------------------------
    console.log("6. Edited");
    const edited = `${title}, and more`;
    await page.evaluate(() => { location.hash = "#announcements/sent"; });
    await page.getByRole("button", { name: `Edit "${title}" for everyone it reached` }).click();
    await page.fill('#announce-sheet [name="title"]', edited);
    await page.getByRole("button", { name: "Look at it" }).click();
    const go = page.getByRole("button", { name: "Change it for everyone" });
    await until(page, () => [...document.querySelectorAll("#announce-sheet button")].some((b) => b.textContent === "Change it for everyone" && !b.disabled),
      null, 15000);
    await go.click();
    const changed = await until(page, () => /^Changed for the one person it reached/.test(document.getElementById("announce-sent-note")?.textContent || ""), null, 15000);
    check(`changed: "${await textOf(page, "#announce-sent-note")}"`, changed);
    {
      const at = await open("/notifications", { who: ann, label: "ann edited" });
      await until(at.page, (id) => Boolean(document.getElementById(`announcement-${id}`)), first?.id, 30000);
      const text = await at.page.evaluate((id) => document.getElementById(`announcement-${id}`)?.textContent.replace(/\s+/g, " ") || "", first?.id);
      check(`Ann's says so: "${text.slice(0, 110)}"`, text.includes(edited) && /edited/.test(text));
      await at.context.close();
    }

    // --- 7. Scheduled, changed, over the day's most --------------------------------
    console.log("7. Scheduled, then changed; over the day's most");
    const later = `Flow ${rand}: tomorrow`;
    await page.evaluate(() => { location.hash = "#announcements/write"; });
    await page.click("#announce-new");
    await page.fill('#announce-form [name="title"]', later);
    await page.selectOption("#announce-kind", "person");
    await page.fill('#announce-form [name="handle"]', HANDLE);
    await page.click("#announce-review");
    await until(page, () => document.getElementById("announce-sheet")?.open === true, null, 20000);
    const picks = page.locator("#announce-sheet select");
    await picks.nth(0).selectOption({ index: 2 });
    await picks.nth(1).selectOption({ index: 40 });
    await page.getByRole("button", { name: "Schedule" }).click();
    const scheduled = await until(page, () => /^Scheduled for /.test(document.getElementById("announce-note")?.textContent || ""), null, 20000);
    check(`scheduled: "${await textOf(page, "#announce-note")}"`, scheduled);
    await page.evaluate(() => { location.hash = "#announcements/sent"; });
    await page.getByRole("button", { name: `Change "${later}": it is a draft again until you send it` }).click();
    await page.fill('#announce-form [name="title"]', `${later}, changed`);
    await page.press('#announce-form [name="title"]', "Enter");
    const unscheduled = await until(page, () => /no longer scheduled/.test(document.getElementById("announce-note")?.textContent || ""), null, 20000);
    check(`changed after scheduling: "${await textOf(page, "#announce-note")}"`, unscheduled);
    const second = ((await as("/api/admin?op=announce")).json?.announcements || []).find((one) => one.title === `${later}, changed`);
    check(`a draft again, nothing pressed: ${second?.status}`, second?.status === "draft" && !second?.send_at);
    if (second) ids.push(second.id);
    await page.evaluate(() => { location.hash = "#announcements/settings"; });
    await page.fill('#announce-most-form [name="most"]', "1");
    await page.press('#announce-most-form [name="most"]', "Enter");
    await until(page, () => /at most 1 a day/.test(document.getElementById("announce-most-note")?.textContent || ""), null, 15000);
    await page.evaluate(() => { location.hash = "#announcements/write"; });
    await page.click("#announce-review");
    await until(page, () => document.getElementById("announce-sheet")?.open === true, null, 20000);
    await page.getByRole("button", { name: "Send now" }).click();
    const refused = await until(page, () => /^Today's most is 1/.test(document.querySelector("#announce-sheet-body p.note[role=status]")?.textContent || ""),
      null, 20000);
    check(`over the day's most, refused in words, never sent: "${await textOf(page, "#announce-sheet-body p.note[role=status]")}"`, refused);
    check("and still a draft", ((await as("/api/admin?op=announce")).json?.announcements || []).find((one) => one.id === second?.id)?.status === "draft");
    await page.keyboard.press("Escape");

    // --- 8. Withdrawn ------------------------------------------------------------------
    console.log("8. Withdrawn");
    await page.evaluate(() => { location.hash = "#announcements/sent"; });
    await page.getByRole("button", { name: `Withdraw "${edited}"` }).click();
    const pulled = await until(page, () => /^Withdrawn: gone from the Notifications of the one person it reached/.test(document.getElementById("announce-sent-note")?.textContent || ""), null, 15000);
    check(`withdrawn: "${await textOf(page, "#announce-sent-note")}"`, pulled);
    {
      const at = await open("/notifications", { who: ann, label: "ann withdrawn" });
      await until(at.page, () => document.documentElement.dataset.notifications && document.documentElement.dataset.notifications !== "loading", null, 30000);
      await at.page.waitForTimeout(1000);
      check("gone from Ann's Notifications", !(await at.page.evaluate((id) => Boolean(document.getElementById(`announcement-${id}`)), first?.id)));
      await at.context.close();
    }

    // --- 9. The console at each size --------------------------------------------------
    console.log("9. The console at 1280, 390 and 430x932");
    await context.close();
    for (const [size, theme] of [["laptop", "dark"], ["phone", "light"], ["phone", "dark"], ["tall", "light"]]) {
      for (const tab of ["write", "sent"]) {
        const at = await console_(`#announcements/${tab}`, { size, theme, who: owner, label: `console ${size}` });
        await at.page.waitForTimeout(600);
        const wide = await sideways(at.page);
        const names = await nameless(at.page, section);
        check(`${tab} at ${SIZES[size].width}x${SIZES[size].height} ${theme}: nothing sideways, every control named${names.length
          ? ` (not: ${JSON.stringify(names.slice(0, 3))})` : ""}`, !wide && names.length === 0);
        await shot(at.page, `${tab}_${size}_${theme}.png`);
        await at.context.close();
      }
    }

    // On a phone, typed words are never lost to New, and what the press
    // says comes into view.
    {
      const at = await console_("#announcements/write", { size: "tall", theme: "light", who: owner, label: "console new" });
      const typedWords = `Flow ${rand}: typed, then New`;
      await at.page.fill('#announce-form [name="title"]', typedWords);
      await at.page.tap("#announce-new");
      const kept = await until(at.page, () => /^What you typed is kept as draft number \d+/.test(document.getElementById("announce-note")?.textContent || ""),
        null, 15000);
      const after = await at.page.evaluate(() => {
        const box = document.getElementById("announce-note").getBoundingClientRect();
        return { inView: box.top >= 0 && box.bottom <= innerHeight, title: document.querySelector('#announce-form [name="title"]').value };
      });
      const draft = ((await as("/api/admin?op=announce")).json?.announcements || []).find((one) => one.title === typedWords);
      if (draft) ids.push(draft.id);
      check(`at 430x932, New keeps what was typed (${draft?.status}), empties the form and says so in view: "${await textOf(at.page, "#announce-note")}"`,
        kept && after.inView && after.title === "" && draft?.status === "draft");
      await at.context.close();
    }

    // --- 10. The site notice --------------------------------------------------------------
    console.log("10. The site notice, its end, hidden by a person");
    const ends = new Date(Date.now() + 30 * 60000).toISOString();
    const set = await as("/api/admin?op=notice_set", { method: "POST", body: { words: { en: `Flow ${rand}: upkeep at 02:00 UTC.` }, tone: "warn", ends } });
    noticeSet = set.status === 200;
    check(`set with an end: ${set.status}, ends ${set.json?.ends_at}`, noticeSet && set.json?.ends_at === ends);
    const seen = async (who, label, size = "laptop") => {
      const at = await open("/gallery", { who, label, size });
      const there = await until(at.page, () => Boolean(document.querySelector(".site-notice")), null, 20000);
      return { ...at, there };
    };
    const first1 = await seen(ann, "ann notice");
    check("Ann sees it", first1.there && (await textOf(first1.page, ".site-notice")).includes(`Flow ${rand}`));
    await shot(first1.page, "notice_laptop_light.png");
    await first1.page.locator('.site-notice button[aria-label="Close"]').click();
    check("her × hides it", await until(first1.page, () => !document.querySelector(".site-notice") || document.querySelector(".site-notice").hidden, null, 10000));
    await first1.page.waitForTimeout(1500);
    await first1.context.close();
    const elsewhere = [];
    const again = await open("/gallery", { who: ann, label: "ann elsewhere", size: "phone", requests: elsewhere });
    await again.page.waitForTimeout(4000);
    check(`hidden in a browser of hers that never saw it (asked: ${elsewhere.some((one) => one.includes("op=notice_hidden"))})`,
      elsewhere.some((one) => one.includes("op=notice_hidden")) && !(await again.page.evaluate(() => {
      const notice = document.querySelector(".site-notice");
      return Boolean(notice && !notice.hidden && notice.offsetParent);
    })));
    await again.context.close();
    const hers = await seen(bea, "bea notice", "phone");
    check("Bea still sees it", hers.there);
    await shot(hers.page, "notice_phone_light.png");
    await hers.context.close();
    const banner = await console_("#announcements/banner", { who: owner, label: "console banner" });
    check(`the Banner tab says its end: "${(await textOf(banner.page, "#announce-banner-said")).slice(0, 90)}"`,
      /, until (?!it is cleared)/.test(await textOf(banner.page, "#announce-banner-said")));
    await banner.context.close();
  }
} catch (trouble) {
  check(`the flow ran through: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  if (owner) {
    const as = (pathname, options = {}) => api(pathname, { token: owner.access_token, ...options });
    if (noticeSet) {
      const cleared = await as("/api/admin?op=notice_clear", { method: "POST", body: {} });
      check(`the notice cleared: ${cleared.status}`, cleared.status === 200);
    }
    for (const id of ids) await as("/api/admin?op=announce_drop", { method: "POST", body: { id } }).catch(() => null);
  }
  for (const email of made) await deleteAccount(email).catch(() => {});
  await browser.close().catch(() => {});
}
check(`no script errors: ${errors.length ? errors.slice(0, 3).join(" | ") : "none"}`, errors.length === 0);
console.log(failed ? `announce: ${failed} failed, ${passed} passed` : `announce: all ok (${passed} checks)`);
process.exit(failed ? 1 : 0);
