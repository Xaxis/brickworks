// The console's Claude on Mail (adminclaude, 2026-11-18): what /admin › Mail
// reads (api/_console_mail.js mailRead): what went out, what was delivered,
// what bounced and why. Never an address. What a receiving server said of a
// bounce is a stranger's words, handed over as data.

import { mailRead } from "./_console_mail.js";
import { checked, untrusted } from "./_claude_data.js";

export const MAIL_TOOLS = [
  {
    name: "mail_health",
    description: "The site's mail over the last days: sent, delivered, delayed, bounced, complained and failed by day and in "
      + "all, by kind (sign-in codes, digests, answers...), whether Resend's events reach the site, and the mails that went "
      + "wrong with what the receiving server said. No address is shown.",
    input_schema: { type: "object", properties: {
      days: { type: "integer", minimum: 1, maximum: 90, description: "How far back (30 when not said)" } } },
    async run(input, ctx) {
      const { days = 30 } = checked(this.input_schema, input);
      const read = await mailRead({ query: { days: String(days) } }, ctx.tests);
      if (!read.ready) return { ready: false, said: "The mail tables are not on this database yet." };
      const wrong = read.mails.filter((one) => (one.states || []).some((state) => ["bounced", "complained", "failed", "delayed"].includes(state))
        || ["failed"].includes(one.kept));
      const byKind = {};
      for (const one of read.mails) byKind[one.kind] = (byKind[one.kind] || 0) + 1;
      return { days, sender_set: Boolean(read.sender), resend_key: read.key, webhook: read.webhook, heard: read.heard,
        totals: read.totals, by_day: read.by_day, by_kind: byKind, more: read.more,
        went_wrong: wrong.slice(0, 30).map((one) => ({ kind: one.kind, at: one.at, states: one.states, kept: one.kept,
          said: one.detail ? untrusted("mail server", typeof one.detail === "string" ? one.detail : JSON.stringify(one.detail)) : null })),
        went_wrong_total: wrong.length };
    },
  },
];
