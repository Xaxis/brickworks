// Talk's second round (supabase/talk2.sql, api/_talk.js, web/talk.js), on
// this machine's stand-in with its crowd (560 threads, Help's 500, a thread
// of 200 posts), in real browsers and through the API, with two throwaway
// accounts at Resend test addresses, deleted at the end:
//
//   node --env-file=$SCRATCH/flow.env tools/web/relay_server.mjs PORT --hold=talk --talk-crowd
//   node --env-file=$SCRATCH/flow.env tools/web/talk2_flow.mjs --url=http://127.0.0.1:PORT --out=DIR
//
//   1. A visitor from a search engine: Help's 500 threads a page of 30, its
//      count, numbered links a crawler follows (rel next and prev, each page
//      its own canonical address), the last page's 20, Show more putting
//      page 2 under page 1 and the address saying so; the 200-post thread
//      20 posts a page, numbered, a post's own address opening its page.
//   2. A search shows the words it found, and how many threads say them;
//      Unanswered lists only threads with no reply, Top the most replied
//      first, and neither is indexed.
//   3. A member asking for help: Ann asks in Help, Bea answers twice. Ann's
//      list marks the thread unread with "2 new", the Unread tab counts it;
//      its title opens the first post she has not read, a line over it.
//      She quotes Bea (the box begins "> "), copies a post's link (its own
//      address), and marks Bea's answer: shown under the question, the
//      thread marked Answered on the page and in the list, its JSON-LD a
//      QAPage. Bea may not mark it.
//   4. Views: a person's opening counted once a day, a crawler's never.
//   5. On a phone (390 x 844): the list and the long thread, nothing
//      sideways, the pages there.
//
// Prints "talk2: all ok".
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("talk2_flow: --url=<this machine's stand-in>");
  process.exit(2);
}
const site = String(args.url).replace(/\/+$/, "");
const host = new URL(site).host;
// Its crowd is the stand-in's alone: never a deployment's Talk.
if (!/^(?:127\.0\.0\.1|localhost)(?::\d+)?$/.test(host) || await fetch(`${site}/__held/talk`).then((reply) => reply.status, () => 0) !== 200) {
  console.error("talk2_flow: on this machine's stand-in only (relay_server.mjs PORT --hold=talk --talk-crowd)");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/talk2"));
mkdirSync(out, { recursive: true });
const rand = randomBytes(4).toString("hex");
const emails = { ann: `delivered+bw-talk2-ann-${rand}@resend.dev`, bea: `delivered+bw-talk2-bea-${rand}@resend.dev` };
const names = { ann: "Ann Asks", bea: "Bea Knows" };

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

async function api(pathname, { method = "GET", token, body, agent } = {}) {
  const sent = {};
  if (token) sent.authorization = `Bearer ${token}`;
  if (agent) sent["user-agent"] = agent;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let parsed = {};
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = {};
  }
  return { status: reply.status, body: parsed, text };
}

