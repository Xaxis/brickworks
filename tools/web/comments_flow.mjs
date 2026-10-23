// Comments on a shared model and on a single step, in real browsers: who
// may write, what each comment says of where it was said, the owner's
// hide and off, a report reaching the admin page, the owner told once a
// day by a dry run, and the step's comments in the step player on a phone.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9040 --static=build/web --hold=model_comments --trust-stand-in &
//   BW_STAND_IN=http://127.0.0.1:9040 node tools/web/comments_flow.mjs --url=http://127.0.0.1:9040 --out=shots/comments
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/comments_flow.mjs --url=<preview> --out=DIR   # once comments.sql is applied
//
// Until supabase/comments.sql (and trust.sql, which it needs) are applied
// to the project, the local relay holds them in memory
// (tools/web/comments_stand_in.mjs, tools/web/trust_stand_in.mjs) and
// sends everything else to the real project. Throwaway accounts at Resend
// test addresses, deleted at the end with their models: an owner, a
// builder 13 or over, one under 13, and a visitor with no account. --site
// leaves out the app (no export needed).
//
//   1. The owner publishes a six-step tower, then version 2 with step 3
//      changed, and asks to be emailed of comments.
//   2. The builder, on the model's page: a comment on the model, and one on
//      step 4 picked from the step list. Each says where ("on version 2",
//      "on step 4 of version 2"). The owner's email of them is a dry run,
//      once: the second comment that day waits. One on step 2 of version
//      1 says it is on an older version, and is on step 2 of version 2
//      (that step did not change); one on step 5 of version 1 is not.
//   3. A visitor with no account reads them all, has no box, and is told
//      to sign in, politely; the API refuses a comment without one (401).
//   4. An account under 13 reads them and is told why it cannot add one
//      (422 from the API, in the same words).
//   5. The owner hides one: gone for the visitor, marked for the owner;
//      turns comments off: the builder is refused (409); and on again.
//   6. The visitor reports a comment from its Report it; the site's owner
//      (MASTER_EMAIL) sees it on the admin page with its words, removes
//      it there, and it is gone from the model's page.
//   7. The app, at 390 x 844: the viewer and the step player show step
//      4's count; tapped, its comments; the builder adds one there and the
//      count goes up; a visitor with no account and the account under 13
//      read them and are told why they cannot write.
//
// And replies (docs/SOCIAL.md U8, supabase/replies.sql), once the
// deployment keeps them (the list says replies: true; before, nobody is
// offered Reply and the API says replies are not open yet). The page puts
// the newest thread first, each with its writer's avatar and its step as a
// pill into the viewer at that step; the box is shown to a visitor too, and
// sending asks them to sign in, keeping what they typed. In 5 the owner
// replies to the step comment from its Reply: under it, marked Designer;
// the builder is told in Notifications ("replied to your comment"), with
// the model's picture, and opening the group reads it; an account under 13
// is refused a reply in the comment's words. The owner hides the step
// comment: its reply goes with it, for a visitor and from the builder's
// notifications; shown again, both are back. In 6 a visitor may report a
// reply, and the comment the site's owner removes takes its reply with it.
//
// Locally the relay holds replies.sql (--hold=replies,
// tools/web/replies_stand_in.mjs):
//
//   node --env-file=.env tools/web/relay_server.mjs 8830 --hold=replies &
//   node --env-file=.env tools/web/comments_flow.mjs --url=http://127.0.0.1:8830 --site --out=DIR
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:9040").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/comments"));
mkdirSync(out, { recursive: true });
const withApp = !args.site;
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const NAME = "Comments Flow Tower";
const rand = randomBytes(4).toString("hex");
const ownerEmail = `delivered+bw-comments-owner-${rand}@resend.dev`;
const writerEmail = `delivered+bw-comments-writer-${rand}@resend.dev`;
const youngEmail = `delivered+bw-comments-young-${rand}@resend.dev`;
const ON_MODEL = "What a tidy tower: thank you for sharing it.";
const ON_STEP = "On step 4 this part goes under, not over. See https://example.com/tip";
const ON_OLD = "Step 2 is easier with the bricks sorted first.";
const ON_GONE = "Step 5 of the first version wobbled for me.";
const FROM_APP = "Built to step 4 on my phone: it holds.";
const REPLY_OWNER = "Thank you: I will say so on step 4's page.";
const FROM_VISITOR = "Lovely tower: which bricks are these?";
const SIGN_IN = "Sign in to add a comment: we email you a code, no password. Anyone can read them.";
const UNDER_13 = "Comments are for people 13 and over, so you can read them here but not add one. "
  + "Building, your models and sharing by link are all yours.";

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

// --- the model: six steps of two bricks, its steps carried ----------------

