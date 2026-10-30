// Plans, coming soon (2026-10-28): who would use Pro, from the interest
// form on /plans (web/plans.html, web/plans.js).
//
//   POST /api/plans   {email, plan, billing, note}
//                     plan "pro" (kept as "plus", PLANS below), billing
//                     "monthly" or "yearly", note one line of at most 200
//                     characters, or none. {said}, the same words whether
//                     the address was there already or not: a second entry
//                     for the same plan changes the first
//                     (supabase/plan_interest.sql), and whether somebody
//                     left one is nobody else's to learn.
//   POST /api/plans   {email, forget: true}
//                     every entry of that address deleted ("Take my email
//                     off"). {said}, the same words whether there were any.
//
// 422 with why for anything else; 429 when one place has sent ten in the
// hour; 503 before the file is applied, or when the database cannot be
// asked. Nothing here takes money and nothing is sent to the address: the
// owner writes once, when the plan opens, and until then reads only the
// counts (tools/plan_interest.py). Where a request came from is kept only
// as a key nobody can turn back into the address, for a day, to count it.
//
// And the plans themselves, from Admission (api/_billing.js), only while
// BRICKWORKS_BILLING is test or live; off, a GET is refused as it always
// was:
//
//   GET /api/plans           what Free and Pro offer, and whether Pro is
//                            for sale: {billing, free, pro, forSale}
//   GET /api/plans?op=plan   the signed-in account's own (a session, as
//                            "Authorization: Bearer …"): {billing,
//                            standing, plan, owner, savedModels: {limit,
//                            kept}, desktop, subscription, freshness}:
//                            the most models the plan keeps with the
//                            account (null for no limit) and how many it
//                            keeps now (null when that cannot be read);
//                            nothing of AI, which no plan limits. 401
//                            without one.
//                            &fresh=1 asks Admission again past what is
//                            kept: back from Checkout, until Stripe's word
//                            has reached it.
//
// And the way to pay for Pro (docs/PLANS.md U3), POSTs with an op, asked
// before the interest form's (which has none), again only while billing is
// on; off, each is the interest form's, refused as it always was:
//
//   POST /api/plans?op=checkout  signed in, {interval: "month" or "year",
//                                consent: true, amount}: where to pay,
//                                {url, kind}: Stripe Checkout, or for one
//                                who pays already the portal to change
//                                plan. 422 without the renewal terms agreed
//                                (consent); the agreement is kept before
//                                anything else (supabase/plan_consents.sql),
//                                or nobody goes on. 409 when Pro is not on
//                                sale, the account has Pro without paying,
//                                or [amount], the price the page showed,
//                                is not the price.
//   POST /api/plans?op=portal    signed in, {flow}: Stripe's billing
//                                portal, {url}; [flow] "cancel" or
//                                "payment_method_update" goes straight to
//                                that. 409 for an account that never paid.
//   POST /api/plans?op=webhook   Admission's events, signed with
//                                ADMISSION_WEBHOOK_SECRET (404 without one,
//                                400 for one it did not sign):
//                                customer.updated forgets what is kept of
//                                that account, on every instance, so its
//                                next request reads its new plan.
//
// Checkout and the portal come back to /settings#plan on this site
// (returnOrigin): ?billing=done, cancelled or portal says from where.
//
// And the beta (api/_beta.js, supabase/beta.sql), answered in every mode,
// BRICKWORKS_BETA deciding it:
//
//   GET  /api/plans?op=beta        {beta: off}, or {beta: open, pool, early,
//                                  test, application}: the spots left, and
//                                  signed in, where your application stands
//   POST /api/plans?op=beta        signed in, the form: kept, and emailed
//   GET  /api/plans?op=beta_spots  {beta: off} or {beta: open, cap, left},
//                                  signed out and cached a minute
//   GET  /api/plans?op=beta_daily  Vercel's cron (/api/plans/beta-daily)
//
// And the paid desktop (api/_desktop.js, units U5 and U6), answered in
// every mode, so a page or an app can ask before it knows which:
//
//   GET /api/plans?op=download            {gated}: whether a download
//                                         needs a session (billing on)
//   GET /api/plans?op=download&file=NAME  the package NAME: a 302, or
//                                         {url} to a request that accepts
//                                         JSON (a page's fetch: a
//                                         navigation cannot carry the
//                                         session). Off: the public address
//                                         it has always had, nobody asked.
//                                         On: GitHub's signed one for a
//                                         session whose plan has the
//                                         desktop, or cannot be known just
//                                         now; 401 without a session, 403
//                                         {error, pro} for a plan without
//                                         it; 404 for no such file
//   GET /api/plans?op=entitlement         the desktop's token, for a
//                                         session: {billing, token, plan,
//                                         desktop, paid_through}. Off:
//                                         {billing: "off"}, nobody asked.
//                                         503 {billing, standing} while
//                                         the plan cannot be known, or
//                                         nothing signs: nothing is granted
//                                         then, nor refused

