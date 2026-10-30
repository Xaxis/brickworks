// The model in 3D, drawn from the packed scene (scene.js) and each part's
// own geometry (web/lbm.js): the one scene both the viewer Claude shows
// (card.js, the MCP App) and a model's page on the site (inline.js, its 3D
// view) draw. Each part's geometry is fetched once by its hash and drawn as
// instances, a mesh per surface, in the bricks' colours; orbit, zoom and
// pan by OrbitControls, the keys by orbitBy and zoomBy, and the camera
// first at the app's front-right corner, the model filling the frame.
//
// What differs between the two is given to View: whether to keep still
// (prefers-reduced-motion), where errors and timings go, how a touch on it
// is shared with the page under it, what to show when the browser takes
// the graphics back, and how a part's geometry is had (shapes).
import {
  Box3, BufferAttribute, BufferGeometry, CanvasTexture, Color, DirectionalLight, DoubleSide,
  EdgesGeometry, FrontSide, Group, HemisphereLight, InstancedMesh, LineBasicMaterial, LineSegments,
  Matrix4, Mesh, MeshBasicMaterial, MeshStandardMaterial, NeutralToneMapping, PerspectiveCamera,
  PlaneGeometry, PMREMGenerator, Quaternion, Raycaster, Scene, Sphere, Spherical, SRGBColorSpace,
  Vector2, Vector3, WebGLRenderer,
} from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { INHERIT, parseLbm } from "../../web/lbm.js";
import { SCENERY } from "./scene.js";

export const CLAY = new Color(0xc9ced6);
// Where the camera starts: the app's front-right corner (ModelShot "corner").
const CORNER = new Vector3(0.72, 0.52, 0.72).normalize();
const FETCHING = 12;

// Whether this browser can draw in 3D at all.
export function webglWorks() {
  try {
    const probe = document.createElement("canvas");
    const gl = probe.getContext("webgl2") || probe.getContext("webgl");
    if (!gl) return false;
    const lose = gl.getExtension("WEBGL_lose_context");
    if (lose) lose.loseContext();
    return true;
  } catch {
    return false;
  }
}

// Each part's geometry once, by its hash, from [root] (root + hash + ".lbm"),
// the store the app loads it from and the browser keeps for good, its name
// being its hash: a promise of the parsed shape, or of null where it could
// not be had (said in [errors]), its bytes counted on it. [hosted], where given, is another way to
// the bytes, taken for every part once a fetch from the store has failed
// and [fallback]() allows it.
export function shapes(root, { errors = [], hosted = null, fallback = () => false } = {}) {
  const kept = new Map();
  let throughHost = false;
  return (mesh) => {
    if (!mesh.hash) return Promise.resolve(null);
    if (!kept.has(mesh.hash)) {
      const direct = () => fetch(root + mesh.hash + ".lbm", { cache: "force-cache", credentials: "omit" })
        .then((answer) => { if (!answer.ok) throw new Error(`HTTP ${answer.status}`); return answer.arrayBuffer(); });
      const loaded = (throughHost ? hosted(mesh) : direct().catch((trouble) => {
        if (!hosted || !fallback()) throw trouble;
        errors.push(`fetch ${mesh.part}: ${trouble.message}; through the host instead`);
        throughHost = true;
        return hosted(mesh);
      }))
        .then((buffer) => Object.assign(parseLbm(buffer), { bytes: buffer.byteLength }))
        .catch((trouble) => { errors.push(`${mesh.part}: ${trouble.message}`); return null; });
      kept.set(mesh.hash, loaded);
    }
    return kept.get(mesh.hash);
  };
}

export function geometryOf(surface) {
  const g = new BufferGeometry();
  g.setAttribute("position", new BufferAttribute(surface.position, 3));
  g.setAttribute("normal", new BufferAttribute(surface.normal, 3));
  g.setIndex(new BufferAttribute(surface.index, 1));
  g.computeBoundingSphere();
  g.computeBoundingBox();
  return g;
}

