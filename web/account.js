// Signing in on the site's own pages (the directory, 2026-10-13): the
// gallery's model pages, profiles and lists, and /profile.
//
// There is one sign-in, the app's: a code emailed by /api/otp and redeemed
// with Supabase directly, the session kept in this browser where the app
// keeps it (src/account/account.gd), so signing in here signs the app in
// and the other way round — as the sign-in page Claude sends people to
// does (web/authorize.js). Renewing a session replaces its refresh token,
// so the renewed one is put back for the app to find; and an access token
// is kept for this tab until it runs out, so a page renews once, not on
// every click.
//
// Or with orangecheck (2026-10-23): its own sign-in window, whose token
// /api/orangecheck exchanges for the same kind of session, kept the same
// way. A Bitcoin wallet, email, Google or GitHub, at orangecheck; Brickworks
// gets an id, never the address. Since 2026-10-24 the button is ours made
// orangecheck's by its own code (web/oc-button.mjs and web/oc-button.css,
// served from here): its mark, its busy state, its window opened from the
// click.
//
// Or with Google or GitHub (signin3, 2026-11-24): a link to /auth/google or
// /auth/github, which go there and back (api/_ways.js) and land on /profile,
// which takes the session the server left for it (takeWay), with the
// verifier this browser made for it as the link was drawn (wayLink), and
// goes on to the page the person was on. The same account as their code's, for the
// same address. And every sign-in also makes the person's orangecheck
// account, once, on the server (api/_oc.js ensureOrangecheck), which the
// dialog says in one line with a link, where Connect is set up: there is no
// box to tick (orangecheck Connect's box, until signin3).
//
// Nothing here is shown as markup: the pages that import it put every
// word on the page as text.
//
// After a first sign-in, one question (2026-10-18, supabase/trust.sql), as
// the app asks it: the month and year the person was born, with nothing
// before the answer to say which answer opens what. Brickworks accounts
// are for 13 and over (2026-11-03). 13 or over, the server keeps only that
// (api/account.js), and First steps follow (web/first-steps.js,
// docs/SOCIAL.md U10): a profile, what they build, and designers and
// models to start with, every one skippable. Under 13, the server deletes
// the account just made, with its address, and the dialog says to ask a
// parent or guardian to sign in with their own email and build with them;
// this browser keeps that it was told (REFUSED, nothing about the person),
// so the sign-in says so at once from then on, and a new account signed in
// here is not asked again but deleted the same way. An account that
// answered 13 or over, a parent's, signs in here as anywhere. The
// orangecheck account is made only once the answer is in: never for a child.
//
// Every word of these dialogs, and every error a person reads in them, the
// server's too, is said in the visitor's language (2026-11-01): on a page
// with a copy in it (/de/gallery) by the copy's own words, and on one with
// none (/profile, where the header's Sign in and the app's orangecheck send
// people, a model's page) by that language's table, /de/words.json, read
// before a dialog is drawn (tools/site_lang.py writes both, and refuses a
// word here said other than through say).

import { CODE_DIGITS, codeBoxes } from "/code-boxes.js";

const KEY = "brickworks.session";
const ACCESS = "brickworks.access";
// That this browser was told accounts are for 13 and over: "1", nothing
// else, as the app keeps it (src/account/account.gd REFUSED_KEY).
const REFUSED = "brickworks.age_refused";
let project = null;

// The visitor's language's words, on a page that has none of its own in it.
let told = null;

/// The language the dialogs speak: the page's, or on a page still in
/// English, the one the visitor chose or their browser asks for (web/theme.js).
function language() {
  const lang = globalThis.brickworksLang;
  if (!lang) return "en";
  return lang.code !== "en" ? lang.code : lang.chosen();
}

/// The language's words fetched, where the page does not carry them: once.
export async function learn() {
  const code = language();
  if (told || code === "en" || globalThis.brickworksLang?.code === code) return;
  told = await fetch(`/${code}/words.json`, { signal: AbortSignal.timeout(5000) })
    .then((reply) => (reply.ok ? reply.json() : {})).catch(() => ({}));
}

/// [english] in the visitor's language, each {name} filled from [values].
export function say(english, values = {}) {
  const said = told?.[english] ?? globalThis.brickworksLang?.say(english) ?? english;
  return said.replace(/\{(\w+)\}/g, (all, name) => (name in values ? String(values[name]) : all));
}

/// [dialog] marked as in the language it speaks where the page is not.
export function speaking(dialog) {
  if (told) dialog.lang = language();
}

async function json(reply) {
  try {
    return await reply.json();
  } catch {
    return {};
  }
}

/// Where codes are redeemed: the Supabase project and its publishable key,
/// as /api/account says.
async function where() {
  if (project) return project;
  const said = await json(await fetch("/api/account"));
  if (!said.enabled || !said.url || !said.key) throw new Error(say("Brickworks cannot sign anyone in just now."));
  project = { url: said.url, key: said.key, orangecheck: said.orangecheck || { ready: false, everyone: false },
    ways: said.ways || { google: false, github: false } };
  return project;
}

function kept() {
  try {
    return JSON.parse(localStorage.getItem(KEY) || "null");
  } catch {
    return null;
  }
}

function keep(body, email) {
  try {
    localStorage.setItem(KEY, JSON.stringify({
      refresh_token: body.refresh_token,
      email: body.user?.email || email || "",
      user_id: body.user?.id || "",
      url: project.url,
      key: project.key,
    }));
  } catch {
    // A browser that keeps nothing is signed in for this page only.
  }
  keepAccess(body, email);
}

/// This tab's access token, from a sign-in or a renewal.
function keepAccess(body, email) {
  try {
    sessionStorage.setItem(ACCESS, JSON.stringify({
      token: body.access_token, until: Date.now() + (Number(body.expires_in) || 3600) * 1000 - 60000,
      email: body.user?.email || email || "",
    }));
  } catch {
    // Asked again at the next call.
  }
}

/// Whether this browser was told accounts are for 13 and over.
export function refusedHere() {
  try {
    return localStorage.getItem(REFUSED) === "1";
  } catch {
    return false;
  }
}

/// Whether this browser has a sign-in to use, without asking anybody.
export function signedIn() {
  const was = kept();
  return Boolean(was && was.refresh_token);
}

/// The address it is for, as kept.
export function email() {
  return (kept() || {}).email || "";
}

/// The account it is for, by its id (its address where none was kept).
export function accountId() {
  const was = kept() || {};
  return was.user_id || was.email || "";
}

/// This browser's notifications (web/push.js) stop with the sign-in, from
/// any Sign out (the header's, Settings', a sign-in found ended): the
/// server is told to forget the device by its endpoint and its secret,
/// which only this browser knows, so no sign-in is needed and a page that
/// is left at once still sends it; and the browser's subscription ends
/// (web/push.js ends it on the next page, if not here).
function forgetDevice() {
  let device = null;
  try {
    device = JSON.parse(localStorage.getItem("brickworks.push") || "null");
  } catch {
    device = null;
  }
  if (device && typeof device === "object" && device.endpoint && device.auth) {
    fetch("/api/people?op=push", { method: "POST", keepalive: true, headers: { "content-type": "application/json" },
      body: JSON.stringify({ on: false, endpoint: device.endpoint, auth: device.auth }) }).catch(() => null);
  }
  navigator.serviceWorker?.getRegistration("/")
    .then((registration) => registration?.pushManager?.getSubscription())
    .then((subscription) => subscription?.unsubscribe())
    .catch(() => null);
}

