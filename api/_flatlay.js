// A set's picture where LDraw has no 3D model of it (sets364): a flat lay
// of its most distinctive parts (tools/set_catalog.py picks them), each
// drawn here from the geometry the app draws it from, as a model page's
// Parts list draws a lot (web/part-pictures.js): orthographic from the
// parts bin's corner, lit by its key and its fill, colour 16 in the lot's
// colour, with an outline. Never a photograph: the LEGO Group's and
// Rebrickable's pictures are theirs, and nothing of theirs is shown or
// fetched.
//
// Drawn in plain JavaScript, a triangle at a time into a depth buffer at
// twice the size and halved, then written as a JPEG (api/_jpeg.js): a
// function has no graphics card. Six parts of a few thousand triangles
// take a fraction of a second, once a set: the CDN keeps the picture a
// year (api/share.js set_picture), and the parts it is drawn from change
// only when the catalogue does.

import { encode } from "./_jpeg.js";
import { INHERIT, parseLbm } from "./_lbm.js";

export const WIDTH = 1200;
export const HEIGHT = 630;
const OVER = 2;
/// The ground, top to foot: the renders' own (site.css --render-top and
/// --render-foot), which a model page on a phone carries on above and below
/// a picture shorter than its frame (web/model-page.js fitPicture).
const GROUND_TOP = [237, 239, 244];
const GROUND_FOOT = [204, 211, 221];
const unit = (v) => {
  const n = Math.hypot(...v) || 1;
  return v.map((x) => x / n);
};
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
/// The parts bin's camera and lights (web/part-pictures.js, PartThumbnails._frame).
const EYE = unit([0.72, 0.52, 0.86]);
const RIGHT = unit(cross([-EYE[0], -EYE[1], -EYE[2]], [0, 1, 0]));
const UP = cross(RIGHT, [-EYE[0], -EYE[1], -EYE[2]]);
const towards = (x, y) => {
  const [a, b] = [x * Math.PI / 180, y * Math.PI / 180];
  return unit([Math.sin(b) * Math.cos(a), -Math.sin(a), Math.cos(b) * Math.cos(a)]);
};
const KEY = towards(-42, -38);
const FILL = towards(-14, 132);

const rgbOf = (hex) => {
  const text = String(hex || "").padEnd(6, "0");
  return [0, 2, 4].map((at) => Number.parseInt(text.slice(at, at + 2), 16) || 0);
};

/// Where each of [n] parts goes: a row of up to three, two rows past that.
export function cells(n, width = WIDTH, height = HEIGHT) {
  const across = n <= 3 ? Math.max(1, n) : n === 4 ? 2 : 3;
  const rows = Math.ceil(n / across);
  const margin = Math.round(height * 0.06);
  const w = (width - margin * 2) / across;
  const h = (height - margin * 2) / rows;
  const out = [];
  for (let k = 0; k < n; k += 1) {
    const row = Math.floor(k / across);
    const inRow = Math.min(across, n - row * across);
    const left = margin + (width - margin * 2 - inRow * w) / 2;
    out.push({ x: left + (k % across) * w, y: margin + row * h, w, h });
  }
  return out;
}

