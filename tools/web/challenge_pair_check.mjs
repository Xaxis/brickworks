// The fan vote two at a time (challengestudio, 2026-11-23), in real
// browsers: /challenge's group shown as a pair side by side at 1280, one
// above the other at 390, each entry turning in its own blind embed
// (/m/<id>/embed?blind=1&autoplay=1), nobody's name and no count anywhere
// in the page or its frames; This one keeps the one liked more and brings
// the next beside it until one is left, then Vote for it asks once more and
// casts it; signed out, it asks to sign in. And its first screen beside the
// cards' (the vote page as it was), the two loaded at the same moments, 8
// rounds at each width: LCP no worse beyond the noise.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 11421 &
//   ~/.claude/claude-core/bin/heavy node tools/web/challenge_pair_check.mjs --url=http://127.0.0.1:11421 --out=DIR
//
// The challenge is a fixture, routed in the page (/api/people?op=challenge):
// an open one, four entries built by hand and two with the assistant, each
// a real published model (the newest six listed, read from the project with
// the secret key, nothing written), so each embed is the real one, drawn by
// api/share.js on the relay; its vote is routed too, and answered as cast,
// so nothing is voted. The page's document is given the headers deploy.sh
// gives every page (cross-origin isolated, the site's CSP), which a frame in
// it must agree with: on the relay alone a frame the deployment would show
// blank would pass.
//
// Writes pair-1280.png, pair-390.png, pair-chosen-390.png and lcp.json in DIR.
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { cardOf } from "../../api/_directory.js";
import { launch } from "./browser.mjs";

const arg = (name, fallback = "") => (process.argv.find((a) => a.startsWith(`--${name}=`)) || "").slice(name.length + 3) || fallback;
const site = arg("url").replace(/\/+$/, "");
const out = arg("out");
const ROUNDS = Number(arg("rounds", "8"));
if (!site || !out) {
  console.error("challenge_pair_check: --url=<the relay> --out=DIR");
  process.exit(2);
}
mkdirSync(out, { recursive: true });
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("challenge_pair_check: no SUPABASE_URL / SUPABASE_SECRET_KEY");
  process.exit(2);
}

let failures = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};
const errors = [];
const median = (list) => [...list].sort((a, b) => a - b)[Math.floor(list.length / 2)];

// --- The fixture -------------------------------------------------------------
const rest = async (query) => {
  const reply = await fetch(`${SUPABASE}/rest/v1/${query}`, { headers: { apikey: SECRET, authorization: `Bearer ${SECRET}` },
    signal: AbortSignal.timeout(30000) });
  if (!reply.ok) throw new Error(`${query.split("?")[0]}: ${reply.status}`);
  return reply.json();
};
// Not the site's own (author Brickworks), whose name is on every page.
const rows = await rest("shared_models?published=is.true&listed=is.true&test=is.false&has_image=is.true&author=not.is.null"
  + "&author=neq.Brickworks"
  + "&select=id,name,author,parts,updated_at,has_image,has_thumb,owner&order=updated_at.desc&limit=6");
if (rows.length < 6) {
  console.error(`challenge_pair_check: only ${rows.length} models to enter`);
  process.exit(2);
}
const owners = [...new Set(rows.map((row) => row.owner).filter(Boolean))];
const profiles = owners.length ? await rest(`people?account=in.(${owners.join(",")})&select=account,handle,name`) : [];
const profileOf = new Map(profiles.map((one) => [one.account, one]));
const entries = rows.map((row, at) => {
  const by = profileOf.get(row.owner);
  return { ...cardOf(site, { ...row, by: by ? { handle: by.handle, name: by.name } : null, likes: 7 + at, views: 40 + at }),
    way: at < 4 ? "hand" : "assistant", entered_at: new Date(Date.now() - at * 3600000).toISOString(), keeps: true, votes: null,
    winner: false, won: [] };
});
// Every maker's name and handle: none may be in the page two at a time.
const makers = [...new Set(entries.flatMap((one) => [one.author, one.by?.name, one.by?.handle])
  .filter((one) => typeof one === "string" && one.trim().length >= 3 && !/^brickworks$/i.test(one.trim()))
  .map((one) => one.trim()))];
const today = new Date().toISOString().slice(0, 10);
const day = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10);
const fixture = (you) => ({
  ready: true, year: false, next: null, past: [], prompt_now: null,
  challenge: { id: 990001, title: "Microscale", brief: "A whole place at the smallest scale.", starts_on: day(-10), ends_on: day(5),
    state: "open", test: true, settled: false, rules: { most_parts: null, set: null, tested: false }, rules_said: [],
    days_said: `${day(-10)} to ${day(5)}`,
    groups: [{ way: "hand", label: "Built by hand", entries: entries.filter((one) => one.way === "hand") },
      { way: "assistant", label: "Built with the assistant", entries: entries.filter((one) => one.way === "assistant") }],
    winners: [] },
  you,
});
console.log(`against ${site}, on ${today}: ${entries.length} entries (${entries.map((one) => one.id).join(" ")}), `
  + `${makers.length} makers' names to find nowhere`);

