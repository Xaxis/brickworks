"""Talk's second round (talk2, 2026-11-27; docs/SOCIAL.md section 10), held to what it promises.

supabase/talk2.sql goes into the live project beside talk.sql, so it may only add: two
tables of its own nobody but its functions reads, three columns on a thread, and functions
only the server's key runs, none of talk.sql's replaced. tools/talk2_try.sql proves who may
do what in a rolled-back dry run, and tools/web/talk2_flow.mjs drives the pages over the
stand-in's crowd; here, that a page's address says one page, that what somebody typed or
searched never becomes markup, and that a search engine is told what a question's answer is.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/talk2.sql").read_text()
TALK = (ROOT / "supabase/talk.sql").read_text()
FUNCTIONS = re.findall(r"create or replace function public\.([a-z0-9_]+)\((.*?)\)\s*\nreturns(.*?)\nas \$\$", SQL, re.S)


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def node(script: str) -> object:
    said = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                          capture_output=True, text=True, timeout=60)
    return json.loads(said.stdout)


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop table", "drop function", "drop column", "drop index", "truncate", "rename ", "alter column"):
        assert word not in plain, f"talk2.sql says {word}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["talk_views", "talk_visits"]
    altered = re.findall(r"alter table public\.([a-z_]+)\s+(\w+)", plain)
    assert altered == [("talk_threads", "add"), ("talk_threads", "add"), ("talk_views", "enable"), ("talk_visits", "enable")], altered
    added = re.findall(r"add (column if not exists|constraint) ([a-z_]+)", plain)
    assert [name for _, name in added] == ["views", "answer", "answered_at", "talk_threads_views_counted"]
    for verb, table in re.findall(r"\b(update|delete from|insert into) public\.([a-z_]+)", plain):
        assert table in {"talk_threads", "talk_views", "talk_visits", "talk_reads"}, f"talk2.sql's {verb} reaches {table}"
    # Each table of its own closed to every client, the server's key too:
    # only the functions read them.
    for table in ("talk_views", "talk_visits"):
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role;" in plain


def test_its_functions_are_new_and_only_the_server_runs_them() -> None:
    names = [name for name, _, _ in FUNCTIONS]
    assert names == ["talk2_mark", "talk2_item", "talk2_list", "talk2_page", "talk_visit", "talk_read_to", "talk_view", "talk_answer"]
    for name in names:
        assert f"function public.{name}(" not in TALK, f"talk2.sql replaces talk.sql's {name}"
    for name, _, head in FUNCTIONS:
        assert "security definer" in head and "set search_path = public" in head, f"{name} runs without its own search path"
        revoked = re.findall(rf"revoke all on function public\.{name}\(([^)]*)\) from public, anon, authenticated;", SQL)
        granted = re.findall(rf"grant execute on function public\.{name}\(([^)]*)\) to ([a-z_, ]+);", SQL)
        assert len(revoked) == 1 and granted == [(revoked[0], "service_role")], f"{name}: {revoked} {granted}"


def test_a_view_is_a_person_once_a_day_and_never_who_they_are() -> None:
    # The viewer kept is a key (a hash of who, api/_talk.js visitorKey),
    # never an address or an account; and a day's are let go the day after.
    view = SQL[SQL.index("create or replace function public.talk_view("):]
    view = view[:view.index("\n$$;")]
    assert "viewer  text not null check (viewer ~ '^[0-9a-f]{32}$')" in SQL
    assert "p_viewer !~ '^[0-9a-f]{32}$'" in view
    # Counted only when the day's row is new: a reload counts nothing.
    made = view.index("on conflict do nothing;")
    assert view.index("get diagnostics made = row_count;") > made
    assert re.search(r"if made > 0 then\s+update public\.talk_threads set views = views \+ 1", view)
    assert "delete from public.talk_views v where v.thread = p_thread and v.day <" in view


def test_quotes_are_blocks_and_never_markup() -> None:
    said = node("""
import { blocksOf, bodyHtml } from "./api/_talk.js";
const hosts = new Set(["brickworks.diy"]);
console.log(JSON.stringify({
  blocks: blocksOf("> Ann said this\\n> and this\\n\\nI agree, 2 > 1."),
  one: blocksOf("just words"),
  html: bodyHtml("> <script>alert(1)</script>\\n\\nAnd <b>this</b>", [], hosts),
  inner: bodyHtml("a > b is not a quote", [], hosts),
}));
""")
    assert said["blocks"] == [{"quote": True, "text": "Ann said this\nand this"}, {"quote": False, "text": "I agree, 2 > 1."}]
    assert said["one"] == [{"quote": False, "text": "just words"}]
    assert said["html"] == '<blockquote class="talk-quote">&lt;script&gt;alert(1)&lt;/script&gt;</blockquote>And &lt;b&gt;this&lt;/b&gt;'
    assert "blockquote" not in said["inner"] and "&gt;" in said["inner"]


def test_an_address_is_one_page_and_says_only_what_differs() -> None:
    said = node("""
