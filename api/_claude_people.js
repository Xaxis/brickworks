// The console's Claude on People (adminclaude, 2026-11-18): what /admin ›
// People reads (api/_console.js people), counted. Never anyone's email, id,
// handle or name: only how many, when they came, and what they do.

import { people } from "./_console.js";
import { checked } from "./_claude_data.js";

const DAY = 864e5;

export const PEOPLE_TOOLS = [
  {
    name: "people_counts",
    description: "The site's accounts in numbers: how many, how many joined and signed in each week, how they sign in, how "
      + "many publish models or use the Claude connector, beta testers, plans and accounts barred. Counts only: nobody's "
      + "email, id, handle or name.",
    input_schema: { type: "object", properties: {
      weeks: { type: "integer", minimum: 1, maximum: 52, description: "Weeks of growth to count back (8 when not said)" } } },
    async run(input, ctx) {
      const { weeks = 8 } = checked(this.input_schema, input);
      const read = await people(ctx.tests);
      const rows = read.people.filter((one) => !one.owner);
      const now = Date.now();
      const within = (iso, days) => Boolean(iso) && Date.parse(iso) > now - days * DAY;
      const tally = (key) => rows.reduce((out, one) => {
        const value = String(key(one) ?? "none");
        out[value] = (out[value] || 0) + 1;
        return out;
      }, {});
      const byWeek = [];
      for (let week = weeks - 1; week >= 0; week -= 1) {
        const from = now - (week + 1) * 7 * DAY;
        const to = now - week * 7 * DAY;
        const inside = (iso) => Boolean(iso) && Date.parse(iso) > from && Date.parse(iso) <= to;
        byWeek.push({ week_ending: new Date(to).toISOString().slice(0, 10), joined: rows.filter((one) => inside(one.joined)).length,
          signed_in: rows.filter((one) => inside(one.last_sign_in)).length });
      }
      return {
        total: rows.length,
        joined: { day: rows.filter((one) => within(one.joined, 1)).length, week: rows.filter((one) => within(one.joined, 7)).length,
          month: rows.filter((one) => within(one.joined, 30)).length },
        signed_in: { week: rows.filter((one) => within(one.last_sign_in, 7)).length,
          month: rows.filter((one) => within(one.last_sign_in, 30)).length },
        by_week: byWeek,
        confirmed: rows.filter((one) => one.confirmed).length,
        signs_in_with: tally((one) => one.signs_in_with),
        publishing: { accounts: rows.filter((one) => one.models > 0).length, models: rows.reduce((sum, one) => sum + one.models, 0),
          listed: rows.reduce((sum, one) => sum + one.listed, 0) },
        connector: { accounts: rows.filter((one) => one.connectors > 0).length,
          seen_week: rows.filter((one) => within(one.connector_seen, 7)).length },
        beta: read.beta_known ? tally((one) => one.beta?.state || "not a tester") : null,
        plans: tally((one) => (typeof one.plan === "string" ? one.plan : one.plan?.key || one.plan?.name || "none")),
        barred: rows.filter((one) => one.barred).length,
        billing: read.billing,
      };
    },
  },
];
