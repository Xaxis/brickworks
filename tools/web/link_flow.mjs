// A link to a model or a picture, given to the app in a real browser as a
// session gives one over the connector: brickify url= and print_part
// picture_url=, from a site that lets other sites fetch its files
// (Wikimedia, which the page's policy names) and from ordinary ones that do
// not (no CORS headers, not in the policy).
//
//   set -a; . ./.env; set +a
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/link_flow.mjs --url=https://<a preview>/app --out=shots/link_web
//
// In a browser the app cannot fetch from most sites itself: the page's
// connect-src names a few hosts, and a site that sends no CORS headers is
// refused even then. Every one came back "Could not fetch … (error 4)", a
// code nobody can act on (urlfetch, 2026-11-03). The app now asks its own
// site to fetch the link for the signed-in account (api/_link.js, POST
// /api/account?op=fetch), which checks where it goes and what comes back.
//
// The page is signed in as the test account (browser.mjs). Plays Claude's
// part over the connector (in_view_flow.mjs has how), and checks:
//
//   1. tools/list, then a 2 x 2 tile placed to print on;
//   2. brickify url= an STL on Wikimedia, and an OBJ on a site with no CORS:
//      each laid ("Brickified …");
//   3. print_part picture_url= a PNG on Wikimedia, and one on a site with no
//      CORS: each printed ("It is #N");
//   4. print_part picture_url= a 14 MB photograph: refused, saying its size,
//      the most a link brings in, and what to do instead;
//   5. no answer says a bare "error <number>".
//
// Fails, exiting 1, on any check that does not hold or a script error in
// the console. The sites are real and outside: a check that fails because
// one is down says what it heard.
import { clickStill, controlsWith, launch, openColumnFor, withJobs } from "./browser.mjs";
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "");
if (!url) {
  console.log("give --url=<a deployment>/app");
  process.exit(2);
}
const out = resolve(String(args.out || "shots/link_web"));
mkdirSync(out, { recursive: true });
const bypass = String(args.bypass || process.env.BW_BYPASS || "");

// Wikimedia sends Access-Control-Allow-Origin: * and is in the page's
// connect-src; people.sc.fsu.edu sends no CORS headers and is not.
const LINKS = {
  stlCors: "https://upload.wikimedia.org/wikipedia/commons/b/b8/Dodecahedron.stl",
  objPlain: "https://people.sc.fsu.edu/~jburkardt/data/obj/teapot.obj",
  pngCors: "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png",
  pngPlain: "https://people.sc.fsu.edu/~jburkardt/data/png/apollonian_gasket.png",
  // 14,679,474 bytes.
  large: "https://upload.wikimedia.org/wikipedia/commons/3/3f/Fronalpstock_big.jpg",
};

const t0 = Date.now();
const said = [];
let fails = 0;
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  if (!passed) fails += 1;
  return passed;
};
const errors = [];

const browser = await launch();
const finish = async (code) => {
  writeFileSync(`${out}/said.txt`, said.join("\n") + "\n");
  await browser.close().catch(() => {});
  process.exit(code);
};
const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: new URL(url).origin });
const page = await context.newPage();
page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
writeFileSync(`${out}/console.log`, "");
page.on("console", (m) => {
  appendFileSync(`${out}/console.log`, `${((Date.now() - t0) / 1000).toFixed(1)}s ${m.text()}\n`);
  if (/SCRIPT ERROR|USER ERROR|Parse Error/.test(m.text())) errors.push(m.text().slice(0, 300));
});

