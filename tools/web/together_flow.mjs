// Building together, in real browsers and the desktop app at once: two
// people build one model live, each in their own copy of the app.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9011 --static=build/web --hold=together_sessions,together_ops,together_people &
//   node tools/web/together_flow.mjs --url=http://127.0.0.1:9011 --out=shots/together
//   BW_BYPASS=… node tools/web/together_flow.mjs --url=<a preview> --out=DIR     once together.sql is applied
//   ... --desktop=no                                                              without the desktop's half
//
// Two browser contexts, each a person with their own account (throwaway
// ones at Resend's test addresses, deleted at the end); the second is under
// 13, who builds together like anyone and is never shown by name:
//
//   1. The owner opens the house, and File, Build together… (the menu typed
//      to, as a person does), and presses Start a session: a link.
//   2. The second person opens the link, signed in: they join, and have the
//      house byte for byte; each sees who is in it ("Builder 2", never an
//      email). The desktop app joins the same session too
//      (src/dev/together_probe.gd --join), and makes edits of its own.
//   3. 50 random edits from the two browsers, interleaved, as the keys make
//      them (Together.check_edit: place, move, paint, delete, undo), some on
//      the same part at the same moment; then, once nothing is on its way,
//      the model is byte-identical in both browsers and the desktop.
//   4. Per-person undo, by the key: the owner puts a part down, the other
//      paints another; the owner's Ctrl+Z takes back the owner's part and
//      leaves the paint, on both sides.
//   5. How long a change takes to reach the other browser: p50 and p95 over
//      20 changes each way, from the edit to the other page having it.
//   6. A third account, not invited: a made-up link is refused in its page,
//      and the session refuses it outright (api/together.js 403).
//   7. The owner ends it, from the panel: the other browser and the desktop
//      are told, and keep what was built; the owner's model is as it was.
//
// Red on a build without it: there is no Build together… in the File menu.
// Pictures in --out. Exit 1 on any failure.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:9011").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/together"));
mkdirSync(out, { recursive: true });
const bypass = args.bypass || process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const withDesktop = String(args.desktop || "yes") !== "no";
const EDITS = Number(args.edits || 50);
const rand = randomBytes(4).toString("hex");
const emails = {
  owner: `delivered+bw-together-owner-${rand}@resend.dev`,
  guest: `delivered+bw-together-guest-${rand}@resend.dev`,
  stranger: `delivered+bw-together-stranger-${rand}@resend.dev`,
  desktop: `delivered+bwtogetherd${rand}@resend.dev`,
};

let failed = 0;
const check = (what, ok, more = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${more ? `  (${more})` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const state = (page) => page.evaluate(() => window.brickworksState || {});
const together = (page) => page.evaluate(() => window.brickworksTogether || {});
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function until(test, what, seconds = 120) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await wait(300);
  }
}

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

// File, then the item's first words typed, then Enter: the menu as a
// person drives it from the keyboard (floor_flow.mjs).
async function menu(page, title, words, shown, seconds = 30) {
  for (let n = 0; n < 3; n++) {
    const at = await until(async () => (await controls(page))[`menu_${title}`], `the ${title} menu`, 240);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(2000 + 1500 * n);
    // Typed without its spaces: a space in a menu presses the row it is on.
    await page.keyboard.type(words.replace(/ /g, ""), { delay: 110 });
    await page.waitForTimeout(700);
    if (n === 0) await shot(page, `menu_${title}_${words.replace(/\W+/g, "_")}.png`);
    await page.keyboard.press("Enter");
    const got = await until(async () => (await controls(page))[shown], shown, seconds).catch(() => null);
    if (got) return got;
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1500);
  }
  return null;
}

// Edits through the app's own builder, and the model's file, asked of the
// page (Together._tell_page).
async function ask(page, asks) {
  await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; }, asks);
  return until(() => page.evaluate(() => window.brickworksTogetherDone), "the page's answer", 30);
}
const textOf = async (page) => (await ask(page, [{ text: true }]))[0];

