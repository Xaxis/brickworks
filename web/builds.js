// The gallery's Builds (docs/SOCIAL.md section 7, item 8), its tab at
// /builds (web/gallery.html, which switches between its lists,
// web/gallery.js): everybody's photos of real builds, newest first, a page
// at a time from /api/people?op=builds (api/_builds.js galleryBuilds),
// searched by the name of the model built. Each card is web/card.js's
// buildCardHtml: the photo, the model it was built from (a link to the
// photo on its page), who built it and when, and what they said. Every
// name and word was typed by somebody, so each goes on the page as text
// (card.js escapes what it draws), and a link is built from ids alone.
//
// The page says where it is on <html>: data-builds is "ready" once a page
// is drawn ("none" when there is nothing yet, and the empty tab says what a
// build is and how to add one).
import { buildCard, counted, langAt, say } from "/card.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;

/// The builds' list, as gallery.js [page] switches to it: {q, grid, tests,
/// state(), eager()}.
export function buildsList(page) {
  const { q, grid, tests } = page;
  // A probe's own models are tests, whose builds the list leaves out unless
  // asked: an address with tests=1 asks, and keeps asking.
  const question = (n) => {
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (n > 1) asked.set("page", String(n));
    if (tests) asked.set("tests", "1");
    return asked;
  };
  /// Page [n]'s address: /de/builds?page=2 in German.
  const addressOf = (n) => {
    const query = question(n).toString();
    return `${langAt()}/builds${query ? `?${query}` : ""}`;
  };

  /// Page [n] of the builds, as cards.
  async function load(n) {
    const asked = question(n);
    asked.set("page", String(n));
    const reply = await fetch(`/api/people?op=builds&${asked}`, { headers: { accept: "application/json" } });
    if (reply.status !== 200) throw new Error(String(reply.status));
    const data = await reply.json();
    const eager = page.eager();
    const items = [];
    for (const photo of data.photos || []) {
      if (!photo || !ID.test(String(photo.id)) || !ID.test(String(photo.model))) continue;
      items.push(buildCard(photo, { eager: items.length < eager }));
    }
    return { items, more: Boolean(data.more), data };
  }

  function drawn({ fresh }) {
    const none = !grid.querySelector(".model");
    const searching = Boolean(q.value.trim());
    $("builds-empty").hidden = !none || searching;
    $("nothing").hidden = !none || !searching;
    if (fresh) $("found").textContent = none ? "" : counted(grid.querySelectorAll(".model").length, "build");
    document.documentElement.dataset.builds = none ? "none" : "ready";
  }

  return {
    flag: "builds",
    page: "builds",
    noun: ["build", "builds"],
    tabs: ["builds"],
    tab: () => "builds",
    title: () => say("Builds · Real models built from the Brickworks gallery"),
    search: () => ({ label: say("Search the builds"), placeholder: say("Search builds by the model built") }),
    enter() {},
    leave() {},
    href: addressOf,
    hrefOf: () => addressOf(1),
    asking() {},
    load,
    drawn,
    failed: () => false,
    searching: () => Boolean(q.value.trim()),
    clear() {},
  };
}
