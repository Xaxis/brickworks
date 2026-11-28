// A model's clip, recorded in a worker (unit turntable, ttfix): the model
// turning once round, drawn as its page's 3D view draws it (view.js), on
// an OffscreenCanvas the clip's own size, and written by
// web/turntable-clip.js. Built by tools/viewer/build.mjs as
// web/turntable-worker.js, which web/model-page.js starts on its
// designer's visit to its page; nothing of it runs on the page's own
// thread, so the page stays as quick while it records as before it did
// (ttreview F6: on the page's thread every frame was a long task, 96 of
// them on a big model).
//
// The page sends {scene, of, kind, coarse}: the scene's address with its
// version (and when that version was made, so no CDN gives an older
// version 1's), what it must say it is ("m:<id>:<version>"), the kind of
// file to write, and whether the device has a coarse pointer (a phone or
// a tablet, which gets the smaller budget). Then {visible} as the page is
// shown or hidden: only while it is shown does it draw. It answers
// {how, clip, bytes, ms, of} once: how "recorded" with the clip in base64
// and the version its scene said it was (of), or
// why not: "stale" (the scene is another version's: ttreview F2),
// "cannot-draw" (no WebGL 2 here, past the clip's budget, nothing in it,
// a part's geometry that did not come), "slow" (past its time), "failed".
//
// Or, for a kit to post elsewhere (unit postkit, web/post-kit.js), the page
// sends {kit: {scene, coarse, stills, turn}} as often as its designer asks
// for one: the scene the page's own 3D view loads, drawn once and kept
// while the page is open, so a second kit fetches nothing. Each still
// {key, width, height, turn, high, wordmark} is the model turned [turn] of a
// whole turn from where its page's view starts (higher where [high]), on
// the backdrop the clip has, a JPEG; [turn], where given, {width, height,
// fps, frames, maxBytes, bitrate, kind}, a turn as recordClip writes one.
// It answers {progress, of} as it goes and then {how: "drawn", stills:
// [{key, blob, width, height, drawn}], clip, clipWhy, timing, ms}, [drawn]
// being what is on each (web/turntable-clip.js easel), [clipWhy] why no
// turn was made where none was, [timing] {load, stills, turn} in ms; or
// {how} as a clip does.
import { Vector3 } from "three";
import { sceneShape, unpack } from "./scene.js";
import { LOOKS, View, shapes } from "./view.js";
import { CLIP, easel, recordClip } from "../../web/turntable-clip.js";

// The triangles a clip is drawn from, at most: 768 by 432 is a fraction
// of the 3D view's pixels, and a device spends no more on a clip nobody is
// watching than on a model it turns for somebody who is. The gallery's
// biggest model (EzEXhtXE2C, 10,101 bricks) is 2.8 million.
const BUDGET = { coarse: 1.5e6, fine: 3e6 };
// How long it may draw, shown, before it stops: a device that takes
// longer for 96 frames is one a clip costs too much on.
const DRAWING_MS = 120000;

/// The model's own View, drawn on an OffscreenCanvas the clip's size at a
/// pixel ratio of 1, turned by the clip alone: no controls, no page.
class ClipView extends View {
  start() {
    this.prepare(new OffscreenCanvas(CLIP.width, CLIP.height), 1);
    this.shape(CLIP.width, CLIP.height);
    this.light();
  }

  /// Drawn [width] by [height] from here on, framed for that shape from
  /// [from] (where its page's view starts, unless another is given): whole
  /// at every turn where it is [turning], as a clip turns it, else filling
  /// the frame from there alone, as a still is taken.
  shape(width, height, from = LOOKS.app.from, turning = true) {
    this.renderer.setSize(width, height, false);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.from = new Vector3(...from).normalize();
    const spin = this.o.spin;
    this.o.spin = turning;
    this.frame();
    this.o.spin = spin;
  }

  // Drawn only when the clip asks for a frame.
  render() {}

  stop() {
    if (!this.renderer) return;
    const renderer = this.renderer;
    this.renderer = null;
    renderer.dispose();
    renderer.forceContextLoss();
  }
}

let shown = true;
let showing = null;
let asked = false;
// The kits asked for, one after another.
let kits = Promise.resolve();

