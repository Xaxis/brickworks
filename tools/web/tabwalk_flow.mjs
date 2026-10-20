// Two real Claude chats, each building in its own Brickworks tab, at once.
//
//   node --env-file=.env tools/web/relay_server.mjs 8920 --static=build/web &
//   node --env-file=.env tools/web/tabwalk_flow.mjs --url=http://127.0.0.1:8920/app \
//     --out=bench/results/tabwalk-<date> [--scratch=DIR]
//
// tabpair_flow.mjs proves the relay's rules with scripted chats; this is
// what a person does, with Claude Code sessions on the subscription doing
// the building (`claude -p`, seeing Brickworks' tools and nothing else).
// Local only: each run spends the subscription's quota for about half an
// hour, so it is not wired into a release's checks (preview_checks.sh says so).
//
// One browser, one throwaway account, Claude Code signed in to it:
//
//   0. Tab A: Brickworks opened, File > New for an empty model. Tab B:
//      File > New tab in A. Each tab's Account, New chat for this tab: the
//      first message that names it, as claude.ai would be handed it.
//   1. Chat 1 is sent tab A's message and "Build a small house"; chat 2,
//      tab B's and "Build a small car", at the same time.
//   2. Each is asked to change one small thing, at the same time,
//   3. then to undo that: each model is back as it was built.
//   4. A third chat, told no tab, is asked to add a tree; then the person
//      says which (the house).
//
// Each chat's transcript (stream-json) beside pictures of both tabs at each
// stage, and what each tab said of the chats in it (brickworksClaude), in
// --out. The checks: every answer a chat got names its own tab; neither
// model changed while the other chat worked; each undo leaves its model as
// built; each tab names the chat working in it; and the third chat changes
// nothing before the person says which tab.
import { launch, withAssistant } from "./browser.mjs";
import { mintSession, STORAGE_KEY } from "./session.mjs";
import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { createWriteStream, mkdirSync, writeFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = withAssistant(String(args.url || "http://127.0.0.1:8920/app"));
const out = resolve(String(args.out || "shots/tabwalk"));
const scratch = resolve(String(args.scratch || `${out}/scratch`));
// A turn of a chat that builds: Claude takes its time.
const TURN_MS = Number(args["turn-minutes"] || 25) * 60 * 1000;
mkdirSync(out, { recursive: true });
mkdirSync(scratch, { recursive: true });

let failed = 0;
function check(what, ok) {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
}
const wait = (ms) => new Promise((done) => setTimeout(done, ms));
const origin = new URL(url).origin;
const USER = "/userfs/godot/app_userdata/Brickworks";
const SECOND_ROW = { dx: 30, dy: 50 };

const EMAIL = `delivered+bwtabwalk${randomBytes(3).toString("hex")}@resend.dev`;
const minted = await mintSession(EMAIL);
const browser = await launch({ signedOut: true });
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
await context.addInitScript(([name, value]) => {
  try {
    if (!localStorage.getItem(name)) localStorage.setItem(name, value);
  } catch {}
}, [STORAGE_KEY, JSON.stringify(minted.kept)]);
const problems = [];
// New chat for this tab opens claude.ai: kept, and answered here.
const popups = [];
await context.route(/^https:\/\/claude\.ai\//, (route) => {
  popups.push(route.request().url());
  return route.fulfill({ status: 200, contentType: "text/html", body: "<title>claude.ai</title>" });
});
context.on("page", (page) => {
  setTimeout(() => {
    if (/claude\.ai/.test(page.url())) page.close().catch(() => {});
  }, 4000);
});

// Claude Code signed in to the account, as `claude mcp login brickworks`
// leaves it: its own client document and a loopback return address.
async function claudeCodeToken() {
  const client = "https://claude.ai/oauth/claude-code-client-metadata";
  const back = "http://127.0.0.1:47321/callback";
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const yes = await (await fetch(`${origin}/api/oauth?op=approve`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${minted.access_token}` },
    body: JSON.stringify({ response_type: "code", client_id: client, redirect_uri: back,
      code_challenge: challenge, code_challenge_method: "S256", state: "tabwalk",
      resource: `${origin}/api/mcp` }),
  })).json();
  const code = new URL(String(yes.redirect || "x:")).searchParams.get("code");
  if (!code) throw new Error(`no code: ${JSON.stringify(yes)}`);
  const tokens = await (await fetch(`${origin}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: back,
      client_id: client, code_verifier: verifier, resource: `${origin}/api/mcp` }).toString(),
  })).json();
  return tokens.access_token || "";
}

