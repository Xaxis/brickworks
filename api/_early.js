// Early features: what beta testers try before everyone (beta374,
// 2026-10-30), and the beta hub's words (/beta-hub, web/beta-hub.js).
//
// A tester is an account whose beta application was approved
// (supabase/feedback.sql beta_tester). The server says which early
// features an account may use, and the site and the app only show:
//
//   GET /api/account, signed in      beta: {tester, early: [key]}, the keys
//                                    of EARLY for a tester, none for anyone
//                                    else (api/account.js)
//   GET /api/plans?op=beta_hub       a tester's: {early, new, known}; 403
//                                    for anyone else
//
// The site asks earlyOn(key) (web/early.js), the app Account.early_on(key)
// (src/account/account.gd); each gate is one line where the feature is
// drawn. To gate a feature: add it to EARLY with a key, gate it where it
// is drawn, and say what to try in the hub's words. To open it to
// everyone: take the gates out, then its line here (a key the server no
// longer sends shuts it for testers too, so the gate goes first).
//
// Only what the person sees is gated. A route an early feature calls
// checks beta_tester itself if what it does must be the testers' alone.

/// What testers may use first: {key, title, words, where: site | app | both}.
export const EARLY = Object.freeze([
  { key: "beta_hub", title: "The beta hub", where: "both",
    words: "This page: what to try, what we know is wrong, and how to tell us. Help, Beta hub in the app, and "
      + "your account menu on the site." },
]);

/// What is new to try, newest first: {title, words, where, href}.
export const NEW = Object.freeze([
  { title: "Send feedback from anywhere", where: "both", href: "/docs/feedback",
    words: "Help, Send feedback in the app, or Send feedback in the site's footer: a bug, an idea or a question, "
      + "with a picture of what you see and, if you agree, the model and the app's last log lines. Your reports and "
      + "our answers are on your settings page." },
  { title: "Choose who designs", where: "app", href: "/docs/ai",
    words: "Settings, AI: Claude, or another AI on your own key (OpenAI, Gemini, OpenRouter, Mistral, a model on your "
      + "own computer). Test it first; it says plainly what works." },
  { title: "The LDraw library on the website", where: "site", href: "/library",
    words: "Every model of a real set the app's Library opens, browsed like the gallery, each with its own page." },
]);

/// What we know is wrong and are working on: {title, words}.
export const KNOWN = Object.freeze([
  { title: "The first visit to the web app is slow",
    words: "The app and its parts are about 17 MB the first time; later visits start from what the browser kept." },
  { title: "Choosing another AI is on the desktop's command line first",
    words: "Settings, AI has the providers; designing with one from the assistant's column is still being finished." },
]);

/// The keys of EARLY [tester] may use: every one for a tester, none for anyone else.
export function earlyFor(tester) {
  return tester ? EARLY.map((one) => one.key) : [];
}
