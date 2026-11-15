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
// row, and a fill, are read by one rule, the studio's too (readCode): a
// whole code in it is laid from the first box and sent; anything else is
// laid and waits. The last digit in calls [onFilled], which signs in where
// that is safe (never deleting an account): the digit that fills the row,
// or one typed into its last box (sent again after a limit kept the
// digits); a digit changed in the middle of a full row waits.
//
// How long a code is the deployment's to say (api/otp.js answers the
// minted code's length as `digits`); a Supabase code was 8 digits when this
// was written (GoTrue mailer_otp_length, measured 2026-11-13), the length
// drawn when nothing says otherwise.
export const CODE_DIGITS = 8;

const onlyDigits = (text) => String(text || "").replace(/[^0-9]/g, "");

/// The code in [text] for a row of [count] boxes, read as the studio reads
/// it (src/ui/code_boxes.gd read_code): {code, whole}. A run of exactly
/// [count] digits, one space or dash allowed inside ("1234 5678",
/// "1234-5678") and no other digit joined to it, is the code, [whole]: sent
/// at once, the email's own words around it or not ("Your Brickworks
/// sign-in code is 12345678. It works once and expires in 10 minutes.").
/// Anything else (too few digits, too many, "123456789") is its first
/// [count] digits, laid in the boxes for the person to look at, never sent
/// by itself (sifix, 2026-11-15: the site sent the first eight of nine and
/// the studio the last eight).
export function readCode(text, count) {
  const said = String(text || "");
  for (const run of said.match(/[0-9]+(?:[ -][0-9]+)*/g) || []) {
    const parts = run.split(/[ -]/);
    if (parts.length <= 2 && parts.join("").length === count) return { code: parts.join(""), whole: true };
  }
  return { code: onlyDigits(said).slice(0, count), whole: false };
}

/// A row of [digits] boxes, its value mirrored into [field] when given (a
/// page's own box, kept as a hidden input so what reads it reads the code)
/// and put after it, or into [into] otherwise. [label]: the element that
/// names the row (the field's label when not given). [id]: the first box's
/// id, "-1" after it (the field's id when not given). [say]: the page's
/// words, for "Digit {n} of {count}". [onFilled]: called with the code when
/// the last digit is in. Returns {row, value, digits, focus, complete, clear,
/// busy, refuse, size}.
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
    // Its required kept: a hidden box is not one a browser checks, so
    // complete() below is what refuses a code short of digits.
    field.type = "hidden";
    field.removeAttribute("maxlength");
    field.removeAttribute("placeholder");
    field.after(row);
  } else if (into) {
    into.append(row);
  }
  let boxes = [];
  let checking = false;

  const value = () => boxes.map((box) => box.value).join("");
  const at = (box) => boxes.indexOf(box);
  const focus = (index = 0) => {
    const box = boxes[Math.max(0, Math.min(boxes.length - 1, index))];
    box?.focus();
    box?.select();
  };
  const full = () => boxes.every((box) => box.value);
  // The row's value told to the page's own box, and each box's digit kept
  // as it was (data-held) for a fill to be told from it; [send]: the code
  // answered (onFilled) if every box has its digit and none is checked.
  const settle = (send = false) => {
    const code = value();
    if (field && field.value !== code) {
      field.value = code;
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
    for (const box of boxes) box.dataset.held = box.value;
    row.dataset.filled = String(code.length);
    if (send && !checking && full()) onFilled?.(code);
  };
  // A digit typed into box [i], and on to the next: the last digit in
  // sends the code, the one that fills the row or one typed into its last
  // box; a digit changed in the middle of a full row waits for the rest.
  const typed = (i, digit) => {
    const was = full();
    boxes[i].value = digit;
    settle(!was || i === boxes.length - 1);
    if (i < boxes.length - 1) focus(i + 1);
  };
  // A code read (readCode) laid in the boxes, the focus after its last
  // digit: a whole one from the first box and sent, even into a row full
  // already (a paste or a fill after a limit kept the digits is somebody
  // sending it); anything else from [from] (the first box when it is a
  // row's worth), laid and not sent.
  const lay = (read, from = 0) => {
    if (!read.code) return false;
    const start = read.whole || read.code.length >= boxes.length ? 0 : from;
    [...read.code].slice(0, boxes.length - start).forEach((digit, i) => {
      boxes[start + i].value = digit;
    });
    focus(Math.min(boxes.length - 1, start + read.code.length));
    settle(read.whole);
    return true;
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
    // What was typed kept, never sent for being redrawn.
    [...was].slice(0, count).forEach((digit, i) => {
      boxes[i].value = digit;
    });
    settle();
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
      typed(i, event.key);
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
    const was = box.dataset.held || "";
    const now = box.value;
    const key = /^insert(Text|CompositionText)$/.test(event.inputType || "") && String(event.data || "").length === 1;
    if (key) {
      // One key: a digit is the box's, where it held one already; anything
      // else is taken back out.
      if (/\d/.test(event.data)) typed(i, event.data);
      else {
        box.value = was;
        settle();
      }
      return;
    }
    // A fill or a phone's paste: what came, read by the paste's rule. A
    // fill put after the box's own digit ("5" then "12345678") is what
    // came, not the nine together.
    const came = was && now.length > was.length && now.startsWith(was) ? now.slice(was.length)
      : was && now.length > was.length && now.endsWith(was) ? now.slice(0, -was.length) : now;
    const read = [readCode(now, boxes.length), readCode(came, boxes.length)].find((one) => one.whole)
      || readCode(came, boxes.length);
    if (read.whole || read.code.length > 1) {
      box.value = "";
      lay(read, i);
    } else if (read.code) {
      typed(i, read.code);
    } else {
      box.value = was;
      settle();
    }
  });
  row.addEventListener("paste", (event) => {
    const text = event.clipboardData?.getData("text") || "";
    event.preventDefault();
    if (checking) return;
    lay(readCode(text, boxes.length), 0);
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
    /// Whether every box has its digit. When not, [tell] is given "Enter
    /// all {count} digits of the code." and the focus goes to the first
    /// empty box: every form a code is sent from asks this first, as the
    /// sign-in's dialog does, so a code short of digits is never sent.
    complete(tell) {
      if (full()) return true;
      tell(say("Enter all {count} digits of the code.", { count: boxes.length }));
      focus(Math.max(0, boxes.findIndex((box) => !box.value)));
      return false;
    },
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
