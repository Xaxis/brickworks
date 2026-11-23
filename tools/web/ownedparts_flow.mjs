// What you own, and what a model needs that you lack (ownedparts), on a
// deployment or a local relay, against the live database's real gallery:
//
//   node --env-file=.env tools/web/relay_server.mjs 11461 &
//   node --env-file=.env tools/web/ownedparts_flow.mjs --url=http://127.0.0.1:11461 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/ownedparts_flow.mjs --url=<preview> --out=DIR
//
//   1. Three throwaway accounts keep collections as people do, on the site's
//      own ops: Ada owns real sets, some twice (op own); Bo owns loose parts
//      made from the first page's models (every part of the first, 60% of
//      the second's, 40% of the third's: op lots); Cy owns a set three times
//      and loose bricks.
//   2. The cards: each one's gallery page of 24 (op=list&mine=1), every
//      card's share against a count made here from the raw rows (the
//      collection's row, the sets' inventories, model_needs' rows: read
//      only, through the database's own connection), 3 x 24, and the line
//      each card draws (web/card.js) from those numbers: "You have 87%" from
//      half up, nothing under half, nothing signed out.
//   3. The Parts tab's What you're missing for three models (op=
//      parts_missing): the model's list (/m/X/parts.json) less the
//      collection's raw rows, by part, colour and count; the BrickLink XML
//      parsed back to exactly those; every Pick a Brick line an element of a
//      lot short.
//   4. In a browser, at 1280 and 390, light and dark: Bo's gallery (the
//      lines, the API asks counted: none a card), a model's Parts tab
//      (Missing chosen, the missing BrickLink XML downloaded and read), and
//      Cy's set page (You own 3, In N lists once supabase/owned_quantity.sql
//      is applied); nothing sideways. And the attacks: 100, -1, x, nothing
//      and 0 typed in You own; Enter then leaving the field sends once; two
//      tabs; the set taken out in another tab while the page is open; signed
//      out in the middle of the page.
//
// Pictures in --out. Every account is deleted at the end with everything
// of theirs (their collection, their list).
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { builtCount, ownedKey, shardOf } from "../../api/_owned.js";
import { ownedLine } from "../../web/card.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11461").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/ownedparts"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const emails = Object.fromEntries(["ada", "bo", "cy"].map((who) => [who, `delivered+bw-ownedparts-${who}-${rand}@resend.dev`]));
// Real sets of the catalogue with inventories: a harbour, a speed boat
// (twice) and Galaxy Explorer; Cy the speed boat three times.
const ADA_SETS = [["6541-1", 1], ["6596-1", 2], ["10497-1", 1]];
const CY_SET = "6596-1";
const SHARDS = path.join(root, "assets/generated/sets");

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
const findings = { cards: [], parts: [], requests: {}, attacks: [] };

async function api(pathname, { method = "GET", token, body } = {}, again = true) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let parsed = {};
  try { parsed = JSON.parse(text); } catch { parsed = { text }; }
  const said = { status: reply.status, body: parsed };
  if (said.status === 503 && again && /sign-in service/.test(String(said.body.error || ""))) {
    await new Promise((done) => setTimeout(done, 1500));
    return api(pathname, { method, token, body }, false);
  }
  return said;
}

// The raw rows, read only, through the database's own connection (the
// tables these sums are kept in have no grant to any API role).
const pgModule = process.env.PG_MODULE || "/tmp/pg/node_modules/pg/lib/index.js";
if (!existsSync(pgModule) || !process.env.SUPABASE_DB_PASSWORD) {
  console.log("ownedparts_flow: needs pg (PG_MODULE, npm install --prefix /tmp/pg pg@8) and .env's SUPABASE_DB_PASSWORD");
  process.exit(2);
}
const pg = (await import(pgModule)).default;
const client = new pg.Client({ host: process.env.SUPABASE_POOLER || "aws-0-us-east-1.pooler.supabase.com", port: 5432,
  user: `postgres.${process.env.SUPABASE_PROJECT_REF}`, password: process.env.SUPABASE_DB_PASSWORD, database: "postgres",
  ssl: { rejectUnauthorized: false } });
await client.connect();
await client.query("set default_transaction_read_only = on");
const rows = async (sql, values = []) => (await client.query(sql, values)).rows;

