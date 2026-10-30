// A page closed straight after a change, in a Build together session: does
// the change reach the other person? (Unit closesend, 2026-10-30: one run of
// seven of together_flow lost two changes a closed page had ready to send.)
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9013 --static=build/web --hold=together_sessions,together_ops,together_people,together_snapshot_parts
//   node tools/web/together_close.mjs --url=http://127.0.0.1:9013 --rounds=30 --held --frame=600
//   ... --held        the page's own sends held first (together_flow 5i's way): only what the page does as it
//                     goes, or the next visit, can carry the change
//   ... --frame=600   each of the closing page's frames held that long, as a page drawing the rich car in
//                     software is (617 ms at the median, together_flow 5f)
//   ... --delays=0,50,200,500   ms from the edit to the close, taken in turn
//
// Two people, each their own throwaway account and browser context. The
// owner opens the car and starts a session. Each round a new tab of the
// second person's joins by the link, puts a part down (Together.check_edit,
// the builder's own place), and is closed that many ms later, as a person
// closes a tab ("Leave" if the page asks). Then the part must be in the
// owner's page: within 15 s ("as it went"), or else once the person opens
// the app again, in a tab of its own with no link ("on the next visit"),
// within 60 s of that. Where it was lost is said too: the server's numbered
// changes, read from the relay's held table. Exit 1 if any round lost it.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { randomBytes } from "node:crypto";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9013").replace(/\/+$/, "").replace(/\/app$/, "");
const rounds = Number(args.rounds || 30);
const delays = String(args.delays || "0,50,200,500").split(",").map(Number);
const held = Boolean(args.held);
const frameMs = Number(args.frame || 0);
const rand = randomBytes(4).toString("hex");
const emails = {
  owner: `delivered+bw-close-owner-${rand}@resend.dev`,
  guest: `delivered+bw-close-guest-${rand}@resend.dev`,
};

const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const controls = (page) => page.evaluate(() => window.brickworksControls || {});
const state = (page) => page.evaluate(() => window.brickworksState || {});
const together = (page) => page.evaluate(() => window.brickworksTogether || {});
async function until(test, what, seconds = 120, every = 300) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await wait(every);
  }
}
async function ask(page, asks) {
  await page.evaluate((a) => { window.brickworksTogetherDone = undefined; window.brickworksTogetherAsk = a; }, asks);
  return until(() => page.evaluate(() => window.brickworksTogetherDone), "the page's answer", 180, 10);
}
const uidsOf = async (page) => (await ask(page, [{ text: true }]))[0].uids;
async function press(page, name, seconds = 60) {
  const at = await until(async () => (await controls(page))[name], name, seconds);
  await page.waitForTimeout(600);
  const again = (await controls(page))[name] || at;
  await page.mouse.click(again.x, again.y);
  await page.waitForTimeout(400);
}
async function menu(page, title, words, shown) {
  for (let n = 0; n < 3; n++) {
    const at = await until(async () => (await controls(page))[`menu_${title}`], `the ${title} menu`, 240);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(2000 + 1500 * n);
    await page.keyboard.type(words.replace(/ /g, ""), { delay: 110 });
    await page.waitForTimeout(700);
    await page.keyboard.press("Enter");
    const got = await until(async () => (await controls(page))[shown], shown, 30).catch(() => null);
    if (got) return got;
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(1500);
  }
  return null;
}

const browser = await launch({ signedOut: true });
async function person(email) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
  const session = await mintSession(email);
  await context.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(session.kept)]);
  return { context };
}
async function tab(who, address) {
  const page = await who.context.newPage();
  page.on("pageerror", (e) => console.log(`        [page error] ${String(e).slice(0, 160)}`));
  // A person asked "Leave site?" as the tab closes answers Leave.
  page.dialogs = 0;
  page.on("dialog", (dialog) => { page.dialogs += 1; dialog.accept().catch(() => {}); });
  await page.goto(address, { waitUntil: "domcontentloaded", timeout: 180000 });
  return page;
}
// In the session by the link, the model whole and nothing on its way.
async function joined(page) {
  return until(async () => {
    const asked = (await controls(page)).replace_discard;
    if (asked) await page.mouse.click(asked.x, asked.y);
    const now = await together(page);
    return now.live && now.waiting === 0 && (await state(page)).awaited === 0 ? now : null;
  }, "in the session by the link", 300);
}
async function heldOps() {
  const answer = await fetch(`${site}/__held/together_ops`).catch(() => null);
  return answer?.ok ? (await answer.json()) || [] : null;
}

