"""Talk, the builders' forum (docs/SOCIAL.md section 10), held to what it promises.

supabase/talk.sql goes into the live project, so it may only add: its own talk_* tables,
none a client may read or write, and functions only the server's key runs (the push
triggers no one). tools/talk_try.sql proves who may do what in a rolled-back dry run, and
tools/web/talk_flow.mjs drives the pages; here, that the rules are the ones written and
that what somebody types never becomes markup, a link to another site dressed as ours,
a broken feed or a script on the page.
"""

from __future__ import annotations

import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/talk.sql").read_text()
TABLES = ["talk_threads", "talk_posts", "talk_follows", "talk_reads", "talk_mentions", "talk_reports", "talk_bans"]
FUNCTIONS = re.findall(r"create or replace function public\.([a-z_]+)\(([^)]*)\)(.*?)\n\$\$;", SQL, re.S)


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def node(script: str) -> object:
    said = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                          capture_output=True, text=True, timeout=60)
    return json.loads(said.stdout)


def replaced(text: str, name: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def test_the_file_only_adds() -> None:
    # push_collect, replaced whole below, writes push.sql's own tables.
    plain = code(SQL.replace(replaced(SQL, "push_collect"), "")).lower()
    for word in ("drop table", "drop function", "drop column", "truncate", "rename ", "alter column"):
        assert word not in plain, f"talk.sql says {word}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == TABLES
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [(t, "enable row level security") for t in TABLES]
    for verb, table in re.findall(r"\b(update|delete from|insert into) public\.([a-z_]+)", plain):
        assert table in TABLES, f"talk.sql's {verb} reaches {table}"
    assert set(re.findall(r"drop trigger if exists ([a-z_]+) on public\.([a-z_]+)", plain)) == {
        ("talk_push_on_post", "talk_posts"), ("talk_push_on_mention", "talk_mentions")}
    assert [name for name, _, _ in FUNCTIONS if not name.startswith("talk_")] == ["notification_rows", "push_collect"]


def test_push_collect_pushes_talk_and_all_it_did() -> None:
    # push_2.sql's body with Talk's kinds, a post's key and a thread's own
    # "last" (one push a thread), and nothing else; made only where push_2.sql
    # made one, so applying that file later is never refused for nothing.
    before = replaced((ROOT / "supabase/push_2.sql").read_text(), "push_collect")
    after = before.replace("r.item->>'challenge', '')", "r.item->>'challenge', r.item->>'post', '')").replace(
        "'photo', 'remix', 'result')", "'photo', 'remix', 'result', 'talk_reply', 'talk_mention')").replace(
        "'last:' || coalesce(nullif(w.model, ''), w.kind) || '@'",
        "'last:' || coalesce(nullif(w.model, ''),\n                                    case when w.kind in ('talk_reply', 'talk_mention') "
        "then 'talk-' || (w.item->>'thread') end,\n                                    w.kind) || '@'")
    assert after != before and replaced(SQL, "push_collect") == after
    guard = SQL[SQL.index("do $do$"):SQL.index("$do$;")]
    assert "if to_regprocedure('public.push_collect(uuid, integer)') is null then" in guard and "return;" in guard
    later = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
             if line.strip() and not line.startswith("#")]
    row = ["push_2.sql", "push_collect", "talk.sql", "'talk-' || (w.item->>'thread')"]
    assert row in later and row[3] not in before and row[3] in after
    said = node("""
import { KINDS, pushSaid } from "./api/_push.js";
const row = { kind: "talk_reply", at: "2026-11-22T10:00:00Z", thread: 12, post: 40, title: "<b>Sports car</b>", yours: true,
  said: "Nice", by: { name: "Bea", handle: "bea" } };
console.log(JSON.stringify({ kinds: KINDS, en: pushSaid(row, "en", "https://brickworks.diy", 2),
  de: pushSaid({ ...row, kind: "talk_mention" }, "de") }));
""")
    assert {"talk_reply", "talk_mention"} <= set(said["kinds"])
    assert said["en"] == {"title": "Talk: <b>Sports car</b>", "body": "Bea replied in your thread\nNice\n2 more on its page",
                          "url": "https://brickworks.diy/talk/t/12#post-40", "tag": "talk-12"}
    assert said["de"]["tag"] == "talk-12" and said["de"]["url"] == "https://brickworks.diy/talk/t/12#post-40"


