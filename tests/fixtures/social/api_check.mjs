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
  async function admin(op, { method = "POST", body, query = {}, token = owner, tests = true } = {}) {
    const got = await askAdmin({ method, query: { op, ...(tests ? { tests: "1" } : {}), ...query },
      headers: { host, ...(token ? { authorization: `Bearer ${token}` } : {}) }, body });
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
  const changed = (await admin("social_draft", { body: { id: third.id, provider: "reddit", kind: "post", community: "legodesign",
    title: "Designing in the browser, changed", body: "Words." } })).json?.send;
  const fourth = (await admin("social_draft", { body: { provider: "reddit", kind: "post", community: "LegoMOC",
    title: "Scheduled, then tampered with", body: "Words." } })).json?.send;
  await admin("social_send", { body: { id: fourth.id, hash: fourth.hash, at } });
  await behind("social_sends", fourth.id, { body: "Words a press never saw.", send_at: new Date(Date.now() - 1000).toISOString() });
  const writesBefore = writes();
  const later = await cron("cron-check-secret");
  answers.push(JSON.stringify(later.json));
  out.edit_after_press = { status: changed?.status, cron: later.json?.outcome, writes: writes() - writesBefore,
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
  const visit = (body) => askPlans({ method: "POST", query: { op: "social_visit" }, headers: { host }, body });
  const v1 = await visit({ campaign: `bw-${post.id}`, nonce: "abcdefgh1234", path: "/gallery", source: "reddit" });
  await visit({ campaign: `bw-${post.id}`, nonce: "abcdefgh1234", path: "/gallery", source: "reddit" });
  await visit({ campaign: `bw-${post.id}`, nonce: "zyxwvuts9876", path: "/m/AbCdEfGhIj", source: "reddit" });
  await visit({ campaign: "bw-nosuchsend", nonce: "abcdefgh1234", path: "/" });
  await visit({ campaign: `bw-${third.id}`, nonce: "abcdefgh5555", path: "/" });
  const after = await admin("social", { method: "GET" });
  const mine = after.json?.sends?.find((one) => one.id === post.id);
  out.results = { sync: resynced.json?.outcome, points: mine?.results?.length, score: mine?.results?.[0]?.score,
    visit_status: v1.status, visits: mine?.visits?.total, by_day: Object.values(mine?.visits?.by_day || {}),
    draft_visits: rows("social_visits").filter((one) => one.send === third.id).length };

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
