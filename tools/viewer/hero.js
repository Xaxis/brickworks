// The home's hero (hero3d, 2026-11-23): the Brickworks mark built in real
// LEGO® parts (tools/web/hero_mark.mjs, web/hero/mark.json), alive in the
// page. The owner: "obviously the hero should in some way contain a
// brilliant 3D variation of our logo or something to do with LEGO".
//
// Built into web/viewer3d.js with the rest of the site's viewer (inline.js),
// which web/landing.js imports only once the page is drawn, the hero is on
// the screen and the browser is idle, on a device that draws in 3D; until
// then, and for good on one that cannot, the page shows its poster, a
// picture of the finished model drawn by this same code
// (tools/web/hero_poster.mjs), so the model takes the poster's place without
// a jump. Once a visit (sessionStorage), it assembles: the bricks come down
// into place a course at a time, the app's own steps (each course is one),
// in about 2.5 s; then it sways slowly about the mark's own view. A drag or a
// touch across turns it and it settles back; the arrow keys turn it, focused;
// a brick lifts a little under the pointer. Somebody who asks for less
// motion sees it finished and still, and turns it by hand.
//
// Drawn as the site's viewer draws a model (view.js): each part's own
// geometry, from the app's .lbm, as instances in the bricks' own colours,
// lit as in a studio (STUDIO): a soft key light with its real shadow on the
// ground and in the cut, a fill, a rim, and the room in the gloss. What no camera here sees is left out:
// each part's inside and underneath (hero_mark.mjs), and the studs a course
// covers, drawn as one instanced stud only where nothing sits on them, so
// the finished mark is ~8,000 triangles a phone draws at its frame rate.
import {
  BufferAttribute, BufferGeometry, CanvasTexture, Color, DirectionalLight, HemisphereLight, InstancedMesh, Matrix4, Mesh,
  MeshBasicMaterial, MeshStandardMaterial, NeutralToneMapping, PCFShadowMap, PerspectiveCamera, PlaneGeometry,
  Quaternion, Raycaster, Scene, ShadowMaterial, SRGBColorSpace, Vector2, Vector3, WebGLRenderer,
} from "three";
import { INHERIT, parseLbm } from "../../web/lbm.js";
import { unpack } from "./scene.js";
import { geometryOf } from "./view.js";

// The mark's own view: from the corner the cut is in, as icon.svg draws it
// (isometric: 45 degrees round, 35.26 up), through a long lens.
export const HOME = { round: Math.PI / 4, up: Math.atan(1 / Math.SQRT2), fov: 17 };
// The sway once built: how far round and how slowly.
const SWAY = (24 * Math.PI) / 180;
const PERIOD = 11;
// Then still, after this long with nobody near it: a page does not move for ever.
const RESTS_AFTER = 45;
// The assembly. It begins as the poster is, built: the bricks leave up and
// out of the picture, the top course first (UP s each, a course every AWAY
// s); then they come down from over the picture's top, a course every GAP
// s, the bottom one first, each falling as a dropped thing does (FALL s from
// the highest), and land with the smallest bounce: about 2.7 s in all.
// Nothing appears in mid-air: each starts over the picture's top, and the
// top fades what crosses it (web/index.html .hero-stage.assembling).
const AWAY = 0.016;
const UP = 0.26;
const GAP = 0.11;
const FALL = 0.56;
// A brick under the pointer lifts this far (LDU), a third of a plate under a brick's height.
const LIFT = 7;
const TURN = Math.PI / 12;
const KEPT = "brickworks.hero";

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
// A brick's own small lateness within its course, the same every visit.
const late = (i) => ((Math.sin(i * 12.9898) * 43758.5453) % 1 + 1) % 1;

