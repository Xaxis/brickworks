// Ask the builders on a set's page (hubask, 2026-11-24; docs/SOCIAL.md
// section 12, supabase/set_asks.sql, api/_asks.js, web/set-page.js), in
// real browsers and through the API, with throwaway accounts at Resend test
// addresses, deleted at the end with their models: Bo and Cy publish
// versions of 346-2, Ann asks its builders about a step, Kit said under 13.
//
// On this machine, over Talk's stand-in (tools/web/talk_stand_in.mjs says
// how; the relay holds set_asks.sql there before it is applied):
//
//   node --env-file=$SCRATCH/flow.env tools/web/hubask_flow.mjs --url=http://127.0.0.1:11870 --out=DIR [--keep]
//
// On a preview once set_asks.sql is applied:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=$SCRATCH/flow.env tools/web/hubask_flow.mjs --url=<preview> --out=DIR
//
//   1. Bo publishes LDraw's 346-2 as it is, Cy a changed version: both are
//      among the set's versions. Asking is refused in words signed out, to
//      Kit (under 13), past the set's last step and for another set's file.
//      Ann asks about step 2 through the API: Bo and Cy hear of it.
//   2. Ann, on the set's page at 1280, opens Ask the builders, picks step 3:
//      its 3D in the box is step 3 (the parts by then, fewer than the
//      whole). She asks: her name first, then the thread, and 2 builders
//      will hear of it.
//   3. Signed out, at 1280 and 390: the thread says step 3 of LEGO set
//      346-2, and its 3D opens at that step; nothing goes sideways.
//   4. Bo's and Cy's Notifications say Ann asked the builders of LEGO set
//      346-2 about step 3, linking the thread; Ann and Kit are told nothing
//      of it. Bo's page shows it at 1280 and 390.
//   5. Bo answers on a part from the 3D: the post says "On the …" and its
//      dot is on the part, at 1280 and (signed out) at 390.
//   6. The set's page lists both asks, newest first: step 3 Answered, step 2
//      Open, each linking its thread, at 1280 and 390.
//
// Pictures (viewport-clipped): hub_ask_<w>, thread_3d_<w>, notice_<w>,
// answered_<w>, hub_answered_<w>, for w 1280 and 390. Prints "hubask: all ok".
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("hubask_flow: --url=<deployment>");
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
if (/^(?:www\.)?brickworks\.diy$/.test(new URL(site).host)) {
  console.error("hubask_flow: never on brickworks.diy");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/hubask"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const WHO = ["ann", "bo", "cy", "kit"];
const emails = Object.fromEntries(WHO.map((who) => [who, `delivered+bw-hub-${who}-${rand}@resend.dev`]));
const handles = Object.fromEntries(WHO.map((who) => [who, `hb-${who}-${rand}`]));
const names = { ann: "Ann Hub", bo: "Bo Hub", cy: "Cy Hub", kit: "Kit Hub" };
const SET = "346-2";
const LIBRARY = "omr-346-2";
const HUB = `/library/set/${SET}?tests=1`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let parsed = {};
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = {};
  }
  return { status: reply.status, body: parsed, text };
}

