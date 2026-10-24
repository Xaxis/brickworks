// Whether this deployment signs people in with orangecheck, and who is
// offered it (2026-10-23): what api/_oc.js checks a token against, and what
// /api/account tells every page and the app (api/account.js), without the
// weight of orangecheck's own code, which only a token needs.

import { dbConfigured } from "./_db.js";

/// The one switch for who sees Sign in with orangecheck. Step 1 of
/// orangecheck's brief kept it off, since a session did not yet end when
/// somebody signed out of orangecheck everywhere: then it was offered only
/// to a tab opened with ?oc=1 and to the test accounts (web/account.js,
/// src/ui/sign_in_form.gd). Steps 2-3 end such a session (api/_auth.js), so
/// it is on for everyone. Every server path works either way.
export const ORANGECHECK_FOR_EVERYONE = true;

/// The origins of the pages a token may be for, which are the only
/// audiences one is taken with, from configuration, never the request:
/// brickworks.diy, and this deployment's own address (Vercel's VERCEL_URL),
/// where a release is checked before the domain is moved onto it. Every
/// deployment is a production one (tools/deploy.sh --prod --skip-domain), so
/// both are a production deployment's. On this machine, only a loopback
/// address set as OC_AUDIENCE. None: no token is taken.
export function audiences() {
  const own = /^[a-z0-9.-]+\.vercel\.app$/.test(process.env.VERCEL_URL || "") ? [`https://${process.env.VERCEL_URL}`] : [];
  if (process.env.VERCEL_ENV === "production") return ["https://brickworks.diy", ...own];
  if (process.env.VERCEL_ENV) return own;
  const local = String(process.env.OC_AUDIENCE || "").replace(/\/+$/, "");
  return /^http:\/\/(127\.0\.0\.1|localhost):\d{2,5}$/.test(local) ? [local] : [];
}

export function ocConfigured() {
  return Boolean(process.env.OC_PROJECT_KEY && process.env.OC_SIGNING_SECRET && audiences().length
    && dbConfigured() && process.env.SUPABASE_PUBLISHABLE_KEY);
}

/// What /api/account says of orangecheck: {ready, everyone}. ready false
/// (no signing secret here, as on a unit's preview): the button, where it
/// is offered, says sign-in with orangecheck is unavailable.
export function orangecheckOffer() {
  return { ready: ocConfigured(), everyone: ORANGECHECK_FOR_EVERYONE };
}
