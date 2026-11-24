// A name before the first public act, and Reply where you read
// (socialloop, 2026-11-24), in real browsers at 1280 (a mouse) and 390 (a
// finger), against a local relay or a preview:
//
//   node --env-file=.env tools/web/relay_server.mjs 11850 &
//   node --env-file=.env tools/web/socialloop_flow.mjs --url=http://127.0.0.1:11850 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/socialloop_flow.mjs --url=<preview> --out=DIR
//
// Throwaway accounts at Resend test addresses, deleted at the end with the
// model: Dana designs a model (she has a profile); a fan at each width
// (13 or over, no profile) and Kit (answered under 13).
//
//   1. The fan writes a comment on Dana's model and presses Post: Make
//      your profile opens over the page first (web/account.js nameFirst,
//      First steps' own step), the words still in the box under it.
//   2. Skip: the comment goes, as "A builder".
//   3. A second comment asks again; a profile made in the ask, the comment
//      goes credited, its name a link to the profile, and the first one with
//      it; a third asks nothing.
//   4. Kit, under 13, never sees the ask: the box is not offered and the
//      page says why, as before.
//   5. A fan with no profile starts a thread in Talk (1280): asked first,
//      Skip, and the thread starts. Then a photo of her build on the
//      model: asked again, its words kept; Skip, and it goes.
//   6. Dana's Notifications: each comment's line has Reply (44 px under a
//      finger). From the keyboard: Reply, the box focused, Ctrl+Enter
//      posts, the line says Replied with the way to it, the focus back on
//      Reply; Escape closes it again. The reply is in the comment's
//      thread on the model's page at once.
//   7. In de, fr and es (390): Reply and Replied in the page's language.
//
// Pictures in --out, each the viewport at its width.
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
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11850").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/socialloop"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const address = (who) => `delivered+bw-socialloop-${who}-${rand}@resend.dev`;
const emails = { dana: address("dana"), fan1280: address("fan1280"), fan390: address("fan390"), kit: address("kit"),
  tess: address("tess") };