def test_notification_rows_keeps_every_row_it_gave() -> None:
    # Replaced as challenge_notices.sql and announce.sql did: announce.sql's
    # body whole, then Talk's rows; supabase/later.tsv refuses announce.sql
    # applied again alone once the live one says talk_notice_rows(.
    def body(text: str) -> str:
        start = text.index("create or replace function public.notification_rows(")
        return text[start:text.index("\n$$;", start)]
    before = body((ROOT / "supabase/announce.sql").read_text())
    assert body(SQL) == before + ("\n    union all\n    -- Talk: a new post in a thread the viewer follows, and one naming them."
                                  "\n    select * from public.talk_notice_rows(viewer, since, until)")
    later = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
             if line.strip() and not line.startswith("#")]
    assert ["announce.sql", "notification_rows", "talk.sql", "talk_notice_rows("] in later


def test_no_client_reaches_a_table() -> None:
    plain = code(SQL).lower()
    for table in TABLES:
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role;" in plain
    assert not re.search(r"grant [a-z, ]+ on (table )?public\.talk_", plain), "a Talk table is granted to somebody"
    assert "create policy" not in plain, "a policy would open a table its revoke closed"


def test_every_function_is_the_servers_alone() -> None:
    assert len(FUNCTIONS) >= 30
    internal = {"talk_push", "talk_push_on_post", "talk_push_on_mention", "push_collect"}
    for name, args, body in FUNCTIONS:
        head = body.split("$$")[0]
        types = ", ".join(re.sub(r"\s+default\s.*$", "", part.strip()).split()[1] for part in args.split(",") if part.strip())
        assert re.search(rf"revoke all on function public\.{name}\({re.escape(types)}\) from public, anon, authenticated", SQL), name
        granted = re.search(rf"grant execute on function public\.{name}\([^)]*\) to ([a-z_, ]+);", SQL)
        if name in internal:
            assert granted is None and re.search(rf"revoke all on function public\.{name}\([^)]*\) from [a-z, ]*service_role;", SQL), name
        else:
            assert granted and granted.group(1) == "service_role", f"{name} is granted to {granted and granted.group(1)}"
        if "security definer" in head:
            assert "set search_path = public" in head, f"{name} runs as its owner without its own search path"
        else:
            assert "immutable" in head, f"{name} runs as its caller and is not a pure function"


def test_a_link_to_another_site_is_never_one_of_ours() -> None:
    said = node("""
import { linkOf, bodyHtml, embedsIn } from "./api/_talk.js";
const hosts = new Set(["brickworks.diy"]);
const tried = ["https://brickworks.diy//elsewhere.example/x", "https://brickworks.diy/\\\\elsewhere.example/x",
  "https://elsewhere.example/m/AbCdEfGhIj", "javascript:alert(1)", "https://brickworks.diy.elsewhere.example/m/AbCdEfGhIj",
  "https://user@elsewhere.example/m/AbCdEfGhIj", "ftp://brickworks.diy/m/AbCdEfGhIj"];
console.log(JSON.stringify({
  links: tried.map((one) => linkOf(one, hosts)),
  html: bodyHtml(tried.join(" "), [], hosts),
  model: embedsIn("Look at https://brickworks.diy/m/AbCdEfGhIj?step=3.", hosts)[0],
  app: linkOf("https://brickworks.diy/de/app?view=AbCdEfGhIj&step=2", hosts),
  set: linkOf("https://brickworks.diy/library/set/6080-1", hosts),
  part: linkOf("https://rebrickable.com/parts/3001/brick-2-x-4/", hosts),
  embeds: embedsIn("https://brickworks.diy/m/AbCdEfGhIj https://brickworks.diy/m/AbCdEfGhIj (https://brickworks.diy/challenge?id=7).", hosts),
}));
""")
    assert said["links"] == [None] * 7
    assert "<a " not in said["html"], said["html"]
    assert said["model"] == {"href": "/m/AbCdEfGhIj?step=3", "kind": "step", "model": "AbCdEfGhIj", "step": 3}
    assert said["app"] == {"href": "/de/app?view=AbCdEfGhIj&step=2", "kind": "step", "model": "AbCdEfGhIj", "step": 2}
    assert said["set"] == {"href": "/library/set/6080-1", "kind": "set", "set": "6080-1"}
    assert said["part"] == {"kind": "part", "part": "3001"}
    assert [one["kind"] for one in said["embeds"]] == ["model", "challenge"], "a model pasted twice is one card; the bracket is the sentence's"


