// Send feedback, from any page of the site (beta374, 2026-10-30): the
// footer's Send feedback and the account menu's (a[data-feedback], heard by
// web/follow.js, which loads this when one is pressed), and /feedback. And
// Report a bug (bugreport, 2026-11-09): the same dialog in its report mode,
// opened by web/bugreport.js with the page already pictured.
//
// A bug, an idea or a question, a few words, and what the person chooses
// to send with it, each shown before it goes and each taken off again:
//
//   a picture   of this page (the browser asks which tab to share, this
//               one first, and the dialog steps aside for it), or one they
//               choose. Drawn again here at most 1600 pixels wide as a
//               JPEG, which also leaves behind whatever the file carried
//               besides the picture (where a photo was taken). A report
//               has the page's picture already, drawn by bugreport.js, shown
//               large, and a drag on it marks the spot with a box, drawn
//               into the picture where it was drawn.
//   details     with their tick: this page's address and the window's
//               size, and the browser's name. A report ticks it, as VS
//               Code's Report Issue ticks its system information; the line
//               "What will be sent" says so with the rest before it goes.
//
// Signed in, the account sends it and the report is on /settings with
// where it stands and the answer; signed out, an address to answer at is
// asked for (a report is an account's: bugreport.js signs in first).
// POST /api/plans?op=feedback (api/_feedback.js). After a report: its
// number, and Your reports, where it is followed (as Linear and GitHub say
// where a new issue is).
//
// Everything here is put on the page as text.
import { call, signedIn } from "/account.js";
import { langAt, number, say, told } from "/card.js";

const KINDS = [["bug", () => say("Something is wrong")], ["idea", () => say("An idea")], ["question", () => say("A question")]];
// A report's title and first question for each kind.
const REPORT_TITLES = { bug: () => say("Report a bug"), idea: () => say("Share an idea"), question: () => say("Ask a question") };
const REPORT_ASKS = { bug: () => say("What happened?"), idea: () => say("What would you like?"),
  question: () => say("What would you like to ask?") };
const WIDEST = 1600;
const MOST_WORDS = 4000;
const MOST_EXPECTED = 2000;
// Marks on a report's picture: at most this many, a drag shorter than this
// (in the page's pixels) a tap, and the mark iOS's system red with a white
// halo, about as thick as it looks, as the app draws it (PictureMarks).
const MOST_MARKS = 6;
const LEAST_DRAG = 6;
const MARK = "#ff3b30";
const HALO = "#ffffff";

const el = (tag, props = {}, ...children) => {
  const made = Object.assign(document.createElement(tag), props);
  made.append(...children);
  return made;
};

/// The browser, in a few words: its name and version, and the system.
function browserOf() {
  const agent = navigator.userAgent;
  const named = /(Firefox|Edg|OPR|Chrome|Version)\/(\d+)/.exec(agent);
  const name = !named ? "" : { Edg: "Edge", OPR: "Opera", Version: "Safari" }[named[1]] || named[1];
  const system = /Windows|Mac OS X|Android|iPhone|iPad|Linux|CrOS/.exec(agent)?.[0]?.replace(/^Mac OS X$/, "macOS") || "";
  return [name && `${name} ${named[2]}`, system].filter(Boolean).join(", ");
}

/// [source] (an image, a video or an ImageBitmap) drawn at most WIDEST wide:
/// {canvas, blob} as a JPEG.
async function redrawn(source, width, height) {
  const scale = Math.min(1, WIDEST / width);
  const canvas = el("canvas", { width: Math.round(width * scale), height: Math.round(height * scale) });
  canvas.getContext("2d").drawImage(source, 0, 0, canvas.width, canvas.height);
  const blob = await new Promise((done) => canvas.toBlob(done, "image/jpeg", 0.85));
  if (!blob) throw new Error("no picture");
  return { canvas, blob };
}

const base64Of = (blob) => new Promise((done, failed) => {
  const reader = new FileReader();
  reader.onload = () => done(String(reader.result).replace(/^data:[^,]*,/, ""));
  reader.onerror = () => failed(reader.error);
  reader.readAsDataURL(blob);
});

