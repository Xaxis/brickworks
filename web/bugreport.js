// Report a bug, from any page of the site, one press (bugreport, 2026-11-09):
// window.brickworksReportBug({source: "site"}), which the beta bar's Report a
// bug calls (web/betabar.js loads this on its first press), and anything
// else that offers it.
//
// It opens over the page, never a page of its own: the person is in the
// middle of something, and the report is about that. Before the dialog
// covers the page, the page is pictured by itself (pagePicture), with no
// question from the browser: the browser's own capture asks which tab to
// share, a step a person reporting a bug stops at, so the page is drawn
// here from what it shows (each element's background, border, words and
// pictures, where the browser laid them out), as Vercel's toolbar and
// Sentry's feedback widget draw theirs. The report itself is
// web/feedback.js's dialog in its report mode: the kind (a bug chosen),
// what happened and what was expected, the picture to mark the spot on,
// and what goes with it, said in a line before it goes.
//
// Reports are an account's (everyone who uses Brickworks has one): signed
// out, the sign-in comes first, then the report.
import { askToSignIn, signedIn } from "/account.js";

// The picture is drawn at most this wide, as feedback.js sends it.
const WIDEST = 1600;
// What drawing the page may take, at most: past it, what is drawn goes.
const BUDGET_MS = 1500;
const MOST_ELEMENTS = 6000;

const clear = (colour) => !colour || colour === "transparent" || /rgba?\([^)]*,\s*0\)$/.test(colour)
  || /\/\s*0\)$/.test(colour);
const px = (value) => parseFloat(value) || 0;

/// The first colour of a gradient, as near as a sketch needs.
function gradientColour(image) {
  const found = /(rgba?\([^)]*\)|#[0-9a-f]{3,8}\b|oklch\([^)]*\)|color\([^)]*\))/i.exec(image || "");
  return found ? found[1] : "";
}

/// Whether [url] is this site's own (or made in the page), so drawing it
/// leaves the picture readable: another site's picture would lock it.
function ours(url) {
  try {
    const at = new URL(url, location.href);
    return at.origin === location.origin || at.protocol === "data:" || at.protocol === "blob:";
  } catch {
    return false;
  }
}

/// Whether a canvas of the page may be drawn into the picture: one holding
/// another site's picture would lock it.
function readable(canvas) {
  try {
    const probe = document.createElement("canvas");
    probe.width = 1;
    probe.height = 1;
    const context = probe.getContext("2d");
    context.drawImage(canvas, 0, 0, 1, 1);
    context.getImageData(0, 0, 1, 1);
    return true;
  } catch {
    return false;
  }
}

