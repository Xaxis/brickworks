// The LDraw library on the site (library333, 2026-10-29): every model of a
// real set the app's Library opens (src/net/model_library.gd), browsed at
// /library as the gallery is browsed, and each with a page of its own at
// /library/<id>, made as a shared model's page is (api/share.js sharePage).
//
// What there is comes from the app's own index in the parts store,
// library/index.json (tools/library_build.py), read as _omr_credit.js reads
// it and kept a while. Not a table: 1,575 models that change a few times a
// year, whose index the app already reads from the store, so a table would
// be a second copy to keep in step with nothing it could add (a set has no
// likes or comments). Each entry is held at this edge to the shape the app
// holds it to (ModelLibrary._entry), and searched, filtered, sorted and
// paged as the app's Library does it (ModelLibrary.search), so the site and
// the app find the same sets for the same words.
//
// Its pictures are the covers the app's Library shows, drawn by the app's
// own renderer (src/dev/library_covers.gd), served from this site's origin
// (api/share.js ?op=set_cover), as a shared model's are.
//
// Pure but for the index's fetch, which a test gives its own:
// tests/test_library_site.py drives it.

import { SITE_LICENCE, storeIndex } from "./_omr_credit.js";
import { SIZES } from "./_directory.js";

/// A set's id as the app makes them, "omr-10179-1" (ModelLibrary.ID), less
/// the dot the app allows and no file name has (tools/library_build.py
/// safe_stem), so a page's address is never mistaken for its picture's.
export const SET_ID = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
export const PER_PAGE = 24;
/// How a page is ordered, and each in words (ModelLibrary.SORT_WORDS).
export const SET_SORTS = { newest: "Newest sets", oldest: "Oldest sets", largest: "Most parts",
  smallest: "Fewest parts", name: "By name" };
/// What the library is, where a set from it is credited (ModelLibrary.FROM).
export const FROM = "LDraw's Official Model Repository";
const LDRAW_PAGE = "https://library.ldraw.org/";
const MAX_QUERY = 100;
const MOST_PAGES = 200;
/// The authors a page names before "and others": their names, not a list.
const MOST_AUTHORS = 4;

const inside = (path) => typeof path === "string" && path.startsWith("library/") && !path.includes("..")
  && !path.includes("\\") && !path.includes("//");
const word = (given, most) => (typeof given === "string" ? given.replace(/\s+/g, " ").trim().slice(0, most) : "");
const whole = (given) => (Number.isInteger(given) && given > 0 ? given : 0);

/// An entry of the index as the shelf keeps it, or null for one that is not
/// whole (ModelLibrary._entry): its file and cover under library/, its page
/// LDraw's, and a licence the site can pass on.
export function entryOf(raw) {
  if (!raw || typeof raw !== "object") return null;
  const id = typeof raw.id === "string" ? raw.id : "";
  if (!SET_ID.test(id) || !inside(raw.file) || !inside(raw.cover) || !SITE_LICENCE[raw.licence]) return null;
  return {
    id, set: word(raw.set, 40), name: word(raw.name, 200) || id, theme: word(raw.theme, 200),
    year: whole(raw.year), parts: whole(raw.parts), box: whole(raw.box), file: raw.file, cover: raw.cover,
    author: word(raw.author, 200), licence: raw.licence,
    page: typeof raw.page === "string" && raw.page.startsWith(LDRAW_PAGE) && raw.page.length <= 200 ? raw.page : "",
    alternate_of: typeof raw.alternate_of === "string" ? word(raw.alternate_of, 40) : "",
  };
}

/// The index's entries, each checked, once by id.
export function shelf(raw) {
  const seen = new Set();
  const kept = [];
  for (const one of Array.isArray(raw) ? raw : []) {
    const entry = entryOf(one);
    if (!entry || seen.has(entry.id)) continue;
    seen.add(entry.id);
    kept.push(entry);
  }
  return kept;
}

let shelved = { raw: null, models: [] };

/// Every set, as the store's index has them now ([index] reads it: the
/// store's, kept ten minutes, unless a test gives its own). [] when the
/// store cannot be read.
export async function librarySets({ index = storeIndex } = {}) {
  const raw = await index().catch(() => []);
  if (raw !== shelved.raw) shelved = { raw, models: shelf(raw) };
  return shelved.models;
}

