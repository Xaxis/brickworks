// A photo of a real build, made safe to show (2026-10-18, supabase/builds.sql).
//
// Somebody's phone puts a great deal into a photo besides the picture: where
// it was taken, to a few metres (GPS), when, on what phone, its serial
// number, a thumbnail of the picture as it was before it was cropped, and
// whatever an editing app wrote. None of it may reach a page. Taking the
// fields out one by one would trust a list of fields, and a file is free to
// carry them anywhere, so nothing of the file is kept: it is decoded to its
// pixels, and a new JPEG is made from the pixels alone. The new file has the
// JFIF header and the picture, and nothing else (api/_jpeg.js's encoder
// writes no other segment). Decoding is also the check that the bytes really
// are a picture: a file that is not a JPEG, a PNG or a WebP all the way
// through does not decode, and is refused.
//
//   JPEG  decoded by jpeg-js (api/_jpeg.js), baseline and progressive, in
//         plain JavaScript; its Exif is read for one thing only, which way
//         up the phone was held (Orientation), and the pixels turned so
//         the new file needs no tag to stand the right way up
//   PNG   decoded here: every chunk's CRC checked, the image data inflated
//         by Node's zlib with a ceiling on how much it may come to, and
//         every colour type, bit depth and interlace PNG has
//   WebP  decoded by libwebp in WebAssembly (api/_webp.js), loaded only
//         when a WebP comes
//
// What comes in: at most 8 MB, at most 40 megapixels and 12,000 pixels a
// side, at least 120 a side; its size read from its header before anything
// is decoded, so a small file that claims to be enormous is refused unread.
// What goes out: a JPEG at most 1,600 pixels on its long side, the
// transparent parts of a PNG or a WebP on white.

import { inflateSync } from "node:zlib";
import { decode as decodeJpeg, encode as encodeJpeg } from "./_jpeg.js";

export { encodeJpeg };

export const MAX_PHOTO_BYTES = 8 * 1024 * 1024;
export const MOST_PIXELS = 40 * 1000 * 1000;
export const MOST_SIDE = 12000;
export const LEAST_SIDE = 120;
export const LONG_SIDE = 1600;
export const QUALITY = 85;
export const TYPES = { "image/jpeg": "jpeg", "image/png": "png", "image/webp": "webp" };

// How long the site's CDN may keep a picture a person sent (a build photo,
// their own avatar) at its address: one taken out on /admin, hidden, or
// taken off by its owner may be seen for this many seconds after, and no
// longer. Never served stale: kept as the pages are (api/share.js
// SHARED_CACHE, 30 s and served stale 30 s more), a picture taken out was
// still served 33 s after its file was deleted (m149's preview, 2026-10-22).
export const PICTURE_KEPT = 10;
export const PICTURE_CACHE = `public, max-age=0, s-maxage=${PICTURE_KEPT}`;

export class PhotoTrouble extends Error {
  constructor(message, status = 415) {
    super(message);
    this.status = status;
  }
}

const NOT_A_PICTURE = "that is not a JPEG, a PNG or a WebP picture";

/// Which of the three [bytes] says it is, from its first bytes, or "".
export function sniff(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "jpeg";
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return "png";
  if (bytes.length >= 12 && bytes.toString("latin1", 0, 4) === "RIFF" && bytes.toString("latin1", 8, 12) === "WEBP") return "webp";
  return "";
}

function checkSize(width, height) {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1) {
    throw new PhotoTrouble(NOT_A_PICTURE);
  }
  if (width > MOST_SIDE || height > MOST_SIDE || width * height > MOST_PIXELS) {
    throw new PhotoTrouble(`that picture is ${width} × ${height}: at most 40 megapixels, please`, 413);
  }
  if (width < LEAST_SIDE || height < LEAST_SIDE) {
    throw new PhotoTrouble(`that picture is ${width} × ${height}: too small to show a build`, 422);
  }
}

// ---------------------------------------------------------------------------
// JPEG.

