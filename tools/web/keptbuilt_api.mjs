// Does /api/collection keep a set marked built, through every other change,
// its files and an older app, and never lose anything else?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 10461 &
//   tools/release/live_db.sh keptbuilt node tools/web/keptbuilt_api.mjs --url=http://127.0.0.1:10461
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/keptbuilt_api.mjs --url=<a preview>
//
// APP_UX9 #6 keptbuilt (2026-11-16): additive only. A set entry may carry
// "built", how many of its copies stand built on a shelf (op "built", every
// copy of the number together). Against the real function and the real
// database, as one throwaway account at a Resend test address (its session
// minted here; nobody is emailed), deleted at the end:
//
//   1. an older collection: 7140-1 and 6020-1 typed, 12 loose lots, 7140-1
//      with a part marked missing
//   2. 7140-1 marked built (was 0, built 1): kept as built 1 on its entry,
//      every other set, mark and lot as it was; read again, the same; sent
//      again with its id, made once
//   3. refused, changing nothing: from a count no longer shown (409, the
//      collection as it is), more than the copies owned (400), a set not
//      owned (409), a set named twice (400)
//   4. every other change keeps the mark: a lot added, a count set, the
//      missing mark changed, a second copy typed (built 1 of 2), an Own
//      down to 1 (the copy kept apart goes: built 1 of 1), an Own back up,
//      a Rebrickable fetch that lists it (replaced, the mark carried), the
//      same fetch with fewer copies than built (said: "unbuilt"), remove_set
//      of 6020-1, and an older app's Remove a set (its whole copy PUT) of
//      6020-1 typed again
//   5. the files: the app's own CSV (Built column) and XML (REMARKS Built)
//      read back into an empty collection keep the mark, copy for copy; a
//      Rebrickable CSV with no Built column carries the marks on a replace
//   6. taken apart (built 0): the entry as the older shape, no "built" left;
//      then the whole older collection of step 1, lot for lot
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:10461").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL = `delivered+bw-keptbuilt-${stamp}@resend.dev`;

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
const id = () => `kbapi-${stamp}-${ids++}`;
/// jsonb keeps an object's keys in an order of its own.
const canon = (v) => (Array.isArray(v) ? v.map(canon) : v && typeof v === "object"
  ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v);
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));
const entriesOf = (c, number) => (c?.sets || []).filter((s) => s.set === number && !s.fig);
const copiesOf = (c, number) => entriesOf(c, number).reduce((n, s) => n + s.qty, 0);
const builtOf = (c, number) => entriesOf(c, number).reduce((n, s) => n + (s.built || 0), 0);
const others = (c, number) => (c?.sets || []).filter((s) => s.set !== number);
/// Everything but the built marks: what no op on built may change.
const unbuilt = (c) => ({ sets: (c?.sets || []).map(({ built, ...rest }) => rest), parts: c?.parts || [] });
const olderCopy = (c) => ({
  sets: c.sets.map((s) => ({ set: s.set, qty: s.qty, spares: Boolean(s.spares) })),
  parts: c.parts.map((p) => ({ part: p.part, colour: p.colour, qty: p.qty })),
});
const LOTS = [["3001", 4, 12], ["3020", 0, 4], ["3021", 4, 4], ["4600", 0, 2], ["4624", 71, 4], ["3641", 0, 4],
  ["3004", 15, 6], ["3023", 15, 6], ["3024", 47, 4], ["3069b", 0, 4], ["3010", 1, 4], ["3062b", 14, 2]];

