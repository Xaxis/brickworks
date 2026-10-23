// Is a model's card the same markup from the server as from the browser?
// (web/card.js, docs/SOCIAL.md U2)
//
//   node tools/web/card_check.mjs [--root=DIR]
//
// There were three card renderers, and they differed: the server's had no
// Moves line and showed Tested only on a designer's page, and a model's
// remixes had a small card of their own. Now there is one, web/card.js,
// which the server's pages draw with (through api/_card.js) and the
// browser's. This proves the two agree where it matters, in a browser:
//
//   the collection page /c/<id> as --root's api/people.js makes it, its
//     cards read by the browser's own HTML parser, against the cards the
//     browser draws itself with /card.js from the same handler's JSON
//     (?op=collection&id=), card by card;
//   and a set of cards with everything a card can say (owned, won, moves,
//     motions, Tested, made with the assistant, its designer's avatar and
//     link, comments, a like that is a button and pressed, no picture, a
//     name with markup and quotes in it, a designer's earned card), drawn by
//     the module the server imports and by the browser's /card.js.
//
// Fails on any card that differs, or when no card was compared. Needs no
// network: the site is served from --root's web/ and api/ as
// design_flow.mjs serves it (design_stand_in.mjs).
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(String(args.root || path.resolve(here, "../..")));
const web = path.join(root, "web");
const api = path.join(root, "api");

let failed = 0;
let compared = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};

// Cards with everything a card can say, and words that must stay words.
const SAMPLES = [
  [{ id: "CardAbcde1", name: "Wizard's <b>Tower</b> & \"keep\"", parts: 9541, author: "Robin <i>C</i>",
    thumb: "/m/CardAbcde1.webp?v=k2x9", views: 3, likes: 12, remixes: 2, builds: 4, tested: true,
    moves: ["door", "drawbridge"], motions: ["Open the gate", "LED blink", "Raise it", "Lower it"],
    won: [{ title: "October: <things> that move", way: "hand" }], owned: { pieces: 9541, have: 4000 } }, {}],
  [{ id: "CardAbcde2", name: "No picture", parts: 1, author: "", views: 0, likes: 0 }, {}],
  [{ id: "CardAbcde3", name: "Sports car", parts: 187, author: "Sam", image: "/m/CardAbcde3.png",
    owned: { pieces: 187, have: 187 }, moves: ["steering"] }, {}],
  [{ id: "CardAbcde4", name: "Designer's own", parts: 640, author: "Dana", thumb: "/m/CardAbcde4.webp",
    views: 90, likes: 5, remixes: 1, builds: 7, comments: 3, tested: true }, { earned: true }],
  [{ id: "CardAbcde5", name: "Liked, from the gallery", parts: 412, author: "Robin Castell", thumb: "/m/CardAbcde5.webp",
    likes: 97, liked: true, builds: 37, comments: 3, tags: ["castle", "ai-designed"],
    by: { handle: "robin-castell", name: "Robin <Castell>" } }, { like: true }],
  [{ id: "CardAbcde6", name: "A handle that is not one", parts: 9, author: "Eve", by: { handle: "../admin", name: "Eve" },
    tags: ["brickify"] }, { like: true }],
  // Its designer's own picture (supabase/avatars.sql), and one from
  // anywhere else, which is never drawn: the tile is.
  [{ id: "CardAbcde7", name: "With a face", parts: 88, author: "Robin Castell", thumb: "/m/CardAbcde7.webp",
    by: { handle: "robin-castell", name: "Robin Castell", picture: "/api/people?op=avatar&id=FaceRobin1" } }, {}],
  [{ id: "CardAbcde8", name: "A face from elsewhere", parts: 88, author: "Mallory", thumb: "/m/CardAbcde8.webp",
    by: { handle: "mallory-m", name: "Mallory", picture: "https://tracker.example/pixel.png" } }, {}],
];

const cardsOf = (html) => [...html.matchAll(/<article class="model"[\s\S]*?<\/article>/g)].map((m) => m[0]);