import { createHmac } from "node:crypto";
import { AdmissionError, AdmissionUnavailable, verifyWebhook, WebhookError } from "./_admission.js";
import { AuthError, bearer, verify } from "./_auth.js";
import {
  admission, agreed, billingMode, charge, currentOffer, entitlementOf, mayDesktop, mostModels, reportOwner,
  returnOrigin,
} from "./_billing.js";
import { betaDaily, betaRoute, betaSpots } from "./_beta.js";
import { db, dbConfigured } from "./_db.js";
import { NoSuchFile, publicUrl, signedUrl, signingKey, tagOf, tokenFor } from "./_desktop.js";

// Pro is the one paid plan since 2026-10-29 (docs/PLANS.md, section 1).
// The table allows only the two the page first asked about, Plus and
// Creator, and both mean Pro now (section 9), so Pro is kept as 'plus':
// no SQL, and the counts read as they did (tools/plan_interest.py).
export const PLANS = { pro: "plus" };
export const BILLING = ["monthly", "yearly"];
export const NOTE_MOST = 200;
// As api/otp.js takes an address: something, an @, something with a dot.
const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
export const KEPT = "Thanks. We will write to you once, when it opens, and not before.";
export const GONE = "Done: that address is not on the list for any plan.";

class Refusal extends Error {}

/// What [body] asks for, checked: {email, plan, billing, note}, or
/// {email, forget: true}; a Refusal saying what is wrong in words a person
/// can act on.
export function entryOf(body) {
  const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
  if (!EMAIL.test(email) || email.length > 320) throw new Refusal("That is not an email address.");
  if (body?.forget === true) return { email, forget: true };
  const asked = String(body?.plan || "");
  if (!Object.hasOwn(PLANS, asked)) throw new Refusal("Choose Pro.");
  const plan = PLANS[asked];
  const billing = String(body?.billing || "");
  if (!BILLING.includes(billing)) throw new Refusal("Choose monthly or yearly.");
  if (body?.note !== undefined && body?.note !== null && typeof body.note !== "string") {
    throw new Refusal("The note is a line of words.");
  }
  // One printable line, its runs of space made one.
  const note = String(body?.note || "").replace(/[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩]+/g, " ")
    .replace(/\s+/g, " ").trim();
  if (note.length > NOTE_MOST) throw new Refusal(`The note is at most ${NOTE_MOST} characters; that is ${note.length}.`);
  return { email, plan, billing, note };
}

/// Where [request] came from, as a key only this server can make, the same
/// all day: the address itself is never kept.
export function placeOf(request, secret = process.env.VIEW_SECRET || process.env.SUPABASE_SECRET_KEY || "") {
  const headers = request.headers || {};
  const address = String(headers["x-real-ip"] || String(headers["x-forwarded-for"] || "").split(",")[0]).trim()
    || request.socket?.remoteAddress || "";
  return createHmac("sha256", `plans:${secret}`).update(address).digest("hex").slice(0, 32);
}

function bodyOf(request) {
  if (typeof request.body !== "string") return request.body || {};
  try {
    return JSON.parse(request.body);
  } catch {
    return {};
  }
}

const say = (response, status, error) => response.status(status).json({ error });
const rpc = (name, body) => db(`rpc/${name}`, { method: "POST", body });

