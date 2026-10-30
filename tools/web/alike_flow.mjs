// More like a designer on a person's page (docs/SOCIAL.md section 7, item
// 9; api/_alike.js, web/follow.js showAlike), in real browsers against the
// real API and the live project's tables:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/alike_flow.mjs --url=<preview> --out=DIR
//   node --env-file=.env tools/web/alike_flow.mjs --url=http://127.0.0.1:PORT --out=DIR   # a local relay
//
// Throwaway accounts at Resend test addresses, deleted at the end with what
// they made. Each lists one model of "Something else" (no theme), built of
// the same few parts nothing else in the gallery is made of, tagged with
// two words made up for this run, t1 and t2:
//
//   Ann   t1 t2     whose page it is
//   Bo    t1 t2     as close as can be
//   Di    t1 t2     as close; she follows Bo
//   Cy    t1        less close
//   Fay   t1 t2     answers under 13: never suggested
//
//   1. Ann's page before anybody else lists: More like is hidden.
//   2. At 1280 px, light, signed out: More like Ann lists Bo and Di, then
//      Cy (closest first), never Ann or Fay; each a link to their profile,
//      what they share in words, and Follow.
//   3. At 390 px, dark, signed in as Di: only Cy (not Di herself, not Bo,
//      whom she follows, not Fay); Follow on Cy follows him in place. Asked
//      again, nobody is left: More like is hidden. Her answer is never kept
//      by the CDN.
// With supabase/designers_alike.sql applied the shared parts count as well
// (the flow says which it saw); the order above holds either way. Pictures
// in --out. Without the section (an older checkout) Ann's page has no More
// like and the API no op=alike: the flow fails.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
if (!args.url) {
  console.error("alike_flow: --url=<a preview or a local relay> (it seeds the real project's tables)");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/alike"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const rand = randomBytes(3).toString("hex");
const who = ["ann", "bo", "cy", "di", "fay"];
const emails = Object.fromEntries(who.map((one) => [one, `delivered+bw-alike-${one}-${rand}@resend.dev`]));
const handles = Object.fromEntries(who.map((one) => [one, `bwal-${one}-${rand}`]));
const names = { ann: "Ann Alike", bo: "Bo Alike", cy: "Cy Alike", di: "Di Alike", fay: "Fay Alike" };
const t1 = `alike${rand}a`;
const t2 = `alike${rand}b`;
const tags = { ann: [t1, t2], bo: [t1, t2], di: [t1, t2], cy: [t1], fay: [t1, t2] };

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
// Parts no model of the gallery's flows is made of: a cone, a round tile and
// a hinge plate, so the parts in common are these five designers' alone.
const model = (name) => `0 ${name}\r\n0 Name: alike.ldr\r\n1 14 0 0 0 1 0 0 0 1 0 0 0 1 4589.dat\r\n0 STEP\r\n`
  + `1 2 0 -24 0 1 0 0 0 1 0 0 0 1 98138.dat\r\n1 0 40 0 0 1 0 0 0 1 0 0 0 1 2429c01.dat\r\n0 STEP\r\n0 // alike flow ${rand}\r\n`;

async function api(pathname, { method = "GET", token = "", body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})), cache: reply.headers.get("cache-control") || "" };
}

const browser = await launch({ signedOut: true });

async function context({ as = null, width = 1280, dark = false } = {}) {
  const phone = width < 600;
  const made = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}

function listen(page, label) {
  page.on("pageerror", (e) => errors.push(`${label}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${label}: ${m.text().slice(0, 220)}`);
  });
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// Ann's page as [page] shows it: More like's state, and each of its rows.
async function alikeOn(page) {
  await page.goto(`${site}/u/${handles.ann}?tests=1`, { waitUntil: "domcontentloaded", timeout: 90000 });
  await until(page, () => document.documentElement.dataset.alike, "More like", 60);
  // Each row's Follow drawn as the API says it stands.
  await page.waitForTimeout(500);
  return page.evaluate(() => {
    const box = document.getElementById("alike");
    return { state: document.documentElement.dataset.alike, shown: Boolean(box && !box.hidden && box.offsetHeight > 0),
      heading: box?.querySelector("h2")?.textContent.trim() || "",
      rows: [...(box?.querySelectorAll(".person-row") || [])].map((row) => ({ handle: row.dataset.handle,
        link: row.querySelector(".names a")?.getAttribute("href") || "", name: row.querySelector(".names b")?.textContent || "",
        said: row.querySelector(".names small")?.textContent || "", follow: row.querySelector("button[data-follow]")?.textContent.trim() || "",
        visible: Boolean(row.querySelector("button[data-follow]") && !row.querySelector("button[data-follow]").hidden) })) };
  });
}

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
const order = (rows) => rows.map((one) => one.handle);

