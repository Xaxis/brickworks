// The latest in Talk on the homepage (#talk-latest): the newest threads of
// every board, drawn on the server as Talk's own rows (api/_talk.js
// talkLatest, ?op=talk_latest&html=1), in the page's language. Asked as it
// nears the screen; until then, and if it never comes, the section's own
// words and its link to /talk stand, so nothing under it moves.
const place = document.getElementById("talk-latest");
const list = place?.querySelector("[data-talk-strip]");
const code = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "";
const tests = new URLSearchParams(location.search).get("tests") === "1";

async function fill() {
  const n = Math.min(8, Math.max(1, Number(place.dataset.n) || 4));
  const reply = await fetch(`/api/people?op=talk_latest&n=${n}&html=1${code ? `&lang=${code}` : ""}${tests ? "&tests=1" : ""}`)
    .catch(() => null);
  const body = reply && reply.ok ? await reply.json().catch(() => null) : null;
  // The server's own escaped rows: every word typed in them is escaped there.
  if (!body || !body.count || typeof body.html !== "string") return;
  list.innerHTML = body.html;
  list.removeAttribute("aria-busy");
  place.dataset.filled = String(body.count);
}

if (place && list) {
  if (!("IntersectionObserver" in window)) {
    fill();
  } else {
    const watch = new IntersectionObserver((seen) => {
      if (!seen.some((one) => one.isIntersecting)) return;
      watch.disconnect();
      fill();
    }, { rootMargin: "150% 0px" });
    watch.observe(place);
  }
}
