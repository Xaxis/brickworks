// The account menu's Admin (bugbar, 2026-11-13; docs/ADMIN.md): what
// GET /api/people?op=feed_count, the header's "who you are", answers the
// site's owner, another account, an unverified claim to the owner's
// address, and nobody signed in. Through api/people.js's real handler, with
// sessions signed as the billing world signs them; the database's counts
// answered as before their files (each falls back), which feed_count takes.
//
//   node tests/fixtures/menu/admin_check.mjs
//
// Prints one JSON object: each asker's status and the answer's keys, and
// its admin value where there is one.
import { world } from "../billing/world.mjs";

const w = await world({ master: "owner@example.com" });
const { default: people } = await import("../../../api/people.js");

async function feedCount(token) {
  let status = 0;
  let json = null;
  const response = {
    setHeader: () => response,
    status: (s) => { status = s; return response; },
    json: (b) => { json = b; return response; },
    end: () => response,
  };
  await people({ method: "GET", query: { op: "feed_count" }, headers: token ? { authorization: `Bearer ${token}` } : {} }, response);
  return { status, keys: Object.keys(json || {}).sort(), ...(json && "admin" in json ? { admin: json.admin } : {}) };
}

const out = {};
try {
  out.owner = await feedCount(await w.signIn({ sub: "00000000-0000-4000-8000-000000000001", email: "Owner@Example.com" }));
  out.other = await feedCount(await w.signIn({ sub: "00000000-0000-4000-8000-000000000002", email: "ada@example.com" }));
  out.unverified = await feedCount(await w.signIn({ sub: "00000000-0000-4000-8000-000000000003", email: "owner@example.com",
    email_verified: false }));
  out.signed_out = await feedCount(null);
} catch (trouble) {
  out.error = String(trouble?.stack || trouble);
}
console.log(JSON.stringify(out));
