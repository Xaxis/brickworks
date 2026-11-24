// Every lot's picture of a published model in one file, drawn once (partpics,
// 2026-11-24): what Build it, the studio's step bar and the parts list show
// at once, before anything is drawn on the page.
//
// The app draws a part's picture live (src/ui/part_thumbnails.gd): a little
// scene of its own, drawn in a frame of the whole window and read back once
// the card has drawn it. In a browser drawing in software that frame is the
// whole model too: step 1 of Survey Ship showed its parts as counts over
// empty boxes for 8.5 s (billbuilds, 2026-11-24). A model's lots are known
// from its file, and the parts they are drawn from are immutable, so they are
// drawn here once a version, the first time anybody asks, and kept beside the
// model in the store: every later ask reads the one small file. The app takes
// them into its pictures (LotPictures) as the model opens, and draws live only
// what the file does not have.
//
// Drawn as the model page's Parts list draws a lot (web/part-pictures.js),
// in plain JavaScript as api/_flatlay.js draws, since a function has no
// graphics card: orthographic from the parts bin's corner, lit by its key and
// its fill, each surface in its own colour and colour 16 in the lot's, then
// its lines where the part turns or steps back. At twice the pixels and
// halved, as the page draws them.
//
// The file is a PNG: [TILE] pixel squares, ACROSS to a row, in the order of
// the index it carries in a tEXt chunk named "brickworks-lots", JSON
// {tile, across, lots: [[part, colour], ...]}; the cells of parts it could
// not draw are left empty and not in the index. One file, so one request;
// a PNG, so the app and a browser read it with nothing added.
import { deflateSync } from "node:zlib";
import { INHERIT, parseLbm } from "./_lbm.js";

export const TILE = 96;
export const ACROSS = 16;
/// The most lots one file holds: 16 across, 64 rows, 6,144 pixels high.
export const MOST = 1024;
/// The chunk the index is carried in.
export const INDEX = "brickworks-lots";
const OVER = 2;
const SIZE = TILE * OVER;

const unit = (v) => {
  const n = Math.hypot(...v) || 1;
  return v.map((x) => x / n);
};
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
/// The camera and lights of web/part-pictures.js (PartThumbnails._frame).
const EYE = unit([0.72, 0.52, 0.86]);
const RIGHT = unit(cross([-EYE[0], -EYE[1], -EYE[2]], [0, 1, 0]));
const UP = cross(RIGHT, [-EYE[0], -EYE[1], -EYE[2]]);
const towards = (x, y) => {
  const [a, b] = [x * Math.PI / 180, y * Math.PI / 180];
  return unit([Math.sin(b) * Math.cos(a), -Math.sin(a), Math.cos(b) * Math.cos(a)]);
};
const KEY = towards(-42, -38);
const FILL = towards(-14, 132);
const HALF = unit([KEY[0] + EYE[0], KEY[1] + EYE[1], KEY[2] + EYE[2]]);

/// A colour as the palette says it, "rrggbb" or "rrggbbaa": [r, g, b, a]
/// from 0 to 1, never less than two thirds there (inkOf); null else.
function inkOf(hex) {
  if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(String(hex || ""))) return null;
  const at = (i) => parseInt(hex.slice(i, i + 2), 16) / 255;
  return [at(0), at(2), at(4), hex.length === 8 ? Math.max(at(6), 0.66) : 1];
}

/// A pixel of a surface of colour [ink] facing [n], lit as the page's
/// FRAGMENT lights it: [r, g, b] from 0 to 1.
function lit(ink, n) {
  const bright = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2];
  const tame = 1 - 0.3 * Math.min(Math.max((bright - 0.6) / 0.4, 0), 1);
  const k = Math.max(dot(n, KEY), 0);
  const f = Math.max(dot(n, FILL), 0);
  const shine = Math.max(dot(n, HALF), 0) ** 48 * 0.22;
  const out = [0, 0, 0];
  for (let c = 0; c < 3; c += 1) {
    out[c] = Math.min(ink[c] * (0.58 + tame * (0.62 * k + 0.3 * f)) + (1 - bright) * 0.16 * k + shine, 1);
  }
  return out;
}

/// The lines' colour on a part of colour [ink] (penOf): grey on the darkest,
/// a dark shade of the colour on the rest, and how strongly.
function penOf(ink) {
  const bright = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2];
  return [...(bright < 0.12 ? [0.5, 0.5, 0.5] : ink.slice(0, 3).map((c) => c * 0.4)), 0.9];
}

const smooth = (a, b, x) => {
  const t = Math.min(Math.max((x - a) / (b - a), 0), 1);
  return t * t * (3 - 2 * t);
};

