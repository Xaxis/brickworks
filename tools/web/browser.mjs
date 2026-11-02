// The one way a browser is started here: drawing in software, on SwiftShader.
//
// Never on the GPU. This box's GPU is leased one job at a time, because two
// amdgpu hangs that took the desktop down both began with several programs on
// it at once, one of them headless Chromium on Vulkan. Two of these scripts
// asked for SwiftShader and five took Playwright's default, so whether a
// deploy's landing check stayed off the GPU was up to Playwright.
//
// And signed in. Everyone who uses Brickworks signs in (2026-10-11), and the
// app shows nothing but the sign-in screen until they have, so every flow
// here that drives the app would otherwise drive that screen. Each context
// this browser opens starts as a returning visitor's: a session of the test
// account, minted on the test side (session.mjs) and put where the app keeps
// one. Needs .env sourced; without it the pages start signed out and say
// so. launch({ signedOut: true }) for a flow about signing in itself.
import { chromium } from "playwright";
import { canSignIn, signInContext, TEST_EMAIL } from "./session.mjs";

export const SOFTWARE = [
  "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
];

// How long a page has for the app to come up and show its controls: five
// minutes, which a fresh page of the web build drawn in software needs on a
// loaded machine (arrival_check, fit_check).
export const START_MS = 5 * 60 * 1000;

let warned = false;

async function signedIn(context) {
  if (!canSignIn()) {
    if (!warned) {
      warned = true;
      console.log("  (not signed in: no Supabase keys in the environment — "
        + "`set -a; . ./.env; set +a` — so the app will show its sign-in screen)");
    }
    return context;
  }
  try {
    await signInContext(context);
  } catch (trouble) {
    console.log(`  (could not sign the test account in: ${trouble.message})`);
  }
  return context;
}

// BW_RATIO=2 draws every page a flow opens at that device pixel ratio,
// unless the flow chooses one itself: how the site's pictures of the app
// are taken, so they stay sharp on a high-density screen.
const RATIO = Number(process.env.BW_RATIO || 0);
const withRatio = (options = {}) =>
  RATIO > 0 && options.deviceScaleFactor === undefined ? { ...options, deviceScaleFactor: RATIO } : options;

/// The visit counter (Overlook) answered from here in a check, not from its
/// own server: the server answers a burst of loads from one address with a
/// 403 that carries no Cross-Origin-Resource-Policy, which the site's
/// isolation then blocks and the page logs, so site_check failed m35 on
/// its 21st page (2026-10-16). A check is not a visit; site_check loads the
/// real one once, on purpose ({ realCounter: true }).
const COUNTER = "https://overlook.technology/**";
export async function quietCounter(context) {
  await context.route(COUNTER, (route) => route.fulfill({ status: 200,
    contentType: "application/javascript", body: "",
    headers: { "cross-origin-resource-policy": "cross-origin", "access-control-allow-origin": "*" } }));
  return context;
}

/// Every picture on the page loaded and decoded, hidden ones too, so a
/// full-page shot or a card's naturalWidth shows the page as read. A lazy
/// picture loads only when drawn near the view, and one in a hidden part of
/// the page never does: its decode() never settles. The gallery's shelves
/// hide while a search is asked, and share_flow, the one copy of this that
/// did not make them eager first, waited on them for 45 minutes and held
/// m84 (2026-10-19). And never more than [ms], whatever a picture does.
export async function allPictures(page, ms = 30000) {
  await page.evaluate(async (limit) => {
    for (const img of document.querySelectorAll("img[loading=lazy]")) img.loading = "eager";
    await Promise.race([
      Promise.all([...document.images].map((img) => img.decode().catch(() => {}))),
      new Promise((done) => setTimeout(done, limit)),
    ]);
  }, ms);
}

export async function launch(options = {}) {
  const { signedOut = false, realCounter = false, ...rest } = options;
  const browser = await chromium.launch({ ...rest, args: [...SOFTWARE, ...(rest.args || [])] });
  const bare = browser.newContext.bind(browser);
  const newContext = realCounter ? bare : async (contextOptions) => quietCounter(await bare(contextOptions));
  if (signedOut) {
    const newPage = browser.newPage.bind(browser);
    browser.newContext = (contextOptions) => newContext(withRatio(contextOptions));
    browser.newPage = (pageOptions) => newPage(withRatio(pageOptions));
    return browser;
  }
  browser.newContext = async (contextOptions) => signedIn(await newContext(withRatio(contextOptions)));
  // A page of its own context, which Playwright closes with the page.
  browser.newPage = async (pageOptions) => {
    const context = await browser.newContext(pageOptions);
    const page = await context.newPage();
    page.on("close", () => context.close().catch(() => {}));
    return page;
  };
  browser.testAccount = canSignIn() ? TEST_EMAIL : null;
  return browser;
}

