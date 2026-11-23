// One way to say something, the same wherever it is said (feedinline,
// 2026-11-23): a comment under a model, a reply in a thread of Talk, in a
// card of the home's feed, in a row of Talk's lists, on a model's page and
// on a thread's page. The owner: replying only by going to another page
// was "shitty ... incoherent and non consistent".
//
// The composer is a box and Post, with the guidelines and the keys under
// it; and the same everywhere:
// - Enter is a new line, never a post; Ctrl+Enter (Cmd+Enter on a Mac)
//   posts, and so does Post; Escape closes a composer that opened in place,
//   the focus back on what opened it.
// - Signed out, Post asks to sign in in the house's dialog (web/account.js
//   askToSignIn), and once in, posts what was typed, from where it was:
//   no page left, no word lost. Whether they may then (13 and over, not
//   barred, the comments on) is the server's, said in its own words.
// - A press posts once: a second while it goes sends nothing more.
// - What was posted shows at once where it will be (pending), then as the
//   server has it; refused, it goes and its words are back in the box.
// - Its line says, for a screen reader too, what happened (role=status).
//
// In a card or a row (commentsInCard, replyInCard), what was said shows as
// lines of web/home-feed.js saidLineHtml: the newest two comments of a
// model, with "n more" opening the rest in place; a thread's latest reply,
// a reply posted here under it. Every word anybody typed goes in as text.
import { askToSignIn, call, signedIn } from "/account.js";
import { counted, escapeHtml, langAt, number, say, told } from "/card.js";
import { saidLineHtml } from "/home-feed.js";

const MAC = /Mac|iPhone|iPad/.test(globalThis.navigator?.platform || globalThis.navigator?.userAgent || "");
/// The keys that post, as a person reads them.
export const KEYS = MAC ? "⌘ Enter" : "Ctrl Enter";

/// Characters as the servers count them: one outside the BMP is one.
const length = (text) => [...String(text || "")].length;

/// The line under a composer: the guidelines and the keys that post.
function footHtml(id) {
  return `<p class="composer-foot" id="${escapeHtml(id)}-foot"><a href="${langAt()}/guidelines">${escapeHtml(say("Community guidelines"))}</a>`
    + `<span class="composer-keys">${escapeHtml(say("{keys} posts", { keys: KEYS }))}</span>`
    + `<span class="composer-count" aria-live="polite"></span></p>`;
}

/// A new composer: [id] its box's, [label] what the box is (read by a
/// screen reader), [placeholder] in it. Cancel closes it ([close], wired
/// by wireComposer). Not yet in the page.
export function makeComposer({ id, label, placeholder = "", post = say("Post") }) {
  const form = document.createElement("form");
  form.className = "composer";
  form.innerHTML = `<label class="visually-hidden" for="${escapeHtml(id)}">${escapeHtml(label)}</label>`
    + `<textarea id="${escapeHtml(id)}" rows="2" placeholder="${escapeHtml(placeholder)}" aria-describedby="${escapeHtml(id)}-foot"`
    + ` aria-keyshortcuts="${MAC ? "Meta+Enter" : "Control+Enter"}"></textarea>`
    + `${footHtml(id)}<div class="composer-go"><p class="said composer-said" role="status"></p>`
    + `<button type="button" class="cta ghost small" data-composer-cancel>${escapeHtml(say("Cancel"))}</button>`
    + `<button type="submit" class="cta small">${escapeHtml(post)}</button></div>`;
  return form;
}

