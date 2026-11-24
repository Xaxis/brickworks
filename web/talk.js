// Talk's pages (api/_talk.js draws each whole on the server): what a reader
// does on them. Signed in, a thread is drawn again as they see it (their
// blocks, their own hidden posts, Edit and Remove on theirs), and they
// reply, follow, report, block, edit and remove; /talk/new starts a thread.
// Signed out, everything reads as it is, and the reply box is there all the
// same: Post asks them to sign in and then posts what they wrote, here.
// Replying is the composer's (web/composer.js), as everywhere: in a row of
// a list too, without leaving the list.
//
// Every word somebody typed comes from the server already escaped, in the
// posts' HTML it draws (api/_talk.js postsHtml); nothing typed is put on
// the page here but as text.
import { askToSignIn, call, nameFirst, say, signedIn } from "/account.js";
import { langAt, number, partSaid, told } from "/card.js";
import { replyInCard, wireComposer } from "/composer.js";
import { openReport } from "/report.js";
import { blockPerson } from "/block.js";
import { ask, tell as tellOver } from "/kit.js";
import { start3d } from "/start3d.js";

const root = document.querySelector("[data-talk]");
const TESTS = new URLSearchParams(location.search).get("tests") === "1";
const CODE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "";
const asked = (query) => `/api/people?${query}${CODE ? `&lang=${CODE}` : ""}${TESTS ? "&tests=1" : ""}`;
const $ = (selector, from = root) => from?.querySelector(selector) || null;

/// A line said in the form's status, for a screen reader too.
function tell(form, words) {
  const said = $("[data-said]", form);
  if (said) said.textContent = words;
}

/// Characters as the server counts them (api/_talk.js cleanPost): a
/// character outside the BMP is one, not the two a maxlength would count.
const length = (text) => [...String(text || "")].length;

/// [field]'s words against its most ([data-most]): never cut, as a
/// maxlength cuts a paste without a word; what is left said near the end,
/// and over it the reason Post waits. Its count is under the field.
function measured(field) {
  const most = Number(field.dataset.most) || 4000;
  const note = document.createElement("small");
  note.className = "note talk-count";
  note.setAttribute("aria-live", "polite");
  field.after(note);
  const show = () => {
    const n = length(field.value);
    note.textContent = n > most ? overSaid(field, n) : most > 200 && n > most - 200 ? say("{n} characters left", { n: number(most - n) }) : "";
    note.classList.toggle("bad", n > most);
  };
  field.addEventListener("input", show);
  show();
}

/// Why [field]'s [n] characters cannot go, in the server's own words.
const overSaid = (field, n) => (Number(field.dataset.most) === 120 ? say("A title is 3 to 120 characters on one line.")
  : say("A post is at most 4,000 characters; that is {n}.", { n: number(n) }));

/// The first of [form]'s fields over its most, said in [form]: true when
/// one is, so nothing is sent (nor a photo stored for a post that waits).
function overInForm(form) {
  for (const field of form.querySelectorAll("[data-most]")) {
    const n = length(field.value);
    if (n > Number(field.dataset.most)) {
      tell(form, overSaid(field, n));
      field.focus();
      return true;
    }
  }
  return false;
}

/// The photo chosen in [form], sent to storage (talk_photo_start): its
/// ticket, null for none, or false when it did not go (said in [form]).
async function sendPhoto(form) {
  const input = $("[data-photo]", form);
  const photo = input?.files?.[0];
  if (!photo) return null;
  tell(form, say("Sending the photo…"));
  const start = await call(asked("op=talk_photo_start"), { method: "POST", body: { type: photo.type, size: photo.size } });
  if (start.status !== 200) {
    tell(form, told(start.body?.error, say("The photo did not go: try again in a minute.")));
    return false;
  }
  const headers = { "content-type": photo.type, "x-upsert": "false" };
  if (start.body.key) headers.apikey = start.body.key;
  const sent = await fetch(start.body.upload, { method: "PUT", headers, body: photo }).catch(() => null);
  if (!sent || !sent.ok) {
    tell(form, say("The photo did not go: try again in a minute."));
    return false;
  }
  tell(form, say("Making it safe to show: taking out where and when it was taken…"));
  return start.body.ticket;
}

