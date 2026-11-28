// First steps' step 3 (web/first-steps.js suggestionsFor): a newcomer who
// chose castles is shown castles first, as Top builds ranks them among
// castles, and not only the few on Top's first page (greenreds2: live's
// first page held 3 of its 7 castles, then a robot and a space ship).
// node --test tests/web/first_steps.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// The page's module imports the site's own by their absolute paths, which
// only a browser resolves; suggestionsFor needs none of them.
const source = readFileSync(new URL("../../web/first-steps.js", import.meta.url), "utf8").replace(/^import .*$/gm, "");
const { suggestionsFor } = await import(`data:text/javascript,${encodeURIComponent(source)}`);

const SCORE = { builds: 3, remixes: 2, tested: 5 };
const card = (id, kind, extra = {}) => ({ id, kind, by: { handle: extra.who || "house" }, builds: 0, remixes: 0,
  tested: true, listed_at: "2026-11-01T00:00:00Z", ...extra });
const ids = (list) => list.map((one) => one.id);
// Top's first page as live's was: three castles among the rest.
const top = [card("robot", "robot"), card("ship", "space"), card("dragon", "castle"), card("tower", "castle"),
  card("castle", "castle"), card("cactus", "nature"), card("fox", "nature")];
const castles = ["dragon", "tower", "castle", "kings", "outpost", "monarch", "defender"].map((id) => card(id, "castle"));

test("nothing chosen: Top's own order", () => {
  assert.deepEqual(ids(suggestionsFor({ cards: top, score: SCORE }, []).models),
    ["robot", "ship", "dragon", "tower", "castle", "cactus"]);
});

test("castles chosen: six castles from their own Top, none of the rest while castles remain", () => {
  assert.deepEqual(ids(suggestionsFor({ cards: top, ofKinds: { castle: castles }, score: SCORE }, ["castle"]).models),
    ["dragon", "tower", "castle", "kings", "outpost", "monarch"]);
});

test("their list unanswered: Top's first page's castles, then the rest", () => {
  assert.deepEqual(ids(suggestionsFor({ cards: top, ofKinds: { castle: null }, score: SCORE }, ["castle"]).models),
    ["dragon", "tower", "castle", "robot", "ship", "cactus"]);
});

test("two kinds taken together in Top's order, each kind's own order kept", () => {
  const nature = [card("fox", "nature", { builds: 1 }), card("cactus", "nature"), card("owl", "nature")];
  assert.deepEqual(ids(suggestionsFor({ cards: top, ofKinds: { castle: castles.slice(0, 2), nature }, score: SCORE },
    ["castle", "nature"]).models), ["fox", "dragon", "tower", "cactus", "owl", "robot"]);
});

test("a designer with a castle among the ones to follow before one with none", () => {
  const ada = card("ada", "castle", { who: "ada", builds: 2, tested: false, listed_at: "2026-11-28T00:00:00Z" });
  const found = { designers: [{ handle: "house" }, { handle: "bill" }, { handle: "ada" }, { handle: "zed" }], cards: top,
    ofKinds: { castle: [ada, ...castles] }, score: SCORE };
  const { designers, models } = suggestionsFor(found, ["castle"]);
  assert.deepEqual(designers.map((one) => one.handle), ["house", "ada", "bill"]);
  assert.deepEqual(ids(models).slice(0, 2), ["ada", "dragon"]);
});