const DANA = `bwsl-dana-${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: socialloop.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // socialloop flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context(as, { phone = false } = {}) {
  const made = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 800 },
    extraHTTPHeaders: headers, colorScheme: "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await made.addInitScript(([name, value]) => {
    try {
      if (!sessionStorage.getItem("flow.seeded") && !localStorage.getItem(name)) localStorage.setItem(name, value);
      sessionStorage.setItem("flow.seeded", "1");
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

/// The viewport as a person sees it, never fullPage (memory fullpage-shot-drops-touch).
const shot = (page, name) => page.screenshot({ path: path.join(out, `${name}.png`), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
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

/// The model page's comments as drawn: [{id, who, linked, body, reply}].
const commentsDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("#comments .comment-list li.comment")]
  .map((li) => ({ id: Number(li.id.replace("comment-", "")), who: li.querySelector(".comment-head a, .comment-head b")?.textContent.trim() || "",
    linked: li.querySelector(".comment-head a")?.getAttribute("href") || "", body: li.querySelector(":scope > .comment-main > .comment-body, .comment-body")?.textContent.trim() || "",
    reply: li.classList.contains("reply"), under: Number(li.parentElement?.closest("li.comment")?.id.replace("comment-", "")) || 0 })));

/// The ask as drawn: open, its step, its title, and what the box under it holds.
const askDrawn = (page, box = "#comment-body") => page.evaluate((field) => {
  const dialog = document.querySelector("dialog.first-steps[open]");
  return { open: Boolean(dialog), step: dialog?.dataset.step || "", title: dialog?.querySelector("h2")?.textContent || "",
    lede: dialog?.querySelector(".step > p")?.textContent || "", skip: Boolean(dialog?.querySelector("#first-skip")),
    box: document.querySelector(field)?.value || "" };
}, box);

/// The fan at one width: the ask before a first comment, Skip, asked
/// again, a profile made in it and the comment credited, then no ask.
async function fanWalk(fan, id, { phone }) {
  const w = phone ? "390" : "1280";
  const ctx = await context(fan, { phone });
  const page = await ctx.newPage();
  listen(page, `fan ${w}`);
  await page.goto(`${site}/m/${id}?tests=1#comments`, { waitUntil: "load" });
  await page.click('#page-tabs [data-tab="comments"]').catch(() => null);
  await until(page, () => {
    const form = document.querySelector("#comments form.comment-new");
    return form && !form.hidden && form.offsetParent;
  }, `${w}: the comment box`, 60);
  const first = `First thoughts at ${w}: the arch is lovely (${rand})`;
  await page.fill("#comment-body", first);
  await page.click("#comments form.comment-new button[type=submit]");
  let ask = await until(page, async () => document.querySelector("dialog.first-steps[open][data-step=profile]") && true, `${w}: the ask`, 30)
    .then(() => askDrawn(page)).catch(() => askDrawn(page));
  check(`${w}: Post asks for a name first, in First steps' Make your profile ("${ask.title}"), the words still in the box`,
    ask.open && ask.step === "profile" && ask.title === "Make your profile" && ask.skip && ask.box === first);
  check(`${w}: ...and says why now, and what Skip does ("${ask.lede.slice(0, 90)}…")`, /goes out under this name/.test(ask.lede)
    && /A builder/.test(ask.lede));
  const sentEarly = (await commentsDrawn(page)).some((one) => one.body === first);
  check(`${w}: nothing posted while it is open`, !sentEarly);
  await shot(page, `${w}_1_ask_before_comment`);
  await page.click("#first-skip");
  // This comment, as the server has it (its id): the other width's fan's
  // comments are on the page already.
  let drawn = await until(page, async (body) => [...document.querySelectorAll("#comments .comment-list li.comment[id^='comment-']")]
    .some((one) => one.querySelector(".comment-body")?.textContent.trim() === body) || null,
  `${w}: the skipped comment`, 30, first).then(() => commentsDrawn(page));
  const skipped = drawn.find((one) => one.body === first);
  check(`${w}: Skip, and the comment goes, as "${skipped?.who}" with no link`, Boolean(skipped) && skipped.who === "A builder" && !skipped.linked);
  check(`${w}: ...and the ask is closed`, !(await askDrawn(page)).open);
  await page.locator(`#comment-${skipped?.id}`).scrollIntoViewIfNeeded().catch(() => null);
  await shot(page, `${w}_2_skipped_posted`);
  // Asked again on the next act.
  const second = `And the roof at ${w} is clever (${rand})`;
  await page.fill("#comment-body", second);
  await page.click("#comments form.comment-new button[type=submit]");
  ask = await until(page, async () => document.querySelector("dialog.first-steps[open][data-step=profile]") && true, `${w}: asked again`, 30)
    .then(() => askDrawn(page)).catch(() => askDrawn(page));
  check(`${w}: the next comment asks again, its words in the box`, ask.open && ask.box === second);
  const name = `Fan Loop ${w}`;
  await page.fill("#first-name", name);
  const handle = await page.inputValue("#first-handle");
  check(`${w}: the handle follows the name ("${handle}")`, handle === `fan-loop-${w}`);
  const unique = `${handle}-${rand}`;
  await page.fill("#first-handle", unique);
  await shot(page, `${w}_3_ask_filled`);
  await page.click("#first-make");
  drawn = await until(page, async (body) => {
    const li = [...document.querySelectorAll("#comments .comment-list li.comment")]
      .find((one) => one.querySelector(".comment-body")?.textContent.trim() === body);
    return li && li.querySelector(".comment-head a") ? true : null;
  }, `${w}: the credited comment`, 30, second).then(() => commentsDrawn(page));
  const credited = drawn.find((one) => one.body === second);
  check(`${w}: made, the comment goes credited "${credited?.who}" (${credited?.linked})`,
    credited?.who === name && /\/u\/fan-loop-/.test(credited?.linked || ""));
  const before = drawn.find((one) => one.body === first);
  check(`${w}: ...and the skipped one is credited with it ("${before?.who}")`, before?.who === name);
  await page.locator(`#comment-${credited?.id}`).scrollIntoViewIfNeeded().catch(() => null);
  await shot(page, `${w}_4_credited`);
  // Named: the next comment asks nothing.
  const third = `One more at ${w} (${rand})`;
  await page.fill("#comment-body", third);
  await page.click("#comments form.comment-new button[type=submit]");
  await until(page, async (body) => [...document.querySelectorAll("#comments .comment-list .comment-body")]
    .some((one) => one.textContent.trim() === body), `${w}: the third comment`, 30, third);
  check(`${w}: with a profile, the next comment asks nothing`, !(await askDrawn(page)).open);
  await ctx.close();
  return { first: skipped?.id || 0, second: credited?.id || 0, name };
}

