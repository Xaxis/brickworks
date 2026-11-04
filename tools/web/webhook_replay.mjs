// Admission's webhook into a --billing-test preview, signed by Admission's
// own code (golive, 2026-11-03; docs/PLANS.md 8.1). A preview is behind
// Vercel's protection, and its bypass never goes into a URL Admission keeps,
// so Admission's own deliveries cannot reach one: this sends what it would.
// Run under Admission's tsx, so its signing (src/server/webhooks/events.ts
// signatureHeader) is the one used, not a copy of it:
//
//   cd ~/Projects/admission.sh/apps/admission
//   pnpm exec tsx --env-file=/mnt/Projects/brickworks/.env \
//     /mnt/Projects/brickworks/tools/web/webhook_replay.mjs --url=<preview> --out=DIR --phase=start
//   (grant_override, test mode, plan pro, for the account DIR/replay.json names)
//   ... --phase=event --reason=override.created --expect=pro
//   (end_override)
//   ... --phase=event --reason=override.revoked --expect=free
//
// start: a throwaway account, Free, its answer now held for 30 s.
// event: within those 30 s, ?op=plan still says the plan it had; the event
// signed with another secret and the event signed ten minutes ago are both
// refused (400) and forget nothing; the event signed now is heard (200),
// the same again "again"; and the next ?op=plan says [expect]. The body is
// the one Admission sends (its deliver.ts): {id, type, createdAt, mode, seq,
// data: {customerId, reason, customer}}, customer its API's answer now.
// Ends "webhook replay: all ok".
import { mintSession } from "./session.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "");
const out = String(args.out || "");
if (!site || !out || !["start", "event"].includes(args.phase)) {
  console.error("webhook_replay: --url=<a --billing-test preview> --out=DIR --phase=start|event [--reason --expect]");
  process.exit(2);
}
const admissionDir = process.env.ADMISSION_DIR || path.resolve(process.cwd());
const { signatureHeader } = await import(path.join(admissionDir, "src/server/webhooks/events.ts"));
const secret = String(process.env.ADMISSION_TEST_WEBHOOK_SECRET || "");
const key = String(process.env.ADMISSION_TEST_KEY || "");
const bypass = process.env.VERCEL_BYPASS || "";
if (!secret.startsWith("adm_whsec_") || !key.startsWith("adm_test_")) {
  console.error("webhook_replay: ADMISSION_TEST_WEBHOOK_SECRET and ADMISSION_TEST_KEY from .env");
  process.exit(2);
}
mkdirSync(out, { recursive: true });
const kept = path.join(out, "replay.json");

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const preview = (route, init = {}) => fetch(`${site}${route}`, { ...init,
  headers: { ...(init.headers || {}), ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}) } });

if (args.phase === "start") {
  const email = `delivered+bw-hook-${randomBytes(4).toString("hex")}@resend.dev`;
  const who = await mintSession(email);
  writeFileSync(kept, JSON.stringify({ email, id: who.kept.user_id }, null, 1));
  const plan = await (await preview("/api/plans?op=plan", { headers: { authorization: `Bearer ${who.access_token}` } })).json();
  console.log(`account ${who.kept.user_id}`);
  check(`?op=plan: ${plan.plan?.key} (${plan.plan?.source}), now held`, plan.plan?.key === "free");
} else {
  const { email, id } = JSON.parse(readFileSync(kept, "utf8"));
  const who = await mintSession(email);
  const plan = async () => (await (await preview("/api/plans?op=plan",
    { headers: { authorization: `Bearer ${who.access_token}` } })).json()).plan;
  const before = await plan();
  const expect = String(args.expect || "");
  console.log(`  ..    ?op=plan before the event: ${before?.key} (${before?.source}); Admission now says ${expect}`);
  check(`within its 30 s the held answer stands: ${before?.key}`, before?.key !== expect);
  // What Admission's deliver.ts sends: the customer's answer from its API now.
  const customer = await (await fetch(`https://admission.sh/v1/customers/${encodeURIComponent(id)}`,
    { headers: { authorization: `Bearer ${key}` } })).json();
  const body = JSON.stringify({ id: `adm_evt_${randomBytes(12).toString("base64url")}`, type: "customer.updated",
    createdAt: new Date().toISOString(), mode: "test", seq: Date.now(),
    data: { customerId: id, reason: String(args.reason || "override.created"), customer } });
  const send = async (signature) => {
    const r = await preview("/api/plans?op=webhook", { method: "POST", body,
      headers: { "content-type": "application/json", "admission-signature": signature } });
    return { status: r.status, json: await r.json().catch(() => null) };
  };
  const wrong = await send(signatureHeader(body, [`adm_whsec_${randomBytes(16).toString("hex")}`], new Date()));
  check(`signed with another secret: ${wrong.status} ${JSON.stringify(wrong.json)}`, wrong.status === 400);
  const stale = await send(signatureHeader(body, [secret], new Date(Date.now() - 10 * 60_000 - 5000)));
  check(`signed ten minutes ago: ${stale.status} ${JSON.stringify(stale.json)}`, stale.status === 400);
  const still = await plan();
  check(`refused, they forgot nothing: ${still?.key}`, still?.key === before?.key);
  const heard = await send(signatureHeader(body, [secret], new Date()));
  check(`signed now: ${heard.status} ${JSON.stringify(heard.json)}`, heard.status === 200 && heard.json?.heard === "customer.updated");
  const again = await send(signatureHeader(body, [secret], new Date()));
  check(`the same event again: ${again.status} ${JSON.stringify(again.json)}`, again.status === 200 && again.json?.heard === "again");
  const after = await plan();
  check(`?op=plan after it: ${after?.key} (${after?.source})`, after?.key === expect);
}
console.log(failed ? `webhook replay: ${failed} FAILED` : "webhook replay: all ok");
process.exit(failed ? 1 : 0);
