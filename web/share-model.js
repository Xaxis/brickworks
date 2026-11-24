// Share a model you made, from its file (bringyours, 2026-11-20,
// docs/SOCIAL.md round 8): /share-model, the gallery's Share yours. A
// builder whose model was made in BrickLink Studio, LDCad, MLCad or any
// other LDraw program chooses its file, and it has its own page (/m/<id>)
// as one shared from the studio has: its parts list the server's own count
// of the file and its steps the file's own (api/share.js), its picture
// drawn here by the site's 3D view (web/viewer3d.js), as the studio's
// Share draws its own.
//
//   An LDraw file (.ldr, .mpd, .dat) is read as it is, a Studio file (.io)
//   through web/studio-io.js. An LDD file (.lxf) is the studio's to open,
//   one tap away; anything else is refused in words.
//   Share it publishes the file, listed as chosen (api/share.js: every
//   refusal, the age rule and may_publish among them, comes before anything
//   is kept), draws its pictures from the site's own scene of it
//   (/m/<id>/scene.json), and puts them on its version 1 (?op=pictures),
//   then goes to it: one publish, as the app's Share is, and its link never
//   taken down (byfix, 2026-11-21: taking it down and sharing it again cost
//   two, and at the hour's last one left the link down for the hour).
//   What a file says of its builder unasked is left out, and said
//   (web/private-lines.js, which the server holds to as well).
//
// What a check reads (tools/web/share_model_flow.mjs): window.brickworksShare.

import { askAgeIfAsked, askToSignIn, call, nameFirst, signedIn } from "/account.js";
import { appAt, langAt, number, say, told } from "/card.js";
import { withoutPrivateLines } from "/private-lines.js";
import { readStudioIo, TROUBLE } from "/studio-io.js";

const $ = (id) => document.getElementById(id);
const page = $("share-model");

/// The server's limits (api/share.js), and the app's for its pictures
/// (src/ui/share_panel.gd): a little under the server's, as the app sends.
const MOST = { model: 2 * 1024 * 1024, name: 80, about: 1000, png: 560 * 1024, thumb: 60 * 1024 };
/// The link's picture, and the gallery card's, drawn twice as big and made
/// smaller (share_panel.gd CARD, THUMB).
const CARD = [1200, 630];
const THUMB = [480, 360];
/// The plain ground under a link's picture for other sites
/// (src/ui/picture.gd GROUND_TOP, GROUND_FOOT).
const GROUND = ["rgb(237, 240, 245)", "rgb(204, 212, 222)"];
const LDRAW = new Set(["ldr", "mpd", "dat"]);
const STUDIO = new Set(["io"]);
const LDD = new Set(["lxf", "lxfml"]);
/// How long its picture may take before it is shared without one.
const DRAW_MS = 75000;
/// The biggest Studio file looked into: a model in one is at most 2 MB
/// unpacked, whatever else Studio keeps beside it.
const MOST_STUDIO_FILE = 256 * 1024 * 1024;
/// How recent a link of the person's must be to be the one a lost answer
/// made (api/share.js PICTURES_WINDOW_MS is how long it can take pictures).
const LOST_MS = 15 * 60 * 1000;

const state = window.brickworksShare = { state: "choose", id: "", file: "", timings: {}, pictures: {}, errors: [] };
const mark = (what) => { state.timings[what] = Math.round(performance.now()); };

let chosen = null;
let busy = false;

// ---------------------------------------------------------------------------
// Choosing the file.

