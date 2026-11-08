// Does /api/collection put a device's bricks into an account's collection
// with every lot and set of both kept, and never twice?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9961 &
//   node tools/web/localbricks_api.mjs --url=http://127.0.0.1:9961
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/localbricks_api.mjs --url=<a preview>
//
// APP_UX6 #8 localbricks (2026-11-07): the endpoint is additive only. A new
// op, "join", adds what a device kept while nobody was signed in to the
// account's collection, the person asked first in the app. Its id is kept
// past the last 100 changes (the last 50 joins), so a device that sends it
// again after a lost answer is never joined twice.
//
//   0. the op itself, pure (applyOp and remembered, no database): a lot of
//      one part, colour and source is one lot, its counts added; a session's
//      lot is its session's; a set in both is one entry, its copies added and
//      both copies' marks kept; a set or figure of the device's only is
//      kept as it came; every refusal says why; the ids kept are the last
//      100 and, before them, the last 50 joins
//   1. against the real function and database, as one throwaway account at
//      a Resend test address (nobody is emailed), deleted at the end: the
//      account's own collection, made the usual ways
//   2. the device's bricks joined: every lot and set of both there, each
//      count the sum of both, nothing of either lost, read back the same
//   3. the same join sent again with its id: answered as it was, made once
//   4. refused joins change nothing (a part that is no part, a set named
//      twice, a figure with parts missing, nothing to join, a colour that is
//      no code, no id-shaped id)
//   5. 105 other changes later the join sent again is still made once
//   6. a count over 100,000 when joined is held there and said
import { applyOp, MOST_JOINS, MOST_REMEMBERED, remembered } from "../../api/collection.js";
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9961").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL = `delivered+bw-localbricks-${stamp}@resend.dev`;

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

async function call(token, { method = "GET", body } = {}) {
  const headers = {};
  if (bypass) headers["x-vercel-protection-bypass"] = bypass;
  if (token) headers.authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  const reply = await fetch(`${base}/api/collection`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: reply.status, body: json, text };
}

let ids = 0;
const id = () => `lbapi-${stamp}-${ids++}`;
/// The database keeps an object's keys in an order of its own (jsonb).
const canon = (v) => (Array.isArray(v) ? v.map(canon) : v && typeof v === "object"
  ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v);
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));
const lotKey = (p) => JSON.stringify([p.part, p.colour, p.src || "", p.by || "", p.chat || ""]);
const setKey = (s) => JSON.stringify([s.set, s.src || ""]);
const markKey = (m) => JSON.stringify([m.part, m.colour]);
const refusal = (fn) => {
  try { fn(); return null; } catch (error) { return { status: error.status, words: String(error.message) }; }
};

/// [before] and [device] summed as a join must: every lot by its key and
/// every set by its number and source, a set's copies and marks added.
function summed(before, device) {
  const lots = new Map(before.parts.map((p) => [lotKey(p), { ...p }]));
  for (const p of device.parts) {
    const held = lots.get(lotKey(p));
    if (held) held.qty = Math.min(100000, held.qty + p.qty);
    else lots.set(lotKey(p), { ...p });
  }
  const sets = new Map(before.sets.map((s) => [setKey(s), { ...s, missing: s.missing ? s.missing.map((m) => ({ ...m })) : undefined }]));
  for (const s of device.sets) {
    const held = sets.get(setKey(s));
    if (!held) {
      sets.set(setKey(s), { ...s });
      continue;
    }
    held.qty += s.qty;
    for (const m of s.missing || []) {
      held.missing = held.missing || [];
      const mark = held.missing.find((n) => markKey(n) === markKey(m));
      if (mark) mark.qty += m.qty;
      else held.missing.push({ ...m });
    }
  }
  return { lots, sets };
}

