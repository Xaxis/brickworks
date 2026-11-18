"""How the site and the studio are used, counted (insights, 2026-11-18; docs/ANALYTICS.md, /admin › Analytics).

tests/fixtures/insights/db_check.mjs applies supabase/analytics.sql twice in
a Postgres of its own (pg.mjs) and asks it: who may reach the rows, what a
beacon keeps and lets go, the caps, the read from the raw rows, the cron's
rollup held against those rows kind by kind, the read again from the rollup,
deleted accounts' rows, and forgetting after 30 days. api_check.mjs drives
the real handlers (api/plans.js's tally and cron, api/admin.js's read,
api/mcp.js's count of a tool call) with that Postgres answering their rpc
calls. names_check.mjs runs web/tally.js's names in node. Each is skipped
without a Postgres, as test_console.py's are.
"""

from __future__ import annotations

import functools
import glob
import json
import os
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/analytics.sql").read_text()
TALLY = (ROOT / "web/tally.js").read_text()
COUNTING = (ROOT / "web/counting.js").read_text()


def _pg_env() -> dict | None:
    pg_module = os.environ.get("PG_MODULE") or "/tmp/pg/node_modules/pg/lib/index.js"
    pg_bin = os.environ.get("PG_BIN") or next(iter(sorted(glob.glob(os.path.expanduser(
        "~/Projects/admission.sh/node_modules/.pnpm/@embedded-postgres+linux-x64@*/node_modules/"
        "@embedded-postgres/linux-x64/native/bin")))), "")
    if shutil.which("node") is None or not Path(pg_module).exists() or not (Path(pg_bin) / "postgres").exists():
        return None
    return {**os.environ, "PG_MODULE": pg_module, "PG_BIN": pg_bin}


