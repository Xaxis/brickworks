// A shared model's page, /m/<id>, for somebody signed in (the directory,
// 2026-10-13): Like, Favourite and Add to a collection, each asking to sign
// in first when this browser is not (web/account.js), and each a call to
// /api/people. What the page shows without it — the counts, the way into
// the viewer — needs none of this.
//
// Every name shown here (a collection's) is put on the page as text.
//
// And its comments (2026-10-18, api/_comments.js): the list, oldest first,
// each saying its step and version ("on step 7 of version 2", and when it
// is an older version); a box to add one, with a step picker, for somebody
// who may write, and why not, politely, for anybody who may not; Report on
// each; Remove on one's own; Hide and Show on each, and comments off or on,
// for the model's builder. What a stranger wrote is set as text, never as
// markup, and a link in it stays words.
import { askToSignIn, call, signedIn } from "/account.js";
import { openReport } from "/report.js";

const marks = document.getElementById("marks");
const id = marks && marks.dataset.id;
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "")) start();
// This month's challenge (supabase/challenges.sql), for the model's own
// designer: Enter this month's challenge, or that it is in.
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "") && signedIn()) challengeEntry();
const comments = document.getElementById("comments");
if (comments && /^[A-Za-z0-9]{10}$/.test(comments.dataset.id || "")) startComments(comments);

