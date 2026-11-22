// The site on a phone's home screen, or a computer's dock, and this
// device's notifications (homescreen, 2026-11-22; docs/SOCIAL.md, the
// units' rank 4). web/theme.js asks for it on every page but an embed's
// card and the connector's consent page, as it asks for the beta's bar.
//
// - The service worker (web/sw.js) is registered once the page has loaded
//   and the browser is idle, so a first visit waits on nothing of it.
// - Installing is offered from a person's second visit, never the first
//   (a visit: a page after 30 minutes without one), in the site notice's
//   card at the window's foot: Install, which is the browser's own
//   dialog, or No thanks, which is kept in this browser and never asked
//   again (Settings still has Install). Chrome and Edge say when the site
//   can be installed (beforeinstallprompt, which theme.js holds from the
//   first moment so the browser's own bar never shows); on an iPhone or
//   iPad, where Safari has no such thing, the card says how: Share, then
//   Add to Home Screen. Not where it is installed already, nor while the
//   owner's notice is shown (the next page then).
// - Settings › Notifications turns this device's notifications on and off
//   (web/settings.js, with turnOn and turnOff here). Signed out, a device
//   turned on stops (its subscription ended here, so the server deletes it
//   at its next push); renewed by the browser, the account is told its new
//   address.
// - The offline page (web/offline.html, which the worker shows when the
//   network is gone) goes back to the page asked for when it returns.
//
// Its words are the page's language's (window.brickworksLang.say).

const VISITS = "brickworks.visits";
const INSTALL = "brickworks.install";
const DEVICE = "brickworks.push";
const GAP_MS = 30 * 60 * 1000;
const root = document.documentElement;
const say = (english, values = {}) => (window.brickworksLang?.say ? window.brickworksLang.say(english, values) : english);

function read(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // A browser that keeps nothing counts every visit as its first.
  }
}

/// Opened from the home screen or the dock, as an app.
export const standalone = () => matchMedia("(display-mode: standalone)").matches || navigator.standalone === true;
/// Whether this browser can be sent pushes.
export const pushable = () => window.isSecureContext && "serviceWorker" in navigator && typeof PushManager === "function"
  && typeof Notification === "function";
/// An iPhone or an iPad, where Safari installs only by Share, Add to Home Screen.
export const apple = () => /iPhone|iPad|iPod/.test(navigator.userAgent)
  || (/Macintosh/.test(navigator.userAgent) && navigator.maxTouchPoints > 1);

// ---------------------------------------------------------------------------
// Visits: this one counted when the last page was 30 minutes ago or more.

const visits = (() => {
  const was = read(VISITS) || { n: 0, last: 0 };
  const now = Date.now();
  const n = now - Number(was.last || 0) >= GAP_MS ? Math.min(Number(was.n || 0) + 1, 9999) : Number(was.n || 0) || 1;
  write(VISITS, { n, last: now });
  return n;
})();

// ---------------------------------------------------------------------------
// The service worker.

let registering = null;

/// The worker registered (once a page), or null where there is none.
export function register() {
  if (!("serviceWorker" in navigator)) return Promise.resolve(null);
  registering ||= navigator.serviceWorker.register("/sw.js", { scope: "/", updateViaCache: "none" }).catch(() => null);
  return registering;
}

/// The worker ready, or null after [ms].
async function ready(ms = 10000) {
  await register();
  return Promise.race([navigator.serviceWorker.ready, new Promise((resolve) => setTimeout(() => resolve(null), ms))]);
}

// ---------------------------------------------------------------------------
// Installing.

// The browser's offer, held: theme.js's, if it came before this loaded.
let held = window.brickworksInstall || null;
addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  held = event;
  offer();
});
addEventListener("appinstalled", () => {
  held = null;
  write(INSTALL, "installed");
  card?.remove();
  delete root.dataset.offer;
  document.dispatchEvent(new Event("brickworks:installed"));
});