/// Its chosen photo's name said under [form]'s box, with a way to drop it.
function photoPicked(form) {
  const input = $("[data-photo]", form);
  const shown = $("[data-photo-chosen]", form);
  if (!input || !shown) return;
  input.addEventListener("change", () => {
    const photo = input.files?.[0];
    shown.replaceChildren();
    shown.hidden = !photo;
    if (!photo) return;
    const drop = document.createElement("button");
    drop.type = "button";
    drop.className = "cta ghost small";
    drop.textContent = say("Remove the photo");
    drop.addEventListener("click", () => {
      input.value = "";
      shown.hidden = true;
      shown.replaceChildren();
    });
    shown.append(say("Photo: {name}", { name: photo.name }), " ", drop);
  });
}

/// Signed out: the box's place says how to sign in, and its button does it.
function offerSignIn(why) {
  const place = $("[data-signin]");
  const button = $("[data-act='sign-in']", place || root);
  if (!place || !button) return;
  place.hidden = false;
  button.hidden = false;
  button.addEventListener("click", async () => {
    if (await askToSignIn(why)) location.reload();
  });
}

// ---------------------------------------------------------------------------
// A thread.

const thread = Number(root?.dataset.thread) || 0;
let answering = null;
let mine = new Map();

// A question asked from the studio (Ask the builders, api/_asks.js): the
// model in 3D at the asked step, in its picture's place (web/start3d.js),
// the asked parts lit, each answer on a part a numbered dot on it; a
// signed-in reader who may write answers on a part from the view's menu
// (Answer on this part), and the reply says which part.
const askStart = (() => {
  try {
    return JSON.parse(document.getElementById("talk-ask-data")?.textContent || "null");
  } catch {
    return null;
  }
})();
const question3d = { pins: askStart?.pins || [], asked: askStart?.ask?.parts || [], mayPin: false, onPart: null, view: null };
// What a check reads (tools/web/askhelp_flow.mjs). Reading only.
globalThis.brickworksAsk = { state: askStart ? "ready" : "none", onPart: null, pins: question3d.pins.length };

/// The reply box on [part] (the 3D view's, {part, colour, at, turn, name}),
/// or on none: said over the words, sent with them.
function onPart(part) {
  const form = $("[data-reply-form]");
  const line = $("[data-on-part]", form);
  if (!form || form.hidden || !line) return;
  question3d.onPart = part ? { part: part.part, colour: part.colour, at: part.at, turn: part.turn } : null;
  globalThis.brickworksAsk.onPart = question3d.onPart;
  line.hidden = !part;
  if (!part) return;
  const name = partSaid(part.name || "");
  $("span", line).textContent = name ? say("On the {part}", { part: name }) : say("On a part");
  form.scrollIntoView({ block: "center" });
  $("textarea", form).focus({ preventScroll: true });
}

function startAsk() {
  const big = $(".talk-ask .picture[data-scene]");
  // A model's ask, or a set's (asked on its page, api/_asks.js setAskHtml).
  if (!big || !(askStart?.ask?.model || askStart?.ask?.set)) return;
  question3d.view = start3d(big, {
    // The step seen whole, 8% clear on every side (the view's buttons sit
    // at its edges), before anybody turns it.
    margin: 0.08,
    pins: () => question3d.pins,
    asked: () => question3d.asked,
    mayPin: () => question3d.mayPin,
    pinWanted: (part) => onPart(part),
    pinWord: () => say("Answer on this part"),
    placed: () => {},
    pinPressed: (id) => {
      const one = question3d.pins.find((pin) => pin.id === id);
      return one ? `${one.by ? `${one.by}: ` : ""}${one.said}` : "";
    },
    partName: () => "",
  });
  root.querySelectorAll("[data-ask-part]").forEach((chip) => chip.addEventListener("click", () => question3d.view.open("mouse")));
}

