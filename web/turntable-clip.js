// The model turning once round, as a short video for its link's preview
// (docs/SOCIAL.md, unit turntable): what Discord, Slack and X play when
// somebody pastes a model's link, where today they show a still picture.
// Its designer's own visit to its page records it (web/model-page.js),
// from the page's own 3D view (tools/viewer/inline.js turntable), and
// sends it to api/share.js ?op=clip, which reads it again (api/_clip.js)
// before keeping it.
//
// Recorded frame by frame with WebCodecs, not filmed off the screen with
// MediaRecorder: each frame is the model turned exactly i/96 of a turn, so
// the 97th would be the first again and the clip loops with no seam,
// however slowly the device draws; nothing is dropped, and a tab put in
// the background goes on (no timers, no frames from the screen). The file
// is written here, an MP4 of H.264 where the browser can encode that, the
// kind every preview and phone plays, and a WebM of VP9 or VP8 where it
// cannot (Firefox without H.264, Chromium as the checks run it). moov
// comes before mdat, so a player starts without reading the whole file.
//
// Nothing here runs as the module loads: a check imports it under node to
// write and read files with it (tests/test_turntable_clip.py).

export const CLIP = { width: 768, height: 432, fps: 24, frames: 96, maxBytes: 1572864 };

// What each kind is tried as, best first: H.264's constrained baseline,
// which every player decodes, then main; VP9, then VP8.
const CODECS = {
  mp4: ["avc1.42001f", "avc1.42e01f", "avc1.4d001f"],
  webm: ["vp09.00.10.08", "vp8"],
};
const BITRATE = 1_800_000;
// A key frame every two seconds, so a player can start part way.
const KEY_EVERY = 48;
// The ground it turns on, as the app's pictures have one, and whose it is.
const BACKDROP = ["#f6f7f9", "#dfe2e8"];
const WORDMARK = { words: "brickworks.diy", font: '600 15px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
  colour: "rgba(91, 97, 112, 0.7)", margin: 14 };

/// The encoder's settings for [codec] at [bitrate].
function settings(codec, bitrate) {
  const made = { codec, width: CLIP.width, height: CLIP.height, bitrate, bitrateMode: "variable",
    framerate: CLIP.fps, latencyMode: "quality" };
  if (codec.startsWith("avc1")) made.avc = { format: "avc" };
  return made;
}

/// The first of [kind]'s codecs this browser encodes, or "".
async function codecFor(kind) {
  for (const codec of CODECS[kind] || []) {
    try {
      const answer = await VideoEncoder.isConfigSupported(settings(codec, BITRATE));
      if (answer && answer.supported) return codec;
    } catch { /* the next */ }
  }
  return "";
}

const encodes = () => typeof VideoEncoder === "function" && typeof VideoFrame === "function";

/// The best kind of clip this browser can write: "mp4" where it encodes
/// H.264, "webm" where it encodes VP9 or VP8 alone, "" where it has no
/// WebCodecs or none of them.
export async function clipKind() {
  if (!encodes()) return "";
  if (await codecFor("mp4")) return "mp4";
  if (await codecFor("webm")) return "webm";
  return "";
}

/// The model turning once round, as a clip: [draw](share) gives a canvas
/// with the model turned [share] (0 to 1) of a whole turn, the clip's
/// shape, and is asked for 0, 1/96, ... 95/96. {kind, type, codec, bytes,
/// width, height, ms}, or null where it cannot be made here or [signal]
/// stops it. Written at half the bitrate once more where it comes out past
/// 1.5 MB. Never throws.
export async function recordClip(draw, { kind = "", signal = null } = {}) {
  try {
    if (!encodes()) return null;
    const wanted = kind || (await clipKind());
    const codec = wanted ? await codecFor(wanted) : "";
    if (!codec) return null;
    for (const bitrate of [BITRATE, BITRATE / 2]) {
      const made = await encodeOnce(draw, wanted, codec, bitrate, signal);
      if (!made) return null;
      if (made.bytes.length <= CLIP.maxBytes) return made;
    }
    return null;
  } catch {
    return null;
  }
}

