// An account deleted, and everything of it (api/account.js ?op=delete, the
// person's own; api/admin.js ?op=delete_account, the site's owner at the
// person's request, console3): its plan at Admission first while billing is
// on, the orangecheck account Connect made for it, the files storage keeps
// of it by name (its build photos and those of its models, its avatar, its
// shared models' files, its feedback's), then the account, and with it every
// row that names it. One
// place for both, so the two can never delete differently.
//
// Who may ask is the caller's to check: here is only what is done.

import { db, reach } from "./_db.js";

const SUPPORT = "support@atypic.ai";
// Admission did not erase the account: one that pays, and any other.
const PLAN_NOT_ENDED = `We couldn't cancel your Pro plan, so nothing was deleted. Try again in a minute, or write to ${SUPPORT}.`;
const PLAN_NOT_ERASED = `We couldn't close your plan with billing just now, so nothing was deleted. Try again in a minute, or write to ${SUPPORT}.`;
export const NOT_DELETED = "Brickworks could not delete the account just now. Try again in a minute.";

/// [account] deleted, and everything of it: {status, body}, the answer
/// ?op=delete gives. Asked by a deletion the person confirmed, by an
/// answer under 13 (takeAge), and by the site's owner at the person's own
/// request (api/admin.js ?op=delete_account, a typed confirmation, kept in
/// the audit).
export async function erase(account) {
  // Its plan before anything here, while billing is on: erased at Admission
  // (api/_billing.js eraseAccount), and a subscription it pays for ended
  // now, nothing charged again. Admission not doing it holds the whole
  // deletion, to try again: an account deleted with its plan left behind
  // would go on being charged, and nobody could cancel it. Off, nothing is
  // asked. Loaded only here, as orangecheck's code is.
  const { eraseAccount, entitlementOf } = await import("./_billing.js");
  let ended;
  try {
    ended = await eraseAccount(account);
  } catch (trouble) {
    console.error(`account: not erased at Admission: ${trouble?.code || trouble?.name || "error"}: `
      + String(trouble?.message || trouble).slice(0, 120));
    // What is held of the account says whether it pays, Admission or not.
    const paying = await entitlementOf(account)
      .then((e) => Boolean(e.subscription && e.subscription.status !== "canceled"), () => false);
    return { status: 503, body: { error: paying ? PLAN_NOT_ENDED : PLAN_NOT_ERASED } };
  }
  // The orangecheck account Connect made for it, at its own tick
  // (api/orangecheck.js ?op=connect), deleted first: until the person
  // claims it, deleting it is Brickworks' to do, and once this account is
  // gone nothing could. Only for an account whose person ticked the box for
  // it (oc_connected): nobody else ever waits on orangecheck to leave. A
  // person can always delete their Brickworks account (site-attest's L1):
  // orangecheck refusing for good leaves theirs with them at ochk.app, said
  // plainly. Every other answer holds the deletion, 503 (api/_oc.js
  // unprovision, an allow-list): an outage asks them to try again, and
  // Connect not set up here (no key, one orangecheck does not know, any
  // answer not known) is paused as Brickworks' own fault, since deleting
  // would leave their orangecheck account behind (orangecheck's final
  // ruling, 2026-10-24). The daily canary asks Connect with the key
  // (api/_canary.js, d).
  // Marked as leaving as it is read, whether or not Connect was ever asked
  // (supabase/orangecheck_connect_leaving.sql), so a Connect ask in flight,
  // or one that starts while this goes on, deletes what it makes rather
  // than keep it (api/_oc.js provision, orangecheck's review, L2). The mark
  // is never taken off, even when this deletion does not go through:
  // another of the same account may be going on (site-attest's R1). It
  // lapses after 15 minutes.
  let connected;
  let kept = "";
  try {
    connected = await db("rpc/oc_connect_leaving", { method: "POST", body: { account } });
  } catch (trouble) {
    console.error(`account: whether Connect made an account: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { status: 502, body: { error: NOT_DELETED } };
  }
  if (connected) {
    const { unprovision } = await import("./_oc.js");
    const decided = await unprovision(account);
    if (!decided.go) return { status: decided.status, body: { error: decided.error } };
    kept = decided.kept || "";
  }
  try {
    // The files of the build photos it posted, and of those posted of its
    // models (their rows go with the models), by name: storage keeps no
    // link to the account.
    let photos = [];
    try {
      const models = (await db(`shared_models?owner=eq.${account}&select=id`)).map((one) => one.id);
      const ofModels = models.length ? await db(`build_photos?model=in.(${models.join(",")})&select=id`) : [];
      const own = await db(`build_photos?account=eq.${account}&select=id`);
      photos = [...new Map([...own, ...ofModels].map((one) => [one.id, one])).values()];
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const key = process.env.SUPABASE_SECRET_KEY;
    // Exactly these files of build-photos (api/_builds.js PHOTOS): each
    // photo and its card's copy (photoName, cardName), not imported from
    // there: this route answers every start of the app, and _builds.js
    // brings the picture decoders with it.
    for (let at = 0; at < photos.length; at += 100) {
      const files = await reach("storage DELETE build-photos", 20, `${base}/storage/v1/object/build-photos`, {
        method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ prefixes: photos.slice(at, at + 100).flatMap((one) => [`${one.id}.jpg`, `${one.id}.card.jpg`]) }) });
      if (!files.ok) throw new Error(`storage DELETE build-photos: ${files.status}`);
    }
    // Its own picture as its avatar (api/_avatars.js AVATARS), by name too.
    let avatars = [];
    try {
      avatars = await db(`profile_avatars?account=eq.${account}&select=id`);
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    if (avatars.length) {
      const files = await reach("storage DELETE avatars", 20, `${base}/storage/v1/object/avatars`, {
        method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
        body: JSON.stringify({ prefixes: avatars.map((one) => `${one.id}.jpg`) }) });
      if (!files.ok) throw new Error(`storage DELETE avatars: ${files.status}`);
    }
    // Its shared models' files, every version's and every picture's: the
    // models' rows go with the account, and storage has no other way to
    // them. Kept, they stayed in the public bucket after the person had gone.
    let modelIds = [];
    try {
      modelIds = (await db(`shared_models?owner=eq.${account}&select=id`)).map((one) => one.id);
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    if (modelIds.length) await modelFilesGone(base, key, modelIds);
    // The files of its feedback (api/_feedback.js): its reports go with the
    // account, their files by name first. Imported here, not above: this
    // route answers every start of the app.
    const feedback = await (await import("./_feedback.js")).deleteFeedbackOf(account);
    // What the owner's notifications kept of it (supabase/owner_notify.sql):
    // its sign-up, its first model, and the words of each mail that told of
    // it (a mail stays in the record as sent, saying no more than that).
    try {
      const told = await db(`owner_notify_events?account=eq.${account}&mail=not.is.null&select=mail`);
      const mails = [...new Set(told.map((one) => one.mail))].filter((id) => /^[a-z0-9]{12}$/.test(id));
      if (mails.length) {
        await db(`owner_notify_mails?id=in.(${mails.join(",")})`, { method: "PATCH",
          body: { subject: "About an account since deleted", body: "" } });
      }
      await db(`owner_notify_events?account=eq.${account}`, { method: "DELETE" });
    } catch (trouble) {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    }
    const gone = await reach("auth DELETE", 20, `${base}/auth/v1/admin/users/${account}`, {
      method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}` } });
    if (!gone.ok && gone.status !== 404) throw new Error(`auth DELETE: ${gone.status}`);
    // What /admin › Analytics kept of it, by its hash, gone now too
    // (api/_analytics.js): the daily cron's diff of the accounts is only the
    // net under this. Loaded only here.
    try {
      await (await import("./_analytics.js")).forgetAccount(account);
    } catch (trouble) {
      console.error(`account: analytics left for the cron: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    return { status: 200, body: { deleted: true, photos: photos.length, avatars: avatars.length, feedback,
      ...(kept ? { orangecheck: { kept: true, said: kept } } : {}), ...(ended ? { plan: { ended } } : {}) } };
  } catch (trouble) {
    console.error(`account: not deleted: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return { status: 502, body: { error: NOT_DELETED } };
  }
}

