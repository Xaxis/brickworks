// Does /api/collection keep where each part is kept, through every other
// change, two tabs at once and an older app, and never change anything else?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 10551 &
//   tools/release/live_db.sh partplaces node tools/web/partplaces_api.mjs --url=http://127.0.0.1:10551
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/partplaces_api.mjs --url=<a preview>
//   node tools/web/partplaces_api.mjs --pure          (step 0 alone: no network, no account)
//
// APP_UX9 #14 partplaces (2026-11-17): additive only. A row may carry
// "places" ({"3001/4": "drawer 3"}, supabase/partplaces.sql), written by op
// "place" alone (and emptied by Start over). Against the real function and
// the real database, as one throwaway account at a Resend test address
// (its session minted here; nobody is emailed), deleted at the end:
//
//   0. with no network: placeText (one line, never cut, 40 characters),
//      placesOf (only keys and places as kept), applyOp's op place on rows
//      made here: held keys from the lots and a set's inventory, refused
//      for what is not held, from a place not shown, named twice, over 40
//      characters, before the column is there (503); Start over forgets them
//   1. 7140-1 typed and 12 loose lots (keptbuilt's)
//   2. places set on 12 lots in one op: 8 loose lots, 4 parts only 7140-1
//      holds; every set and lot as it was, byte for byte, and updated_at
//      too (the gallery's pool is not counted again); read again, the same;
//      sent again with its id, made once
//   3. refused, changing nothing: from a place no longer shown (409, with
//      the places as they are), a part the collection doesn't hold (409),
//      named twice (400), over 40 characters (400), a number (400)
//   4. two tabs at once: two ops on other parts, sent together, both land;
//      two on one part from the same place shown, one lands, the other is
//      told (409) and nothing of it is kept
//   5. every other change keeps them: a lot added, a count set, a lot taken
//      to none (its drawer kept for when it comes back), remove_set and the
//      set typed again, an Own down and up, a Rebrickable fetch replacing,
//      and an older app's Remove a set, its whole copy PUT without it (it
//      knows no places; its copy sent as it is is refused, as before)
//   6. taken off ("" place), for a part no longer held too; Start over
//      forgets every place; an older app's DELETE does too
import { applyOp, placeText, placesOf, keyOf, MOST_PLACE } from "../../api/collection.js";
import { readShard, shardOf } from "../../api/_owned.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:10551").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL = `delivered+bw-partplaces-${stamp}@resend.dev`;
const SET = "7140-1";

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
const id = () => `ppapi-${stamp}-${ids++}`;
/// jsonb keeps an object's keys in an order of its own.
const canon = (v) => (Array.isArray(v) ? v.map(canon) : v && typeof v === "object"
  ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v);
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));
/// Everything a place may not change.
const rest = (c) => ({ sets: c?.sets || [], parts: c?.parts || [] });
const LOTS = [["3001", 4, 12], ["3020", 0, 4], ["3021", 4, 4], ["4600", 0, 2], ["4624", 71, 4], ["3641", 0, 4],
  ["3004", 15, 6], ["3023", 15, 6], ["3024", 47, 4], ["3069b", 0, 4], ["3010", 1, 4], ["3062b", 14, 2]];
const refusedWith = (fn, status, words) => {
  try {
    fn();
    return `made, not refused`;
  } catch (error) {
    return error.status === status && words.test(error.message) ? "" : `${error.status} "${error.message}"`;
  }
};