/// The posts as the signed-in reader sees them, and what they may do.
async function load() {
  const got = await call(asked(`op=talk_thread&id=${thread}&html=1`)).catch(() => null);
  if (!got || got.status !== 200) return null;
  const list = $("#talk-posts");
  list.innerHTML = got.body.html;
  mine = new Map((got.body.mine || []).map((one) => [Number(one.id), String(one.body)]));
  $("[data-blocked-some]").hidden = got.body.blocked_some !== true;
  wireActs();
  const follow = $("[data-talk-follow]");
  if (follow) {
    follow.hidden = false;
    follow.setAttribute("aria-pressed", String(got.body.thread?.following === true));
    follow.textContent = got.body.thread?.following ? say("Following") : say("Follow");
  }
  const form = $("[data-reply-form]");
  const place = $("[data-signin]");
  if (form) form.hidden = got.body.you?.may_write !== true;
  // An ask's answers on parts as this reader sees them, and whether they
  // may answer on one (Answer on this part in the 3D view's menu).
  if (askStart) {
    question3d.pins = got.body.pins || [];
    question3d.mayPin = got.body.you?.may_write === true;
    globalThis.brickworksAsk.pins = question3d.pins.length;
    question3d.view?.pinsChanged();
  }
  if (place) {
    place.hidden = got.body.you?.may_write === true;
    const words = $("p", place);
    if (words) words.textContent = told(got.body.you?.why_not, words.textContent);
    const button = $("[data-act='sign-in']", place);
    if (button) button.hidden = true;
  }
  return got.body;
}

/// Each post's acts shown, now that they do something.
function wireActs() {
  for (const acts of root.querySelectorAll("[data-acts]")) acts.hidden = false;
}

/// Reply to [post]: the box says whom, and has the focus.
function answer(post) {
  const form = $("[data-reply-form]");
  if (!form || form.hidden) return;
  answering = Number(post.dataset.post);
  const line = $("[data-answering]", form);
  line.hidden = false;
  $("span", line).textContent = say("Answering {name}", { name: post.dataset.name || say("a builder") });
  $("textarea", form).focus();
}

/// [post] edited in place: its words in a box, Save and Cancel.
function edit(post) {
  const id = Number(post.dataset.post);
  const body = $(".comment-body", post);
  if (!body || $(".talk-edit", post)) return;
  const box = document.createElement("form");
  box.className = "talk-edit comment-new";
  const label = document.createElement("label");
  label.textContent = say("Your post");
  const words = document.createElement("textarea");
  words.rows = 5;
  words.dataset.most = "4000";
  words.required = true;
  words.value = mine.get(id) ?? body.textContent;
  label.append(words);
  const row = document.createElement("div");
  row.className = "actions";
  const save = document.createElement("button");
  save.className = "cta";
  save.type = "submit";
  save.textContent = say("Save");
  const cancel = document.createElement("button");
  cancel.className = "cta ghost";
  cancel.type = "button";
  cancel.textContent = say("Cancel");
  const said = document.createElement("span");
  said.className = "said";
  said.setAttribute("role", "status");
  said.dataset.said = "";
  row.append(save, cancel, said);
  box.append(label, row);
  body.hidden = true;
  body.after(box);
  measured(words);
  words.focus();
  cancel.addEventListener("click", () => {
    box.remove();
    body.hidden = false;
  });
  box.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (overInForm(box)) return;
    save.disabled = true;
    const done = await call(asked("op=talk_change"), { method: "POST", body: { post: id, what: "edit", body: words.value } });
    save.disabled = false;
    if (done.status !== 200) return tell(box, told(done.body?.error, say("That did not work just now. Try again in a minute.")));
    await load();
    document.getElementById(`post-${id}`)?.querySelector(".comment-body")?.focus?.();
  });
}

