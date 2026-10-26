// A shared model's page, /m/<id> (the directory, 2026-10-13): its action
// bar (2026-10-22, docs/SOCIAL.md U4): Like, Save (your favourites and your
// collections, in one list), Share, Comment, I built it and More, Like and
// Save asking to sign in first when this browser is not (web/account.js),
// each a call to /api/people. What the page shows without it — the
// counts, the way into the viewer — needs none of this.
//
// Every name shown here (a collection's) is put on the page as text.
//
// And its comments (2026-10-18, api/_comments.js), as threads (2026-10-22,
// docs/SOCIAL.md U8): the newest comment first and its replies under it,
// oldest first; each with its writer's avatar, Designer on the model's
// owner's, and its step as a pill that opens the viewer there (an older
// version's step, that version's viewer). The box is everybody's, with a
// step picker: a visitor signs in as they send, and what they wrote is
// kept; somebody who may not write is told why, politely. Reply under each
// comment, Report on each, Remove on one's own, Hide and Show on each and
// comments off or on for the model's owner, replies as comments. What a
// stranger wrote is set as text, never as markup, and a link in it stays
// words.
import { askToSignIn, call, signedIn } from "/account.js";
import { openReport } from "/report.js";
import { avatarHtml } from "/kit.js";

// The comments' own loader, once they are listed (startComments), for
// Comment in the action bar to list them again after signing in.
let commentsLoaded = null;
const marks = document.getElementById("marks");
const id = marks && marks.dataset.id;
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "")) start();
// This month's challenge (supabase/challenges.sql), for the model's own
// designer: Enter this month's challenge, or that it is in.
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "") && signedIn()) challengeEntry();
const comments = document.getElementById("comments");
if (comments && /^[A-Za-z0-9]{10}$/.test(comments.dataset.id || "")) startComments(comments);

// Where the picture's frame is square (directory.css): a phone's.
const PHONE = matchMedia("(max-width: 599px)");
// Its picture: the frame says it is coming until it is drawn, and one that
// fails is asked for again, twice, before the frame says there is none.
const frame = document.querySelector(".model-page .picture");
if (frame) startPicture(frame);

// The strip of its pictures (api/share.js mediaStrip): the one chosen is
// shown in the picture's place, whole, and edged in the strip. The picture
// is still the way into the viewer.
const strip = document.getElementById("pictures");
if (strip) startPictures(strip);
// The page's tabs: the part being read is marked as the page scrolls.
const tabs = document.getElementById("page-tabs");
if (tabs) startTabs(tabs);

function startPicture(big) {
  const img = big.querySelector("img");
  const sign = big.querySelector(".waiting");
  if (!img || !sign) return;
  let tries = 0;
  const drawn = () => {
    sign.hidden = true;
    img.style.visibility = "";
    fitPicture(big, img);
  };
  const failed = () => {
    // Not the browser's broken picture over the words while it is asked again.
    img.style.visibility = "hidden";
    sign.hidden = false;
    if (tries >= 2) {
      sign.textContent = "No picture";
      return;
    }
    tries += 1;
    const src = img.getAttribute("src").replace(/[?&]again=\d+$/, "");
    setTimeout(() => { img.src = `${src}${src.includes("?") ? "&" : "?"}again=${tries}`; }, 1500 * tries);
  };
  img.addEventListener("load", drawn);
  img.addEventListener("error", failed);
  if (img.complete) (img.naturalWidth > 0 ? drawn : failed)();
  PHONE.addEventListener("change", () => fitPicture(big, img));
}


