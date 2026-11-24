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
//      wallet, by orangecheck's own button there: signed out, and the
//      account gone.
//   Step 4 (2026-10-24, oc225; no box since signin3, 2026-11-24),
//   orangecheck Connect around every sign-in, with a throwaway at a Resend
//   test address signed in through the dialog by an emailed code (minted
//   here, as the tests do). --connect runs these alone, with no wallet.
//   6. No box; the dialog says signing in also makes the orangecheck
//      account. Signed in and 13 or over, the server makes one (a did, kept
//      with the account, and added to --keys for orangecheck to purge); the
//      page asks orangecheck nothing itself.
//   7. Signed in again: the same orangecheck account, none made anew.
//   8. Deleting the account deletes it at orangecheck first
//      (connectDelete), then the account.
//   orangecheck down at a sign-in, and an account from before getting one
//   at its next sign-in, are tools/web/ways_check.mjs's, against a stand-in.
// On a preview (BW_BYPASS) the server refuses the token, which is for the
// deployment's own address: production takes tokens for brickworks.diy
// alone (api/_oc_config.js), the only origin orangecheck serves its list of
// ended sessions for. That the answer came back is what it proves there.
import { launch, START_MS } from "./browser.mjs";
import { deleteAccount, mintCode, STORAGE_KEY } from "./session.mjs";
import { appendFileSync, mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { answerAsks } from "./asks.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "https://brickworks.diy").replace(/\/+$/, "");
const out = args.out || "shots/oc_live";
const keys = args.keys || path.join(out, "throwaways.txt");
mkdirSync(out, { recursive: true });
const connectOnly = Boolean(args.connect);
if (!process.env.BIP322_MODULE && !connectOnly) {
  console.error("oc_live_flow: BIP322_MODULE=<path to @orangecheck/bip322's dist/index.mjs>, or --connect alone");
  process.exit(2);
}
const { addressFromPrivateKey, signMessage } = connectOnly ? {} : await import(process.env.BIP322_MODULE);
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
const address = connectOnly ? "" : addressFromPrivateKey(key, "p2wpkh");
if (!connectOnly) {
  appendFileSync(keys, `${new Date().toISOString()} ${site} address ${address}\n`);
  console.log(`  --    throwaway wallet ${address} (written to ${keys})`);
}

/// orangecheck's window, signed in with the throwaway wallet, by the
/// controls /me/sdk "a Bitcoin wallet in the popup" names (2026-10-24), or
/// the placeholders oc188 found before it named them.
async function walletSignIn(popup, name) {
  await popup.waitForLoadState("load", { timeout: 60000 });
  // A click before the window's script has taken over leaves it on Email
  // (seen 2026-10-24): clicked again until the address field shows.
  const field = popup.getByLabel("Bitcoin address").or(popup.getByPlaceholder("bc1q")).first();
  for (let tries = 0; tries < 10 && !(await field.isVisible()); tries++) {
    await popup.getByText("Bitcoin wallet", { exact: true }).click({ timeout: 60000 });
    await popup.waitForTimeout(1000);
  }
  await field.fill(address);
  await popup.getByRole("button", { name: "Get the message to sign" }).click();
  const message = popup.getByLabel("Message to sign").or(popup.locator("textarea[readonly]")).first();
  await message.waitFor({ timeout: 30000 });
  const text = await message.inputValue();
  check(`${name}: orangecheck asks the wallet to sign its message for this address`,
    text.startsWith("orangecheck-auth\n") && text.includes(`address: ${address}\n`) && text.endsWith("\n"), text.slice(0, 80));
  await popup.getByLabel("Signature", { exact: true }).or(popup.getByPlaceholder("paste the signature")).first()
    .fill(signMessage(address, text, key));
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

/// What the database keeps of Connect for [account]: {did, ...} or null.
async function connectedOf(account) {
  const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const reply = await fetch(`${SB}/rest/v1/rpc/oc_connected_of`, { method: "POST",
    headers: { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" }, body: JSON.stringify({ account }) });
  return reply.ok ? reply.json() : { error: reply.status };
}

/// A throwaway [email] signed in through the sign-in dialog by an emailed
/// code, its age answered (30) if asked: {email, account, refresh, asks,
/// line, boxes, signedIn}, asks what the page itself asked of ?op=connect.
async function connectSignIn(name, email) {
  const made = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  if (bypass) await made.route(`${site}/**`, (route) => route.continue({ headers: { ...route.request().headers(), ...headers } }));
  const asks = [];
  await made.route(`${site}/api/orangecheck?op=connect`, (route) => {
    asks.push(route.request().method());
    return route.continue();
  });
  const tab = await made.newPage();
  // Signed out, /profile?sign-in opens the sign-in by itself (signinux, sifix).
  await tab.goto(`${site}/profile?sign-in`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await tab.locator("dialog.sign-in #oc-made-line").waitFor({ state: "visible", timeout: 60000 });
  const line = (await tab.locator("dialog.sign-in #oc-made-line").textContent()).trim();
  const boxes = await tab.locator('dialog.sign-in input[type="checkbox"]').count();
  await tab.fill("dialog.sign-in form input", email);
  await tab.click('dialog.sign-in button[type="submit"]');
  await tab.waitForFunction(() => /The code sent to/.test(document.querySelector("dialog.sign-in label")?.textContent || ""), null, { timeout: 60000 });
  // One digit a box: the whole code in the first goes by itself.
  await tab.fill("dialog.sign-in .code-boxes input:first-child", await mintCode(email));
  const kept = await tab.waitForFunction((name) => {
    try {
      return JSON.parse(localStorage.getItem(name) || "null");
    } catch {
      return null;
    }
  }, STORAGE_KEY, { timeout: 60000 }).then((handle) => handle.jsonValue(), () => null);
  const age = tab.locator("dialog.age");
  if (await age.waitFor({ state: "visible", timeout: 15000 }).then(() => true, () => false)) {
    await tab.selectOption("#age-month", "1");
    await tab.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
    await tab.locator("#age-go").click();
  }
  await shot(tab, `connect_${name}.png`);
  await made.close();
  return { email, account: kept?.user_id || "", refresh: kept?.refresh_token || "", asks, line, boxes, signedIn: Boolean(kept?.refresh_token) };
}

/// What Connect keeps for [account] once the server has had [ms] to make it.
async function connectedWithin(account, ms = 30000) {
  let row = null;
  for (const until = Date.now() + ms; Date.now() < until;) {
    row = await connectedOf(account);
    if (row?.did) break;
    await new Promise((done) => setTimeout(done, 1000));
  }
  return row;
}

try {
  if (connectOnly) throw Object.assign(new Error("connect only"), { connectOnly: true });
  // 1. Through orangecheck's window, offered to everybody.
  // Signed out, /profile?sign-in opens the sign-in by itself (signinux, sifix).
  await page.goto(`${site}/profile?sign-in`, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.locator("dialog.sign-in").waitFor({ state: "visible", timeout: 60000 });
  const answered = nextAnswer();
  // orangecheck's button script dresses the button after the dialog opens:
  // on brickworks.diy its mark was drawn 184 ms in (2026-10-24), and asked
  // at once the check read "not drawn".
  const theirs = await page.waitForSelector("#oc-sign-in[data-oc-sign-in] svg[data-oc-mark=mono]", { timeout: 15000 })
    .then(() => true).catch(() => false);
  check("the button is orangecheck's own, its mark drawn", theirs);
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
    await answerAsks(page, { times: 1 });
    const [again2] = await Promise.all([page.waitForEvent("popup", { timeout: 30000 }), page.locator("#delete-oc").click()]);
    await walletSignIn(again2, "delete");
    // "Signing in with orangecheck, in its own window." is said the moment
    // the window opens. Waiting for any words read that as the answer, and
    // the browser closed before orangecheck's answer could delete anything
    // (2026-10-24): wait for the deletion, or for words that are not that.
    await page.waitForFunction(() => {
      const said = document.querySelector("#delete-said")?.textContent || "";
      return document.documentElement.dataset.deleted === "yes"
        || (said !== "" && !/in its own window/.test(said));
    }, null, { timeout: 120000 }).catch(() => null);
    const deleted = await page.evaluate(() => document.documentElement.dataset.deleted === "yes");
    check("deleted from /settings by signing in with orangecheck again", deleted,
      await page.locator("#delete-said").textContent().catch(() => ""));
    await shot(page, "deleted.png");
  }
} catch (trouble) {
  if (!trouble?.connectOnly) {
    check("the flow finished", false, String(trouble?.stack || trouble).slice(0, 400));
    await shot(page, "trouble.png");
  }
}

// 6-8. orangecheck Connect around a sign-in, on brickworks.diy only: a
// preview has no Connect key (tools/deploy.sh --unit) and says nothing of it.
if (!preview) {
  const leftovers = [];
  try {
    const email = `delivered+bw-oc-live-connect-${randomBytes(4).toString("hex")}@resend.dev`;
    leftovers.push(email);
    const first = await connectSignIn("first", email);
    const row = await connectedWithin(first.account);
    if (row?.did) appendFileSync(keys, `${new Date().toISOString()} ${site} connect did ${row.did} (${email})\n`);
    check("6. no box, the line said, signed in, and the server made an orangecheck account, kept with ours; the page asked nothing",
      first.signedIn && first.boxes === 0 && /^Signing in without orangecheck also makes your orangecheck account\./.test(first.line) && first.asks.length === 0
      && Boolean(row?.did), `${JSON.stringify({ ...first, refresh: undefined })} ${JSON.stringify(row)}`);
    const again = await connectSignIn("again", email);
    await new Promise((done) => setTimeout(done, 5000));
    const still = await connectedOf(again.account);
    check("7. signed in again: the same orangecheck account, none made anew", again.signedIn && again.account === first.account
      && still?.did === row?.did && still?.made_at === row?.made_at, `${JSON.stringify(row)} ${JSON.stringify(still)}`);
    // Deleted as /settings deletes: its address typed again.
    const access = await fetch(`${String(process.env.SUPABASE_URL || "").replace(/\/+$/, "")}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST", headers: { apikey: process.env.SUPABASE_PUBLISHABLE_KEY, "content-type": "application/json" },
      body: JSON.stringify({ refresh_token: again.refresh }) }).then((r) => r.json()).then((b) => b.access_token).catch(() => "");
    const quit = await fetch(`${site}/api/account?op=delete`, { method: "POST",
      headers: { ...headers, authorization: `Bearer ${access}`, "content-type": "application/json" }, body: JSON.stringify({ confirm: email }) });
    check("8. deleting it deletes orangecheck's first, then ours", quit.status === 200 && (await connectedOf(first.account)) === null,
      `${quit.status} ${JSON.stringify(await quit.json().catch(() => null))}`);
  } catch (trouble) {
    check("Connect's steps finished", false, String(trouble?.stack || trouble).slice(0, 400));
  } finally {
    for (const email of leftovers) await deleteAccount(email).catch(() => false);
  }
}
await browser.close();
console.log(`oc_live_flow: ${failed ? `${failed} failed` : "all passed"} (pictures in ${out}; throwaways in ${keys})`);
process.exit(failed ? 1 : 0);
