// Your settings, /settings (settings.html): the beta while it is open (join
// its testers in one press, or leave in one: api/_beta.js; and whether its
// bar is shown on every page, signed out too: web/betabar.js), the theme, this
// device's notifications (web/push.js, api/_push.js), each kind of
// notification here, by push and by email, and the models you muted
// (supabase/notification_prefs.sql; inbox, 2026-11-23), what Brickworks
// emails you, orangecheck linked or not (api/orangecheck.js), your age
// answer, whom your profile shows you follow and whether it shows the
// models you liked (supabase/avatars.sql), the AI apps that may work
// in your tabs, your feedback with where each report stands and our answers
// (api/_feedback.js), whom you blocked with Unblock beside each
// (web/block.js, supabase/block.sql), signing out and deleting the account. Your profile itself (name, handle, words, links, pins) is
// changed on /profile, with Edit profile (docs/SOCIAL.md U6, D9).
//
// Signed in with the app's own sign-in in this browser (account.js). Every
// word goes on the page as text, never as markup. Each part asks for its
// own and draws what came, so one that cannot be read leaves the others.
import {
  age, askAgeIfAsked, askToSignIn, betaOpen, call, codeLength, email, madeUp, orangecheckButton, redeem, sendCode, signOut,
  signedIn, WAY_NAMES, wayLink, wayLinkTo, wayMark,
} from "/account.js";
import { langAt, say, told } from "/card.js";
import { codeBoxes } from "/code-boxes.js";
import { showFeedCount } from "/follow.js";
import { ask, avatarHtml } from "/kit.js";
import { blockPerson } from "/block.js";
import * as device from "/push.js";

const $ = (id) => document.getElementById(id);
// The codes emailed from here, a box per digit (web/code-boxes.js, signinux
// 2026-11-13): the one confirming Link or Unlink orangecheck goes by its
// last digit; deleting the account never goes by itself.
const ocCode = codeBoxes({ field: $("oc-code-field"), say, onFilled: () => $("oc-code").requestSubmit() });
const deleteCode = codeBoxes({ field: $("delete-code"), say });
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
// A date as the page's language writes one: "30 October 2026".
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric" });
const when = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

/// [said], a sentence in the page's language (web/card.js say), into
/// [into]: each {name} in it [parts]'s element or words.
function sayInto(into, said, parts) {
  for (const piece of said.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && name in parts ? parts[name] : piece);
  }
  return into;
}

const KINDS = { bug: () => say("Something wrong"), idea: () => say("An idea"), question: () => say("A question") };
const STANDS = { new: () => say("Received"), seen: () => say("Read"), planned: () => say("Planned"), fixed: () => say("Fixed"),
  wont_fix: () => say("Not planned") };

/// Your feedback: each report, newest first, with where it stands and our
/// answers (GET /api/plans?op=feedback). Not open here, it says so.
async function feedback() {
  const answer = await call("/api/plans?op=feedback");
  const list = $("reports");
  if (answer.status !== 200) {
    $("feedback-said").textContent = answer.status === 503 ? say("Feedback is not open here yet.")
      : say("Your reports did not load just now.");
    return;
  }
  const reports = Array.isArray(answer.body.reports) ? answer.body.reports : [];
  $("feedback-said").textContent = !reports.length
    ? say("Nothing sent yet. Something wrong, an idea or a question: we read every one ourselves.")
    : answer.body.beta ? say("What you sent us, where each stands, and our answers. As a beta tester, yours are marked as a tester's.")
      : say("What you sent us, where each stands, and our answers.");
  list.replaceChildren(...reports.map((one) => {
    const item = make("li", "report");
    item.dataset.report = String(one.id);
    item.dataset.status = one.status;
    // Its number, as the thank-you said it (bugreport): "#123".
    item.id = `report-${one.id}`;
    const marks = make("p", "marks", make("strong", "number", `#${one.id}`),
      make("span", "pill", KINDS[one.kind] ? KINDS[one.kind]() : say("A report")),
      make("span", `pill${one.status === "fixed" ? " good" : one.status === "new" ? "" : " new"}`,
        STANDS[one.status] ? STANDS[one.status]() : one.status),
      one.beta ? make("span", "pill", say("Beta")) : null, make("small", "", when(one.at)));
    const words = make("p", "words", one.words.length > 600 ? `${one.words.slice(0, 600)}…` : one.words);
    const sent = one.picture && one.model ? say("With a picture and the model.") : one.picture ? say("With a picture.")
      : one.model ? say("With the model.") : "";
    item.append(marks, words);
    if (sent) item.append(make("p", "with", sent));
    for (const reply of one.replies || []) {
      item.append(make("div", "answer", make("p", "who", say("Our answer, {day}", { day: when(reply.at) })),
        make("p", "words", reply.words)));
    }
    return item;
  }));
  list.hidden = reports.length === 0;
}

