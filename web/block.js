// Block somebody, or unblock them (2026-11-19, api/_blocks.js,
// supabase/block.sql). From a profile's More menu (web/follow.js draws its
// item once it knows who is asking), a comment's row (web/model-page.js),
// and Settings › Blocked people (web/settings.js), each through blockPerson.
//
// Blocking asks first, in one line that says what it does; unblocking does
// not, since it only gives back what the block took away. The person
// blocked is never told: nothing here or on the server sends them a word.
// Their name goes on the page as text, never as markup.
import { askToSignIn, call, signedIn } from "/account.js";
import { say, told } from "/card.js";

/// What a block does, in the one line it is confirmed with.
export function blockAsked(name) {
  return say("Block {name}? Their models leave your gallery and feed, their comments on your models are hidden, "
    + "and follows between you end. They aren’t told.", { name });
}

/// The person with [handle] (called [name]) blocked ([on] true) or unblocked:
/// {ok, blocked, said}, said in words either way; ok false and said "" when
/// they chose not to, or did not sign in. Asked first for a block.
export async function blockPerson(handle, name, on) {
  if (!signedIn() && !(await askToSignIn(say("Sign in to block somebody: we email you a code, no password.")))) {
    return { ok: false, blocked: !on, said: "" };
  }
  if (on && !confirm(blockAsked(name))) return { ok: false, blocked: false, said: "" };
  const answer = await call("/api/people?op=block", { method: "POST", body: { handle, on } })
    .catch(() => ({ status: 0, body: {} }));
  if (answer.status !== 200) {
    return { ok: false, blocked: !on, said: told(answer.body?.error, say("That did not work just now. Try again in a minute.")) };
  }
  const blocked = answer.body.blocked === true;
  return { ok: true, blocked, said: blocked
    ? say("You blocked {name}. Unblock them here or in Settings › Blocked people.", { name })
    : say("You unblocked {name}: their models and comments are back. Follows between you aren’t.", { name }) };
}

/// A profile's Block item ([button], data-block and data-block-name), drawn
/// as [state] (api/_follows.js followsOf) says: hidden on your own profile
/// and signed out, Unblock where you blocked them.
export function drawBlockItem(button, state) {
  const name = button.dataset.blockName || button.dataset.block;
  button.hidden = !state || state.mine || !state.signed_in;
  button.textContent = state?.you_block ? say("Unblock {name}", { name }) : say("Block {name}", { name });
  button.dataset.blocked = state?.you_block ? "yes" : "no";
}