/// The signed-in account's claims, or null with the refusal sent.
async function signedIn(request, response) {
  try {
    return await verify(bearer(request), request);
  } catch (trouble) {
    if (trouble instanceof AuthError) {
      say(response, trouble.status, trouble.message);
      return null;
    }
    throw trouble;
  }
}

/// A GET while billing is on: the offer, or the signed-in account's plan,
/// the owner's reported to Admission first.
async function planned(request, response) {
  const op = String(request.query?.op || "");
  if (op === "") return response.status(200).json(await currentOffer());
  if (op !== "plan") return say(response, 404, "GET /api/plans, or /api/plans?op=plan signed in");
  const claims = await signedIn(request, response);
  if (!claims) return response;
  await reportOwner(claims);
  if (request.query?.fresh === "1") await admission().forget(claims.sub);
  const [e, kept] = await Promise.all([entitlementOf(claims.sub), modelsKept(claims.sub)]);
  return response.status(200).json({ ...e, savedModels: { limit: mostModels(e), kept } });
}

/// How many models [userId] keeps with the account now
/// (supabase/account_models_delete.sql), or null when that cannot be read.
async function modelsKept(userId) {
  try {
    const kept = await db("rpc/account_models_kept", { method: "POST", body: { p_owner: userId } });
    return Number.isInteger(kept?.models) ? kept.models : null;
  } catch {
    return null;
  }
}

export const INTERVALS = ["month", "year"];
const FLOWS = ["cancel", "payment_method_update"];
const PAID = ["checkout", "portal", "webhook"];
const TRY_AGAIN = "Billing cannot be reached just now. Try again in a minute.";
const NOT_FOR_SALE = "Pro is not on sale yet. Try again soon.";
export const NEVER_PAID = "There is no billing to manage: this account has never paid for Pro.";
export const NO_CONSENT = "Tick the box to agree that Pro renews until you cancel.";

/// The agreement could not be kept, so nobody goes on to pay.
class NotKept extends Error {}

/// Where to pay for Pro: Checkout, once the renewal terms are agreed and
/// the agreement kept.
async function checkout(request, response, claims) {
  const body = bodyOf(request);
  const interval = INTERVALS.includes(body?.interval) ? body.interval : null;
  if (!interval) return say(response, 422, "Choose monthly or yearly.");
  if (body?.consent !== true) return say(response, 422, NO_CONSENT);
  // Pro given, or the owner's: nothing to pay for. One who pays already is
  // sent on, and Admission sends them to the portal to change plan.
  const mine = await entitlementOf(claims.sub);
  if (mine.standing === "known" && (mine.owner || mine.plan?.key === "pro") && !mine.subscription) {
    return say(response, 409, "This account has Pro already, with nothing to pay.");
  }
  const offer = await currentOffer();
  const amount = offer.pro.prices[interval];
  if (!offer.forSale || !Number.isInteger(amount)) return say(response, 409, NOT_FOR_SALE);
  if (body.amount !== undefined && body.amount !== amount) {
    return say(response, 409, `The price is ${charge(amount, offer.pro.currency, interval)} now. `
      + "Read the terms again, and agree to that price to go on.");
  }
  try {
    await agreed(claims.sub, interval, amount, offer.pro.currency);
  } catch (trouble) {
    throw new NotKept(String(trouble?.message || trouble));
  }
  const origin = returnOrigin(request);
  const email = String(claims.email || "");
  const { url, kind } = await admission().checkout({
    customerId: claims.sub,
    // Prefills Checkout; an orangecheck account's address is made up.
    ...(email && !/@oc\.brickworks\.diy$/i.test(email) ? { email } : {}),
    plan: "pro",
    interval,
    returnUrl: `${origin}/settings?billing=done#plan`,
    cancelUrl: `${origin}/settings?billing=cancelled#plan`,
  });
  return response.status(200).json({ url, kind });
}

