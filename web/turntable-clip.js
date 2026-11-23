// The model turning once round, as a short video for its link's preview
// (docs/SOCIAL.md, unit turntable): what Discord, Slack and X play when
// somebody pastes a model's link, where today they show a still picture.
// Its designer's own visit to its page records it in a worker, off the
// page's own thread (web/model-page.js, tools/viewer/clip_worker.js built
// as web/turntable-worker.js), drawn as the page's 3D view draws it, and
// sends it to api/share.js ?op=clip, which reads it again (api/_clip.js)
// before keeping it.
//
// Recorded frame by frame with WebCodecs, not filmed off the screen with
// MediaRecorder: each frame is the model turned exactly i/96 of a turn, so
// the 97th would be the first again and the clip loops with no seam,
// however slowly the device draws; nothing is dropped, and nothing is
// timed by the screen (no timers, no frames from it). The file
// is written here, an MP4 of H.264 where the browser can encode that, the
// kind every preview and phone plays, and a WebM of VP9 or VP8 where it
// cannot (Firefox without H.264, Chromium as the checks run it). moov
// comes before mdat, so a player starts without reading the whole file.
//
// Nothing here runs as the module loads: a check imports it under node to
// write and read files with it (tests/test_turntable_clip.py).

export const CLIP = { width: 768, height: 432, fps: 24, frames: 96, maxBytes: 1572864 };

// What each kind is tried as, best first: H.264's constrained baseline,
// which every player decodes, then main; VP9, then VP8. Each at the level
// its frame needs: 3.1 holds the link's clip, and a frame past 1280 x 720
// (Instagram's 1080 x 1920 turn, web/post-kit.js) needs 4.0.
const CODECS = {
  mp4: ["avc1.42001f", "avc1.42e01f", "avc1.4d001f"],
  webm: ["vp09.00.10.08", "vp8"],
};
const CODECS_LARGE = {
  mp4: ["avc1.420028", "avc1.42e028", "avc1.4d0028"],
  webm: ["vp09.00.40.08", "vp8"],
};
const BITRATE = 1_800_000;
// A key frame every two seconds, so a player can start part way.
const KEY_EVERY = 48;
// The ground it turns on, as the app's pictures have one, and whose it is.
const BACKDROP = ["#f6f7f9", "#dfe2e8"];
const WORDMARK = { words: "brickworks.diy", font: '600 15px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
  colour: "rgba(91, 97, 112, 0.7)", margin: 14 };

/// The codecs to try for a clip of [shape].
const codecsOf = (shape) => (shape.width * shape.height > 1280 * 720 ? CODECS_LARGE : CODECS);

/// The encoder's settings for [codec] at [bitrate], for a clip of [shape]:
/// the link's clip at the encoder's best, a frame past 1280 x 720 at its
/// quicker setting, where a software encoder's best takes the time of many
/// times the pixels (Instagram's turn, web/post-kit.js).
function settings(codec, bitrate, shape) {
  const made = { codec, width: shape.width, height: shape.height, bitrate, bitrateMode: "variable",
    framerate: shape.fps, latencyMode: shape.width * shape.height > 1280 * 720 ? "realtime" : "quality" };
  if (codec.startsWith("avc1")) made.avc = { format: "avc" };
  return made;
}

/// The first of [kind]'s codecs this browser encodes for [shape], or "".
async function codecFor(kind, shape) {
  for (const codec of codecsOf(shape)[kind] || []) {
    try {
      const answer = await VideoEncoder.isConfigSupported(settings(codec, shape.bitrate || BITRATE, shape));
      if (answer && answer.supported) return codec;
    } catch { /* the next */ }
  }
  return "";
}

const encodes = () => typeof VideoEncoder === "function" && typeof VideoFrame === "function";

/// The best kind of clip this browser can write of [shape] (the link's
/// clip unless another is given): "mp4" where it encodes H.264, "webm"
/// where it encodes VP9 or VP8 alone, "" where it has no WebCodecs or none
/// of them.
export async function clipKind(shape = CLIP) {
  if (!encodes()) return "";
  if (await codecFor("mp4", shape)) return "mp4";
  if (await codecFor("webm", shape)) return "webm";
  return "";
}