let token = null;
try {
  console.log(`keptbuilt API test against ${base}`);
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");
  const built = (sets, extra = {}) => call(token, { method: "POST", body: { op: "built", id: id(), sets, ...extra } });

  console.log("\n1. an older collection");
  await call(token, { method: "POST", body: { from: "sets", text: "7140, 6020", id: id() } });
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: LOTS.map(([part, colour, qty]) => ({ part, colour, qty })) } });
  await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: [{ part: "3023", colour: 7, was: 0, qty: 1 }] } });
  const older = (await call(token)).body;
  check(older.sets.length === 2 && older.parts.length === 12 && older.sets.every((s) => !("built" in s))
    && entriesOf(older, "7140-1")[0]?.missing?.length === 1,
    `two sets, 12 lots, 7140-1 with 1 marked missing, nothing built (${JSON.stringify(older.sets)})`);

  console.log("\n2. 7140-1 marked built");
  const once = id();
  const marked = await call(token, { method: "POST", body: { op: "built", id: once, sets: [{ set: "7140", was: 0, built: 1 }] } });
  check(marked.status === 200 && builtOf(marked.body, "7140-1") === 1 && entriesOf(marked.body, "7140-1")[0].built === 1
    && same(marked.body.done?.built, [{ set: "7140-1", was: 0, built: 1 }]),
    `marked: ${marked.status}, built 1 on 7140-1's entry (${JSON.stringify(marked.body?.done)})`);
  check(same(unbuilt(marked.body), unbuilt(older)), "...every other set, its missing mark and every lot as they were");
  const reread = (await call(token)).body;
  check(same(reread.sets, marked.body.sets) && same(reread.parts, marked.body.parts), "...and read again, the same");
  const again = await call(token, { method: "POST", body: { op: "built", id: once, sets: [{ set: "7140-1", was: 0, built: 1 }] } });
  check(again.status === 200 && again.body.done?.again === true && builtOf(again.body, "7140-1") === 1,
    `sent again with its id: made once (${again.status}, again ${again.body?.done?.again})`);

  console.log("\n3. what is refused, changing nothing");
  const stale = await built([{ set: "7140-1", was: 0, built: 1 }]);
  check(stale.status === 409 && builtOf(stale.body, "7140-1") === 1,
    `from a count no longer shown (0, not 1): ${stale.status} "${stale.body?.error}", the collection as it is`);
  const past = await built([{ set: "7140-1", was: 1, built: 2 }]);
  check(past.status === 400 && /one copy/.test(past.body?.error || ""), `2 built of 1 owned: ${past.status} "${past.body?.error}"`);
  const notOwned = await built([{ set: "9493-1", was: 0, built: 1 }]);
  check(notOwned.status === 409, `a set not owned: ${notOwned.status} "${notOwned.body?.error}"`);
  const twice = await built([{ set: "7140-1", was: 1, built: 0 }, { set: "7140", was: 1, built: 1 }]);
  check(twice.status === 400 && /twice/.test(twice.body?.error || ""), `named twice: ${twice.status} "${twice.body?.error}"`);
  const after3 = (await call(token)).body;
  check(same(after3.sets, reread.sets) && same(after3.parts, reread.parts), "...none of it changed anything");

  console.log("\n4. every other change keeps the mark");
  const lotAdded = await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3005", colour: 1, qty: 2 }] } });
  check(builtOf(lotAdded.body, "7140-1") === 1, "a lot added: 7140-1 still built");
  const counted = await call(token, { method: "POST", body: { op: "set", id: id(),
    lots: [{ part: "3005", colour: 1, src: "hand", was: 2, qty: 3 }] } });
  check(counted.status === 200 && builtOf(counted.body, "7140-1") === 1, "a count set: still built");
  const remarked = await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: [{ part: "3023", colour: 7, was: 1, qty: 2 }] } });
  check(remarked.status === 200 && builtOf(remarked.body, "7140-1") === 1
    && entriesOf(remarked.body, "7140-1")[0].missing[0].qty === 2, "its missing mark changed: still built, the mark 2");
  const second = await call(token, { method: "POST", body: { from: "sets", text: "7140-1", id: id() } });
  check(copiesOf(second.body, "7140-1") === 2 && builtOf(second.body, "7140-1") === 1,
    `a second copy typed: ${builtOf(second.body, "7140-1")} of ${copiesOf(second.body, "7140-1")} built`);
  const down = await call(token, { method: "POST", body: { op: "own", id: id(), set: "7140-1", was: 2, qty: 1 } });
  const afterDown = (await call(token)).body;
  check(down.status === 200 && copiesOf(afterDown, "7140-1") === 1 && builtOf(afterDown, "7140-1") === 1,
    `an Own down to 1: the copy kept apart went, ${builtOf(afterDown, "7140-1")} of ${copiesOf(afterDown, "7140-1")} built`);
  const up = await call(token, { method: "POST", body: { op: "own", id: id(), set: "7140-1", was: 1, qty: 2 } });
  const afterUp = (await call(token)).body;
  check(up.status === 200 && copiesOf(afterUp, "7140-1") === 2 && builtOf(afterUp, "7140-1") === 1,
    `an Own back up to 2: ${builtOf(afterUp, "7140-1")} of ${copiesOf(afterUp, "7140-1")} built`);
  await call(token, { method: "POST", body: { op: "own", id: id(), set: "7140-1", was: 2, qty: 1 } });
  const fetched = await call(token, { method: "POST", body: { from: "rebrickable_api", mode: "replace", id: id(),
    sets: [["7140-1", 1, false]], parts: [] } });
  check(fetched.status === 200 && copiesOf(fetched.body, "7140-1") === 1 && builtOf(fetched.body, "7140-1") === 1
    && !fetched.body.done?.unbuilt,
    `a Rebrickable fetch that lists 7140-1: replaced, the mark carried (${JSON.stringify(entriesOf(fetched.body, "7140-1"))})`);
  // Two built of two, then a fetch that keeps one: the second mark is said.
  await call(token, { method: "POST", body: { from: "sets", text: "7140-1", id: id() } });
  const two = await built([{ set: "7140-1", was: 1, built: 2 }]);
  check(two.status === 200 && builtOf(two.body, "7140-1") === 2, "a second copy, both marked built");
  const fewer = await call(token, { method: "POST", body: { from: "rebrickable_api", mode: "replace", id: id(),
    sets: [["7140-1", 1, false]], parts: [] } });
  check(fewer.status === 200 && copiesOf(fewer.body, "7140-1") === 1 && builtOf(fewer.body, "7140-1") === 1
    && same(fewer.body.done?.unbuilt, [{ set: "7140-1", copies: 1 }]) && fewer.body.done?.unbuilt_sets === 1,
    `a fetch that keeps 1 of the 2 built: 1 built, the other said (${JSON.stringify(fewer.body.done?.unbuilt ?? null)})`);
  const removed = await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: "6020-1", src: "hand", was: 1 } });
  check(removed.status === 200 && builtOf(removed.body, "7140-1") === 1 && !entriesOf(removed.body, "6020-1").length,
    "remove_set of 6020-1: gone, 7140-1 still built");
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1", id: id() } });
  const kept = (await call(token)).body;
  const olderSent = olderCopy({ sets: kept.sets.filter((s) => s.set !== "6020-1"), parts: kept.parts });
  const put = await call(token, { method: "PUT", body: olderSent });
  check(put.status === 200 && builtOf(put.body, "7140-1") === 1 && !entriesOf(put.body, "6020-1").length,
    `an older app's Remove (its whole copy PUT, "built" unknown to it) of 6020-1: ${put.status}, 7140-1 still built`);

  console.log("\n5. the files");
  const now = (await call(token)).body;
  const sets = now.sets.filter((s) => !s.fig);
  const csv = ["Set Number,Quantity,Includes Spares,Built",
    ...sets.map((s) => `${s.set},${s.qty},${s.spares ? "True" : "False"},${s.built || 0}`)].join("\r\n");
  const xml = ["<INVENTORY>", ...sets.flatMap((s) => [
    ...(s.built ? [`<ITEM><ITEMTYPE>S</ITEMTYPE><ITEMID>${s.set}</ITEMID><QTY>${s.built}</QTY><REMARKS>Built</REMARKS></ITEM>`] : []),
    ...(s.qty > (s.built || 0) ? [`<ITEM><ITEMTYPE>S</ITEMTYPE><ITEMID>${s.set}</ITEMID><QTY>${s.qty - (s.built || 0)}</QTY></ITEM>`] : []),
  ]), "</INVENTORY>"].join("\n");
  const before5 = { copies: copiesOf(now, "7140-1"), built: builtOf(now, "7140-1") };
  await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: now.rev } });
  const fromCsv = await call(token, { method: "POST", body: { from: "rebrickable_csv", text: csv, mode: "add", id: id() } });
  check(fromCsv.status === 200 && copiesOf(fromCsv.body, "7140-1") === before5.copies && builtOf(fromCsv.body, "7140-1") === before5.built,
    `the CSV read back into an empty collection: 7140-1 ${builtOf(fromCsv.body, "7140-1")} of ${copiesOf(fromCsv.body, "7140-1")} built`);
  const afterCsv = (await call(token)).body;
  await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: afterCsv.rev } });
  const fromXml = await call(token, { method: "POST", body: { from: "bricklink_xml", text: xml, mode: "add", id: id() } });
  check(fromXml.status === 200 && copiesOf(fromXml.body, "7140-1") === before5.copies && builtOf(fromXml.body, "7140-1") === before5.built,
    `the XML read back into an empty collection: 7140-1 ${builtOf(fromXml.body, "7140-1")} of ${copiesOf(fromXml.body, "7140-1")} built`);
  // Rebrickable's own sets list says nothing of built: a replace carries the marks.
  const plain = await call(token, { method: "POST", body: { from: "rebrickable_csv", mode: "replace", id: id(),
    text: "Set Number,Quantity,Includes Spares\n7140-1,1,False\n" } });
  check(plain.status === 200 && builtOf(plain.body, "7140-1") === before5.built,
    `a Rebrickable CSV with no Built column, replacing: the mark carried (${builtOf(plain.body, "7140-1")} built)`);
  const wrongCell = await call(token, { method: "POST", body: { from: "rebrickable_csv", mode: "add", id: id(),
    text: "Set Number,Quantity,Built\n7140-1,1,maybe\n" } });
  check(wrongCell.status === 400 && /Built "maybe"/.test(wrongCell.body?.error || ""),
    `a Built cell that is no count or yes/no: ${wrongCell.status} "${wrongCell.body?.error}"`);

  console.log("\n6. taken apart, then the older collection lot for lot");
  const cur = (await call(token)).body;
  const apart = await built([{ set: "7140-1", was: builtOf(cur, "7140-1"), built: 0 }]);
  check(apart.status === 200 && builtOf(apart.body, "7140-1") === 0 && entriesOf(apart.body, "7140-1").every((s) => !("built" in s)),
    `taken apart: no "built" left on any entry (${JSON.stringify(entriesOf(apart.body, "7140-1"))})`);
  // Back to step 1's collection: the same sets, marks and lots as the older one.
  await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: apart.body.rev } });
  await call(token, { method: "POST", body: { from: "sets", text: "7140, 6020", id: id() } });
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: LOTS.map(([part, colour, qty]) => ({ part, colour, qty })) } });
  await call(token, { method: "POST", body: { op: "missing", id: id(), set: "7140-1", src: "hand",
    lots: [{ part: "3023", colour: 7, was: 0, qty: 1 }] } });
  const marked6 = await built([{ set: "7140-1", was: 0, built: 1 }]);
  const apart6 = await built([{ set: "7140-1", was: 1, built: 0 }]);
  check(marked6.status === 200 && apart6.status === 200 && same(apart6.body.sets, older.sets) && same(apart6.body.parts, older.parts),
    "built and taken apart again: the older collection of step 1, set for set and lot for lot");
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (token) check(await deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\nkeptbuilt API test: every check passed" : `\nkeptbuilt API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
