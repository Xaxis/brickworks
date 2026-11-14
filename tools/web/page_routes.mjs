// Requests of a browser context's pages answered here, as Playwright's
// context.route answers them, holding none of the page's other requests.
//
// A Playwright route, any route, intercepts every request the page makes
// (Fetch.enable on the pattern "*") and lets each go only once it has the
// page's own word of it too (Network.requestWillBeSent), which the page's
// renderer says when the task that asked for it ends. A request the app
// asked for in a frame left when the frame ended: under SwiftShader, 100 to
// 600 ms later, every Together send, chat line, point and relay answer.
// Real browsers send at once (framefetch 2026-11-14: a fetch from a task
// busy 300 ms after it reached a server here in 1-8 ms without a route and
// in 303-316 ms with one), so every check timed a wait no visitor has. Every
// context launch() makes had two routes (the visit counter since 2026-10-16,
// the parts mirror since 2026-11-12).
//
// Here the browser itself is asked to stop only the requests to [patterns]
// (Fetch.enable's urlPattern: * for any run of characters, ? for one), on
// one session of the whole browser's, and those are answered with no word
// from the page: the rest go when the page asks. The browser's own session
// stops a tab the page opens itself (a popup, the booklet's tab, "Open in
// the app") from its first request. A session of each page's own did not:
// it is joined only once Playwright tells of the page, and a popup's first
// requests went to the real counter and bucket before (ffreview
// 2026-11-14). Nor can a second watcher of new tabs hold one paused for
// itself: Playwright lets it run when Playwright is ready.
//
// The browser's session sees every context's requests, so each is answered
// by the routes of the context it came from: a page's id (its main frame's)
// names its context, and a frame inside a page is found in the frame trees
// of the pages joined (a session of each page's own, made as it opens). A
// frame not found within 3 s is answered by the routes any context has.
//
// And each such page keeps no HTTP cache, as a page of a context with a
// Playwright route keeps none: sets_flow, library_tab_flow and
// carried_flow measured loads without one (ffreview 2026-11-14).
//
//   await pageRoute(context, ["https://overlook.technology/*"], (request) =>
//     ({ status: 200, headers: { "content-type": "application/javascript" }, body: "" }));
//
// The handler is given { url, method, headers } and returns { status,
// headers, body (a string or a Buffer) } to answer, or null to let the
// request go on as asked. A persistent context has no browser to ask, so
// there each page's own session stops its requests, and a popup's first
// ones go as asked.
//
// A check that routes requests itself (context.route or page.route) has
// Playwright stop all of its page's requests anyway, and its routes must
// come first: the parts mirror, asked before Playwright's routes, answered
// every .lbm before fetch_retry could cut it (framefetch 2026-11-14). So
// the first route a check makes hands these over: each becomes a Playwright
// route on the context, made before the check's, which falls back to it as
// it did before page_routes, and what Playwright lets go goes.

const ROUTES = Symbol.for("brickworks.pageRoutes");
const WATCH = Symbol.for("brickworks.pageRoutes.browser");
// How long a request from a frame of no page joined yet waits for its page.
const FIND_MS = 3000;

export async function pageRoute(context, patterns, handler) {
  const held = context[ROUTES] || hold(context);
  const added = { patterns, test: patterns.map(asRegExp), handler };
  held.routes.push(added);
  if (held.playwright.going) {
    await held.playwright.going;
    await asPlaywrights(held, added);
    return context;
  }
  const watch = await held.watching;
  if (watch) await stop(watch);
  await Promise.all([...context.pages()].map((page) => join(held, page).catch(() => {})));
  if (!watch) await Promise.all([...held.pages.values()].map((joined) => joined.then(enable).catch(() => {})));
  return context;
}

function hold(context) {
  const browser = context.browser();
  const route = context.route.bind(context);
  const held = context[ROUTES] = {
    context, routes: [], pages: new Map(), id: null,
    playwright: { route, going: null },
    watching: browser ? watch(browser).then((one) => one, () => null) : Promise.resolve(null),
  };
  held.watching.then((one) => {
    if (!one) return;
    one.contexts.add(held);
    context.on("close", () => one.contexts.delete(held));
  });
  context.route = async (...how) => {
    await handOver(context);
    return route(...how);
  };
  for (const page of context.pages()) mind(context, page);
  context.on("page", (page) => { mind(context, page); join(held, page).catch(() => {}); });
  const made = context.newPage.bind(context);
  context.newPage = async (...options) => {
    const page = await made(...options);
    mind(context, page);
    await join(held, page).catch(() => {});
    return page;
  };
  return held;
}

// The browser's one session, which stops the requests every context's
// routes name.
function watch(browser) {
  if (!browser[WATCH]) {
    browser[WATCH] = browser.newBrowserCDPSession().then((session) => {
      const one = { session, contexts: new Set(), frames: new Map(), stopping: "", stopped: Promise.resolve() };
      session.on("Fetch.requestPaused", (event) => paused(one, event));
      return one;
    });
  }
  return browser[WATCH];
}

function stop(one) {
  const patterns = [...new Set([...one.contexts].filter((held) => !held.playwright.going)
    .flatMap((held) => held.routes.flatMap((route) => route.patterns)))];
  const key = patterns.join("\n");
  if (key !== one.stopping) {
    one.stopping = key;
    one.stopped = (patterns.length
      ? one.session.send("Fetch.enable", { patterns: patterns.map((urlPattern) => ({ urlPattern, requestStage: "Request" })) })
      : one.session.send("Fetch.disable")).catch(() => {});
  }
  return one.stopped;
}