addEventListener("message", (event) => {
  const given = event.data || {};
  if (typeof given.visible === "boolean") {
    shown = given.visible;
    if (shown && showing) { showing(); showing = null; }
    return;
  }
  if (given.kit && typeof given.kit.scene === "string") {
    kits = kits.then(() => kit(given.kit)).then((answer) => postMessage(answer), () => postMessage({ how: "failed" }));
    return;
  }
  if (asked || typeof given.scene !== "string") return;
  asked = true;
  record(given).then((answer) => postMessage(answer), () => postMessage({ how: "failed" }));
});

/// Waited on before each frame: while the page is hidden, until it is
/// shown again; then whether its time is up.
function gate(clock, stop) {
  return async () => {
    if (!shown) {
      clock.pause();
      await new Promise((done) => { showing = done; });
      clock.resume();
    }
    if (clock.spent() > DRAWING_MS) stop.abort();
  };
}

/// Time spent while the page was shown.
function clock() {
  let spent = 0;
  let since = performance.now();
  return {
    pause() { spent += performance.now() - since; since = null; },
    resume() { since = performance.now(); },
    spent() { return spent + (since === null ? 0 : performance.now() - since); },
  };
}

/// Whether this worker can draw in 3D: WebGL 2 on an OffscreenCanvas.
function draws() {
  try {
    const gl = typeof OffscreenCanvas === "function" ? new OffscreenCanvas(1, 1).getContext("webgl2") : null;
    if (!gl) return false;
    const lose = gl.getExtension("WEBGL_lose_context");
    if (lose) lose.loseContext();
    return true;
  } catch {
    return false;
  }
}

/// The scene at [at] read ({scene} or {how} why not), from the network
/// ([cache] "no-store") or as the page's own 3D view reads it ("default").
async function sceneAt(at, coarse, cache) {
  if (!draws()) return { how: "cannot-draw" };
  // The site's own, with its cookies (a preview's bypass), as inline.js asks it.
  const answer = await fetch(at, { credentials: "same-origin", cache }).catch(() => null);
  if (!answer || !answer.ok) return { how: "cannot-draw" };
  const scene = sceneShape(await answer.json().catch(() => null));
  if (!scene || scene.count < 1) return { how: "cannot-draw" };
  if (scene.triangles > (coarse ? BUDGET.coarse : BUDGET.fine)) return { how: "cannot-draw", triangles: scene.triangles, of: scene.of };
  return { scene };
}

/// [scene]'s View, drawn, its every part's geometry come: {view} or {how}.
async function viewOf(scene) {
  const data = await unpack(scene).catch(() => null);
  if (!data) return { how: "cannot-draw" };
  const errors = [];
  const view = new ClipView(null, data, { still: false, spin: true, ...LOOKS.app, errors,
    shapeOf: shapes(scene.root, { errors }) });
  try {
    view.start();
    await view.load(() => {});
  } catch (trouble) {
    view.stop();
    throw trouble;
  }
  // A clip of boxes is no clip.
  if (errors.length || !view.renderer) {
    view.stop();
    return { how: "cannot-draw", errors: errors.slice(0, 3) };
  }
  return { view };
}

async function record({ scene: at, of, kind, coarse }) {
  const read = await sceneAt(at, coarse, "no-store");
  if (!read.scene) {
    if (read.of && read.of !== of) return { how: "stale", of: String(read.of) };
    return read.triangles ? { how: read.how, triangles: read.triangles } : { how: read.how };
  }
  const { scene } = read;
  // The scene of the very version the clip is sent as, or none.
  if (scene.of !== of) return { how: "stale", of: String(scene.of || "") };
  const ready = await viewOf(scene);
  if (!ready.view) return ready;
  const { view } = ready;
  try {
    const { eye, target } = view.home;
    const offset = eye.clone().sub(target);
    const up = view.camera.up.clone();
    const time = clock();
    const stop = new AbortController();
    const made = await recordClip((share) => {
      view.camera.position.copy(target).add(offset.clone().applyAxisAngle(up, -share * 2 * Math.PI));
      view.camera.lookAt(target);
      view.draw();
      return view.renderer.domElement;
    }, { kind, signal: stop.signal, gate: gate(time, stop) });
    if (stop.signal.aborted) return { how: "slow", ms: Math.round(time.spent()) };
    if (!made) return { how: "failed" };
    let text = "";
    for (let k = 0; k < made.bytes.length; k += 0x8000) text += String.fromCharCode(...made.bytes.subarray(k, k + 0x8000));
    return { how: "recorded", clip: btoa(text), kind: made.kind, bytes: made.bytes.length, ms: Math.round(time.spent()),
      triangles: scene.triangles, of: scene.of };
  } finally {
    view.stop();
  }
}

