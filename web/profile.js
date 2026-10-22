// Your account, /profile (profile.html): who you are in the gallery, your
// models (designs.js), favourites, collections, the sets you own and what
// they build, whom you follow, your build photos, and the settings, from
// the site's API, signed in with the app's own sign-in in this browser
// (account.js).
//
// Every word — a name, a handle, a collection's, a model's — goes on the
// page as text, never as markup; a link is built from an id or a handle
// only when it is one. Each section asks for its own and draws what came,
// so one that cannot be read leaves the others standing.
import { age, askAgeIfAsked, askToSignIn, call, email, signOut, signedIn } from "/account.js";
import { showFeedCount } from "/follow.js";
import { avatarHtml } from "/kit.js";

// What only a signed-in page draws (card.js, designs.js), fetched as the
// page starts when this browser has a sign-in, and not at all when not:
// the page a visitor who is not signed in gets is two lines and a button.
let counted;
let modelCard;
let showDesigns;
let drawing = null;
function drawn() {
  drawing ||= Promise.all([import("/card.js"), import("/designs.js")]).then(([cards, designs]) => {
    ({ counted, modelCard } = cards);
    ({ showDesigns } = designs);
  });
  return drawing;
}
if (signedIn()) drawn();

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const DAY = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric" });
const when = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");
let handle = "";

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

/// A model's card with a button under it, for something to do with it here.
function kept(model, action) {
  const box = make("div", "kept", modelCard(model));
  const button = make("button", "cta ghost small", action.label);
  button.type = "button";
  button.addEventListener("click", () => action.run(button, box));
  box.append(button);
  return box;
}

async function favourites() {
  const answer = await call("/api/people?op=favourites&page=1");
  const grid = $("favourites");
  grid.replaceChildren();
  const models = (answer.status === 200 ? answer.body.models : []).filter((m) => ID.test(String(m.id)));
  for (const model of models) {
    grid.append(kept(model, { label: "Let it go", run: async (button, box) => {
      button.disabled = true;
      const gone = await call(`/api/people?op=favourite&id=${model.id}`, { method: "POST", body: { on: false } });
      if (gone.status === 200) box.remove();
      else button.disabled = false;
      $("no-favourites").hidden = grid.children.length > 0;
    } }));
  }
  $("no-favourites").hidden = models.length > 0;
}

function listRow(list) {
  const row = document.createElement("div");
  row.className = "list-mine";
  row.dataset.id = list.id;
  const top = document.createElement("div");
  top.className = "list-top";
  const name = document.createElement("input");
  name.value = String(list.name);
  name.maxLength = 80;
  name.setAttribute("aria-label", "The collection's name");
  const open = document.createElement("label");
  open.className = "tick";
  const box = document.createElement("input");
  box.type = "checkbox";
  box.checked = Boolean(list.public);
  open.append(box, document.createTextNode(" Public"));
  if (document.documentElement.dataset.young === "yes") box.disabled = true;
  const save = document.createElement("button");
  save.type = "button";
  save.className = "cta ghost";
  save.textContent = "Save";
  const drop = document.createElement("button");
  drop.type = "button";
  drop.className = "cta ghost";
  drop.textContent = "Delete";
  const page = document.createElement("a");
  page.href = `/c/${list.id}`;
  page.textContent = "Its page";
  page.hidden = !list.public;
  const many = document.createElement("small");
  many.textContent = counted(list.count, "model");
  top.append(name, open, save, drop, page, many);
  const shown = document.createElement("details");
  const summary = document.createElement("summary");
  summary.textContent = "What is in it";
  const grid = document.createElement("div");
  grid.className = "models compact";
  shown.append(summary, grid);
  shown.addEventListener("toggle", async () => {
    if (!shown.open || grid.dataset.loaded) return;
    grid.dataset.loaded = "1";
    const answer = await call(`/api/people?op=collection&id=${list.id}&page=1`);
    for (const model of (answer.body.models || []).filter((m) => ID.test(String(m.id)))) {
      grid.append(kept(model, { label: "Take it out", run: async (button, card) => {
        button.disabled = true;
        const out = await call("/api/people?op=collect", { method: "POST",
          body: { collection: list.id, model: model.id, on: false } });
        if (out.status === 200) card.remove();
        else button.disabled = false;
      } }));
    }
  });
  save.addEventListener("click", async () => {
    save.disabled = true;
    const answer = await call("/api/people?op=collection", { method: "POST",
      body: { id: list.id, name: name.value, public: box.checked } });
    save.disabled = false;
    $("lists-said").textContent = answer.status === 200 ? `Saved "${answer.body.name}".`
      : answer.body.error || "That did not work just now.";
    if (answer.status === 200) page.hidden = !answer.body.public;
  });
  drop.addEventListener("click", async () => {
    if (!confirm(`Delete the collection "${name.value}"? The models in it are not touched.`)) return;
    const answer = await call(`/api/people?op=uncollection&id=${list.id}`, { method: "POST", body: {} });
    if (answer.status === 200) row.remove();
    else $("lists-said").textContent = answer.body.error || "That did not work just now.";
  });
  row.append(top, shown);
  return row;
}

