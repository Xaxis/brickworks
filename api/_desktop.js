// The paid desktop, built dark (docs/PLANS.md, units U5 and U6, 2026-10-29):
// the files behind the plan, and the token a desktop build checks at start.
// Both are ops of api/plans.js (Vercel's Hobby plan stops a deployment at
// 12 functions, and api/ has 12).
//
// Downloads. Every package is a release asset on Xaxis/brickworks-releases.
// While billing is off (api/_billing.js) a file's address is the public one
// it has always been. While it is on, the repo goes private (the owner, at
// U8) and a file is fetched through GitHub's API: the asset endpoint, asked
// with Accept: application/octet-stream, answers a 302 to a signed URL on
// release-assets.githubusercontent.com that lasts minutes, and that is what
// a Pro account is sent to. GitHub "may redirect or stream directly", so a
// 200 is taken as an error and never streamed through Vercel (PLANS.md §4:
// R2 is the way out if it ever streams). RELEASES_TOKEN, a fine-grained
// token that only reads that one repo's contents, is sent when set; the
// public repo answers without it.
//
// Activation. A desktop build asks for a token at start and keeps it beside
// the session: a JWT signed RS256 with DESKTOP_TOKEN_KEY, a private key in
// the environment only (tools/desktop_key.mjs makes one, docs/RELEASING.md
// says how to rotate it), whose public half is compiled into the app
// (src/account/desktop_pass.gd). Its claims:
//
//   sub           the account (a verified session's sub)
//   plan          Admission's plan key, "free" or "pro"
//   desktop       whether the account has the desktop now
//   paid_through  the last day the account had the desktop, "YYYY-MM-DD":
//                 at least today while it has it, a comp's or a paid
//                 period's end when later, the largest ever kept for the
//                 account, and never before DESKTOP_FREE_THROUGH; null
//                 while it has it with no end (a comp without one, the
//                 owner), or when it never had it
//   iat           when it was signed, in seconds
//
// A build runs when paid_through is on or after its release date, so every
// version released while somebody paid stays theirs; or, offline and
// renewed meanwhile, when the token says desktop and is at most 44 days
// old (30, and 14 of grace). The app checks; the server only signs, and
// never on an entitlement it does not know (standing "unknown").

import { createHash, createPrivateKey, createPublicKey, createSign, createVerify } from "node:crypto";
import { db } from "./_db.js";

export const REPO = "Xaxis/brickworks-releases";
/// A package's name, which says its version: Brickworks-0.10.0-linux-x86_64.AppImage.
const PACKAGE = /^Brickworks-(\d{1,3}\.\d{1,3}\.\d{1,3})-[A-Za-z0-9_]+(?:-[A-Za-z0-9_]+)*\.(?:AppImage|tar\.xz|zip)$/;
/// Days a token that says desktop lets a newer build run offline: a month's
/// renewal, and 14 days of grace (PLANS.md §4, step 3).
export const GRACE_DAYS = 44;

/// The release tag of the package [file], or null for anything else.
export function tagOf(file) {
  const m = PACKAGE.exec(String(file || ""));
  return m ? `v${m[1]}` : null;
}

/// The address [file] has always had: public while the repo is.
export function publicUrl(file) {
  return `https://github.com/${REPO}/releases/download/${tagOf(file)}/${file}`;
}

export class NoSuchFile extends Error {}

function github(path, accept) {
  const headers = { accept, "user-agent": "brickworks-download", "x-github-api-version": "2022-11-28" };
  const token = String(process.env.RELEASES_TOKEN || "").trim();
  if (token) headers.authorization = `Bearer ${token}`;
  return fetch(`https://api.github.com/repos/${REPO}${path}`,
    { headers, redirect: "manual", signal: AbortSignal.timeout(8000) });
}

/// GitHub's short-lived address for [file]: the release's asset found by
/// name, then asked for its bytes and answered with where they are.
/// NoSuchFile when there is no such release or asset.
export async function signedUrl(file) {
  const tag = tagOf(file);
  if (!tag) throw new NoSuchFile(file);
  const release = await github(`/releases/tags/${tag}`, "application/vnd.github+json");
  if (release.status === 404) throw new NoSuchFile(file);
  if (!release.ok) throw new Error(`GitHub answered ${release.status} for ${tag}`);
  const asset = ((await release.json()).assets || []).find((a) => a.name === file);
  if (!asset) throw new NoSuchFile(file);
  const bytes = await github(`/releases/assets/${asset.id}`, "application/octet-stream");
  await bytes.body?.cancel();
  const to = bytes.headers.get("location") || "";
  if ([301, 302, 303, 307, 308].includes(bytes.status) && to.startsWith("https://")) return to;
  throw new Error(`GitHub answered ${bytes.status} for ${file}, not a redirect`);
}

// --- The token -------------------------------------------------------------

