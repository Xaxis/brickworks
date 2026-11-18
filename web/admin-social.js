// The console's Social (admin.html › Social, docs/SOCIAL_DESK.md): the
// owner's own accounts on the networks, read through /api/admin?op=social
// (api/_social.js). Four tabs: the Inbox (replies, mentions and messages,
// newest first), Write (a post or a reply, the community's rules beside the
// box, drafts), Sent and scheduled (each post's score, comments and the
// visits its links brought), and Accounts (Connect, Disconnect, what each
// network needs and costs).
//
// Nothing here sends by itself. A send is the owner's press of Send (or
// Schedule) in the sheet that shows the exact words kept on the server, and
// the press carries those words' hash: words changed since are refused.
// Without a connected account the press hands the words to the network's
// own page, where the owner presses Post.
//
// Everything is put on the page as text, never as markup: what came in was
// written by strangers.
import { $, TESTS, act, adminJson, ago, cell, count, day, emptyRow, link, make, say, segmented, sift, timeCell, when }
  from "/admin-kit.js";

let desk = null;
let onChange = () => {};
/// [then] after an act here that the Overview counts (unread, waiting).
export function whenChanged(then) { onChange = then; }
/// Claude's asks on a row (web/admin-claude.js): item(one, acts), draft(one, row).
export const extras = { item: null, draft: null };

// ---------------------------------------------------------------------------
// Coming back from a network's consent: the code and state taken from the
// address at once, so neither stays in the history, and finished once the
// console is open. In the checks' pool (?tests=1) the consent is the
// console's own stand-in, never the network's.

const asked = new URLSearchParams(location.search);
const back = asked.get("connected") ? { provider: asked.get("connected"), code: asked.get("code"), state: asked.get("state"),
  error: asked.get("error") } : null;
const consent = TESTS && asked.get("mock_authorize") === "reddit" ? Object.fromEntries(asked) : null;
if (back || consent) history.replaceState(null, "", `${location.pathname}${TESTS ? "?tests=1" : ""}#social/accounts`);

/// GET op=social: the section whole, drawn.
export async function loadSocial() {
  if (back && !loadSocial.finished) {
    loadSocial.finished = true;
    try {
      const done = await adminJson({ op: "social_connected" }, { method: "POST", body: back });
      say("networks-note", `Connected as u/${done.handle}. Its keys are kept on the server alone.`);
    } catch (problem) {
      say("networks-note", problem.message, true);
    }
  }
  desk = await adminJson({ op: "social" });
  draw();
  if (consent && !loadSocial.consented) {
    loadSocial.consented = true;
    mockConsent(consent);
  }
}

export async function reread() {
  desk = await adminJson({ op: "social" });
  draw();
  onChange();
}

const reddit = () => desk?.networks?.find((one) => one.id === "reddit") || null;
const KIND = { reply: "Reply", mention: "Mention", message: "Message" };
const DETAIL = { comment_reply: "to a comment", post_reply: "to a post", username_mention: "of the account", search: "found by search",
  message: "" };
const STATE = { draft: "Draft", scheduled: "Scheduled", sending: "Sending", handed: "Waiting on you at Reddit", sent: "Sent",
  failed: "Did not go" };
const stateOf = (one) => (one.unsure ? "Unsure: look on Reddit" : STATE[one.status] || one.status);
const where = (one) => (one.community ? `r/${one.community}` : one.kind === "reply" ? "a reply" : "—");
const excerpt = (words, most = 160) => (words.length > most ? `${words.slice(0, most - 1)}…` : words);

function draw() {
  const ready = desk.ready !== false;
  const not = $("social-not-yet");
  not.hidden = ready;
  not.textContent = ready ? "" : `${desk.said} Nothing can be kept here until it is applied.`;
  for (const control of $("social-form").elements) control.disabled = !ready;
  $("inbox-check").disabled = !ready;
  $("inbox-all-read").disabled = !ready;
  drawNetworks();
  drawInbox();
  drawDrafts();
  drawSends();
  drawProviders();
  fill();
  const unread = desk.items.filter((one) => !one.read).length;
  $("tab-social-unread").textContent = unread ? String(unread) : "";
  const waiting = desk.sends.filter((one) => one.hand_off).length;
  $("tab-social-due").textContent = waiting ? String(waiting) : "";
}

// ---------------------------------------------------------------------------
// Accounts.

