// The model as the tab packs it for the viewer (src/net/model_scene.gd):
// which part, in which colour, where and turned how, for every brick, in
// columns, deflated and in base64. Unpacked here into plain arrays.
//
//   v        1
//   of       what the model was when it was packed: "world:generation:revision"
//   root     where each part's geometry is: root + hash + ".lbm"
//   step     LDU per position unit
//   origin   [x, y, z] LDU the positions are counted from
//   meshes   [[part id, hash ("" for a part made in the tab), name,
//              min x, min y, min z, max x, max y, max z], ...]
//   colours  [[code, name, "rrggbb", alpha 0-255], ...]
//   count    how many bricks
//   bricks   the columns, little-endian, count of each:
//              u32 the brick's number less the one before it (look_at_model's #)
//              u16 mesh, u16 colour (indices into meshes and colours)
//              u8 flags (1: the ground it stands on, not the model), then a
//                 byte to keep the rest even when count is odd
//              i16 x, y, z (steps from origin)
//              i16 qx, qy, qz, qw (the turn, a unit quaternion times 32767)

export const SCENERY = 1;

function bytesOf(base64) {
  const raw = atob(base64);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

async function inflate(bytes) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

// A scene the card can draw, or null for anything else.
export function sceneShape(s) {
  return s && typeof s === "object" && s.v === 1 && typeof s.bricks === "string"
    && Number.isInteger(s.count) && s.count >= 0 && Array.isArray(s.meshes) && Array.isArray(s.colours)
    && typeof s.root === "string" && /^https:\/\//.test(s.root) ? s : null;
}

export async function unpack(s) {
  const n = s.count;
  const raw = await inflate(bytesOf(s.bricks));
  const want = n * 4 + n * 2 + n * 2 + n + (n % 2) + n * 6 + n * 8;
  if (raw.length !== want) throw new Error(`the bricks are ${raw.length} bytes, not ${want}`);
  const view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  const ids = new Uint32Array(n);
  const mesh = new Uint16Array(n);
  const colour = new Uint16Array(n);
  const flags = new Uint8Array(n);
  const position = new Float32Array(n * 3);
  const turn = new Float32Array(n * 4);
  let at = 0;
  let id = 0;
  for (let i = 0; i < n; i++, at += 4) { id += view.getUint32(at, true); ids[i] = id; }
  for (let i = 0; i < n; i++, at += 2) mesh[i] = view.getUint16(at, true);
  for (let i = 0; i < n; i++, at += 2) colour[i] = view.getUint16(at, true);
  for (let i = 0; i < n; i++, at += 1) flags[i] = view.getUint8(at);
  at += n % 2;
  const step = Number(s.step) || 1;
  const origin = Array.isArray(s.origin) ? s.origin.map(Number) : [0, 0, 0];
  for (let axis = 0; axis < 3; axis++) {
    for (let i = 0; i < n; i++, at += 2) position[i * 3 + axis] = origin[axis] + view.getInt16(at, true) * step;
  }
  for (let k = 0; k < 4; k++) {
    for (let i = 0; i < n; i++, at += 2) turn[i * 4 + k] = view.getInt16(at, true) / 32767;
  }
  for (let i = 0; i < n; i++) {
    const q = turn.subarray(i * 4, i * 4 + 4);
    const length = Math.hypot(q[0], q[1], q[2], q[3]) || 1;
    for (let k = 0; k < 4; k++) q[k] /= length;
  }
  const byId = new Map();
  for (let i = 0; i < n; i++) byId.set(ids[i], i);
  const colours = s.colours.map((c) => ({ code: Number(c[0]), name: String(c[1] || ""),
    hex: /^[0-9a-f]{6}$/i.test(String(c[2])) ? String(c[2]) : "ff00ff", alpha: Math.max(0, Math.min(255, Number(c[3]) || 255)) }));
  const meshes = s.meshes.map((m) => ({ part: String(m[0] || ""), hash: /^[0-9a-f]{8,64}$/.test(String(m[1])) ? String(m[1]) : "",
    name: String(m[2] || m[0] || ""), bounds: m.slice(3, 9).map(Number) }));
  return { n, ids, mesh, colour, flags, position, turn, byId, colours, meshes };
}
