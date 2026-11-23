// The console's Talk (admin.html #talk): the posts reported in Talk, its
// threads and who is banned from it, with the owner's acts on each
// (api/_console_talk.js through /api/admin, each kept in the audit log).
// /admin?tests=1: the checks' own threads instead.
//
// Everything is put on the page as text, never as markup: every word here
// was typed by somebody else.
import { $, TESTS, adminJson, ago, cell, count, link, make, post, rowAct, say } from "/admin-kit.js";

const BOARDS = { show: "Show and tell", help: "Help", ideas: "Ideas", challenges: "Challenges", news: "News" };
const REASONS = { spam: "Spam", offensive: "Offensive", sexual: "Sexual", violent: "Violent", copied: "Copied",
  trademark: "A mark", personal: "Personal information", other: "Something else" };
// How long a ban lasts, from the reported post.
const BANS = [["1", "A day"], ["7", "A week"], ["30", "A month"], ["", "For good"]];
let searched = "";

const threadLink = (id, title) => link(`/talk/t/${Number(id)}${TESTS ? "?tests=1" : ""}`, title || `thread ${id}`);

/// One act on Talk, then everything read again. Its row is drawn again
/// (a report let go is gone from the list), so what it did is said above
/// the tabs; a refusal stays at [where], on the row that is still there.
async function act(body, where, said) {
  const went = await post("op=talk_act", where, said, { body, after: () => loadTalk() });
  if (went) say("talk-said", said);
  return went;
}
const quote = (title) => `“${String(title || "").slice(0, 80)}”`;

/// The open reports, a post at a time: its words, the reasons and notes
/// given, and Hide, Remove, Ban its writer, or Let it go.
function drawReports(reports) {
  const list = $("talk-reports");
  list.replaceChildren();
  const posts = new Map();
  for (const one of reports) {
    if (!posts.has(one.post)) posts.set(one.post, { ...one, why: [] });
    posts.get(one.post).why.push(one);
  }
  for (const one of posts.values()) {
    const item = make("li", "talk-queue-item");
    item.id = `talk-post-${one.post}`;
    const head = make("p", "talk-queue-head");
    head.append(threadLink(one.thread, one.title), " · ", one.handle ? link(`/u/${encodeURIComponent(one.handle)}`, `@${one.handle}`)
      : "an account", ` · ${count(one.reports)} open report${Number(one.reports) === 1 ? "" : "s"}`,
    one.hidden ? ` · hidden ${one.hidden_by === "reports" ? "by the reports" : "by you"}` : "", one.banned ? " · banned" : "");
    const words = make("blockquote", "talk-queue-words", one.body);
    const why = make("ul", "talk-queue-why");
    for (const report of one.why) {
      why.append(make("li", "", `${REASONS[report.reason] || report.reason}, ${ago(report.at)}`, report.note ? `: “${report.note}”` : ""));
    }
    const where = make("p", "note");
    where.setAttribute("role", "status");
    const whose = `${one.handle ? `@${one.handle}’s` : "the"} post in ${quote(one.title)}`;
    const acts = make("p", "actions");
    acts.append(
      one.hidden ? rowAct("Show it, and let the reports go", () => act({ act: "show", post: one.post }, where, `Shown again: ${whose}.`))
        : rowAct("Hide it", () => act({ act: "hide", post: one.post }, where, `Hidden: ${whose}.`)),
      rowAct("Remove it", () => (confirm("Remove this post from Talk for good?")
        ? act({ act: "remove", post: one.post }, where, `Removed: ${whose}.`) : Promise.resolve(false))),
      rowAct("Let the reports go", () => act({ act: "dismiss", post: one.post }, where, `Reports let go: ${whose}.`)));
    if (!one.banned) {
      const length = make("select");
      length.setAttribute("aria-label", "How long the ban lasts");
      for (const [days, words] of BANS) {
        const option = make("option", "", words);
        option.value = days;
        length.append(option);
      }
      acts.append(length, rowAct("Ban the writer from Talk", () => {
        const days = Number(length.value);
        const until = days ? new Date(Date.now() + days * 864e5).toISOString() : "";
        return act({ act: "ban", post: one.post, until, reason: `Reported: ${one.why.map((r) => r.reason).join(", ")}` }, where, `Banned from Talk: ${one.handle ? `@${one.handle}` : "the writer"}.`);
      }));
    }
    item.append(head, words, why, acts, where);
    list.append(item);
  }
  say("talk-reports-note", posts.size ? "" : "Nothing reported in Talk is waiting.");
  const n = $("tab-talk-reports");
  if (n) n.textContent = posts.size ? String(posts.size) : "";
  const badge = $("nav-talk");
  if (badge) {
    badge.textContent = String(posts.size);
    badge.hidden = posts.size === 0;
  }
}

