// Each answer of 500 or over a function gives, kept for the owner's
// "server errors" notification (api/_notify.js, supabase/owner_notify.sql):
// how many came in an hour is what it is measured against.
//
//   export default noted("share", handler);
//
// The answer is already sent when this keeps it: the person never waits on
// it. Never throws but what the handler threw; before owner_notify.sql is
// applied there is nowhere to keep it, and nothing is said.

import { db, dbConfigured } from "./_db.js";
import { scopeOf } from "./_settings.js";

/// [handler], with each 5xx it answered (or threw) kept as one row.
export function noted(fn, handler) {
  return async function notedHandler(request, response) {
    let thrown = null;
    try {
      return await handler(request, response);
    } catch (trouble) {
      thrown = trouble;
      throw trouble;
    } finally {
      const status = thrown ? 500 : Number(response?.statusCode) || 0;
      if (status >= 500 && status <= 599 && dbConfigured()) {
        const op = String(request?.query?.op || "").replace(/[^a-z0-9_]/gi, "").slice(0, 40) || null;
        await db("owner_notify_errors", { method: "POST", prefer: "return=minimal", seconds: 3,
          body: { scope: scopeOf(request), fn, op, status } }).catch(() => null);
      }
    }
  };
}
