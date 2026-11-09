// The beta's welcome (betajoin, 2026-11-09): joining the beta is a step of
// signing up. While the beta is open, a new account, right after its code
// is accepted and the age question answered (web/account.js
// askAgeIfAsked), sees this once, before First steps: what Brickworks is,
// that it is in beta, what a tester does and gets, and Join the beta
// testers or Not now. Nothing is ticked for them. Join makes the account a
// tester at once (POST /api/plans?op=beta_join), and the dialog says so in
// place, with where to follow what they send; Not now (or Escape) is kept
// by the server (op=beta_leave), so the welcome never comes again, and the
// account joins later from Settings, the homepage or the beta hub. The
// server says when it is due (/api/account's beta.welcome: open, a new
// account, not asked yet); nothing is decided here.
//
// What it takes from whom: one decision a screen with a clear first choice
// and a quiet skip (Linear's onboarding), the beta named in a small label
// rather than a banner (Figma's), one press to join and one to leave, with
// no form in the way (GitHub's Feature preview), and a thank-you that says
// where things are now (Arc's welcome).
//
// Every word is said in the visitor's language, as the sign-in's dialogs
// say theirs (tools/site_lang.py SAID_ALL).
import { call, learn, say, speaking } from "/account.js";
import { langAt } from "/card.js";

/// An element, its class, and what is in it: text or elements.
function make(tag, className = "", ...inside) {
  const made = document.createElement(tag);
  if (className) made.className = className;
  for (const one of inside) if (one !== null && one !== undefined && one !== "") made.append(one);
  return made;
}

function button(words, className, id) {
  const made = make("button", className, words);
  made.type = "button";
  made.id = id;
  return made;
}

/// A link, [href] made by the caller in the page's language (langAt).
function linked(words, href) {
  const made = make("a", "", words);
  made.href = href;
  return made;
}

/// [said], a sentence in the visitor's language, into [into]: each {name}
/// in it [parts]'s element.
function sayInto(into, said, parts) {
  for (const piece of said.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && name in parts ? parts[name] : piece);
  }
  return into;
}

/// The welcome, over the page. [via]: where the press to join is counted
/// (api/_beta.js VIA). Resolves "joined", "not_now" or null (the server
/// did not take the answer), once it is closed.
export async function betaWelcome({ via = "welcome" } = {}) {
  await learn();
  return new Promise((done) => {
    const dialog = make("dialog", "beta-welcome");
    speaking(dialog);
    dialog.setAttribute("aria-labelledby", "beta-welcome-title");
    dialog.setAttribute("aria-describedby", "beta-welcome-what");
    const eyebrow = make("p", "eyebrow", say("Open beta"));
    const title = make("h2", "", say("Welcome to Brickworks"));
    title.id = "beta-welcome-title";
    const what = make("p", "what", say("A CAD for LEGO® models, in your browser: every LDraw part, joined where the real ones join."));
    what.id = "beta-welcome-what";
    const beta = make("p", "", say("It is in open beta: it works, and it gets better every week with what builders tell us."));
    const gets = make("p", "gets", say("Testers try new features first and tell us what is wrong. The first 100 we pick get a month of Pro."));
    const join = button(say("Join the beta testers"), "cta", "beta-join");
    const later = button(say("Not now"), "cta ghost", "beta-not-now");
    const note = make("p", "said");
    note.setAttribute("role", "status");
    const terms = sayInto(make("p", "note"), say("Joining agrees to {terms} and to emails about the beta. Leave any time in Settings."),
      { terms: linked(say("the beta's terms"), `${langAt()}/terms#beta`) });
    const body = make("div", "step", what, beta, gets, make("div", "actions", join, later), note, terms);
    dialog.append(eyebrow, title, body);
    document.body.append(dialog);

    let finished = false;
    let answer = null;
    const end = () => {
      if (finished) return;
      finished = true;
      dialog.close();
      dialog.remove();
      done(answer);
    };
    // Said and kept, as the person chose: [op] beta_join or beta_leave.
    const send = async (op) => {
      join.disabled = true;
      later.disabled = true;
      note.textContent = "";
      const said = await call(`/api/plans?op=${op}`, { method: "POST", body: op === "beta_join" ? { via } : {} })
        .catch(() => null);
      join.disabled = false;
      later.disabled = false;
      if (said && said.status === 200) return said.body;
      note.textContent = said && said.body.error ? say(said.body.error) : say("That did not go just now. Try again in a minute.");
      return null;
    };

    join.addEventListener("click", async () => {
      const said = await send("beta_join");
      if (!said || said.tester !== true) return;
      answer = "joined";
      // The thank-you, in place: where things are now, and on.
      title.textContent = say("You are a beta tester");
      const carry = button(say("Carry on"), "cta", "beta-carry-on");
      carry.addEventListener("click", end);
      body.replaceChildren(
        make("p", "", say("Thank you. Report a bug whenever something is wrong, from wherever you are. What you send, and our answers, are in Settings.")),
        sayInto(make("p", "gets"), say("For a month of Pro, {link}: it takes a minute."),
          { link: linked(say("tell us what you build"), `${langAt()}/beta#apply`) }),
        make("div", "actions", carry));
      dialog.dataset.step = "joined";
      carry.focus();
    });
    later.addEventListener("click", async () => {
      if (await send("beta_leave")) answer = "not_now";
      end();
    });
    // Escape is Not now, kept the same way; after joining, it carries on.
    dialog.addEventListener("cancel", (event) => {
      event.preventDefault();
      if (answer === "joined") return end();
      later.click();
    });
    dialog.showModal();
    join.focus();
  });
}
