// Your own moulds on your account (sitehair, 2026-11-25; supabase/own_moulds.sql).
//
// A mould made in the studio's minifig builder (src/minifig/mould.gd) is a
// plain LDraw part file: its triangles, its base part's connectors as
// comments, its creases as edge lines, and `0 // Moulded by Brickworks:
// from=<base>`. Its id is the app's own, bw-<base>-m-<20 hex digits of the
// SHA-256 of its text without the id> (CustomParts.named), so one text is one
// id. Saved by somebody signed in, the app sends it here (POST
// /api/people?op=mould), and Edit profile's minifig maker lists it beside
// the catalogue's hair and wears it (web/minifig-maker.js).
//
// What is sent is held at this edge before anything is kept (mouldOf): a
// text of the lines a mould has and nothing else (no part it draws on, no
// section of another file), every number a finite one within reach of a
// figure, at most Mould.MOST_OPENED triangles and MOST_BYTES, its id the
// digest of its own text and the part it names. Refused in words, never
// cut or mended: a person whose mould is refused is told why, and each
// refusal has a code (MouldRefusal.code) the studio says in its own words,
// in the person's language.
//
// A mould shaped further from one of the person's own (hairfix): the studio
// sends the one it was shaped from as `replaces`, and that one is taken off
// the account as this one is kept, unless the avatar wears it. So a person
// who reworks their hair has one mould on the account, not one a version.
// POST ?op=mould_remove takes one off; one the avatar wears leaves the
// avatar wearing the part it was shaped from (removeMould).
//
// Who reads one (mouldText): its owner, and nobody else (hairreview M1). An
// avatar is the picture the maker drew, never the mould, so no page view
// reads one; the owner's maker reads each text once a browser (an id is its
// text, kept for good), counted against a limit.

import { createHash } from "node:crypto";
import { db } from "./_db.js";
import { HAIR, OWN_MOULD } from "./_minifig_parts.js";

export const MOST_BYTES = 2 * 1024 * 1024;
export const MOST_TRIANGLES = 18000;
export const MOST_EDGES = 60000;
export const MOST_MOULDS = 40;
export const MOST_KEPT = 24 * 1024 * 1024;
// The most characters (code points, as the table's char_length counts) a
// mould's list name keeps: cut at a whole character the eye sees.
export const MOST_NAME = 120;
// How far from the part's origin a corner may be, in LDU: a minifigure is
// about 100 tall, so a mould twice its size is still let through.
export const REACH = 400;
export const NOT_YET = "Moulds on your account are not open on Brickworks yet: your mould is kept in the studio.";
// Where a person takes one off, for the refusal that says the account is full.
export const WHERE_REMOVED = "Edit profile › Make a minifig › Hair and hats";
// The slots a mould is made for (src/minifig/minifig.gd Minifig.SLOTS).
export const SLOTS = ["headwear", "hat_extra", "head", "neck", "back", "cape", "torso", "arms", "hands", "hips", "hipwear",
  "legs", "footwear", "accessory", "accessory_left"];
// The ones a minifigure's hair is: what Edit profile's maker lists under
// Hair and hats.
export const HAIR_SLOTS = ["headwear"];
const MOULDED_BY = "0 // Moulded by Brickworks:";
const BASE = /^[0-9A-Za-z._-]{1,64}$/;
const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
const COLOUR = /^\d{1,9}$/;
const NOT_THERE = /: 404$/;
// The table's own cap (own_moulds_cap), as it words its refusal.
const CAP_SAID = /^own_moulds: at most/;
const notThere = (trouble) => NOT_THERE.test(String(trouble?.message || ""));
const graphemes = new Intl.Segmenter("en", { granularity: "grapheme" });

/// A refusal the studio and the maker show: [message] in words, [status]
/// the HTTP one, [code] what kind, for the studio to say in its own words:
///   name     the id is not a mould's          slot     no minifigure's slot
///   text     no text, or a broken character   shape    a line no mould has
///   big      over 2 MB, or too many triangles room     the account is full
///   gone     no such mould on the account     not_yet  not open yet
export class MouldRefusal extends Error {
  constructor(message, status = 400, code = "shape") {
    super(message);
    this.status = status;
    this.code = code;
  }
}

