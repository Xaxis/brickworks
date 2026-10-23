// Your settings, /settings (settings.html): the theme, what Brickworks
// emails you, your age answer, whom your profile shows you follow and
// whether it shows the models you liked (supabase/avatars.sql), the
// Claude apps that may work in your tabs, signing out and deleting the
// account. Your profile itself (name, handle, words, links, pins) is
// changed on /profile, with Edit profile (docs/SOCIAL.md U6, D9).
//
// Signed in with the app's own sign-in in this browser (account.js). Every
// word goes on the page as text, never as markup. Each part asks for its
// own and draws what came, so one that cannot be read leaves the others.
import { age, askAgeIfAsked, askToSignIn, call, email, signOut, signedIn } from "/account.js";
import { showFeedCount } from "/follow.js";

const $ = (id) => document.getElementById(id);
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric" });
const when = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
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
    $("claude-said").textContent = "Whether your Claude is connected could not be read just now.";
    return;
  }
  $("claude-how").hidden = connections.length > 0;
  $("claude-said").textContent = connections.length
    ? "These can work in your Brickworks tabs, as you, while a tab is open."
    : "Not connected. With the assistant on, Connect Claude in the app, or add Brickworks to Claude yourself.";
  for (const one of connections) {
    const since = when(one.since);
    const used = when(one.last_used);
    const words = make("span", "", make("b", "", String(one.client || "A Claude app")),
      since ? ` since ${since}` : "", used ? `, last used ${used}` : "");
    const end = make("button", "link", "Disconnect");
    end.type = "button";
    end.addEventListener("click", async () => {
      // Claude forgets the tool permissions given to a connection when it is
      // disconnected, which is why nothing here suggests doing it (2026-10-20).
      if (!confirm(`Disconnect ${String(one.client || "this app")}? It can no longer work in your tabs. Claude also `
        + "forgets the tool permissions you gave it, so connecting again asks for them all again.")) return;
      end.disabled = true;
      const gone = await call(`/api/oauth?op=disconnect&id=${encodeURIComponent(String(one.id))}`, { method: "POST" });
      if (gone.status === 200) claude();
      else end.disabled = false;
    });
    list.append(make("li", "", words, end));
  }
}

