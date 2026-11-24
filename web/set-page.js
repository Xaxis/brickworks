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
// And Ask the builders (hubask, supabase/set_asks.sql), the second tab, for
// a set LDraw modelled: a question about a step of it, the step picked as a
// model's Comments pick one and seen in 3D before it is asked, asked in
// Talk's Help (api/_talk.js talkSetAsk), where its thread draws that step in
// 3D and an answer can be on a part; everybody who published a version of
// it hears of it. Under the box, what was asked here, newest first, each
// saying Answered or Open. The page says on <html data-asks> how many it
// lists, "closed" before set_asks.sql is applied, "broken" when they could
// not be read (tools/web/hubask_flow.mjs).
//
// Every word in the page's language (web/card.js say: /de/library/set/<n>
// carries its copy's words), its numbers as the language writes them.
import { askToSignIn, call, nameFirst, signedIn } from "/account.js";
import { altCardSaid, appAt, counted, langAt, modelCard, number, pictureOf, say, told } from "/card.js";
import { ago } from "/kit.js";
import { start3d } from "/start3d.js";

const SET = /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/;
// A list's link (api/_mylists.js): ten letters and digits.
const ID = /^[A-Za-z0-9]{10}$/;
const owned = document.getElementById("owned");
if (owned && SET.test(owned.dataset.set || "") && signedIn()) start(owned);
const page = document.querySelector("article.set-page");
if (page && SET.test(page.dataset.set || "")) builtFrom(page);
const asks = document.getElementById("asks");
if (asks && SET.test(asks.dataset.set || "")) startAsks(asks);

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
    go.href = appAt(`new=1&parts=${encodeURIComponent(article.dataset.set)}`);
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
    // Each shows its model: LDraw's as it is by the picture the library
    // shows of it; a changed one by its card's picture, else the cut-out its
    // publish made, else (a publish with no picture, or one that does not
    // come) LDraw's model it was made from. Never "No picture".
    const ldraw = /^[A-Za-z0-9._-]+$/.test(article.dataset.model || "") ? `/library/${article.dataset.model}.webp` : "";
    row.append(...shown.map((model) => {
      const own = model.changed !== true ? "" : model.thumb ? pictureOf(model)
        : model.image ? `/m/${encodeURIComponent(model.id)}.cutout.png` : "";
      const card = modelCard({ ...model, picture: own || ldraw || undefined }, { inWords: true });
      const picture = card.querySelector(".frame img");
      if (picture && ldraw) {
        picture.addEventListener("error", () => {
          if (!picture.src.endsWith(ldraw)) picture.src = ldraw;
        });
      }
      // A changed one is its sharer's, and its card says so (cardHtml:
      // who published it, and whose model it was changed from); LDraw's as
      // it is says that it is.
      card.dataset.changed = String(model.changed === true);
      if (model.changed !== true) {
        const line = document.createElement("small");
        line.className = "alt-said version-said";
        line.textContent = say("LDraw's model, as it is");
        card.querySelector(".words")?.append(line);
      }
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

/// The sign-in's reason, said over its dialog (web/account.js).
const ASK_WHY = "Sign in to ask: we email you a code, no password. Anyone can read Talk.";
/// The most a question may be, as Talk takes a post (api/_talk.js).
const MOST_WORDS = 4000;
const MOST_TITLE = 100;

/// Ask the builders: the box and the questions asked here, in [section]
/// (api/_sets.js asksHtml), from ?op=talk_set_asks.
async function startAsks(section) {
  const set = section.dataset.set;
  const library = section.dataset.library || "";
  const tests = new URLSearchParams(location.search).get("tests") === "1";
  const body = section.querySelector(".set-asks-body");
  const address = `/api/people?op=talk_set_asks&set=${encodeURIComponent(set)}${tests ? "&tests=1" : ""}`;
  const rowsOf = (said) => (Array.isArray(said?.asks) ? said.asks : []).filter((one) => one && Number(one.thread) > 0);
  const reply = await call(address).catch(() => null);
  section.setAttribute("aria-busy", "false");
  if (!reply || reply.status !== 200 || !reply.body || typeof reply.body !== "object") {
    document.documentElement.dataset.asks = "broken";
    body.replaceChildren(note(say("The questions asked here could not be read just now. Try again in a minute.")));
    return;
  }
  const at = langAt();
  if (reply.body.open !== true) {
    // Before set_asks.sql: Talk's Help, with the way there.
    document.documentElement.dataset.asks = "closed";
    const go = document.createElement("a");
    go.className = "cta ghost";
    go.href = `${at}/talk/new?board=help${tests ? "&tests=1" : ""}`;
    go.textContent = say("Ask in Talk's Help");
    body.replaceChildren(note(say("Asking a set's builders is not open on Brickworks yet: start a thread in Help and paste the set's link.")), go);
    return;
  }
  const drawn = reply.body.drawn && ID.test(String(reply.body.drawn.model || "")) && Number(reply.body.drawn.steps) > 0
    ? { model: reply.body.drawn.model, steps: Number(reply.body.drawn.steps) } : null;
  const listed = rowsOf(reply.body);
  // The list read again, as after an ask whose answer was lost.
  let list = askList(listed, tests);
  const relist = async () => {
    const again = await call(address).catch(() => null);
    if (!again || again.status !== 200) return;
    const fresh = askList(rowsOf(again.body), tests);
    list.replaceWith(fresh);
    list = fresh;
  };
  body.replaceChildren(askForm({ set, library, drawn, tests, relist }), list);
  document.documentElement.dataset.asks = String(listed.length);
  const tab = document.getElementById("tab-asks");
  if (tab && listed.length && !tab.querySelector(".n")) {
    const n = document.createElement("span");
    n.className = "n";
    n.textContent = number(listed.length);
    tab.append(" ", n);
  }
}

/// A paragraph of the page's quieter words.
function note(words) {
  const line = document.createElement("p");
  line.className = "note";
  line.textContent = words;
  return line;
}

/// Where the asked step is drawn from (api/_asks.js askScene, as its thread
/// will draw it): the version the server offered, else LDraw's file.
const sceneAt = ({ library, drawn }, step) => `${drawn ? `/m/${drawn.model}` : `/library/${library}`}/scene.json${step ? `?step=${step}` : ""}`;

/// A question's thread title: its first line, cut short; one too short for
/// Talk said as help with the set and its step.
function titleOf(words, set, step) {
  let first = words.trim().split("\n")[0].trim();
  if (first.length > MOST_TITLE) first = `${first.slice(0, MOST_TITLE - 1).trim()}…`;
  if (first.length >= 3) return first;
  return step ? say("Help with step {step} of LEGO® set {set}", { step: number(step), set }) : say("Help with LEGO® set {set}", { set });
}

/// The box: the step (the whole set, or one of the drawn version's, as a
/// model's Comments pick one; a number where there is no such version),
/// that step in 3D, the question, and Ask the builders. Signed out, it
/// asks to sign in as it sends, what was typed kept; then a name first,
/// once (web/account.js nameFirst); then the thread, where the step is
/// drawn and every builder of a version was told.
function askForm(at) {
  const { set, library, drawn, tests, relist } = at;
  const form = document.createElement("form");
  form.className = "comment-new set-ask-form";
  form.noValidate = true;
  const on = document.createElement("div");
  on.className = "comment-on";
  const label = document.createElement("label");
  label.htmlFor = "set-ask-step";
  label.textContent = say("On");
  let picker;
  if (drawn && drawn.steps <= 1000) {
    picker = document.createElement("select");
    picker.add(new Option(say("the whole set"), ""));
    for (let n = 1; n <= drawn.steps; n += 1) picker.add(new Option(say("step {n}", { n: number(n) }), String(n)));
  } else {
    picker = document.createElement("input");
    picker.type = "number";
    picker.min = "1";
    if (drawn) picker.max = String(drawn.steps);
    picker.inputMode = "numeric";
    picker.placeholder = say("the whole set");
  }
  picker.id = "set-ask-step";
  picker.dataset.askStep = "";
  const how = document.createElement("span");
  how.className = "note";
  how.textContent = say("as Build it numbers its steps");
  on.append(label, " ", picker, " ", how);
  // The step in 3D, as its thread will draw it, before it is asked.
  const frame = document.createElement("div");
  frame.className = "set-ask-frame";
  let view = null;
  const stepNow = () => {
    const n = Number(picker.value);
    return Number.isInteger(n) && n >= 1 && (!drawn || n <= drawn.steps) ? n : null;
  };
  const drawFrame = () => {
    const step = stepNow();
    // The 3D already open stays open, at the step now picked.
    const was = frame.querySelector(".view3d:not([hidden])");
    const how = was ? was.dataset.how || "mouse" : "";
    if (view) view.close();
    view = null;
    const big = document.createElement("a");
    big.className = "picture set-ask-picture";
    // In the page's language, as every other link into the app here (appAt):
    // a German reader's step opened the app in English (rel-m332's site_lang).
    big.href = drawn ? appAt(`view=${drawn.model}${step ? `&step=${step}` : ""}`)
      : appAt(`new=1&library=${encodeURIComponent(library)}&build`);
    big.dataset.scene = sceneAt(at, step);
    big.setAttribute("aria-label", say("View {name} in 3D", { name: step ? say("Step {step} of LEGO® set {set}", { step: number(step), set })
      : say("LEGO® set {set}", { set }) }));
    const img = document.createElement("img");
    img.src = `/library/${library}.webp`;
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    img.loading = "lazy";
    const go = document.createElement("span");
    go.className = "go";
    go.textContent = step ? say("See step {step} in 3D", { step: number(step) }) : say("See it in 3D");
    big.append(img, go);
    frame.replaceChildren(big);
    view = start3d(big, { margin: 0.08 });
    frame.dataset.step = String(step || "");
    if (how) view.open(how);
  };
  // A step asked for in the address (?step=N, as the app's step player
  // links here), picked at the start.
  const asked = Number(new URLSearchParams(location.search).get("step"));
  if (Number.isInteger(asked) && asked >= 1 && (!drawn || asked <= drawn.steps)) picker.value = String(asked);
  drawFrame();
  picker.addEventListener("change", drawFrame);
  const wordsLabel = document.createElement("label");
  wordsLabel.htmlFor = "set-ask-words";
  wordsLabel.textContent = say("Your question");
  const field = document.createElement("textarea");
  field.id = "set-ask-words";
  field.rows = 4;
  field.placeholder = say("Which way round does the hinge go at this step? Say what you tried.");
  const actions = document.createElement("div");
  actions.className = "actions";
  const send = document.createElement("button");
  send.type = "submit";
  send.className = "cta";
  send.textContent = say("Ask the builders");
  const said = document.createElement("span");
  said.className = "said";
  said.setAttribute("role", "status");
  actions.append(send, said);
  const who = note(say("Everybody who published a version of this set hears of it, and anybody in Talk can answer."));
  form.append(on, frame, wordsLabel, field, actions, who);
  const tell = (words) => { said.textContent = words; };
  let busy = false;
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    // Enter and a press at once ask once: busy before anything is awaited.
    if (busy) return;
    busy = true;
    send.disabled = true;
    try {
      const words = field.value.trim();
      if (words.length < 3) {
        tell(say("Say what you want to ask first."));
        field.focus();
        return;
      }
      // Over the most is said, never cut: the words stay as typed. Counted
      // as the server counts them, by character, not by UTF-16 unit.
      const length = [...words].length;
      if (length > MOST_WORDS) {
        tell(say("That is {n} characters: at most {most}, please.", { n: number(length), most: number(MOST_WORDS) }));
        return;
      }
      // A step typed that is none of the set's is said, never asked as the whole set.
      const step = stepNow();
      if (picker.value.trim() !== "" && step === null) {
        tell(drawn ? say("Pick a step from 1 to {n}.", { n: number(drawn.steps) }) : say("A step is a whole number from 1."));
        picker.focus();
        return;
      }
      if (!signedIn() && !(await askToSignIn(ASK_WHY, { later: true }))) return;
      await nameFirst();
      tell(say("Asking…"));
      const done = await call(`/api/people?op=talk_set_ask${tests ? "&tests=1" : ""}`, { method: "POST",
        body: { set, library, step, title: titleOf(words, set, step), body: words } }).catch(() => null);
      // No answer, or a server's failure with no words: it may have been
      // asked all the same, so the list is read again before another try.
      if (!done || (done.status >= 500 && !done.body?.error)) {
        tell(say("That may not have gone. Look for it in the list below before you ask again."));
        await relist();
        return;
      }
      if (done.status !== 201 || !done.body?.path) {
        tell(told(done.body?.error, say("That did not go just now. Try again in a minute.")));
        return;
      }
      const heard = Number(done.body.heard) || 0;
      tell(heard === 1 ? say("Asked: 1 builder will hear of it.")
        : heard ? say("Asked: {n} builders will hear of it.", { n: number(heard) }) : say("Asked."));
      document.documentElement.dataset.asked = String(Number(done.body.thread?.id) || "");
      location.href = `${langAt()}${done.body.path}${tests ? "?tests=1" : ""}`;
    } finally {
      busy = false;
      send.disabled = false;
    }
  });
  return form;
}

/// What was asked here, newest first: each its question (a link to its
/// thread), Answered or Open, its step, who asked, its replies and when.
function askList(listed, tests) {
  const wrap = document.createElement("div");
  wrap.className = "set-asks-asked";
  const heading = document.createElement("h3");
  heading.textContent = say("Asked here");
  wrap.append(heading);
  if (!listed.length) {
    wrap.append(note(say("Nobody has asked about this set yet.")));
    return wrap;
  }
  const list = document.createElement("ol");
  list.className = "set-asks-list";
  const at = langAt();
  for (const one of listed) {
    const item = document.createElement("li");
    item.className = "set-ask-row";
    item.dataset.thread = String(Number(one.thread));
    item.dataset.answered = String(one.answered === true);
    const link = document.createElement("a");
    link.className = "set-ask-title";
    link.href = `${at}/talk/t/${Number(one.thread)}${tests ? "?tests=1" : ""}`;
    link.textContent = String(one.title || "");
    const meta = document.createElement("p");
    meta.className = "set-ask-meta";
    const state = document.createElement("span");
    state.className = `pill set-ask-state${one.answered ? " answered" : ""}`;
    state.textContent = one.answered ? say("Answered") : say("Open");
    const bits = [
      one.step ? say("Step {n}", { n: number(one.step) }) : say("The whole set"),
      one.by && typeof one.by.name === "string" && one.by.name ? one.by.name : say("A builder"),
      one.replies === 1 ? say("1 reply") : say("{n} replies", { n: number(Number(one.replies) || 0) }),
      ago(one.at),
    ].filter(Boolean);
    meta.append(state, ` ${bits.join(" · ")}`);
    item.append(link, meta);
    list.append(item);
  }
  wrap.append(list);
  return wrap;
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
