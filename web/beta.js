// The beta's page (beta.html): the spots left, and the form or where your
// application stands, from GET /api/plans?op=beta (api/_beta.js). Off,
// the page says the beta is coming soon and asks nothing more. Every word
// goes on the page as text, never as markup.
import { askToSignIn, call } from "/account.js";
import { say, told } from "/card.js";

const $ = (id) => document.getElementById(id);
// A date as the page's language writes one: "30 October 2026".
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";
const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
const day = (iso) => (Number.isFinite(Date.parse(iso || "")) ? DAY.format(new Date(iso)) : "");
const PANELS = ["apply-wait", "apply-soon", "apply-out", "apply-form", "apply-status"];
// The form's own limits, as the server's (api/_beta.js MOST, LEAST_BUILD).
const LEAST_BUILD = 20;

/// Only [id] of the panel's parts shown: swapped in one frame.
function show(id) {
  for (const one of PANELS) $(one).hidden = one !== id;
}

function spotsSaid(pool, applied) {
  if (!pool) return "";
  if (pool.left <= 0) {
    return applied ? say("All {cap} spots are taken.", { cap: pool.cap })
      : say("All {cap} spots are taken. Apply, and you are on the waitlist.", { cap: pool.cap });
  }
  return say("{left} of {cap} spots left", { left: pool.left, cap: pool.cap });
}

/// Where an application stands, in words: [title, line, more].
function standing(answer) {
  const app = answer.application;
  const cap = answer.pool?.cap ?? 100;
  if (app.status === "approved" && app.early) {
    return [say("You are a tester"), say("Your account was made before 29 October 2026, so it has Pro already, free and "
      + "with no end date. You did not need one of the spots."), ""];
  }
  if (app.status === "approved") {
    const month = app.comp === "granted" && app.month_ends_at
      ? say("Your month of Pro runs from {from} to {to}.", { from: day(app.month_starts_at), to: day(app.month_ends_at) })
      : say("Your month of Pro starts the day Pro launches, and runs 30 days from then. We will email you when it starts.");
    return [say("You are in: spot {spot} of {cap}", { spot: app.spot, cap }), month,
      say("When it ends you are back on Free: nothing is charged, and nothing is deleted.")];
  }
  if (app.status === "waitlist") {
    return [say("On the waitlist"), say("You applied on {day}, after all {cap} spots were taken. If we open more, your "
      + "application is read with the others.", { day: day(app.applied_at), cap }), ""];
  }
  if (app.status === "declined") {
    return [say("Not this time"), say("We could not offer you a spot this time. You may apply again from {day}.",
      { day: day(app.may_apply_again_at) }), ""];
  }
  return [say("Applied"), say("You applied on {day}. We read every application ourselves, and will email you once we "
    + "have decided.", { day: day(app.applied_at) }), app.early ? say("Your account was made before 29 October 2026, so "
    + "it has Pro already, free and with no end date; you would not take one of the spots.") : ""];
}

function drawStatus(answer) {
  const [title, said, more] = standing(answer);
  $("status-h").textContent = title;
  $("status-said").textContent = said;
  $("status-more").textContent = more;
  $("status-more").hidden = !more;
  const approved = answer.application.status === "approved";
  $("status-acts").hidden = !approved;
  show("apply-status");
}

/// The page as [answer] has it.
function draw(answer) {
  const open = answer?.beta === "open";
  for (const one of document.querySelectorAll("[data-when]")) one.hidden = one.dataset.when !== (open ? "open" : "off");
  $("to-apply").hidden = !open;
  $("spots").textContent = open ? spotsSaid(answer.pool, Boolean(answer.application))
    : say("Coming soon: applications open here shortly.");
  if (!open) return show("apply-soon");
  if (!answer.signed_in) return show("apply-out");
  const app = answer.application;
  const again = app?.status === "declined" && Date.parse(app.may_apply_again_at || "") <= Date.now();
  if (app && !again) return drawStatus(answer);
  $("apply-was").hidden = !again;
  $("apply-was").textContent = again ? say("Your last application was declined. You may apply again now.") : "";
  return show("apply-form");
}

async function load() {
  let answer = null;
  try {
    const reply = await call("/api/plans?op=beta");
    answer = reply.status === 200 ? reply.body : null;
  } catch {
    answer = null;
  }
  if (!answer) {
    $("spots").textContent = "";
    $("apply-soon").textContent = say("The beta could not be read just now. Try again in a minute.");
    return show("apply-soon");
  }
  return draw(answer);
}

/// What the form says, or a line saying what to fix first.
function filled() {
  const build = $("f-build").value.trim();
  if (build.length < LEAST_BUILD) {
    return [null, say("Say what you would build, in a sentence or two: at least {n} characters.", { n: LEAST_BUILD }), "f-build"];
  }
  if (!$("f-ai").value) return [null, say("Choose which AI you use."), "f-ai"];
  if (!$("f-background").value) return [null, say("Choose your LEGO® or CAD background."), "f-background"];
  if (!$("f-terms").checked) return [null, say("Tick the box to agree to the beta’s terms."), "f-terms"];
  if (!$("f-emails").checked) return [null, say("Tick the box to agree that we email you about the beta."), "f-emails"];
  return [{ build, ai: $("f-ai").value, background: $("f-background").value, background_line: $("f-line").value,
    link: $("f-link").value, terms: true, emails: true }, "", ""];
}

async function send(event) {
  event.preventDefault();
  const said = $("apply-said");
  const [body, why, field] = filled();
  if (!body) {
    said.textContent = why;
    $(field).focus();
    return;
  }
  const button = $("apply-send");
  button.disabled = true;
  said.textContent = say("Sending…");
  try {
    let reply = await call("/api/plans?op=beta", { method: "POST", body });
    if (reply.status === 401 && (await askToSignIn("Sign in again to apply to the beta."))) {
      reply = await call("/api/plans?op=beta", { method: "POST", body });
    }
    if (reply.status === 200) {
      said.textContent = "";
      draw(reply.body);
      $("status-h").focus();
      return;
    }
    said.textContent = told(reply.body?.error, say("That did not go just now. Try again in a minute."));
    if (reply.status === 409) load();
  } catch {
    said.textContent = say("That did not go just now. Try again in a minute.");
  } finally {
    button.disabled = false;
  }
}

$("apply-form").addEventListener("submit", send);
$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in to apply to the Brickworks beta.")) load();
});
// Where focus goes once an application is sent: the answer's title.
$("status-h").tabIndex = -1;
load();