// A part made in the person's tab has no file to fetch: its box stands in.
export function boxOf(bounds) {
  const [x0, y0, z0, x1, y1, z1] = bounds.length === 6 && bounds.every(Number.isFinite) ? bounds : [-10, -24, -10, 10, 0, 10];
  const p = [x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1];
  const faces = [[0, 3, 2, 1, 0, 0, -1], [4, 5, 6, 7, 0, 0, 1], [0, 1, 5, 4, 0, -1, 0], [3, 7, 6, 2, 0, 1, 0], [0, 4, 7, 3, -1, 0, 0], [1, 2, 6, 5, 1, 0, 0]];
  const position = new Float32Array(72);
  const normal = new Float32Array(72);
  const index = new Uint16Array(36);
  faces.forEach((f, k) => {
    for (let c = 0; c < 4; c++) {
      position.set(p.slice(f[c] * 3, f[c] * 3 + 3), (k * 4 + c) * 3);
      normal.set([f[4], f[5], f[6]], (k * 4 + c) * 3);
    }
    index.set([k * 4, k * 4 + 1, k * 4 + 2, k * 4, k * 4 + 2, k * 4 + 3], k * 6);
  });
  return { bounds, surfaces: [{ colour: INHERIT, twoSided: false, position, normal, index }] };
}

export class View {
  constructor(stage, d, given = {}) {
    this.stage = stage;
    this.d = d;
    this.o = { still: false, spin: true, fov: 35, errors: [], mark: () => {}, touchAction: () => "pan-y", lost: () => {},
      shapeOf: () => Promise.resolve(null), ...given };
    this.marked = new Set();
    this.scene = new Scene();
    this.groups = [];
    this.byMesh = new Map();
    this.look = null;
    this.outlined = new Group();
    this.outlined.renderOrder = 10;
    this.scene.add(this.outlined);
    this.edges = new Map();
    this.colours = d.colours.map((c) => new Color().setHex(parseInt(c.hex, 16), SRGBColorSpace));
    this.colourByCode = new Map(d.colours.map((c, k) => [c.code, k]));
    this.loaded = 0;
    this.meshesWanted = 0;
    this.bounds = this.measure();
    this.camera = new PerspectiveCamera(this.o.fov, 4 / 3, 1, 100000);
    this.materials = new Map();
    this.frameQueued = false;
    this.moving = 0;
    this.idleSince = performance.now();
  }

  // The model's box from where its bricks are and how big each part is,
  // before any geometry has come.
  // Every corner of every part but the ground's is kept (this.corners), to
  // frame the model on, as ModelShot frames the app's pictures.
  measure() {
    const box = new Box3();
    const model = new Box3();
    const corner = new Vector3();
    const q = new Quaternion();
    const d = this.d;
    const corners = new Float32Array(d.n * 24);
    let kept = 0;
    const keep = (v) => { corners[kept++] = v.x; corners[kept++] = v.y; corners[kept++] = v.z; };
    for (let i = 0; i < d.n; i++) {
      const b = d.meshes[d.mesh[i]]?.bounds;
      const p = d.position.subarray(i * 3, i * 3 + 3);
      const ground = d.flags[i] & SCENERY;
      q.set(d.turn[i * 4], d.turn[i * 4 + 1], d.turn[i * 4 + 2], d.turn[i * 4 + 3]);
      if (!b || b.length !== 6 || !b.every(Number.isFinite)) {
        box.expandByPoint(corner.set(p[0], p[1], p[2]));
        if (!ground) { model.expandByPoint(corner); keep(corner); }
        continue;
      }
      for (let k = 0; k < 8; k++) {
        corner.set(k & 1 ? b[3] : b[0], k & 2 ? b[4] : b[1], k & 4 ? b[5] : b[2]).applyQuaternion(q);
        box.expandByPoint(corner.set(corner.x + p[0], corner.y + p[1], corner.z + p[2]));
        if (!ground) { model.expandByPoint(corner); keep(corner); }
      }
    }
    if (box.isEmpty()) box.set(new Vector3(-40, 0, -40), new Vector3(40, 40, 40));
    // The model without the ground it stands on: what "the left" is of.
    this.modelBounds = model.isEmpty() ? box.clone() : model;
    if (kept === 0) {
      const b = this.modelBounds;
      for (let k = 0; k < 8; k++) keep(corner.set(k & 1 ? b.max.x : b.min.x, k & 2 ? b.max.y : b.min.y, k & 4 ? b.max.z : b.min.z));
    }
    this.corners = corners.subarray(0, kept);
    return box;
  }

