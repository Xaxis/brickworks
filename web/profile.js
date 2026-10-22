// Your profile, /profile (profile.html): your page as everybody sees it at
// /u/<handle>, with Edit profile, and the tabs only you see beside its
// own (docs/SOCIAL.md U6, D9). Models and Builds as everybody sees them;
// Saved (favourites, collections, whom you follow), Sets (what you own and
// what it builds) and Insights (how your models are doing, designs.js).
// Signed in with no profile yet, a name and a handle to make one. The
// settings are at /settings (settings.js).
//
// Every word — a name, a handle, a collection's, a model's — goes on the
// page as text, never as markup; a link is built from an id or a handle
// only when it is one. Each tab asks for its own when it is first opened
// and draws what came, so one that cannot be read leaves the others.
import { askAgeIfAsked, askToSignIn, call, signOut, signedIn } from "/account.js";
import { showFeedCount } from "/follow.js";
import { avatarHtml, toast } from "/kit.js";

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
const SINCE = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
const TABS = ["models", "builds", "saved", "sets", "insights"];
// Models are shown a few rows at a time, so the page's first screen is
// your profile and its work, not a wall of cards: Show more for the rest.
const STEP = 8;

// What the server said of you: op=me (your profile, collections, mail,
// what your profile shows and what you may pin) and op=profile (your page
// as everybody sees it), and whether you are under 13.
let mine = null;
let shown = null;
let young = false;
// Each tab is drawn once, when first opened, and again after a change.
const drawnTabs = new Set();
let models = { queue: [], page: 0, more: false };

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

const handleOf = () => (mine && mine.profile && HANDLE.test(String(mine.profile.handle)) ? String(mine.profile.handle) : "");

/// A model's card with a button under it, for something to do with it here.
function kept(model, action) {
  const box = make("div", "kept", modelCard(model));
  const button = make("button", "cta ghost small", action.label);
  button.type = "button";
  button.addEventListener("click", () => action.run(button, box));
  box.append(button);
  return box;
}

// ---------------------------------------------------------------------------
// The head: your page's, as /u/<handle> draws it (api/people.js profilePage).

/// The row of numbers: what your work earned and who follows you, each
/// said once there is one ("0 likes" never), builds finished first.
function numbersOf(body) {
  const earned = body && body.designer && Number(body.designer.models) > 0 ? body.designer : null;
  const rows = [
    ["builds", earned?.builds, "build finished", "builds finished"],
    ["remixes", earned?.remixes, "remix", "remixes"],
    ["models", earned ? earned.models : body?.models_count, "model", "models"],
    ["likes", earned ? earned.likes : body?.likes, "like", "likes"],
    ["followers", body?.followers, "follower", "followers"],
    ["following", body?.following, "following", "following"],
  ];
  return rows.filter(([, n]) => Number(n) > 0).map(([kind, n, one, many]) => {
    const li = make("li", "", make("b", "", Number(n).toLocaleString("en-US")), " ", make("span", "", Number(n) === 1 ? one : many));
    li.dataset.stat = kind;
    return li;
  });
}