/// Assistants: which AI apps may work in your tabs, and a
/// way to end one. Ending it loses what that connector was allowed to do,
/// so it asks first.
async function claude() {
  const answer = await call("/api/oauth?op=connections").catch(() => null);
  const list = $("connections");
  list.replaceChildren();
  const connections = answer && answer.status === 200 && Array.isArray(answer.body.connections) ? answer.body.connections : null;
  if (!connections) {
    $("claude-said").textContent = say("Which AI apps are connected could not be read just now.");
    return;
  }
  $("claude-how").hidden = connections.length > 0;
  $("claude-said").textContent = connections.length
    ? say("These can work in your Brickworks tabs, as you, while a tab is open.")
    : say("Not connected. With the assistant on, Connect your AI in the app, or add Brickworks to your AI app yourself.");
  for (const one of connections) {
    const since = when(one.since);
    const used = when(one.last_used);
    const app = make("b", "", one.client ? String(one.client) : say("An AI app"));
    const words = sayInto(make("span"), since && used ? say("{app} since {since}, last used {used}", { since, used })
      : since ? say("{app} since {since}", { since }) : used ? say("{app}, last used {used}", { used }) : "{app}", { app });
    const end = make("button", "link", say("Disconnect"));
    end.type = "button";
    end.addEventListener("click", async () => {
      // Claude forgets the tool permissions given to a connection when it is
      // disconnected, which is why nothing here suggests doing it (2026-10-20).
      if (!(await ask({ title: say("Disconnect {app}?", { app: one.client ? String(one.client) : say("this app") }),
        body: say("It can no longer work in your tabs, and it may forget the tool permissions you gave it, so connecting "
          + "again asks for them all again."), yes: say("Disconnect"), danger: true }))) return;
      end.disabled = true;
      const gone = await call(`/api/oauth?op=disconnect&id=${encodeURIComponent(String(one.id))}`, { method: "POST" });
      if (gone.status === 200) claude();
      else end.disabled = false;
    });
    list.append(make("li", "", words, end));
  }
}

/// Whom you blocked, newest first, each with Unblock (GET /api/people?op=blocks).
/// Unblocking brings back their models and comments, not the follows.
// ---------------------------------------------------------------------------
// What you hear of, and where (inbox, 2026-11-23): a box a kind a place. The
// email of comments, photos, remixes and news is the day's email's own
// choice and the news choice (op=mail, op=news, below); every other box is
// one choice of op=notification_prefs, sent as it is ticked.
const WHERE = { here: () => say("here"), push: () => say("by push"), email: () => say("by email") };
const KEPT_ELSEWHERE = new Set(["comment", "photo", "remix", "news"]);
/// Each box of the kinds' grid with its kind and its place.
const kindBoxes = () => [...$("kinds").querySelectorAll("tr[data-notice] input[data-channel]")].map((box) => ({ box,
  kind: box.closest("tr").dataset.notice, channel: box.dataset.channel }));

async function kinds(ocOnly) {
  const answer = await call("/api/people?op=notification_prefs").catch(() => null);
  const ready = Boolean(answer && answer.status === 200 && answer.body.ready === true);
  const prefs = answer && answer.status === 200 ? answer.body : {};
  for (const { box, kind, channel } of kindBoxes()) {
    if (channel === "email" && KEPT_ELSEWHERE.has(kind)) continue;
    box.checked = Array.isArray(prefs[channel]) ? prefs[channel].includes(kind)
      : channel === "here" || (channel === "push" && ["reply", "mention"].includes(kind));
    box.disabled = !ready || (channel === "email" && ocOnly);
  }
  $("mail-said").textContent = ready ? ""
    : answer && answer.status === 200 ? say("Choosing these is not open on Brickworks yet: for now you hear of everything here.")
      : say("What you chose could not be read just now.");
  drawMuted(Array.isArray(prefs.muted) ? prefs.muted : [], ready);
}

/// The muted models, newest first, each with Unmute.
function drawMuted(muted, ready) {
  $("muted-part").hidden = !ready && muted.length === 0;
  $("muted-none").hidden = muted.length > 0;
  $("muted").replaceChildren(...muted.map((one) => {
    const name = String(one.name || one.model);
    const link = make("a", "who");
    link.href = `${langAt()}/m/${encodeURIComponent(one.model)}`;
    if (one.picture) {
      const img = make("img", "muted-pic");
      img.src = one.picture;
      img.alt = "";
      img.width = 48;
      img.height = 36;
      img.loading = "lazy";
      link.append(img);
    }
    link.append(make("span", "", make("b", "", name)));
    const end = make("button", "cta ghost small", say("Unmute"));
    end.type = "button";
    end.setAttribute("aria-label", say("Unmute {name}", { name }));
    end.addEventListener("click", async () => {
      end.disabled = true;
      const done = await call("/api/people?op=notification_mute", { method: "POST", body: { model: one.model, on: false } })
        .catch(() => null);
      if (!done || done.status !== 200) {
        end.disabled = false;
        $("muted-said").textContent = told(done?.body?.error, say("That did not work just now."));
        return;
      }
      $("muted-said").textContent = say("Unmuted: you hear of {name} again.", { name });
      const item = end.closest("li");
      const next = item.nextElementSibling?.querySelector("button") || item.previousElementSibling?.querySelector("button");
      item.remove();
      $("muted-none").hidden = $("muted").children.length > 0;
      (next || $("muted-said")).focus?.();
    });
    return make("li", "", link, end);
  }));
}

for (const { box, kind, channel } of kindBoxes()) {
  if (channel === "email" && KEPT_ELSEWHERE.has(kind)) continue;
  box.addEventListener("change", async () => {
    const what = box.closest("tr").querySelector("th")?.textContent.trim() || kind;
    box.disabled = true;
    const answer = await call("/api/people?op=notification_prefs", { method: "POST", body: { kind, channel, on: box.checked } })
      .catch(() => null);
    box.disabled = false;
    if (!answer || answer.status !== 200) {
      box.checked = !box.checked;
      $("mail-said").textContent = told(answer?.body?.error, say("That did not work just now."));
      return;
    }
    box.checked = answer.body.on === true;
    $("mail-said").textContent = box.checked ? say("On: {what} {where}.", { what, where: WHERE[channel]() })
      : say("Off: {what} {where}.", { what, where: WHERE[channel]() });
  });
}

