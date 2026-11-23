// The console's Talk (/admin#talk, web/admin-talk.js): what was reported in
// Talk, the threads, and who is banned from it, with the owner's acts on
// them (supabase/talk.sql talk_admin, talk_admin_act). api/admin.js answers
// GET ?op=talk and POST ?op=talk_act with these, the act kept in the audit
// (api/_console.js audited) like every other.
//
//   GET  ?op=talk[&q=words]      {ready, reports, threads, bans}: the open
//                                reports with their posts, the newest 200
//                                threads (hidden and removed too) and the
//                                bans in force; ?tests=1 the checks' own
//   POST ?op=talk_act            {act, thread?, post?, account?, board?,
//                                until?, reason?}: pin, unpin, lock,
//                                unlock, move (to board), hide, show,
//                                remove (a thread or a post), ban (an
//                                account, or a post's writer, until a time
//                                or for good), unban, dismiss (a post's
//                                reports). A post removed takes its photo's
//                                files with it (api/_talk.js dropPhotos).

import { db } from "./_db.js";
import { BOARDS, dropPhotos } from "./_talk.js";

const ACTS = new Set(["pin", "unpin", "lock", "unlock", "move", "hide", "show", "remove", "ban", "unban", "dismiss"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const NOT_THERE = /: 404$/;

class TalkRefusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

// What a refusal of talk_admin_act says.
const REFUSED = {
  no_post: [404, "That post is not there."],
  no_thread: [404, "That thread is not there."],
  no_account: [400, "Say whose account: Brickworks' own cannot be banned."],
  until: [400, "A ban ends after now, or never."],
  board: [400, `A board is one of ${BOARDS.join(", ")}.`],
  act: [400, "That act needs a thread or a post."],
};

/// GET ?op=talk: what the owner moderates in Talk.
export async function talkRead(request, tests) {
  const q = String(request.query?.q || "").replace(/\s+/g, " ").trim().slice(0, 100);
  try {
    const said = await db("rpc/talk_admin", { method: "POST", body: { p_tests: tests, p_q: q || null } });
    return { ready: true, ...said };
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) return { ready: false, reports: [], threads: [], bans: [] };
    throw trouble;
  }
}

const whole = (given) => {
  if (given === undefined || given === null || given === "") return null;
  const n = Number(given);
  if (!Number.isSafeInteger(n) || n < 1) throw new TalkRefusal("thread and post are numbers");
  return n;
};

/// POST ?op=talk_act: one of the owner's acts on Talk.
export async function talkAct(request, response) {
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const act = String(body.act || "");
  if (!ACTS.has(act)) throw new TalkRefusal(`act is one of ${[...ACTS].join(", ")}`);
  const thread = whole(body.thread);
  const post = whole(body.post);
  const account = body.account === undefined || body.account === null || body.account === "" ? null : String(body.account).toLowerCase();
  if (account !== null && !UUID.test(account)) throw new TalkRefusal("account is an account's id");
  const board = body.board === undefined || body.board === null || body.board === "" ? null : String(body.board);
  if (board !== null && !BOARDS.includes(board)) throw new TalkRefusal(REFUSED.board[1]);
  let until = null;
  if (body.until !== undefined && body.until !== null && body.until !== "") {
    const at = Date.parse(String(body.until));
    if (!Number.isFinite(at)) throw new TalkRefusal("until is a time (ISO 8601), or none for good");
    until = new Date(at).toISOString();
  }
  const reason = typeof body.reason === "string" ? body.reason.replace(/[\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 200) : "";
  let said;
  try {
    said = await db("rpc/talk_admin_act", { method: "POST", body: { p_act: act, p_thread: thread, p_post: post, p_account: account,
      p_board: board, p_until: until, p_reason: reason || null } });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || ""))) throw new TalkRefusal("Talk is not open on this deployment yet.", 503);
    throw trouble;
  }
  if (said?.refused) {
    const [status, words] = REFUSED[said.refused] || [400, "That could not be done."];
    throw new TalkRefusal(words, status);
  }
  const photos = Array.isArray(said?.photos) ? said.photos : [];
  if (photos.length) await dropPhotos(photos);
  return response.status(200).json({ done: said.done, thread: said.thread ?? thread, post: said.post ?? post,
    ...(said.account ? { account: said.account } : {}), ...(said.until !== undefined ? { until: said.until } : {}),
    removed: act === "remove", photos: photos.length });
}

export { TalkRefusal };
