// A shared model's page, /m/<id>, for somebody signed in (the directory,
// 2026-10-13): Like, Favourite and Add to a collection, each asking to sign
// in first when this browser is not (web/account.js), and each a call to
// /api/people. What the page shows without it — the counts, the way into
// the viewer — needs none of this.
//
// Every name shown here (a collection's) is put on the page as text.
import { askToSignIn, call, signedIn } from "/account.js";

const marks = document.getElementById("marks");
const id = marks && marks.dataset.id;
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "")) start();

// What the app found of this model as it was published, for its owner
// alone: a model that failed one of the four tests says which, plainly, as
// a note to its designer. api/share.js ?op=tested answers only the model's
// own account, so nobody else is ever shown a failure.
const note = document.getElementById("tested-note");
if (note && /^[A-Za-z0-9]{10}$/.test(note.dataset.id || "") && signedIn()) noteForOwner(note);

async function noteForOwner(note) {
  const version = /^[1-9][0-9]{0,5}$/.test(note.dataset.version || "") ? `&v=${note.dataset.version}` : "";
  const answer = await call(`/api/share?op=tested&id=${note.dataset.id}${version}`);
  const tested = answer.status === 200 && answer.body ? answer.body.tested : null;
  if (!tested || tested.passed) return;
  const head = document.createElement("b");
  head.textContent = tested.cleared ? "Not marked Tested: Brickworks cleared its mark." : "Not marked Tested.";
  note.replaceChildren(head, " Only you see this. ");
  for (const name of ["stands", "steps", "parts", "whole"]) {
    const one = tested.tests && tested.tests[name];
    if (!one || one.ok) continue;
    const line = document.createElement("span");
    line.dataset.failed = name;
    line.textContent = `${one.said}: ${one.why}. `;
    note.append(line);
  }
  note.hidden = false;
  document.documentElement.dataset.testedNote = "shown";
}

function start() {
  const like = marks.querySelector('[data-mark="like"]');
  const keep = marks.querySelector('[data-mark="favourite"]');
  const collect = marks.querySelector("details.collect");
  const lists = marks.querySelector(".collect-list");
  const make = marks.querySelector("form.collect-new");
  const said = marks.querySelector(".said");
  const likes = document.querySelector('[data-count="likes"]');
  let state = null;
  marks.hidden = false;

  const say = (text) => { said.textContent = text; };
  const counted = (n) => `${Number(n).toLocaleString("en-US")} like${Number(n) === 1 ? "" : "s"}`;

  function draw() {
    like.setAttribute("aria-pressed", String(Boolean(state && state.liked)));
    like.textContent = state && state.liked ? "Liked" : "Like";
    keep.setAttribute("aria-pressed", String(Boolean(state && state.favourite)));
    keep.textContent = state && state.favourite ? "In your favourites" : "Favourite";
    lists.replaceChildren();
    for (const list of (state && state.collections) || []) {
      const row = document.createElement("label");
      const box = document.createElement("input");
      box.type = "checkbox";
      box.checked = Boolean(list.has);
      box.addEventListener("change", () => put(list, box));
      const name = document.createElement("span");
      name.textContent = String(list.name);
      const where = document.createElement("small");
      where.textContent = list.public ? "public" : "private";
      row.append(box, name, where);
      lists.append(row);
    }
    if (state && !(state.collections || []).length) {
      const none = document.createElement("p");
      none.className = "note";
      none.textContent = "You have no collections yet: name one below.";
      lists.append(none);
    }
  }

  async function load() {
    if (!signedIn()) return;
    const answer = await call(`/api/people?op=marks&id=${id}`);
    if (answer.status === 200) {
      state = answer.body;
      draw();
    }
  }

  /// Signed in first, if this browser is not.
  async function ready(why) {
    if (signedIn() && state) return true;
    if (!signedIn() && !(await askToSignIn(why))) return false;
    await load();
    return Boolean(state);
  }

  like.addEventListener("click", async () => {
    if (!(await ready("Sign in to like it: we email you a code, no password."))) return;
    like.disabled = true;
    const answer = await call(`/api/people?op=like&id=${id}`, { method: "POST", body: { on: !state.liked } });
    like.disabled = false;
    if (answer.status !== 200) return say(answer.body.error || "That did not work just now.");
    state.liked = answer.body.liked;
    if (likes) likes.textContent = counted(answer.body.likes);
    say("");
    draw();
  });

  keep.addEventListener("click", async () => {
    if (!(await ready("Sign in to keep it in your favourites: we email you a code."))) return;
    keep.disabled = true;
    const answer = await call(`/api/people?op=favourite&id=${id}`, { method: "POST", body: { on: !state.favourite } });
    keep.disabled = false;
    if (answer.status !== 200) return say(answer.body.error || "That did not work just now.");
    state.favourite = answer.body.favourite;
    say(state.favourite ? "Kept. Your favourites are on your profile page." : "");
    draw();
  });

  collect.addEventListener("toggle", async () => {
    if (!collect.open) return;
    if (!(await ready("Sign in to put it in a collection: we email you a code."))) collect.open = false;
  });

  async function put(list, box) {
    box.disabled = true;
    const answer = await call("/api/people?op=collect", { method: "POST",
      body: { collection: list.id, model: id, on: box.checked } });
    box.disabled = false;
    if (answer.status !== 200) {
      box.checked = !box.checked;
      return say(answer.body.error || "That did not work just now.");
    }
    list.has = box.checked;
    say(box.checked ? `In ${list.name}.` : `Out of ${list.name}.`);
  }

  make.addEventListener("submit", async (event) => {
    event.preventDefault();
    const field = make.querySelector("input");
    const name = field.value.trim();
    if (!name || !(await ready("Sign in to make a collection: we email you a code."))) return;
    const made = await call("/api/people?op=collection", { method: "POST", body: { name, public: false } });
    if (made.status !== 200) return say(made.body.error || "That did not work just now.");
    const list = { id: made.body.id, name: made.body.name, public: made.body.public, has: false };
    const box = { checked: true, disabled: false };
    await put(list, box);
    field.value = "";
    await load();
  });

  load();
}