/// [form] made a composer, a new one (makeComposer) or a page's own:
///   field    its box (its textarea)
///   button   its Post
///   said     its line, for what happened
///   most     the most characters it takes; [over](n) says why more cannot go
///   count    whether the foot counts what is left near the end
///   signIn   the words the sign-in dialog opens with
///   ready()  once signed in from here: "" when they may post, else why not
///   send(text)    posts it: {ok, made} or {ok: false, error}
///   pending(text) what shows at once where it will be, or null
///   posted(made, shown)  the server's, in [shown]'s place
///   failed(shown)        refused: [shown] taken back
///   close()  Escape and Cancel; none, and the composer stays
///   done(made)  after posted, what the page does next (says Posted. when none)
export function wireComposer(form, {
  field = form.querySelector("textarea"), button = form.querySelector('button[type="submit"]'),
  said = form.querySelector(".composer-said, [data-said]"), most = 1000, over = null, count = true, signIn = "",
  ready = null, send, pending = null, posted = null, failed = null, close = null, done = null,
} = {}) {
  form.classList.add("composer");
  if (!form.querySelector(".composer-foot")) {
    const made = document.createElement("template");
    made.innerHTML = footHtml(field.id || "composer");
    field.after(made.content.firstElementChild);
    if (field.id) field.setAttribute("aria-describedby", `${field.id}-foot`);
    field.setAttribute("aria-keyshortcuts", MAC ? "Meta+Enter" : "Control+Enter");
  }
  const left = form.querySelector(".composer-count");
  const tell = (words) => {
    if (said) said.textContent = words;
  };
  const overSaid = (n) => (over ? over(n) : say("A comment is 1 to 1,000 characters of plain text."));
  // No maxlength: a paste over it would be cut without a word. What is
  // left shows near the end, and over it the reason Post waits.
  const measure = () => {
    if (!count || !left) return;
    const n = length(field.value);
    left.textContent = n > most ? overSaid(n) : n > most - 100 ? say("{n} characters left", { n: number(most - n) }) : "";
    left.classList.toggle("bad", n > most);
  };
  field.removeAttribute("maxlength");
  field.addEventListener("input", measure);
  field.addEventListener("keydown", (event) => {
    if (event.isComposing) return;
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      event.preventDefault();
      form.requestSubmit(button);
    } else if (event.key === "Escape" && close) {
      event.preventDefault();
      close();
    }
  });
  form.querySelector("[data-composer-cancel]")?.addEventListener("click", () => close?.());
  if (!close) form.querySelector("[data-composer-cancel]")?.remove();
  let sending = false;
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    // One post a press: a second press, or Ctrl+Enter, while the first
    // waits on the sign-in or the answer, sends nothing more.
    if (sending) return;
    if (!length(field.value.trim())) {
      tell(say("Say something first."));
      field.focus();
      return;
    }
    if (length(field.value) > most) {
      tell(overSaid(length(field.value)));
      field.focus();
      return;
    }
    sending = true;
    button.disabled = true;
    let shown = null;
    let sent = "";
    try {
      if (!signedIn()) {
        tell("");
        if (!(await askToSignIn(signIn, { back: () => field }))) {
          tell(say("Not posted: your words are still here."));
          return;
        }
        const why = ready ? await ready() : "";
        if (why) {
          tell(why);
          return;
        }
      }
      sent = field.value.trim();
      shown = pending ? pending(sent) : null;
      // What went leaves the box at once; it is put back if it is refused.
      field.value = "";
      measure();
      tell(say("Posting…"));
      const answer = await send(sent).catch(() => ({ ok: false, error: "" }));
      if (!answer.ok) {
        failed?.(shown);
        shown = null;
        if (!field.value.trim()) field.value = sent;
        measure();
        tell(answer.error || say("That did not go just now. Try again in a minute."));
        field.focus();
        return;
      }
      posted?.(answer.made, shown);
      if (done) done(answer.made);
      else tell(say("Posted."));
    } finally {
      sending = false;
      button.disabled = false;
    }
  });
  measure();
  return { field, tell };
}

// ---------------------------------------------------------------------------
// In a card, or a row.

/// [lines] (an ol of said lines) with [html] put in at its end, and its
/// "none yet" line gone; the new line, or null.
function addLine(lines, html, { first = false } = {}) {
  const made = document.createElement("template");
  made.innerHTML = html;
  const line = made.content.firstElementChild;
  if (!line) return null;
  if (first) lines.prepend(line);
  else lines.append(line);
  lines.hidden = false;
  lines.parentElement?.querySelector(".said-none")?.remove();
  return line;
}

