// Every LEGO® set there is, a page each (sets364, 2026-10-29): the whole of
// Rebrickable's catalogue in the site's library, beside LDraw's 3D models of
// a few hundred of them (api/_library.js).
//
// What a set is comes from tools/set_catalog.py (its number, name, year,
// theme, part count, minifigures, the sets packed in it, the parts its
// picture is drawn from), beside the share function at deploy as
// _set_catalog.json and read from assets/generated in a checkout; what is in
// it from tools/collection_data.py's shards (api/_owned.js readShard), which
// the app's My collection already reads. Nothing here asks Rebrickable
// anything: the catalogue is the copy tools/fetch_data.sh keeps, at most a
// day old. A set's picture is LDraw's model's render when there is one,
// else the set's own picture as Rebrickable has it, credited to them and
// served from here (tools/set_pictures.py fetched it once into our
// storage; a visitor's browser never asks them), else one drawn here from
// its parts' own geometry (api/_flatlay.js) for the few with none.
//
// The library (/library) lists every set, searched by number or name and
// filtered by theme (and the theme inside it), decade and year, size,
// whether LDraw has a 3D model of it and minifigures, a page at a time as
// the LDraw shelf was (PER_PAGE), each set's card marked 3D where it has a
// model. Browsed with nothing typed, it leaves out what Rebrickable lists
// with no parts (books, gear, promotions); a search finds those too.
//
// Each set's page is /library/set/<number> (setPage), kept by the CDN a
// day: its facts, its parts list drawn with the site's own part pictures
// (web/model-page.js and web/part-pictures.js, as a model's Parts list),
// how much of it a signed-in person owns and the rest as a wanted list
// (ownedOf), the app opened with its parts in the bin or the assistant
// asked to design with them, and its 3D model and that model's page, each
// linking the other. Pure but for the catalogue's read: tests/test_sets.py
// drives it.

import { existsSync, readFileSync } from "node:fs";
import { SIZES, count, escapeHtml } from "./_directory.js";
import { SET_SORTS } from "./_library.js";

/// How the library's sets are put in order, the first by default: those LDraw
/// has a model of first, since their picture is the set built in 3D, to
/// open and build. Newest first opened the library on 24 of this year's
/// sets, none modelled yet, and showed no set at all, only parts (the owner,
/// 2026-10-30), before every set had its own picture.
export const SETS_SORTS = { built: "Built in 3D first", ...SET_SORTS };
export const FIRST_SORT = "built";

/// A set's number as Rebrickable writes it, "10497-1", "COMCON001-1", "214.1-1": what a
/// page's address may hold.
export const SET_NUMBER = /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/;
/// A set's card's id in the library's list: its number after this, so the
/// list's ids (web/library.js) keep the shape the LDraw shelf's had.
export const CARD_ID = "set-";
export const PER_PAGE = 24;
/// Every page of the list a visitor can page to: the whole catalogue.
const MOST_PAGES = 1200;
const MAX_QUERY = 100;
/// The sets a page ends with: its theme's, nearest in years.
const NEXT_MOST = 12;
/// How many of a set's lots the assistant's starter brief names.
const BRIEF_LOTS = 12;
/// Where the catalogue's facts come from, credited on every page.
export const CREDIT = { name: "Rebrickable", url: "https://rebrickable.com/" };
/// A set's own page there, which its picture is credited to.
export const creditOf = (entry) => `${CREDIT.url}sets/${encodeURIComponent(entry.set)}/`;
/// One URL for a crawler a sitemap file: a twentieth of Google's 50,000.
export const SITEMAP_SETS = 10000;

const word = (given, most) => (typeof given === "string" ? given.replace(/\s+/g, " ").trim().slice(0, most) : "");

let catalog = null;

/// The catalogue as the pages read it: {sets (by number), by (lower-cased
/// number -> set), themes (id -> {name, parent})}, each set {set, name,
/// year, theme (its path of names, outermost first), parts, figs, lots,
/// photo (its own picture is in our storage), inside, picks, said (what a
/// search reads)}. From _set_catalog.json
/// beside this file in a deployment, or assets/generated in a checkout;
/// null where there is neither.
export function setCatalog() {
  if (catalog !== null) return catalog || null;
  for (const where of ["./_set_catalog.json", "../assets/generated/set_catalog.json"]) {
    const url = new URL(where, import.meta.url);
    if (existsSync(url)) return useCatalog(JSON.parse(readFileSync(url, "utf8")));
  }
  return null;
}