/// A JPEG's size, from its frame header, without decoding it.
function jpegSize(bytes) {
  let at = 2;
  while (at + 4 <= bytes.length) {
    if (bytes[at] !== 0xff) throw new PhotoTrouble(NOT_A_PICTURE);
    const marker = bytes[at + 1];
    if (marker === 0xff) { at += 1; continue; }
    if (marker === 0xd8 || (marker >= 0xd0 && marker <= 0xd7) || marker === 0x01) { at += 2; continue; }
    const length = bytes.readUInt16BE(at + 2);
    if (length < 2) throw new PhotoTrouble(NOT_A_PICTURE);
    // A start of frame: baseline, extended, progressive or lossless.
    if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
      if (at + 9 > bytes.length) break;
      return { height: bytes.readUInt16BE(at + 5), width: bytes.readUInt16BE(at + 7) };
    }
    if (marker === 0xda || marker === 0xd9) break;
    at += 2 + length;
  }
  throw new PhotoTrouble(NOT_A_PICTURE);
}

/// Which way up the phone was held, from the Exif jpeg-js found (the TIFF
/// after "Exif\0"): 1 to 8, as Exif's Orientation says; 1 for anything
/// else. Nothing else of the Exif is read, and none of it is kept.
export function orientationOf(exif) {
  if (!exif || exif.length < 10) return 1;
  const buf = Buffer.from(exif.buffer, exif.byteOffset, exif.length);
  // jpeg-js keeps the second of "Exif\0\0"'s two NULs; the TIFF follows.
  const start = buf[0] === 0 ? 1 : 0;
  const order = buf.toString("latin1", start, start + 2);
  if (order !== "II" && order !== "MM") return 1;
  const little = order === "II";
  const u16 = (at) => (at + 2 <= buf.length ? (little ? buf.readUInt16LE(at) : buf.readUInt16BE(at)) : -1);
  const u32 = (at) => (at + 4 <= buf.length ? (little ? buf.readUInt32LE(at) : buf.readUInt32BE(at)) : -1);
  const ifd = start + u32(start + 4);
  const entries = u16(ifd);
  if (ifd < start || entries < 0 || entries > 500) return 1;
  for (let n = 0; n < entries; n += 1) {
    const entry = ifd + 2 + n * 12;
    if (u16(entry) === 0x0112) {
      const value = u16(entry + 8);
      return value >= 1 && value <= 8 ? value : 1;
    }
  }
  return 1;
}

function readJpeg(bytes) {
  const { width, height } = jpegSize(bytes);
  checkSize(width, height);
  let image;
  try {
    image = decodeJpeg(bytes, { useTArray: true, formatAsRGBA: true, maxResolutionInMP: MOST_PIXELS / 1e6,
      maxMemoryUsageInMB: 900 });
  } catch {
    throw new PhotoTrouble(`${NOT_A_PICTURE}: it would not decode as a JPEG`);
  }
  if (image.width !== width || image.height !== height) throw new PhotoTrouble(NOT_A_PICTURE);
  return { width, height, data: image.data, alpha: false, orientation: orientationOf(image.exifBuffer) };
}

// ---------------------------------------------------------------------------
// PNG.

const CRC = new Int32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c;
});

function crc32(bytes) {
  let c = -1;
  for (let i = 0; i < bytes.length; i += 1) c = CRC[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

const CHANNELS = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 };
const DEPTHS = { 0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16] };
// Adam7's seven passes: where each starts and how far it steps.
const ADAM7 = [[0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4], [0, 2, 2, 4], [1, 0, 2, 2], [0, 1, 1, 2]];

