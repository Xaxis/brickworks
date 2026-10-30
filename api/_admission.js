/**
 * @admission/client: what a customer may do, from Admission (https://admission.sh).
 *
 * One file, no dependencies. Copy it into a product and record the Admission commit in the
 * product's UPSTREAM.md (docs/integrating.md in the Admission repo says how).
 *
 * - Answers come from a short cache (30 s by default), optionally shared through `store`. A check
 *   the cached answer refuses goes to Admission, which decides afresh and counts the refusal, at
 *   most once per 30 s per customer and feature on an instance; between those the no stands.
 * - When Admission can't be reached, a customer it knew is answered from their last snapshot,
 *   however old, so a paying customer is never blocked; past the snapshot's subscription endsAt or
 *   graceEndsAt, or its comp's until, from the plan that still holds, and past a feature's comp
 *   until, that feature from the plan alone. A customer it never saw gets the default plan if
 *   the client has seen the plans, and nothing otherwise: it never grants paid features to a
 *   stranger. Offline use is counted against what it answered, and allowances reset on time.
 * - Mistakes (a bad key, an unknown feature, a malformed request) throw AdmissionError at once;
 *   only outages fall back.
 * - `verifyWebhook` checks what Admission POSTs to the product's webhook URL and returns the event.
 */
/** A request Admission understood and refused: fix the request, retrying won't help. */
export class AdmissionError extends Error {
    status;
    code;
    constructor(status, code, message) {
        super(message);
        this.name = "AdmissionError";
        this.status = status;
        this.code = code;
    }
}
/** Admission couldn't be reached and there was nothing to fall back on. */
export class AdmissionUnavailable extends Error {
    constructor(cause) {
        super("Admission is unreachable and has no snapshot to answer from.", { cause });
        this.name = "AdmissionUnavailable";
    }
}
/** Why a webhook was refused. Answer 400 and don't act on it. */
export class WebhookError extends Error {
    code;
    constructor(code, message) {
        super(message);
        this.name = "WebhookError";
        this.code = code;
    }
}
const hex = (bytes) => [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
/** Compares every candidate in full, whatever matches, so timing says nothing about the secret. */
function anyEqual(expected, candidates) {
    let found = 0;
    for (const c of candidates) {
        let diff = c.length ^ expected.length;
        for (let i = 0; i < expected.length; i++) {
            diff |= expected.charCodeAt(i) ^ (c.charCodeAt(i) || 0);
        }
        found |= diff === 0 ? 1 : 0;
    }
    return found === 1;
}
/**
 * Checks a webhook from Admission and returns its event, or throws WebhookError. Pass the body
 * exactly as received (`await req.text()`, before any JSON parsing), the `Admission-Signature`
 * header, and the endpoint's signing secret (`adm_whsec_…`). The signature is HMAC-SHA256 of
 * `<t>.<body>` under the secret; one older than `toleranceSeconds` (default 300) is refused, so a
 * captured request can't be replayed later. While the owner rotates the secret, Admission signs
 * with both, so either one verifies.
 */
export async function verifyWebhook(rawBody, signatureHeader, secret, opts = {}) {
    if (!signatureHeader) {
        throw new WebhookError("no_signature", "No Admission-Signature header.");
    }
    let t = null;
    const v1 = [];
    for (const part of signatureHeader.split(",")) {
        const i = part.indexOf("=");
        const k = part.slice(0, i).trim();
        const v = part.slice(i + 1).trim();
        if (k === "t" && /^\d{1,12}$/.test(v))
            t = Number(v);
        else if (k === "v1" && /^[0-9a-f]{64}$/.test(v))
            v1.push(v);
    }
    if (t === null || !v1.length) {
        throw new WebhookError("bad_header", "The Admission-Signature header isn't t=…,v1=….");
    }
    const tolerance = opts.toleranceSeconds ?? 300;
    const now = Math.floor((opts.now ?? Date.now)() / 1000);
    if (Math.abs(now - t) > tolerance) {
        throw new WebhookError("too_old", `The signature is from ${now - t} s ago; ${tolerance} s at most.`);
    }
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const expected = hex(await crypto.subtle.sign("HMAC", key, enc.encode(`${t}.${rawBody}`)));
    if (!anyEqual(expected, v1)) {
        throw new WebhookError("bad_signature", "The signature doesn't match this secret and body.");
    }
    try {
        return JSON.parse(rawBody);
    }
    catch {
        throw new WebhookError("bad_body", "The body isn't JSON.");
    }
}
const MAX_ENTRIES = 5000;
const MAX_PENDING = 1000;
/**
 * A refusal from what the client holds goes to Admission at most this often per customer and
 * feature on one instance (ADR-0013), however often the product checks: a page that checks while
 * it renders stays one request per 30 s, not one per view.
 */
const CONFIRM_EVERY_MS = 30_000;
/**
 * Whether a request of `amount` fits. The same rules as Admission's (its test suite checks they
 * agree): a feature not included (or set to 0) is refused whatever the amount; flags ignore the
 * amount; a cap compares it to the limit; an allowance compares used + amount (default 1) to the
 * limit; giving units back always fits.
 */
export function decide(e, amount) {
    if (e.kind === "flag") {
        return { allowed: e.enabled, limit: null, unlimited: false, used: null, remaining: null };
    }
    if (e.kind === "cap") {
        const allowed = amount === undefined
            ? e.enabled
            : e.enabled && (e.unlimited || (e.limit !== null && amount <= e.limit));
        return { allowed, limit: e.limit, unlimited: e.unlimited, used: null, remaining: null };
    }
    const n = amount ?? 1;
    const allowed = e.enabled && (n <= 0 || e.unlimited || (e.limit !== null && e.used + n <= e.limit));
    return { allowed, limit: e.limit, unlimited: e.unlimited, used: e.used, remaining: e.remaining };
}
/** Whether an ISO time has come. A missing or unreadable one never has. */
function passed(iso, now) {
    return iso != null && Date.parse(iso) <= now;
}
/** Whether a subscription has stopped giving its plan: past its endsAt, or past its grace. */
function ended(sub, now) {
    return passed(sub?.endsAt, now) || passed(sub?.graceEndsAt, now);
}
/** Whether what gives this plan has ended: a subscription that has, a comp past its until. */
function lapsed(s, now) {
    if (s.plan.source === "subscription")
        return ended(s.subscription, now);
    if (s.plan.source === "override")
        return passed(s.plan.until, now);
    return false;
}
/**
 * A state brought up to `now` for deciding without Admission: an allowance whose period has ended
 * counts from 0. When the new period ends isn't known until Admission answers, so it doesn't end.
 */
function rollover(s, now) {
    let features;
    for (const [key, e] of Object.entries(s.features)) {
        if (e.kind !== "allowance" || !passed(e.resetsAt, now))
            continue;
        features ??= { ...s.features };
        const remaining = e.unlimited ? null : (e.limit ?? 0);
        features[key] = { ...e, used: 0, remaining, resetsAt: null };
    }
    return features ? { ...s, features } : s;
}
/** A feature as `plan` gives it, without comps, keeping the usage counted in `before`. */
function fromPlan(f, plan, before) {
    const included = f.key in plan.includes;
    const limit = included ? (plan.includes[f.key] ?? null) : 0;
    const unlimited = included && limit === null;
    const enabled = included && (limit === null || limit > 0);
    if (f.kind === "flag")
        return { kind: "flag", enabled };
    if (f.kind === "cap")
        return { kind: "cap", enabled, limit, unlimited };
    const counted = before?.kind === "allowance" ? before : null;
    const used = counted?.used ?? 0;
    return {
        kind: "allowance",
        enabled,
        limit,
        unlimited,
        used,
        remaining: unlimited ? null : Math.max(0, (limit ?? 0) - used),
        reset: (f.reset ?? "never"),
        resetsAt: counted?.resetsAt ?? null,
    };
}
class Outage extends Error {
    constructor(cause) {
        super("unreachable", { cause });
    }
}
const compPath = (customerId, reason) => `/v1/customers/${encodeURIComponent(customerId)}/comps/${encodeURIComponent(reason)}`;
export class Admission {
    mode;
    key;
    base;
    ttl;
    timeout;
    store;
    namespace;
    onFallback;
    fetchFn;
    now;
    customers = new Map();
    plansSnapshot = null;
    pending = [];
    /** The last offline step queued for each customer: each waits for the one before. */
    offlineTurns = new Map();
    /** When a refusal of each customer and feature last went to Admission, oldest first. */
    confirmedAt = new Map();
    /** Refusals on their way to Admission, by customer, feature and amount. */
    confirming = new Map();
    constructor(opts) {
        const m = /^adm_(test|live)_[0-9A-Za-z]{32}$/.exec(opts.key);
        if (!m)
            throw new AdmissionError(0, "bad_key", "An Admission key looks like adm_test_… or adm_live_….");
        this.mode = m[1];
        this.key = opts.key;
        this.base = (opts.baseUrl ?? "https://admission.sh").replace(/\/+$/, "");
        this.ttl = opts.ttlMs ?? 30_000;
        this.timeout = opts.timeoutMs ?? 2_500;
        this.store = opts.store;
        if (opts.namespace !== undefined)
            this.namespace = Promise.resolve(opts.namespace);
        this.onFallback = opts.onFallback ?? (() => { });
        this.fetchFn = opts.fetch ?? globalThis.fetch.bind(globalThis);
        this.now = opts.now ?? Date.now;
    }
    /** The customer's plan, features and usage. */
    async customer(customerId) {
        const held = await this.held(customerId);
        if (held && this.now() - held.at < this.ttl)
            return { ...held.value, freshness: "cached" };
        try {
            return { ...(await this.fetchCustomer(customerId)), freshness: "live" };
        }
        catch (e) {
            if (!(e instanceof Outage))
                throw e;
            this.onFallback("customer", e.cause);
            const snap = await this.inTurn(customerId, async () => this.offline(customerId, await this.held(customerId)));
            if (!snap)
                throw new AdmissionUnavailable(e.cause);
            const guessed = snap.assumed && snap.value.plan.source === "default";
            return { ...snap.value, freshness: guessed ? "default" : "stale" };
        }
    }
    /**
     * May this customer do this? Decided from their (cached) state; a no from it is confirmed with
     * Admission (once per 30 s per customer and feature), which counts the refusal. Counts no usage.
     */
    async check(input) {
        let c;
        try {
            c = await this.customer(input.customerId);
        }
        catch (e) {
            if (!(e instanceof AdmissionUnavailable))
                throw e;
            return {
                allowed: false,
                feature: input.feature,
                limit: null,
                unlimited: false,
                used: null,
                remaining: null,
                plan: null,
                freshness: "unavailable",
            };
        }
        const e = c.features[input.feature];
        if (!e) {
            throw new AdmissionError(404, "unknown_feature", `There is no feature "${input.feature}".`);
        }
        const local = {
            ...decide(e, input.amount),
            feature: input.feature,
            plan: c.plan.key,
            freshness: c.freshness,
        };
        // A yes never asks. An outage's answer stands: Admission was just found unreachable.
        if (local.allowed || (c.freshness !== "live" && c.freshness !== "cached"))
            return local;
        return (await this.confirm(input)) ?? local;
    }
    /** Checks and counts in one step at Admission. Over the limit: allowed false, nothing counted. */
    async track(input) {
        const body = { ...input, amount: input.amount ?? 1 };
        try {
            const a = await this.request("POST", "/v1/track", body);
            await this.noteUsage(input.customerId, input.feature, a.used);
            void this.afterSuccess();
            return { ...a, offline: false };
        }
        catch (e) {
            if (!(e instanceof Outage))
                throw e;
            this.onFallback("track", e.cause);
            return this.inTurn(input.customerId, () => this.trackOffline(body));
        }
    }
    /** A Stripe URL to send the customer to: Checkout to subscribe, or the portal to change plan. */
    async checkout(input) {
        await this.forget(input.customerId);
        return this.requestOrThrow("POST", "/v1/checkout", input);
    }
    /** A Stripe Customer Portal URL: card, invoices, cancel, switch plan. */
    async portal(input) {
        await this.forget(input.customerId);
        return this.requestOrThrow("POST", "/v1/portal", input);
    }
    /** The product's plans and this mode's prices. */
    async plans() {
        if (this.plansSnapshot && this.now() - this.plansSnapshot.at < this.ttl) {
            return this.plansSnapshot.value;
        }
        try {
            const value = await this.request("GET", "/v1/plans");
            await this.holdPlans(value);
            return value;
        }
        catch (e) {
            if (!(e instanceof Outage))
                throw e;
            const held = await this.heldPlans();
            if (held)
                return held.value;
            throw new AdmissionUnavailable(e.cause);
        }
    }
    /**
     * Say whether this customer is one of the product's owners, e.g. signed in with an address in its
     * OWNER_EMAILS (ADR-0009). An owner gets the best plan with every feature unlimited, until told
     * otherwise. Call it whenever you learn who someone is: Admission is asked only when the answer
     * this client holds says otherwise. `false` ends only the marks the product made.
     */
    async owner(customerId, owner) {
        const held = await this.held(customerId);
        if (held && !held.assumed && (held.value.owner ?? false) === owner)
            return;
        const value = await this.requestOrThrow("PUT", `/v1/customers/${encodeURIComponent(customerId)}/owner`, { owner });
        await this.hold(customerId, { at: this.now(), value });
    }
    /**
     * Comp this customer one of the product's plans for a while (ADR-0015), e.g. a beta tester the
     * product approved: for `days` (1 to 31) or `until` (at most 31 days off). Once per customer and
     * `reason`, ever: asking again, even after it ended or was ended, changes nothing and answers how
     * things are, so a retry can't renew it. Off until the owner lets the product's key comp; throws
     * AdmissionError "api_comps_off", "api_comps_full" (the owner's limit of comps on at once is
     * reached), "unknown_plan", "default_plan", "plan_retired" or "bad_until". Returns the customer's
     * state, which this client then holds.
     */
    async comp(input) {
        const { customerId, reason, plan, days, until } = input;
        const value = await this.requestOrThrow("PUT", compPath(customerId, reason), {
            plan,
            ...(days !== undefined ? { days } : {}),
            ...(until !== undefined
                ? { until: until instanceof Date ? until.toISOString() : until }
                : {}),
        });
        await this.hold(customerId, { at: this.now(), value });
        return value;
    }
    /**
     * End the comp this product gave the customer with `reason`, if it's still on; one the owner gave
     * stays. The reason stays used. Throws AdmissionError "unknown_comp" when there never was one.
     * Returns the customer's state, which this client then holds.
     */
    async endComp(customerId, reason) {
        const value = await this.requestOrThrow("DELETE", compPath(customerId, reason));
        await this.hold(customerId, { at: this.now(), value });
        return value;
    }
    /** Everything Admission holds about a customer, for a data request. */
    async exportCustomer(customerId) {
        return this.requestOrThrow("GET", `/v1/customers/${encodeURIComponent(customerId)}/export`);
    }
    /**
     * Erase a customer, for account deletion or a data request, and everything this client keeps
     * about them. A paying customer throws AdmissionError "active_subscription" unless
     * `cancelSubscription`, which ends their subscription now with no refund.
     */
    async eraseCustomer(customerId, opts = {}) {
        const query = opts.cancelSubscription ? "?cancelSubscription=true" : "";
        const erased = await this.requestOrThrow("DELETE", `/v1/customers/${encodeURIComponent(customerId)}${query}`);
        this.customers.delete(customerId);
        this.pending = this.pending.filter((t) => t.customerId !== customerId);
        if (this.store) {
            try {
                await this.store.set(await this.storeKey(`c:${customerId}`), "");
            }
            catch (e) {
                this.onFallback("store.set", e);
            }
        }
        return erased;
    }
    /**
     * Ask Admission about this customer next time, on every instance sharing the store, e.g. when
     * they come back from Checkout. Their last snapshot stays, to answer from during an outage.
     */
    async forget(customerId) {
        const mine = this.customers.get(customerId);
        if (mine)
            this.customers.set(customerId, { ...mine, at: 0 });
        const shared = await this.readStore(`c:${customerId}`);
        if (shared && shared.at !== 0)
            await this.writeStore(`c:${customerId}`, { ...shared, at: 0 });
    }
    // -------------------------------------------------------------------------------------------
    /** Asks Admission for the customer's answer and holds it. */
    async fetchCustomer(customerId) {
        const value = await this.request("GET", `/v1/customers/${encodeURIComponent(customerId)}`);
        await this.hold(customerId, { at: this.now(), value });
        void this.afterSuccess();
        return value;
    }
    /**
     * Admission's answer to a check the client would refuse, or null when the client's no stands:
     * this customer and feature went to Admission in the last 30 s (or this instance already has
     * MAX_ENTRIES refusals within that), or Admission couldn't answer. Calls with the same customer,
     * feature and amount while one is asked share its request.
     */
    confirm(input) {
        const flight = JSON.stringify([input.customerId, input.feature, input.amount ?? null]);
        const sharing = this.confirming.get(flight);
        if (sharing)
            return sharing;
        const now = this.now();
        for (const [k, at] of this.confirmedAt) {
            if (now - at < CONFIRM_EVERY_MS)
                break;
            this.confirmedAt.delete(k);
        }
        const pair = JSON.stringify([input.customerId, input.feature]);
        const last = this.confirmedAt.get(pair);
        if (last !== undefined && now - last < CONFIRM_EVERY_MS)
            return Promise.resolve(null);
        this.confirmedAt.delete(pair);
        if (this.confirmedAt.size >= MAX_ENTRIES)
            return Promise.resolve(null);
        this.confirmedAt.set(pair, now);
        const asking = this.askCheck(input).finally(() => this.confirming.delete(flight));
        this.confirming.set(flight, asking);
        return asking;
    }
    /** POST /v1/check. On a yes, refreshes the customer, so the next calls agree without asking. */
    async askCheck(input) {
        const { customerId, feature, amount } = input;
        let a;
        try {
            a = await this.request("POST", "/v1/check", { customerId, feature, amount });
        }
        catch (e) {
            this.onFallback("check", e instanceof Outage ? e.cause : e);
            return null;
        }
        if (a.allowed) {
            await this.fetchCustomer(customerId).catch((e) => {
                this.onFallback("customer", e instanceof Outage ? e.cause : e);
            });
        }
        else {
            void this.afterSuccess();
        }
        const { allowed, limit, unlimited, used, remaining, plan } = a;
        return { allowed, feature, limit, unlimited, used, remaining, plan, freshness: "live" };
    }
    async requestOrThrow(method, path, body) {
        try {
            return await this.request(method, path, body);
        }
        catch (e) {
            if (e instanceof Outage)
                throw new AdmissionUnavailable(e.cause);
            throw e;
        }
    }
    async request(method, path, body) {
        let res;
        try {
            res = await this.fetchFn(`${this.base}${path}`, {
                method,
                headers: {
                    authorization: `Bearer ${this.key}`,
                    ...(body !== undefined ? { "content-type": "application/json" } : {}),
                },
                ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
                signal: AbortSignal.timeout(this.timeout),
            });
        }
        catch (e) {
            throw new Outage(e);
        }
        if (res.status >= 500 || res.status === 429) {
            throw new Outage(new Error(`Admission answered ${res.status}`));
        }
        let data;
        try {
            data = await res.json();
        }
        catch (e) {
            throw new Outage(e);
        }
        if (!res.ok) {
            const err = data.error;
            throw new AdmissionError(res.status, err?.code ?? "error", err?.message ?? `HTTP ${res.status}`);
        }
        return data;
    }
    /** v2: namespaced by product. v1 keys (one namespace for every product) are never read. */
    async storeKey(what) {
        this.namespace ??= crypto.subtle
            .digest("SHA-256", new TextEncoder().encode(this.key))
            .then((h) => [...new Uint8Array(h, 0, 6)].map((b) => b.toString(16).padStart(2, "0")).join(""));
        return `admission:v2:${await this.namespace}:${this.mode}:${what}`;
    }
    async held(customerId) {
        const mine = this.customers.get(customerId);
        if (mine && this.now() - mine.at < this.ttl)
            return mine;
        const shared = await this.readStore(`c:${customerId}`);
        if (shared && (!mine || shared.at > mine.at)) {
            this.remember(customerId, shared);
            return shared;
        }
        return mine ?? null;
    }
    async hold(customerId, snap) {
        this.remember(customerId, snap);
        await this.writeStore(`c:${customerId}`, snap);
    }
    /**
     * What to answer from while Admission is down: the held snapshot brought up to now (allowances
     * reset, features' ended comps dropped) while its plan holds, or else the client's own answer
     * from the plans. That answer is held like a snapshot, so
     * what's counted against it sticks, and at 0, so Admission is asked first once it's back. Null
     * when the client has neither.
     */
    async offline(customerId, held) {
        const now = this.now();
        const value = held && !lapsed(held.value, now) ? await this.endComps(rollover(held.value, now)) : null;
        if (held && value) {
            if (value === held.value)
                return held;
            const snap = { ...held, value };
            await this.hold(customerId, snap);
            return snap;
        }
        const assumed = await this.assumedState(customerId, held ? rollover(held.value, now) : null);
        if (!assumed)
            return null;
        const snap = { at: 0, value: assumed, assumed: true };
        await this.hold(customerId, snap);
        return snap;
    }
    /**
     * The state with each feature whose comp has ended (its `until` has passed) answered from the
     * plan alone, keeping its usage: other comps on that feature go with it until Admission answers.
     * Null when the client hasn't seen that plan or feature.
     */
    async endComps(s) {
        const now = this.now();
        const ended = Object.keys(s.features).filter((k) => passed(s.features[k]?.until, now));
        if (!ended.length)
            return s;
        const plans = (await this.heldPlans())?.value;
        const plan = plans?.plans.find((p) => p.key === s.plan.key);
        if (!plans || !plan)
            return null;
        const features = { ...s.features };
        for (const key of ended) {
            const f = plans.features.find((x) => x.key === key);
            if (!f)
                return null;
            features[key] = fromPlan(f, plan, s.features[key]);
        }
        return { ...s, features };
    }
    remember(customerId, snap) {
        this.customers.delete(customerId);
        this.customers.set(customerId, snap);
        if (this.customers.size > MAX_ENTRIES) {
            const oldest = this.customers.keys().next().value;
            if (oldest !== undefined)
                this.customers.delete(oldest);
        }
    }
    /**
     * Runs `step` once every earlier offline step for this customer has finished. An offline answer
     * reads the snapshot, decides and writes it back with what it counted (or an allowance's new
     * period); one at a time per customer, two can't both spend the last unit, or write over each
     * other's counts. Per instance: instances sharing a store still decide apart.
     */
    inTurn(customerId, step) {
        const result = (this.offlineTurns.get(customerId) ?? Promise.resolve()).then(step);
        const done = result.then(() => { }, () => { });
        this.offlineTurns.set(customerId, done);
        void done.then(() => {
            if (this.offlineTurns.get(customerId) === done)
                this.offlineTurns.delete(customerId);
        });
        return result;
    }
    async heldPlans() {
        if (this.plansSnapshot)
            return this.plansSnapshot;
        const shared = await this.readStore("plans");
        if (shared)
            this.plansSnapshot = shared;
        return shared;
    }
    async holdPlans(value) {
        this.plansSnapshot = { at: this.now(), value };
        await this.writeStore("plans", this.plansSnapshot);
    }
    async readStore(what) {
        if (!this.store)
            return null;
        try {
            const raw = await this.store.get(await this.storeKey(what));
            if (!raw)
                return null;
            return (typeof raw === "string" ? JSON.parse(raw) : raw);
        }
        catch (e) {
            this.onFallback("store.get", e);
            return null;
        }
    }
    async writeStore(what, snap) {
        if (!this.store)
            return;
        try {
            await this.store.set(await this.storeKey(what), JSON.stringify(snap));
        }
        catch (e) {
            this.onFallback("store.set", e);
        }
    }
    /**
     * The client's own answer, from the plans it has seen, for a customer whose last snapshot (if
     * any) no longer holds: the plan of a subscription that snapshot shows still running (a comp over
     * it ended), else the default plan. Usage carries over from the snapshot. Null without the plans.
     */
    async assumedState(customerId, last) {
        const plans = await this.heldPlans();
        if (!plans)
            return null;
        const sub = last?.subscription ?? null;
        const paid = sub?.plan && !ended(sub, this.now())
            ? plans.value.plans.find((p) => p.key === sub.plan)
            : undefined;
        const plan = paid ?? plans.value.plans.find((p) => p.isDefault);
        if (!plan)
            return null;
        const features = {};
        for (const f of plans.value.features)
            features[f.key] = fromPlan(f, plan, last?.features[f.key]);
        return {
            customerId,
            mode: this.mode,
            plan: {
                key: plan.key,
                name: plan.name,
                version: plan.version,
                source: paid ? "subscription" : "default",
                until: null,
            },
            subscription: paid ? sub : null,
            ...(last?.trialEligible !== undefined ? { trialEligible: last.trialEligible } : {}),
            features,
        };
    }
    async noteUsage(customerId, feature, used) {
        const snap = this.customers.get(customerId);
        if (!snap || used === null)
            return;
        // `used` is this period's count, even when the snapshot is from an earlier period.
        const state = rollover(snap.value, this.now());
        const e = state.features[feature];
        if (e?.kind !== "allowance")
            return;
        const remaining = e.unlimited ? null : Math.max(0, (e.limit ?? 0) - used);
        const value = {
            ...state,
            features: { ...state.features, [feature]: { ...e, used, remaining } },
        };
        await this.hold(customerId, { ...snap, value });
    }
    async trackOffline(body) {
        const snap = await this.offline(body.customerId, await this.held(body.customerId));
        const e = snap?.value.features[body.feature];
        const no = {
            allowed: false,
            feature: body.feature,
            used: null,
            limit: null,
            unlimited: false,
            remaining: null,
            replayed: false,
            offline: true,
        };
        if (!snap)
            return no;
        if (e?.kind !== "allowance") {
            throw new AdmissionError(400, "not_countable", `"${body.feature}" isn't an allowance.`);
        }
        // Giving units back is never refused, as on the server; anything else is decided as it would be.
        if (body.amount >= 0 && !decide(e, body.amount).allowed) {
            return { ...no, used: e.used, limit: e.limit, remaining: e.remaining };
        }
        // Count it here too, so an outage can't become unlimited use.
        const used = Math.max(0, e.used + body.amount);
        await this.noteUsage(body.customerId, body.feature, used);
        if (this.pending.length < MAX_PENDING)
            this.pending.push(body);
        return {
            allowed: true,
            feature: body.feature,
            used,
            limit: e.limit,
            unlimited: e.unlimited,
            remaining: e.unlimited ? null : Math.max(0, (e.limit ?? 0) - used),
            replayed: false,
            offline: true,
        };
    }
    /** After Admission answers again: send what was counted offline, and learn the plans once. */
    async afterSuccess() {
        if (!this.plansSnapshot)
            await this.plans().catch(() => { });
        const queue = this.pending;
        this.pending = [];
        for (let i = 0; i < queue.length; i++) {
            try {
                await this.request("POST", "/v1/track", queue[i]);
            }
            catch (e) {
                if (e instanceof Outage) {
                    this.pending.push(...queue.slice(i));
                    return;
                }
                // Refused now (e.g. over the limit after all): nothing more to do with it.
            }
        }
    }
}