def _run(script: str, env: dict | None, timeout: int = 240) -> dict:
    done = subprocess.run(["node", script], cwd=ROOT, capture_output=True, text=True, timeout=timeout, env=env,
                          stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    got = json.loads(done.stdout.strip().splitlines()[-1])
    assert "error" not in got, got.get("error")
    return got


@functools.cache
def _db() -> dict | None:
    env = _pg_env()
    return None if env is None else _run("tests/fixtures/insights/db_check.mjs", env)


@functools.cache
def _api() -> dict | None:
    env = _pg_env()
    return None if env is None else _run("tests/fixtures/insights/api_check.mjs", env)


@functools.cache
def _names() -> dict:
    return _run("tests/fixtures/insights/names_check.mjs", None, timeout=60)


# --- The SQL ------------------------------------------------------------------


def test_the_sql_only_adds() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    # Additive: applied again, nothing changes; nothing dropped or altered
    # but its own.
    assert _db()["again"] == "ok"
    for line in SQL.splitlines():
        if re.match(r"\s*(drop|alter|truncate|delete)\b", line, re.I):
            assert re.search(r"insights_", line), line


def test_nobody_but_the_servers_functions_reach_a_row() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    roles = _db()["roles"]
    assert roles["anon_reads"].startswith("permission denied")
    assert roles["signed_in_reads"].startswith("permission denied")
    # Not even the server's key reads a table: only the functions.
    assert roles["server_reads_table"].startswith("permission denied")
    assert roles["anon_takes"].startswith("permission denied")
    assert roles["server_takes"] == roles["server_reads"] == "ok"


def test_a_beacon_keeps_only_what_may_be_kept() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert got["take_a"] == 6 and got["take_b"] == 16 and got["take_b2"] == 1
    # One visit over two beacons: its first page kept, its seconds added up,
    # its last act the latest.
    assert got["visit_b"]["landing"] == "/app" and got["visit_b"]["beacons"] == 2 and got["visit_b"]["seconds"] == 360
    assert got["visit_b"]["last_act"] == "press:render_go" and got["visit_b"]["studio"] is True
    # A name with an address in it, words typed, another surface, an unknown
    # kind, a row that is not one: let go. A count past 10,000 is 10,000; a
    # time below 0 is none; seconds past an hour are an hour.
    assert got["take_bad"] == 2
    assert got["bad_events"] == [{"name": "/x", "n": 10000, "ms": None}, {"name": "/y", "n": 1, "ms": None}]
    assert got["bad_visit"] == {"landing": None, "source": None, "channel": "direct", "device": "desktop", "lang": "en",
                                "account": None, "seconds": 3600}
    assert got["bad_id"] == 0
    # A studio neither yes nor no is no; an about that is a list is nothing.
    assert got["take_odd"] == [0, 1]
    assert got["odd_visits"] == [{"visit": "fffffffffffffff7", "studio": False, "landing": "/app"},
                                 {"visit": "ggggggggggggggg8", "studio": False, "landing": None}]


def test_the_caps_hold() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert got["take_many"] == 80
    # Past the day's rows, no new visit and no call.
    assert got["flood"] == 0 and got["flood_visit"] == 0 and got["flood_call"] is False


def test_no_row_holds_an_address_words_or_an_id() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    assert _db()["leaks"] == []
    assert _api()["leaks"] == []
    assert _api()["answers_leak"] == []


def test_the_read_writes_nothing_and_the_rollup_reads_the_same() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert got["read_wrote"] == {"rollups": 0, "days": 0}
    assert got["read_same_before_and_after"] is True
    assert got["unrolled"] == [got["daily"]["rolled"][0]["day"]] and got["unrolled_after"] == 0


def test_the_rollup_is_right_against_the_rows_it_was_made_from() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    held = _db()["held"]
    assert len(held) >= 8, held
    for row in held:
        assert row["rolled"] == row["held"], row
        assert row["rolled_visits"] == row["held_visits"], row
        assert row["rolled_ok"] == row["held_ok"] and row["rolled_failed"] == row["held_failed"], row
        if row["held_p50"] is not None:
            assert abs(row["rolled_p50"] - row["held_p50"]) < 0.01, row


def test_the_rollup_keeps_reach_sources_and_plans() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert {one["name"]: one["visits"] for one in got["reach"]} == {"part": 1, "save": 1, "signed_in": 1, "studio": 1, "visit": 4}
    assert {(one["name"], one["channel"], one["device"]): one["visits"] for one in got["visit_rows"]} == {
        ("google.com", "search", "desktop"): 1, ("(none)", "direct", "desktop"): 2, ("reddit.com", "social", "phone"): 1}
    # An account's plan as the server said it; signed out is none.
    assert got["plan_rows"] == [{"plan": "free", "signed_in": True}, {"plan": "none", "signed_in": False},
                                {"plan": "tester", "signed_in": True}]
    assert got["firsts"] == [{"account": "a1" * 12, "part": True, "save": True, "channel": "search", "source": "google.com"}]


def test_the_read_answers_every_section() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    live = _db()["live"]
    assert live["day"]["visits"] == 4 and live["day"]["calls"] == 2 and live["day"]["published"] == 1
    assert live["funnel"]["signups"] == 2 and live["funnel"]["first_part"] == 1 and live["funnel"]["published"] == 1
    assert live["campaigns"][0]["campaign"] == "bw-abcdefghij"
    assert [one["channel"] for one in live["channels"]] == ["direct", "search", "social"]
    calls = {one["name"]: one for one in live["used"] if one["kind"] == "call"}
    assert calls["place_part"]["failed"] == 1 and calls["look_at_model"]["ok"] == 1
    assert live["retention"] and live["speed"]
    assert _db()["phone"]["visits"] == 1
    # The checks' own are read apart from everyone's.
    assert _db()["tests_read"]["visits"] == 2


def test_where_visits_stopped_is_each_visits_last_act() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    leave = _db()["leave"]
    assert [(one["surface"], one["name"], one["visits"]) for one in leave] == [("studio", "press:render_go", 1)]


def test_a_deleted_accounts_rows_go_and_a_short_listing_deletes_nothing() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert got["daily"]["accounts_gone"] == 1
    assert got["h2_left"] == {"days": 0, "firsts": 0, "visits": 0, "events": 0}
    # An empty listing (a failed read) is not every account deleted.
    assert got["daily_empty"]["accounts_gone"] < 0 and got["h1_kept"] == 1


def test_raw_rows_go_after_30_days_and_the_rollup_stays() -> None:
    if _db() is None:  # no Postgres here (pg.mjs)
        return
    got = _db()
    assert got["forgot"]["events"] > 0 and got["forgot"]["visits"] > 0
    assert got["after"]["events"] == 0 and got["after"]["visits"] == 0 and got["after"]["days"] > 0


# --- The beacon's route ---------------------------------------------------------


def test_a_browser_that_says_no_sends_nothing_that_is_kept() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()
    for key in ("dnt", "gpc", "eu_no_yes", "eu_false", "eu_string", "not_json", "too_big", "bad_visit"):
        assert got[key]["status"] == 204 and got[key]["kept"] == 0, (key, got[key])
    for key in ("plain", "as_text", "dnt_zero", "eu_yes", "us"):
        assert got[key]["status"] == 204 and got[key]["kept"] == 1, (key, got[key])
    assert got["get"] == 405


def test_only_production_rows_are_peoples() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()
    assert got["preview_test"] is True
    # A boolean sent as false, or as words, is as absent.
    assert got["production"] == {"plain": False, "check": True, "check_false": False, "check_string": False}


def test_an_account_is_kept_only_as_its_hash() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()["account"]
    assert got["kept"] == got["hash"] and got["length"] == 24
    assert got["bad_who"] is None


def test_a_studio_visit_lands_whole() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    rows = {(one["kind"], one["name"]): one for one in _api()["studio_rows"]}
    assert rows[("tool", "paint")]["n"] == 3 and rows[("tool", "paint")]["ms"] == 4200
    assert rows[("run", "simulate")]["ok"] is True and rows[("part", "placed")]["n"] == 4
    assert rows[("milestone", "first_save")]["ms"] == 42000 and rows[("load", "studio_ui")]["ms"] == 6100


# --- The owner's read and the cron ----------------------------------------------


def test_the_read_is_the_owners_alone() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()
    # Signed out 401, as every console op; anybody else 404, as a route that
    # is not there.
    assert got["read_signed_out"] == 401 and got["read_stranger"] == 404
    read = got["read"]
    assert read["status"] == 200 and read["ready"] is True and read["tests"] is True and read["hashed"] is True
    # Everyone but the owner unless asked.
    assert read["filters"] == {"plan": "!owner"}
    assert read["today"]["visits"] == 9 and read["today"]["signups"] == 1 and read["today"]["builders"] == 1
    assert read["funnel"]["first_part"] == read["funnel"]["first_save"] == 1
    assert read["tools"][0]["name"] == "paint" and read["runs"][0]["ok"] == 1
    assert read["seen"] == ["parts_search", "render_go"]
    assert got["read_accounts_sent"] == [{"plan": "free", "hashed": True}]


def test_the_reads_filters_and_range() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()
    assert got["read_phone"] == {"status": 200, "filters": {"device": "phone", "signed": True}, "visits": 0}
    assert got["read_backwards"]["status"] == 400 and got["read_too_long"] == 400


def test_the_cron_is_vercels_and_rolls_a_day_once() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()
    assert got["cron_anyone"] == 401
    assert got["cron"] == {"status": 200, "rolled": 1, "gone": 0}
    assert got["cron_plans_sent"] == ["free", "owner"]
    assert got["cron_again"] == {"status": 200, "rolled": 0}
    assert got["logged"] == []


def test_a_tool_call_is_counted_however_it_ended() -> None:
    if _api() is None:  # no Postgres here (pg.mjs)
        return
    got = _api()["mcp"]
    assert got["stopped"] is True and got["tabs"] is True and got["listed"] is True
    # The call the relay stopped on: failed, nobody's. The relay's own tool:
    # the account's, timed, whether it went not told. The list: not a call.
    assert got["counted"] == [{"tool": "look_at_model", "ok": False, "timed": False, "mine": False, "none": True},
                              {"tool": "tabs", "ok": None, "timed": True, "mine": True, "none": False}]


# --- The page's names -----------------------------------------------------------


def test_names_are_only_what_code_names() -> None:
    names = _names()["names"]
    assert names["Paint"] == "paint" and names["accents"] == "unicode_tool" and names["fullwidth"] == "paint"
    assert names["zero_width"] == "paint" and names["spaces"] == "render_go" and names["digits"] == "step_#_of_#"
    # An address is never kept, even mangled.
    assert names["at"] == "" and names["markup"] == "bx/b" and len(names["long"]) == 60
    assert names["empty"] == names["null"] == ""
    assert _names()["names_digits"] == "res://src/ui/main.gd:1234"


def test_a_page_is_its_template_never_its_id() -> None:
    pages = _names()["pages"]
    assert pages["model"] == {"name": "/m/:id", "lang": "en"}
    assert pages["version_de"] == {"name": "/m/:id/v/:n", "lang": "de"}
    assert pages["profile"]["name"] == "/u/:handle" and pages["challenge"]["name"] == "/c/:id"
    assert pages["set"]["name"] == "/library/set/:n" and pages["app"]["name"] == pages["build"]["name"] == "/app"
    assert pages["unknown"]["name"] == "/other" and pages["canonical_odd"]["name"] == "/other"
    assert pages["canonical"]["name"] == "/gallery" and pages["canonical_fr"] == {"name": "/gallery", "lang": "fr"}
    assert pages["said_es"]["lang"] == "es"


def test_a_visits_source_is_names_only() -> None:
    sources = _names()["sources"]
    assert sources["desk"] == {"channel": "social", "source": "reddit", "medium": "social", "campaign": "bw-abcdefghij"}
    # The desk's campaigns join its posts by their ids, digits and all.
    assert sources["desk_digits"]["campaign"] == "bw-k3j2h1g0f9"
    assert sources["google"]["channel"] == "search" and sources["google"]["source"] == "google.com"
    assert sources["chatgpt"]["channel"] == "ai" and sources["paid"]["channel"] == "paid"
    assert sources["mail"]["channel"] == "email" and sources["own"]["channel"] == "direct"
    assert sources["blog"] == {"channel": "referral", "source": "someones-blog.example", "medium": None, "campaign": None}
    assert sources["digit_host"]["source"] == "9to5mac.com"
    assert sources["email_source"]["source"] is None
    assert sources["bad"]["channel"] == "direct"
    assert "ada" not in json.dumps(sources) and "lovelace" not in json.dumps(sources)


def test_a_device_is_its_kind() -> None:
    devices = _names()["devices"]
    assert devices["iphone"] == {"device": "phone", "browser": "safari", "os": "ios"}
    assert devices["ipad"] == {"device": "tablet", "browser": "safari", "os": "ios"}
    assert devices["mac"]["device"] == "desktop" and devices["android"]["device"] == "phone"
    assert devices["android_tablet"]["device"] == "tablet" and devices["edge"]["browser"] == "edge"
    assert devices["firefox_linux"] == {"device": "desktop", "browser": "firefox", "os": "linux"}


def test_said_no_nothing_starts() -> None:
    assert _names()["sent_when_no"] == 0 and _names()["started_when_no"] is False


# --- What the page reads ---------------------------------------------------------


def test_the_collector_never_reads_what_people_type_or_see() -> None:
    # No field's value (a layout shift's entry.value is a number), no page
    # text, no file or model name.
    assert not re.search(r"(?<!entry)\.value\b", TALLY)
    for said in ("textContent", "innerText", "innerHTML", "selection", "clipboard", "files["):
        assert said not in TALLY, said
    # It asks counting.js before anything.
    assert "if (!counting()) return" in TALLY or "counting()" in TALLY
    assert "navigator.globalPrivacyControl === true" in COUNTING and '"brickworks.counting"' in COUNTING


def test_the_beacon_loads_after_the_first_screen() -> None:
    theme = (ROOT / "web/theme.js").read_text()
    shell = (ROOT / "src/boot/shell.html").read_text()
    assert 'import("/tally.js")' in theme and "requestIdleCallback" in theme
    assert 'import("/tally.js")' in shell
    # Nothing on a page loads it but those two.
    for page in (ROOT / "web").glob("*.html"):
        assert not re.search(r"<script[^>]*tally\.js|import\([\"']/tally\.js", page.read_text()), page.name


def test_no_turn_of_the_counter_takes_a_frame() -> None:
    # Each of its timers and handlers alone, on a studio of 3,000 controls
    # (more than any real one), ten minutes of it: never 16 ms of a frame.
    got = _run("tests/fixtures/insights/frame_check.mjs", None, timeout=60)
    assert got["controls"] == 3000 and got["beacons"] >= 40
    assert set(got["slowest"]) >= {"each_second", "a_press", "a_command", "a_beacon", "a_frame", "leaving"}, got["slowest"]
    assert all(ms < 16 for ms in got["slowest"].values()), got["slowest"]
    # A beacon stays small: 80 rows and 400 names at most.
    assert got["largest_beacon"] < 16000
