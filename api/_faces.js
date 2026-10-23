// Whose picture to show beside their name (2026-10-22, supabase/avatars.sql,
// docs/SOCIAL.md D11).
//
// A person's avatar is made from their handle (web/card.js avatarHtml)
// unless they put a picture of their own in its place (api/_avatars.js).
// Every page and answer that names people names them by handle: a card's
// designer ({handle, name}), a comment's writer, a feed row's, a
// notification's, a profile, the people a profile follows. withFaces looks
// all of them up at once and gives each one with a picture its address,
// picture, which avatarHtml draws in the tile's place. One with none, or
// one whose picture was taken out, or whose profile may not be shown,
// keeps the tile.
//
// Before avatars.sql is applied there is nothing to look up, and nobody has
// a picture. A picture is decoration beside a name, so a lookup that fails
// leaves every tile as it was rather than fail the page.
//
// No picture decoder here: this is asked by every page that names a
// person, and the decoders are api/_avatars.js's alone.

import { db } from "./_db.js";

const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;
const ID = /^[A-Za-z0-9]{10}$/;

/// Where an avatar's picture is: the server's, which says for itself
/// whether it may still be shown (api/people.js ?op=avatar).
export const pictureAt = (id) => `/api/people?op=avatar&id=${id}`;

/// Every object in [value] that names a person by their handle.
function peopleIn(value, found = []) {
  if (Array.isArray(value)) {
    for (const one of value) peopleIn(one, found);
  } else if (value && typeof value === "object") {
    if (typeof value.handle === "string" && HANDLE.test(value.handle)) found.push(value);
    for (const inside of Object.values(value)) if (inside && typeof inside === "object") peopleIn(inside, found);
  }
  return found;
}

/// [value] with a picture given to each person in it who has one in
/// [faces] (handle -> avatar id), in place.
export function facesOn(value, faces) {
  for (const one of peopleIn(value)) {
    const id = faces.get(one.handle);
    if (ID.test(String(id || ""))) one.picture = pictureAt(id);
  }
  return value;
}

/// Which of [handles] show a picture of their own: handle -> avatar id.
export async function facesOf(handles) {
  const wanted = [...new Set(handles.filter((one) => HANDLE.test(String(one))))];
  if (!wanted.length) return new Map();
  try {
    const rows = await db("rpc/avatars_of", { method: "POST", body: { handles: wanted } });
    return new Map((rows || []).filter((row) => ID.test(String(row.avatar))).map((row) => [row.handle, row.avatar]));
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`faces: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    return new Map();
  }
}

/// [value] (an answer, a page's people, cards) with every person in it
/// who shows a picture given its address, in place, in one lookup.
export async function withFaces(value) {
  const people = peopleIn(value);
  if (!people.length) return value;
  return facesOn(value, await facesOf(people.map((one) => one.handle)));
}
