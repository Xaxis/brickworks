// The owner's choice of whether a model's page says how it was made, in a
// browser (the owner, 2026-11-23; supabase/made_with_shown.sql).
//
//   node tools/web/made_shown_flow.mjs [--root=DIR] [--out=DIR]
//
// On the stand-in (design_stand_in.mjs), served from --root's web/ and
// api/: Sam's Harbour Tram was laid with the assistant, as its app said,
// and Sam has not chosen to show it.
//
//   1. a stranger opens /m/SamModel01: no With the assistant among its
//      facts, and the gallery's Made: With the assistant does not list it;
//   2. Sam, signed in, opens it: More has Say it was made with the
//      assistant; pressed, the fact is there at once, and More says Stop
//      saying it was made with the assistant;
//   3. the stranger opens it again: the fact is there, and With the
//      assistant lists it;
//   4. Sam presses Stop saying it: the fact goes, and the stranger's page
//      and list say nothing again.
//
// Pictures of each at 1280 in --out. Exits 1 on any failure.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(String(args.root || path.join(path.dirname(fileURLToPath(import.meta.url)), "../..")));
const out = path.resolve(String(args.out || "shots/made_shown"));
mkdirSync(out, { recursive: true });
const ID = "SamModel01";
let failed = 0;
const check = (ok, what) => {
  console.log(`${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed++;
};
const errors = [];

const browser = await launch({ signedOut: true });
try {
  const contextOf = async (signedIn) => {
    const made = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    await stand.serveSite(made, { web: path.join(root, "web"), api: path.join(root, "api") });
    if (signedIn) {
      const kept = stand.signedInStorage();
      await made.addInitScript(([session, access]) => {
        try {
          if (!localStorage.getItem("brickworks.session")) localStorage.setItem("brickworks.session", session);
          sessionStorage.setItem("brickworks.access", access);
        } catch {}
      }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
    }
    const page = await made.newPage();
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    return page;
  };
  const stranger = await contextOf(false);
  const sam = await contextOf(true);
  const fact = async (page) => page.evaluate(() => document.querySelector("ul.facts.pills li.pill.made")?.textContent || "");
  const listed = async (page) => {
    const answer = await page.evaluate(async () => (await fetch("/api/share?op=list&page=1&made=assistant&tests=1")).json());
    return (answer.models || []).map((one) => one.id);
  };
  const look = async (name) => {
    await stranger.goto(`${stand.ORIGIN}/m/${ID}?tests=1`, { waitUntil: "load" });
    await stranger.waitForTimeout(1200);
    await stranger.screenshot({ path: path.join(out, `${name}-1280.png`) });
    return { fact: await fact(stranger), listed: (await listed(stranger)).includes(ID) };
  };
  const choice = async () => {
    await sam.locator("#more summary").click();
    const item = sam.locator("#more [data-made-choice]");
    await item.waitFor({ state: "visible", timeout: 20000 }).catch(() => {});
    return item;
  };

  let seen = await look("1-stranger-before");
  check(!seen.fact && !seen.listed, `1. a stranger: the fact "${seen.fact}", With the assistant lists it: ${seen.listed}`);

  await sam.goto(`${stand.ORIGIN}/m/${ID}?tests=1`, { waitUntil: "load" });
  await sam.waitForFunction(() => document.documentElement.dataset.modelOwner === "yes", null, { timeout: 30000 }).catch(() => {});
  let item = await choice();
  const offered = await item.textContent().catch(() => "");
  await sam.screenshot({ path: path.join(out, "2-owner-more-1280.png") });
  check(offered === "Say it was made with the assistant", `2. Sam's More offers "${offered}"`);
  await item.click().catch(() => {});
  await sam.waitForFunction(() => Boolean(document.querySelector("ul.facts.pills li.pill.made")), null, { timeout: 20000 }).catch(() => {});
  const ownFact = await fact(sam);
  item = await choice();
  const now = await item.textContent().catch(() => "");
  await sam.screenshot({ path: path.join(out, "2-owner-shown-1280.png") });
  await sam.keyboard.press("Escape");
  check(ownFact === "With the assistant" && now === "Stop saying it was made with the assistant",
    `2. pressed: the fact "${ownFact}" at once, More now "${now}"`);

  seen = await look("3-stranger-shown");
  check(seen.fact === "With the assistant" && seen.listed, `3. a stranger again: the fact "${seen.fact}", listed: ${seen.listed}`);

  await sam.goto(`${stand.ORIGIN}/m/${ID}?tests=1`, { waitUntil: "load" });
  await sam.waitForFunction(() => document.documentElement.dataset.modelOwner === "yes", null, { timeout: 30000 }).catch(() => {});
  item = await choice();
  await item.click().catch(() => {});
  await sam.waitForFunction(() => !document.querySelector("ul.facts.pills li.pill.made"), null, { timeout: 20000 }).catch(() => {});
  const gone = await fact(sam);
  seen = await look("4-stranger-after");
  check(!gone && !seen.fact && !seen.listed, `4. Stop saying it: Sam's fact "${gone}", the stranger's "${seen.fact}", listed: ${seen.listed}`);
  check(!errors.length, `no page errors${errors.length ? `: ${errors.slice(0, 3).join(" | ")}` : ""}`);
} finally {
  await browser.close();
}
console.log(failed ? `made shown flow: ${failed} problem(s); pictures in ${out}` : `made shown flow: the owner's choice, said and taken back; pictures in ${out}`);
process.exit(failed ? 1 : 0);
