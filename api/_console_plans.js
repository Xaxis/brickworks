// The console's Plans and revenue section (/admin#plans, docs/ADMIN.md,
// console2): the plans and what each includes, the customers and their
// plans, the comps, revenue by month and Admission's own record of what
// happened, all read from Admission (https://admission.sh). Read only: prices,
// trials, promotions, comps and a plan's status are the owner's to change at
// Admission, and the page says so beside each. Nothing here writes anything,
// at Admission or here.
//
//   plans      GET /v1/plans with this deployment's ADMISSION_KEY (the
//              client in api/_billing.js, cached and kept as a snapshot)
//   customers  the customers Admission last answered for, from the client's
//              snapshots (admission_customers, supabase/console2.sql): no
//              call to Admission an account
//   revenue    GET /v1/owner/metrics and /v1/owner/events with
//              ADMISSION_READ_TOKEN, a read token limited to Brickworks
//              (ownerReader): MRR and subscribers now, payments and refunds
//              by month, and the events themselves, newest first
//
// While billing is off (production's, until the owner's yes to live) none
// of it is asked, and the section says so.

import { admission, billingMode, ownerReader, PRODUCT } from "./_billing.js";
import { db } from "./_db.js";
import { allUsers } from "./_console.js";

/// Where each thing is changed: Admission's own admin, signed in as its owner.
export const AT_ADMISSION = {
  product: "https://admission.sh/products/brickworks",
  customers: "https://admission.sh/customers/brickworks",
  revenue: "https://admission.sh/revenue",
  audit: "https://admission.sh/audit",
  access: "https://admission.sh/access",
};

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const said = (trouble) => String(trouble?.message || trouble).slice(0, 200);

/// Payments in, refunds out, by month (YYYY-MM) and currency, from [events].
export function byMonth(events) {
  const months = new Map();
  for (const event of events || []) {
    const sign = event.type === "payment.succeeded" ? 1 : event.type === "refund" ? -1 : 0;
    if (!sign || !Number.isFinite(Number(event.amount))) continue;
    const key = `${String(event.at).slice(0, 7)} ${event.currency || "usd"}`;
    const one = months.get(key) || { month: String(event.at).slice(0, 7), currency: event.currency || "usd", paid: 0,
      refunded: 0, payments: 0, refunds: 0 };
    if (sign > 0) {
      one.paid += Number(event.amount);
      one.payments += 1;
    } else {
      one.refunded += Number(event.amount);
      one.refunds += 1;
    }
    months.set(key, one);
  }
  return [...months.values()].map((one) => ({ ...one, net: one.paid - one.refunded }))
    .sort((a, b) => b.month.localeCompare(a.month) || a.currency.localeCompare(b.currency));
}

/// A customer as Admission last answered for them: their plan, how they
/// have it (a subscription, a comp, the default), until when, and the
/// subscription's state.
function customerOf(row, emails) {
  let value = null;
  try {
    value = JSON.parse(row.value)?.value || null;
  } catch {
    value = null;
  }
  const plan = value?.plan || {};
  const sub = value?.subscription || null;
  return {
    account: row.customer,
    email: emails.get(row.customer) ?? null,
    plan: plan.key || null,
    plan_name: plan.name || plan.key || null,
    source: plan.source || null,
    until: plan.until ?? null,
    owner: value?.owner === true,
    subscription: sub ? { status: sub.status || null, interval: sub.interval || null, period_end: sub.currentPeriodEnd || null,
      ends_at: sub.endsAt || null } : null,
    answered_at: row.at,
  };
}

/// GET /api/admin?op=plans: {billing, key, read, plans, customers, comps,
/// metrics, months, events, said}.
export async function plansRead() {
  const mode = billingMode();
  const reader = ownerReader();
  const out = {
    billing: mode,
    key: Boolean(String(process.env.ADMISSION_KEY || "").trim()),
    read: Boolean(reader),
    at: AT_ADMISSION,
    product: PRODUCT,
    plans: null,
    customers: null,
    metrics: null,
    months: null,
    events: null,
    said: {},
  };
  if (mode === "off") return out;
  const [catalog, kept, users] = await Promise.all([
    admission().plans().catch((trouble) => {
      out.said.plans = said(trouble);
      return null;
    }),
    db("rpc/admission_customers", { method: "POST", body: { p_mode: mode, p_limit: 2000 } }).catch((trouble) => {
      out.said.customers = notYet(trouble) ? "supabase/console2.sql is not applied" : said(trouble);
      return null;
    }),
    allUsers().catch(() => []),
  ]);
  if (catalog) {
    const features = new Map((catalog.features || []).map((one) => [one.key, one]));
    out.features = catalog.features || [];
    out.grace_days = catalog.graceDays ?? null;
    out.plans = (catalog.plans || []).map((plan) => ({
      key: plan.key, name: plan.name, status: plan.status || null, default: plan.isDefault === true, rank: plan.rank ?? null,
      includes: Object.entries(plan.includes || {}).map(([key, limit]) => ({ key, name: features.get(key)?.name || key,
        kind: features.get(key)?.kind || null, unit: features.get(key)?.unit || null, limit: limit ?? null })),
      prices: (plan.prices || []).map((price) => ({ interval: price.interval, amount: price.amount, currency: price.currency })),
      trial: plan.trial || null,
    }));
  }
  if (kept) {
    const emails = new Map(users.map((user) => [user.id, user.email || null]));
    out.customers = kept.map((row) => customerOf(row, emails));
    out.comps = out.customers.filter((one) => one.source === "override" && !one.owner);
  }
  if (reader) {
    const [metrics, events] = await Promise.all([
      reader.read(`/v1/owner/metrics?product=${PRODUCT}&mode=${mode}`).catch((trouble) => {
        out.said.metrics = said(trouble);
        return null;
      }),
      reader.read(`/v1/owner/events?product=${PRODUCT}&mode=${mode}&limit=500`).catch((trouble) => {
        out.said.events = said(trouble);
        return null;
      }),
    ]);
    out.metrics = metrics;
    if (events) {
      const emails = new Map(users.map((user) => [user.id, user.email || null]));
      const listed = (events.events || []).slice().sort((a, b) => Number(b.id) - Number(a.id));
      out.months = byMonth(listed);
      out.events = listed.slice(0, 100).map((one) => ({ id: one.id, at: one.at, type: one.type, summary: one.summary || null,
        account: one.customerId || null, email: one.customerId ? emails.get(one.customerId) ?? null : null,
        plan: one.plan || null, amount: one.amount ?? null, currency: one.currency || null }));
    }
  }
  return out;
}
