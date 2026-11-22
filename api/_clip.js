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
// the file itself, not from what the sender said. Its length is the
// longest of what its headers say and when its pictures are: every
// picture's own time (an MP4's stts and ctts, a WebM's blocks), which a
// player plays by whatever the headers say (ttreview F4: a 60 s file with
// its headers rewritten to 4 s, and a fragmented MP4, whose moov tells of
// its first fragment alone, were kept). Nothing in it throws: whatever
// cannot be read is an { error } in words.

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
  // A fragmented MP4's moov tells of its first fragment alone; the rest
  // follow in moof boxes a player plays on to the end.
  if (top.some((box) => box.type === "moof" || box.type === "mfra")) return { error: FRAGMENTS };
  const moov = child(top, "moov");
  if (!moov) return { error: "the clip has no description of its pictures (moov)" };
  if (!child(top, "mdat")) return { error: "the clip has no pictures in it" };
  try {
    const inMoov = boxes(bytes, view, moov.start, moov.end);
    if (child(inMoov, "mvex")) return { error: FRAGMENTS };
    const traks = inMoov.filter((box) => box.type === "trak");
    if (traks.length === 0) return { error: "the clip has no pictures in it" };
    if (traks.length > 1) return { error: "the clip carries more than its pictures: one picture track and no sound" };
    const mvhd = child(inMoov, "mvhd");
    const movie = mvhd ? timing(bytes, view, mvhd, 12) : null;
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
    const media = mdhd ? timing(bytes, view, mdhd, 12) : null;
    // Each picture's time is in the track's own ticks: none, no length.
    if (!media || !media.scale) return { error: "the clip says no length" };
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
    // Each picture's size, where they differ, written out: a count the
    // table cannot hold is a count made up.
    if (view.getUint32(stsz.start + 4) === 0 && stsz.end - stsz.start - 12 < frames * 4) throw new Short();
    // When each picture is shown: its decode time (stts) and how far after
    // it (ctts), from the first shown to the end of the last.
    const stts = child(inStbl, "stts");
    if (!stts) return { error: "the clip does not say when its pictures are" };
    const times = runs(view, stts, false);
    const ctts = child(inStbl, "ctts");
    const shifts = ctts ? runs(view, ctts, bytes[ctts.start] === 1) : [];
    const shown = span(times, shifts, frames);
    if (shown === null) return { error: "the clip's pictures and their times do not agree" };
    const ms = (ticks, scale) => (scale ? Math.round((ticks * 1000) / scale) : 0);
    // And what its headers say: the movie's, the track's, its edits' (in
    // the movie's ticks), the media's. A player goes by any of them.
    const said = [ms(shown, media.scale), ms(media.duration, media.scale)];
    if (movie) said.push(ms(movie.duration, movie.scale));
    if (movie && tkhd) said.push(ms(trackLength(bytes, view, tkhd), movie.scale));
    const edts = child(inTrak, "edts");
    const elst = edts && child(boxes(bytes, view, edts.start, edts.end), "elst");
    if (movie && elst) said.push(ms(editsLength(bytes, view, elst), movie.scale));
    return { kind: "mp4", codec: "avc1", width, height, ms: Math.max(...said), frames };
  } catch (trouble) {
    if (trouble instanceof Short) return { error: "the clip is cut short" };
    throw trouble;
  }
}

const FRAGMENTS = "the clip is in fragments: one moov that describes every picture";

/// A full box's timescale and duration (mvhd, mdhd), after its version and
/// flags, its creation and change times: {scale, duration}.
function timing(bytes, view, box, need) {
  const v = bytes[box.start];
  const at = box.start + 4;
  if (v === 1) {
    if (box.end - at < 28) throw new Short();
    return { scale: view.getUint32(at + 16), duration: Number(view.getBigUint64(at + 20)) };
  }
  if (box.end - at < need + 4) throw new Short();
  return { scale: view.getUint32(at + 8), duration: view.getUint32(at + 12) };
}

/// tkhd's duration, in the movie's ticks: after its version and flags,
/// creation and change times, track ID and a reserved word.
function trackLength(bytes, view, tkhd) {
  const v = bytes[tkhd.start];
  const at = tkhd.start + 4 + (v === 1 ? 24 : 16);
  if (at + (v === 1 ? 8 : 4) > tkhd.end) throw new Short();
  return v === 1 ? Number(view.getBigUint64(at)) : view.getUint32(at);
}

/// The sum of an edit list's segments (elst), in the movie's ticks.
function editsLength(bytes, view, elst) {
  const v = bytes[elst.start];
  const count = view.getUint32(elst.start + 4);
  const size = v === 1 ? 20 : 12;
  if (elst.end - elst.start - 8 < count * size) throw new Short();
  let total = 0;
  for (let k = 0, at = elst.start + 8; k < count; k++, at += size) {
    total += v === 1 ? Number(view.getBigUint64(at)) : view.getUint32(at);
  }
  return total;
}

/// A table of runs (stts: count and each one's ticks; ctts: count and each
/// one's offset, [signed] in its version 1): [[count, value], ...].
function runs(view, box, signed) {
  if (box.end - box.start < 8) throw new Short();
  const count = view.getUint32(box.start + 4);
  if (box.end - box.start - 8 < count * 8) throw new Short();
  const out = new Array(count);
  for (let k = 0, at = box.start + 8; k < count; k++, at += 8) {
    out[k] = [view.getUint32(at), signed ? view.getInt32(at + 4) : view.getUint32(at + 4)];
  }
  return out;
}