// The sign-in dialog open in this tab, if one is: ended as signed in when
// another tab signs in (below). False when it has ended already.
let signedInElsewhere = () => false;
// Fields somebody typed in on this page (not in a dialog): a sign-out in
// another tab does not load the page again over their words.
const typedIn = new WeakSet();
addEventListener("input", (event) => {
  if (event.isTrusted && event.target instanceof Element && !event.target.closest("dialog")) typedIn.add(event.target);
}, true);
const typedHere = () => [...document.querySelectorAll("input, textarea")]
  .some((one) => typedIn.has(one) && one.value.trim() && one.value !== one.defaultValue);
// Who a kept sign-in is (its account), or "" for none: [was] as kept, or
// its text.
const whoOf = (was) => (was && was.refresh_token ? String(was.user_id || was.email || "someone") : "");
const whoIn = (text) => {
  try {
    return whoOf(JSON.parse(text || "null"));
  } catch {
    return "";
  }
};

// Signed in or out in another tab of this browser (sifix, 2026-11-15: a tab
// kept its avatar after another signed out). The sign-in is kept in
// localStorage, so every other tab hears it change and follows at once.
// Signed in there: this tab is told as if it signed in here (the header's
// avatar, brickworks:signed-in; the page drawn for them,
// brickworks:signed-in-done), and a sign-in dialog open here closes,
// signed in. Signed out there, or in as somebody else: this tab's own
// access forgotten, brickworks:signed-out (the header back to Sign in,
// web/follow.js), and the page, drawn for whoever was signed in, loaded
// again, unless it holds words typed and not sent, or a page took the
// event (preventDefault) to draw itself again. A renewal (the same person, a
// new token) changes nothing.
addEventListener("storage", (event) => {
  if (event.key !== KEY || event.storageArea !== localStorage) return;
  const [was, now] = [whoIn(event.oldValue), whoIn(event.newValue)];
  if (was === now) return;
  if (was) {
    try {
      sessionStorage.removeItem(ACCESS);
    } catch {
      // Nothing kept here.
    }
    const out = new Event("brickworks:signed-out", { cancelable: true });
    dispatchEvent(out);
    if (!out.defaultPrevented && !typedHere()) {
      location.reload();
      return;
    }
  }
  if (now) {
    dispatchEvent(new Event("brickworks:signed-in"));
    if (!signedInElsewhere()) dispatchEvent(new Event("brickworks:signed-in-done"));
  }
});

// The renewal under way, which every script on the page that asks shares.
let renewing = null;

/// An access token for the kept sign-in: this tab's while it lasts,
/// renewed when not, once however many of the page's scripts ask at once
/// (the header, the theme and the page's own). Supabase renews only so
/// many sessions from one address (150 in five minutes, 30 at once), and
/// a page asked for three or four renewals at every load. Null when there
/// is no sign-in or it has ended.
export async function token() {
  try {
    const held = JSON.parse(sessionStorage.getItem(ACCESS) || "null");
    if (held && held.token && held.until > Date.now() && held.email === email()) return held.token;
  } catch {
    // Asked again below.
  }
  const was = kept();
  if (!was || !was.refresh_token) return null;
  renewing ||= renew(was).finally(() => {
    renewing = null;
  });
  return renewing;
}

/// The kept sign-in renewed. Refused for the rate (429) or a moment's
/// trouble (5xx), it is asked again after a wait, twice: that is not the
/// sign-in ending, and the page is not to be drawn signed out for it.
async function renew(was) {
  await where();
  for (const wait of [1500, 3000, 0]) {
    const reply = await fetch(`${project.url}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { apikey: project.key, "content-type": "application/json" },
      body: JSON.stringify({ refresh_token: was.refresh_token }),
    });
    const body = await json(reply);
    if (reply.ok && body.access_token) {
      // Kept only while the sign-in it renewed is still this browser's
      // (m305fix: a tab's renewal, asked when another tab signed in, was
      // answered after that tab signed out, and written back over the
      // sign-out, signing every tab in again). Signed out meanwhile, or
      // in as somebody else: nothing kept, no token. Renewed meanwhile by
      // another tab: theirs kept, this tab's token its own.
      const now = kept();
      if (!whoOf(now) || whoOf(now) !== whoOf(was)) return null;
      if (now.refresh_token === was.refresh_token) keep(body, was.email);
      else keepAccess(body, was.email);
      return body.access_token;
    }
    if (!wait || (reply.status !== 429 && reply.status < 500)) return null;
    await new Promise((done) => setTimeout(done, wait));
  }
  return null;
}

// How many digits the last code sent has, as the deployment said
// (api/otp.js `digits`), for the boxes it is typed into.
let digits = CODE_DIGITS;

/// How many digits the code just sent has.
export function codeLength() {
  return digits;
}

/// Send a code to [address]. Says why not, in words, when it cannot.
export async function sendCode(address) {
  await learn();
  const wanted = String(address || "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(wanted)) throw new Error(say("That is not an email address."));
  await where();
  // How this visit came (web/theme.js), for the owner's sign-up mail.
  const came = globalThis.brickworksCame || null;
  const reply = await fetch("/api/otp", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: wanted, ...(came ? { came } : {}) }),
  });
  if (!reply.ok) {
    const body = await json(reply);
    const until = reply.status === 429 ? clock(body.retry_at) : "";
    if (until) throw new Error(say("Too many codes asked for. Try again after {time}.", { time: until }));
    throw new Error(body.error ? say(body.error) : say("Could not send a code just now ({status}).", { status: reply.status }));
  }
  const length = Number((await json(reply)).digits);
  digits = Number.isInteger(length) && length >= 4 && length <= 12 ? length : CODE_DIGITS;
  return wanted;
}

/// [iso] as the visitor's clock says it ("14:32"), or "" when it is not a
/// time: when an address may be sent a code again (api/otp.js retry_at).
export function clock(iso) {
  const at = new Date(String(iso || ""));
  if (!iso || Number.isNaN(at.getTime())) return "";
  return at.toLocaleTimeString(language() === "en" ? undefined : language(), { hour: "2-digit", minute: "2-digit" });
}

/// Sign in with the code sent to [address]; the session kept for the app too.
export async function redeem(address, code) {
  await learn();
  await where();
  const reply = await fetch(`${project.url}/auth/v1/verify`, {
    method: "POST",
    headers: { apikey: project.key, "content-type": "application/json" },
    // "email", even for a code minted as a magic link (see account.gd).
    body: JSON.stringify({ type: "email", email: address, token: String(code || "").replace(/[\s-]/g, "") }),
  });
  const body = await json(reply);
  if (!reply.ok || !body.access_token) {
    // Supabase's own words are its developers': each said here in ours.
    // A wrong or spent code says so ([wrong]), for the boxes to empty.
    if (body.error_code === "otp_expired" || body.error_code === "invalid_credentials") {
      throw Object.assign(new Error(say("That code is wrong or has expired. Check it, or ask for a new one.")), { wrong: true });
    }
    if (reply.status === 429) throw new Error(say("Too many tries just now. Wait a few minutes and try again."));
    throw new Error(say("Could not sign in just now ({status}). Try again.", { status: reply.status }));
  }
  keep(body, address);
  // Signed in: what follows a person from browser to browser (their theme,
  // web/theme.js) is fetched for this page.
  dispatchEvent(new Event("brickworks:signed-in"));
  return body.access_token;
}

/// Sign a review account in with its password (web/review.html), kept as a
/// code's sign-in is: an app directory's reviewer, at a Resend test address,
/// where no code can be read (api/_auth.js isTestAccount). Supabase's
/// status, and the page says why in its own words.
export async function signInWithPassword(address, password) {
  await where();
  const reply = await fetch(`${project.url}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: project.key, "content-type": "application/json" },
    body: JSON.stringify({ email: address, password }),
  });
  const body = await json(reply);
  if (!reply.ok || !body.access_token) return { ok: false, status: reply.status };
  keep(body, address);
  dispatchEvent(new Event("brickworks:signed-in"));
  return { ok: true, status: reply.status };
}

