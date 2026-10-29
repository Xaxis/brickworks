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
//                            standing, plan, owner, builds, desktop,
//                            subscription, freshness}; 401 without one

import { createHmac } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { billingMode, currentOffer, entitlementOf, reportOwner } from "./_billing.js";
import { db, dbConfigured } from "./_db.js";

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

/// A GET while billing is on: the offer, or the signed-in account's plan,
/// the owner's reported to Admission first.
async function planned(request, response) {
  const op = String(request.query?.op || "");
  if (op === "") return response.status(200).json(await currentOffer());
  if (op !== "plan") return say(response, 404, "GET /api/plans, or /api/plans?op=plan signed in");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    if (trouble instanceof AuthError) return say(response, trouble.status, trouble.message);
    throw trouble;
  }
  await reportOwner(claims);
  return response.status(200).json(await entitlementOf(claims.sub));
}

export default async function handler(request, response) {
  // Asked only by the site's own page: no cross-origin answer, and nothing
  // kept by any cache.
  response.setHeader("Cache-Control", "no-store");
  if (request.method === "GET" && billingMode() !== "off") return planned(request, response);
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
