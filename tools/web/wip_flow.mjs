// Work in progress, shared by version, in real browsers (2026-11-23, unit
// buildlog; api/_wip.js, supabase/wip.sql, src/ui/share_panel.gd).
//
//   tools/export.sh web
//   grep -E '^(SUPABASE_URL|SUPABASE_SECRET_KEY|SUPABASE_PUBLISHABLE_KEY)=' .env > $SCRATCH/flow.env
//   node --env-file=$SCRATCH/flow.env tools/web/relay_server.mjs 11440 --static=build/web
//   node --env-file=$SCRATCH/flow.env tools/web/wip_flow.mjs --url=http://127.0.0.1:11440 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node ... tools/web/wip_flow.mjs --url=<preview> --out=DIR
//
// Needs supabase/wip.sql applied to the project (and talk.sql, which it
// posts through). Before it is, Share progress is refused in words
// (api/_wip.js NOT_YET) and this says so and stops: exit 2, never "all ok".
//
// Two throwaway accounts of this run's own, at resend.dev, each with a
// profile: Ada designs, Bo follows her. Both are deleted at the end, after
// Ada's model is taken down.
//
//   1. Ada, in the app (/app), presses Share and then Share progress: two
//      presses (a name typed first only if the model has none, said apart).
//      Within 60 s of the second press the model is in Bo's feed, said as
//      work in progress, and is its own Show and tell thread in Talk.
//   2. Bo follows the thread. Ada shares the next version as work in
//      progress with a note: the thread has exactly one post more and no
//      second thread; the post's change line is the versions' own
//      (?op=fetch versions[].said) word for word, and its card is the
//      version's, whose picture (/m/X/v/2.webp) is an image. Bo's feed says
//      the progress, and his notifications have the thread's new post.
//   3. The gallery: Newest (searched by the model's own word) lists it,
//      marked; Top, Builds and Likes do not; nor does the shelf.
//   4. The model's page, signed out, at 390 and 1280 px in light and dark:
//      the Log has both versions, newest first, each with its date, its
//      picture, its note and what changed, the newest marked work in
//      progress, each opening /m/X/v/N; nothing wider than the page.
//   5. Ada presses Mark it finished on her page: the mark is gone, the
//      thread has the finish as one post more, Bo's feed says it, and Top
//      lists the model as any other.
//   6. Bo blocks Ada; she shares another version as work in progress: it
//      reaches Bo nowhere, his feed, his notifications and the thread as he
//      reads it.
//
// Timings, presses and pictures in --out (wip_flow.json and PNGs).
import { clickStill, launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:11440").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/wip"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const WORD = `wipflow${rand}`;
const NAME = `Harbour crane ${WORD}`;
const ADA = `wip-ada-${rand}`;
const BO = `wip-bo-${rand}`;
const emails = { ada: `delivered+bw-wip-ada-${rand}@resend.dev`, bo: `delivered+bw-wip-bo-${rand}@resend.dev` };
const BAR_S = 60;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const said = { presses: 0, named: false };

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

async function until(page, test, what, seconds = 60, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(400);
  }
}

/// [ask] until it gives something, or [seconds]: what it gave and when, in
/// ms from [from].
async function poll(ask, from, seconds) {
  const end = from + seconds * 1000;
  for (;;) {
    const value = await ask().catch(() => null);
    if (value) return { value, ms: Date.now() - from };
    if (Date.now() > end) return { value: null, ms: null };
    await new Promise((done) => setTimeout(done, 1000));
  }
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

/// Press what the app shows by its name where it stands still, counted.
async function press(page, name, seconds = 60) {
  said.presses += 1;
  return clickStill(page, name, { seconds, after: 400 });
}

const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, dark = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(width < 600 ? { isMobile: true, hasTouch: true, deviceScaleFactor: 2 } : {}) });
  if (as) {
    const { kept } = await mintSession(as);
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(kept)]);
  }
  return made;
}

