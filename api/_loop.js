// The loop measured on real people (loopmetrics, 2026-11-23; docs/ANALYTICS.md
// "The loop", docs/MASTERPLAN.md): discover, open, change, share, hear back,
// come back, each step this range against the one before. /admin ›
// Analytics › Funnels' third card reads it; tools/loop_read.mjs prints it.
//
//   GET /api/admin?op=loop&from=&to=   (api/admin.js, after its owner check)
//                                      the same range and filters as
//                                      ?op=analytics (askedOf)
//
// Nothing new is counted about anybody (docs/SOCIAL.md D13): the steps are
// read from the counter's own rows and the social tables, by
// supabase/loop_funnel.sql's insights_loop.

import { accountsOf, askedOf } from "./_analytics.js";
import { db } from "./_db.js";

// What counts as each of the first four steps: [step, surface, kind, name],
// each a name the counter keeps (api/_insights_names.js); tools/insights_names.py
// --check refuses a line whose name it does not keep. Hearing back and coming
// back are read from what the social tables and each account's days keep, in
// supabase/loop_funnel.sql. A name may stand under more than one step.
//
// A unit that adds an act to the loop adds its own block of lines at the end,
// named for it, and changes no other block: nothing else is needed, no SQL,
// no deploy of the database.
export const LOOP = [
  // loopmetrics (2026-11-23): the loop as the site counted it that day.
  // Discovered: a view of the home, the gallery, the library and a set, a
  // model, Talk, a profile, a collection, the builds, the feed, the challenge.
  ["discovered", "site", "view", "/"],
  ["discovered", "site", "view", "/gallery"],
  ["discovered", "site", "view", "/library"],
  ["discovered", "site", "view", "/library/set/:n"],
  ["discovered", "site", "view", "/library/:id"],
  ["discovered", "site", "view", "/m/:id"],
  ["discovered", "site", "view", "/m/:id/v/:n"],
  ["discovered", "site", "view", "/talk"],
  ["discovered", "site", "view", "/talk/b/:board"],
  ["discovered", "site", "view", "/talk/t/:n"],
  ["discovered", "site", "view", "/u/:handle"],
  ["discovered", "site", "view", "/c/:id"],
  ["discovered", "site", "view", "/gallery-lists"],
  ["discovered", "site", "view", "/builds"],
  ["discovered", "site", "view", "/feed"],
  ["discovered", "site", "view", "/challenge"],
  // Opened: a model's page, the studio opened (its viewer and Build it are
  // /app?view=), the step player.
  ["opened", "site", "view", "/m/:id"],
  ["opened", "site", "view", "/m/:id/v/:n"],
  ["opened", "studio", "view", "/app"],
  ["opened", "studio", "panel", "step_playback"],
  // Changed: a part put down in the studio.
  ["changed", "studio", "part", "placed"],
  ["changed", "studio", "milestone", "first_part"],
  // Shared, as the page saw it: Publish pressed in the studio, a model shared
  // from a file on the site, a comment or a reply, a build photo, a Talk
  // thread or post, a challenge entry. The social tables add what the page
  // never sees (a model published from the studio, its photo...).
  ["shared", "studio", "press", "share_publish"],
  ["shared", "site", "act", "share.post"],
  ["shared", "site", "act", "people.comment"],
  ["shared", "site", "act", "people.reply"],
  ["shared", "site", "act", "people.photo"],
  ["shared", "site", "act", "people.talk_start"],
  ["shared", "site", "act", "people.talk_reply"],
  ["shared", "site", "act", "people.enter"],
];

export const STEPS = ["discovered", "opened", "changed", "shared", "heard_back", "came_back"];

/// GET /api/admin?op=loop: the loop for the range asked and the one before.
export async function loopRead(request, tests) {
  const { from, to, filters } = askedOf(request.query || {});
  const accounts = await accountsOf(tests, { unhashed: true });
  let read;
  try {
    read = await db("rpc/insights_loop", { method: "POST", seconds: 20, body: { p_from: from, p_to: to, p_tests: tests,
      p_filters: filters, p_accounts: accounts.map(({ h, id, plan }) => ({ h, id, plan })), p_steps: LOOP } });
  } catch (trouble) {
    // Before supabase/loop_funnel.sql there is no loop to read.
    if (/: 404$/.test(String(trouble?.message || ""))) return { ready: false, tests, from, to, filters };
    throw trouble;
  }
  return { ready: true, tests, from, to, filters, hashed: Boolean(process.env.VIEW_SECRET), accounts: accounts.length, ...read };
}