/// Stripe's billing portal, for an account that has paid: the card,
/// invoices, monthly or yearly, cancelling.
async function portal(request, response, claims) {
  const body = bodyOf(request);
  const flow = body?.flow ?? undefined;
  if (flow !== undefined && !FLOWS.includes(flow)) return say(response, 422, "That is not something billing does.");
  const mine = await entitlementOf(claims.sub);
  if (mine.standing === "known" && !mine.subscription) return say(response, 409, NEVER_PAID);
  const { url } = await admission().portal({
    customerId: claims.sub,
    returnUrl: `${returnOrigin(request)}/settings?billing=portal#plan`,
    ...(flow ? { flow } : {}),
  });
  return response.status(200).json({ url });
}

/// The body exactly as sent, as a signature is made over it, or null past
/// [most] bytes. Vercel's helpers parse a JSON body, which loses its bytes,
/// and leave them to read again as the request's data (@vercel/node
/// restoreBody); a request made here with a string body is that string.
function rawOf(request, most = 256 * 1024) {
  if (typeof request.on !== "function") return Promise.resolve(typeof request.body === "string" ? request.body : null);
  return new Promise((done) => {
    const chunks = [];
    let size = 0;
    const timer = setTimeout(() => done(null), 5000);
    request.on("data", (chunk) => {
      size += chunk.length;
      if (size <= most) chunks.push(Buffer.from(chunk));
    });
    request.on("end", () => {
      clearTimeout(timer);
      done(size > most ? null : Buffer.concat(chunks).toString("utf8"));
    });
    request.on("error", () => {
      clearTimeout(timer);
      done(null);
    });
  });
}

// Events heard on this instance, so one sent twice is acted on once.
// Forgetting twice changes nothing, so an instance that missed the first
// does no harm by acting on the second.
const heardEvents = new Set();

/// Admission's word that something changed (its ADR-0008).
async function webhook(request, response) {
  const secret = String(process.env.ADMISSION_WEBHOOK_SECRET || "").trim();
  if (!secret) return say(response, 404, "This deployment takes no webhook.");
  const raw = await rawOf(request);
  if (raw === null) return say(response, 400, "That is not from Admission.");
  let event;
  try {
    event = await verifyWebhook(raw, String(request.headers?.["admission-signature"] || ""), secret);
  } catch (trouble) {
    if (trouble instanceof WebhookError) return say(response, 400, "That is not from Admission.");
    throw trouble;
  }
  const a = admission();
  const id = String(event?.id || "");
  if (heardEvents.has(id)) return response.status(200).json({ heard: "again" });
  heardEvents.add(id);
  if (heardEvents.size > 1000) heardEvents.delete(heardEvents.values().next().value);
  // The other mode's event is not this deployment's to act on.
  if (event.mode === a.mode && event.type === "customer.updated" && typeof event.data?.customerId === "string") {
    await a.forget(event.data.customerId);
  }
  return response.status(200).json({ heard: String(event.type || "") });
}

/// What went wrong on the way to Stripe, in words a person can act on.
function refusedPaying(response, op, trouble) {
  if (trouble instanceof AdmissionUnavailable) return say(response, 503, TRY_AGAIN);
  if (trouble instanceof NotKept) {
    console.error(`plans: consent: ${trouble.message.slice(0, 120)}`);
    // PostgREST answers 404 for a function that is not there: before the file.
    return say(response, 503, /: 404$/.test(trouble.message) ? "Paying for Pro is not open here yet."
      : "That did not go just now. Try again in a minute.");
  }
  if (trouble instanceof AdmissionError) {
    if (trouble.code === "plan_not_for_sale" || trouble.code === "no_price") return say(response, 409, NOT_FOR_SALE);
    if (trouble.code === "no_stripe_customer") return say(response, 409, NEVER_PAID);
    if (trouble.code === "no_subscription") return say(response, 409, "There is no subscription to cancel.");
    console.error(`billing: ${op}: ${trouble.code}: ${String(trouble.message).slice(0, 120)}`);
    return say(response, 503, TRY_AGAIN);
  }
  throw trouble;
}

/// A POST with one of the ops above while billing is on.
async function paying(request, response, op) {
  if (op === "webhook") return webhook(request, response);
  const claims = await signedIn(request, response);
  if (!claims) return response;
  try {
    return await (op === "checkout" ? checkout : portal)(request, response, claims);
  } catch (trouble) {
    return refusedPaying(response, op, trouble);
  }
}