function startComments(section) {
  const model = section.dataset.id;
  const version = Number(section.dataset.version) || 1;
  const list = section.querySelector(".comment-list");
  const form = section.querySelector("form.comment-new");
  const step = form.querySelector("#comment-step");
  const box = form.querySelector("#comment-body");
  const send = form.querySelector('button[type="submit"]');
  const left = form.querySelector(".comment-count");
  const why = section.querySelector(".comment-why");
  const said = section.querySelector(".comments-said");
  let state = null;
  const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  const say = (text) => { said.textContent = text; };

  async function load() {
    const path = `/api/people?op=comments&id=${model}&v=${version}`;
    let answer;
    if (signedIn()) {
      answer = await call(path);
    } else {
      const reply = await fetch(path, { headers: { accept: "application/json" } });
      answer = { status: reply.status, body: await reply.json().catch(() => ({})) };
    }
    if (answer.status !== 200) return say(answer.body.error || "The comments did not load just now.");
    state = answer.body;
    // Not open on this deployment yet (comments.sql): nothing to show.
    section.hidden = state.ready === false;
    draw();
  }

  function button(words, run, kind = "link") {
    const made = document.createElement("button");
    made.type = "button";
    made.className = kind;
    made.textContent = words;
    made.addEventListener("click", run);
    return made;
  }

  function draw() {
    list.replaceChildren();
    for (const one of state.comments || []) {
      const item = document.createElement("li");
      item.className = `comment${one.hidden ? " hidden-one" : ""}${one.by_owner ? " by-owner" : ""}`;
      item.id = `comment-${one.id}`;
      item.dataset.step = one.step ?? "";
      const head = document.createElement("p");
      head.className = "comment-head";
      const who = one.handle ? document.createElement("a") : document.createElement("b");
      if (one.handle) who.href = `/u/${encodeURIComponent(one.handle)}`;
      who.textContent = one.by || "A builder";
      head.append(who);
      if (one.by_owner) {
        const tag = document.createElement("span");
        tag.className = "tag";
        tag.textContent = "its builder";
        head.append(" ", tag);
      }
      const where = document.createElement("span");
      where.className = "where";
      where.textContent = ` ${one.said}`;
      const at = Date.parse(one.at || "");
      const time = document.createElement("time");
      if (Number.isFinite(at)) {
        time.dateTime = new Date(at).toISOString();
        time.textContent = ` · ${DAY.format(at)}${one.edited_at ? " · edited" : ""}`;
      }
      head.append(where, time);
      const words = document.createElement("p");
      words.className = "comment-body";
      words.textContent = one.body;
      item.append(head, words);
      if (one.hidden) {
        const note = document.createElement("p");
        note.className = "note";
        note.textContent = state.you?.owner ? "Hidden: only you and its author see it."
          : "Its builder hid this comment: only you and they see it.";
        item.append(note);
      }
      const acts = document.createElement("p");
      acts.className = "comment-acts";
      if (state.you?.owner) {
        acts.append(button(one.hidden ? "Show it" : "Hide it", () => change(one, one.hidden ? "show" : "hide")));
      }
      if (one.mine) acts.append(button("Remove it", () => confirm("Remove your comment?") && change(one, "remove")));
      if (!one.mine) acts.append(button("Report it", () => openReport({ comment: one.id }, "this comment")));
      item.append(acts);
      list.append(item);
    }
    if (!(state.comments || []).length) {
      const none = document.createElement("li");
      none.className = "note none";
      none.textContent = state.open ? "Nobody has commented yet." : "No comments.";
      list.append(none);
    }
    const you = state.you || {};
    form.hidden = !you.may_write;
    why.hidden = Boolean(you.may_write);
    why.replaceChildren();
    if (!you.may_write) {
      const words = document.createElement("p");
      words.className = "note";
      words.textContent = you.why_not || "";
      why.append(words);
      if (!you.signed_in) {
        why.append(button("Sign in to comment", async () => {
          if (await askToSignIn("Sign in to add a comment: we email you a code, no password.")) await load();
        }, "cta ghost small"));
      }
    }
    if (you.owner) {
      const line = document.createElement("p");
      line.className = "note owner-line";
      line.append(state.open ? "Comments are on for this model. " : "Comments are off for this model. ",
        button(state.open ? "Turn them off" : "Turn them on", () => setOpen(!state.open)));
      why.hidden = false;
      why.append(line);
    }
    // Opened at a comment (an email's link, the admin page's): marked.
    const named = /^#comment-\d+$/.test(location.hash) ? document.getElementById(location.hash.slice(1)) : null;
    if (named && !draw.shown) {
      draw.shown = true;
      named.classList.add("asked");
      named.scrollIntoView({ block: "center" });
    }
  }

  async function change(one, what) {
    const answer = await call("/api/people?op=comment_change", { method: "POST", body: { id: one.id, what } });
    if (answer.status !== 200) return say(answer.body.error || "That did not work just now.");
    say(what === "remove" ? "Removed." : what === "hide" ? "Hidden from everybody but you and its author." : "Shown again.");
    await load();
  }

  async function setOpen(open) {
    const answer = await call(`/api/people?op=comments_open&id=${model}`, { method: "POST", body: { open } });
    if (answer.status !== 200) return say(answer.body.error || "That did not work just now.");
    say(open ? "Comments are on." : "Comments are off: what was said stays, and nobody can add more.");
    await load();
  }

  box.addEventListener("input", () => {
    const n = [...box.value].length;
    left.textContent = n > 900 ? `${1000 - n} characters left` : "";
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const text = box.value.trim();
    if (!text) return say("Say something first.");
    send.disabled = true;
    say("Adding it…");
    const at = step.value === "" ? null : Number(step.value);
    const answer = await call("/api/people?op=comment", { method: "POST",
      body: { model, version, step: at, body: text } });
    send.disabled = false;
    if (answer.status !== 201) return say(answer.body.error || "That did not go just now. Try again in a minute.");
    box.value = "";
    left.textContent = "";
    say(at ? `Added, on step ${at}.` : "Added.");
    await load();
  });

  load();
}

// What the app found of this model as it was published, for its owner
// alone: a model that failed one of the four tests says which, plainly, as
// a note to its designer. api/share.js ?op=tested answers only the model's
// own account, so nobody else is ever shown a failure.
const note = document.getElementById("tested-note");
if (note && /^[A-Za-z0-9]{10}$/.test(note.dataset.id || "") && signedIn()) noteForOwner(note);

