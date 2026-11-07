// In your room (APP_UX5 #13, arview, 2026-11-07): a model's page places its
// model in the room its visitor is in, at its real size, through the
// phone's camera: AR Quick Look on an iPhone or iPad, WebXR's immersive AR
// on an Android phone or a headset (web/model-page.js offers it only where
// one of them is there; never on a computer).
//
// What is placed is the GLB the app's Export writes of the model (File,
// Export, 3D model…; src/parts/mesh_export.gd), written here, in the
// visitor's browser, by web/glb.js from the model's plan (/m/<id>/room.json,
// api/_parts.js roomOf) and each part's geometry from the store the 3D view
// and the Parts list draw from: each shape once, every part in its colour
// and finish, under its assemblies, in metres. An iPhone's Quick Look wants
// USDZ, which <model-viewer> makes from that same GLB as it opens, so there
// is one model, never a second writer to drift from the first.
//
// <model-viewer> (web/model-viewer-4.4.0, Google's, pinned and served from
// here) and the GLB are asked for only now, on the tap, never with the
// page. Its looks are web/room.css, asked for with it.

import { counted, iconButtonHtml, number, say } from "/card.js";
import { parseLbm } from "/lbm.js";
import { MOST_BYTES, glbSize, guessBytes, writeGlb } from "/glb.js";

const VIEWER = "/model-viewer-4.4.0/model-viewer.min.js";
// Its looks, asked for with it: none of it weighs on the page's first load.
const styled = new Promise((done) => {
  const link = Object.assign(document.createElement("link"), { rel: "stylesheet", href: "/room.css" });
  link.addEventListener("load", done);
  link.addEventListener("error", done);
  document.head.append(link);
});
// Shapes asked for at once, as the Parts list asks for its pictures'.
const AT_ONCE = 6;

