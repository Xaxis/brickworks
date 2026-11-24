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
// Drawn as the app draws its own (PartThumbnails), so a lot from the file sits
// beside one the app drew without a seam, in plain JavaScript as
// api/_flatlay.js draws, since a function has no graphics card: orthographic
// from the parts bin's corner, framed as the app frames a part, each surface
// in its own colour and colour 16 in the lot's, lit as the app's pictures are
// lit (lit: measured from them by src/dev/lot_look_probe.gd), then a light
// line where the part turns or steps back. At twice the pixels and halved.
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
/// How the lots are drawn: one more whenever drawLot draws them otherwise.
/// It is in every file's fingerprint (api/share.js lotsFingerprint), so a
/// file kept, or held a year by a cache, under the old drawing is never
/// asked for again, and the next ask draws the version anew.
export const DRAWN = 1;
const OVER = 2;
const SIZE = TILE * OVER;

const unit = (v) => {
  const n = Math.hypot(...v) || 1;
  return v.map((x) => x / n);
};
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
/// The app's camera and lights for a part's picture (PartThumbnails: _frame
/// and the stage's key and fill).
const EYE = unit([0.72, 0.52, 0.86]);
const RIGHT = unit(cross([-EYE[0], -EYE[1], -EYE[2]], [0, 1, 0]));
const UP = cross(RIGHT, [-EYE[0], -EYE[1], -EYE[2]]);
const towards = (x, y) => {
  const [a, b] = [x * Math.PI / 180, y * Math.PI / 180];
  return unit([Math.sin(b) * Math.cos(a), -Math.sin(a), Math.cos(b) * Math.cos(a)]);
};
const KEY = towards(-42, -38);
const FILL = towards(-14, 132);

/// A colour as the palette says it, "rrggbb" or "rrggbbaa", as the app draws
/// it (shownOf): [r, g, b] from 0 to 1, how see-through it is left out
/// (drawLot); null else.
function inkOf(hex) {
  if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(String(hex || ""))) return null;
  const at = (i) => parseInt(hex.slice(i, i + 2), 16) / 255;
  return shownOf([at(0), at(2), at(4)]);
}

/// What the app draws for a palette value (PartLibrary.shown_for): the value,
/// except the black family, dark and nearly grey in OKLab, which keeps its
/// lightness and loses three quarters of its tint, so black reads black
/// and not navy.
function shownOf(ink) {
  const lin = ink.map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  const cube = (x) => Math.sign(x) * Math.abs(x) ** (1 / 3);
  const l = cube(0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]);
  const m = cube(0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]);
  const s = cube(0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]);
  const L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s;
  const a = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s;
  const b = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s;
  if (L >= 0.35 || Math.hypot(a, b) >= 0.04) return ink;
  const [A, B] = [a * 0.25, b * 0.25];
  const l2 = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3;
  const m2 = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3;
  const s2 = (L - 0.0894841775 * A - 1.291485548 * B) ** 3;
  return [4.0767416621 * l2 - 3.3077115913 * m2 + 0.2309699292 * s2,
    -1.2684380046 * l2 + 2.6097574011 * m2 - 0.3413193965 * s2,
    -0.0041960863 * l2 - 0.7034186147 * m2 + 1.707614701 * s2].map((c) => {
    const v = Math.min(Math.max(c, 0), 1);
    return v < 0.0031308 ? v * 12.92 : 1.055 * v ** (1 / 2.4) - 0.055;
  });
}

/// How much light a face gets in the app's own pictures of a part
/// (PartThumbnails, on the Compatibility renderer the web runs, which
/// lights the colour as it is given): per channel, so much of the colour
/// for any face (a), for facing the key light (k) and for facing the fill
/// (f). Measured from its pictures of plain tiles, whose three faces are
/// three known normals (src/dev/lot_look_probe.gd, 2026-11-24): drawn as the
/// page's Parts list draws them, these were half as light as the app's.
/// DARK is a colour up to half light; a lighter one is given less, as the
/// app gives it (_light_for), down to LIGHT's at white.
const DARK = { a: [1.043, 1.085, 1.155], k: [0.704, 0.65, 0.59], f: [0.19, 0.167, 0.188] };
const LIGHT = { a: [0.881, 0.902, 0.977], k: [0.238, 0.203, 0.107], f: [0.082, 0.095, 0.087] };
const HALF = unit([KEY[0] + EYE[0], KEY[1] + EYE[1], KEY[2] + EYE[2]]);
const SHINE = 0.4;
const GLOSS = 24;