/// Who you are in the gallery, at the top: your name, your page, your
/// counts; or, before you chose a name, where to choose one.
function drawHead(mine, follows) {
  const name = mine ? String(mine.name) : "";
  $("title").textContent = name || "Your account";
  // Their avatar, made from their handle as every page makes it (web/kit.js).
  $("initial").outerHTML = avatarHtml({ handle: mine?.handle || email() || "", name: name || email() || "B" },
    { size: "big", id: "initial" });
  const line = $("handle-line");
  line.replaceChildren();
  if (mine && HANDLE.test(String(mine.handle))) {
    const page = make("a", "", `brickworks.diy/u/${mine.handle}`);
    page.href = `/u/${mine.handle}`;
    line.append(page);
    if (follows && follows.ready) {
      // Said once there are any, as every count is: never "0 followers".
      if (Number(follows.followers)) line.append(` · ${counted(follows.followers, "follower")}`);
      if (Number(follows.following)) line.append(` · ${Number(follows.following).toLocaleString("en-US")} following`);
    }
  } else {
    line.append("Choose the name the gallery shows for you, under ");
    const to = make("a", "", "Settings");
    to.href = "#settings";
    line.append(to, ".");
  }
}

/// The sets you own (in the app, Build › My collection), and what in the
/// gallery they build, every part yours.
async function owned() {
  const [kept, shelves] = await Promise.all([
    call("/api/collection").catch(() => null),
    call("/api/share?op=shelves&mine=1").catch(() => null),
  ]);
  const said = $("owned-said");
  const counts = $("owned-counts");
  const row = $("owned-models");
  const sets = kept && kept.status === 200 && Array.isArray(kept.body.sets) ? kept.body.sets : [];
  const parts = kept && kept.status === 200 && Array.isArray(kept.body.parts) ? kept.body.parts : [];
  const pool = shelves && shelves.status === 200 ? shelves.body.mine : null;
  const pieces = pool ? Number(pool.pieces) || 0 : parts.reduce((all, one) => all + (Number(one.qty) || 0), 0);
  if (!sets.length && !parts.length && !pieces) {
    said.textContent = "Tell Brickworks what you own (in the app, Build › My collection…: a Rebrickable or "
      + "BrickLink export, or set numbers) and this shows what in the gallery you can build with it.";
    counts.hidden = true;
    row.hidden = true;
    $("owned-more").hidden = true;
    return;
  }
  const stat = (n, words) => make("li", "", make("b", "", Number(n).toLocaleString("en-US")), " ", make("span", "", words));
  const boxes = sets.reduce((all, one) => all + (Number(one.qty) || 1), 0);
  counts.replaceChildren(stat(boxes, boxes === 1 ? "set" : "sets"), stat(pieces, pieces === 1 ? "part" : "parts"));
  counts.hidden = false;
  const ready = shelves && shelves.status === 200 && shelves.body.ready
    ? (shelves.body.ready.models || []).filter((m) => m && ID.test(String(m.id))) : [];
  row.replaceChildren(...ready.map((model) => modelCard(model)));
  row.hidden = ready.length === 0;
  said.textContent = ready.length
    ? "Every part of these is in what you own: the most built and remixed first."
    : "Nothing in the gallery is all in what you own yet.";
  $("owned-more").hidden = false;
}