/// The model of [big] (the page's picture, its data-scene the 3D view's
/// scene.json, beside which is room.json) in a room, over the picture,
/// named [name]: until its GLB is written and shown the frame says how far
/// it has got; then the model, to turn, and Place it in your room, which
/// opens the phone's camera on the room with the model in it. {open, close}.
export function openRoom(big, { name }) {
  const shell = document.createElement("div");
  shell.className = "room";
  shell.dataset.state = "loading";
  shell.setAttribute("role", "region");
  shell.setAttribute("aria-label", say("{name} in your room", { name }));
  shell.setAttribute("aria-busy", "true");
  shell.innerHTML = '<div class="room-stage"></div><div class="room-bar" aria-hidden="true"><span></span></div>'
    + `<p class="room-said" role="status"></p>${iconButtonHtml({ icon: "close", name: say("Back to the picture"), attrs: 'data-close=""' })}`;
  const said = shell.querySelector(".room-said");
  const bar = shell.querySelector(".room-bar > span");
  const tell = (words) => {
    said.textContent = words;
    said.hidden = !words;
  };
  tell(say("Getting {name} ready for your room…", { name }));
  // Shown once it has its looks, unless it was closed first.
  let wanted = true;
  shell.hidden = true;
  big.parentElement.append(shell);
  styled.then(() => { shell.hidden = !wanted; });
  const started = performance.now();
  let url = "";
  const close = () => {
    wanted = false;
    shell.hidden = true;
    big.focus({ preventScroll: true });
  };
  const open = () => {
    wanted = true;
    styled.then(() => { shell.hidden = !wanted; });
  };
  shell.querySelector("[data-close]").addEventListener("click", close);
  shell.addEventListener("keydown", (event) => {
    if (event.key === "Escape") close();
  });
  addEventListener("pagehide", () => { if (url) URL.revokeObjectURL(url); });
  const failed = (words) => {
    shell.dataset.state = "failed";
    shell.setAttribute("aria-busy", "false");
    tell(words);
  };
  const refused = (bytes) => {
    shell.dataset.state = "refused";
    shell.dataset.bytes = String(bytes);
    shell.setAttribute("aria-busy", "false");
    tell(say("{name} is too big to place in a room from a phone: its 3D model would be about {size} MB, and a phone is given {most} MB at most.",
      { name, size: number(Math.round(bytes / 1048576)), most: number(MOST_BYTES / 1048576) }));
  };
  let viewer = null;
  const scene = big.dataset.scene || "";
  (async () => {
    const answer = await fetch(scene.replace(/scene\.json$/, "room.json"), { credentials: "same-origin" });
    if (!answer.ok) throw new Error(`room.json ${answer.status}`);
    const plan = await answer.json();
    // Said no before a shape is fetched: a phone's data is not spent on a
    // model it will not be given.
    if (guessBytes(plan) > MOST_BYTES) return refused(guessBytes(plan));
    // <model-viewer> comes while the shapes do.
    viewer = import(VIEWER);
    viewer.catch(() => {});
    const hashes = [...new Set(plan.meshes.map((mesh) => mesh[1]))];
    const shapes = new Map();
    let done = 0;
    let next = 0;
    const fetchOne = async () => {
      while (next < hashes.length) {
        const hash = hashes[next++];
        try {
          const got = await fetch(`${plan.root}${hash}.lbm`, { cache: "force-cache", credentials: "omit" });
          shapes.set(hash, got.ok ? parseLbm(await got.arrayBuffer()) : null);
        } catch {
          shapes.set(hash, null);
        }
        done += 1;
        bar.style.width = `${Math.round((done / hashes.length) * 100)}%`;
      }
    };
    await Promise.all(Array.from({ length: Math.min(AT_ONCE, hashes.length) }, fetchOne));
    const shapeOf = (hash) => shapes.get(hash) || null;
    if (glbSize(plan, shapeOf) > MOST_BYTES) return refused(glbSize(plan, shapeOf));
    const made = writeGlb(plan, shapeOf, { title: name, generator: "Brickworks (brickworks.diy)" });
    url = URL.createObjectURL(new Blob([made.glb], { type: "model/gltf-binary" }));
    Object.assign(shell.dataset, { bytes: String(made.glb.length), parts: String(made.parts), shapes: String(made.shapes),
      leftOut: String(Object.values(made.left_out).reduce((a, b) => a + b, 0)) });
    await viewer;
    const model = document.createElement("model-viewer");
    const settings = {
      src: url, alt: say("{name}, to turn and to place in your room", { name }),
      // Quick Look on an iPhone or iPad, from a USDZ it makes of this GLB;
      // WebXR on Android (Scene Viewer, Google's app, cannot read a GLB the
      // page made: it fetches it again by its address, which only the page
      // has).
      ar: "", "ar-modes": "webxr quick-look",
      // At its real size where it is put, which a pinch can still change.
      "ar-scale": "auto", "ar-placement": "floor",
      // Turned from the front corner, as its picture is drawn.
      "camera-controls": "", "camera-orbit": "-30deg 65deg auto", "touch-action": "pan-y", "interaction-prompt": "none",
      "shadow-intensity": "1", "environment-image": "neutral", loading: "eager",
    };
    for (const [key, value] of Object.entries(settings)) model.setAttribute(key, value);
    model.innerHTML = '<div slot="progress-bar"></div>';
    const place = document.createElement("button");
    place.type = "button";
    place.slot = "ar-button";
    place.className = "cta room-place";
    place.textContent = say("Place it in your room");
    model.append(place);
    model.addEventListener("load", () => {
      shell.dataset.state = "ready";
      shell.dataset.ms = String(Math.round(performance.now() - started));
      shell.setAttribute("aria-busy", "false");
      const out = Number(shell.dataset.leftOut);
      tell(out ? say("Not shown: {parts} made for this model alone, which this site has no shape for.",
        { parts: counted(out, "part", "parts") }) : "");
    }, { once: true });
    model.addEventListener("error", () => failed(say("{name} could not be shown here. The picture is still here; try again in a moment.", { name })));
    model.addEventListener("ar-status", (event) => {
      shell.dataset.ar = event.detail?.status || "";
      if (event.detail?.status === "failed") tell(say("This phone could not open its camera on the room. The model is still here to turn."));
    });
    shell.querySelector(".room-stage").append(model);
    return null;
  })().catch(() => failed(say("{name} could not be got ready for your room. The picture is still here; try again in a moment.", { name })));
  return { open, close };
}
