// Share a model by link, open the link with no account, and take it down,
// in real browsers against a deployment.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/share_flow.mjs --url=<deployment>/app --out=shots/share_web
//   node tools/web/relay_server.mjs 8790 --static=build/web &   # or a local export
//   node tools/web/share_flow.mjs --url=http://127.0.0.1:8790/app --out=shots/share_local
//
// As people do it, by pressing what the app shows (it publishes where its
// controls are, window.brickworksControls, and what it is showing,
// window.brickworksShare):
//
//   1. The owner, signed in (a throwaway account), with the example model
//      on the baseplate, presses Share, names it, ticks Show who made it,
//      and Publish: a link, /m/<id>.
//   2. A browser that has never signed in opens the link: the link's page
//      (og:title, og:image) goes straight on to the viewer, which shows the
//      model, its name, author and part count, with no sign-in screen and
//      the address left at the link. The steps scrub (Start, Next, End),
//      the part under the pointer is named, the parts list opens and gives
//      BrickLink and Rebrickable lists, the booklet opens in a tab. A click,
//      a drag and the editing keys change nothing, and nothing is written
//      to the browser's storage. The link's card renders in a page of
//      somebody else's, in an iframe.
//   3. Open in Brickworks from there: the sign-in screen, then, signed in
//      as a second throwaway account, the model copied into their models.
//   4. The owner presses Unpublish: the link's page, and the viewer, say
//      the model is no longer shared.
//
// Pictures in --out, 1_shared.png to 11_viewer_unpublished.png, and the
// link's own picture as og_image.png. Both accounts are deleted at the end,
// and their rows with them; the model was taken down first, so no file
// is left in the bucket.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import http from "node:http";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const appUrl = String(args.url || "https://brickworks.diy/app");
const site = new URL(appUrl).origin;
const out = args.out || "shots/share_web";
const bypass = process.env.BW_BYPASS || "";
const NAME = "Share Flow Car";
const AUTHOR = "Flow Builder";
mkdirSync(out, { recursive: true });

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const rand = randomBytes(4).toString("hex");
const owner = `delivered+bw-share-owner-${rand}@resend.dev`;
const copier = `delivered+bw-share-copier-${rand}@resend.dev`;

const browser = await launch({ signedOut: true });
const headers = bypass ? { "x-vercel-protection-bypass": bypass } : {};

async function context({ as = null } = {}) {
  const made = await browser.newContext({ viewport: { width: 1400, height: 900 },
    acceptDownloads: true, extraHTTPHeaders: headers });
  if (as) await keepSession(made, as);
  return made;
}

async function keepSession(made, email) {
  const { kept } = await mintSession(email);
  await made.addInitScript(([name, value]) => {
    try {
      if (!localStorage.getItem(name)) localStorage.setItem(name, value);
    } catch {}
  }, [STORAGE_KEY, JSON.stringify(kept)]);
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    const text = m.text();
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(text)) {
      errors.push(`${who}: ${text.slice(0, 220)}`);
    }
  });
}

const state = (page) => page.evaluate(() => window.brickworksShare || {});
const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