  // The renderer, made when the card is on screen and let go when it has
  // been off it a while: a long conversation has a card for every build,
  // and a browser keeps only so many WebGL contexts.
  start() {
    if (this.renderer) return;
    const canvas = document.createElement("canvas");
    canvas.setAttribute("aria-hidden", "true");
    const renderer = new WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: "low-power" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.outputColorSpace = SRGBColorSpace;
    renderer.toneMapping = NeutralToneMapping;
    renderer.toneMappingExposure = 1.0;
    renderer.setClearColor(0x000000, 0);
    this.renderer = renderer;
    // Only the browser's taking it: stop() lets go of its own, and that
    // came here too, and said the view had failed.
    canvas.addEventListener("webglcontextlost", (event) => { event.preventDefault(); if (this.renderer === renderer) this.lost(); });
    this.stage.append(canvas);
    const pmrem = new PMREMGenerator(renderer);
    this.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    this.scene.environmentIntensity = 0.55;
    pmrem.dispose();
    if (!this.lights) {
      this.lights = true;
      this.scene.add(new HemisphereLight(0xffffff, 0x8d8a85, 0.9));
      const key = new DirectionalLight(0xffffff, 1.5);
      key.position.set(0.5, 1, 0.8);
      this.scene.add(key);
      const fill = new DirectionalLight(0xffffff, 0.35);
      fill.position.set(-0.8, 0.3, -0.5);
      this.scene.add(fill);
      this.scene.add(this.shadow());
    }
    this.controls = new OrbitControls(this.camera, canvas);
    this.controls.enableDamping = !this.o.still;
    this.controls.dampingFactor = 0.12;
    this.controls.screenSpacePanning = true;
    this.controls.zoomToCursor = true;
    this.controls.rotateSpeed = 0.85;
    this.controls.addEventListener("change", () => this.render());
    this.controls.addEventListener("start", () => { this.interacted = true; this.controls.autoRotate = false; this.moving += 1; });
    this.controls.addEventListener("end", () => { this.moving = Math.max(0, this.moving - 1); this.idleSince = performance.now(); });
    this.touch();
    this.size();
    if (!this.framed) this.frame();
    else { this.controls.target.copy(this.target); this.camera.position.copy(this.eye); }
    // A slow turn as it arrives, as the pictures turned: a few seconds, then
    // still, since a page does not move for ever; none for a person who asks
    // for less motion.
    this.controls.autoRotate = !this.o.still && this.o.spin && !this.interacted && !this.turned;
    this.controls.autoRotateSpeed = 1.6;
    if (this.controls.autoRotate) {
      this.turned = true;
      setTimeout(() => { if (this.controls) this.controls.autoRotate = false; }, 7000);
    }
    this.render();
  }

  // On a touch screen inline, one finger across turns the model and one
  // finger up or down scrolls what it is in; full screen, or once the
  // person has taken hold of it, it is all the model's (touchAction).
  touch() {
    if (!this.controls) return;
    this.renderer.domElement.style.touchAction = this.o.touchAction();
  }