function readPng(bytes) {
  let at = 8;
  let header = null;
  let palette = null;
  let transparency = null;
  const data = [];
  let ended = false;
  while (at + 12 <= bytes.length) {
    const length = bytes.readUInt32BE(at);
    const type = bytes.toString("latin1", at + 4, at + 8);
    if (length > bytes.length - at - 12) throw new PhotoTrouble(`${NOT_A_PICTURE}: a PNG chunk runs past its end`);
    const body = bytes.subarray(at + 8, at + 8 + length);
    if (crc32(bytes.subarray(at + 4, at + 8 + length)) !== bytes.readUInt32BE(at + 8 + length)) {
      throw new PhotoTrouble(`${NOT_A_PICTURE}: a PNG chunk is damaged`);
    }
    at += 12 + length;
    if (!header && type !== "IHDR") throw new PhotoTrouble(NOT_A_PICTURE);
    if (type === "IHDR") {
      if (length !== 13 || header) throw new PhotoTrouble(NOT_A_PICTURE);
      header = { width: body.readUInt32BE(0), height: body.readUInt32BE(4), depth: body[8], colour: body[9],
        compression: body[10], filter: body[11], interlace: body[12] };
      if (!DEPTHS[header.colour] || !DEPTHS[header.colour].includes(header.depth) || header.compression !== 0
          || header.filter !== 0 || header.interlace > 1) throw new PhotoTrouble(NOT_A_PICTURE);
      checkSize(header.width, header.height);
    } else if (type === "PLTE") {
      if (length % 3 !== 0 || length === 0 || length > 768) throw new PhotoTrouble(NOT_A_PICTURE);
      palette = body;
    } else if (type === "tRNS") {
      transparency = body;
    } else if (type === "IDAT") {
      data.push(body);
    } else if (type === "IEND") {
      ended = true;
      break;
    } else if (!(type.charCodeAt(0) & 0x20)) {
      // A critical chunk this does not know: not a PNG it can read.
      throw new PhotoTrouble(NOT_A_PICTURE);
    }
  }
  if (!header || !ended || data.length === 0) throw new PhotoTrouble(`${NOT_A_PICTURE}: the PNG ends early`);
  if (header.colour === 3 && !palette) throw new PhotoTrouble(NOT_A_PICTURE);
  const { width, height, depth, colour } = header;
  const channels = CHANNELS[colour];
  const bitsPerPixel = channels * depth;
  const passes = header.interlace ? ADAM7 : [[0, 0, 1, 1]];
  const sizes = passes.map(([x0, y0, dx, dy]) => [Math.ceil((width - x0) / dx), Math.ceil((height - y0) / dy)]);
  const expected = sizes.reduce((sum, [w, h]) => sum + (w > 0 && h > 0 ? h * (1 + Math.ceil((w * bitsPerPixel) / 8)) : 0), 0);
  let raw;
  try {
    raw = inflateSync(Buffer.concat(data), { maxOutputLength: expected + 1 });
  } catch {
    throw new PhotoTrouble(`${NOT_A_PICTURE}: its image data would not inflate`);
  }
  if (raw.length < expected) throw new PhotoTrouble(`${NOT_A_PICTURE}: its image data is short`);
  const rgba = new Uint8Array(width * height * 4);
  const bytesPerPixel = Math.max(1, bitsPerPixel >> 3);
  const most = (1 << depth) - 1;
  let alpha = colour === 4 || colour === 6 || transparency !== null;
  const keyed = (value) => transparency && colour === 0 && transparency.length >= 2 && value === transparency.readUInt16BE(0);
  let offset = 0;
  passes.forEach(([x0, y0, dx, dy], pass) => {
    const [w, h] = sizes[pass];
    if (w <= 0 || h <= 0) return;
    const stride = Math.ceil((w * bitsPerPixel) / 8);
    let previous = new Uint8Array(stride);
    for (let row = 0; row < h; row += 1) {
      const filter = raw[offset];
      const line = Uint8Array.from(raw.subarray(offset + 1, offset + 1 + stride));
      offset += 1 + stride;
      for (let i = 0; i < stride; i += 1) {
        const left = i >= bytesPerPixel ? line[i - bytesPerPixel] : 0;
        const up = previous[i];
        const corner = i >= bytesPerPixel ? previous[i - bytesPerPixel] : 0;
        if (filter === 1) line[i] = (line[i] + left) & 0xff;
        else if (filter === 2) line[i] = (line[i] + up) & 0xff;
        else if (filter === 3) line[i] = (line[i] + ((left + up) >> 1)) & 0xff;
        else if (filter === 4) {
          const p = left + up - corner;
          const pa = Math.abs(p - left);
          const pb = Math.abs(p - up);
          const pc = Math.abs(p - corner);
          line[i] = (line[i] + (pa <= pb && pa <= pc ? left : pb <= pc ? up : corner)) & 0xff;
        } else if (filter !== 0) throw new PhotoTrouble(`${NOT_A_PICTURE}: a PNG row has no filter it can have`);
      }
      previous = line;
      const sample = (index) => {
        if (depth === 16) return line[index * 2];
        if (depth === 8) return line[index];
        const bit = index * depth;
        return (line[bit >> 3] >> (8 - depth - (bit & 7))) & most;
      };
      const sample16 = (index) => (depth === 16 ? (line[index * 2] << 8) | line[index * 2 + 1] : sample(index));
      for (let x = 0; x < w; x += 1) {
        const out = ((y0 + row * dy) * width + x0 + x * dx) * 4;
        const base = x * channels;
        let r;
        let g;
        let b;
        let a = 255;
        if (colour === 3) {
          const index = sample(base);
          if (index * 3 + 2 >= palette.length) throw new PhotoTrouble(`${NOT_A_PICTURE}: a colour is not in its palette`);
          [r, g, b] = [palette[index * 3], palette[index * 3 + 1], palette[index * 3 + 2]];
          if (transparency && index < transparency.length) a = transparency[index];
        } else if (colour === 0 || colour === 4) {
          const grey = depth < 8 ? Math.round((sample(base) * 255) / most) : sample(base);
          r = g = b = grey;
          if (colour === 4) a = sample(base + 1);
          else if (keyed(sample16(base))) a = 0;
        } else {
          [r, g, b] = [sample(base), sample(base + 1), sample(base + 2)];
          if (colour === 6) a = sample(base + 3);
          else if (transparency && transparency.length >= 6 && sample16(base) === transparency.readUInt16BE(0)
              && sample16(base + 1) === transparency.readUInt16BE(2) && sample16(base + 2) === transparency.readUInt16BE(4)) a = 0;
        }
        rgba[out] = r;
        rgba[out + 1] = g;
        rgba[out + 2] = b;
        rgba[out + 3] = a;
      }
    }
  });
  if (!alpha) alpha = false;
  return { width, height, data: rgba, alpha, orientation: 1 };
}