/// One part's picture: [part] its parsed geometry (parseLbm), [own] the lot's
/// ink, [palette] each colour code's hex for surfaces moulded in their own.
/// TILE x TILE RGBA, straight alpha; null when it has nothing to draw.
export function drawLot(part, own, palette = {}) {
  const surfaces = part.surfaces.filter((s) => s.index.length && s.position.length);
  if (!surfaces.length) return null;
  const lo = [Infinity, Infinity, Infinity];
  const hi = [-Infinity, -Infinity, -Infinity];
  for (const s of surfaces) {
    const p = s.position;
    for (let v = 0; v < p.length; v += 3) {
      const seen = [p[v] * RIGHT[0] + p[v + 1] * RIGHT[1] + p[v + 2] * RIGHT[2],
        p[v] * UP[0] + p[v + 1] * UP[1] + p[v + 2] * UP[2], p[v] * EYE[0] + p[v + 1] * EYE[1] + p[v + 2] * EYE[2]];
      for (let k = 0; k < 3; k += 1) {
        if (seen[k] < lo[k]) lo[k] = seen[k];
        if (seen[k] > hi[k]) hi[k] = seen[k];
      }
    }
  }
  if (!Number.isFinite(lo[0])) return null;
  // Framed as the page frames it: tight round the part, a little room left.
  const half = Math.max(hi[0] - lo[0], hi[1] - lo[1], 1) * 0.5 * 1.08;
  const deep = Math.max(hi[2] - lo[2], 1) * 0.5 * 1.02;
  const mid = [(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2];
  const N = SIZE * SIZE;
  // Nearest of every surface: where it faces and how near (the page's FACTS).
  const near = new Float32Array(N).fill(-1);
  const across = new Float32Array(N);
  const upward = new Float32Array(N);
  // The part lit: the nearest surface you cannot see through, then the
  // nearest you can over it.
  const solid = new Float32Array(N * 3);
  const solidNear = new Float32Array(N).fill(-1);
  const glass = new Float32Array(N * 4);
  const glassNear = new Float32Array(N).fill(-1);
  const inks = surfaces.map((s) => (s.colour === INHERIT ? own : inkOf(palette[s.colour]) || own));
  surfaces.forEach((s, which) => {
    const ink = inks[which];
    const clear = ink[3] < 1;
    const p = s.position;
    const nor = s.normal;
    const count = p.length / 3;
    const sx = new Float32Array(count);
    const sy = new Float32Array(count);
    const sz = new Float32Array(count);
    for (let v = 0, i = 0; i < count; v += 3, i += 1) {
      const x = p[v] * RIGHT[0] + p[v + 1] * RIGHT[1] + p[v + 2] * RIGHT[2];
      const y = p[v] * UP[0] + p[v + 1] * UP[1] + p[v + 2] * UP[2];
      const e = p[v] * EYE[0] + p[v + 1] * EYE[1] + p[v + 2] * EYE[2];
      sx[i] = ((x - mid[0]) / half * 0.5 + 0.5) * SIZE;
      sy[i] = (0.5 - (y - mid[1]) / half * 0.5) * SIZE;
      sz[i] = 0.02 + 0.98 * ((e - mid[2]) / (2 * deep) + 0.5);
    }
    const idx = s.index;
    for (let t = 0; t + 2 < idx.length; t += 3) {
      const a = idx[t];
      const b = idx[t + 1];
      const c = idx[t + 2];
      const [ax, ay, bx, by, qx, qy] = [sx[a], sy[a], sx[b], sy[b], sx[c], sy[c]];
      const area = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax);
      if (Math.abs(area) < 1e-9) continue;
      const minX = Math.max(0, Math.floor(Math.min(ax, bx, qx)));
      const maxX = Math.min(SIZE - 1, Math.ceil(Math.max(ax, bx, qx)));
      const minY = Math.max(0, Math.floor(Math.min(ay, by, qy)));
      const maxY = Math.min(SIZE - 1, Math.ceil(Math.max(ay, by, qy)));
      for (let y = minY; y <= maxY; y += 1) {
        const py = y + 0.5;
        for (let x = minX; x <= maxX; x += 1) {
          const px = x + 0.5;
          const w0 = ((bx - px) * (qy - py) - (by - py) * (qx - px)) / area;
          const w1 = ((qx - px) * (ay - py) - (qy - py) * (ax - px)) / area;
          const w2 = 1 - w0 - w1;
          if (w0 < 0 || w1 < 0 || w2 < 0) continue;
          const z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c];
          const at = y * SIZE + x;
          const keepsFacts = z > near[at];
          const keepsSolid = !clear && z > solidNear[at];
          const keepsGlass = clear && z > glassNear[at];
          if (!keepsFacts && !keepsSolid && !keepsGlass) continue;
          let n = [0, 0, 0];
          for (let k = 0; k < 3; k += 1) n[k] = w0 * nor[a * 3 + k] + w1 * nor[b * 3 + k] + w2 * nor[c * 3 + k];
          n = unit(n);
          // Facing away, it is its other side that is seen.
          if (dot(n, EYE) < 0) n = n.map((v) => -v);
          if (keepsFacts) {
            near[at] = z;
            across[at] = dot(n, RIGHT);
            upward[at] = dot(n, UP);
          }
          if (keepsSolid || keepsGlass) {
            const shade = lit(ink, n);
            if (keepsSolid) {
              solidNear[at] = z;
              solid.set(shade, at * 3);
            } else {
              glassNear[at] = z;
              glass.set([...shade, ink[3]], at * 4);
            }
          }
        }
      }
    }
  });
  // Each sample's colour (premultiplied), the glass over the solid where it
  // is nearer, and its lines over that.
  const pen = penOf(own);
  const big = new Float32Array(N * 4);
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const at = y * SIZE + x;
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      if (solidNear[at] >= 0) {
        [r, g, b] = [solid[at * 3], solid[at * 3 + 1], solid[at * 3 + 2]];
        a = 1;
      }
      if (glassNear[at] >= 0 && glassNear[at] > solidNear[at]) {
        const o = glass[at * 4 + 3];
        r = glass[at * 4] * o + r * (1 - o);
        g = glass[at * 4 + 1] * o + g * (1 - o);
        b = glass[at * 4 + 2] * o + b * (1 - o);
        a = o + a * (1 - o);
      }
      const here = near[at] >= 0;
      const read = (dx, dy) => {
        const xx = Math.min(Math.max(x + dx, 0), SIZE - 1);
        const yy = Math.min(Math.max(y + dy, 0), SIZE - 1);
        return yy * SIZE + xx;
      };
      const l = read(-1, 0);
      const rr = read(1, 0);
      const u = read(0, -1);
      const d = read(0, 1);
      let line = 0;
      if (here !== (near[l] >= 0) || here !== (near[rr] >= 0) || here !== (near[u] >= 0) || here !== (near[d] >= 0)) line = 1;
      else if (here) {
        const apart = (o) => Math.hypot(across[at] - across[o], upward[at] - upward[o]);
        const fold = Math.max(apart(l), apart(rr), apart(u), apart(d));
        const step = Math.max(Math.abs(near[l] + near[rr] - 2 * near[at]), Math.abs(near[u] + near[d] - 2 * near[at]));
        line = Math.max(smooth(0.22, 0.5, fold), smooth(0.004, 0.012, step));
      }
      const o = pen[3] * line;
      big[at * 4] = pen[0] * line + r * a * (1 - o);
      big[at * 4 + 1] = pen[1] * line + g * a * (1 - o);
      big[at * 4 + 2] = pen[2] * line + b * a * (1 - o);
      big[at * 4 + 3] = o + a * (1 - o);
    }
  }
  // Halved, and straight alpha again.
  const out = new Uint8ClampedArray(TILE * TILE * 4);
  for (let y = 0; y < TILE; y += 1) {
    for (let x = 0; x < TILE; x += 1) {
      const sum = [0, 0, 0, 0];
      for (let dy = 0; dy < OVER; dy += 1) {
        for (let dx = 0; dx < OVER; dx += 1) {
          const at = ((y * OVER + dy) * SIZE + (x * OVER + dx)) * 4;
          for (let k = 0; k < 4; k += 1) sum[k] += big[at + k];
        }
      }
      const a = sum[3] / (OVER * OVER);
      const o = (y * TILE + x) * 4;
      if (a <= 0) continue;
      for (let k = 0; k < 3; k += 1) out[o + k] = Math.round((sum[k] / sum[3]) * 255);
      out[o + 3] = Math.round(a * 255);
    }
  }
  return out;
}