async function blocked() {
  const answer = await call("/api/people?op=blocks").catch(() => null);
  const list = $("blocked");
  list.replaceChildren();
  const people = answer && answer.status === 200 && Array.isArray(answer.body.people) ? answer.body.people : null;
  $("blocked-part").hidden = Boolean(answer && answer.status === 200 && answer.body.ready === false);
  if (!people) {
    $("blocked-said").textContent = say("Whom you blocked could not be read just now.");
    return;
  }
  $("blocked-said").textContent = people.length
    ? say("Their models and comments stay out of your way, and they can’t follow you or comment on your models. They aren’t told.")
    : say("Nobody. To block somebody, use Block in the More menu on their profile, or beside one of their comments.");
  for (const one of people) {
    const name = String(one.name || one.handle);
    const who = make("a", "who");
    who.href = `${langAt()}/u/${encodeURIComponent(one.handle)}`;
    const face = document.createElement("template");
    face.innerHTML = avatarHtml({ handle: one.handle, name, picture: one.picture }, { size: "small" });
    who.append(face.content.firstElementChild, make("span", "", make("b", "", name), " ", make("small", "", `@${one.handle}`)));
    const since = when(one.at);
    const end = make("button", "link", say("Unblock"));
    end.type = "button";
    end.setAttribute("aria-label", say("Unblock {name}", { name }));
    end.addEventListener("click", async () => {
      end.disabled = true;
      const done = await blockPerson(one.handle, name, false);
      $("blocked-done").textContent = done.said;
      if (done.ok) blocked();
      else end.disabled = false;
    });
    list.append(make("li", "", who, since ? make("small", "", say("since {date}", { date: since })) : "", end));
  }
}

/// How this account signs in (signin3, api/_ways.js ?op=ways): a code to its
/// address, always; Google and GitHub, each signing it in (Unlink), unlinked
/// (Link again), or not used yet (its button, where it is offered). Unlinking
/// leaves the code, so there is always a way in. [given] is an answer
/// already in hand (Unlink's and Link again's carry the new state).
async function ways(given = null) {
  const answer = given || await call("/api/otp?op=ways").catch(() => null);
  const said = answer && answer.status === 200 ? answer.body : null;
  $("ways-part").hidden = !said || !said.code;
  if (!said || !said.code) return;
  const list = $("ways");
  list.replaceChildren(make("li", "", make("span", "", make("b", "", say("A code we email you")), " ",
    say("to {address}", { address: email() })), make("small", "", say("Always"))));
  for (const name of ["google", "github"]) {
    const state = said[name];
    if (state === "never" && !said.offered?.[name]) continue;
    const title = make("span", "way-name", wayMark(name), make("b", "", WAY_NAMES[name]));
    let end;
    if (state === "never") {
      end = make("a", "cta ghost small", name === "google" ? say("Sign in with Google") : say("Sign in with GitHub"));
      wayLinkTo(end, wayLink(name, `${langAt()}/settings#ways-part`));
    } else {
      end = make("button", "link", state === "on" ? say("Unlink") : say("Link again"));
      end.type = "button";
      end.addEventListener("click", async () => {
        end.disabled = true;
        const done = await call("/api/otp?op=ways", { method: "POST", body: { with: name, on: state !== "on" } }).catch(() => null);
        const took = done && done.status === 200;
        // Unlinked, what it signed in ends, this session too when it was one
        // (api/_ways.js waysRoute): signed out here, and asked for a code.
        if (took && done.body?.signed_out) {
          signOut();
          showFeedCount().catch(() => null);
          await load();
          askToSignIn(say("{way} no longer signs you in. You had signed in here with it, so sign in again with a code we email you.",
            { way: WAY_NAMES[name] }));
          return;
        }
        // The list from the answer first, then what was done: said before
        // it, the old row stood beside the words a moment (signin3 flow).
        await ways(took ? done : null);
        $("ways-status").textContent = took
          ? state === "on" ? say("{way} no longer signs you in here. A code we email you still does.", { way: WAY_NAMES[name] })
            : say("{way} signs you in here again.", { way: WAY_NAMES[name] })
          : told(done?.body?.error, say("That did not work just now."));
      });
    }
    const where = state === "on" ? say("Signs you in") : state === "off" ? say("Unlinked")
      : say("Not used yet: with this address, it signs you in here");
    list.append(make("li", "", make("span", "way-row", title, make("small", "", where)), end));
  }
}

/// orangecheck on this account: linked or not, and the way to change it.
/// Linking and unlinking each ask for a code emailed just now; then Link
/// orangecheck, orangecheck's button (account.js orangecheckButton), opens
/// its window from the click (one opened later is blocked).
let ocState = null;
async function orangecheck() {
  const answer = await call("/api/orangecheck?op=status").catch(() => null);
  ocState = answer && answer.status === 200 ? answer.body : null;
  $("oc-part").hidden = !(ocState && (ocState.ready || ocState.did || ocState.made));
  if (!ocState) return;
  const did = ocState.did || "";
  // The orangecheck account signing in made for this one (signin3), said
  // first, whatever else is offered.
  const made = ocState.made?.did
    ? `${say("Your orangecheck account ({did}) was made when you signed in. It stays with orangecheck until you claim it at ochk.app.",
      { did: ocState.made.did })} ` : "";
  $("oc-said").textContent = ocState.only
    ? say("You sign in with orangecheck ({did}). Brickworks has this id for you, not an email address.", { did })
    : did ? say("orangecheck ({did}) is linked: it signs you in here as well as your email.", { did })
      : made + say("Link orangecheck to sign in with it as well as your email: a Bitcoin wallet, email, Google or GitHub. "
        + "Brickworks gets an id for you, not your address.");
  $("oc-go").hidden = ocState.only || Boolean(did) || !linkReady;
  $("oc-unlink").hidden = ocState.only || !did;
}