/// A PEM from the environment: as it is, with its newlines written \n (one
/// line, as an env var holds it), or base64 of the whole PEM.
function pemOf(text) {
  const raw = String(text || "").trim();
  if (!raw) return "";
  if (raw.includes("-----BEGIN")) return raw.replace(/\\n/g, "\n");
  return Buffer.from(raw, "base64").toString("utf8");
}

/// A public key's id: the first 16 hex of the SHA-256 of its DER. The app
/// holds each key it trusts under this.
export function kidOf(publicKey) {
  return createHash("sha256").update(publicKey.export({ type: "spki", format: "der" })).digest("hex").slice(0, 16);
}

/// The signing key from [env], {kid, key}, or null when there is none or it
/// is not an RSA private key of 2048 bits or more. Never logged.
export function signingKey(env = process.env) {
  const pem = pemOf(env.DESKTOP_TOKEN_KEY);
  if (!pem) return null;
  try {
    const key = createPrivateKey(pem);
    if (key.asymmetricKeyType !== "rsa" || key.asymmetricKeyDetails.modulusLength < 2048) return null;
    return { kid: kidOf(createPublicKey(key)), key };
  } catch {
    return null;
  }
}

/// [claims] signed RS256 with [signer] ({kid, key}): a JWT.
export function sign(claims, signer) {
  const part = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const body = `${part({ alg: "RS256", typ: "JWT", kid: signer.kid })}.${part(claims)}`;
  return `${body}.${createSign("RSA-SHA256").update(body).sign(signer.key).toString("base64url")}`;
}

/// The claims of [token] if [publicKey] signed it, else null. The app checks
/// with its own (DesktopPass); this is for tests and tools.
export function verify(token, publicKey) {
  const parts = String(token || "").split(".");
  if (parts.length !== 3) return null;
  try {
    const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
    if (header.alg !== "RS256") return null;
    const ok = createVerify("RSA-SHA256").update(`${parts[0]}.${parts[1]}`)
      .verify(publicKey, Buffer.from(parts[2], "base64url"));
    return ok ? JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) : null;
  } catch {
    return null;
  }
}

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const dayOf = (instant) => (instant ? new Date(instant).toISOString().slice(0, 10) : null);
const later = (a, b) => (!a ? b : !b ? a : a > b ? a : b);

/// What [e] (an entitlement of known standing) says of the desktop, at
/// [now]: {desktop, paidThrough, keep}. [keep] is the day to keep as the
/// account's largest: today or later while it has the desktop, with or
/// without an end. [paidThrough] is null for "no end" while it has it.
export function paidThroughOf(e, now = Date.now()) {
  const today = dayOf(now);
  if (e.desktop !== true) return { desktop: false, paidThrough: null, keep: null };
  const plan = e.plan || {};
  // The owner, and a comp with no end, have no end.
  if (e.owner === true || (plan.source === "override" && !plan.until)) {
    return { desktop: true, paidThrough: null, keep: today };
  }
  const end = plan.source === "override" ? plan.until : (e.subscription?.periodEnd ?? plan.until);
  // While Admission says desktop, it is had today at least: a period that
  // ended while Stripe retries still holds the plan (PLANS.md §1).
  const through = later(today, dayOf(end));
  return { desktop: true, paidThrough: through, keep: through };
}

/// The largest day kept for [userId], or null (none, or the table is not
/// there yet: supabase/desktop_paid_through.sql).
async function keptDay(userId) {
  try {
    const day = await db("rpc/desktop_paid_through_get", { method: "POST", body: { p_user: userId } });
    return typeof day === "string" && DAY.test(day) ? day : null;
  } catch {
    return null;
  }
}

async function keepDay(userId, day) {
  try {
    await db("rpc/desktop_paid_through_put", { method: "POST", body: { p_user: userId, p_day: day } });
  } catch (trouble) {
    console.warn(`desktop: paid_through not kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
  }
}

/// The token for the account [userId] of entitlement [e] (standing known),
/// signed with [signer], at [now]: {token, claims}.
export async function tokenFor(userId, e, signer, now = Date.now(), env = process.env) {
  const { desktop, paidThrough, keep } = paidThroughOf(e, now);
  const kept = await keptDay(userId);
  if (keep && (!kept || keep > kept)) await keepDay(userId, keep);
  // Every build released on or before the day billing began was free for
  // everyone, and stays so (PLANS.md §4, "People who already downloaded").
  const free = DAY.test(String(env.DESKTOP_FREE_THROUGH || "").trim()) ? env.DESKTOP_FREE_THROUGH.trim() : null;
  const through = desktop && paidThrough === null ? null : later(later(paidThrough, kept), free);
  const claims = { sub: userId, plan: e.plan?.key ?? null, desktop, paid_through: through,
    iat: Math.floor(now / 1000) };
  return { token: sign(claims, signer), claims };
}
