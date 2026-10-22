// Following a person, the feed, and the count on Account, in real
// browsers: a follow from a profile, the followed designer's new model and
// new version in the feed, a comment and a photo on your own model there
// and counted on Account (the site's header and the app's) until the feed
// is opened, an account under 13 refused, counts but never lists of
// followers, and the day's email telling of the feed in a dry run.
//
//   tools/export.sh web
//   node --env-file=.env tools/web/relay_server.mjs 9240 --static=build/web &
//   node --env-file=.env tools/web/follows_flow.mjs --url=http://127.0.0.1:9240 --out=shots/follows
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/follows_flow.mjs --url=<preview> --out=DIR
//
// follows.sql is applied (rel-m82), so a relay with no --hold and no stand-in
// is a preview's every table, the live project's. The relay can still hold
// the file in memory (tools/web/follows_stand_in.mjs), with comments.sql's
// functions beside it (comments_stand_in.mjs, whose day's email asks it for
// the feed) and the photos' table and buckets (held_tables.mjs), standing in
// for trust.sql (--hold=follows,model_comments,build_photos,report_photos
// --trust-stand-in): the flow sees which (/__held/follows answers) and reads
// each its own way. The day's email is read back as the project kept it,
// through comment_digest_kept with the secret key, from the id the API
// answered Ada's comment with: no key may read comment_digests directly.
// Throwaway accounts at Resend test addresses, deleted at the end with
// their models: Ada designs, Bob follows her, Cy is under 13. --site leaves
// out the app (no export needed).
//
//   1. Ada and Bob make profiles; Bob shares a barn and chooses the day's
//      email of comments, new models, new versions and photos.
//   2. Bob follows Ada from her profile: Follow becomes Following, her
//      count 1 follower; nobody's page or answer lists who follows her.
//   3. Ada shares a castle in the gallery, then its version 2: both are in
//      Bob's /feed, each a link to the thing, newest first. Opened.
//   4. Ada posts a photo of her build of Bob's barn and comments on it:
//      Account says 2 on the site (and on Menu at 390 px) and in the app,
//      and leads to /feed; opened there, both marked new, the count gone.
//      The comment sent Bob's day's email, a dry run, telling of the
//      comment and of the feed: the castle, its version 2 and the photo.
//   5. A model's page: Follow beside its designer, Following for Bob.
//   6. Cy, under 13, is told why not on Ada's profile, and refused (422).
//   7. Bob chooses to show whom he follows: his profile lists Ada; hers
//      still says only how many follow her.
//
// Pictures in --out.
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
const site = String(args.url || "http://127.0.0.1:9240").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/follows"));
mkdirSync(out, { recursive: true });
const withApp = !args.site;
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
// A local relay holding follows.sql in memory answers /__held/follows; a
// preview, or a relay on the live project, does not. Only a held relay is
// knocked (its stand-ins claim nothing real), and only it answers ages.
const held = await fetch(`${site}/__held/follows`, { headers }).then((reply) => reply.ok).catch(() => false);
if (held) process.env.BW_STAND_IN = process.env.BW_STAND_IN || site;
const { encode } = await import(path.join(root, "api/_jpeg.js"));
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-follows-ada-${rand}@resend.dev`;
const bobEmail = `delivered+bw-follows-bob-${rand}@resend.dev`;
const cyEmail = `delivered+bw-follows-cy-${rand}@resend.dev`;
const ADA = `bwf-ada-${rand}`;
const BOB = `bwf-bob-${rand}`;
const UNDER_13 = "Following people is for people 13 and over, because a follow is counted in public. "
  + "Building, your models and sharing by link are all yours.";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: follows.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // follows flow ${rand} ${name}\r\n`;

