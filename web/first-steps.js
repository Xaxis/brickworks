// First steps (docs/SOCIAL.md U10, D12): what a person is offered after
// their first sign-in, once the age question says they are 13 or over
// (web/account.js askAgeIfAsked): at once from a page's own Sign in, and
// from the header's on the home page, the profile and the feed; after what
// they pressed is done where they signed in to do something (a like, a
// follow), and from the header's on any other page (sharing a model,
// reading one), from a snackbar that covers nothing (offerFirstSteps).
// Three steps in one dialog, each skippable:
//
//   1. Make your profile: a name and a handle, the avatar made from the
//      handle drawn as they type (left out when they have one already).
//   2. What do you build?: the gallery's kinds as pills, chosen or not.
//   3. Designers and models to start with: up to three designers to follow,
//      by Top builds and the kinds chosen first, and six models to open:
//      the kinds chosen first, each as Top builds ranks it among its kind.
//
// The kinds chosen only order what step 3 suggests: nothing of them is
// kept, here or on the server (D13). Following a designer here is the
// Follow of everywhere else (web/follow.js), so what they make fills the
// feed; "See your feed" ends it there, unless they came from the snackbar
// after doing something on this page (a like, a comment): they stay on it.
//
// Every word is put on the page as text; a card and an avatar are the
// kit's, which escape their own. Every word is said in the visitor's
// language as the sign-in's dialogs say theirs (web/account.js say), and
// tools/site_lang.py --check fails on one that is not.
import { call, learn, say, signedIn, speaking } from "/account.js";
import { followButton, showFeedCount } from "/follow.js";
import { avatarHtml, langAt, modelCard } from "/card.js";

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

/// What step 3 suggests, from the feed's designers (by Top builds), Top
/// builds' cards, and each kind chosen's own Top builds ([ofKinds], kind ->
/// its cards, as /api/share?op=list&sort=top&kind= ranks them): the
/// designers with most models of [kinds] first, then as they came; the
/// models of [kinds] first, then the rest, each as Top builds ranked it.
/// Top's first page alone held 3 of live's 7 castles, and a newcomer who
/// chose castles was shown a robot and a space ship after them (greenreds2,
/// 2026-11-28). Two kinds' lists are taken together by Top's own order
/// ([score], api/_directory.js SCORE: its score, then builds, then the
/// newest listed), each list's order kept. A kind whose list did not come
/// is Top's first page's of it. Pure.
export function suggestionsFor({ designers = [], cards = [], ofKinds = {}, score = null }, kinds = []) {
  const wanted = new Set(kinds);
  const ofKind = (card) => wanted.has(String(card.kind || ""));
  const lists = [...wanted].map((kind) => (Array.isArray(ofKinds[kind]) ? ofKinds[kind]
    : cards.filter((card) => String(card.kind || "") === kind)).filter((card) => card && card.id && ofKind(card)));
  const seen = new Set();
  const once = (card) => card && card.id && !seen.has(card.id) && seen.add(card.id);
  const chosen = inTopOrder(lists, score).filter(once);
  const matches = new Map();
  for (const card of chosen) {
    const handle = card?.by?.handle;
    if (handle) matches.set(handle, (matches.get(handle) || 0) + 1);
  }
  const people = designers.filter((one) => one && HANDLE.test(String(one.handle || "")))
    .map((one, at) => ({ one, at, n: matches.get(one.handle) || 0 }))
    .sort((a, b) => b.n - a.n || a.at - b.at).slice(0, DESIGNERS).map(({ one }) => one);
  const models = [...chosen, ...cards.filter((card) => !ofKind(card)).filter(once)].slice(0, MODELS);
  return { designers: people, models };
}

/// [lists] of cards, each in Top builds' order, as one list in that order:
/// at each turn the head that Top puts first ([score], api/_directory.js
/// SCORE), the earlier list's on a tie, so each list keeps its own order.
function inTopOrder(lists, score) {
  const key = (card) => [score ? (Number(score.builds) || 0) * (Number(card.builds) || 0)
    + (Number(score.remixes) || 0) * (Number(card.remixes) || 0) + (card.tested === true ? Number(score.tested) || 0 : 0) : 0,
  Number(card.builds) || 0, Date.parse(card.listed_at || "") || 0];
  const before = (a, b) => {
    const [x, y] = [key(a), key(b)];
    for (let at = 0; at < x.length; at += 1) if (x[at] !== y[at]) return x[at] > y[at];
    return false;
  };
  const heads = lists.map((list) => [...list]);
  const out = [];
  for (;;) {
    let best = -1;
    heads.forEach((list, at) => {
      if (list.length && (best < 0 || before(list[0], heads[best][0]))) best = at;
    });
    if (best < 0) return out;
    out.push(heads[best].shift());
  }
}

