// A card's model turning in 3D in its picture's place while a mouse rests on
// it (sitebold, 2026-11-23): the gallery's pick of the week, as the home's
// feed turns its posts. Drawn by the site's own viewer (web/viewer3d.js,
// tools/viewer/inline.js), asked for only on the first such hover, with its
// looks (web/view3d.css, the .showcase place). A drag turns it by hand and
// its tools work as on a model's page; the pointer leaving puts the picture
// back. Never by touch (a tap is the card's link), nor for somebody who asked
// for less motion.
import { appAt, say } from "/card.js";

const REST_MS = 700;
const fine = matchMedia("(hover: hover) and (pointer: fine)");
const still = matchMedia("(prefers-reduced-motion: reduce)");
let styled = false;

/// [card]'s picture ([frame], its .frame) turns its model, [id], in 3D
/// while a mouse rests on it. Nothing is asked for until it does. The
/// card's link is stretched over all of it (site.css .model .open), so the
/// pointer is followed on the card and held to the picture's box.
export function turnOnHover(card, frame, { id, name }) {
  if (!/^[A-Za-z0-9]{10}$/.test(String(id || "")) || !fine.matches || still.matches) return;
  let resting = null;
  let turning = null;

  const close = () => {
    if (!turning) return;
    const { shell, view } = turning;
    turning = null;
    view.then((one) => one && one.close()).catch(() => null);
    shell.remove();
    frame.classList.remove("showcase", "turning");
  };

  const open = () => {
    if (turning) return;
    if (!styled) {
      styled = true;
      const sheet = Object.assign(document.createElement("link"), { rel: "stylesheet", href: "/view3d.css" });
      document.head.append(sheet);
    }
    frame.classList.add("showcase", "turning");
    const shell = document.createElement("div");
    shell.className = "view3d";
    shell.dataset.state = "loading";
    shell.dataset.how = "mouse";
    shell.setAttribute("aria-busy", "true");
    shell.innerHTML = '<div class="stage" tabindex="0" role="application"></div>'
      + '<div class="view3d-bar" aria-hidden="true"><span></span></div><p class="view3d-said" role="status"></p>';
    shell.querySelector(".stage").setAttribute("aria-roledescription", say("3D view"));
    shell.querySelector(".stage").setAttribute("aria-label", say("{name} in 3D", { name }));
    shell.querySelector(".view3d-said").textContent = say("Getting the model in 3D…");
    frame.append(shell);
    const asked = Math.round(performance.now());
    const view = import("/viewer3d.js")
      .then((made) => made.open3d(shell, { scene: `/m/${id}/scene.json`, name, app: appAt(`view=${id}`), how: "mouse", look: "app",
        spin: true, timings: { asked }, closed: () => { if (turning?.shell === shell) close(); } }))
      .catch(() => {
        shell.dataset.state = "failed";
        shell.querySelector(".view3d-said").textContent = say("The 3D view could not load. The picture is still here; try again in a moment.");
        setTimeout(() => { if (turning?.shell === shell) close(); }, 4000);
        return null;
      });
    turning = { shell, view };
    // Turning on its own once drawn, until it is taken hold of: a viewer
    // that does not take spin from its caller is set turning here.
    new MutationObserver((changes, watching) => {
      if (shell.dataset.state !== "ready") return;
      watching.disconnect();
      const drawn = window.brickworks3d?.view;
      if (turning?.shell !== shell || !drawn?.controls || drawn.controls.autoRotate || drawn.interacted) return;
      drawn.controls.autoRotate = true;
      drawn.controls.autoRotateSpeed = 1.6;
      drawn.render();
    }).observe(shell, { attributes: true, attributeFilter: ["data-state"] });
  };

  const away = () => {
    clearTimeout(resting);
    resting = null;
    close();
  };
  card.addEventListener("pointermove", (event) => {
    if (event.pointerType !== "mouse") return;
    const box = frame.getBoundingClientRect();
    const over = event.clientX >= box.left && event.clientX < box.right && event.clientY >= box.top && event.clientY < box.bottom;
    if (!over) away();
    else if (!turning && !resting) resting = setTimeout(() => { resting = null; open(); }, REST_MS);
  });
  card.addEventListener("pointerleave", away);
}