// orangecheck's button code and its stylesheet, fetched once a page offers
// it, so that the button is drawn as it will be and its click opens the
// window at once: a window opened long after the click is blocked.
let buttonCode = null;
function orangecheckCode() {
  buttonCode ||= Promise.all([import("/oc-button.mjs"), new Promise((done, failed) => {
    if (document.querySelector('link[href="/oc-button.css"]')) return done();
    const sheet = document.createElement("link");
    sheet.rel = "stylesheet";
    sheet.href = "/oc-button.css";
    sheet.onload = () => done();
    sheet.onerror = () => failed(new Error("no stylesheet"));
    document.head.append(sheet);
  })]).then(([code]) => code).catch((trouble) => {
    buttonCode = null;
    throw trouble;
  });
  return buttonCode;
}

/// Whether Sign in with orangecheck is offered on this page: to everybody,
/// as the deployment says (api/_oc_config.js, the one switch). {offered,
/// ready, connect}: ready false is a deployment without the signing secret,
/// where the button says so rather than open orangecheck's window; connect,
/// whether signing in makes the person an orangecheck account here
/// (orangecheck Connect's key is here), which the sign-in then says.
export async function orangecheckOffer() {
  const said = (await where()).orangecheck;
  return { offered: said.everyone === true, ready: said.ready === true, connect: said.connect === true };
}

/// Which of Google and GitHub sign people in here (api/_ways.js): {google,
/// github}.
export async function waysOffer() {
  const said = (await where()).ways;
  return { google: said.google === true, github: said.github === true };
}

/// Google and GitHub by their names, as their buttons say them.
export const WAY_NAMES = { google: "Google", github: "GitHub" };

// The verifiers this browser made for the sessions Google and GitHub hand
// back (api/_ways.js wayTake), by their S256 challenge, for 15 minutes:
// made as a Sign in with Google or GitHub is drawn, its challenge sent with
// it, and taken by /profile as the sign-in lands. The session the callback
// leaves in a cookie opens only with its verifier, and only once
// (signinreview F1, F4). In localStorage, so a sign-in finished in another
// tab or window than the one it was started from finds it too.
const TAKES = "bw_way_takes";
const TAKE_MS = 900_000;

function takesKept() {
  try {
    const all = JSON.parse(localStorage.getItem(TAKES) || "{}");
    return Object.fromEntries(Object.entries(all && typeof all === "object" ? all : {})
      .filter(([, one]) => typeof one?.v === "string" && Date.now() - Number(one.t) < TAKE_MS));
  } catch {
    return {};
  }
}

function takesKeep(all) {
  try {
    localStorage.setItem(TAKES, JSON.stringify(all));
  } catch {
    // Storage refused: the take then finds no verifier, and says to sign in again.
  }
}

const base64url = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

/// A verifier made and kept, and its S256 challenge.
async function takeChallenge() {
  const verifier = base64url(crypto.getRandomValues(new Uint8Array(32)));
  const challenge = base64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
  takesKeep({ ...takesKept(), [challenge]: { v: verifier, t: Date.now() } });
  return challenge;
}

/// Where Sign in with Google or GitHub goes: there, and back to [then] (this
/// page, by default) signed in, through /profile, with the challenge of a
/// verifier this browser keeps for it.
export async function wayLink(name, then = location.pathname + location.search + location.hash) {
  return `/auth/${name}?${new URLSearchParams({ then, take: await takeChallenge() })}`;
}

/// [link] given its address (wayLink) as soon as it is made: a press before
/// then goes there once it is.
export function wayLinkTo(link, address) {
  const ready = address.then((href) => {
    link.href = href;
    return href;
  });
  link.addEventListener("click", (event) => {
    if (link.getAttribute("href")) return;
    event.preventDefault();
    ready.then((href) => location.assign(href));
  });
}

/// The session a sign-in with Google or GitHub left this browser
/// (api/_ways.js wayBack), taken once with the verifier whose [challenge]
/// it came back with, and kept, for the app too: {ok} or {error} in the
/// visitor's words.
export async function takeWay(challenge) {
  await where();
  const all = takesKept();
  const verifier = all[challenge]?.v || "";
  delete all[challenge];
  takesKeep(all);
  const reply = await fetch("/api/otp?op=way_take", { method: "POST", credentials: "same-origin",
    headers: { "content-type": "application/json" }, body: JSON.stringify({ code_verifier: verifier }) }).catch(() => null);
  const body = reply ? await json(reply) : {};
  if (!reply || !reply.ok || !body.access_token) {
    return { error: body.error ? say(body.error) : say("Could not sign in just now ({status}). Try again.", { status: reply?.status || 0 }) };
  }
  keep(body, body.user?.email);
  dispatchEvent(new Event("brickworks:signed-in"));
  return { ok: true };
}

/// GitHub's id, which met this account before it had signed in to it, kept
/// for it now that the person is signed in with a code (api/_ways.js
/// wayBind): {ok}, {fresh: false} while the code is still to be typed, or
/// {error} in the visitor's words.
export async function bindWay() {
  const done = await call("/api/otp?op=way_bind", { method: "POST" }).catch(() => null);
  if (done?.status === 200) return { ok: true };
  if (done?.status === 403 && done.body?.fresh === false) return { fresh: false };
  return { error: done?.body?.error ? say(done.body.error) : say("That did not work just now.") };
}

/// This page, to come back to after Google or GitHub: its address without
/// the ?sign-in that opened the dialog (/profile?sign-in).
function hereThen() {
  const here = new URL(location.href);
  here.searchParams.delete("sign-in");
  return here.pathname + here.search + here.hash;
}

const SVG = "http://www.w3.org/2000/svg";
// Each provider's own mark, as its sign-in buttons show it: Google's G in
// its four colours, GitHub's in the button's ink.
const MARKS = {
  google: [["#4285F4", "M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.4h6.5a5.6 5.6 0 0 1-2.4 3.6v3h3.9c2.2-2.1 3.5-5.1 3.5-8.7z"],
    ["#34A853", "M12 24c3.2 0 6-1.1 7.9-2.9l-3.9-3c-1.1.7-2.4 1.2-4 1.2-3.1 0-5.7-2.1-6.7-4.9H1.3v3.1A12 12 0 0 0 12 24z"],
    ["#FBBC05", "M5.3 14.4a7.2 7.2 0 0 1 0-4.7V6.6h-4a12 12 0 0 0 0 10.9l4-3.1z"],
    ["#EA4335", "M12 4.8c1.8 0 3.3.6 4.6 1.8l3.4-3.4A11.5 11.5 0 0 0 12 0 12 12 0 0 0 1.3 6.6l4 3.1c.9-2.8 3.6-4.9 6.7-4.9z"]],
  github: [["currentColor", "M12 .3a12 12 0 0 0-3.8 23.4c.6.1.8-.3.8-.6v-2.2c-3.3.7-4-1.6-4-1.6-.6-1.4-1.4-1.8-1.4-1.8-1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.7-1.6-2.7-.3-5.5-1.3-5.5-6 0-1.2.5-2.3 1.3-3.1-.2-.4-.6-1.6.1-3.2 0 0 1-.3 3.3 1.2a11.5 11.5 0 0 1 6 0c2.3-1.5 3.3-1.2 3.3-1.2.6 1.6.2 2.8.1 3.2.8.8 1.3 1.9 1.3 3.2 0 4.6-2.8 5.6-5.5 5.9.5.4.9 1.1.9 2.2v3.3c0 .3.2.7.8.6A12 12 0 0 0 12 .3"]],
};

