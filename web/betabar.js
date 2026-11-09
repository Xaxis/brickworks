// The beta's bar (betahome, 2026-11-09): on every page of the site while
// the beta is open, a slim bar at the foot of the window: Open beta (the
// beta's page, /beta), Report a bug, and Join, or "You’re a tester" once
// you are; hidden for a day by its ×, and remembered. The owner: "make
// sure you perfectly build the elegant ui/ux for reporting bugs and signup
// for beta testing".
//
// At the foot, floating, not a strip over the header: a strip that comes
// once the server has answered pushes the whole page down under the
// reader's eyes (a layout shift of 0.04 against the site's 0.02,
// docs/DESIGN_SYSTEM.md "Steady loads"), and a bar that floats moves
// nothing. Where Vercel keeps its preview toolbar and Sentry its Report a
// Bug, out of the page's way, one press from anywhere.
//
// web/theme.js asks for this file on every page (so the server's pages,
// /m/, /u/, /c/, have it too), never on an embed's card or the connector's
// consent page, and not at all for ten minutes after the beta was found
// off. It is also the beta's one source for the landing page (web/landing.js)
// and the beta's page (web/beta.js), which import what they need of it:
//
//   betaState()      what the server says, kept here ten minutes:
//                    {beta: "open" | "off" | "unknown", tester (null signed
//                    out), state, cap, left, joined_at}; GET
//                    /api/plans?op=beta signed in, ?op=beta_spots (cached by
//                    the CDN) signed out
//   joinBeta(via)    Join: signed out, sign in first (a new account's
//                    welcome asks there, and its answer stands); then POST
//                    ?op=beta_join {via}. Says so on window ("brickworks:beta",
//                    the server's answer as its detail) for every part of the
//                    page that shows it, as the welcome and Settings do
//   reportBug(from)  Report a bug: web/bugreport.js's dialog in place
//                    (window.brickworksReportBug), loaded on the first press;
//                    without it, Send feedback's dialog as a bug
//
// Every word goes on the page as text.
import { askToSignIn, call, email, signedIn } from "/account.js";
import { iconHtml, langAt, say, told } from "/card.js";

const KEY = "brickworks.beta";
const HIDDEN = "brickworks.betabar.hidden";
const FRESH = 10 * 60 * 1000;
const DAY = 24 * 60 * 60 * 1000;
const root = document.documentElement;

function read(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // A browser that keeps nothing asks again on the next page.
  }
}

/// Who the kept answer is for: the address signed in here, or "" signed out.
const whoNow = () => (signedIn() ? email() || "signed in" : "");

/// An answer of the server's as kept here. The API answers in two shapes
/// (betajoin's tester and spots, and before it the application's status and
/// pool), read alike.
function poolOf(body) {
  const spots = body?.spots;
  if (spots && typeof spots === "object") return spots;
  if (typeof spots === "number") return { left: spots, cap: body.cap ?? body.pool?.cap };
  if (body?.pool && typeof body.pool === "object") return body.pool;
  if (typeof body?.left === "number") return { left: body.left, cap: body.cap };
  return null;
}

function heardOf(body, who) {
  const pool = poolOf(body);
  const inside = Boolean(who) && body?.signed_in !== false;
  const tester = !inside ? null : typeof body?.tester === "boolean" ? body.tester : body?.application?.status === "approved";
  return {
    beta: body?.beta === "open" ? "open" : "off",
    tester,
    state: inside && typeof body?.state === "string" ? body.state : null,
    cap: Number(pool?.cap) || 100,
    left: typeof pool?.left === "number" ? pool.left : null,
    joined_at: body?.joined_at || null,
    who,
    at: Date.now(),
  };
}

/// What was kept for whoever is here now, while it is fresh.
function kept() {
  const was = read(KEY);
  if (!was || was.who !== whoNow() || Date.now() - Number(was.at || 0) > FRESH) return null;
  return was;
}

/// Kept for the next page, whose first frame web/theme.js draws from it.
/// Off, what was held for an open beta on this one goes.
function keep(heard) {
  write(KEY, heard);
  if (heard.beta !== "open") delete root.dataset.beta;
}

let asking = null;

