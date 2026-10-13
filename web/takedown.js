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

$("claim").addEventListener("submit", async (event) => {
  event.preventDefault();
  const what = target($("where").value);
  if (!what) {
    $("said").textContent = "That is not the address of a model, a profile or a collection in the gallery.";
    return;
  }
  $("send").disabled = true;
  $("said").textContent = "Sending…";
  try {
    const reply = await fetch("/api/people?op=report", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ ...what, reason: $("why").value, note: $("what").value, contact: $("contact").value }),
    });
    const body = await reply.json().catch(() => ({}));
    if (!reply.ok) throw new Error(body.error || `Brickworks said ${reply.status}.`);
    $("claim").reset();
    $("said").textContent = "Sent. The site's owner will write to you at the address you gave.";
  } catch (trouble) {
    $("said").textContent = trouble.message;
  } finally {
    $("send").disabled = false;
  }
});