// The headers deploy.sh gives every page of the site (its "/(.*)" route):
// isolated, so a frame in it must say it may be.
const SITE_CSP = "default-src 'self'; script-src 'self'; worker-src 'self' blob:; connect-src 'self' https://overlook.technology blob:; "
  + "img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; media-src 'self' blob:; "
  + "object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
const DEPLOYED = { "cross-origin-opener-policy": "same-origin-allow-popups", "cross-origin-embedder-policy": "require-corp",
  "cross-origin-resource-policy": "same-origin", "content-security-policy": SITE_CSP };

const browser = await launch({ signedOut: true });
async function context({ width, height, phone = false, you = null, voted = null }) {
  const made = await browser.newContext({ viewport: { width, height }, colorScheme: "light",
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await made.route(/\/challenge(\?[^/]*)?$/, async (route) => {
    if (route.request().resourceType() !== "document") return route.continue();
    const reply = await route.fetch();
    return route.fulfill({ response: reply, headers: { ...reply.headers(), ...DEPLOYED } });
  });
  await made.route(/\/api\/people\?op=challenge\b/, (route) => route.fulfill({ status: 200, contentType: "application/json",
    body: JSON.stringify(fixture(you)) }));
  await made.route(/\/api\/people\?op=vote\b/, (route) => {
    if (voted) voted.push(JSON.parse(route.request().postData() || "{}"));
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ ok: true }) });
  });
  return made;
}
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to|Cross-Origin-Embedder|blocked/i.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
}
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const watchPaint = () => {
  window.__lcp = 0;
  window.__cls = 0;
  new PerformanceObserver((list) => { for (const one of list.getEntries()) window.__lcp = one.startTime; })
    .observe({ type: "largest-contentful-paint", buffered: true });
  new PerformanceObserver((list) => {
    for (const one of list.getEntries()) if (!one.hadRecentInput) window.__cls += one.value;
  }).observe({ type: "layout-shift", buffered: true });
};

/// The pair as drawn: each side's entry, box and frame, the line over it,
/// and every name a maker has found in the page or in a frame.
async function pairNow(page) {
  const drawn = await page.evaluate(() => {
    const seen = (el) => Boolean(el && !el.closest("[hidden]") && el.getClientRects().length);
    const box = (el) => { const r = el.getBoundingClientRect(); return { left: r.left, top: r.top + scrollY, right: r.right, bottom: r.bottom + scrollY }; };
    return {
      shown: seen(document.getElementById("pair")),
      said: (document.getElementById("pair-said")?.textContent || "").replace(/\s+/g, " ").trim(),
      state: document.getElementById("pair-two")?.dataset.state || "",
      sides: [...document.querySelectorAll("#pair-two .pair-one")].map((one) => ({ id: one.dataset.entry, box: box(one),
        src: one.querySelector("iframe")?.getAttribute("src") || "", title: one.querySelector("iframe")?.title || "",
        keep: one.querySelector(".pair-keep")?.getAttribute("aria-label") || "" })),
      vote: seen(document.getElementById("pair-vote")) ? document.getElementById("pair-vote").textContent.trim() : "",
      cards: document.querySelectorAll(".model").length,
      numbers: document.getElementById("numbers")?.children.length || 0,
      address: location.search,
    };
  });
  return drawn;
}
const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const NAMES = makers.map((name) => [name, new RegExp(`(^|[^\\p{L}\\p{N}])${escape(name)}($|[^\\p{L}\\p{N}])`, "iu")]);
/// The makers' names found in the page's markup and its frames'.
async function namesIn(page) {
  const found = [];
  const texts = [["page", await page.content()]];
  for (const frame of page.frames()) {
    if (frame === page.mainFrame()) continue;
    texts.push([frame.url(), await frame.content().catch(() => "")]);
  }
  for (const [where, text] of texts) {
    for (const [name, pattern] of NAMES) if (pattern.test(text)) found.push(`${name} in ${where.slice(0, 80)}`);
  }
  return found;
}
/// Each embed of the pair loaded in its frame, blind and not blocked: its
/// picture there, and no bar.
async function framesLoaded(page) {
  const said = [];
  for (const handle of await page.locator("#pair-two iframe").elementHandles()) {
    const frame = await handle.contentFrame();
    if (!frame) { said.push("no frame"); continue; }
    const ok = await frame.waitForSelector("main.embed[data-blind] a.picture", { timeout: 45000 }).then(() => true, () => false);
    const bar = ok ? await frame.locator(".embed-bar").count() : -1;
    said.push(ok && bar === 0 ? "blind" : ok ? "has its bar" : `not drawn (${frame.url().slice(0, 60)})`);
  }
  return said;
}

