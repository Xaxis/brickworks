// Does /api/collection keep a person's collection, and refuse what it should?
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 8790 &
//   node tools/web/collection_probe.mjs --url=http://127.0.0.1:8790
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_probe.mjs --url=<a preview>
//
// Against the real function and the real database, as two throwaway
// accounts at Resend test addresses (their sessions minted here, as every
// test here mints one; nobody is emailed). One imports a Rebrickable sets
// export, a Rebrickable parts export, a BrickLink wanted list and a set
// typed by number, and the probe reads back what was kept, in LDraw's
// numbers. The other tries to reach it: by naming the first account to the
// endpoint, by writing to it, and straight at the database with the
// publishable key the app holds, where row security answers. Then the
// refusals: no sign-in, a body over the limit, a collection over the
// limit, and files that are not what they say. Both accounts are deleted
// at the end, and the probe checks their rows went with them.
import { deleteAccount, mintSession } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:8790").replace(/\/+$/, "");
const bypass = process.env.BW_BYPASS || "";
const stamp = Date.now().toString(36);
const EMAIL_A = `delivered+bw-collection-a-${stamp}@resend.dev`;
const EMAIL_B = `delivered+bw-collection-b-${stamp}@resend.dev`;
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

async function call(token, { method = "GET", body, raw, query = "", headers = {} } = {}) {
  const sent = { ...headers };
  if (bypass) sent["x-vercel-protection-bypass"] = bypass;
  if (token) sent.authorization = `Bearer ${token}`;
  let payload;
  if (raw !== undefined) {
    sent["content-type"] = sent["content-type"] || "application/json";
    payload = raw;
  } else if (body !== undefined) {
    sent["content-type"] = "application/json";
    payload = JSON.stringify(body);
  }
  const reply = await fetch(`${base}/api/collection${query}`, { method, headers: sent, body: payload });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: reply.status, body: json, text };
}

const lot = (collection, part, colour) =>
  (collection?.parts || []).find((p) => p.part === part && p.colour === colour);
const set = (collection, number) => (collection?.sets || []).find((s) => s.set === number);