// "I built it" (supabase/builds.sql): a photo of a real build, with a line,
// for somebody signed in; and for the model's owner, a way to hide a photo
// on it and to show it again. The photo goes from this page straight to
// storage, to an address the server signed for it (a function takes no
// body over 4.5 MB, and a phone's photo can be 8), and the server then
// makes it safe and keeps it (api/_photo.js): nothing of the file but its
// pixels is ever shown.
const builds = document.getElementById("add-build");
if (builds && /^[A-Za-z0-9]{10}$/.test(builds.dataset.id || "")) buildPhotos(builds);

function buildPhotos(box) {
  const model = box.dataset.id;
  const open = box.querySelector("[data-add-build]");
  const form = box.querySelector("form.build-form");
  const file = form.querySelector('input[type="file"]');
  const words = form.querySelector('input[name="words"]');
  const said = form.querySelector(".said");
  const told = box.querySelector(".build-said");
  const strip = () => document.querySelector("#builds .build-strip");
  const MOST = 8 * 1024 * 1024;
  let state = null;
  box.hidden = false;

  const say = (text) => { said.textContent = text; };

  /// The photos as the caller may act on them: their own, and as the
  /// model's owner, every one with Hide (or Show again).
  async function load() {
    if (!signedIn()) return;
    const answer = await call(`/api/people?op=photos&id=${model}`);
    if (answer.status !== 200) return;
    state = answer.body;
    if (state.left === 0) open.textContent = "You have added three photos: the most";
    open.disabled = state.left === 0;
    if (state.owner) ownerTools(state.photos || []);
    document.documentElement.dataset.buildPhotos = state.owner ? "owner" : "ready";
  }

  /// The model's owner's: Hide on each photo shown, and the hidden ones in
  /// a list of their own with Show again.
  function ownerTools(photos) {
    for (const old of document.querySelectorAll("#builds .owner-only")) old.remove();
    const hidden = document.createElement("div");
    hidden.className = "owner-only hidden-builds";
    for (const photo of photos) {
      const figure = document.getElementById(`photo-${photo.id}`);
      if (!photo.hidden && figure) {
        const hide = document.createElement("button");
        hide.type = "button";
        hide.className = "link owner-only";
        hide.dataset.hide = photo.id;
        hide.textContent = "Hide";
        hide.addEventListener("click", () => setHidden(photo.id, true, hide));
        figure.querySelector("figcaption").append(" ", hide);
      } else if (photo.hidden) {
        const row = document.createElement("p");
        row.className = "note";
        row.dataset.hidden = photo.id;
        row.textContent = `Hidden by you: a photo ${photo.by ? `by ${photo.by.name}` : "by a builder"}`
          + `${photo.words ? `, “${photo.words}”` : ""}. `;
        const show = document.createElement("button");
        show.type = "button";
        show.className = "link";
        show.dataset.show = photo.id;
        show.textContent = "Show it again";
        show.addEventListener("click", () => setHidden(photo.id, false, show));
        row.append(show);
        hidden.append(row);
      }
    }
    if (hidden.childElementCount) box.after(hidden);
  }

  async function setHidden(photo, on, button) {
    button.disabled = true;
    const answer = await call("/api/people?op=photo_hide", { method: "POST", body: { photo, on } });
    button.disabled = false;
    if (answer.status !== 200) {
      told.textContent = answer.body.error || "That did not work just now.";
      return;
    }
    if (on) document.getElementById(`photo-${photo}`)?.remove();
    told.textContent = on ? "Hidden: nobody else sees it now." : "Shown again: reload to see it in the strip.";
    document.documentElement.dataset.buildHidden = on ? photo : "";
    await load();
  }

  open.addEventListener("click", async () => {
    if (!signedIn() && !(await askToSignIn("Sign in to add a photo of your build: we email you a code, no password."))) return;
    await load();
    if (state && state.left === 0) return;
    form.hidden = false;
    open.hidden = true;
    file.focus();
  });
  form.querySelector("[data-cancel]").addEventListener("click", () => {
    form.hidden = true;
    open.hidden = false;
    say("");
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const photo = file.files && file.files[0];
    if (!photo) return say("Choose a photo of your build first.");
    if (!["image/jpeg", "image/png", "image/webp"].includes(photo.type)) {
      return say("That is not a JPEG, a PNG or a WebP photo.");
    }
    if (photo.size > MOST) return say(`That photo is ${(photo.size / 1048576).toFixed(1)} MB: at most 8 MB, please.`);
    const send = form.querySelector('button[type="submit"]');
    send.disabled = true;
    try {
      say("Sending the photo…");
      const start = await call("/api/people?op=photo_start", { method: "POST",
        body: { model, type: photo.type, size: photo.size } });
      if (start.status !== 200) return say(start.body.error || "That did not work just now.");
      const headers = { "content-type": photo.type, "x-upsert": "false" };
      if (start.body.key) headers.apikey = start.body.key;
      const sent = await fetch(start.body.upload, { method: "PUT", headers, body: photo });
      if (!sent.ok) return say("The photo did not go: try again in a minute.");
      say("Making it safe to show: taking out where and when it was taken…");
      const kept = await call("/api/people?op=photo", { method: "POST",
        body: { model, ticket: start.body.ticket, words: words.value } });
      if (kept.status !== 201) return say(kept.body.error || "That did not work just now.");
      shown(kept.body);
      form.reset();
      form.hidden = true;
      open.hidden = false;
      say("");
      told.textContent = "Added. Thank you for building it.";
      document.documentElement.dataset.buildPhoto = kept.body.id;
      await load();
    } finally {
      send.disabled = false;
    }
  });

  /// A photo just added, at the front of the strip, made of text and its
  /// address only.
  function shown(photo) {
    let row = strip();
    if (!row) {
      row = document.createElement("div");
      row.className = "build-strip";
      document.querySelector("#builds .no-builds")?.replaceWith(row);
    }
    const figure = document.createElement("figure");
    figure.className = "build";
    figure.id = `photo-${photo.id}`;
    figure.dataset.photo = photo.id;
    const img = document.createElement("img");
    img.src = `/api/people?op=photo_file&id=${encodeURIComponent(photo.id)}`;
    img.alt = "Your build";
    img.width = photo.width;
    img.height = photo.height;
    const caption = document.createElement("figcaption");
    if (photo.words) {
      const line = document.createElement("q");
      line.textContent = photo.words;
      caption.append(line);
    }
    const by = document.createElement("span");
    by.className = "by";
    by.textContent = photo.by ? `by ${photo.by.name} · just now` : "by you · just now";
    caption.append(by);
    figure.append(img, caption);
    row.prepend(figure);
  }

  load();
}

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

