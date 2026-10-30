// The gallery's Builds tab, /builds (web/builds.html; docs/SOCIAL.md
// section 7, item 8): everybody's photos of real builds, newest first, a
// page at a time from /api/people?op=builds (api/_builds.js galleryBuilds),
// paged as every list of the site is (web/pager.js). Each card is
// web/card.js's buildCardHtml: the photo, the model it was built from (a
// link to the photo on its page), who built it and when, and what they
// said. Every name and word was typed by somebody, so each goes on the
// page as text (card.js escapes what it draws), and a link is built from
// ids alone.
//
// The page says where it is on <html>: data-builds is "ready" once a page
// is drawn ("none" when there is nothing yet, and the empty tab says what a
// build is and how to add one) or "broken" when the list did not come.
import { FIRST_SCREEN, buildCard, counted, skeletonHtml } from "/card.js";
// "/" to search the gallery.
import { browseBar } from "/browse.js";
import { pageAsked, pager } from "/pager.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const list = $("builds");
// A probe's own models are tests, whose builds the list leaves out unless
// asked: an address with tests=1 asks, and keeps asking.
const tests = new URLSearchParams(location.search).get("tests") === "1";
const addressOf = (n) => {
  const asked = new URLSearchParams();
  if (n > 1) asked.set("page", String(n));
  if (tests) asked.set("tests", "1");
  const query = asked.toString();
  return query ? `/builds?${query}` : "/builds";
};

/// Page [n] of the builds, as cards.
async function load(n) {
  const reply = await fetch(`/api/people?op=builds&page=${n}${tests ? "&tests=1" : ""}`, { headers: { accept: "application/json" } });
  if (reply.status !== 200) throw new Error(String(reply.status));
  const data = await reply.json();
  // As many pictures asked for at once as the first screen shows.
  const first = document.documentElement.dataset.builds === undefined;
  const eager = first ? [...list.children].filter((one) => one.getBoundingClientRect().top < innerHeight).length
    || FIRST_SCREEN : 0;
  const items = [];
  for (const photo of data.photos || []) {
    if (!photo || !ID.test(String(photo.id)) || !ID.test(String(photo.model))) continue;
    items.push(buildCard(photo, { eager: items.length < eager }));
  }
  return { items, more: Boolean(data.more), data };
}

function drawn({ fresh }) {
  const none = !list.querySelector(".model");
  $("loading").hidden = true;
  $("broken").hidden = true;
  $("builds-empty").hidden = !none;
  $("builds-said").hidden = none;
  if (fresh) $("found").textContent = none ? "" : counted(list.querySelectorAll(".model").length, "build");
  document.documentElement.dataset.builds = none ? "none" : "ready";
}

function failed({ fresh }) {
  if (!fresh) return;
  for (const bones of list.querySelectorAll(".skeleton")) bones.remove();
  $("loading").hidden = true;
  $("broken").hidden = false;
  document.documentElement.dataset.builds = "broken";
}

const paged = pager({ list, load, href: addressOf, noun: ["build", "builds"], drawn, failed,
  skeleton: () => {
    const made = document.createElement("template");
    made.innerHTML = skeletonHtml();
    return made.content.firstElementChild;
  } });

$("retry").addEventListener("click", () => {
  $("broken").hidden = true;
  $("loading").hidden = false;
  paged.start(pageAsked(location.search), { restore: false });
});
browseBar({ search: $("q"), above: null, bar: null });
paged.start(pageAsked(location.search));
