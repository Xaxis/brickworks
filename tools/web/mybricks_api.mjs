// Does /api/collection keep loose lots one at a time, and a session's apart?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 9911 &
//   node tools/web/mybricks_api.mjs --url=http://127.0.0.1:9911
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/mybricks_api.mjs --url=<a preview>
//
// APP_UX5 #2 mybricks (2026-11-06): My collection takes loose parts by hand
// and from a session over MCP, as {"from": "lots", "set": [...], "add":
// [...]}. Against the real function and the real database, as one
// throwaway account at a Resend test address (its session minted here, as
// every test here mints one; nobody is emailed), deleted at the end.
//
//   1. a collection made the old ways first: two sets, a Rebrickable parts
//      export and a BrickLink wanted list; kept as it reads back
//   2. twelve loose lots in one change, each its own lot or added to the
//      person's own of the same part and colour; the old lots and the sets
//      as they were, in their places
//   3. one lot changed, one taken out, by itself
//   4. a session's twelve, marked as its own (by, chat), apart from the
//      person's of the same part and colour; a PUT of the whole (Remove a
//      set) keeps the marks
//   5. taken back: exactly those twelve gone, everything else lot for lot as
//      before
//   6. what is refused, with words: a count of 0 to add, a colour that is
//      not a code, a chat with no one, a session's name that is not one,
//      too many lots at once; none of it changes anything
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

const own = (c) => (c?.parts || []).filter((p) => !p.by);
const theirs = (c) => (c?.parts || []).filter((p) => p.by);
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const lot = (c, part, colour, by = "") =>
  (c?.parts || []).find((p) => p.part === part && p.colour === colour && (p.by || "") === by);

/// Twelve lots a person might count out of a tub: none of them in the
/// old collection's loose lots, so each is a lot of its own.
const TWELVE = [
  ["3004", 4, 6], ["3010", 15, 4], ["3020", 71, 3], ["3022", 0, 5], ["3023", 14, 8], ["3024", 1, 10],
  ["3040", 4, 2], ["3062b", 46, 4], ["3069b", 72, 6], ["3710", 2, 3], ["4070", 15, 2], ["6141", 36, 12],
].map(([part, colour, qty]) => ({ part, colour, qty }));

