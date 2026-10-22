// Reports reaching the owner (2026-10-18), as a dry run, in a real browser:
// a report is made from a model's page, and the email that would go to the
// site's owner is rendered and recorded instead of sent, with a link to its
// row on the admin page; a second that hour waits for the next; and the
// admin page, opened at that link, shows the row.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 --static=build/web --trust-stand-in &
//   BW_STAND_IN=http://127.0.0.1:8790 node tools/web/digest_flow.mjs --url=http://127.0.0.1:8790 --out=shots/digest
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/digest_flow.mjs --url=<deployment> --out=shots/digest   # once trust.sql is applied
//
// Nothing reaches anybody's inbox. The model is a test account's (at a
// Resend test address), so every report of it is in that account's own
// stream (supabase/trust.sql report_stream), which is only ever rendered
// and recorded (api/_trust.js sendDigest). The owner's own stream is never
// asked here except through the stand-in, which claims nothing real: a
// knock at a real deployment would send them this hour's real reports.
//
// The owner's account (MASTER_EMAIL, signed in as the tests are, no email
// sent) opens the admin page; the test account is deleted at the end, its
// model taken down first and its reports and digests with it.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("digest_flow: --url=<deployment>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const out = args.out || "shots/digest";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const standIn = String(process.env.BW_STAND_IN || "").replace(/\/+$/, "");
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const secret = { apikey: SECRET, authorization: `Bearer ${SECRET}` };
const PERSON = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 flow/${randomBytes(3).toString("hex")}`;
const rand = randomBytes(4).toString("hex");
const ownerEmail = `delivered+bw-digest-${rand}@resend.dev`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" || /Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
  page.on("dialog", (d) => d.accept());
}
const shot = (page, name, full = false) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers, "user-agent": PERSON };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// The digest as recorded: from the stand-in, or from the database.
async function recorded(id) {
  if (standIn) return (await (await fetch(`${standIn}/__stand_in/digest?id=${id}`)).json().catch(() => null));
  const rows = await (await fetch(`${SUPABASE}/rest/v1/report_digests?id=eq.${id}&select=*`, { headers: secret })).json();
  return rows[0] || null;
}

const browser = await launch({ signedOut: true });
let id = null;
let owner = null;
try {
  console.log("a test account lists a model");
  owner = await mintSession(ownerEmail);
  // A file of its own: another flow taking house.ldr out bars its fingerprint.
  const house = `${readFileSync(new URL("../../models/house.ldr", import.meta.url), "utf8").trimEnd()}\r\n0 // digest flow ${rand}\r\n`;
  const picture = readFileSync(new URL("../../web/share.png", import.meta.url)).toString("base64");
  const made = await api("/api/share", { method: "POST", token: owner.access_token,
    body: { name: `Digest House ${rand}`, model: house, image: picture, listed: true } });
  id = made.json?.id || null;
  check(`listed: ${made.status} /m/${id}`, made.status === 201 && Boolean(id));

  console.log("a visitor reports it from its page");
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers, userAgent: PERSON });
  const page = await context.newPage();
  listen(page, "visitor");
  await page.goto(`${site}/m/${id}`, { waitUntil: "load", timeout: 60000 });
  await page.waitForSelector("button[data-report]:not([hidden])", { timeout: 20000 });
  // Report it is in the action bar's More (web/model-page.js).
  await page.click("#more > summary");
  await page.click("button[data-report]");
  await page.waitForSelector("dialog.report[open]", { timeout: 15000 });
  await page.check('dialog.report input[value="copied"]');
  await page.fill("dialog.report textarea", `My own house, <b>built</b> in 2019 (${rand}).`);
  const answered = page.waitForResponse((r) => r.url().includes("/api/people?op=report"), { timeout: 30000 });
  await page.click('dialog.report button[type="submit"]');
  const first = await (await answered).json().catch(() => ({}));
  await page.waitForFunction(() => /Thank you/.test(document.querySelector("dialog.report p")?.textContent || ""), null, { timeout: 20000 }).catch(() => {});
  check("the visitor is thanked", /Thank you/.test(await page.textContent("dialog.report p").catch(() => "")));
  check(`a digest made at once, as a dry run (${JSON.stringify(first.digest)})`, first.digest?.state === "dry" && first.digest?.reports === 1);
  await context.close();

  const digest = first.digest?.id ? await recorded(first.digest.id) : null;
  check(`recorded, not sent: ${digest?.state}, "${digest?.subject}"`, digest?.state === "dry" && digest?.subject === "Brickworks: a report to look at");
  const linked = /#report-(\d+)/.exec(String(digest?.body || ""));
  const reportId = linked ? Number(linked[1]) : null;
  check(`it links its row on the admin page (${site}/admin#report-${reportId})`, Boolean(reportId)
    && String(digest.body).includes(`${site}/admin#report-${reportId}`) && String(digest.html).includes(`/admin#report-${reportId}`));
  check("it says what, why and what was said, the note escaped in its HTML", /copied/i.test(digest?.body || "")
    && String(digest?.body).includes(`Digest House ${rand}`) && String(digest?.html).includes("&lt;b&gt;built&lt;/b&gt;")
    && !String(digest?.html).includes("<b>built</b>"));
  check("never who reported it, nor how to reach them", !/rights@|contact/i.test(String(digest?.body || "")));
  if (digest?.html) {
    writeFileSync(path.join(out, "digest.html"), digest.html);
    writeFileSync(path.join(out, "digest.txt"), digest.body);
    const look = await browser.newPage({ viewport: { width: 640, height: 700 } });
    await look.setContent(digest.html);
    await shot(look, "1_digest_email.png", true);
    await look.close();
  }

  console.log("a second report the same hour");
  const second = await api("/api/people?op=report", { method: "POST", body: { model: id, reason: "spam", note: `again ${rand}` } });
  check(`sent, and no second email this hour (${JSON.stringify(second.json)})`, second.status === 200 && second.json?.reported === true
    && !second.json?.digest);
  if (standIn) {
    const knock = await api("/api/people?op=digest", { method: "POST", body: {} });
    check(`the hourly knock, of the owner's own stream: nothing real here to send (${JSON.stringify(knock.json)})`,
      knock.status === 200 && knock.json?.state === "none");
  }

  console.log("the owner opens the link");
  const master = await mintSession(process.env.MASTER_EMAIL);
  const admin = await browser.newContext({ viewport: { width: 1280, height: 900 }, extraHTTPHeaders: headers });
  await admin.addInitScript(([name, value]) => { try { localStorage.setItem(name, value); } catch {} },
    [STORAGE_KEY, JSON.stringify(master.kept)]);
  const desk = await admin.newPage();
  listen(desk, "admin");
  await desk.goto(`${site}/admin#report-${reportId}`, { waitUntil: "load", timeout: 60000 });
  await desk.waitForSelector(`#report-${reportId}`, { timeout: 30000 }).catch(() => {});
  const row = await desk.evaluate((n) => {
    const tr = document.getElementById(`report-${n}`);
    if (!tr) return null;
    const box = tr.getBoundingClientRect();
    return { asked: tr.classList.contains("asked"), text: tr.innerText, inView: box.top >= 0 && box.bottom <= innerHeight };
  }, reportId);
  check(`the admin page shows that report, marked and in view (${row ? `${row.asked ? "marked" : "NOT marked"}, `
    + `${row.inView ? "in view" : "NOT in view"}: ` + row.text.replace(/\s+/g, " ").slice(0, 60) : "no row"})`,
    Boolean(row?.asked && row?.inView && /copied/.test(row.text)));
  await shot(desk, "2_admin_at_the_link.png");
  await admin.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${trouble.stack || trouble}`);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const line of errors.slice(0, 6)) console.log(`        ${line}`);
  await browser.close();
  if (owner && id) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: owner.access_token });
  if (owner?.kept?.user_id) {
    await fetch(`${SUPABASE}/rest/v1/act_log?who=eq.${owner.kept.user_id}`, { method: "DELETE", headers: secret }).catch(() => {});
    await fetch(`${SUPABASE}/rest/v1/report_digests?stream=eq.test:${owner.kept.user_id}`, { method: "DELETE", headers: secret }).catch(() => {});
  }
  check("the test account deleted, its model, reports and digests with it", await deleteAccount(ownerEmail));
}
console.log(failed ? `${failed} FAILED` : "a report reaches the owner as one email an hour, and a test's is only ever a dry run");
process.exit(failed ? 1 : 0);
