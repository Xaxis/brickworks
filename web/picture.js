// A picture of your own as your avatar (docs/SOCIAL.md D11,
// supabase/avatars.sql): the picture you chose, cropped to a circle here
// before anything is sent.
//
// The dialog (#crop-dialog, profile.html; site.css .cropper) shows the
// picture in a square with the circle it will be cut to, the rest dimmed.
// Drag it, with a mouse or a finger, to place it; zoom with the two
// buttons, the wheel or two fingers; or, with the picture focused, move it
// with the arrow keys and zoom with + and −. Use this picture makes the
// square the circle sits in, at most 400 pixels a side, into a JPEG on a
// canvas, and that is what is sent: the server decodes it and makes its own
// (api/_avatars.js), so nothing of the file chosen leaves this browser but
// the pixels in that square.
//
// Refused here, before anything is sent: a file that is not a JPEG, a PNG
// or a WebP, one over 8 MB, one that does not decode, or one under 120
// pixels a side.

export const TYPES = ["image/jpeg", "image/png", "image/webp"];
export const MOST_BYTES = 8 * 1024 * 1024;
export const LEAST = 120;
export const SIDE = 400;
const MOST_ZOOM = 4;
// The canvas's own size, and the margin round the circle that shows what
// is cut away.
const VIEW = 640;
const MARGIN = 40;
const CIRCLE = VIEW - 2 * MARGIN;

/// Why [file] cannot be a picture here, in words; "" when it can.
export function pictureTrouble(file) {
  if (!file) return "Choose a picture first.";
  if (!TYPES.includes(file.type)) return "That is not a JPEG, a PNG or a WebP picture.";
  if (file.size > MOST_BYTES) return `That picture is ${(file.size / 1048576).toFixed(1)} MB: at most 8 MB, please.`;
  return "";
}

