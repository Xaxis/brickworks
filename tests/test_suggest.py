"""A remixer's change sent back, and taken by the designer whole or in part
(api/_suggest.js, api/_suggestions.js, api/_notifications.js; suggestedit,
2026-11-23).

Each class of edit a remixer makes (a part added, taken away, moved,
recoloured, swapped for another, moved to another step, a step of its own,
a change inside a sub-model, a sub-model of its own) is made to real sets
of the library (tests/fixtures/suggest/check.mjs), all at once as the
remix, then taken: whole, every change ticked, each edit alone, and all but
each. Each result is read again and held to the model it should be, part for
part and step for step, section by section. And the designer's own text:
nothing taken gives it back byte for byte; what is taken leaves every line
of theirs it does not touch as they wrote it (their header, comments and
metas), in their line ends; a meta bound to a part goes with it, and a part
put in goes into the bracket it stood in.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SETS = ROOT / "vendor/omr/files"
CHECK = ROOT / "tests/fixtures/suggest/check.mjs"
has_node = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")
has_sets = pytest.mark.skipif(shutil.which("node") is None or not SETS.exists(),
                              reason="needs node and the library's sets (tools/omr.py fetch)")

# Real sets of every shape: sub-models placed in sub-models, LPub and MLCad
# metas, a model with no steps, files in CRLF, a big one (10179's 4,545
# parts in 903 steps), a set whose own section places only sub-models.
REAL = ["6054-1.mpd", "358-1.mpd", "5540-1.mpd", "8257-1.mpd", "7140-1.mpd", "10002-1.mpd", "8880-1.mpd",
        "6532-1.mpd", "7128-1.mpd", "7637-1.mpd", "4554-1.mpd", "5972-1.mpd", "21323-1.mpd", "40182-1.mpd",
        "4096-1_4WD.mpd", "10179-1.mpd"]
CLASSES = {"add", "remove", "move", "recolour", "swap", "step", "new_step", "in_sub_model", "sub_model"}


def node(script: str):
    run = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                         timeout=600, stdin=subprocess.DEVNULL)
    assert run.returncode == 0, run.stderr[-2000:]
    return json.loads(run.stdout)


def merged(mine: str, theirs: str, take) -> dict:
    return node(f"""
