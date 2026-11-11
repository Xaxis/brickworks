// A picture the browser drops under load is taken again before a check is
// told. SwiftShader on a loaded box now and then fails a capture outright
// ("Unable to capture screenshot") or runs past its time, and each drop
// failed a whole check that had passed every step: docs on rel-m283's
// preview and three units' (a 4 px backdrop blur took over 30 s to draw),
// app_menu on rel-m284's (2026-11-10). A page that never draws still fails,
// after its third try.
//
// steadyShots(page) wraps page.screenshot in place: each capture gets two
// minutes unless the caller names its own time, and a dropped one is tried
// twice more, a little later each time. Any other error goes straight on.

export const CAPTURE_TRIES = 3;
export const CAPTURE_TIME_MS = 120000;
const DROPPED = /Unable to capture screenshot|Timeout \d+ms exceeded/i;

export function dropped(trouble) {
  return DROPPED.test(String(trouble?.message ?? trouble ?? ""));
}

export function steadyShots(page, { pauseMs = 2000, log = console.log } = {}) {
  if (!page || page.steadyShots) return page;
  const take = page.screenshot.bind(page);
  page.screenshot = async (options = {}) => {
    for (let tried = 1; ; tried += 1) {
      try {
        return await take({ timeout: CAPTURE_TIME_MS, ...options });
      } catch (trouble) {
        const closed = typeof page.isClosed === "function" && page.isClosed();
        if (!dropped(trouble) || tried >= CAPTURE_TRIES || closed) throw trouble;
        log(`  (a picture the browser dropped, ${String(trouble.message).split("\n")[0].slice(0, 90)}: taken again, try ${tried + 1})`);
        await new Promise((go) => setTimeout(go, pauseMs * tried));
      }
    }
  };
  page.steadyShots = true;
  return page;
}
