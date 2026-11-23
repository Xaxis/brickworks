// Building now (buildlive, 2026-11-23): a Build together session opened to
// watchers, proven end to end against a relay on this machine (api/together.js
// "Watching", web/live.js, web/live-now.js):
//
//   grep -E '^(SUPABASE_URL|SUPABASE_SECRET_KEY|SUPABASE_PUBLISHABLE_KEY|PARTS_URL)=' .env > $SCRATCH/flow.env
//   node --env-file=$SCRATCH/flow.env tools/web/relay_server.mjs 11800 --egress \
//     --hold=together_sessions,together_people,together_ops,together_snapshot_parts,together_watch,together_watchers
//   node --env-file=$SCRATCH/flow.env tools/web/live_flow.mjs --url=http://127.0.0.1:11800 --out=DIR [--watchers=10] [--parts=20]
//
// Three throwaway accounts: a designer (a profile, 13 or over), a watcher who
// chats and asks to build, and one under 13. The designer starts a session on a
// small model by the relay's own API, as the studio does, and opens it to
// watchers. Then:
//
//   1. listed: the show is in op=live (the home feed's and the profile's list)
//      within 10 s, and the home page and the designer's profile draw its card
//   2. watched: --watchers pages, signed out, each open /live/<watch> and hear
//      on the show's channel; --parts parts are put down one at a time, and each
//      page says when each part reached it and when it was drawn. The bar: a
//      part reaches every page within 1 s at p95
//   3. refused: a send by the show's name, a watcher's line that carries a
//      change, and a message on the channel not signed by the relay (a part
//      and a chat line forged): none changes what any page shows
//   4. chat and seats: the watcher's line reaches the pages; the under-13
//      account may not chat; the watcher asks, the designer gives a seat, the
//      watcher reads the link, joins and puts a part down as a builder
//   5. ended: the designer ends the session; every page says so, and op=live
//      lists it no more
//
// And what it cost the database: the bytes the relay read from Supabase for
// the watchers (--egress on the relay: /__egress, by op) and the bytes each
// page heard on the channel, per watcher-minute, with the parts' geometry a
// page fetched once as it opened said apart. Pictures of a watch page and of
// the listing at 1280 and 390, light and dark. Results in DIR/live_flow.json.
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "http://127.0.0.1:11800").replace(/\/+$/, "");
const out = path.resolve(String(args.out || "shots/live_flow"));
mkdirSync(out, { recursive: true });
const WATCHERS = Number(args.watchers || 10);
const PARTS = Number(args.parts || 20);
const rand = randomBytes(4).toString("hex");
const emails = { designer: `delivered+bw-live-d-${rand}@resend.dev`, watcher: `delivered+bw-live-w-${rand}@resend.dev`,
  child: `delivered+bw-live-c-${rand}@resend.dev` };
const HANDLE = `live-${rand}`;
const results = { checks: [], timings: {}, egress: {} };
let failed = 0;
const errors = [];
const wait = (ms) => new Promise((done) => setTimeout(done, ms));

function check(what, ok, detail = "") {
  results.checks.push({ what, ok: Boolean(ok), detail });
  if (!ok) failed += 1;
  console.log(`  ${ok ? "ok" : "FAIL"}  ${what}${detail ? ` (${detail})` : ""}`);
}

async function api(route, { method = "GET", token = "", body } = {}) {
  const headers = { accept: "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const reply = await fetch(`${site}${route}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let parsed = null;
  try { parsed = JSON.parse(text); } catch {}
  return { status: reply.status, body: parsed, text };
}

const quantile = (values, q) => {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.max(0, Math.ceil(q * sorted.length) - 1))];
};

async function until(test, what, seconds = 60, every = 100) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await test().catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`not within ${seconds} s: ${what}`);
    await wait(every);
  }
}

// A brick's state as the app sends it: [part, colour, 12 numbers, group, unit, step],
// in the app's space: LDraw's turned over (LdrModel.FLIP), so y is up.
const brick = (part, colour, x, y, z) => [part, colour, [1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z], "", "", 0];
const PALETTE = [4, 1, 14, 2, 15, 0, 25, 27];

