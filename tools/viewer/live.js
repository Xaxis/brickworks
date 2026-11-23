// A model being built, drawn as it is built: Building now's watch page
// (web/live.js, buildlive 2026-11-23) draws the model in a Build together
// session with the one scene the site's 3D views share (view.js), each part
// put down, moved or taken off as its change arrives.
//
// What it is given is not a packed scene but the parts as the session has
// them (api/together.js watching): {uid: [part, colour, 12 numbers]}, the
// numbers a Godot transform's in the app's own axes (basis x, y, z, then
// the origin: Together.numbers_of), which is what a packed scene's places
// and turns are in too. Each part's geometry is fetched once by its hash
// (shapes), and every surface's geometry made once and kept, so drawing the
// model again after a change only makes the instances anew: a part that
// landed is drawn in the frame after its change came, with its box standing
// in until its own geometry is in.
import { Color, InstancedMesh, Matrix4, Quaternion, SRGBColorSpace, Vector3 } from "three";
import { View, boxOf, geometryOf, shapes, webglWorks, LOOKS } from "./view.js";
import { INHERIT } from "../../web/lbm.js";

const EMPTY = { n: 0, ids: new Uint32Array(0), mesh: new Uint16Array(0), colour: new Uint16Array(0), flags: new Uint8Array(0),
  position: new Float32Array(0), turn: new Float32Array(0), byId: new Map(), colours: [], meshes: [] };
const UNKNOWN_HEX = "9a9a9a";

// The arrays View draws from, of [bricks] (Map uid -> [part, colour, 12
// numbers]), [meshes] ({part: [hash, name, 6 bounds, ...fixed colours]})
// and [colours] ({code: [name, hex, alpha]}); and the uid of each brick.
export function dataOf(bricks, meshes, colours) {
  const n = bricks.size;
  const d = { n, ids: new Uint32Array(n), mesh: new Uint16Array(n), colour: new Uint16Array(n), flags: new Uint8Array(n),
    position: new Float32Array(n * 3), turn: new Float32Array(n * 4), byId: new Map(), colours: [], meshes: [], uids: [] };
  const meshAt = new Map();
  const colourAt = new Map();
  const colourIndex = (code) => {
    if (!colourAt.has(code)) {
      const row = colours[code];
      colourAt.set(code, d.colours.length);
      d.colours.push({ code, name: String(row?.[0] || ""), hex: /^[0-9a-f]{6}$/i.test(String(row?.[1])) ? String(row[1]) : UNKNOWN_HEX,
        alpha: Math.max(0, Math.min(255, Number(row?.[2] ?? 255))) });
    }
    return colourAt.get(code);
  };
  const m = new Matrix4();
  const p = new Vector3();
  const q = new Quaternion();
  const s = new Vector3();
  let i = 0;
  for (const [uid, state] of bricks) {
    const [part, code, at] = state;
    if (!meshAt.has(part)) {
      const row = meshes[part] || [];
      meshAt.set(part, d.meshes.length);
      const bounds = row.slice(2, 8).map(Number);
      d.meshes.push({ part, hash: /^[0-9a-f]{8,64}$/.test(String(row[0])) ? String(row[0]) : "", name: String(row[1] || part),
        bounds: bounds.length === 6 && bounds.every(Number.isFinite) ? bounds : [-10, -24, -10, 10, 0, 10] });
      for (const fixed of row.slice(8)) colourIndex(Number(fixed));
    }
    d.mesh[i] = meshAt.get(part);
    d.colour[i] = colourIndex(Number(code));
    const n12 = Array.isArray(at) && at.length === 12 ? at.map(Number) : [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0];
    m.set(n12[0], n12[3], n12[6], n12[9], n12[1], n12[4], n12[7], n12[10], n12[2], n12[5], n12[8], n12[11], 0, 0, 0, 1);
    m.decompose(p, q, s);
    d.position.set([p.x, p.y, p.z], i * 3);
    d.turn.set([q.x, q.y, q.z, q.w], i * 4);
    d.ids[i] = i + 1;
    d.byId.set(i + 1, i);
    d.uids.push(uid);
    i += 1;
  }
  return d;
}

