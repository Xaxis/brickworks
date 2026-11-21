// BrickLink Studio's model file (.io), read in the browser (bringyours,
// 2026-11-20): what /share-model (web/share-model.js) shares from one, with
// no app in between. The app reads the same file its own way
// (src/parts/studio_io.gd StudioIo); this is the first half of that, the
// model out of the zip, and none of the second (Studio's printed faces,
// StudioDecor), which only the app draws.
//
// An .io is a zip. model.ldr in it is the model in plain LDraw, LDraw's
// colours and part numbers, sub-models as 0 FILE sections and the builder's
// own 0 STEP lines; model2.ldr is the same in BrickLink's numbers (white is
// 1 there), so it is never the one read. Studio locked the zip with one
// password in every file until about 2.25 (PKWARE's old cipher, and in some
// early-access files WinZip's AES); later files are not locked. Parts made
// in Studio's Part Designer are in CustomParts/: each the model names comes
// with it as a part the file carries (0 FILE <name>.dat), its faces kept and
// Studio's picture coordinates on them left off, as LDraw has no place for
// them in a face's line; the site's parts list counts such a part as a made
// one (api/_parts.js), as it does any part a file carries.
//
// Nothing here says words: each trouble is a key (TROUBLE), which the page
// says in its language.
//
//   readStudioIo(bytes) -> {text, carried, prints, error}
//     text      the LDraw text, "" when there is none
//     carried   how many Part Designer parts came with it
//     prints    how many of Studio's own prints and stickers it names
//               (bl_…), which come as the plain part where LDraw has one
//     error     "" or one of TROUBLE

/// Every Studio file's password, published by everyone who has read one.
const PASSWORD = "soho0909";

/// What can be wrong with a file, as keys.
export const TROUBLE = Object.freeze({
  NOT_ZIP: "not-zip",
  DAMAGED: "damaged",
  NO_MODEL: "no-model",
  LOCKED: "locked",
  AES192: "aes-192",
  BROWSER: "browser",
});

const SIGNATURE = { end: 0x06054b50, central: 0x02014b50, local: 0x04034b50 };