/// On a phone the picture's frame is square, and its model is drawn as
/// large as the model's width lets it: the 1200 x 630 picture cropped
/// round the model when the model is no wider than the square, else
/// scaled until all of it is in, the picture's own ground carried on above
/// and below. Never smaller than the whole picture across the frame, as it
/// was: 186 px tall at 390, a fifth of the screen (site273). By transform
/// alone, which moves nothing else, so the page never shifts as it does.
/// A photo is shown whole (.photo), and on a laptop the frame is the
/// picture's own shape.
function fitPicture(big, img) {
  img.style.objectFit = "";
  img.style.transform = "";
  big.style.background = "";
  if (!PHONE.matches || big.classList.contains("photo") || !img.naturalWidth) return;
  // The model's columns, read from a small copy: those that differ from
  // the ground, a gradient from top to bottom read at the corners.
  const w = 120;
  const h = Math.max(1, Math.round((w * img.naturalHeight) / img.naturalWidth));
  const pen = Object.assign(document.createElement("canvas"), { width: w, height: h }).getContext("2d", { willReadFrequently: true });
  let px;
  try {
    pen.drawImage(img, 0, 0, w, h);
    px = pen.getImageData(0, 0, w, h).data;
  } catch {
    return;
  }
  const colour = (x, y) => [0, 1, 2].map((c) => px[(y * w + x) * 4 + c]);
  const mix = (a, b) => a.map((v, c) => (v + b[c]) / 2);
  const top = mix(colour(0, 0), colour(w - 1, 0));
  const foot = mix(colour(0, h - 1), colour(w - 1, h - 1));
  const hits = new Array(w).fill(0);
  for (let y = 0; y < h; y += 1) {
    const ground = top.map((v, c) => v + ((foot[c] - v) * y) / Math.max(1, h - 1));
    for (let x = 0; x < w; x += 1) {
      const here = colour(x, y);
      if (Math.abs(here[0] - ground[0]) + Math.abs(here[1] - ground[1]) + Math.abs(here[2] - ground[2]) > 40) hits[x] += 1;
    }
  }
  const first = hits.findIndex((n) => n >= 2);
  const last = w - 1 - [...hits].reverse().findIndex((n) => n >= 2);
  if (first < 0) return;
  // The share of the picture's width shown: the model's and a margin, and
  // no less than the square's, which crops it to the frame's height.
  const aspect = img.naturalWidth / img.naturalHeight;
  const shown = Math.min(1, Math.max(1 / aspect, (last - first + 1) / w + 0.06));
  const middle = Math.min(1 - shown / 2, Math.max(shown / 2, (first + last + 1) / 2 / w));
  // Drawn whole across the frame (contain), then enlarged round the model.
  img.style.objectFit = "contain";
  img.style.transform = `scale(${(1 / shown).toFixed(4)}) translateX(${((0.5 - middle) * 100).toFixed(2)}%)`;
  // Its ground above and below it, where it is shorter than the frame.
  const band = Math.max(0, (1 - 1 / (shown * aspect)) / 2) * 100;
  if (band > 0.5) {
    const rgb = (c) => `rgb(${c.map(Math.round).join(" ")})`;
    big.style.background = `linear-gradient(180deg, ${rgb(top)} ${band.toFixed(1)}%, ${rgb(foot)} ${(100 - band).toFixed(1)}%)`;
  }
}

function startPictures(row) {
  const big = document.querySelector(".model-page .picture");
  const img = big && big.querySelector("img");
  if (!img) return;
  row.addEventListener("click", (event) => {
    const thumb = event.target.closest("a.thumb[data-picture]");
    if (!thumb) return;
    event.preventDefault();
    img.src = thumb.dataset.picture;
    img.alt = thumb.querySelector("img")?.alt || img.alt;
    // The published picture fills its frame; a photo is shown whole.
    big.classList.toggle("photo", thumb.getAttribute("href").startsWith("#"));
    for (const one of row.querySelectorAll("a.thumb")) one.removeAttribute("aria-current");
    thumb.setAttribute("aria-current", "true");
  });
}