/// [raw] (tools/set_catalog.py's file) as setCatalog keeps it: a test's own,
/// or null for a deployment with none (the library is LDraw's shelf alone).
export function useCatalog(raw) {
  if (raw === null) {
    catalog = false;
    return null;
  }
  const themes = new Map();
  for (const [id, row] of Object.entries(raw?.themes || {})) {
    if (Array.isArray(row)) themes.set(Number(id), { name: word(String(row[0]), 120), parent: Number(row[1]) || 0 });
  }
  const pathOf = (id) => {
    const names = [];
    for (let at = id, hops = 0; at && themes.has(at) && hops < 8; hops += 1) {
      names.unshift(themes.get(at).name);
      at = themes.get(at).parent;
    }
    return names;
  };
  const sets = [];
  const by = new Map();
  for (const row of Array.isArray(raw?.sets) ? raw.sets : []) {
    const [number, name, year, theme, parts, figs, lots, photo] = row;
    if (!SET_NUMBER.test(String(number)) || by.has(String(number).toLowerCase())) continue;
    const path = pathOf(Number(theme));
    const entry = {
      set: String(number), name: word(String(name), 200) || String(number), year: Number(year) || 0, theme: path,
      parts: Number(parts) || 0, figs: Number(figs) || 0, lots: Number(lots) || 0, photo: photo === 1,
      inside: (raw.inside?.[number] || []).filter((one) => Array.isArray(one) && SET_NUMBER.test(String(one[0])))
        .map(([other, n]) => [String(other), Number(n) || 1]),
      picks: (raw.picks?.[number] || []).filter((one) => typeof one === "string"),
    };
    entry.said = `${entry.name} ${entry.set} ${path.join(" ")}`.toLowerCase();
    sets.push(entry);
    by.set(entry.set.toLowerCase(), entry);
  }
  catalog = { sets, by, themes };
  return catalog;
}

/// A set of the catalogue by its number, case not minded, "-1" understood
/// ("10497" is 10497-1); null for none.
export function catalogSet(number, given = setCatalog()) {
  const asked = String(number || "").trim().toLowerCase();
  if (!given || !SET_NUMBER.test(asked)) return null;
  return given.by.get(asked) || (asked.includes("-") ? null : given.by.get(`${asked}-1`)) || null;
}

/// "Star Wars > Ultimate Collector Series".
export const themeWords = (entry) => entry.theme.join(" > ");

/// LDraw's 3D models of each set (api/_library.js librarySets), by the set's
/// lower-cased number: {main, more}, main its model of the set itself and
/// more its others (another build of it, a second model), kept while the
/// shelf is the same.
let modelled = { from: null, by: new Map() };
export function modelsBySet(models) {
  if (models === modelled.from) return modelled.by;
  const by = new Map();
  for (const one of Array.isArray(models) ? models : []) {
    const key = String(one.set || "").toLowerCase();
    if (!key) continue;
    if (!by.has(key)) by.set(key, { main: null, more: [] });
    const held = by.get(key);
    if (!held.main && !one.alternate_of) held.main = one;
    else held.more.push(one);
  }
  modelled = { from: models, by };
  return by;
}

/// What a page of the library asks, from an address's query, checked here:
/// q (a set's number or words of its name or theme), theme (a top theme, or
/// a path to one inside it, "Star Wars > Ultimate Collector Series"),
/// decade ("1990s"), year, size (the gallery's SIZES), model ("3d": only
/// those LDraw has a model of), figs ("with" or "none"), sort (SETS_SORTS),
/// page (from 1). Anything else is left out, as if not asked.
export function askSets(query = {}) {
  const page = Number.parseInt(String(query.page ?? "1"), 10);
  const year = Number.parseInt(String(query.year ?? ""), 10);
  return {
    q: word(String(query.q ?? ""), MAX_QUERY),
    theme: word(String(query.theme ?? ""), 300),
    decade: /^(19|20)[0-9]0s$/.test(String(query.decade ?? "")) ? String(query.decade) : "",
    year: Number.isInteger(year) && year >= 1940 && year <= 2100 ? year : 0,
    size: Object.hasOwn(SIZES, String(query.size ?? "")) ? String(query.size) : "",
    model: String(query.model ?? "") === "3d" ? "3d" : "",
    figs: ["with", "none"].includes(String(query.figs ?? "")) ? String(query.figs) : "",
    sort: Object.hasOwn(SETS_SORTS, String(query.sort ?? "")) ? String(query.sort) : FIRST_SORT,
    page: Number.isFinite(page) ? Math.min(Math.max(page, 1), MOST_PAGES) : 1,
  };
}

