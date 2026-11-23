// The home page's search as it is typed (landing, 2026-11-22): under the
// field, the models, the builders and the real sets it finds, each a link,
// and a way to see all of each. Asked for by web/landing.js once the field
// is used, so a visitor who never searches loads none of it.
//
// What it asks is what the gallery's own tabs ask, signed out, so the CDN
// keeps each answer for everybody: the models from the gallery's search
// (/api/share?op=list&q=, which matches models, builders and tags), the
// builders being the makers of what it found whose names hold what was
// typed, and the sets from the Sets tab's (/api/share?op=library&q=, every
// LEGO® set, by name, number or theme, misspelt or not: api/_search.js).
//
// A combobox as ARIA has it (the field) with a listbox of links: the arrows
// move along the links (aria-activedescendant), Enter opens the one moved
// to, or sends the search to the gallery; Escape closes the list. An
// answer to an older question than the field's is thrown away.
import { avatarHtml, escapeHtml, langAt, pictureOf, say } from "/card.js";

const MODEL = /^[A-Za-z0-9]{10}$/;
const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const EACH = 4;
const WAIT_MS = 180;

async function ask(path) {
  try {
    const reply = await fetch(path, { headers: { accept: "application/json" } });
    return reply.ok ? await reply.json() : null;
  } catch {
    return null;
  }
}

/// Words compared as a builder types them: lower case, no accents.
const plain = (words) => String(words || "").normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase();

/// What [q] finds: {models, builders, sets}.
export async function found(q) {
  const encoded = encodeURIComponent(q);
  const [listed, library] = await Promise.all([ask(`/api/share?op=list&page=1&sort=top&q=${encoded}`),
    ask(`/api/share?op=library&page=1&q=${encoded}`)]);
  const models = (listed?.models || []).filter((m) => m && MODEL.test(String(m.id)) && pictureOf(m));
  const words = plain(q).split(/\s+/).filter((word) => word.length > 1);
  const builders = [];
  for (const m of listed?.models || []) {
    const by = m?.by;
    if (!by || !HANDLE.test(String(by.handle || "")) || builders.some((one) => one.handle === by.handle)) continue;
    const named = plain(`${by.name || ""} ${by.handle}`);
    if (words.some((word) => named.includes(word))) builders.push(by);
  }
  const sets = (library?.models || []).filter((m) => m && SET.test(String(m.id)) && pictureOf(m));
  return { models: models.slice(0, EACH), builders: builders.slice(0, 3), sets: sets.slice(0, EACH) };
}