  stop(keepPicture) {
    if (!this.renderer) return;
    if (keepPicture) {
      try { this.render(true); this.still = this.renderer.domElement.toDataURL("image/webp", 0.85); } catch { this.still = ""; }
    }
    this.eye = this.camera.position.clone();
    this.target = this.controls.target.clone();
    this.controls.dispose();
    this.controls = null;
    const renderer = this.renderer;
    this.renderer = null;
    renderer.dispose();
    renderer.forceContextLoss();
    renderer.domElement.remove();
  }

  // The browser took the graphics back: whoever shows it is told, with the
  // last frame drawn if there is one.
  lost() {
    this.o.errors.push("the WebGL context was lost");
    const shot = this.still;
    this.stop(false);
    this.o.lost(shot);
  }

  // A soft shadow on the ground under the model.
  shadow() {
    const c = document.createElement("canvas");
    c.width = c.height = 128;
    const g = c.getContext("2d");
    const fade = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    fade.addColorStop(0, "rgba(0,0,0,0.32)");
    fade.addColorStop(0.55, "rgba(0,0,0,0.14)");
    fade.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = fade;
    g.fillRect(0, 0, 128, 128);
    const size = this.bounds.getSize(new Vector3());
    const centre = this.bounds.getCenter(new Vector3());
    const plane = new Mesh(new PlaneGeometry(1, 1), new MeshBasicMaterial({ map: new CanvasTexture(c), transparent: true, depthWrite: false }));
    plane.rotation.x = -Math.PI / 2;
    plane.scale.set(Math.max(size.x, 40) * 1.7, Math.max(size.z, 40) * 1.7, 1);
    plane.position.set(centre.x, this.bounds.min.y - 0.4, centre.z);
    plane.renderOrder = -1;
    return plane;
  }

  frame() {
    this.framed = true;
    // The model, not the baseplate it stands on, which runs off the edges
    // as it does in the app's own pictures.
    const sphere = this.modelBounds.getBoundingSphere(new Sphere());
    const r = Math.max(sphere.radius, 20);
    const { centre, distance } = this.fitting(sphere.center);
    const fit = Math.max(distance, 20) * 1.05;
    this.controls.target.copy(centre);
    this.camera.position.copy(centre).addScaledVector(CORNER, fit);
    this.camera.near = Math.max(0.5, fit / 400);
    this.camera.far = fit * 30;
    this.camera.updateProjectionMatrix();
    this.controls.minDistance = r * 0.15;
    this.controls.maxDistance = fit * 6;
    this.home = { eye: this.camera.position.clone(), target: centre.clone() };
    this.controls.update();
  }

  // Where the camera looks and how far from it it stands, from the corner's
  // height, for every corner of every part to be in the frame across and
  // up, with the model in the middle of the frame: at the corner itself, or
  // at each of 16 turns about it where it turns on arrival, so it stays
  // whole as it turns. {centre, distance}. (The bounding sphere, used
  // before, left a model half the frame; the corners of the box round it,
  // next, left a round one, the Falcon, two thirds.)
  fitting(from) {
    const points = this.corners;
    const tanUp = Math.tan((this.camera.fov * Math.PI) / 360);
    const tanAcross = tanUp * this.camera.aspect;
    const level = Math.hypot(CORNER.x, CORNER.z);
    const turns = this.o.spin && !this.o.still ? 16 : 1;
    const axes = (k) => {
      const a = Math.PI / 4 + (k * Math.PI) / 8;
      const back = new Vector3(Math.sin(a) * level, CORNER.y, Math.cos(a) * level);
      const right = new Vector3(Math.cos(a), 0, -Math.sin(a));
      return { back, right, up: new Vector3().crossVectors(back, right) };
    };
    const corner = new Vector3();
    const corners = (centre, each) => {
      for (let c = 0; c < points.length; c += 3) {
        each(corner.set(points[c] - centre.x, points[c + 1] - centre.y, points[c + 2] - centre.z));
      }
    };
    const centre = from.clone();
    let distance = 0;
    for (let pass = 0; pass < 3; pass++) {
      distance = 0;
      for (let k = 0; k < turns; k++) {
        const { back, right, up } = axes(k);
        corners(centre, (v) => {
          const z = v.dot(back);
          distance = Math.max(distance, z + Math.abs(v.dot(right)) / tanAcross, z + Math.abs(v.dot(up)) / tanUp);
        });
      }
      if (pass === 2) break;
      // The box in the middle of the frame as it is first seen.
      const { back, right, up } = axes(0);
      const across = [Infinity, -Infinity];
      const high = [Infinity, -Infinity];
      corners(centre, (v) => {
        const d = distance - v.dot(back);
        const x = v.dot(right) / d;
        const y = v.dot(up) / d;
        across[0] = Math.min(across[0], x); across[1] = Math.max(across[1], x);
        high[0] = Math.min(high[0], y); high[1] = Math.max(high[1], y);
      });
      centre.addScaledVector(right, ((across[0] + across[1]) / 2) * distance)
        .addScaledVector(up, ((high[0] + high[1]) / 2) * distance);
    }
    return { centre, distance };
  }