/// A mark drawn into [context] at [box] ({x, y, w, h}, the picture's
/// pixels): its own edge red, [thick] pixels inside it, a pixel of white
/// either side, as PictureMarks.marked draws it in the app.
function ring(context, box, thick) {
  const frame = (x, y, w, h, t, colour) => {
    if (w <= 0 || h <= 0) return;
    const d = Math.min(t, w, h);
    context.fillStyle = colour;
    context.fillRect(x, y, w, d);
    context.fillRect(x, y + h - d, w, d);
    context.fillRect(x, y, d, h);
    context.fillRect(x + w - d, y, d, h);
  };
  frame(box.x - 1, box.y - 1, box.w + 2, box.h + 2, 1, HALO);
  frame(box.x, box.y, box.w, box.h, thick, MARK);
  frame(box.x + thick, box.y + thick, box.w - 2 * thick, box.h - 2 * thick, 1, HALO);
}

/// A report's picture to mark the spot on: {view, marks, clear, marked}.
/// [made]: {canvas, blob}. A drag on [view] draws a box; [changed] is
/// called with the count after each.
function markable(made, changed) {
  const picture = made.canvas;
  const view = el("canvas", { width: picture.width, height: picture.height, className: "marking" });
  view.setAttribute("role", "img");
  view.setAttribute("aria-label", say("The picture of the page that goes with the report. Drag on it to mark the spot."));
  const context = view.getContext("2d");
  // About 2 of the page's pixels as it is shown here, at least 3 of the
  // picture's: thick enough to see in the dialog and in the inbox.
  const thickNow = () => Math.max(3, Math.round(2 * picture.width / (view.getBoundingClientRect().width || picture.width)));
  let thick = 3;
  const marks = [];
  let drag = null;
  const draw = () => {
    context.drawImage(picture, 0, 0);
    for (const box of marks) ring(context, box, thick);
    if (drag) ring(context, boxOf(drag.from, drag.to), thick);
  };
  // Where on the picture itself: inside its border, each way at its own
  // scale (the border box's shape is not quite the picture's).
  const at = (event) => {
    const shown = view.getBoundingClientRect();
    const x = (event.clientX - shown.left - view.clientLeft) * (picture.width / (view.clientWidth || 1));
    const y = (event.clientY - shown.top - view.clientTop) * (picture.height / (view.clientHeight || 1));
    return { x: Math.round(Math.min(Math.max(x, 0), picture.width)), y: Math.round(Math.min(Math.max(y, 0), picture.height)),
      cx: event.clientX, cy: event.clientY };
  };
  const boxOf = (a, b) => ({ x: Math.min(a.x, b.x), y: Math.min(a.y, b.y), w: Math.abs(b.x - a.x), h: Math.abs(b.y - a.y) });
  view.addEventListener("pointerdown", (event) => {
    if (event.button !== 0 || marks.length >= MOST_MARKS) return;
    event.preventDefault();
    view.setPointerCapture(event.pointerId);
    // Measured as the first box starts, once the picture is laid out.
    if (!marks.length) thick = thickNow();
    drag = { from: at(event), to: at(event) };
  });
  view.addEventListener("pointermove", (event) => {
    if (!drag) return;
    drag.to = at(event);
    draw();
  });
  const end = (event, keep) => {
    if (!drag) return;
    drag.to = at(event);
    const long = Math.min(Math.abs(drag.to.cx - drag.from.cx), Math.abs(drag.to.cy - drag.from.cy));
    const box = boxOf(drag.from, drag.to);
    drag = null;
    if (keep && long >= LEAST_DRAG && box.w >= 2 && box.h >= 2) marks.push(box);
    draw();
    changed(marks.length);
  };
  view.addEventListener("pointerup", (event) => end(event, true));
  view.addEventListener("pointercancel", (event) => end(event, false));
  draw();
  return {
    view, marks,
    clear() {
      marks.length = 0;
      draw();
      changed(0);
    },
    /// The picture as it goes: the marks drawn into it, as a JPEG.
    async marked() {
      if (!marks.length) return made.blob;
      const out = el("canvas", { width: picture.width, height: picture.height });
      const drawn = out.getContext("2d");
      drawn.drawImage(picture, 0, 0);
      for (const box of marks) ring(drawn, box, thick);
      const blob = await new Promise((done) => out.toBlob(done, "image/jpeg", 0.85));
      if (!blob) throw new Error("no picture");
      return blob;
    },
    words: () => marks.map((box) => `${box.x},${box.y},${box.w},${box.h}`).join(";"),
  };
}

