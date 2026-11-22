// A model's clip, as its designer's browser sends it (docs/SOCIAL.md, unit
// turntable): the model turning once round, 4 s or less, which its link's
// preview plays in Discord, Slack and X (api/share.js ?op=clip). The
// browser records it with WebCodecs and writes the file itself
// (web/turntable-clip.js): an MP4 of H.264 where it can encode that, a
// WebM of VP9 or VP8 where it cannot.
//
// The file is somebody else's bytes until it has been read here, so it is
// read here, box by box and element by element, every length held to what
// is left, before anything is stored: one picture track and nothing else
// (no sound to play in a preview muted anyway), a codec every preview
// plays, a size a link preview shows, a length of 4 s or less, and the
// facts the page's head says of it (og:video:width, og:video:height) from
// the file itself, not from what the sender said. Nothing in it throws:
// whatever cannot be read is an { error } in words.

export const MAX_CLIP_BYTES = 1572864;
export const MAX_CLIP_MS = 4000;
export const CLIP_TYPES = { mp4: "video/mp4", webm: "video/webm" };
// The sides a clip may have: a preview draws nothing smaller, and nothing
// bigger fits in 1.5 MB at a picture worth looking at.
const SMALLEST = 16;
const LARGEST = 1920;
// Rounding a length to whole milliseconds may add one.
const ROUNDING_MS = 1;

/// What [bytes] (a Buffer or a Uint8Array) is, as a clip: {kind ("mp4" or
/// "webm"), codec ("avc1", "vp9" or "vp8"), width, height, ms, frames}, or
/// {error} saying why it is not one that can be stored.
export function readClip(bytes) {
  try {
    if (!(bytes instanceof Uint8Array)) return { error: "the clip is not a file" };
    if (bytes.length === 0) return { error: "the clip is empty" };
    if (bytes.length > MAX_CLIP_BYTES) return { error: "the clip is larger than 1.5 MB" };
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    let facts;
    if (bytes.length >= 8 && ascii(bytes, 4, 8) === "ftyp") facts = readMp4(bytes, view);
    else if (bytes.length >= 4 && view.getUint32(0) === 0x1a45dfa3) facts = readWebm(bytes, view);
    else return { error: "the clip is not an MP4 or a WebM" };
    if (facts.error) return facts;
    const { width, height, ms, frames } = facts;
    if (!(width >= SMALLEST && width <= LARGEST && height >= SMALLEST && height <= LARGEST)) {
      return { error: `the clip is ${width} by ${height}: each side is ${SMALLEST} to ${LARGEST} pixels` };
    }
    if (!(frames >= 1)) return { error: "the clip has no pictures in it" };
    if (!(ms > 0)) return { error: "the clip says no length" };
    if (ms > MAX_CLIP_MS + ROUNDING_MS) return { error: "the clip is longer than 4 seconds" };
    return facts;
  } catch {
    return { error: "the clip could not be read" };
  }
}

const ascii = (bytes, from, to) => String.fromCharCode(...bytes.subarray(from, to));

// ---------------------------------------------------------------------------
// MP4 (ISO/IEC 14496-12): boxes, each its size and its type, then its own.

class Short extends Error {}

/// The boxes from [from] to [to], each {type, start (of its content), end}:
/// a box that says it runs past [to] is a file cut short.
function boxes(bytes, view, from, to) {
  const found = [];
  let at = from;
  while (at < to) {
    if (to - at < 8) throw new Short();
    let size = view.getUint32(at);
    const type = ascii(bytes, at + 4, at + 8);
    let start = at + 8;
    if (size === 1) {
      if (to - at < 16) throw new Short();
      const big = view.getBigUint64(at + 8);
      if (big > BigInt(to - at)) throw new Short();
      size = Number(big);
      start = at + 16;
    } else if (size === 0) {
      size = to - at;
    }
    if (size < start - at || at + size > to) throw new Short();
    found.push({ type, start, end: at + size });
    at += size;
  }
  return found;
}

