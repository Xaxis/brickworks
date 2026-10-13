// A shared model's page, /m/<id> (api/share.js): the page's one script.
//
// It counts the view, once a day in this browser: the server counts a
// visitor once a day as well, and never a robot, so this only saves it
// asking. Nothing else here writes anything.
//
// And the viewer, /app?view=<id>, keeps the link in the address bar while
// a model is looked at, marking its place in the history as its own. A
// reload there arrives here; this sends it straight back to the viewer,
// so somebody building from a phone that reloaded the tab is not left on
// the page. Replaced, not followed, so Back still leaves.
(function () {
  "use strict";
  const body = document.body;
  const id = body && body.dataset.id;
  const viewer = body && body.dataset.viewer;
  if (!id || !/^[A-Za-z0-9]{10}$/.test(id)) return;

  const state = history.state;
  if (state && state.brickworksViewer === id && viewer && viewer.startsWith("/app?view=")) {
    location.replace(viewer);
    return;
  }

  const KEY = "brickworks.seen";
  const today = new Date().toISOString().slice(0, 10);
  let seen = {};
  try {
    seen = JSON.parse(localStorage.getItem(KEY) || "{}") || {};
  } catch {
    seen = {};
  }
  if (seen[id] === today) return;
  fetch(`/api/share?op=seen&id=${id}`, { method: "POST", keepalive: true,
    headers: { "content-type": "application/json" }, body: "{}" })
    .then((reply) => {
      if (!reply.ok) return;
      // Today's only, so the list never grows past a day's pages.
      const kept = { [id]: today };
      for (const [other, day] of Object.entries(seen)) if (day === today) kept[other] = day;
      try {
        localStorage.setItem(KEY, JSON.stringify(kept));
      } catch {
        // A browser that keeps nothing is counted by the server alone.
      }
    })
    .catch(() => {});
})();