function fontOf(style) {
  return `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
}

function cased(words, transform) {
  if (transform === "uppercase") return words.toUpperCase();
  if (transform === "lowercase") return words.toLowerCase();
  if (transform === "capitalize") return words.replace(/(^|\s)(\p{L})/gu, (all, gap, first) => gap + first.toUpperCase());
  return words;
}

function roundedPath(context, rect, style) {
  const radius = Math.min(px(style.borderTopLeftRadius), rect.width / 2, rect.height / 2);
  context.beginPath();
  if (radius > 0.5 && context.roundRect) context.roundRect(rect.left, rect.top, rect.width, rect.height, radius);
  else context.rect(rect.left, rect.top, rect.width, rect.height);
}

/// [element]'s own box: its background, and its border.
function box(context, element, style, rect) {
  const fill = clear(style.backgroundColor) ? gradientColour(style.backgroundImage) : style.backgroundColor;
  if (fill && !clear(fill)) {
    context.fillStyle = fill;
    roundedPath(context, rect, style);
    context.fill();
  }
  const sides = ["Top", "Bottom", "Left", "Right"];
  const widths = sides.map((side) => (style[`border${side}Style`] === "none" ? 0 : px(style[`border${side}Width`])));
  const colours = sides.map((side) => style[`border${side}Color`]);
  const even = widths.every((w) => w === widths[0]) && colours.every((c) => c === colours[0]);
  if (even && widths[0] > 0 && !clear(colours[0]) && px(style.borderTopLeftRadius) > 0.5) {
    context.strokeStyle = colours[0];
    context.lineWidth = widths[0];
    const inset = widths[0] / 2;
    roundedPath(context, { left: rect.left + inset, top: rect.top + inset, width: rect.width - widths[0],
      height: rect.height - widths[0] }, style);
    context.stroke();
    return;
  }
  const strips = [[rect.left, rect.top, rect.width, widths[0]], [rect.left, rect.bottom - widths[1], rect.width, widths[1]],
    [rect.left, rect.top, widths[2], rect.height], [rect.right - widths[3], rect.top, widths[3], rect.height]];
  strips.forEach((strip, n) => {
    if (widths[n] <= 0 || clear(colours[n])) return;
    context.fillStyle = colours[n];
    context.fillRect(...strip);
  });
}

/// A picture, a video or a canvas of the page, fitted as the page fits it.
function picture(context, element, style, rect) {
  const media = element;
  const wide = media.naturalWidth || media.videoWidth || media.width;
  const tall = media.naturalHeight || media.videoHeight || media.height;
  if (!wide || !tall || rect.width < 1 || rect.height < 1) return;
  if (element instanceof HTMLImageElement && (!element.complete || !ours(element.currentSrc || element.src))) return;
  if (element instanceof HTMLVideoElement && !ours(element.currentSrc || element.src)) return;
  if (element instanceof HTMLCanvasElement && !readable(element)) return;
  let [x, y, w, h] = [rect.left, rect.top, rect.width, rect.height];
  const fit = style.objectFit;
  if (fit === "contain" || fit === "cover") {
    const scale = (fit === "contain" ? Math.min : Math.max)(rect.width / wide, rect.height / tall);
    w = wide * scale;
    h = tall * scale;
    x = rect.left + (rect.width - w) / 2;
    y = rect.top + (rect.height - h) / 2;
  }
  context.save();
  roundedPath(context, rect, style);
  context.clip();
  try {
    context.drawImage(media, x, y, w, h);
  } catch {
    // Not drawable after all (a picture still decoding): left out.
  }
  context.restore();
}

/// A text box's, a choice's or a list's own words.
function field(context, element, style, rect) {
  const type = (element.type || "").toLowerCase();
  if (type === "checkbox" || type === "radio") {
    context.strokeStyle = style.color;
    context.lineWidth = 1.5;
    context.beginPath();
    if (type === "radio") context.arc(rect.left + rect.width / 2, rect.top + rect.height / 2, Math.min(rect.width, rect.height) / 2 - 1, 0, 7);
    else context.rect(rect.left + 1, rect.top + 1, rect.width - 2, rect.height - 2);
    context.stroke();
    if (element.checked) {
      context.fillStyle = style.accentColor && style.accentColor !== "auto" ? style.accentColor : style.color;
      context.beginPath();
      if (type === "radio") context.arc(rect.left + rect.width / 2, rect.top + rect.height / 2, Math.min(rect.width, rect.height) / 4, 0, 7);
      else context.rect(rect.left + 3, rect.top + 3, rect.width - 6, rect.height - 6);
      context.fill();
    }
    return;
  }
  if (type === "hidden" || type === "file") return;
  // A field's own words: what is typed, never a password's.
  const words = type === "password" ? "•".repeat(Math.min(12, element.value.length))
    : element instanceof HTMLSelectElement ? element.selectedOptions[0]?.textContent || ""
      : element.value || element.placeholder || "";
  if (!words) return;
  context.save();
  context.beginPath();
  context.rect(rect.left, rect.top, rect.width, rect.height);
  context.clip();
  context.font = fontOf(style);
  context.fillStyle = element.value ? style.color : "rgba(128,128,128,0.9)";
  context.textBaseline = "middle";
  const left = rect.left + px(style.paddingLeft) + px(style.borderLeftWidth);
  if (element instanceof HTMLTextAreaElement) {
    const line = px(style.lineHeight) || px(style.fontSize) * 1.3;
    words.split("\n").forEach((one, n) => context.fillText(one, left, rect.top + px(style.paddingTop) + line * (n + 0.5)));
  } else {
    context.fillText(words, left, rect.top + rect.height / 2);
  }
  context.restore();
}

/// A run of words where the browser laid each one out.
function words(context, node, style, view, range) {
  const text = node.data;
  if (!/\S/.test(text)) return;
  context.font = fontOf(style);
  context.fillStyle = style.color;
  context.textBaseline = "alphabetic";
  if ("letterSpacing" in context) context.letterSpacing = style.letterSpacing === "normal" ? "0px" : style.letterSpacing;
  const metric = context.measureText("Hg");
  const ascent = metric.fontBoundingBoxAscent ?? px(style.fontSize) * 0.8;
  const descent = metric.fontBoundingBoxDescent ?? px(style.fontSize) * 0.2;
  const each = /\S+/g;
  let found;
  while ((found = each.exec(text))) {
    range.setStart(node, found.index);
    range.setEnd(node, found.index + found[0].length);
    const rects = range.getClientRects();
    if (!rects.length) continue;
    const at = rects[0];
    if (at.bottom < 0 || at.top > view.height || at.right < 0 || at.left > view.width) continue;
    context.fillText(cased(found[0], style.textTransform), at.left,
      at.top + (at.height - (ascent + descent)) / 2 + ascent);
  }
}

/// The page as it is in the window now, drawn by itself: {canvas, blob}, a
/// JPEG at most WIDEST pixels wide. [leave]: elements left out (a dialog
/// about to open). Never asks anything, never sends anything.
export async function pagePicture({ leave = [] } = {}) {
  await document.fonts?.ready;
  const view = { width: document.documentElement.clientWidth || innerWidth, height: innerHeight };
  const scale = Math.min(devicePixelRatio || 1, 2, WIDEST / view.width);
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(view.width * scale);
  canvas.height = Math.round(view.height * scale);
  const context = canvas.getContext("2d");
  context.scale(scale, scale);
  const root = getComputedStyle(document.documentElement);
  const body = getComputedStyle(document.body);
  context.fillStyle = !clear(body.backgroundColor) ? body.backgroundColor
    : !clear(root.backgroundColor) ? root.backgroundColor : "#ffffff";
  context.fillRect(0, 0, view.width, view.height);
  const range = document.createRange();
  const left = new Set(leave);
  const started = performance.now();
  let drawn = 0;
  // What is fixed, stuck or in the top layer (the header, a bar, an open
  // dialog) goes over the rest, as the page shows it.
  const over = [];

  const paint = (element, alpha, top) => {
    if (left.has(element) || drawn > MOST_ELEMENTS || performance.now() - started > BUDGET_MS) return;
    if (/^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|LINK|META|HEAD)$/.test(element.tagName)) return;
    // Not drawn by the browser either: display none, or inside a closed
    // <details> (the site's menus) or what content-visibility skips.
    if (element.checkVisibility && !element.checkVisibility()) return;
    const holder = element.parentElement;
    if (holder?.tagName === "DETAILS" && !holder.open && element.tagName !== "SUMMARY") return;
    const style = getComputedStyle(element);
    if (style.display === "none") return;
    const shown = alpha * (parseFloat(style.opacity) || (style.opacity === "0" ? 0 : 1));
    if (shown <= 0.02) return;
    if (!top && (style.position === "fixed" || style.position === "sticky"
      || (element.tagName === "DIALOG" && element.open))) {
      over.push([element, alpha]);
      return;
    }
    const rect = element.getBoundingClientRect();
    const sized = rect.width > 0 || rect.height > 0;
    if (sized && style.display !== "contents"
      && (rect.bottom < 0 || rect.top > view.height || rect.right < 0 || rect.left > view.width)) return;
    drawn += 1;
    context.save();
    context.globalAlpha = shown;
    const visible = style.visibility !== "hidden" && style.visibility !== "collapse";
    if (visible && sized && style.display !== "contents") {
      box(context, element, style, rect);
      if (element instanceof HTMLImageElement || element instanceof HTMLCanvasElement
        || element instanceof HTMLVideoElement) picture(context, element, style, rect);
      if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement
        || element instanceof HTMLSelectElement) field(context, element, style, rect);
    }
    // What overflows a clipped box is not seen.
    if (sized && (style.overflowX !== "visible" || style.overflowY !== "visible")) {
      roundedPath(context, rect, style);
      context.clip();
    }
    if (!(element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement
      || element instanceof HTMLSelectElement)) {
      for (const child of element.childNodes) {
        if (child.nodeType === Node.TEXT_NODE) {
          if (visible) words(context, child, style, view, range);
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          paint(child, shown, false);
        }
      }
    }
    context.restore();
  };

  paint(document.body, 1, false);
  for (let n = 0; n < over.length; n += 1) {
    const [element, alpha] = over[n];
    paint(element, alpha, true);
  }
  const blob = await new Promise((done) => canvas.toBlob(done, "image/jpeg", 0.85));
  if (!blob) throw new Error("no picture");
  return { canvas, blob };
}

let opening = null;

/// Report a bug, over this page: signed in first if need be, the page
/// pictured, then the report (web/feedback.js). [source]: "site" for the
/// site's pages; [from], where on them it was asked from, kept with the
/// report. Resolves with the dialog, or null when the sign-in was closed.
export function reportBug({ source = "site", from = "bar", kind = "bug" } = {}) {
  if (opening) return opening;
  opening = (async () => {
    if (!signedIn() && !(await askToSignIn("Sign in to report a bug: your reports, and our answers, are kept with your account."))) {
      return null;
    }
    let shot = null;
    try {
      shot = await pagePicture();
    } catch {
      // A page that cannot be drawn: the report goes without, or with one
      // chosen.
    }
    const { openFeedback } = await import("/feedback.js");
    return openFeedback({ kind, report: true, picture: shot, from: String(from || source).slice(0, 40) });
  })().finally(() => {
    opening = null;
  });
  return opening;
}

window.brickworksReportBug = reportBug;