  // The glide a flick left dropped, before the camera is put somewhere: it
  // carried the model on past where Reset had put it. (OrbitControls keeps
  // it in these; three is pinned in build.mjs.)
  halt() {
    this.controls._sphericalDelta.set(0, 0, 0);
    this.controls._panOffset.set(0, 0, 0);
    this.controls._scale = 1;
  }

  reset() {
    if (!this.controls || !this.home) return;
    this.halt();
    this.controls.target.copy(this.home.target);
    this.camera.position.copy(this.home.eye);
    this.controls.update();
    this.render();
  }

  // Turned by the keys: round, up and down, nearer and further.
  orbitBy(round, up) {
    if (!this.controls) return;
    const offset = this.camera.position.clone().sub(this.controls.target);
    const s = new Spherical().setFromVector3(offset);
    this.halt();
    s.theta += round;
    s.phi = Math.min(Math.PI - 0.05, Math.max(0.05, s.phi + up));
    offset.setFromSpherical(s);
    this.camera.position.copy(this.controls.target).add(offset);
    this.interacted = true;
    this.controls.autoRotate = false;
    this.controls.update();
    this.render();
  }
  zoomBy(factor) {
    if (!this.controls) return;
    this.halt();
    const offset = this.camera.position.clone().sub(this.controls.target);
    const length = Math.min(this.controls.maxDistance, Math.max(this.controls.minDistance, offset.length() * factor));
    this.camera.position.copy(this.controls.target).add(offset.setLength(length));
    this.controls.update();
    this.render();
  }

  size() {
    if (!this.renderer) return;
    const w = Math.max(1, this.stage.clientWidth);
    const h = Math.max(1, this.stage.clientHeight);
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.render();
  }

  // Drawn when something changed, and every frame only while it moves.
  render(now) {
    if (!this.renderer) return;
    if (now) { this.draw(); return; }
    if (this.frameQueued) return;
    this.frameQueued = true;
    requestAnimationFrame(() => {
      this.frameQueued = false;
      if (!this.renderer) return;
      const moved = this.controls.update();
      this.draw();
      if (moved || this.controls.autoRotate || this.moving) this.render();
    });
  }
  draw() {
    this.renderer.render(this.scene, this.camera);
    if (this.loaded > 0) this.once("first3d");
    if (this.loaded >= this.meshesWanted && this.meshesWanted > 0) this.once("complete3d");
  }
  once(what) {
    if (this.marked.has(what)) return;
    this.marked.add(what);
    this.o.mark(what);
  }

  material(twoSided, alpha) {
    const key = `${twoSided ? 2 : 1}:${alpha}`;
    if (!this.materials.has(key)) {
      const m = new MeshStandardMaterial({ color: 0xffffff, roughness: 0.32, metalness: 0.0,
        side: twoSided ? DoubleSide : FrontSide });
      if (alpha < 255) {
        m.transparent = true;
        m.opacity = Math.max(0.25, alpha / 255);
        m.depthWrite = false;
      }
      this.materials.set(key, m);
    }
    return this.materials.get(key);
  }