const input = $("file");
input.addEventListener("change", () => { if (input.files && input.files[0]) choose(input.files[0]); });
$("pick").addEventListener("click", () => input.click());
// Dropped anywhere on the page while it is choosing: the browser would
// otherwise open the file in place of the page.
for (const name of ["dragenter", "dragover"]) {
  document.addEventListener(name, (event) => {
    if (!event.dataTransfer || ![...event.dataTransfer.types].some((one) => one.toLowerCase() === "files")) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = held() ? "none" : "copy";
    if (!held()) $("drop").classList.add("over");
  });
}
document.addEventListener("dragleave", (event) => { if (!event.relatedTarget) $("drop").classList.remove("over"); });
document.addEventListener("drop", (event) => {
  if (!event.dataTransfer || !event.dataTransfer.files.length) return;
  event.preventDefault();
  $("drop").classList.remove("over");
  if (!held()) choose(event.dataTransfer.files[0]);
});
/// Sharing: a file dropped then is not another to share.
function held() { return busy; }

/// [file] read, and what it is said: the form to share it, the studio for
/// an LDD file, or why it cannot be shared. Whatever is in the file, said:
/// one this page cannot follow is damaged.
async function choose(file) {
  try {
    await readFile(file);
  } catch (trouble) {
    state.errors.push(String(trouble?.message || trouble));
    refuse(studioTrouble(TROUBLE.DAMAGED, file.name));
  }
}

async function readFile(file) {
  mark("chosen");
  state.file = file.name;
  state.id = "";
  chosen = null;
  job = null;
  show("choose");
  refuse("");
  $("ldd").hidden = true;
  const ext = (file.name.match(/\.([^./\\]+)$/) || ["", ""])[1].toLowerCase();
  if (LDD.has(ext)) {
    state.state = "ldd";
    $("ldd").hidden = false;
    $("ldd-open").focus();
    return;
  }
  const empty = say("{file} is empty, or could not be read.", { file: file.name });
  if (!file.size) return refuse(empty);
  // A zip is read as Studio's whatever it is called; any other file as
  // LDraw's text, if it is text.
  const head = new Uint8Array(await file.slice(0, 4).arrayBuffer().catch(() => new ArrayBuffer(0)));
  const zipped = head[0] === 0x50 && head[1] === 0x4b;
  if (!zipped && !LDRAW.has(ext) && !STUDIO.has(ext)) {
    return refuse(say("{file} is not a model file. Choose an LDraw file (.ldr, .mpd or .dat) or a BrickLink Studio file (.io).",
      { file: file.name }));
  }
  // Too big to share, said before it is read at all: an LDraw file is its
  // own text (UTF-8, or a code page that only grows as UTF-8, with a
  // byte-order mark at most), and a Studio file far bigger than any model.
  if (file.size > (zipped || STUDIO.has(ext) ? MOST_STUDIO_FILE : MOST.model + 3)) return refuse(tooBig(file.name, file.size));
  const bytes = new Uint8Array(await file.arrayBuffer().catch(() => new ArrayBuffer(0)));
  if (!bytes.length) return refuse(empty);
  let text = "";
  let notes = [];
  if (zipped) {
    const read = await readStudioIo(bytes);
    if (read.error === TROUBLE.TOO_BIG) return refuse(tooBigUnpacked(file.name, read.size));
    if (read.error) return refuse(studioTrouble(read.error, file.name));
    text = read.text;
    if (read.carried) {
      notes.push(say(read.carried === 1 ? "A part made in Part Designer comes with it." : "{n} parts made in Part Designer come with it.",
        { n: number(read.carried) }));
    }
    if (read.prints) notes.push(say("Studio’s own prints and stickers show as their plain parts."));
  } else {
    if (bytes.subarray(0, 4096).includes(0)) {
      return refuse(say("{file} is not a model file: it is not text. Choose an LDraw file (.ldr, .mpd or .dat) or a BrickLink Studio file (.io).",
        { file: file.name }));
    }
    text = textOf(bytes);
  }
  if (!/^\s*1\s/m.test(text)) {
    return refuse(say("{file} has no parts in it, so there is nothing to share.", { file: file.name }));
  }
  // What it says of its builder unasked, left out, as the server leaves it
  // out of whatever is published, and said.
  const kept = withoutPrivateLines(text);
  text = kept.text;
  if (kept.emails) notes.push(say("The email address in its Author line is left out."));
  if (kept.paths) notes.push(say("Lines naming folders on your computer are left out."));
  const size = new TextEncoder().encode(text).length;
  if (size > MOST.model) return refuse(zipped ? tooBigUnpacked(file.name, size) : tooBig(file.name, size));
  chosen = { text, file: file.name, size };
  state.state = "details";
  // The form is this file's: words typed for one chosen before are not
  // carried onto it.
  $("details").reset();
  $("licence").dispatchEvent(new Event("change"));
  $("name").value = nameOf(text, file.name);
  $("read").textContent = [say("Read from {file}.", { file: file.name }), ...notes].join(" ");
  said("name-said", "");
  said("about-said", "");
  said("form-said", "");
  show("details");
  mark("read");
  // Its picture is drawn by the site's 3D view: fetched while the form is
  // filled in, not after Share it.
  import("/viewer3d.js").catch(() => {});
  $("share").focus();
}