function tower(blue) {
  const lines = [`0 ${NAME}`, "0 Name: comments_tower.ldr", "0 Author: Comments Flow", ""];
  for (let step = 1; step <= 6; step += 1) {
    const colour = blue && step === 3 ? 1 : 4;
    lines.push(`1 ${colour} 0 ${-24 * step} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push(`1 ${colour} 80 ${-24 * step} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  }
  return `${lines.join("\r\n")}\r\n0 // comments flow ${rand}\r\n`;
}
const models = path.join(out, "models");
mkdirSync(models, { recursive: true });
const files = [];
for (const [n, blue] of [[1, false], [2, true]]) {
  writeFileSync(path.join(models, `v${n}_bare.ldr`), tower(blue));
  files.push(path.join(models, `v${n}_bare.ldr`), path.join(models, `v${n}.ldr`));
}
const made = spawnSync("godot", ["--headless", "--path", root, "--script", "src/dev/share_pages_probe.gd",
  "--", "--write", ...files], { encoding: "utf8", timeout: 600000,
  env: { ...process.env, XDG_DATA_HOME: process.env.XDG_DATA_HOME || path.join(root, ".scratch-data") } });
const v1 = readFileSync(path.join(models, "v1.ldr"), "utf8");
const v2 = readFileSync(path.join(models, "v2.ldr"), "utf8");
if (!v1.includes("0 !BRICKWORKS PAGES ") || !v2.includes("0 !BRICKWORKS PAGES ")) {
  throw new Error(`the steps were not carried: ${String(made.stderr || "").slice(-300)}`);
}

// --- helpers ---------------------------------------------------------------

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

/// The ids of the dry runs the API said it told the owner of (its answer
/// to a comment, told: {state: "dry", id}), as the page posted them.
const toldIds = [];
const hearing = [];

/// Watch [page] for the API's answers to the comments it posts.
function hearTold(page) {
  page.on("response", (reply) => {
    if (reply.request().method() !== "POST" || !/\/api\/people\?op=comment$/.test(reply.url())) return;
    hearing.push(reply.json().then((said) => { if (said?.told?.id) toldIds.push(said.told.id); }).catch(() => {}));
  });
}

/// The owner's dry runs: what the local relay holds (comments_stand_in.mjs),
/// or, on a deployment, each one the API said it told, as the project kept
/// it (comment_digest_kept, with the secret key). The project's tables are
/// the server's alone: not even the secret key reads comment_digests, so
/// the preview's answer was always none (m81).
async function heldDigests(owner) {
  const local = await fetch(`${site}/__held/comment_digests`, { headers }).catch(() => null);
  if (local && local.ok) return (await local.json()).filter((one) => one.owner === owner);
  await Promise.all(hearing);
  const kept = [];
  for (const one of toldIds) {
    const reply = await fetch(`${SUPABASE}/rest/v1/rpc/comment_digest_kept`, { method: "POST",
      headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json" },
      body: JSON.stringify({ one }) }).catch(() => null);
    const row = reply && reply.ok ? await reply.json().catch(() => null) : null;
    if (row && row.owner === owner) kept.push(row);
  }
  return kept;
}

/// The comments on the model's page, as drawn: each comment and reply in
/// the page's order (the newest thread first, its replies under it).
const drawn = (page) => page.evaluate(() => ({
  shown: !document.getElementById("comments")?.hidden,
  items: [...document.querySelectorAll("#comments .comment")].map((li) => {
    const main = li.querySelector(":scope > .comment-main");
    const pill = main?.querySelector(":scope > .comment-head a.pill.step");
    return {
      id: li.id, body: main?.querySelector(":scope > .comment-body")?.textContent || "",
      reply: li.classList.contains("reply"), under: li.parentElement?.closest("li.comment")?.id || "",
      where: (main?.querySelector(":scope > .comment-head .where")?.textContent || "").trim(),
      step: pill ? pill.textContent : "", to: pill ? pill.getAttribute("href") : "",
      avatar: Boolean(li.querySelector(":scope > .avatar")),
      designer: main?.querySelector(":scope > .comment-head .pill.designer")?.textContent || "",
      links: main?.querySelectorAll(":scope > .comment-body a").length ?? 0,
      acts: [...(main?.querySelectorAll(":scope > .comment-acts button") || [])].map((b) => b.textContent),
      hidden: li.classList.contains("hidden-one") };
  }),
  form: !document.querySelector("#comments form.comment-new")?.hidden,
  send: document.querySelector("#comments form.comment-new button[type=submit]")?.textContent || "",
  why: (document.querySelector("#comments .comment-why")?.hidden ? ""
    : document.querySelector("#comments .comment-why .note")?.textContent) || "",
  said: document.querySelector("#comments .comments-said")?.textContent || "",
}));

async function untilDrawn(page, test, what, seconds = 30) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const now = await drawn(page);
    if (test(now)) return now;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s (${JSON.stringify(now).slice(0, 300)})`);
    await page.waitForTimeout(300);
  }
}

let id = "";
let owner = null;
let writer = null;
let young = null;
try {
  // --- 1. the model, in two versions --------------------------------------
  console.log("the model, published twice");
  owner = await mintSession(ownerEmail);
  writer = await mintSession(writerEmail);
  young = await mintSession(youngEmail, { age: false });
  await answerAge(young.kept.user_id, youngEmail, false);
  const one = await api("/api/share", { method: "POST", token: owner.access_token, body: { name: NAME, model: v1 } });
  id = one.body.id || "";
  const two = await api("/api/share", { method: "POST", token: owner.access_token,
    body: { id, name: NAME, model: v2, note: "Step 3 is blue now" } });
  check(`published at /m/${id}, version ${two.body.version}, step 3 the first changed`,
    one.status === 201 && two.status === 200 && two.body.version === 2 && two.body.first_changed === 3);
  const mail = await api("/api/people?op=mail", { method: "POST", token: owner.access_token, body: { comments: true } });
  check(`the owner asks to be emailed of comments (off until then): ${mail.status}`, mail.status === 200 && mail.body.comments === true);
  const me = await api("/api/people?op=me", { token: owner.access_token });
  check("...and /profile's answer says so", me.body.mail?.comments === true);

  // --- 2. the builder writes ----------------------------------------------
  console.log("a builder, 13 or over, on the model's page");
  const writing = await context({ as: writer });
  let page = await writing.newPage();
  listen(page, "builder");
  hearTold(page);
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  let now = await untilDrawn(page, (d) => d.shown && d.form, "the comment box");
  check(`the comments are on the page with a box to add one (${now.items.length} so far)`, now.items.length === 0 && now.form);
  const options = await page.$$eval("#comment-step option", (all) => all.map((o) => o.textContent));
  check(`the step picker has the whole model and version 2's six steps (${options.join(", ")})`,
    options.length === 7 && options[0] === "the whole model" && options[6] === "step 6");
  await page.fill("#comment-body", ON_MODEL);
  await page.click("#comments form.comment-new button[type=submit]");
  now = await untilDrawn(page, (d) => d.items.length === 1, "the model comment");
  check(`a comment on the model has its writer's avatar and no step (${now.items[0].step || "none"})`,
    now.items[0].body === ON_MODEL && now.items[0].avatar && !now.items[0].step && !now.items[0].where);
  const digests = await heldDigests(owner.kept.user_id);
  check(`the owner is told at once, a dry run (${digests.map((d) => d.state).join(", ")}): "${digests[0]?.subject}"`,
    digests.length === 1 && digests[0].state === "dry" && /comment on your model/.test(digests[0].subject || "")
    && String(digests[0].body || "").includes(ON_MODEL) && String(digests[0].body || "").includes(`/m/${id}#comment-`));
  await page.selectOption("#comment-step", "4");
  await page.fill("#comment-body", ON_STEP);
  await page.click("#comments form.comment-new button[type=submit]");
  now = await untilDrawn(page, (d) => d.items.length === 2, "the step comment");
  check(`the newest first: a comment on step 4 wears "${now.items[0].step}", a way into the viewer there (${now.items[0].to}), its link left as words (${now.items[0].links} links)`,
    now.items[0].body === ON_STEP && now.items[0].step === "Step 4" && now.items[0].to === `/app?view=${id}&step=4`
    && now.items[0].links === 0 && now.items[1].body === ON_MODEL);
  check("...and the owner is not emailed again the same day",
    (await heldDigests(owner.kept.user_id)).length === 1);
  check(`its own comments offer Remove it, not Report it (${now.items[0].acts.join(", ")})`,
    now.items.every((c) => c.acts.includes("Remove it") && !c.acts.includes("Report it")));
  const repliesOn = (await api(`/api/people?op=comments&id=${id}`)).body.replies === true;
  console.log(`  --    replies ${repliesOn ? "kept here (replies.sql, or --hold=replies)" : "not open on this deployment yet"}`);
  await page.evaluate(() => document.getElementById("comments").scrollIntoView());
  await shot(page, "1_builder_comments.png");
  const old = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 1, step: 2, body: ON_OLD } });
  const gone = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 1, step: 5, body: ON_GONE } });
  check(`two on version 1's steps 2 and 5 (${old.status}, ${gone.status})`, old.status === 201 && gone.status === 201);
  const listed = await api(`/api/people?op=comments&id=${id}`);
  const byBody = new Map((listed.body.comments || []).map((c) => [c.body, c]));
  check(`on version 2: step 2 of version 1 says "${byBody.get(ON_OLD)?.said}" and is on step ${byBody.get(ON_OLD)?.on_step}`,
    byBody.get(ON_OLD)?.said === "on step 2 of version 1, an older version" && byBody.get(ON_OLD)?.on_step === 2
    && byBody.get(ON_OLD)?.older === true);
  check(`...step 5 of version 1 is on no step of version 2 (it changed from step 3): ${byBody.get(ON_GONE)?.on_step}`,
    byBody.get(ON_GONE)?.on_step === null && byBody.get(ON_GONE)?.said === "on step 5 of version 1, an older version");
  check(`...newest last (${(listed.body.comments || []).map((c) => c.id).join(", ")})`,
    (listed.body.comments || []).every((c, at, all) => at === 0 || all[at - 1].id < c.id));
  const atOne = await api(`/api/people?op=comments&id=${id}&v=1`);
  const oldOnOne = (atOne.body.comments || []).find((c) => c.body === ON_OLD);
  const stepOnOne = (atOne.body.comments || []).find((c) => c.body === ON_STEP);
  check(`on version 1's own page the same says "${oldOnOne?.said}", and step 4 of version 2 is on no step there`,
    oldOnOne?.said === "on step 2 of version 1, an older version" && oldOnOne?.on_step === 2 && stepOnOne?.on_step === null);
  const tooLong = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 2, body: "a".repeat(1001) } });
  const rude = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 2, body: "What a load of shit" } });
  const noStep = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 2, step: 9, body: "Step 9?" } });
  check(`refused: 1,001 characters (${tooLong.status}), a word the gallery does not show (${rude.status}: "${rude.body.error}"), a step it does not have (${noStep.status})`,
    tooLong.status === 400 && rude.status === 400 && /does not show/.test(rude.body.error || "") && noStep.status === 400);
  await writing.close();

  // --- 3. a visitor with no account ---------------------------------------
  console.log("a visitor with no account");
  const visiting = await context();
  page = await visiting.newPage();
  listen(page, "visitor");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  now = await untilDrawn(page, (d) => d.items.length === 4, "the comments for a visitor");
  check(`reads all four, the newest first, with the box shown to them too ("${now.send}")`,
    now.form && now.send === "Sign in and add it" && !now.why && now.items[0].body === ON_GONE);
  check(`...and may report each (${now.items[1].acts.join(", ")})`, now.items.every((c) => c.acts.includes("Report it")));
  await page.fill("#comment-body", FROM_VISITOR);
  await page.click("#comments form.comment-new button[type=submit]");
  const askedIn = await page.waitForSelector("dialog.sign-in[open]", { timeout: 10000 }).then(() => true, () => false);
  await shot(page, "2a_visitor_signs_in_from_the_box.png");
  check(`sending asks them to sign in: "${askedIn ? (await page.textContent("dialog.sign-in p")).slice(0, 70) : "no dialog"}"`,
    askedIn && /add your comment/.test(await page.textContent("dialog.sign-in p")));
  await page.keyboard.press("Escape");
  check("...and, not signed in, what they typed is kept", (await page.inputValue("#comment-body")) === FROM_VISITOR);
  await page.fill("#comment-body", "");
  const anon = await api("/api/people?op=comment", { method: "POST", body: { model: id, version: 2, body: "hi" } });
  check(`the API refuses a comment without an account: ${anon.status}`, anon.status === 401);
  await page.evaluate(() => document.getElementById("comments").scrollIntoView());
  await shot(page, "2_visitor_reads.png");
  await visiting.close();
  const phonePage = await context({ width: 390, height: 844, phone: true });
  page = await phonePage.newPage();
  listen(page, "visitor phone");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  await untilDrawn(page, (d) => d.items.length === 4, "the comments on a phone");
  check("on a phone, nothing sideways", !(await sideways(page)));
  await page.evaluate(() => document.getElementById("comments").scrollIntoView());
  await shot(page, "3_phone_page.png");
  await phonePage.close();

  // --- 4. under 13 --------------------------------------------------------
  console.log("an account under 13");
  const child = await context({ as: young });
  page = await child.newPage();
  listen(page, "under 13");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  now = await untilDrawn(page, (d) => d.items.length === 4 && d.why, "the comments for an account under 13");
  check(`reads them, with no box, and is told: "${now.why}"`, !now.form && now.why === UNDER_13);
  const refusedYoung = await api("/api/people?op=comment", { method: "POST", token: young.access_token,
    body: { model: id, version: 2, step: 4, body: "Me too!" } });
  check(`the API refuses it in the same words: ${refusedYoung.status}`, refusedYoung.status === 422 && refusedYoung.body.error === UNDER_13);
  await page.evaluate(() => document.getElementById("comments").scrollIntoView());
  await shot(page, "4_under_13.png");
  await child.close();

  // --- 5. the owner -------------------------------------------------------
  console.log("the model's owner");
  const owning = await context({ as: owner });
  page = await owning.newPage();
  listen(page, "owner");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  now = await untilDrawn(page, (d) => d.items.length === 4 && d.items.every((c) => c.acts.includes("Hide it")), "the owner's view");
  check(`each comment has Hide it for its builder (${now.items[0].acts.join(", ")})`, true);
  const stepComment = () => page.locator("#comments .comment-list > li.comment").filter({ hasText: ON_STEP });
  if (repliesOn) await replies(page, stepComment);
  else {
    check(`replies not open: nobody is offered Reply (${now.items[0].acts.join(", ")})`, now.items.every((c) => !c.acts.includes("Reply")));
    const early = await api("/api/people?op=reply", { method: "POST", token: writer.access_token,
      body: { id: Number(now.items[0].id.slice(8)), body: "Early" } });
    check(`...and the API says so: ${early.status}, "${early.body.error}"`, early.status === 503 && /not open/.test(early.body.error || ""));
  }
  const modelComment = page.locator("#comments .comment").filter({ hasText: ON_MODEL });
  await modelComment.locator("button", { hasText: "Hide it" }).click();
  now = await untilDrawn(page, (d) => d.items.some((c) => c.hidden), "the comment hidden");
  check(`hidden: still there for the owner, marked (${now.items.filter((c) => c.hidden).length})`, now.items.find((c) => c.body === ON_MODEL)?.hidden === true);
  const forVisitor = await api(`/api/people?op=comments&id=${id}`);
  check(`...and gone for a visitor (${forVisitor.body.comments.filter((c) => !c.parent).length} shown)`,
    forVisitor.body.comments.filter((c) => !c.parent).length === 3 && !forVisitor.body.comments.some((c) => c.body === ON_MODEL));
  await shot(page, "5_owner_hid_one.png");
  await page.locator("#comments .owner-line button", { hasText: "Turn them off" }).click();
  await page.waitForFunction(() => /Comments are off/.test(document.querySelector("#comments .comments-said")?.textContent || ""), null, { timeout: 20000 });
  const whileOff = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 2, body: "Anyone?" } });
  check(`comments off: the builder is refused (${whileOff.status}: "${whileOff.body.error}")`, whileOff.status === 409);
  await page.locator("#comments .owner-line button", { hasText: "Turn them on" }).click();
  await page.waitForFunction(() => /Comments are on/.test(document.querySelector("#comments .comments-said")?.textContent || ""), null, { timeout: 20000 });
  const notOwner = await api(`/api/people?op=comments_open&id=${id}`, { method: "POST", token: writer.access_token, body: { open: false } });
  check(`...on again; nobody else may turn them off (${notOwner.status})`, notOwner.status === 403);
  await owning.close();

  // --- 6. a report, and the site's owner ----------------------------------
  console.log("a report on a comment, and the admin page");
  const reporting = await context();
  page = await reporting.newPage();
  listen(page, "reporter");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load" });
  now = await untilDrawn(page, (d) => d.items.filter((c) => !c.reply).length === 3, "the comments to report");
  if (repliesOn) {
    check(`a visitor may report a reply too (${now.items.find((c) => c.reply)?.acts.join(", ")})`,
      now.items.some((c) => c.reply) && now.items.filter((c) => c.reply).every((c) => c.acts.includes("Report it")));
  }
  await page.locator("#comments .comment").filter({ hasText: ON_STEP }).locator("button", { hasText: "Report it" }).click();
  await page.waitForSelector("dialog.report[open]");
  check(`the report dialog is for "${await page.textContent("dialog.report h2")}"`, /Report this comment/.test(await page.textContent("dialog.report h2")));
  await page.check('dialog.report input[value="offensive"]');
  await page.fill("dialog.report textarea", "Comments flow: a link in a comment");
  await page.click("dialog.report button[type=submit]");
  await page.waitForFunction(() => /Thank you/.test(document.querySelector("dialog.report p")?.textContent || ""), null, { timeout: 20000 }).catch(() => {});
  check(`sent: "${(await page.textContent("dialog.report p")).slice(0, 60)}"`, /Thank you.*remove it/.test(await page.textContent("dialog.report p")));
  await reporting.close();
  const master = await mintSession(process.env.MASTER_EMAIL);
  const desk = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  await desk.addInitScript(([name, value]) => { try { localStorage.setItem(name, value); } catch {} },
    [STORAGE_KEY, JSON.stringify(master.kept)]);
  page = await desk.newPage();
  listen(page, "admin");
  await page.goto(`${site}/admin`, { waitUntil: "load", timeout: 60000 });
  await page.waitForSelector("#reports tr", { timeout: 30000 });
  const reportRow = page.locator("#reports tr").filter({ has: page.locator(`a[href^="/m/${id}#comment-"]`) });
  const rowText = (await reportRow.count()) ? await reportRow.first().innerText() : "";
  check(`the report is on the admin page with the comment's words: "${rowText.replace(/\s+/g, " ").slice(0, 120)}"`,
    rowText.includes(`A comment on ${NAME}`) && rowText.includes(ON_STEP) && /offensive/.test(rowText));
  const ours = page.locator(`a[href^="/m/${id}#comment-"]`);
  const listedRow = page.locator("#comments tr").filter({ hasText: ON_STEP }).filter({ has: ours });
  check("...and the comment is in the admin page's list of comments", (await listedRow.count()) === 1);
  await shot(page, "6_admin_report.png");
  page.once("dialog", (dialog) => dialog.accept());
  await reportRow.first().locator("button", { hasText: "Remove the comment" }).click();
  await page.waitForFunction(() => /comment is removed/.test(document.getElementById("reports-note").textContent), null, { timeout: 30000 }).catch(() => {});
  check("Remove the comment: the report leaves the queue",
    (await page.locator("#reports tr").filter({ has: page.locator(`a[href^="/m/${id}#comment-"]`) }).count()) === 0);
  const removedText = await page.locator("#comments tr").filter({ hasText: ON_STEP }).filter({ has: ours })
    .first().innerText().catch(() => "");
  check(`...the list says "${removedText.match(/removed by \w+/)?.[0] || removedText.slice(0, 40)}"`, /removed by you/.test(removedText));
  await shot(page, "7_admin_removed.png");
  await desk.close();
  const after = await api(`/api/people?op=comments&id=${id}`);
  check(`...and it is gone from the model's page (${after.body.comments.length} left)`,
    !after.body.comments.some((c) => c.body === ON_STEP));
  if (repliesOn) check("...and its reply with it", !after.body.comments.some((c) => c.body === REPLY_OWNER));
  const kept = await fetch(`${site}/__held/model_comments`, { headers }).then((r) => (r.ok ? r.json() : null)).catch(() => null);
  if (kept) {
    const row = kept.find((c) => c.body === ON_STEP);
    check(`...kept, not deleted (removed_by ${row?.removed_by})`, row?.removed_by === "admin" && Boolean(row?.removed_at));
  }

  // --- 7. the app ---------------------------------------------------------
  if (withApp) await theApp();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (id && owner) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: owner.access_token }).catch(() => {});
  await browser.close();
  for (const email of [ownerEmail, writerEmail, youngEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "comments: who may write, where each was said, the owner's say, reports, and the step player");
process.exit(failed ? 1 : 0);

// --- replies ---------------------------------------------------------------

/// The owner, on the model's page ([page]), replies to the step comment
/// ([stepComment]); the builder is told; an account under 13 is refused;
/// the comment hidden takes its reply with it, and shown brings it back.
async function replies(page, stepComment) {
  await stepComment().locator(":scope > .comment-main > .comment-acts button", { hasText: "Reply" }).click();
  const box = stepComment().locator("form.reply-new textarea");
  await box.fill(REPLY_OWNER);
  await stepComment().locator("form.reply-new button[type=submit]").click();
  let now = await untilDrawn(page, (d) => d.items.some((c) => c.body === REPLY_OWNER), "the owner's reply");
  const theirs = now.items.find((c) => c.body === REPLY_OWNER);
  const parent = now.items.find((c) => c.body === ON_STEP);
  check(`the owner's reply is under the step comment, marked "${theirs.designer}", with its avatar, said "${now.said}"`,
    theirs.reply && theirs.under === parent.id && theirs.designer === "Designer" && theirs.avatar && now.said === "Replied."
    && !now.items.some((c) => c.reply && c.acts.includes("Reply")));
  await page.evaluate(() => document.getElementById("comments").scrollIntoView());
  await shot(page, "5a_owner_replied.png");
  const listed = await api(`/api/people?op=comments&id=${id}`);
  const reply = (listed.body.comments || []).find((c) => c.body === REPLY_OWNER);
  check(`...on its comment's step and version (step ${reply?.step} of version ${reply?.version}), its parent ${reply?.parent}`,
    reply?.step === 4 && reply?.version === 2 && reply?.parent === Number(parent.id.slice(8)));
  const kid = await api("/api/people?op=reply", { method: "POST", token: young.access_token,
    body: { id: Number(parent.id.slice(8)), body: "Me too!" } });
  check(`an account under 13 is refused a reply in a comment's words: ${kid.status}`, kid.status === 422 && kid.body.error === UNDER_13);
  const nobody = await api("/api/people?op=reply", { method: "POST", body: { id: Number(parent.id.slice(8)), body: "hi" } });
  check(`...and nobody signed in: ${nobody.status}`, nobody.status === 401);

  // The builder is told, in Notifications.
  const told = await api("/api/people?op=notifications", { token: writer.access_token });
  const group = (told.body.groups || []).find((g) => g.model === id);
  const row = group?.rows.find((r) => r.kind === "reply");
  check(`the builder's notifications: "${row ? `${row.who} ${row.did}: ${row.said}` : "nothing"}", under "${group?.name}"`,
    told.status === 200 && Boolean(row) && row.did === "replied to your comment on step 4" && row.said === REPLY_OWNER
    && row.link.endsWith(`/m/${id}#comment-${reply?.id}`) && group.name === NAME);
  const reading = await context({ as: await mintSession(writerEmail), width: 390, height: 844, phone: true });
  const inbox = await reading.newPage();
  listen(inbox, "builder's notifications");
  await inbox.goto(`${site}/notifications`, { waitUntil: "load" });
  await inbox.waitForFunction(() => document.documentElement.dataset.notifications === "ready", null, { timeout: 30000 });
  const line = await inbox.evaluate((model) => document.querySelector(`#groups .notice[data-model="${model}"] li[data-kind="reply"]`)
    ?.innerText.replace(/\s+/g, " ") || "", id);
  check(`...on the page at 390: "${line.slice(0, 90)}"`, line.includes("replied to your comment") && line.includes(REPLY_OWNER)
    && !(await sideways(inbox)));
  await shot(inbox, "5b_builder_notified_390.png");
  await inbox.click(`#groups .notice[data-model="${id}"] li[data-kind="reply"] a`);
  await inbox.waitForURL(new RegExp(`/m/${id}#comment-`), { timeout: 30000 });
  await untilDrawn(inbox, (d) => d.items.some((c) => c.body === REPLY_OWNER), "the reply, opened from the notification");
  const asked = await inbox.evaluate(() => document.querySelector("#comments .comment.asked")?.querySelector(".comment-body")?.textContent);
  check(`opened, the model's page marks the reply ("${asked}")`, asked === REPLY_OWNER);
  await shot(inbox, "5c_reply_opened_390.png");
  await reading.close();
  const read = await api("/api/people?op=notifications", { token: writer.access_token });
  check("...and its group is read", (read.body.groups || []).find((g) => g.model === id)?.unread === false);

  // Hiding the comment hides its reply.
  await stepComment().locator(":scope > .comment-main > .comment-acts button", { hasText: "Hide it" }).click();
  now = await untilDrawn(page, (d) => d.items.find((c) => c.body === ON_STEP)?.hidden, "the step comment hidden");
  check("the owner hides the step comment: still there for them, its reply under it",
    now.items.some((c) => c.body === REPLY_OWNER && c.under === now.items.find((p) => p.body === ON_STEP).id));
  const hidden = await api(`/api/people?op=comments&id=${id}`);
  check(`...gone for a visitor, and its reply with it (${hidden.body.comments.length} shown)`,
    !hidden.body.comments.some((c) => c.body === ON_STEP || c.body === REPLY_OWNER));
  const quiet = await api("/api/people?op=notifications", { token: writer.access_token });
  check("...and from the builder's notifications",
    !(quiet.body.groups || []).some((g) => g.rows.some((r) => r.kind === "reply" && r.said === REPLY_OWNER)));
  await stepComment().locator(":scope > .comment-main > .comment-acts button", { hasText: "Show it" }).click();
  await untilDrawn(page, (d) => d.items.find((c) => c.body === ON_STEP)?.hidden === false, "the step comment shown");
  const back = await api(`/api/people?op=comments&id=${id}`);
  check("shown again: the comment and its reply are back",
    back.body.comments.some((c) => c.body === ON_STEP) && back.body.comments.some((c) => c.body === REPLY_OWNER));
}

// --- the app ---------------------------------------------------------------

// Declared, not assigned: the flow above runs before this part of the
// module would be reached.
function state(page) {
  return page.evaluate(() => window.brickworksShare || {});
}
function controls(page) {
  return page.evaluate(() => window.brickworksControls || {});
}

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

/// Press what the app shows by its name, once two of its reports agree on
/// where it is (versions_flow.mjs press).
async function press(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    let at = (await controls(page))[name];
    for (let n = 0; at && n < 6; n += 1) {
      await page.waitForTimeout(550);
      const again = (await controls(page))[name];
      if (again && again.x === at.x && again.y === at.y) break;
      at = again;
    }
    if (at) {
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(400);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

/// The viewer at [address] on a phone-sized page, as [who] (a session, or
/// none), ready; then the step player opened and turned to step [step].
async function onStep(who, label, step) {
  const made = await context({ as: who, width: 390, height: 844 });
  const page = await made.newPage();
  listen(page, label);
  await page.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", `${label}: the viewer`, 300);
  await until(page, () => ((window.brickworksShare || {}).view || {}).comment_pill, `${label}: the viewer's count`, 60);
  const view = (await state(page)).view;
  await press(page, "view_build");
  await until(page, () => ((window.brickworksShare || {}).build || {}).open, `${label}: the step player`, 120);
  for (let n = 0; n < 12; n += 1) {
    const built = (await state(page)).build;
    if (built.page === step) break;
    await press(page, "build_next");
    await until(page, (was) => ((window.brickworksShare || {}).build || {}).page !== was,
      `${label}: the next page`, 60, built.page);
  }
  return { made, page, view };
}

async function theApp() {
  console.log("the app, on a phone-sized page");
  const more = await api("/api/people?op=comment", { method: "POST", token: writer.access_token,
    body: { model: id, version: 2, step: 4, body: "Step 4: press both bricks down until they click." } });
  check(`another comment on step 4 (${more.status})`, more.status === 201);

  // The builder, signed in on this device: reads step 4's, and adds one. A
  // session of its own for each browser: the site's pages renewed the
  // first ones, and a renewed refresh token is spent.
  let { made, page, view } = await onStep(await mintSession(writerEmail), "builder in the app", 4);
  check(`the viewer shows a count for the step it is on ("${view.comment_pill}", step ${view.comment_step})`,
    Boolean(view.comment_pill));
  let built = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.page === 4 && b.comment_pill ? b : null;
  }, "step 4's count", 30);
  check(`step 4 of the step player says "${built.comment_pill}" (${built.comments})`, built.comments === 1 && built.comment_pill === "1 comment");
  await press(page, "build_comments");
  built = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.comments_open && b.comment_can_write ? b : null;
  }, "the comments, and the box for somebody who may write", 90);
  check(`tapped: its comments ("${built.comments_shown.join(" | ")}") and a box`,
    built.comments_shown.length === 1 && /press both bricks down/.test(built.comments_shown[0]));
  await shot(page, "8_app_step_comments.png");
  await press(page, "build_comment_box");
  await page.keyboard.type(FROM_APP, { delay: 15 });
  await press(page, "build_comment_send");
  built = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.comments === 2 ? b : null;
  }, "the count after adding one", 60);
  check(`added from the step player: step 4 says "${built.comment_pill}"`, built.comment_pill === "2 comments"
    && built.comments_shown.some((body) => body === FROM_APP));
  const listed = await api(`/api/people?op=comments&id=${id}`);
  const fromApp = (listed.body.comments || []).find((c) => c.body === FROM_APP);
  check(`...and it is on the model's page as "${fromApp?.said}"`, fromApp?.said === "on step 4 of version 2" && fromApp?.step === 4);
  await shot(page, "9_app_added.png");
  await made.close();

  // A visitor with no account: reads them, told to sign in.
  ({ made, page } = await onStep(null, "visitor in the app", 4));
  await press(page, "build_comments");
  built = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.comments_open && b.comment_why_not ? b : null;
  }, "the visitor's comments", 60);
  // The controls are reported a moment after the page's state.
  const named = await until(page, () => {
    const c = window.brickworksControls || {};
    return c.build_comment_sign_in || c.build_comment_box ? c : null;
  }, "the visitor's sign-in button", 30).catch(() => ({}));
  check(`a visitor reads step 4's two (${built.comments_shown.length}), with no box (${Boolean(named.build_comment_box)}), `
    + `a way to sign in (${Boolean(named.build_comment_sign_in)}), told: "${built.comment_why_not}"`,
    built.comments_shown.length === 2 && !built.comment_can_write && built.comment_why_not === SIGN_IN
    && !named.build_comment_box && Boolean(named.build_comment_sign_in));
  await shot(page, "10_app_visitor.png");
  await made.close();

  // Under 13, signed in on this device: reads them, told why not.
  ({ made, page } = await onStep(await mintSession(youngEmail, { age: false }), "under 13 in the app", 4));
  await press(page, "build_comments");
  built = await until(page, () => {
    const b = (window.brickworksShare || {}).build || {};
    return b.comments_open && b.comment_why_not && b.comment_why_not.startsWith("Comments are for") ? b : null;
  }, "the under-13 account's comments", 90);
  check(`an account under 13 reads them, with no box, told: "${built.comment_why_not}"`,
    built.comments_shown.length === 2 && !built.comment_can_write && built.comment_why_not === UNDER_13);
  await shot(page, "11_app_under_13.png");
  await made.close();
}