async function ask() {
  const who = whoNow();
  let body = null;
  try {
    if (who) {
      const reply = await call("/api/plans?op=beta");
      body = reply.status === 200 ? reply.body : null;
    } else {
      const reply = await fetch("/api/plans?op=beta_spots", { headers: { accept: "application/json" } });
      body = reply.ok ? await reply.json().catch(() => null) : null;
    }
  } catch {
    body = null;
  }
  // Not heard: nothing is drawn and nothing kept, so the next page asks.
  if (!body || !["open", "off"].includes(body.beta)) return { beta: "unknown", tester: null, cap: 100, left: null, who };
  const heard = heardOf(body, who);
  keep(heard);
  return heard;
}

/// The beta as the server last said it, asked again after ten minutes,
/// or now with [fresh]. One question at a time, however many ask.
export function betaState({ fresh = false } = {}) {
  const was = fresh ? null : kept();
  if (was) return Promise.resolve(was);
  if (!asking) asking = ask().finally(() => { asking = null; });
  return asking;
}

/// Told to every part of the page, and to the other tabs by the kept answer.
function tell(heard) {
  keep(heard);
  dispatchEvent(new CustomEvent("brickworks:beta", { detail: heard }));
}

// Joined or left elsewhere on the page (a new account's welcome, Settings):
// the server's answer, its detail, kept before any part of the page draws
// from it (this listener is the page's first: every part imports this
// file); told with none, asked again. This file's own (tell) are kept.
addEventListener("brickworks:beta", (event) => {
  const detail = event.detail;
  if (detail?.who !== undefined) return;
  if (!["open", "off"].includes(detail?.beta)) {
    write(KEY, null);
    betaState({ fresh: true });
    return;
  }
  const was = read(KEY);
  const now = heardOf(detail, whoNow());
  // An answer without the spots (a leave's) keeps the last count.
  if (now.left === null && typeof was?.left === "number") Object.assign(now, { cap: was.cap, left: was.left });
  keep(now);
});

/// Join: the account is a tester at once (POST ?op=beta_join, betajoin).
/// [via]: where it was pressed (api/_beta.js VIA: "bar", "home", "hub").
/// Signed out, signing in comes first, and a new account's welcome asks
/// there: whatever it was told stands, Not now as much as Join, so a
/// person is never joined past their own answer (one more press joins).
/// Resolves to the beta as it now is, or null when the person closed the
/// sign-in. Throws an Error whose message says why, in the page's language.
export async function joinBeta(via = "bar") {
  if (!signedIn()) {
    let answered = false;
    const heard = () => { answered = true; };
    addEventListener("brickworks:beta", heard);
    const yes = await askToSignIn("Sign in to join the Brickworks beta.").finally(() => removeEventListener("brickworks:beta", heard));
    if (!yes) return null;
    const now = await betaState({ fresh: true });
    if (answered || now.tester || now.beta !== "open" || ["not_now", "left"].includes(now.state)) return now;
  }
  const asked = { method: "POST", body: { via } };
  let reply = await call("/api/plans?op=beta_join", asked);
  if (reply.status === 401 && (await askToSignIn("Sign in again to join the beta."))) {
    reply = await call("/api/plans?op=beta_join", asked);
  }
  if (reply.status !== 200) throw new Error(told(reply.body?.error, say("That did not go just now. Try again in a minute.")));
  const heard = heardOf({ beta: "open", tester: true, ...reply.body }, whoNow());
  tell(heard);
  return heard;
}

/// Report a bug, in a dialog over the page: web/bugreport.js's
/// (window.brickworksReportBug, bugreport), asked for on the first press,
/// which signs in first if need be and pictures the page; [from], where it
/// was pressed ("bar", "home", "hub"), goes with the report. Without it,
/// Send feedback's own dialog, as a bug (web/feedback.js).
export async function reportBug(from = "bar") {
  if (typeof globalThis.brickworksReportBug !== "function") await import("/bugreport.js").catch(() => null);
  if (typeof globalThis.brickworksReportBug === "function") return globalThis.brickworksReportBug({ source: "site", from });
  try {
    const { openFeedback } = await import("/feedback.js");
    return openFeedback({ kind: "bug" });
  } catch {
    location.href = `${langAt()}/feedback`;
    return null;
  }
}

