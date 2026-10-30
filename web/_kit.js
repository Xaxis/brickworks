// The kit page's specimens (web/_kit.html), drawn as the pages draw them.
import { cardHtml } from "/card.js";
import { ICONS, avatarHtml, iconButtonHtml, iconHtml, toast } from "/kit.js";

const $ = (id) => document.getElementById(id);
const people = [{ handle: "robin", name: "Robin Castell" }, { handle: "sam-builds", name: "Sam" },
  { handle: "dana", name: "Dana" }, { handle: "lee", name: "Lee" }];
$("avatars").innerHTML = [["small"], [""], ["big"], ["huge"]]
  .map(([size], at) => avatarHtml(people[at], { size })).join("");
// One avatar of each of the eight colours, whichever handles give them.
const tones = new Map();
for (let n = 0; tones.size < 8 && n < 500; n += 1) {
  const html = avatarHtml({ handle: `person-${n}`, name: String.fromCharCode(65 + tones.size) });
  const tone = /c(\d)/.exec(html)[1];
  if (!tones.has(tone)) tones.set(tone, html);
}
$("tones").innerHTML = [...tones.keys()].sort().map((tone) => tones.get(tone)).join("");
$("icon-buttons").innerHTML = [
  iconButtonHtml({ icon: "like", name: "Like", count: 12, one: "like", pressed: false }),
  iconButtonHtml({ icon: "like", name: "Like", count: 13, one: "like", pressed: true }),
  iconButtonHtml({ icon: "save", name: "Save", pressed: false }),
  iconButtonHtml({ icon: "share", name: "Share" }),
  iconButtonHtml({ icon: "comment", name: "Comments", count: 3, one: "comment" }),
  iconButtonHtml({ icon: "build", name: "I built it", count: 4, one: "build" }),
].join("");
$("icon-buttons-small").innerHTML = ICONS.map((icon) => iconButtonHtml({ icon, name: icon, small: true })).join("");
$("more").querySelector("summary").innerHTML = iconHtml("more");
$("copy").addEventListener("click", () => toast("Link copied"));
$("cards").innerHTML = [
  { id: "KitModel01", name: "Wizard's Tower", parts: 9541, author: "Robin Castell", thumb: "x", builds: 4, likes: 12,
    tested: true, moves: ["door"], motions: ["Open the gate"] },
  { id: "KitModel02", name: "A name long enough to need its second line on a narrow card", parts: 1, author: "", views: 0 },
  { id: "KitModel03", name: "Sports car", parts: 187, author: "Sam", image: "x", owned: { pieces: 187, have: 120 },
    won: [{ title: "October: things that move", way: "hand" }] },
].map((model) => cardHtml(model)).join("");
// A row of eight, more than any window shows: the scroller's fades and its
// Previous and Next.
$("row").innerHTML = Array.from({ length: 8 }, (_, n) => cardHtml({ id: `KitRow0${n}`, name: `Model ${n + 1} in a row`,
  parts: 120 + 37 * n, author: people[n % 4].name })).join("");
