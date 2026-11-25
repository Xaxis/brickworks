// Blocking a person (docs/SOCIAL.md section 9, supabase/block.sql), in real
// browsers and through the API, with three throwaway accounts at Resend
// test addresses, deleted at the end with their models: Ada blocks Bob, Cy
// looks on.
//
//   node --env-file=.env tools/web/relay_server.mjs 10981 --static=web &
//   node --env-file=.env tools/web/block_flow.mjs --url=http://127.0.0.1:10981 --out=shots/block
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/block_flow.mjs --url=<preview> --out=DIR
//
//   1. Ada and Bob follow each other; Bob shares a shed, which is in Ada's
//      gallery search and her feed; Bob comments on Ada's tower and Cy
//      answers him; Cy comments too. Ada is told of Bob's comment.
//   2. Ada blocks Bob from his profile's More menu on a phone (390 x 844):
//      one line asks first and says what it does; the item says Unblock.
//   3. What it did: the follows ended both ways; Bob's shed out of Ada's
//      gallery search and feed (still in Cy's and a visitor's); Bob's comment
//      and Cy's answer to it hidden on the tower from Ada, Cy and a visitor,
//      not from Bob; Bob's rows out of Ada's notifications and her count.
//   4. Bob is never told: his notifications and his count as before, his
//      own pages without a word of it; he is refused a follow, a comment and
//      a reply in words that do not say why. Ada is told plainly.
//   5. The edges: yourself, nobody, no handle, no on, and a block again
//      answers the same. Row security: nobody's key reads the blocks, nor
//      calls block.sql's functions; only the server.
//   6. Settings › Blocked people on a phone lists Bob with Unblock; pressed,
//      his shed and comment come back, the follows do not.
//   7. Blocked again from his comment's row on the tower, one line asking
//      first: his comment leaves the page. Unblocked to end.
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { answerAsks } from "./asks.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:10981").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/block"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const PUBLISHABLE = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || "";
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(4).toString("hex");
const emails = { ada: `delivered+bw-block-ada-${rand}@resend.dev`, bob: `delivered+bw-block-bob-${rand}@resend.dev`,
  cy: `delivered+bw-block-cy-${rand}@resend.dev` };
