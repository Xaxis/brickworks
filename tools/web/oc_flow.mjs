// Sign in with orangecheck (2026-10-23), in a real browser, without making
// anybody an orangecheck account: what a deployment shows and refuses before
// orangecheck's own window takes over.
//
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/oc_flow.mjs --url=<deployment> --out=shots/oc
//
//   1. The sign-in dialog (from /profile signed out) has Sign in with
//      orangecheck under the email, with its words, at 390 and 1280 px in
//      light and dark, nothing sideways.
//   2. Its button opens orangecheck's window (me.ochk.io) from the click;
//      closed, the dialog stays as it was and says nothing. A browser that
//      blocks the window is told so, in words, and how to allow it.
//      Sent from the app (/profile?then=/app), the dialog opens by itself to
//      go back there; with an address elsewhere, nothing opens.
//   3. The page loads its orangecheck code from its own origin, with no
//      refusal from the page's security policy.
//   4. The site's pages send Cross-Origin-Opener-Policy
//      same-origin-allow-popups, so the window can answer; /app keeps
//      same-origin for its threads.
//   5. The server: nothing, junk, or a GET refused in words; never cached;
//      no other site may read its answer. Where the deployment has no
//      signing secret, sign-in with orangecheck said to be unavailable. An orangecheck account's made-up
//      address is refused a sign-in code.
//   6. /settings for an email account (a throwaway at a Resend test
//      address, deleted after) offers Link orangecheck with its words, at
//      390 and 1280 in light and dark; with the code just redeemed, the
//      button opens orangecheck's window from the click. Linking without a
//      sign-in is refused.
// A finished orangecheck sign-in needs a wallet and orangecheck's list of
// ended sessions for the domain, which a preview's address is not:
// tools/web/oc_live_flow.mjs does that on brickworks.diy.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
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

async function context(width, theme, { blockWindows = false } = {}) {
  const made = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: theme });
  await made.route(`${site}/**`, (route) => route.continue({ headers: { ...route.request().headers(), ...headers } }));
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

try {
  // 1. The dialog, at both widths, in both themes.
  for (const width of [390, 1280]) {
    for (const theme of ["light", "dark"]) {
      const made = await context(width, theme);
      const page = await made.newPage();
      listen(page, `${width} ${theme}`);
      await openDialog(page);
      const button = page.locator("dialog.sign-in #oc-sign-in");
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

  // 2. The window: opened from the click, at orangecheck; closed, nothing said.
  {
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
    check("closed, the dialog stays, says nothing, and can try again", after.open === true && after.said === "" && after.enabled,
      JSON.stringify(after));
    await made.close();
  }
  {
    const made = await context(390, "dark", { blockWindows: true });
    const page = await made.newPage();
    listen(page, "blocked");
    await openDialog(page);
    await page.locator("#oc-sign-in").click();
    await page.waitForFunction(() => /blocked/.test(document.querySelector("dialog.sign-in .said")?.textContent || ""), null,
      { timeout: 15000 }).catch(() => null);
    const said = await page.locator("dialog.sign-in .said").textContent();
    check("a blocked window is said in words, with how to allow it",
      said === `Your browser blocked the sign-in window. Allow pop-ups for ${host} and try again.`, said);
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
  const code = await fetch(`${site}/oc-popup.mjs`, { headers });
  check("orangecheck's window code is served from this site as a script",
    code.ok && /javascript/.test(code.headers.get("content-type") || "") && /signInWithOcOutcome/.test(await code.text()),
    `${code.status} ${code.headers.get("content-type")}`);
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
  // Vercel's own body parser answers this one, before the route.
  check("a body that is not JSON: refused", broken.status === 400 || broken.status === 422, `${broken.status}`);
  const get = await api("/api/orangecheck?op=signin");
  check("anything but POST ?op=signin: refused", get.status === 405, `${get.status}`);
  const madeUp = await api("/api/otp", { method: "POST", body: { email: "0123456789abcdef0123456789abcdef@oc.brickworks.diy" } });
  check("an orangecheck account's made-up address gets no code", madeUp.status === 422 && /orangecheck/.test(madeUp.json?.error || ""),
    `${madeUp.status} ${madeUp.json?.error || ""}`);

  // 6. /settings, for an account with its own email.
  const unsigned = await api("/api/orangecheck?op=link", { method: "POST", body: { token: "not.a.token" } });
  check("linking without a sign-in: refused", unsigned.status === 401, `${unsigned.status}`);
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
      check(`settings ${width} ${theme}: nothing sideways, drawn ${theme}`, !(await sideways(page))
        && await page.evaluate((wanted) => document.documentElement.getAttribute("data-theme") === wanted, theme));
      await page.locator("#oc-part").scrollIntoViewIfNeeded();
      await shot(page, `settings_${width}_${theme}.png`);
      if (width === 1280 && theme === "light") {
        const [popup] = await Promise.all([
          page.waitForEvent("popup", { timeout: 30000 }),
          page.locator("#oc-go").click(),
        ]);
        check("with a code just redeemed, Link orangecheck opens orangecheck's window", new URL(popup.url()).origin === "https://me.ochk.io",
          popup.url());
        await popup.close();
        await page.waitForFunction(() => !document.querySelector("#oc-go")?.disabled, null, { timeout: 15000 }).catch(() => null);
        check("closed, nothing is linked and nothing said", (await page.locator("#oc-status").textContent()) === ""
          && (await page.locator("#oc-go").textContent()) === "Link orangecheck");
      }
      await made.close();
    }
  }
  check("no refusal from the page's security policy, no error, on /settings either", errors.length === 0, errors.slice(0, 3).join(" | "));
} catch (trouble) {
  check("the flow finished", false, String(trouble?.stack || trouble).slice(0, 400));
} finally {
  await browser.close();
  await deleteAccount(person).catch(() => false);
}
console.log(`oc_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out})`);
process.exit(failed ? 1 : 0);
