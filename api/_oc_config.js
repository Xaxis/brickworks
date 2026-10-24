// Whether this deployment signs people in with orangecheck, and who is
// offered it (2026-10-23): what api/_oc.js checks a token against, and what
// /api/account tells every page and the app (api/account.js), without the
// weight of orangecheck's own code, which only a token needs.

import { dbConfigured } from "./_db.js";

/// The one switch for who sees Sign in with orangecheck, on every page and
/// in the app's sign-in screen (web/account.js, src/ui/sign_in_form.gd):
/// everyone, since steps 2-3 end a session somebody ended everywhere on
/// orangecheck (api/_auth.js). Off, nobody sees the button. Step 1 alone
/// kept it to a tab opened with ?oc=1, a flag that is gone (oc205).
export const ORANGECHECK_FOR_EVERYONE = true;

/// The origins of the pages a token may be for, which are the only
/// audiences one is taken with, from configuration, never the request:
/// in production brickworks.diy alone, the domain orangecheck verified and
/// the only one its list of ended sessions answers for (oc188's review).
/// Every
/// deployment is a production one (tools/deploy.sh --prod --skip-domain),
/// so a release checked at its own address before the domain moves onto it
/// takes no token there. A Preview deployment, its own address. On this
/// machine, only a loopback address set as OC_AUDIENCE. None: no token is
/// taken.
export function audiences() {
  if (process.env.VERCEL_ENV === "production") return ["https://brickworks.diy"];
  if (process.env.VERCEL_ENV) {
    return /^[a-z0-9.-]+\.vercel\.app$/.test(process.env.VERCEL_URL || "") ? [`https://${process.env.VERCEL_URL}`] : [];
  }
  const local = String(process.env.OC_AUDIENCE || "").replace(/\/+$/, "");
  return /^http:\/\/(127\.0\.0\.1|localhost):\d{2,5}$/.test(local) ? [local] : [];
}

/// orangecheck's two hosts: where it signs people in (auth: the tokens'
/// issuer, its key set, where a token is ended and an app's code traded)
/// and where its projects are kept (me: the project's rule, the list of
/// ended sessions). Its own, but on this machine a test stack's when
/// OC_ISSUER and OC_ME_ORIGIN name one (orangecheck's, for the desktop's
/// sign-in, 2026-10-24): never on a deployment, so nothing set there can
/// point a token anywhere else.
export function ocHosts() {
  const local = !process.env.VERCEL_ENV;
  const named = (value) => (local && /^https:\/\/[a-z0-9.-]+$/.test(value || "") ? value : "");
  return { auth: named(process.env.OC_ISSUER) || "https://ochk.io", me: named(process.env.OC_ME_ORIGIN) || "https://me.ochk.io" };
}

/// Whether the desktop app is offered Sign in with orangecheck
/// (api/orangecheck.js ?op=native): the person's own browser, and a
/// one-time code back to the app on 127.0.0.1. orangecheck offers it to
/// test projects alone while it is proven on real builds, so every
/// deployment leaves it off until orangecheck's site-attest has reviewed
/// ours and brickworks.diy's project has it (then true here, as
/// ORANGECHECK_FOR_EVERYONE is). On this machine OC_NATIVE=1 turns it on,
/// for a test project.
export const NATIVE_FOR_EVERYONE = false;

export function nativeOffered() {
  return ocConfigured() && (NATIVE_FOR_EVERYONE || (!process.env.VERCEL_ENV && process.env.OC_NATIVE === "1"));
}

export function ocConfigured() {
  return Boolean(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET && audiences().length
    && dbConfigured() && process.env.SUPABASE_PUBLISHABLE_KEY);
}

/// What /api/account says of orangecheck: {ready, everyone, connect,
/// native}. ready false (no signing secret here, as on a unit's preview):
/// the button, where it is offered, says sign-in with orangecheck is
/// unavailable. connect: orangecheck Connect's key is here, so the sign-in
/// dialog offers the box that makes an orangecheck account
/// (api/orangecheck.js ?op=connect); without it, no box. native: where the
/// desktop app opens orangecheck in the person's browser, {project, auth,
/// audience}, all three public, when it is offered (nativeOffered);
/// otherwise null, and the app's sign-in screen shows no button.
export function orangecheckOffer() {
  return { ready: ocConfigured(), everyone: ORANGECHECK_FOR_EVERYONE,
    connect: Boolean(process.env.OC_CONNECT_KEY && dbConfigured()),
    native: nativeOffered()
      ? { project: process.env.OC_PROJECT_KEY.trim(), auth: ocHosts().auth, audience: audiences()[0] }
      : null };
}
