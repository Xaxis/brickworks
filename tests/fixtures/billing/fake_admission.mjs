// Admission's product API (https://admission.sh/v1/openapi.json) in memory,
// behind a fetch, so the real client (api/_admission.js) talks to it as it
// would to admission.sh: onon's stand-in (src/test/fake-admission.ts at
// Xaxis/onon.me), with Brickworks' plans as docs/PLANS.md section 10 sets
// them up. Track follows Admission's rules: over the limit nothing is
// counted, giving back always fits, and a repeated idempotency key returns
// its first answer. An owner is on the best plan with every feature
// unlimited (ADR-0009). A product's own comp (ADR-0015, the beta's month) is
// one a customer and reason, ever, within apiCompsLimit. Checkout and the
// portal answer with Stripe-shaped
// URLs on hosts nobody owns (checkout.stripe.test), holding return URLs to
// what test mode allows, as Admission's own checkout does
// (apps/admission/src/server/stripe/checkout.ts holdReturnUrls).
//
// It also answers on a unit's preview, in the function's own process
// (api/_billing.js, tools/deploy.sh --billing-stand-in), so nothing here
// may import anything: it is copied beside the function on its own.

export const FAKE_KEY = "adm_test_00000000000000000000000000000000";
export const ADMISSION_URL = "https://admission.test";
/// The stand-in's webhook signing secret: a test's, nobody's real one.
export const WEBHOOK_SECRET = "adm_whsec_standin0000000000000000000000";

/// The Admission-Signature header for [body] (a string) at [t] (unix
/// seconds) under [secret], as Admission signs a webhook: HMAC-SHA256 of
/// "<t>.<body>".
export async function signWebhook(body, secret = WEBHOOK_SECRET, t = Math.floor(Date.now() / 1000)) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false,
    ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(`${t}.${body}`)));
  return `t=${t},v1=${[...mac].map((b) => b.toString(16).padStart(2, "0")).join("")}`;
}

/// Where test mode lets Checkout and the portal send someone back: https on
/// a Vercel preview, or this machine (Admission's holdReturnUrls).
function returnable(raw) {
  try {
    const url = new URL(String(raw));
    return ["localhost", "127.0.0.1"].includes(url.hostname)
      || (url.protocol === "https:" && (url.hostname.endsWith(".vercel.app") || url.hostname === "brickworks.diy"));
  } catch {
    return false;
  }
}

const FEATURES = [
  { key: "ai_builds", name: "AI builds", kind: "allowance", reset: "month", unit: "builds" },
  { key: "desktop", name: "Desktop app", kind: "flag", reset: null, unit: null },
];

const PLANS = {
  free: { name: "Free", rank: 0, includes: { ai_builds: 10 } },
  pro: { name: "Pro", rank: 10, includes: { ai_builds: null, desktop: null } },
};

/// The first of next month, UTC: when a monthly allowance starts again.
function nextMonth(now = Date.now()) {
  const d = new Date(now);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)).toISOString();
}

const error = (code, message) => ({ error: { code, message } });
const reply = (status, body) => new Response(JSON.stringify(body), {
  status, headers: { "content-type": "application/json" } });

/// The longest a product's own comp lasts (Admission's ADR-0015).
const MOST_COMP_DAYS = 31;
const DAY_MS = 86_400_000;