/// Where the app's controls are (window.brickworksControls), once every one
/// of [names] is there, as a person waits for a panel to open: polled every
/// 250 ms for up to [ms]. A control is told to the page only once it has
/// stayed where it is drawn for a publish (Main._page_places, every 500 ms),
/// so about a second after it appears, longer under load; a flow that read
/// the map once right after showing a control could miss it (fit_check,
/// 2026-10-14). Returns whatever the map holds at the deadline, so the
/// caller judges a missing control as strictly as before. With
/// `{ any: true }`, once any one of them is there: whichever of two panels
/// is up (the assistant's brief, or its key form before there is a key).
export async function controlsWith(page, names, ms = 10000, { any = false } = {}) {
  const wanted = [].concat(names || []);
  const read = () => page.evaluate(() => window.brickworksControls || {});
  const until = Date.now() + ms;
  const missing = (where) => (any ? !wanted.some((name) => where[name])
    : wanted.some((name) => !where[name]));
  let where = await read();
  while (missing(where) && Date.now() < until) {
    await page.waitForTimeout(250);
    where = await read();
  }
  return where;
}

/// The page's next [frames] frames, each a turn of the app's loop, however
/// long software drawing makes them: a press is read on the first, so a menu
/// it opens is up once they have run. A fixed wait typed into a menu not up
/// yet on a box drawing three browsers, and a word's letters a frame of over
/// 2 s apart began the menu's search again (cloud_library, 2026-10-31): pick
/// from a menu by its first letter.
export async function framesDrawn(page, frames = 3) {
  await page.evaluate((left) => new Promise((done) => {
    const next = () => (--left > 0 ? requestAnimationFrame(next) : done());
    requestAnimationFrame(next);
  }), frames);
}

/// [words] typed into the menu just opened, to find its row: without spaces
/// (a space presses the row the menu is on) and all in one task, as the keys
/// a person types during a frame reach the page together. Typed a key at a
/// time, each waits for a frame, and a menu begins its search again when
/// more than 2 s pass between two keys (Godot's
/// gui/timers/incremental_search_max_interval_msec): at 2.5 s a frame,
/// together_flow's "Comm" was "m", and My collection opened in place of
/// Comments (2026-10-31). Letters past the row's own words keep the row.
export async function typeInMenu(page, words) {
  await framesDrawn(page, 2);
  await page.evaluate((letters) => {
    const canvas = document.getElementById("canvas") || document.querySelector("canvas");
    for (const key of letters) {
      const code = /[a-z]/i.test(key) ? `Key${key.toUpperCase()}` : /[0-9]/.test(key) ? `Digit${key}` : "";
      for (const type of ["keydown", "keyup"]) canvas.dispatchEvent(new KeyboardEvent(type, { key, code, bubbles: true }));
    }
  }, String(words).replace(/ /g, ""));
}

/// What the app says when it is asked: window.brickworksAsk<what> set, and
/// its answer, window.brickworks<what> (Main._tell_page: "Phone", a finger's
/// targets and the text shown; "Layout", the model's place and its parts;
/// "Words", every word in the window), or null when it has not answered.
///
/// The app answers the first time it tells the page after the ask, which it
/// does on a frame, at most twice a second. So the wait is counted in its
/// tellings, not the clock's seconds: it has [seconds] and [tellings] both.
/// A telling is seen as a new window.brickworksControls, which each one
/// writes. A page just up at 2048 x 2732, drawn in software, drew one frame
/// in 4.4 s at load 24 and over 30 s at load 40, so a fixed 10 s ran out
/// before the app had told the page once: phone and tablet held rel-m236 on
/// "the app said what is on the screen", then passed alone. Null once the
/// app has told the page [tellings] times since the ask without answering
/// (it heard and said nothing), or nothing at all for [quiet] ms (it has
/// stopped drawing); either is said.
export async function askApp(page, what, { seconds = 10, tellings = 20, quiet = START_MS } = {}) {
  const keys = { answer: `brickworks${what}`, ask: `brickworksAsk${what}`, seen: `brickworksSeen${what}` };
  // A look that never comes back is a page that has stopped too.
  const look = async (body) => {
    let timer;
    const late = new Promise((done) => { timer = setTimeout(done, quiet); });
    try {
      return await Promise.race([page.evaluate(body, keys), late]);
    } finally {
      clearTimeout(timer);
    }
  };
  const asked = Date.now();
  await look((k) => {
    window[k.answer] = null;
    window[k.ask] = true;
    window[k.seen] = window.brickworksControls;
  });
  let told = 0;
  let last = asked;
  for (;;) {
    const now = await look((k) => {
      const fresh = window.brickworksControls !== window[k.seen];
      window[k.seen] = window.brickworksControls;
      return { answer: window[k.answer] || null, fresh };
    });
    if (now && now.answer) return now.answer;
    if (now && now.fresh) { told += 1; last = Date.now(); }
    const spent = Date.now() - asked;
    if (told >= tellings && spent >= seconds * 1000) {
      console.log(`  --    the app told the page ${told} times in ${Math.round(spent / 1000)} s `
        + `and did not answer ${what}`);
      return null;
    }
    if (Date.now() - last >= quiet) {
      console.log(`  --    the app told the page nothing for ${Math.round((Date.now() - last) / 1000)} s `
        + `after ${what} was asked (${told} tellings)`);
      return null;
    }
    await page.waitForTimeout(250);
  }
}