function drawHead() {
  const person = mine.profile;
  const handle = handleOf();
  const body = shown || {};
  const name = String(body.name || person.name || "");
  $("title").textContent = name;
  $("avatar").outerHTML = avatarHtml({ handle, name }, { size: "huge", id: "avatar" });
  const designer = body.designer && Number(body.designer.models) > 0;
  const since = Date.parse(body.since || person.created_at || "");
  const line = $("handle-line");
  line.replaceChildren(`@${handle} · `, make("span", "", designer ? "Designer" : "Builder"),
    Number.isFinite(since) ? ` · building here since ${SINCE.format(since)}` : "");
  line.querySelector("span").dataset.role = "";
  const bio = body.bio ?? person.bio;
  $("bio-shown").textContent = bio ? String(bio) : "";
  $("bio-shown").hidden = !bio;
  const links = $("links-shown");
  links.replaceChildren(...(Array.isArray(body.links) ? body.links : []).filter((one) => /^https:\/\//.test(String(one.href)))
    .map((one) => {
      const a = make("a", "", String(one.said || one.href));
      a.href = String(one.href);
      a.rel = "ugc nofollow noopener";
      a.target = "_blank";
      return make("li", "", a);
    }));
  links.hidden = links.children.length === 0;
  $("numbers").replaceChildren(...numbersOf(body));
  const banner = $("banner-shown");
  const pictured = body.banner && ID.test(String(body.banner)) ? String(body.banner) : "";
  banner.replaceChildren();
  if (pictured) {
    const img = make("img");
    img.src = `/m/${pictured}.png`;
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    img.decoding = "async";
    banner.append(img);
  }
  banner.hidden = !pictured;
  $("me").classList.toggle("bannered", Boolean(pictured));
  $("me").classList.toggle("designer", Boolean(designer));
  const pins = (Array.isArray(body.pins) ? body.pins : []).filter((one) => ID.test(String(one.id)));
  $("pins").replaceChildren(...pins.map((card) => modelCard(card, { earned: Boolean(designer) })));
  $("pinned").hidden = pins.length === 0;
  $("view").href = `/u/${handle}`;
  $("edit").disabled = young;
  // The tabs' counts, once there is one.
  const counts = { models: Number(body.models_count) || 0,
    builds: (Array.isArray(body.built) ? body.built.length : 0) + (designer ? (body.designer.photos || []).length : 0) };
  for (const [tab, n] of Object.entries(counts)) {
    const said = document.querySelector(`#tabs [data-tab="${tab}"] .n`);
    said.textContent = n.toLocaleString("en-US");
    said.hidden = !n;
  }
}

/// Your page as everybody sees it, asked again: after a save, and once at
/// the start. Test models are asked for too: they are only ever your own.
async function readShown() {
  const handle = handleOf();
  if (!handle) {
    shown = null;
    return;
  }
  const answer = await call(`/api/people?op=profile&handle=${encodeURIComponent(handle)}&tests=1`).catch(() => null);
  // None for an account the site's owner took out of the gallery, or under
  // 13: the head is drawn from what you saved.
  shown = answer && answer.status === 200 ? answer.body : null;
}

// ---------------------------------------------------------------------------
// The tabs.

async function drawModels() {
  const grid = $("my-models");
  grid.replaceChildren();
  const body = shown;
  const earned = Boolean(body && body.designer && Number(body.designer.models) > 0);
  models = { queue: (body && Array.isArray(body.models) ? body.models : []).filter((one) => ID.test(String(one.id))),
    page: 1, more: Boolean(body && body.more), earned };
  showModels();
  $("no-models").hidden = grid.children.length > 0;
}

/// The next few of your models; the next page of them asked for when the
/// ones read are all shown.
async function showModels({ focus = false } = {}) {
  const grid = $("my-models");
  if (!models.queue.length && models.more) {
    const handle = handleOf();
    const answer = await call(`/api/people?op=profile&handle=${encodeURIComponent(handle)}&tests=1&page=${models.page + 1}`)
      .catch(() => null);
    if (!answer || answer.status !== 200) {
      toast("That did not load just now. Try again in a minute.");
      return;
    }
    models.page += 1;
    models.more = Boolean(answer.body.more);
    models.queue = (answer.body.models || []).filter((one) => ID.test(String(one.id)));
  }
  const next = models.queue.splice(0, STEP).map((model) => modelCard(model, { earned: models.earned }));
  grid.append(...next);
  $("models-paging").hidden = !(models.queue.length || models.more);
  // A keyboard is taken to the first new card, not left at the end.
  if (focus) next[0]?.querySelector("a.open")?.focus({ preventScroll: true });
}

/// A photo of a real build, as a person's page shows one.
function buildFigure(photo, { by = false } = {}) {
  const img = make("img");
  img.src = `/api/people?op=photo_file&id=${photo.id}`;
  img.alt = `A build of ${String(photo.model_name || "a model")}`;
  img.width = Number(photo.width) || 1;
  img.height = Number(photo.height) || 1;
  img.loading = "lazy";
  img.decoding = "async";
  const open = make("a", "", img);
  open.href = `/m/${photo.model}#photo-${photo.id}`;
  const model = make("a", "", String(photo.model_name || "The model"));
  model.href = `/m/${photo.model}`;
  const caption = make("figcaption", "", photo.words ? make("q", "", String(photo.words)) : null, model);
  if (by) {
    const who = photo.by && HANDLE.test(String(photo.by.handle)) ? make("a", "", String(photo.by.name)) : null;
    if (who) who.href = `/u/${photo.by.handle}`;
    caption.append(", built by ", who || "a builder");
  }
  const figure = make("figure", "build", open, caption);
  figure.id = `photo-${photo.id}`;
  return figure;
}

function drawBuilds() {
  const body = shown || {};
  const usable = (list) => (Array.isArray(list) ? list : []).filter((one) => ID.test(String(one.id)) && ID.test(String(one.model)));
  const built = usable(body.built);
  const designer = body.designer && Number(body.designer.models) > 0 ? body.designer : null;
  const theirs = designer ? usable(designer.photos) : [];
  $("builds-strip").replaceChildren(...built.map((one) => buildFigure(one)));
  $("builds-made").hidden = built.length === 0;
  $("builds-of-strip").replaceChildren(...theirs.map((one) => buildFigure(one, { by: true })));
  $("builds-of").hidden = theirs.length === 0;
  if (theirs.length) {
    const people = Number(designer.builders) || 0;
    $("builds-of-said").textContent = `${people === 1 ? "One person" : `${people.toLocaleString("en-US")} people`} posted photos `
      + "of their real builds of your models.";
  }
  $("builds-said").hidden = built.length + theirs.length > 0;
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
  if (young) box.disabled = true;
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
  const shownIn = document.createElement("details");
  const summary = document.createElement("summary");
  summary.textContent = "What is in it";
  const grid = document.createElement("div");
  grid.className = "models compact";
  shownIn.append(summary, grid);
  shownIn.addEventListener("toggle", async () => {
    if (!shownIn.open || grid.dataset.loaded) return;
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
  row.append(top, shownIn);
  return row;
}

/// Whom you follow, for you alone. Where the server cannot list them yet
/// (ready: false), how many, from your page's counts.
async function following() {
  const answer = await call("/api/people?op=following").catch(() => null);
  const list = $("following");
  list.replaceChildren();
  const people = answer && answer.status === 200 ? (answer.body.following || []) : null;
  if (!people) {
    $("following-said").textContent = (answer && answer.body && answer.body.error) || "Whom you follow could not be read just now.";
    return;
  }
  const nobody = "Nobody yet. Press Follow on a designer’s page, or beside their name on a model’s, and what they share comes into your feed.";
  if (answer.body.ready === false) {
    const many = shown ? Number(shown.following) || 0 : null;
    $("following-said").textContent = many ? `You follow ${counted(many, "designer")}: what they share comes into your feed.`
      : many === 0 ? nobody : "What the designers you follow share comes into your feed.";
    return;
  }
  for (const one of people.filter((p) => HANDLE.test(String(p.handle)))) {
    const to = make("a", "pill", String(one.name || one.handle), make("small", "", `@${one.handle}`));
    to.href = `/u/${one.handle}`;
    to.insertAdjacentHTML("afterbegin", avatarHtml({ handle: one.handle, name: one.name }, { size: "small" }));
    list.append(make("li", "", to));
  }
  $("following-said").textContent = people.length
    ? `${counted(people.length, "designer")}: what they share comes into your feed.` : nobody;
}

async function drawSaved() {
  const lists = $("lists");
  lists.replaceChildren();
  for (const list of mine.collections || []) if (ID.test(String(list.id))) lists.append(listRow(list));
  await Promise.all([favourites(), following()].map((one) => one.catch(() => null)));
}

/// The sets you own (in the app, Build › My collection), and what in the
/// gallery they build, every part yours.
async function drawSets() {
  const [owned, shelves] = await Promise.all([
    call("/api/collection").catch(() => null),
    call("/api/share?op=shelves&mine=1").catch(() => null),
  ]);
  const said = $("owned-said");
  const counts = $("owned-counts");
  const row = $("owned-models");
  const sets = owned && owned.status === 200 && Array.isArray(owned.body.sets) ? owned.body.sets : [];
  const parts = owned && owned.status === 200 && Array.isArray(owned.body.parts) ? owned.body.parts : [];
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

const DRAW = { models: drawModels, builds: drawBuilds, saved: drawSaved, sets: drawSets,
  insights: () => showDesigns($("designs")) };

/// The tabs there are: Models and Builds only with a profile.
const tabsNow = () => TABS.filter((tab) => handleOf() || !["models", "builds"].includes(tab));

/// Shows [tab], drawing it the first time, and says so in the address so a
/// reload or a link comes back to it.
async function choose(tab, { push = false } = {}) {
  const there = tabsNow();
  const chosen = there.includes(tab) ? tab : there[0];
  for (const link of document.querySelectorAll("#tabs [data-tab]")) {
    link.hidden = !there.includes(link.dataset.tab);
    if (link.dataset.tab === chosen) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  for (const panel of document.querySelectorAll("#work [data-panel]")) panel.hidden = panel.dataset.panel !== chosen;
  const address = new URL(location.href);
  if (chosen === there[0]) address.searchParams.delete("tab");
  else address.searchParams.set("tab", chosen);
  history[push ? "pushState" : "replaceState"](null, "", address.pathname + address.search + address.hash);
  if (!drawnTabs.has(chosen)) {
    drawnTabs.add(chosen);
    await Promise.resolve(DRAW[chosen]()).catch(() => null);
  }
  return chosen;
}

for (const link of document.querySelectorAll("#tabs [data-tab]")) {
  link.addEventListener("click", (event) => {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) return;
    event.preventDefault();
    choose(link.dataset.tab, { push: true });
  });
}
addEventListener("popstate", () => {
  if (signedIn() && mine) choose(new URLSearchParams(location.search).get("tab") || "");
});
$("models-more").addEventListener("click", () => showModels({ focus: true }));

// ---------------------------------------------------------------------------
// Making your profile, and Edit profile.

const form = $("profile-form");
const dialog = $("edit-dialog");
// What the dialog was filled with, so a save sends only what changed.
let filled = null;

/// The form as a start (a name and a handle, in the page) or as Edit
/// profile (everything your page shows, in its dialog).
function placeForm(start) {
  if (start) $("start").append(form);
  else dialog.append(form);
  for (const part of form.querySelectorAll("[data-more]")) part.hidden = start;
  $("showcase").hidden = start || !(mine.showcase && mine.showcase.ready) || young;
  $("save").textContent = start ? "Make my profile" : "Save";
  for (const field of form.querySelectorAll("input, textarea, select, button[type=submit]")) field.disabled = young;
}

function fillForm() {
  const person = mine.profile || {};
  $("name").value = person.name ? String(person.name) : "";
  $("handle").value = person.handle ? String(person.handle) : "";
  $("bio").value = person.bio ? String(person.bio) : "";
  $("handle-shown").textContent = $("handle").value || "your-handle";
  $("avatar-edit").outerHTML = avatarHtml({ handle: $("handle").value, name: $("name").value || "?" }, { size: "big", id: "avatar-edit" });
  const showcase = mine.showcase || {};
  const choices = (showcase.models || []).filter((one) => ID.test(String(one.id)));
  const fill = (select, chosen, pictured) => {
    select.replaceChildren(make("option", "", "None"));
    select.firstChild.value = "";
    for (const one of choices) {
      if (pictured && !one.picture) continue;
      const option = make("option", "", String(one.name));
      option.value = one.id;
      select.append(option);
    }
    select.value = choices.some((one) => one.id === chosen) ? chosen : "";
  };
  fill($("banner"), showcase.banner, true);
  for (const [at, select] of [...form.querySelectorAll("select[data-pin]")].entries()) fill(select, showcase.pins?.[at], false);
  $("link-1").value = showcase.links?.[0] || "";
  $("link-2").value = showcase.links?.[1] || "";
  filled = showcaseFields();
  $("profile-said").textContent = "";
}

function showcaseFields() {
  return { links: [$("link-1").value, $("link-2").value].map((one) => one.trim()).filter(Boolean),
    banner: $("banner").value || null,
    pins: [...new Set([...form.querySelectorAll("select[data-pin]")].map((select) => select.value).filter(Boolean))] };
}

function openEdit() {
  if (!handleOf() || young) return;
  fillForm();
  placeForm(false);
  dialog.showModal();
  $("name").focus();
}

$("edit").addEventListener("click", openEdit);
$("cancel").addEventListener("click", () => dialog.close());
$("handle").addEventListener("input", () => {
  $("handle-shown").textContent = $("handle").value.trim().toLowerCase() || "your-handle";
});
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const start = !handleOf();
  $("save").disabled = true;
  const said = (words) => {
    $("profile-said").textContent = words;
    $("save").disabled = false;
  };
  const answer = await call("/api/people?op=profile", { method: "POST", body: {
    handle: $("handle").value.trim().toLowerCase(), name: $("name").value, bio: start ? "" : $("bio").value } });
  if (answer.status !== 200) return said(answer.body.error || "That did not work just now.");
  // Links, the banner and pins: only what was changed, so a pin the list
  // here cannot offer (a model taken out of the gallery since) is kept.
  if (!start && mine.showcase && mine.showcase.ready && !young) {
    const now = showcaseFields();
    const changed = {};
    if (JSON.stringify(now.links) !== JSON.stringify(filled.links)) changed.links = now.links;
    if (now.banner !== filled.banner) changed.banner = now.banner;
    if (JSON.stringify(now.pins) !== JSON.stringify(filled.pins)) changed.pins = now.pins;
    if (Object.keys(changed).length) {
      const kept = await call("/api/people?op=showcase", { method: "POST", body: changed });
      if (kept.status !== 200) {
        await refresh();
        return said(`Your name was saved; the rest was not: ${kept.body.error || "that did not work just now."}`);
      }
    }
  }
  said("Saved.");
  await refresh();
  if (dialog.open) dialog.close();
  toast(start ? "Your profile is made" : "Saved. Your page shows it within a minute.");
});

/// Everything asked again and drawn: after a save, your page shows it at
/// once, with no reload.
async function refresh() {
  const answer = await call("/api/people?op=me");
  if (answer.status === 200) mine = answer.body;
  await readShown();
  draw();
  for (const tab of ["models", "builds"]) drawnTabs.delete(tab);
  await choose(new URLSearchParams(location.search).get("tab") || "");
}

/// The page for what is known: the start or your profile's head.
function draw() {
  const handle = handleOf();
  $("start").hidden = Boolean(handle);
  $("me").hidden = !handle;
  if (handle) {
    drawHead();
    if (!dialog.open) placeForm(false);
  } else {
    fillForm();
    placeForm(true);
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
  mine = answer.body;
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  // The age question, if this account has not answered it; and under 13,
  // no public profile or public list here (the server refuses them too).
  const answered = await askAgeIfAsked().catch(() => null);
  young = Boolean(answered && answered.over_13 === false);
  $("young").hidden = !young;
  document.documentElement.dataset.young = young ? "yes" : "no";
  await readShown();
  draw();
  drawnTabs.clear();
  await choose(new URLSearchParams(location.search).get("tab") || "");
  // From Settings' Edit profile.
  if (new URLSearchParams(location.search).get("edit") === "1") {
    const address = new URL(location.href);
    address.searchParams.delete("edit");
    history.replaceState(null, "", address.pathname + address.search);
    openEdit();
  }
  document.documentElement.dataset.profile = "ready";
}

$("share").addEventListener("click", async () => {
  const url = `${location.origin}/u/${handleOf()}`;
  if (navigator.share && matchMedia("(pointer: coarse)").matches) {
    try {
      await navigator.share({ title: `${mine.profile.name} on Brickworks`, url });
      return;
    } catch (trouble) {
      if (trouble?.name === "AbortError") return;
    }
  }
  try {
    await navigator.clipboard.writeText(url);
    toast("Link copied");
  } catch {
    toast(`Could not copy it: your page is ${url}`);
  }
});
$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in with your email address: we send you a code, no password.")) {
    showFeedCount().catch(() => null);
    load();
  }
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

load();
