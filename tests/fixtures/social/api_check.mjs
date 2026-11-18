// The owner's social desk (socialdesk; api/_social.js, api/_social_reddit.js,
// api/_social_mock.js) through the real handlers: api/admin.js's social ops
// and api/plans.js's cron and visit, with the sign-in of billing/world.mjs,
// supabase/social.sql's tables held in memory as PostgREST would answer
// (tools/web/held_tables.mjs, social.sql's checks in its words), and the
// checks' pool talking to the mock Reddit. What tests/test_social.py asks.
//
//   node tests/fixtures/social/api_check.mjs
//
// Every write the mock is sent (a post, a reply) is counted after each act:
// only the owner's press of Send, and the due send of a press, may add one.
// Every answer and every line logged is searched for the mock's tokens.
// Prints one JSON object, each finding by name.
import { askAdmin, askPlans, world } from "../billing/world.mjs";
import { calls } from "../../../api/_social_mock.js";
import { reddit, SocialRefusal } from "../../../api/_social_reddit.js";

const logged = [];
for (const level of ["log", "error", "warn", "info"]) {
  const was = console[level].bind(console);
  console[level] = (...said) => {
    logged.push(said.map(String).join(" "));
    if (level === "error" && process.env.SOCIAL_CHECK_LOUD) was(...said);
  };
}

