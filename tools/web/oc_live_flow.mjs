// Sign in with orangecheck, all the way, through orangecheck's real window
// with a new throwaway Bitcoin key: run on brickworks.diy after a release
// (preview_checks.sh marks it local only: each run makes a real orangecheck
// account, and orangecheck vouches for sessions only on the verified domain).
//
//   npm install --prefix /tmp/bip322 @orangecheck/bip322@1.1.2     once; not a dependency here
//   set -a; . ./.env; set +a
//   BIP322_MODULE=/tmp/bip322/node_modules/@orangecheck/bip322/dist/index.mjs \
//     node tools/web/oc_live_flow.mjs --url=https://brickworks.diy --out=shots/oc_live --keys=oc_throwaways.txt
//
// The key is random and holds nothing; the wallet's address and the
// orangecheck id it signs in as are added to --keys, every run, for
// orangecheck to purge.
//
//   1. /profile, Sign in, Sign in with orangecheck: in orangecheck's window,
//      Bitcoin wallet, the address, the message signed here (BIP-322) and
//      pasted back. The window answers the page, and the page the server.
//   2. Signed in: a new account, its session Brickworks'; the age question
//      and First steps after, as for anybody's first sign-in; /settings says
//      "Signed in with orangecheck" and shows no address.
//   3. The same token again is refused.
//   4. The app, /app, is signed in too.
//   5. Deleted from /settings with a fresh orangecheck sign-in, the same
//      wallet: signed out, and the account gone.
// On a preview (BW_BYPASS) the server refuses the token, which is for the
// deployment's own address: production takes tokens for brickworks.diy
// alone (api/_oc_config.js), the only origin orangecheck serves its list of
// ended sessions for. That the answer came back is what it proves there.
import { launch, START_MS } from "./browser.mjs";
import { appendFileSync, mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "https://brickworks.diy").replace(/\/+$/, "");
const out = args.out || "shots/oc_live";
const keys = args.keys || path.join(out, "throwaways.txt");
mkdirSync(out, { recursive: true });
if (!process.env.BIP322_MODULE) {
  console.error("oc_live_flow: BIP322_MODULE=<path to @orangecheck/bip322's dist/index.mjs>");
  process.exit(2);
}
const { addressFromPrivateKey, signMessage } = await import(process.env.BIP322_MODULE);
const bypass = process.env.BW_BYPASS || "";
const preview = Boolean(bypass) && !/^https:\/\/brickworks\.diy$/.test(site);
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};