/// [text] cut to at most [most] code points, at a whole grapheme: an emoji,
/// a flag or a letter and its accent is kept whole or left out whole.
export function cutAtGrapheme(text, most) {
  let out = "";
  let points = 0;
  for (const { segment } of graphemes.segment(text)) {
    const more = [...segment].length;
    if (points + more > most) break;
    out += segment;
    points += more;
  }
  return out;
}

/// The id a mould's text has, made as the app makes it (CustomParts.named):
/// the stem of its base, and a digest of the text with the id taken out.
export function idOf(text, id, base) {
  const without = Buffer.from(text.split(id).join(""), "utf8");
  const tag = createHash("sha256").update(`${without.length}:`).update(without).digest("hex").slice(0, 20);
  const source = [...base.toLowerCase()].filter((c) => /[a-z0-9]/.test(c)).join("").slice(0, 10);
  return `bw-${source}-m-${tag}`;
}

/// What the app sent, held to what a mould is: {id, slot, base, name,
/// triangles, bytes, text, replaces}, or a MouldRefusal saying what is
/// wrong. [replaces] is the mould of the person's own this one was shaped
/// from, or null; false, null and "" are as if it were not sent.
export function mouldOf(body) {
  const given = body && typeof body === "object" && !Array.isArray(body) ? body : {};
  const { id, slot, text } = given;
  if (typeof id !== "string" || !OWN_MOULD.test(id)) {
    throw new MouldRefusal("that is not a mould's name: bw-<part>-m-<twenty hex digits>, as the studio names one", 400, "name");
  }
  if (typeof slot !== "string" || !SLOTS.includes(slot)) {
    throw new MouldRefusal(`a mould is made for one of a minifigure's slots: ${SLOTS.join(", ")}`, 400, "slot");
  }
  const replaces = given.replaces === undefined || given.replaces === null || given.replaces === false || given.replaces === ""
    ? null : given.replaces;
  if (replaces !== null && (typeof replaces !== "string" || !OWN_MOULD.test(replaces) || replaces === id)) {
    throw new MouldRefusal("replaces is the name of the mould this one was shaped from, as the studio names one, or nothing", 400, "name");
  }
  if (typeof text !== "string" || !text) throw new MouldRefusal("send the mould's text: {id, slot, text}", 400, "text");
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > MOST_BYTES) {
    throw new MouldRefusal(`that mould is ${(bytes / 1048576).toFixed(1)} MB: at most ${MOST_BYTES / 1048576} MB, please`, 413, "big");
  }
  // Half of an emoji (a lone surrogate) is no character at all: the
  // database refuses one, so it is refused here, in words.
  if (!text.isWellFormed()) {
    throw new MouldRefusal("that mould has half of a character in it (half of an emoji): save it again in the studio", 400, "text");
  }
  if (/[\u0000-\u0008\u000b-\u001f\u007f]/.test(text)) {
    throw new MouldRefusal("that mould has a character no part file has (a carriage return or another control character)", 400, "text");
  }
  let triangles = 0;
  let edges = 0;
  let base = "";
  let named = "";
  let title = "";
  const lines = text.split("\n");
  for (let k = 0; k < lines.length; k++) {
    const words = lines[k].trim().split(/[ \t]+/).filter(Boolean);
    if (!words.length) continue;
    const kind = words[0];
    const at = `line ${k + 1}`;
    if (kind === "0") {
      const line = lines[k].trim();
      if (/^0[ \t]+(FILE|NOFILE|!DATA)\b/i.test(line)) {
        throw new MouldRefusal(`${at} starts a file of its own: a mould is one part`);
      }
      if (!title) title = line.slice(1).trim();
      if (/^0[ \t]+Name:/i.test(line)) named = line.replace(/^0[ \t]+Name:[ \t]*/i, "");
      if (line.startsWith(MOULDED_BY)) {
        if (base) throw new MouldRefusal(`${at} says a second time what the mould was shaped from`);
        base = (line.slice(MOULDED_BY.length).split(/[ \t]+/).find((word) => word.startsWith("from=")) || "").slice(5);
        if (!BASE.test(base)) throw new MouldRefusal(`${at} names no part it was shaped from: from=<a part's number>`);
      }
      continue;
    }
    const wanted = { 2: 6, 3: 9 }[kind];
    if (!wanted) {
      throw new MouldRefusal(`${at} is a line of type ${kind.slice(0, 8)}: a mould has only its triangles (3), `
        + "its edges (2) and comments (0)");
    }
    if (words.length !== 2 + wanted) {
      throw new MouldRefusal(`${at} has ${words.length - 2} numbers after its colour: a ${kind === "3" ? "triangle" : "line"} has ${wanted}`);
    }
    if (!COLOUR.test(words[1])) throw new MouldRefusal(`${at}'s colour is not a colour's number`);
    for (const word of words.slice(2)) {
      const n = Number(word);
      if (!NUMBER.test(word) || !Number.isFinite(n)) throw new MouldRefusal(`${at} has "${word.slice(0, 12)}", which is no number`);
      if (Math.abs(n) > REACH) throw new MouldRefusal(`${at} reaches ${Math.round(n)} LDU from the part: at most ${REACH}`);
    }
    if (kind === "3") triangles += 1;
    else edges += 1;
    if (triangles > MOST_TRIANGLES) throw new MouldRefusal(`that mould has more than ${MOST_TRIANGLES.toLocaleString("en")} triangles`, 413, "big");
    if (edges > MOST_EDGES) throw new MouldRefusal(`that mould has more than ${MOST_EDGES.toLocaleString("en")} edges`, 413, "big");
  }
  if (!base) throw new MouldRefusal(`that is no mould made in the studio: it has no "${MOULDED_BY} from=..." line`);
  if (!triangles) throw new MouldRefusal("that mould has no triangles");
  if (named !== `${id}.dat`) throw new MouldRefusal(`that mould calls itself ${named.slice(0, 48) || "nothing"}, not ${id}.dat`, 400, "name");
  if (idOf(text, id, base) !== id) {
    throw new MouldRefusal("that mould's name is not its own: its digits are not its text's (it was changed after it was made)", 400, "name");
  }
  // Its name, as the studio's own first line has it: "<base name>, Custom
  // Mould <title>", cut at a whole character (hairreview M2: a cut through
  // an emoji was refused by the table for good).
  const name = cutAtGrapheme(title.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim(), MOST_NAME).trim() || id;
  return { id, slot, base, name, triangles, bytes, text, replaces };
}