/// A page's head and list, as a crawler reads it: its canonical, rel next
/// and prev, robots, the rows' or posts' numbers.
async function crawled(pathname) {
  const started = Date.now();
  const { status, text } = await api(pathname);
  const ms = Date.now() - started;
  const link = (rel) => (text.match(new RegExp(`<link rel="${rel}" href="([^"]+)"`)) || [])[1] || "";
  return { status, ms, canonical: link("canonical"), next: link("next"), prev: link("prev"),
    robots: (text.match(/<meta name="robots" content="([^"]+)"/) || [])[1] || "",
    rows: (text.match(/<li class="list-row talk-row talk-line/g) || []).length,
    posts: [...text.matchAll(/class="talk-n"[^>]*>#(\d+)</g)].map((one) => Number(one[1])),
    count: (text.match(/<p class="pager-count">([^<]*)</) || [])[1] || "", text };
}

const browser = await launch({ signedOut: true });
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function open(pathname, { who = null, phone = false } = {}) {
  const context = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 900 },
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await context.grantPermissions(["clipboard-read", "clipboard-write"], { origin: site }).catch(() => {});
  if (who) {
    await context.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(who.kept)]);
  }
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${pathname}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${pathname}: ${m.text().slice(0, 220)}`);
  });
  await page.goto(`${site}${pathname}`, { waitUntil: "networkidle", timeout: 120000 });
  return page;
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

const people = {};
try {
  console.log("1. A visitor from a search engine: pages");
  const help = await crawled("/talk/b/help");
  check(`Help, page 1: ${help.rows} threads, "${help.count}", in ${help.ms} ms`, help.rows === 30 && /500/.test(help.count) && help.ms < 1000);
  check(`its head: canonical ${help.canonical}, next ${help.next}, no prev, indexed`, /\/talk\/b\/help$/.test(help.canonical)
    && /\/talk\/b\/help\?page=2$/.test(help.next) && !help.prev && !/noindex/.test(help.robots));
  check("its numbered links reach the last page, 17", help.text.includes('href="/talk/b/help?page=17"'));
  const last = await crawled("/talk/b/help?page=17");
  check(`page 17: ${last.rows} threads, prev ${last.prev}, no next, its own canonical ${last.canonical}, in ${last.ms} ms`, last.rows === 20
    && /\?page=16$/.test(last.prev) && !last.next && /\/talk\/b\/help\?page=17$/.test(last.canonical) && last.ms < 1000);
  const ids = new Set();
  for (let n = 1; n <= 17; n += 1) {
    const one = await api(`/api/people?op=talk&board=help&page=${n}`);
    for (const thread of one.body.threads || []) ids.add(thread.id);
  }
  check(`the 17 pages hold all of Help, each thread once: ${ids.size}`, ids.size === 500);
  const board = await open("/talk/b/help");
  await shot(board, "1-help.png");
  await board.click("nav[data-pager='talk-list'] [data-pager-go=more]");
  const grown = await until(board, () => (document.querySelectorAll("#talk-list > li").length === 60 ? location.search : null), "page 2 under page 1", 30);
  check(`Show more: 60 threads, the address ${grown}`, grown === "?page=2");
  await board.context().close();

  const long = await crawled("/talk/t/501");
  check(`the long thread: posts ${long.posts[0]}–${long.posts[long.posts.length - 1]} of 200 on page 1, next ${long.next}, in ${long.ms} ms`,
    long.posts.length === 20 && long.posts[0] === 1 && long.posts[19] === 20 && /\/talk\/t\/501[^"]*\?page=2$/.test(long.next) && long.ms < 1000);
  const tenth = await crawled("/talk/t/501?page=10");
  check(`page 10: posts ${tenth.posts[0]}–${tenth.posts[tenth.posts.length - 1]}, prev ${tenth.prev}, no next, in ${tenth.ms} ms`,
    tenth.posts[0] === 181 && tenth.posts[tenth.posts.length - 1] === 200 && /\?page=9$/.test(tenth.prev) && !tenth.next && tenth.ms < 1000);
  const page5 = await api("/api/people?op=talk_thread&id=501&page=5");
  const p95 = (page5.body.posts || []).find((one) => Number(one.n) === 95);
  const byPost = p95 ? await crawled(`/talk/t/501?post=${p95.id}`) : null;
  check(`a post's own address (#95, ?post=${p95?.id}) opens its page: posts ${byPost?.posts[0]}–${byPost?.posts[byPost.posts.length - 1]}, canonical ${byPost?.canonical}`,
    Boolean(byPost) && byPost.posts.includes(95) && byPost.posts[0] === 81 && /\?page=5$/.test(byPost.canonical));
  const reader = await open("/talk/t/501?page=3");
  const at = await reader.evaluate(() => ({ first: document.querySelector("#talk-posts .talk-n")?.textContent,
    where: document.querySelector(".talk-where-count")?.textContent.trim(), current: document.querySelector(".talk-where [aria-current]")?.textContent.trim() }));
  check(`page 3 in a browser: first post ${at.first}, "${at.where}", page ${at.current} marked`, at.first === "#41" && /41 to 60 of 200/.test(at.where || "") && at.current === "3");
  await shot(reader, "1-long-page3.png");
  await reader.context().close();

  console.log("2. Search, Unanswered and Top");
  const search = await crawled("/talk?q=hinge");
  const marks = (search.text.match(/<mark>[^<]*<\/mark>/g) || []).length;
  const said = (search.text.match(/<p class="talk-searched"[^>]*>([\s\S]*?)<\/p>/) || [])[1]?.replace(/<[^>]+>/g, "") || "";
  check(`search "hinge": ${search.rows} rows, ${marks} words marked, "${said.slice(0, 60)}", noindex, in ${search.ms} ms`,
    search.rows > 0 && marks >= search.rows && /threads? say/.test(said) && /noindex/.test(search.robots) && search.ms < 1000);
  const unanswered = await api("/api/people?op=talk&board=help&sort=unanswered");
  check(`Unanswered: ${unanswered.body.total} threads, none with a reply`, unanswered.body.total > 0
    && (unanswered.body.threads || []).every((one) => Number(one.replies) === 0));
  const top = await api("/api/people?op=talk&board=help&sort=top&in=year");
  const replies = (top.body.threads || []).map((one) => Number(one.replies));
  check(`Top of the year: most replied first (${replies.slice(0, 5).join(", ")}…)`, replies.length > 1 && replies.every((n, i) => !i || replies[i - 1] >= n));
  check("a sort is not indexed", /noindex/.test((await crawled("/talk/b/help?sort=top")).robots));

  console.log("3. A member asks for help");
  for (const who of ["ann", "bea"]) {
    people[who] = await mintSession(emails[who]);
    const profile = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
      body: { handle: `t2-${who}-${rand}`, name: names[who] } });
    check(`${names[who]}: ${profile.status}`, profile.status === 200);
  }
  // Ann looks at Talk first, so what comes after is new to her. A
  // throwaway's posts are the checks' pool's (?tests=1), as on a preview.
  await api("/api/people?op=talk&html=1&tests=1", { token: people.ann.access_token });
  const asked = await api("/api/people?op=talk_start", { method: "POST", token: people.ann.access_token,
    body: { board: "help", title: `How do I hang a door ${rand}?`, body: "My door on hinges falls off when I open it. What holds it?" } });
  const thread = Number(asked.body.thread?.id);
  check(`Ann asks in Help: ${asked.status} ${asked.body.path}`, asked.status === 201 && thread > 0);
  const answers = [];
  for (const words of ["A hinge brick and a plate on top holds it.", "Or a clip and a bar, if it must swing far."]) {
    const made = await api("/api/people?op=talk_reply", { method: "POST", token: people.bea.access_token, body: { thread, body: words } });
    answers.push(made.body.post);
    check(`Bea answers: ${made.status}`, made.status === 201);
  }
  const list = await open("/talk/b/help?tests=1", { who: people.ann });
  const row = await until(list, (id) => {
    const one = document.querySelector(`#talk-list .talk-row[data-thread="${id}"]`);
    const unread = document.querySelector("[data-unread]");
    return one && unread && !unread.hidden ? { unread: one.classList.contains("unread"), mark: one.querySelector(".pill.new")?.textContent.trim(),
      href: one.querySelector(".talk-row-title a")?.getAttribute("href"), tab: unread.textContent.replace(/\s+/g, " ").trim() } : null;
  }, "Ann's list drawn as she sees it", 30, thread);
  check(`her list: the thread unread (${row.unread}), "${row.mark}", Unread tab "${row.tab}"`, row.unread && row.mark === "2 new" && /Unread\s*\d+/.test(row.tab));
  check(`its title goes to the first post she has not read: ${row.href}`, row.href.includes(`?post=${answers[0].id}`) && row.href.endsWith(`#post-${answers[0].id}`));
  await shot(list, "3-ann-list.png");
  await list.click(`#talk-list .talk-row[data-thread="${thread}"] .talk-row-title a`);
  const opened = await until(list, (id) => {
    const post = document.getElementById(`post-${id}`);
    const line = document.querySelector("[data-new-since]");
    return post && post.classList.contains("first-new") && line && !line.hidden ? { said: post.dataset.newSaid, line: line.textContent.trim() } : null;
  }, "the first post not read, marked", 30, answers[0].id);
  check(`the thread opens at it: "${opened.said}", "${opened.line}"`, /Not read yet/.test(opened.said) && /2 posts you have not read/.test(opened.line));
  await list.click(`#post-${answers[0].id} [data-act=quote]`);
  const quoted = await list.inputValue("#talk-reply-words");
  check(`Quote puts Bea's words in the box: "${quoted.trim().slice(0, 50)}"`, quoted.startsWith("> A hinge brick and a plate on top holds it."));
  await list.click(`#post-${answers[0].id} [data-act=link]`);
  const copied = await list.evaluate(() => navigator.clipboard.readText()).catch(() => "");
  check(`Copy link: ${copied}`, new URL(copied || "http://x/").searchParams.get("post") === String(answers[0].id));
  await list.click(`#post-${answers[0].id} [data-act=mark-answer]`);
  const solved = await until(list, () => {
    const box = document.querySelector(".talk-solution");
    return box && document.querySelector(".talk-thread-meta .pill.answered") ? box.textContent.replace(/\s+/g, " ").trim() : null;
  }, "the answer under the question", 30);
  check(`marked: under the question "${solved.slice(0, 70)}", the thread Answered`, /A hinge brick and a plate/.test(solved) && /Bea Knows/.test(solved));
  await shot(list, "3-answered.png");
  await list.context().close();
  const page = await crawled(`/talk/t/${thread}?tests=1`);
  check("its JSON-LD is a QAPage with the accepted answer", /"@type":"QAPage"/.test(page.text) && /"acceptedAnswer"/.test(page.text));
  const inList = await api(`/api/people?op=talk&board=help&tests=1&q=${encodeURIComponent(rand)}`);
  check("the list marks it answered", (inList.body.threads || []).some((one) => Number(one.id) === thread && one.answered === true));
  const notHers = await api("/api/people?op=talk_answer", { method: "POST", token: people.bea.access_token, body: { thread, post: answers[1].id } });
  check(`Bea may not mark it: ${notHers.status}`, notHers.status === 403);
  const beaSees = await api(`/api/people?op=talk_thread&id=${thread}&html=1&tests=1`, { token: people.bea.access_token });
  check("nor is she offered Mark as the answer", beaSees.status === 200 && !/data-act="mark-answer"/.test(beaSees.body.html || ""));

  console.log("4. Views");
  const crawler = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)";
  const viewsOf = async () => Number((await api(`/api/people?op=talk_thread&id=${thread}&tests=1`)).body.thread?.views) || 0;
  const before = await viewsOf();
  const one = await api("/api/people?op=talk_view", { method: "POST", body: { thread } });
  const again = await api("/api/people?op=talk_view", { method: "POST", body: { thread } });
  const bot = await api("/api/people?op=talk_view", { method: "POST", body: { thread }, agent: crawler });
  const after = await viewsOf();
  check(`a person counted once (${one.body.counted}, then ${again.body.counted}), a crawler never (${bot.body.counted}): ${before} → ${after}`,
    one.body.counted === true && again.body.counted === false && bot.body.counted === false && after === before + 1);

  console.log("5. On a phone");
  for (const where of ["/talk/b/help?page=2", "/talk/t/501?page=4", `/talk/t/${thread}?tests=1`]) {
    const phone = await open(where, { who: people.ann, phone: true });
    await phone.waitForTimeout(1200);
    const pages = await phone.evaluate(() => document.querySelectorAll(".pager-pages a, .talk-where .pager-pages a").length);
    check(`${where} at 390 x 844: nothing sideways, ${pages} page links`, !(await sideways(phone)) && (where.includes(`/t/${thread}`) || pages > 0));
    await shot(phone, `5-phone-${where.replace(/[^a-z0-9]+/gi, "_")}.png`);
    await phone.context().close();
  }
} catch (trouble) {
  failed += 1;
  console.log(`  FAIL  ${String(trouble.stack || trouble).split("\n").slice(0, 3).join(" | ")}`);
} finally {
  await browser.close();
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "talk2: all ok");
process.exit(failed ? 1 : 0);