function bytesOf(base64) {
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

// The room the plastic reflects, and the two lights besides the key, worked
// out where they are seen rather than looked up in a prefiltered map
// (PMREM, three's own) or lit as lights: a floor darker than the ceiling, and
// the key's, the fill's and the rim's soft boxes, each a lobe that widens
// with the surface's roughness; the fill and the rim light the body too. In
// software (SwiftShader, a weak laptop's fallback) the map's look-ups were
// half of each frame and each light a fifth.
const FILL = "vec3(0.951, 0.293, -0.110)";
const RIM = "vec3(-0.536, 0.447, -0.715)";
const STUDIO = `
vec3 studio(vec3 d, float rough) {
\tfloat sharp = mix(64.0, 4.0, rough);
\tfloat keep = mix(1.0, 0.3, rough);
\tvec3 c = mix(vec3(0.24, 0.235, 0.23), vec3(0.74, 0.75, 0.79), smoothstep(-0.2, 0.75, d.y));
\tc += vec3(1.7, 1.62, 1.5) * keep * pow(max(dot(d, vec3(-0.471, 0.770, 0.428)), 0.0), sharp);
\tc += vec3(0.62, 0.66, 0.74) * keep * pow(max(dot(d, ${FILL}), 0.0), sharp);
\tc += vec3(0.8) * keep * pow(max(dot(d, ${RIM}), 0.0), sharp);
\treturn c;
}`;

// ABS: a hard gloss over a coloured body, the room in it. A part's [box]
// (its body's, without studs): the seam round each of its faces drawn dark,
// a pixel or so wide whatever the size, where one brick meets the next, as
// the small gap between real bricks reads; LDraw's own shapes meet flush,
// and a wall of them read as one painted block.
function plastic(box = null) {
  const m = new MeshStandardMaterial({ color: 0xffffff, roughness: 0.24, metalness: 0 });
  m.onBeforeCompile = (shader) => {
    if (box) {
      shader.uniforms.boxLow = { value: box.min };
      shader.uniforms.boxHigh = { value: box.max };
    }
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vLocal;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvLocal = position;");
    const seam = box ? `vec3 edge = min(vLocal - boxLow, boxHigh - vLocal);
\tfloat edgeLow = min(edge.x, min(edge.y, edge.z));
\tfloat edgeHigh = max(edge.x, max(edge.y, edge.z));
\tfloat edgeMid = edge.x + edge.y + edge.z - edgeLow - edgeHigh;
\tfloat edgeW = fwidth(edgeMid);
\tfloat seam = 1.0 - smoothstep(0.2 * edgeW, 1.05 * edgeW + 0.1, edgeMid);` : "float seam = 0.0;";
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", `#include <common>\nvarying vec3 vLocal;${box ? "\nuniform vec3 boxLow;\nuniform vec3 boxHigh;" : ""}${STUDIO}`)
      .replace("void main() {", `void main() {\n\t${seam}`)
      .replace("#include <lights_fragment_maps>", `#include <lights_fragment_maps>
\t{
\t\tvec3 seen = inverseTransformDirection(geometryViewDir, viewMatrix);
\t\tvec3 facing = inverseTransformDirection(geometryNormal, viewMatrix);
\t\tradiance += studio(reflect(-seen, facing), material.roughness);
\t\tirradiance += vec3(1.2, 1.26, 1.38) * max(dot(facing, ${FILL}), 0.0) + vec3(0.7) * max(dot(facing, ${RIM}), 0.0)
\t\t\t+ vec3(1.1, 1.06, 1.0) * max(dot(facing, vec3(-0.2, 0.25, 0.947)), 0.0);
\t}`)
      .replace("#include <opaque_fragment>", "outgoingLight *= 1.0 - 0.5 * seam;\n\t#include <opaque_fragment>");
  };
  m.customProgramCacheKey = () => (box ? "hero-brick" : "hero-stud");
  return m;
}

/// The hero in [stage] (web/index.html's .hero-stage, over its poster):
/// {ready, stop} once drawn, ready a promise of whether it took the
/// poster's place. [given]: scene (web/hero/mark.json's address), still
/// (no motion: prefers-reduced-motion), assemble (false: finished at once),
/// name (what the stage is called once it turns), timed (each frame drawn to the end,
/// for a check), keep (the drawing kept, and nothing moving: the poster's
/// picture, tools/web/hero_poster.mjs), slow
/// (ms: a frame drawn slower than this is a device too weak for it, and
/// the poster stays).
export async function hero3d(stage, given = {}) {
  const state = window.brickworksHero = window.brickworksHero || { state: "loading", timings: {}, errors: [] };
  const timings = state.timings;
  const markTime = (what) => { if (!timings[what]) timings[what] = Math.round(performance.now()); };
  markTime("code");
  const still = given.still ?? matchMedia("(prefers-reduced-motion: reduce)").matches;
  const answer = await fetch(given.scene || "/hero/mark.json", { credentials: "omit" });
  if (!answer.ok) throw new Error(`the mark answered ${answer.status}`);
  const s = await answer.json();
  const d = await unpack(s);
  markTime("scene");

  const canvas = document.createElement("canvas");
  canvas.className = "hero-canvas";
  canvas.setAttribute("aria-hidden", "true");
  const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: Boolean(given.keep) });
  // The screen's own pixels, at most two a CSS pixel; while the bricks fly
  // (the assembly, after the first moment and up to the last landing) 0.7
  // of that across, half the pixels to shade, where nothing is still
  // enough to be looked at closely.
  const sharp = Math.min(window.devicePixelRatio || 1, 2);
  renderer.setPixelRatio(sharp);
  let flying = false;
  const fly = (on) => {
    if (on === flying) return;
    flying = on;
    renderer.setPixelRatio(on ? sharp * 0.7 : sharp);
    renderer.setSize(Math.max(1, stage.clientWidth), Math.max(1, stage.clientHeight), false);
  };
  renderer.outputColorSpace = SRGBColorSpace;
  renderer.toneMapping = NeutralToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.setClearColor(0x000000, 0);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = PCFShadowMap;
  // The light and the bricks keep still while the camera sways: the shadow
  // is drawn again only when a brick moves (place).
  renderer.shadowMap.autoUpdate = false;
  const gl = renderer.getContext();

  const scene = new Scene();
  // The model's middle and size: 12 studs a side, 240 LDU tall, on y 0.
  const centre = new Vector3(0, 122, 0);
  scene.add(new HemisphereLight(0xffffff, 0xb4aea8, 2.3));
  // The key: soft, high and from the left of the mark's view, so the top is
  // the brightest face, the left the next and the right the darkest, as the
  // mark's own three faces are.
  const key = new DirectionalLight(0xfff4e6, 2.7);
  key.position.set(-330, 540, 300).add(centre);
  key.target.position.copy(centre);
  key.castShadow = true;
  key.shadow.mapSize.set(512, 512);
  key.shadow.camera.left = -260; key.shadow.camera.right = 260;
  key.shadow.camera.top = 260; key.shadow.camera.bottom = -260;
  // Its shadows begin at the mark's own reach (215 LDU round its middle,
  // and a lifted brick's): a brick in the air during the assembly, up out
  // of the picture, casts none on what is seen.
  key.shadow.camera.near = key.position.distanceTo(centre) - 235; key.shadow.camera.far = 1400;
  key.shadow.bias = -0.0004;
  key.shadow.normalBias = 0.6;
  key.shadow.radius = 3;
  scene.add(key, key.target);
  // The fill, from the right, and the rim, behind for the studs' and the
  // edges' highlights as it turns: the plastic's own (STUDIO).
  // The ground: the key's shadow, and a soft one under it all.
  // The key's fades out round the mark, so it ends softly inside the
  // picture, never at its edge (it falls to the picture's right, longer
  // than the room the mark is framed with).
  const groundShade = new ShadowMaterial({ opacity: 0.22 });
  groundShade.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader
      .replace("void main() {", "varying vec2 vGround;\nvoid main() {\n\tvGround = position.xy;");
    shader.fragmentShader = shader.fragmentShader
      .replace("void main() {", "varying vec2 vGround;\nvoid main() {")
      .replace("opacity * ( 1.0 - getShadowMask() )", "opacity * ( 1.0 - getShadowMask() ) * ( 1.0 - smoothstep( 150.0, 235.0, length( vGround ) ) )");
  };
  // As wide as the shadow reaches (it is gone at 235 LDU): every pixel of
  // it is a look in the key's shadow, a seventh of a frame over the whole
  // picture.
  const ground = new Mesh(new PlaneGeometry(480, 480), groundShade);
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);
  scene.add(softShadow());

  // Each part's shape, its studs apart.
  const shapes = d.meshes.map((m) => parseLbm(bytesOf(s.shapes[m.hash])));
  const studShape = parseLbm(bytesOf(s.stud));
  const colours = d.colours.map((c) => new Color().setHex(parseInt(c.hex, 16), SRGBColorSpace));
  const n = d.n;
  const groups = [];
  // Drawn top course first (the file's order is the courses' from the
  // ground), nearest the camera first, so what is behind them is found
  // hidden before it is shaded.
  const byMesh = new Map();
  for (let i = n - 1; i >= 0; i--) {
    if (!byMesh.has(d.mesh[i])) byMesh.set(d.mesh[i], []);
    byMesh.get(d.mesh[i]).push(i);
  }
  for (const [m, bricks] of byMesh) {
    for (const surface of shapes[m].surfaces) {
      const geometry = geometryOf(surface);
      const g = new InstancedMesh(geometry, plastic(geometry.boundingBox), bricks.length);
      g.userData = { bricks, fixed: surface.colour === INHERIT ? null : surface.colour };
      g.castShadow = true;
      g.receiveShadow = true;
      g.frustumCulled = false;
      g.renderOrder = -s.course[bricks[0]];
      scene.add(g);
      groups.push(g);
    }
  }
  const studTotal = s.studs.length / 5;
  const studs = new InstancedMesh(geometryOf(studShape.surfaces[0]), plastic(), studTotal);
  studs.castShadow = true;
  studs.receiveShadow = true;
  studs.frustumCulled = false;
  scene.add(studs);
  // The studs of bricks in the air, each a third of a stud's triangles: a
  // quarter of the assembly's frame went on them, a few pixels each as
  // they fall.
  const flyingStuds = new InstancedMesh(roughStud(), studs.material, studTotal);
  flyingStuds.receiveShadow = true;
  flyingStuds.frustumCulled = false;
  flyingStuds.count = 0;
  scene.add(flyingStuds);

  // Each brick's rest, and how it is now: how far over its rest (fall, lift)
  // and how much of it shows.
  const rest = [];
  const turn = [];
  for (let i = 0; i < n; i++) {
    rest.push(new Vector3(d.position[i * 3], d.position[i * 3 + 1], d.position[i * 3 + 2]));
    turn.push(new Quaternion(d.turn[i * 4], d.turn[i * 4 + 1], d.turn[i * 4 + 2], d.turn[i * 4 + 3]));
  }
  const course = Int32Array.from(s.course);
  const courses = Math.max(...course) + 1;
  const over = new Float32Array(n);
  const come = new Uint8Array(n).fill(1);
  const landed = new Uint8Array(n).fill(1);
  const lift = new Float32Array(n);

  const matrix = new Matrix4();
  const nowhere = new Matrix4().makeScale(0, 0, 0);
  const one = new Vector3(1, 1, 1);
  const p = new Vector3();
  const tint = new Color();
  function place() {
    for (const g of groups) {
      const { bricks, fixed } = g.userData;
      for (let k = 0; k < bricks.length; k++) {
        const i = bricks[k];
        p.copy(rest[i]);
        p.y += over[i] + lift[i];
        g.setMatrixAt(k, come[i] ? matrix.compose(p, turn[i], one) : nowhere);
        if (!g.instanceColor || placedColours === false) {
          g.setColorAt(k, fixed === null ? colours[d.colour[i]] : tint.setHex(0x9a9a9a));
        }
      }
      g.instanceMatrix.needsUpdate = true;
      if (g.instanceColor) g.instanceColor.needsUpdate = true;
    }
    placedColours = true;
    renderer.shadowMap.needsUpdate = true;
    // Each stud on a brick that has come, where nothing has come down on it
    // yet, or what is on it is lifted.
    let k = 0;
    let q = 0;
    for (let t = 0; t < studTotal; t++) {
      const i = s.studs[t * 5];
      const cover = s.studs[t * 5 + 4];
      if (!come[i]) continue;
      if (cover >= 0 && landed[cover] && lift[cover] < 0.5) continue;
      p.set(s.studs[t * 5 + 1], s.studs[t * 5 + 2] + over[i] + lift[i], s.studs[t * 5 + 3]);
      const into = landed[i] ? studs : flyingStuds;
      const at = landed[i] ? k++ : q++;
      into.setMatrixAt(at, matrix.compose(p, turn[i], one));
      into.setColorAt(at, colours[d.colour[i]]);
    }
    for (const [m, count] of [[studs, k], [flyingStuds, q]]) {
      m.count = count;
      m.instanceMatrix.needsUpdate = true;
      if (m.instanceColor) m.instanceColor.needsUpdate = true;
    }
  }
  let placedColours = false;

  // Where the camera is: round and up about the middle, at the distance
  // that fits the model in the stage at every turn of its sway.
  const camera = new PerspectiveCamera(HOME.fov, 1, 10, 20000);
  const view = { round: HOME.round, up: HOME.up, distance: 1000 };
  const off = { round: 0, up: 0, vRound: 0, vUp: 0 };
  const corners = [];
  for (let k = 0; k < 8; k++) corners.push(new Vector3(k & 1 ? 120 : -120, k & 2 ? 244 : 0, k & 4 ? 120 : -120));
  function fit() {
    const w = Math.max(1, stage.clientWidth);
    const h = Math.max(1, stage.clientHeight);
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    const tanUp = Math.tan((HOME.fov * Math.PI) / 360);
    const tanAcross = tanUp * camera.aspect;
    // The share of the stage the model may fill, across and up.
    const room = given.room || 0.9;
    let distance = 0;
    // Fitted to its sway for everybody, so the poster (drawn so) is the
    // first frame's size whoever sees it.
    for (const a of [HOME.round - SWAY, HOME.round, HOME.round + SWAY]) {
      const back = new Vector3(Math.cos(HOME.up) * Math.sin(a), Math.sin(HOME.up), Math.cos(HOME.up) * Math.cos(a));
      const right = new Vector3(Math.cos(a), 0, -Math.sin(a));
      const up = new Vector3().crossVectors(back, right);
      for (const c of corners) {
        const v = c.clone().sub(centre);
        const z = v.dot(back);
        distance = Math.max(distance, z + Math.abs(v.dot(right)) / (tanAcross * room), z + Math.abs(v.dot(up)) / (tanUp * room));
      }
    }
    view.distance = distance;
    camera.near = distance / 20;
    camera.far = distance * 6;
    camera.updateProjectionMatrix();
  }
  function aim(time) {
    const a = view.round + off.round + (still ? 0 : sway(time));
    const u = clamp(view.up + off.up, 0.08, 1.25);
    camera.position.set(Math.cos(u) * Math.sin(a), Math.sin(u), Math.cos(u) * Math.cos(a)).multiplyScalar(view.distance).add(centre);
    camera.lookAt(centre);
  }
  // The sway's share: none during the assembly, eased in after it, eased
  // out once it rests.
  let swayShare = 0;
  let swayFrom = 0;
  const sway = (time) => swayShare * SWAY * Math.sin(((time - swayFrom) * 2 * Math.PI) / PERIOD);

  // Drawn: each frame while anything moves, and only while the hero is on
  // the screen and the tab is in front.
  let running = false;
  let onScreen = true;
  let last = 0;
  let restAt = 0;
  let assembly = null;
  let dragging = null;
  let keyed = 0;
  let hovered = -1;
  let lost = false;
  const frames = state.frames = [];
  // [sync]: waited for to the end (a pixel read back waits for the
  // graphics), to time it: SwiftShader draws behind the page.
  function draw(time, sync = Boolean(given.timed || given.keep)) {
    aim(time);
    const begun = performance.now();
    renderer.render(scene, camera);
    if (sync) gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
    const took = performance.now() - begun;
    if (given.timed && assembly) frames.push(Math.round(took * 10) / 10);
    return took;
  }
  function frame(now) {
    running = false;
    if (lost || !onScreen || document.hidden) return;
    const time = now / 1000;
    const dt = last ? Math.min(0.05, time - last) : 1 / 60;
    last = time;
    let moving = false;
    if (assembly) moving = assemble(time) || moving;
    if (!assembly && !still) {
      const resting = time > restAt;
      swayShare = clamp(swayShare + (resting ? -dt / 2 : dt / 1.6), 0, 1);
      if (swayShare > 0) moving = true;
    }
    if (!dragging) {
      const settling = !still && time > keyed;
      if (settling && (Math.abs(off.round) > 1e-4 || Math.abs(off.up) > 1e-4 || Math.abs(off.vRound) > 1e-4)) {
        // Back to where it sways, as a spring that does not overshoot.
        const w = 4.2;
        off.vRound += (-w * w * off.round - 2 * w * off.vRound) * dt;
        off.vUp += (-w * w * off.up - 2 * w * off.vUp) * dt;
        off.round += off.vRound * dt;
        off.up += off.vUp * dt;
        moving = true;
      }
    } else moving = true;
    // The brick under the pointer up, the rest back down.
    let lifted = false;
    for (let i = 0; i < n; i++) {
      const want = i === hovered && !assembly ? LIFT : 0;
      if (Math.abs(lift[i] - want) > 0.02) {
        lift[i] += (want - lift[i]) * (1 - Math.exp(-dt * 16));
        lifted = true;
      } else lift[i] = want;
    }
    if (lifted) { place(); moving = true; }
    draw(time);
    if (moving) go();
  }
  function go() {
    if (running || lost || given.keep) return;
    running = true;
    requestAnimationFrame(frame);
  }
  const wake = () => {
    restAt = performance.now() / 1000 + RESTS_AFTER;
    go();
  };

  // The assembly (AWAY, UP, GAP, FALL, SKY above): away, then each course in turn.
  const leaves = (i) => (courses - 1 - course[i]) * AWAY + late(i) * 0.04;
  const gone = (courses - 1) * AWAY + 0.04 + UP + 0.06;
  // How far over its rest each brick is out of the picture, from the
  // assembly's own view (no sway during it): its height on the screen to
  // the picture's top and a little more, in LDU up.
  const highs = new Float32Array(n);
  let highest = 1;
  function measureHighs() {
    aim(0);
    camera.updateMatrixWorld();
    const half = view.distance * Math.tan((HOME.fov * Math.PI) / 360);
    for (let i = 0; i < n; i++) {
      const y = p.copy(rest[i]).project(camera).y;
      highs[i] = ((1.1 - y) * half) / Math.cos(view.up) + 30;
      highest = Math.max(highest, highs[i]);
    }
  }
  const falls = (i) => Math.max(0.22, FALL * Math.sqrt(highs[i] / highest));
  function assemble(time) {
    const t = time - assembly.from;
    fly(t > 0.12);
    let done = true;
    for (let i = 0; i < n; i++) {
      const high = highs[i];
      if (t < gone) {
        // Away, up and out of the picture. What was under a brick leaving
        // keeps its studs hidden: in the moment before it leaves too they
        // are not seen, and drawing every stud at once halved the frames.
        const u = clamp((t - leaves(i)) / UP, 0, 1);
        come[i] = u < 1 ? 1 : 0;
        landed[i] = 1;
        over[i] = high * u * u;
        done = false;
        continue;
      }
      const start = gone + course[i] * GAP + late(i) * GAP * 0.8;
      const fall = falls(i);
      const f = (t - start) / fall;
      if (f <= 0) { come[i] = 0; over[i] = high; landed[i] = 0; done = false; continue; }
      come[i] = 1;
      if (f < 1) {
        over[i] = high * (1 - f * f);
        landed[i] = 0;
        done = false;
        continue;
      }
      const b = (t - start - fall) / 0.14;
      landed[i] = 1;
      over[i] = b < 1 ? 2.2 * Math.sin(Math.PI * b) * (1 - b) : 0;
      if (b < 1) done = false;
    }
    place();
    if (done) {
      assembly = null;
      fly(false);
      studs.castShadow = true;
      stage.classList.remove("assembling");
      markTime("built");
      state.state = "ready";
      swayFrom = time;
      for (const g of [...groups, studs]) g.computeBoundingSphere();
    }
    return true;
  }

  // Taking hold: a drag (or a touch across) turns it; let go, it settles.
  // A touch up or down is the page's (touch-action pan-y).
  const pointer = new Vector2();
  const ray = new Raycaster();
  function pick(event) {
    const r = canvas.getBoundingClientRect();
    pointer.set(((event.clientX - r.left) / r.width) * 2 - 1, -((event.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(pointer, camera);
    const hit = ray.intersectObjects(groups, false)[0];
    return hit ? hit.object.userData.bricks[hit.instanceId] : -1;
  }
  stage.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    dragging = { id: event.pointerId, x: event.clientX, y: event.clientY, at: performance.now(), moved: false };
    stage.setPointerCapture?.(event.pointerId);
    stage.classList.add("held");
    hovered = -1;
    wake();
  });
  stage.addEventListener("pointermove", (event) => {
    if (dragging && event.pointerId === dragging.id) {
      const dx = event.clientX - dragging.x;
      const dy = event.clientY - dragging.y;
      const at = performance.now();
      const dt = Math.max(1, at - dragging.at) / 1000;
      dragging.x = event.clientX;
      dragging.y = event.clientY;
      dragging.at = at;
      if (Math.abs(dx) + Math.abs(dy) > 0) dragging.moved = true;
      const k = 3.6 / Math.max(240, stage.clientWidth);
      off.round -= dx * k;
      off.up = clamp(off.up + dy * k * 0.7, -0.5, 0.6);
      off.vRound = (-dx * k) / dt;
      off.vUp = (dy * k * 0.7) / dt;
      go();
      return;
    }
    if (event.pointerType !== "mouse" || still || assembly) return;
    const i = pick(event);
    if (i !== hovered) { hovered = i; wake(); }
  });
  const letGo = (event) => {
    if (!dragging || event.pointerId !== dragging.id) return;
    // A flick carries on a little; a hand that stopped before letting go does not.
    if (performance.now() - dragging.at > 80) { off.vRound = 0; off.vUp = 0; }
    off.vRound = clamp(off.vRound, -4, 4);
    off.vUp = clamp(off.vUp, -3, 3);
    dragging = null;
    stage.classList.remove("held");
    if (still) { off.vRound = 0; off.vUp = 0; }
    wake();
  };
  stage.addEventListener("pointerup", letGo);
  stage.addEventListener("pointercancel", letGo);
  stage.addEventListener("pointerleave", () => { if (hovered !== -1) { hovered = -1; go(); } });
  stage.addEventListener("pointerenter", () => wake());
  stage.addEventListener("keydown", (event) => {
    if (event.altKey || event.ctrlKey || event.metaKey) return;
    const keys = { ArrowLeft: [-TURN, 0], ArrowRight: [TURN, 0], ArrowUp: [0, TURN / 1.5], ArrowDown: [0, -TURN / 1.5] };
    if (event.key === "Home" || event.key === "0") { off.round = 0; off.up = 0; off.vRound = 0; off.vUp = 0; go(); event.preventDefault(); return; }
    if (!keys[event.key]) return;
    event.preventDefault();
    off.round += keys[event.key][0];
    off.up = clamp(off.up + keys[event.key][1], -0.5, 0.6);
    off.vRound = 0;
    off.vUp = 0;
    // Held where the keys put it a while, then back.
    keyed = performance.now() / 1000 + 3;
    wake();
  });
  const seen = new IntersectionObserver((entries) => {
    onScreen = entries.some((e) => e.isIntersecting);
    if (onScreen) go();
  });
  seen.observe(stage);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) { last = 0; go(); } });
  new ResizeObserver(() => { fit(); go(); }).observe(stage);
  canvas.addEventListener("webglcontextlost", (event) => {
    event.preventDefault();
    lost = true;
    state.state = "lost";
    stage.classList.remove("live");
  });

  // The finished mark, drawn to the end, and how long it takes once its
  // shaders are made (the first draw makes them, and software makes some
  // of its own on the second): a device that takes longer than [slow] ms
  // keeps the poster.
  stage.append(canvas);
  fit();
  place();
  markTime("built3d");
  draw(0, true);
  const took = Math.min(draw(0, true), draw(0, true));
  state.took = Math.round(took);
  if (given.slow && took > given.slow) {
    state.state = "slow";
    renderer.dispose();
    renderer.forceContextLoss();
    canvas.remove();
    return { ready: Promise.resolve(false), stop: () => {} };
  }
  // Its name now it turns, in the page's language (web/landing.js says it).
  if (given.name) stage.setAttribute("aria-label", given.name);
  const visited = (() => { try { return sessionStorage.getItem(KEPT) === "built"; } catch { return false; } })();
  if (!still && given.assemble !== false && !visited) {
    try { sessionStorage.setItem(KEPT, "built"); } catch { /* a visit that keeps nothing builds it each time */ }
    // It starts as the poster is, built, and comes apart from there.
    assembly = { from: performance.now() / 1000 + 0.25 };
    measureHighs();
    // The studs' own shadows, a texel of the key's, wait for it built: in
    // the air every stud's would be drawn twice a frame.
    studs.castShadow = false;
    stage.classList.add("assembling");
    state.state = "assembling";
    let last = 0;
    for (let i = 0; i < n; i++) last = Math.max(last, gone + course[i] * GAP + late(i) * GAP * 0.8 + falls(i) + 0.14);
    state.assembledIn = Math.round(last * 100) / 100;
  } else {
    state.state = "ready";
    swayFrom = performance.now() / 1000;
    markTime("built");
  }
  draw(performance.now() / 1000);
  // The poster gives way (web/index.html .hero-stage.live).
  stage.classList.add("live");
  markTime("shown");
  restAt = performance.now() / 1000 + RESTS_AFTER;
  if (!still) go();
  state.angle = () => ({ round: view.round + off.round + (still ? 0 : sway(performance.now() / 1000)), up: view.up + off.up });
  state.lifted = () => Array.from(lift).findIndex((v) => v > LIFT / 2);
  state.studsShown = () => studs.count;
  state.bricks = n;
  state.triangles = s.triangles;
  return {
    ready: Promise.resolve(true),
    stop() {
      lost = true;
      seen.disconnect();
      renderer.dispose();
      renderer.forceContextLoss();
      canvas.remove();
      stage.classList.remove("live");
    },
    picture: (type = "image/webp", quality = 0.9) => { draw(performance.now() / 1000); return canvas.toDataURL(type, quality); },
  };
}

