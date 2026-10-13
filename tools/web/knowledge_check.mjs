// Does the web build leave the real-set index out of arrival, and fetch it
// when a design first asks for a technique?
//
//   tools/export.sh web                        build/web, knowledge/ beside it
//   set -a; . ./.env; set +a
//   node tools/web/knowledge_check.mjs --dir=build/web     served here
//   BW_BYPASS=… node tools/web/knowledge_check.mjs --url=<preview>/app
//
// The index (assets/knowledge/snippets.json.gz, 3.6 MB) and the part looks
// beside it ship next to the build, not in the pack every visitor waits
// for (src/ai/real_snippets.gd). So, in a fresh page: nothing under
// knowledge/ is asked for while the app arrives and idles; then, playing
// Claude's part over the connector as arrival_check.mjs does,
// find_techniques fetches the index once and answers with real pieces,
// place_technique lays one on a plate, and find_parts_like fetches the
// looks and answers. Costs nothing: no model is called.
import { launch, openColumnFor } from "./browser.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { createServer } from "node:net";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const out = args.out || "shots/knowledge";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";

async function freePort() {
  return new Promise((done) => {
    const s = createServer();
    s.listen(0, "127.0.0.1", () => { const { port } = s.address(); s.close(() => done(port)); });
  });
}

let server = null;
let url = args.url;
if (!url) {
  const dir = args.dir || "build/web";
  const port = await freePort();
  server = spawn("node", ["tools/web/relay_server.mjs", String(port), `--static=${dir}`],
    { stdio: ["ignore", "pipe", "inherit"] });
  await new Promise((done) => server.stdout.once("data", done));
  url = `http://127.0.0.1:${port}/`;
}
let failures = 0;
function check(ok, label) {
  console.log(`${ok ? "  ok  " : "  FAIL"} ${label}`);
  if (!ok) failures += 1;
}

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
const page = await context.newPage();
const asked = [];
const started = Date.now();
page.on("request", (r) => {
  if (r.url().includes("/knowledge/")) asked.push([Date.now() - started, r.url()]);
});
let received = 0;
page.on("response", async (r) => {
  if (!r.url().includes("/knowledge/")) return;
  try { received += (await r.body()).length; } catch { /* a body the browser kept */ }
});
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });

const controls = () => page.evaluate(() => window.brickworksControls || {});
async function control(names, minutes = 5) {
  for (let tries = 0; tries < minutes * 120; tries++) {
    const shown = await controls();
    for (const name of names) if (shown[name]) return [name, shown[name]];
    if (tries === 6) await openColumnFor(page, names[0]);
    await page.waitForTimeout(500);
  }
  await page.screenshot({ path: `${out}/never_showed.png` }).catch(() => {});
  throw new Error(`the app never showed ${names.join(" or ")}`);
}

try {
  await control(["connect_claude", "connector_private"]);
  // Arrived; and idle a while, as a visitor who looks before designing.
  await page.waitForTimeout(8000);
  check(asked.length === 0, `arrival asks for nothing under knowledge/ (${asked.length} asked)`);

  const offered = await controls();
  const way = offered.connector_private ? "connector_private" : "connect_claude";
  await page.mouse.click(offered[way].x, offered[way].y);
  await page.waitForTimeout(3000);
  if (way === "connector_private") {
    const [, here] = await control(["claude_here"]);
    await page.mouse.click(here.x, here.y);
    await page.waitForTimeout(3000);
  }
  const [, copy] = await control(["connector_copy", "connector_private_copy"]);
  await page.mouse.click(copy.x, copy.y);
  await page.waitForTimeout(1500);
  const address = await page.evaluate(() => navigator.clipboard.readText());
  if (!address.includes("/api/mcp")) throw new Error(`no connector address: ${address.slice(0, 80)}`);
  check(asked.length === 0, "connecting Claude asks for nothing under knowledge/ either");

  let sent = 0;
  async function claude(method, params) {
    sent += 1;
    const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
    if (bypass) headers["x-vercel-protection-bypass"] = bypass;
    const answer = await fetch(address, {
      method: "POST", headers, body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
    });
    return answer.json();
  }
  const said = (answer) => (answer.result?.content || []).map((c) => c.text || "").join(" ").replace(/\s+/g, " ");
  const pictures = (answer) => (answer.result?.content || []).filter((c) => c.type === "image");
  await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "knowledge_check", version: "1" } });
  const listed = await claude("tools/list", {});
  const names = (listed.result?.tools || []).map((t) => t.name);
  check(["find_techniques", "place_technique", "find_parts_like"].every((n) => names.includes(n)),
    "the tab offers find_techniques, place_technique and find_parts_like");

  let t = Date.now();
  const found = await claude("tools/call", { name: "find_techniques", arguments: { query: "car nose", max_studs: 8 } });
  const foundMs = Date.now() - t;
  const text = said(found);
  writeFileSync(`${out}/find_techniques.txt`, text);
  const index = asked.filter(([, u]) => u.endsWith("snippets.json.gz"));
  check(index.length === 1, `find_techniques fetched the index once (${index.length} times, ${(received / 1e6).toFixed(1)} MB)`);
  const ids = [...text.matchAll(/id (\S+) /g)].map((m) => m[1]);
  check(ids.length >= 3 && text.includes("LDraw Official Model Repository"),
    `...and answered with credited real pieces in ${(foundMs / 1000).toFixed(1)} s: ${ids.slice(0, 3).join(", ")}`);
  for (const [n, image] of pictures(found).entries()) {
    writeFileSync(`${out}/find_techniques_${n}.png`, Buffer.from(image.data, "base64"));
  }
  check(pictures(found).length === 1, "...with a picture of them");

  await claude("tools/call", { name: "clear_model", arguments: {} });
  await claude("tools/call", { name: "edit_model", arguments: { add: [{ part: "91405", color: 72, x: 0, y: 0, z: 0, rot: 0 }] } });
  const laysId = (text.match(/id (\S+) [^.]*?lays as it stands/) || [])[1] || ids[0];
  const placed = said(await claude("tools/call", { name: "place_technique", arguments: { id: laysId, x: 4, y: 1, z: 4 } }));
  writeFileSync(`${out}/place_technique.txt`, placed);
  check(placed.includes("Done."), `place_technique laid ${laysId} on the plate: ${placed.slice(0, 120)}`);
  check(asked.filter(([, u]) => u.endsWith("snippets.json.gz")).length === 1, "...without fetching the index again");

  const looks = said(await claude("tools/call", { name: "find_parts_like", arguments: { query: "claw" } }));
  writeFileSync(`${out}/find_parts_like.txt`, looks);
  check(asked.some(([, u]) => u.endsWith("part_looks.json")) && looks.includes("reads as"),
    `find_parts_like fetched the looks and answered: ${looks.slice(0, 100)}`);
  await page.screenshot({ path: `${out}/after.png` });
  writeFileSync(`${out}/requests.json`, JSON.stringify(asked, null, 1));
} catch (error) {
  console.log(`  FAIL ${error.message}`);
  failures += 1;
}
await browser.close();
if (server) server.kill();
console.log(failures ? `knowledge check: ${failures} FAILED` : "knowledge check: arrives without the index, fetches it when asked, and it works");
process.exit(failures ? 1 : 0);
