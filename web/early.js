// Early features, on the site (beta374, 2026-10-30): which this account may
// use before everyone, as the server says (GET /api/account, its beta:
// {tester, early}: api/_early.js), asked once a tab and kept for it.
//
//   earlyOn("beta_hub")   true for a beta tester, false for anyone else
//   beta()                {tester, early}
//
// A gate is one line where its feature is drawn: if (await earlyOn(key)).
// Nothing is asked of the server for a visitor who is not signed in.
import { call, email, signedIn } from "/account.js";

const KEPT = "brickworks.early";
const NOBODY = Object.freeze({ tester: false, early: [] });
let asking = null;

/// {tester, early} for whoever is signed in here.
export function beta() {
  if (!signedIn()) return Promise.resolve(NOBODY);
  try {
    const kept = JSON.parse(sessionStorage.getItem(KEPT) || "null");
    if (kept && kept.email === email()) return Promise.resolve(kept);
  } catch {
    // Not kept: asked.
  }
  asking ||= call("/api/account").then(({ status, body }) => {
    const said = status === 200 && body?.beta ? body.beta : NOBODY;
    const kept = { email: email(), tester: said.tester === true, early: Array.isArray(said.early) ? said.early : [] };
    if (status === 200) {
      try {
        sessionStorage.setItem(KEPT, JSON.stringify(kept));
      } catch {
        // Asked again on the next page.
      }
    }
    return kept;
  }).catch(() => NOBODY);
  return asking;
}

/// Whether the early feature [key] is on for whoever is signed in here.
export async function earlyOn(key) {
  return (await beta()).early.includes(key);
}