async function database(token, path, { method = "GET", body } = {}) {
  const headers = { apikey: process.env.SUPABASE_PUBLISHABLE_KEY || "", "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  const reply = await fetch(`${SUPABASE}/rest/v1/${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await reply.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: reply.status, body: json };
}

async function serviceRows(owner) {
  const secret = process.env.SUPABASE_SECRET_KEY;
  const reply = await fetch(`${SUPABASE}/rest/v1/collections?owner=eq.${owner}&select=owner`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` },
  });
  return reply.ok ? (await reply.json()).length : -1;
}

let a;
let b;
try {
  console.log(`collection probe against ${base}`);
  a = await mintSession(EMAIL_A);
  b = await mintSession(EMAIL_B);
  const idA = a.kept.user_id;
  const idB = b.kept.user_id;
  check(Boolean(idA && idB && idA !== idB), "two throwaway accounts, signed in");

  console.log("\nsigned out");
  const none = await call(null);
  check(none.status === 401, `no sign-in is refused (${none.status}: ${none.body?.error})`);
  const forged = await call("not.a.token");
  check(forged.status === 401, `a made-up token is refused (${forged.status})`);

  console.log("\nimports, in LDraw's numbers");
  const empty = await call(a.access_token);
  check(empty.status === 200 && empty.body.sets.length === 0 && empty.body.parts.length === 0,
    "a new account's collection is empty");
  const sets = await call(a.access_token, { method: "POST", body: {
    from: "rebrickable_csv", mode: "add",
    text: "Set Number,Quantity,Includes Spares,Inventory ver\n6020-1,2,False,1\n10237,1,True,1\n" } });
  check(sets.status === 200 && sets.body.imported?.sets === 2,
    `a Rebrickable sets export: two sets (${sets.status} ${sets.text.slice(0, 120)})`);
  check(set(sets.body, "6020-1")?.qty === 2 && set(sets.body, "10237-1")?.spares === true,
    "...6020-1 twice, and 10237 kept as 10237-1 with its spares");
  const parts = await call(a.access_token, { method: "POST", body: {
    from: "rebrickable_csv",
    text: "Part,Color,Quantity\n3001,4,10\n3023,71,4\n\"3626bpr0001\",14,1\n3001,9999,3\n" } });
  check(parts.status === 200 && parts.body.imported?.lots === 3,
    `a Rebrickable parts export: three lots kept (${parts.status} ${JSON.stringify(parts.body?.imported)})`);
  check(lot(parts.body, "3001", 4)?.qty === 10 && Boolean(lot(parts.body, "3023b", 71) || lot(parts.body, "3023", 71)),
    "...red 2 x 4s as LDraw red, and the 1 x 2 plate in light bluish grey");
  check((parts.body.left_out || []).some((o) => o.count === 3 && /No Color/.test(o.why)),
    `...and the three in [No Color] left out and said so (${JSON.stringify(parts.body.left_out)})`);
  const wanted = await call(a.access_token, { method: "POST", body: { from: "bricklink_xml", text:
    "<INVENTORY>\n <ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3001</ITEMID><COLOR>5</COLOR><MINQTY>2</MINQTY></ITEM>\n" +
    " <ITEM><ITEMTYPE>P</ITEMTYPE><ITEMID>3005</ITEMID><COLOR>11</COLOR><QTY>7</QTY></ITEM>\n" +
    " <ITEM><ITEMTYPE>M</ITEMTYPE><ITEMID>lor072</ITEMID><MINQTY>1</MINQTY></ITEM>\n</INVENTORY>\n" } });
  check(wanted.status === 200 && lot(wanted.body, "3001", 4)?.qty === 12 && lot(wanted.body, "3005", 0)?.qty === 7,
    `a BrickLink wanted list: BrickLink red is LDraw red and adds to the 10 (12), black 1 x 1s (${wanted.status})`);
  check((wanted.body.left_out || []).some((o) => /minifigures/.test(o.why)),
    "...and its minifigure is left out and said so");
  const typed = await call(a.access_token, { method: "POST", body: { from: "sets", text: "75192, 6020-1" } });
  check(typed.status === 200 && set(typed.body, "75192-1")?.qty === 1 && set(typed.body, "6020-1")?.qty === 3,
    "sets typed by number: 75192 is 75192-1, and a third 6020-1 adds to the two");
  const fetched = await call(a.access_token, { method: "POST", body: { from: "rebrickable_api",
    sets: [["6020-1", 1, false]], parts: [["3023", 71, 2], ["3001", -1, 1]] } });
  check(fetched.status === 200 && fetched.body.imported?.sets === 1 && fetched.body.imported?.lots === 1
    && (fetched.body.left_out || []).some((o) => o.count === 1),
    `what the app read from a Rebrickable account is mapped the same way (${fetched.status} ${JSON.stringify(fetched.body?.imported)})`);
  const back = await call(a.access_token);
  check(back.status === 200 && back.body.sets.length === 3 && lot(back.body, "3001", 4)?.qty === 12
    && set(back.body, "6020-1")?.qty === 4 && Boolean(back.body.updated_at),
    "read back: three sets (four Magic Shops), twelve red 2 x 4s, and when");
  const replaced = await call(a.access_token, { method: "POST", body: {
    from: "rebrickable_csv", mode: "replace", text: "Set Number,Quantity\n6020-1,1\n" } });
  check(replaced.status === 200 && replaced.body.sets.length === 1 && lot(replaced.body, "3001", 4)?.qty === 12,
    "replace with a sets list replaces the sets and keeps the loose parts");

  console.log("\nanother account");
  const theirs = await call(b.access_token);
  check(theirs.status === 200 && theirs.body.sets.length === 0 && theirs.body.parts.length === 0,
    "the other account sees its own empty collection, not the first one's");
  const named = await call(b.access_token, { query: `?owner=${idA}` });
  check(named.status === 403, `naming the first account is refused (${named.status}: ${named.body?.error})`);
  const namedUser = await call(b.access_token, { query: `?user_id=${idA}` });
  check(namedUser.status === 403, `...by any name (${namedUser.status})`);
  const overwrite = await call(b.access_token, { method: "PUT", body: { owner: idA, sets: [], parts: [] } });
  check(overwrite.status === 403, `writing to it is refused (${overwrite.status})`);
  const stillThere = await call(a.access_token);
  check(stillThere.body.sets.length === 1 && lot(stillThere.body, "3001", 4)?.qty === 12,
    "...and the first account's collection is untouched");
  // The keys a page holds reach nothing in the database (2026-10-24,
  // supabase/no_client_access.sql): a collection is reached only through
  // /api/collection, which asks as the server.
  const straight = await database(b.access_token, `collections?owner=eq.${idA}&select=*`);
  check(straight.status === 401 || straight.status === 403,
    `straight at the database with the app's key and another session, it is refused (${straight.status})`);
  const own = await database(a.access_token, `collections?select=owner`);
  check(own.status === 401 || own.status === 403,
    `...and with the owner's own session too: only /api/collection reaches it (${own.status})`);
  const planted = await database(b.access_token, "collections", { method: "POST",
    body: { owner: idA, sets: [], parts: [] } });
  check(planted.status === 401 || planted.status === 403,
    `inserting a row for the first account is refused by row security (${planted.status})`);
  const anon = await database(null, "collections?select=*");
  check(anon.status === 401 || anon.status === 403 || (Array.isArray(anon.body) && anon.body.length === 0),
    `the anonymous key reaches nothing (${anon.status})`);

  console.log("\ntoo big");
  const huge = await call(a.access_token, { method: "POST", body: {
    from: "rebrickable_csv", text: "Part,Color,Quantity\n" + "3001,4,1\n".repeat(130000) } });
  check(huge.status === 413, `a body over a megabyte is refused (${huge.status}: ${huge.body?.error})`);
  const many = await call(a.access_token, { method: "PUT", body: { sets: [],
    parts: Array.from({ length: 20001 }, (_, n) => ({ part: `p${n}`, colour: 4, qty: 1 })) } });
  check(many.status === 413, `a collection over 20,000 lots is refused (${many.status}: ${many.body?.error})`);
  const lots = await call(a.access_token, { method: "POST", body: { from: "sets",
    text: Array.from({ length: 5001 }, (_, n) => `${n + 1}-1`).join(" ") } });
  check(lots.status === 413, `...and over 5,000 sets (${lots.status})`);

  console.log("\nnot what it says it is");
  const bad = [
    ["a CSV with neither heading", { from: "rebrickable_csv", text: "hello,world,quantity\n1,2,3\n" }, /neither a sets list/],
    ["a colour that is not a number", { from: "rebrickable_csv", text: "Part,Color,Quantity\n3001,red,2\n" }, /line 2/],
    ["a quantity that is not a whole number", { from: "rebrickable_csv", text: "Set Number,Quantity\n10237-1,lots\n" }, /line 2/],
    ["no quantity column", { from: "rebrickable_csv", text: "Part,Color\n3001,4\n" }, /Quantity/],
    ["a quote never closed", { from: "rebrickable_csv", text: "Part,Color,Quantity\n\"3001,4,2\n" }, /quoted/],
    ["a heading and nothing else", { from: "rebrickable_csv", text: "Part,Color,Quantity\n" }, /nothing under it/],
    ["an empty file", { from: "rebrickable_csv", text: "" }, /empty/],
    ["XML that is not BrickLink's", { from: "bricklink_xml", text: "<foo/>" }, /INVENTORY/],
    ["a set number that is not one", { from: "sets", text: "10237-1 <script>" }, /not a set number/],
    ["an import that says nothing about itself", { text: "Part,Color,Quantity\n3001,4,1\n" }, /say what this is/],
  ];
  for (const [what, body, said] of bad) {
    const got = await call(a.access_token, { method: "POST", body });
    check(got.status === 400 && said.test(got.body?.error || ""), `${what}: 400 "${got.body?.error}"`);
  }
  const notJson = await call(a.access_token, { method: "POST", raw: "{this is not json" });
  check(notJson.status === 400, `a body that is not JSON is refused (${notJson.status})`);
  const patch = await call(a.access_token, { method: "PATCH", body: {} });
  check(patch.status === 405, `PATCH is not a verb here (${patch.status})`);
  const after = await call(a.access_token);
  check(after.body.sets.length === 1 && lot(after.body, "3001", 4)?.qty === 12,
    "none of the refusals changed what was kept");

  console.log("\nforgetting");
  const gone = await call(a.access_token, { method: "DELETE" });
  const empty2 = await call(a.access_token);
  check(gone.status === 200 && empty2.body.sets.length === 0 && empty2.body.parts.length === 0,
    "Start over empties it");
  await call(a.access_token, { method: "POST", body: { from: "sets", text: "6020-1" } });
  check(await serviceRows(idA) === 1, "a row is kept again after one more import");
  check(await deleteAccount(EMAIL_A) && await deleteAccount(EMAIL_B), "both throwaway accounts deleted");
  check(await serviceRows(idA) === 0 && await serviceRows(idB) === 0, "...and their rows went with them");
  a = null;
  b = null;
} catch (error) {
  console.log(`  FAIL  ${error.stack || error}`);
  failures += 1;
} finally {
  if (a) await deleteAccount(EMAIL_A);
  if (b) await deleteAccount(EMAIL_B);
}
console.log(failures === 0 ? "\ncollection probe: every check passed" : `\ncollection probe: ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
