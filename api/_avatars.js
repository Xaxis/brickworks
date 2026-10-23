// Your own picture as your avatar, and your likes on your profile
// (2026-10-22, supabase/avatars.sql, docs/SOCIAL.md D11, U5, U6).
//
// A picture. Edit profile crops the picture a person chose to a circle in
// the page (web/profile.js) and sends the square it shows, at most 2 MB, as
// the JSON a function can take (no storage upload: it is far under a
// function's 4.5 MB). Nothing of what was sent is kept: it is decoded to its
// pixels and a new JPEG made of them (api/_photo.js, as a build photo is),
// the middle square of it if it was not square, at most 400 pixels a side,
// kept as avatars/<id>.jpg. A new picture has a new id; the one before is
// deleted once the new one is kept. Only an account with a profile, 13 or
// over, a few times an hour (may_act).
//
// Shown wherever the person is (api/_faces.js), while it may be: not taken
// out by the site's owner, the profile shown in public. Reported with the
// profile (Report it, on their page), and taken out by the site's owner on
// /admin: its file deleted, the row kept to say so, the reports about the
// profile settled, the avatar made from the handle shown again. Its owner
// takes it off themselves in Edit profile, which deletes the file and the
// row. Deleting the account deletes the file first (api/account.js).
//
// Likes. A person may choose, in /settings, to show on their profile which
// models they liked: off until they turn it on, and nobody else's to turn.
// Then their page has a Likes tab of those models' cards, newest like
// first, page by page.
//
// Until avatars.sql is applied its tables are not there: no picture is
// shown, no profile has Likes, and asking for either says it is not open
// yet (503).

import { db } from "./_db.js";
import { decodePicture, encodeJpeg, PhotoTrouble, QUALITY, resample, upright } from "./_photo.js";
import { deleteFiles, getFile, newPhotoId, putFile } from "./_builds.js";
import { pictureAt } from "./_faces.js";

export const AVATARS = "avatars";
export const AVATAR_SIDE = 400;
export const AVATAR_LEAST = 120;
export const AVATAR_MOST_BYTES = 2 * 1024 * 1024;
export const NOT_YET = "Pictures of your own and likes on your profile are not open on Brickworks yet.";
const ID = /^[A-Za-z0-9]{10}$/;
const NOT_THERE = /: 404$/;
const notThere = (trouble) => NOT_THERE.test(String(trouble?.message || ""));

export class AvatarRefusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/// A picture as sent, made into the avatar that is kept: {bytes (a JPEG),
/// side, was}. The middle square of it, at most AVATAR_SIDE a side.
export async function cleanAvatar(given, declared = "") {
  let image;
  try {
    image = await decodePicture(given, declared, AVATAR_MOST_BYTES);
  } catch (trouble) {
    if (trouble instanceof PhotoTrouble) {
      throw new AvatarRefusal(trouble.message.replace(/\bphoto\b/g, "picture")
        .replace("too small to show a build", `at least ${AVATAR_LEAST} pixels a side, please`), trouble.status);
    }
    throw trouble;
  }
  const turned = upright(image, image.orientation);
  const whole = Math.min(turned.width, turned.height);
  if (whole < AVATAR_LEAST) {
    throw new AvatarRefusal(`that picture is ${turned.width} × ${turned.height}: at least ${AVATAR_LEAST} pixels a side, please`, 422);
  }
  const side = Math.min(AVATAR_SIDE, whole);
  const made = resample(turned, { left: Math.floor((turned.width - whole) / 2), top: Math.floor((turned.height - whole) / 2),
    width: whole, height: whole }, side, side);
  const jpeg = encodeJpeg({ data: made.data, width: side, height: side }, QUALITY).data;
  return { bytes: Buffer.from(jpeg), side, was: image.was };
}

/// [account]'s picture as kept: {ready, id, at, removed} (id null for
/// none); ready false before avatars.sql.
export async function avatarOf(account) {
  try {
    const row = (await db(`profile_avatars?account=eq.${account}&select=id,at,removed_at`))[0];
    return { ready: true, id: row && !row.removed_at ? row.id : null, at: row?.at ?? null, removed: Boolean(row?.removed_at) };
  } catch (trouble) {
    if (notThere(trouble)) return { ready: false, id: null, at: null, removed: false };
    throw trouble;
  }
}

/// What [account] is told of their picture: {ready, picture, removed}.
export const avatarSaid = (kept) => ({ ready: kept.ready, picture: kept.id ? pictureAt(kept.id) : null,
  removed: kept.removed });