function drawNetworks() {
  $("networks").replaceChildren(...desk.networks.map((one) => {
    const card = make("li", "card");
    if (one.later) {
      card.append(make("h3", "", one.name, make("span", "pill", "Not connected yet")),
        make("p", "note", one.needs), make("p", "note", `Cost: ${one.cost}`));
      return card;
    }
    const account = one.account;
    card.append(make("h3", "", one.name, account ? make("span", "pill good", `Connected as u/${account.handle}`)
      : make("span", "pill", "Not connected")));
    if (one.mock) card.append(make("p", "note", "The checks' own stand-in for Reddit: nothing here reaches the real one."));
    if (account) {
      card.append(make("p", "note", `Connected ${ago(account.connected_at)} by ${account.connected_by}. Last look `
        + `${ago(account.synced_at)}${account.sync_said ? `: ${account.sync_said}` : ""}. Posts go by Reddit's API when you press Send.`));
      card.append(make("div", "row",
        act("Check now", () => sync("networks-note")),
        act("Disconnect", async () => {
          if (!confirm(`Disconnect u/${account.handle}? Its keys are taken back at Reddit and forgotten here; what was sent and what came in are kept.`)) return false;
          try {
            const done = await adminJson({ op: "social_disconnect" }, { method: "POST", body: { provider: one.id } });
            say("networks-note", done.revoked ? "Disconnected: Reddit took its keys back, and they are forgotten here."
              : "Disconnected: its keys are forgotten here.");
            await reread();
            return true;
          } catch (problem) {
            say("networks-note", problem.message, true);
            return false;
          }
        }, "ghost")));
      return card;
    }
    if (!one.api) {
      card.append(make("p", "note", `This deployment has no Reddit app: ${one.missing.join(" and ")} ${one.missing.length === 1 ? "is" : "are"} `
        + "not set in Vercel. Reddit stopped taking new API apps on 31 October 2026 and ends the rest in March 2027, so "
        + "the desk posts by hand: Send opens Reddit's own page, you paste the words if it has not and press Post there, then paste "
        + "its address back here so the visits it brings are counted. Its score and comments are read only once Reddit is connected."),
      make("p", "note", "Should Reddit grant Brickworks access, docs/SOCIAL_DESK.md says what to set; Connect then works here."));
    } else card.append(make("p", "note", "Connect to read replies, mentions and messages here and post by Reddit's API. "
      + "You let the desk in on Reddit's own page; its keys stay on the server."));
    const go = act("Connect Reddit", async () => {
      try {
        const asked = await adminJson({ op: "social_connect" }, { method: "POST", body: { provider: one.id } });
        location.assign(asked.authorize);
        return true;
      } catch (problem) {
        say("networks-note", problem.message, true);
        return false;
      }
    }, "cta");
    go.disabled = !one.api;
    card.append(make("div", "row", go));
    return card;
  }));
}

/// The checks' stand-in for Reddit's consent page: Allow sends the console
/// back with a code, as Reddit would. Only an address of this console.
function mockConsent(given) {
  let home;
  try {
    home = new URL(given.redirect_uri);
  } catch {
    return say("networks-note", "That consent named no address to come back to.", true);
  }
  if (home.origin !== location.origin || home.pathname !== "/admin") return say("networks-note", "That consent was for another site.", true);
  const go = (words) => {
    home.searchParams.set("state", given.state || "");
    for (const [key, value] of Object.entries(words)) home.searchParams.set(key, value);
    location.assign(home.href);
  };
  const code = `mock-code-${Array.from(crypto.getRandomValues(new Uint8Array(12)), (n) => "abcdefghijklmnopqrstuvwxyz0123456789"[n % 36]).join("")}`;
  openSheet("Let the desk in? (stand-in)", [
    make("p", "note", "The checks' own stand-in for Reddit's consent page. On brickworks.diy this is Reddit's, at reddit.com."),
    facts([["App", given.client_id], ["Asks for", String(given.scope || "").split(" ").join(", ")], ["Kept", given.duration === "permanent"
      ? "until you disconnect" : "an hour"]]),
    make("div", "row", act("Allow", async () => { go({ code }); return true; }, "cta"),
      act("Decline", async () => { go({ error: "access_denied" }); return true; }, "ghost")),
  ]);
}

// ---------------------------------------------------------------------------
// The Inbox.

let inboxShow = "";
segmented($("inbox-kinds"), (value) => { inboxShow = value; siftInbox(); });
$("inbox-q").addEventListener("input", () => siftInbox());
const siftInbox = () => sift($("inbox"), $("inbox-q").value, (row) => !inboxShow || (inboxShow === "unread"
  ? row.dataset.read === "false" : row.dataset.kind === inboxShow));

