// The model in 3D on its own page (viewer369, 2026-10-30): a gallery
// model's /m/<id>, a set of the LDraw library's /library/<id>, and a
// catalogue set's /library/set/<n> that LDraw has a model of. The owner:
// "a 3D preview widget inline without forcing user to open in the app
// until they want to".
//
// Built by tools/viewer/build.mjs into web/viewer3d.js, three.js and all,
// which web/start3d.js imports only when somebody asks for the model in
// 3D (View in 3D on the picture, a click on it, or the first drag across
// it), on a model's page or in its embed: a visit that never asks loads
// none of it. It draws the scene the
// card in Claude draws (view.js, scene.js), from the same part store
// (web/lbm.js), packed by the site from the model's file (api/_parts.js
// sceneOf, /m/<id>/scene.json), in the frame the picture was in, on the
// picture's own ground (web/view3d.css .view3d), so nothing moves.
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
// A remix's page (given.changes, api/_remix.js) has What changed beside
// the view's buttons, off until pressed: the parts the remix added,
// recoloured or moved drawn as they are, the parts it took away as faint
// red ghosts where they stood, and the rest faded; pressed again, the model
// as it was. Its counts in a line over the view while it is on.
// Its words in the page's language (web/card.js say: a copy of the page
// in German, French or Spanish carries them, tools/site_lang.py).
//
// A comment on a part (partpins, 2026-11-23): where the page allows it
// (given.mayPin), a right click on a part (a press of the right button that
// is no drag), a long press on one by touch, or Shift+F10 or the menu key
// (the lit part, else the one in the middle) offers Comment on this part,
// which hands the page the part as the version's file has it
// (given.pinWanted). The page's pins (given.pins, numbered as the comments
// number them) are each placed on this version by the one rule
// (web/card.js pinPlace) once the first frame is drawn, the page told
// where (given.placed); each open one placed is a numbered dot on its
// part, which lights the part and says its comment (given.pinPressed).
// Nothing of this runs before the first frame.
import { counted, iconButtonHtml, number, pinPlace, pinTurnOfQuaternion, say } from "../../web/card.js";
import { Color, SRGBColorSpace } from "three";
import { sceneShape, unpack } from "./scene.js";
import { LOOKS, View, shapes, webglWorks } from "./view.js";
// The home's hero, the mark in bricks (tools/viewer/hero.js): in the same
// module, so a visitor who then turns a post in 3D has its code already.
export { hero3d } from "./hero.js";
export { webglWorks };

// The triangles a device is trusted to turn smoothly: a phone or a tablet
// (a coarse pointer), and anything else. The library's biggest model is 6
// million (the Liebherr R9800); a gallery model is mostly under half one.
export const BUDGET = { coarse: 3e6, fine: 9e6 };
// The share of the parts' geometry in before the model takes the picture's
// place, as the card does: the most-used parts come first.
const SHOWN_AT = 0.25;
const TURN = Math.PI / 12;
const ZOOM = 0.85;
// How long a finger is held on a part for its menu, and how far it may
// wander meanwhile (a drag turns the model instead).
const HOLD = 500;
const HOLD_SLACK = 8;
// The colour a part is lit in: the card's picked part's (card.js PICKED).
const LIT = 0xffd84d;

const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
const coarse = () => matchMedia("(pointer: coarse)").matches;
const now = () => Math.round(performance.now());

// What a check reads of it (tools/web/model_page_flow.mjs). Reading only.
const state = window.brickworks3d = window.brickworks3d || { state: "closed", timings: {}, errors: [] };