async function remove(post) {
  const id = Number(post.dataset.post);
  const first = post === $("#talk-posts > li");
  if (!(await ask({ title: say("Remove your post?"), body: first ? say("It starts the thread, so the whole thread goes with it.") : "",
    yes: say("Remove"), no: say("Cancel"), danger: true }))) return;
  const done = await call(asked("op=talk_change"), { method: "POST", body: { post: id, what: "remove" } });
  if (done.status !== 200) {
    return tellOver({ title: say("Your post was not removed"),
      body: told(done.body?.error, say("That did not work just now. Try again in a minute.")) });
  }
  if (done.body.thread_removed) {
    location.href = `${langAt()}/talk${TESTS ? "?tests=1" : ""}`;
    return;
  }
  await load();
}

function threadPage() {
  const list = $("#talk-posts");
  wireActs();
  startAsk();
  list.addEventListener("click", async (event) => {
    const button = event.target.closest("button[data-act]");
    const post = button?.closest("li[data-post]");
    if (!button || !post) return;
    const act = button.dataset.act;
    // An answer's part, in the 3D view: opened, turned to it and lit.
    if (act === "show-part" && question3d.view) {
      question3d.view.showPin(Number(button.dataset.pin), event.detail === 0 ? "key" : "mouse");
      $(".talk-ask")?.scrollIntoView({ block: "nearest" });
      return;
    }
    if (act === "reply") {
      // Signed in here and then, the thread drawn as they see it, the box
      // answering the post: no page left, nothing typed lost.
      if (!signedIn()) {
        if (!(await askToSignIn("Sign in to reply: we email you a code, no password. Anyone can read Talk."))) return;
        await load();
        const again = document.getElementById(`post-${Number(post.dataset.post)}`);
        if (again) answer(again);
        return;
      }
      answer(post);
    }
    if (act === "report") openReport({ post: Number(post.dataset.post) }, say("this post"));
    if (act === "edit") edit(post);
    if (act === "remove") await remove(post);
    if (act === "block") {
      button.disabled = true;
      const done = await blockPerson(post.dataset.handle, post.dataset.name || post.dataset.handle, true);
      button.disabled = false;
      if (done.ok) await load();
      if (done.said) {
        const note = $("[data-blocked-some]");
        note.textContent = done.said;
        note.hidden = false;
      }
    }
  });
  const form = $("[data-reply-form]");
  if (form) {
    photoPicked(form);
    form.querySelectorAll("[data-most]").forEach(measured);
    $("[data-act='unanswer']", form)?.addEventListener("click", () => {
      answering = null;
      $("[data-answering]", form).hidden = true;
    });
    $("[data-act='off-part']", form)?.addEventListener("click", () => onPart(null));
    const field = $("textarea", form);
    wireComposer(form, {
      field,
      said: $("[data-said]", form),
      most: 4000,
      over: (n) => overSaid(field, n),
      count: false,
      signIn: "Sign in to reply: we email you a code, no password. Anyone can read Talk.",
      ready: async () => {
        const body = await load();
        return body?.you?.may_write ? "" : told(body?.you?.why_not, say("That did not go just now. Try again in a minute."));
      },
      send: async (text) => {
        const photo = await sendPhoto(form);
        if (photo === false) return { ok: false, error: $("[data-said]", form)?.textContent || "" };
        const done = await call(asked("op=talk_reply"), { method: "POST",
          body: { thread, body: text, ...(answering ? { answers: answering } : {}), ...(photo ? { photo } : {}),
            ...(question3d.onPart ? { part: question3d.onPart } : {}) } });
        return done.status === 201 ? { ok: true, made: done.body } : { ok: false, error: told(done.body?.error) };
      },
      done: async (made) => {
        const input = $("[data-photo]", form);
        if (input) input.value = "";
        field.dispatchEvent(new Event("input"));
        onPart(null);
        answering = null;
        $("[data-answering]", form).hidden = true;
        $("[data-photo-chosen]", form).hidden = true;
        onPart(null);
        await load();
        document.getElementById(`post-${Number(made.post?.id)}`)?.scrollIntoView({ block: "center" });
        tell(form, made.mentions?.length ? say("Posted. {names} will hear of it.", { names: made.mentions.map((one) => `@${one.handle}`).join(", ") })
          : say("Posted."));
      },
    });
  }
  const follow = $("[data-talk-follow]");
  follow?.addEventListener("click", async () => {
    const on = follow.getAttribute("aria-pressed") !== "true";
    follow.disabled = true;
    const done = await call(asked("op=talk_follow"), { method: "POST", body: { thread, on } });
    follow.disabled = false;
    const said = $("[data-talk-follow-said]");
    if (done.status !== 200) {
      said.hidden = false;
      said.textContent = told(done.body?.error, say("That did not work just now. Try again in a minute."));
      return;
    }
    follow.setAttribute("aria-pressed", String(done.body.following === true));
    follow.textContent = done.body.following ? say("Following") : say("Follow");
    said.hidden = false;
    said.textContent = done.body.following ? say("You will hear of each new post here.") : say("You will not hear of new posts here.");
  });
  if (!signedIn()) {
    // The box is everybody's: Post signs them in first (wireComposer).
    if (form) {
      form.hidden = false;
      const place = $("[data-signin]");
      if (place) place.hidden = true;
    } else {
      offerSignIn(say("Sign in to reply: we email you a code, no password. Anyone can read Talk."));
    }
    return;
  }
  load().then((body) => {
    if (body) call(asked("op=talk_read"), { method: "POST", body: { thread } }).catch(() => null);
  });
}

