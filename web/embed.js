// The embed (/m/<id>/embed, api/share.js embedCard), in somebody else's
// page: its picture is the way into the model in 3D, in the frame, as on
// the model's page (web/start3d.js). Nothing more of the 3D view comes
// until it is asked for.
//
// With ?autoplay=1 (X's player for the model's link, unit turntable) and a
// clip of the model, the picture is the model turning, muted and looping,
// with Pause and Play in its corner; still for a person who asks for less
// motion, until they press Play. The 3D view, asked for, takes its place
// and the clip stops.
import { start3d } from "/start3d.js";

const say = (words) => (globalThis.brickworksLang ? globalThis.brickworksLang.say(words) : words);

const picture = document.querySelector(".embed a.picture[data-scene]");
if (picture) start3d(picture);

const clip = picture && picture.querySelector("video");
const toggle = document.querySelector("[data-clip-toggle]");
if (clip && toggle) {
  const draw = () => {
    const playing = !clip.paused;
    toggle.setAttribute("aria-label", playing ? say("Pause") : say("Play"));
    toggle.querySelector("use")?.setAttribute("href", `/icons.svg#${playing ? "pause" : "play"}`);
    document.documentElement.dataset.clip = playing ? "playing" : "paused";
  };
  // Muted, so a browser lets it play unasked; set here as well as in the
  // markup, which some browsers read only as the default.
  clip.muted = true;
  clip.addEventListener("play", draw);
  clip.addEventListener("pause", draw);
  toggle.addEventListener("click", () => {
    if (clip.paused) clip.play().catch(() => {});
    else clip.pause();
  });
  toggle.hidden = false;
  draw();
  if (!matchMedia("(prefers-reduced-motion: reduce)").matches) clip.play().catch(draw);
  // The 3D view over it: the clip stops, and so does its button.
  new MutationObserver(() => {
    if (!picture.parentElement.querySelector(".view3d")) return;
    clip.pause();
    toggle.hidden = true;
  }).observe(picture.parentElement, { childList: true });
}