/// From a model's page into the app, as a person goes there: since the
/// picture turns the model in 3D in its own place (viewer369, 2026-10-30,
/// web/start3d.js), pressed, then the 3D view's Open in the app, the
/// picture's own link, there once a quarter of the model has drawn, or at
/// once for one too big to turn. A press on the picture alone waited 180 s
/// for an app it never opens (play, share_steps, 2026-10-31). False on a page
/// with no such picture (the local relay's).
export async function appFromModelPage(page, { finger = false, ms = 180000 } = {}) {
  const picture = await page.$('.model-page a.picture[href^="/app?view="]').catch(() => null);
  if (!picture) return false;
  await (finger ? picture.tap() : picture.click());
  const app = await page.waitForSelector(".view3d-app:not([hidden]), .view3d-said a.cta", { state: "visible", timeout: ms });
  await Promise.all([page.waitForURL(/\/app\?view=/, { timeout: ms }), finger ? app.tap() : app.click()]);
  return true;
}

// The assistant's controls, which live in the right-hand column.
const ASSISTANT = /^(key_field|use_key|change_key|brief|build|stop|connect_claude|claude_|connector_)/;
// The model tree's and the properties' controls: down the right-hand
// column, which the assistant shares, or a phone's drawer down the left.
const PROPERTIES = /^(prop_|properties$|outliner|sections_)/;

/// Open the column a control lives in, if it is folded, by its rail — as a
/// person does. A window under the design width (1600 units across: every
/// laptop) shows one column beside the model at a time, so the other
/// column's controls are not on the page until its rail is clicked. And a
/// first visit builds by hand, with no assistant at all (Settings,
/// Assistant (AI)): a control of the assistant's turns it on first
/// ([turnAssistantOn]), which opens its column. A flow's wait for a control
/// calls this again and again while the control has not shown, not once: it
/// does nothing before the app has come up, which on a loaded machine is
/// many seconds after the page (arrival_check asked once, 3 s in, 2026-10-31).
/// Does nothing on a build that does not say which columns are open
/// (brickworksState.columns, from 2026-10-12), or when the control's column
/// is open already, so it is safe to call again. True when it clicked.
export async function openColumnFor(page, name) {
  const everything = await page.evaluate(() => window.brickworksState || {});
  const state = everything.columns || null;
  if (!state) return false;
  const column = ASSISTANT.test(name) ? "assistant" : PROPERTIES.test(name) ? "properties" : "parts";
  if (column === "assistant" && everything.assistant === false) return turnAssistantOn(page);
  if (state[column] !== false) return false;
  const rail = await page.evaluate((n) => (window.brickworksControls || {})[n], `${column}_rail`);
  if (!rail) return false;
  await page.mouse.click(rail.x, rail.y);
  await page.waitForTimeout(1500);
  return true;
}