console.log(`card check: ${root}`);
const browser = await launch({ signedOut: true });
try {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await stand.serveSite(context, { web, api });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
  await page.goto(`${stand.ORIGIN}/404`, { waitUntil: "load" });
  // Markup as a browser reads it: parsed, then said again.
  const parsed = (html) => page.evaluate((text) => {
    const made = document.createElement("template");
    made.innerHTML = text;
    return [...made.content.children].map((el) => el.outerHTML);
  }, html);
  const drawn = (models, options) => page.evaluate(async ([list, opts]) => {
    const { modelCard } = await import("/card.js");
    return list.map((model) => modelCard(model, opts).outerHTML);
  }, [models, options]);

  // 1. A page the server made, against the browser's drawing of its data.
  const made = await stand.serverPage(api, `/c/${stand.LIST_ID}`);
  const listed = await stand.serverAsk(api, { name: "people", query: { op: "collection", id: stand.LIST_ID } });
  const models = JSON.parse(listed.html || "{}").models || [];
  const fromServer = await parsed(cardsOf(made.html).join(""));
  const fromBrowser = await drawn(models, {});
  check(made.status === 200 && fromServer.length > 0, `/c/${stand.LIST_ID}: the server made ${fromServer.length} cards`);
  check(fromServer.length === fromBrowser.length,
    `the browser drew ${fromBrowser.length} cards from ?op=collection, the page has ${fromServer.length}`);
  fromServer.forEach((card, at) => {
    compared += 1;
    const id = /data-id="([^"]+)"/.exec(card)?.[1];
    check(card === fromBrowser[at], `card ${id}: the server's markup is the browser's`
      + (card === fromBrowser[at] ? "" : `\n        server:  ${card}\n        browser: ${fromBrowser[at]}`));
  });

  // 2. Everything a card can say, by the module the server imports and by
  //    the browser's /card.js.
  const { cardHtml } = await import(pathToFileURL(path.join(api, "_card.js")).href);
  for (const [model, options] of SAMPLES) {
    compared += 1;
    const [server] = await parsed(cardHtml(model, options));
    const [browserMade] = await drawn([model], options);
    check(server === browserMade, `sample ${model.id}${options.earned ? " (earned)" : options.like ? " (a like button)" : ""}: the same markup`
      + (server === browserMade ? "" : `\n        server:  ${server}\n        browser: ${browserMade}`));
  }
  // Words stay words: a name's markup is text on the card.
  const [risky] = await drawn([SAMPLES[0][0]], {});
  check(!/<b>Tower<\/b>|<i>C<\/i>/.test(risky) && /&lt;b&gt;Tower/.test(risky), "a name's markup is shown as words");
  // A designer's link only from a handle that is one; their name as words.
  const [linked, odd] = await drawn([SAMPLES[4][0], SAMPLES[5][0]], { like: true });
  check(/href="\/u\/robin-castell"/.test(linked) && /Robin &lt;Castell&gt;/.test(linked) && /aria-pressed="true"/.test(linked)
    && !/href="\/u\//.test(odd) && /Brickify/.test(odd), "a designer's link from a handle alone, their name as words, a liked heart pressed");
  // Their own picture only from this site's address for one.
  const [face, elsewhere] = await drawn([SAMPLES[6][0], SAMPLES[7][0]], {});
  check(/class="avatar small c\d pictured"[^>]*><img src="\/api\/people\?op=avatar&amp;id=FaceRobin1"/.test(face)
    && !/<img[^>]*tracker\.example/.test(elsewhere) && />M<\/span>/.test(elsewhere),
  "a designer's own picture drawn, and one from anywhere else never: the tile");
  check(!errors.length, `no script errors${errors.length ? `: ${errors.join("; ")}` : ""}`);
} finally {
  await browser.close();
}
console.log(`\ncard check: ${compared} cards compared, ${failed} failed`);
process.exit(failed || !compared ? 1 : 0);
