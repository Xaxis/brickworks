// The daily sign-in canary (api/_canary.js), run from a checkout: the
// three checks Vercel's cron runs on production each morning, for a
// release or by hand.
//
//   set -a; . ./.env; set +a
//   node tools/web/canary_check.mjs                       from here, against .env's Supabase
//   node tools/web/canary_check.mjs --url=SITE            and SITE's /api/account asked of
//                                                         (c)'s session
//   node tools/web/canary_check.mjs --url=SITE --route    and SITE's own run asked for too
//                                                         (/api/otp/canary, with CRON_SECRET)
//   node tools/web/canary_check.mjs --stand-in            the canary itself checked
//
// (a) a public sign-up refused and no account left, (b) an address the
// admin API made unconfirmed signing in by no way, (c) a new address
// signing in by a code api/otp.js's own mint and deliver made and sent,
// enrolling no authenticator app. Run from here it records nothing and
// mails nobody: a FAIL is said here, and it exits 1. A deployment's own
// run (--route) records itself and, failing, mails the owner where it has
// the mail key (not on a unit's preview). Every account either makes is a
// Resend test address, deleted; at the end Supabase's canary accounts are
// listed, and none of either run's, or older than a run, may be left.
//
// --stand-in: the cron's route (api/otp.js, op=canary) against a Supabase
// in memory (tools/web/canary_stand_in.mjs), wrong in one way at a time:
// sign-up open, an unconfirmed address signing in by its password, the
// code refused, TOTP enrolment on, an account that will not delete,
// orangecheck Connect not knowing the key (d, 2026-10-24). Each
// must fail its own check and only that, mail the owner once naming it and
// what came back (caught here, never sent), and be recorded; as it should
// be, it passes and mails nobody. Nothing leaves this process.
import { STAND_IN, standIn } from "./canary_stand_in.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = args.url ? String(args.url).replace(/\/+$/, "") : "";

let failures = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

if (args["stand-in"]) {
  await standInRun();
} else {
  await liveRun();
}
console.log(failures ? `${failures} FAIL` : "all ok");
process.exit(failures ? 1 : 0);

function show(checks, CHECKS, prefix = "") {
  for (const letter of Object.keys(CHECKS)) {
    const mine = checks.filter((one) => one.check === letter);
    if (mine.length === 0) continue;
    console.log(`${prefix}(${letter}) ${CHECKS[letter]}`);
    for (const one of mine) check(one.ok, `${one.what} (${one.said})`);
  }
}