// A small photo of a build, as a phone would send one.
function photo() {
  const width = 320;
  const height = 240;
  const data = Buffer.alloc(width * height * 4);
  for (let at = 0; at < data.length; at += 4) {
    const x = (at / 4) % width;
    const red = x > 80 && x < 240;
    data[at] = red ? 200 : 40; data[at + 1] = red ? 24 : 90; data[at + 2] = red ? 32 : 160; data[at + 3] = 255;
  }
  return encode({ width, height, data }, 85).data;
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, phone = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
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

const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
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

/// [owner]'s day's emails: what a held relay keeps (comments_stand_in.mjs),
/// or, on the live project, each one the API said it told ([ids]), as the
/// project kept it (comment_digest_kept, with the secret key). Its tables
/// are the server's alone: not even the secret key reads comment_digests.
async function digestsOf(owner, ids) {
  if (held) {
    const rows = await (await fetch(`${site}/__held/comment_digests`, { headers })).json().catch(() => []);
    return (Array.isArray(rows) ? rows : []).filter((one) => one.owner === owner);
  }
  const kept = [];
  for (const one of ids.filter(Boolean)) {
    const reply = await fetch(`${SUPABASE}/rest/v1/rpc/comment_digest_kept`, { method: "POST",
      headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
      body: JSON.stringify({ one }) }).catch(() => null);
    const row = reply && reply.ok ? await reply.json().catch(() => null) : null;
    if (row && row.owner === owner) kept.push(row);
  }
  return kept;
}

/// What a profile's page, as served, says of its followers: "1 follower".
/// A designer's page draws it as a tile, its number apart from its word
/// (api/people.js earnedHtml), so it is read as a person reads it.
const followersOn = (html) => (/data-followers[^>]*>([\s\S]*?)<\/(?:li|span)>/.exec(html)?.[1] || "")
  .replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
/// One of a profile's numbers as served (api/people.js numbersHtml): "1 following".
const statOn = (html, kind) => (new RegExp(`<li data-stat="${kind}"[^>]*>([\\s\\S]*?)</li>`).exec(html)?.[1] || "")
  .replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
/// Whom a profile's page lists under Follows, as served: the handles.
const followsListed = (html) => {
  const section = /<section[^>]*aria-labelledby="follows-h"[^>]*>([\s\S]*?)<\/section>/.exec(html)?.[1] || "";
  return [...section.matchAll(/href="\/u\/([a-z0-9-]+)"/g)].map((one) => one[1]);
};

/// The Follow button on the page, as drawn: {shown, text, pressed, said, followers}.
const followDrawn = (page) => page.evaluate(() => {
  const button = document.querySelector("button[data-follow]");
  return { shown: Boolean(button && !button.hidden), text: button?.textContent || "",
    pressed: button?.getAttribute("aria-pressed") || "",
    said: (button?.parentElement?.querySelector(".said")?.textContent || "").trim(),
    followers: document.querySelector("[data-followers]")?.textContent || "" };
});

/// The header's Account, as drawn: its count and where it leads, on the nav
/// and behind Menu.
const accountDrawn = (page) => page.evaluate(() => {
  const nav = document.querySelector(".site-head .nav a[data-account]");
  const menu = document.querySelector(".site-head .menu summary");
  return { href: nav?.getAttribute("href") || "", count: nav?.querySelector(".count")?.textContent || "",
    visible: Boolean(nav && nav.offsetParent), menu: menu?.querySelector(".count")?.textContent || "" };
});

/// The feed as drawn: [{kind, text, href, new}].
const feedDrawn = (page) => page.evaluate(() => [...document.querySelectorAll("#rows .feed-row")].map((li) => ({
  kind: li.dataset.kind, text: li.textContent.replace(/\s+/g, " ").trim(),
  href: li.querySelector("a")?.getAttribute("href") || "", new: li.classList.contains("new") })));

let ada = null;
let bob = null;
let cy = null;
const made = [];
try {
  // --- 1. two profiles, and Bob's barn ------------------------------------
  console.log("two builders, and Bob's barn");
  ada = await mintSession(adaEmail);
  bob = await mintSession(bobEmail);
  cy = await mintSession(cyEmail, { age: false });
  await answerAge(cy.kept.user_id, cyEmail, false);
  const adaProfile = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Follows" } });
  const bobProfile = await api("/api/people?op=profile", { method: "POST", token: bob.access_token,
    body: { handle: BOB, name: "Bob Follows" } });
  check(`profiles made: /u/${ADA} ${adaProfile.status}, /u/${BOB} ${bobProfile.status}`,
    adaProfile.status === 200 && bobProfile.status === 200);
  const barn = await api("/api/share", { method: "POST", token: bob.access_token,
    body: { name: "Follows Flow Barn", author: "Bob Follows", model: model("Follows Flow Barn"), image: picture, listed: true } });
  made.push([barn.body.id, bob]);
  check(`Bob's barn in the gallery: ${barn.status} /m/${barn.body.id}`, barn.status === 201 && Boolean(barn.body.id));
  const mail = await api("/api/people?op=mail", { method: "POST", token: bob.access_token,
    body: { comments: true, models: true, versions: true, photos: true } });
  check(`Bob chooses the day's email of comments, models, versions and photos, remixes left off: ${JSON.stringify(mail.body)}`,
    mail.status === 200 && mail.body.comments && mail.body.models && mail.body.versions && mail.body.photos
      && mail.body.remixes === false);
  const me = await api("/api/people?op=me", { token: bob.access_token });
  check("...and /profile reads them back, with whom he follows not shown",
    me.body.mail?.photos === true && me.body.mail?.kinds === true && me.body.follows?.shows_follows === false);

  // --- 2. Bob follows Ada from her profile --------------------------------
  console.log("Bob follows Ada from her profile");
  const bobSite = await context({ as: bob });
  const bobPage = await bobSite.newPage();
  listen(bobPage, "Bob");
  await bobPage.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
  await until(bobPage, () => !document.querySelector("button[data-follow]")?.hidden, "Ada's Follow");
  let drawn = await followDrawn(bobPage);
  check(`her profile: "${drawn.text}", "${drawn.followers}"`, drawn.text === "Follow" && drawn.followers === "0 followers");
  await bobPage.click("button[data-follow]");
  await until(bobPage, () => document.querySelector("button[data-follow]")?.textContent === "Following", "Following");
  drawn = await followDrawn(bobPage);
  check(`pressed: "${drawn.text}" (pressed ${drawn.pressed}), "${drawn.followers}", "${drawn.said}"`,
    drawn.text === "Following" && drawn.pressed === "true" && drawn.followers === "1 follower"
      && /in your feed/.test(drawn.said));
  await shot(bobPage, "1_follow.png");
  const asVisitor = await api(`/api/people?op=follows&handle=${ADA}`);
  const asBob = await api(`/api/people?op=follows&handle=${ADA}`, { token: bob.access_token });
  check(`counts only: a visitor sees ${asVisitor.body.followers} follower and no names (${Object.keys(asVisitor.body).join(",")})`,
    asVisitor.body.followers === 1 && asVisitor.body.you_follow === false && !JSON.stringify(asVisitor.body).includes(BOB));
  check(`Bob sees he follows her: ${asBob.body.you_follow}`, asBob.body.you_follow === true);
  const herPage = await (await fetch(`${site}/u/${ADA}?tests=1`, { headers })).text();
  check("her page counts him and never names him", followersOn(herPage) === "1 follower" && !herPage.includes(BOB)
    && !herPage.includes("Bob Follows"));
  const herList = await api(`/api/people?op=following&handle=${ADA}`);
  check(`whom she follows: nothing shown (${JSON.stringify(herList.body.following)})`,
    herList.status === 200 && herList.body.following.length === 0);
  const self = await api("/api/people?op=follow", { method: "POST", token: bob.access_token, body: { handle: BOB, on: true } });
  check(`Bob following himself: ${self.status} "${self.body.error}"`, self.status === 409);

  // --- 3. Ada's castle, and its version 2, in Bob's feed -------------------
  console.log("Ada shares a castle, then its version 2");
  const castle = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { name: "Follows Flow Castle", author: "Ada Follows", model: model("Follows Flow Castle"), image: picture, listed: true } });
  const castleId = castle.body.id;
  made.push([castleId, ada]);
  await new Promise((done) => setTimeout(done, 1200));
  const two = await api("/api/share", { method: "POST", token: ada.access_token,
    body: { id: castleId, name: "Follows Flow Castle", author: "Ada Follows", note: "A taller tower",
      model: model("Follows Flow Castle").replace("3003.dat", "3001.dat"), image: picture, listed: true } });
  check(`the castle at /m/${castleId}, then its version ${two.body.version}`, castle.status === 201 && two.body.version === 2);
  await bobPage.goto(`${site}/feed`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.feed === "ready", "Bob's feed");
  let rows = await feedDrawn(bobPage);
  check(`Bob's feed, newest first: ${rows.map((one) => one.kind).join(", ")}`,
    rows.length >= 2 && rows[0].kind === "version" && rows[1].kind === "model");
  check(`"${rows[0]?.text}" links to ${rows[0]?.href}`, /Ada Follows shared version 2 of “Follows Flow Castle”/.test(rows[0]?.text)
    && /A taller tower/.test(rows[0]?.text) && rows[0]?.href === `/m/${castleId}/v/2`);
  check(`"${rows[1]?.text}" links to ${rows[1]?.href}`, /Ada Follows shared a new model “Follows Flow Castle”/.test(rows[1]?.text)
    && rows[1]?.href === `/m/${castleId}`);
  check("both new to him", rows[0]?.new && rows[1]?.new);
  await shot(bobPage, "2_feed.png", true);
  await bobPage.click(`#rows a[href="/m/${castleId}"]`);
  await bobPage.waitForURL(`**/m/${castleId}`, { timeout: 20000 });
  check(`a row is a link: it opened ${new URL(bobPage.url()).pathname}`, new URL(bobPage.url()).pathname === `/m/${castleId}`);

  // --- 5. Follow beside the designer on a model's page --------------------
  console.log("a model's page");
  await until(bobPage, () => !document.querySelector(".shared-by button[data-follow]")?.hidden, "Follow beside her name");
  drawn = await followDrawn(bobPage);
  check(`beside "Shared by Ada Follows": "${drawn.text}" for Bob`, drawn.text === "Following");
  const visitor = await context();
  const visitorPage = await visitor.newPage();
  listen(visitorPage, "visitor");
  await visitorPage.goto(`${site}/m/${castleId}`, { waitUntil: "load" });
  await until(visitorPage, () => !document.querySelector(".shared-by button[data-follow]")?.hidden, "the visitor's Follow");
  check(`a visitor sees "${(await followDrawn(visitorPage)).text}"`, (await followDrawn(visitorPage)).text === "Follow");
  await visitorPage.click(".shared-by button[data-follow]");
  const asked = await visitorPage.waitForSelector("dialog.sign-in[open]", { timeout: 10000 }).then(() => true).catch(() => false);
  check("...which asks a visitor to sign in first", asked);
  await shot(visitorPage, "3_model_follow.png");
  check("the visitor's page has no Account count", (await accountDrawn(visitorPage)).count === "");

  // --- 4. a photo and a comment on Bob's barn: the count ------------------
  console.log("Ada posts a photo of Bob's barn, and comments on it");
  const jpeg = photo();
  const start = await api("/api/people?op=photo_start", { method: "POST", token: ada.access_token,
    body: { model: barn.body.id, type: "image/jpeg", size: jpeg.length } });
  if (start.status === 200) await fetch(start.body.upload, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: jpeg });
  const kept = await api("/api/people?op=photo", { method: "POST", token: ada.access_token,
    body: { model: barn.body.id, ticket: start.body.ticket, words: "Built the barn on a rainy Sunday" } });
  check(`her photo kept: ${start.status}, ${kept.status} ${kept.body.id}`, start.status === 200 && kept.status === 201);
  const comment = await api("/api/people?op=comment", { method: "POST", token: ada.access_token,
    body: { model: barn.body.id, version: 1, body: "The barn door swings both ways. Lovely." } });
  check(`her comment: ${comment.status}, and Bob told at once, a dry run (${JSON.stringify(comment.body.told)})`,
    comment.status === 201 && comment.body.told?.state === "dry" && Boolean(comment.body.told?.id));
  const counted = await api("/api/people?op=feed_count", { token: bob.access_token });
  check(`Bob's count, since he opened the feed: ${counted.body.count}`, counted.body.count === 2);
  await bobPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(bobPage, () => document.querySelector(".site-head .nav a[data-account] .count"), "Account's count");
  let account = await accountDrawn(bobPage);
  check(`the site's header: Account ${account.count}, leading to ${account.href}`, account.count === "2" && account.href === "/feed");
  await shot(bobPage, "4_account_count.png");
  const bobPhone = await context({ as: bob, width: 390, height: 844, phone: true });
  const phonePage = await bobPhone.newPage();
  listen(phonePage, "Bob's phone");
  await phonePage.goto(`${site}/gallery`, { waitUntil: "load" });
  await until(phonePage, () => document.querySelector(".site-head .menu summary .count"), "Menu's count");
  account = await accountDrawn(phonePage);
  check(`at 390 px, Menu carries it: ${account.menu}, and nothing sideways`, account.menu === "2" && !(await sideways(phonePage)));
  await phonePage.click(".site-head .menu summary");
  await shot(phonePage, "5_account_count-phone.png");

  if (withApp) await theApp("before", 2);

  await bobPage.click(".site-head .nav a[data-account]");
  await bobPage.waitForURL("**/feed", { timeout: 20000 });
  await until(bobPage, () => document.documentElement.dataset.feed === "ready", "the feed again");
  rows = await feedDrawn(bobPage);
  const fresh = rows.filter((one) => one.new).map((one) => one.kind);
  check(`opened from Account: new are ${fresh.join(", ")}`, fresh.length === 2 && fresh.includes("comment") && fresh.includes("photo"));
  const photoRow = rows.find((one) => one.kind === "photo");
  const commentRow = rows.find((one) => one.kind === "comment");
  check(`"${photoRow?.text}" → ${photoRow?.href}`, /Ada Follows posted a photo of their build of your model “Follows Flow Barn”/.test(photoRow?.text || "")
    && /rainy Sunday/.test(photoRow?.text || "") && photoRow?.href === `/m/${barn.body.id}#photo-${kept.body.id}`);
  check(`"${commentRow?.text}" → ${commentRow?.href}`, /Ada Follows commented on your model “Follows Flow Barn”/.test(commentRow?.text || "")
    && /swings both ways/.test(commentRow?.text || "") && new RegExp(`^/m/${barn.body.id}#comment-\\d+$`).test(commentRow?.href || ""));
  check("the older two are not new now", rows.filter((one) => !one.new).length === 2);
  account = await accountDrawn(bobPage);
  check(`on /feed, Account has no count (${account.count || "none"})`, account.count === "");
  await shot(bobPage, "6_feed_opened.png", true);
  const cleared = await api("/api/people?op=feed_count", { token: bob.access_token });
  check(`the count cleared: ${cleared.body.count}`, cleared.body.count === 0);
  // Older, as the page asks for it: strictly before the last row shown,
  // at that row's own time to the microsecond.
  const whole = (await api("/api/people?op=feed", { token: bob.access_token })).body.rows || [];
  const older = await api(`/api/people?op=feed&before=${encodeURIComponent(whole[1]?.at || "")}`, { token: bob.access_token });
  check(`older than the second row: ${(older.body.rows || []).map((one) => one.kind).join(", ")}`,
    whole.length === 4 && JSON.stringify((older.body.rows || []).map((one) => one.link)) === JSON.stringify(whole.slice(2).map((one) => one.link)));
  const badly = await api("/api/people?op=feed&before=yesterday", { token: bob.access_token });
  check(`a time that is not one: ${badly.status}`, badly.status === 400);
  await bobPage.goto(`${site}/gallery`, { waitUntil: "load" });
  await bobPage.waitForTimeout(1500);
  account = await accountDrawn(bobPage);
  check(`back in the gallery: Account ${account.count || "with no count"}, to ${account.href}`, account.count === "" && account.href === "/profile");
  if (withApp) await theApp("after", 0);

  // The day's email: Ada's comment sent it (the first after a quiet day),
  // a dry run for a test account, telling of the comment and of the feed.
  const mine = await digestsOf(bob.kept.user_id, [comment.body.told?.id]);
  const dry = mine.find((one) => one.state === "dry");
  check(`Bob's day's email: ${mine.length} kept, ${dry?.state}, ${dry?.comments} comment and the feed's: "${dry?.subject}"`,
    mine.length === 1 && dry && dry.comments === 1
      && dry.subject === "Brickworks: 1 comment on your models, and 3 new things in your feed");
  const body = String(dry?.body || "");
  check("...saying the comment, and the castle, its version 2 and the photo, each with its link",
    /The barn door swings both ways/.test(body) && /In your feed since the last email:/.test(body)
      && body.includes(`Ada Follows shared a new model “Follows Flow Castle”`) && body.includes(`/m/${castleId}\n`)
      && body.includes(`Ada Follows shared version 2 of “Follows Flow Castle”: “A taller tower”`) && body.includes(`/m/${castleId}/v/2`)
      && body.includes("Ada Follows posted a photo of their build of your model “Follows Flow Barn”")
      && body.includes(`#photo-${kept.body.id}`));
  // Never knocked but where nothing real can be claimed: on the live
  // project the knock sends every owner's real email that is due.
  if (held) {
    const knock = await api("/api/people?op=digest", { method: "POST" });
    const after = await digestsOf(bob.kept.user_id, []);
    check(`the hourly knock sends no second that day (${after.length} kept)`, knock.status === 200 && after.length === 1);
  }

  // --- 6. under 13 ---------------------------------------------------------
  console.log("an account under 13");
  const cySite = await context({ as: cy });
  const cyPage = await cySite.newPage();
  listen(cyPage, "Cy");
  await cyPage.goto(`${site}/u/${ADA}?tests=1`, { waitUntil: "load" });
  await until(cyPage, () => !document.querySelector("button[data-follow]")?.hidden, "Cy's Follow");
  await cyPage.click("button[data-follow]");
  await until(cyPage, () => /13 and over/.test(document.querySelector(".follow-line .said")?.textContent || ""), "Cy told why not");
  drawn = await followDrawn(cyPage);
  check(`Cy is told: "${drawn.said}"`, drawn.said === UNDER_13 && drawn.text === "Follow");
  await shot(cyPage, "7_under_13.png");
  const cyFollow = await api("/api/people?op=follow", { method: "POST", token: cy.access_token, body: { handle: ADA, on: true } });
  check(`...and the server refuses: ${cyFollow.status}`, cyFollow.status === 422 && cyFollow.body.error === UNDER_13);
  const still = await api(`/api/people?op=follows&handle=${ADA}`);
  check(`Ada still has ${still.body.followers} follower`, still.body.followers === 1);

  // --- 7. whom Bob follows, shown by his choice ---------------------------
  console.log("Bob shows whom he follows");
  let bobsPage = await (await fetch(`${site}/u/${BOB}?tests=1`, { headers })).text();
  // Ada is on his page as the builder of his barn (Built by others), which
  // is not whom he follows: only the Follows list says that.
  check("his profile does not list whom he follows, until he chooses", followsListed(bobsPage).length === 0
    && !bobsPage.includes('id="follows-h"') && statOn(bobsPage, "following") === "1 following");
  await bobPage.goto(`${site}/profile`, { waitUntil: "load" });
  await until(bobPage, () => document.documentElement.dataset.profile === "ready", "Bob's /profile");
  const boxes = await bobPage.evaluate(() => ({
    kinds: [...document.querySelectorAll("#mail-kinds input[data-kind]")].map((box) => `${box.dataset.kind}:${box.checked}`),
    shown: !document.getElementById("mail-kinds").hidden, follows: !document.getElementById("follows-choice").hidden,
    feed: document.getElementById("to-feed")?.getAttribute("href") }));
  check(`/profile: the feed's kinds ${boxes.kinds.join(" ")}, a way to the feed (${boxes.feed})`, boxes.shown && boxes.follows
    && boxes.kinds.join(" ") === "models:true versions:true photos:true remixes:false" && boxes.feed === "/feed");
  await bobPage.check("#shows-follows");
  await until(bobPage, () => /Shown/.test(document.getElementById("follows-said")?.textContent || ""), "shown");
  await shot(bobPage, "8_profile_choices.png", true);
  bobsPage = await (await fetch(`${site}/u/${BOB}?tests=1`, { headers })).text();
  check("chosen: his profile lists Ada under Follows", followsListed(bobsPage).join(",") === ADA && bobsPage.includes("Ada Follows"));
  const herNow = await (await fetch(`${site}/u/${ADA}?tests=1`, { headers })).text();
  check("hers still only counts him", followersOn(herNow) === "1 follower" && !herNow.includes(BOB));
  const bobList = await api(`/api/people?op=following&handle=${BOB}`);
  check(`whom Bob follows, asked: ${bobList.body.following.map((one) => one.handle).join(", ")}`,
    bobList.body.following.length === 1 && bobList.body.following[0].handle === ADA);
  const unfollow = await api("/api/people?op=follow", { method: "POST", token: bob.access_token, body: { handle: ADA, on: false } });
  check(`letting her go: ${unfollow.body.followers} followers, following ${unfollow.body.you_follow}`,
    unfollow.status === 200 && unfollow.body.followers === 0 && unfollow.body.you_follow === false);
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const [id, who] of made) {
    if (id && who) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: who.access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of [adaEmail, bobEmail, cyEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "follows: a follow, the feed, the count on Account, under 13, and counts not lists");
process.exit(failed ? 1 : 0);

// --- the app ---------------------------------------------------------------

/// Bob in the app: Account says the count, on a phone and on a laptop, and
/// its panel says it too, with Open your feed. Declared, not assigned: the
/// flow above runs before this part of the module would be reached.
async function theApp(when, count) {
  console.log(`the app, ${when} the feed is opened`);
  const sizes = when === "before" ? [[390, 844, true], [1280, 900, false]] : [[1280, 900, false]];
  for (const [width, height, phone] of sizes) {
    const app = await context({ as: await mintSession(bobEmail), width, height, phone });
    const page = await app.newPage();
    listen(page, `Bob in the app (${when}, ${width} px)`);
    await page.goto(`${site}/app`, { waitUntil: "domcontentloaded", timeout: 180000 });
    const feed = await until(page, (wanted) => {
      const said = (window.brickworksState || {}).feed;
      return said && said.count === wanted && said.account && said.panel ? said : null;
    }, `the app's Account (${count}, ${width} px)`, 300, count);
    check(`at ${width} px the app's Account says "${feed.account}"`,
      count ? feed.account === `Account · ${count}` : feed.account === "Account");
    if (phone) {
      await shot(page, "9_app_account-phone.png");
      await app.close();
      continue;
    }
    // Account opened, as a person opens it: its panel says the count, and
    // leads to the feed.
    const at = await until(page, () => (window.brickworksControls || {}).account, "the app's Account button", 60);
    await page.mouse.click(at.x, at.y);
    const link = await until(page, () => (window.brickworksControls || {}).account_feed, "Open your feed", 30);
    const panel = (await page.evaluate(() => (window.brickworksState || {}).feed)).panel;
    check(`...its panel: "${panel}", with Open your feed`, Boolean(link) && (count
      ? panel === `${count} new in your feed since you last opened it.` : panel === "Nothing new in your feed."));
    await shot(page, `${when === "before" ? "10" : "11"}_app_account_panel.png`);
    await app.close();
  }
}