/// Whether Brickworks can be installed here now: by the browser's dialog
/// ("prompt"), by Share on an iPhone ("apple"), or not (null).
export function installable() {
  if (standalone() || read(INSTALL) === "installed") return null;
  if (held) return "prompt";
  return apple() ? "apple" : null;
}

/// The browser's own install dialog: "accepted", "dismissed", or null when
/// it has none to show.
export async function install() {
  const offered = held;
  if (!offered) return null;
  held = null;
  await offered.prompt();
  const choice = await offered.userChoice.catch(() => null);
  if (choice?.outcome === "accepted") write(INSTALL, "installed");
  return choice?.outcome || "dismissed";
}

let card = null;
let offered = false;

/// The offer, from the second visit, once: never where it was said no to,
/// or is installed.
function offer() {
  const how = installable();
  if (offered || visits < 2 || !how || read(INSTALL) || !document.body) return;
  // Not where Settings offers it itself, nor on the offline page, the
  // owner's console or the directory reviewer's sign-in.
  if (/^\/(?:(?:de|fr|es)\/)?(?:settings|offline|admin|review)\/?$/.test(location.pathname)) return;
  // The owner's notice has the window's foot: the next page.
  if (root.hasAttribute("data-notice")) return;
  offered = true;
  setTimeout(() => draw(how), 1200);
}

function made(tag, props = {}, ...children) {
  const one = Object.assign(document.createElement(tag), props);
  one.append(...children);
  return one;
}

/// The offer drawn: the site notice's card, its words over its buttons.
function draw(how) {
  if (card || root.hasAttribute("data-notice") || installable() !== how) return;
  const words = how === "apple"
    ? say("Add Brickworks to your Home Screen: tap Share, then Add to Home Screen. Opened from there, it can tell you when somebody comments on your models.")
    : say("Install Brickworks on this device: it opens in its own window, and can tell you when somebody comments on your models.");
  const yes = made("button", { type: "button", className: "cta small", textContent: how === "apple" ? say("OK") : say("Install") });
  const no = made("button", { type: "button", className: "cta ghost small", textContent: say("No thanks") });
  card = made("aside", { className: "site-notice install-offer" },
    made("p", { className: "words", textContent: words }),
    made("div", { className: "actions" }, ...(how === "apple" ? [yes] : [no, yes])));
  card.setAttribute("aria-label", say("Install Brickworks"));
  const gone = () => {
    card?.remove();
    card = null;
    delete root.dataset.offer;
  };
  yes.addEventListener("click", async () => {
    if (how === "apple") {
      write(INSTALL, "told");
      gone();
      return;
    }
    gone();
    const outcome = await install();
    if (outcome === "dismissed") write(INSTALL, "no");
  });
  no.addEventListener("click", async () => {
    write(INSTALL, "no");
    gone();
    const { toast } = await import("/toast.js");
    const at = /^\/(de|fr|es)(?:\/|$)/.exec(location.pathname)?.[1];
    const settings = made("a", { href: `${at ? `/${at}` : ""}/settings#email-part`, textContent: say("Settings") });
    const said = say("We won’t ask again. You can install Brickworks from {settings}.");
    toast(said.split(/(\{settings\})/).filter(Boolean).map((piece) => (piece === "{settings}" ? settings : piece)), {
      action: { label: say("Undo"), run: () => {
        write(INSTALL, null);
        offered = false;
        draw(installable());
      } } });
  });
  card.addEventListener("keydown", (event) => {
    if (event.key === "Escape") gone();
  });
  document.body.append(card);
  root.dataset.offer = "";
  requestAnimationFrame(() => card?.classList.add("shown"));
}

// ---------------------------------------------------------------------------
// This device's notifications.