const shardCache = new Map();
const inventory = (set) => {
  const n = shardOf(set);
  if (!shardCache.has(n)) shardCache.set(n, JSON.parse(readFileSync(path.join(SHARDS, `${String(n).padStart(3, "0")}.json`), "utf8")));
  return shardCache.get(n).sets?.[String(set).toLowerCase()] || null;
};

/// What [account] owns, key -> qty, counted here from their collection's
/// raw row: each set's inventory rows times its copies kept apart (less
/// those marked missing), its spares when kept, and the loose rows.
async function ownedRaw(account) {
  const [row] = await rows("select sets, parts from public.collections where owner = $1", [account]);
  const own = new Map();
  const add = (part, colour, n) => {
    const key = ownedKey(part, colour);
    if (key && n > 0) own.set(key, (own.get(key) || 0) + n);
  };
  const bySet = new Map();
  for (const one of row?.sets || []) {
    const held = bySet.get(one.set) || { copies: 0, built: 0, spares: 0, missing: [] };
    const copies = Math.max(1, Number(one.qty) || 1);
    held.copies += copies;
    held.built += builtCount(one);
    if (one.spares) held.spares += copies;
    held.missing.push(...(one.missing || []));
    bySet.set(one.set, held);
  }
  for (const [set, held] of bySet) {
    const record = inventory(set);
    if (!record) continue;
    const gone = new Map();
    for (const lot of held.missing) gone.set(ownedKey(lot.part, lot.colour), (gone.get(ownedKey(lot.part, lot.colour)) || 0) + lot.qty);
    for (const [part, colour, qty] of record.p || []) {
      const key = ownedKey(part, colour);
      const count = qty * (held.copies - held.built);
      const taken = Math.min(count, gone.get(key) || 0);
      if (taken) gone.set(key, gone.get(key) - taken);
      add(part, colour, count - taken);
    }
    for (const [part, colour, qty] of record.s || []) add(part, colour, qty * held.spares);
  }
  for (const lot of row?.parts || []) add(lot.part, lot.colour, Number(lot.qty) || 0);
  return own;
}

/// What each model needs, as its rows are kept: id -> Map key -> qty.
async function needsRaw(ids) {
  const found = await rows("select model, part, colour, qty from public.model_needs where model = any($1)", [ids]);
  const needs = new Map(ids.map((id) => [id, new Map()]));
  for (const row of found) needs.get(row.model)?.set(`${row.part}/${row.colour}`, Number(row.qty));
  return needs;
}

const shareOf = (need, own) => {
  let pieces = 0;
  let have = 0;
  for (const [key, n] of need) {
    pieces += n;
    have += Math.min(n, own.get(key) || 0);
  }
  return { pieces, have };
};