import {{ mergeSuggestion, suggestionChanges }} from "./api/_suggest.js";
const mine = {json.dumps(mine)};
const theirs = {json.dumps(theirs)};
const said = suggestionChanges(mine, theirs);
const take = {json.dumps(take)};
const ids = take === "all" ? "all" : said.changes.filter((c) => take.includes(c.kind)).map((c) => c.id);
console.log(JSON.stringify({{ said, out: mergeSuggestion(mine, theirs, ids) }}));
""")


@has_sets
def test_every_class_on_real_sets_taken_whole_and_in_part_gives_the_remixers_model():
    run = subprocess.run(["node", str(CHECK), *[str(SETS / name) for name in REAL]], cwd=ROOT, capture_output=True,
                         text=True, timeout=900, stdin=subprocess.DEVNULL)
    assert run.returncode == 0, run.stderr[-2000:]
    sets = json.loads(run.stdout)["sets"]
    assert sorted(sets) == sorted(REAL)
    seen = set()
    for name, got in sets.items():
        assert got["faults"] == [], (name, got["faults"][:3])
        seen |= set(got["edits"])
        # Each edit alone was found in the list and taken alone.
        assert all(one["ok"] and one["ids"] >= 1 for one in got["alone"].values()), name
        assert all(got["but"].values()), name
    assert seen == CLASSES


@has_node
def test_nothing_taken_is_the_designers_file_byte_for_byte_and_their_lines_stay():
    mine = ("﻿0 FILE car.ldr\r\n0 My car\r\n0 Name: car.ldr\r\n0 Author: Designer\r\n"
            "0 // the chassis, keep it low\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n"
            "0 !LPUB CALLOUT BEGIN\r\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n0 !LPUB CALLOUT END\r\n"
            "1 14 40 -24 0 1 0 0 0 1 0 0 0 1 3004.dat\r\n0 STEP\r\n0 NOFILE\r\n")
    theirs = ("0 FILE remix.ldr\n0 Their car\n0 Name: remix.ldr\n0 Author: Remixer\n"
              "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n0 !LPUB CALLOUT BEGIN\n"
              "1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\n1 1 20 -24 0 1 0 0 0 1 0 0 0 1 3005.dat\n0 !LPUB CALLOUT END\n"
              "0 !BRICKWORKS COPY 2\n1 14 40 -24 0 1 0 0 0 1 0 0 0 1 3004.dat\n"
              "1 15 80 -24 0 1 0 0 0 1 0 0 0 1 3010.dat\n0 STEP\n0 NOFILE\n")
    none = merged(mine, theirs, [])
    assert none["out"]["text"] == mine
    assert none["said"]["counts"] == {"added": 2, "removed": 0, "moved": 0, "recoloured": 1, "swapped": 0,
                                      "restepped": 0}
    # The additions alone: the designer's header, comment and line ends
    # stay, the recolour is not taken, and the part added in the callout
    # goes into the callout, the other after the step's last bare part.
    added = merged(mine, theirs, ["added"])["out"]["text"]
    assert added.startswith("﻿0 FILE car.ldr\r\n0 My car\r\n0 Name: car.ldr\r\n0 Author: Designer\r\n"
                            "0 // the chassis, keep it low\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n")
    assert "\r\n1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat\r\n1 1 20 -24 0 1 0 0 0 1 0 0 0 1 3005.dat\r\n0 !LPUB CALLOUT END\r\n" in added
    assert "3004.dat\r\n1 15 80 -24 0 1 0 0 0 1 0 0 0 1 3010.dat\r\n0 STEP\r\n" in added
    assert "\n" not in added.replace("\r\n", "")
    # The recolour alone: that one line, the rest as it was.
    painted = merged(mine, theirs, ["recoloured"])["out"]["text"]
    assert painted == mine.replace("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 2 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat")


@has_node
def test_a_meta_bound_to_a_part_goes_with_it():
    mine = ("0 FILE m.ldr\n0 !BRICKWORKS COPY 3\n1 16 0 0 0 1 0 0 0 1 0 0 0 1 wing.ldr\n"
            "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n0 FILE wing.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat\n0 NOFILE\n")
    theirs = "0 FILE m.ldr\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n"
    out = merged(mine, theirs, "all")["out"]["text"]
    # The reference taken away takes its COPY line with it, and the wing
    # nothing places any more goes too.
    assert "COPY" not in out and "wing.ldr" not in out
    assert out == "0 FILE m.ldr\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n"


@has_node
def test_a_model_of_one_file_given_a_sub_model_becomes_one_of_sections():
    mine = "0 Tower\n0 Name: tower.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
    theirs = ("0 FILE tower.ldr\n0 Tower\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
              "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr\n0 NOFILE\n"
              "0 FILE roof.ldr\n0 Roof\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 3037.dat\n0 NOFILE\n")
    got = merged(mine, theirs, "all")
    assert got["said"]["changes"][0]["brings"] == ["roof.ldr"]
    out = got["out"]["text"]
    assert out == ("0 FILE tower.ldr\n0 Tower\n0 Name: tower.ldr\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n"
                   "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 roof.ldr\n0 NOFILE\n"
                   "0 FILE roof.ldr\n0 Roof\n1 2 0 0 0 1 0 0 0 1 0 0 0 1 3037.dat\n0 NOFILE\n")


@has_node
def test_each_change_says_where_it_stands_for_the_studio_to_frame_it():
    mine = ("0 FILE m.ldr\n1 16 100 0 0 1 0 0 0 1 0 0 0 1 w.ldr\n1 16 -100 0 0 1 0 0 0 1 0 0 0 1 w.ldr\n0 NOFILE\n"
            "0 FILE w.ldr\n1 4 0 -24 10 1 0 0 0 1 0 0 0 1 3001.dat\n0 NOFILE\n")
    theirs = mine.replace("1 4 0 -24 10", "1 4 0 -24 30")
    said = merged(mine, theirs, [])["said"]
    [change] = said["changes"]
    assert change["kind"] == "moved" and change["section"] == "w.ldr" and change["part"] == "3001"
    # In the app's axes (+Y up), at both places the sub-model stands.
    assert change["was"]["at"] == [[100, 24, -10], [-100, 24, -10]]
    assert change["now"]["at"] == [[100, 24, -30], [-100, 24, -30]]
    assert change["was"]["step"] == 1 and change["id"] == "moved:w.ldr:6:6"


@has_node
def test_the_bell_says_a_change_sent_and_a_change_taken():
    got = node("""