/// [after] holds every lot and set [want] says, count for count, and no other.
function holds(after, want) {
  const lots = new Map(after.parts.map((p) => [lotKey(p), p]));
  const sets = new Map(after.sets.map((s) => [setKey(s), s]));
  const wrong = [];
  for (const [key, p] of want.lots) if (lots.get(key)?.qty !== p.qty) wrong.push(`lot ${key}: ${lots.get(key)?.qty} not ${p.qty}`);
  for (const [key, s] of want.sets) {
    const got = sets.get(key);
    if (!got || got.qty !== s.qty) { wrong.push(`set ${key}: ${got?.qty} not ${s.qty}`); continue; }
    const marks = new Map((got.missing || []).map((m) => [markKey(m), m.qty]));
    for (const m of s.missing || []) if (marks.get(markKey(m)) !== m.qty) wrong.push(`${key} missing ${markKey(m)}: ${marks.get(markKey(m))} not ${m.qty}`);
    if ((got.missing || []).length !== (s.missing || []).length) wrong.push(`${key}: ${(got.missing || []).length} marks, not ${(s.missing || []).length}`);
  }
  if (lots.size !== want.lots.size) wrong.push(`${lots.size} lots, not ${want.lots.size}`);
  if (sets.size !== want.sets.size) wrong.push(`${sets.size} sets, not ${want.sets.size}`);
  return wrong;
}

// What a device kept while nobody was signed in: 12 lots (one of a session's,
// one of the account's own colours), 2 sets (one the account has, its marks
// to merge), a minifigure.
const DEVICE = {
  parts: [
    ["3001", 4, 5], ["3023", 71, 4], ["3666", 11, 3], ["3004", 1, 6], ["3010", 15, 2], ["3020", 0, 8],
    ["2412b", 72, 4], ["3039", 4, 2], ["3062b", 46, 10], ["4073", 47, 12], ["3069b", 15, 6],
  ].map(([part, colour, qty]) => ({ part, colour, qty, src: "hand" }))
    .concat([{ part: "3005", colour: 1, qty: 2, by: "Claude", chat: "chat-localbricks" }]),
  sets: [
    { set: "7140-1", qty: 1, spares: false, src: "hand", missing: [{ part: "2412b", colour: 4, qty: 1 }, { part: "3004", colour: 1, qty: 2 }] },
    { set: "6862-1", qty: 1, spares: true, src: "hand" },
    { set: "sw0001a", qty: 1, spares: false, fig: true, name: "Luke Skywalker (Tatooine)" },
  ],
};