  // Every part's geometry, fetched a few at a time; each part's bricks
  // drawn as soon as its own geometry is in.
  async load(progress) {
    const d = this.d;
    const by = new Map();
    for (let i = 0; i < d.n; i++) {
      const m = d.mesh[i];
      if (!by.has(m)) by.set(m, []);
      by.get(m).push(i);
    }
    const order = [...by.entries()].sort((a, b) => b[1].length - a[1].length);
    this.meshesWanted = order.length;
    let next = 0;
    const work = async () => {
      while (next < order.length) {
        const [m, bricks] = order[next++];
        const mesh = d.meshes[m] || { part: "?", hash: "", bounds: [] };
        const shape = (await this.o.shapeOf(mesh)) || boxOf(mesh.bounds);
        this.add(m, shape, bricks);
        this.loaded += 1;
        progress(this.loaded / this.meshesWanted);
        this.render();
      }
    };
    await Promise.all(Array.from({ length: Math.min(FETCHING, order.length) }, work));
  }

  add(m, shape, bricks) {
    const d = this.d;
    const parts = [];
    // Clear parts apart from the solid ones, so each is drawn after them.
    const clear = new Map();
    for (const i of bricks) {
      const alpha = this.d.colours[d.colour[i]]?.alpha ?? 255;
      const key = alpha < 255 ? alpha : 255;
      if (!clear.has(key)) clear.set(key, []);
      clear.get(key).push(i);
    }
    const geometries = [];
    shape.surfaces.forEach((surface, s) => {
      const geometry = geometries[s] = geometryOf(surface);
      for (const [alpha, which] of clear) {
        const inherit = surface.colour === INHERIT;
        const fixed = inherit ? null : this.colourByCode.get(surface.colour);
        const fixedAlpha = fixed === undefined || fixed === null ? 255 : d.colours[fixed].alpha;
        const instanced = new InstancedMesh(geometry, this.material(surface.twoSided, inherit ? alpha : fixedAlpha), which.length);
        instanced.userData = { bricks: Int32Array.from(which), fixed: inherit ? -1 : (fixed ?? -2), mesh: m, surface: s };
        if (alpha < 255 || fixedAlpha < 255) instanced.renderOrder = 2;
        instanced.frustumCulled = false;
        this.groups.push(instanced);
        this.scene.add(instanced);
        parts.push(instanced);
      }
    });
    this.byMesh.set(m, { shape, groups: parts, geometries });
    this.paint(parts);
  }

  // Where each brick is, whether it is shown, and in what colour, from
  // what the card is showing (this.look).
  paint(groups = this.groups) {
    const d = this.d;
    const matrix = new Matrix4();
    const p = new Vector3();
    const q = new Quaternion();
    const one = new Vector3(1, 1, 1);
    const none = new Vector3(0, 0, 0);
    const c = new Color();
    for (const g of groups) {
      const { bricks, fixed } = g.userData;
      for (let k = 0; k < bricks.length; k++) {
        const i = bricks[k];
        const look = this.look ? this.look(i) : null;
        p.set(d.position[i * 3], d.position[i * 3 + 1], d.position[i * 3 + 2]);
        q.set(d.turn[i * 4], d.turn[i * 4 + 1], d.turn[i * 4 + 2], d.turn[i * 4 + 3]);
        matrix.compose(p, q, look && look.hidden ? none : one);
        g.setMatrixAt(k, matrix);
        if (look && look.colour) c.copy(look.colour);
        else if (fixed >= 0) c.copy(this.colours[fixed]);
        else if (fixed === -2) c.setHex(0x9a9a9a);
        else c.copy(this.colours[d.colour[i]] || CLAY);
        g.setColorAt(k, c);
      }
      g.instanceMatrix.needsUpdate = true;
      if (g.instanceColor) g.instanceColor.needsUpdate = true;
      g.computeBoundingSphere();
    }
    this.render();
  }

