// The console's Claude on the Site and its backend (adminclaude,
// 2026-11-18): what /admin › Site reads (api/_console_site.js siteRead): the
// releases that went live, each cron's last runs and how it stands, and
// whether each part of Supabase answers.

import { siteRead } from "./_console_site.js";
import { checked, redacted } from "./_claude_data.js";

export const SITE_TOOLS = [
  {
    name: "site_health",
    description: "The site and its backend now: the releases that went live (newest first), each scheduled job's last runs "
      + "and whether it is ok, late or failing, and whether each part of Supabase (database, sign-in, storage) answers, "
      + "with what to do when one does not.",
    input_schema: { type: "object", properties: {} },
    async run(input) {
      checked(this.input_schema, input);
      const read = await siteRead();
      return redacted({
        releases: (read.releases || []).slice(0, 15).map((one) => ({ tag: one.tag, title: one.title, live_at: one.live_at,
          units: one.units })),
        releases_said: read.releases_error,
        crons: (read.crons || []).map((one) => ({ ...one, runs: (one.runs || []).slice(0, 3) })),
        health: read.health,
      });
    },
  },
];