/// A picture kept as [account]'s avatar, in place of the one before.
/// [check] is the caller's own refusals (a profile, the age rule, the rate
/// limit), asked once the picture itself is in order.
export async function keepAvatar(account, base64, type, check) {
  const before = await avatarOf(account);
  if (!before.ready) throw new AvatarRefusal(NOT_YET, 503);
  if (typeof base64 !== "string" || !base64) throw new AvatarRefusal("send the picture: {picture: <base64>, type}");
  if (base64.length > Math.ceil((AVATAR_MOST_BYTES * 4) / 3) + 8) {
    throw new AvatarRefusal(`that picture is more than ${AVATAR_MOST_BYTES / 1048576} MB: a smaller one, please`, 413);
  }
  const made = await cleanAvatar(Buffer.from(base64, "base64"), type);
  await check();
  const id = newPhotoId();
  await putFile(AVATARS, `${id}.jpg`, made.bytes, "image/jpeg");
  try {
    await db("profile_avatars?on_conflict=account", { method: "POST", prefer: "resolution=merge-duplicates",
      body: { account, id, side: made.side, bytes: made.bytes.length, was: made.was, at: new Date().toISOString(),
        removed_at: null, removed_why: null } });
  } catch (trouble) {
    await deleteFiles(AVATARS, [`${id}.jpg`]).catch(() => {});
    if (/: 400$/.test(trouble.message)) throw new AvatarRefusal("that picture could not be kept: a picture is for profiles 13 or over", 422);
    throw trouble;
  }
  // The one before, which nothing shows now: its row is this one.
  if (before.id && before.id !== id) {
    await deleteFiles(AVATARS, [`${before.id}.jpg`]).catch((trouble) =>
      console.error(`avatars: the picture before was not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`));
  }
  return { ready: true, picture: pictureAt(id), removed: false, side: made.side, bytes: made.bytes.length };
}

/// [account]'s own picture taken off: its file and its row deleted, and the
/// avatar made from the handle shown again.
export async function dropAvatar(account) {
  const kept = await avatarOf(account);
  if (!kept.ready) throw new AvatarRefusal(NOT_YET, 503);
  const rows = await db(`profile_avatars?account=eq.${account}&select=id`);
  if (rows.length) await deleteFiles(AVATARS, rows.map((row) => `${row.id}.jpg`));
  await db(`profile_avatars?account=eq.${account}`, { method: "DELETE" });
  return { ready: true, picture: null, removed: false };
}

/// Picture [id], for whoever may see it: null when it was taken out, its
/// profile may not be shown, or it is gone. [shown] says whether an account
/// may be shown in public (api/_trust.js shownPublicly).
export async function avatarFile(id, shown) {
  if (!ID.test(String(id || ""))) return null;
  let row;
  try {
    row = (await db(`profile_avatars?id=eq.${id}&select=account,removed_at`))[0];
  } catch (trouble) {
    if (notThere(trouble)) return null;
    throw trouble;
  }
  if (!row || row.removed_at || !(await shown(row.account))) return null;
  return getFile(AVATARS, `${id}.jpg`);
}

/// The site's owner takes [account]'s picture out: its file deleted, the
/// row kept to say so, and what was reported about the profile settled.
export async function removeAvatar(account, why) {
  const kept = await avatarOf(account);
  if (!kept.ready) throw new AvatarRefusal(NOT_YET, 503);
  const row = (await db(`profile_avatars?account=eq.${account}&select=id,removed_at`))[0];
  if (!row) throw new AvatarRefusal("that profile shows no picture of its own", 404);
  if (!row.removed_at) {
    await db(`profile_avatars?account=eq.${account}`, { method: "PATCH",
      body: { removed_at: new Date().toISOString(), removed_why: why || "Taken out by Brickworks" } });
  }
  await deleteFiles(AVATARS, [`${row.id}.jpg`]);
  const person = (await db(`people?account=eq.${account}&select=handle`))[0];
  let reports = 0;
  if (person) {
    const open = await db(`reports?handle=eq.${person.handle}&resolved_at=is.null&select=id`);
    reports = open.length;
    if (reports) {
      await db(`reports?handle=eq.${person.handle}&resolved_at=is.null`, { method: "PATCH",
        body: { resolved_at: new Date().toISOString(), resolution: "taken_out" } });
    }
  }
  return { account, removed: true, file: `${AVATARS}/${row.id}.jpg`, reports };
}

// ---------------------------------------------------------------------------
// Likes on a profile.

/// Whether [account] chose to show the models they liked: {ready,
/// shows_likes}; ready false before avatars.sql.
export async function likesChoiceOf(account) {
  try {
    const row = (await db(`profile_choices?account=eq.${account}&select=shows_likes`))[0];
    return { ready: true, shows_likes: row?.shows_likes === true };
  } catch (trouble) {
    if (notThere(trouble)) return { ready: false, shows_likes: false };
    throw trouble;
  }
}

/// [account]'s choice kept: show the models they liked, or not.
export async function chooseLikes(account, shows) {
  try {
    await db("profile_choices?on_conflict=account", { method: "POST", prefer: "resolution=merge-duplicates",
      body: { account, shows_likes: shows, updated_at: new Date().toISOString() } });
  } catch (trouble) {
    if (notThere(trouble)) throw new AvatarRefusal(NOT_YET, 503);
    if (/: 400$/.test(trouble.message)) throw new AvatarRefusal("what a profile shows is for profiles 13 or over", 422);
    throw trouble;
  }
  return likesChoiceOf(account);
}

/// How many models [account] liked that the gallery shows.
export async function likesCount(account, tests = false) {
  return Number(await db("rpc/profile_likes_count", { method: "POST", body: { whose: account, tests } })) || 0;
}

/// A page of the models [account] liked, newest like first, as the
/// gallery's rows (directory_card): [size] of them and whether there are more.
export async function likedRows(account, { size, skip, tests = false }) {
  const rows = await db("rpc/profile_likes", { method: "POST", body: { whose: account, size: size + 1, skip, tests } });
  return { rows: (rows || []).slice(0, size), more: (rows || []).length > size };
}