/// The file for [lots] ([{part, colour, hex, bytes}], [bytes] the part's
/// .lbm or null), [palette] each colour code's hex, [of] which model file
/// they are (its index says it, so one kept for another file is never
/// taken for it): {png, drawn}, [drawn] how many of them it holds. Lots
/// past MOST are left out.
export function lotSheet(lots, palette = {}, of = "") {
  const cells = [];
  for (const lot of lots.slice(0, MOST)) {
    if (!lot.bytes) continue;
    let pixels = null;
    try {
      const geometry = parseLbm(lot.bytes.buffer.slice(lot.bytes.byteOffset, lot.bytes.byteOffset + lot.bytes.length));
      pixels = drawLot(geometry, inkOf(palette[lot.colour]) || inkOf(lot.hex) || [0.6, 0.6, 0.6, 1], palette);
    } catch {
      pixels = null;
    }
    if (pixels) cells.push({ lot: [String(lot.part), Number(lot.colour)], pixels });
  }
  const across = Math.max(1, Math.min(ACROSS, cells.length));
  const rows = Math.max(1, Math.ceil(cells.length / across));
  const width = across * TILE;
  const height = rows * TILE;
  const data = new Uint8Array(width * height * 4);
  cells.forEach((cell, n) => {
    const left = (n % across) * TILE;
    const top = Math.floor(n / across) * TILE;
    for (let y = 0; y < TILE; y += 1) {
      data.set(cell.pixels.subarray(y * TILE * 4, (y + 1) * TILE * 4), ((top + y) * width + left) * 4);
    }
  });
  const index = JSON.stringify({ tile: TILE, across, of, lots: cells.map((cell) => cell.lot) });
  return { png: pngRgba(width, height, data, { [INDEX]: index }), drawn: cells.length };
}

