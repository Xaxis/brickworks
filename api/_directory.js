// The directory of shared models (2026-10-13): what the gallery's list,
// a model's page and publishing share about it. supabase/directory.sql has
// the columns and the functions behind it; api/share.js is the endpoint.
//
// Every word here that a page shows was typed by a stranger — a name, a
// credit, a description, a tag — so each is checked at this edge (one
// printable line, or for a description printable lines, all capped), and
// escaped by whatever puts it on a page.

import { createHash, createHmac } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";

/// The kinds of model the gallery filters by. The same ids, in the same
/// order, as src/net/model_kinds.gd, which guesses one from a model's name
/// and tags with the subject vocabulary (SubjectWords) for its owner to
/// change in the Share panel; share_probe holds the two lists together.
export const KINDS = [
  { id: "castle", label: "Castles and fantasy" },
  { id: "space", label: "Space" },
  { id: "vehicle", label: "Vehicles" },
  { id: "town", label: "Town and buildings" },
  { id: "architecture", label: "Architecture" },
  { id: "mechanism", label: "Mechanisms" },
  { id: "robot", label: "Robots and machines" },
  { id: "nature", label: "Animals and nature" },
  { id: "figure", label: "Figures and characters" },
  { id: "art", label: "Art and mosaics" },
  { id: "other", label: "Something else" },
];
const KIND_IDS = new Set(KINDS.map((k) => k.id));
export const kindLabel = (id) => (KINDS.find((k) => k.id === id) || {}).label || "";

/// What a model's owner may let others do with it, chosen in the Share
/// panel; CC BY unless they choose otherwise. A model shared before there
/// was a choice has none (null), and its page says so rather than say it
/// is licensed.
export const LICENCES = {
  "cc-by-4.0": {
    name: "CC BY 4.0",
    url: "https://creativecommons.org/licenses/by/4.0/",
    says: "Anyone may share it, change it and build on it, for any purpose, as long as they credit",
  },
  "cc-by-sa-4.0": {
    name: "CC BY-SA 4.0",
    url: "https://creativecommons.org/licenses/by-sa/4.0/",
    says: "Anyone may share it, change it and build on it, as long as they credit it and share what they make under the same licence. Credit",
  },
  "all-rights-reserved": {
    name: "All rights reserved",
    url: "",
    says: "Look at it and build it for yourself; ask before sharing a copy or a version of it. Made by",
  },
};

/// The gallery's sizes, by part count.
export const SIZES = {
  small: { most: 199, label: "Small, under 200 parts" },
  medium: { least: 200, most: 999, label: "Medium, 200 to 999 parts" },
  large: { least: 1000, label: "Large, 1,000 parts or more" },
};
export const SORTS = {
  newest: "Newest", views: "Most viewed", likes: "Most liked", remixes: "Most remixed",
};

export const MAX_DESCRIPTION = 1000;
export const MAX_TAGS = 8;
const MAX_TAG = 24;
const MAX_QUERY = 100;

export class Unacceptable extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// What an owner says about a model.

