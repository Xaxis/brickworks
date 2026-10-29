// Who modelled a shared model somebody else made (gallery261, 2026-10-25):
// never what the file says of itself, which anyone can type, but the app's
// own Library, the index of LDraw's Official Model Repository it opens
// from (tools/library_build.py: library/index.json in the parts store, and
// each model's file beside it).
//
// The app writes "0 !BRICKWORKS CREDIT {by, licence, page, from}" into a
// model its Library opened, and the Share panel publishes it with it. Here
// only its page is read, to find the index's models of that page (a set's
// models share one); then each one's own file is fetched from the store
// and the shared file is held to it: the same name inside (an .mpd's first
// FILE, or a single model's "0 Name:", which the app keeps as it writes a
// model out again), and at least
// half of each one's parts, by part and colour, in the other. The name,
// the LDraw page and the licence are then the index's. A model the sharer
// changed keeps its credit and says it was changed (changed: true): its
// parts are not exactly the library model's. Anything else is nobody's.
//
// Proved by tests/test_modelled_by.py (a forged credit line gets nothing),
// and on a deployment by publishing a library model (gallery261's proof).

/// Whose words a library model's licence is in, as the site names it.
export const SITE_LICENCE = { "CCAL 2.0": "cc-by-2.0", "CC BY 4.0": "cc-by-4.0" };
/// Of a model's parts, the least that must be the library model's, and of
/// the library model's the least that must be in it.
export const LEAST_SHARED = 0.5;
/// A page names a set; a set has at most a few models.
const MOST_CANDIDATES = 8;
const INDEX_FOR_MS = 10 * 60 * 1000;

/// Where the store is, ending in "/": as api/_viewer.js partsRoot says it
/// (that module carries the viewer's page, too big to load for this).
export function storeRoot(env = process.env) {
  const named = env.PARTS_URL || (env.SUPABASE_URL ? `${env.SUPABASE_URL.replace(/\/+$/, "")}/storage/v1/object/public/parts/` : "");
  return named ? named.replace(/\/?$/, "/") : "";
}

let kept = { at: 0, models: null };

/// The library's models, as the app's Library reads them; kept a while.
/// The site's LDraw library reads them too (api/_library.js).
export async function storeIndex() {
  if (kept.models && Date.now() - kept.at < INDEX_FOR_MS) return kept.models;
  const root = storeRoot();
  if (!root) return [];
  const answer = await fetch(`${root}library/index.json`);
  if (!answer.ok) return [];
  const said = await answer.json();
  kept = { at: Date.now(), models: Array.isArray(said?.models) ? said.models : [] };
  return kept.models;
}

/// A library model's own file, as LDraw has it, or null. A set's page reads
/// it too (api/share.js), for its parts and steps.
export async function storeFile(entry) {
  const root = storeRoot();
  if (!root || typeof entry.file !== "string" || !/^library\/omr\/[A-Za-z0-9._-]+\.mpd$/.test(entry.file)) return null;
  const answer = await fetch(`${root}${entry.file}`);
  return answer.ok ? answer.text() : null;
}

/// The page the file's own credit line names, as a hint where to look; ""
/// for none.
function pageSaid(text) {
  const found = /^0 !BRICKWORKS CREDIT (\{.*\})[ \t\r]*$/m.exec(String(text || ""));
  if (!found) return "";
  try {
    const said = JSON.parse(found[1]);
    return typeof said?.page === "string" && said.page.startsWith("https://library.ldraw.org/") ? said.page : "";
  } catch {
    return "";
  }
}

/// What a library model is called inside its file, as a reader compares
/// names: an .mpd's first FILE, or, for a single model with none (17 of the
/// library's), its "0 Name:"; "" for neither. The app keeps both as it
/// writes a model out again.
function nameInside(text) {
  const said = String(text || "");
  const found = /^[ \t]*0[ \t]+FILE[ \t]+(.+?)[ \t\r]*$/m.exec(said)
    || /^[ \t]*0[ \t]+Name:[ \t]*(.+?)[ \t\r]*$/m.exec(said);
  return found ? found[1].toLowerCase() : "";
}

/// [needs] ([[part, colour, count]], as checkModel counts them) as counts by
/// part and colour, and their sum.
function counted(needs) {
  const by = new Map();
  let all = 0;
  for (const [part, colour, n] of needs || []) {
    const key = `${part}/${colour}`;
    by.set(key, (by.get(key) || 0) + n);
    all += n;
  }
  return { by, all };
}

/// Whether [text], with [needs], is [entry]'s model, held to its own file
/// [theirs]: {changed} when it is, null when it is not.
function heldTo(text, needs, theirs, needsOf) {
  const named = nameInside(text);
  if (!named || named !== nameInside(theirs)) return null;
  const ours = counted(needs);
  const library = counted(needsOf(theirs));
  if (!ours.all || !library.all) return null;
  let shared = 0;
  for (const [key, n] of ours.by) shared += Math.min(n, library.by.get(key) || 0);
  if (shared < LEAST_SHARED * ours.all || shared < LEAST_SHARED * library.all) return null;
  const same = shared === ours.all && shared === library.all;
  return { changed: !same };
}

/// Who modelled [text] (its parts counted as [needs]), from the library:
/// {name, page, licence, changed}, or null. [needsOf] counts a file's parts
/// as the publish does (share.js checkModel); [index] and [file] read the
/// store, and a test gives its own. Never throws: anything the store will
/// not say is nobody's.
export async function libraryCredit(text, needs, { needsOf, index = storeIndex, file = storeFile } = {}) {
  try {
    const page = pageSaid(text);
    if (!page || typeof needsOf !== "function") return null;
    const models = (await index()).filter((one) => one && one.page === page && typeof one.author === "string"
      && one.author.trim() && SITE_LICENCE[one.licence]).slice(0, MOST_CANDIDATES);
    for (const entry of models) {
      const theirs = await file(entry);
      if (!theirs) continue;
      const held = heldTo(text, needs, theirs, needsOf);
      if (held) {
        return { name: entry.author.trim().slice(0, 80), page: entry.page, licence: SITE_LICENCE[entry.licence],
          changed: held.changed };
      }
    }
    return null;
  } catch {
    return null;
  }
}