  // The brick under a point of the stage, by its index in the scene, or -1.
  pick(x, y) {
    if (!this.renderer) return -1;
    const rect = this.renderer.domElement.getBoundingClientRect();
    const at = new Vector2(((x - rect.left) / rect.width) * 2 - 1, -((y - rect.top) / rect.height) * 2 + 1);
    const ray = new Raycaster();
    ray.setFromCamera(at, this.camera);
    const hits = ray.intersectObjects(this.groups, false);
    for (const hit of hits) {
      const i = hit.object.userData.bricks[hit.instanceId];
      if (i !== undefined && !(this.d.flags[i] & SCENERY)) return i;
    }
    return -1;
  }

  // Lines round each of [which]'s parts: the picked part, or what a step adds.
  outline(which, colour) {
    for (const line of [...this.outlined.children]) { this.outlined.remove(line); }
    const d = this.d;
    const matrix = new Matrix4();
    const material = new LineBasicMaterial({ color: colour, transparent: true, opacity: 0.95, depthTest: false });
    const behind = new LineBasicMaterial({ color: colour, transparent: true, opacity: 0.95 });
    for (const i of which) {
      const entry = this.byMesh.get(d.mesh[i]);
      if (!entry) continue;
      matrix.compose(new Vector3(d.position[i * 3], d.position[i * 3 + 1], d.position[i * 3 + 2]),
        new Quaternion(d.turn[i * 4], d.turn[i * 4 + 1], d.turn[i * 4 + 2], d.turn[i * 4 + 3]), new Vector3(1, 1, 1));
      entry.shape.surfaces.forEach((surface, s) => {
        const key = `${d.mesh[i]}:${s}`;
        if (!this.edges.has(key)) this.edges.set(key, new EdgesGeometry(entry.geometries[s] || geometryOf(surface), 28));
        const line = new LineSegments(this.edges.get(key), which.length > 12 ? behind : material);
        line.matrixAutoUpdate = false;
        line.matrix.copy(matrix);
        line.renderOrder = 10;
        this.outlined.add(line);
      });
    }
    this.render();
  }

  themed() { this.render(); }

  // What a check can read of the stage: whether the model is drawn, by the
  // share of pixels that are not the background, read the moment after a
  // frame is drawn.
  sample() {
    if (!this.renderer) return null;
    this.draw();
    const gl = this.renderer.getContext();
    const w = gl.drawingBufferWidth;
    const h = gl.drawingBufferHeight;
    const pixels = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    let drawn = 0;
    let warm = 0;
    let grey = 0;
    const colours = new Set();
    for (let k = 0; k < pixels.length; k += 16) {
      // The model, not the soft shadow under it (a third opaque at most).
      if (pixels[k + 3] > 200) {
        const [r, g, b] = [pixels[k], pixels[k + 1], pixels[k + 2]];
        drawn += 1;
        colours.add((r >> 4) << 8 | (g >> 4) << 4 | (b >> 4));
        // The check's amber to red, and its clay.
        if (r > 150 && r - b > 80 && r - g > 25) warm += 1;
        if (Math.max(r, g, b) - Math.min(r, g, b) < 18 && r > 120) grey += 1;
      }
    }
    const of = pixels.length / 16;
    return { width: w, height: h, drawn: drawn / of, colours: colours.size, warm: warm / of, grey: grey / of };
  }

  instances() {
    let shown = 0;
    const seen = new Set();
    for (const g of this.groups) {
      for (const i of g.userData.bricks) {
        if (seen.has(i) || this.d.flags[i] & SCENERY) continue;
        seen.add(i);
        if (!(this.look && this.look(i)?.hidden)) shown += 1;
      }
    }
    return shown;
  }

  angle() {
    if (!this.controls) return null;
    return { round: this.controls.getAzimuthalAngle(), up: this.controls.getPolarAngle(),
      distance: this.camera.position.distanceTo(this.controls.target) };
  }
}
