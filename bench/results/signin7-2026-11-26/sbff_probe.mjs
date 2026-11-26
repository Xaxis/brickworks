// signin7: does the project honour Sb-Forwarded-For from a browser's key, or only from the secret key?
// Supabase's docs say only a secret key (sb_secret_) is supported; GoTrue itself (supabase/auth PR 2295)
// checks no key: once security_sb_forwarded_for_enabled is on, it rate-limits by the header's first value
// on any request that reaches it. So whether a browser can send it rests on Supabase's gateway, and this
// asks the project itself. Run it right after the setting is turned on; turn it off again if A is not 429.
//
//   set -a; . ./.env; set +a; node sbff_probe.mjs
//
//   A. 34 POSTs of /auth/v1/verify with a made-up token_hash and the PUBLISHABLE key (what a browser holds),
//      each with a new Sb-Forwarded-For (198.18.0.0/15, set aside for tests). Honoured from a browser: none
//      is 429, each address a bucket of its own (UNSAFE: anyone could guess codes past the per-address
//      limit). Ignored: 429 once this box's 30 are spent.
//   B. 6 more with the SECRET key, each a new Sb-Forwarded-For, after A has emptied this box's bucket:
//      honoured, none is 429 (what Brickworks' server needs).
//   C. 3 with the secret key and no header: 429 (this box's bucket, the control).
// Cost: this box's verify bucket is empty for up to five minutes after (a code typed in a test here
// would be refused 429 meanwhile). Nothing is signed in: every token_hash is made up.
import { randomBytes } from "node:crypto";

const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const PUBLISHABLE = process.env.SUPABASE_PUBLISHABLE_KEY || "";
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SB || !PUBLISHABLE || !SECRET) {
  console.error("sbff_probe: no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY: source .env");
  process.exit(2);
}
const address = () => `198.18.${randomBytes(1)[0] % 2}.${1 + (randomBytes(1)[0] % 254)}`;
async function verify(key, forwarded) {
  const reply = await fetch(`${SB}/auth/v1/verify`, { method: "POST",
    headers: { apikey: key, "content-type": "application/json", ...(forwarded ? { "sb-forwarded-for": forwarded } : {}) },
    body: JSON.stringify({ type: "magiclink", token_hash: randomBytes(28).toString("hex") }) });
  await reply.arrayBuffer();
  return reply.status;
}
const run = async (n, key, withHeader) => {
  const statuses = [];
  for (let i = 0; i < n; i += 1) statuses.push(await verify(key, withHeader ? address() : ""));
  return statuses;
};
const said = (statuses) => [...new Set(statuses)].map((s) => `${s} x${statuses.filter((one) => one === s).length}`).join(", ");

const a = await run(34, PUBLISHABLE, true);
const b = await run(6, SECRET, true);
const c = await run(3, SECRET, false);
const aBusy = a.filter((s) => s === 429).length;
console.log(`A. publishable key, a new Sb-Forwarded-For each: ${said(a)}`);
console.log(`B. secret key, a new Sb-Forwarded-For each, this box's bucket empty: ${said(b)}`);
console.log(`C. secret key, no header (control): ${said(c)}`);
const browserHonoured = aBusy === 0;
const serverHonoured = c.every((s) => s === 429) && b.every((s) => s !== 429);
console.log(browserHonoured
  ? "sbff_probe: UNSAFE: a browser's key gets a bucket per address it names. Turn security_sb_forwarded_for_enabled off."
  : serverHonoured
    ? "sbff_probe: safe: the header is ignored from a browser's key and honoured from the secret key."
    : c.every((s) => s === 429)
      ? "sbff_probe: ignored from both keys (the setting off, or not yet in effect): nothing gained, nothing lost."
      : "sbff_probe: unclear (this box's bucket was not emptied by A): run it again in five minutes.");
process.exit(browserHonoured ? 1 : 0);
