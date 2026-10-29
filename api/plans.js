// Plans, coming soon (2026-10-28): who would use Plus or Creator, from the
// interest form on /plans (web/plans.html, web/plans.js).
//
//   POST /api/plans   {email, plan, billing, note}
//                     plan "plus" or "creator", billing "monthly" or
//                     "yearly", note one line of at most 200 characters,
//                     or none. {said}, the same words whether the address
//                     was there already or not: a second entry for the
//                     same plan changes the first (supabase/plan_interest.sql),
//                     and whether somebody left one is nobody else's to learn.
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
import { AuthError, bearer, verify } from "./_auth.js";
import { billingMode, currentOffer, entitlementOf, mayDesktop, reportOwner } from "./_billing.js";
import { db, dbConfigured } from "./_db.js";
import { NoSuchFile, publicUrl, signedUrl, signingKey, tagOf, tokenFor } from "./_desktop.js";

export const PLANS = ["plus", "creator"];
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
  const plan = String(body?.plan || "");
  if (!PLANS.includes(plan)) throw new Refusal("Choose Plus or Creator.");
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
  return response.status(200).json(await entitlementOf(claims.sub));
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
  if (request.method === "GET" && op === "download") return download(request, response);
  if (request.method === "GET" && op === "entitlement") return entitlement(request, response);
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
