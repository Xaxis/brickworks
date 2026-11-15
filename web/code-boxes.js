// The code from the email, typed one digit to a box (signinux, 2026-11-13,
// the owner: "implement the standard pattern of accepting OTP digits not
// just a flat textfield"): the sign-in dialog (web/account.js), the
// connector's sign-in page (web/authorize.js) and /settings' two codes.
//
// One real text box per digit, in a row that is one labelled group ("The
// code sent to …"), each said as "Digit 1 of 8". The first box carries
// autocomplete="one-time-code", so the browser's and a password manager's
// one-time-code fill lands in it, and a whole code put in any one box
// (that fill, a phone keyboard's suggestion, a paste the browser did
// itself) is fanned out across the row. No box has a maxlength: Safari on
// iOS cuts a filled code to it. Every box asks for the number pad
// (inputmode numeric, pattern [0-9]*).
//
// Typing a digit fills its box and moves on; Backspace empties a box, or
// on an empty one steps back and empties that; the arrows, Home and End
// move; anything that is not a digit is refused. A paste anywhere in the
// row fills it from the first box with the clipboard's digits, spaces and
// dashes dropped. The last digit in calls [onFilled] once, which signs in
// where that is safe (never deleting an account).
//
// How long a code is the deployment's to say (api/otp.js answers the
// minted code's length as `digits`); a Supabase code was 8 digits when this
// was written (GoTrue mailer_otp_length, measured 2026-11-13), the length
// drawn when nothing says otherwise.
export const CODE_DIGITS = 8;

const onlyDigits = (text) => String(text || "").replace(/\D/g, "");

