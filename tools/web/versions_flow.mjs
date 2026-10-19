// Versions of a shared model, in real browsers: publishing again keeps the
// old one, says what changed, and keeps a builder's place.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8852 --static=build/web --hold=share_versions &
//   node tools/web/versions_flow.mjs --url=http://127.0.0.1:8852 --out=shots/versions
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/versions_flow.mjs --url=<preview> --out=DIR
//
// The second once supabase/versions.sql is applied to the project the
// preview uses; until then the local relay holds its one table in memory
// (--hold, tools/web/held_tables.mjs) and sends everything else — the
// accounts, the models' rows, their files — to the real project.
//
//   1. A model of six steps, two bricks a step, its steps carried as the
//      app carries them (SharedPages, by src/dev/share_pages_probe.gd
//      --write), published and listed by a throwaway owner. Then the same
//      with the two bricks of step 3 red where they were blue... blue where
//      they were red, published again with a note: version 2, which says
//      2 parts added and 2 removed in step 3, and that step 3 is the first
//      that changed.
//   2. A browser that never signed in: the link's page says what changed
//      and what the owner said, and names version 1 at /m/<id>/v/1, which
//      still has the old model, says it is older and links to the newest.
//      Its viewer opens version 1 and says so.
//   3. Builders who were building version 1 on this device: one parked at
//      step 2 opens the link on step 2 with nothing to tell, kept on
//      version 2 from then; one parked at step 5 is told the model changed
//      from step 3, and Go to step 3 goes there; one who closed the player
//      on step 5 is told on the viewer, and offered step 3.
//   4. The gallery's card is the link, which is the newest; a second
//      throwaway account copies it with Open in Brickworks and shares the
//      copy, whose page says it was remixed from version 2.
//   5. The owner unpublishes: the link, version 1's page, version 1's model
//      and every file of both versions are gone, and so are their rows.
//
// Pictures in --out. Both accounts are deleted at the end with their rows,
// after their models are taken down, so nothing is left in the bucket.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:8852").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/versions"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
const NAME = "Versions Flow Tower";
const WORD = `versionword${randomBytes(3).toString("hex")}`;
const NOTE = "Step 3 is blue now, to match the roof";
const rand = randomBytes(4).toString("hex");
const owner = `delivered+bw-versions-owner-${rand}@resend.dev`;
const copier = `delivered+bw-versions-copier-${rand}@resend.dev`;

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

// --- the two versions, their steps carried -------------------------------

