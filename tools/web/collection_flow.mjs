// My collection in a real browser, as a person uses it.
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_flow.mjs --url=https://<a preview>/app --out=shots/collection_web
//
// Signs in as a throwaway account (a Resend test address; its session minted
// here, nobody emailed), opens the parts list with P and presses its "What
// do I need?", goes to What I own, brings in a made-up Rebrickable parts
// export (tests/fixtures/collection/rebrickable_parts.csv) through the
// page's own file chooser, types a set number in and adds it, then looks at
// what the model on the baseplate needs that is not owned, downloads the
// shortfall as a BrickLink wanted list and as a Rebrickable CSV and reads
// both, ranks what could be built and opens the first. It fails if a
// control never shows, the import is not kept with the account, the
// wanted list does not ask for exactly what is short, the ranking is out of
// order, or a script error reaches the console. The account is deleted at
// the end, and its collection with it (the probe checks the row is gone).
//
// Pictures in --out: 1_need_empty.png, 2_imported.png, 3_need.png,
// 4_build.png, 5_opened.png. Look at them.
import { chromium } from "playwright";
import { mkdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { SOFTWARE } from "./browser.mjs";
import { deleteAccount, signInContext } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8147/index.html";
const bypass = process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = args.out || "shots/collection_web";
mkdirSync(out, { recursive: true });
const sample = resolve(args.csv || "tests/fixtures/collection/rebrickable_parts.csv");
const email = `delivered+bw-collection-flow-${Date.now().toString(36)}@resend.dev`;

const said = [];
const errors = [];
const t0 = Date.now();
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const browser = await chromium.launch({ args: SOFTWARE });
const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, acceptDownloads: true });
let ownerId = "";
try {
  const kept = await signInContext(context, email);
  ownerId = kept.user_id;
  const page = await context.newPage();
  page.choosers = [];
  page.on("filechooser", (chooser) => page.choosers.push(chooser));
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|USER ERROR|Parse Error/i.test(m.text())) errors.push(m.text().slice(0, 300));
  });

  const controls = () => page.evaluate(() => window.brickworksControls || {});
  const state = () => page.evaluate(() => window.brickworksState || null);
  const mine = () => page.evaluate(() => window.brickworksCollection || null);
  const shot = async (name) => {
    try {
      await page.screenshot({ path: `${out}/${name}`, timeout: 120000 });
    } catch (e) {
      console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
    }
  };
  const until = async (test, seconds, what) => {
    for (let n = 0; n < seconds * 2; n++) {
      if (await test()) return true;
      await page.waitForTimeout(500);
    }
    await shot(`never_${what.replace(/\W+/g, "_")}.png`);
    return false;
  };
  const where = async (name, seconds = 120) => {
    if (!(await until(async () => Boolean((await controls())[name]), seconds, name))) {
      throw new Error(`the app never showed "${name}"`);
    }
    return (await controls())[name];
  };
  const click = async (name) => {
    const at = await where(name);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(1500);
  };
  const typeInto = async (name, text) => {
    const at = await where(name);
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(500);
    await page.keyboard.type(text, { delay: 60 });
    await page.waitForTimeout(500);
  };

  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
  ok(await until(async () => Boolean((await controls()).open), 400, "app"), "the app came up, signed in");
  await page.waitForTimeout(Number(args.load || 15000));
  const bricks = (await state())?.bricks || 0;
  ok(bricks > 0, `there is a model on the baseplate to check (${bricks} bricks)`);

  // P, with the pointer over the model, then the parts list's own button.
  const view = await where("view");
  for (let n = 0; n < 3 && !(await controls()).parts_need; n++) {
    await page.mouse.move(view.x, view.y);
    await page.keyboard.press("p");
    await page.waitForTimeout(3000);
  }
  await click("parts_need");
  ok(await until(async () => (await mine())?.open && (await mine())?.page === "need", 60, "need"),
    "the parts list's What do I need? opens My collection on the shortfall");
  const before = await mine();
  ok(before && before.need.pieces > 0 && before.need.short === before.need.pieces,
    `with nothing owned yet, all of it is short: ${before?.need.short} of ${before?.need.pieces}`);
  await shot("1_need_empty.png");

  // What I own: the made-up Rebrickable export, through the page's chooser.
  await click("collection_tab_own");
  let chooser = null;
  for (let n = 0; n < 3 && !chooser; n++) {
    page.choosers.length = 0;
    await click("collection_csv");
    for (let wait = 0; wait < 40 && page.choosers.length === 0; wait++) await page.waitForTimeout(500);
    chooser = page.choosers.shift() || null;
  }
  ok(Boolean(chooser), "Rebrickable CSV… brings up the page's file chooser");
  if (chooser) await chooser.setFiles(sample);
  ok(await until(async () => /rebrickable_parts\.csv/.test((await mine())?.status || "")
    && !/reading/.test((await mine())?.status || ""), 90, "imported"),
    `the export is read: "${(await mine())?.status}"`);
  const imported = await mine();
  ok(imported.lots === 11 && /left out: 2 /.test(imported.status),
    `eleven lots kept, the two in [No Color] left out and said so (${imported.lots} lots)`);
  await typeInto("collection_sets", "6020");
  await click("collection_add_sets");
  ok(await until(async () => (await mine())?.sets === 1 && /added 6020/.test((await mine())?.status || ""),
    90, "set"), `a set typed by number is added and expanded: ${(await mine())?.pieces} pieces in all`);
  const withSet = await mine();
  // Rebrickable's 47, its figure's legs counted as the hips and two legs
  // LDraw draws them as (tools/collection_data.py, 2026-10-19).
  ok(withSet.pieces === 27 + 49, `27 loose pieces and the Magic Shop's 49 (${withSet.pieces})`);
  await page.waitForTimeout(3000);
  await shot("2_imported.png");

  // What do I need, now.
  await click("collection_tab_need");
  await page.waitForTimeout(3000);
  const need = (await mine()).need;
  ok(need.owned > 0 && need.short > 0 && need.short < need.pieces,
    `the model now: ${need.owned} of ${need.pieces} owned, ${need.short} short in ${need.lots} lots`);
  await shot("3_need.png");
  const take = async (name) => {
    const waiting = page.waitForEvent("download", { timeout: 60000 });
    await click(name);
    const file = await waiting;
    const path = `${out}/${file.suggestedFilename()}`;
    await file.saveAs(path);
    return { name: file.suggestedFilename(), text: readFileSync(path, "utf8") };
  };
  const xml = await take("collection_export_bricklink");
  const items = (xml.text.match(/<ITEM>/g) || []).length;
  const asked = [...xml.text.matchAll(/<MINQTY>(\d+)<\/MINQTY>/g)].reduce((n, m) => n + Number(m[1]), 0);
  const left = /lots left off/.test((await mine()).status);
  ok(items > 0 && (left ? asked <= need.short : asked === need.short),
    `the BrickLink wanted list (${xml.name}) asks for what is short: ${asked} pieces in ${items} lots`);
  const csv = await take("collection_export_rebrickable");
  const rows = csv.text.trim().split("\n");
  ok(rows[0] === "Part,Color,Quantity" && rows.length > 1,
    `the Rebrickable CSV (${csv.name}) has ${rows.length - 1} rows`);

  // What can I build.
  await click("collection_tab_build");
  ok(await until(async () => ((await mine())?.build.ranked || 0) > 100, 240, "ranked"),
    `examples and official models ranked: ${(await mine())?.build.ranked}`);
  const top = (await mine()).build.top;
  ok(top.length >= 2 && top[0].exact >= top[1].exact,
    `most owned first: ${top.slice(0, 3).map((t) => `${t.name} ${Math.round(t.exact * 100)}%`).join(", ")}`);
  await page.waitForTimeout(3000);
  await shot("4_build.png");
  await click("collection_open_first");
  ok(await until(async () => (await mine())?.page === "need", 120, "opened"),
    "Open on the first model that opens puts it on the baseplate and shows what it needs");
  await page.waitForTimeout(8000);
  await shot("5_opened.png");
  await page.close();
} catch (error) {
  ok(false, String(error.stack || error).split("\n").slice(0, 3).join(" "));
} finally {
  await browser.close();
  const gone = await deleteAccount(email);
  let rows = -1;
  if (ownerId && process.env.SUPABASE_URL) {
    const secret = process.env.SUPABASE_SECRET_KEY;
    const reply = await fetch(`${process.env.SUPABASE_URL.replace(/\/+$/, "")}/rest/v1/collections?owner=eq.${ownerId}&select=owner`,
      { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
    rows = reply.ok ? (await reply.json()).length : -1;
  }
  ok(gone && rows === 0, `the throwaway account is deleted, and its collection with it (${rows} rows)`);
}

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
console.log(failed
  ? `collection flow: ${failed} problem(s); screenshots in ${out}`
  : `collection flow: imported, short, exported, ranked and opened in a browser; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