function drawInbox() {
  const body = $("inbox");
  body.replaceChildren();
  if (!desk.items.length) {
    const account = reddit()?.account;
    emptyRow(body, desk.ready === false ? "Not open yet." : account ? `Nothing yet. Last look ${ago(account.synced_at)}; Check now looks again.`
      : reddit()?.api ? "Nothing yet. Connect Reddit under Accounts to read replies, mentions and messages here."
        : "Nothing comes in here until Reddit grants the desk API access (it took no new apps from 31 October 2026): "
          + "replies, mentions and messages reach you on Reddit itself, in its inbox.");
    return;
  }
  for (const one of desk.items) {
    const row = make("tr", one.read ? "" : "unread");
    row.dataset.kind = one.kind;
    row.dataset.read = String(one.read);
    timeCell(row, one.made_at);
    cell(row, make("span", "", KIND[one.kind] || one.kind, DETAIL[one.detail] ? make("small", "faint", ` ${DETAIL[one.detail]}`) : ""));
    cell(row, one.author ? `u/${one.author}` : "—", "who");
    cell(row, one.community ? `r/${one.community}` : one.kind === "message" ? "a message" : "—");
    const what = cell(row, "", "text");
    if (one.subject || one.thread) what.append(make("small", "", one.subject || one.thread));
    what.append(excerpt(one.body || "", 280));
    const acts = cell(row, "", "acts");
    if (one.url) {
      const open = link(one.url, "Open on Reddit", "cta ghost small");
      open.target = "_blank";
      open.rel = "noopener noreferrer";
      acts.append(open);
    }
    // A comment, a post or a message: each is answered where it is.
    if (/^t[134]_/.test(one.external_id)) {
      acts.append(act("Reply…", async () => { replyTo(one); return false; }, "cta ghost small"));
    }
    extras.item?.(one, acts);
    acts.append(act(one.read ? "Mark unread" : "Mark read", async () => {
      try {
        await adminJson({ op: "social_mark" }, { method: "POST", body: { provider: one.provider, external_id: one.external_id, read: !one.read } });
        await reread();
        return true;
      } catch (problem) {
        say("inbox-note", problem.message, true);
        return false;
      }
    }, "cta ghost small"));
    body.append(row);
  }
  labelCells(body);
  siftInbox();
}

async function sync(where) {
  try {
    const done = await adminJson({ op: "social_sync" }, { method: "POST", body: {} });
    const looked = done.looked?.[0];
    say(where, done.outcome === "nothing connected" ? "Nothing is connected: connect Reddit under Accounts."
      : `Looked: ${looked?.said || done.outcome}.`, Boolean(looked && !/^\d+ new/.test(looked.said || "")));
    await reread();
    return false;
  } catch (problem) {
    say(where, problem.message, true);
    return false;
  }
}
$("inbox-check").addEventListener("click", async () => {
  $("inbox-check").disabled = true;
  await sync("inbox-note");
  $("inbox-check").disabled = false;
});
$("inbox-all-read").addEventListener("click", async () => {
  try {
    await adminJson({ op: "social_mark" }, { method: "POST", body: { all: true } });
    say("inbox-note", "All marked read here. Nothing is marked at Reddit.");
    await reread();
  } catch (problem) {
    say("inbox-note", problem.message, true);
  }
});

// ---------------------------------------------------------------------------
// Write: one form for a post or a reply, kept as a draft on the server
// before anything is shown to be sent.

/// What the form holds: {id, kind, parent, item} of a draft, or a new post.
let editing = { id: null, kind: "post", parent: null, item: null };
const form = $("social-form");

function drawProviders() {
  const select = $("social-provider");
  const was = select.value || "reddit";
  select.replaceChildren(...desk.networks.map((one) => {
    const option = new Option(one.later ? `${one.name} (not connected yet)` : one.name, one.id);
    option.disabled = Boolean(one.later);
    return option;
  }));
  select.value = was;
}

function fill() {
  const post = editing.kind === "post";
  for (const id of ["social-community-l", "social-title-l", "social-link-l"]) $(id).hidden = !post;
  $("social-form-h").textContent = editing.id ? (post ? "A post, kept" : "A reply, kept") : post ? "A new post" : "A new reply";
  const replying = $("social-replying");
  replying.hidden = post;
  replying.replaceChildren();
  if (!post) {
    const item = editing.item || desk.items.find((one) => one.external_id === editing.parent);
    replying.append(`Replying to ${item?.author ? `u/${item.author}` : "it"}${item?.community ? ` in r/${item.community}` : ""}: `,
      make("q", "", excerpt(item?.body || item?.subject || "", 200)));
    if (item?.url) {
      const open = link(item.url, " Open it on Reddit");
      open.target = "_blank";
      open.rel = "noopener noreferrer";
      replying.append(open);
    }
  }
  counts();
}

function counts() {
  const most = reddit()?.most || { title: 300, body: 40000 };
  $("social-title-n").textContent = `${form.elements.title.value.length} / ${most.title}`;
  $("social-body-n").textContent = `${form.elements.body.value.length.toLocaleString()} / ${most.body.toLocaleString()}`;
}
form.elements.title.addEventListener("input", counts);
form.elements.body.addEventListener("input", counts);

function startNew() {
  editing = { id: null, kind: "post", parent: null, item: null };
  form.reset();
  form.elements.provider.value = "reddit";
  say("social-note", "");
  fill();
}
$("social-new").addEventListener("click", startNew);

export function open(send) {
  editing = { id: send.id, kind: send.kind, parent: send.parent, item: null };
  form.elements.provider.value = send.provider;
  form.elements.community.value = send.community ? `r/${send.community}` : "";
  form.elements.title.value = send.title;
  form.elements.link.value = send.link || "";
  form.elements.body.value = send.body;
  fill();
  location.hash = "#social/write";
  if (send.community) rules(send.community);
}