/// The 3D view in [shell] (web/model-page.js's .view3d, over the picture):
/// {close, open, pinsChanged, showPin, light} for the page. [given]: scene
/// (its address), name, app (the app's address for it, Open in the app),
/// look (where its picture was taken from: "app" or "corner", LOOKS),
/// timings (what model-page.js has marked already), how it was asked for
/// (the pointer's type, or "key"), and closed, called when the person goes
/// back to the picture. And for comments on a part, each optional: pins()
/// ([{id, n, pin, resolved, version}]), mayPin(), pinWanted(part),
/// placed([{id, n, index, moved}], index -1 for on no part here),
/// pinPressed(id) (words to show) and partName(part, colour).
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

  const tell = (words, busy = false) => {
    said.textContent = words || "";
    said.hidden = !words;
    shell.setAttribute("aria-busy", busy ? "true" : "false");
  };
  const progress = (share) => { bar.style.width = `${Math.round(Math.max(0, Math.min(1, share)) * 100)}%`; };

  // Its tools, the site's icon buttons (web/card.js), under it at the right.
  const tools = document.createElement("div");
  tools.className = "view3d-tools";
  tools.setAttribute("role", "toolbar");
  tools.setAttribute("aria-label", say("3D view"));
  tools.hidden = true;
  tools.innerHTML = [
    iconButtonHtml({ icon: "zoom-out", name: say("Zoom out"), small: true, attrs: 'data-act="out"' }),
    iconButtonHtml({ icon: "zoom-in", name: say("Zoom in"), small: true, attrs: 'data-act="in"' }),
    iconButtonHtml({ icon: "reset", name: say("Reset the view"), small: true, attrs: 'data-act="reset"' }),
    given.changes ? iconButtonHtml({ icon: "eye", name: say("What changed"), small: true, pressed: false, labelled: true,
      attrs: 'data-act="changes"' }) : "",
    iconButtonHtml({ icon: "expand", name: say("Full screen"), small: true, pressed: false, attrs: 'data-act="full"' }),
    iconButtonHtml({ icon: "close", name: say("Back to the picture"), small: true, attrs: 'data-act="close"' }),
  ].join("");
  shell.append(tools);
  const button = (act) => tools.querySelector(`[data-act="${act}"]`);
  // The app, for what turning it here does not do: its steps, its parts,
  // changing it.
  const inApp = document.createElement("a");
  inApp.className = "pill view3d-app";
  inApp.href = given.app;
  inApp.textContent = say("Open in the app");
  inApp.hidden = true;
  shell.append(inApp);
  const hint = document.createElement("p");
  hint.className = "view3d-hint";
  hint.hidden = true;
  shell.append(hint);
  // What changed's counts, over the view while it is on.
  const legend = document.createElement("p");
  legend.className = "view3d-legend";
  legend.setAttribute("role", "status");
  legend.hidden = true;
  shell.append(legend);
  let hintTimer = 0;
  const hintFor = (words, ms = 4000) => {
    hint.textContent = words;
    hint.hidden = false;
    clearTimeout(hintTimer);
    hintTimer = setTimeout(() => { hint.hidden = true; }, ms);
  };

  // Comments on a part: what a check reads (tools/web/partpins_flow.mjs),
  // the dots' layer under the tools, and the menu over everything.
  const pins = state.pins = { dots: [], menu: "closed", lastPicked: null, placed: [], lit: -1, turnedTo: -1 };
  const layer = document.createElement("div");
  layer.className = "view3d-pins";
  layer.hidden = true;
  tools.before(layer);
  const menu = document.createElement("div");
  menu.className = "view3d-menu";
  menu.setAttribute("role", "menu");
  menu.hidden = true;
  shell.append(menu);

  // Where it cannot be drawn, or something on the way fails: why, in the
  // status line over the picture, with Try again.
  const failed = (why) => {
    state.state = "failed";
    state.errors.push(why);
    shell.dataset.state = "failed";
    tell(say("The 3D view could not load: {why}. The picture is still here.", { why }));
    const again = document.createElement("button");
    again.type = "button";
    again.className = "cta ghost small";
    again.textContent = say("Try again");
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
    tell(say("Getting the model in 3D…"), true);
    progress(0.04);
    if (!webglWorks()) return failed(say("this browser cannot draw in 3D"));
    if (!data) {
      let answer;
      try {
        answer = await fetch(given.scene, { credentials: "omit" });
      } catch {
        return failed(say("the network did not answer"));
      }
      if (!answer.ok) {
        return failed(answer.status === 503 ? say("the site cannot draw it just now") : say("the site said {status}", { status: answer.status }));
      }
      const text = await answer.text();
      bytes = text.length;
      scene = sceneShape(JSON.parse(text));
      mark("scene");
      if (!scene || scene.count < 1) return failed(say("there is nothing in it to draw"));
      try {
        data = await unpack(scene);
      } catch (trouble) {
        return failed(say("its parts could not be read ({why})", { why: trouble.message }));
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
    const millions = (scene.triangles / 1e6).toLocaleString(globalThis.brickworksLang?.locale || "en-US",
      { minimumFractionDigits: 1, maximumFractionDigits: 1 });
    tell(say("{parts} in {millions} million triangles: more than this device turns smoothly.",
      { parts: counted(data.n, "part"), millions }));
    const anyway = document.createElement("button");
    anyway.type = "button";
    anyway.className = "cta ghost small";
    anyway.textContent = say("Turn it anyway");
    anyway.addEventListener("click", () => { given.anyway = true; start(); });
    const app = document.createElement("a");
    app.className = "cta small";
    app.href = given.app;
    app.textContent = say("Open in the app");
    said.append(" ", anyway, " ", app);
  }

  async function draw() {
    if (view) { view.stop(false); view = null; }
    tell(say("Loading its {n} kinds of part…", { n: number(data.meshes.length) }), true);
    const errors = state.errors;
    const store = shapes(scene.root, { errors });
    const counted = (mesh) => store(mesh).then((shape) => {
      if (shape) bytes += shape.bytes || 0;
      return shape;
    });
    // Still as it arrives, where the picture was: the person turns it. A
    // card of the home's feed asks it turning (given.spin, homefeed), until
    // it is taken hold of, as the view's own autoRotate stops then; never
    // for somebody who asked for less motion (still).
    view = new View(stage, data, {
      still, spin: given.spin === true, ...(LOOKS[given.look] || LOOKS.corner), errors, touchAction, shapeOf: counted,
      mark: (what) => {
        // Timed to the frame drawn, not to when it was asked for: a pixel
        // read back waits for the graphics (SwiftShader draws in seconds
        // what a graphics card draws in milliseconds).
        const gl = view && view.renderer && view.renderer.getContext();
        if (gl) gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
        mark(what);
        // The pins placed once the first frame is drawn, never before it.
        if (what === "first3d") setTimeout(place, 0);
      },
      drawn: () => placeDots(),
      lost: () => { shell.classList.remove("shown"); failed(say("the browser took its graphics back")); },
    });
    state.view = view;
    try {
      view.start();
    } catch (trouble) {
      view = null;
      return failed(say("this browser would not draw it ({why})", { why: trouble.message }));
    }
    stage.setAttribute("aria-label", say("{name} in 3D. Drag to turn it. With it focused, the arrow keys turn it, "
      + "plus and minus zoom, 0 goes back to the start and F is full screen.", { name: given.name }));
    await view.load((share) => {
      progress(0.1 + share * 0.9);
      tell(say("Loading its parts: {share}%", { share: Math.round(share * 100) }), true);
      if (share >= SHOWN_AT) shown();
    });
    mark("loaded");
    shown();
    state.geometryBytes = bytes - state.sceneBytes;
    state.state = "ready";
    shell.dataset.state = "ready";
    tell("");
    view.render();
    hintFor(coarse() ? say("Drag across to turn it · pinch to zoom") : say("Drag to turn it · scroll to zoom · right-drag to move"), 5000);
    // Asked for from the page's line ("See what changed in 3D").
    if (given.changesOn && !changesOn) showChanges(true);
  }

  // The model in the picture's place.
  function shown() {
    if (shell.classList.contains("shown")) return;
    shell.classList.add("shown");
    tools.hidden = false;
    inApp.hidden = false;
    layer.hidden = false;
    view.size();
  }

  // ---------------------------------------------------------------------
  // Comments on a part.

  // This version's parts as a pin knows a part (web/card.js pinPlace):
  // {part, colour, at, turn}, [at] in LDraw's coordinates (the scene's are
  // its x, -y, -z: api/_parts.js placeOf), [turn] as pinTurn keeps one.
  // Made once, when first asked.
  let bricks = null;
  const bricksOf = () => {
    if (bricks || !data) return bricks;
    bricks = new Array(data.n);
    for (let i = 0; i < data.n; i++) bricks[i] = partOf(i);
    return bricks;
  };
  function partOf(i) {
    const mesh = data.meshes[data.mesh[i]] || { part: "", name: "" };
    const colour = data.colours[data.colour[i]] || { code: -1, name: "" };
    return { part: mesh.part, colour: colour.code,
      at: [data.position[i * 3] + 0, -data.position[i * 3 + 1] + 0, -data.position[i * 3 + 2] + 0],
      turn: pinTurnOfQuaternion(Array.from(data.turn.subarray(i * 4, i * 4 + 4))), name: mesh.name, colourName: colour.name };
  }

  // Where each of the page's pins is here: id -> {index, moved}, or null
  // for on no part of this version. Until placed, a pin pressed on the page
  // waits (waiting).
  let placedAt = new Map();
  let placedYet = false;
  let waiting = null;
  let lit = -1;
  const pinList = () => (typeof given.pins === "function" ? given.pins() || [] : []);
  function place() {
    if (!data || !view) return;
    const all = bricksOf();
    const list = pinList();
    placedAt = new Map(list.map((one) => [one.id, pinPlace(one.pin, all)]));
    placedYet = true;
    pins.placed = list.map((one) => {
      const where = placedAt.get(one.id);
      return { id: one.id, n: one.n, index: where ? where.index : -1, moved: Boolean(where && where.moved) };
    });
    given.placed?.(pins.placed);
    drawDots();
    if (waiting !== null) {
      const id = waiting;
      waiting = null;
      showPin(id);
    }
  }

  // A numbered dot on each open pin's part.
  const centres = new Map();
  function drawDots() {
    const open = pinList().filter((one) => !one.resolved && placedAt.get(one.id));
    layer.replaceChildren(...open.map((one) => {
      const dot = document.createElement("button");
      dot.type = "button";
      dot.className = "view3d-pin";
      dot.dataset.pin = String(one.id);
      dot.dataset.n = String(one.n);
      dot.dataset.index = String(placedAt.get(one.id).index);
      dot.textContent = number(one.n);
      dot.setAttribute("aria-label", say("Pin {n}", { n: number(one.n) }));
      return dot;
    }));
    placeDots();
  }
  // Each dot where its part's middle is on the stage, after each frame.
  function placeDots() {
    if (!view || !layer.childElementCount) {
      if (pins.dots.length) pins.dots = [];
      return;
    }
    const box = shell.getBoundingClientRect();
    const rect = view.renderer?.domElement.getBoundingClientRect();
    const out = [];
    for (const dot of layer.children) {
      const i = Number(dot.dataset.index);
      if (!centres.has(i)) centres.set(i, view.centreOf(i));
      const at = rect ? view.onPage(centres.get(i), rect) : null;
      dot.hidden = !at;
      if (!at) continue;
      dot.style.transform = `translate(${(at.x - box.left).toFixed(1)}px, ${(at.y - box.top).toFixed(1)}px) translate(-50%, -50%)`;
      out.push({ n: Number(dot.dataset.n), id: Number(dot.dataset.pin), index: i, x: Math.round(at.x), y: Math.round(at.y) });
    }
    pins.dots = out;
  }
  layer.addEventListener("click", (event) => {
    const dot = event.target.closest(".view3d-pin");
    if (!dot || !view) return;
    engage(true);
    light(Number(dot.dataset.index));
    const words = given.pinPressed?.(Number(dot.dataset.pin));
    if (words) hintFor(words, 6000);
  });

  // [i] lit (a pin's part, or the part being commented on), or none (-1).
  function light(i, keep = true) {
    if (keep) {
      lit = i;
      pins.lit = i;
    }
    if (view) view.outline(i >= 0 ? [i] : [], LIT);
  }

  // The camera turned to pin [id]'s part, once its place here is known.
  function showPin(id) {
    if (!placedYet || !view) {
      waiting = id;
      return;
    }
    const where = placedAt.get(id);
    const one = pinList().find((pin) => pin.id === id);
    if (!where) {
      light(-1);
      hintFor(say("That part is not in this version: the comment was made on version {version}.",
        { version: one ? number(one.version) : "?" }), 6000);
      return;
    }
    engage(true);
    light(where.index);
    view.frameOn(where.index);
    pins.turnedTo = where.index;
    if (where.moved) hintFor(say("The part has moved since the comment was made."), 4000);
  }

  // The menu for part [index], at [x], [y] on the page, asked for by [how]
  // (mouse, touch or key).
  let menuAt = 0;
  let menuHow = "";
  function openMenu(index, x, y, how) {
    if (!view || typeof given.pinWanted !== "function" || !given.mayPin?.()) return;
    if (index < 0) {
      if (how === "key") hintFor(say("Turn the model so a part is in the middle, then press again."));
      return;
    }
    const one = partOf(index);
    pins.lastPicked = { index, part: one.part, colour: one.colour, at: one.at, turn: one.turn };
    pins.menu = "open";
    menuAt = performance.now();
    menuHow = how;
    light(index, false);
    const name = given.partName?.(one.part, one.colour) || one.name;
    const title = document.createElement("p");
    title.className = "view3d-menu-part";
    title.setAttribute("aria-hidden", "true");
    title.textContent = [name, one.colourName].filter(Boolean).join(" · ");
    const go = document.createElement("button");
    go.type = "button";
    go.setAttribute("role", "menuitem");
    go.textContent = say("Comment on this part");
    go.addEventListener("click", () => {
      // The finger that opened it, lifted on it, is not a choice.
      if (menuHow === "touch" && performance.now() - menuAt < 400) return;
      const part = { ...pins.lastPicked, name };
      closeMenu(false);
      light(index);
      if (full) toggleFull();
      given.pinWanted(part);
    });
    menu.setAttribute("aria-label", title.textContent || say("This part"));
    menu.replaceChildren(title, go);
    menu.hidden = false;
    // At the pointer, inside the frame; by touch, up and to the left of
    // the finger, so it is not under it.
    const box = shell.getBoundingClientRect();
    const w = menu.offsetWidth;
    const h = menu.offsetHeight;
    const left = how === "touch" ? x - box.left - w / 2 : x - box.left;
    const top = how === "touch" ? y - box.top - h - 28 : y - box.top;
    menu.style.left = `${Math.max(8, Math.min(box.width - w - 8, left))}px`;
    menu.style.top = `${Math.max(8, Math.min(box.height - h - 8, top < 8 && how === "touch" ? y - box.top + 28 : top))}px`;
    go.focus({ preventScroll: true });
  }
  function closeMenu(back = true) {
    if (menu.hidden) return;
    menu.hidden = true;
    pins.menu = "closed";
    if (back) {
      light(lit, false);
      stage.focus({ preventScroll: true });
    }
  }
  // The browser's own menu is never over this one (the menu key, let go
  // on Windows, opens it on what has the focus); a right click on a dot is
  // one on its part.
  menu.addEventListener("contextmenu", (event) => event.preventDefault());
  layer.addEventListener("contextmenu", (event) => {
    event.preventDefault();
    if (event.target.closest(".view3d-pin") && event.button === 2) {
      openMenu(pickAt(event.clientX, event.clientY), event.clientX, event.clientY, "mouse");
    }
  });
  menu.addEventListener("keydown", (event) => {
    if (event.key === "Escape" || event.key === "Tab") {
      event.preventDefault();
      closeMenu();
    }
  });
  document.addEventListener("pointerdown", (event) => {
    if (!menu.hidden && !menu.contains(event.target)) closeMenu(false);
  }, true);
  const pickAt = (x, y) => (view ? view.pick(x, y) : -1);

  // A right click: the right button pressed and let go where it was (a
  // drag with it pans).
  let right = null;
  stage.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "touch" && event.button === 2) right = { x: event.clientX, y: event.clientY };
  }, true);
  stage.addEventListener("pointerup", (event) => {
    if (event.pointerType === "touch" || event.button !== 2 || !right) return;
    const moved = Math.hypot(event.clientX - right.x, event.clientY - right.y);
    right = null;
    if (moved <= 4) openMenu(pickAt(event.clientX, event.clientY), event.clientX, event.clientY, "mouse");
  }, true);
  // The browser's own menu never: the canvas's is kept from it by
  // OrbitControls; the stage's, which the menu key opens, is here.
  stage.addEventListener("contextmenu", (event) => {
    event.preventDefault();
    if (event.target !== stage || !menu.hidden || performance.now() - menuAt < 1000) return;
    keyMenu();
  });
  // A long press by touch: held still, the finger then turns nothing.
  let press = null;
  let held = null;
  const unpress = () => {
    if (press) clearTimeout(press.timer);
    press = null;
  };
  stage.addEventListener("pointerdown", (event) => {
    if (event.pointerType !== "touch") return;
    unpress();
    // Another finger down already (this one is counted after): a pinch.
    if (touches.size > 0) return;
    const at = { id: event.pointerId, x: event.clientX, y: event.clientY };
    press = { ...at, timer: setTimeout(() => {
      press = null;
      if (!given.mayPin?.()) return;
      held = at.id;
      engage(true);
      openMenu(pickAt(at.x, at.y), at.x, at.y, "touch");
    }, HOLD) };
  }, true);
  stage.addEventListener("pointermove", (event) => {
    if (held === event.pointerId) {
      event.stopPropagation();
      return;
    }
    if (press && press.id === event.pointerId && Math.hypot(event.clientX - press.x, event.clientY - press.y) > HOLD_SLACK) unpress();
  }, true);
  for (const kind of ["pointerup", "pointercancel"]) {
    stage.addEventListener(kind, (event) => {
      if (press && press.id === event.pointerId) unpress();
      if (held === event.pointerId) held = null;
    }, true);
  }
  // From the keys: the part lit, else the one in the middle.
  function keyMenu() {
    if (!view) return;
    const i = lit >= 0 ? lit : view.pickNearMiddle();
    const rect = stage.getBoundingClientRect();
    const at = i >= 0 ? view.onPage(view.centreOf(i)) : null;
    openMenu(i, at ? at.x : rect.left + rect.width / 2, at ? at.y : rect.top + rect.height / 2, "key");
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
    b.setAttribute("aria-label", yes ? say("Leave full screen") : say("Full screen"));
    b.querySelector("use")?.setAttribute("href", `/icons.svg#${yes ? "shrink" : "expand"}`);
    state.full = yes;
    if (view) { view.touch(); requestAnimationFrame(() => view && view.size()); }
  }
  // The window's at once, then the screen's as the browser gives it: a
  // browser drawing a big model slowly took a second or more to say yes,
  // and the button did nothing until then.
  async function toggleFull() {
    if (full) {
      setFull(false);
      if (fullscreen()) await (document.exitFullscreen || document.webkitExitFullscreen).call(document)?.catch(() => {});
      return;
    }
    state.fullscreen = "window";
    setFull(true);
    stage.focus({ preventScroll: true });
    const ask = shell.requestFullscreen || shell.webkitRequestFullscreen;
    if (!ask) return;
    try {
      await ask.call(shell);
      if (full) state.fullscreen = "browser";
      // Left again before the browser said yes.
      else if (fullscreen()) await (document.exitFullscreen || document.webkitExitFullscreen).call(document)?.catch(() => {});
    } catch { /* the window's it stays */ }
  }
  const leftFull = () => { if (full && !fullscreen() && state.fullscreen === "browser") setFull(false); };
  document.addEventListener("fullscreenchange", leftFull);
  document.addEventListener("webkitfullscreenchange", leftFull);

  // What changed: asked of the site once, the first time it is pressed.
  let changes = null;
  let changing = null;
  let changesOn = false;
  const FADED = new Color(0xb8bcc2);
  const fade = (hex) => new Color().setHex(parseInt(hex, 16), SRGBColorSpace).lerp(FADED, 0.78);
  async function whatChanged() {
    if (changes) return changes;
    if (!changing) {
      changing = (async () => {
        const answer = await fetch(given.changes, { credentials: "omit" });
        if (!answer.ok) throw new Error(answer.status === 404 ? say("what it changed is not counted yet") : say("the site said {status}", { status: answer.status }));
        const said = await answer.json();
        // Counted against the packing this page drew: one of another count
        // was packed by another catalogue, and would light the wrong parts.
        if (said.count !== data.n) throw new Error(say("it was counted for another version of its parts"));
        const lit = new Set([...runs(said.added), ...runs(said.recoloured), ...runs(said.moved)]);
        const ghost = said.ghost ? await unpack(sceneShape(said.ghost) || said.ghost) : null;
        changes = { said, lit, ghost };
        return changes;
      })().catch((trouble) => { changing = null; throw trouble; });
    }
    return changing;
  }
  async function showChanges(on) {
    const b = button("changes");
    if (!b || !view) return;
    changesOn = on;
    b.setAttribute("aria-pressed", String(on));
    state.changesOn = on;
    if (!on) {
      view.look = null;
      view.paint();
      view.hideGhosts();
      legend.hidden = true;
      return;
    }
    legend.hidden = false;
    legend.textContent = say("Getting what changed…");
    let got;
    try {
      got = await whatChanged();
    } catch (trouble) {
      legend.textContent = say("What changed could not load: {why}.", { why: trouble.message });
      changesOn = false;
      b.setAttribute("aria-pressed", "false");
      state.changesOn = false;
      return;
    }
    if (!changesOn) return;
    const faded = data.colours.map((c) => fade(c.hex));
    view.look = (i) => (got.lit.has(i) ? null : { colour: faded[data.colour[i]] });
    view.paint();
    const counts = got.said.counts || {};
    const lit = (counts.added || 0) + (counts.recoloured || 0) + (counts.moved || 0);
    legend.textContent = [lit ? say("In colour: {changed}", { changed: [counts.added ? say("{n} added", { n: number(counts.added) }) : "",
      counts.recoloured ? say("{n} recoloured", { n: number(counts.recoloured) }) : "",
      counts.moved ? say("{n} moved", { n: number(counts.moved) }) : ""].filter(Boolean).join(", ") }) : "",
    counts.removed ? (got.ghost ? say("faint red: {n} taken away", { n: number(counts.removed) })
      : say("{n} taken away, too many to draw", { n: number(counts.removed) })) : "",
    !lit && !counts.removed ? say("No parts changed") : ""].filter(Boolean).join(" · ");
    if (got.ghost) await view.addGhosts(got.ghost);
  }

  const act = {
    changes: () => showChanges(!changesOn),
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
    if (event.key === "ContextMenu" || (event.key === "F10" && event.shiftKey)) {
      event.preventDefault();
      engage(true);
      keyMenu();
      return;
    }
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
      hintFor(say("Press the model first to zoom it with the wheel, or use + and −"));
    }
  }, { capture: true, passive: true });

  new ResizeObserver(() => { if (view) view.size(); }).observe(stage);

  function close() {
    if (full) toggleFull();
    closeMenu(false);
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
  // What changed as drawn: the lit parts' indexes, how many are faded, the
  // ghosts drawn (View.drawnChanges), and what the site said.
  state.changes = () => (view ? { on: changesOn, ...view.drawnChanges(), said: changes ? changes.said : null } : null);
  // The brick the viewer's own pick finds at [x], [y] on the page (a
  // pointer's clientX and clientY), or -1: what a check holds a pin to.
  state.pickAt = pickAt;
  start();
  return {
    open,
    close,
    changes: (on) => (state.state === "ready" ? showChanges(on) : (given.changesOn = on)),
    // The page's pins changed (a comment added, resolved or removed):
    // placed again where this version's parts are in.
    pinsChanged: () => { if (placedYet) place(); },
    showPin,
    light: (i) => light(Number.isInteger(i) ? i : -1),
  };
}

/// The indexes runs give ([first, how many] each, api/_remix_changes.js runsOf).
function runs(list) {
  const out = [];
  for (const run of Array.isArray(list) ? list : []) {
    if (!Array.isArray(run) || !Number.isInteger(run[0]) || !Number.isInteger(run[1])) continue;
    for (let k = 0; k < run[1] && k < 1e6; k++) out.push(run[0] + k);
  }
  return out;
}