// A page's own route hands over too: Playwright asks a page's routes before
// its context's.
function mind(context, page) {
  if (page[ROUTES]) return;
  page[ROUTES] = true;
  const route = page.route.bind(page);
  page.route = async (...how) => {
    await handOver(context);
    return route(...how);
  };
}

// Every route here made a Playwright route on [context], and the stopping
// of its requests here ended, once and before the check's first route of
// its own.
function handOver(context) {
  const held = context[ROUTES];
  if (!held.playwright.going) {
    held.playwright.going = (async () => {
      for (const route of held.routes) await asPlaywrights(held, route);
      const one = await held.watching;
      if (one) return stop(one);
      return Promise.all([...held.pages.values()].map((joined) => joined
        .then(({ session }) => session.send("Fetch.disable")).catch(() => {})));
    })();
  }
  return held.playwright.going;
}

function asPlaywrights(held, { test, handler }) {
  return held.playwright.route((url) => test.some((one) => one.test(url.href)), async (route) => {
    const request = route.request();
    try {
      const said = await handler({ url: request.url(), method: request.method(), headers: request.headers() });
      if (!said) return await route.fallback();
      return await route.fulfill({ status: said.status, headers: said.headers || {}, body: said.body ?? "" });
    } catch {
      // The page closed meanwhile, or its request did.
      return route.fallback().catch(() => {});
    }
  });
}

function asRegExp(pattern) {
  const body = pattern.split("").map((c) => (c === "*" ? ".*" : c === "?" ? "." : c.replace(/[.+^${}()|[\]\\/]/g, "\\$&")))
    .join("");
  return new RegExp(`^${body}$`);
}

// One session a page, made once: its HTTP cache off, and its id and its
// context's kept for the browser's session.
function join(held, page) {
  if (!held.pages.has(page)) {
    held.pages.set(page, (async () => {
      const session = await held.context.newCDPSession(page);
      const joined = { session, held };
      page.once("close", () => held.pages.delete(page));
      // The cache is off only while the session's network events are on.
      await session.send("Network.enable", { maxTotalBufferSize: 0, maxResourceBufferSize: 0 });
      await session.send("Network.setCacheDisabled", { cacheDisabled: true });
      const { targetInfo } = await session.send("Target.getTargetInfo");
      held.id = targetInfo.browserContextId;
      const one = await held.watching;
      if (one) {
        one.frames.set(targetInfo.targetId, held);
      } else {
        session.on("Fetch.requestPaused", (event) => answer(session, held.playwright.going ? [] : held.routes, event));
        await enable(joined);
      }
      return joined;
    })());
  }
  return held.pages.get(page);
}

// A persistent context's page stops its own requests.
function enable({ session, held }) {
  if (held.playwright.going) return session.send("Fetch.disable");
  const patterns = held.routes.flatMap((route) => route.patterns).map((urlPattern) => ({ urlPattern, requestStage: "Request" }));
  return session.send("Fetch.enable", { patterns });
}

// A request the browser's session stopped, answered by its context's routes.
async function paused(one, event) {
  let routes = [];
  try {
    const held = await whose(one, event.frameId);
    if (held === undefined) routes = [...one.contexts].filter((each) => !each.playwright.going).flatMap((each) => each.routes);
    else if (held && !held.playwright.going) routes = held.routes;
  } catch {
    // The browser closed meanwhile.
  }
  return answer(one.session, routes, event);
}

// The context of the page [frame] is in: null for a page of a context with
// no routes here, undefined for a frame not found.
async function whose(one, frame) {
  if (!frame) return undefined;
  const until = Date.now() + FIND_MS;
  for (;;) {
    if (one.frames.has(frame)) return one.frames.get(frame);
    const info = await one.session.send("Target.getTargetInfo", { targetId: frame }).then(({ targetInfo }) => targetInfo, () => null);
    if (info) {
      const find = () => [...one.contexts].find((each) => each.id === info.browserContextId) || null;
      // A context's id is known once one of its pages is joined.
      if (!find()) await Promise.all([...one.contexts].flatMap((each) => [...each.pages.values()]).map((joining) => joining.catch(() => {})));
      const held = find();
      if (held) one.frames.set(frame, held);
      return held;
    }
    // Not a page: a frame inside one.
    for (const held of one.contexts) {
      for (const joining of held.pages.values()) {
        const joined = await joining.catch(() => null);
        const tree = joined && await joined.session.send("Page.getFrameTree").then(({ frameTree }) => frameTree, () => null);
        for (const id of framesOf(tree)) one.frames.set(id, held);
      }
    }
    if (one.frames.has(frame)) return one.frames.get(frame);
    if (Date.now() >= until) return undefined;
    await new Promise((done) => setTimeout(done, 250));
  }
}

function framesOf(tree) {
  return tree ? [tree.frame.id, ...(tree.childFrames || []).flatMap(framesOf)] : [];
}

async function answer(session, routes, event) {
  const { url, method, headers } = event.request;
  try {
    for (const route of routes) {
      if (!route.test.some((test) => test.test(url))) continue;
      const said = await route.handler({ url, method, headers });
      if (!said) continue;
      const body = Buffer.isBuffer(said.body) ? said.body : Buffer.from(String(said.body ?? ""));
      await session.send("Fetch.fulfillRequest", {
        requestId: event.requestId,
        responseCode: said.status,
        responseHeaders: Object.entries(said.headers || {}).map(([name, value]) => ({ name, value: String(value) })),
        body: body.toString("base64"),
      });
      return;
    }
    await session.send("Fetch.continueRequest", { requestId: event.requestId });
  } catch {
    // The page closed meanwhile, or its request did: nothing waits on it.
    await session.send("Fetch.continueRequest", { requestId: event.requestId }).catch(() => {});
  }
}