/// A row of [digits] boxes, its value mirrored into [field] when given (a
/// page's own box, kept as a hidden input so what reads it reads the code)
/// and put after it, or into [into] otherwise. [label]: the element that
/// names the row (the field's label when not given). [id]: the first box's
/// id, "-1" after it (the field's id when not given). [say]: the page's
/// words, for "Digit {n} of {count}". [onFilled]: called with the code when
/// the last box is filled. Returns {row, value, digits, focus, clear, busy,
/// refuse, size}.
export function codeBoxes({ field = null, into = null, id = "", digits = CODE_DIGITS, label = null, say, onFilled = null }) {
  const row = document.createElement("div");
  row.className = "code-boxes";
  row.setAttribute("role", "group");
  const named = label || field?.labels?.[0] || null;
  if (named) {
    named.id ||= `${field?.id || "code"}-label`;
    row.setAttribute("aria-labelledby", named.id);
    // A label for the page's box now names its first.
    if (field && named.htmlFor === field.id) named.htmlFor = `${field.id}-1`;
  }
  if (field) {
    field.type = "hidden";
    field.required = false;
    field.removeAttribute("maxlength");
    field.removeAttribute("placeholder");
    field.after(row);
  } else if (into) {
    into.append(row);
  }
  let boxes = [];
  let full = false;
  let checking = false;

  const value = () => boxes.map((box) => box.value).join("");
  const at = (box) => boxes.indexOf(box);
  const focus = (index = 0) => {
    const box = boxes[Math.max(0, Math.min(boxes.length - 1, index))];
    box?.focus();
    box?.select();
  };
  // The row's value told to the page's own box, and the last digit in
  // answered once: a code filled, refused and filled again is answered again.
  const settle = () => {
    const code = value();
    if (field && field.value !== code) {
      field.value = code;
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
    row.dataset.filled = String(code.length);
    const now = code.length === boxes.length && boxes.every((box) => box.value);
    if (now && !full && !checking) {
      full = true;
      onFilled?.(code);
    }
    full = now;
  };
  // [text]'s digits laid into the boxes from [from], the focus after the
  // last one laid (the last box when the row is full). A code laid whole is
  // sent again though the row was full already: a paste or a fill after a
  // limit kept the digits is somebody sending it.
  const lay = (text, from = 0) => {
    const got = onlyDigits(text);
    if (!got) return;
    full = false;
    // A whole code, wherever it landed, is the code from the first box.
    const start = got.length >= boxes.length ? 0 : from;
    [...got].slice(0, boxes.length - start).forEach((digit, i) => {
      boxes[start + i].value = digit;
    });
    focus(Math.min(boxes.length - 1, start + got.length));
    settle();
  };

  const draw = (count) => {
    const was = value();
    boxes = Array.from({ length: count }, (_, i) => {
      const box = document.createElement("input");
      box.type = "text";
      box.className = "code-box";
      box.inputMode = "numeric";
      box.pattern = "[0-9]*";
      box.autocomplete = i === 0 ? "one-time-code" : "off";
      box.spellcheck = false;
      box.setAttribute("autocapitalize", "off");
      box.setAttribute("autocorrect", "off");
      box.setAttribute("enterkeyhint", i === count - 1 ? "go" : "next");
      box.setAttribute("aria-label", say("Digit {n} of {count}", { n: i + 1, count }));
      if ((id || field?.id) && i === 0) box.id = `${id || field.id}-1`;
      return box;
    });
    row.dataset.digits = String(count);
    row.replaceChildren(...boxes);
    full = false;
    if (was) lay(was);
  };

  // A digit typed: into its box, and on to the next. On a phone's keyboard,
  // whose keys say "Unidentified", the input event below does the same.
  row.addEventListener("keydown", (event) => {
    const box = event.target;
    if (!(box instanceof HTMLInputElement) || at(box) < 0 || box.readOnly) return;
    const i = at(box);
    const held = event.ctrlKey || event.metaKey || event.altKey;
    if (/^\d$/.test(event.key) && !held) {
      event.preventDefault();
      box.value = event.key;
      settle();
      if (i < boxes.length - 1) focus(i + 1);
    } else if (event.key === "Backspace" && !held) {
      event.preventDefault();
      if (box.value) {
        box.value = "";
      } else if (i > 0) {
        boxes[i - 1].value = "";
        focus(i - 1);
      }
      settle();
    } else if (event.key === "Delete") {
      event.preventDefault();
      box.value = "";
      settle();
    } else if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      event.preventDefault();
      focus(i + (event.key === "ArrowLeft" ? -1 : 1));
    } else if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      focus(event.key === "Home" ? 0 : boxes.length - 1);
    } else if (event.key.length === 1 && !held) {
      // Not a digit: refused, the box as it was.
      event.preventDefault();
    }
  });
  // What reached a box another way: a phone keyboard's digit, a fill, a
  // paste the browser made itself. A letter is taken back out.
  row.addEventListener("input", (event) => {
    const box = event.target;
    if (!(box instanceof HTMLInputElement) || at(box) < 0) return;
    const i = at(box);
    const got = onlyDigits(box.value);
    const typed = /^insert(Text|CompositionText)$/.test(event.inputType || "") && String(event.data || "").length === 1;
    if (typed) {
      // One key: a digit is the box's, where it held one already; anything
      // else is taken back out.
      box.value = /\d/.test(event.data) ? event.data : got.slice(0, 1);
      settle();
      if (/\d/.test(event.data) && i < boxes.length - 1) focus(i + 1);
    } else if (got.length > 1) {
      box.value = "";
      lay(got, i);
    } else {
      box.value = got;
      settle();
    }
  });
  row.addEventListener("paste", (event) => {
    const text = event.clipboardData?.getData("text") || "";
    event.preventDefault();
    if (checking) return;
    lay(text, 0);
  });
  // Into a box, its digit chosen, so a digit typed replaces it.
  row.addEventListener("focusin", (event) => {
    const box = event.target;
    if (box instanceof HTMLInputElement) requestAnimationFrame(() => box.select());
  });

  draw(digits);
  return {
    row,
    value,
    /// How many digits the code has.
    digits: () => boxes.length,
    focus,
    /// Every box emptied, the focus to the first.
    clear() {
      for (const box of boxes) box.value = "";
      settle();
      focus(0);
    },
    /// While the code is checked: the boxes read-only, the row busy.
    busy(on) {
      checking = on;
      for (const box of boxes) box.readOnly = on;
      if (on) row.setAttribute("aria-busy", "true");
      else row.removeAttribute("aria-busy");
    },
    /// A code refused: the row shakes once (not under reduced motion),
    /// its boxes emptied, the focus back to the first.
    refuse() {
      row.classList.remove("shake");
      // A new animation, though the last one ended this same way.
      void row.offsetWidth;
      row.classList.add("shake");
      this.clear();
    },
    /// Drawn for a code of [count] digits, what was typed kept.
    size(count) {
      const n = Number(count);
      if (Number.isInteger(n) && n >= 4 && n <= 12 && n !== boxes.length) draw(n);
    },
  };
}
