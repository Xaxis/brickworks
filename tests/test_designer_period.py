"""A designer's numbers against last month, held to what they promise.

supabase/designer_period.sql goes into the live project, so it may only add:
one function, replacing nothing another file defines. What it answers is
proven by tools/designer_period_try.sql in a rolled-back dry run (3,300
numbers of 50 made-up models against counts written plainly from the rows)
and on a deployment by tools/web/designer_period_flow.mjs; these read the
files and hold the promises around it:

- only the server may run it, and the API asks it only for the account its
  sign-in proves, never one the request names, and no cache keeps the answer;
- the days are one rule (UTC; the last 30 are today and the 29 before; the
  30 before those; 8 weeks of 7, the newest ending today) in the SQL, the
  flow's plain count and the page's words;
- the six kinds are the same six in the SQL, the API and the page, and each
  is said in words (and in de, fr and es: tools/site_lang.py --check);
- comments are counted by designer_said's rule, the one replies.sql keeps;
- the flow never runs against brickworks.diy, and is a preview check.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/designer_period.sql").read_text()
TRY = (ROOT / "tools/designer_period_try.sql").read_text()
API = (ROOT / "api/_designers.js").read_text()
PAGE = (ROOT / "web/designs.js").read_text()
FLOW = (ROOT / "tools/web/designer_period_flow.mjs").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()
KINDS = ["views", "builds", "likes", "saves", "comments", "remixes"]


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def js_function(text: str, name: str) -> str:
    start = re.search(rf"(export )?(async )?function {name}\(", text)
    assert start, f"no function {name}"
    rest = text[start.start():]
    end = re.search(r"\n}\n", rest)
    return rest[: end.end()] if end else rest


def test_the_file_only_adds_one_function() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "delete from", "rename ", "alter ", "insert into", "update ", "create table",
                 "create index", "create trigger", "create or replace trigger"):
        assert word not in plain, f"designer_period.sql says {word.strip()}"
    assert re.findall(r"create or replace function public\.([a-z_]+)\(", plain) == ["designer_period"]
    others = [path.name for path in (ROOT / "supabase").glob("*.sql")
              if path.name != "designer_period.sql" and "function public.designer_period(" in path.read_text()]
    assert not others, f"another file defines designer_period: {others}"


def test_only_the_server_runs_it() -> None:
    plain = code(SQL)
    head = re.search(r"create or replace function public\.designer_period\(designer uuid\)(.*?)as \$\$", plain, flags=re.S)
    assert head and "security definer" in head[1] and "set search_path = public" in head[1] and "stable" in head[1]
    assert "revoke all on function public.designer_period(uuid) from public, anon, authenticated;" in plain
    assert "grant execute on function public.designer_period(uuid) to service_role;" in plain
    assert not re.search(r"grant execute on function public\.designer_period\([^)]*\) to (anon|authenticated|public)", plain)
    # Its models are designer_mine's: published and not taken out, theirs alone.
    assert "where m.owner = designer_period.designer and m.published and not m.barred" in plain


def test_the_api_asks_only_for_the_signed_in_account() -> None:
    designs = js_function(API, "designs")
    read = js_function(API, "periodRead")
    assert 'response.setHeader("Cache-Control", MINE_CACHE);' in designs.split("\n")[1]
    assert "const account = (await verify(bearer(request), request)).sub;" in designs
    assert 'periodRead(account)' in designs
    assert 'db("rpc/designer_period", { method: "POST", body: { designer: account } })' in read
    # Nothing from the request goes into the function's body.
    assert "request" not in read
    # Before the file is applied: no period, and the page as before.
    assert "if (missing(trouble)) return null;" in read
    assert "period: counted ? counted.period : null" in designs


def test_one_rule_for_the_days() -> None:
    plain = code(SQL)
    assert "(now() at time zone 'UTC')::date as today" in plain
    assert "t.today - 29 as now_from, t.today - 59 as before_from" in plain
    assert "h.day between s.now_from and s.today" in plain
    assert "h.day between s.before_from and s.now_from - 1" in plain
    weeks = re.findall(r"h\.day between s\.today - (\d+) and s\.today(?: - (\d+))?\)", plain)
    # Eight weeks of seven days, the oldest first, the newest ending today.
    assert [(int(a), int(b or 0)) for a, b in weeks] == [(55 - 7 * w, 49 - 7 * w) for w in range(8)]
    # Each timestamp read as its UTC day.
    for at in ("b.at", "l.at", "k.at", "c.at", "r.created_at"):
        assert f"({at} at time zone 'UTC')::date" in plain, at
    # The flow's plain count by the same rule.
    assert "now: [plusDays(today, -29), today], before: [plusDays(today, -59), plusDays(today, -30)]" in FLOW
    assert "[plusDays(today, -55 + 7 * w), plusDays(today, -49 + 7 * w)]" in FLOW
    # And the page says so.
    assert "Days begin at midnight UTC." in PAGE


def test_six_kinds_everywhere_each_in_words() -> None:
    assert re.findall(r"\('([a-z]+)'\)", code(SQL).split("kinds (kind) as")[1].split(")\n")[0] + ")") == KINDS
    assert f'export const PERIOD_KINDS = {str(KINDS).replace(chr(39), chr(34))};' in API
    assert f'const KINDS = {str(KINDS).replace(chr(39), chr(34))};' in PAGE
    assert "export const WEEKS = 8;" in API and "const WEEKS = 8;" in PAGE
    for kind in KINDS:
        assert re.search(rf"  {kind}: \(\) => \[say\(\"[A-Z][^\"]+\"\), say\(\"", PAGE), f"{kind} is not named"
        assert re.search(rf"  {kind}: \(\) => say\(\"[A-Z]", PAGE), f"what {kind} counts is not said"


def test_comments_by_designer_said_rule() -> None:
    plain = code(SQL)
    said = re.search(r"create or replace function public\.designer_said\(.*?\$\$(.*?)\$\$",
                     (ROOT / "supabase/replies.sql").read_text(), flags=re.S)[1]
    for rule in ("c.removed_at is null and c.hidden_at is null", "c.author <> m.owner",
                 "c.at >= coalesce(l.at, '-infinity'::timestamptz)", "c.author in (select s.author from shown s)",
                 "public.comment_parent_shown(c.parent)"):
        assert rule in said, f"designer_said no longer says {rule}"
        assert rule in plain, f"designer_period does not count by {rule}"
    # And the dry run holds them against designer_said itself.
    assert "public.designer_said(array[direct.model], a)" in TRY


def test_the_flow_is_a_preview_check_and_never_on_the_live_site() -> None:
    assert re.search(r"\[designer_period\]=\"tools/web/designer_period_flow\.mjs --url=\$P --out=", CHECKS)
    assert "brickworks\\.diy" in FLOW and "never on brickworks.diy" in FLOW
    # Its accounts are throwaways at Resend's test addresses, deleted after.
    assert "@resend.dev" in FLOW and "deleteAccount(email(who))" in FLOW