/// Who is signed in here, as a pending line names them.
const YOU = () => ({ name: say("You") });

/// The room a card or a row says things in, made where it has none:
/// {room, lines}.
function roomIn(place, { label, before = null }) {
  let room = place.querySelector(".said-room");
  if (!room) {
    room = document.createElement("div");
    room.className = "said-room";
    if (before) before.before(room);
    else place.append(room);
  }
  let lines = room.querySelector(".said-lines");
  if (!lines) {
    lines = document.createElement("ol");
    lines.className = "said-lines";
    lines.setAttribute("aria-label", label);
    room.prepend(lines);
  }
  return { room, lines };
}

/// The comments on model [id] in its card of the feed ([post]): its newest
/// two there, "n more" opening the rest in place, and the composer under
/// them (opened by Add a comment or the comment button). [tests] the
/// checks' pool. Pressed again while open, its box has the focus.
export async function commentsInCard(post, id, { opener = null, all = false, tests = "" } = {}) {
  const talk = post.querySelector(".post-talk");
  if (!talk) return;
  const state = talk.__said ||= { form: null, answer: null, loading: null };
  const toggles = [...post.querySelectorAll(`[data-say="${id}"]`)];
  const more = talk.querySelector("[data-more]");
  const { room, lines } = roomIn(talk, { label: say("Comments"), before: talk.querySelector(".said-acts") });
  const load = async () => {
    const path = `/api/people?op=comments&id=${id}${tests}`;
    let answer = null;
    try {
      if (signedIn()) {
        const got = await call(path);
        answer = got.status === 200 ? got.body : null;
      } else {
        const got = await fetch(path, { headers: { accept: "application/json" } });
        answer = got.ok ? await got.json() : null;
      }
    } catch {
      answer = null;
    }
    state.answer = answer;
    return answer;
  };
  /// Its comments as the server has them, drawn in the card: the newest
  /// two, or all of them (each thread oldest first, its replies under it)
  /// once "n more" is pressed.
  const draw = (answer, { every = talk.classList.contains("every") } = {}) => {
    const shown = (Array.isArray(answer?.comments) ? answer.comments : []).filter((one) => one && !one.hidden);
    const order = (a, b) => (Date.parse(a.at) - Date.parse(b.at)) || (a.id - b.id);
    const threads = shown.filter((one) => !one.parent).sort(order);
    const under = new Map();
    for (const one of shown) if (one.parent) under.set(one.parent, [...(under.get(one.parent) || []), one]);
    const flat = threads.flatMap((one) => [one, ...(under.get(one.id) || []).sort(order)]);
    const line = (one) => saidLineHtml({ by: one.handle ? { handle: one.handle, name: one.by || one.handle, picture: one.picture || "" } : null,
      name: one.by, said: one.body, id: one.id }, { reply: Boolean(one.parent) });
    const drawn = every ? flat : threads.slice(-2);
    lines.innerHTML = drawn.map(line).join("");
    lines.hidden = drawn.length === 0;
    room.querySelector(".said-none")?.remove();
    if (!drawn.length) {
      const none = document.createElement("p");
      none.className = "said-none";
      none.textContent = say("Nothing said yet. Say the first thing.");
      room.append(none);
    }
    const rest = flat.length - drawn.length;
    if (more) {
      more.hidden = !every && rest <= 0;
      more.textContent = every ? say("Show fewer") : say("{n} more", { n: number(rest) });
      more.setAttribute("aria-expanded", String(every));
    }
    if (every) lines.scrollTop = lines.scrollHeight;
  };
  if (all) {
    // "n more" (or "Show fewer"): the rest opened in place, or closed again.
    const every = !talk.classList.contains("every");
    talk.classList.toggle("every", every);
    if (!state.answer) await (state.loading ||= load());
    draw(state.answer, { every });
    if (every) lines.querySelector("li:last-child")?.setAttribute("tabindex", "-1");
    return;
  }
  if (state.form) {
    state.form.hidden = false;
    talk.classList.add("open");
    for (const one of toggles) one.setAttribute("aria-expanded", "true");
    state.form.querySelector("textarea").focus();
    return;
  }
  const back = opener || toggles[0];
  const form = makeComposer({ id: `say-${id}`, label: say("Your comment"), placeholder: say("Say what you think of it") });
  state.form = form;
  talk.append(form);
  talk.classList.add("open");
  for (const one of toggles) one.setAttribute("aria-expanded", "true");
  const close = () => {
    form.hidden = true;
    talk.classList.remove("open");
    for (const one of toggles) one.setAttribute("aria-expanded", "false");
    back?.focus();
  };
  // What they may do, as the server says once it is asked: refused (under
  // 13, barred, comments off), the box is not offered, and why is said.
  const mayNot = (answer) => {
    if (!answer) return say("The comments did not load just now.");
    if (answer.open === false) return say("Comments are off for this model.");
    if (answer.you?.signed_in && !answer.you.may_write) return told(answer.you.why_not, say("That did not go just now. Try again in a minute."));
    return "";
  };
  const { field, tell } = wireComposer(form, {
    signIn: "Sign in to add your comment: we email you a code, no password. What you wrote is kept.",
    close,
    ready: async () => mayNot(await load()),
    send: async (text) => {
      if (!state.answer) await load();
      const version = Number(state.answer?.version) || null;
      const answer = await call(`/api/people?op=comment${tests}`, { method: "POST", body: { model: id, version, step: null, body: text } })
        .catch(() => ({ status: 0, body: {} }));
      return answer.status === 201 ? { ok: true, made: answer.body.comment } : { ok: false, error: told(answer.body?.error) };
    },
    pending: (text) => {
      const line = addLine(lines, saidLineHtml({ name: YOU().name, said: text }, { pending: true }));
      if (!talk.classList.contains("every")) while (lines.children.length > 2) lines.firstElementChild.remove();
      return line;
    },
    posted: (made, shown) => {
      if (made && Array.isArray(state.answer?.comments)) {
        // Drawn again as the server has it: the newest two, theirs last.
        state.answer.comments.push(made);
        draw(state.answer);
      } else if (shown) {
        shown.outerHTML = saidLineHtml({ by: made?.handle ? { handle: made.handle, name: made.by || made.handle } : null,
          name: made?.by || YOU().name, said: made?.body || shown.querySelector("p span")?.textContent || "", id: made?.id });
      }
      // Its count, one more, on the card's comment button.
      const button = post.querySelector(".post-acts [data-say]");
      const n = button?.querySelector(".n");
      const now = (Number(n?.textContent.replace(/\D/g, "")) || 0) + 1;
      if (button) {
        if (n) n.textContent = number(now);
        else button.insertAdjacentHTML("beforeend", `<span class="n" aria-hidden="true">${escapeHtml(number(now))}</span>`);
        const name = post.querySelector(".post-title a")?.textContent || "";
        button.setAttribute("aria-label", `${say("Comments on {name}", { name })}, ${counted(now, "comment")}`);
      }
    },
    failed: (shown) => shown?.remove(),
    done: () => tell(say("Posted: your comment is under it.")),
  });
  field.focus();
  // Signed in, what they may do is asked now; signed out, once they post.
  state.loading ||= load();
  const answer = await state.loading;
  draw(answer);
  const why = signedIn() || answer?.open === false ? mayNot(answer) : "";
  if (why) {
    field.hidden = true;
    form.querySelector('button[type="submit"]').hidden = true;
    form.querySelector(".composer-foot").hidden = true;
    tell(why);
  }
}

