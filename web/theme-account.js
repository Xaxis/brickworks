// The theme on the account (2026-10-22, supabase/theme.sql), so a new
// browser follows a person once they sign in. web/theme.js keeps the
// choice in this browser and loads this only for somebody signed in.
//
// Once a tab, the account is asked: a theme it has is applied here; an
// account with none takes this browser's, if one was chosen. Each choice
// after is sent to it. Until theme.sql is applied the server answers
// ready: false, and the choice stays this browser's alone.
import { call, email, signedIn } from "/account.js";

const ASKED = "brickworks.theme.asked";
const theme = window.brickworksTheme;

async function keep(choice) {
  if (!signedIn()) return;
  await call("/api/account?op=theme", { method: "POST", body: { theme: choice } }).catch(() => null);
}

let listening = false;

/// The account's theme here, and this tab's choices sent to it.
export async function follow() {
  if (!theme || !signedIn()) return;
  if (!listening) {
    listening = true;
    document.addEventListener("brickworks:theme", (event) => keep(event.detail));
  }
  const who = email();
  try {
    if (sessionStorage.getItem(ASKED) === who) return;
  } catch {
    // Asked again below.
  }
  const answer = await call("/api/account?op=theme").catch(() => null);
  if (!answer || answer.status !== 200 || !answer.body.ready) return;
  try {
    sessionStorage.setItem(ASKED, who);
  } catch {
    // Asked again on the next page.
  }
  if (answer.body.chosen) {
    if (answer.body.theme !== theme.chosen()) theme.choose(answer.body.theme, true);
  } else if (theme.picked()) {
    await keep(theme.chosen());
  }
}
