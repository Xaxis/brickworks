// Your settings, /settings (settings.html): the theme, what Brickworks
// emails you, orangecheck linked or not (api/orangecheck.js), your age
// answer, whom your profile shows you follow and whether it shows the
// models you liked (supabase/avatars.sql), the Claude apps that may work
// in your tabs, your feedback with where each report stands and our answers
// (api/_feedback.js), signing out and deleting the account. Your profile itself (name, handle, words, links, pins) is
// changed on /profile, with Edit profile (docs/SOCIAL.md U6, D9).
//
// Signed in with the app's own sign-in in this browser (account.js). Every
// word goes on the page as text, never as markup. Each part asks for its
// own and draws what came, so one that cannot be read leaves the others.
import {
  age, askAgeIfAsked, askToSignIn, call, email, madeUp, orangecheckButton, redeem, sendCode, signOut, signedIn,
} from "/account.js";
import { langAt, say, told } from "/card.js";
import { showFeedCount } from "/follow.js";

const $ = (id) => document.getElementById(id);
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
    const marks = make("p", "marks", make("span", "pill", KINDS[one.kind] ? KINDS[one.kind]() : say("A report")),
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

/// The Claude connection: which Claude apps may work in your tabs, and a
/// way to end one. Ending it loses what that connector was allowed to do,
/// so it asks first.
async function claude() {
  const answer = await call("/api/oauth?op=connections").catch(() => null);
  const list = $("connections");
  list.replaceChildren();
  const connections = answer && answer.status === 200 && Array.isArray(answer.body.connections) ? answer.body.connections : null;
  if (!connections) {
    $("claude-said").textContent = say("Whether your Claude is connected could not be read just now.");
    return;
  }
  $("claude-how").hidden = connections.length > 0;
  $("claude-said").textContent = connections.length
    ? say("These can work in your Brickworks tabs, as you, while a tab is open.")
    : say("Not connected. With the assistant on, Connect Claude in the app, or add Brickworks to Claude yourself.");
  for (const one of connections) {
    const since = when(one.since);
    const used = when(one.last_used);
    const app = make("b", "", one.client ? String(one.client) : say("A Claude app"));
    const words = sayInto(make("span"), since && used ? say("{app} since {since}, last used {used}", { since, used })
      : since ? say("{app} since {since}", { since }) : used ? say("{app}, last used {used}", { used }) : "{app}", { app });
    const end = make("button", "link", say("Disconnect"));
    end.type = "button";
    end.addEventListener("click", async () => {
      // Claude forgets the tool permissions given to a connection when it is
      // disconnected, which is why nothing here suggests doing it (2026-10-20).
      if (!confirm(say("Disconnect {app}? It can no longer work in your tabs. Claude also "
        + "forgets the tool permissions you gave it, so connecting again asks for them all again.",
      { app: one.client ? String(one.client) : say("this app") }))) return;
      end.disabled = true;
      const gone = await call(`/api/oauth?op=disconnect&id=${encodeURIComponent(String(one.id))}`, { method: "POST" });
      if (gone.status === 200) claude();
      else end.disabled = false;
    });
    list.append(make("li", "", words, end));
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
  $("oc-part").hidden = !(ocState && (ocState.ready || ocState.did));
  if (!ocState) return;
  const did = ocState.did || "";
  $("oc-said").textContent = ocState.only
    ? say("You sign in with orangecheck ({did}). Brickworks has this id for you, not an email address.", { did })
    : did ? say("orangecheck ({did}) is linked: it signs you in here as well as your email.", { did })
      : say("Link orangecheck to sign in with it as well as your email: a Bitcoin wallet, email, Google or GitHub. "
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
    $("oc-code-field").value = "";
    $("oc-code-field").focus();
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
  $("oc-code-go").disabled = true;
  try {
    await redeem(email(), $("oc-code-field").value);
    $("oc-code").hidden = true;
    await orangecheck();
    $("oc-status").textContent = !(ocState && ocState.fresh) ? say("That did not confirm it just now. Try again.")
      : ocState.did ? say("Thank you. Now press Unlink.") : say("Thank you. Now press Link orangecheck.");
    $(ocState && ocState.did ? "oc-unlink" : "oc-go").focus();
  } catch (trouble) {
    $("oc-status").textContent = trouble.message;
  } finally {
    $("oc-code-go").disabled = false;
  }
});

/// What the age answer changes, and what is kept of it said in Privacy.
/// Accounts are for 13 and over: an answer under 13 deletes the account, so
/// only a row from before that says so, and it has nothing public here (the
/// server refuses it too).
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
    document.documentElement.dataset.settings = "signed-out";
    return;
  }
  const parts = Promise.all([orangecheck().catch(() => null), claude().catch(() => null), feedback().catch(() => null)]);
  const ageNow = age().catch(() => null);
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
  $("mail").hidden = ocOnly || !(mail && mail.ready !== false);
  $("mail-comments").checked = Boolean(mail && mail.comments);
  $("mail-kinds").hidden = !(mail && mail.kinds === true);
  for (const box of $("mail-kinds").querySelectorAll("input[data-kind]")) box.checked = Boolean(mail && mail[box.dataset.kind]);
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

// Each kind's two sentences, on and off.
const KIND_WORDS = {
  models: [() => say("On: new models from people you follow in the day's one email."),
    () => say("Off: no emails about new models from people you follow.")],
  versions: [() => say("On: new versions of their models in the day's one email."),
    () => say("Off: no emails about new versions of their models.")],
  photos: [() => say("On: photos of builds in the day's one email."), () => say("Off: no emails about photos of builds.")],
  remixes: [() => say("On: remixes of your models in the day's one email."), () => say("Off: no emails about remixes of your models.")],
};
for (const box of $("mail-kinds").querySelectorAll("input[data-kind]")) {
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

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn()) {
    showFeedCount().catch(() => null);
    load();
  }
});
$("sign-out").addEventListener("click", () => {
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
  if (!confirm(`${say("Delete this account and everything in it, for good?")}${ends ? ` ${ends.words}` : ""}`)) return;
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
      $("delete-code").required = true;
      $("delete-code").value = "";
      $("delete-code").focus();
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
  signOut();
  showFeedCount().catch(() => null);
  document.documentElement.dataset.deleted = "yes";
  await load();
  // An orangecheck account Connect made that orangecheck would not delete
  // stays the person's, and they are told where (api/account.js).
  const kept = answer.body.orangecheck && answer.body.orangecheck.kept ? told(answer.body.orangecheck.said) : "";
  // Its Pro plan, ended at Admission first (api/account.js).
  const ended = answer.body.plan && answer.body.plan.ended ? say("Your Pro plan has ended, and you will not be charged again.") : "";
  $("signed-out").querySelector(".lede").textContent = [say("Your account is deleted, and everything in it."), ended, kept,
    say("Sign in again with any address to start a new one.")].filter(Boolean).join(" ");
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
    $("delete-go").disabled = true;
    try {
      await redeem(email(), $("delete-code").value);
      $("delete-code-part").hidden = true;
      $("delete-code").required = false;
    } catch (trouble) {
      $("delete-said").textContent = trouble.message;
      return;
    } finally {
      $("delete-go").disabled = false;
    }
  }
  await deleteAccount({ confirm: typed });
});

load();