let lost = 0;
const tally = {};
const people = {};
try {
  people.owner = await person(emails.owner);
  people.guest = await person(emails.guest);
  const owner = await tab(people.owner, `${site}/app?model=res://models/car.ldr`);
  await until(async () => (await state(owner)).bricks > 0 && (await state(owner)).awaited === 0, "the owner's car", 300);
  if (!await menu(owner, "file", "Build tog", "together_start")) throw new Error("no Build together in the File menu");
  await press(owner, "together_start");
  const started = await until(async () => { const now = await together(owner); return now.live && now.link ? now : null; },
    "the session's link", 60);
  await press(owner, "together_close").catch(() => {});
  console.log(`session ${started.link}; ${rounds} rounds, ${held ? "sends held, " : ""}${frameMs
    ? `frames held ${frameMs} ms, ` : ""}closed ${delays.join("/")} ms after the edit`);
  for (let n = 0; n < rounds; n++) {
    const delay = delays[n % delays.length];
    const guest = await tab(people.guest, started.link);
    await joined(guest);
    if (held) await ask(guest, [{ op: "hold", on: true }]);
    if (frameMs > 0) {
      await guest.evaluate((ms) => {
        const spin = () => {
          const from = performance.now();
          while (performance.now() - from < ms) { /* the frame's drawing */ }
          requestAnimationFrame(spin);
        };
        requestAnimationFrame(spin);
      }, frameMs);
    }
    const at = { x: -2400 + 120 * (n % 20), y: 48, z: -2800 - 120 * Math.floor(n / 20) };
    const [placed] = await ask(guest, [{ op: "place", part: "3001", colour: 1 + (n % 14), ...at }]);
    if (delay > 0) await wait(delay);
    const waiting = (await together(guest).catch(() => ({}))).waiting;
    const gone = guest.waitForEvent("close", { timeout: 30000 }).then(() => true).catch(() => false);
    await guest.close({ runBeforeUnload: true });
    const closed = await gone;
    const atOwner = (seconds) => until(async () => (await uidsOf(owner)).includes(placed?.uid), "the part", seconds)
      .then(() => true).catch(() => false);
    const went = await atOwner(15);
    const atServer = async () => {
      const rows = await heldOps();
      return rows === null ? "?" : rows.some((row) => Object.keys(row.changes || {}).includes(placed?.uid))
        ? "yes" : "no";
    };
    const serverThen = await atServer();
    let later = false;
    if (!went) {
      // The next visit: the app opened again in a tab of its own, no link.
      const next = await tab(people.guest, `${site}/app`);
      await until(async () => (await controls(next)).model_name, "the next visit's app", 300).catch(() => null);
      later = await atOwner(60);
      await next.close().catch(() => {});
    }
    const arrived = went || later;
    const counts = tally[delay] = tally[delay] || { went: 0, later: 0, lost: 0 };
    counts[went ? "went" : later ? "later" : "lost"] += 1;
    if (!arrived) lost += 1;
    console.log(`  ${arrived ? "ok  " : "LOST"}  round ${n + 1}, closed ${delay} ms after the edit (${waiting} waiting,`
      + ` ${guest.dialogs} asked, page ${closed ? "closed" : "still open"}): at the server as it went ${serverThen};`
      + ` at the owner ${went ? "as it went" : later ? "on the next visit" : `no, nor on the next visit (server ${await atServer()})`}`);
  }
} catch (trouble) {
  console.log(`  FAIL  the repro ran to the end: ${String(trouble.message || trouble).split("\n")[0]}`);
  lost += 1;
} finally {
  await browser.close().catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
console.log(`\nby delay: ${Object.entries(tally).map(([d, t]) => `${d} ms: ${t.went} as it went, ${t.later} on the next`
  + ` visit, ${t.lost} lost`).join("; ")}`);
console.log(lost ? `together_close: ${lost} LOST` : "together_close: none lost");
process.exit(lost ? 1 : 0);