/// A frame's own canvas: the backdrop, the model over it, the wordmark.
function easel() {
  const { width, height } = CLIP;
  const canvas = typeof OffscreenCanvas === "function" ? new OffscreenCanvas(width, height)
    : Object.assign(document.createElement("canvas"), { width, height });
  const pen = canvas.getContext("2d", { alpha: false });
  const ground = pen.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, Math.hypot(width, height) / 2);
  ground.addColorStop(0, BACKDROP[0]);
  ground.addColorStop(1, BACKDROP[1]);
  pen.imageSmoothingEnabled = true;
  pen.imageSmoothingQuality = "high";
  return {
    canvas,
    paint(model) {
      pen.fillStyle = ground;
      pen.fillRect(0, 0, width, height);
      pen.drawImage(model, 0, 0, width, height);
      pen.font = WORDMARK.font;
      pen.textAlign = "right";
      pen.textBaseline = "alphabetic";
      pen.fillStyle = WORDMARK.colour;
      pen.fillText(WORDMARK.words, width - WORDMARK.margin, height - WORDMARK.margin);
    },
  };
}

/// A moment for the page between frames, which no background tab holds
/// back as it holds back timers: the scheduler's where there is one, else
/// a message to itself.
function breathe() {
  if (globalThis.scheduler && typeof globalThis.scheduler.yield === "function") return globalThis.scheduler.yield();
  return new Promise((done) => {
    const line = new MessageChannel();
    line.port1.onmessage = () => { line.port1.close(); done(); };
    line.port2.postMessage(0);
  });
}

async function encodeOnce(draw, kind, codec, bitrate, signal) {
  const { fps, frames } = CLIP;
  const chunks = [];
  let description = null;
  let failure = null;
  let failed;
  const stopped = new Promise((resolve) => { failed = resolve; });
  const encoder = new VideoEncoder({
    output: (chunk, metadata) => {
      const data = new Uint8Array(chunk.byteLength);
      chunk.copyTo(data);
      chunks.push({ data, key: chunk.type === "key" });
      const given = metadata && metadata.decoderConfig && metadata.decoderConfig.description;
      if (given && !description) {
        description = given instanceof ArrayBuffer ? new Uint8Array(given.slice(0))
          : new Uint8Array(given.buffer.slice(given.byteOffset, given.byteOffset + given.byteLength));
      }
    },
    error: (trouble) => { failure = trouble || new Error("the encoder failed"); failed(); },
  });
  const close = () => { try { if (encoder.state !== "closed") encoder.close(); } catch { /* closed */ } };
  try {
    encoder.configure(settings(codec, bitrate));
    const page = easel();
    const step = 1e6 / fps;
    for (let i = 0; i < frames; i++) {
      if (signal && signal.aborted) { close(); return null; }
      if (failure) { close(); return null; }
      // Drawn and copied in one go: a WebGL canvas is only readable in
      // the task that drew it.
      page.paint(draw(i / frames));
      const frame = new VideoFrame(page.canvas, { timestamp: Math.round(i * step), duration: Math.round(step) });
      encoder.encode(frame, { keyFrame: i % KEY_EVERY === 0 });
      frame.close();
      while (encoder.encodeQueueSize > 4 && !failure) {
        const drained = "ondequeue" in encoder
          ? new Promise((done) => encoder.addEventListener("dequeue", done, { once: true })) : breathe();
        await Promise.race([drained, stopped]);
      }
      await breathe();
    }
    await Promise.race([encoder.flush(), stopped]);
    close();
    if (failure || chunks.length !== frames) return null;
    const bytes = kind === "mp4"
      ? (description ? muxMp4({ width: CLIP.width, height: CLIP.height, fps, description, chunks }) : null)
      : muxWebm({ width: CLIP.width, height: CLIP.height, fps, codec: codec.startsWith("vp8") ? "V_VP8" : "V_VP9", chunks });
    if (!bytes) return null;
    return { kind, type: kind === "mp4" ? "video/mp4" : "video/webm", codec, bytes, width: CLIP.width,
      height: CLIP.height, ms: (frames * 1000) / fps };
  } catch {
    close();
    return null;
  }
}

