// One way to page a list, the same on every list the site has (site357; the
// owner, 2026-10-29: "a consistent best practice pagination system"): the
// gallery, the LDraw library, a person's models and likes, a collection,
// the collections directory and a challenge's entries. The feed and the
// notifications take it next (site359).
//
// What a person sees on every one of them:
//   - pages of PAGE_SIZE, 24: four, six, eight or twelve whole rows of cards;
//   - Show more under the list, the way on: the next page put after these
//     when it is pressed, and never by itself as the end nears;
//   - the address says the last page shown (?page=3), put back as each one
//     comes, so a reload or a link opens that page alone, with Show earlier
//     above it to put back the ones before, a page a press;
//   - how many are shown: "Showing 25–72 of 1,234 models", or "Showing
//     models 1–48" where the list cannot say how many it has;
//   - numbered links under that, a real link to each page: the one before,
//     the first, a window round the last shown, the last, the one after, so
//     a crawler, a reader with no script and a jump all have them;
//   - after a press the keyboard is on the first new card, and a screen
//     reader is told "24 more models";
//   - Back to the list puts the same pages back, and the card left from
//     where it was.
// The next page is fetched once Show more nears the screen and drawn only
// when it is pressed, so a press is answered at once; a press while it is
// still on its way is answered the moment it comes, never lost (#81: Show
// more was disabled while a page came, and a press then did nothing).
//
// One markup for the server's pages and the browser's (pagerHtml; site.css
// .pager), and one behaviour (pager). A server page needs only this
// script: a nav with data-source="page" is paged by reading the next page's
// own HTML. A page that draws its own list gives pager() a load(n).
//
//   const paged = pager({ list: grid, load: async (n) => ({ items, more, total }) });
//   paged.start(pageAsked());
//
// A deployment copies this file beside its functions (tools/deploy.sh, as
// web/card.js), so it imports nothing, and it touches no document until it
// is in one.

export const PAGE_SIZE = 24;

/// Text as HTML text or an attribute's value (web/card.js escapeHtml).
const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[c]);
const said = (n) => Number(n).toLocaleString("en-US");

/// The page an address asks for: ?page=N, a whole number from 1, else 1.
export function pageAsked(search, param = "page") {
  const n = Number(new URLSearchParams(search).get(param) || "1");
  return Number.isInteger(n) && n >= 1 ? n : 1;
}

/// The page numbers to link to round [at], up to [end]: the first and the
/// end always, [near] either side of [at], and null for each gap. A gap of
/// one page is that page, never "…".
export function pageWindow(at, end, near = 2) {
  const wanted = new Set([1, end]);
  for (let n = at - near; n <= at + near; n += 1) if (n >= 1 && n <= end) wanted.add(n);
  const out = [];
  let last = 0;
  for (const n of [...wanted].sort((a, b) => a - b)) {
    if (n - last === 2) out.push(n - 1);
    else if (n - last > 2) out.push(null);
    out.push(n);
    last = n;
  }
  return out;
}

/// What the count says: which of them are shown, and of how many where
/// that is known. [noun]: [one, many].
export function countSaid({ first, shown, total = -1, size = PAGE_SIZE, noun = ["model", "models"] }) {
  if (!shown) return "";
  const from = (first - 1) * size + 1;
  const to = from + shown - 1;
  if (total >= 0) return `Showing ${from === to ? said(from) : `${said(from)}–${said(to)}`} of ${said(total)} ${total === 1 ? noun[0] : noun[1]}`;
  return from === to ? `Showing ${noun[0]} ${said(from)}` : `Showing ${noun[1]} ${said(from)}–${said(to)}`;
}

