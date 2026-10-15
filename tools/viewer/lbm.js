// A part's geometry, read from the .lbm file the app itself loads
// (tools/ldraw/meshfile.py has the layout; src/parts/lbm.gd reads it in the
// app). Only what drawing needs: each surface's positions, normals and
// triangles, its colour (16 is the colour the part is placed in) and
// whether it is two-sided. Connectors, boxes and sockets are passed over.
//
// The file is in the app's convention, which is three.js's too: +Y up,
// right handed, one unit one LDU. Its triangles are wound clockwise from
// outside, as Godot draws them (src/parts/mesh_export.gd turns them round
// for glTF); three.js wants them counter-clockwise, so each is turned here.

export const INHERIT = 16;
const MAGIC = 0x334d424c; // "LBM3", little-endian
const HEADER = 44;
const VERTEX = 10;
const I16 = 32767;

export function parseLbm(buffer) {
  const view = new DataView(buffer);
  if (buffer.byteLength < HEADER || view.getUint32(0, true) !== MAGIC) {
    throw new Error("not LBM3 geometry");
  }
  const count = view.getUint16(6, true);
  const scale = view.getFloat32(8, true);
  if (!(count > 0) || !(scale > 0)) throw new Error("no surfaces");
  const step = 1 / scale;
  const bounds = [];
  for (let k = 0; k < 6; k++) bounds.push(view.getFloat32(12 + k * 4, true));
  const surfaces = [];
  let at = HEADER;
  for (let s = 0; s < count; s++) {
    if (at + 12 > buffer.byteLength) throw new Error("truncated");
    const colour = view.getInt16(at, true);
    const flags = view.getUint16(at + 2, true);
    const vertices = view.getUint32(at + 4, true);
    const indices = view.getUint32(at + 8, true);
    at += 12;
    const wide = vertices > 0xffff;
    if (at + vertices * VERTEX + indices * (wide ? 4 : 2) > buffer.byteLength) throw new Error("truncated");
    const position = new Float32Array(vertices * 3);
    const normal = new Float32Array(vertices * 3);
    for (let v = 0; v < vertices; v++, at += VERTEX) {
      position[v * 3] = view.getInt16(at, true) * step;
      position[v * 3 + 1] = view.getInt16(at + 2, true) * step;
      position[v * 3 + 2] = view.getInt16(at + 4, true) * step;
      // Octahedral, as Lbm._oct_decode.
      let x = view.getInt16(at + 6, true) / I16;
      let y = view.getInt16(at + 8, true) / I16;
      let z = 1 - Math.abs(x) - Math.abs(y);
      if (z < 0) {
        const fx = (1 - Math.abs(y)) * (x >= 0 ? 1 : -1);
        const fy = (1 - Math.abs(x)) * (y >= 0 ? 1 : -1);
        x = fx;
        y = fy;
      }
      const length = Math.hypot(x, y, z) || 1;
      normal[v * 3] = x / length;
      normal[v * 3 + 1] = y / length;
      normal[v * 3 + 2] = z / length;
    }
    const index = wide ? new Uint32Array(indices) : new Uint16Array(indices);
    for (let i = 0; i + 2 < indices; i += 3) {
      const a = wide ? view.getUint32(at + i * 4, true) : view.getUint16(at + i * 2, true);
      const b = wide ? view.getUint32(at + (i + 1) * 4, true) : view.getUint16(at + (i + 1) * 2, true);
      const c = wide ? view.getUint32(at + (i + 2) * 4, true) : view.getUint16(at + (i + 2) * 2, true);
      index[i] = a;
      index[i + 1] = c;
      index[i + 2] = b;
    }
    at += indices * (wide ? 4 : 2);
    surfaces.push({ colour, twoSided: (flags & 1) !== 0, position, normal, index });
  }
  return { bounds, surfaces };
}