/// Dana's Notifications at one width: Reply under each comment's line,
/// from the keyboard; Replied; Escape; the reply on the model's page.
async function replyWalk(dana, id, fanComment, fanName, { phone }) {
  const w = phone ? "390" : "1280";
  const ctx = await context(dana, { phone });
  const page = await ctx.newPage();
  listen(page, `dana ${w}`);
  await page.goto(`${site}/notifications`, { waitUntil: "load" });
  await until(page, () => document.documentElement.dataset.notifications === "ready", `${w}: notifications`, 60);
  const line = page.locator(`ol.notices .notice[data-model="${id}"] .lines > li`).filter({ has: page.locator(`a[href$="#comment-${fanComment}"]`) });
  const found = await line.count();
  check(`${w}: the comment's line is in her Notifications (${found})`, found === 1);
  const reply = line.locator(".notice-acts button");
  const box = await reply.boundingBox();
  check(`${w}: it has Reply, ${Math.round(box?.width || 0)}x${Math.round(box?.height || 0)} px${phone ? " (44 under a finger)" : ""}`,
    Boolean(box) && (await reply.textContent()).trim() === "Reply" && (!phone || box.height >= 44)
    && (await reply.getAttribute("aria-label")) === `Reply to ${fanName}`);
  await line.scrollIntoViewIfNeeded();
  await shot(page, `${w}_5_notifications_reply`);
  // From the keyboard: focused, Enter opens the box with the focus in it.
  await reply.focus();
  await page.keyboard.press("Enter");
  await until(page, () => document.activeElement?.matches(".notice .composer textarea") || null, `${w}: the box focused`, 20);
  check(`${w}: Enter on Reply opens the composer in place, focused, Reply expanded`,
    (await reply.getAttribute("aria-expanded")) === "true");
  const words = `Thank you! The arch is two 1x2s at ${w} (${rand})`;
  await page.keyboard.type(words);
  await shot(page, `${w}_6_reply_typed`);
  const posted = page.waitForResponse((r) => r.url().includes("op=reply") && r.request().method() === "POST", { timeout: 30000 })
    .catch(() => null);
  await page.keyboard.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
  const went = await posted;
  const made = went ? await went.json().catch(() => ({})) : {};
  const replyId = Number(made?.comment?.id) || 0;
  check(`${w}: Ctrl+Enter posts it to the comment (${went?.status()}, comment ${replyId})`, went?.status() === 201 && replyId > 0);
  const said = await until(page, (n) => {
    const row = [...document.querySelectorAll(".notice .lines > li")].find((li) => li.querySelector(`.said-line[data-line="${n}"]`));
    if (!row) return null;
    return { pill: row.querySelector(".pill.answered")?.textContent || "", see: row.querySelector(".said-see")?.getAttribute("href") || "",
      line: row.querySelector(`.said-line[data-line="${n}"] p > span[lang]`)?.textContent || "", open: !row.querySelector("form.composer")?.hidden,
      focus: document.activeElement?.matches(".notice-acts button") || false, read: !row.closest(".notice")?.classList.contains("unread") };
  }, `${w}: answered`, 20, replyId).catch(() => ({}));
  check(`${w}: the line says "${said.pill}", the reply under it, the way to it (${said.see})`,
    said.pill === "Replied" && said.line === words && new RegExp(`/m/${id}#comment-${replyId}$`).test(said.see || ""));
  check(`${w}: the box folds away, the focus back on Reply, the group read`, said.open === false && said.focus === true && said.read === true);
  await shot(page, `${w}_7_replied_in_place`);
  // Escape closes it again.
  await page.keyboard.press("Enter");
  await until(page, () => document.activeElement?.matches(".notice .composer textarea") || null, `${w}: opened again`, 10).catch(() => null);
  await page.keyboard.press("Escape");
  const closed = await page.evaluate(() => ({ focus: document.activeElement?.matches(".notice-acts button") || false,
    hidden: [...document.querySelectorAll(".notice form.composer")].every((one) => one.hidden) }));
  check(`${w}: Escape closes it, the focus on Reply`, closed.focus && closed.hidden);
  // The model's page has it at once, in the comment's thread.
  await page.locator(".said-see").first().click();
  await page.waitForURL(new RegExp(`/m/${id}`), { timeout: 30000 });
  const there = await until(page, (n) => {
    const li = document.getElementById(`comment-${n}`);
    return li && li.offsetParent ? { reply: li.classList.contains("reply"), under: Number(li.parentElement?.closest("li.comment")?.id.replace("comment-", "")) || 0,
      body: li.querySelector(".comment-body")?.textContent.trim() || "", by: li.querySelector(".comment-head a, .comment-head b")?.textContent.trim() || "",
      asked: li.classList.contains("asked"),
      // One press, one reply: the same words twice under it would be a second send.
      copies: [...(li.parentElement?.closest("li.comment")?.querySelectorAll("li.comment .comment-body") || [])]
        .filter((one) => one.textContent.trim() === li.querySelector(".comment-body")?.textContent.trim()).length } : null;
  }, `${w}: the reply on the model's page`, 30, replyId).catch(() => ({}));
  check(`${w}: the reply is on the model's page at once, under ${fanName}'s comment, by "${there.by}", once (${there.copies})`,
    there.reply === true && there.under === fanComment && there.body === words && there.by === "Dana Loop" && there.copies === 1);
  await page.locator(`#comment-${replyId}`).scrollIntoViewIfNeeded().catch(() => null);
  await shot(page, `${w}_8_reply_on_model_page`);
  const wide = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
  check(`${w}: nothing sideways`, !wide);
  await ctx.close();
  return replyId;
}