// A soft dark under the whole model, where the key's shadow is too sharp to
// say it stands on something.
/// A stud as eight sides and a top (24 triangles; the part's own has 48),
/// in its file's place: radius 6, 4 high, on y 0.
function roughStud(sides = 8) {
  const position = [0, 4, 0];
  const normal = [0, 1, 0];
  for (let k = 0; k < sides; k++) {
    const a = (k / sides) * Math.PI * 2;
    const c = Math.cos(a);
    const z = Math.sin(a);
    position.push(6 * c, 4, 6 * z, 6 * c, 4, 6 * z, 6 * c, 0, 6 * z);
    normal.push(0, 1, 0, c, 0, z, c, 0, z);
  }
  const index = [];
  // Each triangle turned to face the way its normal does.
  const v = (n) => position.slice(n * 3, n * 3 + 3);
  const add = (a, b, c, out) => {
    const [p, q, r] = [v(a), v(b), v(c)];
    const u = [q[0] - p[0], q[1] - p[1], q[2] - p[2]];
    const w = [r[0] - p[0], r[1] - p[1], r[2] - p[2]];
    const n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]];
    index.push(...(n[0] * out[0] + n[1] * out[1] + n[2] * out[2] >= 0 ? [a, b, c] : [a, c, b]));
  };
  for (let k = 0; k < sides; k++) {
    const j = (k + 1) % sides;
    const [top, sideTop, sideLow] = [1 + k * 3, 2 + k * 3, 3 + k * 3];
    const [top2, sideTop2, sideLow2] = [1 + j * 3, 2 + j * 3, 3 + j * 3];
    add(0, top, top2, [0, 1, 0]);
    const a = ((k + 0.5) / sides) * Math.PI * 2;
    const out = [Math.cos(a), 0, Math.sin(a)];
    add(sideTop, sideLow, sideLow2, out);
    add(sideTop, sideLow2, sideTop2, out);
  }
  const g = new BufferGeometry();
  g.setAttribute("position", new BufferAttribute(new Float32Array(position), 3));
  g.setAttribute("normal", new BufferAttribute(new Float32Array(normal), 3));
  g.setIndex(index);
  return g;
}

function softShadow() {
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d");
  const fade = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  fade.addColorStop(0, "rgba(0,0,0,0.34)");
  fade.addColorStop(0.5, "rgba(0,0,0,0.16)");
  fade.addColorStop(1, "rgba(0,0,0,0)");
  g.fillStyle = fade;
  g.fillRect(0, 0, 128, 128);
  const plane = new Mesh(new PlaneGeometry(470, 470), new MeshBasicMaterial({ map: new CanvasTexture(c), transparent: true, depthWrite: false }));
  plane.rotation.x = -Math.PI / 2;
  plane.position.y = 0.3;
  plane.renderOrder = -1;
  return plane;
}
