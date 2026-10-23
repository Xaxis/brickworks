// First steps (docs/SOCIAL.md U10, D12): what a person is offered after
// their first sign-in, once the age question says they are 13 or over
// (web/account.js askAgeIfAsked). Three steps in one dialog, each skippable:
//
//   1. Make your profile: a name and a handle, the avatar made from the
//      handle drawn as they type (left out when they have one already).
//   2. What do you build?: the gallery's kinds as pills, chosen or not.
//   3. Designers and models to start with: up to three designers to follow,
//      by Top builds and the kinds chosen first, and six models to open.
//
// The kinds chosen only order what step 3 suggests: nothing of them is
// kept, here or on the server (D13). Following a designer here is the
// Follow of everywhere else (web/follow.js), so what they make fills the
// feed; "See your feed" ends it there, unless the person signed in to do
// something on this page (a like, a comment), which then goes on as before.
//
// Every word is put on the page as text; a card and an avatar are the
// kit's, which escape their own.
import { call } from "/account.js";
import { followButton, showFeedCount } from "/follow.js";
import { avatarHtml, modelCard } from "/card.js";

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
// How many of each step 3 suggests.
const DESIGNERS = 3;
const MODELS = 6;

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

function button(words, className, type = "button") {
  const made = make("button", className, words);
  made.type = type;
  return made;
}

const parsed = (html) => {
  const made = document.createElement("template");
  made.innerHTML = html;
  return made.content.firstElementChild;
};

/// A handle made from a name, as a person would type one: "Sam Okafor" is
/// sam-okafor. "" when the name makes none (3 characters at the least).
export function handleFrom(name) {
  const made = String(name || "").normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+/, "").slice(0, 24).replace(/-+$/, "");
  return HANDLE.test(made) ? made : "";
}

/// What step 3 suggests, from the feed's designers (by Top builds) and Top
/// builds' cards: the designers with most models of [kinds] first, then as
/// they came; the models of [kinds] first, then the rest, each list as
/// Top builds ranked it. Pure.
export function suggestionsFor({ designers = [], cards = [] }, kinds = []) {
  const wanted = new Set(kinds);
  const ofKind = (card) => wanted.has(String(card.kind || ""));
  const matches = new Map();
  for (const card of cards) {
    const handle = card?.by?.handle;
    if (handle && ofKind(card)) matches.set(handle, (matches.get(handle) || 0) + 1);
  }
  const people = designers.filter((one) => one && HANDLE.test(String(one.handle || "")))
    .map((one, at) => ({ one, at, n: matches.get(one.handle) || 0 }))
    .sort((a, b) => b.n - a.n || a.at - b.at).slice(0, DESIGNERS).map(({ one }) => one);
  const models = [...cards.filter(ofKind), ...cards.filter((card) => !ofKind(card))]
    .filter((card) => card && card.id).slice(0, MODELS);
  return { designers: people, models };
}