const feedOf = async (who) => (await api("/api/people?op=feed", { token: who.access_token })).body.rows || [];
const noticesOf = async (who) => ((await api("/api/people?op=notifications", { token: who.access_token })).body.groups || [])
  .flatMap((group) => group.rows || []);
const threadOf = async (id) => (await api(`/api/people?op=talk_model&id=${id}&tests=1`)).body?.thread || null;
/// Model [id]'s thread as its own page tells it ({id, board, title, model:
/// {id}, ...}): ?op=talk_model names only its id, title and replies
/// (supabase/talk.sql talk_model_thread), its board and model are the thread's.
const threadAbout = async (id) => {
  const named = await threadOf(id);
  if (!named?.id) return null;
  const page = (await api(`/api/people?op=talk_thread&id=${named.id}&tests=1`)).body?.thread;
  return page ? { ...named, ...page } : named;
};
const postsOf = async (thread, who = null) => (await api(`/api/people?op=talk_thread&id=${thread}&tests=1`, { token: who?.access_token })).body.posts || [];
const listOf = async (sort, extra = "") => ((await api(`/api/share?op=list&tests=1&sort=${sort}&q=${WORD}${extra}`)).body.models || [])
  .map((one) => one.id);
const aboutIt = (id) => (row) => String(row.link || "").includes(`/m/${id}`);

/// [text] with [lines] added at the end of its main model: before its
/// second 0 FILE where it has more than one, else at its end; one step more.
function withMore(text, lines) {
  const added = `${lines.join("\r\n")}\r\n0 STEP\r\n`;
  const files = [...text.matchAll(/^0 FILE .*$/gm)];
  if (files.length < 2) return `${text.replace(/\s*$/, "")}\r\n${added}`;
  const at = files[1].index;
  return `${text.slice(0, at).replace(/\s*$/, "")}\r\n${added}${text.slice(at)}`;
}

