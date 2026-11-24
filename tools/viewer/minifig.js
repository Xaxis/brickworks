// A minifigure of real parts, live in the page (figmaker, 2026-11-24): the
// figure Edit profile's maker builds (web/minifig-maker.js), turned by a
// drag or the arrow keys, a press on a part naming its group, and drawn as
// the picture a person keeps as their avatar.
//
// Built by tools/viewer/build.mjs into web/minifig3d.js, three.js and all,
// which the maker imports only once it is opened: a visit that never makes
// a minifig loads none of it. Each part's geometry is the app's own .lbm,
// fetched once by its hash from the part store (PARTS_URL, cached for good
// by the browser and the CDN), and only for the parts the figure has: a
// tile is a picture (web/minifig/tiles), never a fetch of its part.
//
// Put together where the LDraw library and the app put a figure's parts
// (src/minifig/minifig.gd: every number there was checked against the
// figures of real sets): an arm 15.552 LDU out and turned 9.782 degrees to
// the torso's slope, raised about its own pin; a hand 45 degrees in its
// arm, turned about its wrist; what it holds with its bar along the hand's
// grip; the head on the neck, lifted by a collar, turned; the legs about
// the hips' axle, walking or sitting. Worked out in LDraw's axes and turned
// into the page's (+Y up) at the end, as the layers were
// (tools/web/minifig_layers.mjs), and lit as they were: the studio room, a
// soft key light with real shadows, a rim. The picture's head and
// shoulders are the layers' own camera, so a figure made in the maker
// before (v 1) is the same figure.
import {
  AmbientLight, Box3, BufferAttribute, BufferGeometry, Color, DirectionalLight, DoubleSide, FrontSide, Group,
  HemisphereLight, Matrix4, Mesh, MeshPhysicalMaterial, NeutralToneMapping, PCFSoftShadowMap,
  PerspectiveCamera, PlaneGeometry, PMREMGenerator, Quaternion, Raycaster, Scene, ShadowMaterial, SRGBColorSpace,
  Vector2, Vector3, WebGLRenderer,
} from "three";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { INHERIT, parseLbm } from "../../web/lbm.js";
import { figureParts, GRIPS, NECK_LIFT, NECK_TURNED, NECKS, POSES } from "../../web/minifig-parts.js";
import { webglWorks } from "./view.js";

export { webglWorks };

const D = Math.PI / 180;
// LDraw's twelve numbers (x y z, then the rotation by rows) as a matrix.
const ld = (n) => new Matrix4().set(n[3], n[4], n[5], n[0], n[6], n[7], n[8], n[1], n[9], n[10], n[11], n[2], 0, 0, 0, 1);
const I = [1, 0, 0, 0, 1, 0, 0, 0, 1];
// src/minifig/minifig.gd's joints.
const ARM_R = ld([-15.552, 9, 0, 0.985, -0.17, 0, 0.17, 0.985, 0, 0, 0, 1]);
const ARM_L = ld([15.552, 9, 0, 0.985, 0.17, 0, -0.17, 0.985, 0, 0, 0, 1]);
const HAND_R = ld([-23.69, 26.774, -9.898, 0.985, -0.12, 0.12, 0.17, 0.696, -0.696, 0, 0.707, 0.707]);
const HAND_L = ld([23.69, 26.774, -9.898, 0.985, 0.12, -0.12, -0.17, 0.696, -0.696, 0, 0.707, 0.707]);
const HAND_IN_ARM_R = ARM_R.clone().invert().multiply(HAND_R);
const HAND_IN_ARM_L = ARM_L.clone().invert().multiply(HAND_L);
const HEAD = ld([0, -24, 0, ...I]);
const HIPS = ld([0, 32, 0, ...I]);
const LEGS = ld([0, 44, 0, ...I]);
// Where a hand closes, and the bar's direction through it, in the hand's frame.
const GRIP = new Vector3(0, -0.8229, -9.8948);
const GRIP_AXIS = new Vector3(0, 0.968148, 0.25038).normalize();
// Into the page's axes: a half turn about X.
const FLIP = new Matrix4().makeScale(1, -1, -1);
const placed = (m) => FLIP.clone().multiply(m).multiply(FLIP);
const rx = (deg) => new Matrix4().makeRotationX(deg * D);
const ry = (deg) => new Matrix4().makeRotationY(deg * D);
const mul = (...all) => all.reduce((a, b) => a.multiply(b), new Matrix4());

