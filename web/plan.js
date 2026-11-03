// Your plan, a row of /settings (docs/PLANS.md U3): which plan this account
// is on and how it stands, and the ways to Stripe, which are Admission's
// (api/plans.js): Upgrade to Pro, through the step before Checkout, and
// Manage billing. settings.js draws it only while this deployment has
// plans on (/api/people?op=me says so); off, none of it is asked or shown.
//
// The step before Checkout (docs/PLANS.md M7, Bookwright's ADR-0014
// decision 6) is a dialog: what Pro adds, monthly or yearly, and beside a
// box nobody ticks but the person, the terms: the price and how often,
// that it renews at it until cancelled, how to cancel and when that takes
// effect, and who sells it. The server refuses Checkout without the box,
// and keeps the agreement first. Back from Checkout (?billing=done) the
// plan is asked afresh until Stripe's word has reached Admission;
// ?upgrade=month or year opens the step at once (for /plans).
//
// Deleting the account ends a plan it pays for (endsWithAccount), and the
// delete form says so before anyone presses it.
//
// Pro, paid for or given, says what it includes, the licence for
// commercial use linked to its terms (/terms#commercial-use); a paid one has
// Cancel Pro, the portal's own cancel step, so cancelling is two clicks:
// that and Stripe's confirm.
//
// Every word goes on the page as text, never as markup.
import { call } from "/account.js";
import { langAt, number, say, told } from "/card.js";

const ATYPIC = { terms: "https://atypic.ai/terms", refunds: "https://atypic.ai/refunds", support: "support@atypic.ai" };
// The page's language: a date as it writes one, "30 October 2026", and
// money as it writes it, in the currency Admission gives. English writes
// money as the US does ("$8.00", where en-GB writes "US$8.00").
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const MONEY = LOCALE === "en-GB" ? "en-US" : LOCALE;
// Days as Admission keeps them, in UTC.
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const dated = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");
// How long Stripe's word may take before the page says it is taking a while.
const FINISH_MS = 45000;

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

function link(href, words) {
  const a = make("a", "", words);
  a.href = href;
  return a;
}

/// [said], a sentence in the page's language (web/card.js say), into
/// [into]: each {name} in it [parts]'s element or words.
function sayInto(into, said, parts) {
  for (const piece of said.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && name in parts ? parts[name] : piece);
  }
  return into;
}

/// "$8.00 USD a month", as the terms say a price.
function charge(amount, currency, interval) {
  const money = new Intl.NumberFormat(MONEY, { style: "currency", currency: currency.toUpperCase(),
    minimumFractionDigits: 2 }).format(amount / 100);
  const code = currency.toUpperCase();
  return interval === "year" ? say("{money} {code} a year", { money, code }) : say("{money} {code} a month", { money, code });
}

/// "$8" or "$80", for a line that only mentions the price.
function short(amount, currency) {
  return new Intl.NumberFormat(MONEY, { style: "currency", currency: currency.toUpperCase(),
    minimumFractionDigits: amount % 100 ? 2 : 0 }).format(amount / 100);
}

/// What a yearly price saves on twelve months of the monthly one, in whole months.
function monthsFree(prices) {
  if (!prices.month || !prices.year) return 0;
  return Math.max(0, Math.round((prices.month * 12 - prices.year) / prices.month));
}

/// The way to Stripe for [body] at [path], then there; or [tell] what went wrong.
async function toStripe(path, body, button, tell) {
  button.disabled = true;
  tell("");
  const answer = await call(path, { method: "POST", body }).catch(() => ({ status: 0, body: {} }));
  if (answer.status === 200 && typeof answer.body.url === "string" && /^https:\/\//.test(answer.body.url)) {
    location.assign(answer.body.url);
    return;
  }
  button.disabled = false;
  tell(told(answer.body.error, say("That did not work just now. Try again in a minute.")));
}