function replyTo(item) {
  editing = { id: null, kind: "reply", parent: item.external_id, item };
  form.reset();
  form.elements.provider.value = item.provider;
  say("social-note", "");
  fill();
  location.hash = "#social/write";
  if (item.community) rules(item.community);
  form.elements.body.focus();
}

/// The form kept as a draft: the send as the server holds it (its links to
/// the site tagged), put back in the form.
/// One keep at a time: Keep and Review are held while it runs, so two quick
/// presses make one draft, not two.
let keeping = null;
function keep() {
  if (!keeping) {
    const holds = [form.querySelector("button[type=submit]"), $("social-review")];
    for (const button of holds) button.disabled = true;
    keeping = (async () => {
      const e = form.elements;
      const body = { id: editing.id || undefined, provider: e.provider.value, kind: editing.kind, parent: editing.parent || undefined,
        community: e.community.value.trim(), title: e.title.value, body: e.body.value, link: e.link.value.trim() };
      const done = await adminJson({ op: "social_draft" }, { method: "POST", body });
      editing.id = done.send.id;
      e.body.value = done.send.body;
      e.link.value = done.send.link || "";
      fill();
      await reread();
      return { ...done.send, outcome: done.outcome };
    })().finally(() => {
      keeping = null;
      for (const button of holds) button.disabled = desk?.ready === false;
    });
  }
  return keeping;
}

/// What keeping it did, in words: a press undone by an edit is said.
const keptWords = (send) => (send.outcome === "unscheduled" ? "Kept, and no longer scheduled: an edit undoes Schedule. "
  + "Press Review and send to set it going again." : send.outcome === "redrafted" ? "Kept: a draft again, not handed to Reddit." : "Kept.");

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  try {
    const send = await keep();
    say("social-note", `${keptWords(send)}${/utm_campaign=/.test(`${send.body} ${send.link || ""}`)
      ? ` Links to brickworks.diy carry utm_campaign=${send.campaign}.` : ""}`);
  } catch (problem) {
    say("social-note", problem.message, true);
  }
});

$("social-review").addEventListener("click", async () => {
  try {
    const send = await keep();
    say("social-note", send.outcome === "kept" ? "" : keptWords(send));
    review(send);
  } catch (problem) {
    say("social-note", problem.message, true);
  }
});

// ---------------------------------------------------------------------------
// The press: the sheet that shows exactly what goes, where and how, with
// Send, or a day and a quarter-hour to Schedule. The hash is the server's,
// of these words; it is what the press carries.

const MINUTES = Array.from({ length: 96 }, (_, at) => at * 15);