// ---------------------------------------------------------------------------
// This month's challenge (api/_challenges.js): asked only with the sign-in,
// and answered only to the model's own designer, so nobody else is shown
// anything here. A line under Like and Favourite: Enter this month's
// challenge, which opens a dialog with its rules and a choice of how it was
// built; or that it is in, with Take it out.
async function challengeEntry() {
  const answer = await call(`/api/people?op=challenge_entry&id=${id}`);
  if (answer.status !== 200 || !answer.body.mine || !answer.body.challenge) return;
  const said = answer.body;
  let box = document.getElementById("challenge-entry");
  if (!box) {
    box = document.createElement("div");
    box.id = "challenge-entry";
    box.className = "challenge-entry";
    marks.after(box);
  }
  box.replaceChildren();
  const line = document.createElement("p");
  line.className = "note";
  const named = document.createElement("a");
  named.href = "/challenge";
  named.textContent = said.challenge.title;
  if (said.entry) {
    line.append("In this month’s challenge, ", named, `, ${said.entry.label.toLowerCase()}. `);
    const out = document.createElement("button");
    out.type = "button";
    out.className = "link";
    out.textContent = "Take it out";
    out.addEventListener("click", async () => {
      if (!confirm("Take it out of the challenge? Its votes go with it.")) return;
      out.disabled = true;
      const gone = await call("/api/people?op=withdraw", { method: "POST", body: { model: id } });
      if (gone.status !== 200) {
        out.disabled = false;
        line.append(` ${gone.body.error || "That did not work just now."}`);
        return;
      }
      await challengeEntry();
    });
    line.append(out);
    box.append(line);
  } else {
    line.append("This month’s challenge is ", named, `, open until ${said.challenge.days_said.split(" to ")[1]}. `);
    const go = document.createElement("button");
    go.type = "button";
    go.className = "cta ghost small";
    go.dataset.enter = String(said.challenge.id);
    go.textContent = "Enter this month’s challenge";
    go.addEventListener("click", () => enterDialog(said));
    box.append(line, go);
  }
  document.documentElement.dataset.challengeEntry = said.entry ? "entered" : "open";
}