/// The threads, newest talk first: open each, and pin, lock, move, hide
/// or remove it.
function drawThreads(threads) {
  const body = $("talk-threads");
  body.replaceChildren();
  for (const one of threads) {
    const row = make("tr");
    cell(row, threadLink(one.id, one.title));
    cell(row, BOARDS[one.board] || one.board);
    cell(row, one.by_house ? "Brickworks" : one.handle ? `@${one.handle}` : "—");
    cell(row, count(one.posts));
    cell(row, ago(one.last_at));
    cell(row, [one.pinned && "pinned", one.locked && "locked", one.hidden && "hidden", one.removed && `removed by ${one.removed_by}`,
      one.moved_from && `moved from ${BOARDS[one.moved_from] || one.moved_from}`].filter(Boolean).join(", ") || "open");
    const where = make("span", "note");
    where.setAttribute("role", "status");
    const acts = make("div", "actions");
    if (!one.removed) {
      acts.append(
        rowAct(one.pinned ? "Unpin" : "Pin", () => act({ act: one.pinned ? "unpin" : "pin", thread: one.id }, where,
          `${one.pinned ? "Unpinned" : "Pinned"}: ${quote(one.title)}.`)),
        rowAct(one.locked ? "Unlock" : "Lock", () => act({ act: one.locked ? "unlock" : "lock", thread: one.id }, where,
          `${one.locked ? "Unlocked" : "Locked"}: ${quote(one.title)}.`)),
        rowAct(one.hidden ? "Show" : "Hide", () => act({ act: one.hidden ? "show" : "hide", thread: one.id }, where,
          `${one.hidden ? "Shown again" : "Hidden"}: ${quote(one.title)}.`)));
      const to = make("select");
      to.setAttribute("aria-label", `Move “${one.title}” to`);
      for (const [id, name] of Object.entries(BOARDS)) {
        const option = make("option", "", name);
        option.value = id;
        option.selected = id === one.board;
        to.append(option);
      }
      acts.append(to, rowAct("Move", () => act({ act: "move", thread: one.id, board: to.value }, where,
        `Moved to ${BOARDS[to.value] || to.value}: ${quote(one.title)}.`)),
        rowAct("Remove", () => (confirm(`Remove “${one.title}” and every post in it from Talk?`)
          ? act({ act: "remove", thread: one.id }, where, `Removed: ${quote(one.title)}.`) : Promise.resolve(false))));
    }
    acts.append(where);
    cell(row, acts);
    body.append(row);
  }
  say("talk-threads-note", threads.length ? `${count(threads.length)} thread${threads.length === 1 ? "" : "s"}${searched ? " found" : ""}.`
    : searched ? "No thread's title has those words." : "No threads yet.");
}

/// Who may not write in Talk now, and until when; Unban each.
function drawBans(bans) {
  const list = $("talk-bans");
  list.replaceChildren();
  for (const one of bans) {
    const where = make("span", "note");
    where.setAttribute("role", "status");
    list.append(make("li", "talk-queue-item", one.handle ? link(`/u/${encodeURIComponent(one.handle)}`, `@${one.handle}`) : one.account,
      ` · since ${ago(one.at)} · ${one.until ? `until ${new Date(one.until).toLocaleString()}` : "for good"}`,
      one.reason ? ` · ${one.reason}` : "", " ",
      rowAct("Unban", () => act({ act: "unban", account: one.account }, where, `Unbanned: ${one.handle ? `@${one.handle}` : "the account"}.`)), where));
  }
  say("talk-bans-note", bans.length ? "" : "Nobody is banned from Talk.");
  const n = $("tab-talk-bans");
  if (n) n.textContent = bans.length ? String(bans.length) : "";
}

/// Read Talk's reports, threads and bans, and draw them.
export async function loadTalk() {
  try {
    const said = await adminJson(`op=talk${searched ? `&q=${encodeURIComponent(searched)}` : ""}`);
    if (!said.ready) {
      say("talk-reports-note", "Talk is not open on this deployment yet: supabase/talk.sql is not applied.");
      return;
    }
    drawReports(said.reports || []);
    drawThreads(said.threads || []);
    drawBans(said.bans || []);
  } catch (problem) {
    say("talk-reports-note", problem.message, true);
  }
}

let typing = 0;
$("talk-q")?.addEventListener("input", (event) => {
  clearTimeout(typing);
  typing = setTimeout(() => {
    searched = event.target.value.trim();
    loadTalk();
  }, 300);
});