import { noticeSaid, noticeGroups, suggestionLine } from "./api/_notifications.js";
const sent = { kind: "suggestion", at: "2026-11-23T10:00:00Z", on: "AbCdEfGhIj", model: "AbCdEfGhIj", suggestion: 7,
  remix: "ZyXwVuTsRq", name: "Red car, wider", of_name: "Red car", by: { handle: "ann", name: "Ann" },
  counts: { added: 3, removed: 0, moved: 1, recoloured: 0, swapped: 0, restepped: 2 }, note: "Wider wheels" };
const taken = { kind: "suggestion_taken", at: "2026-11-23T11:00:00Z", on: "ZyXwVuTsRq", model: "ZyXwVuTsRq",
  of: "AbCdEfGhIj", suggestion: 7, name: "Red car", of_name: "Red car, wider", by: { handle: "dee", name: "Dee" },
  whole: false, n: 4 };
const groups = noticeGroups({ rows: [taken, sent], models: {}, reads: {}, seen_at: null }, "https://x.test");
console.log(JSON.stringify({ sent: noticeSaid(sent, "https://x.test"), taken: noticeSaid(taken, "https://x.test"),
  line: suggestionLine({ added: 0, moved: 2, swapped: 1 }), groups: groups.groups.map((g) => [g.model, g.name]),
  unread: groups.unread }));
""")
    assert got["sent"]["link"] == "https://x.test/app?suggestion=7"
    assert got["sent"]["line"] == "{who} sent you a change from their remix “Red car, wider”: 3 added, 1 moved, 2 to another step"
    assert got["sent"]["who"] == "Ann" and got["sent"]["said"] == "Wider wheels"
    assert got["taken"]["link"] == "https://x.test/m/AbCdEfGhIj/v/4"
    assert got["taken"]["line"] == "{who} took part of your change into “Red car”"
    assert got["line"] == "2 moved, 1 swapped"
    # Each under the model it is about, named for it: the designer's, and
    # the remixer's own remix.
    assert got["groups"] == [["ZyXwVuTsRq", "Red car, wider"], ["AbCdEfGhIj", "Red car"]] and got["unread"] == 2


@has_node
def test_a_publish_names_the_change_it_takes_only_in_its_shape():
    got = node("""