/// [name]'s mark, 18 px, beside its button's words.
export function wayMark(name) {
  const mark = document.createElementNS(SVG, "svg");
  mark.setAttribute("viewBox", "0 0 24 24");
  mark.setAttribute("width", "18");
  mark.setAttribute("height", "18");
  mark.setAttribute("aria-hidden", "true");
  mark.setAttribute("class", "way-mark");
  for (const [fill, d] of MARKS[name] || []) {
    const path = document.createElementNS(SVG, "path");
    path.setAttribute("fill", fill);
    path.setAttribute("d", d);
    mark.append(path);
  }
  return mark;
}

/// Why a sign-in with Google or GitHub ([name]) came back refused, in the
/// visitor's words ([why], api/_ways.js failed).
export function wayFailed(why, name) {
  const way = WAY_NAMES[name] || name;
  if (why === "again") return say("That sign-in took too long, or was started in another tab. Try again.");
  if (why === "denied") return say("Signing in with {way} was cancelled there.", { way });
  if (why === "unverified") return say("{way} gave no verified email address of yours. Sign in with a code we email you instead.", { way });
  if (why === "vouch") return say("Google vouches only for Gmail and Google Workspace addresses. Sign in with a code we email you instead.");
  if (why === "confirm") {
    return say("This address has a Brickworks account already. Sign in with a code we email you this once, and {way} signs you in from then on.", { way });
  }
  if (why === "unlinked") {
    return say("{way} is unlinked from your account. Sign in with a code we email you, then link it again in Settings.", { way });
  }
  if (why === "off") return say("Signing in with {way} is not offered here just now. Sign in with a code we email you.", { way });
  if (why === "busy") return say("A lot of people are signing in just now. Try again in a minute.");
  return say("{way} did not sign you in just now. Try again in a minute, or sign in with a code we email you.", { way });
}

/// Whether an address is an orangecheck account's, made up by the server
/// (api/orangecheck.js): nobody's inbox, never to be shown as theirs.
export function madeUp(address) {
  return /@oc\.brickworks\.diy$/i.test(String(address || ""));
}

/// [button], one of the site's own (it keeps its classes), made
/// orangecheck's: its mark in the button's ink, [label], which says
/// orangecheck, its busy state while the window is open, and the window
/// opened from the click (orangecheck's enhanceSignInButton). [before], on
/// each click before anything opens: false and nothing opens (somewhere it
/// is unavailable, or a code is to be asked for first). [onToken], with the
/// token the window hands back, for this site only and never kept: it goes
/// straight to the server. [say], with orangecheck's words for a window
/// blocked, closed or not answering (OUTCOME_COPY). Resolves once the
/// button is ready to be shown; says why not, in words, when its code
/// cannot be loaded, and then each click says so too. Its busy state and
/// orangecheck's words in the visitor's language.
///
/// The sign-in dialog follows the window too (signinux, 2026-11-13):
/// [onOpen] once it is open, and [onOutcome] with how it ended ("signed_in",
/// "closed", "blocked", "failed" or "aborted") before anything is said. It
/// resolves with {cancel, show}: cancel closes the window, which then ends
/// "aborted" (orangecheck's own signal option, a new one each click); show
/// brings it to the front, true while it is open. The window is the one
/// orangecheck's code opens from the click: window.open is watched for the
/// length of that one click to keep hold of it.
export async function orangecheckButton(button, { label, before = () => true, onToken, say: tell, onOpen = null,
  onOutcome = null }) {
  let code;
  try {
    code = await orangecheckCode();
  } catch {
    const words = say("The orangecheck sign-in could not be loaded. Check your connection and try again.");
    button.addEventListener("click", () => tell(words));
    throw new Error(words);
  }
  let asked = null;
  let opened = null;
  const popup = {};
  Object.defineProperty(popup, "signal", { enumerable: true, get: () => asked?.signal });
  // Ahead of orangecheck's own click, which opens the window.
  button.addEventListener("click", (event) => {
    if (button.getAttribute("aria-busy") === "true") return;
    if (!before()) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }
    asked = new AbortController();
    opened = null;
    const open = window.open;
    window.open = function watched(...how) {
      opened = open.apply(this, how);
      return opened;
    };
    // orangecheck's click opens the window before it gives the page back.
    setTimeout(() => {
      window.open = open;
      if (opened) onOpen?.();
    }, 0);
  }, { capture: true });
  code.enhanceSignInButton(button, {
    mark: "mono",
    label,
    busyLabel: say(code.SIGN_IN_BUSY_LABEL),
    popup,
    onSignedIn: async ({ token }) => {
      try {
        await onToken(token);
      } catch (trouble) {
        tell(trouble.message);
      }
    },
    onOutcome: (outcome) => {
      onOutcome?.(outcome.status);
      const words = code.OUTCOME_COPY[outcome.status];
      if (outcome.status !== "signed_in" && outcome.status !== "aborted") tell(words ? say(words) : "");
    },
  });
  return {
    cancel: () => asked?.abort(),
    show: () => {
      try {
        if (!opened || opened.closed) return false;
        opened.focus();
        return true;
      } catch {
        return false;
      }
    },
  };
}

/// The token orangecheck's window handed back, exchanged for a session,
/// kept for the app too. Says why not, in words, when it cannot.
export async function exchangeOrangecheck(token) {
  await where();
  const reply = await fetch("/api/orangecheck?op=signin", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ token }),
  });
  const body = await json(reply);
  if (!reply.ok || !body.access_token) {
    throw new Error(body.error ? say(body.error) : say("Could not sign in just now ({status}). Try again.", { status: reply.status }));
  }
  keep(body, body.user?.email);
  dispatchEvent(new Event("brickworks:signed-in"));
}

export function signOut() {
  forgetDevice();
  try {
    localStorage.removeItem(KEY);
    sessionStorage.removeItem(ACCESS);
    // Who the header's avatar was (web/follow.js).
    localStorage.removeItem("brickworks.me");
    // The studio's copy, kept for its other tabs (src/ui/edit_verbs.gd
    // SHARED_COPY): the next account in this browser pasted it, and the
    // parts this one made with it (pastereview F2).
    localStorage.removeItem("brickworks.clipboard");
  } catch {
    // Nothing kept, nothing to forget.
  }
}

// The avatar's count as this page last heard it (web/follow.js
// showFeedCount), for whom: web/notice.js reads the notices the person hid
// from it (notice_hidden), so it asks nothing of its own.
let countHeard = null;
const countWaiting = new Set();

/// What op=feed_count answered on this page ([body], or null when it was
/// not answered), heard by whoever waits on feedCountHeard.
export function tellFeedCount(body) {
  countHeard = { body: body && typeof body === "object" ? body : null, who: email() };
  for (const done of countWaiting) done(countHeard.body);
  countWaiting.clear();
}

