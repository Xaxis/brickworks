// A takedown request (takedown.html): the page's address read for what it
// names — a model (/m/<id>), a profile (/u/<handle>) or a collection
// (/c/<id>) — and sent as a report with the way to reach the person who
// asks (/api/people?op=report). Nothing typed is shown back as markup.
// What the page says is in its language (web/card.js say); what the
// site's owner reads, the statements ticked with it, in English, as the
// notice's law has it (noticeOf, counterNoticeOf).
import { say, told } from "/card.js";

const $ = (id) => document.getElementById(id);

/// What an address names, or null: its copy's address in a language
/// (/de/m/<id>) names it too.
function target(given) {
  let path = "";
  try {
    path = new URL(String(given).trim(), location.origin).pathname.replace(/^\/(?:de|fr|es)(?=\/[muc]\/)/, "");
  } catch {
    return null;
  }
  let found = /^\/m\/([A-Za-z0-9]{10})/.exec(path);
  if (found) return { model: found[1] };
  found = /^\/u\/([a-z0-9-]{3,24})\/?$/.exec(path);
  if (found) return { handle: found[1] };
  found = /^\/c\/([A-Za-z0-9]{10})/.exec(path);
  if (found) return { collection: found[1] };
  return null;
}

/// A report sent, as the Report button sends one: the reply's words, or throws.
async function send(body) {
  const reply = await fetch("/api/people?op=report", {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
  });
  const said = await reply.json().catch(() => ({}));
  if (!reply.ok) throw new Error(told(said.error, say("Brickworks said {status}.", { status: reply.status })));
  return said;
}

/// A copyright notice as the site's owner reads it: [note], signed by
/// [name], with the two statements ticked.
function noticeOf(note, name) {
  return `${note}\n\nSigned: ${name}. In good faith, this use is not allowed by the owner, their agent or the law. `
    + "Accurate, and on pain of perjury the sender owns the work or may act for its owner.";
}

/// A counter-notice as the site's owner reads it, from the form.
function counterNoticeOf() {
  return `Counter-notice. ${$("counter-why").value.trim()}\n\nSigned: ${$("counter-name").value.trim()}. `
    + `Address and phone: ${$("counter-address").value.trim()}. On pain of perjury, in good faith, it was taken out `
    + "by mistake or misidentified. Consents to the federal district court for that address (or, outside the "
    + "United States, any district where Brickworks may be found) and will accept service from whoever asked for the takedown.";
}

// The copyright notice's statements, asked for a copy of somebody's work.
const copyright = () => $("why").value === "copied";
const showStatements = () => {
  $("copyright").hidden = !copyright();
};
$("why").addEventListener("change", showStatements);
showStatements();

/// A takedown request, from the first form.
async function claim(event) {
  event.preventDefault();
  const what = target($("where").value);
  if (!what) {
    $("said").textContent = say("That is not the address of a model, a profile or a collection in the gallery.");
    return;
  }
  let note = $("what").value;
  if (copyright()) {
    const name = $("signature").value.trim();
    if (!name || !$("good-faith").checked || !$("accurate").checked) {
      $("said").textContent = say("A copyright notice needs your name as your signature and both statements ticked.");
      return;
    }
    note = noticeOf(note, name);
  }
  $("send").disabled = true;
  $("said").textContent = say("Sending…");
  try {
    await send({ ...what, reason: $("why").value, note, contact: $("contact").value });
    $("claim").reset();
    showStatements();
    $("said").textContent = say("Sent. The site's owner will write to you at the address you gave.");
  } catch (trouble) {
    $("said").textContent = trouble.message;
  } finally {
    $("send").disabled = false;
  }
}

/// A counter-notice: about a model, which may have been taken out already.
async function counter(event) {
  event.preventDefault();
  const what = target($("counter-where").value);
  if (!what || !what.model) {
    $("counter-said").textContent = say("That is not the address of a model: it looks like https://brickworks.diy/m/ and ten letters.");
    return;
  }
  $("counter-send").disabled = true;
  $("counter-said").textContent = say("Sending…");
  try {
    await send({ model: what.model, reason: "other", counter: true, note: counterNoticeOf(), contact: $("counter-contact").value });
    $("counter").reset();
    $("counter-said").textContent = say("Sent. The site's owner will pass it on, and write to you at the address you gave.");
  } catch (trouble) {
    $("counter-said").textContent = trouble.message;
  } finally {
    $("counter-send").disabled = false;
  }
}

$("claim").addEventListener("submit", claim);
$("counter").addEventListener("submit", counter);
