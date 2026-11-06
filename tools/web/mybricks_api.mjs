// Does /api/collection keep loose lots, and a session's apart, with nothing
// ever lost?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9911 &
//   node tools/web/mybricks_api.mjs --url=http://127.0.0.1:9911
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/mybricks_api.mjs --url=<a preview>
//
// APP_UX5 #2 mybricks, written as server-side ops by mybricks2
// (2026-11-06): every change is one op made on the row as kept, written
// only over the rev it read (supabase/collection_ops.sql). Against the real
// function and the real database, as one throwaway account at a Resend test
// address (its session minted here, as every test here mints one; nobody is
// emailed), deleted at the end.
//
//   1. a collection made the old ways first: two sets, a Rebrickable parts
//      export and a BrickLink wanted list; each lot kept with its source
//   2. twelve loose lots in one op, the person's own (hand); the old lots
//      and the sets as they were, in their places; one more of a part and
//      colour already counted adds to that lot
//   3. one lot's count set from what was shown, one taken out; a count from
//      a stale view refused (409, the collection as it is), nothing changed
//   4. a session's twelve, marked as its own (by, chat), apart from the
//      person's of the same part and colour; another chat's lot apart and
//      taken down by its own remove; an older app's PUT refused with words,
//      nothing changed, every mark kept; a set taken out by remove_set, at
//      the count shown, nothing else moved
//   5. taken back at the counts shown: exactly those twelve gone, everything
//      else lot for lot as before; two kept as the person's own
//   6. a Rebrickable fetch (replace) replaces only Rebrickable's lots
//   7. five changes at once, against the real database: all five kept
//   8. an op sent twice with one id is made once
//   9. what is refused, with words: a count of 0 to add, colours that are
//      not codes (a word, null, "", false), a part that is not one, a chat
//      with no one, a name with nothing printable, a change of lots with no
//      id, too many lots at once; none of it changes anything
//  10. Start over from a stale rev refused; from the rev shown, all gone
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:9911").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL = `delivered+bw-mybricks-${stamp}@resend.dev`;

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
const id = () => `mbapi-${stamp}-${ids++}`;
const own = (c) => (c?.parts || []).filter((p) => !p.by);
const theirs = (c) => (c?.parts || []).filter((p) => p.by);
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const lot = (c, part, colour, by = "", src) => (c?.parts || []).find((p) => p.part === part && p.colour === colour
  && (p.by || "") === by && (src === undefined || (p.src || "") === src));
const pieces = (c, part, colour) => (c?.parts || []).filter((p) => p.part === part && p.colour === colour)
  .reduce((n, p) => n + p.qty, 0);
const named = (p) => Object.fromEntries(["part", "colour", "src", "by", "chat"].filter((k) => p[k] !== undefined).map((k) => [k, p[k]]));
const seen = (p) => ({ ...named(p), was: p.qty });

/// Twelve lots a person might count out of a tub: none of them in the
/// old collection's loose lots, so each is a lot of its own.
const TWELVE = [
  ["3004", 4, 6], ["3010", 15, 4], ["3020", 71, 3], ["3022", 0, 5], ["3023", 14, 8], ["3024", 1, 10],
  ["3040", 4, 2], ["3062b", 46, 4], ["3069b", 72, 6], ["3710", 2, 3], ["4070", 15, 2], ["6141", 36, 12],
].map(([part, colour, qty]) => ({ part, colour, qty }));
const CHAT1 = { by: "Claude", chat: "chat-mybricks-1" };

