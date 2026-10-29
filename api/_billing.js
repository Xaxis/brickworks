// Plans, from Admission (https://admission.sh): what each account may do,
// built dark (docs/PLANS.md, unit U1, 2026-10-29).
//
// BRICKWORKS_BILLING is the one switch, read here (billingMode) and nowhere
// else:
//
//   off   unset, or anything but the two below: nothing is asked of
//         Admission or kept, nothing is limited, and every account is as it
//         was before plans. The default, and production's until the switch
//         to live (U8).
//   test  Admission's test mode, with an adm_test_… key in ADMISSION_KEY.
//   live  live mode, with an adm_live_… key (U8, on the owner's yes).
//
// A mode without its own kind of key is off, said once in the log: a test
// key never answers for live and a live one never for a test. Not
// VERCEL_ENV: every deployment here is a production one, previews included
// (tools/deploy.sh, --prod --skip-domain), so a preview tries test mode by
// setting the two for itself alone (--env), never on the project.
//
// The customer is the Supabase user id of a verified session (claims.sub),
// never anything a request says. One client a process (api/_admission.js,
// UPSTREAM.md), its snapshots kept in the database
// (supabase/admission_snapshots.sql), so a cold instance can still answer a
// paying person while Admission cannot be reached.
//
// What an account gets, entitlementOf: [standing] says how far to trust it.
//
//   off      billing is off: everything, as before plans
//   known    Admission's answer, just now, cached, or the last snapshot of
//            the account brought up to now: refuse what it does not include
//   unknown  Admission cannot be reached and has no snapshot of this
//            account, or was asked wrongly: refuse nothing on it, since
//            this could be someone who pays, and grant nothing lasting on
//            it either (a desktop token, U6): ask again later
//
// mayBuild and mayDesktop say that rule once for the routes that use it.

import { Admission, AdmissionUnavailable } from "./_admission.js";
import { db } from "./_db.js";
import { isMaster } from "./_auth.js";

/// Admission's names for Brickworks (docs/PLANS.md, section 1).
export const PRODUCT = "brickworks";
export const BUILDS = "claude_builds";
export const DESKTOP = "desktop";

/// What /plans says when Admission cannot: section 1 of docs/PLANS.md.
export const PUBLISHED = Object.freeze({
  free: { key: "free", name: "Free", claudeBuilds: 10, desktop: false, prices: {}, currency: "usd" },
  pro: { key: "pro", name: "Pro", claudeBuilds: "unlimited", desktop: true, prices: { month: 800, year: 8000 },
    currency: "usd" },
  forSale: false,
});

const KEYS = { test: /^adm_test_[0-9A-Za-z]{32}$/, live: /^adm_live_[0-9A-Za-z]{32}$/ };
let warned = "";

/// "off", "test" or "live": the switch, with the key it needs.
export function billingMode(env = process.env) {
  const asked = String(env.BRICKWORKS_BILLING || "").trim().toLowerCase();
  if (asked !== "test" && asked !== "live") return "off";
  if (KEYS[asked].test(String(env.ADMISSION_KEY || "").trim())) return asked;
  if (warned !== asked) {
    warned = asked;
    console.warn(`billing: BRICKWORKS_BILLING=${asked} without an adm_${asked}_ key in ADMISSION_KEY, so billing is off`);
  }
  return "off";
}

/// [promise], or a failure after [ms]: an answer from the database is only
/// worth waiting for while it is quicker than doing without, as Admission's
/// own is (2.5 s). The client takes a failure as no snapshot.
function within(ms, promise) {
  let timer;
  const late = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`no answer in ${ms} ms`)), ms);
  });
  return Promise.race([promise, late]).finally(() => clearTimeout(timer));
}

/// Admission's snapshots in the database, through the two functions only the
/// server may call.
export const snapshots = {
  get: (key) => within(2500, db("rpc/admission_snapshot_get", { method: "POST", body: { p_key: key } })),
  set: (key, value) => within(2500, db("rpc/admission_snapshot_put", { method: "POST",
    body: { p_key: key, p_value: value } })),
};

let client = null;

/// The process's client for this mode and key; null while billing is off.
export function admission() {
  const mode = billingMode();
  if (mode === "off") return null;
  const key = String(process.env.ADMISSION_KEY).trim();
  if (client?.key !== key) {
    client = {
      key,
      admission: new Admission({
        key,
        baseUrl: process.env.ADMISSION_URL?.trim() || undefined,
        // Kept across a new key: the namespace is the product, not the key.
        namespace: PRODUCT,
        store: snapshots,
        onFallback: (what, error) => console.warn(`billing: fallback ${what}: ${String(error?.message || error).slice(0, 120)}`),
      }),
    };
  }
  return client.admission;
}

/// Tests: the next admission() makes a new client, as a cold instance does.
export function forgetClient() {
  client = null;
}

