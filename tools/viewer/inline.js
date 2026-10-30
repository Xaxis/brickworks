// The model in 3D on its own page (viewer369, 2026-10-30): a gallery
// model's /m/<id>, a set of the LDraw library's /library/<id>, and a
// catalogue set's /library/set/<n> that LDraw has a model of. The owner:
// "a 3D preview widget inline without forcing user to open in the app
// until they want to".
//
// Built by tools/viewer/build.mjs into web/viewer3d.js, three.js and all,
// which web/model-page.js imports only when somebody asks for the model in
// 3D (View in 3D on the picture, a click on it, or the first drag across
// it): a visit that never asks loads none of it. It draws the scene the
// card in Claude draws (view.js, scene.js), from the same part store
// (web/lbm.js), packed by the site from the model's file (api/_parts.js
// sceneOf, /m/<id>/scene.json), in the frame the picture was in, on the
// picture's own ground (directory.css .view3d), so nothing moves.
//
// Mouse: drag to turn, right-drag to pan, the wheel to zoom once the model
// has been pressed (before that the wheel scrolls the page). Touch: one
// finger across turns it and one up or down scrolls the page, until the
// person takes hold of it (a drag across, two fingers or a tap); then one
// finger turns and two pinch and pan, until it leaves the screen or they
// press elsewhere. Keys, with it focused: the arrows turn it, + and -
// zoom, 0 or Home goes back to where it started, F full screen. Buttons
// for each, named. No turn on arrival for a person who asks for less
// motion. A model past what the device can turn smoothly (BUDGET) asks
// first; anything that fails says why and leaves the picture.
import { iconButtonHtml } from "../../web/card.js";
import { sceneShape, unpack } from "./scene.js";
import { View, shapes, webglWorks } from "./view.js";

// The triangles a device is trusted to turn smoothly: a phone or a tablet
// (a coarse pointer), and anything else. The library's biggest model is 6
// million (the Liebherr R9800); a gallery model is mostly under half one.
export const BUDGET = { coarse: 3e6, fine: 9e6 };
// The share of the parts' geometry in before the model takes the picture's
// place, as the card does: the most-used parts come first.
const SHOWN_AT = 0.25;
// A long lens, the camera stood well back: the page's picture is drawn
// square on (ModelShot's orthographic camera), and the card's 35 degrees
// bent a big model away from it as the 3D took its place.
const FOV = 20;
const TURN = Math.PI / 12;
const ZOOM = 0.85;

const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
const coarse = () => matchMedia("(pointer: coarse)").matches;
const now = () => Math.round(performance.now());

// What a check reads of it (tools/web/model_page_flow.mjs). Reading only.
const state = window.brickworks3d = window.brickworks3d || { state: "closed", timings: {}, errors: [] };