const browser = await launch({ signedOut: true });
async function context({ as = null, width = 1280, height = 900, dark = false } = {}) {
  const phone = width < 600;
  const made = await browser.newContext({ viewport: { width, height }, extraHTTPHeaders: headers,
    colorScheme: dark ? "dark" : "light", isMobile: phone, hasTouch: phone, acceptDownloads: true,
    ...(phone ? { deviceScaleFactor: 2 } : {}) });
  if (as) {
    await made.addInitScript(([name, value]) => {
      // Once a tab: a reload after signing out stays signed out.
      try {
        if (!localStorage.getItem(name) && !sessionStorage.getItem("ownedparts.seeded")) localStorage.setItem(name, value);
        sessionStorage.setItem("ownedparts.seeded", "1");
      } catch {}
    }, [STORAGE_KEY, JSON.stringify(as.kept)]);
  }
  return made;
}
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${who}: ${m.text().slice(0, 220)}`);
  });
}
const shot = (page, name, clip = null) => (clip ? page.locator(clip).screenshot({ path: path.join(out, name), timeout: 60000 })
  : page.screenshot({ path: path.join(out, name), timeout: 60000 }))
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
async function until(page, test, what, seconds = 45, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}
const xmlItems = (text) => [...String(text).matchAll(/<ITEM>([\s\S]*?)<\/ITEM>/g)].map(([, item]) => ({
  id: /<ITEMID>(.*?)<\/ITEMID>/.exec(item)?.[1], colour: Number(/<COLOR>(.*?)<\/COLOR>/.exec(item)?.[1]),
  qty: Number(/<MINQTY>(.*?)<\/MINQTY>/.exec(item)?.[1]) }));

const who = {};
try {
  console.log(`against ${site}`);
  for (const [name, email] of Object.entries(emails)) who[name] = await mintSession(email);
  for (const one of Object.values(who)) one.id = one.kept.user_id;

  // --- 1. The collections --------------------------------------------------
  console.log("three collections, kept as people keep them");
  const own = async (person, set, qty) => api("/api/collection", { method: "POST", token: person.access_token,
    body: { op: "own", set, was: 0, qty, id: `own-${rand}-${set}-${Math.random().toString(36).slice(2, 8)}` } });
  for (const [set, qty] of ADA_SETS) {
    const done = await own(who.ada, set, qty);
    check(`Ada owns ${set} ×${qty}: ${done.status} ${JSON.stringify(done.body.done || done.body.error)}`, done.status === 200 && done.body.done?.owned === qty);
  }
  const front = await api("/api/share?op=list&page=1");
  const firstPage = (front.body.models || []).map((one) => one.id);
  check(`the gallery's first page: ${firstPage.length} cards`, firstPage.length === 24);
  const needs = await needsRaw(firstPage);
  // Bo's loose parts: every part of the first model, 60% of the second's,
  // 40% of the third's, lot by lot, rounded up.
  const loose = new Map();
  const giveOf = (id, share) => {
    for (const [key, n] of needs.get(id) || []) {
      const part = key.slice(0, key.lastIndexOf("/"));
      const colour = Number(key.slice(key.lastIndexOf("/") + 1));
      const take = Math.ceil(n * share);
      if (take > 0) loose.set(key, { part, colour, qty: Math.max(loose.get(key)?.qty || 0, take) });
    }
  };
  giveOf(firstPage[0], 1);
  giveOf(firstPage[1], 0.6);
  giveOf(firstPage[2], 0.4);
  const add = [...loose.values()].filter((lot) => /^[a-z0-9][a-z0-9._-]{0,40}$/.test(lot.part)).slice(0, 2000);
  const lots = await api("/api/collection", { method: "POST", token: who.bo.access_token, body: { op: "lots", id: `lots-${rand}-bo`, add } });
  check(`Bo keeps ${add.length} lots of loose parts: ${lots.status}`, lots.status === 200);
  const cy = await own(who.cy, CY_SET, 3);
  const cyLots = await api("/api/collection", { method: "POST", token: who.cy.access_token, body: { op: "lots", id: `lots-${rand}-cy`,
    add: [{ part: "3001", colour: 4, qty: 50 }, { part: "3020", colour: 15, qty: 20 }, { part: "3062b", colour: 46, qty: 8 }] } });
  check(`Cy owns ${CY_SET} ×3 and 78 loose bricks: ${cy.status}, ${cyLots.status}`, cy.status === 200 && cyLots.status === 200);

  // --- 2. The cards, 3 x 24, against the raw rows ---------------------------
  console.log("each card's share, against a count from the raw rows");
  const pages = {};
  for (const name of ["ada", "bo", "cy"]) {
    const asked = await api("/api/share?op=list&page=1&mine=1", { token: who[name].access_token });
    pages[name] = asked.body.models || [];
    const mine = await ownedRaw(who[name].id);
    const theirs = await needsRaw(pages[name].map((one) => one.id));
    let wrong = 0;
    let lines = 0;
    let shown = 0;
    for (const card of pages[name]) {
      const raw = shareOf(theirs.get(card.id) || new Map(), mine);
      const said = card.owned || {};
      const same = Number(said.pieces) === raw.pieces && Number(said.have) === raw.have;
      if (!same) wrong += 1;
      const line = ownedLine({ have: raw.have, pieces: raw.pieces });
      if (line) shown += 1;
      if (ownedLine(said) === line) lines += 1;
      findings.cards.push({ who: name, id: card.id, api: `${said.have}/${said.pieces}`, raw: `${raw.have}/${raw.pieces}`, line });
    }
    check(`${name}: ${pages[name].length} cards, ${wrong} wrong against the raw rows; ${lines} lines as their numbers say, `
      + `${shown} of them with a line (half or more)`, pages[name].length === 24 && wrong === 0 && lines === pages[name].length);
  }
  const boLine = new Map(findings.cards.filter((one) => one.who === "bo").map((one) => [one.id, one.line]));
  const boLines = firstPage.slice(0, 3).map((id) => boLine.get(id));
  check(`Bo's first three: "${boLines[0]}", "${boLines[1]}", "${boLines[2]}" (every part, 60%, under half)`,
    /every part/.test(boLines[0]) && /^You have (5|6)\d%$/.test(boLines[1]) && boLines[2] === "");
  const signedOut = await api("/api/share?op=list&page=1");
  check("signed out: no card has a share", (signedOut.body.models || []).every((one) => !one.owned));

  // --- 3. What you're missing, three models ---------------------------------
  console.log("the Parts tab's What you're missing, against the model's list less the raw rows");
  const picks = [["bo", firstPage[1]], ["ada", pages.ada.slice().sort((a, b) => (b.owned?.have || 0) / (b.owned?.pieces || 1)
    - (a.owned?.have || 0) / (a.owned?.pieces || 1))[0]?.id], ["cy", firstPage[3]]];
  const missingOf = {};
  for (const [name, id] of picks) {
    const list = await api(`/m/${id}/parts.json`);
    const asked = await api(`/api/share?op=parts_missing&id=${id}`, { token: who[name].access_token });
    const body = asked.body;
    missingOf[id] = body;
    const mine = await ownedRaw(who[name].id);
    const need = new Map();
    for (const lot of list.body.lots || []) {
      const key = lot.custom ? "" : ownedKey(lot.part, lot.colour);
      if (key) need.set(key, (need.get(key) || 0) + lot.count);
    }
    const raw = new Map();
    for (const [key, n] of need) if (n > (mine.get(key) || 0)) raw.set(key, n - (mine.get(key) || 0));
    const got = new Map();
    for (const lot of body.missing || []) {
      const key = ownedKey(lot.part, lot.colour);
      got.set(key, (got.get(key) || 0) + lot.count);
    }
    const keys = new Set([...raw.keys(), ...got.keys()]);
    const wrong = [...keys].filter((key) => (raw.get(key) || 0) !== (got.get(key) || 0));
    const shortBy = [...got.values()].reduce((n, v) => n + v, 0);
    check(`${name} on ${id}: ${asked.status}, ${body.have}/${body.pieces} had, missing ${shortBy} in ${(body.missing || []).length} lots; `
      + `${wrong.length} of ${keys.size} keys wrong against the list less the raw rows`, asked.status === 200 && wrong.length === 0
      && body.have + shortBy === body.pieces);
    const items = xmlItems(body.files?.bricklink);
    const qty = items.reduce((n, item) => n + item.qty, 0);
    check(`its BrickLink XML parses: ${items.length} items, ${qty} parts, the ${(body.missing || []).length} lots short less `
      + `${body.left_out?.bricklink} with no BrickLink colour`, /^<INVENTORY>/.test(body.files?.bricklink || "")
      && items.length + Number(body.left_out?.bricklink || 0) === (body.missing || []).length
      && qty <= shortBy && items.every((item) => item.id && item.colour >= 0 && item.qty >= 1));
    const elements = new Set((body.missing || []).map((lot) => lot.element).filter(Boolean));
    const pab = (body.files?.pickabrick || []).flatMap((file) => file.split("\r\n").slice(1)).map((line) => line.split(","));
    check(`its Pick a Brick list: ${pab.length} lines, each a LEGO element number of a lot short (${elements.size} known), `
      + `${body.left_out?.pickabrick} lots with none left off`, pab.every(([element, n]) => elements.has(element) && Number(n) >= 1)
      && pab.length <= elements.size);
    findings.parts.push({ who: name, id, have: body.have, pieces: body.pieces, missing_lots: (body.missing || []).length,
      missing_parts: shortBy, wrong: wrong.length, bricklink_items: items.length, pickabrick_lines: pab.length,
      card: (pages[name].find((one) => one.id === id) || {}).owned || null });
  }
  const stranger = await api(`/api/share?op=parts_missing&id=${firstPage[1]}`);
  const nobody = await api("/api/share?op=parts_missing&id=NoSuchOne1", { token: who.bo.access_token });
  check(`signed out it is refused (${stranger.status}); a model that is not there is ${nobody.status}`,
    stranger.status === 401 && (nobody.status === 404 || nobody.status === 410));

  // --- 4. In a browser ----------------------------------------------------------
  const boModel = firstPage[1];
  for (const [width, height] of [[1280, 900], [390, 844]]) {
    for (const dark of [false, true]) {
      const theme = dark ? "dark" : "light";
      console.log(`Bo's gallery and Parts tab, ${width} px, ${theme}`);
      const made = await context({ as: who.bo, width, height, dark });
      const page = await made.newPage();
      listen(page, `Bo ${width} ${theme}`);
      const asks = [];
      page.on("request", (request) => { if (new URL(request.url()).pathname.startsWith("/api/")) asks.push(request.url()); });
      await page.goto(`${site}/gallery`, { waitUntil: "load" });
      await until(page, () => document.documentElement.dataset.gallery === "ready", `the gallery, ${width} px`);
      await page.waitForTimeout(1500);
      const cards = await page.evaluate(() => [...document.querySelectorAll("#models .model[data-id]")].map((card) => ({
        id: card.dataset.id, owned: card.dataset.owned || "", line: card.querySelector("small.owned")?.textContent || "" })));
      const expected = new Map(findings.cards.filter((one) => one.who === "bo").map((one) => [one.id, one.line]));
      const drawnWrong = cards.filter((card) => expected.has(card.id) && card.line !== expected.get(card.id));
      const perCard = asks.filter((url) => cards.some((card) => url.includes(card.id)));
      findings.requests[`${width}-${theme}`] = { api: asks.length, per_card: perCard.length, asks: asks.map((url) => new URL(url).search) };
      check(`${cards.length} cards drawn, ${drawnWrong.length} lines not as their numbers say; ${asks.length} API asks, `
        + `${perCard.length} of them for a card; nothing sideways`, cards.length >= 18 && drawnWrong.length === 0 && perCard.length === 0
        && !(await sideways(page)));
      if (dark === false || width === 390) await shot(page, `gallery-${width}-${theme}.png`);
      await page.goto(`${site}/m/${boModel}#parts`, { waitUntil: "load" });
      await page.locator("#parts").scrollIntoViewIfNeeded();
      await until(page, () => /\//.test(document.documentElement.dataset.missing || ""), "what Bo is missing");
      const before = await page.evaluate(() => ({ said: document.querySelector(".parts-have")?.textContent || "",
        shows: [...document.querySelectorAll(".parts-mine [data-show]")].map((b) => b.textContent.trim()) }));
      await page.click('.parts-mine [data-show="missing"]');
      await page.waitForTimeout(300);
      const after = await page.evaluate(() => ({
        lots: document.querySelectorAll(".lot-list li.lot").length,
        shown: document.querySelectorAll(".lot-list li.lot:not([hidden])").length,
        shops: [...document.querySelectorAll(".parts-shops.missing button:not([hidden])")].map((b) => b.textContent),
        whole: [...document.querySelectorAll(".parts-shops:not(.missing)")].every((one) => one.hidden) }));
      const body = missingOf[boModel];
      check(`"${before.said.slice(0, 90)}"; ${before.shows.join(" · ")}; Missing shows ${after.lots} lots (${body.missing.length} short), `
        + `${after.shops.join(", ")} in the whole model's place`, after.lots === body.missing.length && after.whole
        && after.shops.includes("BrickLink XML") && /You have [\d,]+ of its [\d,]+ parts/.test(before.said) && !(await sideways(page)));
      if (width === 1280 && !dark) {
        const [download] = await Promise.all([page.waitForEvent("download"), page.click('.parts-shops.missing [data-missing$="bricklink.xml"]')]);
        const file = path.join(out, download.suggestedFilename());
        await download.saveAs(file);
        check(`the missing BrickLink XML downloaded as ${download.suggestedFilename()}: the answer's own, byte for byte`,
          readFileSync(file, "utf8") === body.files.bricklink);
      }
      await shot(page, `parts-missing-${width}-${theme}.png`, "#parts");
      await made.close();
    }
  }

  // The set page: You own, In N lists, and the attacks.
  const list = await api("/api/people?op=collection", { method: "POST", token: who.cy.access_token,
    body: { name: `Ownedparts boats ${rand}`, public: true } });
  if (list.body?.id) {
    await api("/api/people?op=keep", { method: "POST", token: who.cy.access_token, body: { list: list.body.id, items: [`set:${CY_SET}`], on: true } });
  }
  const based = await api(`/api/share?op=set_based&set=${CY_SET}&tests=1`);
  const sqlThere = based.body.lists && based.body.lists.ready !== false;
  for (const [width, height] of [[1280, 900], [390, 844]]) {
    for (const dark of [false, true]) {
      const theme = dark ? "dark" : "light";
      console.log(`Cy's set page, ${width} px, ${theme}`);
      const made = await context({ as: who.cy, width, height, dark });
      const page = await made.newPage();
      listen(page, `Cy ${width} ${theme}`);
      await page.goto(`${site}/library/set/${CY_SET}?tests=1`, { waitUntil: "load" });
      await until(page, () => /\//.test(document.documentElement.dataset.owned || "")
        && !document.querySelector("[data-keep-count]")?.hidden, "Cy's You own");
      const drawn = await page.evaluate((listId) => ({ n: document.querySelector("[data-keep-count] input")?.value,
        times: document.querySelector(".keep-bar [data-keep-main] .n")?.textContent || "",
        lists: document.documentElement.dataset.lists || "", heading: document.getElementById("in-lists-h")?.textContent || "",
        cys: Boolean(listId && document.querySelector(`#in-lists a[href$="/c/${listId}"]`)) }), list.body?.id || "");
      check(`You own ${drawn.n}, Own ${drawn.times}; ${sqlThere ? `"${drawn.heading}", Cy's list among them: ${drawn.cys}` : "In N lists waits for supabase/owned_quantity.sql"}; `
        + "nothing sideways", drawn.n === "3" && drawn.times === "×3" && (!sqlThere || (/^In (1 list|\d+ lists)$/.test(drawn.heading) && drawn.cys))
        && !(await sideways(page)));
      await page.locator("#owned").scrollIntoViewIfNeeded();
      await shot(page, `set-owned-${width}-${theme}.png`, "#owned");
      if (sqlThere) await shot(page, `set-lists-${width}-${theme}.png`, "#in-lists");
      await made.close();
    }
  }

  console.log("the attacks on You own");
  const made = await context({ as: who.cy, width: 1280, height: 900 });
  const tab = await made.newPage();
  listen(tab, "Cy attacks");
  const sent = [];
  tab.on("request", (request) => {
    if (request.method() === "POST" && new URL(request.url()).pathname === "/api/collection") sent.push(request.postDataJSON());
  });
  await tab.goto(`${site}/library/set/${CY_SET}?tests=1`, { waitUntil: "load" });
  await until(tab, () => !document.querySelector("[data-keep-count]")?.hidden, "You own, for the attacks");
  const field = tab.locator("[data-keep-count] input");
  const ownedNow = async () => (await api(`/api/people?op=keeps&sets=${CY_SET}&models=`, { token: who.cy.access_token })).body.sets?.[CY_SET]?.own;
  // The toast's one region (web/toast.js), emptied before each try so
  // what it says after is that try's.
  const toastSaid = () => tab.evaluate(() => document.querySelector("body > .toast")?.textContent || "");
  const toastClear = () => tab.evaluate(() => document.querySelector("body > .toast")?.replaceChildren());
  for (const typedIn of ["100", "-1", "x", ""]) {
    await toastClear();
    await field.click();
    await field.press("Control+A");
    if (typedIn) await tab.keyboard.type(typedIn);
    else await tab.keyboard.press("Backspace");
    await field.press("Enter");
    await tab.waitForTimeout(600);
    const value = await field.inputValue();
    const words = await toastSaid();
    const server = await ownedNow();
    findings.attacks.push({ typed: typedIn, value, server, words: words.slice(0, 160) });
    check(`"${typedIn}" typed: refused in words ("${words.slice(-80)}"), the field back to ${value}, the account still ${server}`,
      value === "3" && server === 3 && /up to 99|from 1 to 99/.test(words));
  }
  sent.length = 0;
  await field.click();
  await field.press("Control+A");
  await tab.keyboard.type("4");
  await field.press("Enter");
  await tab.waitForTimeout(800);
  await field.press("Tab");
  await tab.waitForTimeout(1200);
  const owns = sent.filter((body) => body?.op === "own");
  check(`4 typed, Enter, then the field left: ${owns.length} change sent (${owns.map((one) => `${one.was}→${one.qty}`).join(", ")}), the account ${await ownedNow()}`,
    owns.length === 1 && (await ownedNow()) === 4);
  // Two tabs: the other makes it 6, this one presses + seeing 4.
  const other = await made.newPage();
  await other.goto(`${site}/library/set/${CY_SET}?tests=1`, { waitUntil: "load" });
  await until(other, () => !document.querySelector("[data-keep-count]")?.hidden, "the other tab's You own");
  const otherField = other.locator("[data-keep-count] input");
  await otherField.click();
  await otherField.press("Control+A");
  await other.keyboard.type("6");
  await otherField.press("Enter");
  await other.waitForTimeout(1200);
  await toastClear();
  await tab.click('[data-keep-count] [data-keep-step="1"]');
  await tab.waitForTimeout(1500);
  let words = await toastSaid();
  check(`two tabs: this one's + after the other made it 6 says "${words.slice(-90)}", and shows ${await field.inputValue()}; the account ${await ownedNow()}`,
    /another device: you own 6/.test(words) && (await field.inputValue()) === "6" && (await ownedNow()) === 6);
  // Taken out in the other tab while this page is open.
  await other.reload({ waitUntil: "load" });
  await until(other, () => document.querySelector(".keep-bar [data-keep-main]")?.getAttribute("aria-pressed") === "true", "the other tab, owned");
  await other.click(".keep-bar [data-keep-main]");
  await other.waitForTimeout(1500);
  await toastClear();
  await tab.click('[data-keep-count] [data-keep-step="1"]');
  await tab.waitForTimeout(1500);
  words = await toastSaid();
  const hidden = await tab.evaluate(() => document.querySelector("[data-keep-count]").hidden);
  check(`taken out in the other tab: + here says "${words.slice(-80)}", You own goes (${hidden}); the account ${await ownedNow()}`,
    /you own none now/.test(words) && hidden && !(await ownedNow()));
  // Owned again, then signed out in the other tab while this page is
  // open: this one hears it (web/account.js) and is drawn again signed
  // out, the count gone, and Own asks to sign in; nothing is changed.
  await own(who.cy, CY_SET, 2);
  await tab.reload({ waitUntil: "load" });
  await until(tab, () => !document.querySelector("[data-keep-count]")?.hidden, "You own, again");
  const reloaded = tab.waitForEvent("load", { timeout: 30000 }).catch(() => null);
  await other.evaluate((name) => localStorage.removeItem(name), STORAGE_KEY);
  await reloaded;
  await until(tab, () => document.readyState === "complete" && document.querySelector(".keep-bar [data-keep-main]"), "the page signed out");
  await tab.waitForTimeout(800);
  const out = await tab.evaluate(() => ({ count: document.querySelector("[data-keep-count]")?.hidden !== false,
    own: document.querySelector(".keep-bar [data-keep-main]")?.getAttribute("aria-pressed") }));
  await tab.click(".keep-bar [data-keep-main]");
  const asked = await tab.waitForSelector("dialog[open]", { timeout: 15000 }).then((d) => d.textContent()).catch(() => "");
  check(`signed out in the other tab mid-page: this one drawn again with no count (${out.count}), Own not pressed (${out.own}); `
    + `Own asks "${asked.replace(/\s+/g, " ").trim().slice(0, 70)}"; the account still ${await ownedNow()}`,
  out.count && out.own !== "true" && /Sign in/.test(asked) && (await ownedNow()) === 2);
  await made.close();
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close().catch(() => {});
  await client.end().catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
writeFileSync(path.join(out, "ownedparts_flow.json"), `${JSON.stringify({ passed, failed, findings }, null, 1)}\n`);
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED, ${passed} passed`
  : `ownedparts: every card's share, what is missing of three models, You own and its attacks (${passed} passed)`);
process.exit(failed ? 1 : 0);
