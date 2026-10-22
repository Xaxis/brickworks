// A person's page, /u/<handle> (api/people.js profilePage): Share, and the
// next page of their models without leaving this one.
//
// Share is the phone's own share sheet where there is one, else the page's
// link copied and said so in the toast. Show more asks /api/people for the
// next page of the person's models and puts its cards after these, the
// same cards the server draws (web/card.js); with no script it is a link to
// that page. Hidden until this is here to make them work.
import { modelCard } from "/card.js";
import { toast } from "/kit.js";

const ID = /^[A-Za-z0-9]{10}$/;
const person = document.querySelector(".person[data-handle]");

for (const button of document.querySelectorAll("button[data-share]")) {
  button.hidden = false;
  button.addEventListener("click", async () => {
    const url = button.dataset.share || location.href;
    if (navigator.share && matchMedia("(pointer: coarse)").matches) {
      try {
        await navigator.share({ title: document.title, url });
        return;
      } catch (trouble) {
        if (trouble?.name === "AbortError") return;
      }
    }
    try {
      await navigator.clipboard.writeText(url);
      toast("Link copied");
    } catch {
      toast("Could not copy it: the address is in the bar above");
    }
  });
}

const more = document.querySelector("a[data-more]");
const grid = document.querySelector("[data-models]");
if (more && grid && person) {
  more.addEventListener("click", async (event) => {
    event.preventDefault();
    if (more.getAttribute("aria-disabled") === "true") return;
    more.setAttribute("aria-disabled", "true");
    const page = Number(more.dataset.more);
    const asked = new URLSearchParams({ op: "profile", handle: person.dataset.handle, page: String(page) });
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
    const earned = person.classList.contains("designer");
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
