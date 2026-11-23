// The model in 3D in its picture's place (viewer369): on a model's page,
// a set's page and the embed (web/embed.js). /viewer3d.js (inline.js,
// three.js) is asked for only once it opens. Looks: web/view3d.css.
// Every byte here is the embed's too: tools/web/embed_flow.mjs holds its
// scripts under 24 KB, comments and all, so these stay short.

// [words] in the page's language (theme.js), {name}s from [values]: not
// imported, as the embed loads this and theme.js alone.
const say = (words, values = {}) => (globalThis.brickworksLang ? globalThis.brickworksLang.say(words) : words)
  .replace(/\{(\w+)\}/g, (all, name) => (name in values ? String(values[name]) : all));

/// The 3D view over [big], the picture (a link to the app): a click, Enter
/// or a drag opens it in the picture's frame (a key held, the app's tab), the
/// frame saying how far it has got. {open(how, changesOn), close(),
/// pinsChanged(), showPin(id, how), light(index)}: [changesOn] opens a
/// remix's What changed (data-changes); [pins], a model page's, go to
/// inline.js open3d as they are.
export function start3d(big, pins = {}) {
  // The model's name, from the picture's label as its page wrote it.
  const label = big.getAttribute("aria-label") || "";
  const [before, after = ""] = say("View {name} in 3D").split("{name}");
  const name = (label.length > before.length + after.length && label.startsWith(before) && label.endsWith(after)
    ? label.slice(before.length, label.length - after.length) : label) || say("The model");
  big.setAttribute("role", "button");
  big.setAttribute("aria-label", say("View {name} in 3D, here", { name }));
  big.setAttribute("draggable", "false");
  const img = big.querySelector("img");
  if (img) img.draggable = false;
  let shell = null;
  let viewing = null;
  let pointer = "";
  const open = (how, changesOn = false) => {
    if (shell && !shell.hidden) {
      if (changesOn && viewing) viewing.then((view) => view && view.changes(true));
      return;
    }
    if (viewing) {
      shell.hidden = false;
      viewing.then((view) => {
        if (!view) return;
        view.open();
        if (changesOn) view.changes(true);
      });
      return;
    }
    const asked = Math.round(performance.now());
    shell = document.createElement("div");
    shell.className = "view3d";
    shell.dataset.state = "loading";
    shell.setAttribute("aria-busy", "true");
    shell.innerHTML = '<div class="stage" tabindex="0" role="application"></div>'
      + '<div class="view3d-bar" aria-hidden="true"><span></span></div><p class="view3d-said" role="status"></p>';
    shell.querySelector(".stage").setAttribute("aria-roledescription", say("3D view"));
    shell.querySelector(".stage").setAttribute("aria-label", say("{name} in 3D", { name }));
    shell.querySelector(".view3d-said").textContent = say("Getting the model in 3D…");
    shell.dataset.how = how;
    // An old picture's own ground: the 3D view drawn on it too, so nothing jumps.
    if (img && img.complete && img.naturalWidth && opaqueCorners(img)) shell.dataset.ground = "render";
    big.after(shell);
    const closed = () => { big.focus({ preventScroll: true }); };
    viewing = import("/viewer3d.js")
      .then((made) => made.open3d(shell, { ...pins, scene: big.dataset.scene, name, app: big.getAttribute("href"), how,
        look: big.dataset.scene.startsWith("/library/") ? "corner" : "app", timings: { asked }, closed,
        changes: big.dataset.changes || "", changesOn }))
      .catch(() => {
        // Not even the code came: said, and asked again on the next try.
        shell.dataset.state = "failed";
        shell.querySelector(".view3d-said").textContent = say("The 3D view could not load. The picture is still here; try again in a moment.");
        shell.setAttribute("aria-busy", "false");
        viewing = null;
        setTimeout(() => { if (shell && shell.dataset.state === "failed") { shell.remove(); shell = null; } }, 6000);
        return null;
      });
  };
  big.addEventListener("pointerdown", (event) => { pointer = event.pointerType || "mouse"; });
  big.addEventListener("click", (event) => {
    if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    open(event.detail === 0 ? "key" : event.pointerType || pointer || "mouse");
  });
  big.addEventListener("keydown", (event) => {
    if (event.key !== " ") return;
    event.preventDefault();
    open("key");
  });
  // The first drag across: a mouse's at once, a finger's once it goes
  // across (up or down scrolls the page).
  big.addEventListener("dragstart", (event) => { event.preventDefault(); open("mouse"); });
  let from = null;
  big.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "touch") from = { x: event.clientX, y: event.clientY };
  });
  big.addEventListener("pointermove", (event) => {
    if (!from) return;
    const dx = event.clientX - from.x;
    if (Math.abs(dx) > 12 && Math.abs(dx) > Math.abs(event.clientY - from.y)) {
      from = null;
      open("touch");
    }
  });
  for (const kind of ["pointerup", "pointercancel"]) big.addEventListener(kind, () => { from = null; });
  const later = (run) => viewing && viewing.then((view) => view && run(view));
  return {
    open,
    close: () => later((view) => view.close()),
    pinsChanged: () => later((view) => view.pinsChanged?.()),
    // A pin pressed on the page: the view opened, then turned to its part.
    showPin: (id, how = "mouse") => {
      if (!shell || shell.hidden) open(how);
      later((view) => view.showPin?.(id));
    },
    light: (index) => later((view) => view.light?.(index)),
  };
}

/// Whether [img]'s four corners are opaque: its own ground, not a cut-out.
function opaqueCorners(img) {
  const w = 60;
  const h = Math.max(1, Math.round((w * img.naturalHeight) / img.naturalWidth));
  const pen = Object.assign(document.createElement("canvas"), { width: w, height: h }).getContext("2d", { willReadFrequently: true });
  try {
    pen.drawImage(img, 0, 0, w, h);
    return [[0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1]].every(([x, y]) => pen.getImageData(x, y, 1, 1).data[3] > 200);
  } catch {
    return false;
  }
}