/// [account]'s moulds, without their text, newest first: {ready, moulds,
/// most: {moulds, bytes}} (what the account has room for, so the studio
/// can tell when a mould refused for room may go).
export async function mouldsOf(account) {
  const most = { moulds: MOST_MOULDS, bytes: MOST_KEPT };
  try {
    const moulds = await db(`own_moulds?account=eq.${account}&select=id,slot,base,name,triangles,bytes,at&order=at.desc`);
    return { ready: true, moulds, most };
  } catch (trouble) {
    if (notThere(trouble)) return { ready: false, moulds: [], most };
    throw trouble;
  }
}

/// The mould [account]'s avatar wears now, or "".
async function wornBy(account) {
  const row = (await db(`profile_avatars?account=eq.${account}&select=minifig,removed_at`))[0];
  return row && !row.removed_at && row.minifig && OWN_MOULD.test(String(row.minifig.hd || "")) ? String(row.minifig.hd) : "";
}

/// Why an account has no room: the words, with where to make room.
function noRoom(what) {
  return new MouldRefusal(`${what}: remove one in ${WHERE_REMOVED}, and the studio sends this one the next time `
    + "its figure builder opens", 409, "room");
}

/// [row] written to own_moulds, in place of the same id. The table's own
/// cap refusing it (a save at the same moment took the room) is a 409 in
/// words; anything else the table refuses is a fault of ours (500, logged
/// by the handler).
async function upsert(row) {
  try {
    await db("own_moulds?on_conflict=account,id", { method: "POST", prefer: "resolution=merge-duplicates,return=minimal", body: row });
  } catch (trouble) {
    if (CAP_SAID.test(String(trouble?.said || ""))) {
      throw noRoom(`your account has room for ${MOST_MOULDS} moulds and ${MOST_KEPT / 1048576} MB of them, and another save took the last of it`);
    }
    throw trouble;
  }
}