/// The dialog. [kind]: the one chosen at first, if any. [report]: Report a
/// bug's mode, with [picture] ({canvas, blob}) the page as it was and
/// [from] where it was asked from (bugreport.js).
export function openFeedback({ kind = "", report = false, picture: given = null, from = "" } = {}) {
  const signed = signedIn();
  const dialog = el("dialog", { className: report ? "sign-in feedback report" : "sign-in feedback" });
  const title = el("h2", { id: "feedback-title", textContent: report ? REPORT_TITLES[kind || "bug"]() : say("Send feedback") });
  dialog.setAttribute("aria-labelledby", title.id);
  const said = el("p", { textContent: report ? say("Tell us what went wrong. We read every report ourselves.")
    : say("Tell us what is wrong, what you would like, or ask us anything. We read every one ourselves.") });
  const form = el("form", { noValidate: false });

  const kinds = el("fieldset", { className: "kinds" }, el("legend", { textContent: say("What is it") }));
  for (const [value, saying] of KINDS) {
    const box = el("input", { type: "radio", name: "kind", value, required: true, checked: value === kind });
    kinds.append(el("label", { className: "choice" }, box, ` ${saying()}`));
  }
  const words = el("textarea", { name: "words", rows: report ? 4 : 5, maxLength: MOST_WORDS, required: true });
  const asking = el("span", { textContent: report ? REPORT_ASKS[kind || "bug"]() : say("What happened, or what would you like?") });
  const wordsLabel = el("label", {}, asking, words);
  // What was expected: a bug's alone, in a report.
  const expected = el("textarea", { name: "expected", rows: 2, maxLength: MOST_EXPECTED });
  const expectedLabel = el("label", { className: "expected" }, say("What did you expect to happen? (optional)"), expected);
  expectedLabel.hidden = !report || (kind || "bug") !== "bug";
  const address = el("input", { type: "email", name: "email", autocomplete: "email", required: true, maxLength: 254 });
  const addressLabel = el("label", {}, say("Your email, so we can answer"), address);
  addressLabel.hidden = signed;
  address.disabled = signed;

  // What goes with it.
  const sent = el("fieldset", { className: "attach" }, el("legend", { textContent: say("Send with it") }));
  let picture = null;
  let marking = null;
  const shown = el("figure", { className: "attached", hidden: true });
  const caption = el("figcaption");
  const remove = el("button", { type: "button", className: "cta ghost small", textContent: say("Remove the picture") });
  shown.append(caption, remove);
  // A report's: large, to mark the spot on.
  const marked = el("figure", { className: "marked", hidden: true });
  const markWords = el("figcaption");
  const clearMarks = el("button", { type: "button", className: "cta ghost small", textContent: say("Clear the marks") });
  const leave = el("button", { type: "button", className: "cta ghost small", textContent: say("Leave the picture out") });
  const markRow = el("div", { className: "actions" }, clearMarks, leave);
  marked.append(markWords, markRow);
  const choose = el("input", { type: "file", accept: "image/png,image/jpeg,image/webp", className: "visually-hidden" });
  choose.setAttribute("aria-label", say("Choose a picture"));
  const capture = el("button", { type: "button", className: "cta ghost small", textContent: say("Picture of this page") });
  capture.hidden = report || !navigator.mediaDevices?.getDisplayMedia;
  const pick = el("button", { type: "button", className: "cta ghost small", textContent: say("Choose a picture…") });
  const adding = el("div", { className: "actions" }, capture, pick, choose);
  const page = `${location.pathname}${location.search}`.slice(0, 300);
  const size = `${window.innerWidth} × ${window.innerHeight}`;
  const browser = browserOf();
  const details = el("input", { type: "checkbox", name: "details", checked: report });
  const detailsLabel = el("label", { className: "tick" }, details,
    el("span", { textContent: browser ? say("This page and your browser: {page}, {size}, {browser}", { page, size, browser })
      : say("This page and your browser: {page}, {size}", { page, size }) }));
  sent.append(marked, adding, shown, detailsLabel);
  // Everything a report sends, in a line, before it goes.
  const sends = el("p", { className: "sends" });
  const sendsPart = el("div", { className: "sends-part", hidden: !report },
    el("p", { className: "sends-head", textContent: say("What will be sent") }), sends);

  const status = el("p", { className: "said" });
  status.setAttribute("role", "status");
  const send = el("button", { type: "submit", className: "cta", textContent: report ? say("Send report") : say("Send") });
  const cancel = el("button", { type: "button", className: "cta ghost", textContent: say("Cancel") });
  // A report's status sits above Send and Cancel, which stay in sight
  // along its foot as it scrolls (site.css).
  const buttons = el("div", { className: "actions" }, send, cancel);
  form.append(kinds, wordsLabel, expectedLabel, addressLabel, sent, sendsPart, ...(report ? [status, buttons] : [buttons, status]));
  dialog.append(title, said, form);
  document.body.append(dialog);

  const chosenKind = () => form.querySelector('input[name="kind"]:checked')?.value || "";
  const saySends = () => {
    if (!report) return;
    const parts = [say("What you wrote")];
    if (picture) {
      const count = marking?.marks.length || 0;
      parts.push(!count ? say("the picture") : count === 1 ? say("the picture, with 1 mark")
        : say("the picture, with {n} marks", { n: number(count) }));
    }
    if (details.checked) parts.push(say("this page and your browser"));
    sends.textContent = parts.join(" · ");
  };
  const sayMarks = (count) => {
    markWords.textContent = !count ? say("Drag on the picture to mark the spot.")
      : count === 1 ? say("1 mark. Drag again to add another.") : say("{n} marks. Drag again to add another.", { n: number(count) });
    clearMarks.hidden = !count;
    saySends();
  };
  kinds.addEventListener("change", () => {
    if (!report) return;
    const now = chosenKind() || "bug";
    title.textContent = REPORT_TITLES[now]();
    asking.textContent = REPORT_ASKS[now]();
    expectedLabel.hidden = now !== "bug";
  });
  details.addEventListener("change", saySends);

  const end = () => {
    dialog.close();
    dialog.remove();
  };
  cancel.addEventListener("click", end);
  dialog.addEventListener("cancel", (event) => {
    // Escape while the browser asks which tab to share is the browser's.
    if (dialog.dataset.capturing) event.preventDefault();
    else end();
  });

  const attach = async (made, from_) => {
    picture = made;
    if (report) {
      // Large, to mark the spot on.
      marking = markable(made, sayMarks);
      marked.querySelector("canvas")?.remove();
      marked.prepend(marking.view);
      marked.hidden = false;
      shown.hidden = true;
      adding.hidden = true;
      leave.textContent = say("Leave the picture out");
      sayMarks(0);
      return;
    }
    made.canvas.className = "thumb";
    shown.querySelector("canvas")?.remove();
    shown.prepend(made.canvas);
    made.canvas.setAttribute("role", "img");
    made.canvas.setAttribute("aria-label", say("The picture: {from}", { from: from_ }));
    caption.textContent = say("{from}, {width} × {height}, {size} kB", { from: from_, width: number(made.canvas.width),
      height: number(made.canvas.height), size: number(Math.max(1, Math.round(made.blob.size / 1000))) });
    shown.hidden = false;
    adding.hidden = true;
    remove.focus();
  };
  remove.addEventListener("click", () => {
    picture = null;
    shown.hidden = true;
    shown.querySelector("canvas")?.remove();
    adding.hidden = false;
    choose.value = "";
    pick.focus();
  });
  // A report's marks taken off: the picture as it was, the count line and
  // what will be sent saying so (markable's clear tells sayMarks), and the
  // keyboard on the picture's next control, this one hidden with no marks.
  clearMarks.addEventListener("click", () => {
    marking?.clear();
    leave.focus();
  });
  // A report's picture left out, and put back as it was, marks and all.
  let leftOut = null;
  leave.addEventListener("click", () => {
    if (picture) {
      leftOut = picture;
      picture = null;
      marking.view.hidden = true;
      clearMarks.hidden = true;
      markWords.textContent = say("No picture goes with it.");
      leave.textContent = say("Put the picture back");
      adding.hidden = false;
    } else if (leftOut) {
      picture = leftOut;
      leftOut = null;
      marking.view.hidden = false;
      leave.textContent = say("Leave the picture out");
      adding.hidden = true;
      sayMarks(marking.marks.length);
    }
    saySends();
  });
  pick.addEventListener("click", () => choose.click());
  choose.addEventListener("change", async () => {
    const file = choose.files?.[0];
    if (!file) return;
    status.textContent = "";
    try {
      const bitmap = await createImageBitmap(file);
      leftOut = null;
      await attach(await redrawn(bitmap, bitmap.width, bitmap.height), file.name.slice(0, 80) || say("A picture"));
      bitmap.close();
    } catch {
      status.textContent = say("That file is not a picture this browser can read. Choose a PNG or a JPEG.");
    }
    saySends();
  });
  capture.addEventListener("click", async () => {
    status.textContent = "";
    dialog.dataset.capturing = "1";
    dialog.close();
    let stream = null;
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({ video: { displaySurface: "browser" }, audio: false,
        preferCurrentTab: true, selfBrowserSurface: "include" });
      const video = el("video", { muted: true, playsInline: true });
      video.srcObject = stream;
      await video.play();
      // A frame or two, so the browser's own bar has gone and the page is drawn.
      await new Promise((done) => setTimeout(done, 350));
      await attach(await redrawn(video, video.videoWidth, video.videoHeight), say("This page"));
    } catch {
      status.textContent = say("No picture was taken. Choose one instead, or send it without.");
    } finally {
      for (const track of stream?.getTracks() || []) track.stop();
      delete dialog.dataset.capturing;
      if (!dialog.open) dialog.showModal();
    }
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const chosen = chosenKind();
    if (!chosen) {
      status.textContent = say("Choose what it is: something wrong, an idea or a question.");
      return;
    }
    const hoped = report && chosen === "bug" ? expected.value.trim() : "";
    if (words.value.trim().length + hoped.length > MOST_WORDS) {
      status.textContent = say("At most {most} characters; that is {n}.", { most: number(MOST_WORDS),
        n: number(words.value.trim().length + hoped.length) });
      return;
    }
    send.disabled = true;
    status.textContent = say("Sending…");
    const body = { kind: chosen, words: words.value, source: "site" };
    if (hoped) body.expected = hoped;
    if (!signed) body.email = address.value;
    if (details.checked) {
      body.page = page;
      body.details = { window: size.replace(" × ", "x"), browser, theme: document.documentElement.dataset.theme || "" };
    }
    if (report) {
      // Where it was asked from and the boxes drawn, in the picture's
      // pixels: what the report is about, nothing of the person's.
      body.details = { ...(body.details || {}), from: from || "site" };
      if (picture && marking?.marks.length) body.details.marks = marking.words();
    }
    let answer;
    try {
      if (picture) {
        const blob = report && marking ? await marking.marked() : picture.blob;
        body.picture = { type: "image/jpeg", data: await base64Of(blob) };
      }
      answer = await call("/api/plans?op=feedback", { method: "POST", body });
    } catch {
      answer = { status: 0, body: {} };
    }
    send.disabled = false;
    if (answer.status !== 200) {
      status.textContent = told(answer.body?.error, say("That did not go just now. Try again in a minute."));
      return;
    }
    form.replaceChildren();
    const done = el("button", { type: "button", className: "cta", textContent: say("Close") });
    done.addEventListener("click", end);
    const row = el("div", { className: "actions" });
    const id = Number(answer.body.id);
    if (report) {
      // Its number, and where to follow it.
      title.textContent = Number.isSafeInteger(id) && id > 0 ? say("Thank you. Report #{id} is in.", { id })
        : say("Thank you. Your report is in.");
      // What did not go with it, in the server's words (api/_feedback.js THANKS).
      const lost = String(answer.body.said || "").split(/(?<=\.) (?=[A-Z])/).filter((one) => /did not go with it\.$/.test(one))
        .map((one) => ` ${told(one)}`).join("");
      said.textContent = say("We read every report ourselves. Follow it, and our answer, in Your reports.") + lost;
      row.append(el("a", { className: "cta", href: `${langAt()}/settings#feedback`, textContent: say("Your reports") }));
      done.className = "cta ghost";
      row.append(done);
    } else {
      // The server's thanks, a sentence at a time (api/_feedback.js THANKS).
      said.textContent = answer.body.said ? String(answer.body.said).split(/(?<=\.) (?=[A-Z])/).map((one) => told(one)).join(" ")
        : say("Thank you.");
      if (signed) row.append(el("a", { className: "cta ghost", href: `${langAt()}/settings#feedback`, textContent: say("See your reports") }));
      row.prepend(done);
    }
    dialog.append(row);
    dialog.dataset.sent = String(answer.body.id);
    (row.querySelector("a") || done).focus();
  });
  if (report && given) attach(given, say("This page"));
  saySends();
  dialog.showModal();
  (form.querySelector('input[name="kind"]:checked') ? words : kinds.querySelector("input")).focus();
  return dialog;
}