/// The step before Checkout, over the page: what Pro adds, monthly or
/// yearly, the terms, and the box. Checkout follows only from its button.
function upgrade(offer, start, opener) {
  const pro = offer.pro;
  const currency = pro.currency || "usd";
  const intervals = ["month", "year"].filter((i) => Number.isInteger(pro.prices[i]));
  let interval = intervals.includes(start) ? start : intervals[intervals.length - 1];
  const dialog = make("dialog", "consent-step");
  dialog.id = "upgrade";
  const title = make("h2", "", say("Upgrade to Pro"));
  title.id = "upgrade-title";
  dialog.setAttribute("aria-labelledby", title.id);
  const kept = offer.free.savedModels;
  const adds = sayInto(make("p"), say("Pro has everything Free has, and two things more: {models} (Free keeps {kept}), and "
    + "{licence}: selling instructions, kits, renders or builds made to order, under the terms that come with "
    + "Pro. {compare}.", {
    kept: kept === "unlimited" ? say("any number") : Number.isFinite(Number(kept)) ? number(kept) : String(kept),
  }), {
    models: make("b", "", say("any number of models kept with your account")),
    licence: make("b", "", say("a licence for commercial use")),
    compare: link(`${langAt()}/plans`, say("Compare the plans")),
  });
  // Monthly or yearly: the site's segmented control, the chosen one pressed.
  const choose = make("div", "segmented");
  choose.setAttribute("role", "group");
  choose.setAttribute("aria-label", say("How often you pay"));
  const buttons = intervals.map((i) => {
    const b = make("button", "", i === "month" ? say("Monthly") : say("Yearly"));
    b.type = "button";
    b.dataset.interval = i;
    choose.append(b);
    return b;
  });
  const price = make("p", "price");
  const terms = make("div", "terms");
  terms.id = "upgrade-terms";
  const box = make("input");
  box.type = "checkbox";
  box.id = "upgrade-agree";
  box.setAttribute("aria-describedby", terms.id);
  const agreeing = make("span");
  const tick = make("label", "choice", box, agreeing);
  const go = make("button", "cta", say("Continue to checkout"));
  go.type = "submit";
  const later = make("button", "cta ghost", say("Not now"));
  later.type = "button";
  const said = make("p", "said");
  said.setAttribute("role", "status");
  const form = make("form", "", choose, price, terms, tick, make("div", "actions", go, later), said);
  const where = make("p", "note", say("You pay on Stripe's checkout page. Your card is never sent to Brickworks."));
  dialog.append(title, adds, form, where);

  const show = () => {
    const amount = pro.prices[interval];
    const each = charge(amount, currency, interval);
    for (const b of buttons) b.setAttribute("aria-pressed", String(b.dataset.interval === interval));
    const free = interval === "year" ? monthsFree(pro.prices) : 0;
    price.replaceChildren();
    sayInto(price, free ? say("{price}, {n} months free", { n: number(free) }) : "{price}", { price: make("b", "", each) });
    const yearly = interval === "year";
    terms.replaceChildren(
      make("p", "", yearly
        ? say("{price}, plus any tax where you live, shown at checkout. Charged today, then at the start of "
          + "each year: it renews automatically at {price} until you cancel.", { price: each })
        : say("{price}, plus any tax where you live, shown at checkout. Charged today, then at the start of "
          + "each month: it renews automatically at {price} until you cancel.", { price: each })),
      make("p", "", yearly
        ? say("Cancel any time in Settings, under Plan, with Cancel Pro, or at link.com. Pro stays on to "
          + "the end of the year you have paid for, and you are not charged again.")
        : say("Cancel any time in Settings, under Plan, with Cancel Pro, or at link.com. Pro stays on to "
          + "the end of the month you have paid for, and you are not charged again.")),
      sayInto(make("p"), say("Sold through Link, the merchant of record, for Atypic: your statement reads LINK.COM* ATYPIC. "
        + "{terms} · {refunds}"), {
        terms: link(ATYPIC.terms, say("Terms of sale")),
        refunds: link(`${langAt()}/terms#refunds`, say("Refunds and cancelling")),
      }));
    agreeing.textContent = say("I agree that Pro renews automatically at {price} until I cancel.", { price: each });
    // An agreement is to one price: another one is agreed afresh.
    box.checked = false;
    go.disabled = true;
    said.textContent = "";
  };
  for (const b of buttons) {
    b.addEventListener("click", () => {
      interval = b.dataset.interval;
      show();
    });
  }
  box.addEventListener("change", () => {
    go.disabled = !box.checked;
  });
  const close = () => {
    dialog.close();
    dialog.remove();
    opener?.focus();
  };
  later.addEventListener("click", close);
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    close();
  });
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!box.checked) {
      said.textContent = say("Tick the box to agree that Pro renews until you cancel.");
      return;
    }
    toStripe("/api/plans?op=checkout", { interval, consent: true, amount: pro.prices[interval] }, go, (words) => {
      said.textContent = words;
    });
  });
  show();
  document.body.append(dialog);
  document.documentElement.dataset.upgrade = "open";
  dialog.addEventListener("close", () => delete document.documentElement.dataset.upgrade);
  dialog.showModal();
  buttons.find((b) => b.dataset.interval === interval)?.focus();
}

