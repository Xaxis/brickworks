// /feed (2026-10-18, supabase/follows.sql): what is new for the signed-in
// account, newest first, from /api/people?op=feed. Each row is one link,
// to the model, the version, the photo or the comment; the rows that came
// since the feed was last opened are marked new. Opening it is what clears
// the count on Account (the server marks the first page as seen).
//
// Every word is put on the page as text.
import { askToSignIn, call, signOut, signedIn } from "/account.js";
import { showFeedCount } from "/follow.js";

const $ = (id) => document.getElementById(id);
const WHEN = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
let oldest = null;

function row(one) {
  const item = document.createElement("li");
  item.className = `feed-row ${one.kind}${one.new ? " new" : ""}`;
  item.dataset.kind = one.kind;
  const link = document.createElement("a");
  // Only the site's own addresses: what the server made from ids.
  try {
    const url = new URL(String(one.link || ""), location.origin);
    link.href = url.origin === location.origin ? url.pathname + url.search + url.hash : "/feed";
  } catch {
    link.href = "/feed";
  }
  const what = document.createElement("p");
  what.className = "what";
  const who = document.createElement("b");
  who.textContent = String(one.who || "A builder");
  const name = document.createElement("b");
  name.textContent = `“${String(one.name || "")}”`;
  what.append(who, ` ${String(one.did || "")} `, name);
  if (one.after) what.append(` ${String(one.after)}`);
  if (one.new) {
    const tag = document.createElement("span");
    tag.className = "tag";
    tag.textContent = "New";
    what.append(tag);
  }
  link.append(what);
  if (one.said) {
    const said = document.createElement("q");
    said.textContent = String(one.said);
    link.append(said);
  }
  const at = Date.parse(String(one.at || ""));
  if (Number.isFinite(at)) {
    const when = document.createElement("small");
    when.textContent = WHEN.format(at);
    link.append(when);
  }
  item.append(link);
  return item;
}

async function page() {
  const answer = await call(`/api/people?op=feed${oldest ? `&before=${encodeURIComponent(oldest)}` : ""}`);
  if (answer.status === 401) {
    signOut();
    return load();
  }
  if (answer.status !== 200) {
    $("said").textContent = answer.body.error || "Brickworks could not show your feed just now. Try again in a minute.";
    return;
  }
  if (answer.body.ready === false) {
    $("not-yet").hidden = false;
    document.documentElement.dataset.feed = "not-yet";
    return;
  }
  const rows = Array.isArray(answer.body.rows) ? answer.body.rows : [];
  for (const one of rows) $("rows").append(row(one));
  if (rows.length) oldest = rows[rows.length - 1].at;
  $("empty").hidden = $("rows").children.length > 0;
  $("older").hidden = !answer.body.more;
  // Opened: what was counted is seen now.
  await showFeedCount().catch(() => null);
  document.documentElement.dataset.feed = "ready";
}

async function load() {
  $("loading").hidden = true;
  if (!signedIn()) {
    $("signed-out").hidden = false;
    $("signed-in").hidden = true;
    document.documentElement.dataset.feed = "signed-out";
    return;
  }
  $("signed-out").hidden = true;
  $("signed-in").hidden = false;
  $("rows").replaceChildren();
  oldest = null;
  await page();
}

$("sign-in").addEventListener("click", async () => {
  if (await askToSignIn("Sign in with your email address: we send you a code, no password.")) load();
});
$("older").addEventListener("click", async () => {
  $("older").disabled = true;
  await page();
  $("older").disabled = false;
});

load();
