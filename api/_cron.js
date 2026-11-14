// Whether a request is Vercel's cron.
//
// tools/deploy.sh writes the project's "crons": /api/share/sweep,
// /api/otp/canary and /api/share/feature once a day each, and
// /api/share/omr once a week. Vercel calls them with
// "Authorization: Bearer <CRON_SECRET>" (set on the project, and in .env
// for the checks that call them by hand); nobody else has it.

import { timingSafeEqual } from "node:crypto";
import { db } from "./_db.js";

export function isCron(request) {
  const secret = process.env.CRON_SECRET || "";
  if (!secret) return false;
  const given = Buffer.from(String(request.headers?.authorization || ""));
  const want = Buffer.from(`Bearer ${secret}`);
  return given.length === want.length && timingSafeEqual(given, want);
}

// A daily sweep deletes the files no row owns, so a read of the rows that
// came back empty and ok (a wrong key under RLS, a PostgREST quirk) would
// say nobody owns anything, and the sweep would delete every file, with
// nothing said until they were gone. An unscoped sweep that would take more
// than a quarter of what it looked at takes nothing, says so in the log
// and in its answer, and leaves it to a person. A few files it may always
// take, so a small bucket still clears two orphans (each a file and its
// picture or copy). A sweep asked of named files (?only=, ?photos=) is
// the asker's and takes what it was asked for.
export const SWEEP_SHARE = 0.25;
export const SWEEP_FLOOR = 4;

/// Why a sweep that looked at [looked] files must not remove [gone] of
/// them, or "" when it may. Pure.
export function sweepHeld(looked, gone) {
  const most = Math.max(SWEEP_FLOOR, Math.floor(looked * SWEEP_SHARE));
  if (gone <= most) return "";
  return `held: it would remove ${gone} of the ${looked} files it looked at, more than the ${most} it may `
    + `(a quarter, or ${SWEEP_FLOOR}), so it removed none. Rows read back empty look like this: check the `
    + "key and the rows, then remove what is left over with a scoped sweep";
}

/// A cron that keeps no lock (the sweep, the beta's daily round) written
/// down as it ends, as the others are by cron_begin and cron_end
/// (supabase/console2.sql cron_noted): the owner's console reads each
/// cron's last runs (/admin#site). Never throws: the run is not the
/// record's, and before console2.sql there is nowhere to write it.
export async function cronNoted(request, job, startedAt, outcome, said = {}) {
  try {
    const holder = /^vercel-cron\b/.test(String(request.headers?.["user-agent"] || "")) ? "vercel-cron" : "by-hand";
    // What it said, if it is short (cron_runs keeps 16 kB at most).
    const words = JSON.stringify(said ?? {});
    await db("rpc/cron_noted", { method: "POST", body: { job, holder, started_at: startedAt, outcome,
      said: words.length <= 4000 ? said ?? {} : { clipped: words.slice(0, 300) } } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`cron: ${job} not written down: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
}