/// Two names in the app's order: numbers by their value, case not minded.
const byName = (a, b) => a.name.localeCompare(b.name, "en", { numeric: true, sensitivity: "base" });
/// Two set numbers in order: 6020-1 before 10497-1.
const byNumber = (a, b) => a.set.localeCompare(b.set, "en", { numeric: true, sensitivity: "base" });

/// Whether a search is a set's number, "10497" or "10497-1", and so its set
/// (or sets) first, before whatever else names it.
function numberAsked(q) {
  const plain = q.trim().toLowerCase();
  return /^[a-z0-9]+(-[0-9]+)?$/.test(plain) && /[0-9]/.test(plain) ? plain : "";
}

/// The sets [ask] (askSets) asks for, a page of them: {sets, total, page,
/// pages}. Every word must be in the set's name, number or theme. With
/// nothing typed and no 3D asked for, a set Rebrickable lists with no parts
/// is left out: the library is browsed for sets, not books and key rings.
export function searchCatalog(sets, ask, models = new Map()) {
  const words = ask.q.toLowerCase().split(" ").filter(Boolean);
  const theme = ask.theme ? ask.theme.split(">").map((one) => one.trim()).filter(Boolean) : [];
  const decade = ask.decade ? Number(ask.decade.slice(0, 4)) : -1;
  const size = SIZES[ask.size] || null;
  const number = numberAsked(ask.q);
  const browsing = !words.length && !ask.model;
  const found = sets.filter((entry) => {
    if (browsing && entry.parts <= 0) return false;
    if (theme.length && theme.some((name, at) => entry.theme[at] !== name)) return false;
    if (decade >= 0 && Math.floor(entry.year / 10) * 10 !== decade) return false;
    if (ask.year && entry.year !== ask.year) return false;
    if (size && (entry.parts < (size.least || 0) || entry.parts > (size.most ?? Infinity))) return false;
    if (ask.figs === "with" && !entry.figs) return false;
    if (ask.figs === "none" && entry.figs) return false;
    if (ask.model && !models.get(entry.set.toLowerCase())?.main) return false;
    return words.every((one) => entry.said.includes(one));
  });
  // A year's biggest sets first: a year holds key rings and promotions too.
  const built = (entry) => (models.get(entry.set.toLowerCase())?.main ? 1 : 0);
  const order = {
    built: (a, b) => built(b) - built(a) || b.year - a.year || b.parts - a.parts,
    oldest: (a, b) => a.year - b.year || b.parts - a.parts,
    largest: (a, b) => b.parts - a.parts,
    smallest: (a, b) => a.parts - b.parts,
    name: (a, b) => byName(a, b),
    newest: (a, b) => b.year - a.year || b.parts - a.parts,
  }[ask.sort] || ((a, b) => b.year - a.year || b.parts - a.parts);
  const exact = (entry) => {
    if (!number) return 1;
    const key = entry.set.toLowerCase();
    return key === number || key === `${number}-1` ? 0 : key.startsWith(number) ? 1 : 2;
  };
  found.sort((a, b) => exact(a) - exact(b) || order(a, b) || byName(a, b) || byNumber(a, b));
  const pages = Math.max(1, Math.ceil(found.length / PER_PAGE));
  const page = Math.min(ask.page, pages);
  return { sets: found.slice((page - 1) * PER_PAGE, page * PER_PAGE), total: found.length, page, pages };
}

/// The theme tree the library filters by: every top theme with how many
/// sets it has (with parts) and the themes inside it, each with theirs.
export function themeTree(sets) {
  const tops = new Map();
  for (const entry of sets) {
    if (!entry.theme.length || entry.parts <= 0) continue;
    const [top, inner] = entry.theme;
    if (!tops.has(top)) tops.set(top, { name: top, n: 0, sub: new Map() });
    const held = tops.get(top);
    held.n += 1;
    if (inner) held.sub.set(inner, (held.sub.get(inner) || 0) + 1);
  }
  const named = (a, b) => a.name.localeCompare(b.name, "en");
  return [...tops.values()].sort(named).map((one) => ({ name: one.name, n: one.n,
    sub: [...one.sub].map(([name, n]) => ({ name, n })).sort(named) }));
}

