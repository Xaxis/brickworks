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
// cut or mended: a person whose mould is refused is told why.
//
// Who reads one (mouldText): its owner; and anybody, for a mould a shown
// avatar wears now, as the picture drawn of it is anybody's to see. A
// browser keeps what it read for good (an id is its text), and an avatar
// is the picture the maker drew, never the mould: a page view reads none.

import { createHash } from "node:crypto";
import { db } from "./_db.js";
import { OWN_MOULD } from "./_minifig_parts.js";

export const MOST_BYTES = 2 * 1024 * 1024;
export const MOST_TRIANGLES = 18000;
export const MOST_EDGES = 60000;
export const MOST_MOULDS = 40;
export const MOST_KEPT = 24 * 1024 * 1024;
// How far from the part's origin a corner may be, in LDU: a minifigure is
// about 100 tall, so a mould twice its size is still let through.
export const REACH = 400;
export const NOT_YET = "Moulds on your account are not open on Brickworks yet: your mould is kept in the studio.";
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
const notThere = (trouble) => NOT_THERE.test(String(trouble?.message || ""));

export class MouldRefusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
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
/// triangles, bytes, text}, or a MouldRefusal saying what is wrong.
export function mouldOf(body) {
  const given = body && typeof body === "object" && !Array.isArray(body) ? body : {};
  const { id, slot, text } = given;
  if (typeof id !== "string" || !OWN_MOULD.test(id)) {
    throw new MouldRefusal("that is not a mould's name: bw-<part>-m-<twenty hex digits>, as the studio names one");
  }
  if (typeof slot !== "string" || !SLOTS.includes(slot)) {
    throw new MouldRefusal(`a mould is made for one of a minifigure's slots: ${SLOTS.join(", ")}`);
  }
  if (typeof text !== "string" || !text) throw new MouldRefusal("send the mould's text: {id, slot, text}");
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > MOST_BYTES) {
    throw new MouldRefusal(`that mould is ${(bytes / 1048576).toFixed(1)} MB: at most ${MOST_BYTES / 1048576} MB, please`, 413);
  }
  if (/[\u0000-\u0008\u000b-\u001f\u007f]/.test(text)) {
    throw new MouldRefusal("that mould has a character no part file has (a carriage return or another control character)");
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
    if (triangles > MOST_TRIANGLES) throw new MouldRefusal(`that mould has more than ${MOST_TRIANGLES.toLocaleString("en")} triangles`, 413);
    if (edges > MOST_EDGES) throw new MouldRefusal(`that mould has more than ${MOST_EDGES.toLocaleString("en")} edges`, 413);
  }
  if (!base) throw new MouldRefusal(`that is no mould made in the studio: it has no "${MOULDED_BY} from=..." line`);
  if (!triangles) throw new MouldRefusal("that mould has no triangles");
  if (named !== `${id}.dat`) throw new MouldRefusal(`that mould calls itself ${named.slice(0, 48) || "nothing"}, not ${id}.dat`);
  if (idOf(text, id, base) !== id) {
    throw new MouldRefusal("that mould's name is not its own: its digits are not its text's (it was changed after it was made)");
  }
  // Its name, as the studio's own first line has it: "<base name>, Custom
  // Mould <title>".
  const name = title.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 120) || id;
  return { id, slot, base, name, triangles, bytes, text };
}

/// [account]'s moulds, without their text, newest first: {ready, moulds}.
export async function mouldsOf(account) {
  try {
    const moulds = await db(`own_moulds?account=eq.${account}&select=id,slot,base,name,triangles,bytes,at&order=at.desc`);
    return { ready: true, moulds };
  } catch (trouble) {
    if (notThere(trouble)) return { ready: false, moulds: [] };
    throw trouble;
  }
}

/// [mould] (mouldOf) kept as [account]'s, in place of the same id kept
/// before. [check] is the caller's own refusals (the rate limit), asked once
/// the mould is in order: {kept, id}.
export async function keepMould(account, mould, check) {
  const { ready, moulds } = await mouldsOf(account);
  if (!ready) throw new MouldRefusal(NOT_YET, 503);
  const others = moulds.filter((one) => one.id !== mould.id);
  if (others.length >= MOST_MOULDS) {
    throw new MouldRefusal(`your account keeps ${MOST_MOULDS} moulds, the most it has room for: `
      + "this one is kept in the studio, and not on the site", 409);
  }
  const weight = others.reduce((sum, one) => sum + Number(one.bytes || 0), 0);
  if (weight + mould.bytes > MOST_KEPT) {
    throw new MouldRefusal(`your account keeps ${(weight / 1048576).toFixed(1)} MB of moulds, and this one would take it past `
      + `${MOST_KEPT / 1048576} MB: it is kept in the studio, and not on the site`, 409);
  }
  await check();
  try {
    await db("own_moulds?on_conflict=account,id", { method: "POST", prefer: "resolution=merge-duplicates,return=minimal",
      body: { account, ...mould, at: new Date().toISOString() } });
  } catch (trouble) {
    // Another save to this account came first and took the room counted
    // above: the table's own cap (own_moulds_cap, which saves to one account
    // pass in turn) refused this one. Every other check the table makes,
    // mouldOf made first.
    if (/: 400$/.test(String(trouble?.message || ""))) {
      throw new MouldRefusal(`your account has room for ${MOST_MOULDS} moulds and ${MOST_KEPT / 1048576} MB of them, `
        + "and another save took the last of it: this one is kept in the studio, and not on the site", 409);
    }
    throw trouble;
  }
  return { kept: true, id: mould.id };
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

/// The text of the mould [id], for [account] (null for nobody signed in):
/// theirs, or one a shown avatar wears now. [shown] is api/_trust.js
/// shownPublicly. {text, mine} or null.
export async function mouldText(id, account, shown) {
  if (!OWN_MOULD.test(String(id || ""))) return null;
  try {
    if (account) {
      const mine = (await db(`own_moulds?account=eq.${account}&id=eq.${id}&select=text`))[0];
      if (mine) return { text: mine.text, mine: true };
    }
    const wearers = await db(`profile_avatars?minifig->>hd=eq.${id}&removed_at=is.null&select=account&limit=5`);
    for (const { account: wearer } of wearers) {
      if (!(await shown(wearer))) continue;
      const worn = (await db(`own_moulds?account=eq.${wearer}&id=eq.${id}&select=text`))[0];
      if (worn) return { text: worn.text, mine: false };
    }
    return null;
  } catch (trouble) {
    if (notThere(trouble)) return null;
    throw trouble;
  }
}