/// A file too big to share, in words: its size, and the most.
function tooBig(file, size) {
  return say("{file} is {size} MB; a shared model is at most 2 MB. Share it from the app, which keeps a big model smaller.",
    { file, size: megabytes(size) });
}

/// A Studio file whose model is too big once unpacked, in words.
function tooBigUnpacked(file, size) {
  return say("{file} is {size} MB unpacked; a shared model is at most 2 MB. Share it from the app, which keeps a big model smaller.",
    { file, size: megabytes(size) });
}

/// Megabytes to a tenth, rounded up: just over the most is never said as it.
const megabytes = (size) => (Math.ceil((size * 10) / 1048576) / 10).toLocaleString(globalThis.brickworksLang?.locale || "en-US", { maximumFractionDigits: 1 });

/// Studio's file troubles, in words.
function studioTrouble(key, file) {
  if (key === TROUBLE.NO_MODEL || key === TROUBLE.NOT_ZIP) {
    return say("{file} is not a model file: there is no model in it. Choose an LDraw file (.ldr, .mpd or .dat) or a BrickLink Studio file (.io).", { file });
  }
  if (key === TROUBLE.LOCKED || key === TROUBLE.AES192) {
    return say("{file} is locked in a way this page cannot open. Open it in BrickLink Studio, save it again, and choose it here.", { file });
  }
  if (key === TROUBLE.BROWSER) {
    return say("This browser cannot unpack a Studio file. Try a newer browser, or export an LDraw file from Studio.");
  }
  return say("{file} is damaged: part of it could not be read. Save it again in BrickLink Studio and choose it here.", { file });
}

/// A text file's words: UTF-8 as LDraw says, else the Windows code page
/// older programs wrote; a byte-order mark left off.
function textOf(bytes) {
  let text;
  try {
    text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    text = new TextDecoder("windows-1252").decode(bytes);
  }
  return text.replace(/^﻿/, "");
}

/// What the model is called: the title its first section gives (its first
/// line), unless that is a file's name or Studio's "Untitled Model"; then
/// its Name:, without the extension; then the file's own name.
function nameOf(text, file) {
  const lines = text.split(/\r?\n/).map((one) => one.trim());
  const plain = (one) => cleanName(one.replace(/\.(?:ldr|mpd|dat|io)$/i, ""));
  let at = 0;
  while (at < lines.length && !lines[at]) at += 1;
  if (/^0\s+FILE\s/i.test(lines[at] || "")) at += 1;
  const title = (lines[at] || "").match(/^0\s+(.+)$/);
  if (title && !/^(?:!|Name:|Author:|FILE\s|NOFILE|STEP|\/\/)/i.test(title[1])
      && !/^Untitled Model$/i.test(title[1].trim()) && !/\.(?:ldr|mpd|dat|io)$/i.test(title[1].trim())) {
    const name = cleanName(title[1]);
    if (name) return name.slice(0, MOST.name);
  }
  const named = lines.find((one) => /^0\s+Name:/i.test(one));
  const fromName = named ? plain(named.replace(/^0\s+Name:\s*/i, "")) : "";
  return (fromName || plain(file) || say("My model")).slice(0, MOST.name);
}