// ---------------------------------------------------------------------------
// WebP.

/// A WebP's size, from its first chunk, without decoding it.
function webpSize(bytes) {
  const kind = bytes.toString("latin1", 12, 16);
  if (kind === "VP8 " && bytes.length >= 30 && bytes[23] === 0x9d && bytes[24] === 0x01 && bytes[25] === 0x2a) {
    return { width: bytes.readUInt16LE(26) & 0x3fff, height: bytes.readUInt16LE(28) & 0x3fff };
  }
  if (kind === "VP8L" && bytes.length >= 25 && bytes[20] === 0x2f) {
    const bits = bytes.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
  }
  if (kind === "VP8X" && bytes.length >= 30) {
    return { width: bytes.readUIntLE(24, 3) + 1, height: bytes.readUIntLE(27, 3) + 1 };
  }
  throw new PhotoTrouble(NOT_A_PICTURE);
}

let webp = null;

async function readWebp(bytes) {
  const { width, height } = webpSize(bytes);
  checkSize(width, height);
  if (!webp) {
    webp = (async () => {
      const [{ default: factory }, { WEBP_WASM }] = await Promise.all([import("./_webp.js"), import("./_webp_wasm.js")]);
      return factory({ wasmBinary: Buffer.from(WEBP_WASM, "base64"), print: () => {}, printErr: () => {} });
    })();
  }
  let image;
  try {
    image = (await webp).decode(bytes);
  } catch {
    image = null;
  }
  if (!image || image.width !== width || image.height !== height || !image.data) {
    throw new PhotoTrouble(`${NOT_A_PICTURE}: it would not decode as a WebP`);
  }
  return { width, height, data: new Uint8Array(image.data.buffer, image.data.byteOffset, image.data.length),
    alpha: true, orientation: 1 };
}

// ---------------------------------------------------------------------------
// The new picture.

