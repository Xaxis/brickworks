// Talk, the builders' forum (docs/SOCIAL.md section 10, supabase/talk.sql,
// api/_talk.js), in real browsers and through the API, with four throwaway
// accounts at Resend test addresses, deleted at the end with their model:
// Ann starts a thread, Bea answers, Cy reports, Dee is blocked.
//
// On this machine, over the stand-in (tools/web/talk_stand_in.mjs says how),
// with only the project's address, its keys and a throwaway's address as
// MASTER_EMAIL, so the console here is a throwaway's and never the owner's:
//
//   node --env-file=$SCRATCH/relay.env tools/web/talk_flow.mjs --url=http://127.0.0.1:11170 --out=DIR
//
// On a preview once talk.sql is applied (the console's step there is the
// three reports' instead: no check signs in as the owner):
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=$SCRATCH/flow.env tools/web/talk_flow.mjs --url=<preview> --out=DIR
//
//   1. The boards, signed out: Latest and the five boards as tabs, the
//      house's first threads in them (never empty), what is said under the
//      models beside them, and a thread's Reply asking to sign in.
//   2. Ann shares a model; its page offers her a Show and tell thread about
//      it; she starts one there with a step of it and @Bea in her words: the
//      thread shows the model's card, the step's, Bea's name as a link, and
//      its JSON-LD (DiscussionForumPosting). The model's page links to it.
//   3. Bea is told she was mentioned; she answers, and Ann is told of the
//      reply, on her Notifications page too.
//   4. Search finds the thread by a word of it, and says when nothing does.
//   5. RSS: every board's and Show and tell's feed carry the thread; Help's
//      does not.
//   6. Dee answers; Ann blocks Dee from the post's Block: Dee's post leaves
//      the thread for Ann and for a visitor (the starter blocked them), Ann
//      is told some posts are not shown, Dee still sees it, and a new reply
//      of Dee's there is refused in words that do not say why.
//   7. Cy reports Bea's reply from its Report: the dialog thanks Cy. Here,
//      the console (a throwaway's) hides it from Reported, kept in the
//      audit; on a preview, two more reports hide it. Either way a visitor
//      no longer sees it and Bea sees it hidden.
//   8. The month's challenge has its thread in Challenges, by Brickworks,
//      with the way to the challenge.
//   9. In German: /de/talk and the thread, their words and lang, and the
//      alternates; and on a phone (390 x 844) nothing goes sideways.
//
// Prints "talk: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("talk_flow: --url=<deployment>");
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const host = new URL(site).host;
if (/^(?:www\.)?brickworks\.diy$/.test(host)) {
  console.error("talk_flow: never on brickworks.diy");
  process.exit(2);
}
const local = /^(?:127\.0\.0\.1|localhost)(?::\d+)?$/.test(host);
// A server of this machine holds Talk itself, so nothing is written to the
// project's Talk; one that does not may only show the waiting page.
if (local && await fetch(`${site}/__held/talk`).then((reply) => reply.status, () => 0) !== 200
  && await fetch(`${site}/api/people?op=talk_latest&n=1&tests=1`).then((reply) => reply.json(), () => null)
    .then((said) => said?.ready !== false, () => true)) {
  console.error("talk_flow: this machine's server is to hold Talk itself (relay_server.mjs PORT --hold=talk)");
  process.exit(2);
}
// The console only where it is a throwaway's: never the owner's.
const consoleEmail = String(process.env.MASTER_EMAIL || "");
const withConsole = local && /^delivered\+[a-z0-9-]+@resend\.dev$/i.test(consoleEmail);
const out = path.resolve(String(args.out || "shots/talk"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const emails = Object.fromEntries(["ann", "bea", "cy", "dee"].map((who) => [who, `delivered+bw-talk-${who}-${rand}@resend.dev`]));
const handles = Object.fromEntries(["ann", "bea", "cy", "dee"].map((who) => [who, `tk-${who}-${rand}`]));
const names = { ann: "Ann Talk", bea: "Bea Talk", cy: "Cy Talk", dee: "Dee Talk" };

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const ldraw = `0 Talk tower\r\n0 Name: talk.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // talk flow ${rand}\r\n`;

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
  return { status: reply.status, body: parsed, text, type: reply.headers.get("content-type") || "" };
}

const browser = await launch({ signedOut: true });
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// [pathname] in a browser of its own, signed in as [who] or out.
async function open(pathname, { who = null, phone = false } = {}) {
  const context = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 900 },
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
  page.on("dialog", (dialog) => dialog.accept());
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

const textOf = (page, selector) => page.evaluate((s) => [...document.querySelectorAll(s)].map((one) => one.textContent.replace(/\s+/g, " ").trim()), selector);
const noticesOf = async (who) => ((await api("/api/people?op=notifications", { token: who.access_token })).body.groups || [])
  .flatMap((group) => group.rows || []);
const postsOf = async (thread, who) => ((await api(`/api/people?op=talk_thread&id=${thread}&tests=1`, { token: who?.access_token })).body.posts || []);

const people = {};
let consoleWho = null;
let modelId = "";
// Where supabase/talk.sql is not applied yet (a preview before the lead
// applies it): /talk says so, the homepage leaves its Talk section out, and
// that is all there is to check; said plainly, never "all ok".
async function waitingOnly() {
  const latest = await api("/api/people?op=talk_latest&n=1&tests=1");
  if (!(latest.status === 200 && latest.body?.ready === false)) return false;
  console.log("0. supabase/talk.sql is not applied on this deployment");
  const page = await fetch(`${site}/talk`, { headers });
  const text = await page.text();
  check(`/talk says Talk is not open yet: ${page.status}`, page.status === 503 && /Talk is not open on Brickworks yet/.test(text));
  const home = await open("/index.html");
  await home.evaluate(() => document.getElementById("talk-latest")?.scrollIntoView());
  const hidden = await until(home, () => document.getElementById("talk-latest")?.hidden === true || null,
    "the homepage's Talk section left out", 60).catch(() => false);
  check("the homepage leaves its Talk section out", hidden === true);
  await home.context().close();
  return true;
}

if (await waitingOnly()) {
  await browser.close();
  for (const error of errors) console.log(`  page: ${error}`);
  check("no page errors", errors.length === 0);
  console.log(failed ? `${failed} FAILED` : "talk: supabase/talk.sql is not applied here, so only its waiting page was checked");
  process.exit(failed ? 1 : 0);
}

try {
  console.log("1. The boards, signed out");
  // The homepage's latest talk (#talk-latest), filled as it nears the screen.
  const landing = await open("/index.html?tests=1");
  await landing.evaluate(() => document.getElementById("talk-latest")?.scrollIntoView());
  const strip = await until(landing, () => {
    const place = document.getElementById("talk-latest");
    const rows = [...(place?.querySelectorAll(".talk-row") || [])];
    return place && !place.hidden && Number(place.dataset.filled) > 0 && rows.length
      ? { rows: rows.length, title: rows[0].querySelector(".talk-row-title a")?.getAttribute("href") || "",
        all: place.querySelector("a[href$='/talk'], a[href*='/talk?']")?.textContent.trim() || "" } : null;
  }, "the homepage's latest talk", 60);
  check(`the homepage shows the latest talk: ${strip.rows} threads, "${strip.all}"`, strip.rows >= 1 && strip.rows <= 4
    && /^\/talk\/t\/\d+/.test(strip.title));
  await landing.context().close();
  const visitor = await open("/talk?tests=1");
  const tabs = await textOf(visitor, "nav.talk-boards a");
  check(`six tabs, Latest and the five boards: ${tabs.join(" | ")}`, tabs.length === 6 && /Latest/.test(tabs[0]) && tabs.some((one) => /Show and tell/.test(one)));
  const rows = await textOf(visitor, "#talk-list .talk-row");
  check(`never empty: ${rows.length} threads on Latest, the house's among them`, rows.length >= 4 && rows.some((one) => /Brickworks started it/.test(one)));
  check("what builders say under the models is beside them", (await textOf(visitor, ".talk-aside h2")).some((one) => /On the models/.test(one)));
  await shot(visitor, "1-latest.png");
  const help = await visitor.goto(`${site}/talk/b/help?tests=1`).then(() => textOf(visitor, "#talk-list .talk-row-meta, #talk-list .pill"));
  const current = await visitor.evaluate(() => document.querySelector("nav.talk-boards a[aria-current]")?.textContent.trim() || "");
  check(`Help: its tab is the current one (${current}), every row is Help's`, /Help/.test(current) && help.length > 0);
  const firstThread = await visitor.evaluate(() => document.querySelector("#talk-list .talk-row-title a")?.getAttribute("href") || "");
  await visitor.goto(`${site}${firstThread}`);
  await until(visitor, () => !document.querySelector("[data-signin]")?.hidden, "the sign-in offer");
  check("a thread, signed out: Reply asks to sign in, no box", await visitor.evaluate(() => document.querySelector("[data-reply-form]")?.hidden === true
    && Boolean(document.querySelector("[data-signin] [data-act='sign-in']:not([hidden])"))));
  await visitor.context().close();

  console.log("2. Ann's model, and her Show and tell thread about it");
  for (const who of ["ann", "bea", "cy", "dee"]) {
    people[who] = await mintSession(emails[who]);
    const profile = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
      body: { handle: handles[who], name: names[who] } });
    check(`${names[who]} @${handles[who]}: ${profile.status}`, profile.status === 200);
  }
  const shared = await api("/api/share", { method: "POST", token: people.ann.access_token,
    body: { name: `Talk tower ${rand}`, author: names.ann, model: ldraw, image: picture, listed: true } });
  modelId = shared.body.id || "";
  check(`Ann's tower /m/${modelId}: ${shared.status}`, shared.status === 201 && /^[A-Za-z0-9]{10}$/.test(modelId));
  const annModel = await open(`/m/${modelId}?tests=1`, { who: people.ann });
  const offer = await until(annModel, () => {
    const place = document.getElementById("talk-about");
    return place && !place.hidden && place.querySelector("a") ? place.querySelector("a").getAttribute("href") : null;
  }, "the model page's Talk offer", 60);
  check(`her model's page offers a Show and tell thread: ${offer}`, /\/talk\/new\?model=/.test(offer));
  await annModel.click("#talk-about a");
  await until(annModel, () => document.querySelector("[data-start-form]") && !document.querySelector("[data-start-form]").hidden, "the start form");
  check("the form starts in Show and tell, about her model", await annModel.evaluate(() =>
    document.querySelector("input[name='board'][value='show']")?.checked === true && Boolean(document.querySelector("[data-model]"))));
  const title = `My tower ${rand}`;
  await annModel.fill("#talk-title", title);
  await annModel.fill("#talk-words", `Here it is. Step 2 is the tricky one: ${site}/app?view=${modelId}&step=2 What do you think, @${handles.bea}?`);
  await annModel.click("[data-start-form] button[type='submit']");
  await annModel.waitForURL(/\/talk\/t\/\d+/, { timeout: 60000 });
  const threadPath = new URL(annModel.url()).pathname;
  const thread = Number(/\/talk\/t\/(\d+)/.exec(threadPath)[1]);
  await until(annModel, () => document.querySelector("#talk-posts li[data-mine]"), "her post, drawn as hers");
  check(`the thread ${threadPath}: the model's card`, await annModel.evaluate((id) => Boolean(document.querySelector(`.talk-model[href*="/m/${id}"]`)), modelId));
  const embeds = await textOf(annModel, "#talk-posts .talk-embed");
  check(`the step's card in her post: ${embeds.join(" | ").slice(0, 120)}`, embeds.some((one) => /Step 2/.test(one)));
  check("Bea's name is a link to her", await annModel.evaluate((handle) => Boolean(document.querySelector(`#talk-posts a.mention[href$="/u/${handle}"]`)), handles.bea));
  const schema = await annModel.evaluate(() => [...document.querySelectorAll('script[type="application/ld+json"]')].map((one) => one.textContent).join(" "));
  check("its JSON-LD is a DiscussionForumPosting", /DiscussionForumPosting/.test(schema) && schema.includes(title));
  await shot(annModel, "2-thread.png");
  await annModel.context().close();
  const about = await open(`/m/${modelId}?tests=1`);
  const linked = await until(about, () => {
    const place = document.getElementById("talk-about");
    return place && !place.hidden ? place.textContent.replace(/\s+/g, " ").trim() : null;
  }, "the model page's thread link", 60);
  check(`the model's page links to it for anybody: ${linked}`, linked.includes(title));
  await about.context().close();

  console.log("3. Bea is told; she answers; Ann is told");
  const beaTold = await noticesOf(people.bea);
  const inThread = (one) => new RegExp(`/talk/t/${thread}(?:[?#]|$)`).test(String(one.link || ""));
  check(`Bea's notifications: mentioned in Talk (${beaTold.map((one) => one.kind).join(",")})`,
    beaTold.some((one) => one.kind === "talk_mention" && inThread(one) && /mentioned you in Talk/.test(one.line || "")));
  const bea = await open(`${threadPath}?tests=1`, { who: people.bea });
  await until(bea, () => document.querySelector("[data-reply-form]") && !document.querySelector("[data-reply-form]").hidden, "Bea's reply box");
  await bea.click("#talk-posts li:first-child button[data-act='reply']");
  check("Answer says whom", /Ann Talk/.test((await textOf(bea, "[data-answering]"))[0] || ""));
  // Over the most, pasted: kept whole, said, and not sent (a maxlength cut it).
  const before = (await postsOf(thread, people.bea)).length;
  await bea.fill("#talk-reply-words", "🧱".repeat(4100));
  await bea.click("[data-reply-form] button[type='submit']");
  const over = await bea.evaluate(() => ({ kept: [...document.getElementById("talk-reply-words").value].length,
    count: document.querySelector("[data-reply-form] .talk-count")?.textContent || "",
    said: document.querySelector("[data-reply-form] [data-said]")?.textContent || "" }));
  check(`a post over 4,000 characters is kept whole and not sent: ${over.kept}, "${over.said}"`, over.kept === 4100
    && /4,000/.test(over.said) && /4,100/.test(over.count) && (await postsOf(thread, people.bea)).length === before);
  await bea.fill("#talk-reply-words", `@${handles.ann} lovely. Try a 1 x 2 plate under it ${rand}`);
  // Post pressed twice at once (a double click): one reply.
  await bea.dblclick("[data-reply-form] button[type='submit']");
  await until(bea, () => /Posted/.test(document.querySelector("[data-reply-form] [data-said]")?.textContent || ""), "Posted");
  const beaPosts = (await postsOf(thread, people.bea)).filter((one) => one.mine && !one.first);
  check(`Post pressed twice made one reply: ${beaPosts.length}`, beaPosts.length === 1);
  const beaPost = beaPosts[0];
  check(`Bea's reply is there, answering Ann's post: ${beaPost?.id}`, Boolean(beaPost?.id) && Boolean(beaPost.answers));
  await bea.context().close();
  const annTold = await noticesOf(people.ann);
  // Bea's reply names Ann in Ann's own thread: told once, as the reply
  // (supabase/talk.sql talk_notice_rows leaves out a mention a follow tells).
  const annTalk = annTold.filter((one) => /^talk_/.test(one.kind) && inThread(one));
  check(`Ann's notifications: Bea's reply in her thread, once (${annTalk.map((one) => one.kind).join(",")})`,
    annTalk.length === 1 && annTalk[0].kind === "talk_reply" && /replied in your thread/.test(annTalk[0].line || ""));
  const annNotices = await open("/notifications", { who: people.ann });
  const noticed = await until(annNotices, () => {
    const text = document.querySelector("main")?.textContent.replace(/\s+/g, " ") || "";
    return /replied in your thread/.test(text) ? text : null;
  }, "Ann's Notifications page", 60);
  check("her Notifications page says Bea replied in her thread", /Bea Talk/.test(noticed));
  await shot(annNotices, "3-notifications.png");
  await annNotices.context().close();

  console.log("4. Search");
  const found = await api(`/api/people?op=talk&tests=1&q=${encodeURIComponent(rand)}`);
  check(`a word of it finds the thread: ${found.status}, ${(found.body.threads || []).length}`, (found.body.threads || []).some((one) => Number(one.id) === thread));
  const searched = await open(`/talk?tests=1&q=nothing${rand}here`);
  const none = (await textOf(searched, ".talk-empty, .talk-searched")).join(" ");
  check(`and says when nothing does: ${none.slice(0, 80)}`, /Nothing in Talk says/.test(none));
  await searched.context().close();

  console.log("5. RSS");
  const all = await api("/talk.rss?tests=1");
  const show = await api("/talk/b/show.rss?tests=1");
  const helpFeed = await api("/talk/b/help.rss?tests=1");
  check(`every board's feed (${all.type}) and Show and tell's carry it`, /rss\+xml/.test(all.type) && /<rss version="2.0"/.test(all.text)
    && all.text.includes(title) && show.text.includes(title));
  check("Help's feed does not", helpFeed.status === 200 && !helpFeed.text.includes(title));

  console.log("6. Dee answers; Ann blocks Dee");
  const deeSaid = await api("/api/people?op=talk_reply&tests=1", { method: "POST", token: people.dee.access_token,
    body: { thread, body: `dee was here ${rand}` } });
  check(`Dee's reply: ${deeSaid.status}`, deeSaid.status === 201);
  const deePost = Number(deeSaid.body.post?.id);
  const ann = await open(`${threadPath}?tests=1`, { who: people.ann });
  await until(ann, (id) => document.querySelector(`#post-${id} [data-acts]:not([hidden]) button[data-act='block']`), "Dee's post's Block", 30, deePost);
  await ann.click(`#post-${deePost} button[data-act='block']`);
  await until(ann, (id) => !document.getElementById(`post-${id}`), "Dee's post gone for Ann", 30, deePost);
  check("Ann is told some posts are not shown", await ann.evaluate(() => document.querySelector("[data-blocked-some]")?.hidden === false));
  await shot(ann, "6-blocked.png");
  await ann.context().close();
  const seen = (await postsOf(thread, null)).map((one) => Number(one.id));
  const deeSees = (await postsOf(thread, people.dee)).map((one) => Number(one.id));
  check(`a visitor no longer sees it (the starter blocked Dee); Dee still does`, !seen.includes(deePost) && deeSees.includes(deePost));
  const deeAgain = await api("/api/people?op=talk_reply&tests=1", { method: "POST", token: people.dee.access_token,
    body: { thread, body: `dee again ${rand}` } });
  check(`Dee's next reply there is refused without saying why: ${deeAgain.status} ${deeAgain.body.error}`,
    deeAgain.status === 403 && deeAgain.body.error === "You cannot post here.");

  console.log("7. Cy reports Bea's reply");
  const cy = await open(`${threadPath}?tests=1`, { who: people.cy });
  await until(cy, (id) => document.querySelector(`#post-${id} [data-acts]:not([hidden]) button[data-act='report']`), "Bea's post's Report", 30, beaPost.id);
  await cy.click(`#post-${beaPost.id} button[data-act='report']`);
  await cy.check("dialog.report input[value='spam']");
  await cy.click("dialog.report button[type='submit']");
  const thanked = await until(cy, () => {
    const text = document.querySelector("dialog.report")?.textContent || "";
    return /Thank you/.test(text) ? text : null;
  }, "the thanks");
  check("the dialog thanks Cy", /remove it if it should not be there/.test(thanked));
  await cy.context().close();
  if (withConsole) {
    consoleWho = await mintSession(consoleEmail, { age: false, welcome: false });
    const desk = await open("/admin?tests=1#talk/reports", { who: consoleWho });
    await until(desk, (id) => document.getElementById(`talk-post-${id}`), "the reported post in the console", 60, beaPost.id);
    await shot(desk, "7-console.png");
    const hide = desk.locator(`#talk-post-${beaPost.id} button`, { hasText: "Hide it" });
    await hide.click();
    const hidden = await until(desk, () => /^Hidden: @/.test(document.getElementById("talk-said")?.textContent || "")
      && document.getElementById("talk-said").textContent, "the console saying Hidden", 30);
    check(`the console says what it did: ${hidden}`, hidden.includes(handles.bea));
    await desk.context().close();
    const held = await fetch(`${site}/__held/talk`).then((reply) => reply.json());
    const audited = (held.audit || []).filter((row) => /talk_act/.test(JSON.stringify(row)));
    check(`the console hid it, kept in the audit (${audited.length})`, audited.length >= 1);
  } else {
    for (const who of ["ann", "dee"]) {
      const said = await api("/api/people?op=report", { method: "POST", token: people[who].access_token, body: { post: beaPost.id, reason: "spam" } });
      check(`${names[who]} reports it too: ${said.status}`, said.status === 200);
    }
  }
  const after = (await postsOf(thread, null)).map((one) => Number(one.id));
  const beaSees = (await postsOf(thread, people.bea)).find((one) => Number(one.id) === Number(beaPost.id));
  check("a visitor no longer sees it; Bea sees it hidden", !after.includes(Number(beaPost.id)) && beaSees?.hidden === true);

  console.log("8. The month's challenge has its thread");
  const challenges = await open("/talk/b/challenges?tests=1");
  const challengeRows = await textOf(challenges, "#talk-list .talk-row");
  check(`a thread in Challenges, by Brickworks: ${challengeRows[0]?.slice(0, 80)}`, challengeRows.some((one) => /Brickworks started it/.test(one)));
  const challengePath = await challenges.evaluate(() => document.querySelector("#talk-list .talk-row-title a")?.getAttribute("href"));
  await challenges.goto(`${site}${challengePath}`);
  check("its thread leads to the challenge", await challenges.evaluate(() => Boolean(document.querySelector(".talk-challenge a[href*='/challenge'], #talk-posts a[href*='/challenge']"))));
  await challenges.context().close();

  console.log("9. In German, and on a phone");
  const german = await open("/de/talk?tests=1");
  const de = await german.evaluate(() => ({ lang: document.documentElement.lang, start: document.querySelector("a[data-start]")?.textContent.trim(),
    tabs: [...document.querySelectorAll("nav.talk-boards a")].map((one) => one.textContent.trim()).join(" | "),
    alternates: [...document.querySelectorAll('link[rel="alternate"][hreflang]')].map((one) => one.hreflang).join(",") }));
  check(`/de/talk: lang ${de.lang}, "${de.start}", ${de.tabs}`, de.lang === "de" && /Thema starten/.test(de.start || "") && /Zeigen/.test(de.tabs));
  check(`its alternates: ${de.alternates}`, ["en", "de", "fr", "es"].every((code) => de.alternates.split(",").includes(code)));
  await shot(german, "9-de.png");
  await german.goto(`${site}/de${threadPath}?tests=1`);
  const deThread = await german.evaluate(() => ({ lang: document.documentElement.lang,
    reply: document.querySelector("#talk-posts button[data-act='reply']")?.textContent.trim() }));
  check(`the thread in German: lang ${deThread.lang}, "${deThread.reply}"`, deThread.lang === "de" && /Antworten/.test(deThread.reply || ""));
  await german.context().close();
  for (const where of ["/talk?tests=1", `${threadPath}?tests=1`, "/talk/new?tests=1"]) {
    const phone = await open(where, { who: people.ann, phone: true });
    await phone.waitForTimeout(1500);
    check(`${where} at 390 x 844: nothing sideways`, !(await sideways(phone)));
    if (where.startsWith(threadPath)) await shot(phone, "9-phone-thread.png");
    await phone.context().close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (modelId && people.ann) await api(`/api/share?op=unpublish&id=${modelId}`, { method: "POST", token: people.ann.access_token }).catch(() => {});
  await browser.close();
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
  if (consoleWho) await deleteAccount(consoleEmail).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "talk: all ok");
process.exit(failed ? 1 : 0);
