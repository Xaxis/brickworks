"""A model's own motions, on its card: one reading of their names, one limit.

The app writes a model's motions into its file as `0 !BRICKWORKS MOTION
"Open the dome" ...` lines (src/assembly/motions.gd), api/share.js reads their
names from the text published (api/_directory.js motionsIn) and keeps them,
and supabase/motions.sql holds them under a check of its own. If the server
kept more or longer names than the database allows, every publish of such a
model would lose them; if it read a name the app does not (a motion that moves
nothing), the card would offer a motion its link cannot play.

And directory_card is defined in several files, the last applied winning:
motions.sql's must carry every key of play.sql's. What the SQL does is proven
by tools/motions_try.sql in a rolled-back dry run, and tools/sql_compare.mjs.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/motions.sql").read_text()
PLAY = (ROOT / "supabase/play.sql").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
LINES = (ROOT / "tests/fixtures/motions/1484-1.motions").read_text()


def function(text: str, name: str) -> str:
    """The body of public.[name] as [text] defines it, last definition first."""
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name} in the file"
    return found[-1]


def node(script: str) -> object:
    """What [script] prints as JSON, run with api/_directory.js as `m`."""
    if shutil.which("node") is None:
        return None
    wrapped = f"import('./api/_directory.js').then((m) => {{ console.log(JSON.stringify(({script}))); }})"
    out = subprocess.run(["node", "-e", wrapped], cwd=ROOT, capture_output=True, text=True, timeout=60, check=True)
    return json.loads(out.stdout)


def test_the_server_and_the_database_hold_the_same_limits() -> None:
    most = int(re.search(r"export const MOST_MOTIONS = (\d+);", DIRECTORY)[1])
    longest = int(re.search(r"export const MOTION_NAME = (\d+);", DIRECTORY)[1])
    check = function(SQL, "motion_names_ok")
    assert f"<= {most}" in check
    assert f"char_length(name) not between 1 and {longest}" in check


def test_the_names_are_read_as_the_app_writes_them() -> None:
    text = "\n".join([
        "0 FILE house.ldr",
        LINES,
        # A motion that moves nothing is nothing to the app (Motions.read).
        '0 !BRICKWORKS MOTION "Do nothing" AFTER "" SECONDS 1',
        # The same name again, in another case: the app's one motion.
        '0 !BRICKWORKS MOTION_TRACK "open the gates" 3 TURN AT 0 JOINT PART 3186 4 90 -48 -110',
        # A driver moves something.
        '0 !BRICKWORKS MOTION_DRIVER "Turn the  crank" TURNS 3 SECONDS 4 AT 0 JOINT PART 4185 71 0 -40 60',
        "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
    ])
    said = node(f"m.motionsIn({json.dumps(text)})")
    if said is None:
        return
    assert said == ["Open the gates", "Open the mailbox", "Turn the crank"]
    # Twelve at most, each 60 characters at most.
    many = "\n".join(f'0 !BRICKWORKS MOTION_TRACK "Swing {n} {"far " * 20}" 1 TURN AT 0 JOINT ASSEMBLY "A"' for n in range(20))
    kept = node(f"m.motionsIn({json.dumps(many)})")
    assert len(kept) == 12 and all(len(name) <= 60 and name == name.strip() for name in kept)


def test_a_card_says_them_as_a_sentence_says_them() -> None:
    said = node('[m.movesWords({motions: ["Open the dome", "Extend the telescope"], moves: ["turntable"]}),'
                ' m.movesWords({motions: ["R2 waves", "LED on", "A gate swings"]}),'
                ' m.movesWords({moves: ["steering", "boom"]}), m.movesWords({}),'
                ' m.movesWords({motions: ["One", "Two", "Three", "Four"]}, 3)]')
    if said is None:
        return
    assert said == ["open the dome, extend the telescope", "R2 waves, LED on, a gate swings", "steering, boom", "",
                    "one, two, three and 1 more"]
    cards = (ROOT / "web/card.js").read_text()
    # The card's own words for them, the same rule as the page's.
    rule = r"/^[A-Z][a-z]*\b/.test(name) ? name[0].toLowerCase() + name.slice(1) : name"
    assert rule in cards and rule.replace("\\b", "\\\\b") in DIRECTORY.replace("\\b", "\\\\b")
    assert re.search(r"^\s*motions: motionsOf\(row\.motions\),$", DIRECTORY, flags=re.M)


def test_directory_card_keeps_every_key_of_play_sql_and_says_the_motions() -> None:
    before = function(PLAY, "directory_card")
    after = function(SQL, "directory_card")
    for key in re.findall(r"'([a-z_]+)', ", before):
        assert f"'{key}', " in after, f"motions.sql's directory_card has lost {key}"
    squash = lambda text: re.sub(r"\s+", " ", text).strip()  # noqa: E731
    assert squash(after).replace(", 'motions', to_jsonb(m.motions)", "") == squash(before)


def test_only_additions() -> None:
    plain = re.sub(r"--[^\n]*", "", SQL).lower()
    for word in ["drop ", "rename ", "delete ", "update ", "truncate "]:
        assert word not in plain, f"motions.sql has a {word.strip()}"
    assert "add column if not exists motions text[] not null default '{}'" in plain
    for granted in re.findall(r"grant (\w+) on (?:function )?public\.(\w+)", SQL):
        assert granted[0] == "execute", f"motions.sql grants {granted[0]} on {granted[1]}"
    for name in ["motion_names_ok", "directory_card"]:
        assert re.search(rf"revoke all on function public\.{name}\(.*?\) from public, anon, authenticated;", SQL)
        assert re.search(rf"grant execute on function public\.{name}\(.*?\) to service_role;", SQL)