/// A reply to thread [thread] of Talk from [card] (a post of the feed, a
/// row of Talk's lists): the composer opened in it, the reply shown under
/// its latest reply once posted, its count one more. [tests] the checks'
/// pool, [lang] the page's language for what the server draws.
export async function replyInCard(card, thread, { opener = null, tests = "", lang = "", after = null } = {}) {
  if (!Number.isSafeInteger(thread) || thread < 1) return;
  const state = card.__reply ||= { form: null, you: null };
  const back = opener;
  if (state.form) {
    state.form.hidden = false;
    opener?.setAttribute("aria-expanded", "true");
    state.form.querySelector("textarea")?.focus();
    return;
  }
  // A post of the feed has its latest reply's room over its acts; a row of
  // a list has none, so one is made under its line of who and when.
  const words = card.querySelector(".post-words, .talk-row-main") || card;
  const acts = words.querySelector(".post-acts");
  const meta = words.querySelector(".talk-row-meta");
  if (!words.querySelector(".said-room")) {
    const room = document.createElement("div");
    room.className = "said-room";
    (meta || acts || words.lastElementChild).after(room);
  }
  const { room, lines } = roomIn(words, { label: say("Replies") });
  const form = makeComposer({ id: `reply-${thread}`, label: say("Your reply"),
    placeholder: say("Reply to {name}", { name: card.querySelector(".post-head .who, .talk-row-meta a:not([data-reply-thread])")?.textContent.trim() || say("them") }) });
  state.form = form;
  (after || acts || room).after(form);
  opener?.setAttribute("aria-expanded", "true");
  const close = () => {
    form.hidden = true;
    opener?.setAttribute("aria-expanded", "false");
    back?.focus();
  };
  const query = `${lang ? `&lang=${lang}` : ""}${tests}`;
  const load = async () => {
    const got = await call(`/api/people?op=talk_thread&id=${thread}${query}`).catch(() => null);
    state.you = got?.status === 200 ? { ...got.body.you, locked: got.body.thread?.locked === true } : null;
    return state.you;
  };
  const mayNot = (you) => (!you ? say("That did not go just now. Try again in a minute.")
    : you.locked ? say("This thread is locked: it takes no new posts.")
    : !you.may_write ? told(you.why_not, say("That did not go just now. Try again in a minute.")) : "");
  const { field, tell } = wireComposer(form, {
    most: 4000,
    over: (n) => say("A post is at most 4,000 characters; that is {n}.", { n: number(n) }),
    signIn: "Sign in to reply: we email you a code, no password. Anyone can read Talk.",
    close,
    ready: async () => mayNot(await load()),
    send: async (text) => {
      const answer = await call(`/api/people?op=talk_reply${query}`, { method: "POST", body: { thread, body: text } })
        .catch(() => ({ status: 0, body: {} }));
      return answer.status === 201 ? { ok: true, made: answer.body } : { ok: false, error: told(answer.body?.error) };
    },
    pending: (text) => addLine(lines, saidLineHtml({ name: YOU().name, said: text }, { pending: true })),
    posted: (made, shown) => {
      const post = made?.post || {};
      const fresh = saidLineHtml({ by: post.handle ? { handle: post.handle, name: post.by || post.handle, picture: post.picture || "" } : null,
        name: post.by || YOU().name, said: post.body || shown?.querySelector("p span")?.textContent || "", id: post.id });
      if (shown && fresh) shown.outerHTML = fresh;
      // Its count, one more, where the card says it.
      const tally = card.querySelector("[data-replies]");
      if (tally) {
        const now = (Number(tally.dataset.replies) || 0) + 1;
        tally.dataset.replies = String(now);
        const said = tally.querySelector("span") || tally;
        said.textContent = now === 1 ? say("1 reply") : say("{n} replies", { n: number(now) });
      }
    },
    failed: (shown) => shown?.remove(),
    done: (made) => tell(made?.mentions?.length
      ? say("Posted. {names} will hear of it.", { names: made.mentions.map((one) => `@${one.handle}`).join(", ") })
      : say("Posted: your reply is in the thread.")),
  });
  field.focus();
  if (signedIn()) {
    const why = mayNot(await load());
    if (why) {
      field.hidden = true;
      form.querySelector('button[type="submit"]').hidden = true;
      form.querySelector(".composer-foot").hidden = true;
      tell(why);
    }
  }
}
