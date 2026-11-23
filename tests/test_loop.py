"""The loop measured on real people (loopmetrics, 2026-11-23; docs/ANALYTICS.md "The loop", /admin › Analytics › Funnels).

tests/fixtures/insights/loop_check.mjs applies supabase/loop_funnel.sql (after
analytics.sql and analytics2.sql) in a Postgres of its own (pg.mjs), lays down
a fixture of known rows and reads the loop, through the function and through
api/admin.js's ?op=loop. Every number below is counted by hand from the
fixture's own comments:

  this week (today - 6 to today), 14 person-days:
    N1   signed out   /privacy                                  stopped before the loop
    S1   signed out   /gallery (a phone)                        discovered
    S2   a2           /, /privacy                               discovered
    S3   signed out   /library/set/:n, /m/:id                   opened
    S4   a4 (tester)  the studio                                opened
    S5   a5           the studio, a part, its first             changed
    S6   signed out   /m/:id, the studio, a part                changed
    S7   a7           /m/:id, a comment on a9's model           shared
    S8   a8           the studio, a part, published (kept)      shared
    S9   a9           /gallery; a9's model: a7's comment, 2 builds   heard back
    S10  a10          /m/:id, a Talk thread; a2 answers in it   heard back
    S11  a11          /gallery and a part, back 3 days later    came back
    S11b a11          / on the day it came back                 discovered
    S12  a12          /; Claude's calls 4 days later            came back
  the week before, 3 person-days: a5 (back 6 days later), a signed-out /,
  a4 in the studio (back 12 days later: within 30, not 7).

Left out of people's read, each beside a person it could have counted for:
the owner's day (unless asked), a check's account doing everything on test
rows, a check's signed-out visit, the test pool's like of a8's model, follow
of a7, comment on a8's model and reply in a10's thread, a8's like of its own
model, a comment the owner took down, a check's build of its own model, and
a2's Talk post on a day a2 was not counted.
"""

from __future__ import annotations

import functools
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_insights import _pg_env  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/loop_funnel.sql").read_text()
LOOP_JS = (ROOT / "api/_loop.js").read_text()
CONSOLE = (ROOT / "web/admin-analytics.js").read_text()