export function fakeAdmission() {
  const usage = new Map();
  const answers = new Map();
  const subs = new Map();
  const overrides = new Map();
  /// The product's own comps (ADR-0015), "customer:reason" to {plan, until, revoked}.
  const apiComps = new Map();
  let sessions = 0;
  const self = {
    /// Every request, as "METHOD /path".
    calls: [],
    /// What each checkout and portal was asked, in order.
    checkouts: [],
    portals: [],
    /// Each erasure: {customerId, found, canceled}, in order.
    erasures: [],
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
    /// How many of the product's own comps may be on at once (ADR-0015):
    /// Brickworks' is 100; null is the owner never having set it.
    apiCompsLimit: 100,
    /// Each comp a product asked for: {customerId, reason, made}, in order.
    compsAsked: [],
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
      return route(method, url.pathname, body, url.searchParams);
    },
  };

  /// The product's comps on now for [customerId], latest ending first.
  function compsOn(customerId, now = Date.now()) {
    return [...apiComps.entries()].filter(([k, c]) => k.startsWith(`${customerId}:`) && !c.revoked
      && Date.parse(c.until) > now).map(([, c]) => c).sort((x, y) => Date.parse(y.until) - Date.parse(x.until));
  }

  function planOf(customerId) {
    if (self.owners.has(customerId)) return { key: "pro", source: "override", until: null };
    const o = overrides.get(customerId);
    if (o) return { key: o.plan, source: "override", until: o.until };
    const comp = compsOn(customerId)[0];
    if (comp) return { key: comp.plan, source: "override", until: comp.until };
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

  function route(method, path, body, query) {
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
    // Erased, as Admission's ADR-0004 has it: one who pays is refused unless
    // cancelSubscription=true, which ends the subscription now; then usage,
    // comps, subscriptions and owner marks go. Erasing again finds nothing.
    if (method === "DELETE" && customer) {
      const id = decodeURIComponent(customer[1]);
      const s = subs.get(id);
      const paying = Boolean(s && s.status !== "canceled");
      if (paying && query?.get("cancelSubscription") !== "true") {
        return reply(409, error("active_subscription", "This customer is paying. Let their subscription end, or "
          + "erase with cancelSubscription=true to end it now (no refund)."));
      }
      const used = [...usage.keys()].filter((k) => k.startsWith(`${id}:`));
      const found = Boolean(s) || overrides.has(id) || self.owners.has(id) || used.length > 0;
      for (const k of used) usage.delete(k);
      for (const k of [...answers.keys()]) if (k.startsWith(`${id}:`)) answers.delete(k);
      subs.delete(id);
      overrides.delete(id);
      for (const k of [...apiComps.keys()]) if (k.startsWith(`${id}:`)) apiComps.delete(k);
      self.owners.delete(id);
      const canceled = paying ? [`sub_${id}`] : [];
      self.erasures.push({ customerId: id, found, canceled });
      return reply(200, { customerId: id, mode: "test", found, canceled, fingerprint: `erased:${id.length}` });
    }
    // A product's own comp (ADR-0015): one a customer and reason, ever; a
    // repeat answers the first unchanged (200), even once it has ended.
    const comping = /^\/v1\/customers\/([^/]+)\/comps\/([^/]+)$/.exec(path);
    if (comping && (method === "PUT" || method === "DELETE")) {
      const id = decodeURIComponent(comping[1]);
      const reason = decodeURIComponent(comping[2]);
      if (!/^[a-z0-9][a-z0-9_-]{0,39}$/.test(reason)) return reply(400, error("bad_request", "reason is 1-40 of a-z, 0-9, _ and -."));
      const key = `${id}:${reason}`;
      if (method === "DELETE") {
        const c = apiComps.get(key);
        if (!c) return reply(404, error("unknown_comp", `This customer has no comp "${reason}" from the product.`));
        if (Date.parse(c.until) > Date.now()) c.revoked = true;
        return reply(200, state(id));
      }
      if (apiComps.has(key)) {
        self.compsAsked.push({ customerId: id, reason, made: false });
        return reply(200, state(id));
      }
      if (self.apiCompsLimit === null) {
        return reply(403, error("api_comps_off", "This product's keys can't comp: the owner turns API comps on in Admission."));
      }
      if (!PLANS[body.plan]) return reply(404, error("unknown_plan", `There is no plan "${body.plan}".`));
      if (body.plan === "free") return reply(400, error("default_plan", "\"free\" is the default plan: everyone has it."));
      if ((body.days === undefined) === (body.until === undefined)) {
        return reply(400, error("bad_request", "send days or until, not both"));
      }
      const now = Date.now();
      const until = body.days !== undefined ? now + Number(body.days) * DAY_MS : Date.parse(body.until);
      if (!Number.isFinite(until) || until <= now || until > now + MOST_COMP_DAYS * DAY_MS
        || (body.days !== undefined && !(Number.isInteger(body.days) && body.days >= 1))) {
        return reply(400, error("bad_until", `A comp ends in the future, at most ${MOST_COMP_DAYS} days from now.`));
      }
      const on = [...apiComps.values()].filter((c) => !c.revoked && Date.parse(c.until) > now).length;
      if (on >= self.apiCompsLimit) {
        return reply(409, error("api_comps_full", `This product's keys already have ${on} comps on, its limit in test mode.`));
      }
      apiComps.set(key, { plan: body.plan, until: new Date(until).toISOString(), revoked: false });
      self.compsAsked.push({ customerId: id, reason, made: true });
      return reply(201, state(id));
    }
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
    if (method === "POST" && path === "/v1/checkout") {
      const customerId = String(body.customerId || "");
      if (!customerId) return reply(400, error("bad_request", "customerId is required."));
      if (!["month", "year"].includes(body.interval)) return reply(400, error("bad_request", "interval is month or year."));
      if (!PLANS[body.plan]) return reply(404, error("unknown_plan", `There is no plan "${body.plan}".`));
      if (body.plan === "free") return reply(409, error("plan_not_for_sale", "\"free\" is the free plan; nothing to buy."));
      for (const field of ["returnUrl", "cancelUrl"]) {
        if (body[field] !== undefined && !returnable(body[field])) {
          return reply(400, error("bad_return_url", `${field} must be on localhost, 127.0.0.1 or an https *.vercel.app preview.`));
        }
      }
      self.checkouts.push(body);
      sessions += 1;
      // A subscriber is sent to the portal to change plan, as Admission does.
      const s = subs.get(customerId);
      if (s && s.status !== "canceled") {
        return reply(200, { url: `https://billing.stripe.test/p/session/bps_test_${sessions}`, kind: "portal" });
      }
      return reply(200, { url: `https://checkout.stripe.test/c/pay/cs_test_${sessions}#${body.interval}`, kind: "checkout" });
    }
    if (method === "POST" && path === "/v1/portal") {
      const customerId = String(body.customerId || "");
      if (!returnable(body.returnUrl)) {
        return reply(400, error("bad_return_url", "returnUrl must be on localhost, 127.0.0.1 or an https *.vercel.app preview."));
      }
      if (body.flow !== undefined && !["cancel", "payment_method_update"].includes(body.flow)) {
        return reply(400, error("bad_request", "flow is cancel or payment_method_update."));
      }
      const s = subs.get(customerId);
      if (!s) return reply(404, error("no_stripe_customer", "This customer hasn't bought anything yet, so there's no billing to manage."));
      if (body.flow === "cancel" && s.status === "canceled") {
        return reply(404, error("no_subscription", "This customer has no subscription to cancel."));
      }
      self.portals.push(body);
      sessions += 1;
      return reply(200, { url: `https://billing.stripe.test/p/session/bps_test_${sessions}`, kind: "portal" });
    }
    return reply(404, error("not_found", "No such endpoint."));
  }
  return self;
}
