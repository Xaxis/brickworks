// The console's Claude on Plans (adminclaude, 2026-11-18): what /admin ›
// Plans reads (api/_console_plans.js plansRead): the plans, their prices and
// what each includes, and the customers and money in numbers. No customer by
// name, account or email; nothing it can change.

import { plansRead } from "./_console_plans.js";
import { checked, redacted } from "./_claude_data.js";

const tally = (list, key) => (list || []).reduce((out, one) => {
  const value = String(key(one) ?? "none");
  out[value] = (out[value] || 0) + 1;
  return out;
}, {});

export const PLANS_TOOLS = [
  {
    name: "plans_read",
    description: "Brickworks' plans as Admission keeps them: each plan, its prices and what it includes, how many customers "
      + "are on each and by what (paid, trial, comp), the revenue numbers Admission reports and the month-by-month events. "
      + "Read only: you cannot change a plan, a price or a customer.",
    input_schema: { type: "object", properties: {} },
    async run(input) {
      checked(this.input_schema, input);
      const read = await plansRead();
      const customers = read.customers || null;
      return redacted({
        billing: read.billing,
        admission: { key: read.key, owner_read: read.read },
        plans: read.plans,
        grace_days: read.grace_days ?? null,
        customers: customers && { total: customers.filter((one) => !one.owner).length, by_plan: tally(customers.filter((one) => !one.owner), (one) => one.plan_name),
          by_status: tally(customers, (one) => one.subscription?.status || "no subscription"), by_source: tally(customers, (one) => one.source) },
        metrics: read.metrics,
        months: read.months,
        events_by_type: read.events ? tally(read.events, (one) => one.type) : null,
        said: read.said,
      });
    },
  },
];
