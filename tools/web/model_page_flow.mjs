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
//   3. Share puts the page's link on the clipboard and says "Link copied";
//      where the browser has a share sheet (navigator.share), the sheet
//      instead, given the link, and nothing copied.
//   4. Save, signed out, asks to sign in; signed in, it opens the lists,
//      Favourites first and ticked when it is a favourite.
//   5. More holds Copy the embed code (the iframe on the clipboard), Report
//      it and Takedown requests.
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
    tabs: ["About", "Comments 3", "Builds 37", "Remixes 3", "Versions 2"], thumbs: 3 },
  { name: "dusk", path: "/m/DesignRmx1", by: 0, like: 3, favourite: false, designer: "Jo Lindqvist",
    tabs: ["About", "Comments 1", "Builds 3", "Remixes", "Versions"].slice(0, 4), thumbs: 0 },
  // Signed in, Sam's own: More has the owner's own in place of Report it.
  { name: "bakery", path: "/m/SamModel02", by: 0, like: 0, gallery: true, favourite: false, designer: null,
    tabs: ["About", "Comments", "Builds", "Remixes"], thumbs: 0, empty: true, owner: true },
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
    document.getElementById(key) ? document.querySelectorAll(`#${key} a.model`).length : 0]));
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
      add: !row.querySelector("[data-add-picture]").hidden, box: box(row) };
    })(),
    // The page's last cards, and any count of none said in words.
    lastCards: (() => {
      const rows = [...document.querySelectorAll("main .next")];
      return rows.length ? rows[rows.length - 1].querySelectorAll("a.model").length : 0;
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
            await page.goto(base + one.path, { waitUntil: "load", timeout: 60000 });
            // Signed in, the lists asked for; and the comments listed, which
            // say Comment's count.
            await until(page, () => !document.getElementById("comments")?.hidden
              || document.documentElement.dataset.commentsReady === "no", null, 8000);
            await page.waitForTimeout(400);
            if (out) await page.screenshot({ path: path.join(out, `${stem}-fold.png`) });
            const seen = await page.evaluate(read);
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
              check(`${label}: its counts are the stand-in's (96 likes, 37 builds, 3 comments)`,
                labels.includes("Like, 96 likes") && labels.includes("I built it, 37 builds") && labels.includes("Comment, 3 comments"));
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
            const wantNames = ["About", "Comments", "Builds", "Remixes", "Versions"].slice(0, tabNames.includes("Versions") ? 5 : 4);
            check(`${label}: the tabs say ${seen.tabs.join(" | ")}`, one.tabs ? JSON.stringify(seen.tabs) === JSON.stringify(one.tabs)
              : JSON.stringify(tabNames) === JSON.stringify(wantNames) || JSON.stringify(tabNames) === JSON.stringify(wantNames.filter((n) => n !== "Comments")));

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
              check(`${label}: its owner has Add a picture in the strip, shown though it has no photo (${JSON.stringify(seen.strip?.thumbs.length)} pictures)`,
                Boolean(seen.strip?.add));
              await page.click("#pictures [data-add-picture]");
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
            await page.click('#page-tabs a[data-tab="comments"]');
            await settled(page);
            const went = await page.evaluate(() => {
              const tabs = document.getElementById("page-tabs").getBoundingClientRect();
              const head = document.querySelector(".site-head").getBoundingClientRect();
              const part = document.getElementById("comments").getBoundingClientRect();
              const end = innerHeight + scrollY >= document.documentElement.scrollHeight - 2;
              return { tabsTop: tabs.top, tabsBottom: tabs.bottom, head: head.bottom, part: part.top, end,
                current: document.querySelector("#page-tabs [aria-current]")?.dataset.tab };
            });
            check(`${label}: the Comments tab brings the comments under the tabs (${Math.round(went.part)} px, tabs ${Math.round(went.tabsTop)}-${Math.round(went.tabsBottom)}), marked ${went.current}`,
              went.current === "comments" && Math.abs(went.tabsTop - went.head) <= 2
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
            await page.evaluate(() => window.scrollTo(0, 0));
            await page.waitForTimeout(150);
            if (out) await page.screenshot({ path: path.join(out, `${stem}.png`), fullPage: true, timeout: 60000 }).catch(() => {});

            // 3. Share: the link copied, and said.
            await page.click("#marks [data-share]");
            const shared = await until(page, () => document.querySelector("body > .toast.shown"), null, 4000);
            const copied = await page.evaluate(() => ({ copied: window.__copied, toast: document.querySelector("body > .toast")?.textContent || "",
              url: `${location.origin}${location.pathname}` }));
            check(`${label}: Share copies the link (${copied.copied[0] || "nothing"}) and says "${copied.toast}"`,
              shared && copied.toast === "Link copied" && copied.copied[0] === copied.url);

            // 5. More.
            await page.click("#more > summary");
            const more = await page.evaluate(() => [...document.querySelectorAll("#more .menu-list > *")]
              .filter((el) => !el.hidden && el.getClientRects().length).map((el) => el.textContent.trim()));
            const owns = signedIn && one.owner;
            check(`${label}: More holds ${more.join(" | ")}`, ["Copy the embed code", owns ? "How your models are doing" : "Report it",
              "Takedown requests"].every((want) => more.includes(want)) && (!owns || !more.includes("Report it")));
            if (out) await page.screenshot({ path: path.join(out, `${stem}_more.png`) });
            await page.click("#more [data-embed]");
            await page.waitForTimeout(150);
            const embed = await page.evaluate(() => window.__copied.at(-1) || "");
            check(`${label}: Copy the embed code puts the iframe on the clipboard`,
              /^<iframe src="https?:\/\/[^"]+\/m\/[A-Za-z0-9]{10}\/embed"/.test(embed));

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

            // 3b. A browser with a share sheet: the sheet, with the link.
            await page.evaluate(() => {
              window.__sheet = null;
              navigator.share = async (data) => { window.__sheet = data; };
              navigator.canShare = () => true;
              window.__copied = [];
            });
            await page.click("#marks [data-share]");
            await page.waitForTimeout(200);
            const sheet = await page.evaluate(() => ({ sheet: window.__sheet, copied: window.__copied.length,
              url: `${location.origin}${location.pathname}` }));
            check(`${label}: with a share sheet, Share opens it with the link (${sheet.sheet?.url}) and copies nothing`,
              sheet.sheet?.url === sheet.url && sheet.copied === 0);
          } catch (trouble) {
            check(`${label}: visited (${String(trouble).split("\n")[0]})`, false);
          } finally {
            await context.close();
          }
        }
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
