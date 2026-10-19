// Report: a model, a profile, a collection, a comment or a photo of a build
// that should not be there (the directory's moderation, 2026-10-13; comments
// and photos of builds, 2026-10-18). A button on each of
// their pages opens this; what is sent goes to the site's owner
// (/api/people?op=report, api/admin.js shows it to them) and to nobody
// else. Signed in or not: a person who saw something wrong should not have
// to make an account to say so, so a report without one is counted by the
// address it came from instead, a few a day.
//
// Everything here is put on the page as text.
import { call, signedIn, token } from "/account.js";

const REASONS = [
  ["spam", "Spam, or not a model"],
  ["offensive", "Hateful, abusive or offensive"],
  ["sexual", "Sexual"],
  ["violent", "Violent or cruel"],
  ["copied", "Somebody else's work, copied"],
  ["trademark", "Uses a name or a mark somebody else owns"],
  ["personal", "Somebody's personal information"],
  ["other", "Something else"],
];

/// The dialog, for [target] ({model} | {handle} | {collection} | {comment}),
/// called [about] in its title. web/model-page.js opens it for a comment.
export function openReport(target, about) {
  open(target, about);
}

function open(target, about) {
  const dialog = document.createElement("dialog");
  dialog.className = "sign-in report";
  const title = document.createElement("h2");
  title.textContent = `Report ${about}`;
  const said = document.createElement("p");
  said.textContent = "Tell the site's owner what is wrong. Only they see this.";
  const form = document.createElement("form");
  const choices = document.createElement("fieldset");
  const legend = document.createElement("legend");
  legend.textContent = "What is wrong with it";
  choices.append(legend);
  for (const [value, words] of REASONS) {
    const row = document.createElement("label");
    row.className = "choice";
    const box = document.createElement("input");
    box.type = "radio";
    box.name = "reason";
    box.value = value;
    box.required = true;
    row.append(box, document.createTextNode(` ${words}`));
    choices.append(row);
  }
  const noteLabel = document.createElement("label");
  noteLabel.textContent = "Anything to add (optional)";
  const note = document.createElement("textarea");
  note.maxLength = 1000;
  note.rows = 3;
  noteLabel.append(note);
  const contactLabel = document.createElement("label");
  contactLabel.textContent = "If it is your work or your mark: how to reach you (optional)";
  const contact = document.createElement("input");
  contact.type = "email";
  contact.maxLength = 200;
  contact.autocomplete = "email";
  contactLabel.append(contact);
  const status = document.createElement("p");
  status.className = "said";
  status.setAttribute("role", "status");
  const send = document.createElement("button");
  send.className = "cta";
  send.type = "submit";
  send.textContent = "Send the report";
  const close = document.createElement("button");
  close.className = "cta ghost";
  close.type = "button";
  close.textContent = "Cancel";
  const row = document.createElement("div");
  row.className = "actions";
  row.append(send, close);
  form.append(choices, noteLabel, contactLabel, row, status);
  dialog.append(title, said, form);
  document.body.append(dialog);
  const end = () => {
    dialog.close();
    dialog.remove();
  };
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const reason = (form.querySelector('input[name="reason"]:checked') || {}).value;
    if (!reason) return;
    send.disabled = true;
    status.textContent = "Sending…";
    const body = { ...target, reason, note: note.value, contact: contact.value };
    let answer;
    if (signedIn() && (await token())) {
      answer = await call("/api/people?op=report", { method: "POST", body });
    } else {
      const reply = await fetch("/api/people?op=report", { method: "POST",
        headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
      answer = { status: reply.status, body: await reply.json().catch(() => ({})) };
    }
    send.disabled = false;
    if (answer.status !== 200) {
      status.textContent = answer.body.error || "That did not go just now. Try again in a minute.";
      return;
    }
    form.replaceChildren();
    said.textContent = target.comment
      ? "Thank you. The site's owner will look at it, and remove it if it should not be there."
      : "Thank you. The site's owner will look at it, and take it out of the gallery if it should not be there.";
    const done = document.createElement("button");
    done.className = "cta";
    done.type = "button";
    done.textContent = "Close";
    done.addEventListener("click", end);
    dialog.append(done);
    done.focus();
  });
  dialog.showModal();
}

for (const button of document.querySelectorAll("[data-report]")) {
  button.hidden = false;
  button.addEventListener("click", () => {
    const target = {};
    // A photo of a build is reported as itself (supabase/builds.sql).
    for (const key of ["model", "handle", "collection", "photo"]) {
      const value = button.dataset[`report${key[0].toUpperCase()}${key.slice(1)}`];
      if (value) target[key] = value;
    }
    open(target, button.dataset.report || "this");
  });
}
