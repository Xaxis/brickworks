"""A comment pinned to a part (partpins, docs/MASTERPLAN.md row 6), held to what it promises.

The rule of which part a pin is on, on its own version and on another
(web/card.js pinPlace, kept by the model's page, its 3D view, the server and
the app's src/net/pin_place.gd), on real models' version pairs made by each
kind of edit (tools/pin_pairs.mjs: move, recolour, remove, add beside, swap):
never on a wrong part, and a moved part's pin follows it. The server's
reading of a pressed part against the version's own file (api/_comments.js
pinFrom), what it keeps, what a notification says, and the promises of
supabase/comment_pins.sql (additive, the server alone). What the SQL does is
proven by tools/comment_pins_try.sql in a rolled-back dry run, the pages by
tools/web/partpins_flow.mjs, the app by src/dev/partpins_probe.gd.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/comment_pins.sql").read_text()
PAIRS = ROOT / "tests/fixtures/pins/pairs.json"


def node(script: str):
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True, capture_output=True, text=True,
                          timeout=300)
    return json.loads(done.stdout)


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_pairs_are_what_the_generator_writes() -> None:
    done = subprocess.run(["node", "tools/pin_pairs.mjs", "--check"], cwd=ROOT, capture_output=True, text=True, timeout=300)
    assert done.returncode == 0, done.stderr


def test_no_pin_on_a_wrong_part_and_a_moved_part_s_pin_follows_it() -> None:
    # The rule run again here, never the file's own answers.
    said = node(f"""
import {{ readFileSync }} from "node:fs";
import {{ pinPlace }} from "./web/card.js";
const cases = JSON.parse(readFileSync({json.dumps(str(PAIRS))}, "utf8"));
const kinds = {{}};
for (const one of cases) {{
  const got = pinPlace(one.pin, one.bricks);
  const k = (kinds[one.kind] ||= {{ n: 0, wrong: [], followed: 0, kept: 0, none: 0, same: 0 }});
  k.n += 1;
  if (JSON.stringify(got) === JSON.stringify(one.want)) k.same += 1;
  if (got && (!one.truth || got.index !== one.truth.index)) k.wrong.push(one.name);
  if (got && one.truth && got.index === one.truth.index) got.moved ? (k.followed += 1) : (k.kept += 1);
  if (!got) k.none += 1;
}}
console.log(JSON.stringify(kinds));
""")
    assert sorted(said) == ["beside", "move", "recolour", "remove", "swap"]
    for kind, k in said.items():
        assert k["n"] == 20, kind
        assert k["wrong"] == [], (kind, k["wrong"])
        assert k["same"] == 20, kind
    # A moved part: its pin follows it, said moved, every time.
    assert said["move"]["followed"] == 20
    # Another added beside: the pin stays on its own part.
    assert said["beside"]["kept"] == 20
    # Gone, recoloured, swapped: listed on its version, on no part.
    for kind in ("remove", "recolour", "swap"):
        assert said[kind]["none"] == 20, kind


def test_a_pin_stays_on_its_part_on_its_own_version_on_every_model() -> None:
    # Every part of every example model, pinned as the page hands it over
    # (its number, colour, place and turn), comes back to itself.
    said = node("""
import { readFileSync, readdirSync } from "node:fs";
import { placesOf } from "./api/_parts.js";
import { pinFrom } from "./api/_comments.js";
import { pinPlace } from "./web/card.js";
const out = {};
for (const file of readdirSync("models").filter((f) => f.endsWith(".ldr")).sort()) {
  const places = placesOf(readFileSync(`models/${file}`, "utf8"));
  if (places.length > 3000) continue;
  let back = 0, refused = 0, other = 0;
  places.forEach((one, i) => {
    const pin = pinFrom(places, { part: one.part, colour: one.colour, at: one.at, turn: one.turn });
    if (!pin) { refused += 1; return; }
    const got = pinPlace(pin, places);
    if (got && !got.moved && (got.index === i || (places[got.index].section === one.section
      && places[got.index].line === one.line && Math.hypot(...places[got.index].at.map((v, k) => v - one.at[k])) < 1e-6))) back += 1;
    else other += 1;
  });
  out[file] = { parts: places.length, back, refused, other };
}
console.log(JSON.stringify(out));
""")
    assert len(said) >= 10
    for file, k in said.items():
        assert k["refused"] == 0, (file, k)
        assert k["other"] == 0, (file, k)
        assert k["back"] == k["parts"], (file, k)


def test_the_server_keeps_only_what_the_file_says() -> None:
    said = node("""
import { placesOf } from "./api/_parts.js";
import { cleanPart, pinFrom, pinShown } from "./api/_comments.js";
const text = ["0 FILE main.ldr", "0 Name: main.ldr", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
  "1 1 40 0 0 1 0 0 0 1 0 0 0 1 wing.ldr", "0 FILE wing.ldr", "1 15 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat"].join("\\n");