/// Where a held part sits in its hand: its bar laid along the grip,
/// through the middle of it (minifig.gd in_hand).
function inHand(part) {
  const grip = GRIPS[part] || [0, 0, 0, 0, 1, 0];
  const bar = new Vector3(grip[0], grip[1], grip[2]);
  const along = new Vector3(grip[3], grip[4], grip[5]).normalize();
  const turn = new Quaternion();
  const axis = new Vector3().crossVectors(along, GRIP_AXIS);
  if (axis.length() > 1e-6) turn.setFromAxisAngle(axis.normalize(), Math.atan2(new Vector3().crossVectors(along, GRIP_AXIS).length(), along.dot(GRIP_AXIS)));
  else if (along.dot(GRIP_AXIS) < 0) turn.setFromAxisAngle(new Vector3(1, 0, 0), Math.PI);
  const m = new Matrix4().makeRotationFromQuaternion(turn);
  const moved = GRIP.clone().sub(bar.clone().applyQuaternion(turn));
  return m.setPosition(moved);
}

const CAPES = new Set(NECKS.filter(([, , kind]) => kind === "cape").map(([id]) => id));

/// Every part of [recipe], placed: [{slot, part, colour, skinFrom, at}]
/// with [at] in the page's axes, the torso's top middle at the origin.
export function assemble(recipe) {
  const [head, armR, armL, handR, handL, stance] = recipe.po || POSES.stand;
  const lift = NECK_LIFT[recipe.nk] || 0;
  const headAt = mul(new Matrix4().makeTranslation(0, -lift, 0), HEAD, ry(-(head + (recipe.fb ? 180 : 0))));
  const armRAt = mul(ARM_R.clone(), rx(armR));
  const armLAt = mul(ARM_L.clone(), rx(armL));
  const handRAt = mul(armRAt.clone(), HAND_IN_ARM_R, ry(handR));
  const handLAt = mul(armLAt.clone(), HAND_IN_ARM_L, ry(-handL));
  const walk = stance === 1 ? 26 : 0;
  const legR = stance === 2 ? -90 : walk;
  const legL = stance === 2 ? -90 : -walk;
  const at = {
    face: headAt, hair: headAt, torso: new Matrix4(), armR: armRAt, armL: armLAt, handR: handRAt, handL: handLAt,
    hips: HIPS, legR: mul(LEGS.clone(), rx(legR)), legL: mul(LEGS.clone(), rx(legL)), skirt: HIPS,
    neck: CAPES.has(recipe.nk) ? new Matrix4().makeTranslation(0, -lift, 0) : ry(NECK_TURNED[recipe.nk] || 0),
    heldR: mul(handRAt.clone(), inHand(recipe.ir)), heldL: mul(handLAt.clone(), inHand(recipe.il)),
  };
  return figureParts(recipe).map((one) => ({ ...one, at: placed(at[one.slot]) }));
}

// The picture's cameras. Head and shoulders: the layers' own (a long lens,
// the figure turned 22 degrees to its left, seen 9 degrees from above, the
// neck in the middle). The whole figure: the same angle, framed to it.
const HOME = { round: -22, up: 9 };
const PORTRAIT = { fov: 11.4, far: 380, target: new Vector3(0, 0, 0) };

// The studio, as the layers are lit.
function studio(scene, renderer) {
  const pmrem = new PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  pmrem.dispose();
  scene.environmentIntensity = 0.75;
  scene.add(new HemisphereLight(0xffffff, 0x8d8a85, 0.6));
  const key = new DirectionalLight(0xfff6ec, 2.2);
  key.position.set(-60, 110, 120);
  key.castShadow = true;
  key.shadow.mapSize.set(1024, 1024);
  Object.assign(key.shadow.camera, { left: -80, right: 80, top: 80, bottom: -100, near: 10, far: 500 });
  key.shadow.bias = -0.0004;
  key.shadow.normalBias = 0.25;
  key.shadow.radius = 4;
  scene.add(key);
  scene.add(key.target);
  const rim = new DirectionalLight(0xffffff, 0.8);
  rim.position.set(80, 60, -120);
  scene.add(rim);
  scene.add(new AmbientLight(0xffffff, 0.05));
}