/// [mould] (mouldOf) kept as [account]'s, in place of the same id kept
/// before, and of the one it replaces unless the avatar wears that. [check]
/// is the caller's own refusals (the rate limit), asked once the mould is
/// in order: {kept, id, replaced (the id taken off, or null)}.
export async function keepMould(account, mould, check) {
  const { ready, moulds } = await mouldsOf(account);
  if (!ready) throw new MouldRefusal(NOT_YET, 503, "not_yet");
  const replacing = mould.replaces && moulds.some((one) => one.id === mould.replaces)
    && (await wornBy(account)) !== mould.replaces ? mould.replaces : null;
  const others = moulds.filter((one) => one.id !== mould.id && one.id !== replacing);
  if (others.length >= MOST_MOULDS) {
    throw noRoom(`your account keeps ${MOST_MOULDS} moulds, the most it has room for`);
  }
  const weight = others.reduce((sum, one) => sum + Number(one.bytes || 0), 0);
  if (weight + mould.bytes > MOST_KEPT) {
    throw noRoom(`your account keeps ${(weight / 1048576).toFixed(1)} MB of moulds, and this one would take it past `
      + `${MOST_KEPT / 1048576} MB`);
  }
  await check();
  const { replaces: _left, ...kept } = mould;
  const row = { account, ...kept, at: new Date().toISOString() };
  if (!replacing) {
    await upsert(row);
    return { kept: true, id: mould.id, replaced: null };
  }
  try {
    await upsert(row);
  } catch (trouble) {
    // Full, and the room is the one it replaces: that one off first, and
    // back as it was if this one is not kept after all.
    if (!(trouble instanceof MouldRefusal)) throw trouble;
    const old = (await db(`own_moulds?account=eq.${account}&id=eq.${replacing}&select=*`))[0];
    await db(`own_moulds?account=eq.${account}&id=eq.${replacing}`, { method: "DELETE" });
    try {
      await upsert(row);
    } catch (again) {
      if (old) await upsert(old).catch(() => {});
      throw again;
    }
    return { kept: true, id: mould.id, replaced: replacing };
  }
  await db(`own_moulds?account=eq.${account}&id=eq.${replacing}`, { method: "DELETE" });
  return { kept: true, id: mould.id, replaced: replacing };
}

/// The mould [id] taken off [account] (the studio keeps its own copy, and
/// every model that uses it keeps it). One the avatar wears: the avatar's
/// figure wears the part it was shaped from instead (no hair, for a part
/// the maker has not), so it opens whole, and its picture is the one drawn
/// before until the person saves another. {removed, id, minifig (the
/// avatar's figure as it is now, when it wore it; else null)}.
export async function removeMould(account, given) {
  const id = given && typeof given === "object" ? given.id : undefined;
  if (typeof id !== "string" || !OWN_MOULD.test(id)) {
    throw new MouldRefusal("that is not a mould's name: bw-<part>-m-<twenty hex digits>, as the studio names one", 400, "name");
  }
  let row;
  try {
    row = (await db(`own_moulds?account=eq.${account}&id=eq.${id}&select=id,base`))[0];
  } catch (trouble) {
    if (notThere(trouble)) throw new MouldRefusal(NOT_YET, 503, "not_yet");
    throw trouble;
  }
  if (!row) throw new MouldRefusal("there is no mould of that name on your account", 404, "gone");
  let minifig = null;
  const avatar = (await db(`profile_avatars?account=eq.${account}&select=minifig,removed_at`))[0];
  if (avatar?.minifig && avatar.minifig.hd === id) {
    const base = HAIR.find(([one]) => one === row.base);
    minifig = { ...avatar.minifig, hd: base ? base[0] : "" };
    await db(`profile_avatars?account=eq.${account}`, { method: "PATCH", body: { minifig } });
  }
  await db(`own_moulds?account=eq.${account}&id=eq.${id}`, { method: "DELETE" });
  return { removed: true, id, minifig };
}

/// Whether [account] keeps the mould [id] for a minifigure's hair: what a
/// recipe that wears it must be (api/people.js saveAvatar).
export async function wearsOwn(account, id) {
  try {
    const rows = await db(`own_moulds?account=eq.${account}&id=eq.${id}&select=slot`);
    return Boolean(rows[0] && HAIR_SLOTS.includes(rows[0].slot));
  } catch (trouble) {
    if (notThere(trouble)) return false;
    throw trouble;
  }
}

/// The text of [account]'s own mould [id], or null: nobody else's, and
/// nothing for nobody signed in.
export async function mouldText(id, account) {
  if (!account || !OWN_MOULD.test(String(id || ""))) return null;
  try {
    const mine = (await db(`own_moulds?account=eq.${account}&id=eq.${id}&select=text`))[0];
    return mine ? { text: mine.text, mine: true } : null;
  } catch (trouble) {
    if (notThere(trouble)) return null;
    throw trouble;
  }
}