/// Six steps of two 2 x 4 bricks, one on another; [blue] makes step 3's
/// two blue where they are red.
function tower(blue) {
  const lines = [`0 ${NAME}`, "0 Name: versions_tower.ldr", "0 Author: Versions Flow", ""];
  for (let step = 1; step <= 6; step += 1) {
    const colour = blue && step === 3 ? 1 : 4;
    lines.push(`1 ${colour} 0 ${-24 * step} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push(`1 ${colour} 80 ${-24 * step} 0 1 0 0 0 1 0 0 0 1 3001.dat`);
    lines.push("0 STEP");
  }
  return `${lines.join("\r\n")}\r\n`;
}
const models = path.join(out, "models");
mkdirSync(models, { recursive: true });
const files = [];
for (const [n, blue] of [[1, false], [2, true]]) {
  writeFileSync(path.join(models, `v${n}_bare.ldr`), tower(blue));
  files.push(path.join(models, `v${n}_bare.ldr`), path.join(models, `v${n}.ldr`));
}
const made = spawnSync("godot", ["--headless", "--path", root, "--script", "src/dev/share_pages_probe.gd",
  "--", "--write", ...files], { encoding: "utf8", timeout: 600000,
  env: { ...process.env, XDG_DATA_HOME: process.env.XDG_DATA_HOME || path.join(root, ".scratch-data") } });
const v1 = readFileSync(path.join(models, "v1.ldr"), "utf8");
const v2 = readFileSync(path.join(models, "v2.ldr"), "utf8");
if (!v1.includes("0 !BRICKWORKS PAGES ") || !v2.includes("0 !BRICKWORKS PAGES ")) {
  throw new Error(`the steps were not carried: ${String(made.stderr || "").slice(-300)}`);
}

// --- helpers ---------------------------------------------------------------

const browser = await launch({ signedOut: true });

async function context({ as = null, place = null, id = "" } = {}) {
  const made = await browser.newContext({ viewport: { width: 1280, height: 860 }, extraHTTPHeaders: headers });
  if (as) {
    const { kept } = await mintSession(as);
    await made.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(kept)]);
  }
  if (place) {
    // Where this device was on the link, as BuildSteps.remember keeps it:
    // set once, before the app first reads it.
    await made.addInitScript(([key, value]) => {
      try { if (!sessionStorage.getItem("placed")) { localStorage.setItem(key, value); sessionStorage.setItem("placed", "1"); } } catch {}
    }, [`brickworks.build.${id}`, JSON.stringify(place)]);
  }
  return made;
}

function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Parse Error|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}

const state = (page) => page.evaluate(() => window.brickworksShare || {});
const controls = (page) => page.evaluate(() => window.brickworksControls || {});

async function until(page, test, what, seconds = 240, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(500);
  }
}

/// Press what the app shows by its name, once two of its reports agree on
/// where it is (share_flow.mjs press).
async function press(page, name, seconds = 60) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    let at = (await controls(page))[name];
    for (let n = 0; at && n < 6; n += 1) {
      await page.waitForTimeout(550);
      const again = (await controls(page))[name];
      if (again && again.x === at.x && again.y === at.y) break;
      at = again;
    }
    if (at) {
      await page.mouse.click(at.x, at.y);
      await page.waitForTimeout(400);
      return at;
    }
    if (Date.now() > end) throw new Error(`no ${name} on the page`);
    await page.waitForTimeout(500);
  }
}

const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));

let asked = 0;
async function fetchText(url) {
  const fresh = `${url}${url.includes("?") ? "&" : "?"}fresh=${Date.now()}-${asked += 1}`;
  const reply = await fetch(fresh, { headers, redirect: "manual" });
  return { status: reply.status, text: await reply.text() };
}

async function api(token, pathname, body) {
  const reply = await fetch(`${site}${pathname}`, { method: "POST",
    headers: { ...headers, "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify(body) });
  return { status: reply.status, body: await reply.json().catch(() => ({})) };
}

/// Whether the bucket has a file, asked with the secret key.
async function inBucket(name) {
  const reply = await fetch(`${SUPABASE}/storage/v1/object/shared-models/${name}`,
    { method: "HEAD", headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` } });
  return reply.ok;
}

/// A builder's browser on the link: the viewer, ready, and what it says.
async function builder(id, place, name, address = `/app?view=${id}`) {
  const made = await context({ place, id });
  const page = await made.newPage();
  listen(page, name);
  await page.goto(`${site}${address}`, { waitUntil: "domcontentloaded", timeout: 180000 });
  await until(page, () => ((window.brickworksShare || {}).view || {}).state === "ready", `${name}: the viewer`, 300);
  return { made, page };
}