/// A set's page, in the page's language where it has one.
const setPage = (m) => (/^\/library\/set\/[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/.test(String(m.library?.page || ""))
  ? `${langAt()}${m.library.page}` : `/library/${m.id}`);

/// The list's rows for [q] and what it [got], as HTML.
export function rowsHtml(q, got) {
  let n = 0;
  const option = (href, inside) => `<a role="option" id="find-${n++}" aria-selected="false" href="${escapeHtml(href)}">${inside}</a>`;
  const picture = (src) => `<img src="${escapeHtml(src)}" alt="" width="48" height="36" loading="lazy" decoding="async">`;
  const at = langAt();
  const parts = [];
  if (got.models.length) {
    parts.push(`<p class="kind" role="presentation">${escapeHtml(say("Models"))}</p>`);
    for (const m of got.models) {
      parts.push(option(`${at}/m/${m.id}`, `${picture(pictureOf(m))}<span translate="no">${escapeHtml(m.name)}</span>`
        + `<small>${escapeHtml(m.by?.name || m.author || "")}</small>`));
    }
  }
  if (got.builders.length) {
    parts.push(`<p class="kind" role="presentation">${escapeHtml(say("Builders"))}</p>`);
    for (const by of got.builders) {
      parts.push(option(`${at}/u/${by.handle}`, `${avatarHtml({ handle: by.handle, name: by.name || by.handle, picture: by.picture }, { size: "small" })}`
        + `<span translate="no">${escapeHtml(by.name || by.handle)}</span><small>@${escapeHtml(by.handle)}</small>`));
    }
  }
  if (got.sets.length) {
    parts.push(`<p class="kind" role="presentation">${escapeHtml(say("Sets"))}</p>`);
    for (const m of got.sets) {
      parts.push(option(setPage(m), `${picture(pictureOf(m))}<span translate="no">${escapeHtml(m.name)}</span>`
        + `<small>${escapeHtml(m.library?.set || "")}</small>`));
    }
  }
  const words = encodeURIComponent(q);
  parts.push(option(`${at}/gallery?q=${words}`, `<span class="all">${escapeHtml(say("Search the gallery for “{q}”", { q }))}</span>`));
  parts.push(option(`${at}/library?q=${words}`, `<span class="all">${escapeHtml(say("Search the sets for “{q}”", { q }))}</span>`));
  return parts.join("");
}

/// What was typed, as it is asked: no zero-width characters, every run of
/// spaces (a no-break one too) one space, at most 100 characters.
export const asked = (typed) => String(typed || "").replace(/[\u200B-\u200D\u2060\uFEFF]/g, "").replace(/\s+/g, " ").trim().slice(0, 100);

/// The search's suggestions on [form] and its [field].
export function findAsYouType(form, field) {
  const list = document.getElementById(field.getAttribute("aria-controls"));
  if (!list) return;
  let question = 0;
  let timer = 0;
  // The last answer shown, so the rows say what is typed now while the
  // next is asked: its last two rows search for the whole text, never a
  // word half typed (homefeed's preview: "castle" sent q=ca).
  let shown = null;
  const options = () => [...list.querySelectorAll('[role="option"]')];
  const close = () => {
    list.hidden = true;
    field.setAttribute("aria-expanded", "false");
    field.removeAttribute("aria-activedescendant");
  };
  const move = (to) => {
    const all = options();
    if (!all.length) return;
    const at = (to + all.length) % all.length;
    all.forEach((one, i) => one.setAttribute("aria-selected", String(i === at)));
    field.setAttribute("aria-activedescendant", all[at].id);
    all[at].scrollIntoView({ block: "nearest" });
  };
  const show = async () => {
    const q = asked(field.value);
    const mine = ++question;
    if (q.length < 2) {
      close();
      return;
    }
    const got = await found(q);
    if (mine !== question) return;
    shown = got;
    list.innerHTML = rowsHtml(q, got);
    list.hidden = false;
    field.setAttribute("aria-expanded", "true");
    field.removeAttribute("aria-activedescendant");
  };
  field.addEventListener("input", () => {
    clearTimeout(timer);
    // An answer still on its way is for what was typed before: never shown.
    question += 1;
    const q = asked(field.value);
    if (shown && !list.hidden && q.length >= 2) {
      list.innerHTML = rowsHtml(q, shown);
      field.removeAttribute("aria-activedescendant");
    }
    timer = setTimeout(show, WAIT_MS);
  });
  field.addEventListener("keydown", (event) => {
    const all = options();
    const at = all.findIndex((one) => one.getAttribute("aria-selected") === "true");
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      if (list.hidden) return;
      event.preventDefault();
      move(event.key === "ArrowDown" ? at + 1 : at < 0 ? all.length - 1 : at - 1);
    } else if (event.key === "Escape" && !list.hidden) {
      event.preventDefault();
      close();
    } else if (event.key === "Enter" && !list.hidden && at >= 0) {
      event.preventDefault();
      location.assign(all[at].href);
    }
  });
  // Sent: the gallery's search, in the page's language.
  form.addEventListener("submit", (event) => {
    const q = asked(field.value);
    event.preventDefault();
    location.assign(`${langAt()}/gallery${q ? `?q=${encodeURIComponent(q)}` : ""}`);
  });
  // A press anywhere else closes it; a press on a row opens its link.
  document.addEventListener("pointerdown", (event) => {
    if (!list.hidden && !form.contains(event.target)) close();
  });
  field.addEventListener("focus", () => {
    if (asked(field.value).length >= 2 && list.innerHTML) {
      list.hidden = false;
      field.setAttribute("aria-expanded", "true");
    }
  });
  form.addEventListener("focusout", (event) => {
    if (!form.contains(event.relatedTarget)) close();
  });
  // Typed before this was in: asked at once.
  if (asked(field.value).length >= 2) show();
}
