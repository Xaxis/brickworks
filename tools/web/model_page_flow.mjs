// A model's page, /m/<id> (api/share.js, web/model-page.js; docs/SOCIAL.md
// U4): does it lead with the work, say what can be done as buttons with
// counts, and lead on to more?
//
//   node tools/web/model_page_flow.mjs [--out=DIR]                     # this checkout's web/ and api/
//   node tools/web/model_page_flow.mjs --url=<deployment> [--out=DIR]  # a deployment's pages
//   [--widths=390,1280] [--themes=light,dark]
//
// With no --url nothing leaves this machine: the pages are made by this
// checkout's api/ and every API call is answered by design_stand_in.mjs,
// as design_flow.mjs does. With --url (a preview: BW_BYPASS=$VERCEL_BYPASS)
// the pages are the deployment's own, its gallery's first model, and only
// what a signed-in page asks is answered here.
//
// At 390 x 844 and 1280 x 900, light and dark, signed out and signed in:
//
//   1. Media first. At 390 the picture leads, and it, the name, the
//      designer and the action bar are wholly on the first screen. At 1280
//      the picture and the column beside it are on the first screen, and
//      the column is still beside it, on screen, after the page scrolls.
//   2. One action bar: Like, Save, Share, Comment, I built it and More,
//      each named for a screen reader with its count ("Like, 96 likes"),
//      the count beside its icon, and never a count of none.
//   3. Share opens its sheet (docs/SOCIAL.md U14), the site's dialog: the
//      page's link, selected, and Copy link puts it on the clipboard and
//      says "Link copied" in the sheet; the embed code, and Copy code puts
//      the iframe on the clipboard; Escape closes it, back on Share. Where
//      the browser has a share sheet of its own (navigator.share), the
//      sheet offers it too, given the link, and nothing copied.
//   4. Save, signed out, asks to sign in; signed in, it opens the lists,
//      Favourites first and ticked when it is a favourite.
//   5. More holds Report it and Takedown requests (the embed code is in
//      Share's sheet).
//   6. More by and Similar models show only with three cards or more, six
//      at most. On the stand-in: the watchtower has More by Robin Castell
//      (3) and no Similar (2 found); its remix at dusk has Similar (3: kind
//      and a shared tag) and no More by (Jo has no other model).
//   7. The paragraph that explained the buttons is gone.
//   8. Tabs under it, About, Comments, Builds, Remixes and (with two or
//      more) Versions, each with its count once there is one; a tab chosen
//      brings its part to just under the tabs, which stay on screen under
//      the header, marked as the one being read.
//   9. A strip of its pictures under the picture: the published one first
//      and marked, then the photos; choosing one shows it in the picture's
//      place. With none it is not shown, but to its owner, who has Add a
//      picture there, which opens the photo form.
//  10. A model with no comments, builds or remixes (the stand-in's bakery,
//      Sam's, shared by link) says so in one line each, with the way in,
//      and shows no count of none anywhere.
//  11. The last screen always has another model to open: with neither row,
//      the gallery's own (More in the gallery).
//  12. Comments that talk (docs/SOCIAL.md U8), on the stand-in's
//      watchtower: the newest thread first and its replies oldest first
//      under it; an avatar on every one; Designer on Robin's (the
//      model's owner's); a step comment's pill a link to the viewer at
//      that step (an older version's changed step, that version's
//      viewer); the box shown to everybody, and Reply on each comment
//      opening a box under its thread; signed out, sending asks to sign
//      in and keeps what was typed; signed in, the reply goes.
//  14. In N collections (docs/SOCIAL.md U11): a pill among its facts, and a
//      tab, both going to its Collections part, a card for each public
//      collection it is in; none when it is in none. The watchtower is in
//      two (Robin's and Sam's public ones), the dusk in one.
//  15. The embed (/m/<id>/embed) in the theme its viewer chose: light
//      chosen on a dark computer is light, dark chosen on a light one dark,
//      and with no choice the computer's. Its button is Build it, the
//      guided build at step 1 as the page's Build it is (/app?view=<id>
//      &build), View in 3D a quiet link beside it to the viewer, and its
//      picture and name the model's page, each in a tab of its own; in a
//      frame a phone's column wide the bar still fits, Build it whole.
//  16. Its parts (site278): a Parts tab and section saying one count, the
//      app's (api/_parts.js); the list asked for only as the section nears
//      the screen and drawn into the space kept for it, nothing under it
//      moving; a row a colour over its lots, the lots' counts adding up to
//      the total, Kind grouping them by kind; each lot on screen its part
//      drawn on the page from its geometry (site304, web/part-pictures.js):
//      a canvas in place of the swatch, a part on it (not blank, lit and
//      lined) and the lot's colour in it, again at once after Kind and
//      Colour; no picture loaded from anywhere, and a policy that lets none
//      in but the site's own and talks only to it and its Supabase project
//      (the store the geometry comes from); the BrickLink wanted list well-formed
//      XML of ITEMTYPE P, ITEMID, a numbered COLOR and MINQTY, adding up to
//      the total less what it says it left off; the Rebrickable CSV
//      Part,Color,Quantity likewise; and Download the stored file byte for
//      byte, signed out, named for the model. And Like and I built it say
//      their names beside their icons.
//  17. In 3D, here (viewer369, tools/viewer/inline.js), on the watchtower
//      (a deployment's first model), signed out: none of the 3D view's code
//      (viewer3d.js, three.js and all) asked for until View in 3D is used;
//      then it in the picture's frame, nothing on the page moving; a
//      frame drawn with the model whole in it, timed to a pixel read back
//      (SwiftShader draws late); its tools named, and Open in the app the picture's own link;
//      on a laptop the arrows turn it, + zooms in, 0 and Reset the view go
//      back to where it started; Full screen fills the window, the model
//      fitted to it, and goes back to the frame as it was; on a phone a
//      swipe up the 3D view scrolls the page and leaves the model as it was
//      (touch-action pan-y until the person takes hold), a swipe across
//      turns it; Back to the picture puts the picture back. Its costs said: the code's bytes,
//      the scene's, the geometry's, and the first frame from the click.
//
// Pictures in --out: each page whole and its first screen (-fold), and
// Save's lists and More open.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const base = remote || stand.ORIGIN;
const out = args.out ? path.resolve(String(args.out)) : "";
if (out) mkdirSync(out, { recursive: true });
const widths = String(args.widths || "390,1280").split(",").map(Number);
const themes = String(args.themes || "light,dark").split(",");
const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
const headers = remote && bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let passed = 0;
let failed = 0;
const check = (what, ok) => {
  if (ok) passed += 1;
  else failed += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
};
/// Until the page stops scrolling (the site scrolls smoothly to a part).
async function settled(page) {
  let last = -1;
  for (let at = 0; at < 30; at++) {
    await page.waitForTimeout(120);
    const y = await page.evaluate(() => scrollY);
    if (y === last) return;
    last = y;
  }
}
const until = (page, test, arg, ms = 8000) => page.waitForFunction(test, arg, { timeout: ms }).then(() => true, () => false);

// The pages visited, and what each must lead on to: the number of cards in
// More by and in Similar (0 for no row). On a deployment, its own model, and
// only that a row shown has three to six.
const PAGES = remote ? [] : [
  { name: "watchtower", path: `/m/${stand.MODEL_ID}`, by: 3, like: 0, favourite: true, designer: "Robin Castell",
    tabs: ["About", "Parts 3", "Comments 6", "Builds 37", "Remixes 3", "Collections 2", "Versions 2"], thumbs: 3, threads: true, lists: 2 },
  { name: "dusk", path: "/m/DesignRmx1", by: 0, like: 3, favourite: false, designer: "Jo Lindqvist",
    tabs: ["About", "Parts 3", "Comments 1", "Builds 3", "Remixes", "Collections 1"], thumbs: 0, lists: 1 },
  // Signed in, Sam's own: More has the owner's own in place of Report it.
  { name: "bakery", path: "/m/SamModel02", by: 0, like: 0, gallery: true, favourite: false, designer: null,
    tabs: ["About", "Parts 3", "Comments", "Builds", "Remixes"], thumbs: 0, empty: true, owner: true, lists: 0 },
];
let remoteDb = "";
const asProject = (text) => (remoteDb ? text.split(stand.DB).join(remoteDb) : text);
if (remote) {
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* none: the stand-in's own */ }
  const listed = await (await fetch(`${remote}/api/share?op=list&page=1`, { headers })).json().catch(() => ({}));
  const first = (listed.models || [])[0];
  if (first) PAGES.push({ name: "first", path: `/m/${first.id}`, by: null, like: null, favourite: null, designer: null });
  else check("the deployment's gallery has a model to visit", false);
}