// A Claude Code session on the subscription, Brickworks its only tools,
// kept running between turns as one chat is.
function chat(name, mcpConfig) {
  const env = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (!/^(ANTHROPIC_|SUPABASE_|RESEND_|VERCEL_|BW_)|SECRET|_KEY$|_TOKEN$/.test(k)) env[k] = v;
  }
  Object.assign(env, { MCP_TOOL_TIMEOUT: "600000", MCP_TIMEOUT: "120000" });
  const child = spawn("claude", ["-p", "--input-format", "stream-json", "--output-format", "stream-json",
    "--verbose", "--mcp-config", mcpConfig, "--strict-mcp-config", "--tools", "", "--restricted",
    "--allowedTools", "mcp__brickworks"], { cwd: scratch, env, stdio: ["pipe", "pipe", "pipe"] });
  const transcript = createWriteStream(`${out}/${name}.jsonl`);
  child.stderr.pipe(createWriteStream(`${out}/${name}.stderr`));
  const events = [];
  let waiting = null;
  createInterface({ input: child.stdout }).on("line", (line) => {
    transcript.write(`${line}\n`);
    let event = null;
    try { event = JSON.parse(line); } catch { return; }
    events.push(event);
    if (event.type === "result" && waiting) {
      const done = waiting;
      waiting = null;
      done(event);
    }
  });
  child.on("exit", () => {
    if (waiting) waiting({ type: "result", subtype: "exited", result: "" });
  });
  return {
    name,
    events,
    // One message from the person; its answer once Claude has finished.
    async say(words) {
      const from = events.length;
      const finished = new Promise((done) => { waiting = done; });
      child.stdin.write(`${JSON.stringify({ type: "user", message: { role: "user", content: words } })}\n`);
      const result = await Promise.race([finished, wait(TURN_MS).then(() => ({ type: "result", subtype: "timeout" }))]);
      return { result, events: events.slice(from) };
    },
    end() {
      child.stdin.end();
      return new Promise((done) => {
        child.on("exit", done);
        setTimeout(() => { child.kill(); done(); }, 30000);
      });
    },
  };
}

// What a turn did: each Brickworks call, and the first line of its answer.
function callsOf(turn) {
  const asked = new Map();
  const calls = [];
  for (const event of turn.events) {
    const blocks = Array.isArray(event.message?.content) ? event.message.content : [];
    for (const block of blocks) {
      if (block.type === "tool_use") asked.set(block.id, block);
      if (block.type === "tool_result") {
        const use = asked.get(block.tool_use_id) || {};
        const content = Array.isArray(block.content) ? block.content : [{ type: "text", text: String(block.content || "") }];
        const words = content.filter((b) => b.type === "text").map((b) => b.text).join("\n");
        calls.push({ tool: String(use.name || "").replace(/^mcp__brickworks__/, ""), input: use.input || {},
          words, error: Boolean(block.is_error) });
      }
    }
  }
  return calls;
}
function said(turn) {
  return String(turn.result?.result || "").replace(/\s+/g, " ").trim();
}