/// What op=feed_count answered for the person signed in on this page:
/// at once when it was heard, else when it is, else null after [ms].
export function feedCountHeard(ms) {
  if (countHeard && countHeard.who === email()) return Promise.resolve(countHeard.body);
  return new Promise((resolve) => {
    const done = (body) => {
      clearTimeout(late);
      countWaiting.delete(done);
      resolve(body);
    };
    const late = setTimeout(() => done(null), ms);
    countWaiting.add(done);
  });
}

// The calls on their way: First steps, put off for what a new person
// pressed, are offered once its call is answered (offerFirstSteps).
let calling = 0;

/// A call to the site's own API with the sign-in, as JSON: {status, body}.
/// [keepalive]: sent on even when the page is left before it is answered.
export async function call(path, { method = "GET", body, keepalive = false } = {}) {
  calling += 1;
  try {
    const access = await token();
    const headers = { accept: "application/json" };
    if (access) headers.authorization = `Bearer ${access}`;
    if (body !== undefined) headers["content-type"] = "application/json";
    const reply = await fetch(path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), keepalive });
    return { status: reply.status, body: await json(reply) };
  } finally {
    calling -= 1;
  }
}

/// The two steps of signing in, in a dialog the page opens over itself:
/// an address, then the code sent to it. Resolves true once signed in,
/// false when the person closes it. [why]: what signing in is for here (a
/// like, a comment), which the page does once it resolves, First steps
/// offered after it; with none, it is the page's own Sign in, and First
/// steps come at once and may end at the feed.
///
/// signinux (2026-11-13), as the best sign-ins set out a second way in
/// (Vercel, Linear, Notion, Figma): the email and orangecheck are two equal
/// ways in, buttons of one size, one under the other with "or" between; the code is
/// typed one digit to a box (web/code-boxes.js) and sent by its last digit,
/// a wrong one shaking the row empty; and while orangecheck's window is
/// open the dialog says so, with a way to bring the window back and a way
/// to cancel, and says how it ended if it ended without signing in.
/// [prefer] "orangecheck": the person came for it (the app's Sign in with
/// orangecheck, /profile?with=orangecheck), so its button has the focus.
/// Signed in, the page is told "brickworks:signed-in-done" once the age
/// question and First steps are behind, to draw what it shows somebody
/// signed in where they are (the header's Sign in opens this on any page).
/// [back]: what has the focus once signed in, the moment the dialog goes,
/// where what opened it is no more (the header's Sign in, the avatar by
/// then); without it the dialog gives the focus back to what opened it.
/// [later]: the person is on a page to do what it is for (share a model,
/// read one, ask on a set), so First steps and the beta's welcome wait in
/// a snackbar as they do after a like, and the page is theirs again once
/// the age question is answered (sitewalk2, 2026-11-24: the header's Sign
/// in on Share a model put five dialogs between the code and the share).
/// Under "or" (signin3, 2026-11-24): Sign in with Google and with GitHub
/// where they are offered, links that go there and come back to [then] (this
/// page by default) signed in, then orangecheck; and at the foot, where
/// Connect is set up, one line saying that signing in also makes the
/// person's orangecheck account, with a link to what that is.
export async function askToSignIn(why, { prefer = "", back = null, later = false, then = "" } = {}) {
  await learn();
  return new Promise((done) => {
    const dialog = document.createElement("dialog");
    dialog.className = "sign-in";
    speaking(dialog);
    const title = document.createElement("h2");
    title.textContent = say("Sign in to Brickworks");
    // Named by its title, as a screen reader says it opens.
    title.id = "sign-in-title";
    dialog.setAttribute("aria-labelledby", title.id);
    const said = document.createElement("p");
    said.className = "lead";
    // A page's reason, said by it or here: on a page with no copy, its
    // English is the key to the visitor's language.
    said.textContent = why ? say(why) : say("Sign in with your email address: we send you a code, no password.");
    // Told here before: said at once, for whoever signs in next.
    const refused = refusedHere() ? tooYoung() : [];

    // The email way: the address, then in its place the code sent to it.
    const form = document.createElement("form");
    form.className = "by-email";
    const label = document.createElement("label");
    label.textContent = say("Email");
    const field = document.createElement("input");
    field.type = "email";
    field.autocomplete = "email";
    field.required = true;
    // Never an orangecheck account's made-up address: it takes no code.
    field.value = madeUp(email()) ? "" : email();
    label.append(field);
    const code = document.createElement("div");
    code.className = "code-step";
    const codeSaid = document.createElement("label");
    codeSaid.id = "sign-in-code-label";
    code.append(codeSaid);
    const boxes = codeBoxes({ into: code, id: "sign-in-digit", label: codeSaid, say,
      onFilled: () => form.requestSubmit() });
    codeSaid.htmlFor = "sign-in-digit-1";
    const codeNote = document.createElement("p");
    codeNote.className = "note";
    codeNote.textContent = say("It works once and expires in ten minutes. Not there? Look in spam.");
    code.append(codeNote);
    const go = document.createElement("button");
    go.className = "cta wide";
    go.type = "submit";
    const goWords = document.createElement("span");
    goWords.textContent = say("Email me a code");
    go.append(goWords);
    const note = document.createElement("p");
    note.className = "said";
    note.setAttribute("role", "status");
    // The email way's line: [bad] words (a code refused, a limit, no
    // connection) in the trouble's colour, as orangecheck's line has them.
    const tell = (words, bad = false) => {
      note.textContent = words;
      note.dataset.tone = bad && words ? "bad" : "";
    };
    // At the code: another code, or another address.
    const links = document.createElement("p");
    links.className = "code-links";
    const resend = document.createElement("button");
    resend.type = "button";
    resend.className = "link";
    resend.textContent = say("Send a new code");
    const another = document.createElement("button");
    another.type = "button";
    another.className = "link";
    another.textContent = say("Use a different address");
    links.append(resend, another);
    links.hidden = true;
    form.append(label, go, note, links);

    // Or Google or GitHub, where they are offered: links there and back
    // (wayLink), each with its mark, as tall and as wide as Email me a code.
    const or = document.createElement("p");
    or.className = "or";
    const orWords = document.createElement("span");
    orWords.textContent = say("or");
    or.append(orWords);
    const other = document.createElement("div");
    other.className = "elsewhere";
    const viaWays = {};
    const wayWords = { google: say("Sign in with Google"), github: say("Sign in with GitHub") };
    for (const name of ["google", "github"]) {
      const via = document.createElement("a");
      via.className = "cta ghost wide way";
      via.id = `way-${name}`;
      wayLinkTo(via, wayLink(name, then || hereThen()));
      via.hidden = true;
      via.append(wayMark(name), wayWords[name]);
      viaWays[name] = via;
      other.append(via);
    }
    // Or orangecheck: its own window, so its own button, ours made
    // orangecheck's (orangecheckButton), its mark's place held; as tall
    // and as wide as Email me a code.
    const oc = document.createElement("button");
    oc.className = "cta ghost wide";
    oc.type = "button";
    oc.id = "oc-sign-in";
    oc.setAttribute("data-oc-sign-in", "");
    const mark = document.createElement("span");
    mark.setAttribute("data-oc-mark", "");
    oc.append(mark, say("Sign in with orangecheck"));
    // How its window ended, when not signed in: under the button.
    const ocTold = document.createElement("p");
    ocTold.className = "said oc-said";
    ocTold.setAttribute("role", "status");
    const ocSaid = document.createElement("p");
    ocSaid.className = "note";
    ocSaid.textContent = say("A Bitcoin wallet, email, Google or GitHub. Brickworks gets an id for you, not your address.");
    other.append(oc, ocTold, ocSaid);

    // While orangecheck's window is open: what to do there, the window
    // brought back, or the whole of it cancelled.
    const waiting = document.createElement("div");
    waiting.className = "waiting";
    waiting.hidden = true;
    const spinner = document.createElement("span");
    spinner.className = "spinner";
    spinner.setAttribute("aria-hidden", "true");
    const waitSaid = document.createElement("p");
    waitSaid.className = "waiting-said";
    waitSaid.setAttribute("role", "status");
    const waitNote = document.createElement("p");
    waitNote.className = "note";
    const show = document.createElement("button");
    show.type = "button";
    show.className = "cta ghost wide";
    show.textContent = say("Show the orangecheck window");
    const stop = document.createElement("button");
    stop.type = "button";
    stop.className = "link";
    stop.textContent = say("Cancel");
    const stopRow = document.createElement("p");
    stopRow.className = "code-links";
    stopRow.append(stop);
    waiting.append(spinner, waitSaid, waitNote, show, stopRow);

    // Not now, last: the page as it was.
    const foot = document.createElement("p");
    foot.className = "foot";
    const close = document.createElement("button");
    close.className = "link";
    close.type = "button";
    close.textContent = say("Not now");
    foot.append(close);

    // Every way in but orangecheck's own makes the person's orangecheck
    // account too, where Connect is set up here: said in one line, with
    // what it is, true for whichever is pressed (signinreview F11).
    const madeLine = document.createElement("p");
    madeLine.className = "note made-line";
    madeLine.id = "oc-made-line";
    const madeWhat = document.createElement("a");
    madeWhat.href = "/docs/account#orangecheck";
    madeWhat.target = "_blank";
    madeWhat.rel = "noopener";
    madeWhat.textContent = say("What is that?");
    madeLine.append(say("Signing in without orangecheck also makes your orangecheck account."), " ", madeWhat);
    madeLine.hidden = true;

    // Each drawn once the deployment has said it is offered here, and its
    // code is in.
    or.hidden = true;
    other.hidden = true;
    oc.hidden = true;
    ocSaid.hidden = true;
    let offer = { offered: false, ready: false, connect: false };
    let offered = { google: false, github: false };
    const anyWay = () => offer.offered || offered.google || offered.github;
    let windowed = null;
    // How orangecheck's window last ended, for the line said after it.
    let ended = "";
    let address = "";
    let finished = false;
    let checking = false;

    // orangecheck's line under its button: calm for a window closed or a
    // sign-in cancelled, a callout for one the browser blocked, the
    // trouble's colour for one that failed.
    const ocTell = (words, tone = "bad") => {
      ocTold.textContent = words;
      ocTold.dataset.tone = words ? tone : "";
      ocTold.setAttribute("role", tone === "bad" || tone === "blocked" ? "alert" : "status");
    };
    // The ways in again, as they were before the window opened.
    const ways = (focus = true) => {
      waiting.hidden = true;
      form.hidden = false;
      or.hidden = !anyWay() || Boolean(address);
      other.hidden = !anyWay() || Boolean(address);
      foot.hidden = false;
      madeLine.hidden = !offer.connect;
      if (focus && !other.hidden && !oc.hidden) oc.focus();
    };
    const wait = (words, more, choices = true) => {
      waitSaid.textContent = words;
      waitNote.textContent = more;
      show.hidden = !choices;
      stopRow.hidden = !choices;
      form.hidden = true;
      or.hidden = true;
      other.hidden = true;
      foot.hidden = true;
      madeLine.hidden = true;
      waiting.hidden = false;
      ocTell("");
      tell("");
    };

    Promise.all([orangecheckOffer(), waysOffer()]).then(async ([known, viaOffered]) => {
      offer = known;
      offered = viaOffered;
      for (const name of ["google", "github"]) viaWays[name].hidden = !offered[name];
      madeLine.hidden = !known.connect || !waiting.hidden;
      // Google and GitHub at once; orangecheck's once its code is in.
      if (offered.google || offered.github) {
        or.hidden = Boolean(address);
        other.hidden = Boolean(address);
      }
      const drawn = [];
      if (known.offered) {
        drawn.push(orangecheckButton(oc, {
          label: say("Sign in with orangecheck"),
          before: () => {
            ocTell("");
            if (!offer.ready) {
              ocTell(say("Signing in with orangecheck is unavailable here. Sign in with your email instead."));
              return false;
            }
            return true;
          },
          onOpen: () => {
            if (finished) return;
            wait(say("Finish signing in in the orangecheck window"), say("It opened in a window of its own."));
            show.focus();
          },
          onOutcome: (how) => {
            ended = how;
            if (finished) return;
            if (how === "signed_in") {
              wait(say("Signing you in…"), "", false);
              return;
            }
            ways();
          },
          onToken: async (token) => {
            await exchangeOrangecheck(token);
            finished = true;
            gone();
            const asked = await askAgeIfAsked({ pending: Boolean(why) || later }).catch(() => null);
            settled(!asked?.refused);
          },
          // Said after onOutcome, which names how the window ended.
          say: (words) => {
            if (finished) return;
            ways();
            ocTell(words, ended === "blocked" ? "blocked" : ended === "closed" ? "calm" : "bad");
            ended = "";
          },
        }).then((window_) => {
          windowed = window_;
        }).catch((trouble) => {
          ocTell(trouble.message);
        }).then(() => {
          oc.hidden = false;
          ocSaid.hidden = false;
          or.hidden = Boolean(address);
          other.hidden = Boolean(address);
          if (prefer === "orangecheck" && !address && document.activeElement === field && !other.hidden) oc.focus();
        }));
      }
      await Promise.all(drawn);
    }).catch(() => null);
    dialog.append(title, ...refused, said, form, or, other, waiting, madeLine, foot);
    document.body.append(dialog);

    // Signed in, the page told to draw what somebody signed in sees, once
    // the age question and First steps are behind.
    const settled = (signed) => {
      if (signed) dispatchEvent(new Event("brickworks:signed-in-done"));
      done(signed);
    };
    // Signed in: the dialog gone and the focus on [back] in the same
    // moment, not on the page while the age question is looked up
    // (m305fix: BODY for over 300 ms after the dialog went, at 1280).
    const gone = () => {
      dialog.close();
      dialog.remove();
      back?.()?.focus({ preventScroll: true });
    };
    const end = (result) => {
      if (finished) return;
      finished = true;
      windowed?.cancel();
      dialog.close();
      dialog.remove();
      done(result);
    };
    // Signed in in another tab while this is open: closed, signed in, the
    // page carrying on with what it asked for (a like, a comment).
    signedInElsewhere = () => {
      if (finished || checking || !signedIn()) return false;
      finished = true;
      windowed?.cancel();
      gone();
      settled(true);
      return true;
    };
    close.addEventListener("click", () => end(false));
    dialog.addEventListener("cancel", (event) => {
      // Escape while a code is checked waits for the answer.
      if (checking) {
        event.preventDefault();
        return;
      }
      end(false);
    });
    show.addEventListener("click", () => {
      if (!windowed?.show()) ways();
    });
    stop.addEventListener("click", () => windowed?.cancel());

    // The step: the address, or the code sent to it.
    const toCode = () => {
      codeSaid.textContent = say("The code sent to {address}", { address });
      if (label.isConnected) label.replaceWith(code);
      goWords.textContent = say("Sign in");
      links.hidden = false;
      or.hidden = true;
      other.hidden = true;
      boxes.clear();
    };
    const toAddress = () => {
      address = "";
      if (code.isConnected) code.replaceWith(label);
      goWords.textContent = say("Email me a code");
      links.hidden = true;
      tell("");
      ways(false);
      field.focus();
      field.select();
    };
    another.addEventListener("click", toAddress);
    resend.addEventListener("click", async () => {
      if (checking) return;
      resend.disabled = true;
      tell(say("Sending a new code…"));
      try {
        await sendCode(address);
        boxes.size(codeLength());
        tell(say("Sent a new code. Use the newest one."));
        boxes.clear();
      } catch (trouble) {
        tell(trouble.message, true);
      } finally {
        resend.disabled = false;
      }
    });
    // While a code is checked: the boxes read-only, the button turning.
    // Never disabled, so a press that comes now is let go by, not lost.
    const busy = (on) => {
      checking = on;
      boxes.busy(on);
      if (on) {
        go.setAttribute("aria-busy", "true");
        go.prepend(spinner.cloneNode());
      } else {
        go.removeAttribute("aria-busy");
        go.querySelector(".spinner")?.remove();
      }
    };

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (checking) return;
      tell("");
      if (!address) {
        busy(true);
        try {
          address = await sendCode(field.value);
          boxes.size(codeLength());
          toCode();
        } catch (trouble) {
          tell(trouble.message, true);
        } finally {
          busy(false);
        }
        return;
      }
      if (!boxes.complete((words) => tell(words, true))) return;
      const typed = boxes.value();
      busy(true);
      try {
        await redeem(address, typed);
      } catch (trouble) {
        busy(false);
        tell(trouble.message, true);
        // A wrong or spent code: the row shakes empty for the right one. A
        // limit or a moment's trouble keeps what was typed, to press again.
        if (trouble.wrong) boxes.refuse();
        return;
      }
      // Signed in: the age question next, if this account has not
      // answered it, before the page carries on.
      finished = true;
      windowed?.cancel();
      gone();
      // Its first word with /api/account makes its orangecheck account on
      // the server, once it is 13 or over (api/account.js).
      const asked = await askAgeIfAsked({ pending: Boolean(why) || later }).catch(() => null);
      settled(!asked?.refused);
    });
    dialog.showModal();
    field.focus();
  });
}