// ---------------------------------------------------------------------------
// A kit's pictures and its turn (unit postkit).

// The scene drawn for kits, kept while the page is open: {at, view} once
// read, so the second kit asks for nothing.
let kitView = null;

/// [view]'s camera turned [share] of a whole turn from where it starts.
function turnTo(view, share) {
  const { eye, target } = view.home;
  const offset = eye.clone().sub(target);
  view.camera.position.copy(target).add(offset.applyAxisAngle(view.camera.up, -share * 2 * Math.PI));
  view.camera.lookAt(target);
}

// The axis a model turns about.
const UP = new Vector3(0, 1, 0);

// Where a still taken from higher looks down from: as the page's view,
// turned the same way round, at 55 degrees.
const HIGH = (() => {
  const [x, , z] = LOOKS.app.from;
  const level = Math.hypot(x, z);
  const down = (55 * Math.PI) / 180;
  return [(x / level) * Math.cos(down), Math.sin(down), (z / level) * Math.cos(down)];
})();

async function kit({ scene: at, coarse, stills = [], turn = null }) {
  const started = performance.now();
  // How long each part took, for the page to say (window.brickworksKit).
  const timing = { load: 0, stills: [], turn: 0 };
  if (!kitView || kitView.at !== at) {
    if (kitView) kitView.view.stop();
    kitView = null;
    const read = await sceneAt(at, coarse, "default");
    if (!read.scene) return read;
    const ready = await viewOf(read.scene);
    if (!ready.view) return ready;
    kitView = { at, view: ready.view };
    timing.load = Math.round(performance.now() - started);
  }
  const { view } = kitView;
  const of = stills.length + (turn ? 1 : 0);
  let done = 0;
  const drawn = [];
  for (const still of stills) {
    const begun = performance.now();
    // Turned [turn] of the way round from where its page's view starts, and
    // framed from there alone: the model fills each still.
    const from = new Vector3(...(still.high ? HIGH : LOOKS.app.from)).applyAxisAngle(UP, -(still.turn || 0) * 2 * Math.PI);
    view.shape(still.width, still.height, [from.x, from.y, from.z], false);
    turnTo(view, 0);
    view.draw();
    const page = easel({ width: still.width, height: still.height, wordmark: still.wordmark === true });
    page.paint(view.renderer.domElement);
    const blob = await page.canvas.convertToBlob({ type: "image/jpeg", quality: 0.92 });
    drawn.push({ key: still.key, blob, width: still.width, height: still.height, drawn: page.drawn });
    timing.stills.push(Math.round(performance.now() - begun));
    postMessage({ progress: ++done, of });
  }
  let clip = null;
  const report = {};
  if (turn) {
    const begun = performance.now();
    // Drawn at the size this device draws in time, and set on the turn's
    // whole frame: a frame of the full size that takes longer than a
    // twentieth of a second is drawn at half.
    view.shape(turn.width, turn.height);
    turnTo(view, 0);
    const timed = performance.now();
    view.draw();
    view.renderer.getContext().finish();
    const half = performance.now() - timed > 50;
    if (half) view.shape(Math.round(turn.width / 2), Math.round(turn.height / 2));
    const made = await recordClip((share) => {
      turnTo(view, share);
      view.draw();
      return view.renderer.domElement;
    }, { kind: turn.kind || "", shape: { ...turn, wordmark: turn.wordmark !== false }, report });
    if (made) clip = { bytes: made.bytes, kind: made.kind, type: made.type, width: made.width, height: made.height,
      ms: made.ms, drawnAt: half ? "half" : "full" };
    timing.turn = Math.round(performance.now() - begun);
    postMessage({ progress: ++done, of });
  }
  return { how: "drawn", stills: drawn, clip, clipWhy: clip ? "" : report.why || "", timing,
    ms: Math.round(performance.now() - started) };
}