// ---------------------------------------------------------------------------
// Bytes, written big-endian.

function joined(parts) {
  let length = 0;
  for (const part of parts) length += part.length;
  const out = new Uint8Array(length);
  let at = 0;
  for (const part of parts) { out.set(part, at); at += part.length; }
  return out;
}

const u8 = (...values) => Uint8Array.from(values);
const u16 = (value) => u8((value >>> 8) & 255, value & 255);
const u32 = (value) => u8((value >>> 24) & 255, (value >>> 16) & 255, (value >>> 8) & 255, value & 255);
const zeros = (n) => new Uint8Array(n);
const text = (words) => Uint8Array.from(words, (c) => c.charCodeAt(0));

// ---------------------------------------------------------------------------
// MP4 (ISO/IEC 14496-12), one picture track, every frame in one chunk.

const box = (type, ...parts) => {
  const body = joined(parts);
  return joined([u32(body.length + 8), text(type), body]);
};
const full = (type, version, flags, ...parts) => box(type, u8(version, (flags >>> 16) & 255, (flags >>> 8) & 255, flags & 255), ...parts);
// The identity, as every header that has a matrix writes it.
const MATRIX = joined([u32(0x10000), u32(0), u32(0), u32(0), u32(0x10000), u32(0), u32(0), u32(0), u32(0x40000000)]);

/// [chunks] ({data, key}, in order, each its NAL units with their lengths
/// in front, as VideoEncoder gives them with avc's "avc" format) as an MP4
/// of [width] by [height] at [fps], [description] its decoder's settings
/// (the avcC VideoEncoder gives with the first): moov before mdat.
export function muxMp4({ width, height, fps, description, chunks }) {
  // A tick that each frame lasts a whole number of: 1000 a frame.
  const scale = Math.round(fps * 1000);
  const tick = 1000;
  const n = chunks.length;
  const mediaDuration = n * tick;
  const movieDuration = Math.round((n * 1000) / fps);
  const keys = [];
  chunks.forEach((chunk, k) => { if (chunk.key) keys.push(k + 1); });
  const ftyp = box("ftyp", text("isom"), u32(512), text("isom"), text("iso2"), text("avc1"), text("mp41"));
  const moovAt = (offset) => box("moov",
    full("mvhd", 0, 0, u32(0), u32(0), u32(1000), u32(movieDuration), u32(0x10000), u16(0x100), zeros(10), MATRIX,
      zeros(24), u32(2)),
    box("trak",
      full("tkhd", 0, 3, u32(0), u32(0), u32(1), u32(0), u32(movieDuration), zeros(8), u16(0), u16(0), u16(0), u16(0),
        MATRIX, u32(width * 65536), u32(height * 65536)),
      box("mdia",
        full("mdhd", 0, 0, u32(0), u32(0), u32(scale), u32(mediaDuration), u16(0x55c4), u16(0)),
        full("hdlr", 0, 0, u32(0), text("vide"), zeros(12), text("VideoHandler\0")),
        box("minf",
          full("vmhd", 0, 1, zeros(8)),
          box("dinf", full("dref", 0, 0, u32(1), full("url ", 0, 1))),
          box("stbl",
            full("stsd", 0, 0, u32(1),
              box("avc1", zeros(6), u16(1), zeros(16), u16(width), u16(height), u32(0x480000), u32(0x480000), u32(0),
                u16(1), zeros(32), u16(0x18), u16(0xffff), box("avcC", description))),
            full("stts", 0, 0, u32(1), u32(n), u32(tick)),
            full("stss", 0, 0, u32(keys.length), ...keys.map(u32)),
            full("stsc", 0, 0, u32(1), u32(1), u32(n), u32(1)),
            full("stsz", 0, 0, u32(0), u32(n), ...chunks.map((chunk) => u32(chunk.data.length))),
            full("stco", 0, 0, u32(1), u32(offset)))))));
  // Its size does not change with the offset written in it: sized once,
  // then written with where the first frame really is.
  const sized = moovAt(0).length;
  const moov = moovAt(ftyp.length + sized + 8);
  const pictures = joined(chunks.map((chunk) => chunk.data));
  return joined([ftyp, moov, u32(pictures.length + 8), text("mdat"), pictures]);
}