/// What the page shows of itself, read in the page.
function read() {
  const box = (el) => {
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { top: r.top, bottom: r.bottom, left: r.left, right: r.right, width: r.width, height: r.height };
  };
  const bar = document.getElementById("marks");
  const buttons = bar ? [...bar.querySelectorAll(":scope > button, :scope > a, :scope > details > summary")] : [];
  const named = buttons.filter((b) => !b.hidden && b.getClientRects().length).map((b) => ({
    label: (b.getAttribute("aria-label") || "").replace(/^Saved$/, "Save"), n: b.querySelector(".n")?.textContent || "",
    box: box(b), pressed: b.getAttribute("aria-pressed"),
  }));
  const rows = Object.fromEntries(["more-by", "similar", "from-gallery"].map((key) => [key,
    document.getElementById(key) ? document.querySelectorAll(`#${key} .model`).length : 0]));
  const zeros = [...document.querySelectorAll("#marks .n, .facts .pill, #page-tabs .n")]
    .filter((el) => el.getClientRects().length && /^0\b|(^|\s)0 \w/.test(el.textContent.trim()))
    .map((el) => el.textContent.trim());
  return {
    viewport: { width: innerWidth, height: innerHeight },
    picture: box(document.querySelector(".model-page .picture")),
    title: box(document.querySelector(".model-page h1")),
    designer: box(document.querySelector(".shared-by")),
    designerName: document.querySelector(".shared-by .names b")?.textContent || "",
    designerLink: document.querySelector(".shared-by a.who")?.getAttribute("href") || "",
    avatar: Boolean(document.querySelector(".shared-by .avatar")),
    bar: box(bar),
    side: box(document.querySelector(".model-page .side")),
    named, rows, zeros,
    tabs: [...document.querySelectorAll("#page-tabs a")].filter((a) => !a.hidden)
      .map((a) => a.textContent.replace(/\s+/g, " ").trim()),
    strip: (() => {
      const row = document.getElementById("pictures");
      if (!row || row.hidden) return null;
      return { thumbs: [...row.querySelectorAll("a.thumb")].map((a) => ({ href: a.getAttribute("href"),
        current: a.getAttribute("aria-current") === "true" })),
      add: Boolean(row.querySelector("[data-add-picture]:not([hidden])")), box: box(row) };
    })(),
    // Its owner's Add a picture: in the strip, or over the picture while
    // there is no strip (site275: a strip shown for it alone moved the page).
    addPicture: (() => {
      const add = document.querySelector("[data-add-picture]");
      return add && !add.hidden ? (add.closest("#pictures") ? "strip" : "picture") : "";
    })(),
    // The page's last cards, and any count of none said in words.
    lastCards: (() => {
      const rows = [...document.querySelectorAll("main .next")];
      return rows.length ? rows[rows.length - 1].querySelectorAll(".model").length : 0;
    })(),
    noneSaid: (document.querySelector("main")?.innerText.match(/(^|[^\d,])0 (comments?|builds?|built|remix(es)?|likes?|views?|photos?)\b/g) || []),
    empties: {
      comments: document.querySelector("#comments .comment-list .none")?.textContent || "",
      commentsWayIn: Boolean([...document.querySelectorAll("#comments .comment-why button, #comments form.comment-new")]
        .find((el) => !el.hidden && el.getClientRects().length)),
      commentsLines: [...document.querySelectorAll("#comments p.note:not(.owner-line), #comments li.note")]
        .filter((el) => !el.hidden && el.getClientRects().length && el.textContent.trim()).length,
      builds: document.querySelector("#builds .no-builds")?.textContent || "",
      buildsLines: [...document.querySelectorAll("#builds > p")].filter((el) => el.getClientRects().length && el.textContent.trim()).length,
      buildsWayIn: Boolean([...document.querySelectorAll("#builds [data-add-build]")].find((el) => el.getClientRects().length)),
      remixes: document.querySelector("#remixes .none")?.textContent.replace(/\s+/g, " ").trim() || "",
      remixesWayIn: Boolean(document.querySelector('#remixes .none a[href^="/app?copy="]')),
    },
    // The old paragraph that said what View in 3D and Open in Brickworks do.
    paragraph: /View in 3D turns it, steps through its build/.test(document.body.innerText),
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
  };
}

/// 16's pictures: every lot row on screen, once each has its picture or
/// has kept its swatch (data-picture), read pixel by pixel. A picture is a
/// canvas where the swatch was, a part on it (between a twentieth and
/// nineteen twentieths of the square covered, in three shades or more:
/// lit faces and lines), and the lot's colour in it (a third of the part
/// within a shade of it). On the stand-in every lot is drawn; on a
/// deployment's model a part its file carries keeps its swatch, and one
/// lot drawn at the least.
async function lotPictures(page, label, how) {
  const settled = await until(page, () => {
    const pics = [...document.querySelectorAll("#parts .lot:not([hidden]) .pic")].filter((pic) => {
      const r = pic.getBoundingClientRect();
      return r.bottom > 0 && r.top < innerHeight;
    });
    return pics.length > 0 && pics.every((pic) => pic.dataset.picture === "drawn" || pic.dataset.picture === "none");
  }, null, 30000);
  const lots = await page.evaluate(() => [...document.querySelectorAll("#parts .lot:not([hidden])")].filter((li) => {
    const r = li.getBoundingClientRect();
    return r.bottom > 0 && r.top < innerHeight;
  }).map((li) => {
    const pic = li.querySelector(".pic");
    const canvas = pic.querySelector("canvas");
    const hex = (li.querySelector(".meta .swatch rect")?.getAttribute("fill") || "").replace("#", "");
    const row = { part: li.dataset.part, hex, state: pic.dataset.picture || "", swatch: Boolean(pic.querySelector(".swatch")),
      canvas: Boolean(canvas) };
    if (!canvas) return row;
    const { data } = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height);
    const ink = [0, 2, 4].map((at) => parseInt(hex.slice(at, at + 2), 16));
    const inkSq = ink.reduce((a, c) => a + c * c, 0) || 1;
    let covered = 0;
    let near = 0;
    const shades = new Set();
    for (let i = 0; i < data.length; i += 4) {
      if (data[i + 3] < 200) continue;
      covered += 1;
      const px = [data[i], data[i + 1], data[i + 2]];
      shades.add(Math.round((0.2126 * px[0] + 0.7152 * px[1] + 0.0722 * px[2]) / 12));
      // The colour lit or shaded: the nearest of it, a half to six fifths as bright.
      const k = Math.min(Math.max(px.reduce((a, c, n) => a + c * ink[n], 0) / inkSq, 0.5), 1.2);
      if (Math.hypot(...px.map((c, n) => c - k * ink[n])) < 48) near += 1;
    }
    return { ...row, covered: covered / (canvas.width * canvas.height), shades: shades.size, near: covered ? near / covered : 0 };
  }));
  const good = (lot) => lot.state === "drawn" && lot.canvas && !lot.swatch && lot.covered > 0.05 && lot.covered < 0.95
    && lot.shades >= 3 && lot.near >= 0.33;
  const drawn = lots.filter((lot) => lot.state === "drawn");
  const said = lots.map((lot) => `${lot.part} #${lot.hex} ${lot.state}${lot.canvas ? ` ${Math.round(lot.covered * 100)}% covered, `
    + `${lot.shades} shades, ${Math.round(lot.near * 100)}% its colour` : ""}`).join("; ");
  check(`${label}: each lot on screen its part ${how}, in its colour (${said || "none"})`,
    settled && lots.length > 0 && drawn.length > 0 && drawn.every(good)
      && (remote ? lots.every((lot) => lot.state === "drawn" || (lot.state === "none" && lot.swatch)) : drawn.length === lots.length));
}