const child = (list, type) => list.find((box) => box.type === type) || null;

function readMp4(bytes, view) {
  let top;
  try {
    top = boxes(bytes, view, 0, bytes.length);
  } catch (trouble) {
    if (trouble instanceof Short) return { error: "the clip is cut short" };
    throw trouble;
  }
  if (top[0].type !== "ftyp") return { error: "the clip is not an MP4 or a WebM" };
  const moov = child(top, "moov");
  if (!moov) return { error: "the clip has no description of its pictures (moov)" };
  if (!child(top, "mdat")) return { error: "the clip has no pictures in it" };
  try {
    const inMoov = boxes(bytes, view, moov.start, moov.end);
    const traks = inMoov.filter((box) => box.type === "trak");
    if (traks.length === 0) return { error: "the clip has no pictures in it" };
    if (traks.length > 1) return { error: "the clip carries more than its pictures: one picture track and no sound" };
    const mvhd = child(inMoov, "mvhd");
    const movie = mvhd ? lengthOf(bytes, view, mvhd, 12) : null;
    const inTrak = boxes(bytes, view, traks[0].start, traks[0].end);
    const tkhd = child(inTrak, "tkhd");
    const mdia = child(inTrak, "mdia");
    if (!mdia) return { error: "the clip has no pictures in it" };
    const inMdia = boxes(bytes, view, mdia.start, mdia.end);
    const hdlr = child(inMdia, "hdlr");
    if (!hdlr || hdlr.end - hdlr.start < 12) return { error: "the clip does not say what its track is" };
    if (ascii(bytes, hdlr.start + 8, hdlr.start + 12) !== "vide") {
      return { error: "the clip's track is not pictures: one picture track and no sound" };
    }
    const mdhd = child(inMdia, "mdhd");
    const media = mdhd ? lengthOf(bytes, view, mdhd, 12) : null;
    const minf = child(inMdia, "minf");
    const stbl = minf && child(boxes(bytes, view, minf.start, minf.end), "stbl");
    if (!stbl) return { error: "the clip has no pictures in it" };
    const inStbl = boxes(bytes, view, stbl.start, stbl.end);
    const stsd = child(inStbl, "stsd");
    if (!stsd || stsd.end - stsd.start < 8 + 8 + 28) return { error: "the clip does not say how its pictures are written" };
    const entry = stsd.start + 8;
    const format = ascii(bytes, entry + 4, entry + 8);
    if (format !== "avc1") return { error: `the clip's pictures are ${format.trim() || "unnamed"}, not H.264 (avc1)` };
    // The sample entry's own width and height, where the track's header
    // has none: 8 (its box) + 6 + 2 + 16 bytes in.
    let width = view.getUint16(entry + 32);
    let height = view.getUint16(entry + 34);
    if (tkhd) {
      const v = bytes[tkhd.start];
      const at = tkhd.start + 4 + (v === 1 ? 32 : 20) + 16 + 36;
      if (at + 8 > tkhd.end) return { error: "the clip is cut short" };
      const w = Math.round(view.getUint32(at) / 65536);
      const h = Math.round(view.getUint32(at + 4) / 65536);
      if (w > 0 && h > 0) { width = w; height = h; }
    }
    const stsz = child(inStbl, "stsz");
    if (!stsz || stsz.end - stsz.start < 12) return { error: "the clip does not count its pictures" };
    const frames = view.getUint32(stsz.start + 8);
    // The longer of what the movie and its track say: a short movie
    // header over a long track is still a long clip.
    const ms = Math.max(movie ?? 0, media ?? 0);
    return { kind: "mp4", codec: "avc1", width, height, ms, frames };
  } catch (trouble) {
    if (trouble instanceof Short) return { error: "the clip is cut short" };
    throw trouble;
  }
}

