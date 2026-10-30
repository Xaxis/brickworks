// Admission's product API (https://admission.sh/v1/openapi.json) in memory,
// behind a fetch, so the real client (api/_admission.js) talks to it as it
// would to admission.sh: onon's stand-in (src/test/fake-admission.ts at
// Xaxis/onon.me), with Brickworks' plans as docs/PLANS.md section 10 sets
// them up. Track follows Admission's rules: over the limit nothing is
// counted, giving back always fits, and a repeated idempotency key returns
// its first answer. An owner is on the best plan with every feature
// unlimited (ADR-0009).

export const FAKE_KEY = "adm_test_00000000000000000000000000000000";
export const ADMISSION_URL = "https://admission.test";

const FEATURES = [
  { key: "desktop", name: "Desktop app", kind: "flag", reset: null, unit: null },
  { key: "saved_models", name: "Saved models", kind: "cap", reset: null, unit: "models" },
];

const PLANS = {
  free: { name: "Free", rank: 0, includes: { saved_models: 25 } },
  pro: { name: "Pro", rank: 10, includes: { desktop: null, saved_models: null } },
};

/// The first of next month, UTC: when a monthly allowance starts again.
function nextMonth(now = Date.now()) {
  const d = new Date(now);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).toISOString();
}

const error = (code, message) => ({ error: { code, message } });
const reply = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { "content-type": "application/json" } });

export function fakeAdmission() {
  const usage = new Map();
  const answers = new Map();
  const subs = new Map();
  const overrides = new Map();
  const self = {
    /// Every request, as "METHOD /path".
    calls: [],
    /// Unreachable: every request fails as a network error would.
    down: false,
    owners: new Set(),
    subscribe(customerId, sub = {}) {
      subs.set(customerId, { plan: "pro", interval: "month", currentPeriodEnd: nextMonth(), endsAt: null, ...sub });
    },
    /// A plan given by hand, as the admin's comp (grant_override) does.
    comp(customerId, plan, until = null) {
      overrides.set(customerId, { plan, until });
    },
    /// The owner's set_usage.
    setUsed(customerId, feature, n) {
      usage.set(`${customerId}:${feature}`, n);
    },
    used: (customerId, feature) => usage.get(`${customerId}:${feature}`) ?? 0,
    async fetch(input, init = {}) {
      const url = new URL(String(input));
      const method = (init.method || "GET").toUpperCase();
      self.calls.push(`${method} ${url.pathname}`);
      if (self.down) throw new TypeError("fetch failed");
      const auth = new Headers(init.headers).get("authorization");
      if (auth !== `Bearer ${FAKE_KEY}`) return reply(401, error("unauthorized", "Bad key."));
      const body = init.body ? JSON.parse(String(init.body)) : {};
      return route(method, url.pathname, body);
    },
  };

  function planOf(customerId) {
    if (self.owners.has(customerId)) return { key: "pro", source: "override", until: null };
    const o = overrides.get(customerId);
    if (o) return { key: o.plan, source: "override", until: o.until };
    const s = subs.get(customerId);
    if (s && s.status !== "canceled") return { key: s.plan, source: "subscription" };
    return { key: "free", source: "default" };
  }

  function state(customerId) {
    const { key, source, until } = planOf(customerId);
    const plan = PLANS[key];
    const owner = self.owners.has(customerId);
    const features = {};
    for (const f of FEATURES) {
      const included = owner || f.key in plan.includes;
      const limit = owner ? null : included ? (plan.includes[f.key] ?? null) : 0;
      const unlimited = included && limit === null;
      const enabled = included && (limit === null || limit > 0);
      if (f.kind === "flag") {
        features[f.key] = { kind: "flag", enabled };
      } else if (f.kind === "cap") {
        features[f.key] = { kind: "cap", enabled, limit, unlimited };
      } else {
        const used = self.used(customerId, f.key);
        features[f.key] = { kind: "allowance", enabled, limit, unlimited, used,
          remaining: unlimited ? null : Math.max(0, (limit ?? 0) - used), reset: f.reset, resetsAt: nextMonth() };
      }
    }
    const s = subs.get(customerId);
    return {
      customerId,
      mode: "test",
      plan: { key, name: plan.name, version: 1, source, ...(until === undefined ? {} : { until }) },
      subscription: s
        ? { id: `sub_${customerId}`, status: s.status ?? "active", plan: s.plan, interval: s.interval,
          currentPeriodEnd: s.currentPeriodEnd, cancelAtPeriodEnd: false, cancelAt: s.endsAt, endsAt: s.endsAt }
        : null,
      trialEligible: !s,
      owner,
      features,
    };
  }

  function route(method, path, body) {
    if (method === "GET" && path === "/v1/plans") {
      return reply(200, {
        mode: "test",
        graceDays: null,
        features: FEATURES,
        plans: Object.entries(PLANS).map(([key, p]) => ({
          key, name: p.name, status: "draft", rank: p.rank, isDefault: key === "free", version: 1,
          includes: p.includes,
          prices: key === "pro"
            ? [{ interval: "month", amount: 800, currency: "usd" }, { interval: "year", amount: 8000, currency: "usd" }]
            : [],
          trial: null,
        })),
      });
    }
    const customer = /^\/v1\/customers\/([^/]+)$/.exec(path);
    if (method === "GET" && customer) return reply(200, state(decodeURIComponent(customer[1])));
    const marking = /^\/v1\/customers\/([^/]+)\/owner$/.exec(path);
    if (method === "PUT" && marking) {
      const id = decodeURIComponent(marking[1]);
      if (body.owner === true) self.owners.add(id);
      else self.owners.delete(id);
      return reply(200, state(id));
    }
    if (method === "POST" && path === "/v1/check") {
      const e = state(String(body.customerId)).features[String(body.feature)];
      if (!e) return reply(404, error("unknown_feature", `There is no feature "${body.feature}".`));
      const amount = Number(body.amount ?? 0);
      const remaining = e.remaining ?? null;
      const allowed = e.enabled && (e.unlimited === true || remaining === null || amount <= remaining);
      return reply(200, { allowed, feature: body.feature, kind: e.kind, limit: e.limit ?? null,
        unlimited: e.unlimited === true, used: e.used ?? null, remaining, plan: planOf(String(body.customerId)).key });
    }
    if (method === "POST" && path === "/v1/track") {
      const customerId = String(body.customerId);
      const feature = String(body.feature);
      const amount = Number(body.amount ?? 1);
      const key = `${customerId}:${body.idempotencyKey}`;
      if (answers.has(key)) return reply(200, { ...answers.get(key), replayed: true });
      const e = state(customerId).features[feature];
      if (!e) return reply(404, error("unknown_feature", `There is no feature "${feature}".`));
      if (e.kind !== "allowance") return reply(400, error("not_countable", `"${feature}" isn't an allowance.`));
      const allowed = amount <= 0 || e.unlimited || (e.limit !== null && e.used + amount <= e.limit);
      const now = allowed ? Math.max(0, e.used + amount) : e.used;
      if (allowed) usage.set(`${customerId}:${feature}`, now);
      const answer = { allowed, feature, used: now, limit: e.limit, unlimited: e.unlimited,
        remaining: e.unlimited ? null : Math.max(0, (e.limit ?? 0) - now), replayed: false };
      answers.set(key, answer);
      return reply(200, answer);
    }
    return reply(404, error("not_found", "No such endpoint."));
  }
  return self;
}
