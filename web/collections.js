// The gallery's Collections (W12, supabase/collection_directory.sql), its
// tab at /collections (web/gallery.html, which switches between its lists,
// web/gallery.js): the public collections anyone may see, the way
// Printables lists its collections, Rebrickable its MOC lists and Flickr
// its albums. What was put in last first, or the most followed; searched
// by their names, their words and whose they are
// (supabase/collection_search.sql); a page of 24 at a time from
// /api/people?op=collections (api/people.js).
//
// Each card is web/card.js's collectionCardHtml, the model card's shape:
// its cover (up to four of its models' pictures), its name, whose, how many
// models and followers, and Follow (web/follow.js wires a page of them,
// all asked in one go, as the pager puts them in). A private collection
// never; nor one with nothing in the gallery, which would be a blank card.
// Every name was typed by somebody: text, never markup.
import { collectionCard, counted, langAt, say } from "/card.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const ORDERS = ["recent", "followed"];

/// The collections' list, as gallery.js [page] switches to it: {q, grid,
/// tests, ask(), state(), eager()}.
export function collectionsList(page) {
  const { q, grid, tests } = page;
  // What was put in last first, the default, or the most followed.
  let order = "recent";
  // Whether the list could search them: before collection_search.sql it
  // lists them all, and says so.
  let searchable = true;
  const question = (n) => {
    const asked = new URLSearchParams();
    const words = q.value.trim().slice(0, 100);
    if (words) asked.set("q", words);
    if (order !== "recent") asked.set("sort", order);
    if (n > 1) asked.set("page", String(n));
    if (tests) asked.set("tests", "1");
    return asked;
  };
  /// Page [n]'s address: /de/collections?sort=followed in German.
  const addressOf = (n) => {
    const query = question(n).toString();
    return `${langAt()}/collections${query ? `?${query}` : ""}`;
  };

  function drawOrders() {
    for (const pill of document.querySelectorAll("#orders [data-order]")) {
      pill.setAttribute("aria-pressed", String(pill.dataset.order === order));
    }
  }

  /// Page [n] of the collections, as cards.
  async function load(n) {
    const asked = question(n);
    asked.set("page", String(n));
    const reply = await fetch(`/api/people?op=collections&${asked}`, { headers: { accept: "application/json" } });
    if (reply.status !== 200) throw new Error(String(reply.status));
    const data = await reply.json();
    const eager = page.eager();
    const items = [];
    for (const list of data.collections || []) {
      if (!list || !ID.test(String(list.id))) continue;
      items.push(collectionCard(list, { eager: items.length < eager }));
    }
    return { items, pages: Number(data.pages) || 1, total: Number(data.total) || 0, data };
  }

  function drawn({ answer, fresh }) {
    const none = !grid.querySelector(".model");
    const searching = Boolean(q.value.trim());
    searchable = answer.data?.searched !== false;
    $("collections-empty").hidden = !none || searching;
    $("nothing").hidden = !none || !searching;
    if (fresh) {
      $("found").textContent = none ? "" : counted(Number(answer.data?.total) || grid.querySelectorAll(".model").length, "collection");
      $("found-said").textContent = !searchable && searching ? say("Collections cannot be searched just yet: here are all of them.") : "";
    }
    drawOrders();
    document.documentElement.dataset.collections = none ? "none" : "ready";
  }

  $("orders").addEventListener("click", (event) => {
    const pill = event.target.closest("[data-order]");
    if (!pill || !ORDERS.includes(pill.dataset.order)) return;
    order = pill.dataset.order;
    page.ask();
  });

  return {
    flag: "collections",
    page: "collections",
    noun: ["collection", "collections"],
    tabs: ["collections"],
    tab: () => "collections",
    title: () => say("Collections — the Brickworks gallery"),
    search: () => ({ label: say("Search the collections"), placeholder: say("Search collections by name or builder") }),
    enter(given) {
      order = given.get("sort") === "followed" ? "followed" : "recent";
      drawOrders();
    },
    leave() {},
    href: addressOf,
    hrefOf: () => addressOf(1),
    asking: drawOrders,
    load,
    drawn,
    failed: () => false,
    searching: () => Boolean(q.value.trim()),
    clear() {},
  };
}
