// Post it elsewhere (unit postkit): on a model's page, for its designer,
// Share's sheet offers a kit for each place a model is posted to (web/
// card.js postPlaces), made here in their browser from what the page has
// published: its picture, the 3D view for more angles and a turn (the
// page's own scene, drawn in the clip's worker, web/turntable-worker.js),
// its parts list and its words. Each kit is checked against its place's
// rules (web/post-rules.js), and says what fails. On a phone whose browser
// shares files, they go to the phone's share sheet; elsewhere, one zip.
// Brickworks posts nothing itself, anywhere.
//
// Asked for by web/model-page.js only once the page knows the person
// looking is its designer: nobody else loads it. Nothing is fetched that
// the page does not load itself: the picture is the one on the page, the
// parts list is the page's own (its promise, [parts]), and the scene and
// its parts' geometry are what its View in 3D loads, read once and kept
// in the worker while the page is open, so a second kit asks for nothing.
//
// <html data-kit> says how the last went (making, made, failed) and
// window.brickworksKit what it made, for tools/web/postkit_flow.mjs.
import { say } from "/card.js";
import { copy } from "/share-sheet.js";
import { easel } from "/turntable-clip.js";
import { LIMITS, OPEN, checksOf, keepsAll, planOf, postText, sizeSaid, slugOf, wordsOf, zipOf } from "/post-rules.js";

// What the worker drew, kept while the page is open: key -> {blob, width,
// height, drawn}; and the turn, once.
const drawnStills = new Map();
let drawnTurn = null;
let worker = null;
let pictureMade = null;

/// The places' names, as the sheet says them.
let placeNames = {};

/// Post it elsewhere in [sheet], for the model [facts] (its page's
/// #post-facts): shown, each place's button making its kit. [parts]() is
/// the page's own parts list (a promise of parts.json, or null).
export function startPostKits(sheet, { facts, parts }) {
  const group = sheet.querySelector("#post-kits");
  if (!group || group.dataset.ready) return;
  group.dataset.ready = "1";
  group.hidden = false;
  placeNames = Object.fromEntries([...group.querySelectorAll("[data-kit]")].map((button) => [button.dataset.kit, button.textContent]));
  for (const button of group.querySelectorAll("[data-kit]")) {
    button.addEventListener("click", () => openKit(button.dataset.kit, { facts, parts }));
  }
}

/// An element: [tag] with [attrs] and [children] (strings or elements).
function el(tag, attrs = {}, ...children) {
  const made = document.createElement(tag);
  for (const [name, value] of Object.entries(attrs)) {
    if (value === false || value === null || value === undefined) continue;
    if (name === "text") made.textContent = value;
    else made.setAttribute(name, value === true ? "" : String(value));
  }
  made.append(...children.filter((child) => child !== null && child !== undefined && child !== ""));
  return made;
}

/// The kit's dialog, made once and drawn again for each place.
function dialogOf() {
  let dialog = document.getElementById("post-kit");
  if (dialog) return dialog;
  dialog = el("dialog", { class: "post-kit", id: "post-kit", "aria-labelledby": "post-kit-h" });
  dialog.addEventListener("close", () => {
    for (const shown of dialog.querySelectorAll("[data-url]")) URL.revokeObjectURL(shown.dataset.url);
  });
  document.body.append(dialog);
  return dialog;
}

// Which kit the dialog is showing: a kit still being made when another
// is asked for is not shown in its place.
let asked = 0;