/// A full box's length in milliseconds (mvhd, mdhd): its timescale and
/// duration, after its version and flags, its creation and change times.
function lengthOf(bytes, view, box, need) {
  const v = bytes[box.start];
  const at = box.start + 4;
  if (v === 1) {
    if (box.end - at < 28) throw new Short();
    const scale = view.getUint32(at + 16);
    const duration = Number(view.getBigUint64(at + 20));
    return scale ? Math.round((duration * 1000) / scale) : null;
  }
  if (box.end - at < need + 4) throw new Short();
  const scale = view.getUint32(at + 8);
  const duration = view.getUint32(at + 12);
  return scale ? Math.round((duration * 1000) / scale) : null;
}

// ---------------------------------------------------------------------------
// WebM (Matroska's EBML): elements, each an ID and a size, both written
// with their own length in their first byte.

const UNKNOWN = -1;
const IDS = {
  EBML: 0x1a45dfa3, DocType: 0x4282, Segment: 0x18538067, Info: 0x1549a966, TimestampScale: 0x2ad7b1,
  Duration: 0x4489, Tracks: 0x1654ae6b, TrackEntry: 0xae, TrackType: 0x83, CodecID: 0x86, Video: 0xe0,
  PixelWidth: 0xb0, PixelHeight: 0xba, Cluster: 0x1f43b675, SimpleBlock: 0xa3, BlockGroup: 0xa0, Block: 0xa1,
};
// What a Segment holds: an element of one of these ends a Cluster whose
// size is not known (MediaRecorder's, a live stream's).
const SEGMENT_CHILDREN = new Set([0x114d9b74, IDS.Info, IDS.Tracks, IDS.Cluster, 0x1c53bb6b, 0x1941a469,
  0x1043a770, 0x1254c367]);
const WEBM_CODECS = { V_VP9: "vp9", V_VP8: "vp8" };

/// The element at [at]: {id, start (of its content), end}, end UNKNOWN
/// where its size says it is not known.
function element(bytes, view, at, to) {
  if (at >= to) throw new Short();
  const first = bytes[at];
  const idLength = first >= 0x80 ? 1 : first >= 0x40 ? 2 : first >= 0x20 ? 3 : first >= 0x10 ? 4 : 0;
  if (!idLength) throw new Short();
  if (at + idLength > to) throw new Short();
  let id = 0;
  for (let k = 0; k < idLength; k++) id = id * 256 + bytes[at + k];
  const s = at + idLength;
  if (s >= to) throw new Short();
  const lead = bytes[s];
  let sizeLength = 0;
  for (let k = 0; k < 8; k++) if (lead & (0x80 >> k)) { sizeLength = k + 1; break; }
  if (!sizeLength || s + sizeLength > to) throw new Short();
  let size = lead & (0xff >> sizeLength);
  let allOnes = size === (0xff >> sizeLength);
  for (let k = 1; k < sizeLength; k++) {
    size = size * 256 + bytes[s + k];
    if (bytes[s + k] !== 0xff) allOnes = false;
  }
  const start = s + sizeLength;
  if (allOnes) return { id, start, end: UNKNOWN };
  if (start + size > to) throw new Short();
  return { id, start, end: start + size };
}

function uintOf(bytes, from, to) {
  if (to - from > 8) throw new Short();
  let value = 0;
  for (let k = from; k < to; k++) value = value * 256 + bytes[k];
  return value;
}

function floatOf(view, from, to) {
  if (to - from === 4) return view.getFloat32(from);
  if (to - from === 8) return view.getFloat64(from);
  return NaN;
}

/// Each child of a master element from [from] to [to], to [each]: a child
/// of unknown size runs to [to]. An element of a Segment met inside a
/// Cluster of unknown size ends that Cluster, as a live stream writes it;
/// [each] returns where the next child starts.
function children(bytes, view, from, to, each) {
  let at = from;
  while (at < to) {
    const one = element(bytes, view, at, to);
    at = each(one) ?? (one.end === UNKNOWN ? to : one.end);
  }
}