const places = placesOf(text);
const at = (p) => ({ part: p.part, colour: p.colour, at: p.at });
console.log(JSON.stringify({
  places: places.map((p) => [p.part, p.colour, p.at, p.section, p.line]),
  second: pinFrom(places, { part: "3001.dat", colour: 4, at: [0.5, -24.5, 0] }),
  wing: pinFrom(places, { part: "3020", colour: 15, at: [40, 0, 0] })?.line,
  wrongColour: pinFrom(places, { part: "3001.dat", colour: 1, at: [0, 0, 0] }),
  nowhere: pinFrom(places, { part: "3001.dat", colour: 4, at: [0, -60, 0] }),
  bad: [null, {}, { part: "", colour: 4, at: [0, 0, 0] }, { part: "3001.dat", colour: "red", at: [0, 0, 0] },
    { part: "3001.dat", colour: 4, at: [0, 0] }, { part: "3001.dat", colour: 4, at: [0, "x", 0] },
    { part: "<b>.dat", colour: 4, at: [0, 0, 0] }, { part: "3001.dat", colour: 4, at: [0, 0, 1e9] }].map((g) => Boolean(cleanPart(g).trouble)),
  good: cleanPart({ part: "3001.dat", colour: 4, at: ["1", 2, 3], said: "<script>" }).part,
  shownJunk: [null, "x", { part: 1 }, { part: "3001.dat", colour: 4, at: [0, 0] }].map(pinShown),
  shown: pinShown({ part: "3001.dat", colour: 4, at: [0, 0, 0], near: [[1, 2, 3], "x", [1]], extra: "dropped", line: -3 }),
}));
""")
    assert said["places"] == [["3001", 4, [0, 0, 0], "main.ldr", 2], ["3001", 4, [0, -24, 0], "main.ldr", 3],
                              ["3020", 15, [40, 0, 0], "wing.ldr", 1]]
    second = said["second"]
    # Where the file has it, not where the page said.
    assert second["at"] == [0, -24, 0] and second["line"] == 3 and second["section"] == "main.ldr"
    assert second["near"] == [[0, 0, 0]]
    assert said["wing"] == 1
    assert said["wrongColour"] is None and said["nowhere"] is None
    assert said["bad"] == [True] * 8
    assert said["good"] == {"part": "3001.dat", "colour": 4, "at": [1, 2, 3], "turn": None}
    assert said["shownJunk"] == [None] * 4
    shown = said["shown"]
    assert "extra" not in shown and shown["near"] == [[1, 2, 3]] and shown["line"] == 0


def test_a_pin_says_its_part_in_words() -> None:
    said = node("""
import { partSaid, pinSaid } from "./web/card.js";
console.log(JSON.stringify([partSaid("Brick 2 x 4"), partSaid("Plate 1 x 2"), partSaid("Slope Brick 45 2 x 1"),
  partSaid("Technic Beam 3"), partSaid(""), pinSaid("Brick 2 x 4", 12), pinSaid("Brick 2 x 4", null), pinSaid("", 3),
  pinSaid("", null)]));
""")
    assert said == ["2 × 4 brick", "1 × 2 plate", "Slope Brick 45 2 × 1", "Technic Beam 3", "", "on the 2 × 4 brick, step 12",
                    "on the 2 × 4 brick", "on a part, step 3", "on a part"]


def test_a_notification_of_a_pin_says_on_a_part() -> None:
    said = node("""
import { noticeSaid } from "./api/_notifications.js";
const row = { kind: "comment", model: "AAAAAAAAAA", comment: 7, step: 12, by: { handle: "bob", name: "Bob" }, said: "hi" };
console.log(JSON.stringify([noticeSaid({ ...row, pinned: true }).line, noticeSaid({ ...row, pinned: true, step: 0 }).line,
  noticeSaid(row).line, noticeSaid({ ...row, kind: "mention", pinned: true }).line,
  noticeSaid({ ...row, parent: 3, pinned: true }).line]));
""")
    assert said[0] == "{who} commented on a part, step 12"
    assert said[1] == "{who} commented on a part"
    assert said[2] == "{who} commented on step 12"
    assert "on a part" in said[3]
    # A reply is on its comment's part: told as a reply.
    assert "replied" in said[4] and "on a part" not in said[4]


def test_the_sql_only_adds_and_only_the_server_calls_it() -> None:
    body = code(SQL).lower()
    for word in ("drop ", "truncate", "rename", "delete from", "alter column", "grant execute on function public.add_pin(uuid, text, integer, integer, text, jsonb) to anon"):
        assert word not in body, word
    assert re.search(r"add column if not exists pin jsonb,\s*add column if not exists resolved_at timestamptz", body)
    functions = re.findall(r"create or replace function public\.([a-z_]+)\(", body)
    assert set(functions) == {"pin_shaped", "comment_pins_guard", "comment_as", "comments_on", "add_pin", "resolve_pin",
                              "comment_pins_of"}
    for name in functions:
        assert f"revoke all on function public.{name}(" in body, name
        if name != "comment_pins_guard":
            assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", body), name
    # Every function runs as itself, with its own search path.
    assert body.count("security definer") >= 6
    assert body.count("set search_path = public") == len(functions)
    later = (ROOT / "supabase/later.tsv").read_text()
    for row in ("replies.sql\tcomment_as\tcomment_pins.sql", "replies.sql\tcomments_on\tcomment_pins.sql"):
        assert row in later


def test_the_stand_in_answers_what_the_api_asks() -> None:
    api = (ROOT / "api/_comments.js").read_text()
    asked = set(re.findall(r'call\("([a-z_]+)"', api))
    stand_in = (ROOT / "tools/web/pins_stand_in.mjs").read_text()
    names = set(json.loads(re.search(r"const NAMES = (\[[^\]]*\]);", stand_in).group(1).replace("'", '"')))
    assert {"add_pin", "resolve_pin", "comment_pins_of"} <= asked
    assert {"add_pin", "resolve_pin", "comment_pins_of", "comments_on"} == names


def test_the_act_names_are_counted() -> None:
    said = node("""
import { NAMES } from "./api/_insights_names.js";
console.log(JSON.stringify({ site: NAMES.exact.site.act, run: NAMES.exact.studio.run }));
""")
    assert "people.pin" in said["site"] and "people.pin_resolve" in said["site"]
    assert "pin_resolved" in said["run"]
    tally = (ROOT / "web/tally.js").read_text()
    assert 'one("run", "pin_resolved"' in tally
