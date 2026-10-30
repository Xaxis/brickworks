// Whether a request is Vercel's cron.
//
// tools/deploy.sh writes the project's "crons": /api/share/sweep,
// /api/otp/canary and /api/share/feature once a day each, and
// /api/share/omr once a week. Vercel calls them with
// "Authorization: Bearer <CRON_SECRET>" (set on the project, and in .env
// for the checks that call them by hand); nobody else has it.

import { timingSafeEqual } from "node:crypto";

export function isCron(request) {
  const secret = process.env.CRON_SECRET || "";
  if (!secret) return false;
  const given = Buffer.from(String(request.headers?.authorization || ""));
  const want = Buffer.from(`Bearer ${secret}`);
  return given.length === want.length && timingSafeEqual(given, want);
}
