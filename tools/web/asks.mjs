// A flow's answer to the site's own ask (web/kit.js ask and tell), where it
// answered the browser's confirm() with page.on("dialog") until 2026-11-23.
//
//   import { answerAsks } from "./asks.mjs";
//   await answerAsks(page);                        every ask answered yes, as dialog.accept() did
//   await answerAsks(page, { times: 1 });          the next one, as page.once("dialog", accept) did
//   const heard = [];
//   await answerAsks(page, { heard });             and what each asked, its title and line
//
// The ask's own button is pressed in the page as it opens, Yes or (once
// [times] are used up) No, as the browser dismissed a confirm nobody
// answered. Called again on a page, it adds [times] and keeps its [heard].
// tools/web/ask_flow.mjs drives the ask itself, with the mouse, the keyboard
// and a screen reader's tree; this is for flows about what the act does.
//
// And the browser's own dialog, which nothing on the site opens any more
// (tools/check.sh): one that opens is said as a FAIL line and dismissed, so
// the act it guarded is not done and the flow's own check of it fails. A
// page's "Leave site?" (beforeunload) is the browser's alone, and accepted.

const states = new WeakMap();

/// [page]'s asks answered [answer] ("yes" or "no"), [times] of them, each
/// one's words pushed to [heard].
export async function answerAsks(page, { answer = "yes", times = Infinity, heard = [] } = {}) {
  const known = states.get(page);
  if (known) {
    known.left = known.left === Infinity || times === Infinity ? Infinity : known.left + times;
    known.answer = answer;
    return known.heard;
  }
  const state = { left: times, answer, heard };
  states.set(page, state);
  await page.exposeFunction("__brickworksAnswer", (words) => {
    state.heard.push(words);
    if (state.left <= 0) return "no";
    state.left -= 1;
    return state.answer;
  });
  page.on("dialog", (dialog) => {
    if (dialog.type() === "beforeunload") return dialog.accept().catch(() => {});
    console.log(`  FAIL  the browser's own ${dialog.type()} opened, where the site's ask belongs: ${dialog.message().slice(0, 120)}`);
    return dialog.dismiss().catch(() => {});
  });
  await page.addInitScript(watch);
  await page.evaluate(watch).catch(() => {});
  return heard;
}

// In the page: each ask, as it opens, answered by its own button.
function watch() {
  if (window.__brickworksAsks) return;
  window.__brickworksAsks = true;
  new MutationObserver((changes) => {
    for (const { target } of changes) {
      if (!target.matches?.("dialog.ask[open]") || target.dataset.heard) continue;
      target.dataset.heard = "yes";
      const words = [...target.querySelectorAll("h2, p")].map((one) => one.textContent).join(" ");
      window.__brickworksAnswer(words).then((answer) => {
        target.querySelector(`[data-answer="${answer === "yes" ? "yes" : "no"}"]`)?.click();
      });
    }
  }).observe(document, { attributes: true, attributeFilter: ["open"], subtree: true });
}