/// Dana's Notifications in [lang] at 390: Reply and Replied in its words.
async function languageWalk(dana, id, fanComment, lang, { reply: replyWord, replied }) {
  const ctx = await context(dana, { phone: true });
  const page = await ctx.newPage();
  listen(page, `dana ${lang}`);
  await page.goto(`${site}/${lang}/notifications`, { waitUntil: "load" });
  await until(page, () => document.documentElement.dataset.notifications === "ready", `${lang}: notifications`, 60);
  const line = page.locator(`ol.notices .notice[data-model="${id}"] .lines > li`).filter({ has: page.locator(`a[href$="#comment-${fanComment}"]`) });
  const reply = line.locator(".notice-acts button");
  const label = (await reply.textContent().catch(() => "")).trim();
  await reply.click();
  await until(page, () => document.activeElement?.matches(".notice .composer textarea") || null, `${lang}: the box`, 20);
  const post = (await line.locator("form.composer button[type=submit]").textContent()).trim();
  await page.keyboard.type(`${lang}: merci, danke, gracias (${rand})`);
  await line.locator("form.composer button[type=submit]").click();
  const pill = await until(page, () => document.querySelector(".notice .pill.answered")?.textContent || null, `${lang}: answered`, 30)
    .catch(() => "");
  check(`${lang}: Reply is "${label}", the composer's Post "${post}", answered "${pill}"`, label === replyWord && pill === replied
    && post !== "Post");
  await line.scrollIntoViewIfNeeded();
  await shot(page, `390_9_${lang}_replied`);
  await ctx.close();
}

