// The landing page's strip from the live gallery (index.html #made): the
// Top builds, as the gallery orders them, drawn as web/cards.js draws
// every card.
//
// It must never show a dead card. So a card is put in only once its
// picture has arrived and decoded, a model with no picture is left out,
// and the strip stays hidden until three cards are ready; an answer that
// does not come leaves it hidden. Asked as the strip nears the screen
// (the sentence under the pictures above it), not before, so a visitor
// who never scrolls fetches none of it.
import { modelCard, pictureOf } from "/cards.js";

const ID = /^[A-Za-z0-9]{10}$/;
const MOST = 8;
const LEAST = 3;
const strip = document.getElementById("made");
const row = document.getElementById("made-models");
const near = document.getElementById("also");

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

async function fill() {
  let models = [];
  try {
    const reply = await fetch("/api/share?op=list&page=1&sort=top", { headers: { accept: "application/json" } });
    if (reply.ok) models = (await reply.json()).models || [];
  } catch { /* no strip */ }
  const listed = models.filter((m) => m && ID.test(String(m.id)) && pictureOf(m)).slice(0, MOST);
  const cards = (await Promise.all(listed.map((m) => ready(m).catch(() => null)))).filter(Boolean);
  document.documentElement.dataset.strip = cards.length >= LEAST ? String(cards.length) : "none";
  if (cards.length < LEAST) return;
  row.replaceChildren(...cards);
  strip.hidden = false;
}

if (strip && row) {
  if (near && "IntersectionObserver" in window) {
    const watch = new IntersectionObserver((seen) => {
      if (!seen.some((one) => one.isIntersecting)) return;
      watch.disconnect();
      fill();
    }, { rootMargin: "900px 0px" });
    watch.observe(near);
  } else {
    fill();
  }
}
