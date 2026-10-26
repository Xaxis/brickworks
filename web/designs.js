// Your models, as a designer (2026-10-19, supabase/designers.sql): how each
// model you shared is doing, for you alone. The last 30 days' opens of its
// page, builds finished, remixes and comments, the same in all since it was
// shared, and who built it, from the photos people posted ("I built it").
//
// On your own profile (/u/<you>: #designs-mine, which this fills only when
// the server says the page is yours) and on Account (/profile, which calls
// showDesigns). Asked with your sign-in, from /api/people?op=designs
// (api/_designers.js), which answers nobody else with anything of yours and
// is never kept by the CDN; the page the CDN keeps has none of it.
//
// Everything is put on the page as text.
import { call, signedIn } from "/account.js";

const ID = /^[A-Za-z0-9]{10}$/;
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const DATE = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const number = (n) => (Number(n) || 0).toLocaleString("en-US");
const plural = (n, one, many = `${one}s`) => `${number(n)} ${Number(n) === 1 ? one : many}`;

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

function link(href, text, className = "") {
  const a = make("a", className, text);
  a.href = href;
  return a;
}

/// One count: the last 30 days, large, and in all beneath.
function tile(kind, recent, ever, one, many, lead = false) {
  const li = make("li", lead ? "lead" : "", make("b", "", number(recent)), " ",
    make("span", "", Number(recent) === 1 ? one : many), make("small", "", `${number(ever)} in all`));
  li.dataset.earned = kind;
  return li;
}

/// What one model is: in the gallery or by link, credited or not, Tested.
function whatItIs(model) {
  const said = [model.listed ? "In the gallery" : "Shared by link"];
  if (!model.credited) said.push("without your name");
  if (model.tested) said.push("✓ Tested");
  if (model.test) said.push("a test model");
  return said.join(" · ");
}

function numbers(model) {
  const box = make("dl", "design-numbers");
  for (const [kind, label] of [["opens", "Opens"], ["builds", "Builds finished"], ["remixes", "Remixes"],
    ["comments", "Comments"]]) {
    const dd = make("dd", "", make("b", "", number(model[kind])), make("small", "", `${number(model[`${kind}_ever`])} in all`));
    dd.dataset.kind = kind;
    box.append(make("div", "", make("dt", "", label), dd));
  }
  return box;
}

/// Who built it: the photos people posted of their builds, with their names.
function builders(model) {
  const photos = (model.photos || []).filter((one) => ID.test(String(one.id)));
  if (!photos.length) return null;
  const strip = make("div", "build-strip");
  for (const one of photos) {
    const picture = document.createElement("img");
    picture.src = `/api/people?op=photo_file&id=${one.id}`;
    picture.alt = `A build of ${model.name}`;
    picture.width = Number(one.width) || 1;
    picture.height = Number(one.height) || 1;
    picture.loading = "lazy";
    picture.decoding = "async";
    const who = one.by && HANDLE.test(String(one.by.handle)) ? link(`/u/${one.by.handle}`, String(one.by.name))
      : make("span", "", "A builder with no profile");
    const figure = make("figure", "build", link(`/m/${model.id}#photo-${one.id}`, picture),
      make("figcaption", "", one.words ? make("q", "", String(one.words)) : null, who));
    figure.dataset.photo = one.id;
    strip.append(figure);
  }
  const more = Number(model.photos_count) - photos.length;
  return make("div", "design-builders",
    make("p", "", `Who built it: ${plural(model.builders, "person", "people")} posted ${plural(model.photos_count, "photo")}`,
      more > 0 ? make("span", "", " (", link(`/m/${model.id}#builds`, `${number(more)} more on its page`), ")") : null),
    strip);
}

