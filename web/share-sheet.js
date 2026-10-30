// Share's sheet on every page that has Share (docs/SOCIAL.md U14 and
// section 7): a model's, a set's, a person's, a collection's, your own
// profile and the challenge. The site's dialog with the page's link, each
// network to post it to, the embed code where the page has one, and where
// the browser has a share sheet of its own, a phone's, a way to it.
//
// A page the server makes draws the sheet in its markup (web/card.js
// shareSheetHtml, api/share.js and api/people.js); a page that draws itself
// (your profile, the challenge) asks sheetFor for one from the same
// function. Copy says what it copied in the sheet, not in the toast, which
// a modal dialog hides from a screen reader too. The link is selected as it
// opens, so a keyboard's copy takes it. Escape and Close close it, the
// browser putting the focus back on Share.
import { shareSheetHtml } from "/card.js";

/// [text] on the clipboard: the browser's clipboard where the page may use
/// it (a secure page), else the older way, through a selection. Whether it
/// went.
export async function copy(text) {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // The older way, below.
  }
  const box = document.createElement("textarea");
  box.value = text;
  box.setAttribute("readonly", "");
  box.className = "visually-hidden";
  document.body.append(box);
  box.select();
  let done = false;
  try {
    done = document.execCommand("copy");
  } catch {
    done = false;
  }
  box.remove();
  return done;
}

const COPIED = { "share-link": ["Link copied", "copied"], "share-embed": ["Embed code copied: paste it into your page", "embed"] };

/// The sheet's own buttons, made to work once: Copy for each field, the
/// networks (said in the sheet as each opens), and Share with another app.
function prepare(sheet) {
  if (sheet.dataset.ready) return;
  sheet.dataset.ready = "1";
  const said = sheet.querySelector(".said");
  const link = sheet.querySelector("#share-link");
  const app = sheet.querySelector("[data-share-app]");
  for (const button of sheet.querySelectorAll("[data-copy]")) {
    button.addEventListener("click", async () => {
      const field = sheet.querySelector(`#${button.dataset.copy}`);
      const [words, mark] = COPIED[button.dataset.copy];
      const done = await copy(field.value);
      said.textContent = done ? words : "It did not copy just now: select it and copy it yourself";
      document.documentElement.dataset.shared = done ? mark : "failed";
      if (!done) field.select();
    });
  }
  for (const to of sheet.querySelectorAll("[data-to]")) {
    to.addEventListener("click", () => {
      said.textContent = to.dataset.to === "email" ? "Your email opens with its link in it"
        : `${to.textContent.replace(/ \(opens in a new tab\)$/, "")} opens in a new tab with its link`;
      document.documentElement.dataset.shared = to.dataset.to;
    });
  }
  app.addEventListener("click", async () => {
    try {
      await navigator.share({ title: sheet.dataset.title || document.title, url: link.value });
      document.documentElement.dataset.shared = "sheet";
      sheet.close();
    } catch (trouble) {
      // Closed without sharing: the sheet stays.
      if (trouble && trouble.name !== "AbortError") said.textContent = "That did not open just now: copy the link instead";
    }
  });
}

/// [sheet] opened, its link selected.
export function openShare(sheet) {
  prepare(sheet);
  const link = sheet.querySelector("#share-link");
  const url = link.value;
  sheet.querySelector("[data-share-app]").hidden = !(typeof navigator.share === "function"
    && (!navigator.canShare || navigator.canShare({ url })));
  sheet.querySelector(".said").textContent = "";
  sheet.showModal();
  document.documentElement.dataset.shared = "open";
  link.focus();
  link.select();
}

/// Share [button] opens [sheet].
export function wireShare(button, sheet) {
  prepare(sheet);
  button.hidden = false;
  button.addEventListener("click", () => openShare(sheet));
}

/// The sheet for a page that draws itself, made from what shareSheetHtml
/// takes and put at the end of the page, in place of one made before.
export function sheetFor(what) {
  document.getElementById("share-sheet")?.remove();
  const holder = document.createElement("div");
  holder.innerHTML = shareSheetHtml(what);
  const sheet = holder.firstElementChild;
  document.body.append(sheet);
  return sheet;
}
