// Your profile, /profile (profile.html): the name the gallery shows for you,
// your favourites and your collections, from /api/people (api/people.js),
// signed in with the app's own sign-in in this browser (account.js).
//
// Every word — a name, a handle, a collection's, a model's — goes on the
// page as text, never as markup; a link is built from an id or a handle
// only when it is one.
import { askToSignIn, call, email, signOut, signedIn } from "/account.js";

const $ = (id) => document.getElementById(id);
const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;

function counted(n, one, many) {
  const value = Number(n) || 0;
  return `${value.toLocaleString("en-US")} ${value === 1 ? one : many || `${one}s`}`;
}

/// A model's card, as the gallery draws it, with a button under it when
/// there is something to do with it here.
function card(model, action) {
  const box = document.createElement("div");
  box.className = "kept";
  const link = document.createElement("a");
  link.className = "model";
  link.href = `/m/${model.id}`;
  link.dataset.id = model.id;
  const frame = document.createElement("div");
  frame.className = "frame";
  const picture = model.thumb ? `/m/${model.id}.webp` : model.image ? `/m/${model.id}.png` : "";
  if (picture) {
    const img = document.createElement("img");
    img.src = picture;
    img.alt = String(model.name);
    img.width = 1200;
    img.height = 630;
    img.loading = "lazy";
    frame.append(img);
  } else {
    frame.classList.add("none");
    frame.textContent = "No picture";
  }
  const words = document.createElement("div");
  words.className = "words";
  const name = document.createElement("b");
  name.textContent = String(model.name);
  const about = document.createElement("span");
  about.textContent = model.author ? `${counted(model.parts, "part")}, by ${model.author}` : counted(model.parts, "part");
  words.append(name, about);
  link.append(frame, words);
  box.append(link);
  if (action) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "cta ghost small";
    button.textContent = action.label;
    button.addEventListener("click", () => action.run(button, box));
    box.append(button);
  }
  return box;
}

async function favourites() {
  const answer = await call("/api/people?op=favourites&page=1");
  const grid = $("favourites");
  grid.replaceChildren();
  const models = (answer.status === 200 ? answer.body.models : []).filter((m) => ID.test(String(m.id)));
  for (const model of models) {
    grid.append(card(model, { label: "Let it go", run: async (button, box) => {
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
  const save = document.createElement("button");
  save.type = "button";
  save.className = "cta ghost small";
  save.textContent = "Save";
  const drop = document.createElement("button");
  drop.type = "button";
  drop.className = "cta ghost small";
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
  grid.className = "models";
  shown.append(summary, grid);
  shown.addEventListener("toggle", async () => {
    if (!shown.open || grid.dataset.loaded) return;
    grid.dataset.loaded = "1";
    const answer = await call(`/api/people?op=collection&id=${list.id}&page=1`);
    for (const model of (answer.body.models || []).filter((m) => ID.test(String(m.id)))) {
      grid.append(card(model, { label: "Take it out", run: async (button, kept) => {
        button.disabled = true;
        const out = await call("/api/people?op=collect", { method: "POST",
          body: { collection: list.id, model: model.id, on: false } });
        if (out.status === 200) kept.remove();
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

async function load() {
  $("loading").hidden = true;
  if (!signedIn()) {
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    document.documentElement.dataset.profile = "signed-out";
    return;
  }
  const answer = await call("/api/people?op=me");
  if (answer.status === 401) {
    signOut();
    return load();
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  $("who").textContent = `Signed in as ${email()}. Only you see the address; the gallery shows the name below.`;
  const mine = answer.body.profile;
  $("name").value = mine ? String(mine.name) : "";
  $("handle").value = mine ? String(mine.handle) : "";
  $("bio").value = mine && mine.bio ? String(mine.bio) : "";
  $("handle-shown").textContent = mine ? String(mine.handle) : "your-handle";
  $("view").hidden = !mine;
  if (mine && HANDLE.test(String(mine.handle))) $("view").href = `/u/${mine.handle}`;
  const lists = $("lists");
  lists.replaceChildren();
  for (const list of answer.body.collections || []) if (ID.test(String(list.id))) lists.append(listRow(list));
  await favourites();
  document.documentElement.dataset.profile = "ready";
}

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in with your email address: we send you a code, no password.")) load();
});
$("sign-out").addEventListener("click", () => {
  signOut();
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
  if (HANDLE.test(String(answer.body.handle))) $("view").href = `/u/${answer.body.handle}`;
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