/// Opens First steps over the page. [pending]: the person signed in to do
/// something here, so the end goes back to it rather than to the feed.
/// Resolves when it is closed, however it is.
export function firstSteps({ pending = false } = {}) {
  return new Promise((done) => {
    const tests = new URLSearchParams(location.search).get("tests") === "1" ? "tests=1" : "";
    const dialog = make("dialog", "first-steps");
    dialog.setAttribute("aria-labelledby", "first-steps-title");
    const count = make("p", "eyebrow");
    const title = make("h2", "");
    title.id = "first-steps-title";
    const body = make("div", "step");
    dialog.append(count, title, body);
    document.body.append(dialog);
    let finished = false;
    const end = () => {
      if (finished) return;
      finished = true;
      dialog.close();
      dialog.remove();
      showFeedCount().catch(() => null);
      done();
    };
    dialog.addEventListener("cancel", end);

    // What the steps need, asked at once: whether you have a profile, the
    // gallery's kinds and Top builds' cards, and the designers to follow.
    const me = call("/api/people?op=me").catch(() => null);
    const top = call(`/api/share?op=list&sort=top${tests ? `&${tests}` : ""}`).catch(() => null);
    const latest = call(`/api/people?op=latest${tests ? `&${tests}` : ""}`).catch(() => null);
    let chosen = [];
    let steps = [];

    const show = (at) => {
      const step = steps[at];
      count.textContent = steps.length > 1 ? `First steps · ${at + 1} of ${steps.length}` : "First steps";
      title.textContent = step.title;
      dialog.dataset.step = step.id;
      body.replaceChildren();
      step.draw(body, () => (at + 1 < steps.length ? show(at + 1) : end()));
    };

    // 1. A name and a handle.
    const profileStep = { id: "profile", title: "Make your profile", draw(into, next) {
      const said = make("p", "", "A name and a handle, and the models you share have a page of your own. "
        + "Your picture is made from your handle.");
      const form = make("form", "profile-start");
      const face = make("div", "face-row");
      let avatar = parsed(avatarHtml({ handle: "", name: "?" }, { size: "big" }));
      const address = make("p", "", "brickworks.diy/u/", make("b", "", "your-handle"));
      face.append(avatar, address);
      const name = make("input");
      name.id = "first-name";
      name.maxLength = 40;
      name.autocomplete = "nickname";
      const handle = make("input");
      handle.id = "first-handle";
      handle.maxLength = 24;
      handle.autocapitalize = "none";
      handle.spellcheck = false;
      // The handle follows the name until it is typed in itself.
      let typed = false;
      const redraw = () => {
        const shown = handle.value.trim().toLowerCase();
        address.lastChild.textContent = shown || "your-handle";
        const fresh = parsed(avatarHtml({ handle: shown, name: name.value.trim() || "?" }, { size: "big" }));
        avatar.replaceWith(fresh);
        avatar = fresh;
      };
      name.addEventListener("input", () => {
        if (!typed) handle.value = handleFrom(name.value);
        redraw();
      });
      handle.addEventListener("input", () => {
        typed = handle.value !== "";
        redraw();
      });
      const nameLabel = make("label", "", "Name", name);
      const handleLabel = make("label", "", "Handle ", make("small", "", "3 to 24 of a-z, 0-9 and hyphens"), handle);
      const note = make("p", "said");
      note.setAttribute("role", "status");
      const go = button("Make my profile", "cta", "submit");
      go.id = "first-make";
      const skip = button("Skip", "cta ghost");
      skip.id = "first-skip";
      skip.addEventListener("click", next);
      form.append(face, nameLabel, handleLabel, make("div", "actions", go, skip), note);
      form.addEventListener("submit", async (event) => {
        event.preventDefault();
        go.disabled = true;
        note.textContent = "";
        const answer = await call("/api/people?op=profile", { method: "POST",
          body: { handle: handle.value.trim().toLowerCase(), name: name.value, bio: "" } }).catch(() => null);
        go.disabled = false;
        if (!answer || answer.status !== 200) {
          note.textContent = (answer && answer.body.error) || "That did not work just now. Try again in a minute.";
          return;
        }
        next();
      });
      into.append(said, form);
      name.focus();
    } };

    // 2. What they build: the gallery's kinds, as pills to choose.
    const kindsStep = (kinds) => ({ id: "kinds", title: "What do you build?", draw(into, next) {
      const said = make("p", "", "Choose any you like: the designers and models next are of those first.");
      const pills = make("div", "pills kinds");
      pills.setAttribute("role", "group");
      pills.setAttribute("aria-label", "What you build");
      for (const kind of kinds) {
        const pill = button(String(kind.label), "pill");
        pill.dataset.kind = String(kind.id);
        pill.setAttribute("aria-pressed", chosen.includes(kind.id) ? "true" : "false");
        pill.addEventListener("click", () => {
          const on = pill.getAttribute("aria-pressed") !== "true";
          pill.setAttribute("aria-pressed", on ? "true" : "false");
          chosen = on ? [...chosen, kind.id] : chosen.filter((one) => one !== kind.id);
        });
        pills.append(pill);
      }
      const go = button("Next", "cta");
      go.id = "first-next";
      go.addEventListener("click", next);
      const skip = button("Skip", "cta ghost");
      skip.id = "first-skip";
      skip.addEventListener("click", () => {
        chosen = [];
        next();
      });
      into.append(said, pills, make("div", "actions", go, skip));
      pills.querySelector("button")?.focus();
    } });

    // 3. Designers to follow and models to open.
    const startStep = (found) => ({ id: "start", title: "Designers and models to start with", draw(into) {
      const { designers, models } = suggestionsFor(found, chosen);
      into.append(make("p", "", designers.length ? "Follow a designer and what they make comes into your feed."
        : "Open a model to look at it, build it step by step or remix it."));
      if (designers.length) {
        const list = make("ul", "people-list");
        list.setAttribute("aria-label", "Designers to follow");
        for (const one of designers) {
          const row = make("li", "person-row");
          row.dataset.handle = one.handle;
          const face = make("a", "face", parsed(avatarHtml({ handle: one.handle, name: one.name })));
          face.href = `/u/${encodeURIComponent(one.handle)}`;
          face.tabIndex = -1;
          face.setAttribute("aria-hidden", "true");
          const name = make("a", "", make("b", "", String(one.name || one.handle)));
          name.href = face.href;
          const best = (Array.isArray(one.models) ? one.models : []).slice(0, 2).map((model) => String(model.name));
          const follow = button("Follow", "cta ghost small follow");
          follow.dataset.follow = one.handle;
          const told = make("span", "said");
          told.setAttribute("role", "status");
          row.append(face, make("div", "names", name, make("small", "", best.length ? best.join(" · ") : `@${one.handle}`)), follow, told);
          followButton(follow, { you_follow: false, mine: false, signed_in: true, may: true, why_not: "" }).catch(() => null);
          list.append(row);
        }
        into.append(make("h3", "", "Designers to follow"), list);
      }
      if (models.length) {
        const grid = make("div", "models");
        grid.setAttribute("aria-label", "Models to start with");
        grid.append(...models.map((one) => modelCard(one)));
        into.append(make("h3", "", "Models to open"), grid);
      } else {
        into.append(make("p", "state", "The gallery is just starting. Share a model from the app and it is one of the first here."));
      }
      const actions = make("div", "actions");
      if (!pending) {
        const feed = make("a", "cta", "See your feed");
        feed.id = "first-feed";
        feed.href = `/feed${tests ? `?${tests}` : ""}`;
        actions.append(feed);
      }
      const close = button("Done", pending ? "cta" : "cta ghost");
      close.id = "first-done";
      close.addEventListener("click", end);
      actions.append(close);
      into.append(actions);
    } });

    dialog.showModal();
    count.textContent = "First steps";
    title.textContent = "Welcome to Brickworks";
    body.append(make("p", "", "One moment…"));
    Promise.all([me, top, latest]).then(([mine, listed, suggested]) => {
      if (finished) return;
      const hasProfile = Boolean(mine && mine.status === 200 && mine.body.profile && mine.body.profile.handle);
      const ok = (answer) => answer && answer.status === 200 && answer.body;
      const kinds = ok(listed) && Array.isArray(listed.body.kinds) ? listed.body.kinds.filter((kind) => kind && kind.id) : [];
      const found = { cards: ok(listed) && Array.isArray(listed.body.models) ? listed.body.models : [],
        designers: ok(suggested) && Array.isArray(suggested.body.designers) ? suggested.body.designers : [] };
      steps = [...(hasProfile ? [] : [profileStep]), ...(kinds.length ? [kindsStep(kinds)] : []), startStep(found)];
      show(0);
    });
  });
}
