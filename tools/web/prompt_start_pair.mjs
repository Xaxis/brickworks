// Start on a weekly quick build, timed against a copy link that is no
// prompt's: the same build, the same model, in two browsers at the same
// moments (memory: same-moment pairs), the only difference the answer to
// the studio's question about the template (api/people.js ?op=prompt_of):
// a prompt open this week, or none. The bar (prompts' brief): Start opens
// the template's copy within the plain copy's time + 2 s, at 390 (touch)
// and at 1280.
//
//   node --env-file=.env tools/web/relay_server.mjs 11372 --static=build/web &
//   node --env-file=.env tools/web/prompt_start_pair.mjs --url=http://127.0.0.1:11372 --out=DIR [--rounds=6]
//
// A throwaway account (a Resend test address) publishes an 8x8 plate with
// ten bricks, unlisted, as the template; each browser is signed in as it,
// since a local export opens the studio only signed in; both are deleted at
// the end. Each round the arm with the prompt changes browser, so neither
// browser's place in the pair is the measure. Timed from the navigation to
// the studio saying the copy is open with every part placed
// (window.brickworksShare.copying, window.brickworksState.bricks), then, for
// the prompt's arm, to the brief said above the model. Exit 1 over the bar.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url || "http://127.0.0.1:11372").replace(/\/+$/, "").replace(/\/app$/, "");
const out = path.resolve(String(args.out || "shots/prompt_start"));
const rounds = Math.max(1, Number(args.rounds) || 6);
mkdirSync(out, { recursive: true });
const rand = randomBytes(4).toString("hex");
const email = `delivered+bw-promptpair-${rand}@resend.dev`;
const BAR_MS = 2000;
const PARTS = 11;

const lines = ["0 Pair template", `0 Name: promptpair_${rand}.ldr`, "0 Author: Prompt Start Pair",
  "1 2 0 0 0 1 0 0 0 1 0 0 0 1 41539.dat"];
for (let n = 0; n < PARTS - 1; n++) lines.push(`1 4 ${-60 + (n % 4) * 40} -32 ${-60 + Math.floor(n / 4) * 40} 1 0 0 0 1 0 0 0 1 3003.dat`);
const text = `${lines.join("\r\n")}\r\n`;

const results = [];
let session = null;
let model = null;
const browsers = [];
try {
  session = await mintSession(email);
  const made = await fetch(`${site}/api/share`, { method: "POST", headers: { "content-type": "application/json",
    authorization: `Bearer ${session.access_token}` }, body: JSON.stringify({ name: `Pair template ${rand}`, model: text,
    image: readFileSync(path.join(root, "web/share.png")).toString("base64"), listed: false }) });
  model = (await made.json().catch(() => ({}))).id;
  if (made.status !== 201 || !model) throw new Error(`the template was not published (${made.status})`);
  const prompt = { id: 1, title: "Habitat", brief: "A home for one minifigure on an 8×8 plate.", starts_on: "2026-11-23",
    ends_on: "2099-11-29", template: model, open: true, page: `${site}/challenge?id=1` };
  browsers.push(await launch({ signedOut: true }), await launch({ signedOut: true }));

  /// One arm's open: ms to the copy open whole, and to the brief said.
  async function arm(browser, size, withPrompt) {
    const context = await browser.newContext({ viewport: { width: size.width, height: size.height },
      ...(size.phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
    await context.addInitScript(([name, value]) => {
      try { localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(session.kept)]);
    await context.route((url) => url.pathname === "/api/people" && url.searchParams.get("op") === "prompt_of",
      (route) => route.fulfill({ status: 200,
      contentType: "application/json", body: JSON.stringify({ prompt: withPrompt ? prompt : null }) }));
    const page = await context.newPage();
    const began = Date.now();
    await page.goto(`${site}/app?copy=${model}`, { waitUntil: "commit", timeout: 120000 });
    const opened = await page.waitForFunction(([id, parts]) => window.brickworksShare?.copying === id
      && Number(window.brickworksState?.bricks) >= parts, [model, PARTS], { timeout: 240000, polling: 100 })
      .then(() => Date.now() - began).catch(() => null);
    const said = withPrompt && opened !== null ? await page.waitForFunction(() => /quick build/.test(
      String(window.brickworksShare?.prompt_line || "")), null, { timeout: 30000, polling: 100 })
      .then(() => Date.now() - began).catch(() => null) : null;
    await context.close();
    return { opened, said };
  }

  for (const size of [{ name: "390", width: 390, height: 844, phone: true }, { name: "1280", width: 1280, height: 800 }]) {
    for (let r = 0; r < rounds; r++) {
      // The prompt's arm in the first browser on even rounds, the second on odd.
      const first = r % 2 === 0;
      const [a, b] = await Promise.all([arm(browsers[0], size, first), arm(browsers[1], size, !first)]);
      const prompted = first ? a : b;
      const plain = first ? b : a;
      results.push({ size: size.name, round: r + 1, prompt: prompted.opened, plain: plain.opened, said: prompted.said });
      console.log(`  ${size.name} round ${r + 1}: Start ${prompted.opened} ms (brief said ${prompted.said} ms), `
        + `plain copy ${plain.opened} ms`);
    }
  }
} catch (trouble) {
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
  results.push({ trouble: String(trouble.message || trouble) });
} finally {
  for (const browser of browsers) await browser.close().catch(() => {});
  if (model && session) {
    await fetch(`${site}/api/share?op=unpublish&id=${model}`, { method: "POST",
      headers: { authorization: `Bearer ${session.access_token}` } }).catch(() => {});
  }
  await deleteAccount(email).catch(() => {});
}

const median = (list) => [...list].sort((x, y) => x - y)[Math.floor(list.length / 2)];
let failed = results.some((one) => one.trouble) ? 1 : 0;
for (const size of ["390", "1280"]) {
  const mine = results.filter((one) => one.size === size);
  const whole = mine.filter((one) => one.prompt !== null && one.plain !== null);
  if (whole.length < Math.ceil(rounds / 2)) {
    console.log(`  FAIL  ${size}: ${whole.length} of ${mine.length} rounds opened both`);
    failed += 1;
    continue;
  }
  const start = median(whole.map((one) => one.prompt));
  const plain = median(whole.map((one) => one.plain));
  const ok = start <= plain + BAR_MS && whole.every((one) => one.said !== null);
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${size}: Start opens the template's copy in ${start} ms (median of ${whole.length}), `
    + `a plain copy in ${plain} ms; the bar ${plain + BAR_MS} ms; the brief said every time: ${whole.every((one) => one.said !== null)}`);
  if (!ok) failed += 1;
}
writeFileSync(path.join(out, "pairs.json"), `${JSON.stringify(results, null, 1)}\n`);
console.log(failed ? `${failed} FAILED` : "prompt start: within the bar at 390 and 1280");
process.exit(failed ? 1 : 0);
