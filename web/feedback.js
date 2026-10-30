// Send feedback, from any page of the site (beta374, 2026-10-30): the
// footer's Send feedback and the account menu's (a[data-feedback], heard by
// web/follow.js, which loads this when one is pressed), and /feedback.
//
// A bug, an idea or a question, a few words, and what the person chooses
// to send with it, each shown before it goes and each taken off again:
//
//   a picture   of this page (the browser asks which tab to share, this
//               one first, and the dialog steps aside for it), or one they
//               choose. Drawn again here at most 1600 pixels wide as a
//               JPEG, which also leaves behind whatever the file carried
//               besides the picture (where a photo was taken). Shown on a
//               canvas: the server's pages allow no data: or blob: image.
//   details     with their tick: this page's address and the window's
//               size, and the browser's name
//
// Signed in, the account sends it and the report is on /settings with
// where it stands and the answer; signed out, an address to answer at is
// asked for. POST /api/plans?op=feedback (api/_feedback.js).
//
// Everything here is put on the page as text.
import { call, signedIn } from "/account.js";

const KINDS = [["bug", "Something is wrong"], ["idea", "An idea"], ["question", "A question"]];
const WIDEST = 1600;
const MOST_WORDS = 4000;

const el = (tag, props = {}, ...children) => {
  const made = Object.assign(document.createElement(tag), props);
  made.append(...children);
  return made;
};

