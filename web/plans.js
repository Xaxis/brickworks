// The interest form on /plans (web/plans.html): "Tell me when it's ready"
// on Plus or Creator opens it with that plan chosen, yearly first, and the
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

/// The form, fresh, for [plan].
function open(plan) {
  form.hidden = false;
  $("interest-done").hidden = true;
  said.textContent = "";
  $("interest-plan").value = plan;
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
  ask({ email: $("interest-email").value, plan: $("interest-plan").value,
    billing: $("interest-billing").value, note: $("interest-note").value });
});
forget.addEventListener("click", () => ask({ email: $("interest-email").value, forget: true }));
