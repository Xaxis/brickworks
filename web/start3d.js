// The model in 3D in its picture's place, the way in (viewer369,
// 2026-10-30): a model's page (web/model-page.js), a set's page, and the
// embed somebody else's page frames (/m/<id>/embed, web/embed.js). The
// picture is a link to the app; with this, a click on it (or Enter, or the
// first drag across it) opens the 3D view over it instead, and only then
// is /viewer3d.js (tools/viewer/inline.js, three.js and all) asked for.
// Its looks are web/view3d.css.

/// The model in 3D over [big], the picture, which without this script is
/// the way into the app: a click on it (or Enter, or a drag across it)
/// opens the 3D view in its frame instead; with a key held, a new tab is
/// still the app's, as a link is. Until three.js and the model come, the
/// frame says so and how far it has got; nothing moves, since the view is
/// the picture's own shape over it (web/view3d.css .view3d). {open(how),
/// close()} for the page.
export function start3d(big) {
  const name = big.getAttribute("aria-label")?.replace(/^View (.*) in 3D$/, "$1") || "The model";
  big.setAttribute("role", "button");
  big.setAttribute("aria-label", `View ${name} in 3D, here`);
  big.setAttribute("draggable", "false");
  const img = big.querySelector("img");
  if (img) img.draggable = false;
  let shell = null;
  let viewing = null;
  let pointer = "";
  const open = (how) => {
    if (shell && !shell.hidden) return;
    if (viewing) {
      shell.hidden = false;
      viewing.then((view) => view && view.open());
      return;
    }
    const asked = Math.round(performance.now());
    shell = document.createElement("div");
    shell.className = "view3d";
    shell.dataset.state = "loading";
    shell.setAttribute("aria-busy", "true");
    shell.innerHTML = '<div class="stage" tabindex="0" role="application" aria-roledescription="3D view"></div>'
      + '<div class="view3d-bar" aria-hidden="true"><span></span></div><p class="view3d-said" role="status">Getting the model in 3D…</p>';
    shell.querySelector(".stage").setAttribute("aria-label", `${name} in 3D`);
    shell.dataset.how = how;
    // A picture published before cut-outs carries the ground it was drawn
    // on: the model in 3D is put on that ground too, so nothing jumps.
    if (img && img.complete && img.naturalWidth && opaqueCorners(img)) shell.dataset.ground = "render";
    big.after(shell);
    const closed = () => { big.focus({ preventScroll: true }); };
    viewing = import("/viewer3d.js")
      .then((made) => made.open3d(shell, { scene: big.dataset.scene, name, app: big.getAttribute("href"), how,
        look: big.dataset.scene.startsWith("/library/") ? "corner" : "app", timings: { asked }, closed }))
      .catch(() => {
        // Not even the code came: said, and asked again on the next try.
        shell.dataset.state = "failed";
        shell.querySelector(".view3d-said").textContent = "The 3D view could not load. The picture is still here; try again in a moment.";
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
  // The first drag across it: a mouse's as it starts, a finger's once it
  // goes across (up or down, the page scrolls: directory.css touch-action).
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
  return { open, close: () => viewing && viewing.then((view) => view && view.close()) };
}

/// Whether [img] is opaque at its four corners: a picture drawn on a ground
/// of its own, not a cut-out.
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
