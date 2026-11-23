// Comments pinned to a part (partpins, 2026-11-23, supabase/comment_pins.sql),
// on a model's page in a real browser: the part pressed in its 3D view is
// the part the pin is on, its numbered dot and its line turn the view to
// it, it follows its part to a new version or says which version it was
// on, its designer's Resolve folds it away within a minute, and a blocked
// person's pins are gone with their comments.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 11400 --static=web --hold=pins &
//   node tools/web/partpins_flow.mjs --url=http://127.0.0.1:11400 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/partpins_flow.mjs --url=<preview> --out=DIR   # once comment_pins.sql is applied
//
// Until supabase/comment_pins.sql is applied, the local relay holds it in
// memory (--hold=pins, tools/web/pins_stand_in.mjs) and sends everything
// else to the real project, where comments.sql and replies.sql are. Two
// throwaway accounts at Resend test addresses, deleted at the end with
// their models (an owner and a commenter, each with a handle), and a
// visitor with no account. Never the site's owner; never brickworks.diy.
//
//   1. The pick: the owner publishes five models of five shapes (house,
//      lighthouse, car, tower, corner_shop); on each, the commenter makes 20
//      right clicks at 1280 x 800 and 20 long presses at 390 x 844 by touch
//      on points over its drawn parts (each a part's middle, projected; a
//      point the viewer's own pick finds nothing at, or under its tools,
//      left out). Each opens the menu; its part (lastPicked) is the one the
//      viewer's pick finds at that point, by its index, number, colour and
//      place; Comment on this part puts the box on it. 200 of 200.
//   2. Three pins on the house through the page's own box, the second on
//      step 1: the server keeps the part pressed; once reloaded, dots 1, 2
//      and 3, each line "on the …", and pin 1's line turns the view to its
//      part (pin_on_site.png).
//   3. Version 2 of the house: pin 1's part moved 20 LDU and pin 2's
//      recoloured. Pin 1 follows its part, "(moved since)"; pin 2 says
//      "on version 1", with no dot and no button; pin 3 is where it was.
//   4. The owner resolves pin 3 as the studio does (op=pin_resolve): a
//      visitor's page, reloaded every 5 s, shows it under Resolved (1) with
//      no dot, within 60 s.
//   5. The owner blocks the commenter: their pins and dots are gone from
//      the owner's page, as their comments are.
//
// Pictures and summary.json in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { placesOf } from "../../api/_parts.js";
import { pinOf, pinPart, pinPlace } from "../../web/card.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11400").replace(/\/+$/, "").replace(/\/app$/, "");
if (/(^|\.)brickworks\.diy$/i.test(new URL(site).hostname)) throw new Error("partpins_flow: never against brickworks.diy");
const out = path.resolve(String(args.out || "shots/partpins"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const ownerEmail = `delivered+bw-partpins-owner-${rand}@resend.dev`;
const writerEmail = `delivered+bw-partpins-writer-${rand}@resend.dev`;
const OWNER = `bwpp-owner-${rand}`;
const WRITER = `bwpp-writer-${rand}`;
const MODELS = ["house", "lighthouse", "car", "tower", "corner_shop"];
const PRESSES = 20;
const SIZES = [{ name: "1280", width: 1280, height: 800, touch: false }, { name: "390", width: 390, height: 844, touch: true }];
const PINS = ["This window wants a sill under it.", "On step 1 this one goes the other way round.", "Lovely roof edge here."];
const MENU = ".view3d-menu [role=menuitem]";

let failed = 0;
const check = (what, ok, detail = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${detail ? ` (${detail})` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const summary = { site, pick: { "1280": { pressed: 0, right: 0 }, "390": { pressed: 0, right: 0 }, misses: [] }, pins: {}, version: {},
  resolve: {}, block: {} };

// A small sure sequence, so a run presses where the one before did.
function random(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}
const apart = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const plus = (a, b) => a.map((v, k) => v + b[k]);

// --- the models ---------------------------------------------------------------

const texts = Object.fromEntries(MODELS.map((name) => [name,
  `${readFileSync(path.join(root, "models", `${name}.ldr`), "utf8").replace(/\s+$/, "")}\r\n0 // partpins flow ${rand}\r\n`]));

/// The index of [lines]'s line placing the part [pin] says ({part, at}):
/// its number, and where it stands within a hundredth of an LDU.
function lineOf(lines, pin) {
  return lines.findIndex((line) => {
    const w = line.trim().split(/\s+/);
    return w[0] === "1" && w.length >= 15 && pinPart(w[14]) === pinPart(pin.part)
      && apart([Number(w[2]), Number(w[3]), Number(w[4])], pin.at) < 0.01;
  });
}
/// [text] with the part [pin] says moved by [by], or recoloured [colour].
function edited(text, pin, { by = null, colour = null }) {
  const lines = text.split(/\r?\n/);
  const at = lineOf(lines, pin);
  if (at < 0) return null;
  const w = lines[at].trim().split(/\s+/);
  if (by) for (let k = 0; k < 3; k += 1) w[2 + k] = String(Number(w[2 + k]) + by[k]);
  if (colour !== null) w[1] = String(colour);
  lines[at] = w.join(" ");
  return lines.join("\r\n");
}
const STEPS = [[20, 0, 0], [-20, 0, 0], [0, 0, 20], [0, 0, -20]];
/// The house's parts a 20 LDU move takes its pin with, by the rule (web/card.js
/// pinPlace) read here: {part, colour, at, by}.
function movable(text) {
  const places = placesOf(text);
  const found = [];
  places.forEach((one, i) => {
    const pin = pinOf(places, i);
    for (const by of STEPS) {
      // Never onto a place another part stands.
      if (places.some((other) => apart(other.at, plus(one.at, by)) <= 2)) continue;
      const next = edited(text, pin, { by });
      if (!next) continue;
      const after = placesOf(next);
      const where = pinPlace(pin, after);
      if (where && where.moved && apart(after[where.index].at, plus(pin.at, by)) < 0.01) {
        found.push({ part: one.part, colour: one.colour, at: one.at, by });
        break;
      }
    }
  });
  return found;
}

// --- helpers --------------------------------------------------------------------

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, height = 800, touch = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers, reducedMotion: "reduce",
    ...(touch ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
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

// The viewport alone: a page's full length drops a touch screen's controls.
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 90000 })
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
    await page.waitForTimeout(250);
  }
}

/// The model's Comments tab pressed as a person presses it (only the chosen
/// tab's panel shows since pagekit; a page opens on Overview), then its
/// comments drawn.
async function toComments(page, touch = false) {
  const tab = '#page-tabs [data-tab="comments"]';
  await until(page, (sel) => document.querySelector(sel)?.checkVisibility() || null, "the Comments tab", 45, tab);
  if (await page.$eval(tab, (a) => a.getAttribute("aria-selected") !== "true")) {
    if (touch) await page.tap(tab);
    else await page.click(tab);
  }
  await until(page, () => {
    const section = document.getElementById("comments");
    return section && !section.hidden && !document.getElementById("comments-hold");
  }, "the comments", 45);
}

/// The model's page with its comments drawn, and its 3D view open and every
/// part in (window.brickworks3d, tools/viewer/inline.js), [pins] of its pins
/// placed.
async function opened(page, id, touch, { v = null, pins = 0 } = {}) {
  await page.goto(`${site}/m/${id}${v ? `/v/${v}` : ""}`, { waitUntil: "load" });
  await toComments(page, touch);
  await page.evaluate(() => document.querySelector(".model-page .picture").scrollIntoView({ block: "center" }));
  if (touch) await page.tap(".model-page .picture");
  else await page.click(".model-page .picture");
  await until(page, (pins) => window.brickworks3d?.state === "ready" && window.brickworks3d.view
    && window.brickworks3d.pins?.placed?.length === pins, "the model in 3D, every part in, its pins placed", 180, pins);
  await page.waitForTimeout(300);
}

/// Brick [i] as the viewer has it, where its middle is on the page, and the
/// brick the viewer's own pick finds there ({x, y, j, brick}), or null for a
/// point off the screen, under something drawn over the model, or on none.
const aimAt = (page, i) => page.evaluate((i) => {
  const s = window.brickworks3d;
  const v = s.view;
  const d = v.d;
  if (i < 0 || i >= d.n || d.flags[i] & 1) return null;
  const at = v.onPage(v.centreOf(i));
  if (!at || at.x < 2 || at.y < 2 || at.x > innerWidth - 2 || at.y > innerHeight - 2) return null;
  if (document.elementFromPoint(at.x, at.y)?.localName !== "canvas") return null;
  const j = s.pickAt(at.x, at.y);
  if (j < 0) return null;
  return { x: at.x, y: at.y, j, n: d.n, brick: { part: d.meshes[d.mesh[j]].part, colour: d.colours[d.colour[j]].code,
    at: [d.position[j * 3] + 0, -d.position[j * 3 + 1] + 0, -d.position[j * 3 + 2] + 0] } };
}, i);

/// The menu opened at [aim] by a right click, or a long press by touch:
/// what the view says it was opened on, and its pick at that point now.
async function pressAt(page, aim, touch) {
  if (touch) {
    const cdp = await page.context().newCDPSession(page);
    await cdp.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x: aim.x, y: aim.y, id: 1 }] });
    await page.waitForTimeout(650);
    await cdp.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    await cdp.detach().catch(() => {});
  } else {
    await page.mouse.move(aim.x, aim.y);
    await page.mouse.down({ button: "right" });
    await page.mouse.up({ button: "right" });
  }
  return until(page, ([x, y]) => {
    const s = window.brickworks3d;
    return s.pins.menu === "open" ? { picked: s.pins.lastPicked, again: s.pickAt(x, y) } : null;
  }, "the part's menu", 5, [aim.x, aim.y]).catch(() => null);
}

