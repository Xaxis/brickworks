// The console's Plans and revenue (admin.html #plans, console2): the plans
// and what each includes, the customers and their plans, the comps, revenue
// by month and Admission's own record, read from Admission through
// /api/admin?op=plans (api/_console_plans.js). Read only: every change is
// the owner's at Admission, and each part links to where.
//
// Everything is put on the page as text, never as markup.
import { $, adminJson, ago, cell, count, day, emptyRow, link, make, resort, say, segmented, sift, timeCell, when }
  from "/admin-kit.js";

const HOW = { subscription: "pays", override: "a comp", default: "the default plan" };
let shown = "";

/// [amount] in [currency]'s minor units, said as money.
export function money(amount, currency = "usd") {
  if (amount === null || amount === undefined) return "—";
  try {
    return new Intl.NumberFormat(undefined, { style: "currency", currency: String(currency).toUpperCase() }).format(amount / 100);
  } catch {
    return `${(amount / 100).toFixed(2)} ${currency}`;
  }
}

function siftCustomers() {
  const n = sift($("customers"), $("customers-q").value, (row) => !shown || row.dataset.source === shown);
  say("customers-note", $("customers").rows.length && !$("customers").rows[0].classList.contains("none")
    ? `${n} of ${$("customers").rows.length} shown.` : "");
}
$("customers-q").addEventListener("input", siftCustomers);
segmented(document.querySelector('[data-filter="customers"]'), (value) => { shown = value; siftCustomers(); });

const limitSaid = (one) => {
  if (one.kind === "flag") return one.name;
  if (one.limit === null) return `${one.name}: no limit`;
  return `${one.name}: ${Number(one.limit).toLocaleString()}${one.unit ? ` ${one.unit}` : ""}`;
};

