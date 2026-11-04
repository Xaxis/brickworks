// The review sign-in (web/review.html), in a real browser: what an app
// directory's reviewer does first (docs/directory/claude.md).
//
//   set -a; . ./.env; set +a; node tools/web/relay_server.mjs 9672 &
//   node tools/web/review_flow.mjs --url=http://127.0.0.1:9672 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/review_flow.mjs --url=<preview> --out=DIR
//
// A throwaway review account (a Resend test address with a password, as
// tools/web/relay_account.mjs review makes the real one), then /review at
// 1280 and 390 px:
//   1. An address that is no review account's is refused in words, and
//      nothing is kept: the page signs in nobody else.
//   2. The review address with a wrong password is refused in words.
//   3. With its password: "Signed in as" the address and the next steps,
//      the session kept where the app and the connector's sign-in read it
//      (brickworks.session), and the site's API takes it as signed in
//      (api/_auth.js lets a test account's password session through).
//   4. Opened again, the page says so at once; Sign out ends it.
// The throwaway account is deleted at the end, and checked gone. Exits 1
// on any FAIL. Pictures of each state in --out.
import { randomBytes } from "node:crypto";
import { mkdirSync } from "node:fs";
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:9672").replace(/\/+$/, "").replace(/\/app$/, "");
const out = String(args.out || "shots/review_flow");
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const secret = process.env.SUPABASE_SECRET_KEY || "";
if (!base || !secret) {
  console.error("no SUPABASE_URL / SUPABASE_SECRET_KEY: source .env");
  process.exit(2);
}

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

const address = `delivered+bwreview${randomBytes(4).toString("hex")}@resend.dev`;
const password = `${randomBytes(18).toString("base64url")}-Aa1`;
const admin = { apikey: secret, authorization: `Bearer ${secret}`, "content-type": "application/json" };
const made = await fetch(`${base}/auth/v1/admin/users`, {
  method: "POST", headers: admin, body: JSON.stringify({ email: address, password, email_confirm: true }),
});
const user = (await made.json().catch(() => ({}))).id;
if (!made.ok || !user) {
  console.error(`the throwaway review account was not made: ${made.status}`);
  process.exit(1);
}
await answerAge(user, address);

const browser = await launch({ signedOut: true });
const said = (page) => page.$eval("#say", (n) => n.textContent.trim());
const kept = (page) => page.evaluate(() => JSON.parse(localStorage.getItem("brickworks.session") || "null"));
const shown = (page, id) => page.$eval(`#${id}`, (n) => !n.classList.contains("hide"));
const signIn = async (page, who, secretWord) => {
  await page.fill("#email", who);
  await page.fill("#password", secretWord);
  await page.click("#go");
  await page.waitForFunction(() => !document.getElementById("go").disabled
    && document.getElementById("say").textContent !== "Signing in…", null, { timeout: 30000 });
};
try {
  for (const width of [1280, 390]) {
    console.log(`\n/review at ${width} px`);
    const context = await browser.newContext({ viewport: { width, height: 900 }, extraHTTPHeaders: headers });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (error) => errors.push(String(error)));
    const opened = await page.goto(`${site}/review`, { waitUntil: "load" });
    check(opened?.status() === 200 && await shown(page, "sign-in-step") && !(await shown(page, "done-step")),
      `the page answers ${opened?.status()} with the sign-in, and no next steps yet`);
    check(await page.$eval("meta[name=robots]", (n) => n.content) === "noindex, nofollow",
      "...and asks not to be listed");
    await page.screenshot({ path: `${out}/${width}_1_sign_in.png` });

    await signIn(page, "someone@example.com", "anything");
    check(/review accounts only/.test(await said(page)) && (await kept(page)) === null,
      `1. another address is refused in words, nothing kept: "${await said(page)}"`);

    await signIn(page, address, `${password}x`);
    check(/not a review account/.test(await said(page)) && (await kept(page)) === null,
      `2. a wrong password is refused in words: "${await said(page)}"`);
    await page.screenshot({ path: `${out}/${width}_2_refused.png` });

    await signIn(page, address, password);
    const session = await kept(page);
    check(await shown(page, "done-step") && (await page.textContent("#signed-in-as")) === address,
      "3. with its password: signed in as the address, and the next steps");
    check(session?.email === address && Boolean(session?.refresh_token) && session?.user_id === user,
      "...kept where the app and the connector's sign-in read it (brickworks.session)");
    const steps = await page.textContent("#done-step");
    check(steps.includes("Open the app") && steps.includes("https://brickworks.diy/api/mcp")
      && await page.$eval("#open-app", (n) => n.getAttribute("href")) === "/app?assistant=on",
      "...the steps: open the app with its assistant on, connect at the connector's address");
    const me = await page.evaluate(async () => {
      const access = JSON.parse(sessionStorage.getItem("brickworks.access") || "null");
      const reply = await fetch("/api/account", { headers: { authorization: `Bearer ${access?.token}` } });
      return { status: reply.status, body: await reply.json().catch(() => ({})) };
    });
    check(me.status === 200 && JSON.stringify(me.body).includes(address),
      `...and the site's API takes the session as the account's (${me.status})`);
    await page.screenshot({ path: `${out}/${width}_3_signed_in.png` });

    await page.reload({ waitUntil: "load" });
    await page.waitForFunction(() => !document.getElementById("done-step").classList.contains("hide"),
      null, { timeout: 10000 }).catch(() => {});
    check(await shown(page, "done-step"), "4. opened again, it says who is signed in at once");
    await page.click("#sign-out");
    check(await shown(page, "sign-in-step") && (await kept(page)) === null, "...and Sign out ends it");
    check(errors.length === 0, `no script errors${errors.length ? `: ${errors.join("; ")}` : ""}`);
    await context.close();
  }
} finally {
  await browser.close();
  const gone = await deleteAccount(address);
  check(gone, "the throwaway review account is deleted");
}
console.log(failures ? `\nreview_flow: ${failures} FAILED` : "\nreview_flow: all ok");
process.exit(failures ? 1 : 0);