/// The model inside [bytes] (an ArrayBuffer or a Uint8Array), as above.
export async function readStudioIo(bytes) {
  const data = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const none = (error) => ({ text: "", carried: 0, prints: 0, error });
  const entries = entriesOf(data);
  if (typeof entries === "string") return none(entries);
  const model = entries.get("model.ldr");
  if (!model) return none(TROUBLE.NO_MODEL);
  const unpacked = await unpack(data, model);
  if (typeof unpacked === "string") return none(unpacked);
  let text = textOf(unpacked);
  const named = namedParts(text);
  // Part Designer's parts, by the name a part line gives them: Studio keeps
  // them as LDraw's library keeps its own (CustomParts/parts/x.dat named
  // x.dat, parts/s/y.dat named s/y.dat, p/z.dat named z.dat).
  const custom = new Map();
  for (const [name, entry] of entries) {
    if (!name.startsWith("customparts/") || !name.endsWith(".dat")) continue;
    custom.set(name.slice("customparts/".length).replace(/^(?:parts|p)\//, ""), entry);
  }
  // Each the model names and does not carry, and each those name in turn.
  let carried = 0;
  const wanted = [...named].filter((one) => custom.has(one));
  const done = new Set();
  while (wanted.length) {
    const file = wanted.shift();
    if (done.has(file) || carriedAlready(text, file)) continue;
    done.add(file);
    const part = await unpack(data, custom.get(file));
    if (typeof part === "string") continue;
    const lines = plainLines(textOf(part));
    text = `${text.replace(/\s*$/, "")}\r\n0 NOFILE\r\n0 FILE ${originalName(custom.get(file), file)}\r\n${lines}\r\n`;
    carried += 1;
    for (const one of namedParts(lines)) if (custom.has(one) && !done.has(one)) wanted.push(one);
  }
  const prints = [...named].filter((one) => one.startsWith("bl_")).length;
  return { text, carried, prints, error: "" };
}

/// The zip's members by their lower-case path: where each starts and how it
/// is packed, from the central directory at the end, which states every size
/// even when a member's own header leaves them until after its data. A
/// TROUBLE key for anything that is not such a zip.
function entriesOf(data) {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const u16 = (at) => view.getUint16(at, true);
  const u32 = (at) => view.getUint32(at, true);
  let end = -1;
  for (let at = data.length - 22; at >= Math.max(0, data.length - 22 - 65535); at -= 1) {
    if (u32(at) === SIGNATURE.end) { end = at; break; }
  }
  if (end < 0) return TROUBLE.NOT_ZIP;
  const count = u16(end + 10);
  let at = u32(end + 16);
  const out = new Map();
  const utf8 = new TextDecoder("utf-8");
  for (let k = 0; k < count; k += 1) {
    if (at + 46 > data.length || u32(at) !== SIGNATURE.central) return TROUBLE.DAMAGED;
    const flags = u16(at + 8);
    const method = u16(at + 10);
    const time = u16(at + 12);
    const crc = u32(at + 16);
    const packed = u32(at + 20);
    const size = u32(at + 24);
    const nameLength = u16(at + 28);
    const extraLength = u16(at + 30);
    const commentLength = u16(at + 32);
    const local = u32(at + 42);
    const name = utf8.decode(data.subarray(at + 46, at + 46 + nameLength)).replace(/\\/g, "/");
    const aes = aesField(view, at + 46 + nameLength, extraLength);
    at += 46 + nameLength + extraLength + commentLength;
    if (local + 30 > data.length || u32(local) !== SIGNATURE.local) return TROUBLE.DAMAGED;
    const start = local + 30 + u16(local + 26) + u16(local + 28);
    if (start + packed > data.length) return TROUBLE.DAMAGED;
    if (name.endsWith("/")) continue;
    // What the cipher's twelfth byte must be: the CRC's top byte, or the
    // time's when the sizes and CRC follow the data.
    const check = flags & 0x08 ? (time >> 8) & 0xff : (crc >>> 24) & 0xff;
    out.set(name.toLowerCase(), { name, start, packed, size, method, crc, encrypted: Boolean(flags & 1), check, aes });
  }
  return out.size ? out : TROUBLE.NOT_ZIP;
}

/// WinZip's AES field (0x9901) of a member's extra data: {version, strength
/// (1, 2 or 3: AES-128, 192, 256), method under the cipher}, or null.
function aesField(view, from, length) {
  let at = from;
  while (at + 4 <= from + length) {
    const id = view.getUint16(at, true);
    const size = view.getUint16(at + 2, true);
    if (id === 0x9901 && size >= 7 && at + 4 + size <= from + length) {
      return { version: view.getUint16(at + 4, true), strength: view.getUint8(at + 8), method: view.getUint16(at + 9, true) };
    }
    at += 4 + size;
  }
  return null;
}

/// A member's bytes, unlocked and inflated, or a TROUBLE key.
async function unpack(data, entry) {
  let raw = data.subarray(entry.start, entry.start + entry.packed);
  let method = entry.method;
  // AE-2 states no CRC: what vouches for the data is the cipher's own check.
  let checked = true;
  if (entry.aes) {
    if (entry.aes.strength !== 1 && entry.aes.strength !== 3) return TROUBLE.AES192;
    const plain = await openAes(raw, entry.aes.strength).catch(() => TROUBLE.BROWSER);
    if (typeof plain === "string") return plain;
    if (!plain) return TROUBLE.LOCKED;
    raw = plain;
    method = entry.aes.method;
    checked = entry.aes.version === 1;
  } else if (entry.encrypted) {
    const plain = openPkware(raw);
    // A wrong password is known before anything is inflated.
    if (plain.length < 12 || plain[11] !== entry.check) return TROUBLE.LOCKED;
    raw = plain.subarray(12);
  }
  let out;
  if (method === 0) out = raw;
  else if (method === 8) {
    out = await inflate(raw).catch((trouble) => (trouble instanceof TypeError ? TROUBLE.BROWSER : TROUBLE.DAMAGED));
    if (typeof out === "string") return out;
  } else return TROUBLE.DAMAGED;
  if (out.length !== entry.size) return TROUBLE.DAMAGED;
  if (checked && crc32(out) !== entry.crc) return TROUBLE.DAMAGED;
  return out;
}

/// Raw deflate, inflated by the browser. A browser without "deflate-raw"
/// throws a TypeError as the stream is made.
async function inflate(raw) {
  const stream = new Blob([raw]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

let crcTable = null;

function crcByte(crc, byte) {
  if (!crcTable) {
    crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n += 1) {
      let value = n;
      for (let k = 0; k < 8; k += 1) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
      crcTable[n] = value >>> 0;
    }
  }
  return (crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8)) >>> 0;
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (let k = 0; k < bytes.length; k += 1) crc = crcByte(crc, bytes[k]);
  return (crc ^ 0xffffffff) >>> 0;
}

/// PKWARE's traditional encryption, undone with Studio's password.
function openPkware(data) {
  const keys = new Uint32Array([305419896, 591751049, 878082192]);
  const update = (c) => {
    keys[0] = crcByte(keys[0], c);
    keys[1] = (Math.imul((keys[1] + (keys[0] & 0xff)) >>> 0, 134775813) + 1) >>> 0;
    keys[2] = crcByte(keys[2], keys[1] >>> 24);
  };
  for (const c of new TextEncoder().encode(PASSWORD)) update(c);
  const out = new Uint8Array(data.length);
  for (let n = 0; n < data.length; n += 1) {
    const temp = (keys[2] | 2) & 0xffff;
    const plain = data[n] ^ ((Math.imul(temp, temp ^ 1) >>> 8) & 0xff);
    out[n] = plain;
    update(plain);
  }
  return out;
}

/// WinZip's AES, undone: the salt, two bytes that say whether the password
/// is right, the data in AES-CTR with a little-endian counter from 1, and
/// ten bytes of HMAC-SHA1 over it, which are checked. The keys and the two
/// bytes are PBKDF2-HMAC-SHA1 of the password, 1,000 rounds. Null for a
/// wrong password or a seal that does not hold. The browser's AES-CTR counts
/// big-endian, so each block's counter is enciphered on its own.
async function openAes(data, strength) {
  const subtle = globalThis.crypto?.subtle;
  if (!subtle) throw new Error("no WebCrypto");
  const length = strength === 1 ? 16 : 32;
  const saltLength = length / 2;
  if (data.length < saltLength + 2 + 10) return null;
  const salt = data.slice(0, saltLength);
  const base = await subtle.importKey("raw", new TextEncoder().encode(PASSWORD), "PBKDF2", false, ["deriveBits"]);
  const made = new Uint8Array(await subtle.deriveBits({ name: "PBKDF2", salt, iterations: 1000, hash: "SHA-1" },
    base, (2 * length + 2) * 8));
  if (made[2 * length] !== data[saltLength] || made[2 * length + 1] !== data[saltLength + 1]) return null;
  const locked = data.slice(saltLength + 2, data.length - 10);
  const sealKey = await subtle.importKey("raw", made.slice(length, 2 * length), { name: "HMAC", hash: "SHA-1" }, false, ["sign"]);
  const seal = new Uint8Array(await subtle.sign("HMAC", sealKey, locked));
  const tail = data.subarray(data.length - 10);
  for (let k = 0; k < 10; k += 1) if (seal[k] !== tail[k]) return null;
  const key = await subtle.importKey("raw", made.slice(0, length), "AES-CTR", false, ["encrypt"]);
  const blocks = Math.ceil(locked.length / 16);
  const plain = new Uint8Array(locked.length);
  const zero = new Uint8Array(16);
  const BATCH = 2048;
  for (let first = 0; first < blocks; first += BATCH) {
    const last = Math.min(blocks, first + BATCH);
    const streams = [];
    for (let n = first; n < last; n += 1) {
      const counter = new Uint8Array(16);
      let value = n + 1;
      for (let k = 0; k < 8 && value > 0; k += 1) { counter[k] = value % 256; value = Math.floor(value / 256); }
      streams.push(subtle.encrypt({ name: "AES-CTR", counter, length: 64 }, key, zero));
    }
    const made = await Promise.all(streams);
    made.forEach((one, k) => {
      const stream = new Uint8Array(one);
      const at = (first + k) * 16;
      for (let b = 0; b < 16 && at + b < locked.length; b += 1) plain[at + b] = locked[at + b] ^ stream[b];
    });
  }
  return plain;
}

/// A member's bytes as text: Studio starts its text with a byte-order mark.
function textOf(bytes) {
  const start = bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf ? 3 : 0;
  return new TextDecoder("utf-8").decode(bytes.subarray(start));
}

/// Every file name the model's part lines name, in lower case, as LDraw
/// compares them.
function namedParts(text) {
  const names = new Set();
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line.startsWith("1")) continue;
    const name = afterFields(line, 14);
    if (name) names.add(name.toLowerCase().replace(/\\/g, "/"));
  }
  return names;
}

