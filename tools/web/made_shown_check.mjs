// Does anything public say a model was made with the assistant when its
// owner did not choose to show it? (the owner, 2026-11-23;
// supabase/made_with_shown.sql)
//
//   node tools/web/made_shown_check.mjs [--root=DIR]
//
// Against the stand-in database (design_stand_in.mjs), with no browser and
// no network: --root's api/ answering as a deployment does. Two of the
// house's models are tagged ai-designed and described "Designed with the
// assistant.": HouseMod01's owner said nothing, HouseMod02's chose to show
// it. For each, what a stranger is told:
//
//   its page (/m/X): With the assistant among the facts, and the
//     ai-designed tag, on HouseMod02's alone;
//   the viewer's JSON (/api/share?id=X): the tag on HouseMod02's alone;
//   the gallery's JSON (op=list): no card's made_with or ai-designed tag
//     but HouseMod02's; made=assistant lists HouseMod02 and never
//     HouseMod01, and Hand-built lists HouseMod01; tag=ai-designed is
//     made=assistant;
//   the home feed's post (web/home-feed.js postHtml): Designed with the
//     assistant on HouseMod02's, no pill on HouseMod01's, and no Built by
//     hand anywhere, which would tell the two apart.
//
// The house's own words (its descriptions, "Designed with the assistant.")
// are its own, and stay. Exits 1 on any failure.
import * as stand from "./design_stand_in.mjs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(String(args.root || path.join(path.dirname(fileURLToPath(import.meta.url)), "../..")));
const api = path.join(root, "api");
let failed = 0;
const check = (ok, what) => {
  console.log(`${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed++;
};
const QUIET = "HouseMod01";
const SHOWN = "HouseMod02";

console.log(`made shown check: ${root}`);
const facts = (html) => /<ul class="facts pills">[^]*?<\/ul>/.exec(html)?.[0] || "";
const tagLinks = (html) => [...html.matchAll(/href="[^"]*[?&]tag=([^"&]+)/g)].map((m) => decodeURIComponent(m[1]));
for (const [id, shown] of [[QUIET, false], [SHOWN, true]]) {
  const page = await stand.serverPage(api, `/m/${id}?tests=1`);
  const fact = /<li class="pill made"[^>]*>With the assistant<\/li>/.test(facts(page.html));
  const tagged = tagLinks(page.html).includes("ai-designed");
  const keywords = /<meta name="keywords" content="[^"]*ai-designed/.test(page.html);
  check(page.status === 200 && fact === shown && tagged === shown && (shown || !keywords),
    `/m/${id} (${shown ? "shown" : "not shown"}): ${page.status}, the fact ${fact ? "said" : "not said"}, `
    + `the ai-designed tag ${tagged ? "linked" : "not linked"}, in its keywords ${keywords ? "yes" : "no"}`);
  const json = await stand.serverAsk(api, { name: "share", query: { id, tests: "1" } });
  const tags = JSON.parse(json.html || "{}").tags || [];
  check(tags.includes("ai-designed") === shown, `/api/share?id=${id}: its tags ${JSON.stringify(tags)}`);
}

const list = async (query) => JSON.parse((await stand.serverAsk(api, { name: "share",
  query: { op: "list", page: "1", tests: "1", ...query } })).html || "{}");
const all = await list({});
const cards = all.models || [];
const saying = cards.filter((one) => one.id !== SHOWN && (one.made_with || (one.tags || []).some((tag) => tag === "ai-designed" || tag === "brickify")));
const shownCard = cards.find((one) => one.id === SHOWN);
check(cards.length > 0 && saying.length === 0 && shownCard && shownCard.made_with_shown === true
  && shownCard.tags.includes("ai-designed"),
  `the gallery's ${cards.length} cards: ${saying.length} say how they were made but ${SHOWN}'s (${saying.map((one) => one.id).join(", ") || "none"})`);
const ids = async (query) => {
  const found = [];
  for (let page = 1; page <= 20; page++) {
    const answer = await list({ ...query, page: String(page) });
    found.push(...(answer.models || []).map((one) => one.id));
    if (!answer.more) break;
  }
  return found;
};
const helped = await ids({ made: "assistant" });
const byHand = await ids({ made: "hand" });
const byTag = await ids({ tag: "ai-designed" });
check(helped.includes(SHOWN) && !helped.includes(QUIET) && byHand.includes(QUIET) && !byHand.includes(SHOWN),
  `Made: With the assistant lists ${helped.join(", ") || "none"}; Hand-built has ${QUIET} ${byHand.includes(QUIET) ? "in it" : "NOT in it"}`);
check(JSON.stringify(byTag) === JSON.stringify(helped), `tag=ai-designed lists what With the assistant does: ${byTag.join(", ") || "none"}`);

const feed = await import(pathToFileURL(path.join(root, "web/home-feed.js")).href);
const quietCard = cards.find((one) => one.id === QUIET) || { id: QUIET, name: "q", parts: 1, tags: ["ai-designed"], made_with: "assistant" };
const raw = { id: QUIET, name: "Raw", parts: 3, tags: ["ai-designed"], made_with: "assistant" };
const pills = (model) => /<p class="post-made">[^]*?<\/p>/.exec(feed.madeHtml(model))?.[0] || "";
check(!/data-made="(assistant|brickify|hand)"/.test(pills(quietCard)) && !/data-made=/.test(pills(raw))
  && /data-made="assistant"[^>]*>Designed with the assistant</.test(pills(shownCard || {}))
  && !/Built by hand/.test(pills(quietCard) + pills(raw) + pills(shownCard || {})),
  `the feed's pills: ${QUIET} "${pills(quietCard)}", one its API never gated "${pills(raw)}", ${SHOWN} "${pills(shownCard || {})}"`);

console.log(failed ? `made shown check: ${failed} problem(s)` : "made shown check: nothing public says how a model was made unless its owner chose to");
process.exit(failed ? 1 : 0);
