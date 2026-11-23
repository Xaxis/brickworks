// A set's page, /library/set/<number> (sets364, api/_sets.js setPage): for
// somebody signed in, how much of the set their collection holds, counted
// as the app's My collection counts it (api/share.js ?op=catalog_owned), and
// what they are missing as a BrickLink wanted list or a Rebrickable parts
// list to download. Its parts list is a model page's (web/model-page.js);
// nobody signed in sees the page as it is sent.
//
// For everybody, the models in the gallery built from the set (altbuilds:
// counted from their parts, api/_alts.js) or said by their designers to be
// based on it (api/_bases.js setBased, docs/SOCIAL.md section 7, item 5):
// Built from this set, a row of their cards after the page's parts, before
// the set's theme, each saying how much of it is from the set. They change
// as models are published and designers say so, and the page is kept a
// day, so they are asked here. While there are none, the row says so and
// offers Build something from it: the studio with the set's parts in its
// parts bin (/app?parts=, the same as Open its parts in Brickworks: the
// studio has no opener that puts a set in a person's collection).
//
// And, for a set LDraw modelled (sethub), Versions of this set: the copies
// of that model people published from Make your own version (the studio
// opens it credited to its modeller, and a publish of it is counted as the
// set's own model: supabase/set_versions.sql), changed ones first, each
// saying whether it is changed; before any, the row says so and offers
// Make your own version. First of the rows, before Built from this set:
// these are the set itself, made over.
//
// The page says what it found on <html data-owned>: "have/pieces", "none"
// for no collection, "broken" when it could not ask (tools/web/sets_flow.mjs
// reads it); on <html data-based> how many models are built from it,
// counted or said, "broken" when it could not ask (tools/web/based_on_flow.mjs,
// tools/web/altbuilds_lcp.mjs); on <html data-versions> how many versions
// it has, "broken" when they could not be read (tools/web/sethub_flow.mjs);
// and on <html data-lists> how many public lists it is in (ownedparts).
//
// Every word in the page's language (web/card.js say: /de/library/set/<n>
// carries its copy's words), its numbers as the language writes them.
import { call, signedIn } from "/account.js";
import { altCardSaid, counted, langAt, modelCard, number, say } from "/card.js";

const SET = /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/;
// A list's link (api/_mylists.js): ten letters and digits.
const ID = /^[A-Za-z0-9]{10}$/;
const owned = document.getElementById("owned");
if (owned && SET.test(owned.dataset.set || "") && signedIn()) start(owned);
const page = document.querySelector("article.set-page");
if (page && SET.test(page.dataset.set || "")) builtFrom(page);

/// Built from this set: the models counted or said to be built from it, put
/// before More <theme> (#similar), or at the page's end; each card says how
/// much of it is from the set. None: the row says so, with Build something
/// from it.
async function builtFrom(article) {
  const tests = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
  const reply = await fetch(`/api/share?op=set_based&set=${encodeURIComponent(article.dataset.set)}${tests}`).catch(() => null);
  const body = reply && reply.ok ? await reply.json().catch(() => null) : null;
  if (!body || !Array.isArray(body.models)) {
    document.documentElement.dataset.based = "broken";
    document.documentElement.dataset.lists = "broken";
    if (article.dataset.model) document.documentElement.dataset.versions = "broken";
    return;
  }
  inLists(article, body.lists);
  const models = body.models.filter((model) => model && typeof model.id === "string");
  const section = document.createElement("section");
  section.className = "next built-from";
  section.id = "built-from";
  section.setAttribute("aria-labelledby", "built-from-h");
  section.innerHTML = '<div class="scroller-head"><h2 id="built-from-h"></h2></div>';
  section.querySelector("h2").textContent = say("Built from this set");
  if (models.length) {
    const row = document.createElement("div");
    row.className = "models scroller";
    row.setAttribute("role", "group");
    row.setAttribute("aria-labelledby", "built-from-h");
    row.append(...models.map((model) => {
      const card = modelCard(model);
      const said = altCardSaid(model.alt, model.based);
      if (said) {
        const line = document.createElement("small");
        line.className = "alt-said";
        line.dataset.alt = model.alt?.role || model.based || "";
        line.textContent = said;
        card.querySelector(".words")?.append(line);
      }
      return card;
    }));
    section.append(row);
  } else {
    // Never a dead end (docs/MASTERPLAN.md, "Intuitive and elegant" 3).
    const empty = document.createElement("div");
    empty.className = "state built-empty";
    const note = document.createElement("p");
    note.textContent = say("Nobody has built anything else from this set yet.");
    const how = document.createElement("p");
    how.className = "note";
    how.textContent = say("Build something of your own from its parts: Brickworks opens with them in its parts bin, and "
      + "once you publish it, it is listed here.");
    const go = document.createElement("a");
    go.className = "cta";
    go.href = `/app?new=1&parts=${encodeURIComponent(article.dataset.set)}`;
    go.dataset.buildFrom = "";
    go.textContent = say("Build something from it");
    empty.append(note, how, go);
    section.append(empty);
  }
  const similar = document.getElementById("similar");
  if (similar) similar.before(section);
  else article.append(section);
  document.documentElement.dataset.based = String(models.length);
  if (article.dataset.model) versionsOf(article, body.versions, section);
}