/// A name as the server keeps it (api/share.js cleanText): no control
/// characters, no invisible ones, each run of spaces one.
function cleanName(given) {
  return String(given || "").replace(/[\u0000-\u001f\u007f​-‍⁠﻿]+/g, " ").replace(/\s+/g, " ").trim();
}

$("again").addEventListener("click", () => {
  chosen = null;
  input.value = "";
  state.state = "choose";
  show("choose");
  $("pick").focus();
});

$("licence").addEventListener("change", () => {
  const licence = $("licence").value;
  $("licence-said").textContent = licence === "cc-by-sa-4.0" ? say("As CC BY, and what others make from it is shared the same way.")
    : licence === "all-rights-reserved" ? say("Others may look at it and build it for themselves, and ask you before sharing it.")
      : say("Anyone may share it, change it and build on it, crediting you.");
});

// ---------------------------------------------------------------------------
// Sharing it.

$("details").addEventListener("submit", (event) => {
  event.preventDefault();
  // Enter held, or pressed twice: one share.
  if (busy) return;
  share();
});
$("retry").addEventListener("click", () => { if (!busy) share(); });

/// What the person asked, checked here first: refused in words beside its
/// field, nothing sent.
function asked() {
  const name = cleanName($("name").value);
  const about = $("about").value.replace(/[​-‍⁠﻿]/g, "").trim();
  let ok = true;
  if (!name) {
    said("name-said", say("Give it a name."));
    ok = false;
  } else if (name.length > MOST.name) {
    said("name-said", say("A name is at most {most} characters; this one is {n}.", { most: MOST.name, n: name.length }));
    ok = false;
  } else said("name-said", "");
  if (about.length > MOST.about) {
    said("about-said", say("What it is is at most {most} characters; this is {n}.", { most: number(MOST.about), n: number(about.length) }));
    ok = false;
  } else said("about-said", "");
  if (!ok) {
    ($("name-said").hidden ? $("about") : $("name")).focus();
    return null;
  }
  return { name, description: about, licence: $("licence").value, listed: $("listed").checked };
}

async function share() {
  if (!chosen) return;
  const given = asked();
  if (!given) return;
  said("form-said", "");
  busy = true;
  $("share").disabled = true;
  try {
    if (!signedIn()) {
      const yes = await askToSignIn("Sign in to share your model: it gets a page of its own, under your name.");
      if (!yes) return;
    }
    const age = await askAgeIfAsked({ pending: true });
    if (age && age.refused) return;
    // Under their name, as the page promises: its page heads it with the
    // profile its credit names and Follow beside it (api/share.js puts the
    // profile's name for any credit sent). This page sent none, so every
    // model shared from it went out with no name and nobody who liked it
    // could follow its designer (sitewalk2, 2026-11-24). With no profile,
    // Make your profile first, as before any public act (nameFirst); Skip
    // shares it with no name. Never asked of an account the server keeps
    // from a profile (under 13): the publish says why in its own words.
    const profile = await nameFirst();
    await publish({ ...given, author: profile ? String(profile.name || "") : "" });
  } finally {
    busy = false;
    $("share").disabled = false;
  }
}

/// The steps, each said as it goes: those before it done, it the current.
function step(name) {
  const all = [...$("progress").children];
  const now = all.findIndex((one) => one.dataset.step === name);
  all.forEach((one, at) => {
    one.dataset.done = String(at < now);
    if (at === now) one.setAttribute("aria-current", "step");
    else one.removeAttribute("aria-current");
  });
}

/// How far a share of the chosen file got, so Try again goes on from
/// there: the link once made and its version, its pictures once drawn (null
/// for none), why it is not listed when it was asked to be, and whether the
/// publish's answer was lost on the way back.
let job = null;

