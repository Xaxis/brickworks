// Sign in with orangecheck (2026-10-23), in a real browser, without making
// anybody an orangecheck account: what a deployment shows and refuses before
// orangecheck's own window takes over.
//
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/oc_flow.mjs --url=<deployment> --out=shots/oc
//
//   0. Offered to everybody, as /api/account says (api/_oc_config.js, the
//      one switch): drawn with no flag on the address (?oc=1 is gone).
//   1. The sign-in dialog (from /profile signed out) has Sign in with
//      orangecheck under the email, with its words, at 390 and 1280 px in
//      light and dark, nothing sideways.
//   2. Where the deployment has no signing secret (a unit's preview), the
//      button says sign-in with orangecheck is unavailable, and opens
//      nothing. Elsewhere it opens orangecheck's window (me.ochk.io) from
//      the click; closed, the dialog stays as it was and says nothing. A
//      browser that blocks the window is told so, in words, and how to
//      allow it. Sent from the app (/profile?then=/app), the dialog opens
//      by itself to go back there; with an address elsewhere, nothing opens.
//   3. The page loads its orangecheck code from its own origin, with no
//      refusal from the page's security policy.
//   4. The site's pages send Cross-Origin-Opener-Policy
//      same-origin-allow-popups, so the window can answer; /app keeps
//      same-origin for its threads.
//   5. The server: nothing, junk, or a GET refused in words; never cached;
//      no other site may read its answer; without the signing secret,
//      sign-in with orangecheck said to be unavailable. An orangecheck
//      account's made-up address is refused a sign-in code.
//   6. /settings for an email account (a throwaway at a Resend test
//      address, deleted after) offers Link orangecheck with its words, at
//      390 and 1280 in light and dark; with the code just redeemed, the
//      button opens orangecheck's window from the click. Linking without a
//      sign-in is refused.
//   Step 4 (2026-10-24, oc225): every button is orangecheck's own
//   (data-oc-sign-in, enhanced by web/oc-button.mjs, its mark drawn, its
//   stylesheet web/oc-button.css loaded from this origin under the page's
//   policy), and still the kit's secondary button beside Email me a code.
//   7. orangecheck Connect's box under it: unticked, in orangecheck's exact
//      words (web/oc-connect-consent.mjs). Ticked, a sign-in by emailed code
//      asks for an orangecheck account once; unticked, never; a failed ask
//      still signs in. orangecheck is stood in for, here in the browser,
//      on every deployment: the box where the deployment has no Connect key
//      (a unit's preview), and ?op=connect always, so this flow never makes
//      anybody an orangecheck account (oc_live_flow.mjs does, on
//      brickworks.diy). Deleting an account Connect made one for asks
//      orangecheck first: without the key it says so and deletes nothing.
// A finished orangecheck sign-in needs a wallet and orangecheck's list of
// ended sessions for the domain, which a preview's address is not:
// tools/web/oc_live_flow.mjs does that on brickworks.diy.
import { launch } from "./browser.mjs";
import { deleteAccount, mintCode, mintSession, STORAGE_KEY } from "./session.mjs";
// orangecheck's own words, as this checkout serves them.
import { OUTCOME_COPY } from "../../web/oc-button.mjs";
import { CONNECT_CONSENT_BLURB, CONNECT_CONSENT_LABEL } from "../../web/oc-connect-consent.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("oc_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const host = new URL(site).hostname;
const out = args.out || "shots/oc";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
// Only ever to this site: orangecheck's window is opened from the same
// browser, and must never be sent the bypass.
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let failed = 0;
const check = (what, ok, said = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said && !ok ? `: ${said}` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/Content Security Policy|Refused to|Failed to load module/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
// A step that must answer within [ms], or fail saying which step it was.
const within = (ms, what, promise) => Promise.race([promise,
  new Promise((_, no) => setTimeout(() => no(new Error(`${what}: no answer in ${ms / 1000} s`)), ms).unref())]);
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function api(pathname, { method = "GET", body, raw } = {}) {
  const sent = { ...headers, origin: "https://elsewhere.example" };
  if (body !== undefined || raw !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent,
    body: raw !== undefined ? raw : body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, headers: reply.headers, json: await reply.json().catch(() => null) };
}

const browser = await launch({ signedOut: true });
const person = `delivered+bw-oc-flow-${randomBytes(4).toString("hex")}@resend.dev`;

// orangecheck Connect, stood in for in the browser: each ask the page makes
// (?op=connect) kept, and answered as set, never sent on.
const connectAsks = [];
let connectAnswer = [200, { made: true, did: "did:oc:00000000000000000000000000000000" }];

async function context(width, theme, { blockWindows = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: theme });
  await made.route(`${site}/**`, (route) => route.continue({ headers: { ...route.request().headers(), ...headers } }));
  // A deployment without the Connect key offers no box: offered here.
  await made.route(`${site}/api/account`, async (route) => {
    if (route.request().method() !== "GET" || route.request().headers().authorization) {
      return route.continue({ headers: { ...route.request().headers(), ...headers } });
    }
    const reply = await route.fetch({ headers: { ...route.request().headers(), ...headers } });
    const said = await reply.json();
    if (said.orangecheck) said.orangecheck.connect = true;
    return route.fulfill({ response: reply, json: said });
  });
  await made.route(`${site}/api/orangecheck?op=connect`, (route) => {
    const request = route.request();
    connectAsks.push({ method: request.method(), body: request.postDataJSON(), signedIn: /^Bearer \S+/.test(request.headers().authorization || "") });
    const [status, json] = connectAnswer;
    return route.fulfill({ status, json });
  });
  await made.addInitScript(([chosen, block]) => {
    try {
      localStorage.setItem("brickworks.theme", chosen);
    } catch { /* none */ }
    if (block) window.open = () => null;
  }, [theme, blockWindows]);
  return made;
}