/// The kit for [place], made and shown.
async function openKit(place, { facts, parts }) {
  const mine = ++asked;
  const dialog = dialogOf();
  const name = placeNames[place] || place;
  const said = el("p", { class: "said", role: "status", text: say("Making the kit…") });
  const heading = el("h2", { id: "post-kit-h", tabindex: "-1", text: say("A kit for {place}", { place: name }) });
  const close = el("button", { type: "submit", class: "cta ghost", value: "close", text: say("Close") });
  dialog.replaceChildren(el("form", { method: "dialog" }, heading,
    el("p", { text: say("Its pictures, its words and its files, in {place}'s form and rules, with this model's link. "
      + "You post it yourself, from your own account: Brickworks posts nothing.", { place: name }) }),
    said, el("div", { class: "actions" }, close)));
  if (!dialog.open) dialog.showModal();
  heading.focus();
  document.documentElement.dataset.kit = "making";
  const started = performance.now();
  let made;
  try {
    made = await makeKit(place, facts, parts, (done, of) => {
      said.textContent = say("Drawing its pictures: {done} of {of}…", { done, of });
    });
  } catch {
    made = null;
  }
  if (!dialog.open || mine !== asked) return;
  if (!made) {
    said.textContent = say("The kit could not be made just now.");
    said.dataset.tone = "bad";
    document.documentElement.dataset.kit = "failed";
    return;
  }
  const ms = Math.round(performance.now() - started);
  show(dialog, place, name, facts, made, said, close);
  window.brickworksKit = { place, ms, checks: made.checks, zipBytes: made.zip.size, why: made.why || "",
    files: made.files.map((file) => ({ name: file.name, bytes: file.bytes.length, type: file.type })),
    images: made.images.map((one) => ({ name: one.name, width: one.width, height: one.height, drawn: one.drawn })),
    clip: made.clip ? { kind: made.clip.kind, width: made.clip.width, height: made.clip.height, ms: made.clip.ms,
      drawnAt: made.clip.drawnAt } : null,
    clipWhy: made.clipWhy, timing: made.timing, words: made.words };
  document.documentElement.dataset.kit = "made";
}

/// The page's picture of it, whole, on the clip's backdrop, as a JPEG:
/// {blob, width, height, drawn}, or null where the page has none drawn.
async function pictureOf() {
  if (pictureMade) return pictureMade;
  const shown = document.querySelector(".model-page .picture img");
  if (!shown) return null;
  // Still on its way: waited on for a few seconds, as it leads the kit.
  if (!shown.complete) {
    await new Promise((done) => {
      shown.addEventListener("load", done, { once: true });
      shown.addEventListener("error", done, { once: true });
      setTimeout(done, 5000);
    });
  }
  if (!shown.complete || shown.naturalWidth < 64) return null;
  const width = shown.naturalWidth;
  const height = shown.naturalHeight;
  const page = easel({ width, height, wordmark: false });
  page.paint(shown);
  const canvas = page.canvas;
  const blob = canvas.convertToBlob ? await canvas.convertToBlob({ type: "image/jpeg", quality: 0.92 })
    : await new Promise((done) => canvas.toBlob(done, "image/jpeg", 0.92));
  if (!blob) return null;
  pictureMade = { blob, width, height, drawn: page.drawn };
  return pictureMade;
}

/// What the worker draws of [plan] that is not drawn yet: {stills, clip,
/// why}; [progress](done, of) as each comes.
function draw(plan, sceneAt, progress) {
  const stills = plan.stills.filter((one) => !drawnStills.has(one.key));
  const turn = plan.turn && !drawnTurn ? plan.turn : null;
  if (!stills.length && !turn) return Promise.resolve({ why: "" });
  if (typeof Worker !== "function" || typeof OffscreenCanvas !== "function") return Promise.resolve({ why: "cannot-draw" });
  if (!worker) worker = new Worker("/turntable-worker.js");
  return new Promise((done) => {
    const heard = (event) => {
      const answer = event.data || {};
      if (typeof answer.progress === "number") {
        progress(answer.progress, answer.of);
        return;
      }
      worker.removeEventListener("message", heard);
      worker.removeEventListener("error", failed);
      if (answer.how !== "drawn") {
        done({ why: String(answer.how || "failed") });
        return;
      }
      for (const one of answer.stills) drawnStills.set(one.key, one);
      if (answer.clip) drawnTurn = answer.clip;
      done({ why: turn && !answer.clip ? "no-turn" : "", clipWhy: answer.clipWhy || "", timing: answer.timing || null });
    };
    const failed = () => {
      worker.removeEventListener("message", heard);
      worker.removeEventListener("error", failed);
      worker = null;
      done({ why: "failed" });
    };
    worker.addEventListener("message", heard);
    worker.addEventListener("error", failed);
    worker.postMessage({ kit: { scene: sceneAt, coarse: matchMedia("(pointer: coarse)").matches, stills, turn } });
  });
}