export async function loadPlans() {
  const p = await adminJson({ op: "plans" });
  for (const [id, where] of [["at-product", "product"], ["at-customers", "customers"], ["at-revenue", "revenue"], ["at-audit", "audit"]]) {
    $(id).href = p.at?.[where] || "https://admission.sh";
  }
  const off = p.billing === "off";
  $("plans-off").hidden = !off;
  say("plans-off-said", off ? `BRICKWORKS_BILLING is off on this deployment${p.key ? "" : ", and it has no ADMISSION_KEY"}: nothing is `
    + "asked of Admission, nothing is limited, and every account has every feature. Plans go on with the owner's yes, "
    + "set in Vercel (tools/deploy.sh), never from here." : "");

  const facts = $("plans-setup");
  facts.replaceChildren();
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("Billing", off ? "off" : `${p.billing} mode${p.billing === "test" ? ": Stripe's sandbox, no real money" : ": real money"}`);
  fact("Admission's key", p.key ? "set (ADMISSION_KEY): plans and each customer's answer" : "none here (ADMISSION_KEY)");
  fact("Read token", p.read ? "set (ADMISSION_READ_TOKEN): revenue and Admission's record"
    : "none here (ADMISSION_READ_TOKEN): revenue and Admission's record need a read token limited to Brickworks, made at ",
  p.read ? "" : link(p.at?.access || "https://admission.sh/access", "Admission's Access"));
  for (const [part, words] of Object.entries(p.said || {})) fact(`Could not read ${part}`, words);

  // The numbers now.
  const revenue = p.metrics?.revenue?.[0] || null;
  $("n-mrr").textContent = revenue ? money(revenue.mrr, revenue.currency) : "—";
  say("n-mrr-said", revenue ? `${money(revenue.paid30d, revenue.currency)} paid in 30 days` : off ? "billing is off" : p.read ? "" : "needs a read token");
  const subs = p.metrics?.subscribers;
  $("n-paying").textContent = subs ? count(subs.paying) : "—";
  say("n-paying-said", subs ? `${count(subs.trialing)} on a trial, ${count(subs.pastDue)} past due, ${count(subs.ending)} ending` : "");
  $("n-comps").textContent = p.metrics ? count(p.metrics.comps) : p.comps ? count(p.comps.length) : "—";
  $("n-customers").textContent = p.metrics ? count(p.metrics.customers) : p.customers ? count(p.customers.length) : "—";

  // The plans.
  const plans = $("plan-list");
  plans.replaceChildren();
  for (const plan of p.plans || []) {
    const row = make("tr");
    row.dataset.plan = plan.key;
    const name = make("th", "", plan.name || plan.key);
    name.scope = "row";
    if (plan.default) name.append(" ", make("span", "badge", "Default"));
    row.append(name);
    cell(row, make("span", plan.status === "live" ? "pill good" : "pill", plan.status || "—"));
    cell(row, plan.includes.length ? plan.includes.map(limitSaid).join("; ") : "nothing beyond the default", "said");
    cell(row, plan.prices.length ? plan.prices.map((one) => `${money(one.amount, one.currency)} a ${one.interval}`).join(", ") : "free");
    cell(row, plan.trial ? `${plan.trial.days ?? ""} days`.trim() : "—", plan.trial ? "" : "faint");
    plans.append(row);
  }
  if (!plans.rows.length) emptyRow(plans, off ? "Billing is off here: no plans are asked of Admission." : p.said?.plans || "No plans.");

  // The customers.
  const body = $("customers");
  body.replaceChildren();
  for (const one of p.customers || []) {
    const row = make("tr");
    row.dataset.account = one.account;
    row.dataset.source = one.source || "";
    row.dataset.find = [one.email, one.plan, one.plan_name].filter(Boolean).join(" ");
    const who = make("th");
    who.scope = "row";
    who.append(link(`#people/${one.account}`, one.email || one.account));
    if (one.owner) who.append(" ", make("span", "badge accent", "Owner"));
    who.dataset.value = one.email || "";
    row.append(who);
    cell(row, one.plan_name || "—");
    cell(row, one.owner ? "an owner" : HOW[one.source] || one.source || "—");
    const until = cell(row, one.until ? day(one.until) : one.subscription?.period_end ? `renews ${day(one.subscription.period_end)}` : "—",
      one.until || one.subscription ? "line" : "line faint");
    until.dataset.value = one.until || one.subscription?.period_end || "";
    cell(row, one.subscription ? `${one.subscription.status}${one.subscription.interval ? `, a ${one.subscription.interval}` : ""}`
      + `${one.subscription.ends_at ? `, ends ${day(one.subscription.ends_at)}` : ""}` : "—", one.subscription ? "" : "faint");
    const asked = cell(row, ago(one.answered_at), "line");
    asked.dataset.value = one.answered_at || "";
    asked.title = when(one.answered_at);
    body.append(row);
  }
  if (!body.rows.length) {
    emptyRow(body, off ? "Billing is off here." : p.said?.customers || "Admission has answered for nobody in this mode yet.");
  }
  resort(body.closest("table"));
  siftCustomers();

  // Revenue by month, and Admission's record.
  const months = $("months-list");
  months.replaceChildren();
  for (const one of p.months || []) {
    const row = make("tr");
    cell(row, one.month, "line");
    cell(row, money(one.paid, one.currency), "n");
    cell(row, money(one.refunded, one.currency), one.refunded ? "n" : "n faint");
    cell(row, money(one.net, one.currency), "n");
    cell(row, `${one.payments}${one.refunds ? `, ${one.refunds} refunded` : ""}`, "n");
    months.append(row);
  }
  if (!months.rows.length) {
    emptyRow(months, off ? "Billing is off here." : !p.read ? "Needs a read token limited to Brickworks (ADMISSION_READ_TOKEN)."
      : p.said?.events || `No payments in ${p.billing} mode yet.`);
  }
  const events = $("events");
  events.replaceChildren();
  for (const one of p.events || []) {
    const row = make("tr");
    timeCell(row, one.at);
    cell(row, make("span", "", make("b", "", one.type), one.summary ? make("br") : "", one.summary ? make("small", "faint", one.summary) : ""), "about");
    cell(row, one.account ? link(`#people/${one.account}`, one.email || one.account) : "—", one.account ? "who" : "faint");
    cell(row, one.amount === null ? "—" : money(one.amount, one.currency), "n");
    events.append(row);
  }
  if (!events.rows.length) {
    emptyRow(events, off ? "Billing is off here." : !p.read ? "Needs a read token limited to Brickworks (ADMISSION_READ_TOKEN)."
      : p.said?.events || "Nothing has happened at Admission in this mode yet.");
  }
  say("plans-note", off ? "" : `Read from Admission ${new Date().toLocaleTimeString()}, ${p.billing} mode.`);
  return p;
}
