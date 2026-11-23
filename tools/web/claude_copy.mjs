// The message a model's page copies for the person's own Claude, as the
// person gets it (With your Claude, claudelink): the page opened in a
// browser, Open in the studio's With your Claude pressed, the ask typed,
// Copy for Claude pressed, and what reached the clipboard printed as one
// line of JSON: {message, said, shot}. tools/bench/claudelink.py gives a
// session this and nothing else.
//
//   node tools/web/claude_copy.mjs --origin=http://127.0.0.1:11380 --id=<link id> --ask="..."
//       [--shot=FILE] [--width=1280] [--theme=light]
//
// --origin is a relay (tools/web/relay_server.mjs) or a deployment; the page
// is its /m/<id>. --shot is the window with the panel open, after the copy.
// The page's clipboard is this script's: a page on plain http may not use
// the browser's.
import { launch } from "./browser.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const origin = String(args.origin || "").replace(/\/+$/, "");
const id = String(args.id || "");
if (!origin || !/^[A-Za-z0-9]{10}$/.test(id)) {
  console.error("claude_copy: --origin=URL --id=<a model's link id> [--ask=WORDS]");
  process.exit(2);
}
const width = Number(args.width || 1280);
const browser = await launch({ signedOut: true });
let said = { message: "", said: "", shot: "" };
try {
  const context = await browser.newContext({ viewport: { width, height: width < 600 ? 844 : 900 },
    colorScheme: String(args.theme || "light") });
  await context.addInitScript(() => {
    window.__copied = [];
    try {
      Object.defineProperty(navigator, "clipboard", { configurable: true,
        value: { writeText: async (text) => { window.__copied.push(String(text)); } } });
      Object.defineProperty(window, "isSecureContext", { configurable: true, value: true });
    } catch { /* kept as it is */ }
  });
  const page = await context.newPage();
  await page.goto(`${origin}/m/${id}`, { waitUntil: "load", timeout: 120000 });
  await page.waitForFunction(() => !document.querySelector("[data-open-claude]")?.hidden, null, { timeout: 30000 });
  await page.click("[data-open-claude]");
  await page.fill("#claude-ask", String(args.ask === true ? "" : args.ask || ""));
  await page.click("#claude-panel .claude-do > .cta:not(.ghost)");
  await page.waitForFunction(() => window.__copied.length > 0, null, { timeout: 10000 });
  said = await page.evaluate(() => ({ message: window.__copied.at(-1), said: document.querySelector(".claude-said")?.textContent || "" }));
  if (args.shot) {
    await page.locator("#claude-panel").scrollIntoViewIfNeeded();
    await page.screenshot({ path: String(args.shot) });
    said.shot = String(args.shot);
  }
} finally {
  await browser.close();
}
console.log(JSON.stringify(said));
process.exit(said.message ? 0 : 1);