// What /api/account said of the beta at the last age(): {tester, early,
// open, welcome}, for the welcome that follows the age question.
let beta = null;

/// What the server keeps of this sign-in's age: {ask, over_13}, or null
/// when nobody is signed in or it does not ask here.
export async function age() {
  const access = await token();
  if (!access) return null;
  const said = await json(await fetch("/api/account", { headers: { authorization: `Bearer ${access}` } }));
  beta = said.signed_in && said.beta ? said.beta : null;
  profileSaid = said.signed_in && said.profile !== undefined ? { of: accountId(), profile: said.profile } : null;
  return said.signed_in && said.age ? said.age : null;
}

// The account's own profile as the last age() heard it: {of, profile}, the
// profile {handle, name} or null for none; null when it was not said.
let profileSaid = null;
// A profile known on this page ({of, profile}): asked about once.
let named = null;

/// One name before the first public act (socialloop, 2026-11-24). A
/// comment, a reply, a post in Talk or a model shared from the site goes
/// out under the account's profile; one by an account with none read "A
/// builder", and nobody could follow its author. So before it goes, an
/// account with no profile is asked for a name and a handle, in First
/// steps' own Make your profile step (web/first-steps.js): one dialog over
/// the page, what they typed still in its box. Skip, or Escape, lets the
/// act go as it is, and the next one asks again. Never asked: an account
/// the server keeps from a profile (13 or over not answered, as
/// api/_trust.js publicTrouble), which is told what it is told today when
/// it acts, nor one whose profile could not be read. Resolves with the
/// profile ({handle, name}) the act goes out under, or null for none.
export async function nameFirst() {
  if (!signedIn()) return null;
  const id = accountId();
  if (named && named.of === id) return named.profile;
  const now = await age().catch(() => null);
  if (!profileSaid || profileSaid.of !== id) return null;
  let profile = profileSaid.profile;
  if (!profile) {
    if (now && now.over_13 !== true) return null;
    const made = await import("/first-steps.js")
      .then((steps) => steps.firstSteps({ pending: true, profileOnly: true })).catch(() => null);
    profile = made && made.profile ? made.profile : null;
  }
  if (profile) named = { of: id, profile };
  return profile;
}