/// A description: printable lines, at most MAX_DESCRIPTION characters,
/// runs of blank lines made one; null for none.
export function cleanDescription(given) {
  if (given === undefined) return undefined;
  if (given === null || given === "") return null;
  if (typeof given !== "string") throw new Unacceptable("a description is text");
  const text = given.replace(/\r\n?/g, "\n")
    .replace(/[\u0000-\u0008\u000b-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .split("\n").map((line) => line.replace(/\s+/g, " ").trim()).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim();
  if (text.length > MAX_DESCRIPTION) {
    throw new Unacceptable(`a description is at most ${MAX_DESCRIPTION} characters; this one is ${text.length}`);
  }
  return text || null;
}

/// One tag: lower case, letters, digits, spaces and hyphens, 2 to 24
/// characters; "" when nothing of it is left.
export function cleanTag(given) {
  return String(given).toLowerCase().normalize("NFC")
    .replace(/[^\p{L}\p{N} -]+/gu, " ").replace(/\s+/g, " ").replace(/^[ -]+|[ -]+$/g, "")
    .slice(0, MAX_TAG).replace(/[ -]+$/g, "");
}

/// Tags, given as a list or as words between commas: each cleaned, the
/// same one once, at most MAX_TAGS.
export function cleanTags(given) {
  if (given === undefined) return undefined;
  if (given === null || given === "") return [];
  const list = typeof given === "string" ? given.split(",") : given;
  if (!Array.isArray(list) || list.some((tag) => typeof tag !== "string")) {
    throw new Unacceptable("tags are a list of words, or words between commas");
  }
  const tags = [...new Set(list.map(cleanTag).filter((tag) => tag.length >= 2))];
  if (tags.length > MAX_TAGS) throw new Unacceptable(`at most ${MAX_TAGS} tags; that is ${tags.length}`);
  return tags;
}

export function cleanKind(given) {
  if (given === undefined) return undefined;
  if (given === null || given === "") return null;
  if (typeof given !== "string" || !KIND_IDS.has(given)) {
    throw new Unacceptable(`a kind is one of ${[...KIND_IDS].join(", ")}`);
  }
  return given;
}

export function cleanLicence(given) {
  if (given === undefined) return undefined;
  if (typeof given !== "string" || !(given in LICENCES)) {
    throw new Unacceptable(`a licence is one of ${Object.keys(LICENCES).join(", ")}`);
  }
  return given;
}

// ---------------------------------------------------------------------------
// What a model is, read from its file: which of its parts are Technic, and
// which make it move.

let facts = null;

/// From the catalogue the app is built with: every Technic part, and the
/// parts that make a mechanism — gears, worms, differentials, motors,
/// actuators, chains. The sub-parts a part is drawn from (names starting
/// "~") are neither.
export function derivePartFacts(catalogue) {
  const technic = [];
  const mechanism = [];
  const MOVES = /\b(gear|gears|worm|differential|turntable|motor|crankshaft|chain link|gearbox|actuator|pneumatic|pump)\b/i;
  const moved = [];
  for (const part of catalogue.parts || []) {
    const name = String(part.name || "");
    // A number LDraw retired for another still names that part in older
    // files: 3648 is the 24-tooth gear, 3648b now.
    if (part.moved_to) moved.push([part.id, String(part.moved_to)]);
    if (name.startsWith("~") || /sticker/i.test(String(part.category || ""))) continue;
    const category = String(part.category || "");
    if (category === "Technic") technic.push(part.id);
    if ((category === "Technic" || category === "Electric") && MOVES.test(name)) mechanism.push(part.id);
  }
  const isTechnicPart = new Set(technic);
  const moves = new Set(mechanism);
  for (const [from, to] of moved) {
    if (isTechnicPart.has(to)) technic.push(from);
    if (moves.has(to)) mechanism.push(from);
  }
  return { technic: technic.sort(), mechanism: mechanism.sort() };
}

/// The part facts: beside this file in a deployment (deploy.sh writes them
/// with tools/web/part_facts.mjs), worked out from the catalogue in a
/// checkout, and none at all where there is neither — then nothing is
/// said to be Technic, rather than everything said not to be.
export function partFacts() {
  if (facts) return facts;
  for (const [where, derive] of [["./_part_facts.json", false], ["../assets/generated/catalogue.json", true]]) {
    const url = new URL(where, import.meta.url);
    if (!existsSync(url)) continue;
    const raw = JSON.parse(readFileSync(url, "utf8"));
    const made = derive ? derivePartFacts(raw) : raw;
    facts = { known: true, technic: new Set(made.technic), mechanism: new Set(made.mechanism) };
    return facts;
  }
  facts = { known: false, technic: new Set(), mechanism: new Set() };
  return facts;
}

/// Whether a model is Technic or a mechanism, from how many of its parts
/// are which: two or more parts that make it move, or Technic for a
/// quarter of it and ten parts at least. Null when the catalogue is not
/// here to say.
export function isTechnic(parts, technicParts, movingParts) {
  if (!partFacts().known) return null;
  return movingParts >= 2 || (technicParts >= 10 && technicParts * 4 >= parts);
}

// ---------------------------------------------------------------------------
// The gallery's question.

/// What a search box's words ask, as a tsquery over directory_words: each
/// word of two letters or more a prefix, all of them wanted. A plural
/// asks for its singular ("castles" finds a castle), and nothing but
/// letters and digits ever reaches the query.
export function searchWords(given) {
  const text = String(given || "").slice(0, MAX_QUERY).toLowerCase().normalize("NFC");
  const words = (text.match(/[\p{L}\p{N}]+/gu) || [])
    .filter((word) => word.length >= 2)
    .map((word) => {
      if (word.length > 4 && /(ses|xes|zes|ches|shes)$/.test(word)) return word.slice(0, -2);
      if (word.length > 3 && /s$/.test(word) && !/ss$/.test(word)) return word.slice(0, -1);
      return word;
    })
    .map((word) => word.slice(0, 30));
  const unique = [...new Set(words)].slice(0, 8);
  return unique.length ? unique.map((word) => `${word}:*`).join(" & ") : null;
}

const YES = new Set(["1", "true", "yes", "on"]);

/// Whether a list is asked for with test models in it (?tests=1): what a
/// test account published, which no visitor is shown
/// (supabase/test_models.sql). Only the probes ask.
export function testsAsked(query) {
  const value = String(query?.tests ?? "").toLowerCase();
  if (!value || value === "0" || value === "false") return false;
  if (!YES.has(value)) throw new Unacceptable("tests is 1 or left out");
  return true;
}

/// What the CDN may keep of an answer with test models in it: nothing. The
/// parameter is part of the address the CDN keeps an answer under, so a
/// visitor's list is never one asked with it; and an answer that has test
/// models in it is not kept at all.
export const TESTS_CACHE = "private, no-store";

/// The list's query string, checked: {asked, said}. asked is what
/// directory_models takes; said is the query as understood, for the answer.
export function listQuery(query, perPage, mostPages) {
  const page = Number(query.page ?? 1);
  if (!Number.isInteger(page) || page < 1 || page > mostPages) {
    throw new Unacceptable(`page is a whole number from 1 to ${mostPages}`);
  }
  const said = { page };
  const asked = { size: perPage + 1, skip: (page - 1) * perPage };
  const q = String(query.q ?? "").trim();
  if (q.length > MAX_QUERY) throw new Unacceptable(`a search is at most ${MAX_QUERY} characters`);
  if (q) {
    said.q = q;
    asked.words = searchWords(q);
  }
  const kind = String(query.kind ?? "");
  if (kind) {
    if (!KIND_IDS.has(kind)) throw new Unacceptable(`kind is one of ${[...KIND_IDS].join(", ")}`);
    said.kind = asked.kind = kind;
  }
  const size = String(query.size ?? "");
  if (size) {
    if (!(size in SIZES)) throw new Unacceptable(`size is one of ${Object.keys(SIZES).join(", ")}`);
    said.size = size;
    if (SIZES[size].least) asked.least = SIZES[size].least;
    if (SIZES[size].most) asked.most = SIZES[size].most;
  }
  for (const [name, column] of [["instructions", "own_steps"], ["technic", "technic"]]) {
    const value = String(query[name] ?? "").toLowerCase();
    if (!value || value === "0" || value === "false") continue;
    if (!YES.has(value)) throw new Unacceptable(`${name} is 1 or left out`);
    said[name] = true;
    asked[column] = true;
  }
  const tag = query.tag === undefined ? "" : cleanTag(query.tag);
  if (query.tag !== undefined && String(query.tag) !== "") {
    if (tag.length < 2) throw new Unacceptable("a tag is two letters or more");
    said.tag = asked.tag = tag;
  }
  const sort = String(query.sort ?? "newest") || "newest";
  if (!(sort in SORTS)) throw new Unacceptable(`sort is one of ${Object.keys(SORTS).join(", ")}`);
  said.sort = asked.sort = sort;
  if (testsAsked(query)) said.tests = asked.tests = true;
  return { asked, said };
}

/// A card as a client is given it: what directory_card read, and where its
/// page and pictures are.
export function cardOf(origin, row) {
  const url = `${origin}/m/${row.id}`;
  const version = Date.parse(row.updated_at || "") || 0;
  return {
    id: row.id, name: row.name, author: row.author, parts: row.parts, listed_at: row.listed_at,
    kind: row.kind ?? null, tags: row.tags || [], licence: row.licence ?? null,
    steps: row.steps ?? null, own_steps: row.own_steps === true, technic: row.technic === true,
    views: Number(row.views) || 0, likes: Number(row.likes) || 0, remixes: Number(row.remixes) || 0,
    by: row.by && typeof row.by === "object" ? { handle: row.by.handle, name: row.by.name } : null,
    url, image: row.has_image ? `${url}.png` : null,
    thumb: row.has_thumb ? `${url}.webp?v=${version.toString(36)}` : null,
  };
}

/// A model file's fingerprint: its SHA-256, line endings and the space at
/// its ends made the same, so the file a model was taken out of the gallery
/// with is known again at any link (supabase/moderation.sql barred_models).
export function modelHash(text) {
  const plain = String(text || "").replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n")
    .split("\n").map((line) => line.trim()).filter(Boolean).join("\n");
  return createHash("sha256").update(plain, "utf8").digest("hex");
}

// ---------------------------------------------------------------------------
// Counting a view: once per visitor per day, never a bot's.

// What says it is not a person: crawlers, link previews, monitors, command
// lines and headless browsers — a test's too.
const BOT = /bot\b|bot\/|crawl|spider|slurp|preview|fetch|curl|wget|python|httpclient|http-client|okhttp|axios|undici|node|go-http|java\/|libwww|headless|lighthouse|pingdom|monitor|uptime|scan|facebookexternalhit|embedly|whatsapp|telegram|discord|slack|skype|vkshare|quora|pinterest|bing|yandex|baidu|duckduck|semrush|ahrefs|phantom|selenium|playwright|puppeteer/i;

/// Whether a request to count a view is a person's, as far as can be told:
/// a browser's fetch from one of this site's own pages (the Fetch Metadata
/// every current browser sends, which a page elsewhere cannot fake), with
/// a user agent that does not say it is a robot.
export function looksLikePerson(request) {
  const headers = request.headers || {};
  const agent = String(headers["user-agent"] || "");
  if (agent.length < 20 || BOT.test(agent)) return false;
  return String(headers["sec-fetch-site"] || "") === "same-origin";
}

/// Who is looking, as a key nobody can turn back into them: the day, the
/// model, the address and the browser, through an HMAC with a secret only
/// this server has. Another day, another key, so no visitor can be
/// followed from one day to the next, nor from one model to another.
export function visitorKey(request, id, day = new Date().toISOString().slice(0, 10)) {
  const headers = request.headers || {};
  const address = String(headers["x-real-ip"] || String(headers["x-forwarded-for"] || "").split(",")[0]).trim();
  const agent = String(headers["user-agent"] || "");
  const secret = process.env.VIEW_SECRET || process.env.SUPABASE_SECRET_KEY || "";
  return createHmac("sha256", `views:${secret}`).update(`${day}\n${id}\n${address}\n${agent}`)
    .digest("hex").slice(0, 32);
}

// ---------------------------------------------------------------------------
// A page of the site, made here: the site's own header and footer.

export const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// The LEGO Group's Fair Play policy asks for this on any page that names
// its mark (docs/TRADEMARKS.md); tests/test_trademarks.py holds it here.
export const NOTICE = "LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this site.";

let chrome = null;

/// The header and footer every page of the site has, taken from the
/// gallery's own page (web/gallery.html: beside this file as _site.html in
/// a deployment, where deploy.sh puts it), so a page made here changes
/// when the site's do. Nothing is marked as the page being looked at. A
/// plain header and footer, with the notice, if the page is not there.
export function siteChrome() {
  if (chrome) return chrome;
  let page = "";
  for (const where of ["./_site.html", "../web/gallery.html"]) {
    const url = new URL(where, import.meta.url);
    if (existsSync(url)) {
      page = readFileSync(url, "utf8");
      break;
    }
  }
  const header = (page.match(/<header class="site-head">[\s\S]*?<\/header>/) || [""])[0];
  const footer = (page.match(/<footer class="site-foot">[\s\S]*?<\/footer>/) || [""])[0];
  const plain = (html) => html.replace(/\s+aria-current="page"/g, "");
  chrome = {
    header: header ? plain(header) : `<header class="site-head"><div class="wrap bar">`
      + `<a class="mark" href="/"><span class="chip" aria-hidden="true"></span>Brickworks</a>`
      + `<nav class="nav" aria-label="Main"><a href="/gallery">Gallery</a>`
      + `<a class="cta" href="/app">Open the app</a></nav></div></header>`,
    footer: footer && footer.includes(NOTICE.slice(0, 40)) ? plain(footer)
      : `<footer class="site-foot"><div class="wrap legal"><p>${NOTICE}</p></div></footer>`,
  };
  return chrome;
}

/// "1,234 parts".
export function count(n, one, many = `${one}s`) {
  const value = Number(n) || 0;
  return `${value.toLocaleString("en-US")} ${value === 1 ? one : many}`;
}
