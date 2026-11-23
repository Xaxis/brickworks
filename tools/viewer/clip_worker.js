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
import { sceneShape, unpack } from "./scene.js";
import { LOOKS, View, shapes } from "./view.js";
import { CLIP, recordClip } from "../../web/turntable-clip.js";

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
    this.renderer.setSize(CLIP.width, CLIP.height, false);
    this.camera.aspect = CLIP.width / CLIP.height;
    this.camera.updateProjectionMatrix();
    this.light();
    this.frame();
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

addEventListener("message", (event) => {
  const given = event.data || {};
  if (typeof given.visible === "boolean") {
    shown = given.visible;
    if (shown && showing) { showing(); showing = null; }
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

async function record({ scene: at, of, kind, coarse }) {
  if (!draws()) return { how: "cannot-draw" };
  const answer = await fetch(at, { credentials: "omit", cache: "no-store" }).catch(() => null);
  if (!answer || !answer.ok) return { how: "cannot-draw" };
  const scene = sceneShape(await answer.json().catch(() => null));
  if (!scene || scene.count < 1) return { how: "cannot-draw" };
  // The scene of the very version the clip is sent as, or none.
  if (scene.of !== of) return { how: "stale", of: String(scene.of || "") };
  if (scene.triangles > (coarse ? BUDGET.coarse : BUDGET.fine)) return { how: "cannot-draw", triangles: scene.triangles };
  const data = await unpack(scene).catch(() => null);
  if (!data) return { how: "cannot-draw" };
  const errors = [];
  const view = new ClipView(null, data, { still: false, spin: true, ...LOOKS.app, errors,
    shapeOf: shapes(scene.root, { errors }) });
  try {
    view.start();
    await view.load(() => {});
    // A clip of boxes is no clip.
    if (errors.length || !view.renderer) return { how: "cannot-draw", errors: errors.slice(0, 3) };
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