/// A button to Stripe's billing portal: its home, or straight to [flow].
function portalButton(label, flow, status, ghost = true) {
  const b = make("button", ghost ? "cta ghost" : "cta", label);
  b.type = "button";
  b.addEventListener("click", () => toStripe("/api/plans?op=portal", flow ? { flow } : {}, b, (words) => {
    status.textContent = words;
  }));
  return b;
}

/// What Pro includes, its licence linked to the terms.
function included() {
  return sayInto(make("p", "included"), say("Included: {models}, and {licence}."), {
    models: say("any number of models kept with your account"),
    licence: link(`${langAt()}/terms#commercial-use`, say("a licence for commercial use")),
  });
}

/// What the plan's row says of [mine] (GET /api/plans?op=plan), with the
/// offer [offer] (GET /api/plans): its words, its buttons, and a state for
/// checks to read.
function standing(mine, offer, status) {
  const s = mine.subscription;
  const pro = offer?.pro;
  if (mine.standing !== "known") {
    return { state: "unknown", lines: [say("Your plan cannot be read just now. Nothing is held back meanwhile; look "
      + "again in a minute.")] };
  }
  if (mine.owner) return { state: "owner", lines: [say("An owner's account: everything, with no limits, and nothing to pay.")] };
  if (s && (s.status === "past_due" || s.status === "unpaid")) {
    return { state: "unpaid", lines: [make("b", "", say("Your last payment did not go through.")), ` ${say("Pro stays on while "
      + "the card is tried again over the next few days. Update your card so it goes through.")}`],
    buttons: [portalButton(say("Update your card"), "payment_method_update", status, false),
      portalButton(say("Manage billing"), "", status)] };
  }
  if (s && s.status !== "canceled" && s.endsAt) {
    return { state: "ending", lines: [make("b", "", say("Pro until {day}.", { day: dated(s.endsAt) })), ` ${say("You will not be charged "
      + "again. Then this account moves to Free and keeps everything in it; you can subscribe again at any time.")}`],
    buttons: [portalButton(say("Manage billing"), "", status)] };
  }
  if (s && s.status !== "canceled" && mine.plan?.source === "subscription") {
    const interval = s.interval === "year" ? "year" : "month";
    const amount = pro?.prices?.[interval];
    const what = Number.isInteger(amount) ? say("Pro, {price}.", { price: charge(amount, pro.currency || "usd", interval) })
      : say("Pro.");
    return { state: "pro", lines: [make("b", "", what), ` ${say("Renews {day}.", { day: dated(s.periodEnd) })}`],
      included: included(),
      more: say("In Stripe's billing portal: your card, monthly or yearly, your invoices, or cancelling. Receipts "
        + "come from Link by email."),
      buttons: [portalButton(say("Manage billing"), "", status), portalButton(say("Cancel Pro"), "cancel", status)] };
  }
  if (mine.plan?.key === "pro") {
    const given = mine.plan.until ? say("Pro, given to you until {day}.", { day: dated(mine.plan.until) })
      : say("Pro, given to you.");
    return { state: "given", lines: [make("b", "", given), ` ${say("Nothing to pay.")}`], included: included() };
  }
  const most = mine.savedModels?.limit;
  const lines = [make("b", "", say("Free.")),
    Number.isInteger(most) ? ` ${say("Up to {n} models kept with your account.", { n: number(most) })}` : ""];
  if (!pro || !offer.forSale) return { state: "free", lines, more: say("Pro opens soon.") };
  const currency = pro.currency || "usd";
  const month = Number.isInteger(pro.prices.month) ? short(pro.prices.month, currency) : "";
  const year = Number.isInteger(pro.prices.year) ? short(pro.prices.year, currency) : "";
  const more = month && year
    ? say("Pro: any number of models kept with your account, and commercial use, at {month} a month or {year} a year.",
      { month, year })
    : month ? say("Pro: any number of models kept with your account, and commercial use, at {month} a month.", { month })
      : say("Pro: any number of models kept with your account, and commercial use, at {year} a year.", { year });
  const up = make("button", "cta", say("Upgrade to Pro"));
  up.type = "button";
  up.id = "upgrade-go";
  up.addEventListener("click", () => upgrade(offer, null, up));
  return { state: "free", lines, more, buttons: [up], upgrade: (start) => upgrade(offer, start, up) };
}