/// The numbered links: the one before what is shown, the window round the
/// last page shown, and the one after. Every page shown is data-shown, the
/// last of them aria-current. Under 600 px the numbers more than one away
/// are left out (data-far), all but the first and the last.
export function pagesHtml({ first, last, pages = 0, more = false, href }) {
  const end = pages || (more ? last + 1 : last);
  if (end <= 1) return "";
  const step = (n, words, rel) => `<li class="step ${rel}"><a href="${escapeHtml(href(n))}" rel="${rel}">`
    + `${rel === "prev" ? '<span aria-hidden="true">‹</span> ' : ""}<span class="words">${words}</span>`
    + `${rel === "next" ? ' <span aria-hidden="true">›</span>' : ""}</a></li>`;
  let out = first > 1 ? step(first - 1, "Previous", "prev") : "";
  for (const n of pageWindow(last, end)) {
    if (n === null) {
      out += '<li class="gap" aria-hidden="true">…</li>';
      continue;
    }
    const far = Math.abs(n - last) > 1 && n !== 1 && n !== end;
    const shown = n >= first && n <= last;
    out += `<li${far ? " data-far" : ""}><a href="${escapeHtml(href(n))}" aria-label="Page ${said(n)}"`
      + `${shown ? " data-shown" : ""}${n === last ? ' aria-current="page"' : ""}>${said(n)}</a></li>`;
  }
  if (more || (pages && last < pages)) out += step(last + 1, "Next", "next");
  return `<ol class="pager-pages">${out}</ol>`;
}

/// The pager's markup for list #[id], as the server's pages and the browser
/// draw it: [earlier], Show earlier, for over the list, and [after], the
/// count, Show more, the numbered links and what a screen reader is told,
/// for under it. [first]..[last]: the pages shown, [shown] cards in all;
/// [pages] and [total] where the list knows them (0 and -1 where not);
/// [more] whether there is a page after [last]; [href](n) page n's address;
/// [source] "page" when the next page is read from its own HTML, and
/// [skeleton] the markup of a card's stand-in while one comes.
export function pagerHtml({ id, first = 1, last = first, shown = 0, pages = 0, total = -1, more = false,
  size = PAGE_SIZE, noun = ["model", "models"], href, source = "", skeleton = "" }) {
  const after = pages ? last < pages : more;
  const count = countSaid({ first, shown, total, size, noun });
  const earlier = `<p class="pager-earlier" data-pager-earlier="${escapeHtml(id)}"${first > 1 ? "" : " hidden"}>`
    + `<a class="cta ghost" href="${escapeHtml(href(Math.max(1, first - 1)))}" data-pager-go="earlier">Show earlier</a></p>`;
  // One page and nothing after it: nothing to page, and no count.
  const alone = first === 1 && last === 1 && !after;
  const nav = `<nav class="pager" data-pager="${escapeHtml(id)}" aria-label="Pages of ${escapeHtml(noun[1])}"${alone ? " hidden" : ""}`
    + ` data-first="${first}" data-last="${last}" data-pages="${pages}" data-total="${total}" data-more="${after ? 1 : 0}"`
    + ` data-size="${size}" data-noun="${escapeHtml(noun.join("|"))}"${source ? ` data-source="${escapeHtml(source)}"` : ""}>`
    + `<p class="pager-count"${count ? "" : " hidden"}>${escapeHtml(count)}</p>`
    + `<a class="cta ghost pager-more" href="${escapeHtml(href(last + 1))}" data-pager-go="more"${after ? "" : " hidden"}>Show more</a>`
    + pagesHtml({ first, last, pages, more: after, href })
    + '<p class="visually-hidden" role="status" data-pager-said></p>'
    + `${skeleton ? `<template data-pager-skeleton>${skeleton}</template>` : ""}</nav>`;
  return { earlier, after: nav };
}

/// The <link>s a server page's head carries for page [at]: the one before
/// and the one after.
export function pagerLinks({ at, more, href }) {
  return `${at > 1 ? `<link rel="prev" href="${escapeHtml(href(at - 1))}">\n` : ""}`
    + `${more ? `<link rel="next" href="${escapeHtml(href(at + 1))}">\n` : ""}`;
}

// ---------------------------------------------------------------------------
// In a browser.