/// The browser, in a few words: its name and version, and the system.
function browserOf() {
  const agent = navigator.userAgent;
  const named = /(Firefox|Edg|OPR|Chrome|Version)\/(\d+)/.exec(agent);
  const name = !named ? "" : named[1] === "Edg" ? "Edge" : named[1] === "OPR" ? "Opera"
    : named[1] === "Version" ? "Safari" : named[1];
  const system = /Windows|Mac OS X|Android|iPhone|iPad|Linux|CrOS/.exec(agent)?.[0]?.replace("Mac OS X", "macOS") || "";
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

/// The dialog. [kind]: the one chosen at first, if any.
export function openFeedback({ kind = "" } = {}) {
  const signed = signedIn();
  const dialog = el("dialog", { className: "sign-in feedback" });
  const title = el("h2", { id: "feedback-title", textContent: "Send feedback" });
  dialog.setAttribute("aria-labelledby", title.id);
  const said = el("p", { textContent: "Tell us what is wrong, what you would like, or ask us anything. We read every one ourselves." });
  const form = el("form", { noValidate: false });

  const kinds = el("fieldset", { className: "kinds" }, el("legend", { textContent: "What is it" }));
  for (const [value, words] of KINDS) {
    const box = el("input", { type: "radio", name: "kind", value, required: true, checked: value === kind });
    kinds.append(el("label", { className: "choice" }, box, ` ${words}`));
  }
  const words = el("textarea", { name: "words", rows: 5, maxLength: MOST_WORDS, required: true });
  const wordsLabel = el("label", {}, "What happened, or what would you like?", words);
  const address = el("input", { type: "email", name: "email", autocomplete: "email", required: true, maxLength: 254 });
  const addressLabel = el("label", {}, "Your email, so we can answer", address);
  addressLabel.hidden = signed;
  address.disabled = signed;

  // What goes with it.
  const sent = el("fieldset", { className: "attach" }, el("legend", { textContent: "Send with it" }));
  let picture = null;
  const shown = el("figure", { className: "attached", hidden: true });
  const caption = el("figcaption");
  const remove = el("button", { type: "button", className: "cta ghost small", textContent: "Remove the picture" });
  shown.append(caption, remove);
  const choose = el("input", { type: "file", accept: "image/png,image/jpeg,image/webp", className: "visually-hidden" });
  choose.setAttribute("aria-label", "Choose a picture");
  const capture = el("button", { type: "button", className: "cta ghost small", textContent: "Picture of this page" });
  capture.hidden = !navigator.mediaDevices?.getDisplayMedia;
  const pick = el("button", { type: "button", className: "cta ghost small", textContent: "Choose a picture…" });
  const adding = el("div", { className: "actions" }, capture, pick, choose);
  const page = `${location.pathname}${location.search}`.slice(0, 300);
  const size = `${window.innerWidth} × ${window.innerHeight}`;
  const browser = browserOf();
  const details = el("input", { type: "checkbox", name: "details" });
  const detailsLabel = el("label", { className: "tick" }, details,
    el("span", { textContent: `This page and your browser: ${page}, ${size}${browser ? `, ${browser}` : ""}` }));
  sent.append(adding, shown, detailsLabel);

  const status = el("p", { className: "said" });
  status.setAttribute("role", "status");
  const send = el("button", { type: "submit", className: "cta", textContent: "Send" });
  const cancel = el("button", { type: "button", className: "cta ghost", textContent: "Cancel" });
  form.append(kinds, wordsLabel, addressLabel, sent, el("div", { className: "actions" }, send, cancel), status);
  dialog.append(title, said, form);
  document.body.append(dialog);

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

  const attach = async (made, from) => {
    picture = made;
    made.canvas.className = "thumb";
    shown.querySelector("canvas")?.remove();
    shown.prepend(made.canvas);
    made.canvas.setAttribute("role", "img");
    made.canvas.setAttribute("aria-label", `The picture: ${from}`);
    caption.textContent = `${from}, ${made.canvas.width} × ${made.canvas.height}, ${Math.max(1, Math.round(made.blob.size / 1000))} kB`;
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
  pick.addEventListener("click", () => choose.click());
  choose.addEventListener("change", async () => {
    const file = choose.files?.[0];
    if (!file) return;
    status.textContent = "";
    try {
      const bitmap = await createImageBitmap(file);
      await attach(await redrawn(bitmap, bitmap.width, bitmap.height), file.name.slice(0, 80) || "A picture");
      bitmap.close();
    } catch {
      status.textContent = "That file is not a picture this browser can read. Choose a PNG or a JPEG.";
    }
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
      await attach(await redrawn(video, video.videoWidth, video.videoHeight), "This page");
    } catch {
      status.textContent = "No picture was taken. Choose one instead, or send it without.";
    } finally {
      for (const track of stream?.getTracks() || []) track.stop();
      delete dialog.dataset.capturing;
      if (!dialog.open) dialog.showModal();
    }
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const chosen = form.querySelector('input[name="kind"]:checked')?.value;
    if (!chosen) {
      status.textContent = "Choose what it is: something wrong, an idea or a question.";
      return;
    }
    send.disabled = true;
    status.textContent = "Sending…";
    const body = { kind: chosen, words: words.value, source: "site" };
    if (!signed) body.email = address.value;
    if (details.checked) {
      body.page = page;
      body.details = { window: size.replace(" × ", "x"), browser, theme: document.documentElement.dataset.theme || "" };
    }
    let answer;
    try {
      if (picture) body.picture = { type: "image/jpeg", data: await base64Of(picture.blob) };
      answer = await call("/api/plans?op=feedback", { method: "POST", body });
    } catch {
      answer = { status: 0, body: {} };
    }
    send.disabled = false;
    if (answer.status !== 200) {
      status.textContent = answer.body?.error || "That did not go just now. Try again in a minute.";
      return;
    }
    form.replaceChildren();
    said.textContent = answer.body.said || "Thank you.";
    const done = el("button", { type: "button", className: "cta", textContent: "Close" });
    done.addEventListener("click", end);
    const row = el("div", { className: "actions" });
    if (signed) row.append(el("a", { className: "cta ghost", href: "/settings#feedback", textContent: "See your reports" }));
    row.prepend(done);
    dialog.append(row);
    dialog.dataset.sent = String(answer.body.id);
    done.focus();
  });
  dialog.showModal();
  (form.querySelector('input[name="kind"]:checked') ? words : kinds.querySelector("input")).focus();
  return dialog;
}