/// The figure in [stage] (an element the canvas fills): a promise of what
/// the maker drives it by. [given]: root (the part store, ending in "/"),
/// meshes ({part: hash}) and colours ({code: "rrggbb" with "m" for metal,
/// "t" for see-through}) from web/minifig/figure.json; recipe; pick(slot),
/// a part pressed; turned(), the person turned it; errors, said in.
export async function minifig3d(stage, given) {
  const o = { pick: () => {}, turned: () => {}, errors: [], ...given };
  const canvas = document.createElement("canvas");
  canvas.className = "minifig-canvas";
  stage.append(canvas);
  const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "high-performance" });
  renderer.setPixelRatio(Math.min(2, globalThis.devicePixelRatio || 1));
  renderer.outputColorSpace = SRGBColorSpace;
  renderer.toneMapping = NeutralToneMapping;
  renderer.setClearColor(0x000000, 0);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = PCFSoftShadowMap;
  const scene = new Scene();
  studio(scene, renderer);
  // The ground the figure stands on, seen only by its shadow.
  const ground = new Mesh(new PlaneGeometry(400, 400), new ShadowMaterial({ opacity: 0.22 }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);
  const camera = new PerspectiveCamera(20, 1, 10, 4000);
  const view = { round: 0, up: 0 };

  // Geometry by hash, once; materials by colour, once.
  const geometry = new Map();
  const shapeOf = (part) => {
    const hash = o.meshes[part];
    if (!hash) return Promise.resolve(null);
    if (!geometry.has(hash)) {
      geometry.set(hash, fetch(`${o.root}${hash}.lbm`, { cache: "force-cache", credentials: "omit" })
        .then((answer) => { if (!answer.ok) throw new Error(`HTTP ${answer.status}`); return answer.arrayBuffer(); })
        .then((buffer) => parseLbm(buffer).surfaces.map((s) => {
          const g = new BufferGeometry();
          g.setAttribute("position", new BufferAttribute(s.position, 3));
          g.setAttribute("normal", new BufferAttribute(s.normal, 3));
          g.setIndex(new BufferAttribute(s.index, 1));
          g.computeBoundingSphere();
          return { g, colour: s.colour, twoSided: s.twoSided };
        }))
        .catch((trouble) => { o.errors.push(`${part}: ${trouble.message}`); geometry.delete(hash); return null; }));
    }
    return geometry.get(hash);
  };
  const materials = new Map();
  const material = (code, side) => {
    const name = `${code}:${side}`;
    if (!materials.has(name)) {
      const said = String(o.colours[code] || o.colours[71] || "969696");
      const metal = said.endsWith("m");
      const clear = said.endsWith("t");
      materials.set(name, new MeshPhysicalMaterial({ side, color: new Color(`#${said.slice(0, 6)}`),
        roughness: metal ? 0.3 : 0.26, metalness: metal ? 0.75 : 0, clearcoat: metal ? 0 : 0.35, clearcoatRoughness: 0.2,
        transparent: clear, opacity: clear ? 0.55 : 1, depthWrite: !clear }));
    }
    return materials.get(name);
  };

  let figure = new Group();
  scene.add(figure);
  let recipe = null;
  let bounds = new Box3();

  /// [next] made, once every part it has is fetched: {made, box}, not yet
  /// in the scene.
  async function make(next) {
    const parts = assemble(next);
    const shapes = await Promise.all(parts.map((one) => shapeOf(one.part)));
    const made = new Group();
    parts.forEach((one, k) => {
      for (const s of shapes[k] || []) {
        const own = s.colour === INHERIT || (one.skinFrom && s.colour === one.skinFrom) ? (s.colour === INHERIT ? one.colour : next.sk) : s.colour;
        const mesh = new Mesh(s.g, material(own, s.twoSided ? DoubleSide : FrontSide));
        mesh.applyMatrix4(one.at);
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        mesh.userData.slot = one.slot;
        made.add(mesh);
      }
    });
    return { made, box: new Box3().setFromObject(made) };
  }
  // [made] in the scene in the figure's place, stood on the ground: the
  // figure it took the place of.
  const swap = ({ made, box }) => {
    const was = { made: figure, box: bounds };
    ground.position.y = box.min.y + 0.05;
    scene.remove(figure);
    figure = made;
    scene.add(figure);
    bounds = box;
    return was;
  };
  // The newest recipe asked for wins: a slow part never puts an older
  // figure back over a newer one.
  let asked = 0;
  async function build(next) {
    const mine = ++asked;
    const built = await make(next);
    if (mine !== asked) return;
    swap(built);
    recipe = next;
  }

  // The camera at [frame] ("stage": the whole figure, a little room round
  // it; "portrait"; "whole"), turned as the person turned it.
  function aim(cam, frame) {
    const round = (HOME.round + view.round) * D;
    const up = Math.max(-30, Math.min(60, HOME.up + view.up)) * D;
    let target;
    let far;
    if (frame === "portrait") {
      cam.fov = PORTRAIT.fov;
      target = PORTRAIT.target.clone();
      far = PORTRAIT.far;
    } else {
      cam.fov = 20;
      const box = bounds.isEmpty() ? new Box3(new Vector3(-30, -75, -20), new Vector3(30, 50, 20)) : bounds;
      target = box.getCenter(new Vector3());
      const size = box.getSize(new Vector3());
      const reach = Math.max(size.y, Math.max(size.x, size.z) * 1.1) * (frame === "stage" ? 0.62 : 0.56);
      far = reach / Math.tan((cam.fov / 2) * D);
    }
    cam.position.set(target.x + far * Math.sin(round) * Math.cos(up), target.y + far * Math.sin(up), target.z + far * Math.cos(round) * Math.cos(up));
    cam.near = far / 4;
    cam.far = far * 4;
    cam.lookAt(target);
    cam.updateProjectionMatrix();
  }

  let width = 0;
  let height = 0;
  const fit = () => {
    const box = stage.getBoundingClientRect();
    width = Math.max(1, Math.round(box.width));
    height = Math.max(1, Math.round(box.height));
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
  };
  let queued = false;
  const draw = () => {
    queued = false;
    if (!recipe) return;
    aim(camera, "stage");
    renderer.render(scene, camera);
  };
  const frame = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(draw);
  };
  const resized = new ResizeObserver(() => { fit(); draw(); });
  resized.observe(stage);
  fit();

  /// [recipe] (or the figure as it is) drawn from its picture's camera, on
  /// nothing, [side] pixels square: a canvas.
  function shot(side, frame) {
    const ratio = renderer.getPixelRatio();
    const was = camera.aspect;
    renderer.setPixelRatio(1);
    renderer.setSize(side, side, false);
    camera.aspect = 1;
    aim(camera, frame);
    renderer.render(scene, camera);
    const out = document.createElement("canvas");
    out.width = out.height = side;
    out.getContext("2d").drawImage(canvas, 0, 0, side, side);
    renderer.setPixelRatio(ratio);
    renderer.setSize(width, height, false);
    camera.aspect = was;
    draw();
    return out;
  }

  // Turning it: a drag across turns it round, up and down tips it; a press
  // that is no drag is a press on the part under it.
  const press = { id: null, x: 0, y: 0, moved: 0 };
  canvas.addEventListener("pointerdown", (event) => {
    press.id = event.pointerId;
    press.x = event.clientX;
    press.y = event.clientY;
    press.moved = 0;
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener("pointermove", (event) => {
    if (press.id !== event.pointerId) return;
    const dx = event.clientX - press.x;
    const dy = event.clientY - press.y;
    press.x = event.clientX;
    press.y = event.clientY;
    press.moved += Math.abs(dx) + Math.abs(dy);
    if (press.moved < 4) return;
    view.round -= dx * 0.6;
    view.up = Math.max(-39, Math.min(51, view.up + dy * 0.3));
    frame();
  });
  const let_go = (event) => {
    if (press.id !== event.pointerId) return;
    press.id = null;
    if (press.moved >= 4) { o.turned(); return; }
    const box = canvas.getBoundingClientRect();
    const at = new Vector2(((event.clientX - box.left) / box.width) * 2 - 1, -((event.clientY - box.top) / box.height) * 2 + 1);
    const ray = new Raycaster();
    aim(camera, "stage");
    ray.setFromCamera(at, camera);
    const hit = ray.intersectObjects(figure.children, false)[0];
    if (hit) o.pick(hit.object.userData.slot);
  };
  canvas.addEventListener("pointerup", let_go);
  canvas.addEventListener("pointercancel", (event) => { if (press.id === event.pointerId) press.id = null; });
  canvas.style.touchAction = "none";

  await build(o.recipe);
  draw();

  return {
    canvas,
    /// [next] built and drawn, once its parts are here.
    async set(next) {
      await build(next);
      draw();
    },
    /// Turned by [round] and tipped by [up] degrees; reset() to where it began.
    turn(round, up = 0) {
      view.round += round;
      view.up = Math.max(-39, Math.min(51, view.up + up));
      frame();
      o.turned();
    },
    reset() {
      view.round = 0;
      view.up = 0;
      frame();
      o.turned();
    },
    /// The figure as its picture, [side] pixels square, [frame] "portrait"
    /// or "whole", over [ground] (a canvas the background is painted on,
    /// or none): a canvas.
    picture(side, frame, ground = null) {
      const drawn = shot(side, frame);
      if (!ground) return drawn;
      const out = document.createElement("canvas");
      out.width = out.height = side;
      const c = out.getContext("2d");
      c.drawImage(ground, 0, 0, side, side);
      c.drawImage(drawn, 0, 0);
      return out;
    },
    /// [other] drawn small (a pose's tile), the figure as it is after.
    async sketch(other, side) {
      const built = await make(other);
      const was = swap(built);
      const drawn = shot(side, "whole");
      swap(was);
      draw();
      return drawn;
    },
    /// The parts this figure fetched and could not.
    errors: o.errors,
    dispose() {
      resized.disconnect();
      for (const one of geometry.values()) one.then((list) => list?.forEach((s) => s.g.dispose()));
      for (const m of materials.values()) m.dispose();
      renderer.dispose();
      renderer.forceContextLoss?.();
      canvas.remove();
    },
  };
}
