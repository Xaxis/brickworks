// Following a person, and what is new for you (2026-10-18,
// supabase/follows.sql): the Follow button on a profile (/u/<handle>) and
// beside a model's designer (/m/<id>), and the count on Account in the
// site's header.
//
// A button with data-follow="<handle>" is shown once the server says who
// is asking: Follow, or Following (pressed again, letting them go). Signed
// out, it asks to sign in first; an account that may not follow is told
// why, in the server's words, beside it. Following tells the person
// followed nothing, and there is no way to write to them from here.
//
// Account (a[data-account] in the header) gets a small count of what came
// into the feed since it was last opened, and leads to /feed while there
// is something. Nothing is asked of the server for a visitor who is not
// signed in.
//
// Everything is put on the page as text.
import { askToSignIn, call, signedIn } from "/account.js";

const plural = (n, one, many = `${one}s`) => `${Number(n).toLocaleString("en-US")} ${n === 1 ? one : many}`;

/// One Follow button, made live.
async function followButton(button) {
  const handle = button.dataset.follow;
  const said = button.parentElement?.querySelector(".said") || null;
  const say = (words) => {
    if (said) said.textContent = words ? ` ${words}` : "";
  };
  let state = null;
  const draw = () => {
    button.textContent = state.you_follow ? "Following" : "Follow";
    button.setAttribute("aria-pressed", state.you_follow ? "true" : "false");
    button.title = state.you_follow ? "You follow them: press to stop" : "See what they share in your feed";
    button.hidden = state.mine;
    for (const counted of document.querySelectorAll(`[data-followers="${handle}"], .person[data-handle="${handle}"] [data-followers]`)) {
      counted.textContent = plural(state.followers, "follower");
    }
  };
  const ask = async () => {
    const answer = await call(`/api/people?op=follows&handle=${encodeURIComponent(handle)}`);
    if (answer.status !== 200 || !answer.body.ready) return false;
    state = answer.body;
    draw();
    return true;
  };
  if (!(await ask())) return;
  button.addEventListener("click", async () => {
    say("");
    if (!state.signed_in) {
      if (!(await askToSignIn("Sign in to follow people: we email you a code, no password."))) return;
      if (!(await ask())) return;
      if (state.mine || state.you_follow) return;
    }
    if (!state.you_follow && !state.may) {
      say(state.why_not);
      return;
    }
    button.disabled = true;
    const answer = await call("/api/people?op=follow", { method: "POST", body: { handle, on: !state.you_follow } });
    button.disabled = false;
    if (answer.status !== 200) {
      say(answer.body.error || "That did not work just now. Try again in a minute.");
      return;
    }
    state = { ...state, ...answer.body };
    draw();
    say(state.you_follow ? "What they share is in your feed now." : "");
  });
}

/// The count on Account: what came into the feed since it was opened.
export async function showFeedCount() {
  const places = [...document.querySelectorAll("a[data-account]")];
  if (places.length === 0) return 0;
  let count = 0;
  if (signedIn() && location.pathname !== "/feed") {
    const answer = await call("/api/people?op=feed_count").catch(() => null);
    count = answer && answer.status === 200 ? Number(answer.body.count) || 0 : 0;
  }
  for (const link of places) {
    link.querySelector(".count")?.remove();
    link.href = count > 0 ? "/feed" : "/profile";
    if (count > 0) {
      const badge = document.createElement("span");
      badge.className = "count";
      badge.textContent = count > 98 ? "99+" : String(count);
      badge.setAttribute("aria-label", `${plural(count, "new thing")} in your feed`);
      link.append(" ", badge);
    }
  }
  // On a phone the header's links are behind Menu: the count is on it too.
  for (const menu of document.querySelectorAll(".site-head .menu summary")) {
    menu.querySelector(".count")?.remove();
    if (count > 0) {
      const badge = document.createElement("span");
      badge.className = "count";
      badge.textContent = count > 98 ? "99+" : String(count);
      badge.setAttribute("aria-hidden", "true");
      menu.append(" ", badge);
    }
  }
  return count;
}

for (const button of document.querySelectorAll("button[data-follow]")) followButton(button).catch(() => null);
showFeedCount().catch(() => null);
