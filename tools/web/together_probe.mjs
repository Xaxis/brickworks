// Building together's server half (api/together.js), from three accounts at
// once, in seconds: what the app's two sides would ask, and how long a
// change takes to reach the other side.
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9011 --hold=together_sessions,together_ops,together_people &
//   node tools/web/together_probe.mjs --url=http://127.0.0.1:9011
//   BW_BYPASS=… node tools/web/together_probe.mjs --url=<a preview>     once together.sql is applied
//
//   1. The owner starts a session with a small model and is given a link;
//      a second account joins by it and is given the model as it began and
//      who is in it, by name or "Builder 2", never an email.
//   2. Both send changes at once, many times: every change is numbered once,
//      in one order both read back the same, with nothing skipped.
//   3. A change sent by one side reaches the other's waiting poll: the time
//      from send to arrival, p50 and p95 over --rounds (default 30).
//   4. A third account with no link, or a made-up one, is refused; so is a
//      send or a poll from an account that never joined. The owner takes
//      the second out: its next poll, its send and joining again by the
//      same link are refused.
//   5. The owner ends it: a waiting poll says so, and a send is refused.
//
// Test accounts at resend.dev, deleted at the end. Exit 1 on any failure.
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9011").replace(/\/+$/, "").replace(/\/app$/, "");
const rounds = Number(args.rounds || 30);
const bypass = args.bypass || process.env.BW_BYPASS || "";

