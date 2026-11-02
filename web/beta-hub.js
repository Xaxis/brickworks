// The beta hub (/beta-hub, beta374): for a beta tester, what is new to try,
// what we know is wrong and the early features on their account, as the
// server says (GET /api/plans?op=beta_hub, api/_early.js); for anyone else,
// what the page is and where the beta is. Everything is put on the page as
// text.
import { askToSignIn, call, signedIn } from "/account.js";
import { langAt, say, told } from "/card.js";

const $ = (id) => document.getElementById(id);
const WHERE = { site: () => say("On the site"), app: () => say("In the app"), both: () => say("In the app and on the site") };
// A page of the site with a copy in the page's language opens it (/library
// as /de/library); the docs have none.
const ledTo = (href) => (/^\/(?:library|gallery|feedback|settings|plans)(?=[/?#]|$)/.test(href) ? `${langAt()}${href}` : href);

/// One card, of what is new, known or early: its title and words as we wrote
/// them, notes in English like the changelog's (lang="en"), and where it
/// is, in the page's language.
function card({ title, words, where, href }) {
  const item = document.createElement("li");
  item.className = "card";
  const head = document.createElement("h3");
  head.textContent = title;
  head.lang = "en";
  const said = document.createElement("p");
  said.textContent = words;
  said.lang = "en";
  item.append(head, said);
  if (href) {
    const link = document.createElement("a");
    link.className = "pill";
    link.href = ledTo(href);
    link.textContent = WHERE[where] ? say("{where}: open it", { where: WHERE[where]() }) : say("Open it");
    item.append(link);
  } else if (WHERE[where]) {
    const pill = document.createElement("span");
    pill.className = "pill";
    pill.textContent = WHERE[where]();
    item.append(pill);
  }
  return item;
}

async function show() {
  const state = $("state");
  if (!signedIn()) {
    state.hidden = true;
    $("signed-out").hidden = false;
    return;
  }
  const { status, body } = await call("/api/plans?op=beta_hub").catch(() => ({ status: 0, body: {} }));
  state.hidden = status === 200 || status === 403;
  if (status === 403) {
    $("not-tester").hidden = false;
    return;
  }
  if (status !== 200) {
    state.textContent = told(body?.error, say("The hub did not load just now. Try again in a minute."));
    return;
  }
  $("new").replaceChildren(...(body.new || []).map(card));
  $("known").replaceChildren(...(body.known || []).map((one) => card({ ...one, where: "" })));
  $("early").replaceChildren(...(body.early || []).map(card));
  $("hub").hidden = false;
}

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in with the account your beta application was approved for.")) location.reload();
});
show();