/// Whom you follow, for you alone. Where the server cannot list them yet
/// (ready: false), how many, from your profile's counts ([follows]).
async function following(follows) {
  const answer = await call("/api/people?op=following").catch(() => null);
  const list = $("following");
  list.replaceChildren();
  const people = answer && answer.status === 200 ? (answer.body.following || []) : null;
  if (!people) {
    $("following-said").textContent = (answer && answer.body && answer.body.error) || "Whom you follow could not be read just now.";
    return;
  }
  if (answer.body.ready === false) {
    const many = follows && follows.ready ? Number(follows.following) || 0 : null;
    $("following-said").textContent = many
      ? `You follow ${counted(many, "designer")}: what they share comes into your feed.`
      : many === 0 ? "Nobody yet. Press Follow on a designer’s page, or beside their name on a model’s, and what they share comes into your feed."
        : "What the designers you follow share comes into your feed.";
    return;
  }
  for (const one of people.filter((p) => HANDLE.test(String(p.handle)))) {
    const to = make("a", "pill", String(one.name || one.handle), make("small", "", `@${one.handle}`));
    to.href = `/u/${one.handle}`;
    list.append(make("li", "", to));
  }
  $("following-said").textContent = people.length
    ? `${counted(people.length, "designer")}: what they share comes into your feed.`
    : "Nobody yet. Press Follow on a designer’s page, or beside their name on a model’s, and what they share comes into your feed.";
}