let id = "";
let remixId = "";
let ownerToken = "";
let copierToken = "";
try {
  // --- 1. two versions ----------------------------------------------------
  console.log("two versions, published");
  ownerToken = (await mintSession(owner)).access_token;
  const one = await api(ownerToken, "/api/share", { name: NAME, model: v1, listed: true,
    description: `A tower of six steps for the versions flow, with a ${WORD}.` });
  id = one.body.id || "";
  check(`version 1 at /m/${id}: ${one.status}, version ${one.body.version}, nothing said changed`,
    one.status === 201 && one.body.version === 1 && one.body.said === "" && one.body.first_changed === null);
  const two = await api(ownerToken, "/api/share", { id, name: NAME, model: v2, listed: true, note: NOTE,
    description: `A tower of six steps for the versions flow, with a ${WORD}.` });
  check(`published again with a note: version ${two.body.version}, "${two.body.said}"`,
    two.status === 200 && two.body.version === 2
    && two.body.said === "Version 2: 2 parts added and 2 removed in step 3." && two.body.note === NOTE);
  const lots = two.body.changes || {};
  check(`worked out from the two files, by part and colour: added ${JSON.stringify(lots.added)}, removed ${JSON.stringify(lots.removed)}`,
    JSON.stringify(lots.added) === JSON.stringify([{ part: "3001", colour: 1, count: 2 }])
    && JSON.stringify(lots.removed) === JSON.stringify([{ part: "3001", colour: 4, count: 2 }]));
  check(`...by step: step 3 changed and the first to differ (${JSON.stringify(lots.steps_changed)}, first ${two.body.first_changed})`,
    JSON.stringify(lots.steps_changed) === "[3]" && two.body.first_changed === 3 && lots.compared === true);
  check("both kept in the bucket: the newest at the link's name, version 1 under its number",
    (await inBucket(`${id}.mpd`)) && (await inBucket(`${id}.v1.mpd`)));

  // --- 2. what a visitor sees ---------------------------------------------
  console.log("the link, as anybody sees it");
  const visitorContext = await context();
  const visitor = await visitorContext.newPage();
  listen(visitor, "visitor");
  await visitor.goto(`${site}/m/${id}`, { waitUntil: "load" });
  const page = await visitor.evaluate(() => ({
    changed: (document.querySelector(".versions .changed") || {}).textContent || "",
    note: (document.querySelector(".versions .version-note") || {}).textContent || "",
    kept: (document.querySelector(".versions .kept") || {}).textContent || "",
    lots: [...document.querySelectorAll(".versions .lots li")].map((li) => li.textContent),
    earlier: [...document.querySelectorAll(".versions .earlier a")].map((a) => a.getAttribute("href")),
    line: (document.querySelector(".version-line") || {}).textContent || "",
  }));
  check(`its page says what changed: "${page.changed.replace(/\s+/g, " ").trim()}"`,
    page.changed.includes("Version 2: 2 parts added and 2 removed in step 3."));
  check(`...what its owner said: "${page.note.trim()}"`, page.note.trim() === NOTE);
  check(`...part by part: ${page.lots.join("; ")}`,
    page.lots.join("|") === "Added 2 × 3001 in Blue|Removed 2 × 3001 in Red");
  check(`...how far a builder can carry on: "${page.kept.replace(/\s+/g, " ").trim()}"`, /Steps 1–2 are as they were/.test(page.kept));
  check(`...and names version 1 at its own address (${page.earlier.join(", ")})`, page.earlier.includes(`/m/${id}/v/1`));
  await visitor.evaluate(() => document.querySelector(".versions")?.scrollIntoView());
  await shot(visitor, "1_page_says_what_changed.png");

  await visitor.goto(`${site}/m/${id}/v/1`, { waitUntil: "load" });
  const old = await visitor.evaluate(() => ({
    banner: (document.querySelector(".old-version") || {}).textContent || "",
    newest: (document.querySelector(".old-version a") || {}).getAttribute?.("href") || "",
    view: (document.querySelector(".actions a.cta") || {}).getAttribute?.("href") || "",
    robots: Boolean(document.querySelector('meta[name="robots"][content="noindex"]')),
  }));
  check(`/m/${id}/v/1 is marked as older: "${old.banner.replace(/\s+/g, " ").trim()}"`,
    /This is version 1 of\s+2/.test(old.banner) && old.newest === `/m/${id}`);
  check(`...its View in 3D is version 1's (${old.view}), and it is kept out of searches`, old.view === `/app?view=${id}&v=1` && old.robots);
  await shot(visitor, "2_version_1_page.png");
  const oldModel = await (await fetch(`${site}/api/share?id=${id}&v=1`, { headers })).json();
  check(`...and version 1's model is the old one: step 3 red (version ${oldModel.version} of ${oldModel.newest})`,
    oldModel.version === 1 && oldModel.newest === 2 && oldModel.model.includes("1 4 0 -72 0 ")
    && !oldModel.model.includes("1 1 0 -72 0 "));

  await visitor.goto(`${site}/app?view=${id}&v=1`, { waitUntil: "domcontentloaded" });
  await until(visitor, () => ((window.brickworksShare || {}).view || {}).state === "ready", "version 1 in the viewer", 300);
  const oldView = (await state(visitor)).view;
  check(`its viewer opens version 1 and says so: "${oldView.version_line}"`,
    oldView.version === 1 && oldView.newest === 2 && oldView.version_line === "Version 1 of 2, an older one. Open the newest");
  check(`...at version 1's own address (${new URL(visitor.url()).pathname})`, new URL(visitor.url()).pathname === `/m/${id}/v/1`);
  await shot(visitor, "3_viewer_version_1.png");
  await visitorContext.close();

  // --- 3. builders --------------------------------------------------------
  console.log("a builder parked at step 2 of version 1");
  let b = await builder(id, { page: 2, building: true, version: 1 }, "builder at 2");
  let built = await until(b.page, () => {
    const s = (window.brickworksShare || {}).build || {};
    return s.open && s.page > 0 ? s : null;
  }, "the step player", 240);
  await b.page.waitForTimeout(1500);
  built = (await state(b.page)).build;
  const view2 = (await state(b.page)).view;
  check(`opens on step ${built.page} of version ${view2.version}, told nothing ("${built.changed}")`,
    built.page === 2 && view2.version === 2 && built.changed_from === 0 && built.changed === "");
  const kept2 = await b.page.evaluate((key) => localStorage.getItem(key), `brickworks.build.${id}`);
  check(`...and the place is kept on version 2 from now (${kept2})`, JSON.parse(kept2 || "{}").version === 2);
  await shot(b.page, "4_builder_at_2.png");
  await b.made.close();

  console.log("a builder parked at step 5 of version 1");
  b = await builder(id, { page: 5, building: true, version: 1 }, "builder at 5");
  built = await until(b.page, () => {
    const s = (window.brickworksShare || {}).build || {};
    return s.open && s.page > 0 && s.changed ? s : null;
  }, "the step player telling", 240);
  check(`opens where they were, step ${built.page}, and says "${built.changed}"`,
    built.page === 5 && built.changed === "This model changed from step 3.");
  await shot(b.page, "5_builder_at_5_told.png");
  await press(b.page, "build_changed_go");
  built = await until(b.page, () => {
    const s = (window.brickworksShare || {}).build || {};
    return s.page === 3 ? s : null;
  }, "step 3", 60);
  check(`Go to step 3 goes there (${built.caption}), and the notice goes`, built.page === 3 && built.changed === "");
  await shot(b.page, "6_builder_to_step_3.png");
  await b.made.close();

  console.log("a builder who closed the step player on step 5 of version 1");
  b = await builder(id, { page: 5, building: false, version: 1 }, "viewer at 5");
  const told = await until(b.page, () => ((window.brickworksShare || {}).view || {}).place_says || null, "the viewer telling", 60);
  check(`the viewer says "${told}"`, told === "This model changed from step 3 since you were on step 5.");
  await shot(b.page, "7_viewer_told.png");
  await press(b.page, "view_build_from");
  built = await until(b.page, () => {
    const s = (window.brickworksShare || {}).build || {};
    return s.open && s.page > 0 ? s : null;
  }, "the step player from step 3", 120);
  check(`Build from step 3 opens the step player there (step ${built.page})`, built.page === 3);
  await b.made.close();

  // --- 4. the gallery and a remix -----------------------------------------
  console.log("the gallery, and a remix of version 2");
  const listed = await (await fetch(`${site}/api/share?op=list&tests=1&q=${WORD}`, { headers })).json();
  const card = (listed.models || []).find((one) => one.id === id) || {};
  check(`the gallery's card is the link, which is the newest (${card.url})`, String(card.url || "").endsWith(`/m/${id}`));
  const copyContext = await context();
  const copying = await copyContext.newPage();
  listen(copying, "copier");
  await copying.goto(`${site}/app?view=${id}`, { waitUntil: "domcontentloaded" });
  await until(copying, () => ((window.brickworksShare || {}).view || {}).state === "ready", "the viewer to copy from", 300);
  await press(copying, "view_copy");
  await until(copying, () => (window.brickworksAccount || {}).gated === true, "the sign-in screen", 180);
  const { kept } = await mintSession(copier);
  copierToken = kept.access_token || (await mintSession(copier)).access_token;
  await copyContext.addInitScript(([name, value]) => {
    try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
  }, [STORAGE_KEY, JSON.stringify(kept)]);
  await copying.reload({ waitUntil: "domcontentloaded" });
  await until(copying, () => {
    const s = window.brickworksShare || {};
    return (window.brickworksAccount || {}).state === "signed_in" && String(s.title || "").startsWith("Versions Flow Tower")
      && !location.search.includes("copy=") ? s : null;
  }, "the copy", 300);
  await copying.waitForTimeout(4000);
  await press(copying, "tool_share");
  const panel = await until(copying, () => ((window.brickworksShare || {}).panel || {}).open
    ? window.brickworksShare.panel : null, "their Share panel");
  check(`the copy knows it is of version ${panel.remixed_from_version} of ${panel.remixed_from}`,
    panel.remixed_from === id && panel.remixed_from_version === 2);
  await press(copying, "share_publish");
  const remix = await until(copying, () => {
    const p = (window.brickworksShare || {}).panel || {};
    return p.state === "published" || p.state === "failed" ? p : null;
  }, "publishing the remix", 180);
  remixId = remix.id || "";
  const remixPage = (await fetchText(`${site}/m/${remixId}`)).text;
  check(`the remix's page says it was remixed from version 2, with a link to it`,
    remixPage.includes(`Remixed from <a href="/m/${id}">${NAME}</a>, <a class="from-version" href="/m/${id}/v/2">version 2</a>`));
  await copying.goto(`${site}/m/${remixId}`, { waitUntil: "load" });
  await shot(copying, "8_remix_of_version_2.png");
  await copyContext.close();

  // --- 5. unpublished, every version --------------------------------------
  console.log("unpublished: both versions go");
  const gone = await api(ownerToken, `/api/share?op=unpublish&id=${id}`, {});
  check(`unpublished (${gone.status}), ${gone.body.versions} versions taken away`, gone.status === 200 && gone.body.versions === 2);
  const after = {
    link: (await fetchText(`${site}/m/${id}`)).status,
    v1: (await fetchText(`${site}/m/${id}/v/1`)).status,
    model: (await fetchText(`${site}/api/share?id=${id}&v=1`)).status,
    newest: await inBucket(`${id}.mpd`), first: await inBucket(`${id}.v1.mpd`),
  };
  check(`the link, version 1's page and its model say it is gone (${after.link}, ${after.v1}, ${after.model})`,
    after.link === 410 && after.v1 === 410 && after.model === 410);
  check("...and neither version's file is in the bucket", !after.newest && !after.first);
  const rows = await fetch(`${site}/__held/share_versions`, { headers });
  if (rows.ok) {
    const held = await rows.json();
    check(`...nor are their rows (${held.filter((row) => row.model === id).length} left)`, !held.some((row) => row.model === id));
  }
  id = "";
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  if (id && ownerToken) await api(ownerToken, `/api/share?op=unpublish&id=${id}`, {}).catch(() => {});
  if (remixId && copierToken) await api(copierToken, `/api/share?op=unpublish&id=${remixId}`, {}).catch(() => {});
  await browser.close();
  for (const email of [owner, copier]) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "a model published again keeps the old one, says what changed, and keeps a builder's place");
process.exit(failed ? 1 : 0);