async function publish(given) {
  const model = chosen.text;
  job = job || { id: "", version: 0, pictures: undefined, unlisted: "", lost: false };
  state.state = "working";
  show("working");
  $("stuck").hidden = true;
  status("");
  // The form is gone, and with it the button pressed: what goes on now is
  // said here, so the reader's place is here.
  $("working-h").focus();
  mark("share");
  if (!job.id && job.lost) {
    // Shared already, perhaps, with only its answer lost: a link of theirs
    // made a moment ago with this name and this file is that one.
    step("send");
    const made = await madeAlready(given.name, chosen.size);
    if (made) {
      job.id = state.id = made.id;
      job.lost = false;
    }
  }
  if (!job.id) {
    step("send");
    const body = { name: given.name, author: given.author || undefined, model, description: given.description || undefined,
      licence: given.licence, listed: given.listed };
    let first = await send(body);
    // Kept from the gallery (the hour's listings, the age rule for a
    // listing, a model taken out of it): shared by its link all the same.
    // Refused, it was not counted, so this is still the one publish.
    if (given.listed && first.status !== 0 && listingRefused(first)) {
      job.unlisted = sentence(first);
      first = await send({ ...body, listed: false });
    }
    if (first.status === 0) {
      job.lost = true;
      return stuck(say("The network did not answer, so it is not known whether it was shared. Share it again, and a link it made already is used, not a second one."), true);
    }
    if (first.status >= 400 || !first.body?.id) {
      job = null;
      return back(sentence(first, say("Brickworks could not share it just now. Try again in a minute.")));
    }
    job.id = state.id = first.body.id;
    job.version = Number(first.body.version) || 0;
    job.lost = false;
    mark("published");
  }
  const id = job.id;
  if (job.pictures === undefined) {
    step("draw");
    status(say("Drawing its picture: a big model takes a while."));
    job.pictures = await draw(id, given.name).catch((trouble) => { state.errors.push(String(trouble?.message || trouble)); return null; });
    state.pictures = { image: Boolean(job.pictures?.image), cutout: Boolean(job.pictures?.cutout), thumb: Boolean(job.pictures?.thumb) };
    mark("drawn");
  }
  const pictures = job.pictures;
  step("publish");
  status("");
  let unpictured = "";
  if (!pictures) {
    unpictured = say("Its picture could not be drawn here, so it is shared without one. Share it again from the app for a picture.");
  } else {
    // Its pictures put on the version just published: no second publish.
    const put = await call(`/api/share?op=pictures&id=${encodeURIComponent(id)}`,
      { method: "POST", body: { ...(job.version ? { version: job.version } : {}), ...pictures } }).catch(() => ({ status: 0, body: null }));
    if (put.status === 0) {
      return stuck(say("It is shared, but the network did not answer as its picture went on its page. Try again to put it there."));
    }
    if (put.status >= 400) {
      unpictured = `${say("It is shared, but its picture could not be put on its page:")} ${sentence(put)}`;
    }
  }
  mark("done");
  const unlisted = job.unlisted;
  job = null;
  if (unlisted || unpictured) {
    state.state = unlisted ? "unlisted" : "unpictured";
    status([unlisted ? say("It is shared by its link, but not listed in the gallery: {why}", { why: unlisted }) : "", unpictured]
      .filter(Boolean).join(" "));
    $("retry").hidden = true;
    $("to-page").href = `${langAt()}/m/${id}`;
    $("to-page").hidden = false;
    $("stuck").hidden = false;
    $("to-page").focus();
    return;
  }
  arrive(id);
}

/// Whether a publish was refused only for its listing, so it can be shared
/// by its link instead: a model taken out of the gallery (409), the age rule
/// for a listing (422), the hour's listings (429, which says "listed"; the
/// hour's publishing says "published", and is refused either way).
function listingRefused(answer) {
  const { error = "" } = answer.body || {};
  if (answer.status === 409) return true;
  if (answer.status === 422) return /\blist/i.test(String(error));
  return answer.status === 429 && /\blisted\b/i.test(String(error));
}

