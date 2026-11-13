// orangecheck's window asks the page that opened it to say a nonce back
// before it signs anything (me-client 0.59.0, 2026-11-11): only the page
// that opened it was handed the nonce. Checked on this machine with
// nothing reached outside it: this checkout's web/oc-button.mjs on a page
// of one local address, orangecheck's window stood in for on another.
//
//   node tools/web/oc_echo_check.mjs
//
//   1. Asked by the window it opened, the button says the nonce back, to
//      orangecheck's address only.
//   2. Asked from a frame inside that window, it says nothing.
//   3. Asked by that window once it is at another address, it says nothing.
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { launch } from "./browser.mjs";

const BUTTON = readFileSync(new URL("../../web/oc-button.mjs", import.meta.url), "utf8");
const NONCE = "oc-echo-check-nonce-0123";

let failed = 0;
const check = (what, ok, said = "") => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${said && !ok ? `: ${said}` : ""}`);
  if (!ok) failed += 1;
  return ok;
};
const serve = (host, handler) => new Promise((done) => {
  const server = createServer(handler).listen(0, host, () => done(server));
});
const html = (response, body) => {
  response.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
  response.end(`<!doctype html><meta charset="utf-8">${body}`);
};
// The window, and a frame in it, each keep every answer they are sent; the
// one that asks asks its opener.
const KEEP = `window.answered = [];
addEventListener("message", (e) => {
  if (e.data && e.data.type === "oc-signin-echo") window.answered.push({ from: e.origin, nonce: e.data.nonce });
});`;
const ASK = (opener) => `<script>${KEEP}
${opener}.postMessage({ type: "oc-signin-challenge", nonce: ${JSON.stringify(NONCE)} }, "*");
</script>`;

let PAGE = "";
let OC = "";
let ELSEWHERE = "";
const page = await serve("127.0.0.1", (request, response) => {
  if (request.url === "/oc-button.mjs") {
    response.writeHead(200, { "content-type": "text/javascript" });
    return response.end(BUTTON);
  }
  const popupPath = new URL(request.url, PAGE).searchParams.get("window") || "/popup/signin";
  html(response, `<button id="b">Sign in with orangecheck</button><script type="module">
import { enhanceSignInButton } from "/oc-button.mjs";
enhanceSignInButton(document.getElementById("b"), { popup: ${JSON.stringify({ popupOrigin: OC, popupPath })}, onSignedIn() {} });
window.ready = true;
</script>`);
});
const oc = await serve("localhost", (request, response) => {
  const { pathname } = new URL(request.url, OC);
  if (pathname === "/frame") return html(response, ASK("parent.opener"));
  if (pathname === "/framed") return html(response, `<script>${KEEP}</script><iframe src="/frame"></iframe>`);
  if (pathname === "/moved") {
    response.writeHead(302, { location: `${ELSEWHERE}/` });
    return response.end();
  }
  html(response, ASK("opener"));
});
const elsewhere = await serve("127.0.0.1", (request, response) => html(response, ASK("opener")));
PAGE = `http://127.0.0.1:${page.address().port}`;
OC = `http://localhost:${oc.address().port}`;
ELSEWHERE = `http://127.0.0.1:${elsewhere.address().port}`;

const browser = await launch({ signedOut: true });
const reached = [];
try {
  for (const [what, popupPath, want] of [
    ["asked by the window it opened, it says the nonce back, to that window's address only", "/popup/signin", [{ from: PAGE, nonce: NONCE }]],
    ["asked from a frame inside that window, it says nothing", "/framed", []],
    ["asked by that window at another address, it says nothing", "/moved", []],
  ]) {
    const context = await browser.newContext();
    await context.route("**/*", (route) => {
      const { origin } = new URL(route.request().url());
      if ([PAGE, OC, ELSEWHERE].includes(origin)) return route.continue();
      reached.push(route.request().url());
      return route.abort();
    });
    const opener = await context.newPage();
    await opener.goto(`${PAGE}/?window=${encodeURIComponent(popupPath)}`);
    await opener.waitForFunction(() => window.ready === true);
    const [popup] = await Promise.all([context.waitForEvent("page"), opener.click("#b")]);
    await popup.waitForLoadState("load");
    await popup.waitForTimeout(1000);
    const frame = popup.frames().find((one) => one !== popup.mainFrame());
    const got = [...await popup.evaluate(() => window.answered || []),
      ...(frame ? await frame.evaluate(() => window.answered || []) : [])];
    check(what, JSON.stringify(got) === JSON.stringify(want), JSON.stringify(got));
    await context.close();
  }
  check("nothing outside this machine was reached", reached.length === 0, reached.slice(0, 3).join(" "));
} catch (trouble) {
  check("the check finished", false, String(trouble?.stack || trouble).slice(0, 400));
} finally {
  await browser.close();
  for (const server of [page, oc, elsewhere]) server.close();
}
console.log(`oc_echo_check: ${failed ? `${failed} failed` : "all passed"}`);
process.exit(failed ? 1 : 0);