async function press(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const at = (await controls(page))[name];
    if (at) {
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(400);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

async function type(page, name, text) {
  await press(page, name);
  await page.keyboard.press("Control+A");
  await page.keyboard.type(text, { delay: 20 });
}

// Not fatal: on SwiftShader under load one frame can outlast a screenshot's
// patience, and a picture missed says nothing about the feature.
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function fetchText(url) {
  const reply = await fetch(url, { headers, redirect: "manual" });
  return { status: reply.status, type: reply.headers.get("content-type") || "",
    csp: reply.headers.get("content-security-policy") || "",
    bytes: Buffer.from(await reply.arrayBuffer()) };
}

let id = "";
let link = "";
let ownerPage = null;
let madeCopier = false;
try {
  // --- 1. The owner shares
  console.log("the owner shares the model on the baseplate");
  const ownerContext = await context({ as: owner });
  ownerPage = await ownerContext.newPage();
  listen(ownerPage, "owner");
  await ownerPage.goto(appUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  await until(ownerPage, () => (window.brickworksAccount || {}).state === "signed_in",
    "the owner signed in");
  await until(ownerPage, () => (window.brickworksState || {}).bricks > 0, "a model on the baseplate");
  // The example's parts arrive over the network after it opens.
  await ownerPage.waitForTimeout(Number(args.load || 15000));
  const bricks = (await ownerPage.evaluate(() => window.brickworksState)).bricks;
  await press(ownerPage, "tool_share");
  await until(ownerPage, () => (window.brickworksShare.panel || {}).open, "the Share panel");
  await type(ownerPage, "share_name", NAME);
  await press(ownerPage, "share_credit");
  await type(ownerPage, "share_author", AUTHOR);
  await press(ownerPage, "share_publish");
  const panel = await until(ownerPage, () => {
    const p = (window.brickworksShare || {}).panel || {};
    return p.state === "published" || p.state === "failed" ? p : null;
  }, "publishing", 180);
  check(`published: ${panel.status}`, panel.state === "published");
  id = panel.id;
  link = panel.url;
  check(`a link at this deployment: ${link}`, link === `${site}/m/${id}` && /^[A-Za-z0-9]{10}$/.test(id));
  check("and an embed snippet", String(panel.embed).startsWith(`<iframe src="${site}/m/${id}/embed"`));
  await shot(ownerPage, "1_shared.png");

  const page = await fetchText(link);
  const html = page.bytes.toString("utf8");
  check(`the link's page: ${page.status}, og:title and og:image`, page.status === 200
    && html.includes(`<meta property="og:title" content="${NAME} — a Brickworks model">`)
    && html.includes(`<meta property="og:image" content="${link}.png">`));
  check(`...crediting ${AUTHOR} with the part count`, html.includes(`by ${AUTHOR}`) && /\d+ parts/.test(html));
  const picture = await fetchText(`${link}.png`);
  check(`its picture: ${picture.status} ${picture.type}, ${Math.round(picture.bytes.length / 1024)} KB`,
    picture.status === 200 && picture.type === "image/png" && picture.bytes.length > 1000);
  if (picture.status === 200) writeFileSync(path.join(out, "og_image.png"), picture.bytes);

  // --- 2. Somebody with no account opens it
  console.log("a browser that never signed in opens the link");
  const visitorContext = await context();
  const visitor = await visitorContext.newPage();
  listen(visitor, "visitor");
  await visitor.goto(link, { waitUntil: "domcontentloaded", timeout: 120000 });
  const viewing = await until(visitor, () => {
    const v = (window.brickworksShare || {}).view || {};
    return v.state === "ready" || v.state === "gone" || v.state === "failed" ? v : null;
  }, "the viewer", 300);
  check(`the viewer opened the model: ${viewing.name}, ${viewing.parts} parts, by ${viewing.author}`,
    viewing.state === "ready" && viewing.name === NAME && viewing.author === AUTHOR && viewing.parts === bricks);
  const account = await visitor.evaluate(() => window.brickworksAccount || {});
  check(`with no sign-in screen (${account.state}, gated ${account.gated})`, account.gated === false
    && account.state !== "signed_in");
  check(`every part standing (${(await visitor.evaluate(() => window.brickworksState)).bricks} of ${bricks})`,
    (await visitor.evaluate(() => window.brickworksState)).bricks === bricks);
  check(`the address is the link (${visitor.url()})`, visitor.url() === link);
  const view = await state(visitor);
  check("read-only: the store writes nothing", view.read_only === true && view.keeps === false);
  // Count every write the app makes to the browser's storage from here on.
  await visitor.evaluate(() => {
    window.__writes = [];
    const was = window.brickworksWrote;
    window.brickworksWrote = (p, s) => {
      window.__writes.push(p);
      return was ? was(p, s) : undefined;
    };
  });
  const names = Object.keys(await controls(visitor));
  check("its bar: Steps, Booklet, Parts list, Open in Brickworks",
    ["view_steps", "view_booklet", "view_parts", "view_copy"].every((n) => names.includes(n)));
  check(`and nothing of the builder's (${names.filter((n) => /^(new|open|save|tool_|menu_|share_|parts_rail|assistant_rail)/.test(n)).join(", ") || "none"})`,
    !names.some((n) => /^(new|open|save|tool_|menu_|share_|parts_rail|assistant_rail)/.test(n)));
  await shot(visitor, "2_viewer.png");

  console.log("the steps");
  let steps = (await state(visitor)).steps || [];
  check(`the timeline is up at the finished model (${steps})`, steps.length === 2 && steps[0] === steps[1] && steps[1] > 0);
  await press(visitor, "steps_start");
  await visitor.waitForTimeout(1500);
  const atStart = (await state(visitor)).steps;
  await press(visitor, "steps_next");
  await press(visitor, "steps_next");
  await visitor.waitForTimeout(1500);
  steps = (await state(visitor)).steps;
  check(`Start empties the baseplate, Next builds it up (${atStart[0]}, then ${steps[0]} of ${steps[1]})`,
    atStart[0] === 0 && steps[0] > 0 && steps[0] < steps[1]);
  await shot(visitor, "3_steps.png");
  await press(visitor, "steps_end");
  await visitor.waitForTimeout(1000);

  console.log("the part under the pointer");
  const middle = (await controls(visitor)).view;
  let named = "";
  for (const [dx, dy] of [[0, 0], [0, 40], [30, 20], [-30, 20], [0, -30], [60, 40], [-60, 40]]) {
    await visitor.mouse.move(middle.x + dx, middle.y + dy, { steps: 4 });
    await visitor.waitForTimeout(1200);
    named = (await state(visitor)).view.hover;
    if (named) break;
  }
  check(`it is named: ${named}`, Boolean(named));
  await shot(visitor, "4_hover.png");

  console.log("the parts list");
  await press(visitor, "view_parts");
  await until(visitor, () => window.brickworksShare.parts_open, "the parts list");
  await shot(visitor, "5_parts.png");
  for (const [button, ext, needle] of [["parts_bricklink", ".xml", "<INVENTORY>"], ["parts_rebrickable", ".csv", ","]]) {
    const coming = visitor.waitForEvent("download", { timeout: 60000 });
    await press(visitor, button);
    const download = await coming.catch(() => null);
    const file = download ? path.join(out, download.suggestedFilename()) : "";
    if (download) await download.saveAs(file);
    const body = file ? readFileSync(file, "utf8") : "";
    check(`${button.replace("parts_", "")} gives ${download ? download.suggestedFilename() : "nothing"}`,
      file.endsWith(ext) && body.includes(needle));
  }
  await press(visitor, "parts_done");

  console.log("the booklet");
  const tabComing = visitorContext.waitForEvent("page", { timeout: 60000 });
  await press(visitor, "view_booklet");
  const tab = await tabComing.catch(() => null);
  let pages = 0;
  if (tab) {
    listen(tab, "booklet");
    const end = Date.now() + 600000;
    while (Date.now() < end && pages === 0) {
      pages = await tab.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0);
      if (!pages) await tab.waitForTimeout(2000);
    }
    if (pages) {
      await tab.waitForTimeout(1500);
      await shot(tab, "6_booklet.png");
    }
  }
  check(`it opens in a tab, ${pages} pages`, pages > 0);

  console.log("nothing that edits");
  const before = await visitor.evaluate(() => window.brickworksState.bricks);
  await visitor.mouse.click(middle.x, middle.y + 30);
  await visitor.mouse.move(middle.x, middle.y);
  await visitor.mouse.down();
  await visitor.mouse.move(middle.x + 140, middle.y, { steps: 8 });
  await visitor.mouse.up();
  for (const key of ["Delete", "Backspace", "q", "r", "x", "Control+z", "Control+v", "Control+d", "Control+s"]) {
    await visitor.keyboard.press(key);
    await visitor.waitForTimeout(200);
  }
  await visitor.waitForTimeout(4000);
  const after = await visitor.evaluate(() => ({ bricks: window.brickworksState.bricks,
    selected: window.brickworksState.selected, writes: window.__writes,
    session: localStorage.getItem("brickworks.session") }));
  check(`a click, a drag and Delete, Q, R, X, Ctrl Z/V/D/S change nothing (${after.bricks} bricks, ${after.selected} selected)`,
    after.bricks === before && after.selected === 0);
  check(`nothing written to the browser's storage (${after.writes.length} writes)`, after.writes.length === 0);
  check("and no session kept", after.session === null);

  console.log("the card, in somebody else's page");
  const card = await fetchText(`${link}/embed`);
  check(`the card: ${card.status}, frameable anywhere`, card.status === 200 && /frame-ancestors \*/.test(card.csp));
  // Somebody else's site: a page of its own origin on this machine, since
  // frame-ancestors * matches only pages served over a network scheme.
  const blogServer = http.createServer((_q, reply) => {
    reply.writeHead(200, { "content-type": "text/html; charset=utf-8" });
    reply.end(`<html><body style="margin:24px;font-family:sans-serif;background:#f6f3ec">
      <h2>My blog post</h2><p>Look what I built:</p>${panel.embed}</body></html>`);
  });
  await new Promise((done) => blogServer.listen(0, "127.0.0.1", done));
  const blog = await visitorContext.newPage();
  listen(blog, "blog");
  await blog.goto(`http://127.0.0.1:${blogServer.address().port}/post.html`, { waitUntil: "load", timeout: 60000 });
  await blog.waitForTimeout(6000);
  blogServer.close();
  const framed = blog.frames().find((f) => f.url().includes(`/m/${id}/embed`));
  const cardText = framed ? await framed.evaluate(() => document.body.innerText).catch(() => "") : "";
  check(`it renders in an iframe: "${cardText.replace(/\s+/g, " ").trim()}"`, cardText.includes(NAME) && cardText.includes("View in 3D"));
  await shot(blog, "7_embed.png");
  await blog.close();

  // --- 3. Open in Brickworks
  console.log("Open in Brickworks");
  await press(visitor, "view_copy");
  await until(visitor, () => (window.brickworksAccount || {}).gated === true, "the sign-in screen", 180);
  check(`it asks the visitor to sign in first (${visitor.url().replace(site, "")})`, visitor.url().includes(`copy=${id}`));
  await shot(visitor, "8_sign_in_to_copy.png");
  // Signed in as a returning visitor would be: the session where the app
  // keeps one, and the same address again.
  madeCopier = true;
  await keepSession(visitorContext, copier);
  // And every file the app writes, so the save into their models is seen.
  await visitorContext.addInitScript(() => {
    let inner;
    window.__writes = [];
    Object.defineProperty(window, "brickworksWrote", {
      configurable: true,
      get() { return inner ? (p, s) => { window.__writes.push(p); return inner(p, s); } : undefined; },
      set(v) { inner = v; },
    });
  });
  await visitor.reload({ waitUntil: "domcontentloaded" });
  const copied = await until(visitor, (want) => {
    const s = window.brickworksShare || {};
    const st = window.brickworksState || {};
    return (window.brickworksAccount || {}).state === "signed_in" && s.title && s.title.startsWith("Share Flow Car")
      && !location.search.includes("copy=") && st.bricks === want
      ? { title: s.title, bricks: st.bricks, search: location.search } : null;
  }, "the copy", 300, bricks);
  // Saved once its parts are all in: the bar says so.
  await visitor.waitForTimeout(4000);
  const copiedNow = await visitor.evaluate(() => ({ bricks: window.brickworksState.bricks, writes: window.__writes || [],
    gated: window.brickworksAccount.gated, viewing: window.brickworksShare.viewing, read_only: window.brickworksShare.read_only }));
  check(`copied into their models as "${copied.title}", ${copiedNow.bricks} parts, editable`,
    copiedNow.bricks === bricks && !copiedNow.read_only && copiedNow.viewing === "" && !copiedNow.gated);
  const kept = copiedNow.writes.find((w) => /models\/Share Flow Car/.test(w)) || "";
  check(`...and saved there (${kept || copiedNow.writes.join(", ") || "nothing written"})`, Boolean(kept));
  await shot(visitor, "9_copied.png");

  // --- 4. Unpublish
  console.log("the owner takes it down");
  await press(ownerPage, "share_unpublish");
  const down = await until(ownerPage, () => {
    const p = (window.brickworksShare || {}).panel || {};
    return p.state === "unpublished" || p.state === "failed" ? p : null;
  }, "unpublishing", 120);
  check(`unpublished: ${down.status}`, down.state === "unpublished");
  await shot(ownerPage, "10a_unpublished_panel.png");
  // Every other page drawn in software was still running: at a load of 66
  // a fresh viewer did not boot in five minutes beside them, and alone it
  // takes about fifteen seconds.
  await visitorContext.close();
  await ownerContext.close();
  const late = await context();
  const lateComer = await late.newPage();
  listen(lateComer, "late");
  const gone = await lateComer.goto(link, { waitUntil: "load", timeout: 120000 });
  await lateComer.waitForTimeout(1500);
  const said = await lateComer.evaluate(() => document.body.innerText);
  check(`the link says so: ${gone.status()} "${said.split("\n")[0]}"`, gone.status() === 410
    && said.includes("This model is no longer shared") && !said.includes(NAME));
  await shot(lateComer, "10_unpublished.png");
  await lateComer.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded", timeout: 120000 });
  const viewerGone = await until(lateComer, () => {
    const v = (window.brickworksShare || {}).view || {};
    return v.state === "gone" || v.state === "ready" ? v : null;
  }, "the viewer of a link taken down", 300);
  check(`and so does the viewer: "${viewerGone.title}"`, viewerGone.state === "gone"
    && viewerGone.title === "This model is no longer shared");
  await shot(lateComer, "11_viewer_unpublished.png");
} catch (trouble) {
  check(String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | "), false);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const e of errors.slice(0, 8)) console.log(`        ${e}`);
  // Taken down if it is still up, then both accounts, and their rows.
  if (id && ownerPage) {
    const { access_token } = await mintSession(owner).catch(() => ({}));
    if (access_token) {
      await fetch(`${site}/api/share?op=unpublish&id=${id}`, { method: "POST",
        headers: { ...headers, authorization: `Bearer ${access_token}` } }).catch(() => {});
    }
  }
  // Each account exists from its first session minted; the copier's only
  // if the flow got that far.
  const goneOwner = await deleteAccount(owner);
  const goneCopier = madeCopier ? await deleteAccount(copier) : true;
  check("the throwaway accounts deleted, and the shared row with them", goneOwner && goneCopier);
  await browser.close();
}
console.log(failed ? `${failed} FAILED` : "a model can be shared by link, looked at by anyone, and taken down");
process.exit(failed ? 1 : 0);