let token = null;
try {
  console.log(`partplaces API test against ${args.pure ? "nothing (--pure)" : base}`);
  console.log("\n0. with no network");
  check(placeText("  drawer\n 3‮ ", "x") === "drawer 3" && placeText(null, "x") === "" && placeText(undefined, "x") === "",
    `placeText makes one line: "${placeText("  drawer\n 3‮ ", "x")}", none for null`);
  check(refusedWith(() => placeText("d".repeat(MOST_PLACE + 1), "place 1"), 400, /at most 40 characters/) === ""
    && placeText("d".repeat(MOST_PLACE), "x").length === MOST_PLACE,
    "41 characters refused, never cut; 40 kept");
  check(refusedWith(() => placeText(3, "place 1"), 400, /a place is words/) === "", "a number refused");
  check(same(placesOf({ places: { "3001/4": "drawer 3", "BAD KEY": "x", "3020/0": "", "3021/4": 7 } }), { "3001/4": "drawer 3" })
    && same(placesOf({ places: ["x"] }), {}) && same(placesOf({}), {}),
    "placesOf keeps only keys as keyOf spells them and places that are words");
  const record = (await readShard(shardOf(SET), "")).sets[SET];
  check(Boolean(record?.p?.length), `${SET}'s inventory read from its shard: ${record?.p?.length} lots`);
  const loose = new Set(LOTS.map(([part, colour]) => keyOf({ part, colour })));
  const onlySet = [...new Set(record.p.map(([part, colour]) => keyOf({ part, colour: Number(colour) })))]
    .filter((key) => !loose.has(key)).slice(0, 4);
  const row = { there: true, placesKept: true, rev: 1, places: {}, sets: [{ set: SET, qty: 1, spares: false, src: "hand" }],
    parts: LOTS.map(([part, colour, qty]) => ({ part, colour, qty, src: "hand" })) };
  const books = new Map([[SET, record]]);
  const split = (key) => ({ part: key.split("/")[0], colour: Number(key.split("/")[1]) });
  const twelve = [...LOTS.slice(0, 8).map(([part, colour]) => ({ part, colour })), ...onlySet.map(split)]
    .map((one, n) => ({ ...one, was: "", place: `drawer ${n + 1}` }));
  const pure = applyOp(row, { op: "place", places: twelve }, books);
  check(pure.next === null && Object.keys(pure.places).length === 12 && pure.done.placed === 12
    && pure.places[keyOf(twelve[2])] === "drawer 3",
    `12 placed, 8 loose and 4 only ${SET} holds (${onlySet.join(", ")}): no lot or set touched`);
  const stranger = { part: "3001", colour: 1, was: "", place: "drawer 9" };
  check(refusedWith(() => applyOp(row, { op: "place", places: [stranger] }, books), 409, /not in your collection/) === "",
    "a part neither loose nor in the set: refused");
  check(refusedWith(() => applyOp(row, { op: "place", places: [stranger] }, new Map([[SET, null]])), 503,
    /could not be read/) === "", "...and when the set's inventory could not be read, it says it could not tell");
  check(refusedWith(() => applyOp({ ...row, places: pure.places }, { op: "place",
    places: [{ ...twelve[0], was: "", place: "box" }] }, books), 409, /kept in "drawer 1" now, not nowhere/) === "",
    "from a place not shown: refused, saying where it is now");
  check(refusedWith(() => applyOp(row, { op: "place", places: [twelve[0], { ...twelve[0], part: "3001" }] }, books), 400,
    /named twice/) === "", "named twice: refused");
  check(refusedWith(() => applyOp({ ...row, placesKept: false }, { op: "place", places: [twelve[0]] }, books), 503,
    /cannot be kept with your account yet/) === "", "before supabase/partplaces.sql: refused, with words (503)");
  const off = applyOp({ ...row, parts: [], sets: [], places: pure.places }, { op: "place",
    places: [{ ...twelve[0], was: "drawer 1", place: "" }] }, new Map());
  check(off.places[keyOf(twelve[0])] === undefined && Object.keys(off.places).length === 11,
    "taken off for a part no longer held: allowed");
  const over = applyOp({ ...row, places: pure.places }, { op: "start_over", rev: 1 });
  check(same(over.next, { sets: [], parts: [] }) && same(over.places, {}), "Start over forgets the places too");
  const bare = applyOp({ ...row, sets: [], parts: [], places: pure.places }, { op: "start_over", rev: 1 });
  check(same(bare.places, {}), "...also when only places are left");
  if (args.pure) throw "pure";

  const { deleteAccount, mintSession } = await import("./session.mjs");
  globalThis.deleteAccount = deleteAccount;
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");
  const place = (places, extra = {}) => call(token, { method: "POST", body: { op: "place", id: id(), places, ...extra } });

  console.log(`\n1. ${SET} and 12 loose lots`);
  await call(token, { method: "POST", body: { from: "sets", text: SET, id: id() } });
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: LOTS.map(([part, colour, qty]) => ({ part, colour, qty })) } });
  const before = (await call(token)).body;
  check(before.sets.length === 1 && before.parts.length === 12 && same(before.places, {}),
    `1 set, 12 lots, no places (${JSON.stringify(before.places)})`);

  console.log("\n2. 12 placed in one op");
  const once = id();
  const placed = await call(token, { method: "POST", body: { op: "place", id: once, places: twelve } });
  check(placed.status === 200 && placed.body.done?.placed === 12 && Object.keys(placed.body.places || {}).length === 12
    && placed.body.places[keyOf(twelve[2])] === "drawer 3",
    `placed: ${placed.status} ${placed.body?.error || JSON.stringify(placed.body?.done)}`);
  check(same(rest(placed.body), rest(before)) && placed.body.updated_at === before.updated_at,
    "...every set and lot as it was, byte for byte, and the time the counts were kept");
  const reread = (await call(token)).body;
  check(same(reread.places, placed.body.places) && same(rest(reread), rest(before)), "...and read again, the same");
  const again = await call(token, { method: "POST", body: { op: "place", id: once, places: twelve } });
  check(again.status === 200 && again.body.done?.again === true && same(again.body.places, placed.body.places),
    `sent again with its id: made once (again ${again.body?.done?.again})`);

  console.log("\n3. refused, changing nothing");
  const stale = await place([{ ...twelve[0], was: "", place: "box 1" }]);
  check(stale.status === 409 && stale.body.places?.[keyOf(twelve[0])] === "drawer 1",
    `from a place no longer shown: ${stale.status} "${stale.body?.error}", the places as they are`);
  const notHeld = await place([stranger]);
  check(notHeld.status === 409 && /not in your collection/.test(notHeld.body?.error || ""),
    `a part it doesn't hold: ${notHeld.status} "${notHeld.body?.error}"`);
  const twice = await place([{ ...twelve[0], was: "drawer 1", place: "a" }, { ...twelve[0], was: "drawer 1", place: "b" }]);
  check(twice.status === 400 && /twice/.test(twice.body?.error || ""), `named twice: ${twice.status} "${twice.body?.error}"`);
  const long = await place([{ ...twelve[0], was: "drawer 1", place: "x".repeat(41) }]);
  check(long.status === 400 && /at most 40/.test(long.body?.error || ""), `41 characters: ${long.status} "${long.body?.error}"`);
  const number = await place([{ ...twelve[0], was: "drawer 1", place: 3 }]);
  check(number.status === 400, `a number for a place: ${number.status} "${number.body?.error}"`);
  const after3 = (await call(token)).body;
  check(same(after3.places, reread.places) && same(rest(after3), rest(before)) && after3.rev === reread.rev,
    "...none of it changed anything, not even the rev");

  console.log("\n4. two tabs at once");
  const [a, b] = await Promise.all([place([{ ...twelve[0], was: "drawer 1", place: "tab A" }]),
    place([{ ...twelve[1], was: "drawer 2", place: "tab B" }])]);
  const both = (await call(token)).body;
  check(a.status === 200 && b.status === 200 && both.places[keyOf(twelve[0])] === "tab A"
    && both.places[keyOf(twelve[1])] === "tab B" && Object.keys(both.places).length === 12,
    `two parts from two tabs, sent together: ${a.status} and ${b.status}, both kept`);
  const [c, d] = await Promise.all([place([{ ...twelve[2], was: "drawer 3", place: "tab C" }]),
    place([{ ...twelve[2], was: "drawer 3", place: "tab D" }])]);
  const one = (await call(token)).body;
  const kept4 = one.places[keyOf(twelve[2])];
  const won = kept4 === "tab C" ? c : d;
  const lost = kept4 === "tab C" ? d : c;
  check(won.status === 200 && lost.status === 409 && (kept4 === "tab C" || kept4 === "tab D")
    && /kept in "tab [CD]" now, not in "drawer 3"/.test(lost.body?.error || ""),
    `one part from two tabs, both from drawer 3: ${kept4} kept, the other told: ${lost.status} "${lost.body?.error}"`);
  check(same(rest(one), rest(before)), "...and no lot or set changed by any of it");

  console.log("\n5. every other change keeps them");
  const placesNow = one.places;
  const keeps = async (what, reply) => {
    const now = (await call(token)).body;
    check(reply.status === 200 && same(now.places, placesNow), `${what}: ${reply.status}${reply.body?.error ? ` "${reply.body.error}"` : ""}, `
      + `the places as they were`);
    return now;
  };
  await keeps("a lot added", await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3005", colour: 1, qty: 2 }] } }));
  await keeps("a count set", await call(token, { method: "POST", body: { op: "set", id: id(),
    lots: [{ part: "3005", colour: 1, src: "hand", was: 2, qty: 3 }] } }));
  const gone = await call(token, { method: "POST", body: { op: "set", id: id(),
    lots: [{ part: LOTS[0][0], colour: LOTS[0][1], src: "hand", was: LOTS[0][2], qty: 0 }] } });
  const noLot = await keeps(`${LOTS[0][0]}/${LOTS[0][1]} taken to none`, gone);
  check(!noLot.parts.some((p) => keyOf(p) === keyOf(twelve[0])), "...that lot gone, its place kept for when it comes back");
  await keeps("...and brought back", await call(token, { method: "POST", body: { op: "lots", id: id(),
    add: [{ part: LOTS[0][0], colour: LOTS[0][1], qty: LOTS[0][2] }] } }));
  await keeps(`remove_set ${SET}`, await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: SET, src: "hand", was: 1 } }));
  await keeps(`${SET} typed again`, await call(token, { method: "POST", body: { from: "sets", text: SET, id: id() } }));
  await call(token, { method: "POST", body: { from: "sets", text: SET, id: id() } });
  await keeps("an Own down to 1", await call(token, { method: "POST", body: { op: "own", id: id(), set: SET, was: 2, qty: 1 } }));
  await keeps("a Rebrickable fetch replacing", await call(token, { method: "POST", body: { from: "rebrickable_api", mode: "replace",
    id: id(), sets: [[SET, 1, false]], parts: (await call(token)).body.parts.map((p) => [p.part, p.colour, p.qty]) } }));
  // An older app (rel-m267 and before) takes a set out by sending its whole
  // copy, which knows no places, without that set: made as remove_set. Its
  // copy sent as it is, not a removal, is refused as before.
  const held = (await call(token)).body;
  const olderCopy = (without) => ({ sets: held.sets.filter((s) => s.set !== without)
    .map((s) => ({ set: s.set, qty: s.qty, spares: Boolean(s.spares) })),
  parts: held.parts.map((p) => ({ part: p.part, colour: p.colour, qty: p.qty })) });
  const asIs = await call(token, { method: "PUT", body: olderCopy("") });
  const afterAsIs = (await call(token)).body;
  check(asIs.status === 409 && same(afterAsIs.places, placesNow) && same(rest(afterAsIs), rest(held)),
    `an older app's whole copy PUT as it is: ${asIs.status} (not a set taken out), nothing changed, places as they were`);
  await keeps(`an older app's Remove ${SET}: its whole copy PUT without it, no places in it`,
    await call(token, { method: "PUT", body: olderCopy(SET) }));

  console.log("\n6. taken off, then forgotten");
  const offOne = await place([{ ...twelve[3], was: "drawer 4", place: "" }]);
  check(offOne.status === 200 && offOne.body.places[keyOf(twelve[3])] === undefined && Object.keys(offOne.body.places).length === 11,
    `drawer 4 taken off: ${offOne.status}, 11 left`);
  const cur = (await call(token)).body;
  const over6 = await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: cur.rev } });
  check(over6.status === 200 && same(over6.body.places, {}) && over6.body.parts.length === 0,
    `Start over: ${over6.status}, places ${JSON.stringify(over6.body.places)}`);
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3001", colour: 4, qty: 1 }] } });
  await place([{ part: "3001", colour: 4, was: "", place: "drawer 3" }]);
  const deleted = await call(token, { method: "DELETE" });
  check(deleted.status === 200 && same(deleted.body.places, {}) && same((await call(token)).body.places, {}),
    `an older app's Start over (DELETE): ${deleted.status}, places ${JSON.stringify(deleted.body?.places)}`);
} catch (error) {
  if (error !== "pure") {
    console.log(`  FAIL  ${error.stack || error}`);
    failures += 1;
  }
} finally {
  if (token) check(await globalThis.deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\npartplaces API test: every check passed" : `\npartplaces API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