/// 16. The Parts section, the shops' lists and the file, on [page].
async function partsChecks(page, label, seen, one) {
  const before = await page.evaluate(() => {
    const section = document.getElementById("parts");
    if (!section) return null;
    const list = section.querySelector(".lot-list");
    return { busy: list.getAttribute("aria-busy"), height: section.getBoundingClientRect().height,
      drawn: document.documentElement.dataset.parts || "", note: section.querySelector(".note").textContent,
      at: section.dataset.parts,
      // Shown beside their icons on a tablet or a laptop; on a phone the
      // row of six has room for icons and counts alone.
      words: [...document.querySelectorAll("#marks .icon-btn.labelled .word")]
        .filter((w) => innerWidth <= 600 || w.getClientRects().length).map((w) => w.textContent),
      download: document.querySelector('.side .actions a[download]')?.getAttribute("href") || "",
      // When the list was asked for, against the page's load: never with
      // the page itself, nor before what the first screen shows.
      asked: performance.getEntriesByType("resource").find((r) => r.name.includes("/parts.json"))?.startTime ?? null,
      loaded: performance.getEntriesByType("navigation")[0]?.loadEventStart ?? null,
      painted: performance.getEntriesByName("first-contentful-paint")[0]?.startTime ?? null };
  });
  check(`${label}: a Parts section (${before ? before.note : "none"})`, Boolean(before));
  if (!before) return;
  const total = Number((/^([\d,]+) parts?/.exec(before.note) || [])[1]?.replace(/,/g, ""));
  const tab = seen.tabs.find((t) => t.startsWith("Parts")) || "";
  check(`${label}: its tab (${tab}) and its section say one count, ${total}`, tab === `Parts ${total.toLocaleString("en-US")}`);
  check(`${label}: Like and I built it say their names beside their icons on a tablet or a laptop (${before.words.join(", ")})`,
    JSON.stringify(before.words) === JSON.stringify(["Like", "Built"]));
  // With its words the row is wider: on a laptop it may take a second row
  // for More where the counts are long, never more, and never past the column.
  const bar = await page.evaluate(() => {
    const bar = document.getElementById("marks").getBoundingClientRect();
    const all = [...document.querySelectorAll("#marks > button, #marks > details")].map((el) => el.getBoundingClientRect());
    return { rows: new Set(all.map((r) => Math.round(r.top))).size, inside: all.every((r) => r.right <= bar.right + 0.5) };
  });
  check(`${label}: the action bar in ${bar.rows} row${bar.rows === 1 ? "" : "s"}, inside its column`,
    bar.rows <= 2 && bar.inside && (seen.viewport.width > 600 || bar.rows === 1));
  check(`${label}: the list its own request, once the page has loaded (asked at ${before.asked === null ? "none yet"
    : Math.round(before.asked)} ms, loaded at ${Math.round(before.loaded)} ms, first paint at ${Math.round(before.painted)} ms)`,
  before.loaded !== null && (before.asked === null ? before.busy === "true" : before.asked >= before.loaded));
  await page.evaluate(() => document.getElementById("parts").scrollIntoView({ block: "start" }));
  const drawn = await until(page, () => document.documentElement.dataset.parts === "drawn", null, 20000);
  check(`${label}: the list drawn once it nears the screen`, drawn);
  if (!drawn) return;
  const after = await page.evaluate(() => {
    const section = document.getElementById("parts");
    const rows = [...section.querySelectorAll(".lot-list li")];
    return { height: section.getBoundingClientRect().height, shown: rows.filter((li) => !li.hidden).length,
      groups: rows.filter((li) => li.classList.contains("group")).length,
      firstGroup: rows[0]?.classList.contains("group"), pictures: section.querySelectorAll(".lot-list img").length,
      all: Boolean(section.querySelector("[data-all]:not([hidden])")) };
  });
  check(`${label}: drawn into the space kept for it (${Math.round(before.height)} px before, ${Math.round(after.height)} after)`,
    Math.abs(after.height - before.height) < 0.5);
  check(`${label}: ${after.shown} rows shown, a colour's row first, no picture loaded from anywhere (${after.pictures})`,
    after.shown > 0 && after.shown <= 12 && after.firstGroup && after.pictures === 0);
  // Each lot's picture, drawn on the page (site304): only images from the
  // site itself, and a fetch only to it and its own Supabase project.
  const sources = (name) => (new RegExp(`(?:^|;)\\s*${name}\\s+([^;]*)`).exec(seen.policy || "") || [])[1]?.trim().split(/\s+/) || [];
  const project = remote ? remoteDb : stand.DB;
  check(`${label}: its policy lets in pictures from itself alone (img-src ${sources("img-src").join(" ")}) and talks to itself and its project (connect-src ${sources("connect-src").join(" ")})`,
    JSON.stringify(sources("img-src")) === JSON.stringify(["'self'"])
      && sources("connect-src").every((one) => one === "'self'" || one === project) && sources("connect-src").includes("'self'"));
  await lotPictures(page, label, "drawn from its geometry");
  if (after.all) await page.click("#parts [data-all]");
  const counted = await page.evaluate(() => {
    const qty = [...document.querySelectorAll("#parts .lot-list .lot .qty")].map((q) => Number(q.textContent.replace(/[^\d]/g, "")));
    return { lots: qty.length, sum: qty.reduce((a, b) => a + b, 0), hidden: document.querySelectorAll("#parts .lot-list li[hidden]").length };
  });
  check(`${label}: Show all shows every lot, and their counts add up to ${total} (${counted.sum} in ${counted.lots} lots)`,
    counted.sum === total && counted.hidden === 0);
  await page.click('#parts [data-group="kind"]');
  const kind = await page.evaluate(() => ({ pressed: document.querySelector('#parts [data-group="kind"]').getAttribute("aria-pressed"),
    first: document.querySelector("#parts .lot-list li.group span")?.textContent || "" }));
  check(`${label}: Kind groups them by kind (first: ${kind.first})`, kind.pressed === "true" && Boolean(kind.first));
  await page.click('#parts [data-group="colour"]');
  await page.evaluate(() => document.getElementById("parts").scrollIntoView({ block: "start" }));
  await lotPictures(page, label, "again by Colour, from what was drawn");
  // The shops' lists and the file, as a visitor's browser fetches them.
  const got = await page.evaluate(async ({ at, download }) => {
    const ask = async (href) => {
      const answer = await fetch(href);
      return { status: answer.status, type: answer.headers.get("content-type") || "", named: answer.headers.get("content-disposition") || "",
        text: await answer.text() };
    };
    const xml = await ask(at.replace(/json$/, "xml"));
    const csv = await ask(at.replace(/json$/, "csv"));
    const json = await (await fetch(at)).json();
    const file = await ask(download);
    const doc = new DOMParser().parseFromString(xml.text, "application/xml");
    const items = [...doc.querySelectorAll("INVENTORY > ITEM")].map((item) => ({
      type: item.querySelector("ITEMTYPE")?.textContent, id: item.querySelector("ITEMID")?.textContent,
      colour: item.querySelector("COLOR")?.textContent, qty: item.querySelector("MINQTY")?.textContent,
      fields: [...item.children].map((c) => c.tagName).join(",") }));
    return { xml: { ...xml, text: xml.text.slice(0, 300), wellFormed: !doc.querySelector("parsererror"),
      root: doc.documentElement.tagName, items }, csv: { ...csv, lines: csv.text.trim().split("\n") },
      left: json.left_out, file };
  }, { at: before.at, download: before.download });
  // The file as it is stored: the viewer's own answer on a deployment
  // (api/share.js gives the model's text as stored), the stand-in's bucket
  // here.
  let stored = stand.BRICKS;
  if (remote) {
    const id = one.path.split("/")[2];
    const v = /\/v\/(\d+)\.mpd$/.exec(before.download)?.[1];
    stored = (await (await fetch(`${remote}/api/share?id=${id}${v ? `&v=${v}` : ""}`, { headers })).json()).model || "";
  }
  got.file.same = Buffer.from(got.file.text).equals(Buffer.from(stored));
  got.file.length = Buffer.byteLength(got.file.text);
  const listed = got.xml.items.reduce((a, item) => a + Number(item.qty), 0);
  check(`${label}: the BrickLink wanted list is well-formed XML in INVENTORY, each ITEM ITEMTYPE P, ITEMID, a numbered COLOR and MINQTY (${got.xml.items.length} items, ${got.xml.named})`,
    got.xml.status === 200 && got.xml.wellFormed && got.xml.root === "INVENTORY" && /xml/.test(got.xml.type)
      && got.xml.items.length > 0 && got.xml.items.every((i) => i.type === "P" && i.id && /^\d+$/.test(i.colour) && /^[1-9]\d*$/.test(i.qty)
        && i.fields === "ITEMTYPE,ITEMID,COLOR,MINQTY") && /attachment; filename="[a-z0-9-]+-bricklink\.xml"/.test(got.xml.named));
  check(`${label}: its items, ${got.xml.items.length}, are the lots less the ${got.left.bricklink} it left off`,
    got.xml.items.length === counted.lots - got.left.bricklink && listed <= total);
  const rows = got.csv.lines.slice(1);
  check(`${label}: the Rebrickable CSV is Part,Color,Quantity, a lot a row (${rows.length}, ${got.left.rebrickable} left off, ${got.csv.named})`,
    got.csv.status === 200 && got.csv.lines[0] === "Part,Color,Quantity" && rows.every((r) => /^[^,]+,\d+,[1-9]\d*$/.test(r))
      && rows.length === counted.lots - got.left.rebrickable && /attachment; filename="[a-z0-9-]+-rebrickable\.csv"/.test(got.csv.named));
  check(`${label}: Download is the stored file byte for byte, signed out (${got.file.length} bytes, ${got.file.named})`,
    got.file.status === 200 && got.file.same && got.file.length > 0 && /attachment; filename="[a-z0-9-]+(-v\d+)?\.mpd"/.test(got.file.named));
  await page.evaluate(() => window.scrollTo(0, 0));
}

