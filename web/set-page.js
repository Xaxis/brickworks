// A set's page, /library/set/<number> (sets364, api/_sets.js setPage): for
// somebody signed in, how much of the set their collection holds, counted
// as the app's My collection counts it (api/share.js ?op=catalog_owned), and
// what they are missing as a BrickLink wanted list or a Rebrickable parts
// list to download. Its parts list is a model page's (web/model-page.js);
// nobody signed in sees the page as it is sent.
//
// For everybody, the models in the gallery built from the set or based on
// it (api/_bases.js setBased, docs/SOCIAL.md section 7, item 5): a row of
// their cards after the page's parts, before the set's theme. They change
// as designers say so, and the page is kept a day, so they are asked here.
//
// The page says what it found on <html data-owned>: "have/pieces", "none"
// for no collection, "broken" when it could not ask (tools/web/sets_flow.mjs
// reads it); and on <html data-based> how many models are built from it,
// "broken" when it could not ask (tools/web/based_on_flow.mjs).
import { call, signedIn } from "/account.js";
import { modelCard } from "/card.js";

const SET = /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/;
const owned = document.getElementById("owned");
if (owned && SET.test(owned.dataset.set || "") && signedIn()) start(owned);
const page = document.querySelector("article.set-page");
if (page && SET.test(page.dataset.set || "")) builtFrom(page);

/// The row of models based on the set, put before More <theme> (#similar),
/// or at the page's end; none, no row.
async function builtFrom(article) {
  const tests = new URLSearchParams(location.search).get("tests") === "1" ? "&tests=1" : "";
  const reply = await fetch(`/api/share?op=set_based&set=${encodeURIComponent(article.dataset.set)}${tests}`).catch(() => null);
  const body = reply && reply.ok ? await reply.json().catch(() => null) : null;
  if (!body || !Array.isArray(body.models)) {
    document.documentElement.dataset.based = "broken";
    return;
  }
  const models = body.models.filter((model) => model && typeof model.id === "string");
  if (models.length) {
    const section = document.createElement("section");
    section.className = "next";
    section.id = "built-from";
    section.setAttribute("aria-labelledby", "built-from-h");
    section.innerHTML = '<div class="scroller-head"><h2 id="built-from-h">Based on this set</h2></div>'
      + '<div class="models scroller" role="group" aria-labelledby="built-from-h"></div>';
    section.querySelector(".models").append(...models.map((model) => modelCard(model)));
    const similar = document.getElementById("similar");
    if (similar) similar.before(section);
    else article.append(section);
  }
  document.documentElement.dataset.based = String(models.length);
}

async function start(section) {
  const set = section.dataset.set;
  const said = document.getElementById("owned-said");
  const reply = await call(`/api/share?op=catalog_owned&set=${encodeURIComponent(set)}`).catch(() => null);
  if (!reply || reply.status !== 200 || !reply.body || typeof reply.body !== "object") {
    document.documentElement.dataset.owned = "broken";
    return;
  }
  const body = reply.body;
  const pieces = Number(body.pieces) || 0;
  const have = Math.min(Number(body.have) || 0, pieces);
  section.hidden = false;
  if (!body.collection) {
    said.textContent = "Your collection is empty. Add the sets and parts you own under My collection in the app, "
      + "and this says how much of this set you have.";
    document.documentElement.dataset.owned = "none";
    return;
  }
  const n = (value) => value.toLocaleString("en-US");
  said.textContent = have >= pieces ? `Parts you own: all ${n(pieces)} of them.`
    : `Parts you own: ${n(have)} of ${n(pieces)}. You are missing ${n(pieces - have)} in `
      + `${n(Number(body.missing) || 0)} ${Number(body.missing) === 1 ? "lot" : "lots"}.`;
  document.documentElement.dataset.owned = `${have}/${pieces}`;
  const wanted = document.getElementById("owned-wanted");
  if (have >= pieces || !wanted || !body.wanted) return;
  wanted.hidden = false;
  const files = {
    bricklink: [body.wanted.bricklink, "application/xml", `${set}-missing-bricklink.xml`],
    rebrickable: [body.wanted.rebrickable, "text/csv", `${set}-missing-rebrickable.csv`],
  };
  for (const button of wanted.querySelectorAll("[data-wanted]")) {
    const [text, type, name] = files[button.dataset.wanted] || [];
    if (typeof text !== "string") {
      button.hidden = true;
      continue;
    }
    button.addEventListener("click", () => {
      const link = document.createElement("a");
      link.href = URL.createObjectURL(new Blob([text], { type }));
      link.download = name;
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(link.href), 1000);
    });
  }
}
