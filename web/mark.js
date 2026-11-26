// The header's mark, our mark built in bricks (herostudio, 2026-11-26): it
// turns once as a visit begins and again whenever a pointer comes onto it or
// it takes the keyboard's focus, each turn whole (site.css .site-head .mark
// .chip.turning steps through web/img/hero/mark-turn.webp). web/theme.js
// asks for this file once the page is in, on a page with the site's header
// and for somebody who has not asked for less motion, so neither it nor the
// frames are in the first screen's bytes or an embed's (the embed budget,
// tests/test_embed_script_budget.py). A turn waits for the frames.
(() => {
  let frames = null;
  const framesIn = () => {
    if (!frames) {
      const picture = new Image();
      picture.src = "/img/hero/mark-turn.webp";
      frames = picture.decode().then(() => true, () => false);
    }
    return frames;
  };
  const turn = (chip) => {
    if (!chip) return;
    framesIn().then((ok) => {
      if (!ok || chip.classList.contains("turning")) return;
      chip.classList.add("turning");
      chip.addEventListener("animationend", () => chip.classList.remove("turning"), { once: true });
    });
  };
  // Coming onto the mark, not moving about inside it.
  const onto = (event) => {
    const mark = event.target instanceof Element ? event.target.closest(".site-head .mark") : null;
    if (!mark || (event.relatedTarget instanceof Node && mark.contains(event.relatedTarget))) return;
    turn(mark.querySelector(".chip"));
  };
  document.addEventListener("pointerover", onto);
  document.addEventListener("focusin", onto);
  // Once a visit: the tab's sessionStorage.
  let first = false;
  try {
    first = !sessionStorage.getItem("brickworks.mark");
    sessionStorage.setItem("brickworks.mark", "turned");
  } catch {
    first = false;
  }
  if (first) turn(document.querySelector(".site-head .mark .chip"));
})();
