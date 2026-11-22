"""A designer's numbers against last month, held to what they promise.

supabase/designer_period.sql went into the live project (insights2); its
review (bench/results/i2review-2026-11-22) found it set the last 30 days
beside "30 days before" that held only a few counted days, let a test row move
views' start for everybody, and ended the last 30 days with today so far.
supabase/designer_period_2.sql replaces that one function (i2fix): the days
each number was counted, whole UTC days ending yesterday, views' start from
real models only. Both go into the live project, so they may only add or
replace that function. What the new one answers is proven by
tools/designer_period_try.sql in a rolled-back dry run (3,900 numbers of 50
made-up models against counts written plainly from the rows) and on a
deployment by tools/web/designer_period_flow.mjs; these read the files and
hold the promises around it:

- only the server may run it, and the API asks it only for the account its
  sign-in proves, never one the request names, and no cache keeps the
  answer; an error from it leaves Insights drawn without it, never failed;
- the days are one rule (UTC; the last 30 end yesterday; the 30 before
  those; 8 weeks of 7, the newest ending yesterday; each number from the day
  its counting began) in the SQL, the flow's plain count and the page's words;
- no change is said against days nobody counted, and such a model is left out
  of Gaining and Fading; the chart begins where counting did;
- views' start is read from models that are not test models;
- the six kinds are the same six in the SQL, the API and the page, and each
  is said in words (and in de, fr and es: tools/site_lang.py --check);
- comments are counted by designer_said's rule, the one replies.sql keeps;
- one minus sign on the page, whole-number ticks;
- the privacy page says designers see how many saved, private lists too;
- the flow never runs against brickworks.diy, writes nothing a real
  designer's numbers read, takes its rows with it however it ends, and is a
  preview check.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIRST = (ROOT / "supabase/designer_period.sql").read_text()
SQL = (ROOT / "supabase/designer_period_2.sql").read_text()
LATER = (ROOT / "supabase/later.tsv").read_text()
TRY = (ROOT / "tools/designer_period_try.sql").read_text()
API = (ROOT / "api/_designers.js").read_text()
PAGE = (ROOT / "web/designs.js").read_text()
CSS = (ROOT / "web/directory.css").read_text()
FLOW = (ROOT / "tools/web/designer_period_flow.mjs").read_text()
SESSION = (ROOT / "tools/web/session.mjs").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()
PRIVACY = (ROOT / "web/privacy.html").read_text()
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


def test_each_file_only_adds_or_replaces_one_function() -> None:
    for name, text in (("designer_period.sql", FIRST), ("designer_period_2.sql", SQL)):
        plain = code(text).lower()
        for word in ("drop ", "truncate", "delete from", "rename ", "alter ", "insert into", "update ", "create table",
                     "create index", "create trigger", "create or replace trigger"):
            assert word not in plain, f"{name} says {word.strip()}"
        assert re.findall(r"create or replace function public\.([a-z_]+)\(", plain) == ["designer_period"], name
    others = [path.name for path in (ROOT / "supabase").glob("*.sql")
              if path.name not in ("designer_period.sql", "designer_period_2.sql")
              and "function public.designer_period(" in path.read_text()]
    assert not others, f"another file defines designer_period: {others}"
    # The first file may not be applied again over the second alone (tools/apply_sql.mjs).
    row = re.search(r"^designer_period\.sql\tdesigner_period\tdesigner_period_2\.sql\t(.+)$", LATER, flags=re.M)
    assert row, "supabase/later.tsv does not say designer_period_2.sql replaced designer_period.sql's function"
    assert row[1] in code(SQL) and row[1] not in FIRST
    # And it says why replacing it was safe.
    assert "nothing live calls designer_period yet" in SQL


def test_only_the_server_runs_it() -> None:
    plain = code(SQL)
    head = re.search(r"create or replace function public\.designer_period\(designer uuid\)(.*?)as \$\$", plain, flags=re.S)
    assert head and "security definer" in head[1] and "set search_path = public" in head[1] and "stable" in head[1]
    assert "revoke all on function public.designer_period(uuid) from public, anon, authenticated;" in plain
    assert "grant execute on function public.designer_period(uuid) to service_role;" in plain
    assert not re.search(r"grant execute on function public\.designer_period\([^)]*\) to (anon|authenticated|public)", plain)
    # Its models are designer_mine's: published and not taken out, theirs alone.
    assert "where m.owner = designer_period.designer and m.published and not m.barred" in plain


def test_the_api_asks_only_for_the_signed_in_account_and_never_fails_for_it() -> None:
    designs = js_function(API, "designs")
    read = re.search(r"const periodRead = \(account\) => (.*?);\n", API, flags=re.S)
    assert read, "no periodRead"
    assert 'response.setHeader("Cache-Control", MINE_CACHE);' in designs.split("\n")[1]
    assert "const account = (await verify(bearer(request), request)).sub;" in designs
    assert "periodRead(account)" in designs
    assert 'db("rpc/designer_period", { method: "POST", body: { designer: account } })' in read[1]
    # Nothing from the request goes into the function's body.
    assert "request" not in read[1]
    # Any trouble reading it (not applied, an error) is no period: Insights as before, never a failed page (F4).
    assert read[1].startswith('orUnknown("designers: designer_period",')
    assert "period.reason" not in designs and "period: counted ? counted.period : null" in designs
    # The first file's answer has no days counted: no period, never a change against days nobody counted.
    assert "!dayOf(said.til)) return null;" in js_function(API, "periodOf")


def test_one_rule_for_the_days() -> None:
    plain = code(SQL)
    assert "(now() at time zone 'UTC')::date as today" in plain
    assert ("t.today - 1 as til, t.today - 30 as now_from, t.today - 60 as before_from,\n"
            "               t.today - 31 as before_til, t.today - 56 as weeks_from") in plain
    # Each window from the day counting began, never today.
    assert "h.day between greatest(s.now_from, c.from_day) and s.til" in plain
    assert "h.day between greatest(s.before_from, c.from_day) and s.before_til" in plain
    assert "h.day between greatest(s.weeks_from, c.from_day) and s.til" in plain
    assert "(h.day - s.weeks_from) / 7" in plain
    assert "when s.weeks_from + 7 * w.w + 6 < c.from_day then null" in plain
    assert "'now_days', greatest(0, s.til - greatest(s.now_from, c.from_day) + 1)" in plain
    assert "'before_days', greatest(0, s.before_til - greatest(s.before_from, c.from_day) + 1)" in plain
    # Each timestamp read as its UTC day.
    for at in ("b.at", "l.at", "k.at", "c.at", "r.created_at", "m.created_at"):
        assert f"({at} at time zone 'UTC')::date" in plain, at
    # The flow's plain count by the same rule, from the answer's own days.
    assert "now: [period.now_from, period.til], before: [period.before_from, period.before_til]" in FLOW
    assert "[plusDays(period.weeks_from, 7 * w), plusDays(period.weeks_from, 7 * w + 6)]" in FLOW
    assert "period.til === plusDays(period.today, -1)" in FLOW and "period.now_from === plusDays(period.today, -30)" in FLOW
    # And the page says so, and never "today so far".
    assert "the newest ending yesterday. Days begin at midnight UTC" in PAGE
    assert "today so far" not in PAGE


def test_views_start_is_read_from_real_models_only() -> None:
    starts = code(SQL).split("starts as (")[1].split("mine as materialized")[0]
    assert re.search(r"select min\(o\.day\)\s+from public\.model_opens o\s+join public\.shared_models x on x\.id = o\.model\s+where not x\.test",
                     starts), "views' start is not read from models that are not test models"
    assert "'views_from', (select k.day from starts k where k.kind = 'views')" in code(SQL)
    # And the dry run shows a test row leaving it and a real one moving it.
    assert "Test rows dated 65 days back leave views' start where the real models have it" in TRY


def test_no_change_against_days_nobody_counted() -> None:
    whole = re.search(r"const whole = \(counts\) => (.*?);\n", PAGE)
    assert whole and whole[1] == "Number(counts?.now_days) >= DAYS && Number(counts?.before_days) >= DAYS"
    change = js_function(PAGE, "changeOf")
    assert change.split("\n")[1].strip() == 'if (!whole(counts)) return "short";'
    said = js_function(PAGE, "changeSaid")
    assert 'say("Counted since {day}", { day: short(counts.from) })' in said
    # Gaining and Fading leave out the short, after the rest, and say so.
    assert 'const AGAINST = new Set(["gaining", "fading"]);' in PAGE
    draw = js_function(PAGE, "drawPeriod")
    assert "const out = against ? rows.filter((one) => !whole(one.model.period[kind])) : [];" in draw
    assert "...out.slice().sort(by(SORTS.most))" in draw
    # The chart and each line from the first week counted: a null week is never drawn as nought.
    assert "weeks.findIndex((value) => value !== null && value !== undefined)" in js_function(PAGE, "countedWeeks")
    assert "countedWeeks(counts.weeks)" in js_function(PAGE, "chartOf")
    assert "countedWeeks(model.period[kind].weeks)" in js_function(PAGE, "weeksLine")


def test_one_minus_sign_and_whole_ticks() -> None:
    assert 'const MINUS = "\u2212";' in PAGE  # the character itself
    assert "signDisplay" not in PAGE.split("// Against the 30 days before.")[1]
    assert 'how === "down" ? MINUS : "+"' in js_function(PAGE, "changeSaid")
    assert ".filter(Number.isInteger)" in js_function(PAGE, "ticksOf")
    assert 'say("none before")' in PAGE
    # The weeks' line at 3:1 or more in both themes: --ink-faint, not --viz-muted (2.6:1 on white).
    assert ".design-weeks .line { fill: none; stroke: var(--ink-faint);" in CSS


def test_six_kinds_everywhere_each_in_words() -> None:
    starts = code(SQL).split("starts as (")[1].split("mine as materialized")[0]
    assert re.findall(r"select '([a-z]+)'", starts) == KINDS
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


def test_the_privacy_page_says_designers_see_how_many_saved() -> None:
    assert ("A model you save, in Saved or in a list of yours, private ones included, is counted for its designer alone: "
            "their Insights show how many people saved each of their models on each day, never who.") in PRIVACY
    assert "private ones included" in PAGE.split("saves: () => say(")[1].split("\n")[0]


def test_the_flow_is_a_preview_check_and_leaves_nothing() -> None:
    assert re.search(r"\[designer_period\]=\"tools/web/designer_period_flow\.mjs --url=\$P --out=", CHECKS)
    assert "brickworks\\.diy" in FLOW and "never on brickworks.diy" in FLOW
    # Its accounts are the run's own, which the leftovers sweep takes when a run is killed outright.
    assert "const addresses = { ada: runAddress(), bob: runAddress(), cy: runAddress() };" in FLOW
    assert "await sweepLeftBehind();" in FLOW and "export async function sweepLeftBehind()" in SESSION
    assert "await sweepLeftBehind();" in js_function(SESSION, "ownAccount")
    assert "bw-period" not in FLOW
    # Every row goes with them, in a finally and on a signal.
    assert "} finally {\n  const left = await tidy();" in FLOW
    assert 'for (const [signal, code] of [["SIGINT", 130], ["SIGHUP", 129], ["SIGTERM", 143]])' in FLOW
    assert "handleSIGINT: false, handleSIGTERM: false, handleSIGHUP: false" in FLOW
    # Views only on days the project already counts, and nobody's start moved.
    assert "plusDays(today, -d) >= firstOpen" in FLOW
    assert "nobody's start moved" in FLOW