/// The kit for [place]: its images ({name, blob, width, height, drawn}),
/// its turn, its words, its files and its zip, and each rule checked.
async function makeKit(place, facts, parts, progress) {
  const picture = await pictureOf();
  const plan = planOf(place, { hasPicture: Boolean(picture) });
  const sceneAt = new URL(facts.scene, location.href).href;
  const { why, clipWhy = "", timing = null } = await draw(plan, sceneAt, progress);
  const slug = slugOf(facts.name);
  const images = [];
  const named = (n, ext) => `${String(n).padStart(2, "0")}-${slug}.${ext}`;
  if (plan.picture && picture) images.push({ ...picture, name: named(1, "jpg") });
  for (const still of plan.stills) {
    const one = drawnStills.get(still.key);
    if (one) images.push({ ...one, name: named(images.length + 1, "jpg") });
  }
  const clip = plan.turn ? drawnTurn : null;
  const words = wordsOf(place, facts);
  const list = place === "rebrickable" && parts ? await parts() : null;
  const csv = list && typeof list.rebrickable_csv === "string" ? list.rebrickable_csv : "";
  const checks = checksOf(place, facts, { images, clip, words, csv });
  const files = [];
  for (const image of images) files.push({ name: image.name, type: "image/jpeg", bytes: new Uint8Array(await image.blob.arrayBuffer()) });
  if (clip) files.push({ name: `${slug}-turn.${clip.kind}`, type: clip.type, bytes: clip.bytes });
  if (csv) files.push({ name: `${slug}-parts-rebrickable.csv`, type: "text/csv", bytes: new TextEncoder().encode(csv) });
  const text = postText(place, facts, words, checks, placeNames[place] || place);
  files.push({ name: "post.txt", type: "text/plain", bytes: new TextEncoder().encode(text) });
  const zip = zipOf(files);
  return { images, clip, words, csv, checks, files, zip, why, clipWhy, timing };
}