const people = {};
const pages = [];
let studioStopped = false;
let pictureMs = 0;
// Each time the relay was asked the whole show (op=watching): a page opened, or this flow's own reads.
let opens = 0;
const loadNow = () => readFileSync("/proc/loadavg", "utf8").split(" ")[0];
let browser = null;
let token = "";
try {
  console.log("three throwaways: a designer, a watcher, and one under 13");
  people.designer = await mintSession(emails.designer);
  people.watcher = await mintSession(emails.watcher);
  people.child = await mintSession(emails.child, { age: false });
  await answerAge(people.child.kept.user_id, emails.child, false);
  const made = await api("/api/people?op=profile", { method: "POST", token: people.designer.access_token,
    body: { handle: HANDLE, name: "Live Designer" } });
  check(`the designer's profile @${HANDLE}`, made.status === 200, String(made.status));
  const watcherProfile = await api("/api/people?op=profile", { method: "POST", token: people.watcher.access_token,
    body: { handle: `watch-${rand}`, name: "Wren Watcher" } });
  check("the watcher's profile", watcherProfile.status === 200, String(watcherProfile.status));

  // --- the session, as the studio starts one, and opened to watchers ---------
  const start = [];
  for (let k = 0; k < 12; k++) start.push([`own00001.${k + 1}`, ...brick("3001", PALETTE[k % 8], (k % 4) * 80, 24 * Math.floor(k / 4), 0)]);
  const started = await api("/api/together?op=start", { method: "POST", token: people.designer.access_token,
    body: { title: `Live ${rand}`, snapshot: { text: "0 Live\r\n0 Name: live.ldr\r\n", lift: 0, bricks: start, meta: {} } } });
  check("the designer starts a session", started.status === 200, String(started.status));
  token = started.body?.s || "";
  const opened = await api("/api/together?op=watch_open", { method: "POST", token: people.designer.access_token, body: { s: token } });
  check("the designer opens it to watchers", opened.status === 200 && /^[A-Za-z0-9]{12}$/.test(String(opened.body?.watch)),
    `${opened.status} ${opened.text.slice(0, 120)}`);
  const w = opened.body.watch;
  const openedAt = Date.now();
  // The designer's studio polls all session long (Together._poll_loop), which
  // is how the listing knows they are still building (OWNER_HEARD_MS).
  (async () => {
    let after = 0;
    while (!studioStopped) {
      const got = await api("/api/together?op=poll", { method: "POST", token: people.designer.access_token,
        body: { s: token, after } }).catch(() => null);
      if (!got || got.status !== 200 || got.body?.ended) break;
      for (const op of got.body?.ops || []) after = Math.max(after, Number(op.seq) || 0);
      await wait(250);
    }
  })();
  const childOpen = await api("/api/together?op=watch_open", { method: "POST", token: people.child.access_token, body: { s: token } });
  check("somebody not its designer cannot open it", childOpen.status === 403, String(childOpen.status));

  // --- 1. listed -------------------------------------------------------------
  console.log("1. listed");
  const listed = await until(async () => {
    const got = await api("/api/together?op=live&tests=1");
    return (got.body?.live || []).find((one) => one.watch === w) || null;
  }, "the show in the listing", 30, 250);
  results.timings.listed_ms = Date.now() - openedAt;
  check("listed within 10 s", results.timings.listed_ms <= 10_000, `${results.timings.listed_ms} ms`);
  check("listed by its designer's name", listed.designer?.handle === HANDLE, JSON.stringify(listed.designer));
  const theirs = await api(`/api/together?op=live&tests=1&handle=${HANDLE}`);
  check("on the designer's own list", (theirs.body?.live || []).some((one) => one.watch === w));
  const others = await api(`/api/together?op=live&tests=1&handle=watch-${rand}`);
  check("on nobody else's", (others.body?.live || []).length === 0);
  const unlisted = await api("/api/together?op=live");
  check("a test account's build is kept out of the real listing", !(unlisted.body?.live || []).some((one) => one.watch === w));

  // --- 2. watched --------------------------------------------------------------
  console.log(`2. ${WATCHERS} watchers, ${PARTS} parts`);
  browser = await launch({ signedOut: true });
  for (let k = 0; k < WATCHERS; k++) {
    const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
    const page = await context.newPage();
    page.on("pageerror", (e) => errors.push(`watcher ${k}: ${String(e).slice(0, 200)}`));
    page.on("console", (m) => {
      if (/Content Security Policy|Refused to|Uncaught/.test(m.text())) errors.push(`watcher ${k}: ${m.text().slice(0, 200)}`);
    });
    // What it heard on the channel, in bytes (CDP).
    const cdp = await context.newCDPSession(page);
    await cdp.send("Network.enable");
    page.heardBytes = 0;
    page.fetchedBytes = { geometry: 0, api: 0 };
    // When each part reached this browser: its channel's frame, timed by the
    // browser's network side (CDP), which a page drawing in software on a
    // loaded box does not hold up as it holds up the page's own handler.
    page.arrived = {};
    page.wallOffset = null;
    cdp.on("Network.webSocketWillSendHandshakeRequest", (event) => {
      page.wallOffset = event.wallTime * 1000 - event.timestamp * 1000;
    });
    cdp.on("Network.webSocketFrameReceived", (event) => {
      const text = String(event.response?.payloadData || "");
      page.heardBytes += text.length;
      if (page.wallOffset === null || !text.includes('"show"')) return;
      try {
        const frame = JSON.parse(text);
        const said = JSON.parse(frame?.payload?.payload?.d || "null");
        for (const op of said?.ops || []) page.arrived[op.seq] ??= event.timestamp * 1000 + page.wallOffset;
      } catch {}
    });
    page.on("response", async (response) => {
      const url = response.url();
      const size = Number((await response.headerValue("content-length").catch(() => null)) || 0)
        || (await response.body().catch(() => Buffer.alloc(0))).length;
      if (/\.lbm(\?|$)/.test(url)) page.fetchedBytes.geometry += size;
      else if (url.includes("/api/together")) page.fetchedBytes.api += size;
    });
    page.openedAt = Date.now();
    opens += 1;
    await page.goto(`${site}/live/${w}?tests=1`, { waitUntil: "domcontentloaded", timeout: 120000 });
    pages.push(page);
  }
  for (const [k, page] of pages.entries()) {
    await until(() => page.evaluate(() => Boolean(window.brickworksLive?.ready && window.brickworksLive.channel === "joined"
      && window.brickworksLive.view)), `watcher ${k} hearing`, 300, 250);
  }
  const shown = await pages[0].evaluate(() => window.brickworksLive.bricks.size);
  // What a page opens on, kept for the docs' picture (docs-site/pictures/build-together.json).
  opens += 1;
  writeFileSync(path.join(out, "watching.json"), (await api(`/api/together?op=watching&w=${w}&tests=1`)).text);
  check("each page opens on the model as it stands", shown === start.length, `${shown} parts`);
  const watchedFrom = Date.now();
  const bytesFrom = pages.map((page) => page.heardBytes);
  const client = `live${rand}`;
  const sent = [];
  for (let k = 0; k < PARTS; k++) {
    const uid = `${client}.${k + 1}`;
    const at = Date.now();
    const got = await api("/api/together?op=send", { method: "POST", token: people.designer.access_token,
      body: { s: token, client, ops: [{ cid: k, changes: { [uid]: brick("3003", PALETTE[k % 8], (k % 5) * 40 + 40, 24 * Math.floor(k / 5), 60) } }] } });
    if (got.status !== 200) check(`part ${k + 1} sent`, false, `${got.status} ${got.text.slice(0, 120)}`);
    sent.push({ uid, at, seq: Number(got.body?.seqs?.[0]), back: Date.now() });
    await wait(Number(args.gap || 1200));
  }
  await wait(1500);
  const reach = [];
  const arrived = [];
  const drawn = [];
  const missed = [];
  for (const [k, page] of pages.entries()) {
    const live = await page.evaluate(() => ({ heard: window.brickworksLive.heard, drawn: window.brickworksLive.drawn,
      n: window.brickworksLive.bricks.size, verified: window.brickworksLive.verified }));
    for (const one of sent) {
      if (page.arrived[one.seq]) arrived.push(Math.round(page.arrived[one.seq] - one.at));
      const heard = live.heard[one.seq];
      if (!heard) { missed.push(`${k}:${one.seq}`); continue; }
      reach.push(heard.at - one.at);
      if (live.drawn[one.seq]) drawn.push(live.drawn[one.seq] - one.at);
      if (heard.via !== "told") missed.push(`${k}:${one.seq} read back`);
    }
  }
  results.timings.arrived_ms = { p50: quantile(arrived, 0.5), p95: quantile(arrived, 0.95), max: Math.max(...arrived), n: arrived.length };
  results.timings.reach_ms = { p50: quantile(reach, 0.5), p95: quantile(reach, 0.95), max: Math.max(...reach), n: reach.length };
  results.timings.drawn_ms = { p50: quantile(drawn, 0.5), p95: quantile(drawn, 0.95), max: Math.max(...drawn), n: drawn.length };
  results.timings.send_ms = { p50: quantile(sent.map((one) => one.back - one.at), 0.5), p95: quantile(sent.map((one) => one.back - one.at), 0.95) };
  check(`every part reached all ${WATCHERS} pages`, missed.length === 0, missed.slice(0, 6).join(", "));
  check(`a part reaches all ${WATCHERS} watchers' browsers within 1 s at p95`, arrived.length === sent.length * WATCHERS
    && results.timings.arrived_ms.p95 <= 1000,
    `from the send asked to its frame on each page's channel: p50 ${results.timings.arrived_ms.p50} ms, p95 ${results.timings.arrived_ms.p95} ms over ${arrived.length}`);
  // The pages' own handling, on this box: ten pages drawing in software on
  // shared cores, said and kept, judged by the line above.
  console.log(`  --    each page took it (verified, in its model) p50 ${results.timings.reach_ms.p50} ms, p95 ${results.timings.reach_ms.p95} ms;`
    + ` drew it p50 ${results.timings.drawn_ms.p50} ms, p95 ${results.timings.drawn_ms.p95} ms (load ${loadNow()})`);
  const minutes = (Date.now() - watchedFrom) / 60000;
  results.egress.heard_per_watcher_minute_while_built = Math.round(pages.reduce((sum, page, k) => sum + page.heardBytes - bytesFrom[k], 0) / WATCHERS / minutes);
  results.egress.geometry_per_watcher_open = Math.round(pages.reduce((sum, page) => sum + page.fetchedBytes.geometry, 0) / WATCHERS);
  results.egress.api_per_watcher = Math.round(pages.reduce((sum, page) => sum + page.fetchedBytes.api, 0) / WATCHERS);
  results.timings.load = loadNow();


  // --- 3. refused ---------------------------------------------------------------
  console.log("3. what a watcher sends is refused");
  const countBefore = await pages[1].evaluate(() => window.brickworksLive.bricks.size);
  const byName = await api("/api/together?op=send", { method: "POST", token: people.watcher.access_token,
    body: { w, client: "watcher01", ops: [{ cid: 0, changes: { "evil0001.1": brick("3001", 4, 0, -400, 0) } }] } });
  check("a send by the show's name is refused at the relay", byName.status === 403, `${byName.status} ${byName.body?.error || ""}`);
  const asSecret = await api("/api/together?op=send", { method: "POST", token: people.watcher.access_token,
    body: { s: `${w}${w}${w.slice(0, 8)}`, client: "watcher01", ops: [{ cid: 0, changes: { "evil0001.1": brick("3001", 4, 0, -400, 0) } }] } });
  check("the show's name is no session's secret", asSecret.status === 404, String(asSecret.status));
  const lineWithPart = await api("/api/together?op=watch_say", { method: "POST", token: people.watcher.access_token,
    body: { w, text: "hello", changes: { "evil0001.2": brick("3001", 4, 0, -400, 0) } } });
  check("a watcher's line carrying a change is refused", lineWithPart.status === 403, String(lineWithPart.status));
  const joinByName = await api("/api/together?op=join", { method: "POST", token: people.watcher.access_token, body: { s: w } });
  check("nobody joins by the show's name", joinByName.status === 404, String(joinByName.status));
  // A message on the channel, not the relay's: anybody may say anything there.
  const forged = await (async () => {
    opens += 1;
    const show = (await api(`/api/together?op=watching&w=${w}&tests=1`)).body;
    const d = JSON.stringify({ w, from: show.seq + 1, to: show.seq + 1, ops: [{ seq: show.seq + 1, who: "00000000",
      changes: { "evil0001.3": ["3001", 4, [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -400, 0]], "~chat": "forged line", "~by": "Mallory" } }],
    meshes: {}, colours: {}, names: {}, at: Date.now() });
    const key = process.env.SUPABASE_PUBLISHABLE_KEY;
    const sentOn = await fetch(`${String(process.env.SUPABASE_URL).replace(/\/+$/, "")}/realtime/v1/api/broadcast`, {
      method: "POST", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ messages: [{ topic: show.channel.topic, event: "show", payload: { d, sig: "A".repeat(86) }, private: false }] }),
    });
    return sentOn.status;
  })();
  await wait(2500);
  const after = await Promise.all(pages.map((page) => page.evaluate(() => ({ n: window.brickworksLive.bricks.size,
    evil: [...window.brickworksLive.bricks.keys()].filter((uid) => uid.startsWith("evil")).length, dropped: window.brickworksLive.dropped,
    forged: [...document.querySelectorAll("#live-chat li")].some((li) => li.textContent.includes("forged line")) }))));
  check(`a forged message (sent with the page's own key: ${forged}) changes nothing on any page`,
    after.every((one) => one.evil === 0 && !one.forged && one.n === countBefore), JSON.stringify(after[1]));
  check("and each page dropped it", forged !== 202 || after.every((one) => one.dropped >= 1), after.map((one) => one.dropped).join(","));

  // --- 4. chat and a seat ---------------------------------------------------
  console.log("4. chat, an ask and a seat");
  const saidAt = Date.now();
  const said = await api("/api/together?op=watch_say", { method: "POST", token: people.watcher.access_token, body: { w, text: "Nice wheels!" } });
  check("a watcher chats", said.status === 200, `${said.status} ${said.text.slice(0, 120)}`);
  await until(() => pages[2].evaluate(() => [...document.querySelectorAll("#live-chat li")].some((li) => li.textContent.includes("Nice wheels!"))),
    "the line on another page", 10, 50);
  results.timings.chat_ms = Date.now() - saidAt;
  check("the line reaches the other pages", true, `${results.timings.chat_ms} ms`);
  const child = await api("/api/together?op=watch_say", { method: "POST", token: people.child.access_token, body: { w, text: "hi" } });
  check("an account under 13 may not chat", child.status === 422, `${child.status} ${child.body?.error || ""}`);
  const polled = await api("/api/together?op=poll", { method: "POST", token: people.designer.access_token, body: { s: token, after: 0 } });
  const heardByStudio = (polled.body?.ops || []).find((op) => op.changes?.["~chat"] === "Nice wheels!");
  check("the designer's studio hears the line with its name", heardByStudio?.changes?.["~by"] === "Wren Watcher",
    JSON.stringify(heardByStudio?.changes || null));
  const ask = await api("/api/together?op=watch_ask", { method: "POST", token: people.watcher.access_token, body: { w } });
  check("the watcher asks to build", ask.status === 200 && ask.body?.who, ask.text.slice(0, 120));
  const again = await api("/api/together?op=watch_ask", { method: "POST", token: people.watcher.access_token, body: { w } });
  check("and is told they asked already", again.status === 429, String(again.status));
  const before = await api("/api/together?op=watch_seat", { method: "POST", token: people.watcher.access_token, body: { w } });
  check("no link before a seat is given", before.status === 200 && before.body?.seated === false && !before.body?.link);
  const notOwner = await api("/api/together?op=seat", { method: "POST", token: people.watcher.access_token, body: { s: token, who: ask.body.who } });
  check("only the designer gives a seat", notOwner.status === 403, String(notOwner.status));
  const seat = await api("/api/together?op=seat", { method: "POST", token: people.designer.access_token, body: { s: token, who: ask.body.who } });
  check("the designer gives a seat", seat.status === 200, `${seat.status} ${seat.text.slice(0, 120)}`);
  const link = await api("/api/together?op=watch_seat", { method: "POST", token: people.watcher.access_token, body: { w } });
  const secret = /together=([A-Za-z0-9_-]{32})/.exec(String(link.body?.link || ""))?.[1] || "";
  check("the watcher is told the session's link", secret === token, link.text.slice(0, 80).replace(/together=[^"]+/, "together=…"));
  const childSeat = await api("/api/together?op=watch_seat", { method: "POST", token: people.child.access_token, body: { w } });
  check("nobody else is", !childSeat.body?.link, childSeat.text.slice(0, 80));
  const joined = await api("/api/together?op=join", { method: "POST", token: people.watcher.access_token, body: { s: secret } });
  check("and joins as a builder", joined.status === 200, String(joined.status));
  const theirPart = await api("/api/together?op=send", { method: "POST", token: people.watcher.access_token,
    body: { s: secret, client: "wren0001", ops: [{ cid: 0, changes: { "wren0001.1": brick("3001", 14, 0, 72, 0) } }] } });
  check("whose part goes down", theirPart.status === 200, String(theirPart.status));
  await until(() => pages[3].evaluate(() => window.brickworksLive.bricks.has("wren0001.1")), "their part on a page", 10, 100);
  check("and reaches the watchers", true);

  // --- pictures ------------------------------------------------------------------
  console.log("pictures");
  for (const [width, dark] of [[1280, false], [390, false], [1280, true], [390, true]]) {
    const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 860 }, colorScheme: dark ? "dark" : "light",
      ...(width < 600 ? { isMobile: true, hasTouch: true, deviceScaleFactor: 2 } : {}) });
    const page = await context.newPage();
    const pictureFrom = Date.now();
    opens += 1;
    await page.goto(`${site}/live/${w}?tests=1`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await until(() => page.evaluate(() => Boolean(window.brickworksLive?.ready && window.brickworksLive.view
      && window.brickworksLive.bricks.size > 0)), "the watch page", 120, 250).catch(() => null);
    await page.waitForTimeout(4000);
    await page.screenshot({ path: path.join(out, `watch-${width}${dark ? "-dark" : ""}.png`), timeout: 90000 });
    pictureMs += Date.now() - pictureFrom;
    await page.goto(`${site}/index.html?tests=1`, { waitUntil: "domcontentloaded", timeout: 120000 });
    await until(() => page.evaluate(() => document.querySelector("[data-live-now]")?.dataset.liveCount > 0), "the listing on the home", 30, 250)
      .then(() => check(`the home lists it first at ${width}${dark ? " dark" : ""}`, true))
      .catch(() => check(`the home lists it first at ${width}${dark ? " dark" : ""}`, false));
    await page.evaluate(() => document.querySelector("[data-live-now]")?.scrollIntoView({ block: "start" }));
    await page.waitForTimeout(1200);
    await page.screenshot({ path: path.join(out, `home-${width}${dark ? "-dark" : ""}.png`), timeout: 90000 });
    if (!dark) {
      await page.goto(`${site}/u/${HANDLE}?tests=1`, { waitUntil: "domcontentloaded", timeout: 120000 });
      await until(() => page.evaluate(() => document.querySelector("[data-live-now]")?.dataset.liveCount > 0), "the listing on the profile", 30, 250)
        .then(() => check(`the profile lists it at ${width}`, true)).catch(() => check(`the profile lists it at ${width}`, false));
      await page.waitForTimeout(800);
      await page.screenshot({ path: path.join(out, `profile-${width}.png`), timeout: 90000 });
    }
    await context.close();
  }

  // --- 5. ended -------------------------------------------------------------------
  console.log("5. ended");
  const ended = await api("/api/together?op=end", { method: "POST", token: people.designer.access_token, body: { s: token } });
  check("the designer ends it, and is told it was watched", ended.status === 200 && ended.body?.watched?.watch === w,
    JSON.stringify(ended.body));
  for (const [k, page] of pages.entries()) {
    await until(() => page.evaluate(() => window.brickworksLive.ended), `watcher ${k} told it ended`, 15, 100)
      .catch(() => check(`watcher ${k} told it ended`, false));
  }
  const closedAt = Date.now();
  results.egress.watch_minutes = Math.round(pages.reduce((sum, page) => sum + (closedAt - page.openedAt), 0) / 60000 * 100) / 100
    + Math.round(pictureMs / 60000 * 100) / 100;
  results.egress.heard_per_watcher_minute = Math.round(pages.reduce((sum, page) => sum + page.heardBytes, 0)
    / (pages.reduce((sum, page) => sum + (closedAt - page.openedAt), 0) / 60000));
  check("every page says it ended", true);
  const gone = await api("/api/together?op=live&tests=1");
  check("and it is listed no more", !(gone.body?.live || []).some((one) => one.watch === w));
  await pages[0].screenshot({ path: path.join(out, "watch-ended-1280.png"), timeout: 90000 });

  // --- what it cost the database --------------------------------------------------
  const egress = await api("/__egress");
  if (egress.status === 200) {
    results.egress.relay = egress.body;
    const reads = ["watching", "watch_ops", "live"].reduce((sum, op) => sum + (egress.body?.[op]?.bytes || 0), 0);
    // A page's heartbeat and read-backs, over all the minutes every page was open.
    results.egress.relay_read_per_watcher_minute = Math.round(((egress.body?.watch_ops?.bytes || 0)) / Math.max(results.egress.watch_minutes, 0.01));
    // Opening a page, each: the model as it stands.
    results.egress.relay_read_per_open = Math.round((egress.body?.watching?.bytes || 0) / Math.max(1, opens));
    results.egress.relay_read_watchers_total = reads;
  }
  check("no page error", errors.length === 0, errors.slice(0, 4).join(" | "));
} catch (trouble) {
  check(`the flow ran to its end: ${String(trouble?.message || trouble).slice(0, 240)}`, false);
  // What each page had come to, to say why.
  for (const [k, page] of pages.entries()) {
    const had = await page.evaluate(() => {
      const live = window.brickworksLive || {};
      return { ready: live.ready, channel: live.channel, view: Boolean(live.view), parts: live.bricks?.size, seq: live.seq,
        said: document.getElementById("live-said")?.textContent || "", errors: (live.errors || []).slice(0, 3) };
    }).catch((why) => ({ unread: String(why).slice(0, 120) }));
    console.log(`  --    page ${k}: ${JSON.stringify(had)} (load ${loadNow()})`);
    if (k === 0) await page.screenshot({ path: path.join(out, "stuck-page0.png"), timeout: 60000 }).catch(() => null);
  }
  if (errors.length) console.log(`  --    page errors: ${errors.slice(0, 4).join(" | ")}`);
} finally {
  studioStopped = true;
  if (browser) await browser.close().catch(() => {});
  if (token && people.designer) {
    await api("/api/together?op=end", { method: "POST", token: people.designer.access_token, body: { s: token } }).catch(() => null);
  }
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => null);
  results.failed = failed;
  results.errors = errors;
  writeFileSync(path.join(out, "live_flow.json"), JSON.stringify(results, null, 2));
  console.log(JSON.stringify({ timings: results.timings, egress: { ...results.egress, relay: undefined } }));
  console.log(failed ? `live_flow: ${failed} FAILED` : `live_flow: all ${results.checks.length} passed`);
  process.exit(failed ? 1 : 0);
}
