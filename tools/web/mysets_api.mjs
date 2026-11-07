// Does /api/collection keep a set's missing parts and a minifigure, with
// an older collection read lot for lot and nothing of it ever lost?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9961 &
//   node tools/web/mysets_api.mjs --url=http://127.0.0.1:9961
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/mysets_api.mjs --url=<a preview>
//
// APP_UX6 #6 mysets (2026-11-07): the endpoint is additive only. A set
// entry may carry "missing" (its lots short, by the "missing" op) and a
// minifigure is kept among the sets ("fig": true). Against the real
// function and the real database, as one throwaway account at a Resend test
// address (its session minted here; nobody is emailed), deleted at the end:
//
//   1. a collection made the old ways, as the builds out there make one:
//      two sets typed, a Rebrickable parts export, a BrickLink XML and a
//      session's lot; read back, it is the older collection
//   2. 7140-1 typed, then 12 of its lots marked missing in one op, each
//      from 0 shown: kept on 7140-1 alone, every other set and lot as it
//      was; read again, the same
//   3. a mark from a count no longer shown refused (409, the collection as
//      it is), as is a set no longer there; a lot named twice, a colour
//      that is no code, a part that is no part, a count over 100,000:
//      refused (400); none of it changes anything
//   4. every other change keeps the marks: a lot added, a count set, a
//      session's lot kept, 7140-1 typed again (2 copies, the marks kept), a
//      Rebrickable fetch that lists 7140-1 (replaced, its marks carried),
//      remove_set of another set, and an older app's Remove a set (its
//      whole copy PUT, marks it knows nothing of stripped) of another set
//   5. a mark sent twice with one id is made once
//   6. a minifigure found by a photo kept among the sets by BrickLink's
//      number and name; one that looks like a set number refused; taken out
//      by remove_set as a figure, and by an older app's remove_set, which
//      names it as a set
//   7. every mark taken off (to 0): 7140-1 kept as the older shape, no
//      "missing" left; 7140-1 taken out, and the collection lot for lot the
//      older collection of step 1
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9961").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL = `delivered+bw-mysets-${stamp}@resend.dev`;

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
const id = () => `msapi-${stamp}-${ids++}`;
/// The database keeps an object's keys in an order of its own (jsonb), so
/// two are the same when their keys and values are, in any order.
const canon = (v) => (Array.isArray(v) ? v.map(canon) : v && typeof v === "object"
  ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v);
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));
const setOf = (c, number, src) => (c?.sets || []).find((s) => s.set === number && (src === undefined || (s.src || "") === src));
const others = (c, number) => (c?.sets || []).filter((s) => s.set !== number);
const seen = (p) => ({ ...Object.fromEntries(["part", "colour", "src", "by", "chat"].filter((k) => p[k] !== undefined)
  .map((k) => [k, p[k]])), was: p.qty });
/// An older app's copy of a collection, as its Collection.from_json keeps it
/// and its Remove sends it: a set's number, count, spares and source; a
/// lot's part, colour and count, every source and session dropped.
const olderCopy = (c) => ({
  sets: c.sets.map((s) => ({ set: s.set, qty: s.qty, spares: Boolean(s.spares) })),
  parts: c.parts.map((p) => ({ part: p.part, colour: p.colour, qty: p.qty })),
});

/// Twelve of 7140-1's lots, as its inventory has them: one of each missing.
const TWELVE = [
  ["2412b", 4], ["2420", 7], ["2431", 14], ["2445", 7], ["2456", 4], ["2555", 0],
  ["3004", 1], ["3005", 7], ["3009", 8], ["3010", 7], ["3021", 19], ["3029", 7],
].map(([part, colour]) => ({ part, colour }));