/// A code to this account's own address, the first time Link or Unlink is
/// pressed: a tab left open is not enough to change how it signs in.
async function askForCode(unlinking, button) {
  button.disabled = true;
  try {
    const to = await sendCode(email());
    $("oc-code-said").textContent = say("The code we emailed to {to}", { to });
    $("oc-code").hidden = false;
    ocCode.size(codeLength());
    ocCode.clear();
    $("oc-status").textContent = unlinking ? say("Confirm it is you, then press Unlink.")
      : say("Confirm it is you, then press Link orangecheck.");
  } catch (trouble) {
    $("oc-status").textContent = trouble.message;
  } finally {
    button.disabled = false;
  }
}

// Shown once orangecheck's button code is in.
let linkReady = false;
orangecheckButton($("oc-go"), {
  label: say("Link orangecheck"),
  before: () => {
    $("oc-status").textContent = "";
    if (!ocState || !ocState.fresh) {
      askForCode(false, $("oc-go"));
      return false;
    }
    $("oc-status").textContent = say("Signing in with orangecheck, in its own window.");
    return true;
  },
  onToken: async (token) => {
    const answer = await call("/api/orangecheck?op=link", { method: "POST", body: { token } });
    $("oc-status").textContent = answer.status === 200
      ? say("Linked. orangecheck signs you in here now, and your email is told.")
      : told(answer.body.error, say("That did not work just now."));
    await orangecheck();
  },
  say: (words) => {
    $("oc-status").textContent = words;
  },
}).then(() => {
  linkReady = true;
  if (ocState) $("oc-go").hidden = ocState.only || Boolean(ocState.did);
}).catch((trouble) => {
  $("oc-status").textContent = trouble.message;
});

$("oc-unlink").addEventListener("click", async () => {
  $("oc-status").textContent = "";
  if (!ocState || !ocState.fresh) return askForCode(true, $("oc-unlink"));
  $("oc-unlink").disabled = true;
  try {
    const answer = await call("/api/orangecheck?op=unlink", { method: "POST", body: {} });
    $("oc-status").textContent = answer.status === 200
      ? say("Unlinked. The sign-ins orangecheck started here are ended, and your email is told.")
      : told(answer.body.error, say("That did not work just now."));
    await orangecheck();
  } catch (trouble) {
    $("oc-status").textContent = trouble.message;
  } finally {
    $("oc-unlink").disabled = false;
  }
});

$("oc-code").addEventListener("submit", async (event) => {
  event.preventDefault();
  // Every digit first, as the sign-in asks: a code short of some is never sent.
  if (!ocCode.complete((words) => { $("oc-status").textContent = words; })) return;
  $("oc-code-go").disabled = true;
  ocCode.busy(true);
  try {
    await redeem(email(), $("oc-code-field").value);
    ocCode.busy(false);
    $("oc-code").hidden = true;
    await orangecheck();
    $("oc-status").textContent = !(ocState && ocState.fresh) ? say("That did not confirm it just now. Try again.")
      : ocState.did ? say("Thank you. Now press Unlink.") : say("Thank you. Now press Link orangecheck.");
    $(ocState && ocState.did ? "oc-unlink" : "oc-go").focus();
  } catch (trouble) {
    ocCode.busy(false);
    $("oc-status").textContent = trouble.message;
    if (trouble.wrong) ocCode.refuse();
  } finally {
    $("oc-code-go").disabled = false;
  }
});

/// What the age answer changes, and what is kept of it said in Privacy.
/// Accounts are for 13 and over: an answer under 13 deletes the account, so
/// only a row from before that says so, and it has nothing public here (the
/// server refuses it too).
/// The beta's row, as GET /api/plans?op=beta says it stands (null: off, or
/// not known): Join for anybody not a tester, and for a tester since when,
/// the hub, Leave, and where its month of Pro stands.
function drawBeta(said) {
  const open = Boolean(said && said.beta === "open" && said.signed_in === true);
  $("beta-part").hidden = !open;
  $("beta-toc").hidden = !open;
  if (!open) return;
  const tester = said.tester === true;
  $("beta-said").textContent = tester
    ? (said.joined_at ? say("You have been a beta tester since {day}. Thank you.", { day: when(said.joined_at) })
      : say("You are a beta tester. Thank you."))
    : say("Brickworks is in open beta. Testers try new features first and tell us what is wrong; the first 100 we pick get a month of Pro.");
  $("beta-join").hidden = tester;
  $("beta-hub").hidden = !tester;
  $("beta-hub").href = `${langAt()}/beta`;
  $("beta-leave").hidden = !tester;
  const month = monthSaid(said.month || said);
  $("beta-month").hidden = !tester;
  $("beta-month").replaceChildren();
  if (tester && month) $("beta-month").append(month);
  if (tester && !month) {
    const about = make("a", "", say("tell us what you build"));
    about.href = `${langAt()}/beta#about`;
    $("beta-month").append(sayInto(make("span"), say("For a month of Pro, {link}: it takes a minute."), { link: about }));
  }
}

/// Where a tester's month of Pro stands, in words, from the month's part
/// of op=beta ({early, application}); "" with nothing told us yet.
function monthSaid({ early, application } = {}) {
  if (early) return say("Your account has Pro already, free and with no end date.");
  if (!application) return "";
  if (application.status === "approved" && application.comp === "granted") {
    return say("Your month of Pro runs from {starts} to {ends}.", { starts: when(application.month_starts_at),
      ends: when(application.month_ends_at) });
  }
  if (application.status === "approved") return say("Your month of Pro starts the day Pro launches.");
  if (application.status === "declined") return say("Not one of this round's months of Pro. You stay a tester.");
  return say("We have what you told us, and email you once we decide on your month of Pro.");
}

/// The beta's row asked for and drawn, its choice of the bar with it.
async function beta() {
  const answer = await call("/api/plans?op=beta");
  drawBeta(answer.status === 200 ? answer.body : null);
  if (!$("beta-part").hidden) await barChoice();
}