/// From the first picture shown to the end of the last, in ticks, with
/// [times] (stts) and [shifts] (ctts, or none) walked together run by run;
/// null where they count other than the [frames] stsz counts.
function span(times, shifts, frames) {
  let counted = 0;
  for (const [count] of times) counted += count;
  if (counted !== frames || frames === 0) return null;
  let first = Infinity;
  let last = -Infinity;
  let at = 0;
  let t = 0;
  let tLeft = times[0][0];
  let s = 0;
  let sLeft = shifts.length ? shifts[0][0] : Infinity;
  for (let left = frames; left > 0;) {
    while (tLeft === 0) tLeft = times[++t][0];
    while (sLeft === 0) sLeft = ++s < shifts.length ? shifts[s][0] : Infinity;
    const k = Math.min(tLeft, sLeft, left);
    const tick = times[t][1];
    const shift = s < shifts.length ? shifts[s][1] : 0;
    first = Math.min(first, at + shift);
    last = Math.max(last, at + k * tick + shift);
    at += k * tick;
    tLeft -= k;
    sLeft -= k;
    left -= k;
  }
  return last - first;
}

// ---------------------------------------------------------------------------
// WebM (Matroska's EBML): elements, each an ID and a size, both written
// with their own length in their first byte.

const UNKNOWN = -1;
const IDS = {
  EBML: 0x1a45dfa3, DocType: 0x4282, Segment: 0x18538067, Info: 0x1549a966, TimestampScale: 0x2ad7b1,
  Duration: 0x4489, Tracks: 0x1654ae6b, TrackEntry: 0xae, TrackType: 0x83, CodecID: 0x86, Video: 0xe0,
  PixelWidth: 0xb0, PixelHeight: 0xba, Cluster: 0x1f43b675, SimpleBlock: 0xa3, BlockGroup: 0xa0, Block: 0xa1,
  Timestamp: 0xe7, BlockDuration: 0x9b, DefaultDuration: 0x23e383,
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
    // When each picture is, in the Segment's ticks: its Cluster's
    // Timestamp and its block's own offset from it, the first and the end
    // of the last (with its BlockDuration where it says one).
    const when = { first: Infinity, last: -Infinity, longest: 0 };
    let laced = false;
    let missing = false;
    /// A block's picture at [start] (its content: track number, offset,
    /// flags) in a Cluster at [cluster], lasting [lasts] ticks where said.
    const block = (start, end, cluster, lasts = 0) => {
      if (cluster === null) { missing = true; return; }
      const lead = bytes[start];
      const n = lead >= 0x80 ? 1 : lead >= 0x40 ? 2 : lead >= 0x20 ? 3 : lead >= 0x10 ? 4 : 0;
      if (!n || start + n + 3 > end) throw new Short();
      const t = cluster + view.getInt16(start + n);
      // Several pictures packed in one block share its time: nothing a
      // player turns into a length here.
      if (bytes[start + n + 2] & 0x06) laced = true;
      when.first = Math.min(when.first, t);
      when.last = Math.max(when.last, t + lasts);
      when.longest = Math.max(when.longest, lasts);
      frames += 1;
    };
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
          const track = { type: 0, codec: "", width: 0, height: 0, each: 0 };
          children(bytes, view, entry.start, entry.end === UNKNOWN ? end : entry.end, (field) => {
            if (field.id === IDS.TrackType) track.type = uintOf(bytes, field.start, field.end);
            if (field.id === IDS.CodecID) track.codec = ascii(bytes, field.start, field.end).replace(/\0+$/, "");
            if (field.id === IDS.DefaultDuration) track.each = uintOf(bytes, field.start, field.end);
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
        let cluster = null;
        while (at < end) {
          const inner = element(bytes, view, at, end);
          if (one.end === UNKNOWN && SEGMENT_CHILDREN.has(inner.id)) return at;
          const innerEnd = inner.end === UNKNOWN ? end : inner.end;
          if (inner.id === IDS.Timestamp) cluster = uintOf(bytes, inner.start, innerEnd);
          if (inner.id === IDS.SimpleBlock) block(inner.start, innerEnd, cluster);
          if (inner.id === IDS.BlockGroup) {
            let found = null;
            let lasts = 0;
            children(bytes, view, inner.start, innerEnd, (part) => {
              if (part.id === IDS.Block) found = part;
              if (part.id === IDS.BlockDuration) lasts = uintOf(bytes, part.start, part.end);
            });
            if (found) block(found.start, found.end === UNKNOWN ? innerEnd : found.end, cluster, lasts);
          }
          at = innerEnd;
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
    if (missing) return { error: "the clip does not say when its pictures are" };
    if (laced) return { error: "the clip packs several pictures in a block: one picture a block" };
    // From its first picture to the end of its last: the last lasts as its
    // track says each does, or as its block says, or as long as the
    // pictures before it did on average.
    let shown = 0;
    if (frames > 0) {
      const ticks = when.last - when.first;
      const each = track.each ? track.each / scale : when.longest || (frames > 1 ? ticks / (frames - 1) : 0);
      shown = Math.round(((ticks + each) * scale) / 1e6);
    }
    const ms = Math.max(Math.round((duration * scale) / 1e6), shown);
    return { kind: "webm", codec, width: track.width, height: track.height, ms, frames };
  } catch (trouble) {
    if (trouble instanceof Short) return { error: "the clip is cut short" };
    throw trouble;
  }
}
