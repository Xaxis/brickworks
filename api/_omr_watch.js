// What LDraw's Official Model Repository has that the site's library has
// not, looked for once a week by Vercel's cron (gallery362, 2026-10-29):
// /api/share/omr (api/share.js ?op=omr, tools/deploy.sh's crons).
//
// The OMR has no feed. Its front page names its latest models, and a set's
// page (library.ldraw.org/omr/sets/<n>) names each of its models, who
// modelled it and its file, whose address carries a stamp (?v=<seconds>)
// that changes when the file does. So a look asks, a second apart, as
// tools/omr.py does:
//
//   - the front page, for the sets of its latest models;
//   - the pages after the highest the library or an earlier look knows,
//     until three in a row are not there, or LOOK_AHEAD of them: a set
//     added with no model yet ("No Models Yet") is passed over and looked
//     at again next week.
//
// A set's page with a model is found when the library has no set of that
// page, or has it from an index older than the file's stamp (an update).
// What is found is written down (library_arrivals_found), once a stamp:
// nothing here downloads a file or touches the store's index. Drawing its
// pictures takes the app's own renderer, so tools/library_import.py, on
// the box, takes it from there: the file, LDraw's licence, our own checks,
// the pictures, the store, and staged for the lead to let out.
//
// Pure but for [fetchText], [db] and [sets], which a test gives its own:
// tests/test_gallery_crons.py.

export const SITE = "https://library.ldraw.org";
export const JOB = "omr_watch";
/// How many pages past the highest known a look asks at most, and after
/// how many missing in a row it stops.
export const LOOK_AHEAD = 10;
export const MISSING_IN_A_ROW = 3;
/// A second between requests, as tools/omr.py asks.
export const PAUSE_MS = 1000;
export const LEASE_SECONDS = 240;
export const AGENT = "brickworks (https://brickworks.diy)";
const PAGE = /^https:\/\/library\.ldraw\.org\/omr\/sets\/(\d+)$/;
const FILE = /href="(https:\/\/library\.ldraw\.org\/media\/omr_models\/\d+\/([A-Za-z0-9._'-]+\.(?:mpd|ldr)))\?v=(\d+)"/g;