async function openDialog(page) {
  await page.goto(`${site}/profile`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.locator("#sign-in").waitFor({ state: "visible", timeout: 60000 });
  await page.locator("#sign-in").click();
  await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
}

// What the deployment says of orangecheck (api/_oc_config.js): whether it
// takes a token here, and whether everybody is offered it.
const offer = (await (await fetch(`${site}/api/account`, { headers })).json()).orangecheck || {};
console.log(`  --    orangecheck here: ${offer.ready ? "takes a token" : "unavailable (no signing secret)"}, `
  + `offered to ${offer.everyone ? "everybody" : "nobody"}, Connect ${offer.connect ? "set up" : "not set up (stood in for)"}`);

try {
  // 0. Who is offered it: everybody, with nothing on the address.
  {
    const made = await context(1280, "light");
    const page = await made.newPage();
    await openDialog(page);
    await page.locator("dialog.sign-in #oc-sign-in").waitFor({ state: "visible", timeout: 15000 }).catch(() => null);
    const drawn = await page.locator("dialog.sign-in #oc-sign-in").isVisible();
    check("offered to everybody, with no flag on the address", offer.everyone === true && drawn, `everyone ${offer.everyone}, drawn ${drawn}`);
    await made.close();
  }

  // 1. The dialog, at both widths, in both themes.
  for (const width of [390, 1280]) {
    for (const theme of ["light", "dark"]) {
      const made = await context(width, theme);
      const page = await made.newPage();
      listen(page, `${width} ${theme}`);
      await openDialog(page);
      const button = page.locator("dialog.sign-in #oc-sign-in");
      // Drawn once the page has heard whether it is offered (/api/account).
      await button.waitFor({ state: "visible", timeout: 15000 }).catch(() => null);
      const said = await page.locator("dialog.sign-in .elsewhere .note").textContent().catch(() => "");
      check(`${width} ${theme}: Sign in with orangecheck under the email`, await button.isVisible()
        && (await button.textContent()) === "Sign in with orangecheck"
        && said === "A Bitcoin wallet, email, Google or GitHub. Brickworks gets an id for you, not your address.", said);
      const looks = await page.evaluate(() => {
        const b = document.querySelector("#oc-sign-in");
        const e = document.querySelector("dialog.sign-in .elsewhere");
        const go = document.querySelector("dialog.sign-in button[type=submit]");
        const r = b.getBoundingClientRect();
        const d = document.querySelector("dialog.sign-in").getBoundingClientRect();
        const style = getComputedStyle(b);
        return { inside: r.left >= d.left && r.right <= d.right && r.bottom <= d.bottom,
          below: e.getBoundingClientRect().top >= go.getBoundingClientRect().bottom,
          ghost: b.classList.contains("cta") && b.classList.contains("ghost"),
          height: Math.round(r.height), ink: style.color, theme: document.documentElement.getAttribute("data-theme") };
      });
      check(`${width} ${theme}: drawn as the kit's secondary button, inside the dialog, below the email`,
        looks.inside && looks.below && looks.ghost && looks.height >= 40 && looks.theme === theme, JSON.stringify(looks));
      const theirs = await page.evaluate(() => {
        const b = document.querySelector("#oc-sign-in");
        const go = document.querySelector("dialog.sign-in button[type=submit]");
        const mark = b.querySelector("svg[data-oc-mark]");
        const words = b.querySelector("[data-oc-label]");
        const sheet = [...document.styleSheets].find((one) => one.href && new URL(one.href).pathname === "/oc-button.css");
        let rules = 0;
        try {
          rules = sheet ? sheet.cssRules.length : 0;
        } catch { /* another origin's */ }
        const m = mark ? mark.getBoundingClientRect() : null;
        return { attr: b.hasAttribute("data-oc-sign-in"), variant: mark?.getAttribute("data-oc-mark"),
          first: b.firstElementChild === mark, ink: [...(mark?.querySelectorAll("polygon") || [])].every((one) => one.getAttribute("fill") === "currentColor"),
          markWide: m ? Math.round(m.width) : 0, words: words?.textContent, sheet: sheet ? new URL(sheet.href).origin === location.origin : false, rules,
          height: Math.round(b.getBoundingClientRect().height), goHeight: Math.round(go.getBoundingClientRect().height),
          radius: getComputedStyle(b).borderRadius === getComputedStyle(go).borderRadius,
          font: getComputedStyle(b).fontSize === getComputedStyle(go).fontSize && getComputedStyle(b).fontWeight === getComputedStyle(go).fontWeight };
      });
      check(`${width} ${theme}: it is orangecheck's button (data-oc-sign-in), its mono mark in the button's ink before its words`,
        theirs.attr && theirs.variant === "mono" && theirs.first && theirs.ink && theirs.markWide >= 16 && theirs.words === "Sign in with orangecheck",
        JSON.stringify(theirs));
      check(`${width} ${theme}: its stylesheet is orangecheck's, from this site, read under the page's policy`, theirs.sheet && theirs.rules > 0,
        JSON.stringify(theirs));
      check(`${width} ${theme}: and it looks like Email me a code's kind: the same height, corners and type`,
        theirs.height === theirs.goHeight && theirs.height >= 44 && theirs.radius && theirs.font, JSON.stringify(theirs));
      const box = await page.evaluate(() => {
        const tick = document.querySelector("dialog.sign-in #oc-connect");
        const label = tick?.closest("label");
        const blurb = document.querySelector("dialog.sign-in #oc-connect-blurb");
        const b = document.querySelector("#oc-sign-in").getBoundingClientRect();
        return { drawn: Boolean(tick && tick.checkVisibility()), checked: tick?.checked, label: label?.textContent.trim(),
          blurb: blurb?.textContent, described: tick?.getAttribute("aria-describedby") === "oc-connect-blurb",
          under: tick ? label.getBoundingClientRect().top >= b.bottom : false, choice: label?.classList.contains("choice") };
      });
      check(`${width} ${theme}: under it, orangecheck Connect's box, unticked, with orangecheck's exact words`, box.drawn && box.checked === false
        && box.label === CONNECT_CONSENT_LABEL && box.blurb === CONNECT_CONSENT_BLURB && box.described && box.under && box.choice, JSON.stringify(box));
      check(`${width} ${theme}: nothing sideways`, !(await sideways(page)));
      // The pointer off the dialog: the click that opened it leaves it over
      // whatever button is drawn there now.
      await page.mouse.move(1, 1);
      const [primary, page_] = await page.evaluate(() => [
        getComputedStyle(document.querySelector("dialog.sign-in button[type=submit]")).backgroundColor,
        getComputedStyle(document.querySelector("#sign-in")).backgroundColor]);
      check(`${width} ${theme}: Email me a code stays the primary, as the page's Sign in is`, primary === page_, `${primary} ${page_}`);
      await page.hover("dialog.sign-in button[type=submit]");
      const hovered = await page.evaluate(() => getComputedStyle(document.querySelector("dialog.sign-in button[type=submit]")).backgroundColor);
      check(`${width} ${theme}: and under the pointer`, hovered === page_, `${hovered} ${page_}`);
      await page.mouse.move(1, 1);
      await shot(page, `dialog_${width}_${theme}.png`);
      await made.close();
    }
  }

  // 2. Where orangecheck takes no token: the button says so, and opens nothing.
  if (!offer.ready) {
    const made = await context(390, "light");
    const page = await made.newPage();
    listen(page, "unavailable");
    let opened = false;
    page.on("popup", () => { opened = true; });
    await openDialog(page);
    await page.locator("#oc-sign-in").click();
    await page.waitForTimeout(1500);
    const said = await page.locator("dialog.sign-in .said").textContent();
    check("unavailable here: the button says so, in words, and opens no window",
      said === "Signing in with orangecheck is unavailable here. Sign in with your email instead." && !opened, said);
    await page.mouse.move(1, 1);
    await shot(page, "unavailable_390_light.png");
    await made.close();
  }

  // 2. The window: opened from the click, at orangecheck; closed, nothing said.
  if (offer.ready) {
    const made = await context(1280, "light");
    const leaked = [];
    made.on("request", (request) => {
      if (new URL(request.url()).origin !== new URL(site).origin && request.headers()["x-vercel-protection-bypass"]) leaked.push(request.url());
    });
    const page = await made.newPage();
    listen(page, "window");
    await openDialog(page);
    const [popup] = await Promise.all([
      page.waitForEvent("popup", { timeout: 30000 }),
      page.locator("#oc-sign-in").click(),
    ]);
    await popup.waitForLoadState("domcontentloaded", { timeout: 60000 }).catch(() => null);
    const where = new URL(popup.url());
    check("the button opens orangecheck's sign-in window", where.origin === "https://me.ochk.io", popup.url());
    check("while it is open the dialog says so", /orangecheck/.test(await page.locator("dialog.sign-in .said").textContent()));
    await popup.waitForTimeout(3000);
    await shot(popup, "window_1280.png");
    await popup.close();
    check("nothing but this site was sent the deployment's bypass", leaked.length === 0, leaked.slice(0, 2).join(" "));
    await page.waitForFunction(() => !document.querySelector("#oc-sign-in")?.disabled, null, { timeout: 15000 }).catch(() => null);
    const after = await page.evaluate(() => ({ open: document.querySelector("dialog.sign-in")?.open,
      said: document.querySelector("dialog.sign-in .said")?.textContent, enabled: !document.querySelector("#oc-sign-in").disabled }));
    check("closed, the dialog stays, says so in orangecheck's words, and can try again", after.open === true
      && after.said === OUTCOME_COPY.closed && after.enabled, JSON.stringify(after));
    await made.close();
  }
  if (offer.ready) {
    const made = await context(390, "dark", { blockWindows: true });
    const page = await made.newPage();
    listen(page, "blocked");
    await openDialog(page);
    await page.locator("#oc-sign-in").click();
    await page.waitForFunction(() => /blocked/.test(document.querySelector("dialog.sign-in .said")?.textContent || ""), null,
      { timeout: 15000 }).catch(() => null);
    const said = await page.locator("dialog.sign-in .said").textContent();
    check("a blocked window is said in orangecheck's words, with how to allow it", said === OUTCOME_COPY.blocked, said);
    await shot(page, "blocked_390_dark.png");
    await made.close();
  }

  // 2b. From the app's sign-in screen: /profile?then=/app opens the dialog
  // by itself, to go back to the app; never to an address elsewhere.
  {
    const made = await context(390, "light");
    const page = await made.newPage();
    listen(page, "from the app");
    await page.goto(`${site}/profile?then=${encodeURIComponent("/app")}`, { waitUntil: "domcontentloaded", timeout: 120000 });
    const opened = await page.locator("dialog.sign-in #oc-sign-in").waitFor({ state: "visible", timeout: 60000 }).then(() => true, () => false);
    const said = await page.locator("dialog.sign-in p").first().textContent().catch(() => "");
    check("sent from the app, the sign-in opens by itself and says it goes back", opened && /back to the app/.test(said), said);
    await page.mouse.move(1, 1);
    await shot(page, "from_app_390_light.png");
    await page.goto(`${site}/profile?then=${encodeURIComponent("https://elsewhere.example/")}`, { waitUntil: "domcontentloaded" });
    await page.locator("#sign-in").waitFor({ state: "visible", timeout: 60000 });
    await page.waitForTimeout(1500);
    check("sent with an address elsewhere, nothing opens and nothing is followed",
      !(await page.locator("dialog.sign-in").isVisible().catch(() => false)) && new URL(page.url()).origin === new URL(site).origin);
    await made.close();
  }

  // 3. Loaded from here, and nothing refused.
  for (const [file, type, has] of [["/oc-button.mjs", /javascript/, /enhanceSignInButton/], ["/oc-button.css", /text\/css/, /data-oc-sign-in/],
    ["/oc-connect-consent.mjs", /javascript/, /CONNECT_CONSENT_LABEL/]]) {
    const code = await fetch(site + file, { headers });
    check(`orangecheck's ${file} is served from this site, as orangecheck made it`,
      code.ok && type.test(code.headers.get("content-type") || "") && has.test(await code.text()), `${code.status} ${code.headers.get("content-type")}`);
  }
  const gone = await fetch(`${site}/oc-popup.mjs`, { headers });
  check("the popup module it replaces is gone", gone.status === 404, String(gone.status));
  check("no refusal from the page's security policy, no error", errors.length === 0, errors.slice(0, 3).join(" | "));

  // 4. Who may open a window.
  for (const [pathname, wanted] of [["/", "same-origin-allow-popups"], ["/profile", "same-origin-allow-popups"],
    ["/gallery", "same-origin-allow-popups"], ["/settings", "same-origin-allow-popups"], ["/app", "same-origin"]]) {
    const reply = await fetch(site + pathname, { headers });
    check(`${pathname} sends Cross-Origin-Opener-Policy ${wanted}`, reply.headers.get("cross-origin-opener-policy") === wanted,
      String(reply.headers.get("cross-origin-opener-policy")));
  }

  // 5. The server.
  const none = await api("/api/orangecheck?op=signin", { method: "POST", body: {} });
  const junk = await api("/api/orangecheck?op=signin", { method: "POST", body: { token: "not.a.token" } });
  // A deployment without the project's signing secret (Vercel's Preview
  // environment has the key at most) takes no token, and says so; the
  // button is drawn all the same (above).
  const available = !(none.status === 503 && /unavailable here/.test(none.json?.error || ""));
  if (!available) {
    console.log("  --    no signing secret here: orangecheck sign-in is unavailable on this deployment");
    check("without the signing secret, sign-in with orangecheck is said to be unavailable, with email offered",
      /Sign in with your email/.test(none.json.error) && junk.status === 503 && junk.json?.error === none.json.error, none.json.error);
  } else {
    check("no token: refused in words", none.status === 422 && /orangecheck/.test(none.json?.error || ""), `${none.status}`);
    check("a token that is not one: refused in words", junk.status === 401 && (junk.json?.error || "").length > 20,
      `${junk.status} ${junk.json?.error || ""}`);
  }
  check("never cached, and no other site may read it", junk.headers.get("cache-control") === "no-store"
    && !junk.headers.get("access-control-allow-origin"));
  const broken = await api("/api/orangecheck?op=signin", { method: "POST", raw: "{" });
  // Vercel's own body parser answers this one, before the route; where
  // orangecheck is unavailable the route answers first.
  check("a body that is not JSON: refused", broken.status === 400 || broken.status === 422
    || (!offer.ready && broken.status === 503), `${broken.status}`);
  const get = await api("/api/orangecheck?op=signin");
  check("anything but POST ?op=signin: refused", get.status === 405, `${get.status}`);
  const madeUp = await api("/api/otp", { method: "POST", body: { email: "0123456789abcdef0123456789abcdef@oc.brickworks.diy" } });
  check("an orangecheck account's made-up address gets no code", madeUp.status === 422 && /orangecheck/.test(madeUp.json?.error || ""),
    `${madeUp.status} ${madeUp.json?.error || ""}`);

  // 6. /settings, for an account with its own email.
  // Where orangecheck takes no token, linking is said to be unavailable
  // before anything is asked of who is linking.
  const unsigned = await api("/api/orangecheck?op=link", { method: "POST", body: { token: "not.a.token" } });
  check(available ? "linking without a sign-in: refused" : "linking where orangecheck is unavailable: said so, in words",
    available ? unsigned.status === 401 : unsigned.status === 503 && /not set up here/.test(unsigned.json?.error || ""),
    `${unsigned.status} ${unsigned.json?.error || ""}`);
  // Settings offer orangecheck only where it signs people in.
  const session = available ? await mintSession(person, { age: true }) : null;
  for (const width of available ? [390, 1280] : []) {
    for (const theme of ["light", "dark"]) {
      // The account keeps the theme too (web/theme-account.js), and a
      // signed-in page follows it: set it to the one looked at.
      await fetch(`${site}/api/account?op=theme`, { method: "POST",
        headers: { ...headers, authorization: `Bearer ${session.access_token}`, "content-type": "application/json" },
        body: JSON.stringify({ theme }) });
      const made = await context(width, theme);
      await made.addInitScript(([name, value]) => {
        try {
          if (!localStorage.getItem(name)) localStorage.setItem(name, value);
        } catch { /* none */ }
      }, [STORAGE_KEY, JSON.stringify(session.kept)]);
      const page = await made.newPage();
      listen(page, `settings ${width} ${theme}`);
      await page.goto(`${site}/settings`, { waitUntil: "domcontentloaded", timeout: 120000 });
      await page.locator("#oc-part").waitFor({ state: "visible", timeout: 60000 }).catch(() => null);
      const said = await page.locator("#oc-said").textContent().catch(() => "");
      check(`settings ${width} ${theme}: Link orangecheck, with its words`, await page.locator("#oc-go").isVisible()
        && (await page.locator("#oc-go").textContent()) === "Link orangecheck" && /^Link orangecheck to sign in with it/.test(said), said);
      const linkIs = await page.evaluate(() => ({
        link: Boolean(document.querySelector("#oc-go[data-oc-sign-in].cta.ghost svg[data-oc-mark=mono]")),
        remove: Boolean(document.querySelector("#delete-oc[data-oc-sign-in].cta.ghost.danger svg[data-oc-mark=mono]")),
        unlink: document.querySelector("#oc-unlink")?.hidden === true,
        height: Math.round(document.querySelector("#oc-go").getBoundingClientRect().height) }));
      check(`settings ${width} ${theme}: Link orangecheck is orangecheck's button, the kit's secondary, and so is an orangecheck account's delete`,
        linkIs.link && linkIs.remove && linkIs.unlink && linkIs.height >= 44, JSON.stringify(linkIs));
      check(`settings ${width} ${theme}: nothing sideways, drawn ${theme}`, !(await sideways(page))
        && await page.evaluate((wanted) => document.documentElement.getAttribute("data-theme") === wanted, theme));
      await page.locator("#oc-part").scrollIntoViewIfNeeded();
      await shot(page, `settings_${width}_${theme}.png`);
      if (width === 1280 && theme === "light") {
        // m162's battery sat an hour after this window opened, under load,
        // and kept nothing to say why (2026-10-24). Each step now has a
        // bound, and the window's requests, its console and what the page
        // was posted are kept for orangecheck to read if one stalls.
        const trail = [];
        const note = (line) => trail.push(`${new Date().toISOString()} ${line}`);
        await page.evaluate(() => {
          window.__ocHeard = [];
          addEventListener("message", (e) => window.__ocHeard.push(`${new Date().toISOString()} ${e.origin} ${typeof e.data}`));
        });
        const [popup] = await Promise.all([
          page.waitForEvent("popup", { timeout: 30000 }),
          page.locator("#oc-go").click(),
        ]);
        note(`opened ${popup.url()}`);
        popup.on("console", (m) => note(`console ${m.type()}: ${m.text().slice(0, 200)}`));
        popup.on("request", (r) => note(`${r.method()} ${r.url().slice(0, 160)}`));
        popup.on("requestfailed", (r) => note(`failed ${r.url().slice(0, 160)}: ${r.failure()?.errorText}`));
        check("with a code just redeemed, Link orangecheck opens orangecheck's window", new URL(popup.url()).origin === "https://me.ochk.io",
          popup.url());
        try {
          await within(60000, "closing orangecheck's window", popup.close());
          note("closed");
          await page.waitForFunction(() => !document.querySelector("#oc-go")?.disabled, null, { timeout: 15000 }).catch(() => null);
          const status = await within(60000, "reading #oc-status", page.locator("#oc-status").textContent());
          const label = await within(60000, "reading #oc-go", page.locator("#oc-go").textContent());
          check("closed, nothing is linked, and it says so in orangecheck's words", status === OUTCOME_COPY.closed && label === "Link orangecheck",
            `${status} ${label}`);
        } catch (trouble) {
          const heard = await within(10000, "reading what the page heard", page.evaluate(() => window.__ocHeard)).catch(() => ["(page did not answer)"]);
          writeFileSync(path.join(out, "popup_trail.txt"), [...trail, "-- the page heard:", ...heard, `-- ${trouble.message}`].join("\n") + "\n");
          check("closed, nothing is linked and nothing said", false, `${trouble.message}; trail in ${path.join(out, "popup_trail.txt")}`);
        }
      }
      await made.close();
    }
  }
  check("no refusal from the page's security policy, no error, on /settings either", errors.length === 0, errors.slice(0, 3).join(" | "));

  // 7. orangecheck Connect's box, ticked or not, at a sign-in by emailed code.
  const signInByCode = async ({ tick }) => {
    const made = await context(390, "light");
    const page = await made.newPage();
    listen(page, `connect ${tick ? "ticked" : "unticked"}`);
    await openDialog(page);
    await page.locator("dialog.sign-in #oc-connect").waitFor({ state: "visible", timeout: 15000 });
    if (tick) await page.locator("dialog.sign-in #oc-connect").check();
    await page.fill("dialog.sign-in form input", person);
    await page.click('dialog.sign-in button[type="submit"]');
    await page.waitForFunction(() => /The code sent to/.test(document.querySelector("dialog.sign-in label")?.textContent || ""), null, { timeout: 30000 });
    const ticked = await page.locator("dialog.sign-in #oc-connect").isChecked();
    const shown = await page.locator("dialog.sign-in #oc-connect").isVisible();
    if (tick) await shot(page, "connect_ticked_390_light.png");
    await page.fill("dialog.sign-in form input", await mintCode(person));
    await page.click('dialog.sign-in button[type="submit"]');
    const signedIn = await page.waitForFunction((key) => {
      try {
        return Boolean(JSON.parse(localStorage.getItem(key) || "null")?.refresh_token);
      } catch {
        return false;
      }
    }, STORAGE_KEY, { timeout: 30000 }).then(() => true, () => false);
    // The ask is never waited on: a moment for it to go.
    await page.waitForTimeout(3000);
    await made.close();
    return { signedIn, ticked, shown };
  };
  connectAsks.length = 0;
  const unticked = await signInByCode({ tick: false });
  check("Connect: unticked, a sign-in by code asks for no orangecheck account", unticked.signedIn && connectAsks.length === 0,
    `${JSON.stringify(unticked)} ${connectAsks.length} asks`);
  connectAsks.length = 0;
  const ticked = await signInByCode({ tick: true });
  check("Connect: ticked, the box stays ticked through the code, and the sign-in asks once, signed in, with consent",
    ticked.signedIn && ticked.ticked && ticked.shown && connectAsks.length === 1 && connectAsks[0].method === "POST"
    && connectAsks[0].signedIn && connectAsks[0].body?.consent === true, `${JSON.stringify(ticked)} ${JSON.stringify(connectAsks)}`);
  connectAsks.length = 0;
  connectAnswer = [503, { error: "orangecheck is down" }];
  const failing = await signInByCode({ tick: true });
  check("Connect: an ask that fails still signs in", failing.signedIn && connectAsks.length === 1, `${JSON.stringify(failing)} ${connectAsks.length}`);
  connectAnswer = [200, { made: true }];

  // Deleting an account Connect made one for asks orangecheck first.
  {
    const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const secret = process.env.SUPABASE_SECRET_KEY || "";
    const leaver = `delivered+bw-oc-flow-leave-${randomBytes(4).toString("hex")}@resend.dev`;
    const theirs = await mintSession(leaver, { age: true });
    const asked = await fetch(`${SB}/rest/v1/rpc/oc_connect_asked`, { method: "POST",
      headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" },
      body: JSON.stringify({ account: theirs.kept.user_id }) });
    const quit = await fetch(`${site}/api/account?op=delete`, { method: "POST",
      headers: { ...headers, authorization: `Bearer ${theirs.access_token}`, "content-type": "application/json" },
      body: JSON.stringify({ confirm: leaver }) });
    const said = await quit.json().catch(() => ({}));
    const still = await fetch(`${SB}/auth/v1/admin/users/${theirs.kept.user_id}`, { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
    if (offer.connect) {
      check("Connect: deleting an account Connect made one for asks orangecheck to delete it, then deletes the account",
        asked.ok && quit.status === 200 && still.status === 404, `${asked.status} ${quit.status} ${said.error || ""} ${still.status}`);
    } else {
      check("Connect: deleting an account Connect made one for asks orangecheck first: with no Connect key here, it says so and deletes nothing",
        asked.ok && quit.status === 503 && /orangecheck could not delete/.test(said.error || "") && still.status === 200,
        `${asked.status} ${quit.status} ${said.error || ""} ${still.status}`);
    }
    await deleteAccount(leaver).catch(() => false);
  }
  check("no refusal from the page's security policy, no error, signing in with the box", errors.length === 0, errors.slice(0, 3).join(" | "));
} catch (trouble) {
  check("the flow finished", false, String(trouble?.stack || trouble).slice(0, 400));
} finally {
  await browser.close();
  await deleteAccount(person).catch(() => false);
}
console.log(`oc_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out})`);
process.exit(failed ? 1 : 0);
