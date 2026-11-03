// Does a person's own AI key stay where it is put, in a real browser, under
// the site's own security policy?
//
//   BW_BYPASS=… node tools/web/key_leak_flow.mjs --url=<a preview>/app --out=DIR
//   ... --plant    the key also written into the site's storage as it is, as a
//                  leak would: the search must then find it (the red; exits 1)
//
// A made-up Anthropic key is pasted in the assistant's column as a person
// pastes it (the panel is drawn in the canvas: window.brickworksControls says
// where), and Anthropic is answered here, never reached: its models call says
// yes, so the key is checked, taken and kept. Then:
// - the key went to api.anthropic.com alone, in x-api-key: no other request
//   from the page or its workers carried it in its address, headers or body;
// - nothing the page logged holds it;
// - the site's storage holds it scrambled, never as written (every IndexedDB
//   database, where the app's files are, localStorage, sessionStorage,
//   cookies), and holds its file (anthropic.key, encrypted: GDEC);
// - Change key forgets it: the file gone from the site's storage;
// - pasted again with Remember unticked (this visit only), nothing of it is
//   written anywhere;
// - the policies in the headers (tools/deploy.sh): no script from anywhere
//   but the site, on the app and the site's pages, the app able to reach the
//   providers a key goes to and the site's pages not; and nothing refused by
//   a policy while it ran, on the app, the home page and the gallery (the
//   console, and the page's securitypolicyviolation events).
import { clickStill, launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "https://brickworks.diy/app";
const out = args.out || "shots/key_leak";
const site = new URL(url).origin;
const plant = Boolean(args.plant);
mkdirSync(out, { recursive: true });
const made = () => "sk-ant-api03-KEYLEAKFLOW" + [...crypto.getRandomValues(new Uint8Array(20))]
  .map((b) => b.toString(16).padStart(2, "0")).join("");
const key = made();
const visit = made();
const keys = [key, visit];

let failures = 0;
const ok = (what) => console.log(`  ok    ${what}`);
const fail = (what) => { failures += 1; console.log(`  FAIL  ${what}`); };
const check = (what, good) => (good ? ok(what) : fail(what));
/// Whether [text] holds a key as written, in hex or in base64.
const holds = (text) => keys.some((one) => [one, Buffer.from(one).toString("hex"),
  Buffer.from(one).toString("base64").replace(/=+$/, "")].some((form) => text.includes(form)));

// -- the policies, as served ---------------------------------------------------
console.log("the policies");
const bypass = process.env.BW_BYPASS ? { "x-vercel-protection-bypass": process.env.BW_BYPASS } : {};
const policy = async (path) => (await fetch(site + path, { headers: bypass, redirect: "manual" }))
  .headers.get("content-security-policy") || "";
const appCsp = await policy("/app");
const siteCsp = await policy("/");
const galleryCsp = await policy("/gallery");
console.log(`  /app: ${appCsp}\n  /:    ${siteCsp}`);
for (const [whose, csp] of [["/app", appCsp], ["/", siteCsp], ["/gallery", galleryCsp]]) {
  const scripts = (csp.match(/script-src ([^;]*)/) || [])[1] || "";
  check(`${whose}: script only from the site and the hashes it ships (${scripts.trim()})`,
    scripts && !/(^|\s)(https?:|\*|'unsafe-inline'|data:|blob:)/.test(scripts));
}
const providers = ["https://api.anthropic.com", "https://api.openai.com",
  "https://generativelanguage.googleapis.com", "https://openrouter.ai", "https://api.mistral.ai",
  "https://api.groq.com", "https://api.together.xyz", "https://api.deepseek.com", "https://api.x.ai"];
const reach = (csp) => ((csp.match(/connect-src ([^;]*)/) || [])[1] || "").trim().split(/\s+/);
check("the app may reach every provider a key goes to, and the site's pages none",
  providers.every((one) => reach(appCsp).includes(one))
  && providers.every((one) => !reach(siteCsp).includes(one)));
check("the app stays cross-origin isolated, which its threads need",
  await fetch(site + "/app", { headers: bypass }).then((r) =>
    r.headers.get("cross-origin-opener-policy") === "same-origin"
    && r.headers.get("cross-origin-embedder-policy") === "require-corp"));

// -- the app, with a key ---------------------------------------------------------
const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 860 } });
const refused = [];
await context.addInitScript(() => {
  window.__refused = [];
  document.addEventListener("securitypolicyviolation", (e) =>
    window.__refused.push(`${e.violatedDirective} ${e.blockedURI}`));
});
const requests = [];
context.on("request", async (r) => {
  const headers = await r.allHeaders().catch(() => r.headers());
  requests.push({ url: r.url(), headers: JSON.stringify(headers), body: r.postData() || "" });
});
const cors = { "access-control-allow-origin": "*", "access-control-allow-headers": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS" };
const asked = [];
await context.route(/^https:\/\/api\.anthropic\.com\//, (route) => {
  const request = route.request();
  if (request.method() === "OPTIONS") return route.fulfill({ status: 204, headers: cors });
  asked.push({ url: request.url(), key: request.headers()["x-api-key"] || "" });
  return route.fulfill({ status: 200, headers: { ...cors, "content-type": "application/json" },
    body: JSON.stringify({ data: [{ type: "model", id: "claude-opus-5-5" }], has_more: false }) });
});
const page = await context.newPage();
const logged = [];
const watch = (one) => one.on("console", (m) => {
  const text = m.text();
  logged.push(text);
  if (/Content Security Policy|Refused to (connect|load|execute|create|frame|apply)/i.test(text)) {
    refused.push(`${one.url()}: ${text.slice(0, 220)}`);
  }
});
watch(page);
page.on("pageerror", (e) => logged.push(String(e)));