/// The photos of your builds that show on your profile.
async function builds(mine) {
  const strip = $("builds-strip");
  strip.replaceChildren();
  if (!mine || !HANDLE.test(String(mine.handle))) {
    strip.hidden = true;
    return;
  }
  const answer = await call(`/api/people?op=profile&handle=${encodeURIComponent(mine.handle)}`).catch(() => null);
  const photos = answer && answer.status === 200 && Array.isArray(answer.body.built) ? answer.body.built : [];
  for (const photo of photos.filter((one) => ID.test(String(one.id)) && ID.test(String(one.model)))) {
    const img = make("img");
    img.src = `/api/people?op=photo_file&id=${photo.id}`;
    img.alt = photo.words ? String(photo.words) : `A photo of ${String(photo.model_name || "a build")}`;
    img.loading = "lazy";
    img.width = Number(photo.width) || 1200;
    img.height = Number(photo.height) || 900;
    const to = make("a", "", String(photo.model_name || "The model"));
    to.href = `/m/${photo.model}#photo-${photo.id}`;
    strip.append(make("figure", "build", img, make("figcaption", "", photo.words ? make("q", "", String(photo.words)) : "", to)));
  }
  strip.hidden = strip.children.length === 0;
  if (photos.length) $("builds-said").textContent = `${counted(photos.length, "photo")} of your builds, on your profile.`;
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
    document.documentElement.dataset.profile = "signed-out";
    return;
  }
  const [answer] = await Promise.all([call("/api/people?op=me"), drawn()]);
  if (answer.status === 401) {
    signOut();
    return load();
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  $("who").textContent = `Signed in as ${email()}. Only you see the address; the gallery shows the name above.`;
  $("delete-confirm").placeholder = email();
  // The age question, if this account has not answered it; and under 13,
  // no public profile or public list here (the server refuses them too).
  const answered = await askAgeIfAsked().catch(() => null);
  const young = Boolean(answered && answered.over_13 === false);
  $("young").hidden = !young;
  for (const field of $("profile-form").querySelectorAll("input, textarea, button[type=submit]")) field.disabled = young;
  document.documentElement.dataset.young = young ? "yes" : "no";
  const kept = answered || await age().catch(() => null);
  $("age-said").textContent = kept && kept.over_13 === true
    ? "You told Brickworks you are 13 or over. Only that is kept, never your date of birth."
    : kept && kept.over_13 === false
      ? "You told Brickworks you are under 13, so your profile and collections stay private. Only that is kept."
      : "Brickworks asks everyone once whether they are 13 or over, and keeps only that answer.";
  const mine = answer.body.profile;
  handle = mine ? String(mine.handle) : "";
  $("name").value = mine ? String(mine.name) : "";
  $("handle").value = handle;
  $("bio").value = mine && mine.bio ? String(mine.bio) : "";
  $("handle-shown").textContent = handle || "your-handle";
  drawShowcase(mine, answer.body.showcase, young);
  $("view").hidden = !mine;
  if (mine && HANDLE.test(handle)) $("view").href = `/u/${handle}`;
  const follows = mine && HANDLE.test(handle)
    ? await call(`/api/people?op=follows&handle=${encodeURIComponent(handle)}`).then((a) => (a.status === 200 ? a.body : null), () => null)
    : null;
  drawHead(mine, follows);
  const lists = $("lists");
  lists.replaceChildren();
  for (const list of answer.body.collections || []) if (ID.test(String(list.id))) lists.append(listRow(list));
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
  // Each of the rest asks for its own; one that fails leaves the others.
  await Promise.all([favourites(), showDesigns($("designs")), owned(), following(follows), builds(mine), claude()]
    .map((one) => Promise.resolve(one).catch(() => null)));
  document.documentElement.dataset.profile = "ready";
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

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in with your email address: we send you a code, no password.")) {
    showFeedCount().catch(() => null);
    load();
  }
});
$("sign-out").addEventListener("click", () => {
  signOut();
  showFeedCount().catch(() => null);
  load();
});
$("handle").addEventListener("input", () => {
  $("handle-shown").textContent = $("handle").value.trim().toLowerCase() || "your-handle";
});
$("profile-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  $("save").disabled = true;
  const answer = await call("/api/people?op=profile", { method: "POST", body: {
    handle: $("handle").value.trim().toLowerCase(), name: $("name").value, bio: $("bio").value } });
  $("save").disabled = false;
  if (answer.status !== 200) {
    $("profile-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("profile-said").textContent = "Saved.";
  $("view").hidden = false;
  if (HANDLE.test(String(answer.body.handle))) {
    handle = String(answer.body.handle);
    $("view").href = `/u/${handle}`;
  }
  drawHead({ handle, name: answer.body.name }, null);
});
/// What your profile shows besides its name (supabase/profile_shows.sql):
/// your links, a banner and pins, chosen from your models in the gallery.
/// Only once you have a profile, and once the server keeps them.
function drawShowcase(mine, showcase, young) {
  const form = $("showcase-form");
  form.hidden = !mine || !showcase || !showcase.ready;
  if (form.hidden) return;
  const models = (showcase.models || []).filter((one) => ID.test(String(one.id)));
  const fill = (select, chosen, pictured) => {
    select.replaceChildren(make("option", "", "None"));
    select.firstChild.value = "";
    for (const one of models) {
      if (pictured && !one.picture) continue;
      const option = make("option", "", String(one.name));
      option.value = one.id;
      select.append(option);
    }
    select.value = models.some((one) => one.id === chosen) ? chosen : "";
  };
  fill($("banner"), showcase.banner, true);
  for (const [at, select] of [...form.querySelectorAll("select[data-pin]")].entries()) fill(select, showcase.pins?.[at], false);
  $("link-1").value = showcase.links?.[0] || "";
  $("link-2").value = showcase.links?.[1] || "";
  for (const field of form.querySelectorAll("input, select, button[type=submit]")) field.disabled = young;
}
$("showcase-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const form = $("showcase-form");
  $("showcase-save").disabled = true;
  const pins = [...form.querySelectorAll("select[data-pin]")].map((select) => select.value).filter(Boolean);
  const answer = await call("/api/people?op=showcase", { method: "POST", body: {
    links: [$("link-1").value, $("link-2").value].map((one) => one.trim()).filter(Boolean),
    banner: $("banner").value || null, pins: [...new Set(pins)] } });
  $("showcase-save").disabled = false;
  if (answer.status !== 200) {
    $("showcase-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("link-1").value = answer.body.links?.[0] || "";
  $("link-2").value = answer.body.links?.[1] || "";
  $("showcase-said").textContent = "Saved. Your profile shows it within a minute.";
});
$("new-list").addEventListener("submit", async (event) => {
  event.preventDefault();
  const name = $("new-name").value.trim();
  if (!name) return;
  const answer = await call("/api/people?op=collection", { method: "POST", body: { name, public: false } });
  if (answer.status !== 200) {
    $("lists-said").textContent = answer.body.error || "That did not work just now.";
    return;
  }
  $("new-name").value = "";
  $("lists").prepend(listRow({ id: answer.body.id, name: answer.body.name, public: false, count: 0 }));
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

// The rail says which section is on the screen.
const rail = [...document.querySelectorAll(".subnav a")];
if ("IntersectionObserver" in window && rail.length) {
  const watch = new IntersectionObserver((seen) => {
    for (const one of seen) {
      if (!one.isIntersecting) continue;
      for (const a of rail) a.setAttribute("aria-current", String(a.getAttribute("href") === `#${one.target.id}`));
    }
  }, { rootMargin: "-30% 0px -60% 0px" });
  for (const a of rail) {
    const target = document.getElementById(a.getAttribute("href").slice(1));
    if (target) watch.observe(target);
  }
}

load();