/// What follows the first [n] fields of [line]: a file name may have spaces.
function afterFields(line, n) {
  const match = line.match(new RegExp(`^(?:\\S+\\s+){${n}}(.*)$`));
  return match ? match[1].trim() : "";
}

/// Whether [text] already has a section for [file].
function carriedAlready(text, file) {
  return text.split(/\r?\n/).some((raw) => /^0\s+FILE\s/i.test(raw.trim())
    && afterFields(raw.trim(), 2).toLowerCase() === file);
}

/// The part's own name as the zip spells it.
function originalName(entry, file) {
  const own = entry.name.replace(/^customparts\/(?:parts\/|p\/)?/i, "");
  return own && own.toLowerCase() === file ? own : file;
}

/// LDraw's lines of a Part Designer part: Studio's picture lines (0 PE_TEX_…)
/// left out, and a face's picture coordinates after its points left off,
/// which LDraw's line has no place for.
function plainLines(text) {
  const keep = { 2: 8, 3: 11, 4: 14, 5: 14 };
  const out = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    if (/^0\s+PE_TEX_/i.test(line)) continue;
    const tokens = line.split(/\s+/);
    const fields = keep[tokens[0]];
    out.push(fields && tokens.length > fields ? tokens.slice(0, fields).join(" ") : line);
  }
  return out.join("\r\n");
}