/// The decades and years there are sets of, newest first.
export function yearsOf(sets) {
  const years = [...new Set(sets.filter((entry) => entry.year > 0 && entry.parts > 0).map((entry) => entry.year))]
    .sort((a, b) => b - a);
  const decades = [...new Set(years.map((year) => `${Math.floor(year / 10) * 10}s`))];
  return { decades, years };
}

/// A set's own page, its picture and its parts, under /library/set/.
export const pageOf = (entry) => `/library/set/${entry.set}`;

/// The picture a set is shown by: LDraw's model's render where it has one
/// (api/share.js set_cover); else its own, Rebrickable's, from our storage
/// (api/share.js catalog_photo): a card's 4:3 and the page's its own
/// shape; else the one drawn here from its parts (api/_flatlay.js); "" for
/// a set with none of these.
export function pictureOf(entry, model, as = "card") {
  if (model) return `/library/${model.id}${as === "card" ? "" : ".cutout"}.webp`;
  if (entry.photo) return `${pageOf(entry)}${as === "card" ? "" : ".page"}.webp`;
  return entry.picks.length ? `${pageOf(entry)}.jpg` : "";
}

/// Whether a set is shown by its own picture: Rebrickable's, credited.
export const photoOf = (entry, model) => !model && entry.photo;

/// A set as a card (web/card.js cardHtml): its page and picture named,
/// marked 3D when LDraw has a model of it, and who modelled that.
export function catalogCard(entry, models = new Map()) {
  const model = models.get(entry.set.toLowerCase())?.main || null;
  return {
    id: `${CARD_ID}${entry.set}`, name: entry.name, parts: entry.parts,
    modelled_by: model && model.author && model.page ? { name: model.author, page: model.page } : null,
    library: { set: entry.set, theme: entry.theme[0] || "", year: entry.year, page: pageOf(entry),
      picture: pictureOf(entry, model), model3d: Boolean(model), figs: entry.figs },
  };
}

/// "10497-1 Galaxy Explorer".
export const titleOf = (entry) => `${entry.set} ${entry.name}`;

/// The sets a set's page ends with: its theme's (as deep as it goes), the
/// nearest in years first.
export function setsBeside(sets, entry, most = NEXT_MOST) {
  if (!entry.theme.length) return [];
  const path = entry.theme.join(">");
  const top = entry.theme[0];
  const kin = (same) => sets.filter((one) => one !== entry && one.parts > 0 && same(one));
  let found = kin((one) => one.theme.join(">") === path);
  if (found.length < 4) found = kin((one) => one.theme[0] === top);
  return found.sort((a, b) => Math.abs(a.year - entry.year) - Math.abs(b.year - entry.year) || byNumber(a, b))
    .slice(0, most);
}

/// What the assistant is asked to start from, in the person's own words box
/// (/app?brief=, not sent until they send it): the set and its parts, the
/// most of a lot first, the rest counted.
export function starterBrief(entry, lots = []) {
  const shown = [...lots].sort((a, b) => b.count - a.count).slice(0, BRIEF_LOTS)
    .map((lot) => `${lot.count} × ${lot.name} in ${lot.colour_name}`);
  const rest = lots.length - shown.length;
  return `Design something new of your own with the parts of LEGO® set ${titleOf(entry)} `
    + `(${count(entry.parts, "part")}${shown.length ? `: ${shown.join(", ")}${rest > 0 ? `, and ${count(rest, "more lot")}` : ""}` : ""}). `
    + "Use only those parts, in those colours.";
}

/// The app opened with the set's parts in its parts bin (Main's --parts),
/// a tab of its own.
export const binLink = (entry) => `/app?new=1&parts=${encodeURIComponent(entry.set)}`;
/// The app opened with the assistant on and its brief drafted (--brief).
export const designLink = (entry, lots) => `/app?new=1&assistant=on&parts=${encodeURIComponent(entry.set)}`
  + `&brief=${encodeURIComponent(starterBrief(entry, lots))}`;

