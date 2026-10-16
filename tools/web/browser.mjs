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

export async function launch(options = {}) {
  const { signedOut = false, ...rest } = options;
  const browser = await chromium.launch({ ...rest, args: [...SOFTWARE, ...(rest.args || [])] });
  const newContext = browser.newContext.bind(browser);
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

// The assistant's controls, which live in the right-hand column.
const ASSISTANT = /^(key_field|use_key|change_key|brief|build|stop|connect_claude|claude_|connector_)/;

/// Open the column a control lives in, if it is folded, by its rail — as a
/// person does. A window under the design width (1600 units across: every
/// laptop) shows one column beside the model at a time, so the other
/// column's controls are not on the page until its rail is clicked. And a
/// first visit builds by hand, with no assistant at all (Settings,
/// Assistant (AI)): a control of the assistant's turns it on first
/// ([turnAssistantOn]), which opens its column. A flow's wait for a control
/// calls this while the control has not shown. Does nothing on a build that
/// does not say which columns are open (brickworksState.columns, from
/// 2026-10-12), or when the control's column is open already, so it is safe
/// to call again. True when it clicked.
export async function openColumnFor(page, name) {
  const everything = await page.evaluate(() => window.brickworksState || {});
  const state = everything.columns || null;
  if (!state) return false;
  const column = ASSISTANT.test(name) ? "assistant" : "parts";
  if (column === "assistant" && everything.assistant === false) return turnAssistantOn(page);
  if (state[column] !== false) return false;
  const rail = await page.evaluate((n) => (window.brickworksControls || {})[n], `${column}_rail`);
  if (!rail) return false;
  await page.mouse.click(rail.x, rail.y);
  await page.waitForTimeout(1500);
  return true;
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
  const where = (await named())[choice];
  if (!where) return false;
  await page.mouse.click(where.x, where.y);
  for (let tries = 0; tries < 40 && (await now()) !== on; tries++) await page.waitForTimeout(250);
  const done = (await named()).settings_done;
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