function readWebm(bytes, view) {
  try {
    const head = element(bytes, view, 0, bytes.length);
    if (head.end === UNKNOWN) return { error: "the clip is not an MP4 or a WebM" };
    let docType = "";
    children(bytes, view, head.start, head.end, (one) => {
      if (one.id === IDS.DocType) docType = ascii(bytes, one.start, one.end).replace(/\0+$/, "");
    });
    if (docType !== "webm") return { error: `the clip is a ${docType || "Matroska"} file, not a WebM` };
    const segment = element(bytes, view, head.end, bytes.length);
    if (segment.id !== IDS.Segment) return { error: "the clip has no pictures in it" };
    const segmentEnd = segment.end === UNKNOWN ? bytes.length : segment.end;
    let scale = 1000000;
    let duration = NaN;
    const tracks = [];
    let frames = 0;
    children(bytes, view, segment.start, segmentEnd, (one) => {
      const end = one.end === UNKNOWN ? segmentEnd : one.end;
      if (one.id === IDS.Info) {
        children(bytes, view, one.start, end, (field) => {
          if (field.id === IDS.TimestampScale) scale = uintOf(bytes, field.start, field.end);
          if (field.id === IDS.Duration) duration = floatOf(view, field.start, field.end);
        });
      } else if (one.id === IDS.Tracks) {
        children(bytes, view, one.start, end, (entry) => {
          if (entry.id !== IDS.TrackEntry) return undefined;
          const track = { type: 0, codec: "", width: 0, height: 0 };
          children(bytes, view, entry.start, entry.end === UNKNOWN ? end : entry.end, (field) => {
            if (field.id === IDS.TrackType) track.type = uintOf(bytes, field.start, field.end);
            if (field.id === IDS.CodecID) track.codec = ascii(bytes, field.start, field.end).replace(/\0+$/, "");
            if (field.id === IDS.Video) {
              children(bytes, view, field.start, field.end === UNKNOWN ? end : field.end, (side) => {
                if (side.id === IDS.PixelWidth) track.width = uintOf(bytes, side.start, side.end);
                if (side.id === IDS.PixelHeight) track.height = uintOf(bytes, side.start, side.end);
              });
            }
          });
          tracks.push(track);
          return undefined;
        });
      } else if (one.id === IDS.Cluster) {
        // A Cluster of unknown size ends where the next of the Segment's
        // own elements begins.
        let at = one.start;
        while (at < end) {
          const inner = element(bytes, view, at, end);
          if (one.end === UNKNOWN && SEGMENT_CHILDREN.has(inner.id)) return at;
          if (inner.id === IDS.SimpleBlock) frames += 1;
          if (inner.id === IDS.BlockGroup) {
            children(bytes, view, inner.start, inner.end === UNKNOWN ? end : inner.end, (part) => {
              if (part.id === IDS.Block) frames += 1;
            });
          }
          at = inner.end === UNKNOWN ? end : inner.end;
        }
        return end;
      }
      return undefined;
    });
    if (tracks.length === 0) return { error: "the clip has no pictures in it" };
    if (tracks.length > 1) return { error: "the clip carries more than its pictures: one picture track and no sound" };
    const [track] = tracks;
    if (track.type !== 1) return { error: "the clip's track is not pictures: one picture track and no sound" };
    const codec = WEBM_CODECS[track.codec];
    if (!codec) return { error: `the clip's pictures are ${track.codec || "unnamed"}, not VP9 or VP8` };
    if (!Number.isFinite(duration) || duration <= 0) return { error: "the clip says no length" };
    const ms = Math.round((duration * scale) / 1e6);
    return { kind: "webm", codec, width: track.width, height: track.height, ms, frames };
  } catch (trouble) {
    if (trouble instanceof Short) return { error: "the clip is cut short" };
    throw trouble;
  }
}