function row(model) {
  const picture = model.thumb ? `/m/${model.id}.webp${/\?v=[a-z0-9]+$/.test(model.thumb) ? model.thumb.slice(model.thumb.indexOf("?")) : ""}`
    : model.image ? `/m/${model.id}.png` : "";
  const frame = make("a", `pic${picture ? "" : " none"}`);
  frame.href = `/m/${model.id}`;
  frame.tabIndex = -1;
  frame.setAttribute("aria-hidden", "true");
  if (picture) {
    const img = document.createElement("img");
    img.src = picture;
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    img.loading = "lazy";
    frame.append(img);
  } else {
    frame.textContent = "No picture";
  }
  const item = make("li", "design-row", frame, make("div", "design-main",
    make("h3", "", link(`/m/${model.id}`, String(model.name))), make("p", "design-meta", whatItIs(model)),
    numbers(model), builders(model)));
  item.dataset.id = model.id;
  return item;
}

/// Fill [box] with the signed-in designer's own numbers. [handle]: asked
/// from that profile's page, and drawn only when it is theirs. Says what it
/// drew on document.documentElement.dataset.designs: ready, empty, not-yet,
/// not-mine, signed-out or trouble.
export async function showDesigns(box, { handle = null, heading = "Your models, as a designer" } = {}) {
  const said = (state) => {
    document.documentElement.dataset.designs = state;
    return state;
  };
  if (!box) return said("none");
  if (!signedIn()) {
    box.hidden = true;
    return said("signed-out");
  }
  const asked = handle && HANDLE.test(handle) ? `&handle=${encodeURIComponent(handle)}` : "";
  const answer = await call(`/api/people?op=designs${asked}`).catch(() => null);
  if (!answer || answer.status !== 200) {
    box.hidden = Boolean(handle);
    box.replaceChildren(make("h2", "", heading),
      make("p", "note", (answer && answer.body && answer.body.error) || "Your numbers could not be read just now."));
    return said("trouble");
  }
  const mine = answer.body;
  if (!mine.mine) {
    box.hidden = true;
    box.replaceChildren();
    return said("not-mine");
  }
  const title = make("h2", "", heading);
  title.id = `${box.id || "designs"}-h`;
  box.setAttribute("aria-labelledby", title.id);
  const only = make("p", "private", "Only you see this: it is read with your sign-in and never kept by the site’s cache. "
    + `The last ${number(mine.days || 30)} days, and in all since each model was shared.`);
  if (!mine.ready) {
    box.replaceChildren(title, make("p", "note", "How your models are doing is not open on Brickworks yet."));
    box.hidden = false;
    return said("not-yet");
  }
  const models = (mine.models || []).filter((one) => ID.test(String(one.id)));
  if (!models.length) {
    box.replaceChildren(title, only, make("p", "note", "Nothing shared yet. Share a model from the app (Share, on its bar), "
      + "and how many open it, build it and remix it is here."));
    box.hidden = false;
    return said("empty");
  }
  const t = mine.totals || {};
  const totals = make("ul", "earned mine-totals",
    tile("opens", t.opens, t.opens_ever, "open", "opens", true),
    tile("builds", t.builds, t.builds_ever, "build finished", "builds finished", true),
    tile("remixes", t.remixes, t.remixes_ever, "remix", "remixes"),
    tile("comments", t.comments, t.comments_ever, "comment", "comments"));
  totals.setAttribute("aria-label", `Your models, the last ${number(mine.days || 30)} days`);
  // Opens are kept by the day only from when designers.sql went in: before
  // that, only in all.
  const from = Date.parse(mine.counted_from || "");
  const since = Date.parse(mine.since || "");
  const counting = Number.isFinite(from) && Number.isFinite(since) && from > since
    ? make("p", "note", `Opens are counted by the day from ${DATE.format(from)}; before that, only in all.`) : null;
  const list = make("ol", "design-rows", ...models.map(row));
  box.replaceChildren(title, only, totals, counting, list);
  box.hidden = false;
  // The pictures on the first screen asked for at once: a lazy one there
  // came last (the first row at 1280 and 1920, site277). Which they are is
  // known once they are laid out.
  for (const img of list.querySelectorAll("img")) {
    const at = img.getBoundingClientRect();
    if (at.top < innerHeight && at.bottom > 0) img.loading = "eager";
  }
  return said("ready");
}

// On a profile's page: drawn only when it is the signed-in designer's own.
const own = document.getElementById("designs-mine");
const page = own ? own.closest(".person[data-handle]") : null;
if (own && page) showDesigns(own, { handle: page.dataset.handle, heading: "How your models are doing" });