async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = ((await page.evaluate(() => window.brickworksControls || {})) || {})[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name.replace(/\W/g, "_")}.png`);
  throw new Error(`the app never showed "${name}"`);
}
const press = (name) => clickStill(page, name, { find: where, after: 1500 });

try {
  await page.goto(bypass
    ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
    : url, { waitUntil: "domcontentloaded", timeout: 180000 });
  ok(Boolean(await where("open", 400)), "the app came up, signed in");
  await where("view", 120);
  await page.waitForTimeout(Number(args.load || 8000));

  // The connector's private address, as freeze_check.mjs reads it.
  await openColumnFor(page, "connector_private");
  if ((await controlsWith(page, ["connector_private"])).connector_private) {
    await press("connector_private");
    await press("claude_here");
    await page.waitForTimeout(1500);
    await press("connector_private_copy");
  } else {
    await press("connect_claude");
    await page.waitForTimeout(1500);
    await press("connector_copy");
  }
  await page.waitForTimeout(1500);
  const address = await page.evaluate(() => navigator.clipboard.readText()).catch(() => "");
  if (!ok(address.includes("/api/mcp"), `the connector's private address is on the clipboard (${address.slice(0, 60)}…)`)) {
    await shot("no_address.png");
    await finish(1);
  }
  let sent = 0;
  async function send(method, params) {
    sent += 1;
    const headers = { "content-type": "application/json", accept: "application/json, text/event-stream" };
    if (bypass) headers["x-vercel-protection-bypass"] = bypass;
    const answer = await fetch(address, {
      method: "POST", headers,
      body: JSON.stringify({ jsonrpc: "2.0", id: sent, method, params }),
    });
    return answer.json();
  }
  const claude = withJobs(send);
  await claude("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "link_flow", version: "1" } });
  const names = ((await claude("tools/list", {})).result?.tools || []).map((t) => t.name);
  ok(names.includes("brickify") && names.includes("print_part"), `tools/list has brickify and print_part (${names.length} tools)`);
  const answers = [];
  const call = async (name, input = {}) => {
    const answer = await claude("tools/call", { name, arguments: input });
    const text = (answer.result?.content || []).filter((c) => c.type === "text").map((c) => c.text).join("\n")
      || JSON.stringify(answer.error || answer).slice(0, 300);
    answers.push(`${name} ${JSON.stringify(input)}\n${text}\n`);
    appendFileSync(`${out}/answers.txt`, `── ${name} ${JSON.stringify(input)}\n${text}\n\n`);
    return text;
  };
  writeFileSync(`${out}/answers.txt`, "");
  // An answer without the tab it came from and the job it was: what was said.
  const gist = (text) => text.split("\n").filter((line) => !/^Tab \w+, |^Job \d+ \(\w+\) is done/.test(line))
    .join("\n").trim();

  // 1. Something to print on: two 2 x 2 tiles, each its own number.
  await call("clear_model", {});
  const placed = await call("edit_model", { add: [
    { part: "3068b", color: 15, x: 0, y: 0, z: 0, rot: 0 },
    { part: "3068b", color: 15, x: 40, y: 0, z: 0, rot: 0 },
    { part: "3068b", color: 15, x: 80, y: 0, z: 0, rot: 0 },
  ] });
  const looked = await call("look_at_model", {});
  // "Put down 3 (#2, #3, #4)."; look_at_model lists them too.
  const tiles = [...new Set([...`${placed}\n${looked}`.matchAll(/#(\d+)\b/g)].map((m) => Number(m[1])))].slice(0, 3);
  ok(tiles.length === 3, `three tiles to print on: ${tiles.map((n) => `#${n}`).join(", ")}`);

  // 2. Brickify from a link, with CORS and without.
  for (const [what, link] of [["an STL on Wikimedia (CORS)", LINKS.stlCors], ["an OBJ on a site with no CORS", LINKS.objPlain]]) {
    const text = gist(await call("brickify", { url: link, studs: 12 }));
    ok(/^Brickified /.test(text), `brickify ${what} is laid: ${text.split("\n")[0].slice(0, 160)}`);
  }
  await shot("brickified.png");

  // 3. A print from a link, with CORS and without.
  for (const [what, link, tile] of [["a PNG on Wikimedia (CORS)", LINKS.pngCors, tiles[0]],
    ["a PNG on a site with no CORS", LINKS.pngPlain, tiles[1]]]) {
    const text = gist(await call("print_part", { brick: tile, picture_url: link, name: "Link print" }));
    ok(/It is #\d+/.test(text), `print_part ${what} is printed: ${text.split("\n")[0].slice(0, 160)}`);
  }
  await shot("printed.png");

  // 4. Too large for a link: said plainly, with its size and what to do.
  const large = gist(await call("print_part", { brick: tiles[2], picture_url: LINKS.large }));
  ok(/14 MB/.test(large) && /4 MB/.test(large) && /computer/.test(large) && !/It is #\d+/.test(large),
    `a 14 MB photograph is refused, saying so: ${large.slice(0, 220)}`);

  // 5. Never a bare code.
  const coded = answers.filter((a) => /\berror \d+\b/i.test(a.split("\n").slice(1).join("\n")));
  ok(coded.length === 0, `no answer says a bare error code${coded.length ? `: ${coded[0].slice(0, 200)}` : ""}`);
} catch (trouble) {
  ok(false, `the flow stopped: ${String(trouble?.message || trouble).slice(0, 300)}`);
  await shot("stopped.png");
}
ok(errors.length === 0, `no script errors${errors.length ? `: ${errors[0]}` : ""}`);
console.log(fails === 0 ? "link flow: every link brought in or refused in words" : `link flow: ${fails} FAILED`);
await finish(fails === 0 ? 0 : 1);
