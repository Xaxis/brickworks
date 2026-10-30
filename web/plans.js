// /plans (web/plans.html): the Monthly / Yearly choice, which price Pro
// shows; Pro's way in, which is the interest form while Pro is not for
// sale and the step before Checkout once it is; the beta's callout while
// the beta is open; and the interest form.
//
// Monthly or Yearly ([data-billing], Yearly first) shows the prices that
// say it ([data-billed]), chooses it in the form, and is where Upgrade to
// Pro goes: /settings?upgrade=month or year#plan (web/plan.js opens the
// step at once). Whether Pro is for sale is GET /api/plans's to say
// (api/_billing.js currentOffer, only while BRICKWORKS_BILLING is on; off,
// it is refused as it always was): for sale, what is marked
// data-when="sale" is shown in place of data-when="soon", with Pro's
// prices as Admission has them. Asked once; until it answers, and if it
// cannot, the page is as written: coming soon.
//
// "Tell me when it's ready" on Pro opens the form for that plan, the
// address of whoever is signed in filled in. Sent to /api/plans, which
// answers the same words for a first entry and a second (a second for the
// same plan changes the first), and Take it off deletes that address's
// entries, every plan. Nothing typed is shown back as markup.
import { email, madeUp } from "/account.js";

const $ = (id) => document.getElementById(id);
const dialog = $("interest");
const form = $("interest-form");
const said = $("interest-said");
const send = $("interest-send");
const forget = $("interest-forget");
// The plan the form was opened for: Pro, the one there is.
let chosen = "pro";
// How Pro is billed, as the page's choice says: "month" or "year".
let billed = "year";
const upgrade = $("pro-upgrade");

/// Billed by [interval]: its prices shown, its choice pressed, the form's
/// dropdown and Upgrade to Pro following.
function bill(interval) {
  billed = interval === "month" ? "month" : "year";
  for (const button of document.querySelectorAll("[data-billing]")) {
    button.setAttribute("aria-pressed", String(button.dataset.billing === billed));
  }
  for (const one of document.querySelectorAll("[data-billed]")) one.hidden = one.dataset.billed !== billed;
  $("interest-billing").value = billed === "month" ? "monthly" : "yearly";
  if (upgrade) upgrade.href = `/settings?upgrade=${billed}#plan`;
}
for (const button of document.querySelectorAll("[data-billing]")) {
  button.addEventListener("click", () => bill(button.dataset.billing));
}

/// "$8" or "$80" from Admission's minor units, as the page writes a price.
function money(amount, currency) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: String(currency || "usd").toUpperCase(),
    minimumFractionDigits: amount % 100 ? 2 : 0 }).format(amount / 100);
}

/// Pro for sale: the page's "sale" parts in place of its "soon" ones, and
/// Pro's prices as Admission has them.
async function onSale() {
  let offer = null;
  try {
    const answer = await fetch("/api/plans", { headers: { accept: "application/json" } });
    // Read whatever it says, refused or not: an answer whose words are never
    // read stays open, and the page never goes quiet (plans_flow's
    // networkidle waited 30 s for the 405 billing off gives).
    const said = await answer.json().catch(() => null);
    if (answer.ok) offer = said;
  } catch { /* coming soon, as written */ }
  if (!offer || offer.forSale !== true) return;
  for (const one of document.querySelectorAll("[data-when]")) one.hidden = one.dataset.when !== "sale";
  const prices = offer.pro?.prices || {};
  for (const interval of ["month", "year"]) {
    const amount = prices[interval];
    const shown = document.querySelector(`[data-amount="${interval}"]`);
    if (shown && Number.isInteger(amount) && amount > 0) shown.textContent = money(amount, offer.pro.currency);
  }
  document.documentElement.dataset.plans = "sale";
}
onSale();

/// The beta's callout under the plans, only while the beta is open
/// (GET /api/plans?op=beta_spots, beta361: {beta: "open", cap, left}; off,
/// unknown or a refusal and it stays hidden). Out of the first screen, so
/// its coming moves nothing in view.
async function beta() {
  const callout = $("beta");
  if (!callout) return;
  try {
    const answer = await fetch("/api/plans?op=beta_spots", { headers: { accept: "application/json" } });
    const said = await answer.json().catch(() => null);
    if (answer.ok && said?.beta === "open") callout.hidden = false;
  } catch { /* hidden, as written */ }
}
beta();

/// The form, fresh, for [plan].
function open(plan) {
  form.hidden = false;
  $("interest-done").hidden = true;
  said.textContent = "";
  chosen = plan;
  const mine = email();
  if (!$("interest-email").value && mine && !madeUp(mine)) $("interest-email").value = mine;
  dialog.showModal();
  $("interest-email").focus();
}

for (const button of document.querySelectorAll("[data-interest]")) {
  button.addEventListener("click", () => open(button.dataset.interest));
}
for (const button of dialog.querySelectorAll("[data-close]")) {
  button.addEventListener("click", () => dialog.close());
}

/// [body] sent to /api/plans, and what it said shown: the thanks in place of
/// the form, or why not under it.
async function ask(body) {
  send.disabled = true;
  forget.disabled = true;
  said.textContent = "Sending…";
  let reply;
  try {
    const answer = await fetch("/api/plans", {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
    });
    reply = { ok: answer.ok, body: await answer.json().catch(() => ({})) };
  } catch {
    reply = { ok: false, body: { error: "That did not go: no connection. Try again in a minute." } };
  } finally {
    send.disabled = false;
    forget.disabled = false;
  }
  if (!reply.ok) {
    said.textContent = reply.body.error || "That did not go just now. Try again in a minute.";
    return;
  }
  $("interest-thanks").textContent = reply.body.said;
  form.hidden = true;
  $("interest-done").hidden = false;
  $("interest-done").querySelector("button").focus();
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  ask({ email: $("interest-email").value, plan: chosen,
    billing: $("interest-billing").value, note: $("interest-note").value });
});
forget.addEventListener("click", () => ask({ email: $("interest-email").value, forget: true }));
