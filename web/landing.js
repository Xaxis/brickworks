// The landing page's two live strips (index.html #community): the
// gallery's Top builds (#made), as the gallery orders them, and the LDraw
// library's biggest sets (#sets, as /library orders them by Most parts),
// each drawn as web/card.js draws every card.
//
// Neither may show a dead card. So a card is put in only once its picture
// has arrived and decoded, a model with no picture is left out, and a
// strip's cards go in only once three are ready; until then its row holds
// skeletons at a card's size (site.css .skeleton), so the page under it
// stays where it is, and an answer that does not come takes that strip
// away (and the section with it, when both go). Asked as they near the
// screen (a screen and a half before the line under the before and after
// above them), so they are in by the time they are read, and a visitor who
// never scrolls fetches none of it.
import { modelCard, pictureOf } from "/card.js";

const GALLERY = /^[A-Za-z0-9]{10}$/;
const SET = /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/;
const MOST = 8;
const LEAST = 3;
const section = document.getElementById("community");
const near = document.getElementById("also");
// Each strip: where it is, its row, what to ask, which ids are cards, and
// the attribute on <html> that says how it ended (tools/web/landing_check.mjs
// waits on data-strip).
const STRIPS = [
  { strip: "made", row: "made-models", ask: "/api/share?op=list&page=1&sort=top", id: GALLERY, said: "strip" },
  { strip: "sets", row: "sets-models", ask: "/api/share?op=library&page=1&sort=largest", id: SET, said: "sets" },
];

/// [model]'s card once its picture is in, or null.
async function ready(model) {
  const card = modelCard(model);
  const img = card.querySelector("img");
  if (!img) return null;
  img.loading = "eager";
  try {
    await img.decode();
  } catch {
    return null;
  }
  return img.naturalWidth > 0 ? card : null;
}

/// One strip filled, or taken away: whether it is shown.
async function fill({ strip, row, ask, id, said }) {
  const where = document.getElementById(strip);
  const cards = document.getElementById(row);
  if (!where || !cards) return false;
  let models = [];
  try {
    const reply = await fetch(ask, { headers: { accept: "application/json" } });
    // Read even a refusal: an answer never read keeps the page busy.
    const body = await reply.json().catch(() => null);
    if (reply.ok) models = body?.models || [];
  } catch { /* no strip */ }
  const listed = models.filter((m) => m && id.test(String(m.id)) && pictureOf(m)).slice(0, MOST);
  const drawn = (await Promise.all(listed.map((m) => ready(m).catch(() => null)))).filter(Boolean);
  document.documentElement.dataset[said] = drawn.length >= LEAST ? String(drawn.length) : "none";
  if (drawn.length < LEAST) {
    where.hidden = true;
    return false;
  }
  cards.replaceChildren(...drawn);
  return true;
}

async function fillAll() {
  const shown = await Promise.all(STRIPS.map(fill));
  if (section && !shown.some(Boolean)) section.hidden = true;
}

if (section) {
  if (near && "IntersectionObserver" in window) {
    const watch = new IntersectionObserver((seen) => {
      if (!seen.some((one) => one.isIntersecting)) return;
      watch.disconnect();
      fillAll();
    }, { rootMargin: "150% 0px" });
    watch.observe(near);
  } else {
    fillAll();
  }
}