// -- the bar --------------------------------------------------------------

const hiddenNow = () => Number(read(HIDDEN) || 0) > Date.now();

function made(tag, props = {}, ...children) {
  const one = Object.assign(document.createElement(tag), props);
  one.append(...children);
  return one;
}

/// The bar's third part: Join, or that you are a tester (to the beta's page).
function third(heard) {
  if (heard.tester) {
    const link = made("a", { className: "tester", href: `${langAt()}/beta` });
    link.innerHTML = iconHtml("check");
    link.append(say("You’re a tester"));
    return link;
  }
  const join = made("button", { type: "button", className: "cta small", textContent: say("Join") });
  join.setAttribute("aria-label", say("Join the beta"));
  join.dataset.betaJoin = "";
  join.addEventListener("click", async () => {
    join.disabled = true;
    try {
      const now = await joinBeta("bar");
      if (now?.tester) {
        const { toast } = await import("/kit.js");
        toast(say("You’re a tester. Thank you!"));
      }
    } catch (trouble) {
      const { toast } = await import("/kit.js");
      toast(trouble.message);
    } finally {
      join.disabled = false;
    }
  });
  return join;
}

function drawBar(heard) {
  let bar = document.getElementById("beta-bar");
  if (heard.beta !== "open" || hiddenNow()) {
    bar?.remove();
    delete root.dataset.betabar;
    return;
  }
  if (!bar) {
    bar = made("aside", { className: "beta-bar", id: "beta-bar" });
    bar.setAttribute("aria-label", say("The Brickworks beta"));
    // Not in the picture a report takes of the page (web/bugreport.js).
    bar.dataset.picture = "leave";
    // "Open beta", and on a phone "Beta" (site.css).
    const badge = made("a", { className: "badge accent", href: `${langAt()}/beta` });
    badge.append(made("span", { className: "long", textContent: say("Open beta") }), made("span", { className: "short", textContent: say("Beta") }));
    const report = made("button", { type: "button", className: "cta ghost small", textContent: say("Report a bug") });
    report.dataset.betaReport = "";
    report.addEventListener("click", () => reportBug("bar"));
    const hide = made("button", { type: "button", className: "icon-btn small" });
    hide.innerHTML = iconHtml("close");
    hide.setAttribute("aria-label", say("Hide the beta bar for a day"));
    hide.dataset.betaHide = "";
    hide.addEventListener("click", () => {
      write(HIDDEN, Date.now() + DAY);
      // Its × gone with it, the keyboard carries on from the page.
      const main = document.getElementById("main");
      if (main) {
        main.tabIndex = -1;
        main.focus({ preventScroll: true });
      }
      drawBar(heard);
    });
    bar.append(badge, report, made("span", { className: "third" }), hide);
    document.body.append(bar);
    root.dataset.betabar = "shown";
    // In the frame after: it rises and fades in (site.css), moving nothing.
    requestAnimationFrame(() => requestAnimationFrame(() => bar.classList.add("shown")));
  }
  bar.querySelector(".third").replaceChildren(third(heard));
  fit(bar);
}

/// Too narrow for all of it (a small phone, a long language), its label goes
/// and Report a bug, Join and its × stay, whole.
function fit(bar) {
  bar.classList.remove("tight");
  if (bar.scrollWidth > bar.clientWidth + 1) bar.classList.add("tight");
}

async function start() {
  // A page that is not the site's own to browse (its embed's card) has none.
  if (root.hasAttribute("data-embed")) return;
  drawBar(await betaState());
  addEventListener("brickworks:beta", () => betaState().then(drawBar));
  addEventListener("brickworks:signed-in", () => betaState({ fresh: true }).then(drawBar));
  addEventListener("resize", () => {
    const bar = document.getElementById("beta-bar");
    if (bar) fit(bar);
  }, { passive: true });
  // Another tab joined, signed in or out, or hid the bar.
  addEventListener("storage", (event) => {
    if (event.key === KEY || event.key === HIDDEN) betaState().then(drawBar);
  });
}

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
else start();