// The beta's bar (web/betabar.js), shown on every page or not in this
// browser (bugbar, 2026-11-13): the Beta row's choice signed in, a row of
// its own signed out, each as it stands now and following the bar's × and
// the other tabs. Asked for only while the beta may be open, as theme.js
// asks for the bar: heard off, this page loads none of it.
let barKit = null;
function barChoice() {
  if (window.brickworksBeta === "off") return Promise.resolve(null);
  barKit ||= import("/betabar.js").then((kit) => {
    const boxes = [...document.querySelectorAll("input[data-beta-bar-show]")];
    const draw = () => {
      for (const box of boxes) box.checked = kit.barShown();
    };
    for (const box of boxes) box.addEventListener("change", () => kit.showBar(box.checked));
    addEventListener("brickworks:betabar", draw);
    draw();
    return kit;
  }).catch(() => null);
  return barKit;
}

/// Join or leave from the row, in one press: [op] beta_join or beta_leave.
async function betaPress(op, button) {
  button.disabled = true;
  $("beta-status").textContent = "";
  const answer = await call(`/api/plans?op=${op}`, { method: "POST", body: op === "beta_join" ? { via: "settings" } : {} })
    .catch(() => null);
  button.disabled = false;
  if (!answer || answer.status !== 200) {
    $("beta-status").textContent = told(answer?.body?.error, say("That did not work just now."));
    return;
  }
  drawBeta(answer.body);
  // The beta's bar (web/betabar.js) redraws from it, in this tab at once.
  dispatchEvent(new CustomEvent("brickworks:beta", { detail: answer.body }));
  $("beta-status").textContent = answer.body.tester ? say("Joined. You are a beta tester.")
    : say("You left the beta. Join again any time.");
  (answer.body.tester ? $("beta-leave") : $("beta-join")).focus();
}
$("beta-join").addEventListener("click", () => betaPress("beta_join", $("beta-join")));
$("beta-leave").addEventListener("click", () => betaPress("beta_leave", $("beta-leave")));

function drawAge(kept, handle) {
  const young = Boolean(kept && kept.over_13 === false);
  $("young").hidden = !young;
  document.documentElement.dataset.young = young ? "yes" : "no";
  $("age-said").textContent = kept && kept.over_13 === true
    ? say("You told Brickworks you are 13 or over. Only that is kept, never your date of birth.")
    : say("Brickworks asks everyone once whether they are 13 or over, and keeps only that answer.");
  $("edit-profile").hidden = young;
  if (young && !handle) $("profile-line").textContent = say("A public profile is for people 13 and over.");
  $("follows-choice").hidden = !$("follows-choice").dataset.ready || young;
  $("likes-choice").hidden = !$("likes-choice").dataset.ready || young || !handle;
}

// Signed in, the skeleton (settings.html #loading) holds the panel's place
// while every part is asked at once, and the panel is drawn whole when they
// have come: each part drawn as it came moved the rows under it (site273,
// /settings at 390 px 1.17). Then the age question, if this account is to
// be asked it, over the page.
async function load() {
  if (!signedIn()) {
    $("loading").hidden = true;
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    // The bar's own row, under the sign-in, while the beta is open; the
    // page said drawn only once it is (or is not) there.
    const kit = await barChoice();
    $("beta-bar-out").hidden = !kit || (await kit.betaState()).beta !== "open";
    document.documentElement.dataset.settings = "signed-out";
    return;
  }
  const ageNow = age().catch(() => null);
  // The beta's row only while the account says the beta is open: with it
  // off the page asks nothing of /api/plans, as before (billing_flow).
  const parts = Promise.all([ways().catch(() => null), orangecheck().catch(() => null), claude().catch(() => null), feedback().catch(() => null),
    blocked().catch(() => null),
    ageNow.then(() => (betaOpen() ? beta() : drawBeta(null))).catch(() => drawBeta(null))]);
  const answer = await call("/api/people?op=me");
  if (answer.status === 401) {
    signOut();
    return load();
  }
  // An orangecheck account has no address: Brickworks has an id for it, and
  // mails it nothing. It is deleted by signing in with orangecheck again.
  const ocOnly = madeUp(email());
  $("who").textContent = ocOnly
    ? say("Signed in with orangecheck. Brickworks has an id for you, not an email address, so it emails you nothing.")
    : say("Signed in as {email}. Only you see the address; the gallery shows your profile’s name.", { email: email() });
  $("delete-confirm").placeholder = ocOnly ? "" : email();
  $("delete-confirm").required = !ocOnly;
  $("delete-confirm").closest("label").hidden = ocOnly;
  $("delete-go").hidden = ocOnly;
  $("delete-oc").hidden = !ocOnly;
  const mine = answer.body.profile;
  const handle = mine && HANDLE.test(String(mine.handle)) ? String(mine.handle) : "";
  $("profile-line").textContent = handle
    ? say("brickworks.diy/u/{handle}: your name, words, links and pinned models, as everybody sees them.", { handle })
    : say("No profile yet: choose a name and a handle, and your models in the gallery have a page of their own.");
  $("edit-profile").textContent = handle ? say("Edit profile") : say("Make your profile");
  $("edit-profile").href = handle ? `${langAt()}/profile?edit=1` : `${langAt()}/profile`;
  // What is emailed (api/_comments.js): comments on their models, at most
  // once a day, off until chosen. Not there before comments.sql. And the
  // feed's kinds, one choice each, since follows.sql.
  const mail = answer.body.mail;
  const mailed = !ocOnly && Boolean(mail && mail.ready !== false);
  $("mail").hidden = !mailed || !(mail && mail.kinds === true);
  $("mail-comments").checked = Boolean(mail && mail.comments);
  $("mail-comments").disabled = !mailed;
  $("mail-kinds").hidden = !(mail && mail.kinds === true);
  for (const box of $("email-part").querySelectorAll("input[data-kind]")) {
    box.checked = Boolean(mail && mail[box.dataset.kind]);
    box.disabled = !mailed || !(mail && mail.kinds === true);
  }
  // This device's notifications, drawn on their own (web/push.js); and each
  // kind here, by push and by email, and the models muted.
  drawPush().catch(() => null);
  const chosen = kinds(ocOnly).catch(() => null);
  // Brickworks' news by email (api/_announce.js), off until chosen.
  const news = answer.body.news;
  $("mail-news").disabled = ocOnly || !(news && news.ready);
  $("mail-news").checked = Boolean(news && news.news);
  // Whether their profile shows whom they follow (supabase/follows.sql).
  const shows = answer.body.follows;
  $("follows-choice").dataset.ready = shows && shows.ready ? "yes" : "";
  $("shows-follows").checked = Boolean(shows && shows.shows_follows);
  // Whether their profile shows the models they liked: only with a profile
  // to show them on (supabase/avatars.sql).
  const likes = answer.body.likes;
  $("likes-choice").dataset.ready = likes && likes.ready ? "yes" : "";
  $("shows-likes").checked = Boolean(likes && likes.shows_likes);
  // The plan, only while this deployment has plans on (web/plan.js):
  // otherwise nothing of it is asked or drawn.
  $("plan")?.remove();
  planSays = null;
  const plan = answer.body.billing
    ? import("/plan.js").then((m) => {
      planSays = m.endsWithAccount;
      return m.planPart($("profile-part"));
    }).catch(() => null) : null;
  // The answer kept, if there is one: what Privacy says, drawn with the rest.
  const known = await ageNow;
  drawAge(known, handle);
  await parts;
  await plan;
  await chosen;
  $("loading").hidden = true;
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  // The age question, if this account has not answered it; answered under
  // 13, the account is gone, and the page drawn again for nobody.
  if (known && known.ask) {
    const answered = await askAgeIfAsked().catch(() => null);
    if (answered && answered.refused) {
      showFeedCount().catch(() => null);
      return load();
    }
    drawAge(answered || known, handle);
  }
  // Back from Stripe to #plan, which was not on the page until now.
  if (plan && location.hash === "#plan") $("plan")?.scrollIntoView({ block: "start" });
  document.documentElement.dataset.settings = "ready";
}

