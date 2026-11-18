// What the console's Claude is handed to read (adminclaude, 2026-11-18;
// docs/ADMIN_CLAUDE.md): the helpers every area's tools share.
//
//   untrusted(source, text)  words somebody outside wrote (a Reddit reply, a
//                            feedback report, a mail's subject), wrapped as
//                            quoted data the system prompt says is never an
//                            instruction; a tag inside it cannot close it,
//                            however it is written (entities, full-width
//                            or other look-alike forms, invisible characters)
//   redacted(value)          every email address taken out of [value], deep:
//                            nobody's address reaches Claude, whatever a
//                            section's read holds
//   fitted(value, most)      [value] as JSON within [most] characters: the
//                            longest list halved until it fits, with how many
//                            were left out, never cut mid-word
//   checked(schema, input)   a tool's input against its schema, strictly: no
//                            field it does not name, each of its type and
//                            bounds; a boolean false is as if it were absent

export class ToolRefusal extends Error {}

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// An opening or closing tag, with a space anywhere in it; its attributes and
// end taken with it when they come (a > within 200 characters), else the
// start of it alone.
const TAG = /<\s*\/?\s*untrusted\b(?:[^<>]{0,200}>)?/gi;
const INVISIBLE = /[\u00ad\u180e\u200b-\u200f\u2028-\u202e\u2060-\u2064\ufeff]/g;
const NAMED = { lt: "<", gt: ">", amp: "&", quot: '"', apos: "'", sol: "/", nbsp: " " };

/// [text]'s HTML entities, named and numbered, read as the characters they stand for.
function decoded(text) {
  return text.replace(/&(#x[0-9a-f]{1,6}|#[0-9]{1,7}|[a-z]{2,8});?/gi, (whole, name) => {
    if (name[0] !== "#") return NAMED[name.toLowerCase()] ?? whole;
    const code = name[1] === "x" || name[1] === "X" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
    return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : "";
  });
}

/// [text] as it reads: no invisible characters, each look-alike form (a
/// full-width <, a small one) the plain one (NFKC), entities decoded; again
/// until nothing changes, so an entity of an entity is read too.
export function canonical(text) {
  let now = String(text ?? "");
  for (let round = 0; round < 6; round += 1) {
    const next = decoded(now.replace(INVISIBLE, "").normalize("NFKC")).replace(INVISIBLE, "");
    if (next === now) break;
    now = next;
  }
  return now;
}

/// [text] from [source], as data: read as it reads, then its own tags made
/// harmless, and any email address taken out.
export function untrusted(source, text) {
  const words = canonical(text).replace(TAG, "[tag]").replace(EMAIL, "[an address]");
  return words ? `<untrusted source="${source}">${words}</untrusted>` : "";
}

/// [value] with every email address replaced, all the way down.
export function redacted(value) {
  if (typeof value === "string") return value.replace(EMAIL, "[an address]");
  if (Array.isArray(value)) return value.map(redacted);
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, inner] of Object.entries(value)) {
      if (/^(email|e_mail|address|to|from|reply_to|recipient|recipients|actor)$/i.test(key) && typeof inner === "string") continue;
      out[key] = redacted(inner);
    }
    return out;
  }
  return value;
}

/// The longest array in [value], with where it is.
function longest(value, found = { list: null, holder: null, key: null }) {
  if (Array.isArray(value)) {
    for (const one of value) longest(one, found);
  } else if (value && typeof value === "object") {
    for (const [key, inner] of Object.entries(value)) {
      if (Array.isArray(inner) && (!found.list || inner.length > found.list.length)) Object.assign(found, { list: inner, holder: value, key });
      longest(inner, found);
    }
  }
  return found;
}

/// [value] as JSON within [most] characters.
export function fitted(value, most = 24000) {
  let copy = JSON.parse(JSON.stringify(value ?? null));
  let text = JSON.stringify(copy);
  for (let tries = 0; text.length > most && tries < 40; tries += 1) {
    const { list, holder, key } = longest(copy);
    if (!list || list.length < 2 || !holder) break;
    const kept = Math.floor(list.length / 2);
    holder[key] = list.slice(0, kept);
    holder[`${key}_not_shown`] = (Number(holder[`${key}_not_shown`]) || 0) + (list.length - kept);
    text = JSON.stringify(copy);
  }
  if (text.length > most) {
    copy = { too_long: true, said: `This read is ${text.length.toLocaleString("en")} characters, over the ${most.toLocaleString("en")} a tool may hand over: ask for less.` };
    text = JSON.stringify(copy);
  }
  return text;
}

/// [input] checked against [schema] (an object of named properties): the
/// value to use, or a ToolRefusal that says what is wrong.
export function checked(schema, input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new ToolRefusal("The input is to be an object.");
  const names = Object.keys(schema.properties || {});
  const extra = Object.keys(input).filter((key) => !names.includes(key));
  if (extra.length) {
    throw new ToolRefusal(`Not a field of this tool: ${extra.slice(0, 10).join(", ")}${extra.length > 10 ? ` and ${extra.length - 10} more` : ""}. `
      + `It takes only: ${names.join(", ") || "nothing"}.`);
  }
  const out = {};
  for (const name of names) {
    const rule = schema.properties[name];
    let given = input[name];
    if (rule.type === "boolean" && given === false) given = undefined;
    if (given === undefined || given === null) {
      if ((schema.required || []).includes(name)) throw new ToolRefusal(`${name} is needed.`);
      continue;
    }
    if (rule.type === "string") {
      if (typeof given !== "string") throw new ToolRefusal(`${name} is to be words.`);
      if (rule.enum && !rule.enum.includes(given)) throw new ToolRefusal(`${name} is one of: ${rule.enum.join(", ")}.`);
      if (rule.maxLength && [...given].length > rule.maxLength) throw new ToolRefusal(`${name} is at most ${rule.maxLength} characters.`);
      if (rule.pattern && !new RegExp(rule.pattern).test(given)) throw new ToolRefusal(`${name} is not in its form (${rule.pattern}).`);
    } else if (rule.type === "integer") {
      if (!Number.isInteger(given)) throw new ToolRefusal(`${name} is to be a whole number.`);
      if (rule.minimum !== undefined && given < rule.minimum) throw new ToolRefusal(`${name} is at least ${rule.minimum}.`);
      if (rule.maximum !== undefined && given > rule.maximum) throw new ToolRefusal(`${name} is at most ${rule.maximum}.`);
    } else if (rule.type === "boolean") {
      if (typeof given !== "boolean") throw new ToolRefusal(`${name} is to be true or false.`);
    }
    out[name] = given;
  }
  return out;
}

/// A console read that answers with a response (feedback's), as a value.
export async function heldRead(route, request) {
  const held = { statusCode: 200, body: undefined, status(code) { this.statusCode = code; return this; },
    setHeader() { return this; }, json(body) { this.body = body; return this; }, end() { return this; } };
  await route(request, held);
  if (held.statusCode >= 400) throw new ToolRefusal(String(held.body?.error || `That read answered ${held.statusCode}.`));
  return held.body;
}