async function load() {
  $("loading").hidden = true;
  if (!signedIn()) {
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    document.documentElement.dataset.settings = "signed-out";
    return;
  }
  const answer = await call("/api/people?op=me");
  if (answer.status === 401) {
    signOut();
    return load();
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  $("who").textContent = `Signed in as ${email()}. Only you see the address; the gallery shows your profile’s name.`;
  $("delete-confirm").placeholder = email();
  // The age question, if this account has not answered it; and under 13,
  // no public profile here (the server refuses one too).
  const answered = await askAgeIfAsked().catch(() => null);
  const young = Boolean(answered && answered.over_13 === false);
  $("young").hidden = !young;
  document.documentElement.dataset.young = young ? "yes" : "no";
  const kept = answered || await age().catch(() => null);
  $("age-said").textContent = kept && kept.over_13 === true
    ? "You told Brickworks you are 13 or over. Only that is kept, never your date of birth."
    : kept && kept.over_13 === false
      ? "You told Brickworks you are under 13, so your profile and collections stay private. Only that is kept."
      : "Brickworks asks everyone once whether they are 13 or over, and keeps only that answer.";
  const mine = answer.body.profile;
  const handle = mine && HANDLE.test(String(mine.handle)) ? String(mine.handle) : "";
  $("profile-line").textContent = handle
    ? `brickworks.diy/u/${handle}: your name, words, links and pinned models, as everybody sees them.`
    : young ? "A public profile is for people 13 and over."
      : "No profile yet: choose a name and a handle, and your models in the gallery have a page of their own.";
  $("edit-profile").textContent = handle ? "Edit profile" : "Make your profile";
  $("edit-profile").href = handle ? "/profile?edit=1" : "/profile";
  $("edit-profile").hidden = young;
  // What is emailed (api/_comments.js): comments on their models, at most
  // once a day, off until chosen. Not there before comments.sql. And the
  // feed's kinds, one choice each, since follows.sql.
  const mail = answer.body.mail;
  $("mail").hidden = !(mail && mail.ready !== false);
  $("mail-comments").checked = Boolean(mail && mail.comments);
  $("mail-kinds").hidden = !(mail && mail.kinds === true);
  for (const box of $("mail-kinds").querySelectorAll("input[data-kind]")) box.checked = Boolean(mail && mail[box.dataset.kind]);
  // Whether their profile shows whom they follow (supabase/follows.sql).
  const shows = answer.body.follows;
  $("follows-choice").hidden = !(shows && shows.ready) || young;
  $("shows-follows").checked = Boolean(shows && shows.shows_follows);
  // Whether their profile shows the models they liked: only with a profile
  // to show them on (supabase/avatars.sql).
  const likes = answer.body.likes;
  $("likes-choice").hidden = !(likes && likes.ready) || young || !handle;
  $("shows-likes").checked = Boolean(likes && likes.shows_likes);
  await claude().catch(() => null);
  document.documentElement.dataset.settings = "ready";
}

$("mail-comments").addEventListener("change", async () => {
  const box = $("mail-comments");
  box.disabled = true;
  const answer = await call("/api/people?op=mail", { method: "POST", body: { comments: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("mail-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("mail-said").textContent = answer.body.comments
    ? "On: at most one email a day, when somebody comments on a model you shared."
    : "Off: no emails about comments.";
});

const KIND_WORDS = { models: "new models from people you follow", versions: "new versions of their models",
  photos: "photos of builds", remixes: "remixes of your models" };
for (const box of $("mail-kinds").querySelectorAll("input[data-kind]")) {
  box.addEventListener("change", async () => {
    const kind = box.dataset.kind;
    box.disabled = true;
    const answer = await call("/api/people?op=mail", { method: "POST", body: { [kind]: box.checked } });
    box.disabled = false;
    if (answer.status !== 200) {
      box.checked = !box.checked;
      $("mail-said").textContent = answer.body.error || "That did not work just now.";
      return;
    }
    $("mail-said").textContent = answer.body[kind]
      ? `On: ${KIND_WORDS[kind]} in the day's one email.`
      : `Off: no emails about ${KIND_WORDS[kind]}.`;
  });
}

$("shows-follows").addEventListener("change", async () => {
  const box = $("shows-follows");
  box.disabled = true;
  const answer = await call("/api/people?op=follow_choice", { method: "POST", body: { shows: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("follows-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("follows-said").textContent = answer.body.shows_follows
    ? "Shown: your profile lists whom you follow."
    : "Not shown: your profile says only how many.";
});

$("shows-likes").addEventListener("change", async () => {
  const box = $("shows-likes");
  box.disabled = true;
  const answer = await call("/api/people?op=likes_choice", { method: "POST", body: { shows: box.checked } });
  box.disabled = false;
  if (answer.status !== 200) {
    box.checked = !box.checked;
    $("likes-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("likes-said").textContent = answer.body.shows_likes
    ? "Shown: your profile has a Likes tab of the models you liked."
    : "Not shown: nobody sees which models you liked.";
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
$("delete-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const typed = $("delete-confirm").value.trim();
  if (typed.toLowerCase() !== email().toLowerCase()) {
    $("delete-said").textContent = "That is not the address this account signs in with.";
    return;
  }
  if (!confirm("Delete this account and everything in it, for good?")) return;
  $("delete-go").disabled = true;
  const answer = await call("/api/account?op=delete", { method: "POST", body: { confirm: typed } });
  $("delete-go").disabled = false;
  if (answer.status !== 200) {
    $("delete-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  signOut();
  showFeedCount().catch(() => null);
  document.documentElement.dataset.deleted = "yes";
  await load();
  $("signed-out").querySelector(".lede").textContent = "Your account is deleted, and everything in it. "
    + "Sign in again with any address to start a new one.";
});

load();