/// What the server answered, as a sentence in the page's language: the
/// hour's limits in the page's own words, anything else told() and made a
/// sentence; [otherwise] when it said nothing.
function sentence(answer, otherwise = "") {
  const { error = "" } = answer?.body || {};
  if (answer?.status === 429) {
    return /\blisted\b/i.test(String(error))
      ? say("You have listed a lot in the gallery in the last hour.")
      : say("You have shared a lot in the last hour. Try again in an hour: your file and what you wrote stay here while this page is open.");
  }
  const said = told(error, otherwise);
  if (!said) return "";
  const capital = said.charAt(0).toLocaleUpperCase(globalThis.brickworksLang?.locale || "en-US") + said.slice(1);
  return /[.!?]$/.test(capital) ? capital : `${capital}.`;
}

/// A link of the person's own made in the last few minutes with this name
/// and this many bytes of model, or null: what a share whose answer was lost
/// made, if it made anything.
async function madeAlready(name, bytes) {
  const mine = await call("/api/share?op=mine").catch(() => ({ status: 0, body: null }));
  if (mine.status !== 200) return null;
  const now = Date.now();
  return (mine.body?.shared || []).find((row) => row.published && row.name === name && row.bytes === bytes
    && now - Date.parse(row.updated_at || 0) < LOST_MS) || null;
}

/// A publish, with what went wrong on the way as a status of 0.
async function send(body) {
  try {
    return await call("/api/share", { method: "POST", body });
  } catch {
    return { status: 0, body: null };
  }
}

function arrive(id) {
  job = null;
  state.state = "done";
  location.assign(`${langAt()}/m/${id}`);
}

/// Back to the form, nothing kept, with why.
function back(words) {
  state.state = "details";
  state.errors.push(words);
  show("details");
  said("form-said", words);
  $("share").focus();
}

/// Stopped part way, with why and Try again.
function stuck(words, unknown = false) {
  state.state = "stuck";
  state.errors.push(words);
  status(words);
  $("retry").textContent = unknown ? say("Share it again") : say("Try again");
  $("retry").hidden = false;
  $("to-page").hidden = true;
  $("stuck").hidden = false;
  $("retry").focus();
}

// ---------------------------------------------------------------------------
// Its pictures.

/// The link's pictures, from the site's scene of it: {image, cutout,
/// thumb}, each base64 as api/share.js takes it, any left out that came
/// out too big; null when none could be drawn.
async function draw(id, name) {
  if (!webgl()) throw new Error("no WebGL");
  const shell = $("frame");
  const ratio = Math.min(window.devicePixelRatio || 1, 2);
  stageAt(CARD, ratio);
  const three = await import("/viewer3d.js");
  const started = performance.now();
  three.open3d(shell, { scene: `/m/${id}/scene.json`, name, app: appAt(`view=${id}`), look: "app", how: "touch", anyway: true });
  const live = window.brickworks3d;
  for (;;) {
    if (live.state === "ready" && live.view && live.view.loaded >= live.view.meshesWanted) break;
    if (live.state === "failed") throw new Error(live.errors.join("; ") || "the 3D view failed");
    if (performance.now() - started > DRAW_MS) throw new Error("drawing took too long");
    await new Promise((done) => setTimeout(done, 100));
  }
  const view = live.view;
  const card = shot(view, CARD);
  if (!drawn(card)) throw new Error("nothing was drawn");
  const image = await pngUnder(onGround(card));
  const cutout = await pngUnder(card);
  stageAt([THUMB[0] * 2, THUMB[1] * 2], ratio);
  view.size();
  const thumb = await webpUnder(scaled(shot(view, [THUMB[0] * 2, THUMB[1] * 2]), THUMB));
  stageAt(CARD, ratio);
  view.size();
  const out = {};
  if (image) out.image = await base64(image);
  if (cutout) out.cutout = await base64(cutout);
  if (thumb) out.thumb = await base64(thumb);
  return out.image || out.cutout ? out : null;
}