/// Whether the last age() heard the beta is open for this account: a page
/// asks nothing more of the beta when it is not (billing_flow, beta off).
export function betaOpen() {
  return beta?.open === true;
}

/// The beta's welcome (web/beta-welcome.js), when the server says it is
/// due: the beta open, a new account, not asked yet. Once a page.
async function welcomeIfDue() {
  if (!beta || beta.welcome !== true) return null;
  beta = { ...beta, welcome: false };
  return import("/beta-welcome.js").then((one) => one.betaWelcome()).catch(() => null);
}

/// The age question, if this account is to be asked it: resolves with
/// {ask, over_13} as kept after, {refused: true} when the account was
/// deleted for an answer under 13 (signed out here, the page to carry on as
/// it is for nobody), or null when there was nothing to ask or it was put
/// off. Answered 13 or over, this was a first sign-in, and First steps are
/// offered: at once on a page with nothing pressed, and where it has
/// something to do once signed in ([pending]: a like, a follow), after it
/// has done it, in a snackbar (offerFirstSteps). A browser told before is
/// not asked: the new account goes as an answer under 13 does. While the
/// beta is open, a new account is welcomed to it first, asked once whether
/// to join its testers (betajoin, 2026-11-09), never before the age
/// question and never for an account it deleted.
export async function askAgeIfAsked({ pending = false } = {}) {
  const now = await age();
  if (!now || !now.ask) {
    // The welcome waits for a page with nothing pressed (the profile's,
    // the settings', which ask this as they open).
    if (!pending) await welcomeIfDue();
    return now;
  }
  const kept = refusedHere() ? await refuseAgain() : await askAge();
  if (kept && kept.over_13 === true) {
    if (pending) {
      keepStepsDue(email());
      offerFirstSteps().catch(() => null);
    } else {
      await welcomeIfDue();
      await import("/first-steps.js").then((steps) => steps.firstSteps()).catch(() => null);
    }
  }
  return kept;
}

// First steps put off (checkdrift, 2026-11-23): a new account that signed
// in to do something (a like, a follow, a comment) is asked its age, which
// must come first, and then what it pressed is done; First steps opened
// over the page instead and the like waited behind them, never made for
// whoever closed the window there. Kept for the address until offered, in
// a snackbar that covers nothing, once the page has done it (its calls
// answered, no dialog open), or on the next page this browser opens if
// this one went (the app's sign-in on /profile goes back to the app at
// once).
const STEPS_DUE = "brickworks.first_steps_due";
// A moment for the page to start what was pressed; then quiet for one
// look in a row, and offered regardless after the longest wait.
const STEPS_LATER_MS = 1000;
const STEPS_QUIET_MS = 250;
const STEPS_LONGEST_MS = 20000;
function stepsDue() {
  try {
    return localStorage.getItem(STEPS_DUE) || "";
  } catch {
    return "";
  }
}
function keepStepsDue(address) {
  try {
    if (address) localStorage.setItem(STEPS_DUE, address);
    else localStorage.removeItem(STEPS_DUE);
  } catch {
    // A browser that keeps nothing offers them on this page alone.
  }
}

