// api/together.js's build party (APP_UX5 buildparty), its handler as Vercel
// calls it, against a database kept here: a shared model, the parties'
// sessions and their numbered words (together_append as together.sql makes
// it). No sign-in anywhere. Prints one line of JSON (tests/test_together_party.py).
process.env.SUPABASE_URL = "http://db.test";
process.env.SUPABASE_SECRET_KEY = "secret";

const OWNER = "11111111-1111-4111-8111-111111111111";
const LINK = "Car0000001";
const store = { models: [{ id: LINK, owner: OWNER, published: true }], sessions: [], ops: [] };

const answer = (value, status = 200) => new Response(value === undefined ? "" : JSON.stringify(value), { status });
globalThis.fetch = async (url, options = {}) => {
  const where = new URL(String(url));
  const method = options.method || "GET";
  const table = where.pathname.replace("/rest/v1/", "");
  const q = where.searchParams;
  const eq = (key) => (q.get(key) || "").replace(/^eq\./, "");
  if (table === "shared_models") return answer(store.models.filter((one) => one.id === eq("id") && one.published));
  if (table === "together_sessions") {
    if (method === "POST") {
      const row = JSON.parse(options.body);
      if (store.sessions.some((one) => one.id === row.id)) return answer({ message: "duplicate" }, 409);
      store.sessions.push({ ...row, last_seq: 0, created_at: new Date().toISOString(), ended_at: null });
      return answer(undefined, 201);
    }
    let rows = store.sessions;
    if (q.get("id")) rows = rows.filter((one) => one.id === eq("id"));
    if (q.get("title")) rows = rows.filter((one) => one.title === eq("title"));
    if (q.get("ended_at")) rows = rows.filter((one) => !one.ended_at);
    return answer(rows.map((one) => ({ ...one })));
  }
  if (table === "together_ops") {
    const after = Number((q.get("seq") || "gt.0").replace("gt.", ""));
    return answer(store.ops.filter((one) => one.session === eq("session") && one.seq > after)
      .sort((a, b) => a.seq - b.seq).map((one) => ({ ...one })));
  }
  if (table === "rpc/together_append") {
    const { p_session: id, p_author: author, p_client: client, p_ops: ops } = JSON.parse(options.body);
    const session = store.sessions.find((one) => one.id === id && !one.ended_at);
    if (!session || session.owner !== author) return answer({ message: "refused" }, 400);
    const first = session.last_seq;
    session.last_seq += ops.length;
    ops.forEach((op, k) => store.ops.push({ session: id, seq: first + k + 1, client, cid: op.cid, changes: op.changes }));
    return answer(ops.map((_, k) => first + k + 1));
  }
  if (table === "rpc/together_sweep") return answer(0);
  return answer(null);
};

const { default: handler } = await import(process.env.TOGETHER_API || "../../../api/together.js");

async function ask(op, body) {
  const response = {
    statusCode: 200, body: null, headersSent: false, headers: {},
    setHeader(name, value) { this.headers[name.toLowerCase()] = value; return this; },
    status(code) { this.statusCode = code; return this; },
    json(value) { this.body = value; this.headersSent = true; return this; },
    end(text) { this.headersSent = true; if (text) this.body = JSON.parse(text); return this; },
  };
  await handler({ method: "POST", query: { op }, headers: {}, body }, response);
  return { status: response.statusCode, body: response.body };
}

const out = {};
// Started with no sign-in: a code of four, and the phone in seat 1.
const started = await ask("party_start", { link: LINK, phone: "phoneaaa1", name: "Ana" });
out.start = { status: started.status, code: started.body?.code, seat: started.body?.seat,
  ops: started.body?.ops?.length, owner: store.sessions[0]?.owner, title: store.sessions[0]?.title };
