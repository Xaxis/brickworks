// One group of the Notifications page as it is drawn (web/notifications.js),
// and as the owner's console previews an announcement before it goes
// (web/admin-announce.js): what a person will see is drawn by the same code.
// A model's group with its picture and each thing that happened to it; the
// achievements', a challenge's, and an announcement's from the site's owner
// (supabase/announce.sql), the spark where a picture is, its title its name
// and its words as they were written, its link its own (this site, or https).
//
// Every word is put on the page as text; an avatar is the kit's, which
// escapes its own.
import { ago, avatarHtml, iconHtml } from "/kit.js";
import { langAt, say } from "/card.js";

/// Only the site's own addresses: what the server made from ids.
export function here(link) {
  try {
    const url = new URL(String(link || ""), location.origin);
    if (url.origin !== location.origin) return `${langAt()}/notifications`;
    // A page with a copy in the page's language opens it (/de/m/<id>).
    const copied = /^\/(?:[muc]\/|(?:challenge|profile|collections)(?=\/?$))/.test(url.pathname);
    return (copied ? langAt() : "") + url.pathname + url.search + url.hash;
  } catch {
    return `${langAt()}/notifications`;
  }
}

const parsed = (html) => {
  const made = document.createElement("template");
  made.innerHTML = html;
  return made.content.firstElementChild;
};

/// An announcement's own link as it goes: another site's https address as
/// it is, else the site's own (here).
export function outside(link) {
  try {
    const url = new URL(String(link || ""), location.origin);
    return url.protocol === "https:" && url.origin !== location.origin ? url.href : here(link);
  } catch {
    return here(link);
  }
}

export function line(one) {
  const item = document.createElement("li");
  item.dataset.kind = String(one.kind || "");
  if (one.unread) item.classList.add("unread");
  const link = document.createElement("a");
  link.href = one.kind === "announcement" ? outside(one.link) : here(one.link);
  if (one.by && one.by.handle) {
    link.append(parsed(avatarHtml({ handle: one.by.handle, name: one.by.name, picture: one.by.picture }, { size: "small" })));
  }
  else link.append(parsed(iconHtml(["result", "achievement", "challenge_won"].includes(one.kind) ? "award"
    : ["challenge_open", "challenge_closing"].includes(one.kind) ? "build" : one.kind === "likes" ? "like"
      : one.kind === "announcement" ? "spark" : "comment")));
  const words = document.createElement("span");
  words.className = "what";
  // The line as the server said it in the page's language, whoever did it
  // where the language puts them.
  const who = document.createElement("b");
  who.textContent = String(one.who || "");
  for (const piece of String(one.line || "").split(/(\{who\})/)) {
    if (piece) words.append(piece === "{who}" ? who : piece);
  }
  if (one.new) {
    const tag = document.createElement("span");
    tag.className = "pill new";
    tag.textContent = say("New");
    words.append(" ", tag);
  }
  if (one.said) {
    // An announcement's words are the owner's own, not a quote of somebody's.
    const said = document.createElement(one.kind === "announcement" ? "span" : "q");
    if (one.kind === "announcement") said.className = "words";
    said.textContent = String(one.said);
    words.append(said);
  }
  const at = document.createElement("time");
  at.dateTime = String(one.at || "");
  at.textContent = ago(one.at);
  words.append(at);
  link.append(words);
  item.append(link);
  return item;
}

/// [one] group drawn; [i] its place, the first screen's pictures asked at once.
export function group(one, i = 0) {
  const item = document.createElement("li");
  item.className = `notice${one.unread ? " unread" : ""}`;
  item.dataset.model = String(one.model || "");
  if (one.achievements) item.dataset.achievements = "";
  if (one.challenge) item.dataset.challenge = String(Number(one.challenge) || "");
  if (one.talk) item.dataset.talk = String(Number(one.talk) || "");
  const told = Number(one.announcement) > 0 || one.announcement === 0;
  const to = told ? outside(one.link) : here(one.link);
  if (told) {
    item.dataset.announcement = String(Number(one.announcement) || 0);
    item.id = `announcement-${Number(one.announcement) || 0}`;
    // Its own link, when it has one: following it is counted (a click).
    if (!/#announcement-\d+$/.test(String(one.link || ""))) item.dataset.own = to;
  }
  const picture = document.createElement("a");
  picture.className = one.achievements ? "pic award" : one.challenge ? "pic challenge" : told ? "pic announce" : one.talk ? "pic talk" : "pic";
  picture.href = to;
  picture.tabIndex = -1;
  picture.setAttribute("aria-hidden", "true");
  if (one.picture) {
    const img = document.createElement("img");
    img.src = here(one.picture);
    img.alt = "";
    img.width = 1200;
    img.height = 630;
    // The first screen's asked at once.
    img.loading = i < 4 ? "eager" : "lazy";
    img.decoding = "async";
    picture.append(img);
  }
  if (one.achievements) picture.append(parsed(iconHtml("award")));
  if (one.challenge) picture.append(parsed(iconHtml("build")));
  if (told) picture.append(parsed(iconHtml("spark")));
  if (one.talk) picture.append(parsed(iconHtml("comment")));
  const body = document.createElement("div");
  body.className = "body";
  const title = document.createElement("h2");
  const name = document.createElement("a");
  name.href = to;
  name.textContent = String(one.name || say("Your model"));
  title.append(name);
  if (one.unread) {
    const dot = document.createElement("span");
    dot.className = "dot";
    dot.title = say("Not opened yet");
    const words = document.createElement("span");
    words.className = "visually-hidden";
    words.textContent = say("Not opened yet");
    dot.append(words);
    title.append(dot);
  }
  const lines = document.createElement("ul");
  lines.className = "lines";
  for (const row of one.rows || []) lines.append(line(row));
  body.append(title, lines);
  // A weekly quick build's notice opens the studio on its template.
  if (one.start) {
    const start = document.createElement("a");
    start.className = "cta small";
    start.href = here(one.start);
    start.textContent = say("Start");
    body.append(start);
  }
  item.append(picture, body);
  return item;
}