/// This address with page [n] asked by [param] (page 1: no param at all).
const addressWith = (param) => (n) => {
  const at = new URL(location.href);
  if (n > 1) at.searchParams.set(param, String(n));
  else at.searchParams.delete(param);
  return at.pathname + at.search;
};

/// Page [n] of a server page's list #[id], read from its own HTML: its
/// cards, and what its pager says of the rest.
const fromPage = (id, href) => async (n) => {
  const reply = await fetch(href(n), { headers: { accept: "text/html" } });
  if (!reply.ok && reply.status !== 404) throw new Error(String(reply.status));
  const made = new DOMParser().parseFromString(await reply.text(), "text/html");
  const nav = made.querySelector(`[data-pager="${CSS.escape(id)}"]`);
  const items = [...(made.getElementById(id)?.children || [])].map((one) => document.adoptNode(one));
  // Pictures under the first screen of that page are under this one's too.
  for (const img of items.flatMap((one) => [...one.querySelectorAll("img")])) {
    img.loading = "lazy";
    img.removeAttribute("fetchpriority");
  }
  return { items, pages: Number(nav?.dataset.pages) || 0, total: nav ? Number(nav.dataset.total) : -1,
    more: nav?.dataset.more === "1" };
};

/// Where the keyboard goes on a card come new: its name's link (a model's
/// a.open, a collection's a.name), else its first it can reach, else itself.
function focusOn(item) {
  const target = item.matches("a[href], button") ? item
    : item.querySelector("a.open, a.name") || item.querySelector('a[href]:not([tabindex="-1"]), button');
  if (target) {
    target.focus({ preventScroll: true });
    return;
  }
  item.tabIndex = -1;
  item.focus({ preventScroll: true });
}