/// How much of a set somebody owns, as the app's collection counts it
/// (api/_owned.js keyed: a part by the number it means today, a mould's
/// letter left off, a colour by the one a shop files it under), its lots
/// taken from their pool one at a time: {pieces (those a collection can
/// hold), have, missing [[part, colour, qty]] in the set's own numbers}.
/// [rows] is the set's inventory, [pool] keyed lots, [keyOf] api/_owned.js
/// keyed of one lot.
export function ownedOf(rows, pool, keyOf) {
  const left = new Map(pool.map((lot) => [`${lot.part}/${lot.colour}`, lot.qty]));
  let pieces = 0;
  let have = 0;
  const missing = [];
  for (const [part, colour, qty] of rows) {
    const keyed = keyOf([part, colour, qty]);
    if (!keyed) continue;
    const key = `${keyed.part}/${keyed.colour}`;
    const held = left.get(key) || 0;
    const taken = Math.min(held, qty);
    left.set(key, held - taken);
    pieces += qty;
    have += taken;
    if (taken < qty) missing.push([part, colour, qty - taken]);
  }
  return { pieces, have, missing };
}

/// A set's facts, in a page's pills: its parts, its minifigures, its year
/// and its theme (each a way to more of the library), and that LDraw has a
/// 3D model of it.
function facts(entry, model) {
  const decade = entry.year ? `${Math.floor(entry.year / 10) * 10}s` : "";
  const theme = entry.theme.map((name, at) => {
    const path = entry.theme.slice(0, at + 1).join(" > ");
    return `<li><a class="pill" href="/library?theme=${encodeURIComponent(path)}">${escapeHtml(name)}</a></li>`;
  }).join("");
  return [
    `<li class="pill" data-parts="${entry.parts}">${escapeHtml(count(entry.parts, "part"))}</li>`,
    entry.lots ? `<li class="pill">${escapeHtml(count(entry.lots, "lot"))}</li>` : "",
    entry.figs ? `<li class="pill" data-figs="${entry.figs}">${escapeHtml(count(entry.figs, "minifigure"))}</li>` : "",
    decade ? `<li><a class="pill" href="/library?decade=${decade}&amp;year=${entry.year}">${entry.year}</a></li>` : "",
    theme,
    model ? `<li><a class="pill good" href="/library/${escapeHtml(model.id)}">3D model</a></li>` : "",
  ].join("");
}

/// What a search engine reads of the page: schema.org's CreativeWork (never
/// a Product: there is nothing sold here, no offer and no price) and its
/// place in the library as a BreadcrumbList. A data block, never run; its
/// "<" written as \u003c.
function structured(origin, entry, picture, description) {
  const url = `${origin}${pageOf(entry)}`;
  const crumbs = [["Library", `${origin}/library`], ...entry.theme.map((name, at) =>
    [name, `${origin}/library?theme=${encodeURIComponent(entry.theme.slice(0, at + 1).join(" > "))}`]),
  [entry.name, url]];
  const data = [{
    "@context": "https://schema.org", "@type": "CreativeWork", name: `LEGO® set ${titleOf(entry)}`, url,
    identifier: entry.set, description, image: picture ? `${origin}${picture}` : undefined,
    dateCreated: entry.year ? String(entry.year) : undefined, genre: entry.theme.join(" > ") || undefined,
    isAccessibleForFree: true,
    citation: { "@type": "Dataset", name: "Rebrickable set and inventory data", url: CREDIT.url },
  }, {
    "@context": "https://schema.org", "@type": "BreadcrumbList",
    itemListElement: crumbs.map(([name, item], at) => ({ "@type": "ListItem", position: at + 1, name, item })),
  }];
  return `<script type="application/ld+json">${JSON.stringify(data).replace(/</g, "\\u003c")}</script>`;
}