def test_what_is_typed_is_never_markup() -> None:
    said = node("""
import { bodyHtml, cleanPost, cleanTitle, threadRowHtml, postHtml } from "./api/_talk.js";
const bad = '<img src=x onerror=alert(1)> "quoted" \\u202eevil </script>';
const thread = { id: 5, title: bad, said: bad, board: "help", by: { name: bad, handle: "x" }, at: "2026-10-01T00:00:00Z",
  last_at: "2026-10-01T00:00:00Z", last_by: { name: bad, handle: "y" }, replies: 1 };
const post = { id: 9, body: bad + " @bea", by: bad, handle: "x", at: "2026-10-01T00:00:00Z", first: false,
  mentions: [{ handle: "bea", name: '"><b>Bea' }] };
console.log(JSON.stringify({ body: bodyHtml(post.body, post.mentions), row: threadRowHtml(thread), post: postHtml(post),
  clean: cleanPost("a\\u202eb\\u0000c\\n\\n\\n\\nd"), title: cleanTitle("two\\nlines"), empty: cleanPost("   \\n "),
  spaces: cleanPost("a\\u2003\\u3000b\\u2060c\\ufeffd\\u00a0 e\\u2028f"), invisible: cleanPost("\\u200b\\u2060\\ufeff\\u3000"),
  title_spaces: cleanTitle("\\u2003Two\\u3000words\\u2060"),
  long: cleanPost("x".repeat(4001)), longest: cleanPost("😀".repeat(4000)) }));
""")
    for where in ("body", "row", "post"):
        assert "<img" not in said[where] and "</script" not in said[where] and "<b>" not in said[where], where
    assert "&lt;img src=x onerror=alert(1)&gt;" in said["body"]
    assert 'title="&quot;&gt;&lt;b&gt;Bea"' in said["body"] and 'class="mention" href="/u/bea"' in said["body"]
    assert said["clean"] == {"text": "a b c\n\nd"}
    assert said["title"] == {"text": "two lines"}
    assert said["spaces"] == {"text": "a b c d e\nf"}, "every kind of space one space, a line separator a line"
    assert "trouble" in said["invisible"], "only invisible characters is nothing said"
    assert said["title_spaces"] == {"text": "Two words"}
    assert "trouble" in said["empty"] and "trouble" in said["long"]
    assert said["longest"] == {"text": "😀" * 4000}, "4,000 characters as the database counts them, not UTF-16 units"


def test_a_feed_is_xml_and_a_page_keeps_its_script() -> None:
    said = node("""
import { rssOf, threadSchema } from "./api/_talk.js";
const bad = "</script><script>alert(1)</script> & ]]> \\u0001 \\ud83d";
const thread = { id: 5, title: bad, said: bad, board: "help", by: { name: bad, handle: "x" }, at: "2026-10-01T00:00:00Z",
  last_at: "2026-10-01T00:00:00Z", replies: 1 };
const page = { thread, posts: [{ id: 1, body: bad, by: bad, handle: "x", at: "2026-10-01T00:00:00Z", first: true },
  { id: 2, body: bad, by: bad, handle: "y", at: "2026-10-02T00:00:00Z" }] };
console.log(JSON.stringify({ rss: rssOf([thread], { origin: "https://brickworks.diy", board: "help", lang: "de" }),
  schema: threadSchema(page, "https://brickworks.diy", "https://brickworks.diy/talk/t/5") }));
""")
    # A lone half of a pair is no UTF-8: Node sends U+FFFD for it, this a "?".
    feed = ET.fromstring(said["rss"].encode("utf-8", errors="replace"))
    item = feed.find("channel/item")
    assert item is not None and item.findtext("title").startswith("</script>")
    assert item.findtext("link") == "https://brickworks.diy/de/talk/t/5/script-script-alert-1-script", "German's feed, German's pages"
    assert feed.find("channel/{http://www.w3.org/2005/Atom}link").get("href") == "https://brickworks.diy/de/talk/b/help.rss"
    assert "</script" not in said["schema"].lower()
    schema = json.loads(said["schema"])
    assert schema["@type"] == "DiscussionForumPosting" and schema["headline"].startswith("</script>")
    assert schema["comment"][0]["@type"] == "Comment"


def test_the_house_writes_as_itself() -> None:
    # The first threads are the house's own (never as made-up people), on
    # production only, and a person can tell (by_house).
    talk = (ROOT / "api/_talk.js").read_text()
    seeds = node('import { HOUSE_THREADS } from "./api/_talk.js"; console.log(JSON.stringify(HOUSE_THREADS));')
    assert {one["board"] for one in seeds} <= {"show", "help", "ideas", "challenges", "news"} and len(seeds) >= 4
    assert all(set(one) == {"seed", "board", "title", "said"} for one in seeds), "a seed names who wrote it"
    assert 'if (!tests && process.env.VERCEL_ENV !== "production") return;' in talk
    body = re.search(r"create or replace function public\.talk_seed\(.*?\n\$\$;", SQL, re.S).group(0)
    assert "house uuid := public.talk_house();" in body and "if house is null" in body
    assert "values (p_board, p_title, house, p_seed, coalesce(p_test, false))" in body
    assert "values (t, house, p_said, true)" in body, "a seed's first post is the house's"
    assert "x.seed = p_seed and x.test = coalesce(p_test, false)" in body, "a seed is written once a pool"
