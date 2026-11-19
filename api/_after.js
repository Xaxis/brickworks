// Work an answer does not wait on (onfix, 2026-11-18): the owner's
// notifications raised as a sign-up, a first publish, a report or
// Admission's word is answered (api/_notify.js raise), and a 5xx kept
// (api/_noted.js). Awaited where it happened, each added its table's time
// to the person's wait, up to 5 s when the table hung, and a first publish
// waited on a count besides (onreview's latency.mjs).
//
// On Vercel the function is kept alive for it by the request's own context,
// which Vercel's Node runtime keeps at globalThis[Symbol.for(
// "@vercel/request-context")]: its get() gives {waitUntil}, read exactly as
// @vercel/functions' waitUntil reads it (get-context.js and wait-until.js in
// 3.10.6). The API has no npm dependencies (tools/package_api.sh packs it),
// so it is read here. Anywhere it is absent (relay_server.mjs on this
// machine, the tests) the work runs on its own and nobody waits for it past
// BOUND. Never throws into the request.

const CONTEXT = Symbol.for("@vercel/request-context");
/// How long anything here waits on work it began, where Vercel's context is absent.
export const BOUND = 1500;
const running = new Set();

/// The request's waitUntil, called as the context's own; null when absent.
function keeper() {
  try {
    const context = globalThis[CONTEXT]?.get?.();
    return typeof context?.waitUntil === "function" ? (promise) => context.waitUntil(promise) : null;
  } catch {
    return null;
  }
}

/// How this deployment keeps work past an answer: "waitUntil" (Vercel's
/// request context) or "bounded" (on its own, BOUND at most).
export const afterHow = () => (keeper() ? "waitUntil" : "bounded");

/// [work] (a function, called once the code that asked has run on, so the
/// answer it sends goes first) done after the answer and never in its way:
/// a failure is logged under [where], never thrown.
export function afterAnswer(work, where = "after") {
  const done = Promise.resolve().then(work).catch((trouble) => {
    console.error(`${where}: ${String(trouble?.message || trouble).slice(0, 160)}`);
  });
  const keep = keeper();
  if (keep) {
    try {
      keep(done);
      return;
    } catch {
      // Kept on its own below.
    }
  }
  // The bound's timer holds a process that would end (a script, a check)
  // open for the work, BOUND at most.
  let timer = null;
  const bounded = Promise.race([done, new Promise((resolve) => {
    timer = setTimeout(resolve, BOUND);
  })]).finally(() => {
    clearTimeout(timer);
    running.delete(bounded);
  });
  running.add(bounded);
}

/// Every piece of work begun here without Vercel's context, done or past
/// its bound: for a check that reads what the work wrote.
export const settled = () => Promise.all([...running]);