/// A pixel of a surface of colour [ink] facing [n], lit as the app lights
/// its pictures: [r, g, b] from 0 to 1.
function lit(ink, n) {
  const bright = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2];
  const t = Math.min(Math.max((bright - 0.5) / 0.45, 0), 1);
  const k = Math.max(dot(n, KEY), 0);
  const f = Math.max(dot(n, FILL), 0);
  // The key's glint, where a round turns to it between the eye and the key:
  // white, as on the app's tyres and rounded edges.
  const shine = SHINE * Math.max(dot(n, HALF), 0) ** GLOSS;
  const out = [0, 0, 0];
  for (let c = 0; c < 3; c += 1) {
    const by = (what) => DARK[what][c] + t * (LIGHT[what][c] - DARK[what][c]);
    out[c] = Math.min(ink[c] * (by("a") + by("k") * k + by("f") * f) + shine, 1);
  }
  return out;
}

/// The lines' colour on a part of colour [ink] (penOf): grey on the darkest,
/// a darker shade of the colour on the rest, and how strongly. Light, as the
/// app's pictures have only a shade where a part folds.
function penOf(ink) {
  const bright = 0.2126 * ink[0] + 0.7152 * ink[1] + 0.0722 * ink[2];
  return [...(bright < 0.12 ? [0.45, 0.45, 0.45] : ink.slice(0, 3).map((c) => c * 0.62)), 0.6];
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
  // Framed as the app frames it (PartThumbnails._frame): on the middle of the
  // part's box, as wide as 1.06 of the box's half diagonal each way, so a
  // part is as big in its square here as in the app's.
  const box = [[Infinity, Infinity, Infinity], [-Infinity, -Infinity, -Infinity]];
  for (const s of surfaces) {
    for (let v = 0; v < s.position.length; v += 3) {
      for (let k = 0; k < 3; k += 1) {
        box[0][k] = Math.min(box[0][k], s.position[v + k]);
        box[1][k] = Math.max(box[1][k], s.position[v + k]);
      }
    }
  }
  const centre = [0, 1, 2].map((k) => (box[0][k] + box[1][k]) / 2);
  const radius = Math.max(Math.hypot(...[0, 1, 2].map((k) => box[1][k] - box[0][k])) * 0.5, 4);
  const half = radius * 1.06;
  const mid = [dot(centre, RIGHT), dot(centre, UP), dot(centre, EYE)];
  // Lines as fine as the app's shade where a part folds: a part shrunk to fit
  // its square, a big plate's hundred studs, would be its lines alone.
  const fine = Math.min(Math.max(0.6 / (2 * half / SIZE), 0.3), 1);
  const N = SIZE * SIZE;
  // The nearest surface: where it faces, how near, and its colour lit. One
  // you can see through is drawn as one you cannot, as the app draws it.
  const near = new Float32Array(N).fill(-1);
  const across = new Float32Array(N);
  const upward = new Float32Array(N);
  const shaded = new Float32Array(N * 3);
  const inks = surfaces.map((s) => (s.colour === INHERIT ? own : inkOf(palette[s.colour]) || own));
  surfaces.forEach((s, which) => {
    const ink = inks[which];
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
      sz[i] = 0.02 + 0.98 * ((e - mid[2]) / (2 * radius) + 0.5);
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
          if (z <= near[at]) continue;
          let n = [0, 0, 0];
          for (let k = 0; k < 3; k += 1) n[k] = w0 * nor[a * 3 + k] + w1 * nor[b * 3 + k] + w2 * nor[c * 3 + k];
          n = unit(n);
          // Facing away, it is its other side that is seen.
          if (dot(n, EYE) < 0) n = n.map((v) => -v);
          near[at] = z;
          across[at] = dot(n, RIGHT);
          upward[at] = dot(n, UP);
          shaded.set(lit(ink, n), at * 3);
        }
      }
    }
  });
  // Each sample's colour (premultiplied), its lines over it.
  const pen = penOf(own);
  const big = new Float32Array(N * 4);
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const at = y * SIZE + x;
      const here = near[at] >= 0;
      const [r, g, b] = here ? shaded.subarray(at * 3, at * 3 + 3) : [0, 0, 0];
      const a = here ? 1 : 0;
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
        line = Math.max(smooth(0.22, 0.5, fold), smooth(0.004, 0.012, step)) * fine;
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
      pixels = drawLot(geometry, inkOf(palette[lot.colour]) || inkOf(lot.hex) || [0.6, 0.6, 0.6], palette);
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