/// The 3D view in [shell] (web/model-page.js's .view3d, over the picture):
/// {close, open} for the page. [given]: scene (its address), name, app (the
/// app's address for it, Open in Brickworks), timings (what model-page.js
/// has marked already), how it was asked for (the pointer's type, or
/// "key"), and closed, called when the person goes back to the picture.
export function open3d(shell, given) {
  const timings = Object.assign(state.timings, given.timings || {});
  const mark = (what) => { if (!timings[what]) timings[what] = now(); };
  mark("code");
  state.state = "loading";
  state.errors = [];
  const stage = shell.querySelector(".stage");
  const said = shell.querySelector(".view3d-said");
  const bar = shell.querySelector(".view3d-bar > span");
  let view = null;
  let data = null;
  let scene = null;
  // Asked for with a mouse or the keys, it is the person's at once; by
  // touch, not until they take hold of it, so the page still scrolls.
  let engaged = given.how !== "touch";
  let full = false;
  let bytes = 0;

  const say = (words, busy = false) => {
    said.textContent = words || "";
    said.hidden = !words;
    shell.setAttribute("aria-busy", busy ? "true" : "false");
  };
  const progress = (share) => { bar.style.width = `${Math.round(Math.max(0, Math.min(1, share)) * 100)}%`; };

  // Its tools, the site's icon buttons (web/card.js), under it at the right.
  const tools = document.createElement("div");
  tools.className = "view3d-tools";
  tools.setAttribute("role", "toolbar");
  tools.setAttribute("aria-label", "3D view");
  tools.hidden = true;
  tools.innerHTML = [
    iconButtonHtml({ icon: "zoom-out", name: "Zoom out", small: true, attrs: 'data-act="out"' }),
    iconButtonHtml({ icon: "zoom-in", name: "Zoom in", small: true, attrs: 'data-act="in"' }),
    iconButtonHtml({ icon: "reset", name: "Reset the view", small: true, attrs: 'data-act="reset"' }),
    iconButtonHtml({ icon: "expand", name: "Full screen", small: true, pressed: false, attrs: 'data-act="full"' }),
    iconButtonHtml({ icon: "close", name: "Back to the picture", small: true, attrs: 'data-act="close"' }),
  ].join("");
  shell.append(tools);
  const button = (act) => tools.querySelector(`[data-act="${act}"]`);
  // The app, for what turning it here does not do: its steps, its parts,
  // changing it.
  const inApp = document.createElement("a");
  inApp.className = "pill view3d-app";
  inApp.href = given.app;
  inApp.textContent = "Open in the app";
  inApp.hidden = true;
  shell.append(inApp);
  const hint = document.createElement("p");
  hint.className = "view3d-hint";
  hint.hidden = true;
  shell.append(hint);
  let hintTimer = 0;
  const hintFor = (words, ms = 4000) => {
    hint.textContent = words;
    hint.hidden = false;
    clearTimeout(hintTimer);
    hintTimer = setTimeout(() => { hint.hidden = true; }, ms);
  };

  // Where it cannot be drawn, or something on the way fails: why, in the
  // status line over the picture, with Try again.
  const failed = (why) => {
    state.state = "failed";
    state.errors.push(why);
    shell.dataset.state = "failed";
    say(`The 3D view could not load: ${why}. The picture is still here.`);
    const again = document.createElement("button");
    again.type = "button";
    again.className = "cta ghost small";
    again.textContent = "Try again";
    again.addEventListener("click", () => { again.remove(); start(); });
    said.append(" ", again);
  };

  const touchAction = () => (full || engaged ? "none" : "pan-y");
  const engage = (yes) => {
    if (engaged === yes) return;
    engaged = yes;
    shell.toggleAttribute("data-engaged", yes);
    if (view) view.touch();
  };

  async function start() {
    state.state = "loading";
    shell.dataset.state = "loading";
    say("Getting the model in 3D…", true);
    progress(0.04);
    if (!webglWorks()) return failed("this browser cannot draw in 3D");
    if (!data) {
      let answer;
      try {
        answer = await fetch(given.scene, { credentials: "omit" });
      } catch {
        return failed("the network did not answer");
      }
      if (!answer.ok) return failed(answer.status === 503 ? "the site cannot draw it just now" : `the site said ${answer.status}`);
      const text = await answer.text();
      bytes = text.length;
      scene = sceneShape(JSON.parse(text));
      mark("scene");
      if (!scene || scene.count < 1) return failed("there is nothing in it to draw");
      try {
        data = await unpack(scene);
      } catch (trouble) {
        return failed(`its parts could not be read (${trouble.message})`);
      }
      mark("unpacked");
      state.parts = data.n;
      state.shapes = data.meshes.length;
      state.triangles = scene.triangles || 0;
      state.sceneBytes = bytes;
    }
    progress(0.1);
    const budget = coarse() ? BUDGET.coarse : BUDGET.fine;
    if (scene.triangles > budget && !given.anyway) return big(budget);
    draw();
  }

  // Past the budget: said, with the way to turn it anyway or in the app.
  function big(budget) {
    state.state = "big";
    state.budget = budget;
    shell.dataset.state = "big";
    const millions = (scene.triangles / 1e6).toFixed(1);
    say(`${data.n.toLocaleString("en-US")} parts in ${millions} million triangles: more than this device turns smoothly.`);
    const anyway = document.createElement("button");
    anyway.type = "button";
    anyway.className = "cta ghost small";
    anyway.textContent = "Turn it anyway";
    anyway.addEventListener("click", () => { given.anyway = true; start(); });
    const app = document.createElement("a");
    app.className = "cta small";
    app.href = given.app;
    app.textContent = "Open in the app";
    said.append(" ", anyway, " ", app);
  }

  async function draw() {
    if (view) { view.stop(false); view = null; }
    say(`Loading its ${data.meshes.length.toLocaleString("en-US")} kinds of part…`, true);
    const errors = state.errors;
    const store = shapes(scene.root, { errors });
    const counted = (mesh) => store(mesh).then((shape) => {
      if (shape) bytes += shape.bytes || 0;
      return shape;
    });
    // Still as it arrives, where the picture was: the person turns it.
    view = new View(stage, data, {
      still, spin: false, fov: FOV, errors, touchAction, shapeOf: counted,
      mark: (what) => {
        // Timed to the frame drawn, not to when it was asked for: a pixel
        // read back waits for the graphics (SwiftShader draws in seconds
        // what a graphics card draws in milliseconds).
        const gl = view && view.renderer && view.renderer.getContext();
        if (gl) gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
        mark(what);
      },
      lost: () => { shell.classList.remove("shown"); failed("the browser took its graphics back"); },
    });
    state.view = view;
    try {
      view.start();
    } catch (trouble) {
      view = null;
      return failed(`this browser would not draw it (${trouble.message})`);
    }
    stage.setAttribute("aria-label", `${given.name} in 3D. Drag to turn it. With it focused, the arrow keys turn it, `
      + "plus and minus zoom, 0 goes back to the start and F is full screen.");
    await view.load((share) => {
      progress(0.1 + share * 0.9);
      say(`Loading its parts: ${Math.round(share * 100)}%`, true);
      if (share >= SHOWN_AT) shown();
    });
    mark("loaded");
    shown();
    state.geometryBytes = bytes - state.sceneBytes;
    state.state = "ready";
    shell.dataset.state = "ready";
    say("");
    view.render();
    hintFor(coarse() ? "Drag across to turn it · pinch to zoom" : "Drag to turn it · scroll to zoom · right-drag to move", 5000);
  }

  // The model in the picture's place.
  function shown() {
    if (shell.classList.contains("shown")) return;
    shell.classList.add("shown");
    tools.hidden = false;
    inApp.hidden = false;
    view.size();
  }

  // Full screen: the browser's own where it has it, else the window's
  // (an iPhone's Safari has none for anything but a video).
  const fullscreen = () => document.fullscreenElement === shell || document.webkitFullscreenElement === shell;
  function setFull(yes) {
    full = yes;
    shell.classList.toggle("full", yes);
    document.documentElement.classList.toggle("view3d-full", yes);
    const b = button("full");
    b.setAttribute("aria-pressed", String(yes));
    b.setAttribute("aria-label", yes ? "Leave full screen" : "Full screen");
    b.querySelector("use")?.setAttribute("href", `/icons.svg#${yes ? "shrink" : "expand"}`);
    state.full = yes;
    if (view) { view.touch(); requestAnimationFrame(() => view && view.size()); }
  }
  async function toggleFull() {
    if (full) {
      if (fullscreen()) await (document.exitFullscreen || document.webkitExitFullscreen).call(document).catch(() => {});
      setFull(false);
      return;
    }
    const ask = shell.requestFullscreen || shell.webkitRequestFullscreen;
    if (ask) {
      try {
        await ask.call(shell);
        state.fullscreen = "browser";
      } catch {
        state.fullscreen = "window";
      }
    } else state.fullscreen = "window";
    setFull(true);
    stage.focus({ preventScroll: true });
  }
  const leftFull = () => { if (full && !fullscreen() && state.fullscreen === "browser") setFull(false); };
  document.addEventListener("fullscreenchange", leftFull);
  document.addEventListener("webkitfullscreenchange", leftFull);

  const act = {
    out: () => view && view.zoomBy(1 / ZOOM),
    in: () => view && view.zoomBy(ZOOM),
    reset: () => view && view.reset(),
    full: () => toggleFull(),
    close: () => close(),
  };
  tools.addEventListener("click", (event) => {
    const b = event.target.closest("[data-act]");
    if (!b) return;
    engage(true);
    act[b.dataset.act]();
  });

  stage.addEventListener("keydown", (event) => {
    if (!view || event.altKey || event.ctrlKey || event.metaKey) return;
    const keys = { ArrowLeft: () => view.orbitBy(-TURN, 0), ArrowRight: () => view.orbitBy(TURN, 0),
      ArrowUp: () => view.orbitBy(0, -TURN / 1.5), ArrowDown: () => view.orbitBy(0, TURN / 1.5),
      "+": act.in, "=": act.in, "-": act.out, _: act.out, 0: act.reset, Home: act.reset,
      f: act.full, F: act.full, Escape: () => { if (full && !fullscreen()) setFull(false); } };
    if (!keys[event.key]) return;
    event.preventDefault();
    engage(true);
    keys[event.key]();
  });
  stage.addEventListener("focus", () => engage(true));

  // Taking hold, by touch: a gesture the browser left to the model (a drag
  // across, a second finger, a tap). A drag up or down it takes for the
  // page, and says so with pointercancel.
  const touches = new Map();
  stage.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "touch") { engage(true); return; }
    touches.set(event.pointerId, { x: event.clientX, y: event.clientY, moved: false });
    if (touches.size >= 2) engage(true);
  }, true);
  stage.addEventListener("pointermove", (event) => {
    const t = touches.get(event.pointerId);
    if (!t) return;
    const dx = event.clientX - t.x;
    const dy = event.clientY - t.y;
    if (!t.moved && Math.hypot(dx, dy) > 8) {
      t.moved = true;
      if (Math.abs(dx) > Math.abs(dy)) engage(true);
    }
    // Until then the model stays as it was while the page scrolls: a
    // browser that lets the page have the swipe sends the moves on too,
    // and OrbitControls turned it up and over as the page went by.
    if (!engaged) event.stopPropagation();
  }, true);
  stage.addEventListener("pointerup", (event) => {
    const t = touches.get(event.pointerId);
    touches.delete(event.pointerId);
    if (t && !t.moved) engage(true);
  }, true);
  stage.addEventListener("pointercancel", (event) => touches.delete(event.pointerId), true);
  // Let go of when pressed elsewhere, or once it is off the screen.
  const elsewhere = (event) => { if (!full && !shell.contains(event.target)) engage(false); };
  document.addEventListener("pointerdown", elsewhere, true);
  const seen = new IntersectionObserver((entries) => {
    if (!entries.some((e) => e.isIntersecting)) engage(false);
  });
  seen.observe(shell);
  // The wheel is the page's until the model has been pressed: caught on
  // the way down, so OrbitControls never hears it and the page scrolls.
  stage.addEventListener("wheel", (event) => {
    if (engaged || full) return;
    event.stopPropagation();
    if (!state.wheelHinted) {
      state.wheelHinted = true;
      hintFor("Press the model first to zoom it with the wheel, or use + and −");
    }
  }, { capture: true, passive: true });

  new ResizeObserver(() => { if (view) view.size(); }).observe(stage);

  function close() {
    if (full) toggleFull();
    engage(false);
    shell.classList.remove("shown");
    shell.hidden = true;
    state.state = "closed";
    if (view) view.stop(false);
    given.closed?.();
  }

  function open() {
    shell.hidden = false;
    if (view && data && state.state !== "failed") {
      view.start();
      shell.classList.add("shown");
      state.state = "ready";
      return;
    }
    start();
  }

  shell.toggleAttribute("data-engaged", engaged);
  if (given.how !== "touch") stage.focus({ preventScroll: true });
  state.sample = () => (view ? view.sample() : null);
  state.angle = () => (view ? view.angle() : null);
  state.shown = () => (view ? view.instances() : 0);
  state.engaged = () => engaged;
  state.touchAction = () => (view && view.renderer ? view.renderer.domElement.style.touchAction : "");
  state.bytes = () => bytes;
  start();
  return { open, close };
}
