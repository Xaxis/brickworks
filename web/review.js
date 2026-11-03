// The review sign-in (web/review.html): a review account, at a Resend
// test address, signed in by its password and kept as every sign-in is
// (web/account.js), so the app and the connector's sign-in find it. Any
// other address is sent to the emailed code: this page signs in nobody
// else. English only, as the page is.
import { email, signInWithPassword, signOut, signedIn } from "/account.js";

// The only accounts a password signs in to (api/_auth.js isTestAccount).
const REVIEW_ADDRESS = /@resend\.dev$/i;

const $ = (id) => document.getElementById(id);
const tell = (words, bad = false) => {
  $("say").textContent = words;
  $("say").classList.toggle("bad", bad);
};

function show(signedInAs) {
  $("sign-in-step").classList.toggle("hide", Boolean(signedInAs));
  $("done-step").classList.toggle("hide", !signedInAs);
  $("signed-in-as").textContent = signedInAs || "";
}

$("sign-in-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const address = $("email").value.trim().toLowerCase();
  const password = $("password").value;
  if (!REVIEW_ADDRESS.test(address)) {
    tell("This page signs in review accounts only. Every other account signs in with a code we email.", true);
    return;
  }
  if (!password) {
    tell("Type the review account’s password.", true);
    return;
  }
  $("go").disabled = true;
  tell("Signing in…");
  try {
    const signed = await signInWithPassword(address, password);
    if (signed.ok) {
      tell("");
      show(address);
      return;
    }
    if (signed.status === 429) tell("Too many tries just now. Wait a few minutes and try again.", true);
    else if (signed.status === 400) tell("That address and password are not a review account’s. Check them and try again.", true);
    else tell(`Could not sign in just now (${signed.status}). Try again.`, true);
  } catch (trouble) {
    tell(String(trouble?.message || trouble), true);
  } finally {
    $("go").disabled = false;
  }
});

$("sign-out").addEventListener("click", () => {
  signOut();
  show("");
  tell("Signed out.");
});

// Signed in as a review account already, in this browser: the next steps.
if (signedIn() && REVIEW_ADDRESS.test(email())) show(email());