const code = started.body?.code || "";
// A stranger's link, and a made-up code: refused.
out.no_model = (await ask("party_start", { link: "Nope000000", phone: "phoneaaa9", name: "" })).status;
out.wrong_code = (await ask("party_join", { link: LINK, code: code === "BBBB" ? "CCCC" : "BBBB", phone: "phonebbb2" })).status;
// The same code on another model: no such build.
store.models.push({ id: "Other00001", owner: OWNER, published: true });
out.other_link = (await ask("party_join", { link: "Other00001", code, phone: "phonebbb2" })).status;
// A name a stranger may not be shown: refused, with words.
const rude = await ask("party_join", { link: LINK, code, phone: "phonebbb2", name: "fuck" });
out.rude = { status: rude.status, error: rude.body?.error || "" };
// Joined, typed in lower case with a space: seat 2, every word so far.
const joined = await ask("party_join", { link: LINK, code: `${code.slice(0, 2).toLowerCase()} ${code.slice(2).toLowerCase()}`,
  phone: "phonebbb2", name: "  Leo\n " });
out.join = { status: joined.status, seat: joined.body?.seat, ops: joined.body?.ops?.length,
  names: joined.body?.ops?.filter((one) => one.said.join).map((one) => one.said.join.name),
  phones_shown: JSON.stringify(joined.body).includes("phoneaaa1") || JSON.stringify(joined.body).includes("phonebbb2") };
// Only seat 1 deals; once.
out.deal_by_two = (await ask("party_send", { link: LINK, code, phone: "phonebbb2", cid: 1, said: { deal: 2 } })).status;
out.deal = (await ask("party_send", { link: LINK, code, phone: "phoneaaa1", cid: 1, said: { deal: 2 } })).status;
out.deal_again = (await ask("party_send", { link: LINK, code, phone: "phoneaaa1", cid: 2, said: { deal: 2 } })).status;
// A third phone once dealt: refused; the second phone again: its seat back.
out.late = (await ask("party_join", { link: LINK, code, phone: "phoneccc3", name: "" })).status;
// Progress, and a word of the wrong shape.
out.at = (await ask("party_send", { link: LINK, code, phone: "phonebbb2", cid: 2,
  said: { at: { done: 4, of: 9, page: 2, part: 1, finished: false } } })).status;
out.bad_word = (await ask("party_send", { link: LINK, code, phone: "phonebbb2", cid: 3, said: { at: { done: "4" } } })).status;
out.not_in = (await ask("party_send", { link: LINK, code, phone: "phoneddd4", cid: 1, said: { left: true } })).status;
out.left = (await ask("party_send", { link: LINK, code, phone: "phonebbb2", cid: 3, said: { left: true } })).status;
const back = await ask("party_join", { link: LINK, code, phone: "phonebbb2", name: "Leo" });
out.back = { status: back.status, seat: back.body?.seat };
// A poll answers at once with what is new, and waits for the next word.
const polled = await ask("party_poll", { link: LINK, code, after: 0 });
out.poll = { status: polled.status, ops: polled.body?.ops?.length, seq: polled.body?.seq,
  kinds: polled.body?.ops?.map((one) => Object.keys(one.said)[0]) };
const began = Date.now();
const waiting = ask("party_poll", { link: LINK, code, after: polled.body?.seq });
setTimeout(() => ask("party_send", { link: LINK, code, phone: "phoneaaa1", cid: 3,
  said: { at: { done: 1, of: 9, page: 1, part: 1, finished: false } } }), 400);
const heard = await waiting;
out.poll_wait = { status: heard.status, ops: heard.body?.ops?.length, ms: Date.now() - began };
// Four at most.
const four = await ask("party_start", { link: LINK, phone: "phoneeee1", name: "" });
for (const phone of ["phoneeee2", "phoneeee3", "phoneeee4"]) await ask("party_join", { link: LINK, code: four.body.code, phone, name: "" });
out.fifth = (await ask("party_join", { link: LINK, code: four.body.code, phone: "phoneeee5", name: "" })).status;
// A day on, over.
store.sessions[0].created_at = new Date(Date.now() - 25 * 3600_000).toISOString();
out.old = (await ask("party_poll", { link: LINK, code, after: 0 })).status;
console.log(JSON.stringify(out));