/// Opens First steps over the page. [pending]: the person signed in to do
/// something here, so the end goes back to it rather than to the feed.
/// [profileOnly]: Make your profile alone, as the step before something that
/// goes out under their name (web/account.js nameFirst: a comment, a reply,
/// a post, a model shared); its caller knows the account has no profile, so
/// the step shows at once. Resolves when it is closed, however it is:
/// {profile: {handle, name}} when a profile was made in it, else {}.
export async function firstSteps({ pending = false, profileOnly = false } = {}) {
  await learn();
  let made = null;
  return new Promise((done) => {
    const tests = new URLSearchParams(location.search).get("tests") === "1" ? "tests=1" : "";
    const dialog = make("dialog", "first-steps");
    speaking(dialog);
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
      done(made ? { profile: made } : {});
    };
    dialog.addEventListener("cancel", end);

    // What the steps need, asked at once: whether you have a profile, the
    // gallery's kinds and Top builds' cards, and the designers to follow.
    const me = profileOnly ? null : call("/api/people?op=me").catch(() => null);
    const top = profileOnly ? null : call(`/api/share?op=list&sort=top${tests ? `&${tests}` : ""}`).catch(() => null);
    // As you (mine=1) once signed in: nobody you blocked is among the
    // designers offered. Signed out, everybody's URL, which the CDN keeps.
    const as = signedIn() ? "&mine=1" : "";
    const latest = profileOnly ? null : call(`/api/people?op=latest${as}${tests ? `&${tests}` : ""}`).catch(() => null);
    let chosen = [];
    let steps = [];
    // Each kind chosen's own Top builds, asked as its pill is pressed so
    // step 3 has them by the time Next is: kind -> its answer.
    const ofKinds = new Map();
    const askKind = (kind) => {
      if (!ofKinds.has(kind)) {
        ofKinds.set(kind, call(`/api/share?op=list&sort=top&kind=${encodeURIComponent(kind)}${tests ? `&${tests}` : ""}`)
          .catch(() => null));
      }
      return ofKinds.get(kind);
    };

    // The step's id is put on the dialog once it is drawn: step 3 waits
    // for the kinds chosen.
    let showing = 0;
    const show = async (at) => {
      const step = steps[at];
      const now = ++showing;
      count.textContent = steps.length > 1 ? say("First steps · {at} of {all}", { at: at + 1, all: steps.length })
        : say("First steps");
      title.textContent = step.title;
      delete dialog.dataset.step;
      body.replaceChildren();
      await step.draw(body, () => (at + 1 < steps.length ? show(at + 1) : end()));
      if (!finished && now === showing) dialog.dataset.step = step.id;
    };

    // 1. A name and a handle.
    const profileStep = { id: "profile", title: say("Make your profile"), draw(into, next) {
      // Asked before something goes out under their name, it says why now,
      // and what Skip does: it goes, unnamed.
      const said = make("p", "", profileOnly
        ? say("What you say and share goes out under this name, so people know who it is and can follow you. "
          + "Skip, and it goes out as “A builder”.")
        : say("A name and a handle, and the models you share have a page of your own. "
          + "Your picture is made from your handle."));
      const form = make("form", "profile-start");
      const face = make("div", "face-row");
      let avatar = parsed(avatarHtml({ handle: "", name: "?" }, { size: "big" }));
      const address = make("p", "", "brickworks.diy/u/", make("b", "", say("your-handle")));
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
        address.lastChild.textContent = shown || say("your-handle");
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
      const nameLabel = make("label", "", say("Name"), name);
      const handleLabel = make("label", "", `${say("Handle")} `, make("small", "", say("3 to 24 of a-z, 0-9 and hyphens")), handle);
      const note = make("p", "said");
      note.setAttribute("role", "status");
      const go = button(say("Make my profile"), "cta", "submit");
      go.id = "first-make";
      const skip = button(say("Skip"), "cta ghost");
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
          note.textContent = answer && answer.body.error ? say(answer.body.error) : say("That did not work just now. Try again in a minute.");
          return;
        }
        made = { handle: String(answer.body.handle || ""), name: String(answer.body.name || answer.body.handle || "") };
        next();
      });
      into.append(said, form);
      name.focus();
    } };

    // 2. What they build: the gallery's kinds, as pills to choose.
    const kindsStep = (kinds) => ({ id: "kinds", title: say("What do you build?"), draw(into, next) {
      const said = make("p", "", say("Choose any you like: the designers and models next are of those first."));
      const pills = make("div", "pills kinds");
      pills.setAttribute("role", "group");
      pills.setAttribute("aria-label", say("What you build"));
      for (const kind of kinds) {
        const pill = button(say(String(kind.label)), "pill");
        pill.dataset.kind = String(kind.id);
        pill.setAttribute("aria-pressed", chosen.includes(kind.id) ? "true" : "false");
        pill.addEventListener("click", () => {
          const on = pill.getAttribute("aria-pressed") !== "true";
          pill.setAttribute("aria-pressed", on ? "true" : "false");
          chosen = on ? [...chosen, kind.id] : chosen.filter((one) => one !== kind.id);
          if (on) askKind(String(kind.id));
        });
        pills.append(pill);
      }
      const go = button(say("Next"), "cta");
      go.id = "first-next";
      go.addEventListener("click", next);
      const skip = button(say("Skip"), "cta ghost");
      skip.id = "first-skip";
      skip.addEventListener("click", () => {
        chosen = [];
        next();
      });
      into.append(said, pills, make("div", "actions", go, skip));
      pills.querySelector("button")?.focus();
    } });

    // 3. Designers to follow and models to open.
    const startStep = (found) => ({ id: "start", title: say("Designers and models to start with"), async draw(into) {
      const kinds = [...chosen];
      if (kinds.length) {
        const wait = make("p", "", say("One moment…"));
        into.append(wait);
        const answers = await Promise.all(kinds.map(askKind));
        wait.remove();
        if (finished) return;
        found = { ...found, ofKinds: Object.fromEntries(kinds.map((kind, at) => [kind,
          answers[at] && answers[at].status === 200 && Array.isArray(answers[at].body?.models) ? answers[at].body.models : null])) };
      }
      const { designers, models } = suggestionsFor(found, kinds);
      into.append(make("p", "", designers.length ? say("Follow a designer and what they make comes into your feed.")
        : say("Open a model to look at it, build it step by step or remix it.")));
      if (designers.length) {
        const list = make("ul", "people-list");
        list.setAttribute("aria-label", say("Designers to follow"));
        for (const one of designers) {
          const row = make("li", "person-row");
          row.dataset.handle = one.handle;
          const face = make("a", "face", parsed(avatarHtml({ handle: one.handle, name: one.name, picture: one.picture })));
          face.href = `${langAt()}/u/${encodeURIComponent(one.handle)}`;
          face.tabIndex = -1;
          face.setAttribute("aria-hidden", "true");
          const name = make("a", "", make("b", "", String(one.name || one.handle)));
          name.href = face.href;
          const best = (Array.isArray(one.models) ? one.models : []).slice(0, 2).map((model) => String(model.name));
          const follow = button(say("Follow"), "cta ghost small follow");
          follow.dataset.follow = one.handle;
          const told = make("span", "said");
          told.setAttribute("role", "status");
          row.append(face, make("div", "names", name, make("small", "", best.length ? best.join(" · ") : `@${one.handle}`)), follow, told);
          followButton(follow, { you_follow: false, mine: false, signed_in: true, may: true, why_not: "" }).catch(() => null);
          list.append(row);
        }
        into.append(make("h3", "", say("Designers to follow")), list);
      }
      if (models.length) {
        const grid = make("div", "models");
        grid.setAttribute("aria-label", say("Models to start with"));
        grid.append(...models.map((one) => modelCard(one)));
        into.append(make("h3", "", say("Models to open")), grid);
      } else {
        into.append(make("p", "state", say("The gallery is just starting. Share a model from the app and it is one of the first here.")));
      }
      const actions = make("div", "actions");
      if (!pending) {
        const feed = make("a", "cta", say("See your feed"));
        feed.id = "first-feed";
        feed.href = `${langAt()}/feed${tests ? `?${tests}` : ""}`;
        actions.append(feed);
      }
      const close = button(say("Done"), pending ? "cta" : "cta ghost");
      close.id = "first-done";
      close.addEventListener("click", end);
      actions.append(close);
      into.append(actions);
    } });

    dialog.showModal();
    count.textContent = say("First steps");
    title.textContent = profileOnly ? say("Make your profile") : say("Welcome to Brickworks");
    body.append(make("p", "", say("One moment…")));
    Promise.all([me, top, latest]).then(([mine, listed, suggested]) => {
      if (finished) return;
      const hasProfile = Boolean(mine && mine.status === 200 && mine.body.profile && mine.body.profile.handle);
      const ok = (answer) => answer && answer.status === 200 && answer.body;
      const kinds = ok(listed) && Array.isArray(listed.body.kinds) ? listed.body.kinds.filter((kind) => kind && kind.id) : [];
      const found = { cards: ok(listed) && Array.isArray(listed.body.models) ? listed.body.models : [],
        designers: ok(suggested) && Array.isArray(suggested.body.designers) ? suggested.body.designers : [],
        score: ok(listed) && listed.body.score && typeof listed.body.score === "object" ? listed.body.score : null };
      steps = profileOnly ? [profileStep]
        : [...(hasProfile ? [] : [profileStep]), ...(kinds.length ? [kindsStep(kinds)] : []), startStep(found)];
      if (!steps.length) end();
      else show(0);
    });
  });
}
