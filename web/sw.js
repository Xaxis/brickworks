// The site's service worker (homescreen, 2026-11-22): what lets a phone or a
// computer install brickworks.diy as an app, say it is offline when it is,
// and show a push (api/_push.js) as the system's own notification. Asked
// for by web/push.js once a page has loaded, never before, so a first
// visit waits on nothing of it.
//
// It never stands between a person and a new deploy. Nothing it keeps is a
// page of the site: a page is always asked of the network, the deploy's
// own, and only when the network cannot be reached at all (no answer, not
// an error page) is the offline page shown in its place. The app (/app),
// its build (/b/), the engine (/e/), the API, the connector's sign-in and
// the console are not even seen: where the browser can (the static routing
// API, Chrome 123), it is told so at install; elsewhere the handler lets
// them go by untouched. What it keeps is the offline page in each language
// and what it is drawn with, made again whenever this file changes.

const VERSION = "1";
const KEPT = `brickworks-offline-${VERSION}`;
const OFFLINE = { en: "/offline", de: "/de/offline", fr: "/fr/offline", es: "/es/offline" };
const DRAWN_WITH = ["/site.css", "/theme.js", "/push.js", "/favicon-32.png", "/icon.svg"];
const KEEP = [...Object.values(OFFLINE), ...DRAWN_WITH];
// Never this worker's: the network's alone.
const PASS = /^\/(?:app(?:[/?]|$)|b\/|e\/|api\/|oauth\/|admin(?:[/?]|$)|\.well-known\/|(?:de|fr|es)\/oauth\/)/;

self.addEventListener("install", (event) => {
  // Asked while the install event is being dispatched, as the routing API
  // wants; where it refuses, the handler below lets them go by all the same.
  let routed = null;
  if (typeof event.addRoutes === "function" && typeof URLPattern === "function") {
    try {
      routed = Promise.resolve(event.addRoutes(["/app", "/app/*", "/b/*", "/e/*", "/api/*", "/oauth/*", "/admin", "/admin/*"]
        .map((pathname) => ({ condition: { urlPattern: new URLPattern({ pathname }) }, source: "network" })))).catch(() => null);
    } catch {
      routed = null;
    }
  }
  // Each kept on its own: one that cannot be had (a copy not made yet)
  // leaves the rest.
  event.waitUntil(Promise.all([routed, caches.open(KEPT)
    .then((kept) => Promise.all(KEEP.map((path) => kept.add(new Request(path, { cache: "reload" })).catch(() => null))))])
    .then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith("brickworks-") && name !== KEPT) await caches.delete(name);
    }
    // A page's request starts while the worker does.
    if (self.registration.navigationPreload) await self.registration.navigationPreload.enable().catch(() => null);
    await self.clients.claim();
  })());
});

// The offline page in the language the address is in, else the browser's.
function offlineFor(url) {
  const lang = /^\/(de|fr|es)(?:\/|$)/.exec(url.pathname)?.[1]
    || (self.navigator.languages || [self.navigator.language || ""]).map((tag) => String(tag).slice(0, 2).toLowerCase())
      .find((code) => code in OFFLINE)
    || "en";
  return OFFLINE[lang] || OFFLINE.en;
}

async function fromKept(path) {
  const kept = await caches.open(KEPT);
  return (await kept.match(path)) || (await kept.match(OFFLINE.en));
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || PASS.test(url.pathname)) return;
  if (request.mode === "navigate") {
    event.respondWith((async () => {
      try {
        return (await event.preloadResponse) || (await fetch(request));
      } catch {
        return (await fromKept(offlineFor(url))) || Response.error();
      }
    })());
    return;
  }
  // What the offline page is drawn with: the network's, as ever, and the
  // kept copy only when there is no network.
  if (DRAWN_WITH.includes(url.pathname)) {
    event.respondWith(fetch(request).catch(async () => (await (await caches.open(KEPT)).match(url.pathname)) || Response.error()));
  }
});

// A push (api/_push.js pushSaid): {title, body, url, tag}. Each model's
// newest replaces the one before, as the notifications page groups them.
self.addEventListener("push", (event) => {
  let said = {};
  try {
    said = event.data ? event.data.json() : {};
  } catch {
    said = { body: event.data ? event.data.text() : "" };
  }
  const title = String(said.title || "Brickworks").slice(0, 120);
  event.waitUntil(self.registration.showNotification(title, {
    body: String(said.body || "").slice(0, 600),
    tag: said.tag ? String(said.tag).slice(0, 64) : undefined,
    renotify: Boolean(said.tag),
    icon: "/favicon-192.png",
    badge: "/badge-96.png",
    timestamp: Date.now(),
    data: { url: String(said.url || "/notifications") },
  }));
});

// Opened: its page, focused where a window already shows it, else in a new
// one. Never by taking over a window that shows something else: that could
// be the studio, with a model not yet saved.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  let target;
  try {
    target = new URL(event.notification.data?.url || "/notifications", self.location.origin);
  } catch {
    target = new URL("/notifications", self.location.origin);
  }
  // Only this site's pages: a push names nowhere else.
  if (target.origin !== self.location.origin) target = new URL("/notifications", self.location.origin);
  event.waitUntil((async () => {
    const open = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const same = open.find((client) => {
      const at = new URL(client.url);
      return at.origin === target.origin && at.pathname === target.pathname;
    });
    if (same) return same.focus();
    return self.clients.openWindow(target.href);
  })());
});

// The browser renewed a device's subscription: the pages are told when
// next opened (web/push.js checks it against the account on each visit).
self.addEventListener("pushsubscriptionchange", () => {});
