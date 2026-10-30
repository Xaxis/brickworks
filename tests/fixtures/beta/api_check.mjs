// The beta's API (api/_beta.js through api/plans.js and api/admin.js)
// against supabase/beta.sql itself, in pg.mjs's Postgres, with the stand-in
// Admission (tests/fixtures/billing/): what tests/test_beta.py asks of it.
// The database's functions are answered by the real file, as PostgREST
// would call them; Resend is answered here, every email kept.
//
//   PG_MODULE=... PG_BIN=... node tests/fixtures/beta/api_check.mjs
//
// Prints one JSON object, each scenario's findings by name.
import { askAdmin, askPlans, SUPABASE_URL, world } from "../billing/world.mjs";
import { startPostgres } from "./pg.mjs";

const db = await startPostgres();
const out = {};
const mails = [];
let resendDown = false;

try {
  const w = await world({ billing: "test" });
  const stood = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const rpc = /^\/rest\/v1\/rpc\/(beta_[a-z_]+)$/.exec(url.pathname);
    if (url.origin === SUPABASE_URL && rpc) {
      w.calls.push(`POST ${url.origin}${url.pathname}`);
      try {
        const answer = await db.rpc(rpc[1], JSON.parse(String(init.body || "{}")));
        return new Response(JSON.stringify(answer), { status: 200 });
      } catch (trouble) {
        return new Response(JSON.stringify({ message: String(trouble.message) }), { status: 400 });
      }
    }
    if (url.origin === "https://api.resend.com") {
      const sent = JSON.parse(String(init.body));
      mails.push({ ...sent, key: new Headers(init.headers).get("authorization") });
      if (resendDown) return new Response("{}", { status: 500 });
      return new Response(JSON.stringify({ id: `re-${mails.length}` }), { status: 200 });
    }
    return stood(input, init);
  };
  const owner = await w.signIn({ sub: "00000000-0000-4000-8000-0000000000ff", email: "owner@example.com" });
  const asOwner = { authorization: `Bearer ${owner}` };
  const callsTo = (what) => w.calls.filter((one) => one.includes(what)).length;

  // Off: nothing asked of the database, and nothing taken.
  delete process.env.BRICKWORKS_BETA;
  const before = w.calls.length;
  out.off_get = await askPlans({ query: { op: "beta" } });
  const adaId = await db.user("ada@example.com");
  const ada = await w.signIn({ sub: adaId, email: "ada@example.com" });
  const form = { build: "A working crane with a slewing ring and a two-speed winch", ai: "claude", background: "lego",
    background_line: "Ten years of Technic", link: "rebrickable.com/users/ada/mocs/", terms: true, emails: true };
  out.off_post = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${ada}` }, body: form });
  out.off_calls = w.calls.slice(before);
  out.spots_off = await askPlans({ query: { op: "beta_spots" } });

  process.env.BRICKWORKS_BETA = "open";
  out.open_signed_out = await askPlans({ query: { op: "beta" } });
  out.spots_open = await askPlans({ query: { op: "beta_spots" }, headers: { authorization: "Bearer not-a-token" } });
  out.post_signed_out = await askPlans({ method: "POST", query: { op: "beta" }, body: form });
  // Refused at the edge, each in words.
  const refusals = {
    short: { ...form, build: "a crane" },
    long: { ...form, build: "x".repeat(801) },
    ai: { ...form, ai: "gemini" },
    background: { ...form, background: "" },
    line: { ...form, background_line: "y".repeat(161) },
    link: { ...form, link: "javascript:alert(1)" },
    http_link: { ...form, link: "http://example.com/me" },
    terms: { ...form, terms: false },
    emails: { ...form, emails: undefined },
    not_words: { ...form, build: 42 },
  };
  out.refused = {};
  for (const [name, body] of Object.entries(refusals)) {
    const said = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${ada}` }, body });
    out.refused[name] = [said.status, said.json?.error];
  }

  // Applied: kept, emailed (dry: no mail key here, a test inbox would be), once.
  delete process.env.RESEND_API_KEY;
  const testerId = await db.user("delivered+beta-a@resend.dev");
  const tester = await w.signIn({ sub: testerId, email: "delivered+beta-a@resend.dev" });
  out.applied = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${tester}` }, body: form });
  out.applied_again = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${tester}` }, body: form });
  out.tester_status = await askPlans({ query: { op: "beta" }, headers: { authorization: `Bearer ${tester}` } });
  out.tester_mail = await db.rpc("beta_mail_of", { p_account: testerId });
  // A real address with the mail key: sent through Resend, with its id kept.
  process.env.RESEND_API_KEY = "re_test_key";
  out.ada_applied = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${ada}` }, body: form });
  out.ada_mail = await db.rpc("beta_mail_of", { p_account: adaId });
  out.sent = mails.map((one) => ({ to: one.to, subject: one.subject, from: one.from, has_text: Boolean(one.text),
    has_html: /^<!doctype html>/.test(one.html || "") }));
  out.received_text = mails[0]?.text;

  // The owner's queue, and nobody else's.
  out.queue_stranger = await askAdmin({ query: { op: "beta" }, headers: { authorization: `Bearer ${ada}` } });
  const queue = await askAdmin({ query: { op: "beta", tests: "1" }, headers: asOwner });
  out.queue = { status: queue.status, beta: queue.json?.beta, months: queue.json?.months, pool: queue.json?.pool,
    counts: queue.json?.counts, first: queue.json?.applications?.[0] };
  out.queue_real = (await askAdmin({ query: { op: "beta" }, headers: asOwner })).json?.applications?.map((a) => a.email);
  out.queue_bad_status = (await askAdmin({ query: { op: "beta", status: "everything" }, headers: asOwner })).status;

  // Approved, a tester: spot 1 of the checks' pool, and its month given at
  // Admission's test mode at once.
  mails.length = 0;
  const approve = (id, note) => askAdmin({ method: "POST", query: { op: "beta_decide", account: id }, headers: asOwner,
    body: { decision: "approve", note } });
  out.approved = await approve(testerId, "Good crane");
  out.comps_asked = w.admission.compsAsked;
  out.approved_mail = mails.map((one) => ({ subject: one.subject, text: one.text }));
  out.approved_again = await approve(testerId);
  out.comps_asked_again = w.admission.compsAsked.length;
  out.tester_after = (await askPlans({ query: { op: "beta" }, headers: { authorization: `Bearer ${tester}` } })).json;

  // Approved, a real applicant while billing is test: spot 1 of the 100,
  // its month waiting for Pro to launch; nothing asked of Admission.
  const comps = w.admission.compsAsked.length;
  out.ada_approved = await approve(adaId);
  out.ada_comps_asked = w.admission.compsAsked.length - comps;
  out.ada_after = (await askPlans({ query: { op: "beta" }, headers: { authorization: `Bearer ${ada}` } })).json;
  out.ada_approved_text = mails.at(-1)?.text;

  // Admission refusing: the month waits, and the owner reads why.
  const offId = await db.user("delivered+beta-off@resend.dev");
  const off = await w.signIn({ sub: offId, email: "delivered+beta-off@resend.dev" });
  await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${off}` }, body: form });
  w.admission.apiCompsLimit = null;
  out.comps_off = await approve(offId);
  const fullId = await db.user("delivered+beta-full@resend.dev");
  const full = await w.signIn({ sub: fullId, email: "delivered+beta-full@resend.dev" });
  await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${full}` }, body: form });
  w.admission.apiCompsLimit = 1;
  out.comps_full = await approve(fullId);
  // Grant pending months, once the owner has set the limit: both given,
  // each mailed that it started; again, nothing more.
  w.admission.apiCompsLimit = 100;
  mails.length = 0;
  out.grant = await askAdmin({ method: "POST", query: { op: "beta_grant" }, headers: asOwner });
  out.grant_mail = mails.map((one) => one.subject);
  out.grant_again = await askAdmin({ method: "POST", query: { op: "beta_grant" }, headers: asOwner });
  out.queue_pending = (await askAdmin({ query: { op: "beta", tests: "1" }, headers: asOwner })).json?.counts;

  // A month Admission gave once and that has ended (or was revoked):
  // asked again, Admission answers the old one unchanged, and the queue says
  // so rather than counting it given.
  const onceId = await db.user("delivered+beta-once@resend.dev");
  const once = await w.signIn({ sub: onceId, email: "delivered+beta-once@resend.dev" });
  await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${once}` }, body: form });
  await w.admission.fetch(`https://admission.test/v1/customers/${onceId}/comps/beta`, { method: "PUT",
    headers: { authorization: "Bearer adm_test_00000000000000000000000000000000" }, body: JSON.stringify({ plan: "pro", days: 30 }) });
  w.admission.endedComp(onceId, "beta");
  out.once = (await approve(onceId)).json;
  out.once_again = (await askAdmin({ method: "POST", query: { op: "beta_grant" }, headers: asOwner })).json;
  out.once_queue = (await askAdmin({ query: { op: "beta", tests: "1", status: "approved" }, headers: asOwner })).json
    ?.applications?.find((one) => one.account === onceId);

  // Declined: emailed kindly, and may apply again in 30 days.
  const deeId = await db.user("delivered+beta-dee@resend.dev");
  const dee = await w.signIn({ sub: deeId, email: "delivered+beta-dee@resend.dev" });
  await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${dee}` }, body: form });
  mails.length = 0;
  out.declined = await askAdmin({ method: "POST", query: { op: "beta_decide", account: deeId }, headers: asOwner,
    body: { decision: "decline", note: "Thin" } });
  out.declined_mail = mails.map((one) => ({ subject: one.subject, text: one.text }));
  out.dee_again = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${dee}` }, body: form });
  out.decline_approved = await askAdmin({ method: "POST", query: { op: "beta_decide", account: testerId }, headers: asOwner,
    body: { decision: "decline" } });
  out.decide_nobody = await askAdmin({ method: "POST", query: { op: "beta_decide", account: "00000000-0000-4000-8000-0000000000aa" },
    headers: asOwner, body: { decision: "approve" } });

  // The last spot, and none after it.
  await db.rpc("beta_test_pool", { p_given: 99 });
  const lastId = await db.user("delivered+beta-last@resend.dev");
  const lateId = await db.user("delivered+beta-late@resend.dev");
  for (const [id, email] of [[lastId, "delivered+beta-last@resend.dev"], [lateId, "delivered+beta-late@resend.dev"]]) {
    await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${await w.signIn({ sub: id, email })}` },
      body: form });
  }
  const both = await Promise.all([approve(lastId), approve(lateId)]);
  out.last_two = both.map((one) => [one.status, one.json?.application?.spot ?? null, one.json?.refused ?? null]);
  out.full_status = (await askPlans({ query: { op: "beta" }, headers: { authorization: `Bearer ${tester}` } })).json?.pool;

  // An account from before 29 October 2026: approved, no spot, no month.
  const earlyId = await db.user("delivered+beta-early@resend.dev", { made: "2026-10-12T00:00:00Z" });
  const early = await w.signIn({ sub: earlyId, email: "delivered+beta-early@resend.dev" });
  out.early_applied = (await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${early}` },
    body: form })).json?.application;
  mails.length = 0;
  out.early_approved = (await approve(earlyId)).json;
  out.early_mail = mails.map((one) => one.subject);

  // The daily run: the cron's alone; reminders three days out, once.
  process.env.CRON_SECRET = "cron-secret";
  out.daily_stranger = (await askPlans({ query: { op: "beta_daily" } })).status;
  await db.q("update public.beta_applications set month_ends_at = now() + interval '2 days' where account = $1", [testerId]);
  mails.length = 0;
  out.daily = await askPlans({ query: { op: "beta_daily" }, headers: { authorization: "Bearer cron-secret" } });
  out.daily_mail = mails.map((one) => ({ to: one.to, subject: one.subject }));
  out.daily_again = (await askPlans({ query: { op: "beta_daily" }, headers: { authorization: "Bearer cron-secret" } })).json;

  // Resend down: the email is kept as failed, and the application stands.
  resendDown = true;
  const bobId = await db.user("bob@example.com");
  const bob = await w.signIn({ sub: bobId, email: "bob@example.com" });
  out.resend_down = await askPlans({ method: "POST", query: { op: "beta" }, headers: { authorization: `Bearer ${bob}` }, body: form });
  resendDown = false;
  out.calls_to_admission = callsTo("admission.test");
} finally {
  await db.stop();
}
console.log(JSON.stringify(out));