// ---------------------------------------------------------------------------
// Start a thread.

function newPage() {
  const form = $("[data-start-form]");
  if (!signedIn()) {
    offerSignIn(say("Sign in to start a thread: we email you a code, no password. Anyone can read Talk."));
    return;
  }
  $("[data-signin]").hidden = true;
  form.hidden = false;
  photoPicked(form);
  form.querySelectorAll("[data-most]").forEach(measured);
  const model = $("[data-model]", form)?.dataset.model || "";
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (overInForm(form)) return;
    const send = $("button[type='submit']", form);
    send.disabled = true;
    try {
      // A name first, once, as before any reply (web/account.js nameFirst):
      // made or skipped, the thread then starts, its words as typed.
      await nameFirst();
      const photo = await sendPhoto(form);
      if (photo === false) return;
      tell(form, say("Posting…"));
      const board = $("input[name='board']:checked", form)?.value || "";
      const done = await call(asked("op=talk_start"), { method: "POST", body: { board, title: form.elements.title.value,
        body: form.elements.body.value, ...(model && board === "show" ? { model } : {}), ...(photo ? { photo } : {}) } });
      if (done.status === 409 && done.body?.path) {
        location.href = `${langAt()}${done.body.path}${TESTS ? "?tests=1" : ""}`;
        return;
      }
      if (done.status !== 201) return tell(form, told(done.body?.error, say("That did not go just now. Try again in a minute.")));
      location.href = `${langAt()}${done.body.path}${TESTS ? "?tests=1" : ""}`;
    } finally {
      send.disabled = false;
    }
  });
}

// ---------------------------------------------------------------------------
// A list: Reply in a row, and the way to start a thread keeps a test's pool.

function listPage() {
  // Reply in a row: the composer opened under it, the reply shown there
  // once posted; the thread's own page for a new tab or window.
  root.addEventListener("click", (event) => {
    const pressed = event.target instanceof Element ? event.target.closest("a[data-reply-thread]") : null;
    const row = pressed?.closest(".talk-row");
    if (!row || event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    replyInCard(row, Number(pressed.dataset.replyThread), { opener: pressed, tests: TESTS ? "&tests=1" : "", lang: CODE });
  });
  if (!TESTS) return;
  for (const link of root.querySelectorAll("a[href*='/talk']")) {
    const url = new URL(link.href, location.href);
    if (url.origin === location.origin && !url.searchParams.has("tests")) {
      url.searchParams.set("tests", "1");
      link.href = `${url.pathname}${url.search}${url.hash}`;
    }
  }
}

if (root?.dataset.talk === "thread") threadPage();
if (root?.dataset.talk === "new") newPage();
if (root?.dataset.talk === "list") listPage();