// ---------------------------------------------------------------------------
// This device's notifications (homescreen, 2026-11-22): on or off for this
// browser alone, as the account knows it (GET /api/people?op=push with the
// device's endpoint); the browser's own prompt only once it is turned on.
// And Install Brickworks, while the browser offers it, for whoever said No
// thanks to the offer at a page's foot (web/push.js).

let pushKey = null;
const pushSaid = (words) => {
  $("push-said").textContent = words;
};
const BLOCKED = () => say("Notifications are blocked for this site in your browser’s settings. Allow them there, then turn this on.");

/// Turn off on every device (N): shown while the account has any, from any
/// browser, this one able to show notifications or not.
function drawEvery(devices) {
  const n = Number(devices) || 0;
  $("push-every-part").hidden = n < 1;
  $("push-every").textContent = say("Turn off on every device ({n})", { n });
}

async function drawPush() {
  const box = $("push-on");
  box.disabled = true;
  drawInstall();
  const here = await device.device().catch(() => ({ pushable: false }));
  const endpoint = here.subscription?.endpoint;
  const answer = await call(`/api/people?op=push${endpoint ? `&endpoint=${encodeURIComponent(endpoint)}` : ""}`).catch(() => null);
  const open = Boolean(answer && answer.status === 200 && answer.body.ready && answer.body.key);
  drawEvery(open ? answer.body.devices : 0);
  if (!here.pushable) {
    box.checked = false;
    // Apple lets a site notify only from the Home Screen, from iOS 16.4,
    // and the Home Screen app opens in the studio (/app).
    pushSaid(device.apple() && !device.standalone()
      ? say("On an iPhone or iPad (iOS 16.4 or later), add Brickworks to your Home Screen first: Share, then Add to Home Screen. Open it from there: it opens in the studio, so tap its menu, Back to brickworks.diy, then Menu › Settings, and turn this on there.")
      : say("This browser can’t show notifications from a site."));
    return;
  }
  if (!open) {
    box.checked = false;
    pushSaid(say("Notifications on this device are not open on Brickworks yet."));
    return;
  }
  pushKey = answer.body.key;
  const on = Boolean(answer.body.on && endpoint && here.permission === "granted");
  box.checked = on;
  if (on) device.told(here.subscription);
  if (here.permission === "denied") {
    pushSaid(BLOCKED());
    return;
  }
  box.disabled = false;
  pushSaid("");
}

$("push-on").addEventListener("change", async () => {
  const box = $("push-on");
  box.disabled = true;
  if (box.checked) {
    pushSaid(say("Asking your browser…"));
    const on = await device.turnOn(pushKey).catch(() => ({ state: "failed" }));
    if (on.state !== "granted") {
      box.checked = false;
      box.disabled = on.state === "denied";
      pushSaid(on.state === "denied" ? BLOCKED()
        : on.state === "default" ? say("Not turned on: your browser asked, and it wasn’t allowed.")
          : say("This browser’s push service didn’t answer. Try again in a minute."));
      return;
    }
    const sub = on.subscription;
    const answer = await call("/api/people?op=push", { method: "POST", body: { on: true, endpoint: sub.endpoint,
      p256dh: sub.keys?.p256dh, auth: sub.keys?.auth, lang: globalThis.brickworksLang?.code || "en" } }).catch(() => null);
    box.disabled = false;
    if (!answer || answer.status !== 200) {
      box.checked = false;
      await device.turnOff().catch(() => null);
      pushSaid(told(answer?.body?.error, say("That did not work just now.")));
      return;
    }
    device.told(sub);
    drawEvery(answer.body.devices);
    pushSaid(say("On for this device: what happens to your models shows here within the minute."));
    return;
  }
  const here = await device.device().catch(() => ({ subscription: null }));
  const endpoint = here.subscription?.endpoint;
  if (endpoint) {
    const answer = await call("/api/people?op=push", { method: "POST", body: { on: false, endpoint } }).catch(() => null);
    if (!answer || answer.status !== 200) {
      box.checked = true;
      box.disabled = false;
      pushSaid(told(answer?.body?.error, say("That did not work just now.")));
      return;
    }
    drawEvery(answer.body.devices);
  }
  await device.turnOff().catch(() => null);
  box.disabled = false;
  pushSaid(say("Off for this device."));
});