const keyBytes = (key) => {
  const text = String(key).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(text + "=".repeat((4 - (text.length % 4)) % 4));
  return Uint8Array.from(raw, (c) => c.charCodeAt(0));
};
const sameKey = (subscription, key) => {
  const had = subscription?.options?.applicationServerKey;
  if (!had) return true;
  const a = new Uint8Array(had);
  const b = keyBytes(key);
  return a.length === b.length && a.every((byte, i) => byte === b[i]);
};

/// This device as the browser has it: {pushable, permission, subscription
/// (its JSON) or null}.
export async function device() {
  if (!pushable()) return { pushable: false, permission: "unsupported", subscription: null };
  const registration = await ready(4000);
  const subscription = registration ? await registration.pushManager.getSubscription().catch(() => null) : null;
  return { pushable: true, permission: Notification.permission, subscription: subscription ? subscription.toJSON() : null };
}

/// This device subscribed with [key], after the browser's own prompt:
/// {state: "granted", subscription} or {state: "denied" | "default"}, or
/// {state: "failed"} when the browser's push service would not.
export async function turnOn(key) {
  if (!pushable()) return { state: "unsupported" };
  const permission = Notification.permission === "granted" ? "granted" : await Notification.requestPermission();
  if (permission !== "granted") return { state: permission };
  const registration = await ready();
  if (!registration) return { state: "failed" };
  let subscription = await registration.pushManager.getSubscription().catch(() => null);
  // One made with another key (a key changed since) cannot be sent to.
  if (subscription && !sameKey(subscription, key)) {
    await subscription.unsubscribe().catch(() => null);
    subscription = null;
  }
  try {
    subscription ||= await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(key) });
  } catch {
    return { state: "failed" };
  }
  return { state: "granted", subscription: subscription.toJSON() };
}

/// This device's subscription ended: its endpoint, or null for none.
export async function turnOff() {
  const registration = pushable() ? await ready(4000) : null;
  const subscription = registration ? await registration.pushManager.getSubscription().catch(() => null) : null;
  if (!subscription) return null;
  const { endpoint } = subscription;
  await subscription.unsubscribe().catch(() => null);
  write(DEVICE, null);
  return endpoint;
}

/// The device the account was told of ([endpoint], or null for none).
export function told(endpoint) {
  write(DEVICE, endpoint || null);
}

/// On each page: signed out, a device turned on stops; renewed by the
/// browser, the account is told its new address.
async function keep() {
  const endpoint = read(DEVICE);
  if (!endpoint || !pushable() || Notification.permission !== "granted") return;
  const registration = await navigator.serviceWorker.getRegistration("/").catch(() => null);
  const subscription = registration ? await registration.pushManager.getSubscription().catch(() => null) : null;
  const account = await import("/account.js").catch(() => null);
  if (!account) return;
  if (!account.signedIn()) {
    await subscription?.unsubscribe().catch(() => null);
    write(DEVICE, null);
    return;
  }
  if (!subscription || subscription.endpoint === endpoint) return;
  const said = subscription.toJSON();
  const answer = await account.call("/api/people?op=push", { method: "POST", body: { on: true, endpoint: said.endpoint,
    p256dh: said.keys?.p256dh, auth: said.keys?.auth, lang: window.brickworksLang?.code || "en" } }).catch(() => null);
  if (answer?.status === 200) write(DEVICE, said.endpoint);
}

// ---------------------------------------------------------------------------
// Once the page has loaded and the browser is idle.

function settle() {
  register();
  // The server's pages (/m/, /u/, /c/) carry no manifest of their own.
  if (!document.querySelector('link[rel="manifest"]')) {
    document.head.append(made("link", { rel: "manifest", href: "/site.webmanifest" }));
  }
  offer();
  keep();
}
const idle = () => (window.requestIdleCallback ? requestIdleCallback(settle, { timeout: 4000 }) : setTimeout(settle, 500));
if (document.readyState === "complete") idle();
else addEventListener("load", idle, { once: true });

// The offline page: the page asked for, once the network is back.
if (root.hasAttribute("data-offline")) addEventListener("online", () => location.reload());
