// Building now, listed (buildlive, 2026-11-23): the builds open to watchers
// at this moment, first in the home feed (web/index.html) and on their
// designer's profile (api/people.js, data-live-handle), each a card that
// opens its watch page (/live/<watch>, web/live.js). From
// /api/together?op=live, which the CDN keeps 4 s, so a build opened is
// listed within about ten: asked as the page opens, and again every 30 s
// while the page is in view. Nothing shows while nothing is being built.
// Every word goes on the page as text.
import { langAt, say } from "/card.js";

const box = document.querySelector("[data-live-now]");
const TESTS = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const WATCH = /^[A-Za-z0-9]{12}$/;
const MODEL = /^[A-Za-z0-9]{10}$/;
const EVERY = 30_000;

function card(show) {
  const link = document.createElement("a");
  link.className = "live-card";
  link.href = `${langAt()}/live/${show.watch}${TESTS ? "?tests=1" : ""}`;
  const pic = document.createElement("span");
  pic.className = "live-pic";
  if (MODEL.test(String(show.model || ""))) {
    const img = document.createElement("img");
    img.src = `/m/${show.model}.webp`;
    img.alt = "";
    img.width = 160;
    img.height = 120;
    img.loading = "lazy";
    img.decoding = "async";
    img.addEventListener("error", () => img.remove());
    pic.append(img);
  }
  const badge = document.createElement("span");
  badge.className = "live-tag";
  badge.textContent = say("Live");
  pic.append(badge);
  const words = document.createElement("span");
  words.className = "live-words";
  const title = document.createElement("b");
  title.textContent = show.title || say("A build");
  const by = document.createElement("span");
  by.textContent = say("{name} is building it now", { name: show.designer?.name || show.designer?.handle || "" });
  const count = document.createElement("span");
  count.className = "live-count";
  const n = Number(show.watchers) || 0;
  count.textContent = n === 0 ? say("Be the first to watch") : n === 1 ? say("1 watching") : say("{n} watching", { n });
  words.append(title, by, count);
  link.append(pic, words);
  link.setAttribute("aria-label", say("{title} by {name}, building now: watch", { title: title.textContent,
    name: show.designer?.name || "" }));
  return link;
}

async function draw() {
  if (!box) return;
  const handle = HANDLE.test(String(box.dataset.liveHandle || "")) ? box.dataset.liveHandle : "";
  let shows = [];
  try {
    const reply = await fetch(`/api/together?op=live${handle ? `&handle=${handle}` : ""}${TESTS}`, { headers: { accept: "application/json" } });
    shows = reply.ok ? ((await reply.json())?.live || []).filter((one) => WATCH.test(String(one?.watch))) : [];
  } catch {
    shows = [];
  }
  box.dataset.liveCount = String(shows.length);
  if (shows.length === 0) {
    box.hidden = true;
    box.replaceChildren();
    return;
  }
  const head = document.createElement("h2");
  head.className = "live-now-h";
  const dot = document.createElement("span");
  dot.className = "dot";
  dot.setAttribute("aria-hidden", "true");
  head.append(dot, document.createTextNode(say("Building now")));
  const row = document.createElement("div");
  row.className = "live-now-row";
  row.append(...shows.map(card));
  box.replaceChildren(head, row);
  box.hidden = false;
}

draw();
setInterval(() => document.visibilityState === "visible" && draw(), EVERY);
document.addEventListener("visibilitychange", () => document.visibilityState === "visible" && draw());