// ---------------------------------------------------------------------------
// WebM (Matroska's EBML): one picture track, a Cluster from each key frame.

/// An EBML size, in as few bytes as hold it.
function size(n) {
  for (let length = 1; length <= 8; length++) {
    if (n < 2 ** (7 * length) - 1) {
      const out = new Uint8Array(length);
      let rest = n;
      for (let k = length - 1; k >= 0; k--) { out[k] = rest % 256; rest = Math.floor(rest / 256); }
      out[0] |= 0x80 >> (length - 1);
      return out;
    }
  }
  throw new Error("too big for EBML");
}

/// An element: its ID (marker and all, as the spec writes it), its size,
/// what it holds.
function el(id, ...parts) {
  const head = [];
  for (let rest = id; rest > 0; rest = Math.floor(rest / 256)) head.unshift(rest % 256);
  const body = joined(parts);
  return joined([Uint8Array.from(head), size(body.length), body]);
}

function uint(id, value) {
  const bytes = [];
  for (let rest = value; rest > 0; rest = Math.floor(rest / 256)) bytes.unshift(rest % 256);
  return el(id, Uint8Array.from(bytes.length ? bytes : [0]));
}

function float(id, value) {
  const out = new Uint8Array(8);
  new DataView(out.buffer).setFloat64(0, value);
  return el(id, out);
}

const string = (id, words) => el(id, text(words));

/// [chunks] ({data, key}, in order) as a WebM of [width] by [height] at
/// [fps], [codec] its CodecID (V_VP9 or V_VP8), with its length said
/// (a MediaRecorder's file says none, and a preview cannot show one).
export function muxWebm({ width, height, fps, codec, chunks }) {
  const ms = (chunks.length * 1000) / fps;
  const head = el(0x1a45dfa3, uint(0x4286, 1), uint(0x42f7, 1), uint(0x42f2, 4), uint(0x42f3, 8),
    string(0x4282, "webm"), uint(0x4287, 4), uint(0x4285, 2));
  const info = el(0x1549a966, uint(0x2ad7b1, 1000000), string(0x4d80, "brickworks"), string(0x5741, "brickworks"),
    float(0x4489, ms));
  const tracks = el(0x1654ae6b, el(0xae, uint(0xd7, 1), uint(0x73c5, 1), uint(0x83, 1), uint(0x9c, 0),
    string(0x86, codec), uint(0x23e383, Math.round(1e9 / fps)), el(0xe0, uint(0xb0, width), uint(0xba, height))));
  const clusters = [];
  let start = 0;
  let blocks = [];
  const close = () => { if (blocks.length) clusters.push(el(0x1f43b675, uint(0xe7, start), ...blocks)); blocks = []; };
  chunks.forEach((chunk, k) => {
    const at = Math.round((k * 1000) / fps);
    // A Cluster from each key frame, and before a frame's time from it
    // would not fit in its two bytes.
    if (k === 0 || chunk.key || at - start > 30000) { close(); start = at; }
    const relative = at - start;
    blocks.push(el(0xa3, u8(0x81, (relative >> 8) & 255, relative & 255, chunk.key ? 0x80 : 0), chunk.data));
  });
  close();
  return joined([head, el(0x18538067, info, tracks, ...clusters)]);
}