async function liveRun() {
  const url = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  if (!url || !secret || !process.env.SUPABASE_PUBLISHABLE_KEY) {
    console.error("no SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY — source .env");
    process.exit(2);
  }
  if (args.route && !site) {
    console.error("--route asks a deployment: name it with --url=SITE");
    process.exit(2);
  }
  const { mint, deliver } = await import("../../api/otp.js");
  const { canary, CHECKS, CANARY_ADDRESS } = await import("../../api/_canary.js");
  const bypass = process.env.BW_BYPASS || process.env.VERCEL_BYPASS || "";
  const atSite = (more = {}) => ({ ...(bypass ? { "x-vercel-protection-bypass": bypass } : {}), ...more });

  const askSite = site ? async (access) => {
    const reply = await fetch(`${site}/api/account`, { headers: atSite({ authorization: `Bearer ${access}` }) });
    const account = await reply.json().catch(() => ({}));
    return { ok: reply.status === 200 && account.signed_in === true, said: `${site}/api/account ${reply.status}, signed_in ${account.signed_in}` };
  } : null;
  console.log(`the canary from here, against ${url}${site ? `, ${site} asked of (c)'s session` : ""}`);
  const here = await canary({ mint, deliver }, { askSite });
  show(here.checks, CHECKS);

  const made = [...here.made];
  if (args.route) {
    console.log(`${site}/api/otp/canary, the deployment's own run`);
    const refused = await fetch(`${site}/api/otp/canary`, { headers: atSite() });
    check(refused.status === 401, `without the cron's secret it is refused, and runs nothing (${refused.status})`);
    const reply = await fetch(`${site}/api/otp/canary`, {
      headers: atSite({ authorization: `Bearer ${process.env.CRON_SECRET || ""}` }),
      signal: AbortSignal.timeout(120000),
    });
    const there = await reply.json().catch(() => ({}));
    made.push(...(there.made || []));
    check(reply.status === 200 && there.ok === true, `with it, the run says every check held (${reply.status}, ok ${there.ok}, on ${there.host})`);
    show(there.checks || [], CHECKS, "  ");
    check(there.recorded === true, `the run is recorded in canary_runs (recorded ${there.recorded})`);
    console.log(`  the owner's mail: ${there.mailed}`);
  }

  // What Supabase holds of any canary: none of these runs', and none older
  // than a run, whosever it was.
  const headers = { apikey: secret, authorization: `Bearer ${secret}` };
  const listed = await (await fetch(`${url}/auth/v1/admin/users?page=1&per_page=1000&filter=${encodeURIComponent("+canary-")}`,
    { headers })).json().catch(() => ({}));
  const canaries = (listed.users || []).filter((one) => CANARY_ADDRESS.test(String(one.email || "")));
  const ours = canaries.filter((one) => made.includes(one.email));
  const old = canaries.filter((one) => Date.now() - Date.parse(one.created_at || 0) > 15 * 60 * 1000);
  check(listed.users !== undefined && ours.length === 0 && old.length === 0,
    `no canary account is left: ${made.length} made here and there, ${canaries.length} canary accounts in Supabase now`
    + `${ours.length + old.length ? `, left: ${[...new Set([...ours, ...old].map((one) => one.email))].join(", ")}` : ""}`);
}

async function standInRun() {
  // Before api/ is loaded: nothing here may reach the real project or Resend.
  Object.assign(process.env, {
    SUPABASE_URL: STAND_IN, SUPABASE_PUBLISHABLE_KEY: "sb_publishable_stand_in", SUPABASE_SECRET_KEY: "sb_secret_stand_in",
    RESEND_API_KEY: "re_stand_in", MASTER_EMAIL: "owner@stand-in.invalid", CRON_SECRET: "stand-in-cron",
    OC_CONNECT_KEY: "ock_stand_in",
  });
  for (const name of ["EMAIL_FROM", "EMAIL_FROM_FALLBACK", "VERCEL_URL"]) delete process.env[name];
  const otp = (await import("../../api/otp.js")).default;
  const { CHECKS } = await import("../../api/_canary.js");

  async function route(authorization) {
    let status = 0;
    let body = null;
    const response = {
      setHeader() { return this; },
      status(code) { status = code; return this; },
      json(value) { body = value; return this; },
      end() { return this; },
    };
    await otp({ method: "GET", query: { op: "canary" }, headers: { host: "stand-in.invalid", authorization } }, response);
    return { status, body };
  }

  const all = { signupOpen: true, unconfirmedSignsIn: true, codeRefused: true, totpOn: true };
  const SCENARIOS = [
    ["as it should be, with a canary account an earlier run left", {}, []],
    ["sign-up open, Supabase confirming an address itself (as on 2026-10-23)", { signupOpen: true }, ["a", "b"]],
    ["an unconfirmed address signing in by its password", { unconfirmedSignsIn: true }, ["b"]],
    ["the emailed code refused", { codeRefused: true }, ["c"]],
    ["TOTP enrolment on", { totpOn: true }, ["c"]],
    ["an account that will not delete", { undeletable: true }, ["gone"]],
    ["orangecheck Connect not knowing the key (invalid_api_key)", { connectKeyBad: true }, ["d"]],
    ["all of them wrong, Resend refusing and the record unwritable", { ...all, resendDown: true, recordDown: true }, ["a", "b", "c"]],
  ];

  {
    const fake = standIn();
    globalThis.fetch = fake.fetch;
    console.log("the canary's route, asked by somebody else");
    const none = await route(undefined);
    const wrong = await route("Bearer not-the-cron");
    check(none.status === 401 && wrong.status === 401 && fake.users.size === 0 && fake.mail.length === 0 && fake.rows.length === 0,
      `refused without the cron's secret and with another (${none.status}, ${wrong.status}): no account made, no mail, no record`);
  }

  for (const [name, faults, expected] of SCENARIOS) {
    const fake = standIn(faults);
    globalThis.fetch = fake.fetch;
    const hour = new Date(Date.now() - 3600 * 1000).toISOString();
    const seeded = name.startsWith("as it should be") ? {
      stale: fake.make("delivered+canary-c-1-abc123@resend.dev", true, null, hour),
      running: fake.make(`delivered+canary-a-${Date.now()}-def456@resend.dev`, true),
      byHand: fake.make("delivered+canary-check-by-hand@resend.dev", true, null, hour),
    } : null;
    console.log(`stand-in: ${name}`);
    const { status, body } = await route("Bearer stand-in-cron");
    const failed = [...new Set((body?.checks || []).filter((one) => !one.ok).map((one) => one.check))];
    check(status === (expected.length ? 500 : 200) && JSON.stringify(failed) === JSON.stringify(expected),
      `${expected.length ? `fails ${expected.map((one) => `(${one})`).join(" ")}, and only that` : "every check holds"}`
      + ` (${status}; failed: ${failed.map((one) => `(${one})`).join(" ") || "none"})`);
    for (const one of (body?.checks || []).filter((step) => !step.ok)) console.log(`          (${one.check}) ${one.what}: ${one.said}`);

    const toOwner = fake.mail.filter((one) => one.to?.[0] === "owner@stand-in.invalid");
    if (expected.length) {
      const letter = toOwner[0] || {};
      const named = expected.every((one) => letter.subject?.includes(`(${one})`))
        && (body?.checks || []).filter((one) => !one.ok).every((one) => letter.text?.includes(`got: ${one.said}`));
      check(toOwner.length === 1 && named, `the owner's mail attempted once, naming each failed check and what it got back`
        + ` (${toOwner.length} attempted, caught: "${letter.subject || ""}")`);
      check(body?.mailed === (faults.resendDown ? "failed: Resend 500" : "sent"), `and the run says how it went (${body?.mailed})`);
    } else {
      check(toOwner.length === 0 && body?.mailed === "none", `no mail to the owner (${toOwner.length}, mailed ${body?.mailed})`);
    }
    // (d): one ask of Connect, for a made-up user id, never an account's.
    check(fake.connect.length === 1 && /^canary-\d+-[0-9a-f]+$/.test(fake.connect[0]?.user_id || ""),
      `(d) asks orangecheck Connect once, to delete a made-up user (${fake.connect.length}, ${fake.connect[0]?.user_id || "none"})`);
    const codes = fake.mail.filter((one) => /@resend\.dev$/.test(one.to?.[0] || ""));
    check(codes.length === 1 && /is your Brickworks sign-in code/.test(codes[0].subject || ""),
      `(c)'s code mailed once, as api/otp.js mails one, to its test address (${codes.length}, caught)`);
    if (faults.recordDown) {
      check(body?.recorded === false && fake.rows.length === 0, `the record unwritable is said, not hidden (recorded ${body?.recorded})`);
    } else {
      const row = fake.rows[0] || {};
      check(fake.rows.length === 1 && body?.recorded === true && row.ok === (expected.length === 0)
        && Array.isArray(row.checks) && row.checks.length === body.checks.length && row.mailed === body.mailed,
        `the run recorded once, as it came out (${fake.rows.length} row, ok ${row.ok})`);
    }
    const left = [...fake.users.values()].filter((one) => !seeded || ![seeded.running.id, seeded.byHand.id].includes(one.id));
    if (faults.undeletable) {
      const named = left.map((one) => one.email).sort();
      check(named.length > 0 && JSON.stringify(named) === JSON.stringify([...(body?.left || [])].sort()),
        `the accounts it could not delete are named (${body?.left?.length} named, ${named.length} there)`);
    } else {
      check(left.length === 0, `every account it made is gone (${left.length} left)`);
    }
    if (seeded) {
      check(body?.stale === 1 && !fake.users.has(seeded.stale.id) && fake.users.has(seeded.running.id) && fake.users.has(seeded.byHand.id),
        `an earlier run's account an hour old is deleted first, another run's of now and one only named like a canary's are not (stale ${body?.stale})`);
    }
  }
}