/// 17. The model in 3D, here, on [page] (the picture on screen).
async function threeD(page, label, stem, phone) {
  const frameOf = () => {
    const box = (el) => {
      if (!el || el.hidden) return null;
      const r = el.getBoundingClientRect();
      return [r.left, r.top, r.width, r.height].map((n) => Math.round(n));
    };
    const b = window.brickworks3d;
    return { picture: box(document.querySelector(".model-page .picture")), shell: box(document.querySelector(".model-page .view3d")),
      height: document.documentElement.scrollHeight, y: scrollY, state: b?.state || "", full: Boolean(b?.full),
      engaged: b?.engaged ? b.engaged() : null, touch: b?.touchAction ? b.touchAction() : "", angle: b?.angle ? b.angle() : null,
      viewport: [innerWidth, innerHeight] };
  };
  const before = await page.evaluate(() => {
    const frame = document.querySelector(".model-page .picture");
    return { asked: performance.getEntriesByType("resource").map((r) => r.name).filter((n) => /viewer3d|three/.test(n)),
      loaded: Boolean(window.brickworks3d), scene: frame?.dataset.scene || "", control: frame?.querySelector(".go")?.textContent || "",
      role: frame?.getAttribute("role") || "", name: frame?.getAttribute("aria-label") || "" };
  });
  check(`${label}: none of the 3D view's code asked for before View in 3D is used (${before.asked.join(", ") || "none"})`,
    before.asked.length === 0 && !before.loaded);
  check(`${label}: the picture says View in 3D (${before.control}), a button named "${before.name}", its scene ${before.scene}`,
    before.control === "View in 3D" && before.role === "button" && /^View .+ in 3D, here$/.test(before.name)
      && /^\/(m\/[A-Za-z0-9]{10}(\/v\/\d+)?|library\/[^/]+)\/scene\.json$/.test(before.scene));
  if (!before.scene) return;
  const was = await page.evaluate(frameOf);
  if (phone) await page.tap(".model-page .picture .go");
  else await page.click(".model-page .picture .go");
  const drawn = () => until(page, () => {
    const b = window.brickworks3d;
    return b && (b.timings.complete3d || b.state === "failed" || b.state === "big");
  }, null, 180000);
  let came = await drawn();
  // Past what this device turns smoothly: it asks first, and is told to.
  const asked = await page.evaluate(() => (window.brickworks3d.state === "big"
    ? document.querySelector(".view3d-said")?.textContent || "" : ""));
  if (asked) {
    check(`${label}: a model this big asks first ("${asked}")`, /Turn it anyway/.test(asked) && /Open in the app/.test(asked));
    await page.click(".view3d-said button");
    came = await drawn();
  }
  const got = await page.evaluate(() => {
    const b = window.brickworks3d;
    const code = performance.getEntriesByType("resource").find((r) => /\/viewer3d\.js/.test(r.name));
    return { state: b.state, timings: b.timings, parts: b.parts, shapes: b.shapes, triangles: b.triangles, scene: b.sceneBytes,
      geometry: b.geometryBytes, errors: b.errors, sample: b.sample ? b.sample() : null, shown: b.shown ? b.shown() : 0,
      code: code ? { sent: code.transferSize, body: code.encodedBodySize, size: code.decodedBodySize } : null,
      tools: [...document.querySelectorAll(".view3d-tools [data-act]")].map((t) => t.getAttribute("aria-label")),
      app: (() => { const a = document.querySelector(".view3d-app"); return a && !a.hidden ? `${a.textContent} ${a.getAttribute("href")}` : ""; })(),
      href: document.querySelector(".model-page .picture").getAttribute("href"),
      said: document.querySelector(".view3d-said")?.textContent || "" };
  });
  const after = await page.evaluate(frameOf);
  const t = got.timings || {};
  const from = (k) => (t[k] && t.asked ? `${((t[k] - t.asked) / 1000).toFixed(2)} s` : "-");
  const kb = (n) => `${Math.round((n || 0) / 1024)} KB`;
  check(`${label}: View in 3D draws the model here (${got.state}${got.said ? `, "${got.said}"` : ""}): ${got.parts} parts, ${got.shapes} shapes, `
    + `${((got.triangles || 0) / 1e6).toFixed(2)}M triangles; code ${got.code ? `${kb(got.code.sent)} sent, ${kb(got.code.size)}` : "?"} `
    + `in ${from("code")}, scene ${kb(got.scene)}, geometry ${kb(got.geometry)}; first frame ${from("first3d")}, all drawn ${from("complete3d")}`,
  came && got.state === "ready" && got.code && got.code.size > 100000 && got.parts > 0 && got.shown === got.parts && !got.errors.length);
  check(`${label}: a frame with the model in it, whole (${got.sample ? `${(got.sample.drawn * 100).toFixed(1)}% of it, ${got.sample.colours} colours${got.sample.cut ? ", cut off at an edge" : ""}` : "none"})`,
    Boolean(got.sample && got.sample.drawn > 0.01 && !got.sample.cut));
  check(`${label}: in the picture's frame (${after.shell} over ${was.picture}), nothing on the page moved (${was.height} px tall, then ${after.height})`,
    JSON.stringify(after.shell) === JSON.stringify(was.picture) && JSON.stringify(after.picture) === JSON.stringify(was.picture)
      && after.height === was.height && after.y === was.y);
  check(`${label}: its tools named: ${got.tools.join(", ")}; and ${got.app || "no way into the app"}`,
    JSON.stringify(got.tools) === JSON.stringify(["Zoom out", "Zoom in", "Reset the view", "Full screen", "Back to the picture"])
      && got.app === `Open in the app ${got.href}`);
  if (out) await page.screenshot({ path: path.join(out, `${stem}_3d.png`) });
  if (got.state !== "ready") return;
  const near = (a, b) => a && b && Math.abs(a.round - b.round) < 1e-3 && Math.abs(a.up - b.up) < 1e-3
    && Math.abs(a.distance - b.distance) < b.distance * 1e-3;
  const home = after.angle;
  if (phone) {
    // Before taking hold: a swipe up it scrolls the page, the model as it
    // was. A finger's own touches (as phone_flow.mjs drags), not a scroll
    // gesture: headless Chromium scrolls nothing with one of those.
    const cdp = await page.context().newCDPSession(page);
    const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: points.map(([x, y], i) => ({ x, y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
    const drag = async (a, b, steps = 12) => {
      await touch("touchStart", [a]);
      for (let n = 1; n <= steps; n++) {
        await touch("touchMove", [[a[0] + ((b[0] - a[0]) * n) / steps, a[1] + ((b[1] - a[1]) * n) / steps]]);
        await page.waitForTimeout(30);
      }
      await touch("touchEnd", []);
    };
    const middle = [after.shell[0] + after.shell[2] / 2, after.shell[1] + after.shell[3] / 2];
    await drag(middle, [middle[0], middle[1] - 260]);
    await page.waitForTimeout(300);
    const swiped = await page.evaluate(frameOf);
    check(`${label}: before it is taken hold of (touch-action ${after.touch}), a swipe up it scrolls the page (${swiped.y} px) and leaves the model as it was`,
      after.touch === "pan-y" && after.engaged === false && swiped.y > 100 && near(swiped.angle, home));
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(200);
    await drag([middle[0] + 80, middle[1]], [middle[0] - 80, middle[1]]);
    await page.waitForTimeout(300);
    const turned = await page.evaluate(frameOf);
    check(`${label}: a swipe across turns it (${home.round.toFixed(2)} to ${turned.angle?.round.toFixed(2)}), and it is the person's now (touch-action ${turned.touch}), the page where it was (${turned.y} px)`,
      turned.angle && Math.abs(turned.angle.round - home.round) > 0.05 && turned.engaged === true && turned.touch === "none" && turned.y === 0);
    await cdp.detach();
    await page.tap('.view3d-tools [data-act="reset"]');
    await page.waitForTimeout(150);
    const reset = await page.evaluate(frameOf);
    check(`${label}: Reset the view goes back to where it started`, near(reset.angle, home));
  } else {
    await page.focus(".model-page .view3d .stage");
    await page.keyboard.press("ArrowRight");
    const turned = await page.evaluate(frameOf);
    await page.keyboard.press("+");
    const nearer = await page.evaluate(frameOf);
    await page.keyboard.press("0");
    const back = await page.evaluate(frameOf);
    check(`${label}: the keys: an arrow turns it (${home.round.toFixed(2)} to ${turned.angle.round.toFixed(2)}), + brings it nearer (${Math.round(turned.angle.distance)} to ${Math.round(nearer.angle.distance)}), 0 goes back to the start`,
      Math.abs(turned.angle.round - home.round) > 0.2 && nearer.angle.distance < turned.angle.distance * 0.9 && near(back.angle, home));
    await page.keyboard.press("ArrowUp");
    await page.mouse.move(after.shell[0] + after.shell[2] * 0.4, after.shell[1] + after.shell[3] * 0.5);
    await page.mouse.down();
    await page.mouse.move(after.shell[0] + after.shell[2] * 0.6, after.shell[1] + after.shell[3] * 0.45, { steps: 6 });
    await page.mouse.up();
    const dragged = await page.evaluate(frameOf);
    await page.click('.view3d-tools [data-act="reset"]');
    await page.waitForTimeout(150);
    const reset = await page.evaluate(frameOf);
    check(`${label}: a drag turns it (${home.round.toFixed(2)} to ${dragged.angle.round.toFixed(2)}), Reset the view goes back to the start`,
      Math.abs(dragged.angle.round - home.round) > 0.05 && near(reset.angle, home));
  }
  // Full screen, and back into the frame.
  await page.click('.view3d-tools [data-act="full"]');
  await until(page, () => window.brickworks3d.full && window.brickworks3d.fullscreen !== "window", null, 8000);
  await page.waitForTimeout(300);
  const full = await page.evaluate(() => {
    const r = document.querySelector(".model-page .view3d").getBoundingClientRect();
    const b = document.querySelector('.view3d-tools [data-act="full"]');
    return { box: [r.left, r.top, r.width, r.height].map(Math.round), viewport: [innerWidth, innerHeight], full: window.brickworks3d.full,
      how: window.brickworks3d.fullscreen, pressed: b.getAttribute("aria-pressed"), name: b.getAttribute("aria-label"),
      sample: window.brickworks3d.sample(), angle: window.brickworks3d.angle() };
  });
  if (out) await page.screenshot({ path: path.join(out, `${stem}_3d_full.png`) });
  check(`${label}: Full screen fills the screen (${full.box} in ${full.viewport}, the ${full.how}'s), pressed, "${full.name}", the model drawn whole, fitted to it (${full.sample ? (full.sample.drawn * 100).toFixed(1) : 0}%${full.sample?.cut ? ", cut off at an edge" : ""}, ${Math.round(home.distance)} to ${Math.round(full.angle?.distance)} away)`,
    full.full && full.box[0] === 0 && full.box[1] === 0 && full.box[2] >= full.viewport[0] - 1 && full.box[3] >= full.viewport[1] - 1
      && full.pressed === "true" && full.name === "Leave full screen" && full.sample && full.sample.drawn > 0.01 && !full.sample.cut);
  await page.click('.view3d-tools [data-act="full"]');
  await until(page, () => !window.brickworks3d.full && !document.fullscreenElement, null, 8000);
  await page.waitForTimeout(300);
  const left = await page.evaluate(frameOf);
  check(`${label}: and leaving it puts it back in the frame (${left.shell}), as it started`, !left.full && JSON.stringify(left.shell) === JSON.stringify(was.picture)
    && near(left.angle, home));
  await page.click('.view3d-tools [data-act="close"]');
  await page.waitForTimeout(200);
  const closed = await page.evaluate(frameOf);
  check(`${label}: Back to the picture puts the picture back (${closed.state})`, closed.state === "closed" && closed.shell === null
    && JSON.stringify(closed.picture) === JSON.stringify(was.picture));
}

const browser = await launch({ signedOut: true });
const errors = [];
try {
  for (const one of PAGES) {
    for (const signedIn of [false, true]) {
      for (const width of widths) {
        for (const theme of themes) {
          const who = signedIn ? "in" : "out";
          const label = `${one.name} ${width} ${theme} ${who}`;
          const stem = `${one.name}_${width}_${theme}_${who}`;
          const phone = width < 600;
          console.log(label);
          const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 },
            colorScheme: theme, extraHTTPHeaders: headers,
            ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
          await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb });
          // A deployment's own comments, asked as a visitor: the stand-in
          // knows none of its models.
          if (remote) {
            await context.route((url) => url.origin === new URL(remote).origin && url.pathname === "/api/people"
              && url.searchParams.get("op") === "comments", (route) => {
              const { authorization, ...rest } = route.request().headers();
              return route.continue({ headers: { ...rest, ...headers } });
            });
          }
          // What the page copies, and what it gives a share sheet, kept for
          // this flow to read: the clipboard of a page on plain http is not
          // the page's to use, nor to read back here.
          await context.addInitScript(() => {
            window.__copied = [];
            const keep = async (text) => { window.__copied.push(String(text)); };
            try {
              Object.defineProperty(navigator, "clipboard", { configurable: true, value: { writeText: keep } });
              Object.defineProperty(window, "isSecureContext", { configurable: true, value: true });
            } catch { /* kept as it is */ }
          });
          if (signedIn) {
            const kept = JSON.parse(asProject(JSON.stringify(stand.signedInStorage())));
            await context.addInitScript(([session, access]) => {
              try {
                localStorage.setItem("brickworks.session", session);
                sessionStorage.setItem("brickworks.access", access);
              } catch { /* a browser that keeps nothing */ }
            }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
          }
          const page = await context.newPage();
          page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
          page.on("console", (m) => {
            if (m.type() === "error" && /Content Security Policy|Refused|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
              errors.push(`${label}: ${m.text().slice(0, 200)}`);
            }
          });
          try {
            const visited = await page.goto(base + one.path, { waitUntil: "load", timeout: 60000 });
            // Signed in, the lists asked for; and the comments listed, which
            // say Comment's count.
            await until(page, () => !document.getElementById("comments")?.hidden
              || document.documentElement.dataset.commentsReady === "no", null, 8000);
            await page.waitForTimeout(400);
            if (out) await page.screenshot({ path: path.join(out, `${stem}-fold.png`) });
            const seen = await page.evaluate(read);
            seen.policy = visited?.headers()["content-security-policy"] || "";
            const vh = seen.viewport.height;

            // 1. Media first.
            const onScreen = (b) => b && b.top >= 0 && b.bottom <= vh + 0.5;
            if (phone) {
              check(`${label}: the picture leads (${Math.round(seen.picture?.top)} px down) and is above the name`,
                seen.picture && seen.picture.top < 200 && seen.picture.bottom <= seen.title.top);
              check(`${label}: the picture, name, designer and action bar on the first screen (bar ends at ${Math.round(seen.bar?.bottom)} of ${vh})`,
                onScreen(seen.picture) && onScreen(seen.title) && (!one.designer || onScreen(seen.designer)) && onScreen(seen.bar));
            } else {
              check(`${label}: the picture and the column beside it on the first screen`,
                onScreen(seen.picture) && seen.side && seen.side.left >= seen.picture.right && onScreen(seen.title) && onScreen(seen.bar));
              await page.evaluate(() => window.scrollTo(0, 1200));
              await page.waitForTimeout(200);
              const later = await page.evaluate(() => {
                const r = document.querySelector(".model-page .side").getBoundingClientRect();
                const rest = document.querySelector(".model-page .rest").getBoundingClientRect();
                return { top: r.top, bottom: r.bottom, restBottom: rest.bottom, scrolled: scrollY };
              });
              // Only while there is page beside it: a short page ends first.
              check(`${label}: the column stays on screen as the page scrolls (top at ${Math.round(later.top)} px after ${later.scrolled} px)`,
                later.restBottom <= later.bottom + 1 || (later.top >= 0 && later.top < 120));
              await page.evaluate(() => window.scrollTo(0, 0));
            }
            check(`${label}: nothing sideways`, !seen.sideways);

            // The designer.
            if (one.designer) {
              check(`${label}: the designer, ${seen.designerName}, with an avatar and a link to their profile (${seen.designerLink})`,
                seen.designerName === one.designer && seen.avatar && /^\/u\/[a-z0-9-]+$/.test(seen.designerLink));
            }

            // 2. The action bar.
            const labels = seen.named.map((b) => b.label);
            const names = labels.map((l) => l.split(",")[0]);
            check(`${label}: the action bar says ${labels.join(" | ")}`,
              JSON.stringify(names) === JSON.stringify(["Like", "Save", "Share", "Comment", "I built it", "More"]));
            const counted = seen.named.filter((b) => b.label.includes(","));
            check(`${label}: each count beside its icon as its label says it (${counted.map((b) => b.n).join(", ") || "none"})`,
              counted.every((b) => b.label.includes(` ${b.n} `)) && seen.named.every((b) => b.n === "" || b.label.includes(",")));
            check(`${label}: no count of none (${seen.zeros.join(", ") || "none"})`, !seen.zeros.length && seen.named.every((b) => b.n !== "0"));
            if (!remote && one.name === "watchtower") {
              check(`${label}: its counts are the stand-in's (96 likes, 37 builds, 6 comments and replies)`,
                labels.includes("Like, 96 likes") && labels.includes("I built it, 37 builds") && labels.includes("Comment, 6 comments"));
            }
            check(`${label}: the paragraph explaining the buttons is gone`, !seen.paragraph);

            // 6. What comes next.
            if (one.by !== null) {
              check(`${label}: More by ${one.by ? `shows ${one.by}` : "is not shown"} (${seen.rows["more-by"]}), Similar ${one.like ? `shows ${one.like}` : "is not shown"} (${seen.rows.similar})`,
                seen.rows["more-by"] === one.by && seen.rows.similar === one.like);
              check(`${label}: More in the gallery ${one.gallery ? "shows, with neither row" : "is not shown"} (${seen.rows["from-gallery"]})`,
                one.gallery ? seen.rows["from-gallery"] >= 1 && seen.rows["from-gallery"] <= 6 : seen.rows["from-gallery"] === 0);
            } else {
              check(`${label}: More by (${seen.rows["more-by"]}) and Similar (${seen.rows.similar}) each none or three to six`,
                [seen.rows["more-by"], seen.rows.similar].every((n) => n === 0 || (n >= 3 && n <= 6)));
            }
            // 11. Another model to open, at the end.
            check(`${label}: the last screen has another model to open (${seen.lastCards} cards in its last row)`, seen.lastCards >= 1);

            // 8. The tabs.
            const tabNames = seen.tabs.map((t) => t.replace(/ [\d,]+$/, ""));
            // On a deployment its own model's: in this order, each there or
            // not as the model has it (Comments where they are open,
            // Collections once it is in one, Versions with two), and About,
            // Parts, Builds and Remixes always.
            const ORDER = ["About", "Parts", "Comments", "Builds", "Remixes", "Collections", "Versions"];
            const ordered = tabNames.every((n, k) => ORDER.includes(n) && (k === 0 || ORDER.indexOf(tabNames[k - 1]) < ORDER.indexOf(n)));
            check(`${label}: the tabs say ${seen.tabs.join(" | ")}`, one.tabs ? JSON.stringify(seen.tabs) === JSON.stringify(one.tabs)
              : ordered && ["About", "Parts", "Builds", "Remixes"].every((n) => tabNames.includes(n)));

            // 16. Its parts, signed out.
            if (!signedIn) await partsChecks(page, label, seen, one);
            // 17. In 3D, here: once a pass, signed out.
            if (!signedIn && (remote || one.name === "watchtower")) await threeD(page, label, stem, phone);

            // 9. The strip of its pictures.
            if (one.thumbs !== undefined && !(signedIn && one.owner)) {
              check(`${label}: the strip has ${seen.strip ? seen.strip.thumbs.length : "no"} pictures (${one.thumbs || "none"} wanted), the published one first and marked`,
                one.thumbs ? seen.strip?.thumbs.length === one.thumbs && seen.strip.thumbs[0].current
                  && !seen.strip.thumbs[0].href.startsWith("#") && seen.strip.thumbs.slice(1).every((t) => t.href.startsWith("#photo-"))
                  && !seen.strip.add : seen.strip === null);
            } else if (seen.strip) {
              check(`${label}: the strip's first picture is the published one, marked`, seen.strip.thumbs[0]?.current === true);
            }
            if (seen.strip && seen.strip.thumbs.length > 1) {
              await page.click("#pictures a.thumb:nth-of-type(2)");
              await page.waitForTimeout(150);
              const big = await page.evaluate(() => ({ src: document.querySelector(".model-page .picture img").getAttribute("src"),
                photo: document.querySelector(".model-page .picture").classList.contains("photo"),
                current: document.querySelector("#pictures a.thumb:nth-of-type(2)").getAttribute("aria-current"),
                first: document.querySelector("#pictures a.thumb").getAttribute("aria-current"), y: scrollY }));
              check(`${label}: choosing a photo in the strip shows it in the picture's place, whole (${big.src})`,
                /op=photo_file&id=[A-Za-z0-9]{10}$/.test(big.src) && big.photo && big.current === "true" && big.first === null && big.y === 0);
              if (out) await page.screenshot({ path: path.join(out, `${stem}_photo.png`) });
              await page.click("#pictures a.thumb:nth-of-type(1)");
            }
            if (signedIn && one.owner) {
              check(`${label}: its owner has Add a picture, in the strip or over the picture while it has no photo (${seen.addPicture || "none"}, ${JSON.stringify(seen.strip?.thumbs.length ?? 0)} pictures)`,
                seen.addPicture === (seen.strip ? "strip" : "picture"));
              await page.click("[data-add-picture]");
              const formOpen = await until(page, () => !document.querySelector("#builds .build-form").hidden, null, 4000);
              check(`${label}: Add a picture opens the photo form`, formOpen);
              await page.click("#builds .build-form [data-cancel]").catch(() => {});
            }

            // 10. Nothing yet, said once, with the way in.
            check(`${label}: no count of none said in words (${seen.noneSaid.join(", ") || "none"})`, !seen.noneSaid.length);
            if (one.empty) {
              const e = seen.empties;
              check(`${label}: no comments is one line, "${e.comments}", and the way in`,
                e.comments === "Nobody has commented yet." && e.commentsLines === 1 && e.commentsWayIn);
              check(`${label}: no builds is one line, "${e.builds}", and the way in`,
                e.builds.startsWith("Nobody has built it yet.") && e.buildsLines === 1 && e.buildsWayIn);
              check(`${label}: no remixes is one line, "${e.remixes.slice(0, 40)}…", and the way in`,
                e.remixes.startsWith("Nobody has remixed it yet.") && e.remixesWayIn);
            }

            // 8b. A tab chosen: its part just under the tabs, the tabs on
            // screen under the header, it marked; the page scrolled on, the
            // tabs still there.
            // Comments, or where comments are not open, Builds.
            const target = await page.evaluate(() => (document.querySelector('#page-tabs a[data-tab="comments"]').hidden
              ? "builds" : "comments"));
            await page.click(`#page-tabs a[data-tab="${target}"]`);
            await settled(page);
            const went = await page.evaluate((key) => {
              const tabs = document.getElementById("page-tabs").getBoundingClientRect();
              const head = document.querySelector(".site-head").getBoundingClientRect();
              const part = document.getElementById(key).getBoundingClientRect();
              const end = innerHeight + scrollY >= document.documentElement.scrollHeight - 2;
              return { tabsTop: tabs.top, tabsBottom: tabs.bottom, head: head.bottom, part: part.top, end,
                current: document.querySelector("#page-tabs [aria-current]")?.dataset.tab };
            }, target);
            check(`${label}: the ${target} tab brings its part under the tabs (${Math.round(went.part)} px, tabs ${Math.round(went.tabsTop)}-${Math.round(went.tabsBottom)}), marked ${went.current}`,
              went.current === target && Math.abs(went.tabsTop - went.head) <= 2
              && (went.end || (went.part >= went.tabsBottom - 1 && went.part <= went.tabsBottom + 40)));
            await page.mouse.wheel(0, 500);
            await settled(page);
            const later = await page.evaluate(() => ({ top: document.getElementById("page-tabs").getBoundingClientRect().top,
              head: document.querySelector(".site-head").getBoundingClientRect().bottom,
              rest: document.querySelector(".model-page .rest").getBoundingClientRect().bottom,
              current: document.querySelector("#page-tabs [aria-current]")?.dataset.tab }));
            check(`${label}: scrolled on, the tabs stay under the header (${Math.round(later.top)} px), marking ${later.current}`,
              Boolean(later.current) && (Math.abs(later.top - later.head) <= 2 || later.rest < later.head + 120));
            if (out) await page.screenshot({ path: path.join(out, `${stem}_tabs.png`) });

            // 12. Comments that talk.
            if (one.threads) {
              const t = await page.evaluate(() => {
                const top = [...document.querySelectorAll("#comments .comment-list > li.comment")];
                const pill = (li) => li.querySelector(":scope > .comment-main > .comment-head a.pill.step");
                return {
                  threads: top.map((li) => li.id),
                  replies: Object.fromEntries(top.map((li) => [li.id,
                    [...li.querySelectorAll(":scope > .comment-main > .replies > li.comment.reply")].map((r) => r.id)])),
                  avatars: [...document.querySelectorAll("#comments li.comment")].every((li) => li.querySelector(":scope > .avatar")),
                  all: document.querySelectorAll("#comments li.comment").length,
                  designer: [...document.querySelectorAll("#comments li.comment")].filter((li) => li.querySelector(
                    ":scope > .comment-main > .comment-head .pill.designer")?.textContent === "Designer").map((li) => li.id),
                  steps: Object.fromEntries(top.filter(pill).map((li) => [li.id, [pill(li).textContent, pill(li).getAttribute("href")]])),
                  box: !document.querySelector("#comments form.comment-new").hidden,
                  send: document.querySelector("#comments form.comment-new button[type=submit]").textContent,
                  replyButtons: [...document.querySelectorAll("#comments .comment-acts button")].filter((b) => b.textContent === "Reply").length,
                  wide: document.documentElement.scrollWidth > innerWidth + 1,
                };
              });
              check(`${label}: the newest thread first (${t.threads.join(", ")}) and replies oldest first under it (${t.replies["comment-103"]?.join(", ")})`,
                JSON.stringify(t.threads) === JSON.stringify(["comment-103", "comment-102", "comment-101"])
                && JSON.stringify(t.replies["comment-103"]) === JSON.stringify(["comment-109", "comment-110"])
                && JSON.stringify(t.replies["comment-101"]) === JSON.stringify(["comment-108"]));
              check(`${label}: an avatar on each of the ${t.all}, Designer on Robin's (${t.designer.join(", ")})`,
                t.avatars && t.all === 6 && JSON.stringify(t.designer.sort()) === JSON.stringify(["comment-102", "comment-108", "comment-109"]));
              check(`${label}: a step is a pill to the viewer there: ${Object.entries(t.steps).map(([k, [w, h]]) => `${k} ${w} ${h}`).join("; ")}`,
                t.steps["comment-103"]?.[0] === "Step 5" && t.steps["comment-103"]?.[1] === `/app?view=${stand.MODEL_ID}&step=5`
                && /^Step 3/.test(t.steps["comment-101"]?.[0] || "") && /[?&]step=3$/.test(t.steps["comment-101"]?.[1] || "")
                && !t.steps["comment-102"]);
              check(`${label}: the box is shown (${t.send}), Reply on each of the 3 comments (${t.replyButtons}), nothing wider than the screen`,
                t.box && t.send === (signedIn ? "Add the comment" : "Sign in and add it") && t.replyButtons === 3 && !t.wide);
              await page.click("#comment-103 > .comment-main > .comment-acts button:text-is('Reply')");
              const boxed = await until(page, () => document.activeElement?.closest?.("#comment-103 form.reply-new"), null, 4000);
              check(`${label}: Reply opens a box under Priya's thread, ready to type`, boxed);
              await page.fill("#comment-103 form.reply-new textarea", "Thank you: under, then it clicks.");
              if (out) await page.locator("#comments").screenshot({ path: path.join(out, `${stem}_comments.png`) }).catch(() => {});
              await page.click("#comment-103 form.reply-new button[type=submit]");
              if (!signedIn) {
                const asked = await until(page, () => document.querySelector("dialog.sign-in[open]"), null, 6000);
                check(`${label}: signed out, Reply asks to sign in first`, asked);
                await page.keyboard.press("Escape");
                const kept = await page.evaluate(() => document.querySelector("#comment-103 form.reply-new textarea")?.value);
                check(`${label}: and what was typed is kept ("${kept}")`, kept === "Thank you: under, then it clicks.");
              } else {
                const went = await until(page, () => document.querySelector("#comments .comments-said")?.textContent === "Replied."
                  && !document.querySelector("#comments form.reply-new"), null, 6000);
                check(`${label}: signed in, the reply goes ("Replied.") and its box closes`, went);
              }
            }
            await page.evaluate(() => window.scrollTo(0, 0));
            await page.waitForTimeout(150);
            if (out) await page.screenshot({ path: path.join(out, `${stem}.png`), fullPage: true, timeout: 60000 }).catch(() => {});

            // 3. Share: its sheet, the link and the embed code each copied,
            // and said in the sheet.
            await page.click("#marks [data-share]");
            const opened = await until(page, () => document.querySelector("dialog.share-sheet[open]"), null, 4000);
            const sheetNow = await page.evaluate(() => {
              const link = document.getElementById("share-link");
              return { link: link?.value || "", selected: document.activeElement === link
                && link.selectionStart === 0 && link.selectionEnd === link.value.length,
              app: !document.querySelector("[data-share-app]")?.hidden, url: `${location.origin}${location.pathname}` };
            });
            check(`${label}: Share opens its sheet, the link ${sheetNow.link} selected, no other app's sheet offered here`,
              opened && sheetNow.link === sheetNow.url && sheetNow.selected && !sheetNow.app);
            if (out) await page.screenshot({ path: path.join(out, `${stem}_share.png`) });
            await page.click('dialog.share-sheet [data-copy="share-link"]');
            await until(page, () => document.querySelector("dialog.share-sheet .said")?.textContent, null, 4000);
            const copied = await page.evaluate(() => ({ copied: window.__copied.at(-1) || "",
              said: document.querySelector("dialog.share-sheet .said")?.textContent || "", url: `${location.origin}${location.pathname}` }));
            check(`${label}: Copy link copies it (${copied.copied || "nothing"}) and says "${copied.said}"`,
              copied.copied === copied.url && copied.said === "Link copied");
            await page.click('dialog.share-sheet [data-copy="share-embed"]');
            await until(page, () => /Embed/.test(document.querySelector("dialog.share-sheet .said")?.textContent || ""), null, 4000);
            const embedded = await page.evaluate(() => ({ copied: window.__copied.at(-1) || "",
              shown: document.getElementById("share-embed")?.value || "", said: document.querySelector("dialog.share-sheet .said")?.textContent || "" }));
            check(`${label}: Copy code puts the iframe on the clipboard, as the sheet shows it, and says "${embedded.said}"`,
              /^<iframe src="https?:\/\/[^"]+\/m\/[A-Za-z0-9]{10}\/embed"/.test(embedded.copied) && embedded.copied === embedded.shown
                && /^Embed code copied/.test(embedded.said));
            await page.keyboard.press("Escape");
            const closed = await until(page, () => !document.querySelector("dialog.share-sheet[open]")
              && document.activeElement?.matches("#marks [data-share]"), null, 4000);
            check(`${label}: Escape closes it, back on Share`, closed);

            // 5. More.
            await page.click("#more > summary");
            const more = await page.evaluate(() => [...document.querySelectorAll("#more .menu-list > *")]
              .filter((el) => !el.hidden && el.getClientRects().length).map((el) => el.textContent.trim()));
            const owns = signedIn && one.owner;
            check(`${label}: More holds ${more.join(" | ")}`, [owns ? "How your models are doing" : "Report it",
              "Takedown requests"].every((want) => more.includes(want)) && (!owns || !more.includes("Report it"))
              && !more.includes("Copy the embed code"));
            if (out) await page.screenshot({ path: path.join(out, `${stem}_more.png`) });
            await page.keyboard.press("Escape");

            // 14. In N collections: the pill and the tab, to a card each.
            const lists = await page.evaluate(() => ({
              pill: document.querySelector('.facts a[href="#collections"]')?.textContent || "",
              tab: (document.querySelector('#page-tabs a[data-tab="collections"]')?.textContent || "").replace(/\s+/g, " ").trim(),
              cards: [...document.querySelectorAll("#collections .list-card")].map((card) => card.getAttribute("href")) }));
            const n = one.lists ?? Number((/^In (\d+) collections?$/.exec(lists.pill) || [])[1] || 0);
            check(`${label}: "${lists.pill || "no collections"}", ${lists.cards.length} cards (${lists.cards.join(" ")})`,
              n ? lists.pill === `In ${n} collection${n === 1 ? "" : "s"}` && lists.tab === `Collections ${n}`
                && lists.cards.length === Math.min(n, 12) && lists.cards.every((href) => /^\/c\/[A-Za-z0-9]{10}$/.test(href))
                : !lists.pill && !lists.tab && lists.cards.length === 0);
            if (n) {
              await page.click('.facts a[href="#collections"]');
              await settled(page);
              const at = await page.evaluate(() => Math.round(document.getElementById("collections").getBoundingClientRect().top));
              check(`${label}: the pill brings its collections into view (${at} px down)`, at >= 0 && at < 300);
              await page.evaluate(() => window.scrollTo(0, 0));
            }

            // 4. Save.
            await page.click('#marks [data-mark="save"]');
            if (!signedIn) {
              const asked = await until(page, () => document.querySelector("dialog.sign-in[open]"), null, 6000);
              check(`${label}: Save asks to sign in`, asked);
              await page.keyboard.press("Escape");
              await page.click('#marks [data-mark="like"]');
              check(`${label}: Like asks to sign in`, await until(page, () => document.querySelector("dialog.sign-in[open]"), null, 6000));
              await page.keyboard.press("Escape");
            } else {
              const opened = await until(page, () => !document.getElementById("save-panel")?.hidden
                && document.querySelectorAll("#save-panel .collect-list label").length > 1, null, 6000);
              const lists = await page.evaluate(() => [...document.querySelectorAll("#save-panel .collect-list label")]
                .map((row) => ({ name: row.querySelector("span").textContent, on: row.querySelector("input").checked })));
              const save = await page.evaluate(() => document.querySelector('#marks [data-mark="save"]').getAttribute("aria-expanded"));
              check(`${label}: Save opens the lists, Favourites first${one.favourite === null ? "" : `, ${one.favourite ? "ticked" : "not ticked"}`}: `
                + lists.map((l) => `${l.name}${l.on ? " ✓" : ""}`).join(", "),
              opened && save === "true" && lists[0]?.name === "Favourites" && (one.favourite === null || lists[0].on === one.favourite));
              if (out) await page.screenshot({ path: path.join(out, `${stem}_save.png`) });
            }

            // 3b. A browser with a share sheet of its own, a phone's: the
            // sheet offers it, and gives it the link.
            await page.evaluate(() => {
              window.__sheet = null;
              navigator.share = async (data) => { window.__sheet = data; };
              navigator.canShare = () => true;
              window.__copied = [];
            });
            await page.click("#marks [data-share]");
            const offered = await until(page, () => !document.querySelector("dialog.share-sheet[open] [data-share-app]")?.hidden, null, 4000);
            if (offered) await page.click("dialog.share-sheet [data-share-app]");
            await page.waitForTimeout(200);
            const sheet = await page.evaluate(() => ({ sheet: window.__sheet, copied: window.__copied.length,
              open: Boolean(document.querySelector("dialog.share-sheet[open]")), url: `${location.origin}${location.pathname}` }));
            check(`${label}: with a share sheet of its own, Share offers it, gives it the link (${sheet.sheet?.url}), copies nothing and closes`,
              offered && sheet.sheet?.url === sheet.url && sheet.copied === 0 && !sheet.open);
          } catch (trouble) {
            check(`${label}: visited (${String(trouble).split("\n")[0]})`, false);
          } finally {
            await context.close();
          }
        }
      }
    }
  }

  // 15. The embed in the theme its viewer chose: on a computer set to one,
  // the other chosen on the site (web/theme.js), and none chosen.
  {
    const id = PAGES[0]?.path.split("/")[2];
    const ground = {};
    // The iframe the share sheet gives is 560 x 420, and max-width 100%: in
    // a phone's column, some 340 wide.
    for (const [system, chosen, width] of [["light", null, 560], ["dark", null, 560], ["dark", "light", 560],
      ["light", "dark", 560], ["light", null, 340], ["dark", null, 340]]) {
      const label = `the embed ${width}, ${system} computer, ${chosen ? `${chosen} chosen` : "nothing chosen"}`;
      const context = await browser.newContext({ viewport: { width, height: 420 }, colorScheme: system, extraHTTPHeaders: headers });
      await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb });
      if (chosen) await context.addInitScript((theme) => { try { localStorage.setItem("brickworks.theme", theme); } catch {} }, chosen);
      const page = await context.newPage();
      page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
      page.on("console", (m) => {
        if (m.type() === "error" && /Content Security Policy|Refused/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 200)}`);
      });
      try {
        await page.goto(`${base}/m/${id}/embed`, { waitUntil: "load", timeout: 60000 });
        const seen = await page.evaluate(() => ({ ground: getComputedStyle(document.body).backgroundColor,
          ink: getComputedStyle(document.querySelector(".embed-bar b")).color, theme: document.documentElement.dataset.theme || "" }));
        const card = await page.evaluate(() => {
          const shown = (el) => Boolean(el) && getComputedStyle(el).display !== "none" && el.getClientRects().length > 0;
          const said = (a) => a ? { href: a.getAttribute("href"), tab: a.target === "_blank", text: a.textContent.trim(),
            shown: shown(a), right: a.getBoundingClientRect().right, left: a.getBoundingClientRect().left } : null;
          return { build: said(document.querySelector(".embed-bar a.cta")), view: said(document.querySelector(".embed-bar a.link")),
            name: said(document.querySelector(".embed-bar a.words")), picture: said(document.querySelector("a.picture")),
            wide: document.documentElement.scrollWidth, room: innerWidth };
        });
        if (width === 560) {
          check(`${label}: its button is Build it, the guided build at step 1 (${card.build?.href}), in a tab of its own`,
            card.build?.text.startsWith("Build it") && card.build?.href === `${base}/app?view=${id}&build` && card.build?.tab);
          check(`${label}: View in 3D a quiet link to the viewer (${card.view?.href})`,
            card.view?.shown && card.view?.text.startsWith("View in 3D") && card.view?.href === `${base}/app?view=${id}` && card.view?.tab);
          check(`${label}: its picture and its name the model's page (${card.picture?.href}, ${card.name?.href})`,
            card.picture?.href === `${base}/m/${id}` && card.name?.href === `${base}/m/${id}` && card.picture?.tab && card.name?.tab);
        } else {
          check(`${label}: the bar fits (${card.wide} of ${card.room} px), Build it whole (${Math.round(card.build?.left)} to `
            + `${Math.round(card.build?.right)}), the name beside it (${card.name ? Math.round(card.name.right - card.name.left) : 0} px)`,
            card.wide <= card.room && card.build?.shown && card.build.left >= 0 && card.build.right <= card.room
            && card.name?.shown && card.name.right - card.name.left >= 80);
        }
        if (width === 560 && !chosen) {
          ground[system] = seen;
          check(`${label}: the computer's (${seen.ground}, its name in ${seen.ink})`, seen.theme === "");
        } else if (width === 560) {
          check(`${label}: ${chosen} (${seen.ground}, its name in ${seen.ink})`, seen.theme === chosen
            && seen.ground === ground[chosen]?.ground && seen.ink === ground[chosen]?.ink && ground.light?.ground !== ground.dark?.ground);
        }
        if (out) await page.screenshot({ path: path.join(out, `embed_${width}_${system}_${chosen || "none"}.png`) });
      } catch (trouble) {
        check(`${label}: visited (${String(trouble).split("\n")[0]})`, false);
      } finally {
        await context.close();
      }
    }
  }

  // 13. Build it starts the build at step 1 (?build: the step player, not the
  // viewer on the finished model; walk180 W3), and View in 3D is the viewer.
  // The picture slow to come, as a first view right after publishing was:
  // the frame says it is coming, never a blank grey frame (walk180 S2); and a
  // picture that fails once is asked again.
  const first = PAGES[0];
  for (const width of widths) {
    for (const theme of themes) {
      const label = `${first.name} ${width} ${theme}, its picture slow`;
      const phone = width < 600;
      const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 },
        colorScheme: theme, extraHTTPHeaders: headers,
        ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
      await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api"), remote, headers, remoteDb });
      const id = first.path.split("/")[2];
      let release = () => {};
      const held = new Promise((done) => { release = done; });
      let asked = 0;
      const failOnce = width === widths[0] && theme === themes[0];
      await context.route((url) => url.pathname === `/m/${id}.cutout.png`, async (route) => {
        asked += 1;
        // The first view's, failed once where this checks the asking again,
        // and held until this lets it go.
        if (asked === 1 && failOnce) return route.fulfill({ status: 404, contentType: "text/plain", body: "" });
        await held;
        return route.fallback();
      });
      const page = await context.newPage();
      page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
      try {
        await page.goto(base + first.path, { waitUntil: "domcontentloaded", timeout: 60000 });
        const links = await page.evaluate(() => ({
          build: document.querySelector(".model-page .actions a.cta:not(.ghost)")?.getAttribute("href") || "",
          view: document.querySelector(".model-page a.picture")?.getAttribute("href") || "",
        }));
        check(`${label}: Build it starts the build at step 1 (${links.build}), View in 3D is the viewer (${links.view})`,
          links.build === `/app?view=${id}&build` && links.view === `/app?view=${id}`);
        await page.waitForTimeout(1500);
        const waiting = await page.evaluate(() => {
          const frame = document.querySelector(".model-page .picture");
          const img = frame?.querySelector("img");
          const sign = frame?.querySelector(".waiting");
          const shown = sign && getComputedStyle(sign).display !== "none" && sign.getClientRects().length > 0;
          return { drawn: Boolean(img && img.complete && img.naturalWidth > 0), sign: shown ? sign.textContent.trim() : "" };
        });
        check(`${label}: while its picture comes, the frame says so ("${waiting.sign}"), not a blank frame`,
          !waiting.drawn && waiting.sign.length > 0);
        if (out) await page.locator(".model-page .picture").screenshot({
          path: path.join(out, `picture_waiting_${width}_${theme}.png`) }).catch(() => {});
        release();
        const came = await until(page, () => {
          const frame = document.querySelector(".model-page .picture");
          const img = frame?.querySelector("img");
          const sign = frame?.querySelector(".waiting");
          return img && img.complete && img.naturalWidth > 0
            && (!sign || getComputedStyle(sign).display === "none");
        }, null, 15000);
        check(`${label}: then the picture, and nothing over it${failOnce ? `, asked again after it failed (${asked} asks)` : ""}`,
          came && (!failOnce || asked >= 2));
        if (out) await page.locator(".model-page .picture").screenshot({
          path: path.join(out, `picture_came_${width}_${theme}.png`) }).catch(() => {});
      } catch (trouble) {
        check(`${label}: visited (${String(trouble).split("\n")[0]})`, false);
      } finally {
        release();
        await context.close();
      }
    }
  }
} finally {
  await browser.close();
}
for (const error of errors) check(`no script error: ${error}`, false);
console.log(`\nmodel page flow: ${passed} passed, ${failed} failed`);
if (!passed) process.exit(1);
process.exit(failed ? 1 : 0);