/// The app's control [name] clicked where it has come to rest, as a person
/// clicks what they see once it has stopped moving. The app tells the page
/// a control's place only once it stood there at the telling before
/// (Main._page_places), but a panel can lay itself out again a frame or
/// more after what changed it: Account's Done moved Connect Claude 136 px
/// after its place was told, the click went where it had been, and rel-m233
/// was held twice on it (oauth_flow, a01d21bf). So the place is read again
/// at the app's next telling, not twice from the same one, until two agree;
/// when no new telling comes in 5 s the app is moving nothing.
///
/// [find] waits until the control shows and gives its place, or null: the
/// flow's own way where it has one (its column opened, a dialog scrolled
/// to it); by default asked every 500 ms for [seconds], five minutes unless
/// said ([START_MS]), and with [open] its column opened every 5 s
/// ([openColumnFor]). Never shown:
/// a picture in [shots], then an error, or false when [optional]. [act]
/// presses the place (a mouse click by default; a finger's tap, a right
/// click), and [after] ms are waited after it. The place it pressed.
export async function clickStill(page, name, { find = null, seconds = START_MS / 1000, open = false,
  shots = "", optional = false, act = (at) => page.mouse.click(at.x, at.y), after = 0 } = {}) {
  const look = find || ((n) => shownWithin(page, n, seconds, open));
  let at = await look(name);
  for (let n = 0; at && n < 10; n++) {
    const again = await nextTelling(page, name);
    if (again === undefined || (again && again.x === at.x && again.y === at.y)) break;
    at = again || (await look(name));
  }
  if (!at) {
    if (shots) await page.screenshot({ path: `${shots}/never_showed_${name}.png` }).catch(() => {});
    if (optional) return false;
    throw new Error(`the app never showed "${name}"${shots ? `; see ${shots}/never_showed_${name}.png` : ""}`);
  }
  await act(at);
  if (after) await page.waitForTimeout(after);
  return at;
}

async function shownWithin(page, name, seconds, open) {
  for (let tries = 0; tries < seconds * 2; tries++) {
    const at = await page.evaluate((n) => (window.brickworksControls || {})[n], name);
    if (at) return at;
    if (open && tries % 10 === 6) await openColumnFor(page, name);
    await page.waitForTimeout(500);
  }
  return null;
}

/// [name]'s place at the app's next telling (null when that telling leaves
/// it out: it moved, or went), or undefined when none comes in [ms]. Each
/// telling is a new window.brickworksControls, told apart from the one
/// there now by identity.
async function nextTelling(page, name, ms = 5000) {
  await page.evaluate(() => { window.brickworksControlsBefore = window.brickworksControls; });
  const next = await page.waitForFunction((n) => {
    const told = window.brickworksControls;
    return told && told !== window.brickworksControlsBefore ? { at: told[n] || null } : false;
  }, name, { timeout: ms, polling: 100 }).catch(() => null);
  return next ? (await next.jsonValue()).at : undefined;
}

/// Open… > "From a file on this computer…", as a person opens a file, and
/// the page's file chooser it brings up, answered with [file] when one is
/// given. Open is pressed once it has come to rest ([clickStill]), then the
/// first row of the menu it opens. The app tells no menu's rows, but this
/// menu opens under the pointer (ModelBar._on_open: 8 px below it), so the
/// row is where the press put it, 40 right and 22 down, once the app has
/// drawn the frames that read the press ([framesDrawn]). Twenty-three flows
/// read Open's place once, pressed it there, and pressed the row a fixed 3
/// to 12 s later: on a busy box the toolbar could still be laying itself
/// out, or the menu not up yet (2026-11-01). Tried again, the menu shut by
/// Escape, when no chooser comes in 30 s.
///
/// The chooser is caught into [choosers] (page.choosers by default) by a
/// listener the page has had from its start: Playwright stops a chooser
/// only while something listens for one, and a waitForEvent added just
/// before the press was sometimes switched on after the app had asked, so
/// the chooser was never seen (studio_flow). The chooser, or null when none
/// came and [optional]; otherwise an error. A picture of each try that
/// brought none, and of an Open never shown, in [shots].
export async function openFromFile(page, file = null, { choosers = page.choosers, shots = "",
  optional = false } = {}) {
  if (!choosers) throw new Error("openFromFile: the page catches no file choosers (page.choosers)");
  for (let n = 0; n < 3; n++) {
    choosers.length = 0;
    const at = await clickStill(page, "open", { shots });
    await framesDrawn(page, 3);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && choosers.length === 0; wait++) await page.waitForTimeout(500);
    const chooser = choosers.shift();
    if (chooser) {
      if (file) await chooser.setFiles(file);
      return chooser;
    }
    if (shots) await page.screenshot({ path: `${shots}/no_picker_${n}.png` }).catch(() => {});
    await page.keyboard.press("Escape");
    await framesDrawn(page, 3);
  }
  if (optional) return null;
  throw new Error(`Open… > From a file brought no file chooser${shots ? `; see ${shots}/no_picker_*.png` : ""}`);
}