const first = process.env.BW_BYPASS
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${process.env.BW_BYPASS}&x-vercel-set-bypass-cookie=true`
  : url;
await page.goto(first, { waitUntil: "domcontentloaded", timeout: 120000 });
await page.waitForSelector("#boot.done", { state: "attached", timeout: 300000 }).catch(() => {});
const click = (name) => clickStill(page, name, { open: true, shots: out });
const showing = (n) => page.evaluate((n) => Boolean((window.brickworksControls || {})[n]), n);
async function paste(given) {
  await click("key_field");
  await page.waitForTimeout(1000);
  await page.keyboard.type(given, { delay: 10 });
  await click("use_key");
  for (let tries = 0; tries < 120; tries++) {
    await page.waitForTimeout(500);
    if (await showing("brief")) return true;
  }
  return false;
}
/// Everything the site keeps in this browser, as text to search: each
/// IndexedDB database's every value (a file's bytes as Latin-1), the two
/// storages and the cookies. And the app's files there by name, with their
/// first bytes.
async function stored() {
  // The app writes its files to IndexedDB a moment after it closes them.
  await page.waitForTimeout(4000);
  const kept = await page.evaluate(async () => {
    const text = [];
    const files = {};
    const asBytes = (v) => (v instanceof Uint8Array ? v : v instanceof ArrayBuffer ? new Uint8Array(v) : null);
    const latin1 = (bytes) => {
      let said = "";
      for (let at = 0; at < bytes.length; at += 8192) said += String.fromCharCode(...bytes.subarray(at, at + 8192));
      return said;
    };
    for (const { name } of await indexedDB.databases()) {
      const db = await new Promise((done, failed) => {
        const asking = indexedDB.open(name);
        asking.onsuccess = () => done(asking.result);
        asking.onerror = () => failed(asking.error);
      });
      for (const store of db.objectStoreNames) {
        const all = await new Promise((done) => {
          const seen = [];
          const walk = db.transaction(store, "readonly").objectStore(store).openCursor();
          walk.onsuccess = () => {
            const at = walk.result;
            if (!at) return done(seen);
            seen.push([String(at.key), at.value]);
            at.continue();
          };
          walk.onerror = () => done(seen);
        });
        for (const [where, value] of all) {
          const bytes = asBytes(value && value.contents) || asBytes(value);
          const said = bytes ? latin1(bytes.subarray(0, 1 << 20)) : JSON.stringify(value);
          text.push(`${name}/${store}/${where}: ${said}`);
          if (bytes) files[where] = latin1(bytes.subarray(0, 4));
        }
      }
      db.close();
    }
    for (const box of [localStorage, sessionStorage]) {
      for (let n = 0; n < box.length; n++) text.push(`${box.key(n)}=${box.getItem(box.key(n))}`);
    }
    text.push(document.cookie);
    return { text: text.join("\n"), files };
  });
  kept.text += "\n" + JSON.stringify(await context.cookies());
  return kept;
}
const keyFile = (files) => Object.keys(files).find((name) => name.endsWith("/anthropic.key"));

console.log("a key, kept");
check("the made-up key was checked with Anthropic (here), taken and kept", await paste(key));
await page.screenshot({ path: `${out}/1_key_taken.png` });
if (plant) await page.evaluate((given) => localStorage.setItem("planted", given), key);
check(`it went to Anthropic, in x-api-key (${asked.length} call(s))`,
  asked.length > 0 && asked.every((one) => one.key === key));
const elsewhere = requests.filter((r) => !r.url.startsWith("https://api.anthropic.com/")
  && holds(r.url + r.headers + r.body));
check(`no other request of ${requests.length} carried it${elsewhere.length ? ": " + elsewhere.map((r) => r.url).join(", ") : ""}`,
  elsewhere.length === 0 && requests.length > 20);
let kept = await stored();
const file = keyFile(kept.files);
check(`the site's storage holds its file (${file || "none"}), encrypted (${file ? JSON.stringify(kept.files[file]) : "-"})`,
  Boolean(file) && kept.files[file] === "GDEC");