function review(send) {
  const account = reddit()?.account;
  const api = Boolean(account && reddit()?.api);
  const target = send.kind === "post" ? `r/${send.community}` : "the item it answers";
  const said = make("p", "note");
  said.setAttribute("role", "status");
  const parts = [
    make("p", "", api ? `This goes to ${target} by Reddit's API, as u/${account.handle}, exactly as it is here.`
      : send.kind === "post" ? `Reddit's own page for ${target} opens next, with these words to copy. Nothing is posted until you `
        + "press Post there." : "The item opens on Reddit next, with these words to copy and paste as your reply there."),
    words(send),
  ];
  if (!api && send.kind === "post" && !send.hand_off_filled) {
    parts.push(make("p", "note", "These words are too long to go in Reddit's address, so its page opens with the title alone: "
      + "copy the words and paste them into its box."));
  }
  const now = act(api ? "Send now" : "Post it on Reddit…", async () => press(send, null, said), "cta");
  parts.push(make("div", "row", now));
  // A day (today and the next 60) and a quarter-hour, in this browser's time.
  const dayPick = make("select");
  dayPick.append(Object.assign(new Option("Day", "", true, true), { disabled: true, hidden: true }));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let at = 0; at <= 60; at += 1) {
    const d = new Date(today);
    d.setDate(today.getDate() + at);
    dayPick.append(new Option(at === 0 ? "Today" : at === 1 ? "Tomorrow" : d.toLocaleDateString(undefined, { weekday: "short", day: "numeric",
      month: "short" }), d.toISOString()));
  }
  const timePick = make("select");
  timePick.append(Object.assign(new Option("Time", "", true, true), { disabled: true, hidden: true }));
  for (const minutes of MINUTES) {
    const t = new Date(2000, 0, 1, Math.floor(minutes / 60), minutes % 60);
    timePick.append(new Option(t.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" }), String(minutes)));
  }
  const zone = Intl.DateTimeFormat().resolvedOptions().timeZone || "this computer's time";
  const later = act("Schedule", async () => {
    if (!dayPick.value || timePick.value === "") {
      say(said, "Choose a day and a time.", true);
      return false;
    }
    const at = new Date(dayPick.value);
    at.setMinutes(Number(timePick.value));
    return press(send, at.toISOString(), said);
  }, "ghost");
  const pickDay = make("label", "", make("span", "visually-hidden", "Day"), dayPick);
  const pickTime = make("label", "", make("span", "visually-hidden", "Time"), timePick);
  parts.push(make("div", "part", make("h3", "", "Or at a time"),
    make("p", "note", `In ${zone}. Looked for every quarter of an hour, so it goes within 15 minutes of then, and only as these words: `
      + `edit it and it is a draft again.${api ? "" : " With nothing connected, the console tells you when it is due and you post it on Reddit."}`),
    make("div", "when-pair", pickDay, pickTime, later)));
  parts.push(said);
  openSheet(send.kind === "post" ? "Send this post?" : "Send this reply?", parts, send.id);
}

function words(send) {
  const shown = make("div", "words");
  if (send.title) shown.append(make("b", "", send.title));
  if (send.link) shown.append(send.link, send.body ? "\n\n" : "");
  shown.append(send.body);
  return shown;
}

/// The owner's press on [send] (now, or at [at]): its hash, the server's, sent with it.
async function press(send, at, said) {
  try {
    const done = await adminJson({ op: "social_send" }, { method: "POST", body: { id: send.id, hash: send.hash, ...(at ? { at } : {}) } });
    // The form emptied for the next, before what became of this is said.
    startNew();
    if (done.outcome === "scheduled") {
      closeSheet();
      await reread();
      landed(send.id, `Scheduled for ${when(done.send.send_at)}.`);
      return true;
    } else if (done.outcome === "sent") {
      say("social-note", "Sent.");
      openSheet("Sent", [make("p", "", "It is on Reddit: "), done.url ? linkOut(done.url, done.url) : "—"], send.id);
    } else if (done.outcome === "handed") handOff({ ...done.send, hand_off: done.hand_off, hand_off_filled: done.hand_off_filled });
    await reread();
    return true;
  } catch (problem) {
    say(said, problem.message, true);
    await reread().catch(() => null);
    // A Send that did not go is not pressed again from this sheet: what
    // became of it is under Sent, which says whether it may be up. A time
    // refused is chosen again.
    return !at;
  }
}

/// A send handed to the owner: Reddit's page with its words, the words to
/// copy, and its address pasted back once it is posted.
function handOff(send) {
  const said = make("p", "note");
  said.setAttribute("role", "status");
  const address = addressBox();
  const copy = act("Copy the words", async () => {
    try {
      await navigator.clipboard.writeText([send.title, send.link, send.body].filter(Boolean).join("\n\n"));
      say(said, "Copied.");
    } catch {
      say(said, "This browser would not copy: select the words above.", true);
    }
    return false;
  }, "ghost");
  // A reply to a private message has no address of its own: its conversation's is kept.
  const message = send.kind === "reply" && /^t4_/.test(String(send.parent));
  const posted = postedButton(send, address, said, "It is posted");
  const page = send.kind === "post" ? (send.hand_off_filled
    ? "Copy the words first. Reddit's page may fill in the title and words; where a box is empty, paste them. "
    : "The words are too long for Reddit's address, so its page opens with the title alone: copy the words and paste them into its box. ")
    + "Press Post there: nothing is posted from here."
    : "Copy the words, open the item on Reddit, paste them as your reply and press Reply there: nothing is sent from here.";
  openSheet(send.kind === "post" ? "Post it on Reddit" : "Reply on Reddit", [
    make("p", "", page),
    words(send),
    make("div", "row", copy, send.hand_off ? linkOut(send.hand_off, send.kind === "post" ? "Open Reddit's page" : "Open it on Reddit", "cta")
      : make("span", "note", "Its item is no longer in the inbox: find it on Reddit.")),
    make("div", "part", make("h3", "", "Once it is up"), message
      ? make("p", "note", "A reply to a message has no address of its own: the conversation's is kept.")
      : make("label", "", `Paste the address of the ${send.kind} on Reddit`, address), make("div", "row", posted)),
    said,
  ], send.id);
}

/// "It is posted" (or found up): its address sent, the send marked sent.
function postedButton(send, address, said, words) {
  return act(words, async () => {
    try {
      await adminJson({ op: "social_posted" }, { method: "POST", body: { id: send.id, url: address.value.trim() } });
      closeSheet();
      await reread();
      landed(send.id, reddit()?.account ? "Kept: its score and the visits it brings are counted from now."
        : "Kept: the visits it brings are counted from now. Its score is read only once Reddit is connected.");
      return true;
    } catch (problem) {
      say(said, problem.message, true);
      return false;
    }
  }, "cta");
}

function addressBox() {
  const address = make("input");
  address.type = "url";
  address.inputMode = "url";
  address.placeholder = "https://www.reddit.com/r/…/comments/…";
  address.spellcheck = false;
  return address;
}

/// A send that may be up: look on Reddit, then paste its address, or take
/// it back to the drafts to press Send afresh. Never sent again from here.
function unsureSheet(send) {
  const said = make("p", "note");
  said.setAttribute("role", "status");
  const address = addressBox();
  const handle = reddit()?.account?.handle;
  const look = handle ? `https://www.reddit.com/user/${handle}/${send.kind === "post" ? "submitted" : "comments"}/`
    : send.community ? `https://www.reddit.com/r/${send.community}/new/` : "https://www.reddit.com/message/sent/";
  openSheet("Is it up on Reddit?", [
    make("p", "", "Reddit gave no clear answer when this went, so it may be up. It is not sent again from here: look first."),
    send.said ? make("p", "note", send.said) : "",
    words(send),
    make("div", "row", linkOut(look, handle ? `u/${handle}'s ${send.kind === "post" ? "posts" : "comments"} on Reddit`
      : `r/${send.community || "…"}'s newest`, "cta ghost")),
    make("div", "part", make("h3", "", "It is there"),
      make("label", "", `Paste the address of the ${send.kind} on Reddit`, address), make("div", "row", postedButton(send, address, said,
        "Keep its address"))),
    make("div", "part", make("h3", "", "It is not there"), make("p", "note", "Back to the drafts: it goes again only when you press Send."),
      make("div", "row", backButton(send, said, "Back to the drafts"))),
    said,
  ], send.id);
}

/// Back to the drafts, its press forgotten: a scheduled send, one handed
/// to you and not posted, or one that is unsure and not up.
const backButton = (send, where, words) => act(words, async () => {
  try {
    const done = await adminJson({ op: "social_unschedule" }, { method: "POST", body: { id: send.id } });
    if ($("social-sheet").open) closeSheet();
    await reread();
    landed(send.id, done.outcome === "unscheduled" ? "Unscheduled: back among the drafts, and it goes only when you press Send again."
      : "Back among the drafts: it goes only when you press Send again.");
    return true;
  } catch (problem) {
    say(where, problem.message, true);
    return false;
  }
}, "cta ghost small");

const linkOut = (href, words, className = "") => {
  const a = link(href, words, className);
  a.target = "_blank";
  a.rel = "noopener noreferrer";
  return a;
};

// ---------------------------------------------------------------------------
// A community's rules, beside the box, and the owner's notes on them.

let rulesOf = "";
$("social-rules-get").addEventListener("click", () => rules(form.elements.community.value));
form.elements.community.addEventListener("change", () => rules(form.elements.community.value));

async function rules(given) {
  const community = String(given || "").trim().replace(/^\/?r\//i, "");
  if (!/^[A-Za-z0-9_]{2,21}$/.test(community)) {
    say("social-rules-said", "A community's name is 2 to 21 letters, digits or _ (r/lego).", true);
    return;
  }
  rulesOf = community;
  say("social-rules-said", `Reading r/${community}'s rules…`);
  $("social-rules").replaceChildren();
  try {
    const got = await adminJson({ op: "social_rules", provider: form.elements.provider.value || "reddit", community });
    if (rulesOf !== community) return;
    $("h-social-rules").textContent = `r/${got.community}'s rules`;
    const about = got.about;
    const takes = { link: "links only", self: "text posts only", any: "links and text posts" };
    const line = about ? [about.members !== null ? `${count(about.members)} members` : "", takes[about.takes] || ""].filter(Boolean).join(" · ") : "";
    say("social-rules-said", got.from === "missing" ? `Reddit has no r/${community}, or it is private.`
      : got.from === "none" && !got.rules ? "With nothing connected the desk cannot read them: read them on Reddit, and keep your notes here."
        : `${line ? `${line}. ` : ""}Read ${ago(got.read_at)} from Reddit.`, got.from === "missing");
    $("social-rules").replaceChildren(...(got.rules || []).map((one) => make("li", "", make("b", "", one.title),
      make("span", "", `${one.applies === "both" ? "" : `On ${one.applies}. `}${one.words}`))));
    if (about?.submit_text) $("social-rules").append(make("li", "", make("b", "", "When you post"), make("span", "", about.submit_text)));
    $("social-rules-link").replaceChildren(linkOut(got.page, `r/${got.community}'s rules on Reddit`), " · ",
      linkOut("https://support.reddithelp.com/hc/en-us/articles/360043504051", "Reddit's own rules on promotion"));
    $("social-rules-notes").value = got.notes || "";
    say("social-notes-said", "");
  } catch (problem) {
    say("social-rules-said", problem.message, true);
  }
}

$("social-notes-keep").addEventListener("click", async () => {
  if (!rulesOf) return say("social-notes-said", "Read a community's rules first.", true);
  try {
    await adminJson({ op: "social_notes" }, { method: "POST", body: { provider: form.elements.provider.value || "reddit", community: rulesOf,
      notes: $("social-rules-notes").value } });
    say("social-notes-said", `Kept for r/${rulesOf}.`);
  } catch (problem) {
    say("social-notes-said", problem.message, true);
  }
});

// ---------------------------------------------------------------------------
// Drafts, and what was sent or waits to go.

function drawDrafts() {
  const body = $("drafts");
  body.replaceChildren();
  const drafts = desk.sends.filter((one) => one.status === "draft");
  if (!drafts.length) return emptyRow(body, "No drafts.");
  for (const one of drafts) {
    const row = make("tr");
    row.id = `draft-${one.id}`;
    timeCell(row, one.changed_at);
    cell(row, where(one));
    cell(row, excerpt(one.title || one.body || "(empty)"), "text");
    cell(row, "", "acts").append(act("Edit", async () => { open(one); return false; }, "cta ghost small"), drop(one, "social-note"));
    extras.draft?.(one, row);
    body.append(row);
  }
  labelCells(body);
}

const drop = (one, note) => act("Drop", async () => {
  if (!confirm(`Throw away this ${one.kind}? ${one.status === "handed" ? "It was handed to you and is not marked posted; "
    + "if you did post it on Reddit, it stays there." : "It was never sent."}`)) return false;
  try {
    await adminJson({ op: "social_drop" }, { method: "POST", body: { id: one.id } });
    if (editing.id === one.id) startNew();
    say(note, "Thrown away.");
    await reread();
    return true;
  } catch (problem) {
    say(note, problem.message, true);
    return false;
  }
}, "cta ghost small");

function drawSends() {
  const shown = desk.sends.filter((one) => one.status !== "draft");
  const sent = shown.filter((one) => one.status === "sent");
  const scheduled = shown.filter((one) => one.status === "scheduled");
  $("n-social-sent").textContent = count(sent.length);
  say("n-social-sent-said", sent.length ? `${sent.filter((one) => one.route === "api").length} by the API, `
    + `${sent.filter((one) => one.route === "by_hand").length} by hand` : "");
  $("n-social-waiting").textContent = count(scheduled.length);
  const next = scheduled.map((one) => one.send_at).sort()[0];
  say("n-social-waiting-said", next ? `next ${when(next)}` : "");
  const total = shown.reduce((sum, one) => sum + (one.visits?.total || 0), 0);
  $("n-social-visits").textContent = count(total);
  const week = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10);
  const recent = shown.reduce((sum, one) => sum + Object.entries(one.visits?.by_day || {}).filter(([d]) => d >= week)
    .reduce((s, [, n]) => s + n, 0), 0);
  say("n-social-visits-said", total ? `${count(recent)} in 7 days` : "counted by each post's utm_campaign");

  const older = $("sends-older");
  older.hidden = !desk.unlisted;
  say(older, desk.unlisted ? `${count(desk.unlisted)} older ${desk.unlisted === 1 ? "one is" : "ones are"} kept and not listed: `
    + "here are the newest 300 and every one still to go." : "");
  const body = $("sends");
  body.replaceChildren();
  if (!shown.length) return emptyRow(body, "Nothing sent or scheduled yet. Write a post under Write.");
  for (const one of shown) {
    const row = make("tr");
    row.id = `send-${one.id}`;
    timeCell(row, one.sent_at || one.send_at || one.changed_at);
    const due = one.status === "scheduled" && one.route === "by_hand" && Date.parse(one.send_at) <= Date.now();
    const state = make("span", one.status === "sent" ? "pill good" : one.status === "failed" || one.unsure ? "pill" : "pill new",
      due ? "Due: post it on Reddit" : one.status === "scheduled" ? `Scheduled, ${one.route === "api" ? "by the API" : "by hand"}`
        : stateOf(one));
    cell(row, make("span", "", state, (one.status === "failed" || one.unsure) && one.said ? make("small", "faint", ` ${one.said}`) : ""));
    cell(row, where(one));
    const what = cell(row, "", "text");
    what.append(one.url ? linkOut(one.url, excerpt(one.title || one.body)) : excerpt(one.title || one.body));
    const last = one.results.at(-1);
    cell(row, last?.score ?? "—", "n").dataset.value = String(last?.score ?? -1);
    cell(row, last?.comments ?? "—", "n");
    cell(row, count(one.visits?.total || 0), "n");
    const acts = cell(row, "", "acts");
    if (one.hand_off) acts.append(act(due || one.status === "handed" ? "Post it on Reddit…" : "Open on Reddit…", async () => {
      if (one.status === "handed") handOff(one);
      else review(one);
      return false;
    }, "cta small"));
    acts.append(act("Details", async () => { details(one); return false; }, "cta ghost small"));
    if (one.unsure) acts.append(act("Is it up?…", async () => { unsureSheet(one); return false; }, "cta small"));
    if (one.status === "scheduled") acts.append(backButton(one, "sends-note", "Unschedule"));
    if (one.status === "handed") acts.append(backButton(one, "sends-note", "Back to drafts"), drop(one, "sends-note"));
    if (one.status === "failed") acts.append(act("Look again", async () => { open(one); return false; }, "cta ghost small"), drop(one, "sends-note"));
    body.append(row);
  }
  labelCells(body);
}

/// Each cell named by its column, for the rows drawn as cards on a phone
/// (admin.html's table.cards below 600 px).
function labelCells(body) {
  const heads = [...(body.closest("table")?.tHead?.rows[0]?.cells || [])].map((th) => th.textContent.trim());
  for (const row of body.rows) [...row.cells].forEach((td, at) => { if (heads[at] && td.colSpan === 1) td.dataset.label = heads[at]; });
}

function details(one) {
  const parts = [words(one), facts([
    ["State", stateOf(one)],
    ["Where", where(one)],
    ["Pressed", one.pressed_at ? `${when(one.pressed_at)} by ${one.pressed_by}` : "—"],
    ["Went", one.route === "api" ? "by Reddit's API" : one.route === "by_hand" ? "by hand, posted by you on Reddit" : "—"],
    ["Scheduled for", one.send_at ? when(one.send_at) : null],
    ["Sent", one.sent_at ? when(one.sent_at) : null],
    ["Address", one.url ? linkOut(one.url, one.url) : null],
    ["Its tag", `utm_campaign=${one.campaign}`],
    ["Said", one.said],
  ])];
  if (one.results.length) {
    const table = make("table", "", make("caption", "visually-hidden", "Its score over time"),
      make("thead", "", make("tr", "", ...["When", "Score", "Comments", "Upvoted"].map((h) => {
      const th = make("th", "", h);
      th.scope = "col";
      return th;
    }))));
    const rows = make("tbody");
    for (const point of one.results.slice(-48).reverse()) {
      const row = make("tr");
      cell(row, when(point.at));
      cell(row, point.score ?? "—", "n");
      cell(row, point.comments ?? "—", "n");
      cell(row, point.ratio === null || point.ratio === undefined ? "—" : `${Math.round(point.ratio * 100)}%`, "n");
      rows.append(row);
    }
    table.append(rows);
    const region = make("div", "table", table);
    region.tabIndex = 0;
    region.setAttribute("role", "region");
    region.setAttribute("aria-label", "Its score over time");
    parts.push(make("div", "part", make("h3", "", "Over time"), make("p", "note", "As Reddit says it, read every quarter of an hour."), region));
  }
  const days = Object.entries(one.visits?.by_day || {}).sort(([a], [b]) => (a < b ? 1 : -1));
  parts.push(make("div", "part", make("h3", "", `Visits it brought: ${count(one.visits?.total || 0)}`),
    days.length ? make("ul", "points", ...days.map(([d, n]) => make("li", "", `${day(`${d}T12:00:00Z`)}: ${count(n)}`)))
      : make("p", "note", one.status === "sent" ? "None yet: each landing on brickworks.diy by its link is counted once."
        : "Counted once it is sent.")));
  openSheet(one.title || (one.kind === "reply" ? "A reply" : "A post"), parts, one.id);
}

function facts(pairs) {
  const list = make("dl", "facts");
  for (const [term, value] of pairs) {
    if (value === null || value === undefined || value === "") continue;
    list.append(make("dt", "", term), make("dd", "", value));
  }
  return list;
}

// ---------------------------------------------------------------------------
// The desk's own sheet (dialog.sheet, site.css), over the tab it came from.

function openSheet(title, body, id = "") {
  const sheet = $("social-sheet");
  const heading = $("social-sheet-title");
  heading.textContent = title;
  $("social-sheet-body").replaceChildren(...[body].flat());
  sheet.dataset.send = id;
  if (!sheet.open) sheet.showModal();
  // A sheet that becomes the next (Review, then Post it on Reddit): the
  // control pressed went with the old one, so its name is what is read
  // next, and Tab goes on from there. Opened afresh, it starts at Close.
  else if (!sheet.contains(document.activeElement)) {
    heading.tabIndex = -1;
    heading.focus();
  }
}

/// Once an act from a row or a sheet has moved a send and the lists are
/// drawn again, focus lands on what is there, never on the page: the send's
/// row in the tab shown, else that tab's own place (Write's Review, or the
/// list), and what became of it is said in that tab's line.
function landed(id, words) {
  const tab = [...document.querySelectorAll('[data-section="social"] [data-tab]')].find((one) => !one.hidden)?.dataset.tab;
  say(tab === "write" ? "social-note" : "sends-note", words);
  const row = [$(`send-${id}`), $(`draft-${id}`)].find((one) => one && !one.closest("[data-tab]").hidden);
  (row?.querySelector("a, button") || (tab === "write" ? $("social-review") : $("sends").closest(".table")))?.focus();
}
function closeSheet() { $("social-sheet").close(); }
$("social-sheet").addEventListener("close", () => $("social-sheet-title").removeAttribute("tabindex"));
$("social-sheet-close").addEventListener("click", closeSheet);
$("social-sheet").addEventListener("click", (event) => { if (event.target === $("social-sheet")) closeSheet(); });