/// A set by its id, or null.
export async function librarySet(id, options) {
  if (!SET_ID.test(String(id || ""))) return null;
  return (await librarySets(options)).find((entry) => entry.id === id) || null;
}

/// A set's top theme, as the shelf filters by it: "Town" of "Town > Classic Town".
export const themeOf = (entry) => entry.theme.split(" > ")[0].split(" / ")[0].trim();

/// Every top theme with how many sets it has, by name.
export function themes(models) {
  const counted = new Map();
  for (const entry of models) {
    const theme = themeOf(entry);
    if (theme) counted.set(theme, (counted.get(theme) || 0) + 1);
  }
  return [...counted].sort((a, b) => a[0].localeCompare(b[0], "en")).map(([name, n]) => ({ name, n }));
}

/// The decades the shelf filters by, newest first: "2020s" … "1960s".
export function decades(models) {
  const seen = new Set(models.filter((entry) => entry.year > 0).map((entry) => Math.floor(entry.year / 10) * 10));
  return [...seen].sort((a, b) => b - a).map((year) => `${year}s`);
}

/// What a page of the shelf asks, from an address's query, checked at this
/// edge: q (words of a name, a set's number, a theme or who modelled it),
/// theme, decade ("1990s"), size (the gallery's SIZES), sort (SET_SORTS),
/// page (from 1). Anything else is left out, as if not asked.
export function askOf(query = {}) {
  const page = Number.parseInt(String(query.page ?? "1"), 10);
  return {
    q: word(String(query.q ?? ""), MAX_QUERY),
    theme: word(String(query.theme ?? ""), 200),
    decade: /^(19|20)[0-9]0s$/.test(String(query.decade ?? "")) ? String(query.decade) : "",
    size: Object.hasOwn(SIZES, String(query.size ?? "")) ? String(query.size) : "",
    sort: Object.hasOwn(SET_SORTS, String(query.sort ?? "")) ? String(query.sort) : "newest",
    page: Number.isFinite(page) ? Math.min(Math.max(page, 1), MOST_PAGES) : 1,
  };
}

/// Two names in the app's order (String.naturalnocasecmp_to): numbers by
/// their value, case not minded.
const byName = (a, b) => a.name.localeCompare(b.name, "en", { numeric: true, sensitivity: "base" });

/// The sets [ask] (askOf) asks for, a page of them: {models, total, page,
/// pages}, as ModelLibrary.search answers. Every word must be in the set's
/// name, number, theme or modeller.
export function searchSets(models, ask) {
  const words = ask.q.toLowerCase().split(" ").filter(Boolean);
  const decade = ask.decade ? Number(ask.decade.slice(0, 4)) : -1;
  const size = SIZES[ask.size] || null;
  const found = models.filter((entry) => {
    if (ask.theme && themeOf(entry) !== ask.theme) return false;
    if (decade >= 0 && Math.floor(entry.year / 10) * 10 !== decade) return false;
    if (size && (entry.parts < (size.least || 0) || entry.parts > (size.most ?? Infinity))) return false;
    const said = `${entry.name} ${entry.set} ${entry.theme} ${entry.author}`.toLowerCase();
    return words.every((one) => said.includes(one));
  });
  const order = {
    oldest: (a, b) => a.year - b.year,
    largest: (a, b) => b.parts - a.parts,
    smallest: (a, b) => a.parts - b.parts,
    name: () => 0,
    newest: (a, b) => b.year - a.year,
  }[ask.sort] || ((a, b) => b.year - a.year);
  found.sort((a, b) => order(a, b) || byName(a, b));
  const pages = Math.max(1, Math.ceil(found.length / PER_PAGE));
  const page = Math.min(ask.page, pages);
  return { models: found.slice((page - 1) * PER_PAGE, page * PER_PAGE), total: found.length, page, pages };
}

/// "10179-1 Millennium Falcon - UCS": which set it is and what it was called.
export const setTitle = (entry) => (entry.set ? `${entry.set} ${entry.name}` : entry.name);

/// Who modelled it, as a credit names them: the authors its page found in
/// the file (authorsIn), or the index's one.
const creditNames = (entry, authors = []) => (authors.length ? authors : [entry.author]).filter(Boolean);

/// "Ann, Bo and Cy"; past MOST_AUTHORS, the first ones "and 3 others".
export function namesSaid(names) {
  const shown = names.length > MOST_AUTHORS ? [...names.slice(0, MOST_AUTHORS - 1), `${names.length - MOST_AUTHORS + 1} others`]
    : names;
  return shown.length > 1 ? `${shown.slice(0, -1).join(", ")} and ${shown[shown.length - 1]}` : shown[0] || "";
}