/// The model turning once round, as a clip: [draw](share) gives a canvas
/// with the model turned [share] (0 to 1) of a whole turn, the clip's
/// shape, and is asked for 0, 1/96, ... 95/96. {kind, type, codec, bytes,
/// width, height, ms}, or null where it cannot be made here or [signal]
/// stops it. [gate], where given, is waited on before each frame (the
/// worker holds it while the page is hidden). Written at half the bitrate
/// once more where it comes out past 1.5 MB. Never throws. [shape] is the
/// link's clip (CLIP) unless another is given: {width, height, fps,
/// frames, maxBytes, bitrate}, as Instagram's turn is (web/post-kit.js).
/// Why it made none is put on [report].why, where a report is given.
export async function recordClip(draw, { kind = "", signal = null, gate = null, shape = CLIP, report = null } = {}) {
  const why = (said) => {
    if (report) report.why = said;
    return null;
  };
  try {
    if (!encodes()) return why("no WebCodecs");
    const wanted = kind || (await clipKind(shape));
    const codec = wanted ? await codecFor(wanted, shape) : "";
    if (!codec) return why(`no encoder for ${shape.width} x ${shape.height}`);
    const bitrate = shape.bitrate || BITRATE;
    for (const rate of [bitrate, bitrate / 2]) {
      const made = await encodeOnce(draw, wanted, codec, rate, signal, gate, shape, report);
      if (!made) return null;
      if (made.bytes.length <= shape.maxBytes) return made;
      if (report) report.why = `${codec} came to ${made.bytes.length} bytes`;
    }
    return null;
  } catch (trouble) {
    return why(`${trouble && trouble.message ? trouble.message : trouble}`);
  }
}

/// A picture's own canvas, [width] by [height]: the backdrop, the model
/// over it, and the wordmark unless [wordmark] is false. What it drew is
/// counted on [drawn] (each layer, and every run of text), so a check can
/// say what is on a picture without reading it: LEGO® Ideas takes no text
/// on a project's main picture (web/post-kit.js).
export function easel({ width, height, wordmark = true } = CLIP) {
  const canvas = typeof OffscreenCanvas === "function" ? new OffscreenCanvas(width, height)
    : Object.assign(document.createElement("canvas"), { width, height });
  const pen = canvas.getContext("2d", { alpha: false });
  const ground = pen.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, Math.hypot(width, height) / 2);
  ground.addColorStop(0, BACKDROP[0]);
  ground.addColorStop(1, BACKDROP[1]);
  pen.imageSmoothingEnabled = true;
  pen.imageSmoothingQuality = "high";
  const drawn = { layers: [], text: [] };
  // The wordmark at the same share of the frame on a picture of any size.
  const scale = Math.max(1, Math.min(width, height) / CLIP.height);
  return {
    canvas,
    drawn,
    /// [model] over the backdrop, drawn to the whole frame; [box], where
    /// given, the part of the frame it is drawn in ({x, y, width, height}).
    paint(model, box = null) {
      pen.fillStyle = ground;
      pen.fillRect(0, 0, width, height);
      if (box) pen.drawImage(model, box.x, box.y, box.width, box.height);
      else pen.drawImage(model, 0, 0, width, height);
      if (!drawn.layers.length) drawn.layers.push("backdrop", "model");
      if (!wordmark) return;
      pen.font = WORDMARK.font.replace("15px", `${Math.round(15 * scale)}px`);
      pen.textAlign = "right";
      pen.textBaseline = "alphabetic";
      pen.fillStyle = WORDMARK.colour;
      pen.fillText(WORDMARK.words, width - WORDMARK.margin * scale, height - WORDMARK.margin * scale);
      if (!drawn.text.length) {
        drawn.layers.push("wordmark");
        drawn.text.push(WORDMARK.words);
      }
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

async function encodeOnce(draw, kind, codec, bitrate, signal, gate, shape, report = null) {
  const why = (said) => {
    if (report) report.why = `${codec}: ${said}`;
    return null;
  };
  const { fps, frames } = shape;
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
    encoder.configure(settings(codec, bitrate, shape));
    const page = easel(shape);
    const step = 1e6 / fps;
    for (let i = 0; i < frames; i++) {
      if (gate) await gate();
      if (signal && signal.aborted) { close(); return why("stopped"); }
      if (failure) { close(); return why(failure.message || String(failure)); }
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
    if (failure) return why(failure.message || String(failure));
    if (chunks.length !== frames) return why(`${chunks.length} of ${frames} frames came out`);
    const { width, height } = shape;
    const bytes = kind === "mp4"
      ? (description ? muxMp4({ width, height, fps, description, chunks }) : null)
      : muxWebm({ width, height, fps, codec: codec.startsWith("vp8") ? "V_VP8" : "V_VP9", chunks });
    if (!bytes) return why("it could not be put in its file");
    return { kind, type: kind === "mp4" ? "video/mp4" : "video/webm", codec, bytes, width, height,
      ms: (frames * 1000) / fps };
  } catch (trouble) {
    close();
    return why(trouble && trouble.message ? trouble.message : String(trouble));
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
