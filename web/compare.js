// /compare's clips play, muted and looping, while they are on screen, and
// not before: each is preload="none" with a poster, so the page fetches only
// its pictures until someone scrolls to a clip. Once this takes a clip over,
// its controls go (they sat over the picture) and a click or Enter pauses
// it and plays it again; a clip someone paused stays paused. A person who
// asks for less motion keeps the controls and the posters, and nothing plays
// by itself. Without this script the clips are posters with controls. No
// inline script: the site's content security policy runs none it has not
// hashed.
(function () {
  "use strict";

  const clips = document.querySelectorAll("video[data-play]");
  if (!clips.length || !("IntersectionObserver" in window)) return;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const ours = new WeakSet();
  const seen = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      const clip = entry.target;
      if (clip.dataset.held) continue;
      if (entry.isIntersecting) {
        clip.play().catch(() => {});
      } else if (!clip.paused) {
        ours.add(clip);
        clip.pause();
      }
    }
  }, { threshold: 0.35 });

  for (const clip of clips) {
    clip.controls = false;
    clip.tabIndex = 0;
    const toggle = () => {
      if (clip.paused) {
        delete clip.dataset.held;
        clip.play().catch(() => {});
      } else {
        clip.dataset.held = "1";
        ours.add(clip);
        clip.pause();
      }
    };
    clip.addEventListener("click", toggle);
    clip.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        toggle();
      }
    });
    // A pause this script did not make (the browser's own menu, say) is a
    // person's: leave it so.
    clip.addEventListener("pause", () => {
      if (ours.has(clip)) ours.delete(clip);
      else clip.dataset.held = "1";
    });
    seen.observe(clip);
  }
})();