/// What a download is refused with, for a plan without the desktop.
export const DESKTOP_IS_PRO = "The desktop app comes with Pro. The web app is free, in any browser.";

/// GET ?op=download: whether a download is gated, or one package.
async function download(request, response) {
  const mode = billingMode();
  const file = String(request.query?.file || "");
  if (file === "") return response.status(200).json({ gated: mode !== "off" });
  if (!tagOf(file)) return say(response, 404, "There is no download of that name.");
  const send = (url) => {
    if (/application\/json/.test(String(request.headers?.accept || ""))) return response.status(200).json({ url });
    response.setHeader("Location", url);
    return response.status(302).end();
  };
  if (mode === "off") return send(publicUrl(file));
  const claims = await signedIn(request, response);
  if (!claims) return response;
  await reportOwner(claims);
  if (!mayDesktop(await entitlementOf(claims.sub))) {
    return response.status(403).json({ error: DESKTOP_IS_PRO, pro: "/plans" });
  }
  try {
    return send(await signedUrl(file));
  } catch (trouble) {
    if (trouble instanceof NoSuchFile) return say(response, 404, "There is no download of that name.");
    console.error(`download: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return say(response, 503, "The download did not start just now. Try again in a minute.");
  }
}

/// GET ?op=entitlement: the desktop's token, signed only on a plan known.
async function entitlement(request, response) {
  const mode = billingMode();
  if (mode === "off") return response.status(200).json({ billing: "off" });
  const claims = await signedIn(request, response);
  if (!claims) return response;
  await reportOwner(claims);
  const e = await entitlementOf(claims.sub);
  const signer = signingKey();
  if (e.standing !== "known" || !signer) {
    if (!signer) console.error("desktop: billing is on and DESKTOP_TOKEN_KEY is not an RSA private key");
    return response.status(503).json({ billing: e.billing, standing: signer ? e.standing : "unsigned" });
  }
  const { token, claims: said } = await tokenFor(claims.sub, e, signer);
  return response.status(200).json({ billing: e.billing, token, plan: said.plan, desktop: said.desktop,
    paid_through: said.paid_through });
}

export default async function handler(request, response) {
  // Asked only by the site's own page: no cross-origin answer, and nothing
  // kept by any cache.
  response.setHeader("Cache-Control", "no-store");
  const op = String(request.query?.op || "");
  if (op === "beta") return betaRoute(request, response);
  if (request.method === "GET" && op === "beta_spots") return betaSpots(request, response);
  if (request.method === "GET" && op === "beta_daily") return betaDaily(request, response);
  if (request.method === "GET" && op === "download") return download(request, response);
  if (request.method === "GET" && op === "entitlement") return entitlement(request, response);
  if (request.method === "GET" && billingMode() !== "off") return planned(request, response);
  if (request.method === "POST" && PAID.includes(op) && billingMode() !== "off") return paying(request, response, op);
  if (request.method !== "POST") return say(response, 405, "POST {email, plan, billing, note} or {email, forget: true}");
  let entry;
  try {
    entry = entryOf(bodyOf(request));
  } catch (trouble) {
    if (trouble instanceof Refusal) return say(response, 422, trouble.message);
    throw trouble;
  }
  if (!dbConfigured()) return say(response, 503, "The form is not open here yet.");
  try {
    if ((await rpc("plan_interest_may", { p_who: placeOf(request) })) !== true) {
      return say(response, 429, "That is a lot from one place in an hour. Try again later.");
    }
    if (entry.forget) {
      await rpc("plan_interest_forget", { p_email: entry.email });
      return response.status(200).json({ said: GONE });
    }
    await rpc("plan_interest_note", { p_email: entry.email, p_plan: entry.plan, p_billing: entry.billing,
      p_note: entry.note });
    return response.status(200).json({ said: KEPT });
  } catch (trouble) {
    const message = String(trouble?.message || trouble);
    console.error(`plans: ${message.slice(0, 120)}`);
    // PostgREST answers 404 for a function that is not there: before the file.
    if (/: 404$/.test(message)) return say(response, 503, "The form is not open yet. Try again soon.");
    return say(response, 503, "That did not go just now. Try again in a minute.");
  }
}
