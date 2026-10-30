// A person's page, /u/<handle> (api/people.js profilePage): Share, and the
// next page of their models without leaving this one.
//
// Share opens the page's share sheet (web/share-sheet.js). Show more asks
// /api/people for the next page of the person's models (or of the models
// they liked, on their Likes tab) and puts its cards after these, the same
// cards the server draws (web/card.js); with no script it is a link to
// that page. Hidden until this is here to make them work.
import { modelCard } from "/card.js";
import { toast } from "/kit.js";
import { wireShare } from "/share-sheet.js";

const ID = /^[A-Za-z0-9]{10}$/;
const person = document.querySelector(".person[data-handle]");

// Share opens the page's sheet (web/share-sheet.js): its link, the
// networks to post it to, and the phone's own sheet where there is one.
const sheet = document.getElementById("share-sheet");
for (const button of document.querySelectorAll("button[data-share]")) if (sheet) wireShare(button, sheet);

const more = document.querySelector("a[data-more]");
const grid = document.querySelector("[data-models]");
if (more && grid && person) {
  more.addEventListener("click", async (event) => {
    event.preventDefault();
    if (more.getAttribute("aria-disabled") === "true") return;
    more.setAttribute("aria-disabled", "true");
    const page = Number(more.dataset.more);
    const liked = grid.closest("[data-panel]")?.dataset.panel === "likes";
    const asked = new URLSearchParams({ op: liked ? "likes" : "profile", handle: person.dataset.handle, page: String(page) });
    const tests = new URLSearchParams(location.search).get("tests");
    if (tests) asked.set("tests", tests);
    let body = null;
    try {
      const answer = await fetch(`/api/people?${asked}`);
      body = answer.ok ? await answer.json() : null;
    } catch {
      body = null;
    }
    more.removeAttribute("aria-disabled");
    // Not this time: the link still goes to that page.
    if (!body || !Array.isArray(body.models)) {
      toast("That did not load just now. Try again in a minute.");
      return;
    }
    const earned = !liked && person.classList.contains("designer");
    const cards = body.models.filter((model) => ID.test(String(model.id))).map((model) => modelCard(model, { earned }));
    grid.append(...cards);
    grid.dataset.page = String(page);
    if (body.more) {
      more.dataset.more = String(page + 1);
      const next = new URL(more.href, location.href);
      next.searchParams.set("page", String(page + 1));
      more.href = next.pathname + next.search;
    } else {
      more.remove();
    }
    // A keyboard is taken to the first new card, not left at the end.
    cards[0]?.focus({ preventScroll: true });
  });
}
