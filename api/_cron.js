// Whether a request is Vercel's cron.
//
// tools/deploy.sh writes the project's "crons": /api/share/sweep and
// /api/otp/canary, once a day each. Vercel calls them with
// "Authorization: Bearer <CRON_SECRET>" (set on the project, and in .env
// for the checks that call them by hand); nobody else has it. The sweep
// in api/share.js keeps its own copy of this from before, until share.js
// next changes.

import { timingSafeEqual } from "node:crypto";

export function isCron(request) {
  const secret = process.env.CRON_SECRET || "";
  if (!secret) return false;
  const given = Buffer.from(String(request.headers?.authorization || ""));
  const want = Buffer.from(`Bearer ${secret}`);
  return given.length === want.length && timingSafeEqual(given, want);
}
