// What a model is based on, in real browsers (docs/SOCIAL.md section 7,
// item 5, supabase/model_bases.sql, api/_bases.js): its designer says it in
// a dialog on its page, a LEGO® set built from and work elsewhere changed;
// the page credits each in a line, its structured data and its JSON say
// them; the set's page lists the model; a wrong set or a link that is not
// one is said in words; nobody else may say it; taken away, gone.
//
//   node tools/web/based_on_flow.mjs [--out=DIR]                     # this checkout, the stand-in's
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/based_on_flow.mjs --url=<preview> --out=DIR
//
// With no --url nothing leaves this machine: the pages are made by this
// checkout's api/ and every call answered by design_stand_in.mjs, which
// keeps a list as model_bases.sql does: Ivy is the stand-in's Sam and her
// castle his tram, Jon is Sam asking of Robin's watchtower, and a visitor
// is shown no test model only on a deployment.
//
// With --url, the live project's tables. Before model_bases.sql there is
// nowhere to keep a list: the designer is offered nothing, a list sent is
// refused in words (503), and the pages say nothing of it; the flow proves
// that and passes, saying so. Throwaway accounts at Resend test addresses,
// deleted at the end with the model: Ivy designs, Jon is somebody else.
//
//   1. Ivy shares a castle in the gallery. Asked whether the file is there.
//   2. Ivy, at 1280 px (light), opens its page: "Say what it is based on".
//      A set the library has not got, and an alternate build of a link,
//      each said in the dialog in words and nothing kept; then set 6080-1
//      as an alternate build, and a work elsewhere changed, with its title,
//      author and licence. Saved: two lines under its name, the set's
//      linked to its page here, the work's to its address, marked as not
//      ours (nofollow ugc).
//   3. A visitor: the page as sent has both lines, its structured data
//      isBasedOn both, its JSON based_on both; Jon is offered nothing, and
//      his list is refused (403); four are refused (400).
//   4. Set 6080-1's page at 390 px (dark), with tests=1: "Based on this
//      set", the castle's card; a visitor without tests=1 is not shown a
//      test model; nothing sideways.
//   5. Ivy takes them away at 390 px (dark): the lines gone, and the set's
//      page lists nothing of hers.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const site = remote || stand.ORIGIN;
const out = path.resolve(String(args.out || "shots/based_on"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const ivyEmail = `delivered+bw-based-ivy-${rand}@resend.dev`;
const jonEmail = `delivered+bw-based-jon-${rand}@resend.dev`;
const CASTLE = `Based Flow Castle ${rand}`;
const SET = "6080-1";
const WORK = `https://example.org/castle-${rand}`;
const NOT_OPEN = "Saying what a model is based on is not open yet.";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: based.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // based on flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, dark = false, phone = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(made, { web: path.join(root, "web"), api: path.join(root, "api") });
  if (as) {
    // The stand-in's Sam as web/account.js keeps a session, or a throwaway's.
    const kept = remote ? null : stand.signedInStorage();
    await made.addInitScript(([name, value, access]) => {
      try {
        if (!localStorage.getItem(name)) localStorage.setItem(name, value);
        if (access) sessionStorage.setItem("brickworks.access", access);
      } catch {}
    }, kept ? [STORAGE_KEY, JSON.stringify(kept.session), JSON.stringify(kept.access)] : [STORAGE_KEY, JSON.stringify(as.kept), ""]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

// The viewport only: a full-page picture of a phone's context draws the
// mouse's controls (fullpage-shot-drops-touch).
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  if (!remote) {
    const url = new URL(pathname, stand.ORIGIN);
    // A model's own answer (?id=X) is the handler's, as the app asks it.
    if (!url.searchParams.get("op") && url.searchParams.get("id")) {
      const made = await stand.serverAsk(path.join(root, "api"), { name: "share", query: Object.fromEntries(url.searchParams) });
      return { status: made.status, body: JSON.parse(made.html || "{}") };
    }
    const said = stand.apiAnswer({ url, method, body, state: { signedIn: Boolean(token) } });
    return said ? { status: said.status, body: said.json || {} } : { status: 404, body: {} };
  }
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}
const text = async (pathname) => {
  if (!remote) {
    const made = await stand.serverPage(path.join(root, "api"), pathname);
    return { status: made.status, html: made.html };
  }
  const reply = await fetch(`${site}${pathname}`, { headers });
  return { status: reply.status, html: await reply.text() };
};

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// The page's lines of what it is based on, as drawn.
const linesDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("#based-on li")].map((li) => ({
  how: li.dataset.how, text: li.textContent.replace(/\s+/g, " ").trim(),
  href: li.querySelector("a")?.getAttribute("href") || "", rel: li.querySelector("a")?.getAttribute("rel") || "" })));

/// The lines as the server sent them, before any script: [how, text, href, rel].
const linesSent = (html) => {
  const list = /<ul class="from based-on"[^>]*>([\s\S]*?)<\/ul>/.exec(html);
  return list ? [...list[1].matchAll(/<li data-how="([a-z]+)">([\s\S]*?)<\/li>/g)].map(([, how, inner]) => ({ how,
    text: inner.replace(/<[^>]+>/g, "").replace(/&#39;/g, "'").replace(/&amp;/g, "&"),
    href: (/href="([^"]*)"/.exec(inner) || [])[1] || "", rel: (/rel="([^"]*)"/.exec(inner) || [])[1] || "" })) : [];
};

/// Ivy's dialog: open it, put [rows] in it ({how, what, title, author,
/// licence}), as many as there are rows, and Save; what it said.
async function sayBases(page, rows) {
  await page.click("#bases-own button");
  await page.waitForSelector("dialog.bases-dialog[open]");
  const dialog = page.locator("dialog.bases-dialog");
  for (;;) {
    const have = await dialog.locator("fieldset").count();
    if (have > rows.length && have > 1) await dialog.locator("fieldset").last().getByRole("button", { name: "Remove" }).click();
    else if (have < rows.length) await dialog.getByRole("button", { name: "Add another" }).click();
    else break;
  }
  const boxes = dialog.locator("fieldset");
  for (const [at, row] of rows.entries()) {
    const box = boxes.nth(at);
    await box.locator("select[name=how]").selectOption(row.how);
    await box.locator("input[name=what]").fill(row.what);
    if (row.title !== undefined) {
      await box.locator("input[name=title]").fill(row.title);
      await box.locator("input[name=author]").fill(row.author || "");
      await box.locator("input[name=licence]").fill(row.licence || "");
    }
  }
  if (!rows.length) await boxes.first().locator("input[name=what]").fill("");
  await page.evaluate(() => { delete document.documentElement.dataset.basesRefused; });
  await dialog.getByRole("button", { name: "Save" }).click();
  return until(page, () => (!document.querySelector("dialog.bases-dialog")
    ? { kept: true } : document.documentElement.dataset.basesRefused
      ? { kept: false, status: document.documentElement.dataset.basesRefused,
        said: document.querySelector("dialog.bases-dialog .said").textContent.trim() } : null), "the dialog's answer");
}

let ivy = null;
let jon = null;
let castle = "";
try {
  // --- 1. Ivy's castle ------------------------------------------------------
  // Jon's own model to ask of: on a deployment the castle, here Robin's.
  let jonsTarget = "";
  if (remote) {
    console.log("Ivy shares a castle in the gallery");
    ivy = await mintSession(ivyEmail);
    jon = await mintSession(jonEmail);
    const shared = await api("/api/share", { method: "POST", token: ivy.access_token,
      body: { name: CASTLE, author: "Ivy Bases", model: model(CASTLE), image: picture, listed: true } });
    castle = shared.body.id || "";
    jonsTarget = castle;
    check(`the castle /m/${castle}: ${shared.status}`, shared.status === 201 && Boolean(castle));
  } else {
    console.log("The stand-in: Sam's tram is Ivy's castle, Robin's watchtower Jon's");
    ivy = { access_token: "stand-in", kept: null };
    jon = { access_token: "stand-in", kept: null };
    castle = "SamModel01";
    jonsTarget = stand.MODEL_ID;
  }
  const asked = await api(`/api/share?op=bases&id=${castle}`, { token: ivy.access_token });
  check(`asked as its designer: ${asked.status} mine ${asked.body.mine}, ready ${asked.body.ready}, ${JSON.stringify(asked.body.bases)}`,
    asked.status === 200 && asked.body.mine === true && Array.isArray(asked.body.bases) && asked.body.bases.length === 0);
  const ready = asked.body.ready === true;
  console.log(ready ? "  --    model_bases.sql is applied: the whole of it" : "  --    model_bases.sql is not applied: what a page does before it");

  const ivySite = await context({ as: ivy });
  const ivyPage = await ivySite.newPage();
  listen(ivyPage, "Ivy");
  await ivyPage.goto(`${site}/m/${castle}?tests=1`, { waitUntil: "load" });
  const visitor = await context();
  const setPage = await visitor.newPage();
  listen(setPage, "a visitor");

  if (!ready) {
    // --- Before the file -----------------------------------------------------
    const marked = await until(ivyPage, () => document.documentElement.dataset.bases, "the page's answer", 30);
    check(`her page offers nothing (data-bases ${marked}, no line to change it)`, marked === "not-open"
      && (await ivyPage.locator("#bases-own").count()) === 0 && (await ivyPage.locator("#based-on").count()) === 0);
    const sent = await api("/api/share?op=bases", { method: "POST", token: ivy.access_token,
      body: { model: castle, bases: [{ how: "alternate", set: SET }] } });
    check(`a list sent is refused in words: ${sent.status} "${sent.body.error}"`, sent.status === 503 && sent.body.error === NOT_OPEN);
    const json = await api(`/api/share?id=${castle}`);
    check(`its JSON says nothing of it: based_on ${JSON.stringify(json.body.based_on)}`, json.status === 200
      && Array.isArray(json.body.based_on) && json.body.based_on.length === 0);
    await setPage.goto(`${site}/library/set/${SET}?tests=1`, { waitUntil: "load" });
    const based = await until(setPage, () => document.documentElement.dataset.based, "the set's page's answer");
    check(`set ${SET}'s page lists nothing (data-based ${based}, no row)`, based === "0"
      && (await setPage.locator("#built-from").count()) === 0);
    await shot(ivyPage, "0_not_open.png");
  } else {
    // --- 2. Ivy says what it is based on ---------------------------------------
    console.log("Ivy says what the castle is based on");
    await until(ivyPage, () => document.querySelector("#bases-own button")?.textContent, "Say what it is based on");
    check(`her page offers "${await ivyPage.textContent("#bases-own button")}", no line yet`,
      (await ivyPage.textContent("#bases-own button")) === "Say what it is based on"
      && (await ivyPage.locator("#based-on").count()) === 0);
    let said = await sayBases(ivyPage, [{ how: "alternate", what: "99999999-1" }]);
    check(`a set the library has not got: ${said.status} "${said.said}"`, said.kept === false && said.status === "400"
      && /^There is no set 99999999-1 in the library/.test(said.said));
    await shot(ivyPage, "1_no_such_set.png");
    await ivyPage.keyboard.press("Escape");
    await until(ivyPage, () => !document.querySelector("dialog.bases-dialog"), "the dialog closed by Escape");
    check("Escape closes it, and the focus is back on its button",
      await ivyPage.evaluate(() => document.activeElement === document.querySelector("#bases-own button")));
    said = await sayBases(ivyPage, [{ how: "alternate", what: WORK, title: "A castle" }]);
    check(`an alternate build of a link: "${said.said}"`, said.kept === false
      && /^An alternate build is built from a set's parts/.test(said.said));
    await ivyPage.keyboard.press("Escape");
    await until(ivyPage, () => !document.querySelector("dialog.bases-dialog"), "the dialog closed");
    check(`nothing kept: data-bases ${await ivyPage.evaluate(() => document.documentElement.dataset.bases)}`,
      (await ivyPage.locator("#based-on").count()) === 0);
    said = await sayBases(ivyPage, [{ how: "alternate", what: SET },
      { how: "changed", what: WORK, title: "A castle", author: "Someone", licence: "CC BY 4.0" }]);
    check(`kept: ${JSON.stringify(said)}`, said.kept === true);
    let lines = await linesDrawn(ivyPage);
    check(`its page: ${lines.map((one) => `"${one.text}" → ${one.href}`).join(", ")}`, lines.length === 2
      && lines[0].how === "alternate" && lines[0].text === `An alternate build of set ${SET} King's Castle`
      && lines[0].href === `/library/set/${SET}`
      && lines[1].how === "changed" && lines[1].text === "Changed from “A castle” by Someone (CC BY 4.0)"
      && lines[1].href === WORK && lines[1].rel === "nofollow ugc noopener");
    check(`its button says "${await ivyPage.textContent("#bases-own button")}"`,
      (await ivyPage.textContent("#bases-own button")) === "Change what it is based on"
      && (await ivyPage.evaluate(() => document.documentElement.dataset.bases)) === "2");
    await shot(ivyPage, "2_said.png");

    // --- 3. A visitor, Jon --------------------------------------------------------
    console.log("A visitor, and Jon");
    // A model's page is kept by the CDN for half a minute (api/share.js
    // SHARED_CACHE): asked anew.
    const page = await text(`/m/${castle}?asked=${Date.now()}`);
    const sent = linesSent(page.html);
    check(`the page as sent: ${sent.map((one) => `"${one.text}"`).join(", ")}`, page.status === 200 && sent.length === 2
      && sent[0].text === lines[0].text && sent[1].text === lines[1].text && sent[1].rel === "nofollow ugc noopener");
    const data = [...page.html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)]
      .map((found) => JSON.parse(found[1])).find((one) => one["@type"] === "CreativeWork") || {};
    check(`its structured data, isBasedOn ${JSON.stringify(data.isBasedOn)}`, Array.isArray(data.isBasedOn)
      && data.isBasedOn.includes(`${new URL(data.url || site).origin}/library/set/${SET}`) && data.isBasedOn.includes(WORK));
    const json = await api(`/api/share?id=${castle}`);
    const on = json.body.based_on || [];
    check(`its JSON, based_on ${JSON.stringify(on)}`, on.length === 2 && on[0].set === SET && /^https?:\/\/[^/]+\/library\/set\/6080-1$/.test(on[0].href)
      && on[1].url === WORK && on[1].name === "A castle" && on[1].author === "Someone" && on[1].licence === "CC BY 4.0");
    // On the stand-in only Sam signs in: his castle seen signed out.
    const jonSite = await context({ as: remote ? jon : null });
    const jonPage = await jonSite.newPage();
    listen(jonPage, "Jon");
    await jonPage.goto(`${site}/m/${castle}?tests=1&asked=${Date.now()}`, { waitUntil: "load" });
    await until(jonPage, () => document.querySelectorAll("#based-on li").length === 2, "Jon's page's lines");
    const jonAsked = await api(`/api/share?op=bases&id=${jonsTarget}`, { token: jon.access_token });
    await jonPage.waitForTimeout(1500);
    check(`Jon sees the lines and is offered nothing to change (mine ${jonAsked.body.mine})`, jonAsked.body.mine === false
      && (await jonPage.locator("#bases-own").count()) === 0);
    await shot(jonPage, "2_seen.png");
    const jonSent = await api("/api/share?op=bases", { method: "POST", token: jon.access_token, body: { model: jonsTarget, bases: [] } });
    check(`his list is refused: ${jonSent.status} "${jonSent.body.error}"`, jonSent.status === 403
      && jonSent.body.error === "Only its designer says what it is based on.");
    const four = await api("/api/share?op=bases", { method: "POST", token: ivy.access_token,
      body: { model: castle, bases: [1, 2, 3, 4].map(() => ({ how: "inspired", set: SET })) } });
    check(`four are refused: ${four.status} "${four.body.error}"`, four.status === 400 && /^At most 3/.test(four.body.error));
    const plain = await api("/api/share?op=bases", { method: "POST", token: ivy.access_token,
      body: { model: castle, bases: [{ how: "inspired", url: "http://example.org/x", title: "X" }] } });
    check(`a link not https is refused: ${plain.status} "${plain.body.error}"`, plain.status === 400
      && /starting https:\/\//.test(plain.body.error));
    const still = await api(`/api/share?op=bases&id=${castle}`);
    check(`and the list stands: ${still.body.bases?.length}`, still.body.bases?.length === 2);

    // --- 4. The set's page --------------------------------------------------------
    console.log(`Set ${SET}'s page`);
    const phone = await context({ width: 390, height: 844, dark: true, phone: true });
    const setPhone = await phone.newPage();
    listen(setPhone, "a visitor at 390");
    await setPhone.goto(`${site}/library/set/${SET}?tests=1`, { waitUntil: "load" });
    const based = await until(setPhone, () => document.documentElement.dataset.based, "the set's page's answer");
    const row = await setPhone.evaluate(() => ({ heading: document.querySelector("#built-from h2")?.textContent || "",
      cards: [...document.querySelectorAll("#built-from .models .model")].map((card) => card.dataset.id),
      before: document.querySelector("#built-from")?.nextElementSibling?.id || "" }));
    check(`at 390 px (dark): data-based ${based}, "${row.heading}", cards ${row.cards.join(", ")}, then #${row.before || "nothing"}`,
      Number(based) >= 1 && row.heading === "Based on this set" && row.cards.includes(castle));
    await setPhone.locator("#built-from").scrollIntoViewIfNeeded();
    await shot(setPhone, "3_set_page_390_dark.png");
    check("nothing sideways", !(await sideways(setPhone)));
    if (remote) {
      const visitorList = await api(`/api/share?op=set_based&set=${SET}`);
      check(`a visitor without tests=1 is shown no test model: ${visitorList.status}, ${(visitorList.body.models || []).length} models`,
        visitorList.status === 200 && !(visitorList.body.models || []).some((one) => one.id === castle));
    }

    // --- 5. Taken away -----------------------------------------------------------
    console.log("Ivy takes them away, at 390 px (dark)");
    const ivyPhone = await context({ as: ivy, width: 390, height: 844, dark: true, phone: true });
    const ivySmall = await ivyPhone.newPage();
    listen(ivySmall, "Ivy at 390");
    await ivySmall.goto(`${site}/m/${castle}?tests=1&asked=${Date.now()}`, { waitUntil: "load" });
    await until(ivySmall, () => document.querySelector("#bases-own button")?.textContent === "Change what it is based on", "Change it");
    await ivySmall.locator("#bases-own").scrollIntoViewIfNeeded();
    await ivySmall.click("#bases-own button");
    await ivySmall.waitForSelector("dialog.bases-dialog[open]");
    // Once it has risen (site.css dialog[open]'s animation).
    await ivySmall.waitForTimeout(600);
    check("the dialog at 390 px: nothing sideways", !(await sideways(ivySmall)));
    await shot(ivySmall, "4_dialog_390_dark.png");
    await ivySmall.keyboard.press("Escape");
    await until(ivySmall, () => !document.querySelector("dialog.bases-dialog"), "the dialog closed");
    said = await sayBases(ivySmall, []);
    lines = await linesDrawn(ivySmall);
    check(`taken away: kept ${said.kept}, ${lines.length} lines, "${await ivySmall.textContent("#bases-own button")}"`,
      said.kept === true && lines.length === 0 && (await ivySmall.textContent("#bases-own button")) === "Say what it is based on");
    const after = await api(`/api/share?op=set_based&set=${SET}&tests=1`);
    check(`set ${SET}'s list has nothing of hers`, after.status === 200 && !(after.body.models || []).some((one) => one.id === castle));
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (remote && castle && ivy) await api(`/api/share?op=unpublish&id=${castle}`, { method: "POST", token: ivy.access_token }).catch(() => {});
  await browser.close();
  if (remote) for (const email of [ivyEmail, jonEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "based on: said in a dialog, credited on the page, its data and its set's page, refused in words, taken away");
process.exit(failed ? 1 : 0);