const ADA = `bwb-ada-${rand}`;
const BOB = `bwb-bob-${rand}`;
const CY = `bwb-cy-${rand}`;
// A word in both models' names, for the gallery's search.
const WORD = `blockflow${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: block.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // block flow ${rand} ${name}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, phone = true } = {}) {
  const made = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 900 },
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

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

/// What [who] reads: the gallery's search for WORD (ids), the feed's rows'
/// writers and models, the notifications' writers, the counts, and the
/// tower's comments ({id, handle, parent}).
// As the gallery page asks it (web/models.js askApi): signed in, with mine=1.
const galleryOf = async (who) => ((await api(`/api/share?op=list&tests=1&q=${WORD}${who ? "&mine=1" : ""}`,
  { token: who?.access_token })).body.models || [])
  .map((one) => one.id);
const feedOf = async (who) => (await api("/api/people?op=feed", { token: who.access_token })).body.rows || [];
const noticesOf = async (who) => ((await api("/api/people?op=notifications", { token: who.access_token })).body.groups || [])
  .flatMap((group) => group.rows || []);
const countOf = async (who) => (await api("/api/people?op=feed_count", { token: who.access_token })).body;
const commentsOn = async (id, who) => ((await api(`/api/people?op=comments&id=${id}&v=1`, { token: who?.access_token })).body.comments || [])
  .map((one) => ({ id: one.id, handle: one.handle, parent: one.parent || null }));
const byHandle = (rows, handle) => rows.filter((row) => row?.by?.handle === handle).length;
const block = (who, handle, on) => api("/api/people?op=block", { method: "POST", token: who.access_token, body: { handle, on } });
/// A read of supabase's own REST, as a client with [key] (and [token]) may: its status.
const rest = async (pathname, { key = PUBLISHABLE, token = key, method = "GET", body } = {}) => {
  // A visitor sends the key alone, as supabase-js does; a person, their own session's token.
  const reply = await fetch(`${SUPABASE}/rest/v1/${pathname}`, { method, headers: { apikey: key,
    ...(token !== key ? { authorization: `Bearer ${token}` } : {}), ...(body ? { "content-type": "application/json" } : {}) },
  body: body ? JSON.stringify(body) : undefined });
  return { status: reply.status, text: (await reply.text()).slice(0, 160) };
};

const people = {};
const made = [];
try {
  // --- 1. before -------------------------------------------------------------
  console.log("Ada and Bob follow each other; Bob's shed; Bob and Cy on Ada's tower");
  for (const [who, handle, name] of [["ada", ADA, "Ada Block"], ["bob", BOB, "Bob Block"], ["cy", CY, "Cy Block"]]) {
    people[who] = await mintSession(emails[who]);
    const profile = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token, body: { handle, name } });
    check(`/u/${handle}: ${profile.status}`, profile.status === 200);
  }
  const { ada, bob, cy } = people;
  const follows = [await api("/api/people?op=follow", { method: "POST", token: ada.access_token, body: { handle: BOB, on: true } }),
    await api("/api/people?op=follow", { method: "POST", token: bob.access_token, body: { handle: ADA, on: true } })];
  check(`Ada follows Bob and Bob Ada: ${follows.map((one) => one.status)}`, follows.every((one) => one.status === 200 && one.body.you_follow));
  const tower = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: `Tower ${WORD}`, author: "Ada Block", model: model("Tower"), image: picture, listed: true } });
  made.push([tower.body.id, ada]);
  const shed = await api("/api/share", { method: "POST", token: bob.access_token,
    body: { name: `Shed ${WORD}`, author: "Bob Block", model: model("Shed"), image: picture, listed: true } });
  made.push([shed.body.id, bob]);
  const towerId = tower.body.id;
  const shedId = shed.body.id;
  check(`the tower /m/${towerId} and the shed /m/${shedId}`, tower.status === 201 && shed.status === 201);
  // Bob remixes the tower and puts it in a public collection of his, named
  // as he likes: both on the tower's page, for everybody, until she blocks.
  const remix = await api("/api/share", { method: "POST", token: bob.access_token, body: { name: `Bob's remix ${WORD}`,
    author: "Bob Block", model: model("Remix"), image: picture, listed: true, remixed_from: towerId } });
  made.push([remix.body.id, bob]);
  const remixId = remix.body.id;
  const bobList = await api("/api/people?op=collection", { method: "POST", token: bob.access_token,
    body: { name: `Bob says ${WORD}`, public: true } });
  const bobListId = bobList.body.id;
  const bobPut = await api("/api/people?op=collect", { method: "POST", token: bob.access_token,
    body: { collection: bobListId, model: towerId, on: true } });
  check(`Bob's remix /m/${remixId} (${remix.status}), his public collection (${bobList.status}) with the tower (${bobPut.status})`,
    remix.status === 201 && bobList.status === 200 && bobPut.status === 200 && bobPut.body.has === true);
  // The tower's page as anybody reads it, past the CDN's half a minute.
  const towerPage = async () => {
    const page = await (await fetch(`${site}/m/${towerId}?tests=1&n=${Date.now()}`, { headers })).text();
    return { remix: page.includes(`/m/${remixId}`), list: page.includes(`Bob says ${WORD}`) };
  };
  const pageBefore = await towerPage();
  check(`the tower's page names Bob's remix (${pageBefore.remix}) and his collection (${pageBefore.list})`,
    pageBefore.remix && pageBefore.list);
  // Each's first model is a level reached, told: read, so what follows is the comments'.
  for (const who of [ada, bob, cy]) await api("/api/people?op=notifications", { token: who.access_token });
  const bobSays = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
    body: { model: towerId, version: 1, body: `A fine tower, @${ADA}.` } });
  const bobComment = bobSays.body.comment?.id;
  const cyAnswers = await api("/api/people?op=reply", { method: "POST", token: cy.access_token, body: { id: bobComment, body: "I agree." } });
  const cySays = await api("/api/people?op=comment", { method: "POST", token: cy.access_token,
    body: { model: towerId, version: 1, body: "Lovely colours." } });
  check(`Bob comments (${bobSays.status}), Cy answers him (${cyAnswers.status}) and comments (${cySays.status})`,
    bobSays.status === 201 && cyAnswers.status === 201 && cySays.status === 201);
  const cyReply = cyAnswers.body.comment?.id;
  const cyComment = cySays.body.comment?.id;
  let seen = await galleryOf(ada);
  check(`Ada's gallery search has the shed and the tower: ${seen.length}`, seen.includes(shedId) && seen.includes(towerId));
  check("Ada's feed has Bob's shed", (await feedOf(ada)).some((row) => row.model === shedId));
  const adaNotices = await noticesOf(ada);
  const adaBefore = await countOf(ada);
  check(`Ada is told of Bob's comment (${byHandle(adaNotices, BOB)} of ${adaNotices.length}); her count ${adaBefore.notifications}`,
    byHandle(adaNotices, BOB) >= 1);
  // Ada's count, unread again: what she was told is read when the block page asks.
  const bobNoticesBefore = (await noticesOf(bob)).map((row) => `${row.kind}:${row.by?.handle || ""}:${row.at}`);
  const bobCountBefore = await countOf(bob);
  const bobOwnBefore = await (await fetch(`${site}/u/${BOB}?tests=1`, { headers })).text();
  const bobCommentsBefore = await commentsOn(towerId, bob);
  // Ada's notifications were read above; Bob says one more thing, unread.
  await api("/api/people?op=comment", { method: "POST", token: bob.access_token, body: { model: towerId, version: 1, body: "And a door." } });
  const adaUnread = await countOf(ada);
  check(`Ada's count says Bob's new comment: ${adaUnread.notifications}`, adaUnread.notifications >= 1);

  // --- 2. Ada blocks Bob from his profile, on a phone ------------------------
  console.log("Ada blocks Bob from his profile's More menu, at 390 x 844");
  const adaSite = await context({ as: ada });
  const adaPage = await adaSite.newPage();
  listen(adaPage, "Ada");
  // What each ask said (web/kit.js ask: its question, then its line).
  const heard = await answerAsks(adaPage);
  await adaPage.goto(`${site}/u/${BOB}?tests=1`, { waitUntil: "load" });
  await until(adaPage, () => !document.querySelector("button[data-block]")?.hidden, "Block in the More menu");
  await adaPage.click(".profile-head .more-menu summary");
  const item = await adaPage.evaluate(() => {
    const button = document.querySelector("button[data-block]");
    const box = button.getBoundingClientRect();
    return { text: button.textContent, width: box.width, height: box.height, inside: box.right <= innerWidth && box.left >= 0 };
  });
  check(`the item: "${item.text}", ${Math.round(item.width)} x ${Math.round(item.height)} px, on the screen`,
    item.text === "Block Bob Block" && item.height >= 32 && item.inside);
  await shot(adaPage, "1_profile_menu-390.png");
  await adaPage.click("button[data-block]");
  await until(adaPage, () => document.querySelector("button[data-block]")?.dataset.blocked === "yes", "Unblock drawn");
  const asked = heard.at(-1) || "";
  check(`one line asked first, saying what it does: "${asked}"`, /^Block Bob Block\? Their models leave your gallery and feed, their comments on your models are hidden, and follows between you end\. They aren’t told\.$/.test(asked));
  const after = await adaPage.evaluate(() => ({ item: document.querySelector("button[data-block]").textContent,
    follow: document.querySelector("button[data-follow]")?.textContent, said: document.querySelector(".follow-line .said")?.textContent || "" }));
  check(`then: "${after.item}", Follow "${after.follow}", "${after.said.trim()}"`,
    after.item === "Unblock Bob Block" && after.follow === "Follow" && /You blocked Bob Block\./.test(after.said));
  check("no sideways scroll at 390 px", !(await sideways(adaPage)));
  await shot(adaPage, "2_blocked-390.png");

  // --- 3. what it did ---------------------------------------------------------
  console.log("what the block did");
  const adaOnBob = (await api(`/api/people?op=follows&handle=${BOB}`, { token: ada.access_token })).body;
  const bobOnAda = (await api(`/api/people?op=follows&handle=${ADA}`, { token: bob.access_token })).body;
  check(`follows ended both ways: Ada→Bob ${adaOnBob.you_follow}, Bob→Ada ${bobOnAda.you_follow}; Ada's says you_block ${adaOnBob.you_block}`,
    adaOnBob.you_follow === false && bobOnAda.you_follow === false && adaOnBob.you_block === true);
  check(`Bob's answer never says it: you_block ${bobOnAda.you_block}`, bobOnAda.you_block === false
    && !/block/i.test(JSON.stringify({ ...bobOnAda, you_block: undefined })));
  seen = await galleryOf(ada);
  check(`Ada's gallery search: no shed, the tower kept (${seen.join(",")})`, !seen.includes(shedId) && seen.includes(towerId));
  check("Cy's and a visitor's still have the shed", (await galleryOf(cy)).includes(shedId) && (await galleryOf(null)).includes(shedId));
  const adaFeed = await feedOf(ada);
  check(`Ada's feed: nothing of Bob's (${adaFeed.length} rows)`, !adaFeed.some((row) => row.model === shedId || row.by?.handle === BOB));
  const towerFor = { ada: await commentsOn(towerId, ada), cy: await commentsOn(towerId, cy), visitor: await commentsOn(towerId, null),
    bob: await commentsOn(towerId, bob) };
  for (const who of ["ada", "cy", "visitor"]) {
    const ids = towerFor[who].map((one) => one.id);
    check(`the tower as ${who}: Bob's comments and Cy's answer hidden, Cy's comment shown (${ids.join(",")})`,
      !towerFor[who].some((one) => one.handle === BOB) && !ids.includes(cyReply) && ids.includes(cyComment));
  }
  check(`the tower as Bob: as before, his comments and Cy's answer there (${towerFor.bob.length})`,
    towerFor.bob.some((one) => one.id === bobComment) && towerFor.bob.some((one) => one.id === cyReply));
  const pageBlocked = await towerPage();
  check(`the tower's page, for everybody: Bob's remix (${pageBlocked.remix}) and collection (${pageBlocked.list}) left off`,
    !pageBlocked.remix && !pageBlocked.list);
  // Latest on Brickworks (the feed's rail, First steps): nothing of Bob's
  // for Ada, kept for her alone; Cy's has his newest.
  const latestOf = async (who) => (await api("/api/people?op=latest&mine=1&tests=1", { token: who.access_token })).body;
  const [adaLatest, cyLatest] = [await latestOf(ada), await latestOf(cy)];
  const bobsIn = (said) => [...(said.models || []).filter((one) => one.by?.handle === BOB || [shedId, remixId].includes(one.id))
    .map((one) => one.id), ...(said.designers || []).filter((one) => one.handle === BOB).map((one) => `@${one.handle}`),
  ...(said.photos || []).filter((one) => one.by?.handle === BOB).map((one) => one.id)];
  check(`Latest for Ada: nothing of Bob's (${bobsIn(adaLatest).join(",") || "none"} of ${(adaLatest.models || []).length}); `
    + `for Cy his newest (${bobsIn(cyLatest).join(",") || "none"})`, bobsIn(adaLatest).length === 0
    && (adaLatest.models || []).length > 0 && bobsIn(cyLatest).some((id) => [shedId, remixId].includes(id)));
  // The feed page asks Latest as Ada, kept for nobody; signed out, it asks
  // everybody's URL, which the CDN keeps.
  const latestAsked = async (made) => {
    const feed = await made.newPage();
    listen(feed, "the feed");
    const said = feed.waitForResponse((answer) => answer.url().includes("/api/people?op=latest"), { timeout: 60000 })
      .then((answer) => ({ url: answer.url(), cache: answer.headers()["cache-control"] || "" }))
      .catch(() => ({ url: "", cache: "" }));
    await feed.goto(`${site}/feed`, { waitUntil: "load" }).catch(() => null);
    const got = await said;
    await feed.close();
    return got;
  };
  const visitorSite = await context();
  const outLatest = await latestAsked(visitorSite);
  await visitorSite.close();
  const adaFeedLatest = await latestAsked(adaSite);
  const askedAs = (got) => `${got.url ? new URL(got.url).search : "nothing asked"} "${got.cache}"`;
  check(`the feed page's Latest, signed out: ${askedAs(outLatest)}; as Ada: ${askedAs(adaFeedLatest)}`,
    Boolean(outLatest.url) && !outLatest.url.includes("mine=1") && !outLatest.cache.includes("no-store")
    && adaFeedLatest.url.includes("mine=1") && adaFeedLatest.cache.includes("no-store"));
  const adaNoticesAfter = await noticesOf(ada);
  const adaAfter = await countOf(ada);
  check(`Ada's notifications: nothing by Bob (${adaNoticesAfter.length} rows); her count ${adaUnread.notifications} → ${adaAfter.notifications}`,
    byHandle(adaNoticesAfter, BOB) === 0 && adaAfter.notifications < adaUnread.notifications);

  // --- 4. Bob is never told ----------------------------------------------------
  console.log("Bob is never told");
  const bobNoticesAfter = (await noticesOf(bob)).map((row) => `${row.kind}:${row.by?.handle || ""}:${row.at}`);
  check(`his notifications as before (${bobNoticesAfter.length})`, JSON.stringify(bobNoticesAfter) === JSON.stringify(bobNoticesBefore));
  const bobCountAfter = await countOf(bob);
  check(`his count as before: ${bobCountBefore.notifications} → ${bobCountAfter.notifications}`,
    bobCountAfter.notifications === bobCountBefore.notifications);
  const bobOwn = await (await fetch(`${site}/u/${BOB}?tests=1`, { headers })).text();
  check("his own page: no word of a block, and as before but for the follow", !/blocked/i.test(bobOwn)
    && bobOwn.includes(`Shed ${WORD}`) === bobOwnBefore.includes(`Shed ${WORD}`));
  check("the tower's comments as Bob reads them: what he read before",
    bobCommentsBefore.every((one) => towerFor.bob.some((now) => now.id === one.id)));
  const bobFollow = await api("/api/people?op=follow", { method: "POST", token: bob.access_token, body: { handle: ADA, on: true } });
  const bobComments = await api("/api/people?op=comment", { method: "POST", token: bob.access_token,
    body: { model: towerId, version: 1, body: "Again." } });
  const bobReplies = await api("/api/people?op=reply", { method: "POST", token: bob.access_token, body: { id: cyComment, body: "Indeed." } });
  const bobLikes = await api(`/api/people?op=like&id=${towerId}`, { method: "POST", token: bob.access_token, body: { on: true } });
  const bobCollects = await api("/api/people?op=collect", { method: "POST", token: bob.access_token,
    body: { collection: bobListId, model: towerId, on: true } });
  const bobKeeps = await api("/api/people?op=keep", { method: "POST", token: bob.access_token,
    body: { list: "want", items: [`model:${towerId}`], on: true } });
  for (const [what, said, words] of [["a follow", bobFollow, "You can’t follow this profile."],
    ["a comment", bobComments, "You can’t comment on this model."], ["a reply", bobReplies, "You can’t reply to this comment."],
    ["a like", bobLikes, "You can’t like this model."], ["a collection", bobCollects, "You can’t put this model in a collection."],
    ["a list of his", bobKeeps, "You can’t put this model in a collection."]]) {
    check(`Bob refused ${what}, neutrally: ${said.status} "${said.body.error}"`, said.status === 403 && said.body.error === words);
  }
  // A new remix is refused as the publish's other refusals are (409: the
  // app answers a 403 by publishing at a new link); the one from before
  // is his, and its republish keeps its link.
  const bobRemixes = await api("/api/share", { method: "POST", token: bob.access_token, body: { name: `Bob again ${WORD}`,
    author: "Bob Block", model: model("Again"), image: picture, listed: true, remixed_from: towerId } });
  if (bobRemixes.body.id) made.push([bobRemixes.body.id, bob]);
  const bobRepublishes = await api("/api/share", { method: "POST", token: bob.access_token, body: { id: remixId,
    name: `Bob's remix ${WORD}`, author: "Bob Block", model: model("Remix, again"), image: picture, listed: true, remixed_from: towerId } });
  check(`Bob refused a remix, neutrally: ${bobRemixes.status} "${bobRemixes.body.error}"; his from before republished: `
    + `${bobRepublishes.status} ${bobRepublishes.body.remixed_from}`, bobRemixes.status === 409
    && bobRemixes.body.error === "You can’t remix this model." && [200, 201].includes(bobRepublishes.status)
    && bobRepublishes.body.id === remixId && bobRepublishes.body.remixed_from === towerId);
  const bobYou = (await api(`/api/people?op=comments&id=${towerId}&v=1`, { token: bob.access_token })).body.you || {};
  check(`the tower's box for Bob: may_write ${bobYou.may_write}, "${bobYou.why_not}"`,
    bobYou.may_write === false && bobYou.why_not === "You can’t comment on this model.");
  const adaFollow = await api("/api/people?op=follow", { method: "POST", token: ada.access_token, body: { handle: BOB, on: true } });
  const adaOnShed = await api("/api/people?op=comment", { method: "POST", token: ada.access_token,
    body: { model: shedId, version: 1, body: "Hm." } });
  const adaLikesShed = await api(`/api/people?op=like&id=${shedId}`, { method: "POST", token: ada.access_token, body: { on: true } });
  const adaList = await api("/api/people?op=collection", { method: "POST", token: ada.access_token, body: { name: `Ada keeps ${WORD}` } });
  const adaCollectsShed = await api("/api/people?op=collect", { method: "POST", token: ada.access_token,
    body: { collection: adaList.body.id, model: shedId, on: true } });
  const adaRemixesShed = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `Ada's shed ${WORD}`,
    author: "Ada Block", model: model("Ada's shed"), image: picture, listed: true, remixed_from: shedId } });
  if (adaRemixesShed.body.id) made.push([adaRemixesShed.body.id, ada]);
  check(`Ada is told plainly: ${adaFollow.status} "${adaFollow.body.error}"; on his shed ${adaOnShed.status}, its like ${adaLikesShed.status}, `
    + `a collection ${adaCollectsShed.status}, a remix ${adaRemixesShed.status}`,
    adaFollow.status === 409 && /You blocked them/.test(adaFollow.body.error || "") && adaOnShed.status === 409
      && adaLikesShed.status === 409 && /like it\.$/.test(adaLikesShed.body.error || "")
      && adaCollectsShed.status === 409 && /put it in a collection\.$/.test(adaCollectsShed.body.error || "")
      && adaRemixesShed.status === 409 && /remix it\.$/.test(adaRemixesShed.body.error || ""));
  // The @ list: Ada finds Bob no more; Bob finds Ada as anybody does (her
  // missing would tell him), and a comment of his names her not.
  const findAs = async (who, q) => ((await api(`/api/people?op=people_find&q=${encodeURIComponent(q)}&tests=1`,
    { token: who.access_token })).body.people || []).map((one) => one.handle);
  const [adaFinds, bobFinds] = [await findAs(ada, BOB), await findAs(bob, ADA)];
  check(`the @ list: Ada's has no Bob (${adaFinds.join(",") || "nobody"}), Bob's has Ada (${bobFinds.join(",")})`,
    !adaFinds.includes(BOB) && bobFinds.includes(ADA));

  // --- 5. the edges and row security ------------------------------------------
  console.log("the edges, and who can read the blocks");
  const again = await block(ada, BOB, true);
  const first = (await api("/api/people?op=blocks", { token: ada.access_token })).body.people || [];
  check(`blocked again: the same answer (${again.status}, at ${again.body.at === first[0]?.at}), one row (${first.length})`,
    again.status === 200 && again.body.blocked === true && again.body.at === first[0]?.at && first.length === 1);
  const edges = [await block(ada, ADA, true), await block(ada, `bwb-nobody-${rand}`, true),
    await api("/api/people?op=block", { method: "POST", token: ada.access_token, body: { on: true } }),
    await api("/api/people?op=block", { method: "POST", token: ada.access_token, body: { handle: BOB } }),
    await api("/api/people?op=block", { method: "POST", body: { handle: BOB, on: true } })];
  check(`yourself ${edges[0].status} "${edges[0].body.error}"`, edges[0].status === 409 && /yourself/.test(edges[0].body.error || ""));
  check(`nobody ${edges[1].status} "${edges[1].body.error}"`, edges[1].status === 404 && edges[1].body.error === "Nobody here has that handle.");
  check(`no handle ${edges[2].status}, no on ${edges[3].status}, signed out ${edges[4].status}`,
    edges[2].status === 400 && edges[3].status === 400 && edges[4].status === 401);
  check(`Bob's list of blocks: nobody (${JSON.stringify((await api("/api/people?op=blocks", { token: bob.access_token })).body.people)})`,
    ((await api("/api/people?op=blocks", { token: bob.access_token })).body.people || []).length === 0);
  if (SUPABASE && PUBLISHABLE) {
    const reads = { visitor: await rest("blocks?select=*"), bob: await rest("blocks?select=*", { token: bob.access_token }),
      cy: await rest("blocks?select=*", { token: cy.access_token }), ada: await rest("blocks?select=*", { token: ada.access_token }) };
    for (const [who, said] of Object.entries(reads)) {
      check(`the blocks table read as ${who}: ${said.status} ${said.text}`, said.status === 401 || said.status === 403 || said.status === 404
        || (said.status === 200 && said.text === "[]"));
    }
    const calls = [await rest("rpc/block_list", { token: bob.access_token, method: "POST", body: { account: ada.kept.user_id } }),
      await rest("rpc/block_between", { token: cy.access_token, method: "POST", body: { account: ada.kept.user_id, other: bob.kept.user_id } }),
      await rest("rpc/block_person", { token: bob.access_token, method: "POST", body: { account: ada.kept.user_id, wanted: BOB, blocking: false } })];
    check(`block.sql's functions refused to clients: ${calls.map((one) => one.status).join(", ")}`,
      calls.every((one) => one.status === 401 || one.status === 403 || one.status === 404));
    if (SECRET) {
      const counted = await rest("rpc/block_count_against", { key: SECRET, method: "POST", body: { p_account: bob.kept.user_id } });
      check(`the owner's count for Bob (/admin › People): ${counted.text}`, counted.status === 200 && counted.text === "1");
    }
  }

  // --- 6. Settings › Blocked people, Unblock ----------------------------------
  console.log("Settings › Blocked people at 390 x 844, and Unblock");
  await adaPage.goto(`${site}/settings`, { waitUntil: "load" });
  await until(adaPage, () => document.documentElement.dataset.settings === "ready", "Settings drawn", 45);
  const listed = await adaPage.evaluate(() => [...document.querySelectorAll("#blocked li")].map((li) => {
    const button = li.querySelector("button");
    const box = button.getBoundingClientRect();
    return { who: li.querySelector(".who")?.textContent.replace(/\s+/g, " ").trim(), href: li.querySelector("a.who")?.getAttribute("href"),
      button: button.textContent, height: box.height, inside: box.right <= innerWidth };
  }));
  check(`listed: ${JSON.stringify(listed)}`, listed.length === 1 && listed[0].who.includes("Bob Block") && listed[0].who.includes(`@${BOB}`)
    && listed[0].button === "Unblock" && listed[0].height >= 44 && listed[0].inside);
  check("no sideways scroll at 390 px", !(await sideways(adaPage)));
  await adaPage.locator("#blocked-part").scrollIntoViewIfNeeded();
  await shot(adaPage, "3_settings_blocked-390.png");
  await adaPage.click("#blocked li button");
  await until(adaPage, () => document.querySelectorAll("#blocked li").length === 0 && /^Nobody\./.test(document.getElementById("blocked-said").textContent),
    "the list empty");
  const done = await adaPage.evaluate(() => document.getElementById("blocked-done").textContent);
  check(`unblocked: "${done}"`, done === "You unblocked Bob Block: their models and comments are back. Follows between you aren’t.");
  await shot(adaPage, "4_settings_unblocked-390.png");
  seen = await galleryOf(ada);
  check("Ada's gallery search has the shed again", seen.includes(shedId));
  const backFor = await commentsOn(towerId, cy);
  check("the tower shows Bob's comment and Cy's answer again", backFor.some((one) => one.id === bobComment) && backFor.some((one) => one.id === cyReply));
  const pageBack = await towerPage();
  check(`the tower's page names Bob's remix (${pageBack.remix}) and collection (${pageBack.list}) again`, pageBack.remix && pageBack.list);
  const notBack = [(await api(`/api/people?op=follows&handle=${BOB}`, { token: ada.access_token })).body,
    (await api(`/api/people?op=follows&handle=${ADA}`, { token: bob.access_token })).body];
  check(`the follows not back: ${notBack.map((one) => one.you_follow)}`, notBack.every((one) => one.you_follow === false));

  // --- 7. from a comment's row ------------------------------------------------
  console.log("blocked again from Bob's comment on the tower");
  heard.length = 0;
  // The comments are a tab of their own since pagekit (3cfdbeabe, 11-23),
  // hidden until chosen: opened at it, as a person's link to them is.
  await adaPage.goto(`${site}/m/${towerId}#comments`, { waitUntil: "load" });
  const blockButton = `#comment-${bobComment} button[data-block-comment="${BOB}"]`;
  await until(adaPage, (selector) => Boolean(document.querySelector(selector)), "Block on Bob's comment", 45, blockButton);
  const row = await adaPage.evaluate((selector) => {
    const button = document.querySelector(selector);
    button.scrollIntoView({ block: "center" });
    const box = button.getBoundingClientRect();
    // A hidden button's box is all 0, inside any window: drawn means a size.
    return { label: button.getAttribute("aria-label"), text: button.textContent,
      inside: box.width > 0 && box.height > 0 && box.right <= innerWidth && box.left >= 0 && box.top >= 0 && box.bottom <= innerHeight };
  }, blockButton);
  check(`the row's "${row.text}" (${row.label}), on the screen`, row.text === "Block" && row.label === "Block Bob Block" && row.inside);
  await shot(adaPage, "5_comment_row-390.png");
  await adaPage.click(blockButton);
  await until(adaPage, (id) => !document.getElementById(`comment-${id}`), "Bob's comment gone from the page", 30, bobComment);
  check(`asked first: "${(heard.at(-1) || "").slice(0, 40)}…"`, (heard.at(-1) || "").startsWith("Block Bob Block? "));
  check("Cy's comment still on the page", await adaPage.evaluate((id) => Boolean(document.getElementById(`comment-${id}`)), cyComment));
  await shot(adaPage, "6_comment_blocked-390.png");
  const ended = await block(ada, BOB, false);
  check(`unblocked to end: ${ended.status} blocked ${ended.body.blocked}`, ended.status === 200 && ended.body.blocked === false);
  await adaSite.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const [id, who] of made) {
    if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "block: hidden from the one who blocked, never told, refused neutrally, undone in Settings");
process.exit(failed ? 1 : 0);