/// The dialog: the rules, how it was built, and Enter it. The server checks
/// the rules on the model as it is stored and says which it breaks.
function enterDialog(said) {
  const dialog = document.createElement("dialog");
  dialog.className = "sign-in report enter";
  const title = document.createElement("h2");
  title.textContent = `Enter “${said.challenge.title}”`;
  const lede = document.createElement("p");
  lede.textContent = (said.challenge.rules_said || []).length
    ? "Brickworks checks its rules on this model as you shared it:" : "It has no rules but its brief.";
  const rules = document.createElement("ul");
  for (const text of said.challenge.rules_said || []) {
    const item = document.createElement("li");
    item.textContent = text;
    rules.append(item);
  }
  const form = document.createElement("form");
  const choices = document.createElement("fieldset");
  const legend = document.createElement("legend");
  legend.textContent = "How did you build it? The two are judged apart.";
  choices.append(legend);
  for (const [value, words] of [["hand", "By hand"], ["assistant", "With the assistant"]]) {
    const row = document.createElement("label");
    row.className = "choice";
    const pick = document.createElement("input");
    pick.type = "radio";
    pick.name = "way";
    pick.value = value;
    pick.required = true;
    row.append(pick, document.createTextNode(` ${words}`));
    choices.append(row);
  }
  const status = document.createElement("div");
  status.className = "said";
  status.setAttribute("role", "status");
  const send = document.createElement("button");
  send.className = "cta";
  send.type = "submit";
  send.textContent = "Enter it";
  const close = document.createElement("button");
  close.className = "cta ghost";
  close.type = "button";
  close.textContent = "Cancel";
  const row = document.createElement("div");
  row.className = "actions";
  row.append(send, close);
  form.append(choices, row, status);
  dialog.append(title, lede, rules, form);
  document.body.append(dialog);
  const end = () => {
    dialog.close();
    dialog.remove();
  };
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const way = (form.querySelector('input[name="way"]:checked') || {}).value;
    if (!way) return;
    send.disabled = true;
    status.textContent = "Checking it against the rules…";
    const answer = await call("/api/people?op=enter", { method: "POST", body: { model: id, way } });
    send.disabled = false;
    if (answer.status !== 201) {
      status.replaceChildren();
      const broken = answer.body.broken || [];
      if (broken.length) {
        status.append("It does not keep the rules yet:");
        const list = document.createElement("ul");
        for (const one of broken) {
          const item = document.createElement("li");
          item.dataset.rule = one.rule;
          item.textContent = one.said;
          list.append(item);
        }
        status.append(list);
      } else {
        status.textContent = answer.body.error || "That did not go just now. Try again in a minute.";
      }
      document.documentElement.dataset.challengeRefused = answer.body.refused || "error";
      return;
    }
    form.replaceChildren();
    rules.remove();
    lede.textContent = `It is in, ${answer.body.label.toLowerCase()}. People signed in vote until the challenge ends.`;
    const done = document.createElement("button");
    done.className = "cta";
    done.type = "button";
    done.textContent = "Close";
    done.addEventListener("click", end);
    dialog.append(done);
    done.focus();
    await challengeEntry();
  });
  dialog.showModal();
}