/// The plan's row, drawn into [row]; [fresh] asks Admission past what the
/// server keeps. Resolves with what it drew.
async function draw(row, fresh = false) {
  const [mine, offer] = await Promise.all([
    call(`/api/plans?op=plan${fresh ? "&fresh=1" : ""}`).catch(() => ({ status: 0, body: {} })),
    call("/api/plans").catch(() => ({ status: 0, body: {} })),
  ]);
  const status = make("p", "said wide");
  status.setAttribute("role", "status");
  const said = mine.status === 200
    ? standing(mine.body, offer.status === 200 ? offer.body : null, status)
    : { state: "unknown", lines: [told(mine.body.error, say("Your plan could not be read just now."))] };
  const words = make("div", "", make("h2", "", say("Plan")), make("p", "", ...said.lines), said.included ?? null,
    said.more ? make("p", "", said.more) : null);
  words.id = "plan-said";
  row.replaceChildren(words, said.buttons ? make("div", "actions", ...said.buttons) : "", status);
  row.dataset.plan = said.state;
  return { ...said, mine: mine.body, status };
}

/// What deleting the account does to a plan it pays for, as the plan's row
/// [state] has it: Pro ends now, and nothing is charged again, since
/// api/account.js ends it at Admission before anything else goes. {words}
/// for the question asked before deleting, and {said} for the form; null
/// for a plan nobody pays for.
export function endsWithAccount(state) {
  if (!["pro", "ending", "unpaid"].includes(state)) return null;
  const words = say("Your Pro plan ends now, with the account, and you are not charged again.");
  const said = sayInto(make("p", "", `${words} `), say("Any refund is as the {terms} say."),
    { terms: link(ATYPIC.refunds, say("terms of sale")) });
  said.id = "delete-plan";
  return { words, said };
}

/// The plan's row on /settings, after [after]; resolves once drawn. Back
/// from Checkout or the portal, it is asked afresh, and again as Stripe's
/// word arrives.
export async function planPart(after) {
  const row = make("div", "setting");
  row.id = "plan";
  after.after(row);
  const asked = new URLSearchParams(location.search);
  const back = asked.get("billing");
  const start = asked.get("upgrade");
  // A reload neither waits again nor opens the step again.
  if (back || start) history.replaceState(null, "", `${location.pathname}${location.hash}`);
  let drawn = await draw(row, back === "done" || back === "portal");
  if (back === "cancelled" && drawn.state === "free") {
    drawn.status.textContent = say("Checkout closed. You have not been charged, and this account is still on Free.");
  }
  if (back === "portal") setTimeout(() => draw(row, true), 4000);
  if (back === "done" && drawn.state === "free") {
    const began = Date.now();
    const waiting = () => {
      drawn.status.textContent = Date.now() - began > FINISH_MS
        ? say("Stripe has not told Brickworks yet. It usually takes seconds, and this shows Pro as soon as it knows; "
          + "do not pay again. If Pro has not come on in a few minutes, write to {address}.", { address: ATYPIC.support })
        : say("Finishing your upgrade… This usually takes a few seconds.");
    };
    waiting();
    // Asked again every few seconds, for five minutes at most.
    const tick = async () => {
      drawn = await draw(row, true);
      if (drawn.state !== "free") return;
      waiting();
      if (Date.now() - began < 5 * 60000) setTimeout(tick, 2500);
    };
    setTimeout(tick, 2500);
  }
  if ((start === "month" || start === "year") && drawn.upgrade) drawn.upgrade(start);
  return drawn;
}