const accounts = {};
const made = [];
try {
  console.log("Dana designs a model; two fans with no profile; Kit, under 13");
  accounts.dana = await mintSession(emails.dana);
  accounts.fan1280 = await mintSession(emails.fan1280);
  accounts.fan390 = await mintSession(emails.fan390);
  accounts.tess = await mintSession(emails.tess);
  accounts.kit = await mintSession(emails.kit, { age: false });
  await answerAge(accounts.kit.kept.user_id, emails.kit, false);
  const profile = await api("/api/people?op=profile", { method: "POST", token: accounts.dana.access_token,
    body: { handle: DANA, name: "Dana Loop" } });
  check(`Dana's profile: ${profile.status}`, profile.status === 200);
  const shared = await api("/api/share", { method: "POST", token: accounts.dana.access_token,
    body: { name: "Socialloop Arch", author: "Dana Loop", model: model("Socialloop Arch"), image: picture, listed: true } });
  const id = shared.body.id;
  made.push([id, accounts.dana]);
  check(`her model: ${shared.status} /m/${id}`, shared.status === 201 && Boolean(id));
  const said = await api("/api/account", { token: accounts.fan1280.access_token });
  check(`/api/account says a fan has no profile (${JSON.stringify(said.body.profile)}) and Dana has hers`,
    said.body.profile === null
    && (await api("/api/account", { token: accounts.dana.access_token })).body.profile?.handle === DANA);

  console.log("1-3. The fans comment");
  const at1280 = await fanWalk(accounts.fan1280, id, { phone: false });
  const at390 = await fanWalk(accounts.fan390, id, { phone: true });

  console.log("4. Kit, under 13");
  {
    const ctx = await context(accounts.kit);
    const page = await ctx.newPage();
    listen(page, "kit");
    await page.goto(`${site}/m/${id}?tests=1#comments`, { waitUntil: "load" });
    await page.click('#page-tabs [data-tab="comments"]').catch(() => null);
    const why = await until(page, () => {
      const note = document.querySelector("#comments .comment-why");
      return note && !note.hidden ? note.textContent.trim() : null;
    }, "kit: why not", 60).catch(() => "");
    const form = await page.evaluate(() => Boolean(document.querySelector("#comments form.comment-new")?.offsetParent));
    await page.waitForTimeout(1500);
    check(`under 13: no ask, the box not offered, and why as before ("${why.slice(0, 70)}…")`,
      !(await askDrawn(page)).open && !form && /13 and over/.test(why));
    await page.locator("#comments").scrollIntoViewIfNeeded().catch(() => null);
    await shot(page, "1280_under_13");
    await ctx.close();
  }

  console.log("5. A thread in Talk from an account with no profile");
  {
    const ctx = await context(accounts.tess);
    const page = await ctx.newPage();
    listen(page, "tess");
    await page.goto(`${site}/talk/new?tests=1`, { waitUntil: "load" });
    await until(page, () => {
      const form = document.querySelector("[data-start-form]");
      return form && !form.hidden;
    }, "tess: the new thread's form", 60);
    const title = `Which arch for a gate? (${rand})`;
    await page.locator("[data-start-form] input[name='board']").first().check().catch(() => null);
    await page.fill("[data-start-form] [name='title']", title);
    await page.fill("[data-start-form] [name='body']", "Looking for an arch that fits a 6-wide gate.");
    await page.click("[data-start-form] button[type='submit']");
    const ask = await until(page, () => document.querySelector("dialog.first-steps[open][data-step=profile]") && true, "tess: the ask", 30)
      .then(() => askDrawn(page, "[data-start-form] [name='title']")).catch(() => askDrawn(page, "[data-start-form] [name='title']"));
    check(`Talk: Post asks first, the title still typed ("${ask.box.slice(0, 30)}")`, ask.open && ask.box === title);
    await shot(page, "1280_talk_ask");
    await page.click("#first-skip");
    await page.waitForURL(/\/talk\/t\/\d+/, { timeout: 30000 }).catch(() => null);
    const thread = Number(/\/talk\/t\/(\d+)/.exec(page.url())?.[1]) || 0;
    check(`Talk: Skip, and the thread starts (/talk/t/${thread})`, thread > 0);
    if (thread) made.push([`talk:${thread}`, accounts.tess]);
    // A photo of her build on Dana's model: asked again (she skipped),
    // its words kept; Skip, and the photo goes.
    await page.goto(`${site}/m/${id}?tests=1#builds`, { waitUntil: "load" });
    await until(page, () => document.documentElement.dataset.buildPhotos, "tess: the builds section", 60);
    await page.click("[data-add-build]");
    await page.setInputFiles('.build-form input[type="file"]', path.join(here, "../../docs/brickify/fox-24.jpg"));
    const caption = `My fox beside the arch (${rand})`;
    await page.fill('.build-form input[name="words"]', caption);
    await page.click('.build-form button[type="submit"]');
    const asked = await until(page, () => document.querySelector("dialog.first-steps[open][data-step=profile]") && true, "tess: the photo's ask", 30)
      .then(() => askDrawn(page, '.build-form input[name="words"]')).catch(() => askDrawn(page, '.build-form input[name="words"]'));
    check(`a build photo: Send asks first, its words still there ("${asked.box.slice(0, 30)}")`, asked.open && asked.box === caption);
    await shot(page, "1280_photo_ask");
    await page.click("#first-skip");
    const kept = await until(page, () => document.documentElement.dataset.buildPhoto || null, "tess: the photo kept", 120).catch(() => "");
    check(`...Skip, and the photo goes (${kept})`, /^[A-Za-z0-9]{10}$/.test(kept || ""));
    await ctx.close();
  }

  console.log("6. Dana replies from Notifications");
  await replyWalk(accounts.dana, id, at1280.second, at1280.name, { phone: false });
  await replyWalk(accounts.dana, id, at390.second, at390.name, { phone: true });

  console.log("7. In de, fr and es");
  await languageWalk(accounts.dana, id, at1280.first, "de", { reply: "Antworten", replied: "Beantwortet" });
  await languageWalk(accounts.dana, id, at390.first, "fr", { reply: "Répondre", replied: "Répondu" });
  await languageWalk(accounts.dana, id, at1280.second, "es", { reply: "Responder", replied: "Respondido" });
} catch (trouble) {
  check(`the walk went on: ${String(trouble?.message || trouble).split("\n")[0]}`, false);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const one of errors.slice(0, 5)) console.log(`        ${one}`);
  for (const [one, who] of made) {
    if (!String(one).startsWith("talk:") && one && who) {
      await api(`/api/share?op=unpublish&id=${one}`, { method: "POST", token: who.access_token }).catch(() => {});
    }
  }
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
  await browser.close();
}
console.log(failed ? `socialloop: ${failed} FAILED` : "socialloop: a name before the first public act, Reply where you read: ok");
process.exit(failed ? 1 : 0);