/// Pages the list #[list.id] (pagerHtml's markup, found by its id, or put
/// round the list here when the page has none). [load](n) answers page n:
/// {items, more, pages, total, data}; none for a server page, whose next
/// page is read from its HTML. [href](n): page n's address. [key](item):
/// what tells a card apart, so one shown twice is not, and Back finds it.
/// [skeleton](): a card's stand-in while a page comes. [counted](): how
/// many of the list are shown, where some are drawn outside it (the
/// gallery's pick, one of its first page). [drawn]({page,
/// answer, items, fresh}) after each page is put in; [failed]({fresh,
/// trouble}) when one did not come. Each is optional but load. Returns
/// {start(n), restart(n), more(), earlier(), stop(), state}; stop() for a
/// list that is drawn again in a new element (a challenge's, after a vote).
export function pager({ list, load = null, href = null, param = "page", size = 0, noun = null, skeleton = null,
  key = (item) => item.dataset?.id || "", counted = null, drawn = () => {}, failed = () => {} }) {
  const id = list.id;
  let nav = document.querySelector(`[data-pager="${CSS.escape(id)}"]`);
  let up = document.querySelector(`[data-pager-earlier="${CSS.escape(id)}"]`);
  const given = nav ? nav.dataset : {};
  const at = href || addressWith(param);
  noun = noun || (given.noun ? given.noun.split("|") : ["model", "models"]);
  size = size || Number(given.size) || PAGE_SIZE;
  if (!nav || !up) {
    const made = pagerHtml({ id, href: at, noun, size });
    const holder = document.createElement("template");
    if (!up) {
      holder.innerHTML = made.earlier;
      up = holder.content.firstElementChild;
      list.before(up);
    }
    if (!nav) {
      holder.innerHTML = made.after;
      nav = holder.content.firstElementChild;
      list.after(nav);
    }
  }
  const fromHtml = !load;
  load = load || fromPage(id, at);
  const bone = nav.querySelector("template[data-pager-skeleton]")?.content.firstElementChild;
  skeleton = skeleton || (bone ? () => bone.cloneNode(true) : null);
  const count = nav.querySelector(".pager-count");
  const moreLink = nav.querySelector("[data-pager-go=more]");
  const upLink = up.querySelector("[data-pager-go=earlier]");
  const told = nav.querySelector("[data-pager-said]");

  // What is shown: pages first..last, and what the list said of the rest.
  const state = { first: Number(given.first) || 0, last: Number(given.last) || 0, pages: Number(given.pages) || 0,
    total: given.total === undefined ? -1 : Number(given.total), more: given.more === "1" };
  // Each question asked anew (start) is a generation: what an older one
  // asked is dropped when it comes. Pages asked ahead, by number.
  let generation = 0;
  const ahead = new Map();
  // A press being answered: Show more or Show earlier.
  let going = null;
  // Everything this pager listens to, let go of by stop().
  const ending = new AbortController();
  const signal = ending.signal;

  const shownCount = counted || (() => [...list.children].filter((one) => !one.classList.contains("skeleton")).length);

  function draw() {
    const after = state.pages ? state.last < state.pages : state.more;
    const shown = shownCount();
    const words = countSaid({ first: state.first, shown, total: state.total, size, noun });
    count.hidden = !words && !count.dataset.trouble;
    if (!count.dataset.trouble) count.textContent = words;
    moreLink.hidden = !after;
    moreLink.href = at(state.last + 1);
    upLink.href = at(Math.max(1, state.first - 1));
    up.hidden = state.first <= 1;
    const pages = pagesHtml({ first: state.first, last: state.last, pages: state.pages, more: after, href: at });
    const old = nav.querySelector(".pager-pages");
    const holder = document.createElement("template");
    holder.innerHTML = pages;
    if (old && pages) old.replaceWith(holder.content);
    else if (old) old.remove();
    else if (pages) moreLink.after(holder.content);
    Object.assign(nav.dataset, { first: state.first, last: state.last, pages: state.pages, total: state.total,
      more: after ? "1" : "0" });
    // One page and nothing after it: nothing to page, and no count.
    nav.hidden = state.first === 1 && state.last === 1 && !after && !count.dataset.trouble;
  }

  /// The trouble a press met, said where the count is, Show more (or
  /// Show earlier) saying Retry; [words] "" to clear it.
  function trouble(words, link = moreLink) {
    if (words) {
      count.dataset.trouble = "1";
      count.textContent = words;
      count.hidden = false;
      link.textContent = "Retry";
    } else {
      delete count.dataset.trouble;
      moreLink.textContent = "Show more";
      upLink.textContent = "Show earlier";
    }
  }

  /// Cards put on the page, said to whatever else wires them (web/follow.js
  /// a collection's Follow): a "pager:drawn" event from the list.
  function put(items, page) {
    list.dispatchEvent(new CustomEvent("pager:drawn", { bubbles: true, detail: { items, page } }));
  }

  function tell(words) {
    told.textContent = "";
    requestAnimationFrame(() => { told.textContent = words; });
  }

  /// The address saying what is shown, kept with what Back needs.
  function keep(extra = {}) {
    const kept = history.state && typeof history.state === "object" ? history.state : {};
    const pagers = { ...(kept.pagers || {}), [id]: { ...((kept.pagers || {})[id] || {}), first: state.first,
      last: state.last, ...extra } };
    history.replaceState({ ...kept, pagers }, "", at(state.last));
  }

  /// Page [n], asked ahead or now.
  function fetchPage(n) {
    if (!ahead.has(n)) {
      const asked = Promise.resolve().then(() => load(n));
      asked.catch(() => ahead.delete(n));
      ahead.set(n, asked);
    }
    return ahead.get(n);
  }

  /// What the list said of the rest, from page [n]'s answer.
  function learn(answer, n) {
    if (Number(answer.pages) > 0) state.pages = Number(answer.pages);
    if (Number.isFinite(Number(answer.total)) && Number(answer.total) >= 0) state.total = Number(answer.total);
    if (n >= state.last) state.more = state.pages ? n < state.pages : Boolean(answer.more);
  }

  /// [items] without any already shown.
  function fresh(items) {
    const shown = new Set([...list.children].map(key).filter(Boolean));
    return items.filter((one) => {
      const k = key(one);
      if (!k) return true;
      if (shown.has(k)) return false;
      shown.add(k);
      return true;
    });
  }

  /// Stand-ins while page [n] comes, where [where] the page goes.
  function bones(where) {
    if (!skeleton) return [];
    const n = state.total >= 0 ? Math.min(size, Math.max(0, state.total - state.last * size)) : size;
    const made = Array.from({ length: n || size }, () => skeleton());
    if (where === "end") list.append(...made);
    else list.prepend(...made);
    return made;
  }

  /// A page drawn after (or before) these, pressed for: at once if it was
  /// asked ahead, else once it comes, with stand-ins meanwhile.
  async function press(way) {
    if (going) return going;
    const n = way === "more" ? state.last + 1 : state.first - 1;
    if (n < 1) return null;
    const mine = generation;
    const link = way === "more" ? moreLink : upLink;
    trouble("");
    link.setAttribute("aria-busy", "true");
    let stand = [];
    const asked = fetchPage(n);
    // Not here within a frame: stand-ins where it will go.
    const waited = setTimeout(() => { stand = bones(way === "more" ? "end" : "start"); }, 16);
    going = (async () => {
      try {
        const answer = await asked;
        if (mine !== generation) return;
        clearTimeout(waited);
        for (const one of stand) one.remove();
        const items = fresh(answer.items || []);
        learn(answer, n);
        if (way === "more") {
          list.append(...items);
          state.last = n;
        } else {
          list.prepend(...items);
          state.first = n;
        }
        ahead.delete(n);
        draw();
        keep();
        drawn({ page: n, answer, items, fresh: false });
        put(items, n);
        if (items.length) {
          focusOn(items[0]);
          // Show earlier's page goes above it: where it starts, in view.
          if (way !== "more" && items[0].getBoundingClientRect().top < 0) items[0].scrollIntoView({ block: "start" });
        }
        tell(items.length ? `${said(items.length)} ${way === "more" ? "more" : "earlier"} ${items.length === 1 ? noun[0] : noun[1]}`
          : "Nothing more");
        if (way === "more") watch();
      } catch (problem) {
        if (mine !== generation) return;
        clearTimeout(waited);
        for (const one of stand) one.remove();
        trouble("That page did not load just now.", link);
        tell("That page did not load just now. Retry is where Show more was.");
        failed({ fresh: false, trouble: problem });
      } finally {
        link.removeAttribute("aria-busy");
        going = null;
      }
    })();
    return going;
  }

  // The next page asked for once Show more is within a screen of the
  // window, and drawn only when it is pressed.
  const near = "IntersectionObserver" in window ? new IntersectionObserver((seen) => {
    if (!seen.some((one) => one.isIntersecting) || moreLink.hidden) return;
    fetchPage(state.last + 1);
  }, { rootMargin: "0px 0px 100% 0px" }) : null;
  function watch() {
    if (!near) return;
    near.unobserve(moreLink);
    if (!moreLink.hidden) near.observe(moreLink);
  }

  for (const [link, way] of [[moreLink, "more"], [upLink, "earlier"]]) {
    link.addEventListener("click", (event) => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      event.preventDefault();
      press(way);
    }, { signal });
  }

  /// Which card to come back to: the one opened, else the first in view;
  /// and where it was in the window.
  function remember(item = null) {
    if (!state.last) return;
    const head = document.querySelector(".site-head")?.getBoundingClientRect().bottom || 0;
    const card = item || [...list.children].find((one) => one.getBoundingClientRect().bottom > head + 8);
    const k = card ? key(card) : "";
    keep(k ? { key: k, top: Math.round(card.getBoundingClientRect().top) } : {});
  }
  // The card a link was followed from, until the page scrolls again.
  let opened = null;
  document.addEventListener("click", (event) => {
    const link = event.target.closest?.("a[href]");
    if (!link || link.closest(".pager, .pager-earlier")) return;
    opened = list.contains(link) ? [...list.children].find((one) => one.contains(link)) || null : null;
    remember(opened);
  }, { capture: true, signal });
  addEventListener("scroll", () => { opened = null; }, { passive: true, signal });
  addEventListener("pagehide", () => remember(opened && list.contains(opened) ? opened : null), { signal });

  /// The list from page [n] alone, in place of whatever is shown; with
  /// [restore], the pages Back left (up to ten, the last of them [n]) and
  /// the card left where it was; with [from], pages [from]..[n] (up to
  /// ten), as a list drawn again keeps what it showed. Resolves to the last
  /// page's answer, or null when it did not come or an answer to a newer
  /// question did.
  async function start(n = pageAsked(location.search, param), { restore = true, adopted = false, from: kept = 0 } = {}) {
    const mine = ++generation;
    ahead.clear();
    trouble("");
    const back = restore && history.state?.pagers?.[id];
    let from = back && back.last === n && back.first >= 1 && back.first <= n ? Math.max(back.first, n - 9) : n;
    if (kept >= 1 && kept <= n) from = Math.max(kept, n - 9);
    try {
      let answers;
      if (adopted) {
        // A server page: page n is drawn; the pages before it Back left, read.
        answers = await Promise.all(Array.from({ length: n - from }, (_, i) => fetchPage(from + i)));
        if (mine !== generation) return null;
        const items = fresh(answers.flatMap((one) => one.items || []));
        list.prepend(...items);
        state.first = from;
        state.last = n;
        if (items.length) {
          drawn({ page: from, answer: answers[0], items, fresh: false });
          put(items, from);
        }
      } else {
        answers = await Promise.all(Array.from({ length: n - from + 1 }, (_, i) => fetchPage(from + i)));
        if (mine !== generation) return null;
        // A page past the end (the list grew shorter, or a hand-made
        // address): the first, and the address put right.
        if (n > 1 && answers.every((one) => !(one.items || []).length)) return start(1, { restore: false });
        list.replaceChildren();
        const items = fresh(answers.flatMap((one) => one.items || []));
        list.append(...items);
        Object.assign(state, { pages: 0, total: -1, more: false });
        for (const [i, answer] of answers.entries()) learn(answer, from + i);
        state.first = from;
        state.last = n;
        drawn({ page: from, answer: answers[answers.length - 1], items, fresh: true });
        put(items, from);
      }
      ahead.clear();
      draw();
      keep();
      if (back && back.key) {
        const card = [...list.children].find((one) => key(one) === back.key);
        // At once, not the page's smooth scroll, which a person coming back
        // would watch run down the list.
        if (card) scrollTo({ top: Math.max(0, scrollY + card.getBoundingClientRect().top - (Number(back.top) || 0)), behavior: "instant" });
        document.documentElement.dataset.back = card ? back.key : "lost";
      }
      watch();
      return answers[answers.length - 1] || { items: [] };
    } catch (problem) {
      if (mine !== generation) return null;
      failed({ fresh: true, trouble: problem });
      return null;
    }
  }

  if ("scrollRestoration" in history) history.scrollRestoration = "manual";
  if (fromHtml) {
    // A server page: what it drew is page first..last already.
    state.first = state.first || pageAsked(location.search, param);
    state.last = state.last || state.first;
    start(state.last, { adopted: true });
  }

  return {
    start,
    /// Asked anew (a search, a filter): page 1, Back's pages forgotten.
    restart: (n = 1) => start(n, { restore: false }),
    more: () => press("more"),
    earlier: () => press("earlier"),
    stop: () => {
      generation += 1;
      ending.abort();
      near?.disconnect();
    },
    state,
  };
}

// A server page's lists page themselves: each nav that says its next page
// is its own HTML.
if (typeof document !== "undefined") {
  for (const nav of document.querySelectorAll('nav[data-pager][data-source="page"]')) {
    const list = document.getElementById(nav.dataset.pager);
    if (list) pager({ list });
  }
}
