// Feedback's API (api/_feedback.js through api/plans.js, api/admin.js and
// api/account.js) against supabase/beta.sql and feedback.sql themselves,
// in tests/fixtures/beta/pg.mjs's Postgres: what tests/test_feedback.py asks
// of it. The database's functions are answered by the real files, as
// PostgREST would call them; the 'feedback' bucket and Resend are answered
// here, every file and email kept.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/feedback/api_check.mjs
//
// Prints one JSON object, each scenario's findings by name.
import { askAccount, askAdmin, askPlans, SUPABASE_URL, world } from "../billing/world.mjs";
import { startPostgres } from "../beta/pg.mjs";

const db = await startPostgres({ also: ["supabase/feedback.sql"] });
const out = {};
const mails = [];
const bucket = new Map();
let storageDown = false;
let noSql = false;

// A real PNG's first bytes and a real JPEG's, as base64.
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(64, 7)]);
const JPEG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(64, 9)]);
const MODEL = "0 FILE crane.ldr\n0 Crane\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n";

try {
  const w = await world({ billing: "" });
  const stood = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const rpc = /^\/rest\/v1\/rpc\/((?:beta|feedback)_[a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && rpc) {
      w.calls.push(`POST ${url.origin}${url.pathname}`);
      if (noSql && rpc[1].startsWith("feedback_") || noSql && rpc[1] === "beta_tester") {
        return new Response(JSON.stringify({ message: "not there" }), { status: 404 });
      }
      try {
        const answer = await db.rpc(rpc[1], JSON.parse(String(init.body || "{}")));
        return new Response(JSON.stringify(answer), { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    const file = /^\/storage\/v1\/object\/feedback(?:\/(.+))?$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && file) {
      const method = (init.method || "GET").toUpperCase();
      if (storageDown) return new Response("{}", { status: 500 });
      if (method === "POST") {
        bucket.set(file[1], { type: new Headers(init.headers).get("content-type"), bytes: Buffer.from(init.body) });
        return new Response("{}", { status: 200 });
      }
      if (method === "DELETE") {
        for (const name of JSON.parse(String(init.body)).prefixes) bucket.delete(name);
        return new Response("[]", { status: 200 });
      }
      const kept = bucket.get(file[1]);
      return kept ? new Response(kept.bytes, { status: 200 }) : new Response("{}", { status: 404 });
    }
    if (url.origin === "https://api.resend.com") {
      mails.push(JSON.parse(String(init.body)));
      return new Response(JSON.stringify({ id: `re-${mails.length}` }), { status: 200 });
    }
    return stood(input, init);
  };
  const owner = await w.signIn({ sub: "00000000-0000-4000-8000-0000000000ff", email: "owner@example.com" });
  const asOwner = { authorization: `Bearer ${owner}` };
  const send = (body, token, headers = {}) => askPlans({ method: "POST", query: { op: "feedback" },
    headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers }, body });

  // Signed in: kept with the account, the picture and the model stored.
  const adaId = await db.user("ada@example.com");
  const ada = await w.signIn({ sub: adaId, email: "ada@example.com" });
  out.sent = await send({ kind: "bug", words: "  The hinge\r\n\r\n\r\nturns the wrong way.  ", source: "app", page: "desktop",
    details: { version: "0.10.0", platform: "Linux", "Bad Key": "x", screen: "1400x900", long: "y".repeat(300) },
    log: "line one\nline two", picture: { type: "image/png", data: PNG.toString("base64") },
    model: { name: "Crane", text: MODEL } }, ada);
  out.bucket = [...bucket.entries()].map(([name, kept]) => ({ name, type: kept.type, size: kept.bytes.length }));
  out.mine = await askPlans({ query: { op: "feedback" }, headers: { authorization: `Bearer ${ada}` } });
  out.mine_signed_out = await askPlans({ query: { op: "feedback" } });

  // Signed out: an address asked for; a JPEG; from one place five an hour.
  out.signed_out_no_email = await send({ kind: "idea", words: "A dark baseplate" });
  out.signed_out = await send({ kind: "idea", words: "A dark baseplate", email: " Visitor@Example.com ",
    source: "site", page: "/gallery", picture: { type: "image/jpeg", data: JPEG.toString("base64") } },
  null, { "x-real-ip": "203.0.113.9" });
  out.place_rate = [];
  for (let n = 0; n < 6; n += 1) {
    out.place_rate.push((await send({ kind: "question", words: "Is it free?", email: `v${n}@example.com` }, null,
      { "x-real-ip": "203.0.113.7" })).status);
  }
  // A token that has ended is not taken for signed out.
  out.ended_token = await send({ kind: "bug", words: "Broken", email: "x@example.com" }, "not-a-token");

  // Refused at the edge, each in words.
  const refusals = {
    kind: { kind: "rant", words: "Bad" },
    short: { kind: "bug", words: " a " },
    long: { kind: "bug", words: "x".repeat(4001) },
    not_words: { kind: "bug", words: 42 },
    picture_kind: { kind: "bug", words: "See this", picture: { type: "image/gif", data: "R0lGOD" } },
    picture_bytes: { kind: "bug", words: "See this", picture: { type: "image/png", data: Buffer.from("<svg/>").toString("base64") } },
    picture_big: { kind: "bug", words: "See this", picture: { type: "image/png",
      data: Buffer.concat([PNG, Buffer.alloc(1_500_001)]).toString("base64") } },
    model_text: { kind: "bug", words: "My model", model: { name: "x", text: "<html>not a model</html>" } },
    model_big: { kind: "bug", words: "My model", model: { name: "x", text: `0 big\n${"0 ".padEnd(1_500_001, "x")}` } },
    log: { kind: "bug", words: "Logs", log: ["a"] },
  };
  out.refused = {};
  for (const [name, body] of Object.entries(refusals)) {
    const said = await send(body, ada);
    out.refused[name] = [said.status, said.json?.error];
  }
  out.signed_out_bad_email = (await send({ kind: "bug", words: "Broken", email: "not an address" })).json;

  // A storage outage: the report kept, the picture said not to have gone.
  storageDown = true;
  out.storage_down = await send({ kind: "bug", words: "See this", picture: { type: "image/png", data: PNG.toString("base64") } }, ada);
  storageDown = false;

  // A tester: approved by beta.sql; their reports marked beta; the account
  // says so, with the early features; the hub opens for them alone.
  const boId = await db.user("delivered+bw-feedback-bo@resend.dev");
  const bo = await w.signIn({ sub: boId, email: "delivered+bw-feedback-bo@resend.dev" });
  out.account_before = (await askAccount({ headers: { authorization: `Bearer ${bo}` } })).json?.beta;
  out.hub_before = await askPlans({ query: { op: "beta_hub" }, headers: { authorization: `Bearer ${bo}` } });
  await db.rpc("beta_apply", { p_account: boId, p_build: "A working crane with a slewing ring and a two-speed winch",
    p_ai: "claude", p_background: "lego", p_background_line: "", p_link: null, p_terms: "2026-10-29", p_signals: {} });
  await db.rpc("beta_decide", { p_account: boId, p_decision: "approve", p_note: null, p_by: "owner@example.com" });
  out.account_tester = (await askAccount({ headers: { authorization: `Bearer ${bo}` } })).json?.beta;
  out.hub = await askPlans({ query: { op: "beta_hub" }, headers: { authorization: `Bearer ${bo}` } });
  out.hub_signed_out = (await askPlans({ query: { op: "beta_hub" } })).status;
  out.from_tester = await send({ kind: "idea", words: "Let me pin a part", source: "site", page: "/beta-hub" }, bo);

  // The owner's inbox, and nobody else's.
  out.inbox_stranger = await askAdmin({ query: { op: "feedback" }, headers: { authorization: `Bearer ${ada}` } });
  out.inbox = await askAdmin({ query: { op: "feedback" }, headers: asOwner });
  out.inbox_tests = await askAdmin({ query: { op: "feedback", tests: "1" }, headers: asOwner });
  out.inbox_ideas = await askAdmin({ query: { op: "feedback", kind: "idea" }, headers: asOwner });
  out.inbox_not_beta = await askAdmin({ query: { op: "feedback", beta: "0", tests: "1" }, headers: asOwner });
  out.inbox_bad = [(await askAdmin({ query: { op: "feedback", kind: "rant" }, headers: asOwner })).status,
    (await askAdmin({ query: { op: "feedback", status: "done" }, headers: asOwner })).status];

  // A file, to the owner alone, as its bytes.
  const { default: admin } = await import("../../../api/admin.js");
  const fetched = async (query, token) => {
    const got = { status: 0, headers: {}, bytes: null };
    const response = {
      setHeader: (name, value) => { got.headers[name.toLowerCase()] = value; return response; },
      status: (s) => { got.status = s; return response; },
      json: (b) => { got.json = b; return response; },
      end: (b) => { got.bytes = b ? Buffer.from(b) : null; return response; },
    };
    await admin({ method: "GET", query, headers: { authorization: `Bearer ${token}` } }, response);
    return got;
  };
  const id = out.sent.json?.id;
  const picture = await fetched({ op: "feedback_file", id: String(id), file: "picture" }, owner);
  out.file_picture = { status: picture.status, type: picture.headers["content-type"], same: picture.bytes?.equals(PNG) };
  const model = await fetched({ op: "feedback_file", id: String(id), file: "model" }, owner);
  out.file_model = { status: model.status, type: model.headers["content-type"], disposition: model.headers["content-disposition"],
    text: model.bytes?.toString() };
  out.file_stranger = (await fetched({ op: "feedback_file", id: String(id), file: "picture" }, ada)).status;
  out.file_none = (await fetched({ op: "feedback_file", id: String(out.from_tester.json?.id), file: "picture" }, owner)).status;

  // Triage: a status and a note the sender never sees.
  const triage = (rid, body) => askAdmin({ method: "POST", query: { op: "feedback_triage", id: String(rid) }, headers: asOwner, body });
  out.triaged = await triage(id, { status: "planned", note: "For 0.11" });
  out.triage_bad = (await triage(id, { status: "done" })).status;
  out.triage_none = (await triage(999999, { status: "seen" })).status;
  out.triage_stranger = (await askAdmin({ method: "POST", query: { op: "feedback_triage", id: String(id) },
    headers: { authorization: `Bearer ${ada}` }, body: { status: "fixed" } })).status;

  // An answer: emailed from BETA_REPLY_TO, and kept; a test inbox with no
  // mail key here is dry.
  process.env.BETA_REPLY_TO = "beta@brickworks.diy";
  process.env.RESEND_API_KEY = "re_test_key";
  const reply = (rid, words) => askAdmin({ method: "POST", query: { op: "feedback_reply", id: String(rid) }, headers: asOwner,
    body: { words } });
  out.replied = await reply(id, "Thank you, Ada.\nIt is planned for 0.11.");
  out.reply_mail = mails.map((one) => ({ to: one.to, reply_to: one.reply_to, subject: one.subject, text: one.text,
    has_html: /^<!doctype html>/.test(one.html || "") }));
  out.replied_signed_out = await reply(out.signed_out.json?.id, "Noted: a dark baseplate.");
  out.reply_signed_out_text = mails.at(-1)?.text;
  delete process.env.RESEND_API_KEY;
  out.replied_tester = await reply(out.from_tester.json?.id, "Pinning is on the list.");
  out.reply_empty = (await reply(id, " ")).status;
  out.mine_after = (await askPlans({ query: { op: "feedback" }, headers: { authorization: `Bearer ${ada}` } })).json;

  // Deleting the account deletes its files, then its reports with it.
  const files = bucket.size;
  out.deleted = await askAccount({ method: "POST", query: { op: "delete" }, headers: { authorization: `Bearer ${ada}` },
    body: { confirm: "ada@example.com" } });
  await db.q("delete from auth.users where id = $1", [adaId]);
  out.files_after_delete = [files, bucket.size, [...bucket.keys()]];

  // The daily run sweeps the checks' own after a day, with their files.
  process.env.CRON_SECRET = "cron";
  await db.q("update public.feedback set at = now() - interval '2 days' where test");
  out.daily = await askPlans({ query: { op: "beta_daily" }, headers: { authorization: "Bearer cron" } });

  // Before feedback.sql: words, never a crash.
  noSql = true;
  out.no_sql_send = await send({ kind: "bug", words: "Broken", email: "x@example.com" });
  out.no_sql_inbox = await askAdmin({ query: { op: "feedback" }, headers: asOwner });
  out.no_sql_account = (await askAccount({ headers: { authorization: `Bearer ${bo}` } })).json?.beta;
  out.no_sql_hub = await askPlans({ query: { op: "beta_hub" }, headers: { authorization: `Bearer ${bo}` } });
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