/// The app's address as the site links to it for someone who came for the
/// assistant: `assistant=on` added (Main._assistant_from_address). A first
/// visit builds by hand with the connector held off, so a flow that drives
/// Claude through the connector arrives this way, as such a person does.
export function withAssistant(address) {
  if (/[?&]assistant=/.test(address)) return address;
  return `${address}${address.includes("?") ? "&" : "?"}assistant=on`;
}

/// The assistant on, as a person turns it on: Settings (the comma key), the
/// choice "Show the assistant", and Done. A first visit builds by hand, with
/// no assistant anywhere in the window (the app's ShellPrefs.assistant_shown),
/// so a flow that drives the assistant asks for it first; turned on, its
/// column opens. Does nothing on a build that does not say
/// (brickworksState.assistant, from 2026-10-13) or when it is on already.
/// True when it turned it on.
export async function turnAssistantOn(page) {
  return chooseAssistant(page, true);
}

/// Settings, Assistant (AI): on or off, by the clicks a person makes. True
/// when it changed it.
export async function chooseAssistant(page, on) {
  const now = () => page.evaluate(() => (window.brickworksState || {}).assistant);
  const was = await now();
  if (was === undefined || was === on) return false;
  const named = () => page.evaluate(() => window.brickworksControls || {});
  const choice = on ? "assistant_on" : "assistant_off";
  for (let tries = 0; tries < 60 && !(await named())[choice]; tries++) {
    // The comma key is Settings; a page that has not had a click yet may
    // not have the keys, so the model is clicked once to give them to it.
    if (tries === 8) {
      const view = (await named()).view;
      if (view) await page.mouse.click(view.x, view.y);
    }
    if (tries % 8 === 0) await page.keyboard.press("Comma");
    await page.waitForTimeout(500);
  }
  let where = (await named())[choice];
  if (!where) return false;
  // Below the foot of a short screen (a phone on its side: Settings is
  // taller than 390 points), scrolled up into sight as a person scrolls,
  // and read again once it stands still (Main._page_places). In sight is
  // whole and above Done, which stands over the dialog's foot: half under
  // it at 844 x 390, the click went to Done and closed Settings.
  const pageSize = page.viewportSize();
  const done = (await named()).settings_done;
  const foot = done ? done.y - done.h / 2 : pageSize.height;
  const hidden = (at) => at.y - at.h / 2 < 0 || at.y + at.h / 2 > foot;
  for (let tries = 0; tries < 12 && where && hidden(where); tries++) {
    await page.mouse.move(pageSize.width / 2, pageSize.height / 2);
    await page.mouse.wheel(0, where.y - pageSize.height / 2);
    await page.waitForTimeout(500);
    where = null;
    for (let n = 0; n < 12 && !where; n++) {
      where = (await named())[choice];
      if (!where) await page.waitForTimeout(250);
    }
  }
  if (!where) return false;
  await page.mouse.click(where.x, where.y);
  for (let tries = 0; tries < 40 && (await now()) !== on; tries++) await page.waitForTimeout(250);
  if (done) await page.mouse.click(done.x, done.y);
  await page.waitForTimeout(1500);
  return (await now()) === on;
}

/// Tool calls made as a session makes them (src/net/tool_jobs.gd). A call
/// still going after 20 s answers "Started job N": the job tool is called
/// (it waits up to 10 s a time) until the job is done, and its answer is the
/// call's. A call made while a job holds the app answers "The app is busy
/// with job N": that job is followed, then the call made again. On a loaded
/// box the knowledge check's own edit_model became a job and the call after
/// it was turned away, so the check failed with the app doing as it says
/// (2026-10-15). `claude(method, params)` sends one request; the wrapped one
/// has the same shape.
export function withJobs(claude, { waits = 60 } = {}) {
  const said = (answer) => (answer?.result?.content || []).map((c) => c.text || "").join(" ");
  const follow = async (id) => {
    let answer;
    for (let n = 0; n < waits; n++) {
      answer = await claude("tools/call", { name: "job", arguments: { id } });
      if (!/is still going/.test(said(answer))) break;
    }
    return answer;
  };
  return async (method, params) => {
    if (method !== "tools/call" || params?.name === "job") return claude(method, params);
    for (let tries = 0; ; tries++) {
      const answer = await claude(method, params);
      const busy = /The app is busy with job (\d+)/.exec(said(answer));
      if (busy && tries < 3) { await follow(Number(busy[1])); continue; }
      const started = /Started job (\d+)/.exec(said(answer));
      return started ? follow(Number(started[1])) : answer;
    }
  };
}