check(`...and holds the key nowhere as written, in hex or in base64 (${kept.text.length} characters searched)`,
  !holds(kept.text));

console.log("forgotten");
await click("change_key");
for (let tries = 0; tries < 60 && !(await showing("key_field")); tries++) await page.waitForTimeout(500);
kept = await stored();
check("Change key: its file gone from the site's storage", !keyFile(kept.files) && !holds(kept.text.replace(/planted=\S+/, "")));

console.log("for this visit only");
await click("remember_key");
await page.waitForTimeout(800);
check("pasted with Remember unticked, taken", await paste(visit));
await page.screenshot({ path: `${out}/2_this_visit.png` });
kept = await stored();
check("...and written nowhere: no file, nothing of it in the site's storage",
  !keyFile(kept.files) && !kept.text.includes(visit) && !holds(kept.text.replace(/planted=\S+/, "")));

console.log("nowhere else");
check(`nothing the page logged (${logged.length} lines) holds a key`, !logged.some((line) => holds(line)));
for (const path of ["/", "/gallery"]) {
  const other = await context.newPage();
  watch(other);
  await other.goto(site + path, { waitUntil: "load", timeout: 120000 }).catch(() => {});
  await other.waitForTimeout(3000);
  refused.push(...(await other.evaluate(() => window.__refused || []).catch(() => [])).map((r) => `${path}: ${r}`));
  await other.close();
}
refused.push(...(await page.evaluate(() => window.__refused || []).catch(() => [])).map((r) => `/app: ${r}`));
check(`no policy refused anything, on /app, / and /gallery${refused.length ? ": " + refused.slice(0, 5).join(" | ") : ""}`,
  refused.length === 0);
await browser.close();

console.log(failures === 0
  ? "the key went to its provider alone, kept scrambled, forgotten whole, and kept nowhere for a visit"
  : `${failures} FAILURE(S)${plant ? " (planted: the search found the key it was given)" : ""}`);
process.exit(failures === 0 ? 0 : 1);