/// Comment on this part chosen: the box is on it ("On the …", with Cancel).
async function choose(page, touch) {
  // The finger that opened the menu is lifted first (inline.js waits 400 ms).
  if (touch) await page.waitForTimeout(450);
  if (touch) await page.tap(MENU);
  else await page.click(MENU);
  return until(page, () => {
    const chip = document.querySelector("#comments .comment-part");
    return chip && !chip.hidden ? chip.querySelector(".pill")?.textContent || "?" : null;
  }, "the box on the part", 10).catch(() => "");
}

const back = (page) => page.evaluate(() => document.querySelector(".model-page .picture").scrollIntoView({ block: "center" }));

/// The pins in an answer, numbered as the page numbers them: oldest first.
const numbered = (comments) => (comments || []).filter((one) => one.pin && !one.parent)
  .sort((a, b) => (Date.parse(a.at) - Date.parse(b.at)) || (a.id - b.id));

/// Each pin's line on the page: {n, text, button, gone, resolved (folded)}.
const lines = (page) => page.evaluate(() => [...document.querySelectorAll("#comments .comment-pin")].map((line) => ({
  n: Number(line.querySelector(".pin-n")?.textContent || 0), text: line.textContent.replace(/^\d+/, "").trim(),
  button: Boolean(line.querySelector("button.pin-go")), gone: line.classList.contains("gone"),
  id: line.closest("li.comment")?.id || "", folded: Boolean(line.closest(".comments-resolved")) })));