// A shared model's files in storage, found by its link: its file and every
// version's, its pictures, its cut-out, its card's copy (api/share.js BUCKET
// and THUMBS). Not imported from there: this route answers every start of
// the app.
const MODEL_BUCKETS = ["shared-models", "shared-thumbs"];

/// The files of the models [ids] deleted from both buckets. A bucket that is
/// not there has none; any other answer throws, so the deletion stops before
/// the account goes and can be asked again.
async function modelFilesGone(base, key, ids) {
  const headers = { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" };
  for (const bucket of MODEL_BUCKETS) {
    const names = [];
    for (const id of new Set(ids)) {
      if (!/^[A-Za-z0-9]{10}$/.test(id)) continue;
      for (let offset = 0; ; offset += 1000) {
        const listed = await reach(`storage list ${bucket}`, 20, `${base}/storage/v1/object/list/${bucket}`, {
          method: "POST", headers,
          body: JSON.stringify({ prefix: "", search: id, limit: 1000, offset, sortBy: { column: "name", order: "asc" } }) });
        if (listed.status === 400 || listed.status === 404) break;
        if (!listed.ok) throw new Error(`storage list ${bucket}: ${listed.status}`);
        const page = await listed.json();
        // The search matches anywhere in a name: this model's own files only.
        names.push(...page.filter((file) => file.id !== null && String(file.name).startsWith(`${id}.`))
          .map((file) => file.name));
        if (page.length < 1000) break;
      }
    }
    for (let at = 0; at < names.length; at += 100) {
      const gone = await reach(`storage DELETE ${bucket}`, 20, `${base}/storage/v1/object/${bucket}`, {
        method: "DELETE", headers, body: JSON.stringify({ prefixes: names.slice(at, at + 100) }) });
      if (!gone.ok && gone.status !== 404) throw new Error(`storage DELETE ${bucket}: ${gone.status}`);
    }
  }
}
