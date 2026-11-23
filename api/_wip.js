// Work in progress, shared by version (2026-11-23, unit buildlog;
// supabase/wip.sql, docs/SOCIAL.md section 11, docs/MASTERPLAN.md row 10).
//
// A model was shared when it was finished, so the months it took to build
// were seen by nobody. Now the studio's Share progress publishes a version
// as Publish does, marked work in progress (api/share.js publish, wip:
// true), and the model is WIP until its designer publishes a version as
// finished or marks the newest one finished on its page:
//
//   POST /api/share?op=finish     (session) {id}: the owner's WIP model
//                                 called finished, its newest version the
//                                 finished one (supabase/wip.sql wip_finish)
//
// Each WIP version, and the finish, is one post in the model's one Show and
// tell thread in Talk, written as its designer (wip_talk): the first opens
// the thread, with the model's card; each later one is a reply with its
// version's card (its picture), its note and what changed, the very line
// the versions say (api/_versions.js saidOf); never a new thread. Talk's
// own rules hold (limits, bans, the age question, blocks); a post refused
// never stops the publish, and the answer says why.
//
// While WIP a model is on its page, in its Log, in its followers' feeds and
// in the gallery's Newest marked so; never in Top, a ranked sort, This
// week's pick, a challenge or a shelf (the SQL's rules). Until wip.sql is
// applied none of it is there: wipReady() says so, and a publish asking for
// it is refused in words.

import { db } from "./_db.js";
import { Unacceptable } from "./_directory.js";
import { WORDS as TALK_WORDS } from "./_talk.js";
import { saidOf } from "./_versions.js";

const NOT_THERE = /: (?:400|404)$/;
const ID = /^[A-Za-z0-9]{10}$/;
// How long one function's answer to "is wip.sql applied" is kept.
const READY_MS = 5 * 60 * 1000;
export const NOT_YET = "Sharing work in progress is not open on Brickworks yet: publish it as it is, or try again later.";
/// Why a work in progress must be listed and credited: it is shown by name.
export const SHOWN = "Work in progress is shown in the gallery, to your followers and in Talk by your name: "
  + "tick List it in the gallery and Show who made it, or press Publish to share it by its link only.";

let readiness = { at: -Infinity, yes: false };

/// Whether supabase/wip.sql is applied here: its columns are there. Asked
/// once in READY_MS by each function; before the file, every read and write
/// leaves the columns out, as the code before it did.
export async function wipReady(now = Date.now()) {
  if (now - readiness.at < READY_MS) return readiness.yes;
  let yes = false;
  let kept = now;
  try {
    await db("share_versions?select=wip,finished_at,talk_post,finished_post,has_thumb&limit=0", { seconds: 5 });
    yes = true;
  } catch (trouble) {
    // Not there (400: no such column) is kept; the database unreachable is
    // asked again in half a minute, and meanwhile read as before the file.
    if (!NOT_THERE.test(String(trouble?.message || ""))) kept = now - READY_MS + 30000;
  }
  readiness = { at: kept, yes };
  return yes;
}

/// Whether a model is work in progress, from its versions, newest first
/// (api/share.js versionsOf): its newest was shared as one and not called
/// finished since, which is when supabase/wip.sql keeps wip_at. Pure.
export const isWip = (versions) => Boolean(versions?.[0]?.wip && !versions[0].finished_at);

/// For tests: forget what was found.
export function forgetReadiness() {
  readiness = { at: -Infinity, yes: false };
}