const OFF = Object.freeze({ billing: "off", standing: "off", plan: null, owner: false, builds: null, desktop: null,
  subscription: null, freshness: null });

const unknown = (billing) => ({ ...OFF, billing, standing: "unknown" });

/// Admission's customer answer [c] as Brickworks reads it.
function entitlementFrom(billing, c) {
  // The client's own guess at the default plan: no snapshot of this account
  // held, or its plan lapsed while Admission was away. A guess is not
  // enough to refuse anybody.
  if (c.freshness === "default") return unknown(billing);
  const builds = c.features?.[BUILDS];
  const desktop = c.features?.[DESKTOP];
  const s = c.subscription;
  return {
    billing,
    standing: "known",
    plan: { key: c.plan.key, name: c.plan.name, source: c.plan.source, until: c.plan.until ?? null },
    owner: c.owner === true,
    builds: builds?.kind === "allowance"
      ? {
        limit: builds.unlimited ? null : (builds.limit ?? 0),
        used: builds.used,
        remaining: builds.unlimited ? null : (builds.remaining ?? 0),
        resetsAt: builds.resetsAt,
      }
      : null,
    desktop: desktop?.enabled === true,
    subscription: s
      ? { status: s.status, interval: s.interval, periodEnd: s.currentPeriodEnd, endsAt: s.endsAt,
        graceEndsAt: s.graceEndsAt ?? null }
      : null,
    freshness: c.freshness,
  };
}

/// What the account [userId] (a verified session's sub) gets now.
export async function entitlementOf(userId) {
  if (typeof userId !== "string" || userId === "") throw new TypeError("entitlementOf takes a user id");
  const a = admission();
  if (!a) return OFF;
  const billing = a.mode;
  try {
    return entitlementFrom(billing, await a.customer(userId));
  } catch (trouble) {
    // An outage with nothing held, or a mistake of ours (a key Admission
    // does not know, a product not made yet): never the person's to pay for.
    if (!(trouble instanceof AdmissionUnavailable)) {
      console.error(`billing: customer: ${trouble?.code || "error"}: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    return unknown(billing);
  }
}

/// Whether [e] lets its account start a Claude build: unless Admission said
/// this month's are used. Only reads; counting one is the relay's (U2).
export function mayBuild(e) {
  if (e.standing !== "known" || !e.builds) return true;
  return e.builds.limit === null || e.builds.remaining > 0;
}

/// Whether [e] lets its account have the desktop app now (U5, U6).
export function mayDesktop(e) {
  return e.standing !== "known" || e.desktop === true;
}

/// Tells Admission whether the signed-in [claims] are the owner's
/// (MASTER_EMAIL), so the owner's account has every feature unlimited
/// (Admission's ADR-0009). Admission is asked only when what the client
/// holds says otherwise. A failure is logged, never shown.
export async function reportOwner(claims) {
  const a = admission();
  if (!a || !claims?.sub) return;
  try {
    await a.owner(claims.sub, isMaster(claims));
  } catch (trouble) {
    console.warn(`billing: owner: ${trouble?.code || "error"}: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

function amountOf(includes, feature) {
  if (!(feature in includes)) return "none";
  return includes[feature] ?? "unlimited";
}

/// Free and Pro as Admission's [plans] have them: the published ones for a
/// plan it lacks. Pro is for sale when it is live, or a draft in test mode,
/// and has a price.
export function offerOf(plans) {
  const one = (key) => {
    const p = plans.plans.find((x) => x.key === key);
    if (!p) return { offer: PUBLISHED[key], status: "retired" };
    const desktop = amountOf(p.includes, DESKTOP);
    const prices = {};
    for (const price of p.prices) prices[price.interval] = price.amount;
    return {
      offer: { key, name: p.name, claudeBuilds: amountOf(p.includes, BUILDS),
        desktop: desktop === "unlimited" || (typeof desktop === "number" && desktop > 0), prices,
        currency: p.prices[0]?.currency ?? "usd" },
      status: p.status,
    };
  };
  const free = one("free");
  const pro = one("pro");
  const forSale = (pro.status === "live" || (plans.mode === "test" && pro.status === "draft"))
    && Object.keys(pro.offer.prices).length > 0;
  return { free: free.offer, pro: pro.offer, forSale };
}

/// What the plans offer now, for /plans; the published ones, not for sale,
/// when Admission cannot say. Null while billing is off.
export async function currentOffer() {
  const a = admission();
  if (!a) return null;
  try {
    return { billing: a.mode, ...offerOf(await a.plans()) };
  } catch (trouble) {
    if (!(trouble instanceof AdmissionUnavailable)) {
      console.error(`billing: plans: ${trouble?.code || "error"}: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    return { billing: a.mode, ...PUBLISHED };
  }
}