try {
  // --- 1. Two at a time, at each size -------------------------------------
  for (const [width, height, phone] of [[1280, 800, false], [390, 844, true]]) {
    console.log(`1. at ${width}: the cards, then two at a time`);
    const ctx = await context({ width, height, phone });
    const page = await ctx.newPage();
    listen(page, `pair ${width}`);
    await page.goto(`${site}/challenge`, { waitUntil: "load" });
    await page.waitForSelector("#entries .model[data-entry]", { timeout: 45000 });
    const link = page.locator("#pair-link");
    check(`at ${width}: over the cards, "${(await link.textContent().catch(() => "")).trim()}"`, await link.isVisible());
    await link.click();
    await page.waitForSelector("#pair:not([hidden]) .pair-one iframe", { timeout: 30000 });
    let now = await pairNow(page);
    check(`at ${width}: the address says it (${now.address})`, /[?&]pair=hand\b/.test(now.address));
    check(`at ${width}: two of the four by hand, each its own (${now.sides.map((one) => one.id).join(", ")})`,
      now.sides.length === 2 && now.sides[0].id !== now.sides[1].id
      && now.sides.every((one) => entries.some((entry) => entry.id === one.id && entry.way === "hand")));
    const [a, b] = now.sides.map((one) => one.box);
    check(width >= 1000 ? `at ${width}: side by side (tops ${Math.round(a.top)} and ${Math.round(b.top)}, ${Math.round(a.right)} left of ${Math.round(b.left)})`
      : `at ${width}: one above the other (${Math.round(a.bottom)} above ${Math.round(b.top)})`,
    width >= 1000 ? Math.abs(a.top - b.top) < 2 && a.right <= b.left : a.bottom <= b.top && Math.abs(a.left - b.left) < 2);
    check(`at ${width}: each in its blind embed, turning (${now.sides.map((one) => one.src).join(", ")})`,
      now.sides.every((one) => /\/m\/[A-Za-z0-9]{10}\/embed\?blind=1&autoplay=1$/.test(one.src)));
    check(`at ${width}: each frame named for a screen reader ("${now.sides[0].title}") and its button ("${now.sides[0].keep}")`,
      now.sides.every((one) => one.title.includes("3D") && one.keep.length > 8));
    await page.locator("#entries").scrollIntoViewIfNeeded();
    const loaded = await framesLoaded(page);
    check(`at ${width}: both embeds drawn in an isolated page, blind (${loaded.join(", ")})`, loaded.every((one) => one === "blind"));
    check(`at ${width}: no card, no numbers (${now.cards} cards, ${now.numbers} numbers)`, now.cards === 0 && now.numbers === 0);
    let names = await namesIn(page);
    check(`at ${width}: no maker's name in the page or its frames (${names.join("; ") || "none of " + makers.length})`, !names.length);
    const counts = await page.evaluate(() => [...document.querySelectorAll(".likes, .views, .votes, .count, [data-count]")]
      .map((one) => one.className || one.dataset.count));
    check(`at ${width}: no count (${counts.join(", ") || "none"})`, !counts.length);
    await page.evaluate(() => document.getElementById("entries").scrollIntoView({ block: "start" }));
    await page.waitForTimeout(1500);
    await shot(page, `pair-${width}.png`);

    // This one, until one is left.
    let presses = 0;
    const seen = new Set(now.sides.map((one) => one.id));
    let kept = "";
    while (now.state === "choosing" && presses < 6) {
      kept = now.sides[0].id;
      const before = now.sides[1].id;
      await page.locator('#pair-two .pair-one[data-side="0"] .pair-keep').click();
      presses += 1;
      await page.waitForFunction((was) => {
        const two = document.getElementById("pair-two");
        return two.dataset.state !== "choosing" || two.querySelector('.pair-one[data-side="1"]')?.dataset.entry !== was;
      }, before, { timeout: 10000 });
      now = await pairNow(page);
      if (now.state === "choosing") {
        check(`at ${width}: This one keeps "${kept}" where it was and brings ${now.sides[1].id} beside it (${now.said})`,
          now.sides[0].id === kept && !seen.has(now.sides[1].id));
        seen.add(now.sides[1].id);
      }
    }
    check(`at ${width}: after ${presses} presses all four seen, one chosen (${now.said})`, presses === 3 && seen.size === 4
      && now.state === "chosen" && now.sides.length === 1 && now.sides[0].id === kept);
    check(`at ${width}: then "${now.vote}"`, /^Vote for “.+”$/.test(now.vote));
    names = await namesIn(page);
    check(`at ${width}: still no maker's name (${names.join("; ") || "none"})`, !names.length);
    if (phone) await shot(page, `pair-chosen-${width}.png`);
    // Signed out: Vote asks to sign in.
    await page.locator("#pair-vote").click();
    const asked = await page.waitForSelector("dialog[open]", { timeout: 10000 }).then(() => true, () => false);
    check(`at ${width}: signed out, Vote asks to sign in`, asked);
    await page.keyboard.press("Escape");
    // See every entry: the cards again.
    await page.locator("#pair-back").click();
    await page.waitForSelector("#groups:not([hidden]) .model[data-entry]", { timeout: 10000 });
    check(`at ${width}: See every entry, the cards again (${await page.evaluate(() => location.search) || "no ?pair"})`,
      !/pair=/.test(await page.evaluate(() => location.search)));
    await ctx.close();
  }

  // --- 2. A vote cast from the pair, with a vote to cast -------------------
  console.log("2. at 390: a vote cast two at a time");
  {
    const voted = [];
    const you = { voted: {}, entries: [], may_vote: true };
    const ctx = await context({ width: 390, height: 844, phone: true, you, voted });
    const page = await ctx.newPage();
    listen(page, "vote");
    await page.goto(`${site}/challenge?pair=assistant`, { waitUntil: "load" });
    await page.waitForSelector("#pair:not([hidden]) .pair-one", { timeout: 30000 });
    let now = await pairNow(page);
    check(`the address opens it at the group asked (${now.sides.map((one) => one.id).join(", ")}, with the assistant)`,
      now.sides.length === 2 && now.sides.every((one) => entries.some((entry) => entry.id === one.id && entry.way === "assistant")));
    const liked = now.sides[1].id;
    await page.locator('#pair-two .pair-one[data-side="1"] .pair-keep').click();
    await page.waitForFunction(() => document.getElementById("pair-two").dataset.state === "chosen", null, { timeout: 10000 });
    await page.locator("#pair-vote").click();
    const confirm = page.locator("dialog.vote-confirm[open]");
    await confirm.waitFor({ timeout: 10000 });
    check(`asked once more: "${(await confirm.locator("h2").textContent()).trim()}"`, true);
    await confirm.locator(".cta:not(.ghost)").click();
    await page.waitForFunction(() => document.getElementById("pair-two").dataset.state === "voted", null, { timeout: 10000 });
    now = await pairNow(page);
    check(`cast for the one liked (${JSON.stringify(voted)}), and said (${now.said})`, voted.length === 1
      && voted[0].model === liked && voted[0].challenge === 990001 && /Your vote in this group is for/.test(now.said));
    await ctx.close();
  }

  // --- 3. Its first screen beside the cards', at the same moments ----------
  console.log(`3. LCP two at a time beside the cards, ${ROUNDS} rounds at the same moments`);
  const rounds = [];
  for (let at = 0; at < ROUNDS; at++) {
    for (const [width, height, phone] of [[390, 844, true], [1280, 800, false]]) {
      const pair = await Promise.all(["/challenge?pair=hand", "/challenge"].map(async (address) => {
        const ctx = await context({ width, height, phone });
        const page = await ctx.newPage();
        await page.addInitScript(watchPaint);
        await page.goto(`${site}${address}`, { waitUntil: "load" });
        await page.waitForTimeout(2500);
        const said = await page.evaluate(() => ({ lcp: window.__lcp, cls: window.__cls }));
        await ctx.close();
        return said;
      }));
      rounds.push({ width, pair: pair[0], cards: pair[1] });
    }
  }
  writeFileSync(path.join(out, "lcp.json"), `${JSON.stringify(rounds, null, 1)}\n`);
  for (const width of [390, 1280]) {
    const mine = rounds.filter((one) => one.width === width);
    const lcp = median(mine.map((one) => one.pair.lcp));
    const theirs = median(mine.map((one) => one.cards.lcp));
    const cls = Math.max(...mine.map((one) => one.pair.cls));
    check(`at ${width}: LCP two at a time ${Math.round(lcp)} ms beside the cards' ${Math.round(theirs)} ms (median of ${mine.length}), `
      + `CLS at most ${cls.toFixed(3)}`, lcp <= Math.max(theirs * 1.15, theirs + 150) && cls < 0.1);
  }
} catch (trouble) {
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" ")}`);
  failures += 1;
} finally {
  await browser.close();
}
check(`no script errors (${errors.slice(0, 4).join(" | ") || "none"})`, errors.length === 0);
console.log(failures ? `${failures} FAILED` : "the fan vote two at a time: blind, side by side, one above the other on a phone, cast in one more press");
process.exit(failures ? 1 : 0);