let token = null;
try {
  console.log(`mybricks API test against ${base}`);
  const session = await mintSession(EMAIL);
  token = session.access_token;
  check(Boolean(token && session.kept.user_id), "a throwaway account, signed in");

  console.log("\n1. a collection made the old ways");
  await call(token, { method: "POST", body: { from: "sets", text: "6020-1, 10237" } });
  await call(token, { method: "POST", body: { from: "rebrickable_csv",
    text: "Part,Color,Quantity\n3001,4,10\n3023,71,4\n3005,0,7\n" } });
  await call(token, { method: "POST", body: { from: "bricklink_xml", text:
    "<INVENTORY><ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3001</ITEMID><COLOR>5</COLOR><MINQTY>2</MINQTY></ITEM>"
    + "<ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3666</ITEMID><COLOR>11</COLOR><QTY>3</QTY></ITEM></INVENTORY>" } });
  const before = await call(token);
  check(before.status === 200 && before.body.sets.length === 2 && own(before.body).length === 4
    && lot(before.body, "3001", 4)?.qty === 12,
    `two sets and four lots (${JSON.stringify(before.body?.parts)})`);

  console.log("\n2. twelve loose lots, one change");
  const added = await call(token, { method: "POST", body: { from: "lots", add: TWELVE } });
  check(added.status === 200 && added.body.imported?.lots === 12,
    `added: ${added.status} ${JSON.stringify(added.body?.imported)}`);
  check(same(added.body.sets, before.body.sets), "...the sets as they were");
  check(same(added.body.parts.slice(0, 4), before.body.parts),
    "...the four old lots as they were, in their places");
  check(TWELVE.every((t) => lot(added.body, t.part, t.colour)?.qty === t.qty) && added.body.parts.length === 16,
    "...and the twelve after them, each at its count");
  const more = await call(token, { method: "POST", body: { from: "lots", add: [{ part: "3004", colour: 4, qty: 1 }] } });
  check(lot(more.body, "3004", 4)?.qty === 7 && more.body.parts.length === 16,
    "one more of a part and colour already there adds to that lot: 6 + 1 = 7, still 16 lots");

  console.log("\n3. one lot changed, one taken out, by itself");
  const changed = await call(token, { method: "POST", body: { from: "lots",
    set: [{ part: "3004", colour: 4, qty: 6 }, { part: "6141", colour: 36, qty: 0 }] } });
  check(changed.status === 200 && lot(changed.body, "3004", 4)?.qty === 6 && !lot(changed.body, "6141", 36)
    && changed.body.parts.length === 15, `3004 red set to 6, the trans red 1 x 1 rounds taken out (${changed.status})`);
  check(same(changed.body.parts.slice(0, 4), before.body.parts) && same(changed.body.sets, before.body.sets),
    "...and nothing else moved");
  const restored = await call(token, { method: "POST", body: { from: "lots",
    add: [{ part: "6141", colour: 36, qty: 12 }] } });
  check(restored.body.parts.length === 16, "the rounds back, at the end");

  console.log("\n4. a session's twelve, marked as its own");
  const mine = await call(token);
  const marked = TWELVE.map((t) => ({ ...t, by: "Claude", chat: "chat-mybricks-1" }));
  const session12 = await call(token, { method: "POST", body: { from: "lots", add: marked } });
  check(session12.status === 200 && theirs(session12.body).length === 12,
    `twelve lots marked Claude's (${session12.status} ${session12.text.slice(0, 100)})`);
  check(same(own(session12.body), own(mine.body)),
    "...apart from the person's own of the same part and colour, which are as they were");
  check(lot(session12.body, "3004", 4, "Claude")?.chat === "chat-mybricks-1", "...each with its chat");
  const second = await call(token, { method: "POST", body: { from: "lots",
    add: [{ part: "3004", colour: 4, qty: 1, by: "Claude", chat: "chat-mybricks-2" }] } });
  check(theirs(second.body).length === 13, "another chat's lot of the same part and colour is its own lot (13)");
  await call(token, { method: "POST", body: { from: "lots",
    set: [{ part: "3004", colour: 4, qty: 0, by: "Claude", chat: "chat-mybricks-2" }] } });
  const put = await call(token, { method: "PUT", body: { sets: [mine.body.sets[0]], parts: session12.body.parts } });
  check(put.status === 200 && theirs(put.body).length === 12 && lot(put.body, "3004", 4, "Claude")?.chat === "chat-mybricks-1",
    `a set taken out (PUT of the whole) keeps the session's marks (${put.status})`);
  const putBack = await call(token, { method: "POST", body: { from: "sets", text: mine.body.sets[1].set } });
  check(same(putBack.body.sets, mine.body.sets), "...and the set back, in its place");

  console.log("\n5. taken back");
  const back = await call(token, { method: "POST", body: { from: "lots",
    set: theirs(putBack.body).map((p) => ({ ...p, qty: 0 })) } });
  check(back.status === 200 && theirs(back.body).length === 0, "the session's twelve gone");
  check(same(back.body.parts, mine.body.parts) && same(back.body.sets, mine.body.sets),
    "...and the collection lot for lot as before them");

  console.log("\n6. refused, with words");
  const bad = [
    ["a count of 0 to add", { from: "lots", add: [{ part: "3001", colour: 4, qty: 0 }] }, /outside 1/],
    ["a colour that is not a code", { from: "lots", add: [{ part: "3001", colour: "red", qty: 1 }] }, /colour/],
    ["a part that is not a number", { from: "lots", add: [{ part: "<b>", colour: 4, qty: 1 }] }, /part number/],
    ["a chat with no one", { from: "lots", add: [{ part: "3001", colour: 4, qty: 1, chat: "x" }] }, /chat/],
    ["a name that is not one", { from: "lots", add: [{ part: "3001", colour: 4, qty: 1, by: "<script>" }] }, /who added/],
    ["nothing to do", { from: "lots" }, /no lots/],
  ];
  for (const [what, body, said] of bad) {
    const got = await call(token, { method: "POST", body });
    check(got.status === 400 && said.test(got.body?.error || ""), `${what}: ${got.status} "${got.body?.error}"`);
  }
  const many = await call(token, { method: "POST", body: { from: "lots",
    add: Array.from({ length: 2001 }, (_, n) => ({ part: `p${n}`, colour: 4, qty: 1 })) } });
  check(many.status === 413, `2,001 lots at once: ${many.status} "${many.body?.error}"`);
  const after = await call(token);
  check(same(after.body.parts, mine.body.parts) && same(after.body.sets, mine.body.sets),
    "none of the refusals changed anything");
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (token) check(await deleteAccount(EMAIL), "the throwaway account deleted");
}
console.log(failures === 0 ? "\nmybricks API test: every check passed" : `\nmybricks API test: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