/// [made] shown in [dialog]: its pictures, its words to copy, its rules,
/// and the ways to take it.
function show(dialog, place, name, facts, made, said, close) {
  const form = dialog.querySelector("form");
  const fails = made.checks.filter((one) => one.how === "fails");
  said.textContent = fails.length
    ? say("Made. It does not keep {n} of {place}'s rules: see below.", { n: fails.length, place: name })
    : made.why ? say("Made, with its picture alone: this browser could not draw it in 3D here.")
      : say("Made: it keeps each of {place}'s rules it can.", { place: name });
  said.dataset.tone = fails.length ? "bad" : "";
  const pictures = el("div", { class: "kit-pictures", role: "group", "aria-label": say("Its pictures") });
  for (const image of made.images) {
    const url = URL.createObjectURL(image.blob);
    pictures.append(el("img", { src: url, "data-url": url, alt: `${image.name}, ${image.width} × ${image.height}`, width: image.width,
      height: image.height, loading: "lazy" }));
  }
  if (made.clip) {
    const url = URL.createObjectURL(new Blob([made.clip.bytes], { type: made.clip.type }));
    pictures.append(el("video", { src: url, "data-url": url, muted: true, loop: true, playsinline: true, controls: true,
      "aria-label": say("Its turn, {width} × {height}", { width: made.clip.width, height: made.clip.height }) }));
  }
  const field = (id, label, value, rows = 0) => {
    const box = rows ? el("textarea", { id, rows, readonly: true, spellcheck: "false" }) : el("input", { id, readonly: true, spellcheck: "false" });
    box.value = value;
    const button = el("button", { type: "button", class: "cta ghost", text: say("Copy") });
    button.addEventListener("click", async () => {
      const done = await copy(box.value);
      said.textContent = done ? say("Copied: paste it on {place}", { place: name }) : say("It did not copy just now: select it and copy it yourself");
      said.dataset.tone = "";
      if (!done) box.select();
    });
    return el("div", { class: "copy-row" }, el("label", {}, label, box), button);
  };
  const words = el("div", { class: "kit-words" },
    made.words.title ? field("kit-title", say("Title"), made.words.title) : null,
    made.words.flair ? el("p", {}, `${say("Flair")}: `, el("b", { text: made.words.flair })) : null,
    field("kit-words", place === "instagram" ? say("Caption") : place === "legomoc" || place === "lego"
      ? say("The words to paste, as a comment under it") : say("Its description"), made.words.words, 6),
    made.words.tags ? field("kit-tags", say("Tags"), made.words.tags) : null);
  const ordered = [...made.checks].sort((a, b) => (a.how === "fails" ? 0 : 1) - (b.how === "fails" ? 0 : 1));
  const rules = el("ul", { class: "kit-rules ticks" }, ...ordered.map((one) => el("li", { "data-how": one.how, "data-rule": one.id },
    el("b", { text: one.rule }),
    one.how === "fails" && one.said ? ` ${one.said}.` : one.how === "yours" ? ` ${say("Yours to keep.")}` : "",
    " ", el("a", { href: one.page, target: "_blank", rel: "noopener noreferrer", text: say("Its rule") },
      el("span", { class: "visually-hidden", text: ` ${say("(opens in a new tab)")}` })))));
  const note = place === "ideas"
    ? el("p", { class: "note", text: say("Brickworks is not the LEGO Group. LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this site.") })
    : null;
  const actions = el("div", { class: "actions" });
  const files = made.files.map((file) => new File([file.bytes], file.name, { type: file.type }));
  const phone = matchMedia("(pointer: coarse)").matches;
  const shares = phone && typeof navigator.share === "function" && typeof navigator.canShare === "function"
    && (() => { try { return navigator.canShare({ files }); } catch { return false; } })();
  if (shares) {
    const share = el("button", { type: "button", class: "cta", "data-take": "share", text: say("Share the files") });
    share.addEventListener("click", async () => {
      try {
        await navigator.share({ files, title: made.words.title || facts.name, text: made.words.words });
        taken(place, "share");
      } catch (trouble) {
        if (trouble && trouble.name !== "AbortError") said.textContent = say("That did not open just now: save the kit instead");
      }
    });
    actions.append(share);
  }
  const zip = el("button", { type: "button", class: shares ? "cta ghost" : "cta", "data-take": "zip",
    text: say("Save the kit ({size})", { size: `.zip, ${sizeSaid(made.zip.size)}` }) });
  zip.addEventListener("click", () => {
    const url = URL.createObjectURL(new Blob(made.zip.parts, { type: "application/zip" }));
    const link = el("a", { href: url, download: `${slugOf(facts.name)}-${place}-kit.zip` });
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
    said.textContent = say("Saved: {name}", { name: link.download });
    said.dataset.tone = "";
    taken(place, "zip");
  });
  actions.append(zip, el("a", { class: "cta ghost", href: OPEN[place], target: "_blank", rel: "noopener noreferrer",
    "data-open": place, text: say("Open {place}", { place: name }) },
  el("span", { class: "visually-hidden", text: ` ${say("(opens in a new tab)")}` })), close);
  const tooBig = made.zip.size > LIMITS.zipBytes;
  if (tooBig) zip.disabled = true;
  // The heading, its words and the line that says how it went stay where
  // they are, so the heading keeps the focus it was given.
  const kept = new Set([form.querySelector("h2"), form.querySelector("p"), said]);
  for (const child of [...form.children]) if (!kept.has(child)) child.remove();
  form.append(...[pictures, words, el("h3", { text: keepsAll(made.checks) ? say("Its rules, kept") : say("Its rules") }), rules, note,
    el("p", { class: "note", text: say("Brickworks posts nothing: you post this yourself, from your own account.") }), actions]
    .filter(Boolean));
}

/// The kit taken: counted as the site counts what a person does (web/
/// tally.js, share.kit_<place>), and said on <html data-kit-taken>.
function taken(place, how) {
  document.documentElement.dataset.kitTaken = `${place}:${how}`;
  dispatchEvent(new CustomEvent("brickworks:kit", { detail: { place } }));
}