/// A set as a card (web/card.js cardHtml): its page and cover under
/// /library/, who modelled it for LDraw, and which set it is.
export function setCard(entry) {
  return {
    id: entry.id, name: entry.name, parts: entry.parts, licence: SITE_LICENCE[entry.licence],
    modelled_by: entry.author && entry.page ? { name: entry.author, page: entry.page } : null,
    library: { set: entry.set, theme: themeOf(entry), year: entry.year },
  };
}

/// What a set's page shows it as: a shared model's page's own fields
/// (api/share.js sharePage), with [library] saying it is a set of the
/// library and which. [authors] are the model's own (authorsIn), [steps] the
/// steps its file lays out (fileSteps).
export function setModel(entry, { authors = [], steps = 0 } = {}) {
  const names = creditNames(entry, authors);
  const by = namesSaid(names);
  const said = [entry.theme, entry.year ? String(entry.year) : ""].filter(Boolean).join(", ");
  return {
    id: entry.id, name: entry.name, author: null, by: null, parts: entry.parts,
    has_image: true, has_thumb: true, tags: [], kind: null, from: [], remixes_listed: [],
    licence: SITE_LICENCE[entry.licence],
    modelled_by: by && entry.page ? { name: by, page: entry.page } : null,
    description: `An LDraw model of LEGO® set ${setTitle(entry)}${said ? ` (${said})` : ""}, `
      + `modelled ${by ? `by ${by} ` : ""}for ${FROM}.`,
    library: { set: entry.set, theme: themeOf(entry), year: entry.year, box: entry.box, steps,
      alternate_of: entry.alternate_of, authors: names },
  };
}

/// Whether two names are one person's: "Evert-Jan Boer" and "Evert Jan Boer".
const plain = (name) => name.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
/// The programs that sign the files they write, which are not modellers.
const TOOLS = new Set(["ldcad", "ldraw", "ldraworg", "mlcad", "ldd", "lddesignpad", "leocad", "studio", "bricklinkstudio"]);

/// Every modeller [text] (an LDraw file) names, its main model's first:
/// each model's "0 Author:" line, not a part's (a .dat the file carries is the
/// parts library's, credited on every page), their logins in brackets and
/// their addresses left out, and a program that signed a model it wrote
/// (LDCad's flexible parts) left out. The licence asks each one credited.
export function authorsIn(text) {
  const names = [];
  const keys = new Set();
  let part = false;
  for (const raw of String(text || "").split("\n")) {
    const line = raw.trim();
    const file = /^0\s+FILE\s+(.+)$/i.exec(line);
    if (file) {
      part = /\.dat$/i.test(file[1].trim());
      continue;
    }
    if (part) continue;
    const said = /^0\s+Author:\s*(.*)$/i.exec(line);
    if (!said) continue;
    const name = said[1].replace(/\[[^\]]*\]?/g, " ").replace(/\([^)]*@[^)]*\)/g, " ")
      .replace(/\S+@\S+/g, " ").replace(/[[\]]/g, " ").replace(/\s+/g, " ").trim().slice(0, 80);
    const key = plain(name);
    if (!key || TOOLS.has(key) || keys.has(key)) continue;
    keys.add(key);
    names.push(name);
  }
  return names;
}

/// The steps [text] lays out, its modeller's own: every model's 0 STEP (or
/// ROTSTEP) that ends a step putting a part on, and its last step when it
/// ends with no STEP; a part's own file (.dat) is no model. 0 for a file
/// that lays out no steps, whose steps the app works out as it opens it.
export function fileSteps(text) {
  let steps = 0;
  let marked = false;
  let placed = false;
  let part = false;
  const close = () => {
    if (placed) steps += 1;
    placed = false;
  };
  for (const raw of String(text || "").split("\n")) {
    const line = raw.trim();
    if (/^0\s+FILE\s/i.test(line)) {
      if (!part) close();
      part = /\.dat$/i.test(line);
      placed = false;
      continue;
    }
    if (part) continue;
    if (/^0\s+(ROT)?STEP\b/i.test(line)) {
      marked = true;
      close();
    } else if (/^1\s/.test(line)) {
      placed = true;
    }
  }
  if (!part) close();
  return marked ? steps : 0;
}