const dots = (page) => page.evaluate(() => window.brickworks3d.pins.dots.map((dot) => dot.n).sort((a, b) => a - b));

const ids = {};
let owner = null;
let writer = null;
try {
  console.log("an owner and a commenter, and five models of five shapes");
  owner = await mintSession(ownerEmail);
  writer = await mintSession(writerEmail);
  for (const [who, handle, name] of [[owner, OWNER, "Pin Owner"], [writer, WRITER, "Pin Writer"]]) {
    const made = await api("/api/people?op=profile", { method: "POST", token: who.access_token, body: { handle, name } });
    check(`/u/${handle}`, made.status === 200, String(made.status));
  }
  for (const name of MODELS) {
    const made = await api("/api/share", { method: "POST", token: owner.access_token,
      body: { name: `Pin Flow ${name.replace(/_/g, " ")} ${rand}`, model: texts[name] } });
    ids[name] = made.body.id || "";
    check(`${name} published at /m/${ids[name]}`, made.status === 201 && /^[A-Za-z0-9]{10}$/.test(ids[name]), String(made.status));
  }
  const open = await api(`/api/people?op=comments&id=${ids.house}`, { token: writer.access_token });
  if (!check("comments on a part are open here (the list says pins: true)", open.body.pins === true,
    `pins: ${open.body.pins}; comment_pins.sql, or --hold=pins`)) throw new Error("pins are not open on this deployment");

  // --- 1. the pick ------------------------------------------------------------
  for (const size of SIZES) {
    console.log(`the pick at ${size.width} x ${size.height}${size.touch ? ", by touch (a long press)" : ", by mouse (a right click)"}`);
    const made = await context({ as: writer, width: size.width, height: size.height, touch: size.touch });
    const page = await made.newPage();
    listen(page, `pick ${size.name}`);
    for (const [m, name] of MODELS.entries()) {
      await opened(page, ids[name], size.touch);
      const next = random(1000 * m + (size.touch ? 7 : 3));
      const n = await page.evaluate(() => window.brickworks3d.view.d.n);
      let pressed = 0;
      let right = 0;
      for (let tries = 0; pressed < PRESSES && tries < 400; tries += 1) {
        await back(page);
        const aim = await aimAt(page, Math.floor(next() * n));
        if (!aim) continue;
        const menu = await pressAt(page, aim, size.touch);
        pressed += 1;
        const picked = menu?.picked;
        const same = Boolean(picked) && picked.index === aim.j && menu.again === aim.j && pinPart(picked.part) === pinPart(aim.brick.part)
          && picked.colour === aim.brick.colour && apart(picked.at, aim.brick.at) < 0.01;
        if (pressed === 1 && m === 0 && menu) await shot(page, `menu_${size.name}.png`);
        const chip = menu ? await choose(page, size.touch) : "";
        if (same && chip) right += 1;
        else summary.pick.misses.push({ size: size.name, model: name, at: [Math.round(aim.x), Math.round(aim.y)], want: aim.j,
          picked: picked ? picked.index : null, again: menu ? menu.again : null, chip });
        // The box back on the whole model, for the next.
        if (chip) {
          if (size.touch) await page.tap("#comments .comment-part button");
          else await page.click("#comments .comment-part button");
        } else await page.keyboard.press("Escape").catch(() => {});
      }
      summary.pick[size.name].pressed += pressed;
      summary.pick[size.name].right += right;
      check(`${name} at ${size.name}: ${right} of ${pressed} presses opened the menu on the part under the pointer, by the viewer's own pick, `
        + "and put the box on it", pressed === PRESSES && right === PRESSES);
    }
    await made.close();
  }
  const picked = summary.pick["1280"].right + summary.pick["390"].right;
  check(`the pick bar: ${picked} of ${MODELS.length * PRESSES * 2}`, picked === MODELS.length * PRESSES * 2);

  // --- 2. three pins on the house --------------------------------------------
  console.log("three pins on the house, through the page's own box");
  const moves = movable(texts.house);
  check(`the house has parts a 20 LDU move takes their pin with, by the rule (${moves.length})`, moves.length > 0);
  const writing = await context({ as: writer });
  let page = await writing.newPage();
  listen(page, "commenter");
  await opened(page, ids.house, false);
  // Pin 1 on a part that moves; pins 2 and 3 on parts well apart from it.
  const chosen = await page.evaluate(([moves]) => {
    const s = window.brickworks3d;
    const v = s.view;
    const d = v.d;
    const at = (i) => [d.position[i * 3] + 0, -d.position[i * 3 + 1] + 0, -d.position[i * 3 + 2] + 0];
    const part = (i) => String(d.meshes[d.mesh[i]].part).toLowerCase().replace(/\.dat$/, "");
    const seen = (i) => {
      const p = v.onPage(v.centreOf(i));
      return p && document.elementFromPoint(p.x, p.y)?.localName === "canvas" && s.pickAt(p.x, p.y) === i ? p : null;
    };
    // Further than a pin's neighbours are kept (PIN.near + PIN.slack).
    const far = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]) > 30;
    let first = -1;
    let by = null;
    for (const one of moves) {
      for (let i = 0; i < d.n && first < 0; i++) {
        if (part(i) === String(one.part).toLowerCase().replace(/\.dat$/, "") && d.colours[d.colour[i]].code === one.colour
          && Math.hypot(...at(i).map((x, k) => x - one.at[k])) < 0.5 && seen(i)) [first, by] = [i, one.by];
      }
      if (first >= 0) break;
    }
    if (first < 0) return null;
    const rest = [];
    for (let i = 0; i < d.n && rest.length < 2; i++) {
      if (i === first || d.flags[i] & 1 || !seen(i) || !far(at(i), at(first))) continue;
      if (rest.length && !far(at(i), at(rest[0]))) continue;
      rest.push(i);
    }
    return rest.length === 2 ? { indices: [first, ...rest], by } : null;
  }, [moves]);
  if (!check("three parts in sight to pin, the first one that moves", Boolean(chosen))) throw new Error("no parts to pin");
  const pressedParts = [];
  for (const [k, i] of chosen.indices.entries()) {
    await back(page);
    const aim = await aimAt(page, i);
    const menu = aim ? await pressAt(page, aim, false) : null;
    const chip = menu ? await choose(page, false) : "";
    if (k === 1) {
      const picker = await page.$eval("#comment-step", (e) => e.localName);
      if (picker === "select") await page.selectOption("#comment-step", "1");
      else await page.fill("#comment-step", "1");
    }
    await page.fill("#comment-body", PINS[k]);
    const sent = page.waitForResponse((r) => r.request().method() === "POST" && /\/api\/people\?op=pin$/.test(r.url()), { timeout: 30000 })
      .catch(() => null);
    await page.click("#comments form.comment-new button[type=submit]");
    const reply = await sent;
    pressedParts.push(menu?.picked || null);
    check(`pin ${k + 1} sent from the box that said "${chip}"`, Boolean(menu && chip) && reply?.status() === 201,
      `${reply ? reply.status() : "no answer"}`);
    await until(page, (want) => document.querySelectorAll("#comments .comment-pin").length === want, `pin ${k + 1} listed`, 20, k + 1)
      .catch(() => null);
    if (k === 1) {
      const picker = await page.$eval("#comment-step", (e) => e.localName);
      if (picker === "select") await page.selectOption("#comment-step", "");
      else await page.fill("#comment-step", "");
    }
  }
  const listed = numbered((await api(`/api/people?op=comments&id=${ids.house}`, { token: writer.access_token })).body.comments);
  summary.pins.ids = listed.map((one) => one.id);
  check(`three pins, numbered oldest first (${listed.map((one) => one.id).join(", ")})`, listed.length === 3
    && listed.every((one, k) => one.body === PINS[k]) && listed[1].step === 1);
  check("each kept on the part pressed: its number, colour and place", listed.length === 3 && listed.every((one, k) =>
    pressedParts[k] && pinPart(one.pin.part) === pinPart(pressedParts[k].part) && one.pin.colour === pressedParts[k].colour
    && apart(one.pin.at, pressedParts[k].at) <= 0.5));
  await page.reload({ waitUntil: "load" });
  await toComments(page);
  await until(page, () => !document.getElementById("comments")?.hidden && document.querySelectorAll("#comments .comment-pin").length === 3,
    "the three pins' lines", 45);
  await page.evaluate(() => document.querySelector(".model-page .picture").scrollIntoView({ block: "center" }));
  await page.click(".model-page .picture");
  await until(page, () => window.brickworks3d?.state === "ready" && window.brickworks3d.pins?.placed?.length === 3, "the pins placed", 180);
  const dotted = await until(page, () => (window.brickworks3d.pins.dots.length === 3 ? window.brickworks3d.pins.dots : null),
    "three dots", 20).catch(() => []);
  check(`dots numbered ${dotted.map((dot) => dot.n).sort().join(", ")}, each on its pin's part`, dotted.length === 3
    && [1, 2, 3].every((n) => dotted.some((dot) => dot.n === n && dot.index === chosen.indices[n - 1])));
  const said = await until(page, () => {
    const all = [...document.querySelectorAll("#comments .comment-pin")].map((line) => line.textContent.replace(/^\d+/, "").trim());
    return all.length === 3 && all.every((words) => words.startsWith("on the ")) ? all : null;
  }, "the pins' lines with their parts' names", 45).catch(async () => (await lines(page)).map((one) => one.text));
  summary.pins.lines = said;
  check(`each line says its part: ${said.map((words) => `"${words}"`).join(", ")}`, said.length === 3
    && said.every((words) => words.startsWith("on the ")) && said.some((words) => /, step 1$/.test(words)));
  await page.click(`#comment-${listed[0].id} .comment-pin button.pin-go`);
  const turned = await until(page, (i) => (window.brickworks3d.pins.turnedTo === i ? i : null), "the view turned to pin 1", 15,
    chosen.indices[0]).catch(() => -1);
  check("pin 1's line pressed turns the view to its part, lit", turned === chosen.indices[0]
    && await page.evaluate(() => window.brickworks3d.pins.lit) === chosen.indices[0]);
  await shot(page, "pin_dots.png");
  await shot(page, "pin_on_site.png", true);
  await writing.close();

  // --- 3. a new version --------------------------------------------------------
  console.log("version 2 of the house: pin 1's part moved 20 LDU, pin 2's recoloured");
  const [one, two, three] = listed;
  const colour = [14, 25, 191, 70].find((c) => c !== one.pin.colour && c !== two.pin.colour);
  const moved = edited(texts.house, one.pin, { by: chosen.by });
  const v2 = moved && edited(moved, two.pin, { colour });
  const after = v2 ? placesOf(v2) : [];
  const want = [pinPlace(one.pin, after), pinPlace(two.pin, after), pinPlace(three.pin, after)];
  check(`the rule, read here, on the new file: pin 1 moved, pin 2 on none, pin 3 kept (${JSON.stringify(want)})`,
    Boolean(v2) && want[0]?.moved === true && want[1] === null && want[2] && want[2].moved === false);
  const published = await api("/api/share", { method: "POST", token: owner.access_token,
    body: { id: ids.house, name: `Pin Flow house ${rand}`, model: v2, note: "A part moved, and one recoloured" } });
  check(`version ${published.body.version} published`, published.status === 200 && published.body.version === 2, String(published.status));
  const reading = await context();
  page = await reading.newPage();
  listen(page, "visitor");
  await opened(page, ids.house, false, { pins: 3 });
  const placed = await page.evaluate(() => window.brickworks3d.pins.placed);
  const movedTo = placed.find((pin) => pin.n === 1);
  const movedAt = movedTo && movedTo.index >= 0 ? await page.evaluate((j) => {
    const d = window.brickworks3d.view.d;
    return [d.position[j * 3] + 0, -d.position[j * 3 + 1] + 0, -d.position[j * 3 + 2] + 0];
  }, movedTo.index) : null;
  summary.version = { placed, by: chosen.by, colour };
  check(`pin 1 follows its part ${JSON.stringify(chosen.by)} LDU`, movedTo?.moved === true && Boolean(movedAt)
    && apart(movedAt, plus(one.pin.at, chosen.by)) <= 0.5);
  check("pin 2, its part recoloured, is on no part here", placed.find((pin) => pin.n === 2)?.index === -1);
  check("pin 3 is where it was", placed.find((pin) => pin.n === 3)?.index >= 0 && placed.find((pin) => pin.n === 3)?.moved === false);
  check(`dots ${(await dots(page)).join(", ")}: none for pin 2`, JSON.stringify(await dots(page)) === "[1,3]");
  const now = await lines(page);
  const line = (n) => now.find((one) => one.n === n) || {};
  summary.version.lines = now;
  check(`pin 1's line: "${line(1).text}"`, / \(moved since\)$/.test(line(1).text || "") && line(1).button);
  check(`pin 2's line: "${line(2).text}", words alone`, /, on version 1$/.test(line(2).text || "") && line(2).gone && !line(2).button);
  await back(page);
  await shot(page, "new_version.png");
  await reading.close();

  // --- 4. resolved ----------------------------------------------------------------
  console.log("the owner resolves pin 3, as the studio does");
  const done = await api("/api/people?op=pin_resolve", { method: "POST", token: owner.access_token, body: { id: three.id, resolved: true } });
  const began = Date.now();
  check("op=pin_resolve as the owner", done.status === 200 && done.body.comment?.resolved === true, String(done.status));
  const refused = await api("/api/people?op=pin_resolve", { method: "POST", token: writer.access_token, body: { id: one.id, resolved: true } });
  check(`...and refused to the commenter (${refused.status})`, refused.status === 403);
  const visiting = await context();
  page = await visiting.newPage();
  listen(page, "visitor, for Resolve");
  let seenAfter = null;
  while (Date.now() - began < 60000) {
    await page.goto(`${site}/m/${ids.house}`, { waitUntil: "load" });
    await toComments(page).catch(() => null);
    const folded = await until(page, (id) => {
      const fold = document.querySelector("#comments .comments-resolved");
      if (document.getElementById("comments")?.hidden || document.getElementById("comments-hold")) return null;
      return { shown: Boolean(fold && !fold.hidden), said: fold?.querySelector("summary")?.textContent || "",
        inside: Boolean(fold?.querySelector(`#comment-${id}`)) };
    }, "the comments", 30, three.id).catch(() => null);
    if (folded && folded.shown && folded.said === "Resolved (1)" && folded.inside) {
      seenAfter = Date.now() - began;
      break;
    }
    await page.waitForTimeout(5000);
  }
  summary.resolve.ms = seenAfter;
  check(`a visitor sees it under Resolved (1) after ${seenAfter === null ? "more than 60,000" : seenAfter.toLocaleString("en-US")} ms`,
    seenAfter !== null && seenAfter < 60000);
  if (seenAfter !== null) {
    await page.evaluate(() => document.querySelector(".model-page .picture").scrollIntoView({ block: "center" }));
    await page.click(".model-page .picture");
    await until(page, () => window.brickworks3d?.state === "ready" && window.brickworks3d.pins?.placed?.length === 3, "the pins placed", 180);
    check(`...with no dot (dots ${(await dots(page)).join(", ")})`, JSON.stringify(await dots(page)) === "[1]");
    await page.evaluate(() => { const fold = document.querySelector("#comments .comments-resolved"); if (fold) fold.open = true; });
    await page.evaluate(() => document.getElementById("comments").scrollIntoView());
    await shot(page, "resolved.png");
  }
  await visiting.close();

  // --- 5. blocked ---------------------------------------------------------------
  console.log("the owner blocks the commenter");
  const blocked = await api("/api/people?op=block", { method: "POST", token: owner.access_token, body: { handle: WRITER, on: true } });
  check("op=block as the owner", blocked.status === 200, String(blocked.status));
  const theirs = ((await api(`/api/people?op=comments&id=${ids.house}`, { token: owner.access_token })).body.comments || [])
    .filter((c) => c.handle === WRITER);
  check(`the owner's list has none of the commenter's comments (${theirs.length})`, theirs.length === 0);
  const owning = await context({ as: owner });
  page = await owning.newPage();
  listen(page, "owner, blocked");
  await opened(page, ids.house, false);
  const left = await lines(page);
  const dotsLeft = await dots(page);
  summary.block = { lines: left.length, dots: dotsLeft.length };
  check(`the owner's page shows none of their pins (${left.length} lines, ${dotsLeft.length} dots)`, left.length === 0 && dotsLeft.length === 0);
  await back(page);
  await shot(page, "blocked.png");
  await owning.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  for (const id of Object.values(ids)) {
    if (id && owner) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: owner.access_token }).catch(() => {});
  }
  await browser.close();
  for (const email of [ownerEmail, writerEmail]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
summary.failed = failed;
writeFileSync(path.join(out, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
console.log(failed ? `${failed} FAILED` : "partpins: the part pressed, its dot and line, across versions, resolved, and blocked");
process.exit(failed ? 1 : 0);