import { checkSuggestion } from "./api/_suggestions.js";
const out = {};
for (const [name, given] of Object.entries({ none: undefined, ok: { id: 3, taken: { added: 2 }, whole: false },
    bad_id: { id: "3" }, bad_count: { id: 3, taken: { added: -1 } }, bad_whole: { id: 3, whole: "yes" } })) {
  try { out[name] = checkSuggestion(given); } catch (trouble) { out[name] = "refused: " + trouble.message; }
}
console.log(JSON.stringify(out));
""")
    assert got["none"] is None
    assert got["ok"] == {"id": 3, "taken": {"added": 2, "removed": 0, "moved": 0, "recoloured": 0, "swapped": 0,
                                            "restepped": 0}, "whole": False}
    assert all(str(got[name]).startswith("refused") for name in ["bad_id", "bad_count", "bad_whole"])


@has_node
def test_sent_heard_at_once_taken_in_part_published_and_credited_through_the_real_handlers():
    run = subprocess.run(["node", str(ROOT / "tests/fixtures/suggest/flow.mjs")], cwd=ROOT, capture_output=True,
                         text=True, timeout=300, stdin=subprocess.DEVNULL)
    assert run.returncode == 0, run.stderr[-2000:]
    got = json.loads(run.stdout)
    assert got["troubles"] == []
    # Refused where it must be: nobody, the designer sending the remix, a model that is no remix.
    assert [got[k]["status"] for k in ["not_signed_in", "not_yours", "not_a_remix"]] == [401, 403, 422]
    # A note over the limit refused in words, nothing kept; one with
    # zero-width characters and a no-break space kept clean.
    assert got["too_long"]["status"] == 422 and "559 characters: 500 at most" in got["too_long"]["body"]["error"]
    assert got["too_long_rows"] == 0 and got["sent_note"] == "Wider wheels, and a spoiler"
    # Sent, then sent again: one open, brought up to date.
    assert got["sent"]["status"] == 201 and got["sent"]["body"]["counts"] == {
        "added": 2, "removed": 1, "moved": 1, "recoloured": 1, "swapped": 1, "restepped": 1}
    assert got["sent_again"]["status"] == 200 and got["sent_again"]["body"]["again"] is True
    assert got["open_rows"] == 1
    # The designer's bell counts it the moment it is sent, the sender's not;
    # opening her notifications clears it, and they name it under her model.
    assert got["before_bell"]["body"]["count"] == 0
    assert got["bell"]["body"]["count"] == 1 and got["bell"]["body"]["notifications"] == 1
    assert got["ann_bell"]["body"]["count"] == 0
    assert got["bell_after_opening"]["body"]["count"] == 0
    [group] = got["told_groups"]
    assert group["model"] == "SuggestDee" and group["rows"][0]["kind"] == "suggestion"
    assert group["rows"][0]["link"] == "/app?suggestion=1" and group["rows"][0]["said"] == "Wider wheels, and a spoiler"
    # Read: the designer with her model's text, the sender without, nobody not at all.
    designer = got["as_designer"]["body"]
    assert designer["you"] == "designer" and designer["mine"] and designer["theirs"] and len(designer["changes"]) == 7
    assert got["as_sender"]["body"]["you"] == "sender" and "mine" not in got["as_sender"]["body"]
    assert got["as_nobody"]["status"] == 401
    assert len(got["open_for_dee"]["body"]["open"]) == 1 and got["open_for_ann"]["body"]["open"] is None
    # Taken in part: never by the sender, never into a version she does not have.
    assert got["merge_by_ann"]["status"] == 404 and got["merge_stale"]["status"] == 409
    assert got["merged"]["status"] == 200 and got["merged_as_engine"] is True
    assert got["merged"]["body"]["whole"] is False and got["merged"]["body"]["taken"]["recoloured"] == 0
    # Published as her version 2, naming it: marked taken by that version,
    # the file the merge, version 1's kept.
    assert got["published"]["status"] == 200 and got["published"]["body"]["version"] == 2
    assert got["published"]["body"]["suggestion"] == {"taken": True, "id": 1}
    assert got["row"]["status"] == "taken" and got["row"]["taken_n"] == 2 and got["row"]["whole"] is False
    assert got["versions"] == [1, 2] and got["file_now"] and got["file_kept"]
    assert got["taken_again"]["status"] == 409
    # The sender hears it, under her remix, linked to the version that took it.
    [heard] = got["ann_told"]["body"]["groups"]
    assert heard["model"] == "SuggestAnn" and heard["rows"][0]["kind"] == "suggestion_taken"
    assert heard["rows"][0]["link"] == "/m/SuggestDee/v/2"
    # And the model's changes credit her, for anybody.
    [credit] = got["credited"]["body"]["taken"]
    assert credit["n"] == 2 and credit["by"]["handle"] == "ann"
    # A second change, declined: closed, nothing taken.
    assert got["second"]["status"] == 201 and got["declined"]["status"] == 200 and got["declined_row"] == "declined"


def test_the_bell_is_asked_again_within_a_minute_in_the_app_and_on_the_site():
    app = (ROOT / "src/ui/account_panel.gd").read_text()
    site = (ROOT / "web/follow.js").read_text()
    import re
    every = float(re.search(r"const FEED_EVERY := ([0-9.]+)", app).group(1))
    again = int(re.search(r"const ASK_AGAIN_MS = (\d+);", site).group(1))
    assert every <= 50 and again <= 50000
    assert "setInterval(askCountAgain, ASK_AGAIN_MS)" in site and "visibilitychange" in site