const people = {};
let modelId = "";
const timings = {};
let notApplied = false;
try {
  // --- the two, a profile each, Bo following Ada -----------------------------
  console.log("two throwaways: Ada designs, Bo follows her");
  for (const [who, handle, name] of [["ada", ADA, "Ada Wip"], ["bo", BO, "Bo Wip"]]) {
    people[who] = await mintSession(emails[who]);
    const made = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token, body: { handle, name } });
    check(`${name}'s profile @${handle} (${made.status})`, made.status === 200);
  }
  const follows = await api("/api/people?op=follow", { method: "POST", token: people.bo.access_token, body: { handle: ADA, on: true } });
  check(`Bo follows Ada (${follows.status})`, follows.status === 200);

  // --- 1. from the studio: Share, Share progress -------------------------------
  console.log("1. Ada shares progress from the studio");
  const adaContext = await context({ as: emails.ada });
  const studio = await adaContext.newPage();
  listen(studio, "studio");
  await studio.goto(`${site}/app`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await until(studio, () => (window.brickworksAccount || {}).state === "signed_in", "Ada signed in", 240);
  await until(studio, () => (window.brickworksState || {}).bricks > 0, "a model on the baseplate", 240);
  await studio.waitForTimeout(Number(args.load || 15000));
  const before = Date.now();
  await press(studio, "tool_share");
  await until(studio, () => (window.brickworksShare.panel || {}).open, "the Share panel");
  const panelName = await studio.evaluate(() => ((window.brickworksShare || {}).panel || {}).name || "");
  // Named as this run's own, so its lists find it: a person's model has
  // the name they gave it, and naming it is not part of sharing it.
  said.named = true;
  await clickStill(studio, "share_name", { seconds: 30, after: 200 });
  await studio.keyboard.press("Control+A");
  await studio.keyboard.type(NAME, { delay: 30 });
  await until(studio, (n) => ((window.brickworksShare || {}).panel || {}).name === n, "the name typed", 45, NAME).catch(() => null);
  const named = Date.now();
  await press(studio, "share_progress");
  const pressed = Date.now();
  const panel = await until(studio, () => {
    const p = (window.brickworksShare || {}).panel || {};
    return p.state === "published" || p.state === "failed" ? p : null;
  }, "publishing", 300);
  if (/not open on Brickworks yet/.test(String(panel.status || ""))) {
    notApplied = true;
    console.log(`  --    supabase/wip.sql is not applied here: "${panel.status}"`);
    throw new Error("wip.sql not applied");
  }
  modelId = String(panel.id || "");
  timings.published_ms = Date.now() - pressed;
  check(`two presses, Share and Share progress (${said.presses}; the model was named "${panelName}" before, renamed for this run)`,
    said.presses === 2);
  check(`published as work in progress at /m/${modelId} in ${timings.published_ms} ms: "${panel.status}"`,
    panel.state === "published" && panel.wip === true && /work in progress/.test(panel.status || ""));
  check(`...Talk took it (${JSON.stringify(panel.talk)}), and Publish reads "${panel.publish_text}"`,
    Boolean(panel.talk?.url) && panel.publish_text === "Publish as finished");
  await shot(studio, "1_studio_shared.png");
  const inFeed = await poll(async () => (await feedOf(people.bo)).find(aboutIt(modelId)), pressed, BAR_S);
  const inTalk = await poll(() => threadAbout(modelId), pressed, BAR_S);
  timings.feed_ms = inFeed.ms;
  timings.talk_ms = inTalk.ms;
  // Share pressed to the name typed, and from there to Share progress pressed.
  timings.share_to_named_ms = named - before;
  timings.named_to_progress_ms = pressed - named;
  check(`in Bo's feed within ${BAR_S} s of the press: ${inFeed.ms} ms, "${inFeed.value?.line}"`,
    inFeed.value && /work in progress/.test(inFeed.value.line || ""));
  const thread = inTalk.value;
  check(`its Show and tell thread within ${BAR_S} s: ${inTalk.ms} ms, ${thread ? `/talk/t/${thread.id} "${thread.title}" (${thread.board})` : "none"}`,
    Boolean(thread) && thread.board === "show");
  const first = thread ? await postsOf(thread.id) : [];
  check(`...the thread about the model (${thread?.model?.id || thread?.model}), one post by Ada with version 1's card (${first.length}: "${String(first[0]?.body || "").split("\n")[0]}")`,
    (thread?.model?.id || thread?.model) === modelId && first.length === 1 && String(first[0]?.body || "").endsWith(`/m/${modelId}/v/1`));

  // --- 2. the next version --------------------------------------------------
  console.log("2. the next version, as work in progress");
  const follow = await api("/api/people?op=talk_follow", { method: "POST", token: people.bo.access_token, body: { thread: thread?.id, on: true } });
  check(`Bo follows the thread (${follow.status})`, follow.status === 200);
  const file = await fetch(`${site}/m/${modelId}.mpd`, { headers }).then((r) => r.text());
  const more = withMore(file, ["1 4 0 -200 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 4 80 -200 0 1 0 0 0 1 0 0 0 1 3001.dat"]);
  check(`the model's file read back (${file.length} characters)`, file.length > 0 && !/^\s*[{<]/.test(file));
  const NOTE = "The jib is on";
  const unlisted = await api("/api/share", { method: "POST", token: people.ada.access_token,
    body: { id: modelId, name: NAME, model: file, listed: false, note: "only a link", wip: true } });
  check(`work in progress by its link only is refused, nothing written (${unlisted.status}): "${unlisted.body.error}"`,
    unlisted.status === 422 && /List it in the gallery/.test(unlisted.body.error || "")
    && ((await api(`/api/share?id=${modelId}`)).body.versions || []).length === 1);
  // The app sends each version with its picture and small picture (the PNG
  // and WebP it drew); this version goes by the API, so it carries version
  // 1's two as the app would carry its own. Without them it has none, and
  // /m/X/v/2.webp is rightly 404 (api/share.js op=thumb).
  const drawn = async (address, kind) => {
    const got = await fetch(`${site}${address}`, { headers });
    const bytes = Buffer.from(await got.arrayBuffer());
    const ok = kind === "png" ? bytes.subarray(1, 4).toString() === "PNG"
      : bytes.subarray(0, 4).toString() === "RIFF" && bytes.subarray(8, 12).toString() === "WEBP";
    return got.status === 200 && ok ? bytes.toString("base64") : undefined;
  };
  const [image, thumb] = [await drawn(`/m/${modelId}/v/1.png`, "png"), await drawn(`/m/${modelId}/v/1.webp`, "webp")];
  check(`version 1's picture and small picture read back to send with version 2 (${image ? "PNG" : "none"}, ${thumb ? "WebP" : "none"})`,
    Boolean(image));
  const second = await api("/api/share", { method: "POST", token: people.ada.access_token,
    body: { id: modelId, name: NAME, model: more, listed: true, author: "Ada Wip", note: NOTE, wip: true, image, thumb } });
  check(`version ${second.body.version} shared as work in progress (${second.status}): "${second.body.said}"`,
    second.status === 200 && second.body.version === 2 && second.body.wip === true && second.body.talk?.thread === thread?.id);
  const posts = await postsOf(thread?.id);
  const fetched = await api(`/api/share?id=${modelId}`);
  const versionLine = (fetched.body.versions || []).find((one) => one.n === 2)?.said || "";
  const lines = String(posts.at(-1)?.body || "").split("\n");
  check(`the thread has exactly one post more (${posts.length}) and the model one thread (${(await threadOf(modelId))?.id === thread?.id})`,
    posts.length === 2 && (await threadOf(modelId))?.id === thread?.id);
  check(`its change line is the versions' own: "${lines[1]}" = "${versionLine}"`, Boolean(versionLine) && lines[1] === versionLine);
  check(`...its note and the version's card: "${lines[0]}", ${lines.at(-1)}`,
    lines[0] === `Work in progress, version 2. ${NOTE}` && lines.at(-1).endsWith(`/m/${modelId}/v/2`));
  const picture = await fetch(`${site}/m/${modelId}/v/2.webp`, { headers });
  const kind = picture.headers.get("content-type") || "";
  check(`the version's picture /m/${modelId}/v/2.webp: ${picture.status} ${kind}`, picture.status === 200 && /^image\//.test(kind));
  const firstPicture = await fetch(`${site}/m/${modelId}/v/1.webp`, { headers });
  check(`...and version 1's, kept: ${firstPicture.status} ${firstPicture.headers.get("content-type")}`,
    firstPicture.status === 200 && /^image\//.test(firstPicture.headers.get("content-type") || ""));
  const progress = await poll(async () => (await feedOf(people.bo)).find((row) => String(row.link || "").endsWith(`/m/${modelId}/v/2`)), Date.now(), BAR_S);
  check(`Bo's feed says the progress: "${progress.value?.line}"`, /shared progress on/.test(progress.value?.line || ""));
  const told = await poll(async () => (await noticesOf(people.bo)).find((one) => String(one.kind || "").startsWith("talk")
    && String(one.link || "").includes(`/talk/t/${thread?.id}`)), Date.now(), BAR_S);
  check(`Bo's notifications have the thread's new post: ${told.value?.kind} "${told.value?.line}"`, Boolean(told.value));

  // --- 3. where the gallery lists it -----------------------------------------
  console.log("3. the gallery");
  const newest = await api(`/api/share?op=list&tests=1&sort=newest&q=${WORD}`);
  const card = (newest.body.models || []).find((one) => one.id === modelId);
  check(`Newest lists it, marked (${card ? `wip ${card.wip}` : "not listed"})`, card?.wip === true);
  for (const sort of ["top", "builds", "likes", "views"]) {
    check(`${sort} does not (${(await listOf(sort)).includes(modelId) ? "listed" : "not listed"})`, !(await listOf(sort)).includes(modelId));
  }
  const shelves = await api("/api/share?op=shelves&tests=1");
  const shelved = JSON.stringify(shelves.body || {}).includes(modelId);
  check(`nor the gallery's front: this week's pick and the shelf (${shelves.status}, ${shelved ? "there" : "not there"})`, !shelved);

  // --- 4. the Log, as anybody reads it ---------------------------------------
  console.log("4. the Log on its page");
  for (const width of [390, 1280]) {
    for (const dark of [false, true]) {
      const visitorContext = await context({ width, dark });
      const visitor = await visitorContext.newPage();
      listen(visitor, `visitor ${width}`);
      await visitor.goto(`${site}/m/${modelId}?tests=1#versions`, { waitUntil: "load" });
      await visitor.waitForTimeout(1500);
      const log = await visitor.evaluate(() => {
        const entries = [...document.querySelectorAll(".versions .earlier.log li.log-entry")];
        return { entries: entries.map((li) => ({ href: li.querySelector("a")?.getAttribute("href") || "",
            wip: li.classList.contains("wip"), date: Boolean(li.querySelector("time")),
            picture: (() => { const img = li.querySelector("img"); return img ? { loaded: img.complete && img.naturalWidth > 0, w: img.getBoundingClientRect().width } : null; })(),
            changed: li.querySelector(".log-changed")?.textContent.trim() || "", note: li.querySelector(".log-note")?.textContent.trim() || "" })),
          pill: Boolean(document.querySelector(".pill.wip")), wide: document.documentElement.scrollWidth - window.innerWidth,
          // The page's tabs are a role=tablist since pagekit (3cfdbeabe, 11-23), not a nav.
          tab: [...document.querySelectorAll('[role="tab"]')].map((one) => one.textContent.trim()).find((t) => /^Log/.test(t)) || "" };
      });
      const theme = dark ? "dark" : "light";
      check(`${width} px ${theme}: the Log has ${log.entries.length}, newest first (${log.entries.map((one) => one.href).join(", ")})`,
        log.entries.length === 2 && log.entries[0].href.endsWith(`/m/${modelId}/v/2`) && log.entries[1].href.endsWith(`/m/${modelId}/v/1`));
      check(`...each with its date, its picture and what changed; the newest marked work in progress (${JSON.stringify(log.entries.map((one) => [one.wip, one.date, one.picture?.loaded, one.changed.slice(0, 40)]))})`,
        log.entries.every((one) => one.date && one.picture?.loaded && one.changed) && log.entries[0].wip && log.entries[0].note === NOTE
        && log.pill);
      check(`...nothing wider than the page (${log.wide} px over), its tab "${log.tab}"`, log.wide <= 0 && /^Log/.test(log.tab));
      await visitor.evaluate(() => document.getElementById("versions")?.scrollIntoView());
      await shot(visitor, `4_log_${width}_${theme}.png`);
      await visitorContext.close();
    }
  }

  // --- 5. Mark it finished ------------------------------------------------------
  console.log("5. Ada marks it finished on its page");
  const page = await adaContext.newPage();
  listen(page, "Ada's page");
  await page.goto(`${site}/m/${modelId}?tests=1`, { waitUntil: "load" });
  // Mark it finished is in the Log, a tab of its own since pagekit
  // (3cfdbeabe, 11-23) and hidden until chosen: chosen as she would.
  await page.click("#tab-versions");
  await until(page, () => {
    const b = document.querySelector("[data-finish]");
    return b && !b.hidden && b.getBoundingClientRect().width > 0;
  }, "Mark it finished", 30);
  await shot(page, "5_mark_finished.png");
  await page.click("[data-finish]");
  const finishSaid = await until(page, () => { const s = document.querySelector(".finish-said"); return s && !s.hidden && /Finished/.test(s.textContent) ? s.textContent : null; },
    "the finish said", 30).catch(() => "");
  check(`the page says: "${String(finishSaid).trim()}"`, /version 2 is the finished one/.test(finishSaid));
  check("...and its mark is gone", await page.evaluate(() => !document.querySelector(".pill.wip") && !document.querySelector(".wip-line")));
  await shot(page, "5_finished.png");
  const after = await postsOf(thread?.id);
  check(`the thread has the finish as one post more (${after.length}): "${String(after.at(-1)?.body || "").split("\n")[0]}"`,
    after.length === 3 && /^Finished: version 2/.test(String(after.at(-1)?.body || "")));
  const finished = await poll(async () => (await feedOf(people.bo)).find((row) => /finished/.test(row.line || "") && aboutIt(modelId)(row)), Date.now(), BAR_S);
  check(`Bo's feed says it: "${finished.value?.line}"`, Boolean(finished.value));
  check(`Top lists it now as any other (${(await listOf("top")).includes(modelId)})`, (await listOf("top")).includes(modelId));
  const again = await api("/api/share?op=finish", { method: "POST", token: people.ada.access_token, body: { id: modelId } });
  check(`finished again: ${again.status} "${again.body.error}"`, again.status === 409);
  const notHers = await api("/api/share?op=finish", { method: "POST", token: people.bo.access_token, body: { id: modelId } });
  check(`Bo cannot finish it: ${notHers.status}`, notHers.status === 404);

  // --- 6. blocked -----------------------------------------------------------
  console.log("6. Bo blocks Ada, and she shares more progress");
  const blocked = await api("/api/people?op=block", { method: "POST", token: people.bo.access_token, body: { handle: ADA, on: true } });
  check(`Bo blocks Ada (${blocked.status})`, blocked.status === 200);
  const noticesBefore = (await noticesOf(people.bo)).length;
  const third = await api("/api/share", { method: "POST", token: people.ada.access_token,
    body: { id: modelId, name: NAME, model: withMore(more, ["1 1 0 -224 0 1 0 0 0 1 0 0 0 1 3001.dat"]), listed: true, author: "Ada Wip",
      note: "A hook", wip: true } });
  check(`version 3 shared as work in progress (${third.status}, posted ${Boolean(third.body.talk?.post)})`,
    third.status === 200 && third.body.wip === true && Boolean(third.body.talk?.post));
  await new Promise((done) => setTimeout(done, 5000));
  const boFeed = (await feedOf(people.bo)).filter(aboutIt(modelId));
  check(`Bo's feed has nothing of hers (${boFeed.length})`, boFeed.length === 0);
  check(`...nor his notifications anything new (${(await noticesOf(people.bo)).length} of ${noticesBefore})`,
    (await noticesOf(people.bo)).length <= noticesBefore);
  const boSees = await postsOf(thread?.id, people.bo);
  check(`...nor the thread as he reads it (${boSees.length} posts of Ada's)`, boSees.length === 0);
  await adaContext.close();
} catch (trouble) {
  if (!notApplied) {
    failed += 1;
    console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
  }
} finally {
  if (modelId && people.ada) await api(`/api/share?op=unpublish&id=${modelId}`, { method: "POST", token: people.ada.access_token, body: {} }).catch(() => {});
  await browser.close();
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
writeFileSync(path.join(out, "wip_flow.json"), JSON.stringify({ model: modelId, presses: said.presses, named: said.named, timings,
  not_applied: notApplied, failed }, null, 1));
for (const error of errors) console.log(`  page: ${error}`);
if (notApplied) {
  console.log("NOT RUN: supabase/wip.sql is not applied to this project; the lead applies it, then this runs");
  process.exit(2);
}
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : `work in progress went from the studio to a follower's feed in ${timings.feed_ms} ms and to Talk in ${timings.talk_ms} ms, one post a version`);
process.exit(failed ? 1 : 0);