/// Versions of this set (sethub): the gallery's copies of LDraw's model of
/// it, before Built from this set ([before] is that row); each card says
/// whether it was changed. None: the row says so, with Make your own
/// version, the same link as the one under the set's name.
function versionsOf(article, versions, before) {
  if (!Array.isArray(versions)) {
    document.documentElement.dataset.versions = "broken";
    return;
  }
  const shown = versions.filter((model) => model && typeof model.id === "string");
  const section = document.createElement("section");
  section.className = "next versions";
  section.id = "versions";
  section.setAttribute("aria-labelledby", "versions-h");
  section.innerHTML = '<div class="scroller-head"><h2 id="versions-h"></h2></div>';
  section.querySelector("h2").textContent = say("Versions of this set");
  const make = document.querySelector("[data-version]");
  if (shown.length) {
    const row = document.createElement("div");
    row.className = "models scroller";
    row.setAttribute("role", "group");
    row.setAttribute("aria-labelledby", "versions-h");
    row.append(...shown.map((model) => {
      const card = modelCard(model);
      const line = document.createElement("small");
      line.className = "alt-said version-said";
      line.dataset.changed = String(model.changed === true);
      line.textContent = model.changed === true ? say("Their own version: changed from LDraw's model")
        : say("LDraw's model, as it is");
      card.querySelector(".words")?.append(line);
      return card;
    }));
    section.append(row);
  } else {
    const empty = document.createElement("div");
    empty.className = "state built-empty";
    const note = document.createElement("p");
    note.textContent = say("Nobody has published their own version of this set yet.");
    const how = document.createElement("p");
    how.className = "note";
    how.textContent = say("Make your own version: Brickworks opens a copy of LDraw's model of it, credited to "
      + "whoever modelled it. Change it, publish it, and it is listed here.");
    empty.append(note, how);
    if (make) {
      const go = document.createElement("a");
      go.className = "cta";
      go.href = make.getAttribute("href");
      go.dataset.versionEmpty = "";
      go.textContent = say("Make your own version");
      empty.append(go);
    }
    section.append(empty);
  }
  before.before(section);
  document.documentElement.dataset.versions = String(shown.length);
  // From a version's own page ("A version of LEGO® set …"): the row it is in.
  if (location.hash === "#versions") section.scrollIntoView({ block: "start" });
}