/// A thread's title from a model's [name]: the name itself, which says what
/// the thread is about whether it is still being built or finished; one
/// too short for Talk (3 characters) is said as a model's. Pure.
export function threadTitle(name) {
  const plain = String(name || "").replace(/[\x00-\x1f\x7f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 120);
  return plain.length >= 3 ? plain : `The model ${plain || "without a name"}`.slice(0, 120);
}

/// What the post of version [n] of model [id] says, as its designer posts
/// it: {title, body}. [kind] "wip" (a version shared as work in progress),
/// "finished" (published as the finished one) or "marked" (the newest
/// called finished on its page). [first]: it opens the thread, so it says
/// each version will follow. Each carries its own version's card (/m/X/v/N,
/// that version's picture) for good, under the thread's own card of the
/// model as it is now (api/_talk.js threadHtml). [said] is the
/// versions' own line (saidOf), as the page and the studio say it. Plain
/// text, as every post is. Pure.
export function postWords({ id, name, n, note = null, said = "", kind = "wip", first = false, origin = "https://brickworks.diy" }) {
  const lines = [];
  const noted = note ? ` ${String(note).trim()}` : "";
  if (kind === "wip") lines.push(`Work in progress, version ${n}.${noted}`);
  else lines.push(`Finished: version ${n} is the finished model.${kind === "finished" ? noted : ""}`);
  if (said && kind !== "marked") lines.push(said);
  if (first && kind === "wip") lines.push("Each new version will be posted in this thread as it is shared.");
  lines.push(`${origin}/m/${id}/v/${n}`);
  return { title: threadTitle(name), body: lines.join("\n") };
}

/// Why Talk took no post, in words: Talk's own refusals as Talk says them.
export function refusedSaid(code) {
  if (code === "no_profile") {
    return "Make a profile at brickworks.diy/profile: Talk and your followers see work in progress by the name it shows.";
  }
  if (code === "model" || code === "no_version") return "That version is not there any more.";
  return (TALK_WORDS[code] || [0, "Talk could not take the post just now."])[1];
}

/// The post version [n] of [model] makes in its Talk thread, as [account]
/// ([kind] as postWords; "marked" is kept as the version's finished_post).
/// {thread, post, made, url} or {refused, why}. Never throws: a post that
/// cannot be made never stops what made it.
export async function postVersion(account, model, { n, note = null, changes = null, kind = "wip", origin, profile }) {
  try {
    if (!profile || !profile.handle) return { refused: "no_profile", why: refusedSaid("no_profile") };
    // Both ways it may go: a reply in the model's thread, or the thread's
    // first post when it has none (wip_talk chooses, holding the version).
    const asked = { id: model.id, name: model.name, n, note, said: saidOf(n, changes) || "", kind, origin };
    const reply = postWords(asked);
    const opening = postWords({ ...asked, first: true });
    const said = await db("rpc/wip_talk", { method: "POST", body: { account, p_model: model.id, p_n: n,
      p_title: reply.title, p_said: reply.body, p_kind: kind === "marked" ? "finished" : "version", p_first: opening.body } });
    if (!said || said.refused) return { refused: said?.refused || "unknown", why: refusedSaid(said?.refused) };
    return { thread: Number(said.thread), post: Number(said.post), made: said.made === true,
      url: `${origin}/talk/t/${Number(said.thread)}` };
  } catch (trouble) {
    console.error(`wip: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return { refused: "unknown", why: refusedSaid("unknown") };
  }
}

/// POST ?op=finish {id}: the owner's WIP model called finished now, its
/// newest version the finished one, and that said in its Talk thread.
/// {id, version, finished_at, talk}. [owner] is the session's account,
/// verified by the caller; [origin] the site's.
export async function finish(owner, given, origin) {
  const id = String(given || "");
  if (!ID.test(id)) throw new Unacceptable("name a link: {id: <ten characters>}");
  if (!(await wipReady())) throw new Unacceptable(NOT_YET, 503);
  const said = await db("rpc/wip_finish", { method: "POST", body: { account: owner, p_model: id } });
  if (!said || said.refused === "model") throw new Unacceptable("That is not one of your shared models.", 404);
  if (said.refused === "not_wip") throw new Unacceptable("That model is not work in progress: it is finished already.", 409);
  const [model] = await db(`shared_models?id=eq.${id}&select=id,name,owner,listed,author`);
  // Said in Talk only while it is shown by name, as its versions were.
  const shown = model && model.listed === true && Boolean(model.author);
  const profile = shown ? await db("rpc/feed_who", { method: "POST", body: { account: owner } }).catch(() => null) : null;
  const talk = shown ? await postVersion(owner, model, { n: Number(said.n), kind: "marked", origin, profile }) : null;
  return { id, version: Number(said.n), finished_at: said.finished_at, finished: true, talk };
}