function webgl() {
  try {
    return Boolean(document.createElement("canvas").getContext("webgl2"));
  } catch {
    return false;
  }
}

/// The 3D view drawn at [size] pixels exactly, whatever the screen's
/// density, and shown scaled to the page's column.
function stageAt([w, h], ratio) {
  const stage = $("stage");
  stage.style.width = `${w / ratio}px`;
  stage.style.height = `${h / ratio}px`;
  fitStage();
}

function fitStage() {
  const stage = $("stage");
  const frame = $("frame");
  const w = stage.offsetWidth;
  const h = stage.offsetHeight;
  if (!w || !h) return;
  frame.style.aspectRatio = `${w} / ${h}`;
  stage.style.transform = `scale(${frame.clientWidth / w})`;
}
new ResizeObserver(fitStage).observe($("frame"));

function canvas(w, h) {
  const out = document.createElement("canvas");
  out.width = w;
  out.height = h;
  return out;
}

/// What the view draws now, on nothing.
function shot(view, [w, h]) {
  view.render(true);
  const out = canvas(w, h);
  const pen = out.getContext("2d");
  pen.imageSmoothingQuality = "high";
  pen.drawImage(view.renderer.domElement, 0, 0, w, h);
  return out;
}

/// Whether anything is in [picture].
function drawn(picture) {
  const small = scaled(picture, [64, 34]);
  const dots = small.getContext("2d").getImageData(0, 0, 64, 34).data;
  for (let at = 3; at < dots.length; at += 4) if (dots[at] > 8) return true;
  return false;
}

function scaled(picture, [w, h]) {
  const out = canvas(w, h);
  const pen = out.getContext("2d");
  pen.imageSmoothingQuality = "high";
  pen.drawImage(picture, 0, 0, w, h);
  return out;
}

/// [picture] on the plain ground other sites show it on.
function onGround(picture) {
  const out = canvas(picture.width, picture.height);
  const pen = out.getContext("2d");
  const ground = pen.createLinearGradient(0, 0, 0, picture.height);
  ground.addColorStop(0, GROUND[0]);
  ground.addColorStop(1, GROUND[1]);
  pen.fillStyle = ground;
  pen.fillRect(0, 0, picture.width, picture.height);
  pen.drawImage(picture, 0, 0);
  return out;
}

const blobOf = (picture, type, quality) => new Promise((done) => picture.toBlob(done, type, quality));

/// A PNG under the server's limit: smaller if it must be (share_panel.gd
/// _png_under), null if even that is too big.
async function pngUnder(picture) {
  let png = await blobOf(picture, "image/png");
  if (png && png.size > MOST.png) png = await blobOf(scaled(picture, [800, 420]), "image/png");
  return png && png.size <= MOST.png ? png : null;
}

/// The gallery card's WebP, as the app makes it; null where the browser
/// makes no WebP (it gives a PNG instead) or it is too big.
async function webpUnder(picture) {
  let webp = await blobOf(picture, "image/webp", 0.8);
  if (webp && webp.type === "image/webp" && webp.size > MOST.thumb) webp = await blobOf(picture, "image/webp", 0.55);
  return webp && webp.type === "image/webp" && webp.size <= MOST.thumb ? webp : null;
}

async function base64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let text = "";
  for (let at = 0; at < bytes.length; at += 0x8000) text += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
  return btoa(text);
}

// ---------------------------------------------------------------------------
// The page.

function show(which) {
  page.dataset.state = which;
  $("choose").hidden = which !== "choose";
  $("details").hidden = which !== "details";
  $("working").hidden = which !== "working";
}

function refuse(words) {
  const box = $("refused");
  box.textContent = words;
  box.hidden = !words;
  if (words) {
    state.state = "refused";
    state.errors.push(words);
    input.value = "";
  }
}

function said(id, words) {
  $(id).textContent = words;
  $(id).hidden = !words;
}

function status(words) {
  $("status").textContent = words;
}