/// Parts you own: how much of the set their collection holds, and what they
/// are missing as each shop's list; asked again whenever they change how
/// many of it they own on this page (web/keep.js "brickworks:owned"), so
/// the count and what it means are said together.
async function start(section) {
  const set = section.dataset.set;
  const said = document.getElementById("owned-said");
  const wanted = document.getElementById("owned-wanted");
  // What each download button gives, as the newest answer has it.
  const files = {};
  if (wanted) {
    wanted.addEventListener("click", (event) => {
      const button = event.target.closest?.("[data-wanted]");
      const [text, type, name] = files[button?.dataset.wanted] || [];
      if (typeof text !== "string") return;
      const link = document.createElement("a");
      link.href = URL.createObjectURL(new Blob([text], { type }));
      link.download = name;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    });
  }
  let asking = 0;
  const ask = async () => {
    const mine = ++asking;
    const reply = await call(`/api/share?op=catalog_owned&set=${encodeURIComponent(set)}`).catch(() => null);
    if (mine !== asking) return;
    if (!reply || reply.status !== 200 || !reply.body || typeof reply.body !== "object") {
      document.documentElement.dataset.owned = "broken";
      return;
    }
    const body = reply.body;
    const pieces = Number(body.pieces) || 0;
    const have = Math.min(Number(body.have) || 0, pieces);
    section.hidden = false;
    for (const key of Object.keys(files)) delete files[key];
    if (wanted) wanted.hidden = true;
    if (!body.collection) {
      said.textContent = say("Your collection is empty. Add the sets and parts you own under My collection in the app, "
        + "and this says how much of this set you have.");
      document.documentElement.dataset.owned = "none";
      return;
    }
    said.textContent = have >= pieces ? say("Parts you own: all {n} of them.", { n: number(pieces) })
      : say("Parts you own: {have} of {pieces}. You are missing {missing} in {lots}.", { have: number(have),
        pieces: number(pieces), missing: number(pieces - have), lots: counted(Number(body.missing) || 0, "lot") });
    document.documentElement.dataset.owned = `${have}/${pieces}`;
    if (have >= pieces || !wanted || !body.wanted) return;
    wanted.hidden = false;
    files.bricklink = [body.wanted.bricklink, "application/xml", `${set}-missing-bricklink.xml`];
    files.rebrickable = [body.wanted.rebrickable, "text/csv", `${set}-missing-rebrickable.csv`];
    // LEGO® Pick a Brick's, a file of 400 elements each (ownedparts): a
    // button a file where there are more.
    const pab = Array.isArray(body.wanted.pickabrick) ? body.wanted.pickabrick.filter((text) => typeof text === "string") : [];
    for (const extra of wanted.querySelectorAll('[data-wanted^="pickabrick-"]')) extra.remove();
    const first = wanted.querySelector('[data-wanted="pickabrick"]');
    pab.forEach((text, n) => {
      const button = n === 0 ? first : first.cloneNode(false);
      if (!button) return;
      button.dataset.wanted = n === 0 ? "pickabrick" : `pickabrick-${n + 1}`;
      button.textContent = pab.length > 1 ? say("LEGO® Pick a Brick CSV, {n} of {all}", { n: number(n + 1), all: number(pab.length) })
        : say("LEGO® Pick a Brick CSV");
      files[button.dataset.wanted] = [text, "text/csv", `${set}-missing-pickabrick${pab.length > 1 ? `-${n + 1}` : ""}.csv`];
      if (n > 0) wanted.append(button);
    });
    for (const button of wanted.querySelectorAll("[data-wanted]")) button.hidden = typeof files[button.dataset.wanted]?.[0] !== "string";
  };
  addEventListener("brickworks:owned", (event) => {
    if (event.detail?.key === `set:${set.toLowerCase()}`) ask();
  });
  await ask();
}

/// "In N lists" (ownedparts): the public lists the set is in, as the
/// set_based answer has them (api/_lists.js setListsOf), by name and whose,
/// after its parts (never among the facts under its name, where a pill
/// coming late would move the first screen); none while it is in none, or
/// when they could not be read.
function inLists(article, lists) {
  const count = Number(lists?.count) || 0;
  const shown = (Array.isArray(lists?.lists) ? lists.lists : []).filter((list) => list && ID.test(String(list.id)));
  document.documentElement.dataset.lists = lists ? String(count) : "broken";
  if (!count || !shown.length) return;
  const at = langAt();
  const section = document.createElement("section");
  section.className = "words in-lists";
  section.id = "in-lists";
  section.setAttribute("aria-labelledby", "in-lists-h");
  const heading = document.createElement("h2");
  heading.id = "in-lists-h";
  heading.textContent = count === 1 ? say("In 1 list") : say("In {n} lists", { n: number(count) });
  const note = document.createElement("p");
  note.className = "note";
  note.textContent = say("People put it in {lists}.", { lists: counted(count, "public list") });
  const pills = document.createElement("ul");
  pills.className = "pills";
  for (const list of shown) {
    const item = document.createElement("li");
    const link = document.createElement("a");
    link.className = "pill";
    link.href = `${at}/c/${list.id}`;
    link.append(String(list.name || say("A list")));
    const by = list.by && typeof list.by.name === "string" ? list.by.name : "";
    if (by) {
      const whose = document.createElement("small");
      whose.textContent = ` · ${by}`;
      link.append(whose);
    }
    item.append(link);
    pills.append(item);
  }
  section.append(heading, note, pills);
  const before = document.getElementById("inside") || document.getElementById("models3d") || document.getElementById("about");
  if (before) before.before(section);
  else article.append(section);
}