// Every device of the account off at once: a phone left somewhere, a
// computer that was not yours.
$("push-every").addEventListener("click", async () => {
  const every = $("push-every");
  every.disabled = true;
  const answer = await call("/api/people?op=push", { method: "POST", body: { on: false, all: true } }).catch(() => null);
  every.disabled = false;
  if (!answer || answer.status !== 200) {
    pushSaid(told(answer?.body?.error, say("That did not work just now.")));
    return;
  }
  await device.turnOff().catch(() => null);
  $("push-on").checked = false;
  drawEvery(0);
  pushSaid(say("Off on every device."));
  $("push-on").focus();
});

function drawInstall() {
  $("install-part").hidden = device.installable() !== "prompt";
}
addEventListener("beforeinstallprompt", () => setTimeout(drawInstall));
addEventListener("appinstalled", () => setTimeout(drawInstall));
$("install").addEventListener("click", async () => {
  const outcome = await device.install().catch(() => null);
  drawInstall();
  if (outcome === "accepted") pushSaid(say("Installed: Brickworks opens from your home screen or dock now."));
});

$("mail-comments").addEventListener("change", async () => {
  const box = $("mail-comments");
  box.disabled = true;
  const answer = await call("/api/people?op=mail", { method: "POST", body: { comments: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("mail-said").textContent = told(answer.body.error, say("That did not work just now."));
    return;
  }
  $("mail-said").textContent = answer.body.comments
    ? say("On: at most one email a day, when somebody comments on a model you shared.")
    : say("Off: no emails about comments.");
});

$("mail-news").addEventListener("change", async () => {
  const box = $("mail-news");
  box.disabled = true;
  const answer = await call("/api/people?op=news", { method: "POST", body: { news: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("mail-said").textContent = told(answer.body.error, say("That did not work just now."));
    return;
  }
  $("mail-said").textContent = answer.body.news
    ? say("On: Brickworks' news by email, now and then. Each one has a link to stop them.")
    : say("Off: no news by email.");
});

// Each kind's two sentences, on and off.
const KIND_WORDS = {
  models: [() => say("On: new models from people you follow in the day's one email."),
    () => say("Off: no emails about new models from people you follow.")],
  versions: [() => say("On: new versions of their models in the day's one email."),
    () => say("Off: no emails about new versions of their models.")],
  photos: [() => say("On: photos of builds in the day's one email."), () => say("Off: no emails about photos of builds.")],
  remixes: [() => say("On: remixes of your models in the day's one email."), () => say("Off: no emails about remixes of your models.")],
};
for (const box of $("email-part").querySelectorAll("input[data-kind]")) {
  box.addEventListener("change", async () => {
    const kind = box.dataset.kind;
    box.disabled = true;
    const answer = await call("/api/people?op=mail", { method: "POST", body: { [kind]: box.checked } });
    box.disabled = false;
    if (answer.status !== 200) {
      box.checked = !box.checked;
      $("mail-said").textContent = told(answer.body.error, say("That did not work just now."));
      return;
    }
    $("mail-said").textContent = KIND_WORDS[kind][answer.body[kind] ? 0 : 1]();
  });
}

$("shows-follows").addEventListener("change", async () => {
  const box = $("shows-follows");
  box.disabled = true;
  const answer = await call("/api/people?op=follow_choice", { method: "POST", body: { shows: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("follows-said").textContent = told(answer.body.error, say("That did not work just now."));
    return;
  }
  $("follows-said").textContent = answer.body.shows_follows
    ? say("Shown: your profile lists whom you follow.")
    : say("Not shown: your profile says only how many.");
});

$("shows-likes").addEventListener("change", async () => {
  const box = $("shows-likes");
  box.disabled = true;
  const answer = await call("/api/people?op=likes_choice", { method: "POST", body: { shows: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("likes-said").textContent = told(answer.body.error, say("That did not work just now."));
    return;
  }
  $("likes-said").textContent = answer.body.shows_likes
    ? say("Shown: your profile has a Likes tab of the models you liked.")
    : say("Not shown: nobody sees which models you liked.");
});

$("sign-in").addEventListener("click", () => askToSignIn());
// Signed in by any dialog on this page (its own Sign in, the header's):
// drawn for them, where they are (signinux, 2026-11-13).
addEventListener("brickworks:signed-in-done", () => {
  if (document.documentElement.dataset.settings === "signed-out") load();
});
$("sign-out").addEventListener("click", () => {
  // This device's notifications stop with it (web/account.js signOut).
  signOut();
  showFeedCount().catch(() => null);
  load();
});
// What deleting does to the plan this account pays for (web/plan.js
// endsWithAccount), while plans are on; null while they are off.
let planSays = null;
const planEnds = () => (planSays ? planSays($("plan")?.dataset.plan) : null);

// Opening the delete form says it again, as the plan's row has it now.
$("delete-form").closest("details").addEventListener("toggle", () => {
  $("delete-plan")?.remove();
  const ends = planEnds();
  if (ends) $("delete-form").querySelector("p").after(ends.said);
});

/// The account deleted, with [body] as its confirmation: its address typed
/// again, or a fresh sign-in with orangecheck. Asked first, for good.
async function deleteAccount(body) {
  const ends = planEnds();
  if (!(await ask({ title: say("Delete this account and everything in it, for good?"), body: ends ? ends.words : "",
    yes: say("Delete my account"), danger: true }))) return;
  $("delete-go").disabled = true;
  const answer = await call("/api/account?op=delete", { method: "POST", body });
  $("delete-go").disabled = false;
  if (answer.status === 403 && answer.body.fresh === false) {
    // Signed in with orangecheck, to an account with its own email: a code
    // to it first, as unlinking asks (api/account.js).
    try {
      const to = await sendCode(email());
      $("delete-code-said").textContent = say("The code we emailed to {to}", { to });
      $("delete-code-part").hidden = false;
      deleteCode.size(codeLength());
      deleteCode.clear();
      $("delete-said").textContent = say("Confirm it is you with the code, then press Delete my account again.");
    } catch (trouble) {
      $("delete-said").textContent = trouble.message;
    }
    return;
  }
  if (answer.status !== 200) {
    $("delete-said").textContent = told(answer.body.error, say("That did not work just now."));
    return;
  }
  // Its devices went with it (supabase/push.sql); this one's subscription too.
  await device.turnOff().catch(() => null);
  signOut();
  showFeedCount().catch(() => null);
  await load();
  // An orangecheck account Connect made that orangecheck would not delete
  // stays the person's, and they are told where (api/account.js).
  const kept = answer.body.orangecheck && answer.body.orangecheck.kept ? told(answer.body.orangecheck.said) : "";
  // Its Pro plan, ended at Admission first (api/account.js).
  const ended = answer.body.plan && answer.body.plan.ended ? say("Your Pro plan has ended, and you will not be charged again.") : "";
  $("signed-out").querySelector(".lede").textContent = [say("Your account is deleted, and everything in it."), ended, kept,
    say("Sign in again with any address to start a new one.")].filter(Boolean).join(" ");
  // Said done only now, with the page drawn signed out and its words
  // written: load() waits on the beta's bar (bugbar), and a mark set before
  // it was read while the lede still asked to sign in (rel-m298).
  document.documentElement.dataset.deleted = "yes";
}

// An orangecheck account, whose address is made up, signs in with
// orangecheck again instead of typing it: orangecheck's button, whose
// window opens from the click (one opened after a question is blocked).
orangecheckButton($("delete-oc"), {
  label: say("Sign in with orangecheck to delete"),
  before: () => {
    $("delete-said").textContent = say("Signing in with orangecheck, in its own window.");
    return true;
  },
  onToken: async (token) => {
    $("delete-said").textContent = "";
    await deleteAccount({ orangecheck: token });
  },
  say: (words) => {
    $("delete-said").textContent = words;
  },
}).catch(() => null);

$("delete-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const typed = $("delete-confirm").value.trim();
  if (typed.toLowerCase() !== email().toLowerCase()) {
    $("delete-said").textContent = say("That is not the address this account signs in with.");
    return;
  }
  // Asked for below, when this browser signed in with orangecheck: the
  // code redeemed is a sign-in of its own, by email, just now.
  if (!$("delete-code-part").hidden) {
    if (!deleteCode.complete((words) => { $("delete-said").textContent = words; })) return;
    $("delete-go").disabled = true;
    try {
      await redeem(email(), $("delete-code").value);
      $("delete-code-part").hidden = true;
    } catch (trouble) {
      $("delete-said").textContent = trouble.message;
      if (trouble.wrong) deleteCode.refuse();
      return;
    } finally {
      $("delete-go").disabled = false;
    }
  }
  await deleteAccount({ confirm: typed });
});

/// Opened from a news mail's Unsubscribe (/settings?unsubscribe=<account>.<token>,
/// api/_announce.js): an Unsubscribe button, signed in or not, which asks.
/// Never on opening: a mail's link scanner opens every link in it, and
/// would unsubscribe the person (anreview L4). A mail client's own one
/// click is the POST its List-Unsubscribe-Post header names (RFC 8058).
async function unsubscribed() {
  const asked = new URLSearchParams(location.search).get("unsubscribe") || "";
  const found = /^([0-9a-f-]{36})\.([A-Za-z0-9_-]{20,64})$/.exec(asked);
  if (!asked) return;
  const left = new URL(location.href);
  left.searchParams.delete("unsubscribe");
  history.replaceState(null, "", left.pathname + left.search + left.hash);
  const note = $("unsubscribed");
  note.hidden = false;
  if (!found) {
    note.textContent = say("That unsubscribe link was cut short. Turn off Brickworks news under Email below, once signed in.");
    return;
  }
  note.textContent = say("Stop Brickworks news by email to this address?");
  const actions = document.createElement("div");
  actions.className = "actions unsubscribe-actions";
  const go = document.createElement("button");
  go.type = "button";
  go.className = "cta";
  go.id = "unsubscribe-go";
  go.textContent = say("Unsubscribe");
  actions.append(go);
  note.after(actions);
  go.addEventListener("click", async () => {
    go.disabled = true;
    const answer = await fetch("/api/people?op=news_unsubscribe", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ a: found[1], t: found[2] }) }).then(async (reply) => ({ status: reply.status,
      body: await reply.json().catch(() => ({})) }), () => null);
    go.disabled = false;
    if (answer && answer.status === 200) {
      actions.remove();
      note.textContent = say("Unsubscribed: Brickworks will email you no more news. You can turn it on again under Email.");
      // Signed in as them, the Email choice below says so too.
      if (signedIn()) load();
      return;
    }
    note.textContent = told(answer?.body?.error, say("That did not work just now. Press Unsubscribe again in a minute."));
  });
}

unsubscribed().catch(() => null).finally(() => load());