/// The picture in [file] cropped to a circle in [dialog]: {blob (a JPEG),
/// side}, or null when it was let go. Throws, in words, for a picture that
/// will not do.
export async function cropPicture(file, dialog) {
  const trouble = pictureTrouble(file);
  if (trouble) throw new Error(trouble);
  let bitmap;
  try {
    // Turned the way the phone was held, as a browser shows it.
    bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
  } catch {
    throw new Error("That picture would not open: try another.");
  }
  const { width, height } = bitmap;
  if (Math.min(width, height) < LEAST) {
    bitmap.close();
    throw new Error(`That picture is ${width} × ${height}: at least ${LEAST} pixels a side, please.`);
  }
  const canvas = dialog.querySelector("canvas");
  canvas.width = VIEW;
  canvas.height = VIEW;
  const g = canvas.getContext("2d");
  // The scale at which the picture just covers the circle's square, and
  // how far in from there; the picture's top left corner, in the canvas.
  const fit = CIRCLE / Math.min(width, height);
  let zoom = 1;
  let left = (VIEW - width * fit) / 2;
  let top = (VIEW - height * fit) / 2;
  const scale = () => fit * zoom;
  // The circle's square always covered.
  const hold = () => {
    const s = scale();
    left = Math.min(MARGIN, Math.max(VIEW - MARGIN - width * s, left));
    top = Math.min(MARGIN, Math.max(VIEW - MARGIN - height * s, top));
  };
  const draw = () => {
    g.fillStyle = "#ffffff";
    g.fillRect(0, 0, VIEW, VIEW);
    g.drawImage(bitmap, left, top, width * scale(), height * scale());
    // What is cut away, dimmed; the circle's edge.
    g.beginPath();
    g.rect(0, 0, VIEW, VIEW);
    g.arc(VIEW / 2, VIEW / 2, CIRCLE / 2, 0, Math.PI * 2, true);
    g.fillStyle = "rgba(0, 0, 0, 0.55)";
    g.fill("evenodd");
    g.beginPath();
    g.arc(VIEW / 2, VIEW / 2, CIRCLE / 2, 0, Math.PI * 2);
    g.lineWidth = 3;
    g.strokeStyle = "rgba(255, 255, 255, 0.9)";
    g.stroke();
    canvas.dataset.zoom = zoom.toFixed(2);
  };
  /// Zoomed to [to], the point [at] (canvas pixels) kept where it is.
  const zoomTo = (to, at = [VIEW / 2, VIEW / 2]) => {
    const was = scale();
    zoom = Math.min(MOST_ZOOM, Math.max(1, to));
    const now = scale();
    left = at[0] - ((at[0] - left) * now) / was;
    top = at[1] - ((at[1] - top) * now) / was;
    hold();
    draw();
  };
  const moveBy = (dx, dy) => {
    left += dx;
    top += dy;
    hold();
    draw();
  };
  /// Where an event is, in the canvas's own pixels.
  const inCanvas = (event) => {
    const box = canvas.getBoundingClientRect();
    return [((event.clientX - box.left) * VIEW) / box.width, ((event.clientY - box.top) * VIEW) / box.height];
  };
  hold();
  draw();

  // A finger or a mouse moves it; two fingers zoom.
  const down = new Map();
  let pinch = null;
  const onDown = (event) => {
    canvas.setPointerCapture(event.pointerId);
    down.set(event.pointerId, inCanvas(event));
    if (down.size === 2) {
      const [a, b] = [...down.values()];
      pinch = { apart: Math.hypot(a[0] - b[0], a[1] - b[1]), zoom };
    }
  };
  const onMove = (event) => {
    if (!down.has(event.pointerId)) return;
    const was = down.get(event.pointerId);
    const now = inCanvas(event);
    down.set(event.pointerId, now);
    if (down.size === 1) return moveBy(now[0] - was[0], now[1] - was[1]);
    if (pinch && down.size === 2) {
      const [a, b] = [...down.values()];
      zoomTo((pinch.zoom * Math.hypot(a[0] - b[0], a[1] - b[1])) / Math.max(1, pinch.apart),
        [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]);
    }
  };
  const onUp = (event) => {
    down.delete(event.pointerId);
    if (down.size < 2) pinch = null;
  };
  const onWheel = (event) => {
    event.preventDefault();
    zoomTo(zoom * Math.exp(-event.deltaY / 500), inCanvas(event));
  };
  const onKey = (event) => {
    const step = event.shiftKey ? 40 : 10;
    const moves = { ArrowLeft: [-step, 0], ArrowRight: [step, 0], ArrowUp: [0, -step], ArrowDown: [0, step] };
    if (moves[event.key]) moveBy(...moves[event.key]);
    else if (event.key === "+" || event.key === "=") zoomTo(zoom * 1.25);
    else if (event.key === "-" || event.key === "_") zoomTo(zoom / 1.25);
    else return;
    event.preventDefault();
  };
  canvas.addEventListener("pointerdown", onDown);
  canvas.addEventListener("pointermove", onMove);
  canvas.addEventListener("pointerup", onUp);
  canvas.addEventListener("pointercancel", onUp);
  canvas.addEventListener("wheel", onWheel, { passive: false });
  canvas.addEventListener("keydown", onKey);
  const zoomIn = dialog.querySelector("[data-zoom=in]");
  const zoomOut = dialog.querySelector("[data-zoom=out]");
  const inward = () => zoomTo(zoom * 1.25);
  const outward = () => zoomTo(zoom / 1.25);
  zoomIn.addEventListener("click", inward);
  zoomOut.addEventListener("click", outward);

  const use = dialog.querySelector("[data-crop=use]");
  const cancel = dialog.querySelector("[data-crop=cancel]");
  const chosen = await new Promise((resolve) => {
    const done = (value) => {
      use.removeEventListener("click", onUse);
      cancel.removeEventListener("click", onCancel);
      dialog.removeEventListener("close", onClose);
      resolve(value);
    };
    // The square the circle sits in, in the picture's own pixels.
    const onUse = () => done({ x: (MARGIN - left) / scale(), y: (MARGIN - top) / scale(), side: CIRCLE / scale() });
    const onCancel = () => done(null);
    const onClose = () => done(null);
    use.addEventListener("click", onUse);
    cancel.addEventListener("click", onCancel);
    dialog.addEventListener("close", onClose);
    dialog.showModal();
    canvas.focus();
  });
  canvas.removeEventListener("pointerdown", onDown);
  canvas.removeEventListener("pointermove", onMove);
  canvas.removeEventListener("pointerup", onUp);
  canvas.removeEventListener("pointercancel", onUp);
  canvas.removeEventListener("wheel", onWheel);
  canvas.removeEventListener("keydown", onKey);
  zoomIn.removeEventListener("click", inward);
  zoomOut.removeEventListener("click", outward);
  if (dialog.open) dialog.close();
  if (!chosen) {
    bitmap.close();
    return null;
  }
  // The square, made at most SIDE a side (never smaller than LEAST), on
  // white where the picture is clear.
  const side = Math.max(LEAST, Math.min(SIDE, Math.round(chosen.side)));
  const out = document.createElement("canvas");
  out.width = side;
  out.height = side;
  const o = out.getContext("2d");
  o.fillStyle = "#ffffff";
  o.fillRect(0, 0, side, side);
  o.imageSmoothingQuality = "high";
  o.drawImage(bitmap, chosen.x, chosen.y, chosen.side, chosen.side, 0, 0, side, side);
  bitmap.close();
  const blob = await new Promise((resolve) => out.toBlob(resolve, "image/jpeg", 0.92));
  if (!blob) throw new Error("That picture could not be made just now: try again.");
  return { blob, side };
}

/// [blob]'s bytes as base64, for the JSON the server takes.
export async function base64Of(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let text = "";
  for (let at = 0; at < bytes.length; at += 0x8000) text += String.fromCharCode(...bytes.subarray(at, at + 0x8000));
  return btoa(text);
}
