// Fingers on the app's canvas in a browser that speaks no CDP: Playwright's
// WebKit, the engine of every iPhone browser (phonetruth, 2026-11-18).
//
// Chromium is touched through CDP (Input.dispatchTouchEvent), and both
// engines tap through Playwright's touchscreen, which is the browser's own
// touch. But Playwright has no finger to hold or drag, and none of two at
// once. So here a finger held, dragged or pinched is the events Godot's web
// platform listens for on the canvas (touchstart, touchmove, touchend: their
// changedTouches, each touch's identifier and clientX/Y), made in the page.
// WebKit makes no Touch or TouchEvent from a script ("Illegal constructor",
// "Type error"), but its document.createTouch and createTouchList still
// work, and an Event carrying those lists is what Godot reads.
//
// [type] and [points] are CDP's: touchStart, touchMove, touchEnd or
// touchCancel with every finger still down, numbered 1, 2, … in order, so
// touchEnd with [] lifts them all. What changed is worked out as CDP does:
// the fingers new to a start, all of them in a move, those gone at an end.

export async function madeTouch(page, type, points) {
  await page.evaluate(([kind, at]) => {
    const canvas = document.getElementById("canvas") || document.querySelector("canvas");
    if (!canvas) throw new Error("no canvas to touch");
    const down = window.brickworksFingers || (window.brickworksFingers = new Map());
    const now = new Map(at.map((p, i) => [i + 1, p]));
    const name = { touchStart: "touchstart", touchMove: "touchmove", touchEnd: "touchend", touchCancel: "touchcancel" }[kind];
    if (!name) throw new Error(`no touch is called ${kind}`);
    let changed;
    if (kind === "touchStart") changed = [...now].filter(([id]) => !down.has(id));
    else if (kind === "touchMove") changed = [...now];
    else changed = [...down].filter(([id]) => !now.has(id));
    if (kind === "touchEnd" || kind === "touchCancel") for (const [id] of changed) down.delete(id);
    else for (const [id, p] of now) down.set(id, p);
    const touch = ([id, p]) => document.createTouch(window, canvas, id, p.x + window.scrollX, p.y + window.scrollY, p.x, p.y);
    const touches = document.createTouchList(...[...down].map(touch));
    const event = new Event(name, { bubbles: true, cancelable: true });
    Object.defineProperties(event, {
      touches: { value: touches },
      targetTouches: { value: touches },
      changedTouches: { value: document.createTouchList(...changed.map(touch)) },
    });
    canvas.dispatchEvent(event);
  }, [type, points]);
}

/// The way to touch [page]: through [cdp] when there is one (Chromium),
/// else made in the page.
export function fingersOf(page, cdp) {
  return (type, points) => (cdp
    ? cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) })
    : madeTouch(page, type, points));
}