import { listAsked, listPath, threadPagePath, postPath } from "./api/_talk.js";
const asked = [
  {}, { sort: "top", in: "month", page: "3" }, { sort: "top", in: "decade" }, { sort: "unanswered", in: "week" },
  { sort: "nonsense", page: "-2" }, { page: "1e9" }, { q: "  red \\u00a0 hin\\u200bge\\ufeff  " }, { sort: "unread", page: "2.5" },
];
console.log(JSON.stringify({
  asked: asked.map(listAsked),
  paths: asked.map((one) => listPath({ ...listAsked(one), board: "help" })),
  long: listAsked({ q: "x".repeat(500) }).q.length,
  tests: listPath({ board: null, sort: "new", page: 2, tests: true }),
  thread: [threadPagePath({ id: 501, title: "My first Technic crane" }, 1), threadPagePath({ id: 501, title: "My first Technic crane" }, 4, true)],
  post: postPath({ id: 501, title: "My first Technic crane" }, 95),
}));
""")
    assert said["asked"][0] == {"board": None, "q": "", "sort": "latest", "period": None, "page": 1}
    assert said["asked"][1] == {"board": None, "q": "", "sort": "top", "period": "month", "page": 3}
    assert said["asked"][2]["period"] is None, "a period no list knows is all time"
    assert said["asked"][3]["period"] is None, "only Top has a period"
    assert said["asked"][4]["sort"] == "latest" and said["asked"][4]["page"] == 1
    assert said["asked"][5]["page"] <= 100000
    assert said["asked"][6]["q"] == "red hinge"
    assert said["asked"][7]["sort"] == "unread" and said["asked"][7]["page"] == 1, "a page is a whole number"
    assert said["long"] == 200
    assert said["paths"] == ["/talk/b/help", "/talk/b/help?sort=top&in=month&page=3", "/talk/b/help?sort=top",
                             "/talk/b/help?sort=unanswered", "/talk/b/help", f"/talk/b/help?page={said['asked'][5]['page']}",
                             "/talk/b/help?q=red+hinge", "/talk/b/help?sort=unread"]
    assert said["tests"] == "/talk?sort=new&page=2&tests=1"
    assert said["thread"] == ["/talk/t/501/my-first-technic-crane", "/talk/t/501/my-first-technic-crane?page=4&tests=1"]
    assert said["post"] == "/talk/t/501/my-first-technic-crane?post=95#post-95"


def test_a_search_marks_its_words_and_nothing_else() -> None:
    said = node("""
import { searchWords, markedHtml, excerptHtml } from "./api/_talk.js";
const words = searchWords("Hinge <b> HINGE plate!");
const long = "Lots of words before it. ".repeat(20) + "Then a hinge brick turns the roof. " + "And more after. ".repeat(20);
console.log(JSON.stringify({
  words,
  marked: markedHtml("Hinges & <b>plates</b> hinge", words),
  none: markedHtml("<i>x</i>", []),
  lt: markedHtml("a <b> c", searchWords("lt gt")),
  excerpt: excerptHtml(long, searchWords("hinge"), 120),
  start: excerptHtml(long, searchWords("nowhere"), 60),
}));
""")
    assert said["words"] == ["hinge", "b", "plate"]
    assert said["marked"] == "<mark>Hinges</mark> &amp; &lt;<mark>b</mark>&gt;<mark>plates</mark>&lt;/<mark>b</mark>&gt; <mark>hinge</mark>"
    assert said["none"] == "&lt;i&gt;x&lt;/i&gt;"
    assert said["lt"] == "a &lt;b&gt; c", "a word is found in what was written, never in its escaping"
    assert said["excerpt"].startswith("…") and said["excerpt"].endswith("…") and "<mark>hinge</mark>" in said["excerpt"]
    assert len(re.sub(r"</?mark>", "", said["excerpt"])) <= 122
    assert said["start"].startswith("Lots of words") and said["start"].endswith("…")


def test_a_question_with_its_answer_is_a_qa_page() -> None:
    said = node("""
import { threadSchema } from "./api/_talk.js";
const thread = { id: 7, title: "How do I hinge a roof?", board: "help", at: "2026-11-27T10:00:00Z" };
const first = { id: 70, n: 1, first: true, body: "It will not turn </script><script>alert(1)</script>", by: "Ann", handle: "ann", at: thread.at };
const answer = { id: 72, n: 3, body: "A hinge brick.", by: "Bea", handle: "bea", at: "2026-11-27T11:00:00Z" };
const other = { id: 71, n: 2, body: "Try a clip.", by: "Cy", at: "2026-11-27T10:30:00Z" };
const page = { thread, first, posts: [first, other, answer], total: 3 };
console.log(JSON.stringify({
  qa: threadSchema({ ...page, answer }, "https://example.test", "https://example.test/talk/t/7/how-do-i-hinge-a-roof"),
  open: threadSchema(page, "https://example.test", "https://example.test/talk/t/7/how-do-i-hinge-a-roof"),
  show: threadSchema({ ...page, thread: { ...thread, board: "show" }, answer }, "https://example.test", "https://example.test/talk/t/7/x"),
}));
""")
    assert "</script" not in said["qa"] and "</script" not in said["open"]
    qa = json.loads(said["qa"])
    assert qa["@type"] == "QAPage"
    question = qa["mainEntity"]
    assert question["@type"] == "Question" and question["name"] == "How do I hinge a roof?" and question["answerCount"] == 2
    assert question["acceptedAnswer"]["text"] == "A hinge brick." and question["acceptedAnswer"]["position"] == 3
    assert question["acceptedAnswer"]["url"] == "https://example.test/talk/t/7/how-do-i-hinge-a-roof?post=72#post-72"
    assert [one["text"] for one in question["suggestedAnswer"]] == ["Try a clip."]
    assert json.loads(said["open"])["@type"] == "DiscussionForumPosting", "a question nobody answered is a discussion"
    assert json.loads(said["show"])["@type"] == "DiscussionForumPosting", "only Help has answers"
