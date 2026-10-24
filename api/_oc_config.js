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