let failed = 0;
function check(what, ok, more = "") {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}${more ? `  (${more})` : ""}`);
  if (!ok) failed += 1;
}

async function ask(token, op, body) {
  const headers = { "content-type": "application/json", authorization: `Bearer ${token}` };
  if (bypass) headers["x-vercel-protection-bypass"] = bypass;
  const answer = await fetch(`${base}/api/together?op=${op}`, { method: "POST", headers, body: JSON.stringify(body) });
  const text = await answer.text();
  let value = null;
  try { value = JSON.parse(text); } catch { value = { raw: text.slice(0, 200) }; }
  return { status: answer.status, value };
}

const stamp = Date.now().toString(36);
const emails = ["a", "b", "c"].map((who) => `delivered+together-${who}-${stamp}@resend.dev`);
const [owner, guest, stranger] = await Promise.all(emails.map((email) => mintSession(email)));
const tokens = [owner, guest, stranger].map((one) => one.access_token);
const at = (x) => [1, 0, 0, 0, 1, 0, 0, 0, 1, x, 0, 0];
const brick = (x, colour = 4) => ["3001.dat", colour, at(x), "", "", -1];

try {
  console.log("1. start and join");
  const started = await ask(tokens[0], "start", {
    title: "Probe house",
    snapshot: { text: "0 Probe house\n", lift: 0, bricks: [["0.1", ...brick(0)], ["0.2", ...brick(20)]] },
  });
  check("the owner starts a session and is given a link", started.status === 200 && /\/app\?together=/.test(started.value.link || ""),
    `${started.status}`);
  const s = started.value.s;
  const joined = await ask(tokens[1], "join", { s });
  check("a second account joins by the link and is given the model", joined.status === 200
    && joined.value.snapshot?.bricks?.length === 2 && joined.value.owner === false, `${joined.status}`);
  const names = (joined.value.people || []).map((one) => one.name);
  check(`who is in it: ${names.join(", ")}`, names.length === 2 && !names.some((n) => n.includes("@")));

  console.log("2. both send at once");
  const sends = [];
  for (let n = 0; n < 20; n++) {
    sends.push(ask(tokens[0], "send", { s, client: "ownerab", ops: [{ cid: n, changes: { "0.1": brick(n) } }] }));
    sends.push(ask(tokens[1], "send", { s, client: "guestab", ops: [{ cid: n, changes: { "0.1": brick(-n), [`g.${n}`]: brick(100 + n, 1) } }] }));
  }
  const sent = await Promise.all(sends);
  const seqs = sent.flatMap((one) => one.value.seqs || []).sort((a, b) => a - b);
  check("every send numbered", sent.every((one) => one.status === 200), sent.filter((one) => one.status !== 200).map((one) => one.status).join(","));
  check("40 numbers, 1 to 40, each once", seqs.length === 40 && seqs.every((n, k) => n === k + 1), seqs.slice(0, 5).join(","));
  const readBack = async (token) => {
    const got = [];
    let after = 0;
    for (let n = 0; n < 5 && got.length < 40; n++) {
      const polled = await ask(token, "poll", { s, after, seen: "x" });
      got.push(...(polled.value.ops || []));
      after = got.length ? got[got.length - 1].seq : after;
    }
    return got;
  };
  const [a, b] = await Promise.all([readBack(tokens[0]), readBack(tokens[1])]);
  const order = (ops) => ops.map((op) => `${op.seq}:${op.client}:${op.cid}`).join(" ");
  check("both read the same 40 changes in the same order", a.length === 40 && order(a) === order(b));
  check("a change says who made it, never their account", a.every((op) => /^[0-9a-f]{8}$/.test(op.who)));

  console.log("3. from one side to the other");
  let after = a.length ? a[a.length - 1].seq : 0;
  const times = [];
  for (let n = 0; n < rounds; n++) {
    const waiting = ask(tokens[1], "poll", { s, after, seen: joined.value.seen });
    await new Promise((done) => setTimeout(done, 300));
    const sentAt = Date.now();
    await ask(tokens[0], "send", { s, client: "ownerab", ops: [{ cid: 100 + n, changes: { "0.2": brick(n * 20) } }] });
    let got = await waiting;
    // A poll that came back for who is in it, not the change: once more.
    if (!(got.value.ops || []).length) got = await ask(tokens[1], "poll", { s, after, seen: got.value.seen });
    const arrived = Date.now();
    if ((got.value.ops || []).length) {
      times.push(arrived - sentAt);
      after = got.value.ops[got.value.ops.length - 1].seq;
    }
  }
  times.sort((x, y) => x - y);
  const pct = (p) => times[Math.min(times.length - 1, Math.floor(p * times.length))];
  check(`${times.length} of ${rounds} changes arrived: p50 ${pct(0.5)} ms, p95 ${pct(0.95)} ms`, times.length === rounds && pct(0.5) < 1000);

  console.log("4. who may not");
  const guessed = await ask(tokens[2], "join", { s: "x".repeat(32) });
  check("a made-up link is refused", guessed.status === 404, `${guessed.status}`);
  const peeked = await ask(tokens[2], "poll", { s, after: 0 });
  const pushed = await ask(tokens[2], "send", { s, client: "strangr", ops: [{ cid: 0, changes: { "0.1": null } }] });
  check("an account that never joined can neither read nor send", peeked.status === 403 && pushed.status === 403,
    `${peeked.status}, ${pushed.status}`);
  const guestWho = (joined.value.people || []).find((one) => !one.owner)?.who;
  const removed = await ask(tokens[0], "remove", { s, who: guestWho });
  check("the owner takes the second account out", removed.status === 200 && removed.value.people.length === 1, `${removed.status}`);
  const after1 = await ask(tokens[1], "poll", { s, after });
  const after2 = await ask(tokens[1], "send", { s, client: "guestab", ops: [{ cid: 999, changes: { "0.1": null } }] });
  const again = await ask(tokens[1], "join", { s });
  check("...and it is refused: poll, send, and joining again by the link", after1.status === 403 && after2.status === 403
    && again.status === 403, `${after1.status}, ${after2.status}, ${again.status}`);

  console.log("5. the owner ends it");
  const notOwner = await ask(tokens[2], "end", { s });
  check("only the owner ends it", notOwner.status === 403, `${notOwner.status}`);
  const now = await ask(tokens[0], "poll", { s, after, seen: "x" });
  const waiting = ask(tokens[0], "poll", { s, after, seen: now.value.seen });
  await new Promise((done) => setTimeout(done, 500));
  const ended = await ask(tokens[0], "end", { s });
  const told = await waiting;
  const late = await ask(tokens[0], "send", { s, client: "ownerab", ops: [{ cid: 1000, changes: { "0.1": null } }] });
  const lateJoin = await ask(tokens[2], "join", { s });
  check("ended: said to the owner's own poll; a send and a join refused", ended.status === 200
    && (told.value.ended === true || (told.value.ops || []).length > 0) && late.status === 410 && lateJoin.status === 410,
    `${ended.status}, ${told.value.ended}, ${late.status}, ${lateJoin.status}`);
} finally {
  for (const email of emails) await deleteAccount(email).catch(() => {});
}
console.log(failed ? `\ntogether_probe: ${failed} FAILED` : "\ntogether_probe: all ok");
process.exit(failed ? 1 : 0);