/// A set's page (/library/set/X). [chrome] the site's head, header and
/// footer (api/_directory.js siteChrome); [held] LDraw's models of it
/// (modelsBySet); [inside] the sets packed in it that the catalogue has;
/// [next] cards (catalogCard) of its theme, drawn with [cardHtml]; [lots]
/// its parts list's lots, for the assistant's brief; [origin] the site.
export function setPage({ origin, entry, chrome, held = null, inside = [], next = [], lots = [], cardHtml }) {
  const model = held?.main || null;
  const others = [...(model ? [model] : []), ...(held?.more || [])];
  const picture = pictureOf(entry, model, "page");
  const photo = photoOf(entry, model);
  const small = pictureOf(entry, model, "card");
  const said = [entry.year ? String(entry.year) : "", themeWords(entry)].filter(Boolean).join(", ");
  const description = `LEGO® set ${titleOf(entry)}${said ? ` (${said})` : ""}: `
    + `${count(entry.parts, "part")}${entry.lots ? ` in ${count(entry.lots, "lot")}` : ""}`
    + `${entry.figs ? ` and ${count(entry.figs, "minifigure")}` : ""}. See every part, check what you own, `
    + "and build with them in Brickworks.";
  const title = `${entry.name}, LEGO® set ${entry.set}: every part — Brickworks`;
  const url = `${origin}${pageOf(entry)}`;
  const image = small ? `${origin}${small}` : `${origin}/share.png`;
  const crumbs = [`<a href="/library">Library</a>`, ...entry.theme.map((name, at) =>
    `<a href="/library?theme=${encodeURIComponent(entry.theme.slice(0, at + 1).join(" > "))}">${escapeHtml(name)}</a>`)]
    .join(' <span aria-hidden="true">›</span> ');
  const viewer = model ? `/app?new=1&library=${encodeURIComponent(model.id)}` : "";
  const alt = model ? `LDraw's 3D model of ${entry.name}` : photo ? `${entry.name}, LEGO® set ${entry.set}`
    : `Some of the parts of ${entry.name}, drawn by Brickworks`;
  const pictureHtml = picture
    ? `<span class="waiting" aria-hidden="true">Loading its picture…</span><img src="${escapeHtml(picture)}" `
      + `alt="${escapeHtml(alt)}" width="1200" height="630" fetchpriority="high">`
      + `${model ? '<span class="go" aria-hidden="true">View in 3D</span>' : ""}`
    : `<span class="none">No picture: Rebrickable lists no parts for it</span>`;
  // Its own picture is Rebrickable's, and said so under it, short.
  const pictureCredit = photo
    ? `<p class="picture-credit">Picture: <a href="${escapeHtml(creditOf(entry))}">Rebrickable</a></p>` : "";
  const insideHtml = inside.length
    ? `<section class="words" id="inside" aria-labelledby="inside-h"><h2 id="inside-h">Sets packed in it</h2><ul class="pills">`
      + inside.map(([one, n]) => `<li><a class="pill" href="${pageOf(one)}">${n > 1 ? `${n} × ` : ""}`
        + `${escapeHtml(titleOf(one))}</a></li>`).join("") + "</ul></section>" : "";
  const modelsHtml = others.length
    ? `<section class="words" id="models3d" aria-labelledby="models3d-h"><h2 id="models3d-h">In 3D</h2><ul class="list">`
      + others.map((one) => `<li><a href="/library/${escapeHtml(one.id)}">${escapeHtml(one.name)}</a>`
        + `${one.author ? `, modelled by ${escapeHtml(one.author)} for LDraw's Official Model Repository` : ""}</li>`).join("")
      + "</ul></section>" : "";
  const partsHtml = entry.lots
    ? `<section class="parts" id="parts" aria-labelledby="parts-h" data-parts="${pageOf(entry)}/parts.json">`
      + `<h2 id="parts-h">Parts</h2><p class="note">${escapeHtml(count(entry.parts, "part"))} in ${escapeHtml(count(entry.lots, "lot"))}, `
      + `its minifigures' and the sets packed in it counted in, spares not</p>`
      + `<div class="parts-bar"><div class="segmented" role="group" aria-label="Group them by">`
      + `<button type="button" data-group="colour" aria-pressed="true">Colour</button>`
      + `<button type="button" data-group="kind" aria-pressed="false">Kind</button></div>`
      + `<a class="cta ghost small" href="${pageOf(entry)}/parts.xml" download>BrickLink XML</a>`
      + `<a class="cta ghost small" href="${pageOf(entry)}/parts.csv" download>Rebrickable CSV</a></div>`
      + `<ul class="lot-list" style="min-height:${Math.min(12, entry.lots) * 60}px"></ul>`
      + (entry.lots > 12 ? `<button type="button" class="cta ghost small" data-all hidden>Show all ${escapeHtml(count(entry.lots, "lot"))}</button>` : "")
      + "</section>"
    : `<section class="parts" id="parts-none"><h2>Parts</h2><p class="note">Rebrickable lists no parts for it: `
      + "a book, gear or something else that is not built.</p></section>";
  const owned = entry.lots
    ? `<section class="owned" id="owned" data-set="${escapeHtml(entry.set)}" aria-live="polite" hidden>`
      + `<h2 id="owned-h">Parts you own</h2><p class="owned-said" id="owned-said"></p>`
      + `<div class="actions" id="owned-wanted" hidden><span class="note">What you are missing, as a wanted list:</span>`
      + `<button type="button" class="cta ghost small" data-wanted="bricklink">BrickLink XML</button>`
      + `<button type="button" class="cta ghost small" data-wanted="rebrickable">Rebrickable CSV</button></div></section>`
    : "";
  const nextHtml = next.length
    ? `<section class="next" id="similar" aria-labelledby="similar-h"><h2 id="similar-h">More ${escapeHtml(entry.theme[entry.theme.length - 1] || "sets")}</h2>`
      + `<div class="models compact">${next.map((card) => cardHtml(card)).join("")}</div></section>` : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
<link rel="canonical" href="${escapeHtml(url)}">
${entry.parts > 0 ? "" : '<meta name="robots" content="noindex">\n'}<meta property="og:type" content="website">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(url)}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
${chrome.head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<link rel="stylesheet" href="/view3d.css">
<script src="/model-page.js" type="module"></script>
<script src="/set-page.js" type="module"></script>
${structured(origin, entry, small, description)}
</head>
<body data-set="${escapeHtml(entry.set)}">
<a class="skip" href="#main">Skip to content</a>
${chrome.header}
<main id="main">
<article class="wrap wide model-page set-page" data-set="${escapeHtml(entry.set)}"${model ? ` data-model="${escapeHtml(model.id)}"` : ""}>
  <nav class="crumbs" aria-label="Where it is">${crumbs}</nav>
  <div class="top">
    <div class="media">
    ${viewer ? `<a class="picture" href="${escapeHtml(viewer)}" aria-label="View ${escapeHtml(entry.name)} in 3D" `
      + `data-scene="/library/${escapeHtml(model.id)}/scene.json" data-parts="${Number(model.parts) || 0}">${pictureHtml}</a>`
    : `<div class="picture${photo ? " photo" : ""}">${pictureHtml}</div>`}
    ${pictureCredit}
    </div>
    <div class="side">
      <h1>${escapeHtml(entry.name)}</h1>
      <p class="modelled">LEGO® set ${escapeHtml(entry.set)}${entry.year ? `, from ${entry.year}` : ""}</p>
      <div class="actions">
        ${model ? `<a class="cta" href="${escapeHtml(viewer)}" data-build3d title="Open LDraw's 3D model of it in Brickworks: turn it, step through its build, change it">Build it in 3D</a>` : ""}
        ${entry.lots ? `<a class="cta${model ? " ghost" : ""}" href="${escapeHtml(binLink(entry))}" data-bin title="Open Brickworks with this set's parts in its parts bin">Open its parts in Brickworks</a>
        <a class="cta ghost" href="${escapeHtml(designLink(entry, lots))}" data-design title="Open Brickworks with the assistant on and a brief naming these parts, for your own AI to design with">Design with these parts</a>` : ""}
      </div>
      <ul class="facts pills">${facts(entry, model)}</ul>
      ${model ? `<p class="from">LDraw's model of it has <a href="/library/${escapeHtml(model.id)}">a page of its own</a>: who modelled it, its steps and its file.</p>` : ""}
    </div>
    <div class="rest">
  ${owned}
  ${partsHtml}
  ${insideHtml}
  ${modelsHtml}
  <section class="words" id="about" aria-labelledby="about-h"><h2 id="about-h">About this page</h2>
    <p class="credit">Set and inventory data: <a href="${CREDIT.url}">Rebrickable</a>.${photo
    ? ` The set's picture is <a href="${escapeHtml(creditOf(entry))}">Rebrickable's</a>.`
    : ""} The parts are drawn by Brickworks from LDraw's geometry. LEGO® is a trademark of the LEGO Group,
    which does not sponsor, authorise or endorse this site.</p></section>
    </div>
  </div>
  ${nextHtml}
</article>
</main>
${chrome.footer}
</body>
</html>`;
}

/// The sitemap files of the sets' pages: their number, and each one's URLs
/// (every set Rebrickable lists parts for: a page of nothing is not one a
/// search should find).
export function sitemapSets(sets, origin) {
  const listed = sets.filter((entry) => entry.parts > 0);
  const files = [];
  for (let at = 0; at < listed.length; at += SITEMAP_SETS) {
    files.push(listed.slice(at, at + SITEMAP_SETS).map((entry) => `${origin}${pageOf(entry)}`));
  }
  return files;
}
