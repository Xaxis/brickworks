"""The gallery that keeps itself fresh (gallery362, 2026-10-29).

api/_featured.js chooses, once a day, this week's pick, today's featured
model and today's set from the LDraw library, and api/_omr_watch.js looks
once a week at LDraw's Official Model Repository for sets the library has
not got. These drive the real code with a database and a web of their own:
the picking rules (what each signal weighs, no repeats, the same choice all
day), the lock against two runs at once, and how a look at the OMR reads
its pages and what it calls new. What the SQL does with the same calls is
proven by tools/gallery_crons_try.sql in a rolled-back dry run.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="no node here")


def node(script: str, env: dict | None = None) -> object:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, env=env)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


# A database as the SQL answers: the lock, the kept choices, the signals.
FAKE_DB = """
import * as F from "./api/_featured.js";
export function fakeDb(signals, { held = false, failOn = "" } = {}) {
  const state = { lock: held ? "someone" : null, runs: [], kept: [], calls: [] };
  const db = async (path, { body } = {}) => {
    const name = path.replace(/^rpc\\//, "");
    state.calls.push(name);
    if (name === failOn) throw new Error(`database POST rpc/${name}: 500`);
    if (name === "cron_begin") {
      const took = !state.lock;
      if (took) state.lock = body.holder;
      state.runs.push({ run: state.runs.length + 1, holder: body.holder, outcome: took ? null : "locked" });
      return { run: state.runs.length, locked: !took };
    }
    if (name === "cron_end") {
      const run = state.runs[body.run - 1];
      if (!run || run.outcome) return false;
      run.outcome = body.outcome; run.said = body.said;
      if (state.lock === body.holder) state.lock = null;
      return true;
    }
    if (name === "gallery_features_since") {
      return state.kept.filter((row) => row.slot === body.slot && row.day >= body.since)
        .sort((a, b) => b.day.localeCompare(a.day)).map(({ day, item, why }) => ({ day, item, why }));
    }
    if (name === "gallery_feature_signals") return signals;
    if (name === "gallery_feature_keep") {
      const there = state.kept.find((row) => row.slot === body.slot && row.day === body.day);
      if (there) return { ...there, made: false };
      const row = { slot: body.slot, day: body.day, item: body.item, why: body.why };
      state.kept.push(row);
      return { ...row, made: true };
    }
    throw new Error(`no rpc ${name}`);
  };
  return { db, state };
}
"""

SIGNALS = [
    {"id": "Kiln000001", "likes": 2, "builds": 1, "comments": 1, "remixes": 0, "tested": False,
     "listed_at": "2026-10-20T00:00:00Z", "has_image": True},
    {"id": "Quay000002", "likes": 0, "builds": 0, "comments": 0, "remixes": 0, "tested": False,
     "listed_at": "2026-10-28T00:00:00Z", "has_image": True},
    {"id": "Mill000003", "likes": 5, "builds": 0, "comments": 0, "remixes": 0, "tested": False,
     "listed_at": "2026-09-01T00:00:00Z", "has_image": True},
    {"id": "Dark000004", "likes": 50, "builds": 50, "comments": 0, "remixes": 0, "tested": True,
     "listed_at": "2026-10-01T00:00:00Z", "has_image": False},
]


def test_each_signal_weighs_what_it_says_and_new_fades() -> None:
    said = node("""
import * as F from "./api/_featured.js";
const day = "2026-10-29";
const one = (over) => F.scoreOf({ likes: 0, builds: 0, comments: 0, remixes: 0, tested: false, listed_at: "2020-01-01T00:00:00Z", ...over }, day).activity;
const fresh = (listed) => F.scoreOf({ listed_at: listed }, day).fresh;
console.log(JSON.stringify({
  like: one({ likes: 1 }), build: one({ builds: 1 }), comment: one({ comments: 1 }), remix: one({ remixes: 1 }),
  tested: one({ tested: true }), junk: one({ likes: -4, builds: "x" }),
  today: fresh("2026-10-29T00:00:00Z"), twoWeeks: fresh("2026-10-15T00:00:00Z"), never: fresh(null),
}));
""")
    assert said == {"like": 2, "build": 3, "comment": 1, "remix": 2, "tested": 5, "junk": 0,
                    "today": 4, "twoWeeks": 2, "never": 0}
    # A build finished counts as Top builds counts it.
    directory = (ROOT / "api/_directory.js").read_text()
    builds = re.search(r"export const SCORE = \{ builds: (\d+),", directory)
    assert builds and int(builds[1]) == said["build"]


def test_the_best_with_a_picture_is_featured_and_the_same_all_day() -> None:
    said = node(f"""
import * as F from "./api/_featured.js";
const signals = {json.dumps(SIGNALS)};
const day = "2026-10-29";
const a = F.chooseModel(signals, {{ day }});
const b = F.chooseModel([...signals].reverse(), {{ day }});
console.log(JSON.stringify({{ a, same: JSON.stringify(a) === JSON.stringify(b) }}));
""")
    # Mill's 5 likes (10, and old) and Kiln's 2 likes, a build and a comment
    # (8, and new) against Dark's 50 builds, which has no picture.
    assert said["a"]["item"] == "Kiln000001"
    assert said["a"]["why"]["likes"] == 2 and said["a"]["why"]["builds"] == 1 and said["a"]["why"]["comments"] == 1
    assert said["same"] is True


def test_nothing_featured_again_within_four_weeks_while_there_is_another() -> None:
    said = node(f"""
import * as F from "./api/_featured.js";
const signals = {json.dumps(SIGNALS)};
const recent = [{{ day: "2026-10-10", item: "Kiln000001" }}, {{ day: "2026-10-20", item: "Mill000003" }}];
const fresh = F.chooseModel(signals, {{ day: "2026-10-29", recent }});
const avoided = F.chooseModel(signals, {{ day: "2026-10-29", avoid: new Set(["Kiln000001"]) }});
// Every one featured lately: the one featured longest ago comes back.
const all = F.chooseModel(signals, {{ day: "2026-10-29", recent: [...recent, {{ day: "2026-10-25", item: "Quay000002" }}] }});
// Four weeks after Kiln was, it may come back; a day short of that, not.
const others = signals.filter((one) => one.id !== "Mill000003");
const kiln = [{{ day: "2026-10-10", item: "Kiln000001" }}];
const later = F.chooseModel(others, {{ day: "2026-11-08", recent: kiln }});
const short = F.chooseModel(others, {{ day: "2026-11-06", recent: kiln }});
console.log(JSON.stringify({{ fresh: fresh.item, avoided: avoided.item, all, later: later.item, short: short.item,
  none: F.chooseModel([], {{ day: "2026-10-29" }}) }}));
""")
    assert said["fresh"] == "Quay000002"
    assert said["avoided"] == "Mill000003"
    assert said["all"]["item"] == "Kiln000001" and said["all"]["why"]["again"] is True
    assert said["later"] == "Kiln000001" and said["short"] == "Quay000002"
    assert said["none"] is None


def test_ties_fall_by_the_day_never_at_random() -> None:
    said = node("""
import * as F from "./api/_featured.js";
const twins = ["Twin000001", "Twin000002", "Twin000003"].map((id) => ({ id, likes: 1, builds: 0, comments: 0, remixes: 0,
  tested: false, listed_at: null, has_image: true }));
const days = [];
for (let n = 0; n < 14; n += 1) days.push(F.chooseModel(twins, { day: F.daysFrom("2026-10-01", n) }).item);
const again = [];
for (let n = 0; n < 14; n += 1) again.push(F.chooseModel([...twins].reverse(), { day: F.daysFrom("2026-10-01", n) }).item);
console.log(JSON.stringify({ days, same: days.join() === again.join() }));
""")
    assert said["same"] is True
    assert len(set(said["days"])) >= 2


def test_a_week_is_kept_under_its_monday() -> None:
    said = node("""
import * as F from "./api/_featured.js";
console.log(JSON.stringify(["2026-10-26", "2026-10-29", "2026-11-01", "2026-11-02"].map(F.mondayOf)
  .concat([F.dayOf(new Date("2026-10-29T23:59:59Z")), F.daysFrom("2026-10-29", -90)])));
""")
    assert said == ["2026-10-26", "2026-10-26", "2026-10-26", "2026-11-02", "2026-10-29", "2026-07-31"]


SETS = [{"id": f"omr-{n}-1", "set": f"{n}-1", "name": f"Set {n}", "theme": theme, "year": year}
        for n, (theme, year) in enumerate([("Castle", 1984), ("Castle", 1986), ("Castle", 1993), ("Space", 1979),
                                           ("Space", 1987), ("Town", 1985), ("Town", 2004), ("Train > 9V", 2001),
                                           ("Pirates", 1989)] * 14, start=1000)]


def test_the_library_rotates_themes_and_decades_and_never_repeats_in_90_days() -> None:
    said = node(f"""
import * as F from "./api/_featured.js";
const sets = {json.dumps(SETS)};
const recent = [];
const days = [];
for (let n = 0; n < 100; n += 1) {{
  const day = F.daysFrom("2026-01-01", n);
  const choice = F.chooseSet(sets, {{ day, recent }});
  days.push({{ day, ...choice }});
  recent.unshift({{ day, item: choice.item, why: choice.why }});
}}
// The same day asked again chooses the same.
const again = F.chooseSet(sets, {{ day: "2026-01-01", recent: [] }});
// Every set featured within 90 days: none, never one again.
const spent = F.chooseSet(sets.slice(0, 3), {{ day: "2026-01-05", recent: sets.slice(0, 3).map((one, n) =>
  ({{ day: F.daysFrom("2026-01-01", n), item: one.id, why: {{}} }})) }});
console.log(JSON.stringify({{ days, again, spent }}));
""")
    days = said["days"]
    assert said["again"]["item"] == days[0]["item"]
    assert said["spent"] is None
    # Never a set within 90 days of its last.
    last: dict[str, str] = {}
    from datetime import date
    for one in days:
        if one["item"] in last:
            gap = (date.fromisoformat(one["day"]) - date.fromisoformat(last[one["item"]])).days
            assert gap > 90, (one["item"], gap)
        last[one["item"]] = one["day"]
    # Five themes: every five days each once.
    for at in range(0, 25, 5):
        assert sorted(one["why"]["theme"] for one in days[at:at + 5]) == ["Castle", "Pirates", "Space", "Town", "Train"]
    # Castle's decades take turns: 1980s, 1990s, 1980s ... never the same twice running.
    castle = [one["why"]["decade"] for one in days[:30] if one["why"]["theme"] == "Castle"]
    assert all(a != b for a, b in zip(castle, castle[1:])), castle
    assert set(castle) == {"1980s", "1990s"}


def test_a_run_keeps_each_choice_once_and_a_second_run_changes_nothing() -> None:
    said = node(FAKE_DB + f"""
const {{ db, state }} = fakeDb({json.dumps(SIGNALS)});
const sets = async () => {json.dumps(SETS[:6])};
const now = new Date("2026-10-29T00:07:00Z");
const first = await F.runFeatures({{ db, sets, now, holder: "test" }});
const second = await F.runFeatures({{ db, sets, now: new Date("2026-10-29T13:00:00Z"), holder: "test" }});
const next = await F.runFeatures({{ db, sets, now: new Date("2026-10-30T00:07:00Z"), holder: "test" }});
console.log(JSON.stringify({{ first, second, next, kept: state.kept, runs: state.runs, lock: state.lock }}));
""")
    first, second, nxt = said["first"], said["second"], said["next"]
    assert first["outcome"] == "done"
    assert first["pick"]["made"] and first["featured"]["made"] and first["library"]["made"]
    # The week's pick is kept under Monday; never also today's featured model.
    assert [row["day"] for row in said["kept"] if row["slot"] == "pick"] == ["2026-10-26"]
    assert first["pick"]["item"] != first["featured"]["item"]
    # The same day again: the same three, nothing made.
    assert second["outcome"] == "unchanged"
    assert {k: second[k]["item"] for k in ("pick", "featured", "library")} \
        == {k: first[k]["item"] for k in ("pick", "featured", "library")}
    assert not any(second[k]["made"] for k in ("pick", "featured", "library"))
    # The next day: the week's pick stays, a new featured model and a new set.
    assert nxt["outcome"] == "done" and nxt["pick"]["made"] is False and nxt["pick"]["item"] == first["pick"]["item"]
    assert nxt["featured"]["item"] != first["featured"]["item"] and nxt["library"]["item"] != first["library"]["item"]
    assert [run["outcome"] for run in said["runs"]] == ["done", "unchanged", "done"]
    assert said["lock"] is None
    assert len(said["kept"]) == 5


def test_a_run_that_finds_the_lock_held_does_nothing() -> None:
    said = node(FAKE_DB + f"""
const {{ db, state }} = fakeDb({json.dumps(SIGNALS)}, {{ held: true }});
const done = await F.runFeatures({{ db, sets: async () => [], now: new Date("2026-10-29T00:07:00Z") }});
console.log(JSON.stringify({{ done, kept: state.kept, calls: state.calls, runs: state.runs }}));
""")
    assert said["done"]["outcome"] == "locked"
    assert said["kept"] == [] and said["calls"] == ["cron_begin"]
    assert said["runs"][0]["outcome"] == "locked"


def test_a_run_that_fails_is_written_down_as_failed_and_lets_the_lock_go() -> None:
    said = node(FAKE_DB + f"""
const {{ db, state }} = fakeDb({json.dumps(SIGNALS)}, {{ failOn: "gallery_feature_keep" }});
let thrown = "";
try {{ await F.runFeatures({{ db, sets: async () => [], now: new Date("2026-10-29T00:07:00Z") }}); }}
catch (trouble) {{ thrown = trouble.message; }}
console.log(JSON.stringify({{ thrown, runs: state.runs, lock: state.lock }}));
""")
    assert "500" in said["thrown"]
    assert said["runs"][0]["outcome"] == "failed" and "500" in said["runs"][0]["said"]["error"]
    assert said["lock"] is None


# The OMR, as its pages are laid out (library.ldraw.org, 2026-10-29), cut down.
FRONT = """<html><div>Latest Models</div><div class="grid">
<a class="flex" href="https://library.ldraw.org/omr/sets/1689"><div>8094-1 - TECHNIC Control Centre</div></a>
<a class="flex" href="https://library.ldraw.org/omr/sets/1689"><div>8094-1 - TECHNIC Control Centre</div></a>
<a class="flex" href="https://library.ldraw.org/omr/sets/4515"><div>31153-1 - Modern House</div></a>
</div><div>What is this?</div><a href="https://library.ldraw.org/omr/sets/9">not latest</a></html>"""


def set_page(number: str, name: str, models: list[tuple[str, str, int]]) -> str:
    blocks = "".join(
        f'<div><div> {title} </div><div><span class="x">Author:</span>{author} </div>'
        f'<a class="y" href="https://library.ldraw.org/media/omr_models/1/{file}?v={stamp}">Download</a></div>'
        for title, author, stamp, file in models)
    if not models:
        blocks = "<div>No Models Yet</div>"
    return (f"<html><head><title>LDraw.org Official Model Repository - {name.replace('&', '&amp;amp;')} | LDraw.org "
            f'Library</title></head><body><div wire:name="omr.set.show"><div class="t">{number} - '
            f"{name.replace('&', '&amp;')}</div><div>Models</div>{blocks}</div></body></html>")


WEB = {
    "https://library.ldraw.org/omr": FRONT,
    "https://library.ldraw.org/omr/sets/1689": set_page("8094-1", "TECHNIC Control Centre", [
        ("Robotic Arm", "Takeshi Takahashi [RainbowDolphin]", 1770148074, "8094-1_Robotic-Arm.mpd"),
        ("Plotter", "Takeshi Takahashi [RainbowDolphin]", 1770148096, "8094-1_Plotter.mpd")]),
    "https://library.ldraw.org/omr/sets/4515": set_page("31153-1", "Modern House", [
        ("Main Model", "Johann Eisner [technicbasics]", 1770147417, "31153-1.mpd")]),
    "https://library.ldraw.org/omr/sets/1474": set_page("6990-1", "Monorail Transport System", [
        ("Main Model", "Someone", 1690000000, "6990-1.mpd")]),
    "https://library.ldraw.org/omr/sets/1475": set_page("60504-1", "Coast Guard Rescue Boat & Helicopter", []),
    "https://library.ldraw.org/omr/sets/1476": set_page("4000-1", "Updated Again", [
        ("Main Model", "Someone Else", 1790000000, "4000-1.mpd")]),
}


def test_a_set_page_is_read_for_its_models_files_and_stamps() -> None:
    said = node(f"""
import * as W from "./api/_omr_watch.js";
const web = {json.dumps(WEB)};
console.log(JSON.stringify({{
  latest: W.latestPages(web["https://library.ldraw.org/omr"]),
  control: W.arrivalOf(W.readSetPage(web["https://library.ldraw.org/omr/sets/1689"], 1689)),
  house: W.arrivalOf(W.readSetPage(web["https://library.ldraw.org/omr/sets/4515"], 4515)),
  empty: W.readSetPage(web["https://library.ldraw.org/omr/sets/1475"], 1475),
  notASet: W.readSetPage("<html><title>Page not found</title></html>", 7),
  pageOf: W.pageOf({{ page: "https://library.ldraw.org/omr/sets/657" }}),
}}));
""")
    assert said["latest"] == [1689, 4515]
    # No file named for the set: its first model, and the newest stamp of all.
    assert said["control"] == {"page": 1689, "set_number": "8094-1", "name": "TECHNIC Control Centre",
                               "file": "https://library.ldraw.org/media/omr_models/1/8094-1_Robotic-Arm.mpd",
                               "stamp": 1770148096, "author": "Takeshi Takahashi [RainbowDolphin]"}
    assert said["house"]["file"].endswith("/31153-1.mpd") and said["house"]["author"] == "Johann Eisner [technicbasics]"
    assert said["empty"]["models"] == [] and said["empty"]["name"] == "Coast Guard Rescue Boat & Helicopter"
    assert said["notASet"] is None
    assert said["pageOf"] == 657


LOOK = f"""
import * as W from "./api/_omr_watch.js";
const web = {json.dumps(WEB)};
const asked = [];
const fetchText = async (url) => {{ asked.push(url); return web[url] ? {{ status: 200, text: web[url] }} : {{ status: 404, text: "" }}; }};
const waits = [];
const wait = async (ms) => {{ waits.push(ms); }};
"""


def test_a_look_finds_what_is_new_or_updated_and_stops_after_three_missing() -> None:
    said = node(LOOK + """
// The library has 1473 (the highest) and 4515, from an index written on 2026-10-26.
const sets = [{ page: "https://library.ldraw.org/omr/sets/1473" }, { page: "https://library.ldraw.org/omr/sets/4515" }];
const indexAt = Date.parse("2026-10-26T12:00:00Z");
const first = await W.look({ fetchText, sets, indexAt, wait });
const askedFirst = [...asked];
const waitsFirst = waits.length;
// An earlier look wrote 1689 down with its stamp: not found again.
asked.length = 0;
const again = await W.look({ fetchText, sets, indexAt, known: { 1689: 1770148096, 1474: 1690000000 }, wait });
console.log(JSON.stringify({ first, askedFirst, again: again.found.map((one) => one.page), waits: waitsFirst }));
""")
    first = said["first"]
    # 1689, of the latest, is not in the library; 4515 is, from an index
    # written after its file.
    assert [one["page"] for one in first["found"]] == [1689]
    # Ahead of 4515 (the highest known): 4516-4518 missing, then it stops.
    assert first["ahead"] == [{"page": 4516, "set": None, "models": 0}, {"page": 4517, "set": None, "models": 0},
                              {"page": 4518, "set": None, "models": 0}]
    assert said["askedFirst"][:3] == ["https://library.ldraw.org/omr", "https://library.ldraw.org/omr/sets/1689",
                                      "https://library.ldraw.org/omr/sets/4515"]
    # A second between every two requests.
    assert said["waits"] == len(said["askedFirst"]) - 1 == 5
    assert "https://library.ldraw.org/omr/sets/9" not in said["askedFirst"]
    # Found by an earlier look with the same stamp: not again.
    assert said["again"] == []


def test_a_look_past_the_highest_passes_a_set_with_no_model_yet() -> None:
    said = node(LOOK + """
const sets = [{ page: "https://library.ldraw.org/omr/sets/1473" }];
const seen = await W.look({ fetchText, sets, indexAt: 0, known: {}, wait });
console.log(JSON.stringify({ found: seen.found.map((one) => [one.page, one.set_number]), ahead: seen.ahead }));
""")
    # Past 1473: 1474 (found), 1475 (no model yet, passed over), 1476 (found),
    # then 1477-1479 missing.
    assert said["found"] == [[1689, "8094-1"], [4515, "31153-1"], [1474, "6990-1"], [1476, "4000-1"]]
    assert [one["page"] for one in said["ahead"]] == [1474, 1475, 1476, 1477, 1478, 1479]
    assert said["ahead"][1] == {"page": 1475, "set": "60504-1", "models": 0}


def test_an_update_is_a_newer_stamp_than_the_index_or_the_last_look() -> None:
    said = node(LOOK + """
const sets = [{ page: "https://library.ldraw.org/omr/sets/4515" }, { page: "https://library.ldraw.org/omr/sets/1689" }];
// The index written before 4515's file changed: an update; 1689's after: not.
const before = await W.look({ fetchText, sets, indexAt: Date.parse("2026-02-03T00:00:00Z"), wait });
const after = await W.look({ fetchText, sets, indexAt: Date.parse("2026-10-26T00:00:00Z"), wait });
console.log(JSON.stringify({ before: before.found.map((one) => one.page), after: after.found.map((one) => one.page) }));
""")
    assert 4515 in said["before"] and 1689 in said["before"]
    assert 4515 not in said["after"] and 1689 not in said["after"]


def test_the_weekly_run_writes_what_it_found_under_its_lock_and_a_dry_run_writes_nothing() -> None:
    said = node(LOOK + """
const sets = async () => [{ page: "https://library.ldraw.org/omr/sets/4515" }];
const make = (held) => {
  const state = { lock: held, written: [], runs: [] };
  const db = async (path, { body } = {}) => {
    const name = path.replace(/^rpc\\//, "");
    if (name === "cron_begin") { const took = !state.lock; if (took) state.lock = body.holder; state.runs.push(took ? null : "locked"); return { run: state.runs.length, locked: !took }; }
    if (name === "cron_end") { state.runs[body.run - 1] = body.outcome; state.lock = null; return true; }
    if (name === "library_arrivals_in") return [];
    if (name === "library_arrivals_found") { state.written.push(...body.found); return body.found.map((one) => one.page); }
    throw new Error(name);
  };
  return { db, state };
};
const dry = make(null);
const dryDone = await W.runOmrWatch({ db: dry.db, fetchText, sets, indexAt: Date.now(), dry: true, wait });
const real = make(null);
const done = await W.runOmrWatch({ db: real.db, fetchText, sets, indexAt: Date.now(), holder: "test", wait });
const held = make("someone");
const locked = await W.runOmrWatch({ db: held.db, fetchText, sets, indexAt: Date.now(), wait });
let refused = "";
try { await W.runOmrWatch({ db: real.db, fetchText, sets: async () => [], indexAt: 0, wait }); } catch (e) { refused = e.message; }
console.log(JSON.stringify({ dry: [dryDone.outcome, dryDone.found.length, dry.state.written.length, dry.state.runs.length],
  done: [done.outcome, done.written, real.state.runs], locked: [locked.outcome, held.state.written.length], refused }));
""")
    assert said["dry"][0] == "dry" and said["dry"][1] > 0 and said["dry"][2:] == [0, 0]
    assert said["done"][0] == "done" and 1689 in said["done"][1] and said["done"][2] == ["done"]
    assert said["locked"] == ["locked", 0]
    assert "cannot be read" in said["refused"]


def test_the_crons_are_registered_routed_and_the_cron_s_alone() -> None:
    deploy = (ROOT / "tools/deploy.sh").read_text()
    for path, op in (("/api/share/feature", "feature"), ("/api/share/omr", "omr")):
        assert re.search(rf'\{{ "path": "{re.escape(path)}", "schedule": "[0-9*/ ,-]+" \}}', deploy), path
        assert f'{{ "src": "{path}", "dest": "/api/share?op={op}" }}' in deploy
    env = {**os.environ, "SUPABASE_URL": "https://example.invalid", "SUPABASE_SECRET_KEY": "x",
           "SUPABASE_PUBLISHABLE_KEY": "x", "CRON_SECRET": "right"}
    said = node("""
import handler from "./api/share.js";
const ask = async (op, authorization) => {
  let status = 0; let body = null;
  const response = { setHeader() { return this; }, status(n) { status = n; return this; }, json(b) { body = b; return this; }, end() { return this; } };
  await handler({ method: "GET", query: { op }, headers: authorization ? { authorization } : {} }, response);
  return [status, body?.error || ""];
};
console.log(JSON.stringify({ feature: await ask("feature"), omr: await ask("omr", "Bearer wrong") }));
""", env=env)
    assert said["feature"][0] == 401 and said["omr"][0] == 401


def test_an_arrival_is_held_to_our_checks_before_it_is_staged(tmp_path: Path) -> None:
    import sys
    sys.path.insert(0, str(ROOT / "tools"))
    import library_import

    arrival = {"page": 4515, "set_number": "31153-1", "name": "Modern House",
               "file": "https://library.ldraw.org/media/omr_models/1858/31153-1.mpd"}
    sets = {"31153-1": {"number": "31153-1", "name": "Modern House", "theme": "Creator", "year": "2024"}}
    good = tmp_path / "31153-1.mpd"
    good.write_text("0 FILE 31153-1.ldr\n0 Modern House\n0 Name: 31153-1.ldr\n0 Author: Johann Eisner [technicbasics]\n"
                    "0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt\n"
                    "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
    entry, why = library_import.entry_of(arrival, good, sets)
    assert why == "" and entry is not None
    assert entry["id"] == "omr-31153-1" and entry["licence"] == "CC BY 4.0" and entry["author"] == "Johann Eisner"
    assert entry["page"] == "https://library.ldraw.org/omr/sets/4515" and entry["parts"] == 2
    assert entry["theme"] == "Creator" and entry["year"] == 2024 and entry["file"] == "library/omr/31153-1.mpd"
    # A licence the site cannot pass on, no parts, or no theme and year: refused, with why.
    closed = tmp_path / "closed.mpd"
    closed.write_text(good.read_text().replace("Licensed under CC BY 4.0", "Not redistributable"))
    assert library_import.entry_of(arrival, closed, sets)[1].startswith("no licence")
    empty = tmp_path / "empty.mpd"
    empty.write_text("0 FILE e.ldr\n0 Author: X\n0 !LICENSE Licensed under CC BY 4.0 : see CAreadme.txt\n")
    assert "no parts" in library_import.entry_of(arrival, empty, sets)[1]
    assert "theme and year" in library_import.entry_of(arrival, good, {})[1]


def test_a_featured_model_s_why_says_only_what_is_true() -> None:
    said = node("""
import * as F from "./api/_featured.js";
const day = "2026-10-30";
const none = { likes: 0, builds: 0, comments: 0, remixes: 0 };
console.log(JSON.stringify({
  done: F.featuredSaid({ ...none, likes: 2, builds: 1, tested: true }, "2026-05-03T10:00:00Z", day),
  one: F.featuredSaid({ ...none, comments: 1 }, null, day),
  oldTested: F.featuredSaid({ ...none, tested: true }, "2026-05-03T10:00:00Z", day),
  oldPlain: F.featuredSaid({ ...none, tested: false }, "2026-05-03T10:00:00Z", day),
  newTested: F.featuredSaid({ ...none, tested: true }, "2026-10-20T10:00:00Z", day),
  newPlain: F.featuredSaid(none, "2026-10-01T00:00:00Z", day),
  monthAndADay: F.featuredSaid(none, "2026-09-29T23:00:00Z", day),
  unknown: F.featuredSaid({}, null, day),
}));
""")
    assert said == {
        "done": "2 likes, 1 build finished in the past 30 days",
        "one": "1 comment in the past 30 days",
        # Nothing done in 30 days: "New" only for a model listed in them.
        "oldTested": "Tested", "oldPlain": "",
        "newTested": "New in the past 30 days, and Tested", "newPlain": "New in the past 30 days",
        "monthAndADay": "", "unknown": "",
    }