const unescape = (text) => String(text).replace(/&amp;/g, "&").replace(/&#0?39;|&apos;/g, "'").replace(/&quot;/g, '"')
  .replace(/&lt;/g, "<").replace(/&gt;/g, ">");
const words = (html) => unescape(String(html).replace(/<[^>]*>/g, " ")).replace(/\s+/g, " ").trim();

/// The set pages the OMR's front page names under Latest Models, once each.
export function latestPages(html) {
  const text = String(html || "");
  const from = text.indexOf("Latest Models");
  if (from < 0) return [];
  // To the page's next heading, "What is this?": the set links after it are not latest.
  const to = text.indexOf("What is this?", from);
  const seen = [];
  for (const found of text.slice(from, to > from ? to : from + 8000).matchAll(/href="https:\/\/library\.ldraw\.org\/omr\/sets\/(\d+)"/g)) {
    const page = Number(found[1]);
    if (!seen.includes(page)) seen.push(page);
  }
  return seen;
}

/// A set's page, read: {page, set_number, name, models: [{name, author,
/// file, stamp}]}, models [] for a set with none yet; null for a page that
/// is not a set's.
export function readSetPage(html, page) {
  const text = String(html || "");
  if (!/<title>\s*LDraw\.org Official Model Repository - /.test(text)) return null;
  // Its heading, "8094-1 - TECHNIC Control Centre", the first after the set's own component.
  const from = Math.max(0, text.indexOf('wire:name="omr.set.show"'));
  const heading = />\s*([A-Za-z0-9._-]{1,40}) - ([^<]{1,300}?)\s*<\/div>/.exec(text.slice(from));
  if (!heading) return null;
  const models = [];
  // Each model's block runs from its name to its Download link.
  for (const found of text.matchAll(FILE)) {
    const block = text.slice(Math.max(0, found.index - 4000), found.index);
    const authored = [...block.matchAll(/Author:<\/span>\s*([^<]*)</g)].pop();
    if (models.some((one) => one.file === found[1])) continue;
    models.push({ file: found[1], stem: found[2], stamp: Number(found[3]),
      author: authored ? words(authored[1]).slice(0, 200) : "" });
  }
  return { page, set_number: heading[1], name: words(heading[2]).slice(0, 200), models };
}

/// The arrival a set's page makes, its main model's file and the newest
/// stamp of its files, or null for a set with no model.
export function arrivalOf(set) {
  if (!set || !set.models.length) return null;
  const main = set.models.find((one) => one.stem.replace(/\.(mpd|ldr)$/, "") === set.set_number) || set.models[0];
  return { page: set.page, set_number: set.set_number, name: set.name, file: main.file,
    stamp: Math.max(...set.models.map((one) => one.stamp)), author: main.author || null };
}

/// The page number of a library entry's LDraw page, or 0.
export const pageOf = (entry) => Number((PAGE.exec(String(entry?.page || "")) || [])[1] || 0);

/// One look at the OMR: {found, looked, latest, ahead}. [sets] are the
/// library's entries (api/_library.js), [indexAt] when the store's index was
/// last written (ms), [known] the pages earlier looks found with their
/// stamps ({page: stamp}). [fetchText](url) answers {status, text}; [pause]
/// waits between two requests.
export async function look({ fetchText, sets, indexAt = 0, known = {}, pause = PAUSE_MS, wait = defaultWait }) {
  const library = new Set((sets || []).map(pageOf).filter(Boolean));
  const looked = [];
  let first = true;
  const ask = async (url) => {
    if (!first) await wait(pause);
    first = false;
    looked.push(url);
    return fetchText(url);
  };
  const found = [];
  const consider = (set) => {
    const arrival = arrivalOf(set);
    if (!arrival) return;
    const before = Number(known[arrival.page] || 0);
    const newer = arrival.stamp > before;
    const inLibrary = library.has(arrival.page);
    // In the library: an update only when its file changed after the index was written.
    if (inLibrary && !(arrival.stamp * 1000 > indexAt && newer)) return;
    if (!inLibrary && before && !newer) return;
    if (!found.some((one) => one.page === arrival.page)) found.push(arrival);
  };
  const front = await ask(`${SITE}/omr`);
  const latest = front.status === 200 ? latestPages(front.text) : [];
  for (const page of latest) {
    const answer = await ask(`${SITE}/omr/sets/${page}`);
    if (answer.status === 200) consider(readSetPage(answer.text, page));
  }
  const highest = Math.max(0, ...library, ...Object.keys(known).map(Number));
  let missing = 0;
  const ahead = [];
  for (let page = highest + 1; page <= highest + LOOK_AHEAD && missing < MISSING_IN_A_ROW; page += 1) {
    if (latest.includes(page)) continue;
    const answer = await ask(`${SITE}/omr/sets/${page}`);
    const set = answer.status === 200 ? readSetPage(answer.text, page) : null;
    missing = set ? 0 : missing + 1;
    ahead.push({ page, set: set ? set.set_number : null, models: set ? set.models.length : 0 });
    if (set) consider(set);
  }
  return { found, looked, latest, ahead };
}

const defaultWait = (ms) => new Promise((done) => setTimeout(done, ms));

/// One run of the weekly cron, as [holder]: the look, and what it found
/// written down unless [dry]. {outcome: done | unchanged | locked, run,
/// found, written, latest, ahead, asked}.
export async function runOmrWatch({ db, fetchText, sets, indexAt, holder = "cron", dry = false, wait }) {
  const rpc = (name, body) => db(`rpc/${name}`, { method: "POST", body });
  if (dry) {
    if (!(await sets()).length) throw new Error("the library's index cannot be read");
    const known = Object.fromEntries((await rpc("library_arrivals_in", { state: null }) || [])
      .map((one) => [one.page, Number(one.stamp) || 0]));
    const seen = await look({ fetchText, sets: await sets(), indexAt, known, wait });
    return { outcome: "dry", run: null, found: seen.found, written: [], latest: seen.latest, ahead: seen.ahead,
      asked: seen.looked.length };
  }
  // An index that cannot be read would make every set look new.
  const library = await sets();
  if (!library.length) throw new Error("the library's index cannot be read");
  const begun = await rpc("cron_begin", { job: JOB, holder, seconds: LEASE_SECONDS });
  if (!begun || begun.locked !== false) return { outcome: "locked", run: begun?.run ?? null };
  const run = begun.run;
  try {
    const known = Object.fromEntries((await rpc("library_arrivals_in", { state: null }) || [])
      .map((one) => [one.page, Number(one.stamp) || 0]));
    const seen = await look({ fetchText, sets: library, indexAt, known, wait });
    const written = seen.found.length ? (await rpc("library_arrivals_found", { found: seen.found }) || []) : [];
    const outcome = written.length ? "done" : "unchanged";
    const said = { found: seen.found.map((one) => `${one.page} ${one.set_number}`), written,
      latest: seen.latest, ahead: seen.ahead.map((one) => `${one.page}:${one.set || "-"}`), asked: seen.looked.length };
    await rpc("cron_end", { run, holder, outcome, said });
    return { outcome, run, found: seen.found, written, latest: seen.latest, ahead: seen.ahead, asked: seen.looked.length };
  } catch (trouble) {
    await rpc("cron_end", { run, holder, outcome: "failed", said: { error: String(trouble?.message || trouble).slice(0, 300) } })
      .catch(() => null);
    throw trouble;
  }
}