let failed = 0;
const check = (what, ok, said = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said && !ok ? `: ${said}` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

// OC_THROWAWAY_KEY (64 hex) signs in as the same throwaway again, rather
// than make another for orangecheck to purge.
const key = /^[0-9a-f]{64}$/.test(process.env.OC_THROWAWAY_KEY || "") ? Buffer.from(process.env.OC_THROWAWAY_KEY, "hex") : randomBytes(32);
const address = addressFromPrivateKey(key, "p2wpkh");
appendFileSync(keys, `${new Date().toISOString()} ${site} address ${address}\n`);
console.log(`  --    throwaway wallet ${address} (written to ${keys})`);

/// orangecheck's window, signed in with the throwaway wallet.
async function walletSignIn(popup, name) {
  await popup.waitForLoadState("domcontentloaded", { timeout: 60000 });
  await popup.getByText("Bitcoin wallet", { exact: true }).click({ timeout: 60000 });
  await popup.getByPlaceholder("bc1q").fill(address);
  await popup.getByRole("button", { name: "Get the message to sign" }).click();
  const message = popup.locator("textarea[readonly]").first();
  await message.waitFor({ timeout: 30000 });
  const text = await message.inputValue();
  check(`${name}: orangecheck asks the wallet to sign its message for this address`,
    text.startsWith("orangecheck-auth\n") && text.includes(`address: ${address}\n`) && text.endsWith("\n"), text.slice(0, 80));
  await popup.getByPlaceholder("paste the signature").fill(signMessage(address, text, key));
  await shot(popup, `${name}_window.png`);
  await popup.getByRole("button", { name: "Sign me in" }).click();
}

const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
if (bypass) await context.route(`${site}/**`, (route) => route.continue({ headers: { ...route.request().headers(), ...headers } }));
// The token, seen on its way to the server, only so a second try with it can
// be made: the page itself never keeps it.
let token = "";
let answer = null;
await context.route(`${site}/api/orangecheck?op=signin`, async (route) => {
  try {
    token ||= JSON.parse(route.request().postData() || "{}").token || "";
  } catch { /* not ours to read */ }
  await route.continue({ headers: { ...route.request().headers(), ...headers } });
});
const page = await context.newPage();
/// The server's answer to the next sign-in the page sends it.
const nextAnswer = () => page.waitForResponse((response) => response.url().endsWith("/api/orangecheck?op=signin"), { timeout: 180000 })
  .then(async (response) => ({ status: response.status(), body: await response.json().catch(() => null) }))
  .catch(() => null);

try {
  // 1. Through orangecheck's window, offered to everybody.
  await page.goto(`${site}/profile`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.locator("#sign-in").click({ timeout: 60000 });
  await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 30000 });
  const answered = nextAnswer();
  const [popup] = await Promise.all([page.waitForEvent("popup", { timeout: 30000 }), page.locator("#oc-sign-in").click()]);
  await walletSignIn(popup, "sign_in");
  answer = await answered;
  await page.waitForFunction(() => !document.querySelector("dialog.sign-in")?.open
    || !/in its own window/.test(document.querySelector("dialog.sign-in .said")?.textContent || ""), null, { timeout: 120000 });
  check("the window answered the page, and the page the server", Boolean(token) && Boolean(answer), JSON.stringify(answer));
  // What the token says (never the token): why, when it is refused.
  const claims = token ? JSON.parse(Buffer.from(token.split(".")[1] || "", "base64url").toString() || "{}") : {};
  const header = token ? JSON.parse(Buffer.from(token.split(".")[0] || "", "base64url").toString() || "{}") : {};
  console.log(`  --    the token: ${JSON.stringify(header)} aud ${claims.aud} iss ${claims.iss} did ${claims.did_oc} `
    + `rh ${claims.rh ? "yes" : "no"} jti ${claims.jti ? "yes" : "no"} iat ${claims.iat} exp ${claims.exp} `
    + `claims ${Object.keys(claims).join(",")}`);
  // OC_KEEP_TOKEN=<file>: the token written there too, for looking into a
  // refusal by hand. A credential: only ever into a scratch folder.
  if (process.env.OC_KEEP_TOKEN && token) appendFileSync(process.env.OC_KEEP_TOKEN, `${token}\n`, { mode: 0o600 });
  const did = answer?.body?.orangecheck?.did || claims.did_oc || "";
  if (did) appendFileSync(keys, `${new Date().toISOString()} ${site} did ${did} (wallet ${address})\n`);

  if (preview) {
    const said = await page.locator("dialog.sign-in .said").textContent().catch(() => "");
    check("on a preview, the server refuses a token for the deployment's own address, in words",
      answer?.status === 401 && /not for Brickworks/.test(said), `${answer?.status} ${said}`);
    await shot(page, "preview_refused.png");
  } else {
    // 2. Signed in, as a new account, asked what anybody is asked first.
    check("signed in with orangecheck: a new account", answer?.status === 200 && answer.body?.orangecheck?.new_account === true,
      `${answer?.status} ${answer?.body?.error || ""}`);
    const age = page.locator("dialog.age");
    await age.waitFor({ state: "visible", timeout: 60000 });
    check("then the age question, as after any first sign-in", await age.isVisible());
    await page.selectOption("#age-month", "1");
    await page.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
    await page.locator("#age-go").click();
    await page.locator("dialog.first-steps").waitFor({ state: "visible", timeout: 60000 }).catch(() => null);
    await shot(page, "first_steps.png");
    await page.keyboard.press("Escape");
    await page.goto(`${site}/settings`, { waitUntil: "domcontentloaded" });
    await page.locator("#who").waitFor({ state: "visible", timeout: 60000 });
    const who = await page.locator("#who").textContent();
    check("/settings says signed in with orangecheck, and shows no address", /^Signed in with orangecheck/.test(who)
      && !/@/.test(who), who);
    await shot(page, "settings.png");

    // 3. The same token again.
    const again = await fetch(`${site}/api/orangecheck?op=signin`, { method: "POST",
      headers: { ...headers, "content-type": "application/json" }, body: JSON.stringify({ token }) });
    check("the same token again is refused", again.status === 409 || again.status === 401, String(again.status));

    // 4. The app.
    const app = await context.newPage();
    await app.goto(`${site}/app`, { waitUntil: "domcontentloaded", timeout: 120000 });
    let state = null;
    for (const until = Date.now() + START_MS; Date.now() < until;) {
      state = await app.evaluate(() => window.brickworksAccount || null).catch(() => null);
      if (state && state.state !== "checking") break;
      await app.waitForTimeout(1000);
    }
    check("the app is signed in too", state?.state === "signed_in" && state.gated === false, JSON.stringify(state));
    await shot(app, "app.png");
    await app.close();

    // 5. Deleted with a fresh orangecheck sign-in.
    await page.goto(`${site}/settings`, { waitUntil: "domcontentloaded" });
    await page.locator("#delete-part summary").click();
    page.once("dialog", (dialog) => dialog.accept());
    const [again2] = await Promise.all([page.waitForEvent("popup", { timeout: 30000 }), page.locator("#delete-go").click()]);
    await walletSignIn(again2, "delete");
    await page.waitForFunction(() => document.documentElement.dataset.deleted === "yes"
      || /./.test(document.querySelector("#delete-said")?.textContent || ""), null, { timeout: 120000 });
    const deleted = await page.evaluate(() => document.documentElement.dataset.deleted === "yes");
    check("deleted from /settings by signing in with orangecheck again", deleted,
      await page.locator("#delete-said").textContent().catch(() => ""));
    await shot(page, "deleted.png");
  }
} catch (trouble) {
  check("the flow finished", false, String(trouble?.stack || trouble).slice(0, 400));
  await shot(page, "trouble.png");
} finally {
  await browser.close();
}
console.log(`oc_live_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out}; throwaways in ${keys})`);
process.exit(failed ? 1 : 0);