const browser = await launch({ signedOut: true });
async function person(email, { under13 = false } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 }, extraHTTPHeaders: headers });
  const session = await mintSession(email, { age: !under13 });
  if (under13) await answerAge(session.kept.user_id, email, false);
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  const page = await context.newPage();
  page.on("pageerror", (e) => console.log(`        [page error] ${String(e).slice(0, 160)}`));
  return { context, page, token: session.access_token, email };
}
async function opened(who, query) {
  await who.page.goto(`${site}/app?${query}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(who.page)).model_name, "the app", 300);
  await until(async () => {
    const now = await state(who.page);
    return now.bricks > 0 && now.awaited === 0;
  }, "the model whole", 180);
}
async function settled(pages, desktopFile = null, seconds = 60) {
  return until(async () => {
    const all = await Promise.all(pages.map(together));
    const top = Math.max(...all.map((one) => one.seq || 0));
    if (!all.every((one) => one.live && one.waiting === 0 && one.seq === top)) return null;
    if (desktopFile) {
      const desk = readDesktop(desktopFile);
      if (!desk || desk.seq !== top || desk.waiting !== 0) return null;
    }
    // Twice, a moment apart, so nothing was numbered meanwhile.
    await wait(1200);
    const again = await Promise.all(pages.map(together));
    return again.every((one) => one.seq === top && one.waiting === 0) ? top : null;
  }, "nothing on its way", seconds);
}
function readDesktop(file) {
  try { return existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null; } catch { return null; }
}

let desktop = null;
const desktopFile = path.join(out, "desktop.json");
const people = {};
try {
  people.owner = await person(emails.owner);
  people.guest = await person(emails.guest, { under13: true });
  const { owner, guest } = people;
  if (bypass) {
    await owner.page.goto(`${site}/app?x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`,
      { waitUntil: "domcontentloaded", timeout: 180000 }).catch(() => {});
  }

  console.log("\n1. the owner starts a session");
  await opened(owner, "model=res://models/house.ldr");
  const panel = await menu(owner.page, "file", "Build tog", "together_start");
  check("File, Build together… opens its panel", Boolean(panel));
  if (!panel) throw new Error("no Build together in the File menu");
  await shot(owner.page, "1_panel.png");
  await press(owner.page, "together_start");
  const started = await until(async () => {
    const now = await together(owner.page);
    return now.live && now.link ? now : null;
  }, "the session's link", 60);
  check("Start a session gives a link", /\/app\?together=[A-Za-z0-9_-]{32}$/.test(started.link), started.link);
  await until(async () => (await controls(owner.page)).together_copy, "the link in the panel", 20);
  await shot(owner.page, "1_link.png");

  console.log("\n2. the other person joins by the link, and the desktop");
  await guest.page.goto(started.link, { waitUntil: "domcontentloaded", timeout: 180000 });
  const joined = await until(async () => {
    const now = await together(guest.page);
    return now.live ? now : null;
  }, "the second browser in the session", 240);
  check("the link joins the second person (under 13)", joined.live && !joined.owner);
  await until(async () => (await state(guest.page)).awaited === 0, "the house whole there", 120);
  const [a0, b0] = [await textOf(owner.page), await textOf(guest.page)];
  check("both have the house, byte for byte", a0.hash === b0.hash && a0.text.length > 1000,
    `${a0.uids.length} parts, ${a0.text.length} bytes`);
  const names = (await until(async () => {
    const now = await together(owner.page);
    return now.people?.length === 2 ? now.people : null;
  }, "two people in it", 30)).map((one) => one.name);
  check(`each is shown who is in it: ${names.join(", ")}`, names.length === 2
    && !names.some((name) => name.includes("@")) && names.includes("Builder 2"));
  await until(async () => (await controls(guest.page)).together_end, "the guest's panel", 30).catch(() => null);
  await shot(guest.page, "2_joined.png");
  await press(guest.page, "together_close").catch(() => {});
  await press(owner.page, "together_close").catch(() => {});

  if (withDesktop) {
    // Plain godot: the flow holds the box's slot already, and the desktop's
    // half is a headless copy that mostly waits on the network.
    const godotArgs = ["--headless", "--path", root, "--script", "src/dev/together_probe.gd", "--",
      `--api=${site}`, `--join=${started.link}`, `--out=${desktopFile}`, "--edits=6", `--email=${emails.desktop}`,
      "--seconds=900"];
    desktop = spawn("godot", godotArgs, {
      env: { ...process.env, XDG_DATA_HOME: process.env.TOGETHER_XDG || path.join(out, "desktop-data") },
      stdio: ["ignore", "pipe", "pipe"],
    });
    desktop.stdout.on("data", (bytes) => {
      for (const line of String(bytes).split("\n")) if (/ok  |FAIL|together probe/.test(line)) console.log(`        [desktop] ${line.trim()}`);
    });
    const live = await until(async () => readDesktop(desktopFile)?.live, "the desktop in the session", 300).catch(() => null);
    check("the desktop app joins the same session", Boolean(live));
  }

  console.log(`\n3. ${EDITS} edits from both browsers, interleaved`);
  const sides = [owner, guest];
  let made = 0;
  let together_moves = 0;
  const uidsOf = async (page) => (await textOf(page)).uids;
  let known = await uidsOf(owner.page);
  for (let n = 0; n < EDITS; n++) {
    if (n % 10 === 0) known = await uidsOf(sides[n % 2].page);
    const pick = () => known[Math.floor(Math.random() * known.length)];
    const roll = Math.random();
    let edits;
    if (n % 9 === 4) {
      // The same part, both at once.
      const uid = pick();
      const [x, y] = await Promise.all([
        ask(owner.page, [{ op: "move", uid, by: [0, 6 + 2 * n, 0] }]),
        ask(guest.page, [{ op: "move", uid, by: [0, 8 + 2 * n, 0] }]),
      ]);
      if (x[0]?.ok && y[0]?.ok) together_moves += 1;
      made += (x[0]?.ok ? 1 : 0) + (y[0]?.ok ? 1 : 0);
      continue;
    }
    if (roll < 0.3) {
      edits = [{ op: "place", part: ["3001", "3003", "3004", "3010"][n % 4], colour: [1, 2, 4, 14, 15][n % 5],
        x: 600 + 80 * Math.floor(Math.random() * 20), y: 48 + 24 * Math.floor(Math.random() * 6),
        z: 600 + 80 * Math.floor(Math.random() * 20) }];
    } else if (roll < 0.6) {
      edits = [{ op: "move", uid: pick(), by: [10 * Math.floor(Math.random() * 7 - 3), 12 * (1 + Math.floor(Math.random() * 3)),
        10 * Math.floor(Math.random() * 7 - 3)] }];
    } else if (roll < 0.8) {
      edits = [{ op: "paint", uid: pick(), colour: [1, 2, 4, 14, 15, 0][Math.floor(Math.random() * 6)] }];
    } else if (roll < 0.9) {
      edits = [{ op: "delete", uid: pick() }];
    } else {
      edits = [{ op: "undo" }];
    }
    const [done] = await ask(sides[n % 2].page, edits);
    if (done?.ok) made += 1;
    if (done?.uid) known.push(done.uid);
    await wait(Math.floor(Math.random() * 250));
  }
  const top = await settled([owner.page, guest.page], withDesktop ? desktopFile : null, 90).catch(() => null);
  check(`${made} edits made (${together_moves} times the same part moved by both at once); all numbered`, Boolean(top) && made >= EDITS * 0.6,
    `seq ${top}`);
  const [a1, b1] = [await textOf(owner.page), await textOf(guest.page)];
  check("the model is byte-identical in both browsers", a1.hash === b1.hash, `${a1.uids.length} parts, ${a1.text.length} bytes`);
  if (withDesktop) {
    const desk = readDesktop(desktopFile);
    check(`...and in the desktop app (${desk?.made ?? 0} edits of its own)`, desk?.hash === a1.hash, `seq ${desk?.seq}`);
  }
  await shot(owner.page, "3_owner.png");
  await shot(guest.page, "3_guest.png");

  console.log("\n4. each undo is its own");
  const [placed] = await ask(owner.page, [{ op: "place", part: "3001", colour: 4, x: -1200, y: 96, z: -1200 }]);
  await settled([owner.page, guest.page]);
  const target = (await uidsOf(guest.page)).find((uid) => uid !== placed.uid);
  const [painted] = await ask(guest.page, [{ op: "paint", uid: target, colour: 14 }]);
  await settled([owner.page, guest.page]);
  // The owner's own key, in the owner's page.
  const view = (await controls(owner.page)).view;
  if (view) await owner.page.mouse.move(view.x, view.y + 40);
  await owner.page.keyboard.press("Control+z");
  await settled([owner.page, guest.page]);
  const [a2, b2] = [await textOf(owner.page), await textOf(guest.page)];
  check("the owner's Ctrl+Z takes back the owner's part, on both sides", placed?.ok && !a2.uids.includes(placed.uid)
    && !b2.uids.includes(placed.uid));
  const paintSeen = (text) => text.includes(" 14 ") ;
  check("...and leaves the other's paint, on both", painted?.ok && paintSeen(a2.text) && a2.hash === b2.hash);

  console.log("\n5. how long a change takes to reach the other browser");
  const times = { "owner to guest": [], "guest to owner": [] };
  for (let n = 0; n < 40; n++) {
    const [from, to, label] = n % 2 === 0 ? [owner, guest, "owner to guest"] : [guest, owner, "guest to owner"];
    const before = (await together(to.page)).seq;
    const uids = a2.uids;
    // From the moment the edit is asked of one page to the frame the other
    // page has it, read every 20 ms: what a person waits, frames and all.
    await from.page.evaluate(() => { window.brickworksTogetherDone = undefined; });
    const t0 = Date.now();
    await from.page.evaluate((a) => { window.brickworksTogetherAsk = a; },
      [{ op: "paint", uid: uids[n % uids.length], colour: n % 2 ? 1 : 4 }]);
    let got = null;
    for (const end = Date.now() + 20000; Date.now() < end && !got;) {
      if ((await together(to.page)).seq > before) got = Date.now();
      else await wait(20);
    }
    if (got) times[label].push(got - t0);
    await until(() => from.page.evaluate(() => window.brickworksTogetherDone), "the edit's answer", 20).catch(() => null);
    await wait(300);
  }
  const all = [...times["owner to guest"], ...times["guest to owner"]].sort((x, y) => x - y);
  const pct = (list, p) => list[Math.min(list.length - 1, Math.floor(p * list.length))];
  check(`${all.length} changes arrived: p50 ${pct(all, 0.5)} ms, p95 ${pct(all, 0.95)} ms`, all.length >= 36 && pct(all, 0.5) < 1500,
    Object.entries(times).map(([k, v]) => `${k} p50 ${pct([...v].sort((x, y) => x - y), 0.5)}`).join(", "));

  console.log("\n6. an account not invited");
  people.stranger = await person(emails.stranger);
  await people.stranger.page.goto(`${site}/app?together=${"Z".repeat(32)}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(async () => (await controls(people.stranger.page)).model_name, "the stranger's app", 300);
  await wait(6000);
  check("a made-up link joins nobody", !(await together(people.stranger.page)).live);
  const secret = started.link.split("together=")[1];
  const refused = await fetch(`${site}/api/together?op=poll`, { method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${people.stranger.token}` },
    body: JSON.stringify({ s: secret, after: 0 }) });
  check("the session refuses an account that never joined it", refused.status === 403, `${refused.status}`);
  await shot(people.stranger.page, "6_stranger.png");

  console.log("\n7. the owner ends it");
  const before = await textOf(owner.page);
  const reopened = await menu(owner.page, "file", "Build tog", "together_end");
  check("the panel shows the session", Boolean(reopened));
  await shot(owner.page, "7_panel.png");
  await press(owner.page, "together_end");
  const told = await until(async () => {
    const now = await together(guest.page);
    return !now.live && now.ended ? now : null;
  }, "the guest told", 40).catch(() => null);
  check("the other browser is told, and keeps what was built", Boolean(told)
    && (await state(guest.page)).bricks === (await state(owner.page)).bricks, told?.ended);
  const after = await textOf(owner.page);
  check("the owner's model is as it was, and theirs", !(await together(owner.page)).live && after.hash === before.hash);
  if (withDesktop) {
    const desk = await until(async () => {
      const now = readDesktop(desktopFile);
      return now && now.live === false ? now : null;
    }, "the desktop told", 60).catch(() => null);
    check("the desktop is told too, and has the same model", Boolean(desk) && desk.hash === before.hash, desk?.ended);
  }
  await shot(guest.page, "7_guest.png");
} catch (trouble) {
  check(`the flow ran to the end: ${String(trouble.message || trouble).split("\n")[0]}`, false);
  for (const [name, who] of Object.entries(people)) await shot(who.page, `stopped_${name}.png`);
} finally {
  if (desktop) {
    await until(async () => desktop.exitCode !== null, "the desktop to finish", 60).catch(() => desktop.kill());
  }
  await browser.close().catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
console.log(failed ? `\ntogether_flow: ${failed} FAILED` : "\ntogether_flow: all ok");
process.exit(failed ? 1 : 0);
