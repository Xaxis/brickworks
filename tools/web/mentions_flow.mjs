// @mentions in comments, in real browsers (docs/SOCIAL.md section 7, item
// 6, supabase/comment_mentions.sql, api/_comments.js): @ in a comment's box
// offers the people on the page, Enter puts one in; a comment naming
// somebody links their name to their profile, and they are told in
// Notifications, unless they hear of it already (the model's designer, a
// reply in their own conversation); a handle nobody has stays words.
//
//   node tools/web/mentions_flow.mjs [--out=DIR]                     # this checkout, the stand-in's
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/mentions_flow.mjs --url=<preview> --out=DIR
//
// With no --url nothing leaves this machine: the pages are made by this
// checkout's api/ and every call answered by design_stand_in.mjs, signed
// in as its Sam: the watchtower's reply naming Priya is a link; Sam's reply
// there names her from the picker; his Notifications have Jo naming him on
// the gearbox.
//
// With --url, the live project's tables, and throwaway accounts at Resend
// test addresses, deleted at the end with the model: Pia designs, Max
// comments, Lia names them both. Before comment_mentions.sql a comment
// names nobody: its @handle stays words, nobody is told, and the comment
// goes as ever; the flow proves that and passes, saying so.
//
//   1. Pia shares a tower; Max comments on it.
//   2. Lia, at 1280 px (light), types @ in the box: the picker offers Pia
//      (the designer) and Max; typing narrows it, Escape closes it alone,
//      Enter puts Max in. She names a handle nobody has too, and sends.
//   3. Her comment: @Max a link to his profile, the other words; the API's
//      comment names Max alone.
//   4. Max, at 390 px (dark): Notifications has "Lia mentioned you in a
//      comment", under Pia's tower, its link the comment; Pia hears it as a
//      comment, not twice.
//   5. Lia replies to Max's comment naming him: he hears it as a reply in
//      his conversation, not as a mention as well.
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
const out = path.resolve(String(args.out || "shots/mentions"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(3).toString("hex");
const emails = { pia: `delivered+bw-men-pia-${rand}@resend.dev`, max: `delivered+bw-men-max-${rand}@resend.dev`,
  lia: `delivered+bw-men-lia-${rand}@resend.dev` };
const handles = { pia: `bwm-pia-${rand}`, max: `bwm-max-${rand}`, lia: `bwm-lia-${rand}` };
const names = { pia: "Pia Mentions", max: "Max Mentions", lia: "Lia Mentions" };
const TOWER = `Mentions Flow Tower ${rand}`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
const model = (name) => `0 ${name}\r\n0 Name: mentions.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n`
  + `1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 STEP\r\n0 // mentions flow ${rand}\r\n`;

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 900, dark = false, phone = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (!remote) await stand.serveSite(made, { web: path.join(root, "web"), api: path.join(root, "api") });
  if (as) {
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

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
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

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// The picker under [box] as drawn: open, its options, the one marked.
const picker = (page, box) => page.evaluate((selector) => {
  const field = document.querySelector(selector);
  const list = field && document.getElementById(field.getAttribute("aria-controls"));
  const marked = list?.querySelector("[aria-selected=true]");
  // Still the box it was to a screen reader, the one marked its active
  // descendant, and a status saying the list is there.
  return { role: field?.getAttribute("role") || field?.tagName.toLowerCase(), open: Boolean(list && !list.hidden),
    listbox: list?.getAttribute("role") === "listbox",
    active: Boolean(marked) && field.getAttribute("aria-activedescendant") === marked.id,
    said: list?.parentElement.querySelector("[role=status]")?.textContent || "",
    options: list ? [...list.querySelectorAll("[role=option]")].map((li) => li.textContent.replace(/\s+/g, " ").trim()) : [],
    marked: marked?.textContent.replace(/\s+/g, " ").trim() || "",
    value: field?.value || "" };
}, box);

/// A comment's words as drawn: its text, and each link in them.
const wordsOf = (page, id) => page.evaluate((key) => {
  const words = document.querySelector(`#comment-${key} > .comment-main > .comment-body`);
  return words ? { text: words.textContent, links: [...words.querySelectorAll("a.mention")].map((a) => [a.textContent, a.getAttribute("href")]) }
    : null;
}, id);

/// [who]'s Notifications rows of [kind] on [model], from the API.
async function noticesOf(token, kind, model) {
  const said = await api("/api/people?op=notifications", { token });
  return (said.body.groups || []).filter((one) => one.model === model).flatMap((one) => one.rows).filter((row) => row.kind === kind);
}

const people = {};
let tower = "";
try {
  if (!remote) {
    // --- The stand-in: Sam on the watchtower ----------------------------------
    console.log("The stand-in: Sam on Robin's watchtower");
    const sam = await context({ as: {} });
    const page = await sam.newPage();
    listen(page, "Sam");
    await page.goto(`${site}/m/${stand.MODEL_ID}`, { waitUntil: "load" });
    await until(page, () => document.querySelector("#comment-110 .comment-body"), "the comments");
    const words = await wordsOf(page, 110);
    check(`Jo's reply: "${words.text}", its link ${JSON.stringify(words.links)}`, words.links.length === 1
      && words.links[0][0] === "@priya-plays" && words.links[0][1] === "/u/priya-plays" && words.text.includes("Same here, @priya-plays."));
    await page.click("#comment-103 > .comment-main > .comment-acts button:text-is('Reply')");
    const box = "#comment-103 form.reply-new textarea";
    await page.waitForSelector(box);
    await page.type(box, "Thank you @");
    let pick = await picker(page, box);
    check(`@ offers the people on the page: ${pick.options.join(" | ")} (a ${pick.role}'s listbox, "${pick.said}")`, pick.open
      && pick.role === "textarea" && pick.listbox && pick.active && /^\d+ people to name/.test(pick.said)
      && pick.options[0]?.startsWith("Robin Castell")
      && pick.options.some((one) => one.includes("@priya-plays")));
    await page.type(box, "pr");
    pick = await picker(page, box);
    check(`"@pr" narrows it to ${pick.options.join(" | ")}, marked "${pick.marked}", "${pick.said}"`, pick.options.length === 1
      && pick.marked === "Priya Raman @priya-plays" && pick.active && pick.said.startsWith("1 person to name"));
    await shot(page, "1_picker.png");
    await page.keyboard.press("Escape");
    pick = await picker(page, box);
    check(`Escape closes the picker alone: open ${pick.open}, the reply box still there`, !pick.open && !pick.said
      && (await page.locator(box).count()) === 1);
    await page.type(box, "i");
    await page.keyboard.press("Enter");
    pick = await picker(page, box);
    check(`Enter puts her in: "${pick.value}"`, pick.value === "Thank you @priya-plays " && !pick.open);
    await page.type(box, "it clicks.");
    // The stand-in keeps no write, so the list drawn again is as it was:
    // what the reply's answer named is what the API would keep.
    const [sent] = await Promise.all([page.waitForResponse((reply) => reply.url().includes("op=reply")
      && reply.request().method() === "POST"), page.click("#comment-103 form.reply-new button[type=submit]")]);
    const made = (await sent.json()).comment || {};
    check(`his reply: "${made.body}", naming ${JSON.stringify(made.mentions)}`, made.body === "Thank you @priya-plays it clicks."
      && made.mentions?.length === 1 && made.mentions[0].handle === "priya-plays");
    // Sam's Notifications, at 390 px (dark).
    const phone = await context({ as: {}, width: 390, height: 844, dark: true, phone: true });
    const small = await phone.newPage();
    listen(small, "Sam at 390");
    await small.goto(`${site}/notifications`, { waitUntil: "load" });
    const row = await until(small, () => {
      const li = document.querySelector('#groups li[data-kind="mention"]');
      return li && { text: li.querySelector(".what").textContent.replace(/\s+/g, " ").trim(), href: li.querySelector("a")?.getAttribute("href") || "",
        group: li.closest(".notice")?.dataset.model || "" };
    }, "the mention in Notifications");
    check(`Notifications at 390 px (dark): "${row.text.slice(0, 90)}…" → ${row.href} (under ${row.group})`,
      /^Jo Lindqvist mentioned you in a comment on step 2/.test(row.text) && row.href.endsWith("/m/DesignGea1#comment-104")
      && row.group === "DesignGea1");
    check("nothing sideways", !(await sideways(small)));
    await small.locator('#groups li[data-kind="mention"]').scrollIntoViewIfNeeded();
    await shot(small, "2_notifications_390_dark.png");
  } else {
    // --- 1. Pia's tower, Max's comment -----------------------------------------------
    console.log("Pia shares a tower; Max comments on it");
    for (const who of ["pia", "max", "lia"]) {
      people[who] = await mintSession(emails[who]);
      const made = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
        body: { handle: handles[who], name: names[who] } });
      check(`${names[who]}'s profile @${handles[who]}: ${made.status}`, made.status === 200);
    }
    const shared = await api("/api/share", { method: "POST", token: people.pia.access_token,
      body: { name: TOWER, author: names.pia, model: model(TOWER), image: picture, listed: true } });
    tower = shared.body.id || "";
    check(`the tower /m/${tower}: ${shared.status}`, shared.status === 201 && Boolean(tower));
    const maxSaid = await api("/api/people?op=comment", { method: "POST", token: people.max.access_token,
      body: { model: tower, version: 1, body: "Lovely tower." } });
    const maxComment = maxSaid.body.comment?.id;
    check(`Max's comment: ${maxSaid.status}`, maxSaid.status === 201 && Boolean(maxComment));

    // --- 2. Lia names him from the picker ----------------------------------------------
    console.log("Lia names Max, at 1280 px (light)");
    const liaSite = await context({ as: people.lia });
    const page = await liaSite.newPage();
    listen(page, "Lia");
    await page.goto(`${site}/m/${tower}?tests=1`, { waitUntil: "load" });
    await until(page, () => document.querySelector(`#comment-${document.querySelector("#comments li.comment")?.id.slice(8)} .comment-body`)
      && !document.querySelector("#comments form.comment-new").hidden, "the comments and the box");
    const box = "#comment-body";
    await page.click(box);
    await page.type(box, "Ask @");
    let pick = await picker(page, box);
    check(`@ offers ${pick.options.join(" | ")}`, pick.open && pick.options[0] === `${names.pia} @${handles.pia}`
      && pick.options.includes(`${names.max} @${handles.max}`));
    await page.type(box, "bwm-m");
    pick = await picker(page, box);
    check(`"@bwm-m" narrows it to ${pick.options.join(" | ")}`, pick.options.length === 1 && pick.marked === `${names.max} @${handles.max}`);
    await page.keyboard.press("Escape");
    check("Escape closes it", !(await picker(page, box)).open);
    await page.type(box, "a");
    await page.keyboard.press("Enter");
    pick = await picker(page, box);
    check(`Enter puts him in: "${pick.value}"`, pick.value === `Ask @${handles.max} `);
    await shot(page, "1_named.png");
    await page.type(box, `how he did the roof, and @bwm-nobody-${rand} too.`);
    await page.click("#comments form.comment-new button[type=submit]");
    const id = await until(page, () => {
      const all = [...document.querySelectorAll("#comments li.comment")].filter((li) => /how he did the roof/.test(li.textContent));
      return all[0]?.id.slice(8);
    }, "her comment drawn");

    // --- 3. Her comment --------------------------------------------------------------------
    const listed = await api(`/api/people?op=comments&id=${tower}`, { token: people.lia.access_token });
    const hers = (listed.body.comments || []).find((one) => String(one.id) === String(id));
    const applied = Array.isArray(hers?.mentions);
    console.log(applied ? "  --    comment_mentions.sql is applied: the whole of it" : "  --    comment_mentions.sql is not applied: a comment names nobody");
    await page.reload({ waitUntil: "load" });
    await until(page, (key) => document.querySelector(`#comment-${key} .comment-body`), "her comment after a reload", 30, id);
    const words = await wordsOf(page, id);
    if (applied) {
      check(`the API names ${JSON.stringify(hers.mentions)}`, hers.mentions.length === 1 && hers.mentions[0].handle === handles.max);
      check(`her words: "${words.text}", links ${JSON.stringify(words.links)}`, words.links.length === 1
        && words.links[0][0] === `@${handles.max}` && words.links[0][1] === `/u/${handles.max}`
        && words.text.includes(`@bwm-nobody-${rand} too.`));
    } else {
      check(`her words, all words: "${words.text}", no link`, words.links.length === 0 && words.text.includes(`@${handles.max}`));
    }
    await shot(page, "2_comment.png");

    // --- 4. Max is told ----------------------------------------------------------------------
    console.log("Max's Notifications, at 390 px (dark)");
    const told = await noticesOf(people.max.access_token, "mention", tower);
    const piaTold = await noticesOf(people.pia.access_token, "mention", tower);
    const piaComments = await noticesOf(people.pia.access_token, "comment", tower);
    if (applied) {
      check(`Max is told: ${JSON.stringify(told.map((row) => [row.who, row.did, row.link]))}`, told.length === 1
        && told[0].who === names.lia && told[0].did === "mentioned you in a comment" && told[0].link.endsWith(`/m/${tower}#comment-${id}`));
      const phone = await context({ as: people.max, width: 390, height: 844, dark: true, phone: true });
      const small = await phone.newPage();
      listen(small, "Max at 390");
      await small.goto(`${site}/notifications`, { waitUntil: "load" });
      const row = await until(small, () => document.querySelector('#groups li[data-kind="mention"] .what')?.textContent.replace(/\s+/g, " ").trim(),
        "the mention in Notifications");
      check(`his Notifications: "${row.slice(0, 80)}…"`, row.startsWith(`${names.lia} mentioned you in a comment`));
      check("nothing sideways", !(await sideways(small)));
      await shot(small, "3_notifications_390_dark.png");
    } else {
      check(`Max is told nothing (${told.length})`, told.length === 0);
    }
    check(`Pia hears it as a comment on her tower (${piaComments.length}), not a mention (${piaTold.length})`,
      piaComments.length >= 1 && piaTold.length === 0);

    // --- 5. A reply in his own conversation ----------------------------------------------
    console.log("Lia answers Max's comment, naming him");
    const reply = await api("/api/people?op=reply", { method: "POST", token: people.lia.access_token,
      body: { id: maxComment, body: `@${handles.max} the roof is plates.` } });
    check(`her reply: ${reply.status}, names ${JSON.stringify(reply.body.comment?.mentions || [])}`, reply.status === 201
      && (applied ? reply.body.comment?.mentions?.[0]?.handle === handles.max : !reply.body.comment?.mentions));
    const replies = await noticesOf(people.max.access_token, "reply", tower);
    const mentions = await noticesOf(people.max.access_token, "mention", tower);
    check(`Max hears it once, as a reply (${replies.length}); his mentions still ${mentions.length}`, replies.length === 1
      && mentions.length === (applied ? 1 : 0));
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (remote && tower && people.pia) await api(`/api/share?op=unpublish&id=${tower}`, { method: "POST", token: people.pia.access_token }).catch(() => {});
  await browser.close();
}
if (remote) {
  const gone = [];
  for (const email of Object.values(emails)) gone.push(await deleteAccount(email).catch(() => false));
  check(`the three throwaway accounts deleted (${gone.filter(Boolean).length})`, gone.every(Boolean));
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "mentions: offered as you type, linked on the page, told to whom it names, once");
process.exit(failed ? 1 : 0);