async function state(page) {
  return page.evaluate(() => window.brickworksState || {});
}
async function claude(page) {
  return page.evaluate(() => window.brickworksClaude || {});
}
async function controlAt(page, name, seconds = 400) {
  for (let n = 0; n < seconds * 2; n++) {
    const where = await page.evaluate((c) => (window.brickworksControls || {})[c], name);
    if (where) return where;
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/missing_${name}.png` }).catch(() => {});
  throw new Error(`the app never showed its ${name} control`);
}
async function press(page, name) {
  const at = await controlAt(page, name, 60);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(600);
}
async function until(test, seconds) {
  for (let n = 0; n < seconds * 2; n++) {
    if (await test()) return true;
    await wait(500);
  }
  return false;
}
async function settle(page) {
  await controlAt(page, "model_name");
  for (let n = 0; n < 120; n++) {
    const s = await state(page);
    if (s.bricks !== undefined && !s.awaited) break;
    await page.waitForTimeout(500);
  }
  await page.waitForTimeout(3000);
}
async function accountOpen(page) {
  if (!(await page.evaluate(() => Boolean((window.brickworksControls || {}).account_done)))) {
    await press(page, "account");
  }
  return until(async () => Boolean(await page.evaluate(() => (window.brickworksControls || {}).account_done)), 20);
}
async function accountShut(page) {
  const open = () => page.evaluate(() => Boolean((window.brickworksControls || {}).account_done));
  for (let n = 0; n < 3 && await open(); n++) {
    await page.mouse.move(5, 790);
    await page.waitForTimeout(800);
    await press(page, "account_done");
    await until(async () => !(await open()), 5);
  }
  if (await open()) await page.keyboard.press("Escape");
}
// The model as the tab keeps it in the browser: its part lines, sorted.
async function partsOf(page, id) {
  const text = await page.evaluate((path) => new Promise((done) => {
    const req = indexedDB.open("/userfs");
    req.onerror = () => done("");
    req.onsuccess = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains("FILE_DATA")) { db.close(); done(""); return; }
      const get = db.transaction("FILE_DATA", "readonly").objectStore("FILE_DATA").get(path);
      get.onsuccess = () => {
        db.close();
        const v = get.result;
        done(v && v.contents ? new TextDecoder().decode(v.contents) : "");
      };
      get.onerror = () => { db.close(); done(""); };
    };
  }), `${USER}/sessions/${id}/autosave.ldr`);
  // Parts alone: a saved model is kept with its sub-models, and the lines
  // naming them come and go with the save, not with the parts.
  return text.split(/\r?\n/).filter((line) => /^1 .*\.dat\s*$/i.test(line)).map((line) => line.trim())
    .sort().join("\n");
}
// The parts once the tab has kept what it shows: the count it shows held
// still, then what it stored, read until two reads 4 s apart agree. Read
// once, the stored model was a minifigure short, which is how a reload
// losing it was found (CommandSocket.model_changed).
async function settledParts(tab) {
  let last = -1;
  for (let n = 0; n < 40; n++) {
    const now = (await state(tab.page)).bricks;
    if (now === last) break;
    last = now;
    await wait(3000);
  }
  let parts = await partsOf(tab.page, tab.id);
  for (let n = 0; n < 10; n++) {
    await wait(4000);
    const again = await partsOf(tab.page, tab.id);
    if (again === parts) break;
    parts = again;
  }
  return { bricks: last, parts, count: parts ? parts.split("\n").length : 0 };
}

const log = [];
// Both tabs, as the person sees them, and what each says of its chats.
async function stage(name, { account = false } = {}) {
  const row = { stage: name, at: new Date().toISOString(), tabs: {} };
  for (const tab of TABS) {
    const kept = await settledParts(tab);
    await tab.page.mouse.move(640, 500);
    await wait(800);
    await tab.page.screenshot({ path: `${out}/${name}_${tab.label}.png` });
    if (account) {
      await accountOpen(tab.page);
      await wait(1500);
      await tab.page.mouse.move(640, 790);
      await wait(800);
      await tab.page.screenshot({ path: `${out}/${name}_${tab.label}_account.png` });
    }
    const c = await claude(tab.page);
    if (account) await accountShut(tab.page);
    row.tabs[tab.label] = { id: tab.id, badge: c.badge, chats: c.chats, account_says: c.account_says,
      bricks: kept.bricks, parts: kept.count };
    tab.kept = kept;
    writeFileSync(`${out}/${name}_${tab.label}.parts`, `${kept.parts}\n`);
  }
  log.push(row);
  writeFileSync(`${out}/stages.json`, JSON.stringify(log, null, 2));
  console.log(`  [${name}] ${TABS.map((t) => `${t.label} ${t.id}: ${row.tabs[t.label].parts} parts, "${row.tabs[t.label].badge}"`).join("; ")}`);
  return row;
}

// Steps 1 to 4: the chats.
async function walk(mcpConfig) {
  console.log("\n1. chat 1 builds a house in A, chat 2 a car in B, at once");
  const one = chat("chat1_house", mcpConfig);
  const two = chat("chat2_car", mcpConfig);
  chats.push(one, two);
  const [house, car] = await Promise.all([
    one.say(`${A.message} Build a small house.`),
    two.say(`${B.message} Build a small car.`),
  ]);
  const built = await stage("1_built", { account: true });
  // Every answer from a tab begins by naming it (api/mcp.js header()).
  function judge(turn, mine, theirs, who) {
    const calls = callsOf(turn);
    const fromTabs = calls.filter((c) => /^Tab [a-z2-9]+,/.test(c.words));
    const wrong = fromTabs.filter((c) => !c.words.startsWith(`Tab ${mine.id},`));
    const changes = calls.filter((c) => /edit_model|build|add|place|undo|redo|remove|clear|recolor|move/.test(c.tool));
    check(`${who}: ${calls.length} calls, ${fromTabs.length} answered by a tab, every one ${mine.id}`
      + `${wrong.length ? `; ${wrong.length} from elsewhere: ${wrong[0].words.slice(0, 80)}` : ""}`,
      turn.result.subtype === "success" && fromTabs.length > 0 && wrong.length === 0
        && !calls.some((c) => c.words.startsWith(`Tab ${theirs.id},`)));
    console.log(`        said: ${said(turn).slice(0, 220)}`);
    return { calls, changes };
  }
  judge(house, A, B, "chat 1 (house)");
  judge(car, B, A, "chat 2 (car)");
  check(`A has a model (${A.kept.count} parts) and B has one (${B.kept.count} parts)`, A.kept.count > 0 && B.kept.count > 0);
  for (const [tab, chatName] of [[A, "house"], [B, "car"]]) {
    const t = built.tabs[tab.label];
    check(`${tab.label} says one chat works in it: "${t.badge}" / "${String(t.account_says || "").split("\n").slice(0, 2).join(" ")}"`,
      t.badge === `Claude working · tab ${tab.id}` && (t.chats || []).length === 1);
    tab[`${chatName}Parts`] = tab.kept.parts;
  }
  check(`the two tabs name different chats: ${(built.tabs.A.chats || [])[0]?.chat} and ${(built.tabs.B.chats || [])[0]?.chat}`,
    (built.tabs.A.chats || [])[0]?.chat && (built.tabs.A.chats || [])[0]?.chat !== (built.tabs.B.chats || [])[0]?.chat);
  const builtA = A.kept.parts;
  const builtB = B.kept.parts;

  console.log("\n2. each changes one thing, at once");
  const ASK_CHANGE = "Now change one small thing about it, your choice, and tell me what you changed.";
  const [houseChange, carChange] = await Promise.all([one.say(ASK_CHANGE), two.say(ASK_CHANGE)]);
  await stage("2_changed");
  judge(houseChange, A, B, "chat 1's change");
  judge(carChange, B, A, "chat 2's change");
  check(`both models changed: A ${A.kept.parts !== builtA}, B ${B.kept.parts !== builtB}`,
    A.kept.parts !== builtA && B.kept.parts !== builtB);

  console.log("\n3. each undoes its change, at once");
  const [houseUndo, carUndo] = await Promise.all([one.say("Undo that change."), two.say("Undo that change.")]);
  await stage("3_undone");
  judge(houseUndo, A, B, "chat 1's undo");
  judge(carUndo, B, A, "chat 2's undo");
  check(`A is the house as built again (${A.kept.count} parts)`, A.kept.parts === builtA);
  check(`B is the car as built again (${B.kept.count} parts)`, B.kept.parts === builtB);

  console.log("\n4. a third chat, no tab named, asked for a tree");
  const three = chat("chat3_tree", mcpConfig);
  chats.push(three);
  const before = { A: A.kept.parts, B: B.kept.parts };
  const tree = await three.say("Add a tree to my Brickworks model.");
  await stage("4_asked");
  const treeCalls = callsOf(tree);
  for (const c of treeCalls) console.log(`        ${c.tool} ${JSON.stringify(c.input).slice(0, 80)} -> ${c.words.split("\n")[0].slice(0, 120)}`);
  console.log(`        said: ${said(tree).slice(0, 300)}`);
  check("chat 3 changed neither model before the person said which tab",
    A.kept.parts === before.A && B.kept.parts === before.B);
  check("chat 3 asked the person which tab", /\?/.test(said(tree)) && /tab|house|car/i.test(said(tree)));
  const answered = await three.say("The house tab.");
  await stage("5_tree", { account: true });
  const answeredCalls = callsOf(answered);
  for (const c of answeredCalls) console.log(`        ${c.tool} ${JSON.stringify(c.input).slice(0, 80)} -> ${c.words.split("\n")[0].slice(0, 160)}`);
  console.log(`        said: ${said(answered).slice(0, 300)}`);
  check(`the tree went into A (${A.kept.count} parts, was ${before.A.split("\n").length}), B unchanged`,
    A.kept.parts !== before.A && B.kept.parts === before.B);
  const last = log[log.length - 1].tabs;
  check(`A says two chats work in it: "${last.A.badge}"`, last.A.badge === `2 Claude chats · tab ${A.id}`);
  check(`B still says one: "${last.B.badge}"`, last.B.badge === `Claude working · tab ${B.id}`);

  console.log("\n5. both tabs reloaded: what the chats built is kept");
  for (const tab of TABS) {
    const shown = last[tab.label].bricks;
    await tab.page.reload({ waitUntil: "domcontentloaded", timeout: 180000 });
    await settle(tab.page);
    const back = (await state(tab.page)).bricks;
    check(`${tab.label} reloaded has ${back} parts, as it showed (${shown})`, back === shown);
  }
}

const TABS = [{ label: "A" }, { label: "B" }];
const [A, B] = TABS;
const chats = [];
try {
  // Claude Code signed in first, as for a person who has used it: every
  // tab opened after listens by itself.
  const token = await claudeCodeToken();
  check("Claude Code signs in to the account", token.startsWith("bwa_"));
  const mcpConfig = `${scratch}/mcp.json`;
  writeFileSync(mcpConfig, JSON.stringify({ mcpServers: { brickworks: {
    type: "http", url: `${origin}/api/mcp`, headers: { Authorization: `Bearer ${token}` } } } }));

  console.log("\n0. two tabs: A opened and emptied, B by File > New tab");
  A.page = await context.newPage();
  A.page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  await A.page.goto(url, { waitUntil: "domcontentloaded", timeout: 180000 });
  await settle(A.page);
  // File > New, by its key, on the canvas.
  const name = await controlAt(A.page, "model_name");
  await A.page.mouse.click(name.x, name.y);
  await A.page.keyboard.press("Escape");
  await A.page.keyboard.press("Control+n");
  await A.page.waitForTimeout(2000);
  if ((await state(A.page)).bricks > 0) {
    // "Not saved as it is now": the dialog's OK.
    await A.page.keyboard.press("Enter");
  }
  check(`A: File > New leaves an empty model (${(await state(A.page)).bricks} parts)`,
    await until(async () => (await state(A.page)).bricks === 0, 30));
  const file = await controlAt(A.page, "menu_file");
  await A.page.mouse.click(file.x, file.y);
  await A.page.waitForTimeout(2500);
  const row = { x: file.x + SECOND_ROW.dx, y: file.y + SECOND_ROW.dy };
  await A.page.mouse.move(row.x, row.y, { steps: 3 });
  await A.page.waitForTimeout(1200);
  const coming = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
  await A.page.mouse.click(row.x, row.y);
  B.page = await coming;
  check("B: File > New tab opened a tab", Boolean(B.page));
  B.page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));
  await settle(B.page);
  for (const tab of TABS) {
    tab.on = await until(async () => Boolean(await tab.page.evaluate(() => window.brickworksConnector || "")), 120);
    tab.id = (await claude(tab.page)).tab || "";
  }
  check(`each tab listens, under an id of its own: A ${A.id} ${A.on ? "on" : "off"}, B ${B.id} ${B.on ? "on" : "off"}`,
    A.on && B.on && A.id && B.id && A.id !== B.id);
  await wait(12000);

  for (const tab of TABS) {
    await accountOpen(tab.page);
    const before = popups.length;
    await press(tab.page, "account_new_chat");
    await until(async () => popups.length > before, 15);
    const landed = popups[popups.length - 1] || "";
    tab.message = landed.includes("?q=") ? decodeURIComponent(landed.split("?q=")[1].split("&")[0]) : "";
    check(`${tab.label}: New chat for this tab hands claude.ai "${tab.message}"`, tab.message.includes(tab.id));
    // Back from the claude.ai tab it opened, as the person comes back.
    await tab.page.bringToFront();
    await accountShut(tab.page);
  }
  await stage("0_two_tabs");

  if (args["setup-only"]) console.log("  (--setup-only: no chats)");
  else await walk(mcpConfig);
} catch (trouble) {
  check(`the walk ran to its end: ${trouble.stack || trouble}`, false);
} finally {
  for (const one of chats) await one.end();
  check(`the pages raised no errors${problems.length ? ": " + problems[0] : ""}`, problems.length === 0);
  await browser.close();
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  let gone = false;
  if (base && secret && minted.kept.user_id) {
    gone = (await fetch(`${base}/auth/v1/admin/users/${minted.kept.user_id}`, {
      method: "DELETE", headers: { apikey: secret, authorization: `Bearer ${secret}` },
    }).catch(() => ({ ok: false }))).ok;
  }
  console.log(`  (the throwaway account ${gone ? "deleted" : "NOT deleted"})`);
}
console.log(failed ? `\n${failed} failed` : "\ntwo real chats, two tabs: each in its own, undo its own, a third asks first");
process.exit(failed ? 1 : 0);
