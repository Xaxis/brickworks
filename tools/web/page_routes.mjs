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
// Here the browser is asked to stop only the requests to [patterns]
// (Fetch.enable's urlPattern: * for any run of characters, ? for one), on
// a session of each page of its own, and those are answered with no word
// from the page: the rest go when the page asks.
//
//   await pageRoute(context, ["https://overlook.technology/*"], (request) =>
//     ({ status: 200, headers: { "content-type": "application/javascript" }, body: "" }));
//
// The handler is given { url, method, headers } and returns { status,
// headers, body (a string or a Buffer) } to answer, or null to let the
// request go on as asked. A page opened by context.newPage is ready before
// its first request; one the page opens itself (a popup) is joined as soon
// as Playwright tells of it, and a request it makes before that goes as
// asked.

const ROUTES = Symbol.for("brickworks.pageRoutes");

export async function pageRoute(context, patterns, handler) {
  let held = context[ROUTES];
  if (!held) {
    held = context[ROUTES] = { routes: [], sessions: new Map() };
    context.on("page", (page) => { join(context, page).catch(() => {}); });
    const made = context.newPage.bind(context);
    context.newPage = async (...options) => {
      const page = await made(...options);
      await join(context, page).catch(() => {});
      return page;
    };
  }
  held.routes.push({ patterns, test: patterns.map(asRegExp), handler });
  await Promise.all([...context.pages()].map((page) => join(context, page).catch(() => {})));
  await Promise.all([...held.sessions.values()].map((joined) => joined.then(enable).catch(() => {})));
  return context;
}

function asRegExp(pattern) {
  const body = pattern.split("").map((c) => (c === "*" ? ".*" : c === "?" ? "." : c.replace(/[.+^${}()|[\]\\/]/g, "\\$&")))
    .join("");
  return new RegExp(`^${body}$`);
}

// One session a page, made once, stopping the requests every route names.
function join(context, page) {
  const held = context[ROUTES];
  if (!held.sessions.has(page)) {
    held.sessions.set(page, (async () => {
      const session = await context.newCDPSession(page);
      const joined = { session, held };
      session.on("Fetch.requestPaused", (event) => answer(joined, event));
      page.once("close", () => held.sessions.delete(page));
      await enable(joined);
      return joined;
    })());
  }
  return held.sessions.get(page);
}

function enable({ session, held }) {
  const patterns = held.routes.flatMap((route) => route.patterns).map((urlPattern) => ({ urlPattern, requestStage: "Request" }));
  return session.send("Fetch.enable", { patterns });
}

async function answer({ session, held }, event) {
  const { url, method, headers } = event.request;
  try {
    for (const route of held.routes) {
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