const browser = await launch({ signedOut: true });
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function open(pathname, { who = null, phone = false } = {}) {
  const context = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 800 },
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (who) {
    await context.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(who.kept)]);
  }
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${pathname}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${pathname}: ${m.text().slice(0, 220)}`);
  });
  await page.goto(`${site}${pathname}`, { waitUntil: "domcontentloaded", timeout: 120000 });
  return page;
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// The 3D in [frame] (a selector round a .picture) opened by a press, its parts in.
async function open3d(page, frame, phone) {
  await page.evaluate((at) => document.querySelector(`${at} .picture`).scrollIntoView({ block: "center" }), frame);
  if (phone) await page.tap(`${frame} .picture`);
  else await page.click(`${frame} .picture`);
  return until(page, (at) => {
    const shell = document.querySelector(`${at} .view3d`);
    const s = window.brickworks3d;
    return shell && shell.dataset.state === "ready" && s?.state === "ready" && s.view
      ? { n: s.view.d.n, dots: s.pins?.dots?.length || 0 } : null;
  }, `the 3D in ${frame}`, 180, frame);
}

/// The set's page's asks, as the page reads them (?op=talk_set_asks).
const asksOf = (token) => api(`/api/people?op=talk_set_asks&set=${SET}&tests=1`, { token });

const people = {};
const models = {};
let firstThread = 0;
let threadId = 0;
let threadPath = "";
try {
  console.log("1. Bo and Cy publish versions of 346-2; Ann asks about step 2");
  for (const who of WHO) {
    people[who] = await mintSession(emails[who], { age: who !== "kit" });
    if (who === "kit") {
      await answerAge(people.kit.kept.user_id, emails.kit, false);
      continue;
    }
    const profile = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
      body: { handle: handles[who], name: names[who] } });
    check(`${names[who]} @${handles[who]}: ${profile.status}`, profile.status === 200);
  }
  const house = readFileSync(path.join(root, "tests/fixtures/omr_credit/346-2.published.ldr"), "utf8");
  const lines = house.split("\n");
  const parts = lines.map((line, at) => (/^1 .*\.dat\s*$/i.test(line) ? at : -1)).filter((at) => at >= 0);
  const cut = new Set(parts.slice(0, Math.floor(parts.length / 10)));
  for (const [who, model, name] of [["bo", house, "Bo's House with Car"], ["cy", lines.filter((_, at) => !cut.has(at)).join("\n"), "Cy's House with Car"]]) {
    const made = await api("/api/share", { method: "POST", token: people[who].access_token,
      body: { name: `${name} ${rand}`, author: names[who], listed: true, model, licence: "cc-by-4.0" } });
    models[who] = made.body.id || "";
    check(`${names[who]} publishes a version of 346-2: ${made.status} /m/${models[who]}, changed ${made.body.modelled_by?.changed}`,
      made.status === 201 && Boolean(models[who]));
  }
  const began = Date.now();
  let both = false;
  while (!both && Date.now() - began < 180000) {
    const based = await api(`/api/share?op=set_based&set=${SET}&tests=1`);
    both = [models.bo, models.cy].every((id) => based.body.versions?.some((one) => one.id === id));
    if (!both) await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  check(`both are among 346-2's versions ${((Date.now() - began) / 1000).toFixed(1)} s after`, both);
  const ask = (who, body) => api("/api/people?op=talk_set_ask&tests=1", { method: "POST", token: who ? people[who].access_token : undefined,
    body: { set: SET, library: LIBRARY, title: "A question", body: `About the house (hubask flow ${rand})`, ...body } });
  const signedOut = await ask(null, { step: 2 });
  check(`signed out, asking is refused: ${signedOut.status}`, signedOut.status === 401);
  const kit = await ask("kit", { step: 2 });
  check(`Kit, who said under 13, cannot ask: ${kit.status} "${kit.body.error}"`, kit.status === 422 && /13 and over/.test(kit.body.error || ""));
  const late = await ask("ann", { step: 999 });
  check(`past the set's last step is refused: ${late.status} "${late.body.error}"`, late.status >= 400 && late.status < 500 && Boolean(late.body.error));
  const other = await ask("ann", { library: "omr-10497-1", step: 2 });
  check(`another set's file is refused: ${other.status} "${other.body.error}"`, other.status >= 400 && other.status < 500 && Boolean(other.body.error));
  const first = await ask("ann", { step: 2, title: "Where does the door go at step 2?", body: `Which way round is the door at step 2? (hubask flow ${rand})` });
  firstThread = Number(first.body.thread?.id) || 0;
  check(`Ann asks about step 2: ${first.status}, ${first.body.path || first.body.error}, step ${first.body.ask?.step}, set ${first.body.ask?.set}, ${first.body.heard} told`,
    first.status === 201 && firstThread > 0 && first.body.ask?.step === 2 && first.body.ask?.set === SET && first.body.heard === 2);
  await new Promise((resolve) => setTimeout(resolve, 1200));

  console.log("2. Ann asks on the set's page, at step 3, in the box's 3D");
  const ann = await open(`${HUB}#asks`, { who: people.ann });
  const box = await until(ann, () => {
    const said = document.documentElement.dataset.asks;
    const picker = document.querySelector("#set-ask-step");
    return said && picker ? { said, steps: picker.options ? picker.options.length - 1 : 0, tab: document.querySelector("#tab-asks")?.textContent.trim() } : null;
  }, "Ask the builders", 45);
  check(`its tab "${box.tab}", ${box.said} asked, a step picker of ${box.steps} steps`, Number(box.said) >= 1 && box.steps > 3 && /Ask the builders/.test(box.tab));
  await ann.selectOption("#set-ask-step", "3");
  const drawn = await until(ann, () => {
    const pic = document.querySelector(".set-ask-frame .picture");
    return document.querySelector(".set-ask-frame")?.dataset.step === "3" && pic ? pic.dataset.scene : null;
  }, "step 3 in the box", 10);
  const whole = await api(drawn.replace(/\?step=3$/, ""));
  const three = await api(drawn);
  const inBox = await open3d(ann, ".set-ask-frame", false);
  check(`the box's 3D is step 3: ${inBox.n} parts of ${whole.body.count} (${drawn}, drawn at the step ${JSON.stringify(three.body.at_step)})`,
    inBox.n === three.body.count && three.body.count < whole.body.count && three.body.at_step?.drawn === true);
  const question = `How does the chimney sit on the roof at step 3? Mine leans. (hubask flow ${rand})`;
  await ann.fill("#set-ask-words", question);
  await ann.evaluate(() => document.querySelector(".set-ask-form").scrollIntoView({ block: "start" }));
  await ann.waitForTimeout(5500);
  await shot(ann, "hub_ask_1280.png");
  // The same box on a phone, signed out: step 3 picked from the address
  // (?step=3, as the app's step player links here), its 3D in the box.
  const phoneHub = await open(`${HUB}&step=3#asks`, { phone: true });
  const phoneStep = await until(phoneHub, () => document.querySelector(".set-ask-frame")?.dataset.step || null, "the box at 390", 45);
  check(`390: ?step=3 picks step 3 in the box (${phoneStep})`, phoneStep === "3");
  const phoneBox = await open3d(phoneHub, ".set-ask-frame", true);
  check(`390: the box's 3D is step 3: ${phoneBox.n} parts`, phoneBox.n === three.body.count);
  await phoneHub.fill("#set-ask-words", question);
  await phoneHub.evaluate(() => document.querySelector(".set-ask-form").scrollIntoView({ block: "start" }));
  await phoneHub.waitForTimeout(5500);
  await shot(phoneHub, "hub_ask_390.png");
  check("390: nothing goes sideways", !(await sideways(phoneHub)));
  await phoneHub.context().close();
  // What the box says as it goes (the page goes on to the thread at once,
  // and the answer's body with it): kept in the tab's sessionStorage.
  await ann.evaluate(() => {
    const said = document.querySelector(".set-ask-form .said");
    new MutationObserver(() => sessionStorage.setItem("hubask-said", said.textContent))
      .observe(said, { childList: true, characterData: true, subtree: true });
  });
  const replied = ann.waitForResponse((reply) => reply.url().includes("op=talk_set_ask") && reply.request().method() === "POST", { timeout: 60000 });
  await ann.click(".set-ask-form button[type=submit]");
  const sent = await replied;
  await ann.waitForURL((at) => /^\/talk\/t\/\d+/.test(at.pathname), { timeout: 60000 }).catch(() => {});
  threadPath = new URL(ann.url()).pathname;
  threadId = Number(/^\/talk\/t\/(\d+)/.exec(threadPath)?.[1]) || 0;
  const boxSaid = await ann.evaluate(() => sessionStorage.getItem("hubask-said")).catch(() => "");
  check(`asked: ${sent.status()}, the box said "${boxSaid}", and the page went on to the thread ${threadPath}`,
    sent.status() === 201 && boxSaid === "Asked: 2 builders will hear of it." && threadId > 0 && threadId !== firstThread);
  await ann.context().close();

  console.log("3. Signed out, the thread is at step 3 of the set, in 3D");
  for (const phone of [false, true]) {
    const size = phone ? "390" : "1280";
    const visitor = await open(`${threadPath}?tests=1`, { phone });
    const card = await until(visitor, () => {
      const one = document.querySelector(".talk-ask");
      return one ? { go: one.querySelector(".go")?.textContent.trim(), where: one.querySelector(".talk-ask-where")?.textContent.trim().replace(/\s+/g, " ") } : null;
    }, "the ask on its thread", 30);
    check(`${size}: "${card.go}", "${card.where}"`, /step 3/i.test(card.go || "") && /Step 3 of LEGO® set 346-2/.test(card.where || ""));
    const view = await open3d(visitor, ".talk-ask", phone);
    check(`${size}: its 3D is step 3: ${view.n} parts`, view.n === three.body.count);
    await visitor.waitForTimeout(5500);
    await shot(visitor, `thread_3d_${size}.png`);
    check(`${size}: nothing goes sideways`, !(await sideways(visitor)));
    await visitor.context().close();
  }

  console.log("4. Bo and Cy are told; Ann and Kit are not");
  const line = new RegExp(`${names.ann} asked the builders of LEGO® set 346-2 about step 3`);
  for (const who of ["bo", "cy", "ann", "kit"]) {
    const told = await api("/api/people?op=notifications", { token: people[who].access_token });
    const rows = (told.body.groups || []).flatMap((group) => group.rows || []);
    const ours = rows.filter((row) => Number(row.thread) === threadId || String(row.link || "").includes(`/talk/t/${threadId}`));
    const wanted = who === "bo" || who === "cy";
    // The line names who asked as {who}, which the page makes their link.
    const said = ours[0] ? String(ours[0].line || "").replace("{who}", String(ours[0].who || "")) : "";
    check(`${names[who]}: ${told.status}, ${ours.length} notice of it${said ? `, "${said}"` : ""}`,
      told.status === 200 && (wanted ? ours.length === 1 && line.test(said) : ours.length === 0));
  }
  for (const phone of [false, true]) {
    const size = phone ? "390" : "1280";
    const bo = await open("/notifications?tests=1", { who: people.bo, phone });
    const row = await until(bo, (thread) => {
      const one = [...document.querySelectorAll("#groups .lines > li")].find((li) => /asked the builders of LEGO® set 346-2 about step 3/.test(li.textContent));
      if (!one) return null;
      one.scrollIntoView({ block: "center" });
      const link = one.querySelector(`a[href*="/talk/t/${thread}"]`) || one.closest("#groups > *")?.querySelector(`a[href*="/talk/t/${thread}"]`);
      return { text: one.textContent.trim().replace(/\s+/g, " ").slice(0, 160), link: Boolean(link) };
    }, "Bo's notice", 45, threadId).catch(() => null);
    check(`${size}: Bo's Notifications say "${row?.text}", linking the thread`, Boolean(row?.link));
    await shot(bo, `notice_${size}.png`);
    check(`${size}: nothing goes sideways`, !(await sideways(bo)));
    await bo.context().close();
  }

  console.log("5. Bo answers on a part from the 3D");
  const bo = await open(`${threadPath}?tests=1`, { who: people.bo });
  await until(bo, () => document.querySelector("[data-reply-form]") && !document.querySelector("[data-reply-form]").hidden, "Bo's reply box", 45);
  await open3d(bo, ".talk-ask", false);
  const aim = await bo.evaluate(() => {
    const s = window.brickworks3d;
    const v = s.view;
    for (let i = v.d.n - 1; i >= 0; i--) {
      const at = v.onPage(v.centreOf(i));
      if (!at || document.elementFromPoint(at.x, at.y)?.localName !== "canvas") continue;
      if (s.pickAt(at.x, at.y) === i) return { x: at.x, y: at.y, part: v.d.meshes[v.d.mesh[i]].part };
    }
    return null;
  });
  check(`a part of step 3 is on the screen to press: ${JSON.stringify(aim)}`, Boolean(aim));
  if (aim) {
    await bo.mouse.move(aim.x, aim.y);
    await bo.mouse.down({ button: "right" });
    await bo.mouse.up({ button: "right" });
    const menu = await until(bo, () => (window.brickworks3d.pins.menu === "open"
      ? document.querySelector(".view3d-menu [role=menuitem]")?.textContent.trim() : null), "the part's menu", 5).catch(() => "");
    check(`its menu says "${menu}"`, menu === "Answer on this part");
    await bo.click(".view3d-menu [role=menuitem]");
    await bo.fill("#talk-reply-words", `It sits one stud in from the back. (hubask flow ${rand})`);
    await bo.click("[data-reply-form] button[type=submit]");
    const on = await until(bo, () => [...document.querySelectorAll("#talk-posts .talk-post.on-part .talk-on-part")]
      .map((one) => one.textContent.trim())[0] || null, "Bo's answer on its part", 30).catch(() => "");
    check(`his answer says "${on}"`, /^On the /.test(on));
    const dots = await until(bo, () => (window.brickworks3d.pins.dots.length ? window.brickworks3d.pins.dots.length : null), "its dot", 10).catch(() => 0);
    check(`its dot is on the part in the 3D: ${dots}`, dots === 1);
    await bo.evaluate(() => document.querySelector(".talk-ask").scrollIntoView({ block: "start" }));
    await shot(bo, "answered_1280.png");
  }
  await bo.context().close();
  const phoneAnswer = await open(`${threadPath}?tests=1`, { phone: true });
  const phoneView = await open3d(phoneAnswer, ".talk-ask", true);
  await until(phoneAnswer, () => (window.brickworks3d.pins.dots.length ? true : null), "the answer's dot at 390", 15).catch(() => null);
  const phoneDots = await phoneAnswer.evaluate(() => window.brickworks3d.pins.dots.length);
  check(`390: the answer's dot is on its part (${phoneDots}, ${phoneView.n} parts)`, phoneDots === 1);
  await phoneAnswer.waitForTimeout(5500);
  await shot(phoneAnswer, "answered_390.png");
  await phoneAnswer.context().close();

  console.log("6. The set's page lists both, newest first, step 3 answered");
  // Signed out, the list is the CDN's for 20 s (and served stale for 60 more)
  // by design (api/_talk.js talkSetAsks), and the first steps asked it a
  // minute ago: a question of its own asks the server, not that copy.
  // rel-m332's train read #78 alone, from before #80 was asked.
  const listed = await api(`/api/people?op=talk_set_asks&set=${SET}&tests=1&fresh=${Date.now()}`, {});
  const rows = (listed.body.asks || []).filter((one) => one.thread === threadId || one.thread === firstThread);
  check(`talk_set_asks: ${listed.status}, ${rows.map((one) => `#${one.thread} step ${one.step} ${one.answered ? "answered" : "open"}`).join(", ")}`,
    listed.status === 200 && rows.length === 2 && rows[0].thread === threadId && rows[0].answered === true
    && rows[1].thread === firstThread && rows[1].answered === false);
  for (const phone of [false, true]) {
    const size = phone ? "390" : "1280";
    const visitor = await open(`${HUB}#asks`, { phone });
    const seen = await until(visitor, () => {
      const items = [...document.querySelectorAll(".set-ask-row")];
      if (!items.length) return null;
      items[0].closest(".set-asks-asked").scrollIntoView({ block: "start" });
      return items.map((one) => ({ thread: Number(one.dataset.thread), answered: one.dataset.answered === "true",
        state: one.querySelector(".set-ask-state")?.textContent.trim(), href: one.querySelector("a")?.getAttribute("href") }));
    }, "the asks listed", 45);
    const ours = seen.filter((one) => one.thread === threadId || one.thread === firstThread);
    check(`${size}: ${ours.map((one) => `#${one.thread} ${one.state}`).join(", ")}, each linking its thread`,
      ours.length === 2 && ours[0].thread === threadId && ours[0].state === "Answered" && ours[1].state === "Open"
      && ours.every((one) => one.href?.startsWith(`/talk/t/${one.thread}`)));
    await visitor.waitForTimeout(400);
    await shot(visitor, `hub_answered_${size}.png`);
    check(`${size}: nothing goes sideways`, !(await sideways(visitor)));
    await visitor.context().close();
  }
} catch (trouble) {
  check(`ran to the end: ${String(trouble?.message || trouble).split("\n")[0]}`, false);
} finally {
  await browser.close().catch(() => {});
  const keep = args.keep && /^http:\/\/127\.0\.0\.1:/.test(args.url);
  if (keep) console.log(`  kept: ${threadPath}?tests=1`);
  else {
    for (const who of ["bo", "cy"]) {
      if (models[who] && people[who]) await api(`/api/share?op=unpublish&id=${models[who]}`, { method: "POST", token: people[who].access_token }).catch(() => {});
    }
    for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
  }
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "hubask: all ok");
process.exit(failed ? 1 : 0);