export class LiveView extends View {
  constructor(stage, given = {}) {
    super(stage, EMPTY, { spin: false, ...LOOKS.app, ...given });
    this.store = shapes(given.root || "", { errors: this.o.errors });
    // Each part's shape once in (by hash), and each surface's geometry.
    this.ready = new Map();
    this.asked = new Set();
    this.geometries = new Map();
    this.size0 = 0;
  }

  // The model as [bricks] has it now: drawn again in the next frame.
  show(bricks, meshes, colours) {
    this.d = dataOf(bricks, meshes, colours);
    this.colours = this.d.colours.map((c) => new Color().setHex(parseInt(c.hex, 16), SRGBColorSpace));
    this.colourByCode = new Map(this.d.colours.map((c, k) => [c.code, k]));
    this.bounds = this.measure();
    this.rebuild();
    // Its shadow under it where it stands now.
    if (this.shadowPlane && this.renderer) {
      this.scene.remove(this.shadowPlane);
      this.shadowPlane.geometry.dispose();
      this.shadowPlane.material.map?.dispose();
      this.shadowPlane.material.dispose();
      this.scene.add(this.shadow());
    }
    // Framed again while nobody has turned it, as it grows.
    const size = this.modelBounds.getSize(new Vector3()).length();
    if (this.renderer && !this.interacted && (this.size0 === 0 || size > this.size0 * 1.08 || size < this.size0 * 0.7)) {
      this.size0 = size;
      this.frame();
    }
    this.render();
    return this.d;
  }

  rebuild() {
    for (const g of this.groups) {
      this.scene.remove(g);
      g.dispose();
    }
    this.groups = [];
    const by = new Map();
    for (let i = 0; i < this.d.n; i++) {
      const m = this.d.mesh[i];
      if (!by.has(m)) by.set(m, []);
      by.get(m).push(i);
    }
    this.meshesWanted = by.size;
    this.loaded = 0;
    for (const [m, bricks] of by) {
      const mesh = this.d.meshes[m];
      const key = mesh.hash || `box:${mesh.part}`;
      let shape = this.ready.get(key);
      if (shape) this.loaded += 1;
      else {
        shape = boxOf(mesh.bounds);
        if (mesh.hash && !this.asked.has(key)) {
          this.asked.add(key);
          this.store(mesh).then((got) => {
            this.ready.set(key, got || boxOf(mesh.bounds));
            this.queue();
          });
        }
      }
      this.place(m, key, shape, bricks);
    }
  }

  // Drawn again once, in the next frame, however many shapes came in it.
  queue() {
    if (this.queued) return;
    this.queued = true;
    requestAnimationFrame(() => {
      this.queued = false;
      this.rebuild();
      this.render();
      this.o.shaped?.();
    });
  }

  // View.add's instances, with each surface's geometry kept by its key.
  place(m, key, shape, bricks) {
    const d = this.d;
    const clear = new Map();
    for (const i of bricks) {
      const alpha = d.colours[d.colour[i]]?.alpha ?? 255;
      const k = alpha < 255 ? alpha : 255;
      if (!clear.has(k)) clear.set(k, []);
      clear.get(k).push(i);
    }
    const groups = [];
    shape.surfaces.forEach((surface, s) => {
      const at = `${key}:${s}:${shape === this.ready.get(key) ? 1 : 0}`;
      if (!this.geometries.has(at)) this.geometries.set(at, geometryOf(surface));
      const geometry = this.geometries.get(at);
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
        groups.push(instanced);
      }
    });
    this.paint(groups);
  }

  shadow() {
    this.shadowPlane = super.shadow();
    return this.shadowPlane;
  }

  // The uid of the part under a point of the stage, or "".
  uidAt(x, y) {
    const i = this.pick(x, y);
    return i >= 0 ? this.d.uids[i] || "" : "";
  }
}

export { webglWorks };
