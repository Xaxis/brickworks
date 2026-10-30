// A set's page, /library/set/<number> (sets364, api/_sets.js setPage): for
// somebody signed in, how much of the set their collection holds, counted
// as the app's My collection counts it (api/share.js ?op=catalog_owned), and
// what they are missing as a BrickLink wanted list or a Rebrickable parts
// list to download. Its parts list is a model page's (web/model-page.js);
// nobody signed in sees the page as it is sent.
//
// The page says what it found on <html data-owned>: "have/pieces", "none"
// for no collection, "broken" when it could not ask (tools/web/sets_flow.mjs
// reads it).
import { call, signedIn } from "/account.js";

const owned = document.getElementById("owned");
if (owned && /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/.test(owned.dataset.set || "") && signedIn()) start(owned);

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