/// The tab of the part at the top of the screen, under the tabs; a tab
/// chosen stays marked until the reader scrolls on themselves, since the
/// last parts are often too short to reach the top.
function startTabs(nav) {
  const links = [...nav.querySelectorAll("a[data-tab]")];
  let held = "";
  let queued = false;
  const mark = (key) => {
    for (const link of links) {
      if (link.dataset.tab !== key) {
        link.removeAttribute("aria-current");
        continue;
      }
      link.setAttribute("aria-current", "true");
      // On a phone the row scrolls inside itself: the marked tab in view.
      if (link.offsetLeft < nav.scrollLeft || link.offsetLeft + link.offsetWidth > nav.scrollLeft + nav.clientWidth) {
        nav.scrollLeft = Math.max(0, link.offsetLeft - 16);
      }
    }
  };
  const stuckAt = parseFloat(getComputedStyle(nav).top) || 0;
  const reading = () => {
    queued = false;
    // Only stuck under the header does it need a ground of its own: under
    // the picture, it would cut across the picture's shadow.
    nav.classList.toggle("loose", nav.getBoundingClientRect().top > stuckAt + 1);
    if (held) return mark(held);
    // The part read is the one across the top third of what shows under the tabs.
    const under = nav.getBoundingClientRect().bottom;
    const line = under + Math.max(16, (innerHeight - under) / 3);
    let key = links[0]?.dataset.tab || "";
    for (const link of links) {
      const part = document.getElementById(link.dataset.tab);
      if (part && !part.hidden && !link.hidden && part.getBoundingClientRect().top <= line) key = link.dataset.tab;
    }
    mark(key);
  };
  addEventListener("scroll", () => {
    if (!queued) {
      queued = true;
      requestAnimationFrame(reading);
    }
  }, { passive: true });
  for (const name of ["wheel", "touchmove", "keydown"]) {
    addEventListener(name, () => { held = ""; }, { passive: true });
  }
  nav.addEventListener("click", (event) => {
    const link = event.target.closest("a[data-tab]");
    if (!link) return;
    held = link.dataset.tab;
    mark(held);
  });
  reading();
}