const sessions = {};
try {
  console.log(`seeding: ${who.map((one) => handles[one]).join(", ")}; tags ${t1}, ${t2}`);
  async function designer(one) {
    sessions[one] = await mintSession(emails[one]);
    const made = await api("/api/people?op=profile", { method: "POST", token: sessions[one].access_token,
      body: { handle: handles[one], name: names[one] } });
    if (made.status !== 200) throw new Error(`${one}'s profile: ${made.status} ${JSON.stringify(made.body)}`);
    const shared = await api("/api/share", { method: "POST", token: sessions[one].access_token,
      body: { name: `${names[one]}'s ${rand}`, author: names[one], model: model(names[one]), image: picture, listed: true,
        kind: "other", tags: tags[one] } });
    if (shared.status !== 201) throw new Error(`${one}'s model: ${shared.status} ${JSON.stringify(shared.body)}`);
  }
  await designer("ann");

  // --- 1. nobody close yet ----------------------------------------------------
  console.log("Ann alone");
  {
    const made = await context();
    const page = await made.newPage();
    listen(page, "alone");
    const seen = await alikeOn(page);
    check(`with nobody close, More like is hidden (${seen.state}, ${seen.rows.length} rows)`,
      seen.state === "none" && !seen.shown && seen.rows.length === 0);
    await made.close();
  }

  for (const one of ["bo", "cy", "di", "fay"]) await designer(one);
  const young = await fetch(`${SUPABASE}/rest/v1/profiles?id=eq.${sessions.fay.kept.user_id}`, { method: "PATCH",
    headers: { apikey: SECRET, authorization: `Bearer ${SECRET}`, "content-type": "application/json", prefer: "return=minimal" },
    body: JSON.stringify({ over_13: false, age_asked_at: new Date().toISOString() }) });
  check(`Fay answers under 13 (${young.status})`, young.ok);
  const follow = await api("/api/people?op=follow", { method: "POST", token: sessions.di.access_token, body: { handle: handles.bo, on: true } });
  check(`Di follows Bo (${follow.status})`, follow.status === 200 && follow.body.you_follow === true);

  // --- 2. signed out, 1280, light ---------------------------------------------
  console.log("at 1280 px, light, signed out");
  const asked = await api(`/api/people?op=alike&handle=${handles.ann}&tests=1`);
  const ours = (asked.body.designers || []).filter((one) => Object.values(handles).includes(one.handle));
  console.log(`  --    the API's: ${(asked.body.designers || []).map((one) => `${one.handle} "${one.said}"`).join(", ")}`);
  check(`the API: Bo and Di, then Cy (${order(ours).join(", ")})`, asked.status === 200 && ours.length === 3
    && ours[2].handle === handles.cy && new Set(order(ours).slice(0, 2)).size === 2
    && order(ours).slice(0, 2).every((one) => [handles.bo, handles.di].includes(one)));
  const parts = ours.some((one) => /many of the same parts/i.test(one.said));
  console.log(`  --    the parts in common ${parts ? "counted (designers_alike.sql applied)" : "not counted (designers_alike.sql not applied)"}`);
  check(`never Ann, never Fay (${order(asked.body.designers || []).join(", ")})`,
    !(asked.body.designers || []).some((one) => [handles.ann, handles.fay].includes(one.handle)));
  check(`six at most (${(asked.body.designers || []).length})`, (asked.body.designers || []).length <= 6);
  {
    const made = await context();
    const page = await made.newPage();
    listen(page, "1280");
    const seen = await alikeOn(page);
    const mine = seen.rows.filter((one) => Object.values(handles).includes(one.handle));
    check(`"${seen.heading}" shown, Bo and Di then Cy (${order(mine).join(", ")})`, seen.state === "shown" && seen.shown
      && seen.heading === `More like ${names.ann}` && JSON.stringify(order(mine)) === JSON.stringify(order(ours)));
    check(`each a link to their profile, with what they share (${mine.map((one) => `${one.link} "${one.said}"`).join(", ")})`,
      mine.length === 3 && mine.every((one) => one.link === `/u/${one.handle}` && one.said.toLowerCase().includes(t1)));
    check(`and Follow beside each (${mine.map((one) => one.follow).join(", ")})`, mine.every((one) => one.follow === "Follow" && one.visible));
    await page.evaluate(() => document.getElementById("alike")?.scrollIntoView({ block: "center" }));
    await page.waitForTimeout(400);
    await shot(page, "1_alike_1280_light_out.png");
    await made.close();
  }

  // --- 3. signed in as Di, 390, dark --------------------------------------------
  console.log("at 390 px, dark, signed in as Di");
  const hers = await api(`/api/people?op=alike&handle=${handles.ann}&tests=1`, { token: sessions.di.access_token });
  check(`her answer is hers alone, never kept (${hers.cache})`, /private/.test(hers.cache) && /no-store/.test(hers.cache));
  {
    const made = await context({ as: sessions.di, width: 390, dark: true });
    const page = await made.newPage();
    listen(page, "390");
    const seen = await alikeOn(page);
    const mine = seen.rows.filter((one) => Object.values(handles).includes(one.handle));
    check(`only Cy: not Di herself, not Bo, whom she follows, not Fay (${order(mine).join(", ")})`,
      seen.state === "shown" && JSON.stringify(order(mine)) === JSON.stringify([handles.cy]));
    check("nothing wider than the phone", !(await sideways(page)));
    await page.evaluate(() => document.getElementById("alike")?.scrollIntoView({ block: "center" }));
    await page.waitForTimeout(400);
    await shot(page, "2_alike_390_dark_in.png");
    await page.click(`#alike .person-row[data-handle="${handles.cy}"] button[data-follow]`);
    await until(page, (handle) => document.querySelector(`#alike .person-row[data-handle="${handle}"] button[data-follow]`)
      ?.getAttribute("aria-pressed") === "true" && !document.querySelector(`#alike .person-row[data-handle="${handle}"] button[data-follow]`)
      .disabled, "Follow pressed", 30, handles.cy);
    const state = await api(`/api/people?op=follows&handle=${handles.cy}`, { token: sessions.di.access_token });
    const button = await page.evaluate((handle) => document.querySelector(`#alike .person-row[data-handle="${handle}"] button[data-follow]`)
      ?.textContent.trim(), handles.cy);
    check(`Follow on Cy follows him in place (${button}; the API: you_follow ${state.body.you_follow})`,
      button === "Following" && state.body.you_follow === true && page.url().includes(`/u/${handles.ann}`));
    await shot(page, "3_alike_390_dark_followed.png");
    const again = await alikeOn(page);
    const left = again.rows.filter((one) => Object.values(handles).includes(one.handle));
    check(`asked again, nobody of these is left (${order(left).join(", ") || "none"}), and with nobody More like is hidden`,
      left.length === 0 && (again.rows.length > 0 || (again.state === "none" && !again.shown)));
    await made.close();
  }
} catch (trouble) {
  check(`the flow ran to its end (${String(trouble.message || trouble).slice(0, 300)})`, false);
} finally {
  for (const one of who) {
    const gone = await deleteAccount(emails[one]).catch(() => false);
    if (!gone && sessions[one]) console.log(`  --    ${emails[one]} was not deleted`);
  }
  await browser.close();
}
check(`no page errors${errors.length ? `: ${errors.slice(0, 4).join(" | ")}` : ""}`, errors.length === 0);
console.log(failed ? `alike flow: ${failed} FAILED` : "alike flow: passed");
process.exit(failed ? 1 : 0);
