// A takedown request (takedown.html): the page's address read for what it
// names — a model (/m/<id>), a profile (/u/<handle>) or a collection
// (/c/<id>) — and sent as a report with the way to reach the person who
// asks (/api/people?op=report). Nothing typed is shown back as markup.
const $ = (id) => document.getElementById(id);

/// What an address names, or null.
function target(given) {
  let path = "";
  try {
    path = new URL(String(given).trim(), location.origin).pathname;
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
  if (!reply.ok) throw new Error(said.error || `Brickworks said ${reply.status}.`);
  return said;
}

// The copyright notice's statements, asked for a copy of somebody's work.
const copyright = () => $("why").value === "copied";
const showStatements = () => {
  $("copyright").hidden = !copyright();
};
$("why").addEventListener("change", showStatements);
showStatements();

$("claim").addEventListener("submit", async (event) => {
  event.preventDefault();
  const what = target($("where").value);
  if (!what) {
    $("said").textContent = "That is not the address of a model, a profile or a collection in the gallery.";
    return;
  }
  let note = $("what").value;
  if (copyright()) {
    const name = $("signature").value.trim();
    if (!name || !$("good-faith").checked || !$("accurate").checked) {
      $("said").textContent = "A copyright notice needs your name as your signature and both statements ticked.";
      return;
    }
    note = `${note}\n\nSigned: ${name}. In good faith, this use is not allowed by the owner, their agent or the law. `
      + "Accurate, and on pain of perjury the sender owns the work or may act for its owner.";
  }
  $("send").disabled = true;
  $("said").textContent = "Sending…";
  try {
    await send({ ...what, reason: $("why").value, note, contact: $("contact").value });
    $("claim").reset();
    showStatements();
    $("said").textContent = "Sent. The site's owner will write to you at the address you gave.";
  } catch (trouble) {
    $("said").textContent = trouble.message;
  } finally {
    $("send").disabled = false;
  }
});

// A counter-notice: about a model, which may have been taken out already.
$("counter").addEventListener("submit", async (event) => {
  event.preventDefault();
  const what = target($("counter-where").value);
  if (!what || !what.model) {
    $("counter-said").textContent = "That is not the address of a model: it looks like https://brickworks.diy/m/ and ten letters.";
    return;
  }
  const note = `Counter-notice. ${$("counter-why").value.trim()}\n\nSigned: ${$("counter-name").value.trim()}. `
    + `Address and phone: ${$("counter-address").value.trim()}. On pain of perjury, in good faith, it was taken out `
    + "by mistake or misidentified. Consents to the federal district court for that address (or, outside the "
    + "United States, any district where Brickworks may be found) and will accept service from whoever asked for the takedown.";
  $("counter-send").disabled = true;
  $("counter-said").textContent = "Sending…";
  try {
    await send({ model: what.model, reason: "other", counter: true, note, contact: $("counter-contact").value });
    $("counter").reset();
    $("counter-said").textContent = "Sent. The site's owner will pass it on, and write to you at the address you gave.";
  } catch (trouble) {
    $("counter-said").textContent = trouble.message;
  } finally {
    $("counter-send").disabled = false;
  }
});