/// First steps offered as a snackbar (web/toast.js): "Welcome to
/// Brickworks" and First steps, which opens the beta's welcome where it is
/// due and then First steps, ending back on the page. Once, for the
/// address they were kept for, and only while it is signed in here.
async function offerFirstSteps() {
  const pause = (ms) => new Promise((done) => setTimeout(done, ms));
  await pause(STEPS_LATER_MS);
  const giveUp = Date.now() + STEPS_LONGEST_MS;
  while ((calling > 0 || document.querySelector("dialog[open]")) && Date.now() < giveUp) await pause(STEPS_QUIET_MS);
  const address = stepsDue();
  if (!address || !signedIn() || address !== email()) return;
  keepStepsDue("");
  const { toast } = await import("/toast.js");
  toast(say("Welcome to Brickworks"), { action: { label: say("First steps"), run: async () => {
    await age().catch(() => null);
    await welcomeIfDue();
    await import("/first-steps.js").then((steps) => steps.firstSteps({ pending: true })).catch(() => null);
  } } });
}
if (stepsDue()) {
  const later = () => offerFirstSteps().catch(() => null);
  if (document.readyState === "complete") later();
  else addEventListener("load", later, { once: true });
}

/// What somebody under 13 is told, as paragraphs: the server's words, and
/// that nothing of them is kept.
function tooYoung() {
  const words = document.createElement("p");
  words.className = "said too-young";
  words.id = "age-refused";
  words.textContent = say("Brickworks accounts are for 13 and over. Ask a parent or guardian to sign in "
    + "with their own email and build with you.");
  const parent = document.createElement("p");
  parent.textContent = say("A parent or guardian new to Brickworks makes their account on their own phone or "
    + "computer first, then signs in here.");
  return [words, parent];
}

/// An answer under 13 taken: the account is gone, so this browser forgets
/// the sign-in and keeps that it was told.
function refusedNow() {
  try {
    localStorage.setItem(REFUSED, "1");
  } catch {
    // A browser that keeps nothing is told again at the next answer.
  }
  signOut();
}

/// A new account signed in on a browser told before: deleted without the
/// question, and said so in a dialog as after an answer under 13.
async function refuseAgain() {
  const answer = await call("/api/account?op=age", { method: "POST", body: { again: true } });
  if (answer.body && answer.body.age) return answer.body.age;
  if (!answer.body || answer.body.deleted !== true) return null;
  refusedNow();
  await learn();
  return new Promise((done) => {
    const dialog = document.createElement("dialog");
    dialog.className = "sign-in age";
    speaking(dialog);
    const title = document.createElement("h2");
    title.id = "age-title";
    dialog.setAttribute("aria-labelledby", title.id);
    document.body.append(dialog);
    showRefused(dialog, title, () => done({ refused: true }));
    dialog.showModal();
  });
}

/// [dialog] made to say that accounts are for 13 and over, that the account
/// is deleted, and a button to close it with; [then] once it is closed.
function showRefused(dialog, title, then) {
  title.textContent = say("Accounts are for 13 and over");
  const gone = document.createElement("p");
  gone.textContent = say("The account is deleted, with your email address. The date was never kept.");
  const close = document.createElement("button");
  close.className = "cta";
  close.type = "button";
  close.id = "age-done";
  close.textContent = say("Close");
  const row = document.createElement("div");
  row.className = "actions";
  row.append(close);
  let finished = false;
  const end = () => {
    if (finished) return;
    finished = true;
    dialog.close();
    dialog.remove();
    then();
  };
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  const [words, parent] = tooYoung();
  dialog.replaceChildren(title, words, gone, parent, row);
  close.focus();
}

/// The question itself, in a dialog over the page. Neutral: the same
/// question for everybody, and nothing before the answer about what either
/// answer opens.
async function askAge() {
  await learn();
  return new Promise((done) => {
    const dialog = document.createElement("dialog");
    dialog.className = "sign-in age";
    speaking(dialog);
    const title = document.createElement("h2");
    title.textContent = say("One question first");
    title.id = "age-title";
    dialog.setAttribute("aria-labelledby", title.id);
    const said = document.createElement("p");
    said.textContent = say("When were you born?");
    const form = document.createElement("form");
    // Month and year as two dropdowns side by side, the way a date of birth
    // is asked everywhere: the month by name, the years newest first. The
    // months as the language names them (Januar, janvier, enero).
    const choose = (id, said, autocomplete, choices) => {
      // Said once, inside the control; the label is there for a screen reader.
      const label = document.createElement("label");
      const words = document.createElement("span");
      words.className = "visually-hidden";
      words.textContent = said;
      const select = document.createElement("select");
      select.id = id;
      select.required = true;
      select.autocomplete = autocomplete;
      const none = document.createElement("option");
      none.value = "";
      none.textContent = said;
      none.disabled = true;
      none.selected = true;
      none.hidden = true;
      select.append(none);
      for (const [value, text] of choices) {
        const option = document.createElement("option");
        option.value = String(value);
        option.textContent = text;
        select.append(option);
      }
      label.append(words, select);
      return [label, select];
    };
    const thisYear = new Date().getFullYear();
    const months = new Intl.DateTimeFormat(language() === "en" ? "en-US" : language(), { month: "long", timeZone: "UTC" });
    const [monthLabel, month] = choose("age-month", say("Month"), "bday-month",
      Array.from({ length: 12 }, (_, at) => [at + 1, months.format(Date.UTC(2000, at, 1))]));
    const [yearLabel, year] = choose("age-year", say("Year"), "bday-year",
      Array.from({ length: 111 }, (_, back) => [thisYear - back, String(thisYear - back)]));
    const when = document.createElement("div");
    when.className = "when";
    when.append(monthLabel, yearLabel);
    const note = document.createElement("p");
    note.className = "said";
    note.setAttribute("role", "status");
    const go = document.createElement("button");
    go.className = "cta";
    go.type = "submit";
    go.id = "age-go";
    go.textContent = say("Carry on");
    const row = document.createElement("div");
    row.className = "actions";
    row.append(go);
    const quiet = document.createElement("p");
    quiet.className = "note";
    quiet.textContent = say("Brickworks asks everyone this once. The date itself is not kept.");
    form.append(when, row, note, quiet);
    dialog.append(title, said, form);
    document.body.append(dialog);
    let finished = false;
    const end = (result) => {
      if (finished) return;
      finished = true;
      dialog.close();
      dialog.remove();
      done(result);
    };
    dialog.addEventListener("cancel", () => end(null));
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      go.disabled = true;
      note.textContent = "";
      const answer = await call("/api/account?op=age", { method: "POST",
        body: { month: Number(month.value), year: Number(year.value) } });
      go.disabled = false;
      if (answer.status === 403 && answer.body.deleted === true) {
        // Under 13, said after the answer, never before it: the account is
        // gone, and the dialog says so until it is closed.
        refusedNow();
        finished = true;
        showRefused(dialog, title, () => done({ refused: true }));
        return;
      }
      if (answer.status !== 200 || !answer.body.age) {
        // The answer's own trouble (a month not come yet), else ours.
        note.textContent = answer.status === 422 && answer.body.error ? say(answer.body.error)
          : say("That did not go just now. Try again in a minute.");
        return;
      }
      end(answer.body.age);
    });
    dialog.showModal();
    month.focus();
  });
}