/// The part [box] ({left, top, width, height}) of [image] made [w] x [h]
/// pixels, each new one the average of the pixels it covers, its
/// transparent parts on white: RGBA, opaque. Only ever made smaller.
export function resample(image, box, w, h) {
  const { width, data } = image;
  const { left, top } = box;
  const sums = new Float64Array(w * h * 3);
  const counts = new Float64Array(w * h);
  const columns = new Int32Array(box.width);
  for (let x = 0; x < box.width; x += 1) columns[x] = Math.min(w - 1, Math.floor((x * w) / box.width));
  for (let y = 0; y < box.height; y += 1) {
    const row = Math.min(h - 1, Math.floor((y * h) / box.height)) * w;
    for (let x = 0; x < box.width; x += 1) {
      const from = ((top + y) * width + left + x) * 4;
      const to = row + columns[x];
      const a = data[from + 3] / 255;
      sums[to * 3] += data[from] * a + 255 * (1 - a);
      sums[to * 3 + 1] += data[from + 1] * a + 255 * (1 - a);
      sums[to * 3 + 2] += data[from + 2] * a + 255 * (1 - a);
      counts[to] += 1;
    }
  }
  const out = new Uint8Array(w * h * 4);
  for (let i = 0; i < w * h; i += 1) {
    const n = counts[i] || 1;
    out[i * 4] = Math.round(sums[i * 3] / n);
    out[i * 4 + 1] = Math.round(sums[i * 3 + 1] / n);
    out[i * 4 + 2] = Math.round(sums[i * 3 + 2] / n);
    out[i * 4 + 3] = 255;
  }
  return { width: w, height: h, data: out };
}

/// [image] made at most LONG_SIDE on its long side.
function shrink(image) {
  const { width, height } = image;
  const scale = Math.min(1, LONG_SIDE / Math.max(width, height));
  return resample(image, { left: 0, top: 0, width, height },
    Math.max(1, Math.round(width * scale)), Math.max(1, Math.round(height * scale)));
}

/// [image] turned and flipped the way Exif's [orientation] says it was
/// held, so it stands the right way up with no tag to say so.
export function upright(image, orientation) {
  if (orientation <= 1 || orientation > 8) return image;
  const { width, height, data } = image;
  const turned = orientation >= 5;
  const w = turned ? height : width;
  const h = turned ? width : height;
  const out = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y += 1) {
    for (let x = 0; x < w; x += 1) {
      // Where the pixel shown at (x, y) is in the file.
      let sx;
      let sy;
      switch (orientation) {
        case 2: sx = width - 1 - x; sy = y; break;
        case 3: sx = width - 1 - x; sy = height - 1 - y; break;
        case 4: sx = x; sy = height - 1 - y; break;
        case 5: sx = y; sy = x; break;
        case 6: sx = y; sy = height - 1 - x; break;
        case 7: sx = width - 1 - y; sy = height - 1 - x; break;
        default: sx = width - 1 - y; sy = x; break;
      }
      out.set(data.subarray((sy * width + sx) * 4, (sy * width + sx) * 4 + 4), (y * w + x) * 4);
    }
  }
  return { width: w, height: h, data: out };
}

/// A picture as it was sent, decoded: {width, height, data (RGBA),
/// orientation, was ("jpeg", "png" or "webp")}. [declared] is the type the
/// upload said it was; it must agree with what the bytes say. [most] is
/// the most bytes it may be.
export async function decodePicture(given, declared = "", most = MAX_PHOTO_BYTES) {
  const bytes = Buffer.isBuffer(given) ? given : Buffer.from(given || []);
  if (bytes.length === 0) throw new PhotoTrouble("there is no photo in that", 400);
  if (bytes.length > most) {
    throw new PhotoTrouble(`that photo is ${(bytes.length / 1048576).toFixed(1)} MB: at most ${most / 1048576} MB, please`, 413);
  }
  const was = sniff(bytes);
  if (!was) throw new PhotoTrouble(NOT_A_PICTURE);
  if (declared && TYPES[declared] !== was) throw new PhotoTrouble(`that file says it is ${declared}, and it is not`);
  const image = was === "jpeg" ? readJpeg(bytes) : was === "png" ? readPng(bytes) : await readWebp(bytes);
  return { ...image, was };
}

/// A photo as it was sent, made into the one that is kept: {bytes (a JPEG),
/// width, height, was ("jpeg", "png" or "webp")}. [declared] is the type
/// the upload said it was; it must agree with what the bytes say.
export async function cleanPhoto(given, declared = "") {
  const image = await decodePicture(given, declared);
  const made = upright(shrink(image), image.orientation);
  const jpeg = encodeJpeg({ data: made.data, width: made.width, height: made.height }, QUALITY).data;
  return { bytes: Buffer.from(jpeg), width: made.width, height: made.height, was: image.was };
}