function startComments(section) {
  const model = section.dataset.id;
  const version = Number(section.dataset.version) || 1;
  const newest = Number(section.dataset.newest) || version;
  const list = section.querySelector(".comment-list");
  const form = section.querySelector("form.comment-new");
  const step = form.querySelector("#comment-step");
  const box = form.querySelector("#comment-body");
  const send = form.querySelector('button[type="submit"]');
  const left = form.querySelector(".comment-count");
  const why = section.querySelector(".comment-why");
  const said = section.querySelector(".comments-said");
  let state = null;
  // The thread whose reply box is open, and what was typed in it, kept
  // across a sign-in and a redraw.
  let replying = null;
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
    if (answer.status !== 200) {
      // The section stays hidden, and so does its tab.
      const tab = document.querySelector('#page-tabs a[data-tab="comments"]');
      if (tab && section.hidden) tab.hidden = true;
      return say(answer.body.error || "The comments did not load just now.");
    }
    state = answer.body;
    // Not open on this deployment yet (comments.sql): nothing to show.
    section.hidden = state.ready === false;
    draw();
    commentsSaid(state, setOpen);
  }
  commentsLoaded = { reload: load };

  function button(words, run, kind = "link") {
    const made = document.createElement("button");
    made.type = "button";
    made.className = kind;
    made.textContent = words;
    made.addEventListener("click", run);
    return made;
  }

  /// The viewer at [at], a step of version [of]: Build it, opened there.
  const viewerAt = (of, at) => `/app?view=${model}${of === newest ? "" : `&v=${of}`}&step=${at}`;

  /// Somebody signed out may say something: the box is everybody's, and
  /// sending signs them in first. Whether they may then is the server's.
  const mayTry = () => state.you?.may_write || (!state.you?.signed_in && state.open);

  /// One comment or reply: the avatar, who (a link to their page), the
  /// Designer pill on the model's owner's, the step as a pill that opens
  /// the viewer there, when, the words, and what the reader may do.
  function item(one, reply, replies) {
    const made = document.createElement("li");
    made.className = `comment${reply ? " reply" : ""}${one.hidden ? " hidden-one" : ""}${one.by_owner ? " by-owner" : ""}`;
    made.id = `comment-${one.id}`;
    made.dataset.step = one.step ?? "";
    const face = document.createElement("template");
    face.innerHTML = avatarHtml({ handle: one.handle || "", name: one.by || "A builder", picture: one.picture },
      { size: reply ? "small" : "" });
    const main = document.createElement("div");
    main.className = "comment-main";
    const head = document.createElement("p");
    head.className = "comment-head";
    const who = one.handle ? document.createElement("a") : document.createElement("b");
    if (one.handle) who.href = `/u/${encodeURIComponent(one.handle)}`;
    who.textContent = one.by || "A builder";
    head.append(who);
    if (one.by_owner) {
      const tag = document.createElement("span");
      tag.className = "pill designer";
      tag.textContent = "Designer";
      head.append(" ", tag);
    }
    // A reply is on its comment's step: said once, on the comment.
    if (one.step && !reply) {
      const pill = document.createElement("a");
      pill.className = "pill step";
      const here = one.on_step !== null && one.on_step !== undefined;
      pill.href = here ? viewerAt(version, one.on_step) : viewerAt(one.version, one.step);
      pill.textContent = here ? `Step ${one.on_step}` : `Step ${one.step} of version ${one.version}`;
      pill.title = `Open it at this step: said ${one.said}`;
      head.append(" ", pill);
    }
    const time = document.createElement("time");
    const at = Date.parse(one.at || "");
    if (Number.isFinite(at)) {
      time.dateTime = new Date(at).toISOString();
      time.textContent = `${DAY.format(at)}${one.edited_at ? " · edited" : ""}`;
    }
    head.append(" ", time);
    // Said on an older version than the one shown, and not by its step.
    if (!reply && one.older && !(one.step && one.on_step === null)) {
      const where = document.createElement("span");
      where.className = "where";
      where.textContent = ` · ${one.said}`;
      head.append(where);
    }
    const words = document.createElement("p");
    words.className = "comment-body";
    words.textContent = one.body;
    main.append(head, words);
    if (one.hidden) {
      const note = document.createElement("p");
      note.className = "note";
      const what = reply ? "reply" : replies.length ? "comment and its replies" : "comment";
      note.textContent = state.you?.owner ? `Hidden: only you and its author see this ${what}.`
        : `Its designer hid this ${what}: only you and they see it.`;
      main.append(note);
    }
    const acts = document.createElement("p");
    acts.className = "comment-acts";
    if (!reply && state.replies && state.open && !one.hidden && mayTry()) {
      const answer = button("Reply", () => openReply(one.id));
      answer.dataset.reply = String(one.id);
      // Whose, for a screen reader's list of buttons: six "Reply" say nothing.
      answer.setAttribute("aria-label", `Reply to ${one.by || "a builder"}`);
      acts.append(answer);
    }
    if (state.you?.owner) {
      acts.append(button(one.hidden ? "Show it" : "Hide it", () => change(one, one.hidden ? "show" : "hide")));
    }
    if (one.mine) {
      const ask = reply ? "Remove your reply?" : replies.length ? "Remove your comment? Its replies go with it." : "Remove your comment?";
      acts.append(button("Remove it", () => confirm(ask) && change(one, "remove")));
    }
    if (!one.mine) acts.append(button("Report it", () => openReport({ comment: one.id }, reply ? "this reply" : "this comment")));
    main.append(acts);
    if (!reply) {
      const under = document.createElement("ol");
      under.className = "replies";
      under.hidden = replies.length === 0;
      for (const answer of replies) under.append(item(answer, true, []));
      main.append(under);
    }
    made.append(face.content.firstElementChild, main);
    return made;
  }

  function draw() {
    // Each thread a comment and its replies: the newest thread first, its
    // replies oldest first, as the conversation went.
    const all = state.comments || [];
    const under = new Map();
    for (const one of all) {
      if (one.parent) under.set(one.parent, [...(under.get(one.parent) || []), one]);
    }
    const order = (a, b) => (Date.parse(a.at) - Date.parse(b.at)) || (a.id - b.id);
    const threads = all.filter((one) => !one.parent).sort((a, b) => order(b, a));
    // A person on the keyboard pressed something in a comment (Hide it,
    // Show it): the same comment's button keeps the focus once it is drawn
    // again, else the comment, else the list's heading, never the body.
    const at = list.contains(document.activeElement) ? document.activeElement : null;
    const where = at && { comment: at.closest("li.comment")?.id, words: at.localName === "button" ? at.textContent : "" };
    list.replaceChildren(...threads.map((one) => item(one, false, (under.get(one.id) || []).sort(order))));
    if (where && !list.contains(document.activeElement) && !document.querySelector("form.reply-new")) {
      const again = where.comment && document.getElementById(where.comment);
      const pressed = again && [...again.querySelectorAll(":scope > .comment-main > .comment-acts button")]
        .find((one) => one.textContent === where.words);
      const heading = document.getElementById("comments-h");
      const to = pressed || again || heading;
      if (to && to.tabIndex < 0 && to.localName !== "button") to.tabIndex = -1;
      to?.focus({ preventScroll: true });
    }
    // None yet: one line, and the box under it.
    const empty = threads.length === 0;
    section.querySelector(".comments-lede").hidden = empty;
    if (empty) {
      const none = document.createElement("li");
      none.className = "note none";
      none.textContent = state.open ? "Nobody has commented yet." : "No comments.";
      list.append(none);
    }
    const you = state.you || {};
    form.hidden = !mayTry();
    send.textContent = you.signed_in ? "Add the comment" : "Sign in and add it";
    why.replaceChildren();
    why.hidden = !you.signed_in || Boolean(you.may_write);
    if (you.signed_in && !you.may_write) {
      const words = document.createElement("p");
      words.className = "note";
      words.textContent = you.why_not || "";
      why.append(words);
    }
    if (!you.signed_in && !state.open) {
      const words = document.createElement("p");
      words.className = "note";
      words.textContent = "Comments are off for this model.";
      why.hidden = false;
      why.append(words);
    }
    if (you.owner) {
      const line = document.createElement("p");
      line.className = "note owner-line";
      line.append(state.open ? "Comments are on for this model. " : "Comments are off for this model. ",
        button(state.open ? "Turn them off" : "Turn them on", () => setOpen(!state.open)));
      why.hidden = false;
      why.append(line);
    }
    if (replying) openReply(replying.id, replying.text, false);
    // Opened at a comment (an email's link, a notification's, the admin
    // page's): marked.
    const named = /^#comment-\d+$/.test(location.hash) ? document.getElementById(location.hash.slice(1)) : null;
    if (named && !draw.shown) {
      draw.shown = true;
      named.classList.add("asked");
      named.scrollIntoView({ block: "center" });
    }
  }

  /// Signed in, or signed in now from the box: whether to go on sending.
  async function signInFirst(words) {
    if (signedIn()) return true;
    if (!(await askToSignIn(words))) return false;
    await load();
    if (state.you?.may_write) return true;
    say(state.you?.why_not || "That did not go just now. Try again in a minute.");
    return false;
  }

  /// The reply box under thread [to], with [text] in it.
  function openReply(to, text = "", focus = true) {
    const thread = document.getElementById(`comment-${to}`);
    if (!thread || thread.classList.contains("reply")) {
      replying = null;
      return;
    }
    for (const open of list.querySelectorAll("form.reply-new")) if (open.dataset.to !== String(to)) open.remove();
    let made = thread.querySelector("form.reply-new");
    if (!made) {
      made = document.createElement("form");
      made.className = "reply-new";
      made.dataset.to = String(to);
      const label = document.createElement("label");
      label.className = "visually-hidden";
      label.htmlFor = `reply-${to}`;
      label.textContent = "Your reply";
      const field = document.createElement("textarea");
      field.id = `reply-${to}`;
      field.maxLength = 1000;
      field.rows = 2;
      field.placeholder = `Reply to ${thread.querySelector(".comment-head a, .comment-head b")?.textContent || "them"}`;
      const go = document.createElement("div");
      go.className = "actions";
      const post = document.createElement("button");
      post.type = "submit";
      post.className = "cta small";
      post.textContent = signedIn() ? "Reply" : "Sign in and reply";
      // Cancel, or Escape in the box: gone, the focus back on Reply.
      const cancel = () => {
        replying = null;
        made.remove();
        thread.querySelector(`[data-reply="${to}"]`)?.focus();
      };
      go.append(post, button("Cancel", cancel, "cta ghost small"));
      made.addEventListener("keydown", (event) => {
        if (event.key !== "Escape") return;
        event.preventDefault();
        cancel();
      });
      made.append(label, field, go);
      field.addEventListener("input", () => {
        replying = { id: to, text: field.value };
      });
      made.addEventListener("submit", (event) => {
        event.preventDefault();
        sendReply(to, field, post);
      });
      thread.querySelector(".comment-main").append(made);
    }
    const field = made.querySelector("textarea");
    if (text && !field.value) field.value = text;
    replying = { id: to, text: field.value };
    if (focus) field.focus();
  }

  async function sendReply(to, field, post) {
    const text = field.value.trim();
    if (!text) return say("Say something first.");
    replying = { id: to, text: field.value };
    if (!(await signInFirst("Sign in to add your reply: we email you a code, no password. What you wrote is kept."))) return;
    post.disabled = true;
    say("Adding it…");
    const answer = await call("/api/people?op=reply", { method: "POST", body: { id: to, body: text } });
    post.disabled = false;
    if (answer.status !== 201) return say(answer.body.error || "That did not go just now. Try again in a minute.");
    replying = null;
    say("Replied.");
    await load();
    // The reply, read out where it now is; else its comment's Reply.
    const made = document.getElementById(`comment-${answer.body.comment?.id}`);
    if (made) {
      made.tabIndex = -1;
      made.focus({ preventScroll: true });
      made.scrollIntoView({ block: "nearest" });
    } else document.querySelector(`[data-reply="${to}"]`)?.focus();
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
    if (!(await signInFirst("Sign in to add your comment: we email you a code, no password. What you wrote is kept."))) return;
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
  const pictures = document.getElementById("pictures");
  const addPicture = pictures && pictures.querySelector("[data-add-picture]");
  const MOST = 8 * 1024 * 1024;
  let state = null;
  box.hidden = false;
  // The owner's own pictures go the same way, from the strip's last tile.
  addPicture?.addEventListener("click", () => {
    document.getElementById("builds")?.scrollIntoView({ block: "start" });
    open.click();
  });

  const say = (text) => { said.textContent = text; };

  /// The photos as the caller may act on them: their own, and as the
  /// model's owner, every one with Hide (or Show again).
  async function load() {
    if (!signedIn()) return;
    const answer = await call(`/api/people?op=photos&id=${model}`);
    if (answer.status !== 200) return;
    state = answer.body;
    if (state.left === 0) open.textContent = "You have added three photos: the most";
    else if (state.owner) open.textContent = "Add a picture of it";
    open.disabled = state.left === 0;
    if (state.owner) ownerTools(state.photos || []);
    // Its owner adds pictures of their own under the picture: they lead
    // the strip (api/share.js mediaStrip), shown to them even while empty.
    if (state.owner && addPicture) {
      pictures.hidden = false;
      addPicture.hidden = false;
      addPicture.disabled = state.left === 0;
      addPicture.textContent = state.left === 0 ? "Three added" : "Add a picture";
    }
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
    // And in the strip under the picture: the owner's with theirs, first.
    if (pictures) {
      const thumb = document.createElement("a");
      thumb.className = "thumb";
      thumb.href = `#photo-${photo.id}`;
      thumb.dataset.picture = img.src;
      if (state?.owner) thumb.dataset.own = "";
      const small = document.createElement("img");
      small.src = img.src;
      small.alt = state?.owner ? "Your picture of it" : "Your build";
      thumb.append(small);
      const own = pictures.querySelectorAll("a.thumb[data-own]");
      const after = state?.owner ? pictures.querySelector("a.thumb:not([href^='#'])") : own[own.length - 1]
        || pictures.querySelector("a.thumb:not([href^='#'])");
      if (after) after.after(thumb);
      else pictures.prepend(thumb);
      pictures.hidden = false;
    }
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

/// An icon button's count, and its name and count as its label ("Like, 12
/// likes"; "Like" at none), as web/kit.js iconButtonHtml draws them: a
/// count of none is not shown.
function setCount(button, n, name, one, many = `${one}s`) {
  if (!button) return;
  const value = Number(n) || 0;
  let shown = button.querySelector(".n");
  if (value && !shown) {
    shown = document.createElement("span");
    shown.className = "n";
    shown.setAttribute("aria-hidden", "true");
    button.append(shown);
  }
  if (shown && !value) shown.remove();
  else if (shown) shown.textContent = value.toLocaleString("en-US");
  button.setAttribute("aria-label", value ? `${name}, ${value.toLocaleString("en-US")} ${value === 1 ? one : many}` : name);
}

/// A tab's count (api/share.js pageTabs), never one of none.
function tabCount(tab, n) {
  const value = Number(n) || 0;
  let shown = tab.querySelector(".n");
  if (!value) return shown?.remove();
  if (!shown) {
    shown = document.createElement("span");
    shown.className = "n";
    tab.append(" ", shown);
  }
  shown.textContent = value.toLocaleString("en-US");
}

/// [text] on the clipboard: the browser's clipboard where the page may use
/// it (a secure page), else the older way, through a selection. Whether it
/// went.
async function copy(text) {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // The older way, below.
  }
  const box = document.createElement("textarea");
  box.value = text;
  box.setAttribute("readonly", "");
  box.className = "visually-hidden";
  document.body.append(box);
  box.select();
  let done = false;
  try {
    done = document.execCommand("copy");
  } catch {
    done = false;
  }
  box.remove();
  return done;
}

/// Share's sheet (api/share.js shareSheet, docs/SOCIAL.md U14): the site's
/// dialog with the page's link and the embed code, each copied by its own
/// button and said so in the sheet (the toast, outside a dialog that is
/// open, is behind it for a screen reader too); and where the browser has a
/// share sheet of its own, a phone's, a way to it, given the link. The
/// link is selected as it opens, so a keyboard's copy takes it too.
/// Escape and Close close it, back on Share.
function shareSheet(share, sheet) {
  const said = sheet.querySelector(".said");
  const link = sheet.querySelector("#share-link");
  const app = sheet.querySelector("[data-share-app]");
  const url = link.value;
  const title = document.querySelector("main h1")?.textContent || document.title;
  share.addEventListener("click", () => {
    app.hidden = !(typeof navigator.share === "function" && (!navigator.canShare || navigator.canShare({ url })));
    said.textContent = "";
    sheet.showModal();
    document.documentElement.dataset.shared = "open";
    link.focus();
    link.select();
  });
  const COPIED = { "share-link": ["Link copied", "copied"], "share-embed": ["Embed code copied: paste it into your page", "embed"] };
  for (const button of sheet.querySelectorAll("[data-copy]")) {
    button.addEventListener("click", async () => {
      const field = sheet.querySelector(`#${button.dataset.copy}`);
      const [words, mark] = COPIED[button.dataset.copy];
      const done = await copy(field.value);
      said.textContent = done ? words : "It did not copy just now: select it and copy it yourself";
      document.documentElement.dataset.shared = done ? mark : "failed";
      if (!done) field.select();
    });
  }
  app.addEventListener("click", async () => {
    try {
      await navigator.share({ title, url });
      document.documentElement.dataset.shared = "sheet";
      sheet.close();
    } catch (trouble) {
      // Closed without sharing: the sheet stays.
      if (trouble && trouble.name !== "AbortError") said.textContent = "That did not open just now: copy the link instead";
    }
  });
}

/// The action bar (api/share.js actionBar): Like; Save, which opens your
/// lists, Favourites first (docs/SOCIAL.md D2); Share, which opens its sheet
/// (shareSheet); Comment and I built it, which go to their sections; and
/// More: Report it, Takedown requests, and the owner's own. Like and Save
/// ask to sign in first when this browser is not.
function start() {
  const like = marks.querySelector('[data-mark="like"]');
  const save = marks.querySelector('[data-mark="save"]');
  const share = marks.querySelector("[data-share]");
  const comment = marks.querySelector('[data-mark="comment"]');
  const built = marks.querySelector('[data-mark="built"]');
  const panel = document.getElementById("save-panel");
  const lists = panel.querySelector(".collect-list");
  const make = panel.querySelector("form.collect-new");
  const said = document.querySelector(".marks-said");
  let state = null;

  const say = (text) => { said.textContent = text; };

  /// One of Save's lists: a box to tick, its name, and who sees it.
  function listRow(name, where, has, change, key) {
    const row = document.createElement("label");
    row.dataset.list = key;
    const box = document.createElement("input");
    box.type = "checkbox";
    box.checked = Boolean(has);
    // The lists are drawn again once it is kept: the same list's box keeps
    // the keyboard's focus.
    box.addEventListener("change", async () => {
      const focused = document.activeElement === box;
      await change(box);
      if (focused) [...lists.querySelectorAll("label[data-list]")].find((one) => one.dataset.list === key)?.querySelector("input")?.focus();
    });
    const words = document.createElement("span");
    words.textContent = String(name);
    const who = document.createElement("small");
    who.textContent = where;
    row.append(box, words, who);
    return row;
  }

  function draw() {
    like.setAttribute("aria-pressed", String(Boolean(state && state.liked)));
    const saved = Boolean(state && (state.favourite || (state.collections || []).some((list) => list.has)));
    save.toggleAttribute("data-on", saved);
    save.setAttribute("aria-label", saved ? "Saved" : "Save");
    lists.replaceChildren();
    if (!state) return;
    lists.append(listRow("Favourites", "only you", state.favourite, keep, "favourites"));
    for (const list of state.collections || []) {
      lists.append(listRow(list.name, list.public ? "public" : "only you", list.has, (box) => put(list, box), list.id));
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
    setCount(like, answer.body.likes, "Like", "like");
    say("");
    draw();
  });

  save.addEventListener("click", async () => {
    if (!(await ready("Sign in to save it: we email you a code, no password."))) return;
    panel.hidden = !panel.hidden;
    save.setAttribute("aria-expanded", String(!panel.hidden));
    if (!panel.hidden) lists.querySelector("input")?.focus();
  });
  // Escape closes your lists, back on Save, as a menu closes.
  panel.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || panel.hidden) return;
    event.preventDefault();
    panel.hidden = true;
    save.setAttribute("aria-expanded", "false");
    save.focus();
  });

  async function keep(box) {
    box.disabled = true;
    const answer = await call(`/api/people?op=favourite&id=${id}`, { method: "POST", body: { on: box.checked } });
    box.disabled = false;
    if (answer.status !== 200) {
      box.checked = !box.checked;
      return say(answer.body.error || "That did not work just now.");
    }
    state.favourite = answer.body.favourite;
    say(state.favourite ? "Saved to your favourites, on your account page." : "Out of your favourites.");
    draw();
  }

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
    say(box.checked ? `Saved to ${list.name}.` : `Out of ${list.name}.`);
    draw();
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

  const sheet = document.getElementById("share-sheet");
  if (sheet) shareSheet(share, sheet);

  // The box is everybody's: sending it signs a visitor in.
  comment.addEventListener("click", () => {
    const section = document.getElementById("comments");
    if (!section) return;
    section.scrollIntoView({ block: "start" });
    const box = document.getElementById("comment-body");
    if (box && !box.closest("form").hidden) box.focus({ preventScroll: true });
  });

  built.addEventListener("click", () => {
    document.getElementById("builds")?.scrollIntoView({ block: "start" });
    const add = document.querySelector("[data-add-build]");
    if (add && !add.hidden && !add.disabled) add.click();
    else document.querySelector('.build-form input[type="file"]')?.focus({ preventScroll: true });
  });

  load();
}