/// [lots] of a model's list (api/_parts.js inventoryOf), each with its part's
/// geometry read through [read] (a hash -> its .lbm's bytes or null), a few
/// at a time: what lotSheet draws.
export async function withGeometry(lots, read, { atOnce = 8 } = {}) {
  const wanted = lots.filter((lot) => /^[0-9a-f]{8,64}$/.test(String(lot.mesh || ""))).slice(0, MOST);
  const bytes = new Map();
  const meshes = [...new Set(wanted.map((lot) => lot.mesh))];
  let next = 0;
  const worker = async () => {
    while (next < meshes.length) {
      const mesh = meshes[next++];
      bytes.set(mesh, await read(mesh).catch(() => null));
    }
  };
  await Promise.all(Array.from({ length: Math.min(atOnce, meshes.length) }, worker));
  return wanted.map((lot) => ({ part: lot.part, colour: lot.colour, hex: lot.hex, bytes: bytes.get(lot.mesh) || null }));
}

/// The index a sheet carries, or null: what the app and the page read.
export function indexOf(png) {
  const bytes = Buffer.from(png);
  for (let at = 8; at + 8 <= bytes.length;) {
    const length = bytes.readUInt32BE(at);
    const type = bytes.toString("latin1", at + 4, at + 8);
    if (type === "tEXt") {
      const body = bytes.subarray(at + 8, at + 8 + length);
      const zero = body.indexOf(0);
      if (zero > 0 && body.toString("latin1", 0, zero) === INDEX) return JSON.parse(body.toString("latin1", zero + 1));
    }
    if (type === "IEND") break;
    at += 12 + length;
  }
  return null;
}

/// RGBA pixels as a PNG, each row filtered as packs smallest, with [texts]
/// ({keyword: text}) as tEXt chunks before the pixels.
export function pngRgba(width, height, data, texts = {}) {
  const stride = width * 4;
  const rows = Buffer.alloc((stride + 1) * height);
  const line = new Uint8Array(stride);
  for (let y = 0; y < height; y += 1) {
    const row = data.subarray(y * stride, (y + 1) * stride);
    const above = y ? data.subarray((y - 1) * stride, y * stride) : null;
    let best = -1;
    let bestSum = Infinity;
    let bestLine = null;
    for (let filter = 0; filter <= 4; filter += 1) {
      let sum = 0;
      for (let i = 0; i < stride; i += 1) {
        const left = i >= 4 ? row[i - 4] : 0;
        const up = above ? above[i] : 0;
        const corner = above && i >= 4 ? above[i - 4] : 0;
        let value = row[i];
        if (filter === 1) value -= left;
        else if (filter === 2) value -= up;
        else if (filter === 3) value -= (left + up) >> 1;
        else if (filter === 4) {
          const p = left + up - corner;
          const pa = Math.abs(p - left);
          const pb = Math.abs(p - up);
          const pc = Math.abs(p - corner);
          value -= pa <= pb && pa <= pc ? left : pb <= pc ? up : corner;
        }
        line[i] = value & 0xff;
        sum += line[i] < 128 ? line[i] : 256 - line[i];
      }
      if (sum < bestSum) {
        bestSum = sum;
        best = filter;
        bestLine = Uint8Array.from(line);
      }
    }
    const at = y * (stride + 1);
    rows[at] = best;
    rows.set(bestLine, at + 1);
  }
  const chunk = (type, body) => {
    const head = Buffer.alloc(8);
    head.writeUInt32BE(body.length, 0);
    head.write(type, 4, "ascii");
    const sum = Buffer.alloc(4);
    sum.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), body])) >>> 0, 0);
    return Buffer.concat([head, body, sum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bits a sample
  header[9] = 6; // RGBA
  const said = Object.entries(texts).map(([key, text]) => chunk("tEXt", Buffer.concat([Buffer.from(key, "latin1"),
    Buffer.from([0]), Buffer.from(text, "latin1")])));
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", header), ...said,
    chunk("IDAT", deflateSync(rows, { level: 9 })), chunk("IEND", Buffer.alloc(0))]);
}

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

function crc32(bytes) {
  let c = -1;
  for (let i = 0; i < bytes.length; i += 1) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return c ^ -1;
}