let token = null;
try {
  console.log(`mybricks API test against ${base}`);
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");

  console.log("\n1. a collection made the old ways");
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1, 10237", id: id() } });
  await call(token, { method: "POST", body: { from: "rebrickable_csv", id: id(),
    text: "Part,Color,Quantity\n3001,4,10\n3023,71,4\n3005,0,7\n" } });
  await call(token, { method: "POST", body: { from: "bricklink_xml", id: id(), text:
    "<INVENTORY><ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3001</ITEMID><COLOR>5</COLOR><MINQTY>2</MINQTY></ITEM>"
    + "<ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3666</ITEMID><COLOR>11</COLOR><QTY>3</QTY></ITEM></INVENTORY>" } });
  const before = await call(token);
  check(before.status === 200 && before.body.sets.length === 2 && own(before.body).length === 5
    && pieces(before.body, "3001", 4) === 12 && before.body.sets.every((s) => s.src === "hand")
    && lot(before.body, "3001", 4, "", "rebrickable_csv")?.qty === 10 && lot(before.body, "3001", 4, "", "bricklink_xml")?.qty === 2,
    `two sets typed, five lots each with its source, 12 red 2 x 4s in all (${JSON.stringify(before.body?.parts)})`);
  check(Number.isInteger(before.body.rev) && before.body.rev > 0, `...and the rev it was read at (${before.body.rev})`);

  console.log("\n2. twelve loose lots, one op");
  const added = await call(token, { method: "POST", body: { op: "lots", id: id(), add: TWELVE } });
  check(added.status === 200 && added.body.done?.added === 12, `added: ${added.status} ${JSON.stringify(added.body?.done)}`);
  check(same(added.body.sets, before.body.sets), "...the sets as they were");
  check(same(added.body.parts.slice(0, 5), before.body.parts), "...the five old lots as they were, in their places");
  check(TWELVE.every((t) => lot(added.body, t.part, t.colour, "", "hand")?.qty === t.qty) && added.body.parts.length === 17,
    "...and the twelve after them, each at its count, each the person's own (hand)");
  const more = await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3004", colour: 4, qty: 1 }] } });
  check(lot(more.body, "3004", 4)?.qty === 7 && more.body.parts.length === 17,
    "one more of a part and colour already counted adds to that lot: 6 + 1 = 7, still 17 lots");

  console.log("\n3. counts set from what was shown");
  const shown = more.body;
  const changed = await call(token, { method: "POST", body: { op: "set", id: id(), lots: [
    { ...seen(lot(shown, "3004", 4)), qty: 6 }, { ...seen(lot(shown, "6141", 36)), qty: 0 }] } });
  check(changed.status === 200 && lot(changed.body, "3004", 4)?.qty === 6 && !lot(changed.body, "6141", 36)
    && changed.body.parts.length === 16, `3004 red 7 -> 6, the trans red rounds 12 -> out (${changed.status})`);
  check(same(changed.body.parts.slice(0, 5), before.body.parts) && same(changed.body.sets, before.body.sets),
    "...and nothing else moved");
  const stale = await call(token, { method: "POST", body: { op: "set", id: id(), lots: [
    { ...seen(lot(shown, "3004", 4)), qty: 9 }] } });
  check(stale.status === 409 && /7 shown|is 6 now/.test(stale.body?.error || "") && same(stale.body.parts, changed.body.parts),
    `a count from a stale view (7 shown, 6 kept) refused, the collection as it is sent back (${stale.status} "${stale.body?.error}")`);
  const gone = await call(token, { method: "POST", body: { op: "set", id: id(), lots: [
    { ...seen(lot(shown, "6141", 36)), qty: 3 }] } });
  check(gone.status === 409 && !lot((await call(token)).body, "6141", 36),
    `a count for a lot taken out is refused, never made again (${gone.status} "${gone.body?.error}")`);
  const restored = await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "6141", colour: 36, qty: 12 }] } });
  check(restored.body.parts.length === 17, "the rounds back, at the end");

  console.log("\n4. a session's twelve, marked as its own");
  const mine = await call(token);
  const session12 = await call(token, { method: "POST", body: { op: "lots", id: id(), add: TWELVE.map((t) => ({ ...t, ...CHAT1 })) } });
  check(session12.status === 200 && theirs(session12.body).length === 12,
    `twelve lots marked Claude's (${session12.status} ${session12.text.slice(0, 100)})`);
  check(same(own(session12.body), own(mine.body)), "...apart from the person's own of the same part and colour, which are as they were");
  check(lot(session12.body, "3004", 4, "Claude")?.chat === "chat-mybricks-1", "...each with its chat");
  const second = await call(token, { method: "POST", body: { op: "lots", id: id(),
    add: [{ part: "3004", colour: 4, qty: 1, by: "Claude", chat: "chat-mybricks-2" }] } });
  check(theirs(second.body).length === 13, "another chat's lot of the same part and colour is its own lot (13)");
  const down = await call(token, { method: "POST", body: { op: "lots", id: id(),
    remove: [{ part: "3004", colour: 4, by: "Claude", chat: "chat-mybricks-2" }] } });
  check(down.status === 200 && theirs(down.body).length === 12 && lot(down.body, "3004", 4, "Claude")?.qty === 6,
    "...taken down by its own remove; the first chat's lot of it untouched");
  const notMine = await call(token, { method: "POST", body: { op: "lots", id: id(), remove: [{ part: "3001", colour: 4 }] } });
  check(notMine.status === 400 && /only a lot a session added/.test(notMine.body?.error || ""),
    `a remove of the person's own lot is refused: ${notMine.status} "${notMine.body?.error}"`);
  const asKept = (await call(token)).body;
  const put = await call(token, { method: "PUT", body: { sets: [asKept.sets[0]], parts: asKept.parts.map(({ part, colour, qty }) => ({ part, colour, qty })) } });
  const afterPut = (await call(token)).body;
  check(put.status === 409 && /Update/.test(put.body?.error || "") && same(afterPut.parts, asKept.parts) && same(afterPut.sets, asKept.sets),
    `an older app's PUT (marks stripped, a set out) refused with words to update, nothing changed (${put.status})`);
  const setOut = await call(token, { method: "POST", body: { op: "remove_set", id: id(), set: asKept.sets[1].set, src: asKept.sets[1].src,
    was: asKept.sets[1].qty } });
  check(setOut.status === 200 && same(setOut.body.sets, [asKept.sets[0]]) && same(setOut.body.parts, asKept.parts),
    "a set taken out at the count shown: that set and nothing else");
  const putBack = await call(token, { method: "POST", body: { from: "sets", text: asKept.sets[1].set, id: id() } });
  check(same(putBack.body.sets, mine.body.sets), "...and the set back, in its place");

  console.log("\n5. taken back, and kept");
  const back = await call(token, { method: "POST", body: { op: "take_back", id: id(), lots: theirs(putBack.body).map(seen) } });
  check(back.status === 200 && theirs(back.body).length === 0, "the session's twelve taken back at the counts shown");
  check(same(back.body.parts, mine.body.parts) && same(back.body.sets, mine.body.sets),
    "...and the collection lot for lot as before them");
  const two = await call(token, { method: "POST", body: { op: "lots", id: id(),
    add: [{ part: "3004", colour: 4, qty: 2, ...CHAT1 }, { part: "2357", colour: 15, qty: 1, ...CHAT1 }] } });
  const kept = await call(token, { method: "POST", body: { op: "keep", id: id(), lots: theirs(two.body).map(seen) } });
  check(kept.status === 200 && theirs(kept.body).length === 0 && lot(kept.body, "3004", 4, "", "hand")?.qty === 8
    && lot(kept.body, "2357", 15, "", "hand")?.qty === 1,
    "two kept as the person's own: 6 + 2 = 8 of 3004 red, and a new lot of 2357");
  await call(token, { method: "POST", body: { op: "set", id: id(), lots: [{ ...seen(lot(kept.body, "3004", 4, "", "hand")), qty: 6 },
    { ...seen(lot(kept.body, "2357", 15, "", "hand")), qty: 0 }] } });

  console.log("\n6. a Rebrickable fetch replaces only what Rebrickable brought");
  await call(token, { method: "POST", body: { op: "lots", id: id(), add: [{ part: "3005", colour: 1, qty: 9, ...CHAT1 }] } });
  const fetched1 = await call(token, { method: "POST", body: { from: "rebrickable_api", id: id(), mode: "replace",
    sets: [], parts: [["3001", 4, 5]] } });
  const fetched2 = await call(token, { method: "POST", body: { from: "rebrickable_api", id: id(), mode: "replace",
    sets: [], parts: [["3001", 4, 4]] } });
  check(fetched1.status === 200 && fetched2.status === 200 && lot(fetched2.body, "3001", 4, "", "rebrickable")?.qty === 4
    && same(own(fetched2.body).filter((p) => p.src !== "rebrickable"), own(mine.body)) && lot(fetched2.body, "3005", 1, "Claude")?.qty === 9,
    "fetched twice: Rebrickable's 5 replaced by its 4, every hand, CSV and XML lot and the session's as they were");

  console.log("\n7. five changes at once, against the real database");
  const many = await Promise.all(["3001", "3002", "3003", "3004", "3005"].map((part, n) => call(token, { method: "POST",
    body: { op: "lots", id: id(), add: [{ part, colour: 2, qty: n + 1, ...(n % 2 ? CHAT1 : {}) }] } })));
  const after7 = (await call(token)).body;
  check(many.every((r) => r.status === 200) && ["3001", "3002", "3003", "3004", "3005"].every((part, n) => pieces(after7, part, 2) === n + 1),
    `five lots requests at once all kept (${many.map((r) => r.status).join(" ")}): ${after7.parts.filter((p) => p.colour === 2).length} of 5`);

  console.log("\n8. an op sent twice is made once");
  const once = { op: "lots", id: id(), add: [{ part: "3003", colour: 15, qty: 7 }] };
  const first = await call(token, { method: "POST", body: once });
  const again = await call(token, { method: "POST", body: once });
  check(first.status === 200 && again.status === 200 && again.body.done?.again === true && lot(again.body, "3003", 15)?.qty === 7,
    `sent again with its id: ${again.status} ${JSON.stringify(again.body?.done)}, 7 x 3003 not 14`);

  console.log("\n9. refused, with words");
  const held = (await call(token)).body;
  const bad = [
    ["a count of 0 to add", { op: "lots", id: id(), add: [{ part: "3001", colour: 4, qty: 0 }] }, /outside 1/],
    ["a colour that is a word", { op: "lots", id: id(), add: [{ part: "3001", colour: "red", qty: 1 }] }, /colour/],
    ["a colour of null", { op: "lots", id: id(), add: [{ part: "3001", colour: null, qty: 1 }] }, /colour/],
    ["a colour of \"\"", { op: "lots", id: id(), add: [{ part: "3001", colour: "", qty: 1 }] }, /colour/],
    ["a colour of false", { op: "lots", id: id(), add: [{ part: "3001", colour: false, qty: 1 }] }, /colour/],
    ["colour 16, the colour a part is placed in", { op: "lots", id: id(), add: [{ part: "3001", colour: 16, qty: 1 }] }, /colour/],
    ["a part that is not a number", { op: "lots", id: id(), add: [{ part: "<b>", colour: 4, qty: 1 }] }, /part number/],
    ["a chat with no one", { op: "lots", id: id(), add: [{ part: "3001", colour: 4, qty: 1, chat: "x" }] }, /chat/],
    ["a name with nothing printable", { op: "lots", id: id(), add: [{ part: "3001", colour: 4, qty: 1, by: "\u0000\u0007" }] }, /not a name/],
    ["a change of lots with no id", { op: "lots", add: [{ part: "3001", colour: 4, qty: 1 }] }, /id/],
    ["nothing to do", { op: "lots", id: id() }, /no lots/],
    ["one lot named twice in a set", { op: "set", id: id(), lots: [{ ...seen(lot(held, "3004", 4)), qty: 1 }, { ...seen(lot(held, "3004", 4)), qty: 2 }] }, /twice/],
    ["the old lots form", { from: "lots", add: [{ part: "3001", colour: 4, qty: 1 }] }, /say what this is/],
  ];
  for (const [what, body, said] of bad) {
    const got = await call(token, { method: "POST", body });
    check(got.status === 400 && said.test(got.body?.error || ""), `${what}: ${got.status} "${got.body?.error}"`);
  }
  const tooMany = await call(token, { method: "POST", body: { op: "lots", id: id(),
    add: Array.from({ length: 2001 }, (_, n) => ({ part: `p${n}`, colour: 4, qty: 1 })) } });
  check(tooMany.status === 413, `2,001 lots at once: ${tooMany.status} "${tooMany.body?.error}"`);
  const after = (await call(token)).body;
  check(same(after.parts, held.parts) && same(after.sets, held.sets), "none of the refusals changed anything");

  console.log("\n10. Start over");
  const staleStart = await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: before.body.rev } });
  check(staleStart.status === 409 && (await call(token)).body.parts.length === held.parts.length,
    `from a rev read before the latest change: refused, nothing forgotten (${staleStart.status} "${staleStart.body?.error}")`);
  const started = await call(token, { method: "POST", body: { op: "start_over", id: id(), rev: after.rev } });
  check(started.status === 200 && started.body.sets.length === 0 && started.body.parts.length === 0,
    `from the rev shown: all of it forgotten (${started.status})`);
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (token) check(await deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\nmybricks API test: every check passed" : `\nmybricks API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