console.log("0. the join op, pure");
{
  const have = {
    sets: [{ set: "7140-1", qty: 1, spares: false, src: "hand", missing: [{ part: "2412b", colour: 4, qty: 1 }] },
      { set: "6020-1", qty: 1, spares: false, src: "hand" }],
    parts: [{ part: "3001", colour: 4, qty: 10, src: "hand" }, { part: "3005", colour: 1, qty: 4, by: "Claude", chat: "chat-localbricks" },
      { part: "3005", colour: 1, qty: 7, src: "hand" }],
  };
  const made = applyOp(have, { op: "join", ...DEVICE });
  const wrong = holds(made.next, summed(have, DEVICE));
  check(wrong.length === 0, `every lot and set of both, each count the sum: ${wrong.join("; ") || "13 lots, 4 sets"}`);
  check(made.next.parts.find((p) => p.by === "Claude")?.qty === 6 && made.next.parts.find((p) => p.part === "3005" && p.src === "hand")?.qty === 7,
    "a session's lot added to its session's, the person's own 3005 apart");
  const seventy = made.next.sets.find((s) => s.set === "7140-1");
  check(seventy.qty === 2 && same(seventy.missing, [{ part: "2412b", colour: 4, qty: 2 }, { part: "3004", colour: 1, qty: 2 }]),
    `7140-1 in both: 2 copies, each one's marks kept (${JSON.stringify(seventy)})`);
  check(same(made.next.sets.find((s) => s.set === "sw0001a"), DEVICE.sets[2]) && made.next.sets.find((s) => s.set === "6862-1")?.spares === true,
    "a figure and a set of the device's only kept as they came");
  check(same(made.done, { joined: { sets: 3, lots: 12 } }), `said: ${JSON.stringify(made.done)}`);
  check(same(have.parts[0], { part: "3001", colour: 4, qty: 10, src: "hand" }) && have.sets[0].qty === 1, "the collection given is not changed");
  const refused = [
    [{}, "nothing to join"],
    [{ parts: [{ part: "3001", colour: 4, qty: 1 }, { part: "3001", colour: 4, qty: 2 }] }, "named twice"],
    [{ sets: [{ set: "6020-1", qty: 1 }, { set: "6020", qty: 1 }] }, "named twice"],
    [{ sets: [{ set: "sw0001a", fig: true, qty: 1, missing: [{ part: "3626b", colour: 14, qty: 1 }] }] }, "no parts marked missing"],
    [{ parts: [{ part: "not a part!", colour: 4, qty: 1 }] }, "part"],
    [{ parts: [{ part: "3001", colour: 99999, qty: 1 }] }, "colour"],
    [{ parts: [{ part: "3001", colour: 4, qty: -1 }] }, ""],
    [{ sets: [{ set: "7140-1", qty: 1, src: "the shop" }] }, "where a set comes from"],
    [{ sets: [{ set: "7140-1", qty: 1, missing: [{ part: "3001", colour: 4, qty: 1 }, { part: "3001", colour: 4, qty: 1 }] }] }, "named twice"],
  ];
  for (const [body, words] of refused) {
    const got = refusal(() => applyOp(have, { op: "join", ...body }));
    check(got !== null && got.status === 400 && got.words.includes(words), `refused (${got?.status}): ${got?.words}`);
  }
  const big = applyOp({ sets: [], parts: [{ part: "3001", colour: 4, qty: 99999, src: "hand" }] },
    { op: "join", parts: [{ part: "3001", colour: 4, qty: 5, src: "hand" }], sets: [] });
  check(big.next.parts[0].qty === 100000 && big.done.clamped_lots === 1, `a count over 100,000 held there and said (${JSON.stringify(big.done)})`);
  const list = [];
  for (let n = 0; n < 400; n++) list.push(n % 4 === 0 ? { id: `join-${n}`, done: { joined: { sets: 0, lots: 1 } } } : { id: `op-${n}`, done: {} });
  const kept = remembered(list);
  const joins = kept.filter((one) => one.done.joined);
  check(kept.length === MOST_REMEMBERED + MOST_JOINS && same(kept.slice(-MOST_REMEMBERED), list.slice(-MOST_REMEMBERED))
    && joins.length === MOST_JOINS + MOST_REMEMBERED / 4 && kept[0].id === `join-${(400 - MOST_REMEMBERED) - 4 * MOST_JOINS}`,
    `ids kept: the last ${MOST_REMEMBERED} and, before them, the last ${MOST_JOINS} joins (${kept.length}, first ${kept[0].id})`);
  check(same(remembered(list.slice(0, 40)), list.slice(0, 40)), "under 100, every id kept as it was");
}