def _run(*extra: str) -> dict | None:
    env = _pg_env()
    if env is None:
        return None
    done = subprocess.run(["node", "tests/fixtures/insights/loop_check.mjs", *extra], cwd=ROOT, capture_output=True,
                          text=True, timeout=900, env=env, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


@functools.cache
def _loop() -> dict | None:
    return _run()


@functools.cache
def _loaded() -> dict | None:
    # A busy site's 90 days laid on top: minutes of inserts, so its own run.
    return _run("--load=500")


def test_the_sql_only_adds_functions() -> None:
    # No table, no column, nothing kept about anybody (docs/SOCIAL.md D13):
    # only temporary tables of its own and one function, the server's alone.
    assert not re.search(r"create\s+table(?!\s+if not exists loop_)", SQL.replace("temp table", "table"), re.I)
    for made in re.findall(r"create\s+(?:temp\s+)?table\s+if not exists\s+(\S+)", SQL, re.I):
        assert made.startswith("loop_"), made
        assert re.search(rf"create temp table if not exists {made} \([^;]*\)\s+on commit drop;", SQL, re.S), made
    assert not re.search(r"^\s*(alter|drop)\s", SQL, re.I | re.M)
    for written in re.findall(r"\b(?:insert into|update|delete from|truncate)\s+(\S+)", SQL, re.I):
        assert written.startswith("pg_temp.loop_"), written
    assert "security definer" in SQL and "set search_path = ''" in SQL
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    assert _loop()["again"] == "ok"
    assert _loop()["tables_after"] == 0
    roles = _loop()["roles"]
    assert roles["anon"].startswith("permission denied") and roles["signed_in"].startswith("permission denied")
    assert roles["server"] == "ok"


def test_each_step_is_the_hand_count() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    week = _loop()["week"]
    this = week["this"]
    assert this["people"] == 14 and this["signed_in"] == 10 and this["days"] == 7 and this["kept_days"] == 7
    assert this["steps"] == {"discovered": 10, "opened": 7, "changed": 4, "shared": 3, "heard_back": 2, "came_back": 2,
                             "came_back_30": 2}
    # Each person-day at its furthest step: two at each, N1 short of the loop,
    # and a11's second day at discovered.
    assert this["stopped"] == {"none": 1, "discovered": 3, "opened": 2, "changed": 2, "shared": 2, "heard_back": 2, "came_back": 2}
    assert sum(this["stopped"].values()) == this["people"]
    assert this["built"] == 2
    assert this["heard"] == {"like": 0, "comment": 1, "follow": 0, "build": 1, "reply": 1}
    assert {k["name"]: k["people"] for k in this["kept"]} == {"share_publishes": 1, "build_photos": 0, "model_comments": 1,
                                                              "talk_posts": 1, "challenge_entries": 0}
    before = week["before"]
    assert before["people"] == 3 and before["days"] == 7
    assert before["steps"] == {"discovered": 2, "opened": 2, "changed": 0, "shared": 0, "heard_back": 0, "came_back": 1,
                               "came_back_30": 2}
    assert before["stopped"] == {"none": 0, "discovered": 1, "opened": 1, "changed": 0, "shared": 0, "heard_back": 0, "came_back": 1}
    assert before["built"] == 1
    assert week["range"]["before_to"] < week["range"]["from"] and before["to"] == week["range"]["before_to"]


def test_each_steps_names_are_listed_with_their_people() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    acts = {(a["step"], a["surface"], a["kind"], a["name"]): a["people"] for a in _loop()["week"]["this"]["acts"]}
    # Every line of api/_loop.js's table, in its order, zero or not.
    assert len(acts) == len(re.findall(r'^\s*\["(?:discovered|opened|changed|shared)", ', LOOP_JS, re.M))
    assert {k: v for k, v in acts.items() if v} == {
        ("discovered", "site", "view", "/"): 3, ("discovered", "site", "view", "/gallery"): 3,
        ("discovered", "site", "view", "/library/set/:n"): 1, ("discovered", "site", "view", "/m/:id"): 4,
        ("opened", "site", "view", "/m/:id"): 4, ("opened", "studio", "view", "/app"): 4,
        ("changed", "studio", "part", "placed"): 4, ("changed", "studio", "milestone", "first_part"): 1,
        ("shared", "site", "act", "people.comment"): 1, ("shared", "site", "act", "people.talk_start"): 1}


def test_the_checks_and_the_owner_are_left_out() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    got = _loop()
    # Everyone, the owner too: one person-day more, who opened, changed, discovered.
    assert got["everyone"]["this"]["people"] == 15
    assert got["everyone"]["this"]["steps"]["changed"] == 5 and got["everyone"]["this"]["steps"]["discovered"] == 11
    assert got["owner_only"]["this"]["people"] == 1
    # The checks' own read: the check's account and its signed-out visit, and
    # the build of the check's model (a build is a device's).
    checks = got["checks"]["this"]
    assert checks["people"] == 2 and checks["steps"]["changed"] == 1 and checks["steps"]["shared"] == 1
    assert checks["built"] == 1 and checks["heard"]["build"] == 1


def test_the_filters_narrow_as_the_consoles_do() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    got = _loop()
    assert got["signed_out"]["this"]["people"] == 4 and got["signed_out"]["this"]["steps"]["discovered"] == 3
    assert got["signed_out"]["this"]["signed_in"] == 0
    assert got["phone"]["this"]["people"] == 1 and got["phone"]["this"]["steps"]["discovered"] == 1
    assert got["testers"]["this"]["people"] == 1 and got["testers"]["this"]["steps"]["opened"] == 1
    # A sampled visit counts at its weight, as Overview's visitors do.
    assert got["sampled"]["this"]["people"] == 8 and got["sampled"]["this"]["steps"]["discovered"] == 8


def test_without_the_servers_secret_only_what_needs_no_account_is_read() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    got = _loop()["unhashed"]["this"]
    # No hash is joined to an id: the owner cannot be told apart, nothing kept
    # in the social tables is joined, Claude's days are not; the rows' own
    # hashes still say who came back on the site.
    assert got["people"] == 15 and got["steps"]["heard_back"] == 0 and got["steps"]["shared"] == 2
    assert got["steps"]["came_back"] == 1 and got["built"] == 2


def test_a_name_not_in_the_table_is_no_step_and_the_range_is_bounded() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    got = _loop()
    made_up = got["made_up"]["this"]
    assert [a["name"] for a in made_up["acts"]] == ["/gallery"]
    assert made_up["steps"]["discovered"] == 4 and made_up["steps"]["opened"] == 0
    assert got["too_long"] == "a range of at most 400 days"


def test_the_op_is_the_owners_and_says_what_the_function_says() -> None:
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    got = _loop()
    assert got["api_signed_out"] == 401 and got["api_stranger"] == 404
    api = got["api"]
    assert api["status"] == 200 and api["ready"] is True and api["hashed"] is True and api["filters"] == {"plan": "!owner"}
    # The same rows, hashed by the server: the same numbers as the function's.
    assert api["this"] == got["week"]["this"] and api["before"] == got["week"]["before"]
    sent = got["api_sent"]
    assert sent["steps"] == len(re.findall(r'^\s*\["(?:discovered|opened|changed|shared)", ', LOOP_JS, re.M))
    # People's accounts only (the test pool and the check's are the checks' read's), each hashed.
    assert sent["accounts"] == 10 and sent["hashed"] is True and sent["plans"]["owner"] == "owner"
    assert "check" not in sent["plans"] and "pool" not in sent["plans"]
    assert got["api_checks"] == {"status": 200, "people": 2, "accounts": 2}
    assert got["api_backwards"] == 400
    assert got["api_before_sql"] == {"status": 200, "ready": False}


def test_it_answers_within_a_second_over_90_days_of_a_busy_site() -> None:
    if _loaded() is None:  # no Postgres here (pg.mjs)
        return
    load = _loaded()["load"]
    # docs/ANALYTICS.md's cost: 500 visits a day, about 15,000 rows kept a day.
    assert load["visits"] >= 15000 and load["events"] >= 400000, load
    assert load["people"] >= 15000, load
    assert min(load["ms"]) <= 1000, load


def test_every_loop_name_is_one_the_counter_keeps() -> None:
    done = subprocess.run(["python3", "tools/insights_names.py", "--check"], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stdout + done.stderr
    assert "the loop's" in done.stdout
    # The check refuses a line naming nothing kept (a unit's typo).
    import importlib.util
    spec = importlib.util.spec_from_file_location("insights_names", ROOT / "tools/insights_names.py")
    names = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(names)
    data = names.build()
    looped, unkept = names.loop_unkept(data)
    assert looped >= 30 and unkept == []
    real = names.LOOP
    try:
        fake = ROOT / "tests" / ".loop_typo.js"
        fake.write_text(LOOP_JS.replace('["shared", "site", "act", "people.enter"],',
                                        '["shared", "site", "act", "people.enter"],\n  ["shared", "site", "act", "people.entre"],'))
        names.LOOP = fake
        assert names.loop_unkept(data)[1] == ["shared site act people.entre"]
    finally:
        names.LOOP = real
        fake.unlink(missing_ok=True)


def test_definitions_say_each_steps_rule() -> None:
    # Every step the op answers has its rule in Definitions (the card's
    # drawing is tools/web/loop_card_check.mjs's, in a browser).
    if _loop() is None:  # no Postgres here (pg.mjs)
        return
    steps = set(_loop()["week"]["this"]["steps"]) - {"came_back_30"}
    for step in steps | {"built"}:
        assert re.search(rf'\bloop_{step}: \["[^"]+", "[^"]{{20,}}"\]', CONSOLE), step
    assert {k for k, _ in re.findall(r'\["(\w+)", "([^"]+)"\]', CONSOLE.split("const LOOP_STEPS = ")[1].split(";")[0])} == steps