/// The picture of [parts] ([{mesh: ArrayBuffer of its .lbm, hex: its
/// colour}]), [palette] each colour code's hex (api/_parts.js paletteOf):
/// {width, height, data} as RGBA.
export function drawFlatLay(parts, palette = {}, { width = WIDTH, height = HEIGHT } = {}) {
  const W = width * OVER;
  const H = height * OVER;
  const colour = new Float32Array(W * H * 3);
  const depth = new Float32Array(W * H).fill(-Infinity);
  const owner = new Int16Array(W * H).fill(-1);
  for (let y = 0; y < H; y += 1) {
    // By the picture's own row, so its first is the top's and its last the foot's.
    const ground = GROUND_TOP.map((v, c) => v + ((GROUND_FOOT[c] - v) * Math.floor(y / OVER)) / Math.max(1, height - 1));
    for (let x = 0; x < W; x += 1) colour.set(ground, (y * W + x) * 3);
  }
  const places = cells(parts.length, W, H);
  parts.forEach((part, which) => {
    let geometry;
    try {
      geometry = parseLbm(part.mesh);
    } catch {
      return;
    }
    // Its outline as the camera sees it, fitted to its cell with room round it.
    let [x0, x1, y0, y1] = [Infinity, -Infinity, Infinity, -Infinity];
    for (const surface of geometry.surfaces) {
      const at = surface.position;
      for (let v = 0; v < at.length; v += 3) {
        const x = at[v] * RIGHT[0] + at[v + 1] * RIGHT[1] + at[v + 2] * RIGHT[2];
        const y = at[v] * UP[0] + at[v + 1] * UP[1] + at[v + 2] * UP[2];
        x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
      }
    }
    if (!Number.isFinite(x0)) return;
    const cell = places[which];
    const scale = Math.min(cell.w * 0.84 / Math.max(x1 - x0, 1e-3), cell.h * 0.84 / Math.max(y1 - y0, 1e-3));
    const cx = cell.x + cell.w / 2 - ((x0 + x1) / 2) * scale;
    const cy = cell.y + cell.h / 2 + ((y0 + y1) / 2) * scale;
    const own = rgbOf(part.hex);
    for (const surface of geometry.surfaces) {
      const said = surface.colour === INHERIT ? null : palette[surface.colour];
      const base = said ? rgbOf(said) : own;
      const pos = surface.position;
      const nor = surface.normal;
      const idx = surface.index;
      const sx = new Float32Array(pos.length / 3);
      const sy = new Float32Array(pos.length / 3);
      const sz = new Float32Array(pos.length / 3);
      for (let v = 0, i = 0; v < pos.length; v += 3, i += 1) {
        sx[i] = cx + (pos[v] * RIGHT[0] + pos[v + 1] * RIGHT[1] + pos[v + 2] * RIGHT[2]) * scale;
        sy[i] = cy - (pos[v] * UP[0] + pos[v + 1] * UP[1] + pos[v + 2] * UP[2]) * scale;
        sz[i] = pos[v] * EYE[0] + pos[v + 1] * EYE[1] + pos[v + 2] * EYE[2];
      }
      for (let t = 0; t + 2 < idx.length; t += 3) {
        const a = idx[t];
        const b = idx[t + 1];
        const c = idx[t + 2];
        // Lit by the face's own normal, turned to the camera when it faces away.
        let n = [0, 0, 0];
        for (const v of [a, b, c]) for (let k = 0; k < 3; k += 1) n[k] += nor[v * 3 + k];
        n = unit(n);
        if (n[0] * EYE[0] + n[1] * EYE[1] + n[2] * EYE[2] < 0) n = n.map((x) => -x);
        const lit = 0.42 + 0.5 * Math.max(0, n[0] * KEY[0] + n[1] * KEY[1] + n[2] * KEY[2])
          + 0.22 * Math.max(0, n[0] * FILL[0] + n[1] * FILL[1] + n[2] * FILL[2]);
        const shade = [Math.min(255, base[0] * lit), Math.min(255, base[1] * lit), Math.min(255, base[2] * lit)];
        const [ax, ay, bx, by, qx, qy] = [sx[a], sy[a], sx[b], sy[b], sx[c], sy[c]];
        const area = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax);
        if (Math.abs(area) < 1e-9) continue;
        const minX = Math.max(0, Math.floor(Math.min(ax, bx, qx)));
        const maxX = Math.min(W - 1, Math.ceil(Math.max(ax, bx, qx)));
        const minY = Math.max(0, Math.floor(Math.min(ay, by, qy)));
        const maxY = Math.min(H - 1, Math.ceil(Math.max(ay, by, qy)));
        for (let y = minY; y <= maxY; y += 1) {
          const py = y + 0.5;
          for (let x = minX; x <= maxX; x += 1) {
            const px = x + 0.5;
            const w0 = ((bx - px) * (qy - py) - (by - py) * (qx - px)) / area;
            const w1 = ((qx - px) * (ay - py) - (qy - py) * (ax - px)) / area;
            const w2 = 1 - w0 - w1;
            if (w0 < 0 || w1 < 0 || w2 < 0) continue;
            const z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c];
            const at = y * W + x;
            if (z <= depth[at]) continue;
            depth[at] = z;
            owner[at] = which;
            colour[at * 3] = shade[0];
            colour[at * 3 + 1] = shade[1];
            colour[at * 3 + 2] = shade[2];
          }
        }
      }
    }
  });
  // Its lines, as the instructions draw a part's: where a part ends, and
  // where one face steps back from the one in front of it.
  const edge = new Uint8Array(W * H);
  for (let y = 1; y < H - 1; y += 1) {
    for (let x = 1; x < W - 1; x += 1) {
      const at = y * W + x;
      if (owner[at] < 0) continue;
      for (const near of [at - 1, at + 1, at - W, at + W]) {
        if (owner[near] !== owner[at] || depth[at] - depth[near] > 6) {
          edge[at] = 1;
          break;
        }
      }
    }
  }
  const data = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const sum = [0, 0, 0];
      for (let dy = 0; dy < OVER; dy += 1) {
        for (let dx = 0; dx < OVER; dx += 1) {
          const at = (y * OVER + dy) * W + (x * OVER + dx);
          const dark = edge[at] ? 0.45 : 1;
          sum[0] += colour[at * 3] * dark;
          sum[1] += colour[at * 3 + 1] * dark;
          sum[2] += colour[at * 3 + 2] * dark;
        }
      }
      const out = (y * width + x) * 4;
      data[out] = sum[0] / (OVER * OVER);
      data[out + 1] = sum[1] / (OVER * OVER);
      data[out + 2] = sum[2] / (OVER * OVER);
      data[out + 3] = 255;
    }
  }
  return { width, height, data };
}

/// The picture as a JPEG's bytes.
export function flatLayJpeg(parts, palette, options) {
  return Buffer.from(encode(drawFlatLay(parts, palette, options), 86).data);
}