const out = {};
const answers = [];
try {
  const w = await world({ master: "owner@example.com" });
  process.env.CRON_SECRET = "cron-check-secret";
  delete process.env.REDDIT_CLIENT_ID;
  delete process.env.REDDIT_CLIENT_SECRET;
  const held = await import("../../../tools/web/held_tables.mjs");
  held.hold(["social_accounts", "social_tokens", "social_items", "social_sends", "social_results", "social_visits", "social_rules"]);
  const owner = await w.signIn({ sub: "11111111-1111-4111-8111-111111111111", email: "owner@example.com" });
  const stranger = await w.signIn({ sub: "22222222-2222-4222-8222-222222222222", email: "someone@example.com" });
  const host = "brickworks.diy";

  /// One request to api/admin.js as [token] (null: signed out).
  async function admin(op, { method = "POST", body, query = {}, token = owner, tests = true, at = host } = {}) {
    const got = await askAdmin({ method, query: { op, ...(tests ? { tests: "1" } : {}), ...query },
      headers: { host: at, ...(token ? { authorization: `Bearer ${token}` } : {}) }, body });
    answers.push(JSON.stringify(got.json));
    return got;
  }
  const writes = () => calls.filter((one) => one.sent).length;
  const rows = (table) => held.rowsOf(table);
  /// A held row changed behind the API's back, as time passing or a hand in
  /// the database would.
  const behind = (table, id, change) => fetch(`${process.env.SUPABASE_URL}/rest/v1/${table}?id=eq.${id}`, { method: "PATCH",
    headers: { "content-type": "application/json" }, body: JSON.stringify(change) });

  // 1. The gate: every op of the desk, signed out and as somebody else.
  const OPS = [["social", "GET"], ["social_rules", "GET"], ["social_connect", "POST"], ["social_connected", "POST"],
    ["social_disconnect", "POST"], ["social_sync", "POST"], ["social_mark", "POST"], ["social_draft", "POST"],
    ["social_drop", "POST"], ["social_send", "POST"], ["social_unschedule", "POST"], ["social_posted", "POST"],
    ["social_notes", "POST"]];
  const gate = [];
  for (const [op, method] of OPS) {
    const out1 = await admin(op, { method, token: null, body: { provider: "reddit", id: "aaaaaaaaaa" } });
    const out2 = await admin(op, { method, token: stranger, body: { provider: "reddit", id: "aaaaaaaaaa" } });
    gate.push(`${op}:${out1.status}:${out2.status}`);
  }
  out.gate = gate;
  out.gate_wrote = writes() + rows("social_sends").length + rows("social_accounts").length;

  // 2. The owner's pool with no Reddit app: nothing to connect, and why.
  const real = await admin("social", { method: "GET", tests: false });
  const realReddit = real.json?.networks?.find((one) => one.id === "reddit");
  out.real_reddit = { api: realReddit?.api, missing: realReddit?.missing, route: realReddit?.route,
    later: real.json?.networks?.filter((one) => one.later).map((one) => one.id) };
  // What the page shows in place for connecting later: names, never values.
  out.real_later = { env: realReddit?.env, redirect: realReddit?.redirect, scopes: realReddit?.scopes };
  const refused = await admin("social_connect", { body: { provider: "reddit" }, tests: false });
  out.real_connect = { status: refused.status, said: refused.json?.error };

  // 3. Connect the checks' Reddit (the mock): the state signed, the code taken.
  const asked = await admin("social_connect", { body: { provider: "reddit" } });
  const authorize = new URL(asked.json?.authorize || "http://none/");
  const state = authorize.searchParams.get("state");
  out.authorize = { status: asked.status, page: `${authorize.pathname}?${[...authorize.searchParams.keys()].join(",")}`,
    redirect: authorize.searchParams.get("redirect_uri") };
  const forged = await admin("social_connected", { body: { provider: "reddit", code: "mock-code-abcdefgh",
    state: `${state.slice(0, -4)}AAAA` } });
  const connected = await admin("social_connected", { body: { provider: "reddit", code: "mock-code-abcdefgh", state } });
  out.connect = { forged: forged.status, status: connected.status, handle: connected.json?.handle,
    accounts: rows("social_accounts").length, tokens: rows("social_tokens").length };

  // 3b. A connect is finished once (sdreview L9): its state again is
  //     refused, and two finishes of one connect at once make one account,
  //     the loser's keys handed back. Reddit's own app comes back to
  //     brickworks.diy, whichever host the console was on (L8).
  const replay = await admin("social_connected", { body: { provider: "reddit", code: "mock-code-replay01", state } });
  const asked2 = await admin("social_connect", { body: { provider: "reddit" } });
  const state2 = new URL(asked2.json?.authorize || "http://none/").searchParams.get("state");
  const revokes = () => calls.filter((one) => /revoke_token/.test(one.path)).length;
  const revoked0 = revokes();
  // Both held at the exchange until both are there, so both have read the
  // account as the connect found it: only the write decides.
  const exchange = reddit.exchange;
  let reached = 0;
  let bothThere;
  const there = new Promise((resolve) => { bothThere = resolve; });
  reddit.exchange = async (...args) => {
    reached += 1;
    if (reached === 2) bothThere();
    await Promise.race([there, new Promise((resolve) => { setTimeout(resolve, 3000); })]);
    return exchange(...args);
  };
  const finishes = await Promise.all(["mock-code-twinone1", "mock-code-twintwo2"].map((code) => admin("social_connected",
    { body: { provider: "reddit", code, state: state2 } })));
  reddit.exchange = exchange;
  const afterBoth = await admin("social_connected", { body: { provider: "reddit", code: "mock-code-after003", state: state2 } });
  out.state_once = { replay: replay.status, said: replay.json?.error, twins: finishes.map((one) => one.status).sort(),
    after: afterBoth.status, accounts: rows("social_accounts").length, tokens: rows("social_tokens").length,
    both_exchanged: reached === 2, handed_back: revokes() - revoked0 };
  process.env.REDDIT_CLIENT_ID = "check-only-id";
  process.env.REDDIT_CLIENT_SECRET = "check-only-secret";
  const redirects = {};
  for (const at of ["brickworks.diy", "www.brickworks.diy"]) {
    const got = await admin("social_connect", { body: { provider: "reddit" }, tests: false, at });
    redirects[at] = new URL(got.json?.authorize || "http://none/").searchParams.get("redirect_uri");
  }
  delete process.env.REDDIT_CLIENT_ID;
  delete process.env.REDDIT_CLIENT_SECRET;
  out.redirects = redirects;

  // 4. What came in: the inbox's replies, mention and message, and the search.
  const before = writes();
  const synced = await admin("social_sync");
  const again = await admin("social_sync");
  const read = await admin("social", { method: "GET" });
  const items = read.json?.items || [];
  out.sync = { status: synced.status, first: synced.json?.outcome, second: again.json?.outcome,
    kinds: items.map((one) => `${one.kind}:${one.detail}`).sort(), unread: items.filter((one) => !one.read).length,
    links: items.every((one) => /^https:\/\/www\.reddit\.com\//.test(one.url)) };
  const marked = await admin("social_mark", { body: { provider: "reddit", external_id: "t4_mk4001", read: true } });
  out.mark = { status: marked.status, read: rows("social_items").filter((one) => one.read_at).map((one) => one.external_id) };

  // 5. A community's rules, from Reddit (the mock), kept a day; and a missing one.
  const rules = await admin("social_rules", { method: "GET", query: { provider: "reddit", community: "lego" } });
  const missing = await admin("social_rules", { method: "GET", query: { provider: "reddit", community: "nosuchsub" } });
  out.rules = { status: rules.status, from: rules.json?.from, count: rules.json?.rules?.length, missing: missing.json?.from };

  // 6. Drafts: a post with the site's links tagged, a reply; nothing sent.
  const draft = await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "r/lego",
    title: "A free LEGO CAD in the browser", body: "Have a look: https://brickworks.diy/gallery, and https://example.com/x.",
    link: "" } });
  const post = draft.json?.send;
  out.draft = { status: draft.status, body: post?.body, campaign: post?.campaign, hash: /^[0-9a-f]{64}$/.test(post?.hash || "") };
  const reply = (await admin("social_draft", { body: { provider: "reddit", kind: "reply", parent: "t1_mkc001",
    body: "Yes: File, Export, LDraw." } })).json?.send;
  const orphan = await admin("social_draft", { body: { provider: "reddit", kind: "reply", parent: "t1_nothere", body: "x" } });
  out.reply_draft = { status: reply?.status, orphan: orphan.status };

  // 7. No send without the press on those exact words.
  const stale = await admin("social_send", { body: { id: post.id, hash: "0".repeat(64) } });
  const edited = (await admin("social_draft", { body: { id: post.id, provider: "reddit", kind: "post", community: "lego",
    title: "A free LEGO CAD in the browser!", body: post.body, link: "" } })).json?.send;
  const oldPress = await admin("social_send", { body: { id: post.id, hash: post.hash } });
  out.press = { wrong_hash: stale.status, old_words: oldPress.status, said: oldPress.json?.error, writes: writes() - before };

  // 8. Send now: one post at Reddit (the mock), its address kept.
  const sent = await admin("social_send", { body: { id: post.id, hash: edited.hash } });
  out.send = { status: sent.status, outcome: sent.json?.outcome, url: sent.json?.url, writes: writes() - before,
    row: rows("social_sends").find((one) => one.id === post.id)?.status,
    pressed_by: rows("social_sends").find((one) => one.id === post.id)?.pressed_by };
  const twice = await admin("social_send", { body: { id: post.id, hash: edited.hash } });
  out.send_twice = { status: twice.status, writes: writes() - before };

  // 9. A reply, scheduled: not before its time, then by the cron; edited
  //    after its press, it is a draft again and the cron leaves it.
  const at = new Date(Date.now() + 5 * 60000).toISOString();
  const soon = await admin("social_send", { body: { id: reply.id, hash: reply.hash, at: new Date(Date.now() + 1000).toISOString() } });
  const scheduled = await admin("social_send", { body: { id: reply.id, hash: reply.hash, at } });
  const cron = (token) => askPlans({ method: "GET", query: { op: "social_due" },
    headers: { host, "user-agent": "vercel-cron/1.0", ...(token ? { authorization: `Bearer ${token}` } : {}) } });
  const notCron = await cron("wrong");
  const early = await cron("cron-check-secret");
  answers.push(JSON.stringify(early.json));
  const writesBeforeDue = writes() - before;
  await behind("social_sends", reply.id, { send_at: new Date(Date.now() - 1000).toISOString() });
  const due = await cron("cron-check-secret");
  answers.push(JSON.stringify(due.json));
  out.schedule = { too_soon: soon.status, status: scheduled.status, outcome: scheduled.json?.outcome, not_cron: notCron.status,
    early: early.json?.outcome, writes_before_due: writesBeforeDue, due: due.json?.outcome, writes: writes() - before,
    row: rows("social_sends").find((one) => one.id === reply.id)?.status };

  const third = (await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "legodesign",
    title: "Designing in the browser", body: "Words." } })).json?.send;
  await admin("social_send", { body: { id: third.id, hash: third.hash, at } });
  const changedAnswer = await admin("social_draft", { body: { id: third.id, provider: "reddit", kind: "post", community: "legodesign",
    title: "Designing in the browser, changed", body: "Words." } });
  const changed = changedAnswer.json?.send;
  const fourth = (await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "LegoMOC",
    title: "Scheduled, then tampered with", body: "Words." } })).json?.send;
  await admin("social_send", { body: { id: fourth.id, hash: fourth.hash, at } });
  await behind("social_sends", fourth.id, { body: "Words a press never saw.", send_at: new Date(Date.now() - 1000).toISOString() });
  const writesBefore = writes();
  const later = await cron("cron-check-secret");
  answers.push(JSON.stringify(later.json));
  out.edit_after_press = { status: changed?.status, outcome: changedAnswer.json?.outcome, cron: later.json?.outcome, writes: writes() - writesBefore,
    tampered: rows("social_sends").find((one) => one.id === fourth.id)?.status,
    said: rows("social_sends").find((one) => one.id === fourth.id)?.said };
  const unscheduled = await admin("social_unschedule", { body: { id: third.id } });
  out.unschedule_draft = unscheduled.status;

  // 10. A row past a draft with no press: the database's own refusal.
  const direct = await fetch(`${process.env.SUPABASE_URL}/rest/v1/social_sends`, { method: "POST",
    headers: { "content-type": "application/json" }, body: JSON.stringify({ id: "zzzzzzzzzz", provider: "reddit", kind: "post",
      community: "lego", title: "t", status: "sent", sent_at: new Date().toISOString(), url: "https://www.reddit.com/r/lego/" }) });
  out.unpressed_row = { status: direct.status, said: (await direct.json().catch(() => ({}))).message };

  // 11. Results over time, and the visits a sent post's link brought.
  const resynced = await admin("social_sync");
  // A visitor is who the server sees (address and browser), never a number
  // the page sends: the same one twice, with two numbers, is one visit.
  const visit = (body, agent = "Visitor/1") => askPlans({ method: "POST", query: { op: "social_visit" },
    headers: { host, "user-agent": agent, "x-real-ip": "203.0.113.7" }, body });
  const v1 = await visit({ campaign: `bw-${post.id}`, nonce: "abcdefgh1234", path: "/gallery", source: "reddit" });
  await visit({ campaign: `bw-${post.id}`, nonce: "abcdefgh1234", path: "/gallery", source: "reddit" });
  await visit({ campaign: `bw-${post.id}`, nonce: "qqqqqqqq0000", path: "/gallery", source: "reddit" });
  await visit({ campaign: `bw-${post.id}`, nonce: "zyxwvuts9876", path: "/m/AbCdEfGhIj", source: "reddit" }, "Visitor/2");
  await visit({ campaign: "bw-nosuchsend", nonce: "abcdefgh1234", path: "/" });
  await visit({ campaign: `bw-${third.id}`, nonce: "abcdefgh5555", path: "/" });
  const after = await admin("social", { method: "GET" });
  const mine = after.json?.sends?.find((one) => one.id === post.id);
  out.results = { sync: resynced.json?.outcome, points: mine?.results?.length, score: mine?.results?.[0]?.score,
    visit_status: v1.status, visits: mine?.visits?.total, by_day: Object.values(mine?.visits?.by_day || {}),
    draft_visits: rows("social_visits").filter((one) => one.send === third.id).length };

  // 11b. The review's findings on the API route (sdreview, 2026-11-18).
  const draftOf = async (fields) => (await admin("social_draft", { body: { provider: "reddit", kind: "post", ...fields } })).json?.send;
  const rowOf = (id) => rows("social_sends").find((one) => one.id === id);
  const viewOf = async (id) => (await admin("social", { method: "GET" })).json?.sends?.find((one) => one.id === id);
  // A link and words together: refused, never sent with the link dropped.
  const both = await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego", title: "Both",
    body: "Words about it.", link: "https://brickworks.diy/gallery" } });
  out.link_and_words = { status: both.status, said: both.json?.error };
  // Reddit takes the post and its answer is lost: unsure, and never sent
  // again on that press, by Send, an edit or a drop.
  const realSend = reddit.send;
  const lost = await draftOf({ community: "lego", title: "Answer lost", body: "w" });
  const writesLost = writes();
  reddit.send = async (session, words) => {
    await realSend(session, words);
    throw new Error("The operation was aborted due to timeout");
  };
  const lostSend = await admin("social_send", { body: { id: lost.id, hash: lost.hash } });
  reddit.send = realSend;
  const lostView = await viewOf(lost.id);
  out.answer_lost = { status: lostSend.status, said: lostSend.json?.error, row: rowOf(lost.id)?.status, unsure: lostView?.unsure,
    resend: (await admin("social_send", { body: { id: lost.id, hash: lost.hash } })).status,
    edit: (await admin("social_draft", { body: { id: lost.id, provider: "reddit", kind: "post", community: "lego", title: "Answer lost",
      body: "w" } })).status,
    drop: (await admin("social_drop", { body: { id: lost.id } })).status, posts: writes() - writesLost };
  // ...found up: its address kept.
  const found = await admin("social_posted", { body: { id: lost.id, url: "https://www.reddit.com/r/lego/comments/abc999/answer_lost/" } });
  out.answer_lost.found = found.json?.send?.status;
  // ...not up: back to the drafts, and a fresh press sends it once.
  const lost2 = await draftOf({ community: "lego", title: "Answer lost again", body: "w" });
  reddit.send = async () => { throw new TypeError("fetch failed"); };
  await admin("social_send", { body: { id: lost2.id, hash: lost2.hash } });
  reddit.send = realSend;
  const writesBack = writes();
  const back = await admin("social_unschedule", { body: { id: lost2.id } });
  const fresh = await admin("social_send", { body: { id: lost2.id, hash: back.json?.send?.hash } });
  out.not_up = { back: back.json?.outcome, status_after_back: back.json?.send?.status, fresh: fresh.json?.outcome,
    posts: writes() - writesBack };
  // Reddit's own no is "did not go": nothing is there, and it may be pressed again.
  const refusedPost = await draftOf({ community: "lego", title: "Refused", body: "w" });
  reddit.send = async () => { throw new SocialRefusal("Reddit did not take the post: SUBREDDIT_NOTALLOWED.", 409); };
  const refusal = await admin("social_send", { body: { id: refusedPost.id, hash: refusedPost.hash } });
  reddit.send = realSend;
  out.reddit_refused = { status: refusal.status, row: rowOf(refusedPost.id)?.status, unsure: (await viewOf(refusedPost.id))?.unsure };
  // Cut off mid-send: in flight for five minutes, then unsure, and taken back.
  const cut = await draftOf({ community: "lego", title: "Cut off", body: "w" });
  const pressed = { status: "sending", route: "api", pressed_at: new Date().toISOString(), pressed_by: "owner@example.com",
    pressed_hash: cut.hash };
  await behind("social_sends", cut.id, { ...pressed, changed_at: new Date().toISOString() });
  const inFlight = { unsure: (await viewOf(cut.id))?.unsure, back: (await admin("social_unschedule", { body: { id: cut.id } })).status };
  await behind("social_sends", cut.id, { changed_at: new Date(Date.now() - 6 * 60000).toISOString() });
  out.cut_off = { in_flight: inFlight, unsure: (await viewOf(cut.id))?.unsure,
    back: (await admin("social_unschedule", { body: { id: cut.id } })).json?.outcome };
  // Wrong types refused, not kept as their String(); a title counted in characters.
  const typed = (fields) => admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego", title: "t", body: "w",
    ...fields } }).then((got) => got.status);
  out.types = { body_object: await typed({ body: { a: 1 } }), title_list: await typed({ title: ["x", "y"] }),
    community_list: await typed({ community: ["lego"] }),
    hash_list: (await admin("social_send", { body: { id: cut.id, hash: [cut.hash] } })).status,
    emoji_title: await typed({ title: "😀".repeat(200) }), emoji_over: await typed({ title: "😀".repeat(301) }) };

  // 12. Disconnect: the tokens taken back and gone; a post then goes by hand.
  const left = await admin("social_disconnect", { body: { provider: "reddit" } });
  out.disconnect = { status: left.status, revoked: left.json?.revoked, tokens: rows("social_tokens").length,
    accounts: rows("social_accounts").length, kept_sends: rows("social_sends").length };
  const byHand = (await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego",
    title: "By hand", body: "Posted by the owner: https://brickworks.diy/" } })).json?.send;
  const writesHand = writes();
  const handed = await admin("social_send", { body: { id: byHand.id, hash: byHand.hash } });
  const wrongUrl = await admin("social_posted", { body: { id: byHand.id, url: "https://example.com/r/lego/comments/abc/" } });
  const posted = await admin("social_posted", { body: { id: byHand.id,
    url: "https://www.reddit.com/r/lego/comments/abc123/by_hand/" } });
  out.by_hand = { status: handed.status, outcome: handed.json?.outcome, hand_off: handed.json?.hand_off?.split("?")[0],
    hand_text: new URL(handed.json?.hand_off || "http://x/").searchParams.get("text"), writes: writes() - writesHand,
    wrong_url: wrongUrl.status, posted: posted.json?.send?.status, external_id: posted.json?.send?.external_id };

  // 12b. By hand (sdreview): a long post's address, a handed send taken back
  //      or dropped, the right kind of address, a reply to a message.
  const long = await draftOf({ community: "lego", title: "Long", body: "word ".repeat(3000).trim() });
  const longSend = await admin("social_send", { body: { id: long.id, hash: long.hash } });
  out.long_by_hand = { filled_before: long.hand_off_filled, filled: longSend.json?.hand_off_filled,
    length: longSend.json?.hand_off?.length, text_in_address: new URL(longSend.json?.hand_off || "http://x/").searchParams.has("text") };
  const short = await draftOf({ community: "lego", title: "Short", body: "A few words." });
  out.long_by_hand.short_filled = short.hand_off_filled;
  out.handed_back = { back: (await admin("social_unschedule", { body: { id: long.id } })).json?.outcome,
    row: rowOf(long.id)?.status, pressed: rowOf(long.id)?.pressed_hash ?? null };
  await admin("social_send", { body: { id: short.id, hash: short.hash } });
  out.handed_back.drop = (await admin("social_drop", { body: { id: short.id } })).status;
  out.handed_back.gone = rowOf(short.id) === undefined;
  const third2 = await draftOf({ community: "lego", title: "Marked", body: "w" });
  await admin("social_send", { body: { id: third2.id, hash: third2.hash } });
  const pasted = (url) => admin("social_posted", { body: { id: third2.id, url } }).then((got) => got.status);
  out.paste = { comment_for_post: await pasted("https://www.reddit.com/r/lego/comments/abc123/x/def456/"),
    share_link: await pasted("https://www.reddit.com/r/lego/s/AbCdEf12"),
    said: (await admin("social_posted", { body: { id: third2.id, url: "https://redd.it/abc123" } })).json?.error,
    post: await pasted("https://www.reddit.com/r/lego/comments/abc124/marked/") };
  const pm = (await admin("social_draft", { body: { provider: "reddit", kind: "reply", parent: "t4_mk4001", body: "Thanks!" } })).json?.send;
  const pmSend = await admin("social_send", { body: { id: pm.id, hash: pm.hash } });
  const pmPosted = await admin("social_posted", { body: { id: pm.id, url: "" } });
  out.message_reply = { handed: pmSend.json?.outcome, posted: pmPosted.json?.send?.status, url: pmPosted.json?.send?.url };

  // 12d. A reply by hand to any post or comment, by its address (redditway:
  //      no inbox without Reddit's API, and its RSS ended 2026-11-13).
  const byAddress = (address, words = "Lovely build!") => admin("social_draft", { body: { provider: "reddit", kind: "reply", address,
    body: words } });
  const toComment = await byAddress("https://old.reddit.com/r/lego/comments/abc777/a_castle/def888/?context=3#x");
  const toPost = await byAddress("https://www.reddit.com/r/legomoc/comments/abc999/", "Which bricks? https://brickworks.diy/gallery");
  const refusedTo = {};
  for (const [name, address] of [["share", "https://www.reddit.com/r/lego/s/AbCdEf12"], ["redd_it", "https://redd.it/abc777"],
    ["subreddit", "https://www.reddit.com/r/lego/"], ["other", "https://example.com/r/lego/comments/abc777/"],
    ["script", "javascript:alert(1)"], ["none", ""]]) {
    const got = await byAddress(address);
    refusedTo[name] = got.status;
  }
  const comment = toComment.json?.send;
  const handedTo = await admin("social_send", { body: { id: comment?.id, hash: comment?.hash } });
  const listed = (await admin("social", { method: "GET" })).json?.sends?.find((one) => one.id === comment?.id);
  // Edited once handed: a draft again, still answering the same comment.
  const reEdited = await admin("social_draft", { body: { provider: "reddit", kind: "reply", id: comment?.id, address: "https://www.reddit.com/r/x/comments/zzz111/",
    body: "Lovely build, truly!" } });
  const handedAgain = await admin("social_send", { body: { id: comment?.id, hash: reEdited.json?.send?.hash } });
  const replyPosted = await admin("social_posted", { body: { id: comment?.id,
    url: "https://www.reddit.com/r/lego/comments/abc777/a_castle/ghi999/" } });
  out.reply_by_address = {
    comment: { status: toComment.status, parent: comment?.parent, link: comment?.link, community: comment?.community },
    post: { status: toPost.status, parent: toPost.json?.send?.parent, link: toPost.json?.send?.link,
      tagged: /utm_campaign=bw-/.test(toPost.json?.send?.body || "") },
    refused: refusedTo, said: (await byAddress("https://redd.it/abc777")).json?.error,
    handed: { outcome: handedTo.json?.outcome, hand_off: handedTo.json?.hand_off, filled: handedTo.json?.hand_off_filled, listed: listed?.hand_off },
    edited: { outcome: reEdited.json?.outcome, parent: reEdited.json?.send?.parent, link: reEdited.json?.send?.link },
    again: handedAgain.json?.hand_off,
    posted: { status: replyPosted.json?.send?.status, external_id: rowOf(comment?.id)?.external_id, url: replyPosted.json?.send?.url },
  };

  // 12c. Two Keeps of one new draft at once are one draft, both answered
  //      with it (sdreview's double_keep_new); a schedule older than the
  //      newest 300 is still listed, and what is not listed is counted (L10).
  const keptBefore = rows("social_sends").length;
  const twinKeeps = await Promise.all([1, 2].map(() => admin("social_draft", { body: { provider: "reddit", kind: "post",
    community: "lego", title: "Twice", body: "Both at once: https://brickworks.diy/gallery" } })));
  out.twin_keeps = { statuses: twinKeeps.map((one) => one.status), made: rows("social_sends").length - keptBefore,
    same: twinKeeps[0].json?.send?.id === twinKeeps[1].json?.send?.id,
    tagged: twinKeeps.map((one) => one.json?.send?.body.includes(`bw-${one.json?.send?.id}`)) };
  const apart = await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego", title: "Twice",
    body: "Both at once: https://brickworks.diy/gallery!" } });
  out.twin_keeps.other_words = apart.json?.send?.id !== twinKeeps[0].json?.send?.id;
  // Kept again at once (its answer lost): the same draft. Twenty seconds on: a second.
  const keepTwice = () => admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego", title: "Twice",
    body: "Both at once: https://brickworks.diy/gallery" } }).then((got) => got.json?.send?.id);
  out.twin_keeps.retried = (await keepTwice()) === twinKeeps[0].json?.send?.id;
  await behind("social_sends", twinKeeps[0].json?.send?.id, { made_at: new Date(Date.now() - 25000).toISOString() });
  out.twin_keeps.later = (await keepTwice()) !== twinKeeps[0].json?.send?.id;
  const old = await draftOf({ community: "lego", title: "Long ago", body: "w" });
  await admin("social_send", { body: { id: old.id, hash: old.hash, at: new Date(Date.now() + 864e5).toISOString() } });
  await behind("social_sends", old.id, { changed_at: "2026-01-01T00:00:00.000Z" });
  for (let n = 0; n < 300; n += 1) {
    await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "lego", title: `Many ${n}`, body: "w" } });
  }
  const many = await admin("social", { method: "GET" });
  out.listed = { total: rows("social_sends").length, listed: many.json?.sends?.length, unlisted: many.json?.unlisted,
    old_scheduled: many.json?.sends?.find((one) => one.id === old.id)?.status ?? null };

  // 13. Tokens: in no answer and no line logged.
  const text = answers.join("\n");
  out.tokens_in_answers = (text.match(/mocktoken-[ar]-/g) || []).length;
  out.tokens_in_logs = logged.filter((one) => /mocktoken-[ar]-/.test(one)).length;
  out.logged = logged.length;
  out.calls_with_token_in_path = calls.filter((one) => /mocktoken/.test(one.path)).length;
} catch (trouble) {
  out.error = String(trouble?.stack || trouble).slice(0, 2000);
}
process.stdout.write(`${JSON.stringify(out)}\n`);