/// What the comments, once listed, change in the action bar: Comment's
/// count (the ones everybody sees), Comment gone where comments are not
/// open on this deployment, and for the model's owner their own in More:
/// comments off or on, and their models' numbers, in place of Report it.
function commentsSaid(state, setOpen) {
  const comment = marks && marks.querySelector('[data-mark="comment"]');
  if (!comment) return;
  comment.hidden = state.ready === false;
  // What everybody sees: not hidden, and not under a comment that is.
  const hidden = new Set((state.comments || []).filter((one) => one.hidden).map((one) => one.id));
  const shown = (state.comments || []).filter((one) => !one.hidden && !hidden.has(one.parent)).length;
  setCount(comment, shown, "Comment", "comment");
  const tab = document.querySelector('#page-tabs a[data-tab="comments"]');
  if (tab) {
    tab.hidden = state.ready === false;
    tabCount(tab, shown);
  }
  const menu = marks.querySelector("#more .menu-list");
  for (const old of menu.querySelectorAll(".owner-only")) old.remove();
  if (!state.you?.owner) return;
  menu.querySelector("[data-report]")?.setAttribute("hidden", "");
  const turn = document.createElement("button");
  turn.type = "button";
  turn.className = "owner-only";
  turn.textContent = state.open ? "Turn comments off" : "Turn comments on";
  turn.addEventListener("click", () => {
    marks.querySelector("#more").open = false;
    setOpen(!state.open);
  });
  const numbers = document.createElement("a");
  numbers.className = "owner-only";
  numbers.href = "/profile#designs";
  numbers.textContent = "How your models are doing";
  menu.prepend(turn, numbers);
  document.documentElement.dataset.modelOwner = "yes";
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
    (document.querySelector(".marks-said") || marks).after(box);
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
  title.id = "enter-title";
  dialog.setAttribute("aria-labelledby", title.id);
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