let token = null;
try {
  console.log(`\nlocalbricks API test against ${base}`);
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");

  console.log("\n1. the account's own collection");
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1, 10237, 7140", id: id() } });
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: [
    { part: "3001", colour: 4, qty: 10, src: "hand" }, { part: "3005", colour: 1, qty: 4, by: "Claude", chat: "chat-localbricks" }] } });
  await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: [{ part: "2412b", colour: 4, was: 0, qty: 1 }] } });
  const before = (await call(token)).body;
  check(before.sets.length === 3 && before.parts.length === 2 && before.sets.find((s) => s.set === "7140-1")?.missing?.length === 1,
    `three sets (7140-1 with one mark) and two lots (${before.sets.length}, ${before.parts.length})`);

  console.log("\n2. the device's bricks joined");
  const joinId = `join-${id()}`;
  const joined = await call(token, { method: "POST", body: { op: "join", id: joinId, ...DEVICE } });
  const want = summed(before, DEVICE);
  const wrong = joined.status === 200 ? holds(joined.body, want) : [joined.text];
  check(joined.status === 200 && wrong.length === 0,
    `${joined.status}: every lot and set of both, each count the sum (${wrong.join("; ") || `${want.lots.size} lots, ${want.sets.size} sets`})`);
  check(same(joined.body?.done, { joined: { sets: 3, lots: 12 } }), `said: ${JSON.stringify(joined.body?.done)}`);
  const read = (await call(token)).body;
  check(holds(read, want).length === 0 && read.rev === joined.body?.rev, "read back, the same");

  console.log("\n3. the same join sent again");
  const again = await call(token, { method: "POST", body: { op: "join", id: joinId, ...DEVICE } });
  check(again.status === 200 && again.body?.done?.again === true && same(again.body?.done?.joined, { sets: 3, lots: 12 })
    && holds(again.body, want).length === 0 && again.body.rev === read.rev,
    `answered as it was (${JSON.stringify(again.body?.done)}), made once: rev ${again.body?.rev}`);

  console.log("\n4. refused joins change nothing");
  for (const [body, words] of [
    [{ parts: [{ part: "not a part!", colour: 4, qty: 1 }], sets: [] }, "part"],
    [{ sets: [{ set: "6020-1", qty: 1 }, { set: "6020", qty: 1 }], parts: [] }, "named twice"],
    [{ sets: [{ set: "sw0001a", fig: true, qty: 1, missing: [{ part: "3626b", colour: 14, qty: 1 }] }], parts: [] }, "missing"],
    [{ sets: [], parts: [] }, "nothing to join"],
    [{ parts: [{ part: "3001", colour: 99999, qty: 1 }], sets: [] }, "colour"],
  ]) {
    const got = await call(token, { method: "POST", body: { op: "join", id: `join-${id()}`, ...body } });
    check(got.status === 400 && String(got.body?.error || got.text).includes(words), `${got.status}: ${got.body?.error || got.text}`);
  }
  const badId = await call(token, { method: "POST", body: { op: "join", id: "no", ...DEVICE } });
  check(badId.status === 400, `an id that is no id: ${badId.status}`);
  const after4 = (await call(token)).body;
  check(holds(after4, want).length === 0 && after4.rev === read.rev, `nothing changed: rev ${after4.rev}`);

  console.log("\n5. 105 other changes later");
  for (let n = 0; n < 105; n++) {
    const one = await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3070b", colour: 15, qty: 1, src: "hand" }] } });
    if (one.status !== 200) { check(false, `change ${n + 1}: ${one.status} ${one.text}`); break; }
  }
  const later = (await call(token)).body;
  check(later.parts.find((p) => p.part === "3070b")?.qty === 105, "105 changes made");
  const late = await call(token, { method: "POST", body: { op: "join", id: joinId, ...DEVICE } });
  const sevenLater = late.body?.sets?.find((s) => s.set === "7140-1");
  check(late.status === 200 && late.body?.done?.again === true && late.body.rev === later.rev && sevenLater?.qty === 2,
    `the join sent again is still made once (${JSON.stringify(late.body?.done)}; 7140-1 ×${sevenLater?.qty})`);

  console.log("\n6. a count over 100,000");
  const near = await call(token, { method: "POST", body: { op: "set", id: id(), lots: [{ part: "3001", colour: 4, src: "hand", was: 15, qty: 99999 }] } });
  const over = await call(token, { method: "POST", body: { op: "join", id: `join-${id()}`, sets: [], parts: [{ part: "3001", colour: 4, qty: 7, src: "hand" }] } });
  check(near.status === 200 && over.status === 200 && over.body.parts.find((p) => p.part === "3001" && p.src === "hand")?.qty === 100000
    && over.body.done?.clamped_lots === 1, `held at 100,000 and said (${JSON.stringify(over.body?.done)})`);
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (token) check(await deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\nlocalbricks API test: every check passed" : `\nlocalbricks API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