let token = null;
try {
  console.log(`mysets API test against ${base}`);
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");

  console.log("\n1. an older collection, made the old ways");
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1, 10237", id: id() } });
  await call(token, { method: "POST", body: { from: "rebrickable_csv", id: id(),
    text: "Part,Color,Quantity\n3001,4,10\n3023,71,4\n" } });
  await call(token, { method: "POST", body: { from: "bricklink_xml", id: id(), text:
    "<INVENTORY><ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3666</ITEMID><COLOR>11</COLOR><QTY>3</QTY></ITEM></INVENTORY>" } });
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3005", colour: 1, qty: 4, by: "Claude", chat: "chat-mysets" }] } });
  const older = (await call(token)).body;
  check(older.sets.length === 2 && older.parts.length === 4 && older.sets.every((s) => !("missing" in s) && !("fig" in s)),
    `two sets and four lots, in the shape the builds out there keep (${JSON.stringify(older.sets)})`);

  console.log("\n2. 7140-1 typed, and 12 of its lots marked missing in one op");
  const typed = (await call(token, { method: "POST", body: { from: "sets", text: "7140", id: id() } })).body;
  check(same(setOf(typed, "7140-1"), { set: "7140-1", qty: 1, spares: false, src: "hand" }), "7140 typed is 7140-1, the person's own");
  const marked = await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: TWELVE.map((t) => ({ ...t, was: 0, qty: 1 })) } });
  const held = setOf(marked.body, "7140-1");
  check(marked.status === 200 && held?.missing?.length === 12 && TWELVE.every((t) => held.missing.some((m) =>
    m.part === t.part && m.colour === t.colour && m.qty === 1)) && marked.body.done?.missing === 12,
    `marked: ${marked.status}, 12 lots on 7140-1, 12 pieces (${JSON.stringify(marked.body?.done)})`);
  check(same(others(marked.body, "7140-1"), older.sets) && same(marked.body.parts, older.parts),
    "...every other set and every lot as it was");
  const reread = (await call(token)).body;
  check(same(reread.sets, marked.body.sets) && same(reread.parts, marked.body.parts), "...and read again, the same");

  console.log("\n3. what is refused, changing nothing");
  const kept = reread;
  const stale = await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: [{ ...TWELVE[0], was: 0, qty: 2 }] } });
  check(stale.status === 409 && setOf(stale.body, "7140-1")?.missing?.length === 12,
    `from a count no longer shown (0, not 1): ${stale.status} "${stale.body?.error}", the collection as it is`);
  const gone = await call(token, { method: "POST", body: { op: "missing", id: id(), set: "9493-1",
    lots: [{ part: "3001", colour: 4, was: 0, qty: 1 }] } });
  check(gone.status === 409, `a set not in the collection: ${gone.status} "${gone.body?.error}"`);
  for (const [what, lots, said] of [
    ["a lot named twice", [{ ...TWELVE[0], was: 1, qty: 0 }, { ...TWELVE[0], was: 1, qty: 1 }], /twice/],
    ["a colour that is no code", [{ part: "3001", colour: "red", was: 0, qty: 1 }], /colour/],
    ["a part that is no part", [{ part: "<b>", colour: 4, was: 0, qty: 1 }], /part number/],
    ["a count over 100,000", [{ part: "3001", colour: 4, was: 0, qty: 100001 }], /outside/],
    ["no lots", [], /no lots/],
  ]) {
    const got = await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand", lots } });
    check(got.status === 400 && said.test(got.body?.error || ""), `${what}: ${got.status} "${got.body?.error}"`);
  }
  const after = (await call(token)).body;
  check(same(after.sets, kept.sets) && same(after.parts, kept.parts), "none of the refusals changed anything");

  console.log("\n4. every other change keeps the marks");
  const marks = setOf(kept, "7140-1").missing;
  const keeps = (c) => same(setOf(c, "7140-1")?.missing, marks);
  const added = (await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3020", colour: 4, qty: 2 }] } })).body;
  check(keeps(added) && added.parts.length === 5, "a loose lot added: the marks kept");
  const lot3020 = added.parts.find((p) => p.part === "3020");
  const counted = (await call(token, { method: "POST", body: { op: "set", id: id(), lots: [{ ...seen(lot3020), qty: 3 }] } })).body;
  check(keeps(counted), "its count set: the marks kept");
  const claude = counted.parts.find((p) => p.by === "Claude");
  const kept2 = (await call(token, { method: "POST", body: { op: "keep", id: id(), lots: [seen(claude)] } })).body;
  check(keeps(kept2) && !kept2.parts.some((p) => p.by), "a session's lot kept as the person's own: the marks kept");
  const twice = (await call(token, { method: "POST", body: { from: "sets", text: "7140-1", id: id() } })).body;
  check(keeps(twice) && setOf(twice, "7140-1").qty === 2, "7140-1 typed again: 2 copies, the marks kept");
  const fetched = await call(token, { method: "POST", body: { from: "rebrickable_api", mode: "replace", id: id(),
    sets: [["7140-1", 1, false], ["6020-1", 1, false]], parts: [] } });
  const fetchedSet = setOf(fetched.body, "7140-1");
  check(fetched.status === 200 && fetchedSet?.src === "rebrickable" && same(fetchedSet.missing, marks)
    && !setOf(fetched.body, "7140-1", "hand"),
    `a Rebrickable fetch that lists 7140-1 replaces it as Rebrickable's, its marks carried (${JSON.stringify(fetchedSet)})`);
  const withRb = fetched.body;
  const removed = (await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "10237-1", src: "hand", was: 1 } })).body;
  check(same(setOf(removed, "7140-1")?.missing, marks) && !setOf(removed, "10237-1")
    && same(removed.parts, withRb.parts), "remove_set of 10237-1: gone, 7140-1's marks and every lot kept");
  const put = await call(token, { method: "PUT", body: (() => {
    const copy = olderCopy(removed);
    copy.sets = copy.sets.filter((s) => s.set !== "6020-1");
    return copy;
  })() });
  check(put.status === 200 && !setOf(put.body, "6020-1") && same(setOf(put.body, "7140-1")?.missing, marks)
    && same(put.body.parts, removed.parts),
    `an older app's Remove of 6020-1 (its whole copy PUT, no marks in it): ${put.status}, 7140-1's marks kept`);

  console.log("\n5. a mark sent twice with one id is made once");
  const once = id();
  const first = await call(token, { method: "POST", body: { op: "missing", id: once, set: "7140-1", src: "rebrickable",
    lots: [{ part: "3001", colour: 0, was: 0, qty: 1 }] } });
  const again = await call(token, { method: "POST", body: { op: "missing", id: once, set: "7140-1", src: "rebrickable",
    lots: [{ part: "3001", colour: 0, was: 0, qty: 1 }] } });
  check(first.status === 200 && again.status === 200 && again.body.done?.again === true
    && setOf(again.body, "7140-1").missing.filter((m) => m.part === "3001").length === 1,
    `sent twice: made once, the second answered as the first (${JSON.stringify(again.body?.done)})`);
  await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "rebrickable",
    lots: [{ part: "3001", colour: 0, was: 1, qty: 0 }] } });

  console.log("\n6. a minifigure");
  const before6 = (await call(token)).body;
  const fig = await call(token, { method: "POST", body: { from: "figs", id: id(),
    figs: [{ fig: "SW0001a", name: "Luke Skywalker\n(Tatooine)" }] } });
  const figSet = setOf(fig.body, "sw0001a");
  check(fig.status === 200 && same(figSet, { set: "sw0001a", qty: 1, spares: false, fig: true,
    name: "Luke Skywalker (Tatooine)", src: "hand" }) && same(fig.body.parts, before6.parts),
    `kept among the sets by BrickLink's number, its name one line (${JSON.stringify(figSet)})`);
  const asSet = await call(token, { method: "POST", body: { from: "figs", id: id(), figs: [{ fig: "7140-1" }] } });
  check(asSet.status === 400, `one that looks like a set number: ${asSet.status} "${asSet.body?.error}"`);
  const figOut = (await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "sw0001a", fig: true,
    src: "hand", was: 1 } })).body;
  check(!setOf(figOut, "sw0001a") && same(figOut.sets, before6.sets), "taken out as a figure: gone, nothing else moved");
  await call(token, { method: "POST", body: { from: "figs", id: id(), figs: [{ fig: "sw0001a", name: "Luke" }] } });
  const olderOut = (await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "sw0001a",
    src: "hand", was: 1 } })).body;
  check(!setOf(olderOut, "sw0001a") && same(olderOut.sets, before6.sets),
    "...and by an older app's remove_set, which names it as a set: gone, nothing else moved");

  console.log("\n7. back to the older collection");
  const now = (await call(token)).body;
  const unmarked = (await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "rebrickable",
    lots: setOf(now, "7140-1").missing.map((m) => ({ part: m.part, colour: m.colour, was: m.qty, qty: 0 })) } })).body;
  check(same(setOf(unmarked, "7140-1"), { set: "7140-1", qty: 1, spares: false, src: "rebrickable" }),
    `every mark taken off: 7140-1 as the older shape, no "missing" left (${JSON.stringify(setOf(unmarked, "7140-1"))})`);
  await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "7140-1", src: "rebrickable", was: 1 } });
  // Step 4's own changes undone: 3020 out, 6020-1 and 10237-1 typed again,
  // the session's lot made its own again stays the person's (Keep).
  const back = (await call(token)).body;
  const l3020 = back.parts.find((p) => p.part === "3020");
  await call(token, { method: "POST", body: { op: "set", id: id(), lots: [{ ...seen(l3020), qty: 0 }] } });
  const sixty = setOf(back, "6020-1");
  if (sixty) await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "6020-1", src: sixty.src, was: sixty.qty } });
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1, 10237", id: id() } });
  const last = (await call(token)).body;
  const asOlder = (c) => ({ sets: c.sets, parts: c.parts.map((p) => (p.by ? { part: p.part, colour: p.colour, qty: p.qty, src: "hand" } : p)) });
  check(same(last.sets, older.sets) && same(asOlder(last).parts, asOlder(older).parts),
    `the collection lot for lot the older one (the session's lot kept as the person's): ${JSON.stringify(last.parts)}`);
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (token) check(await deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\nmysets API test: every check passed" : `\nmysets API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
