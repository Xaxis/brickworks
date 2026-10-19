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
