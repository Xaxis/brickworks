"""The weekly quick build (supabase/challenge_prompts.sql, api/_prompts.js).

A prompt is a row of the challenges table of its own kind. The file only
adds: columns, constraints, functions, and the house's four prompts. Each
month function it replaces is the live body with the month picked out
(kind = 'month'), guarded in supabase/later.tsv, so a month's challenge, its
vote and its honours work as before. The stack of a week's entries holds
the sum of their parts, each entry its own sub-model credited to its maker.
"""
import difflib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/challenge_prompts.sql").read_text()
LATER = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
         if line.strip() and not line.startswith("#")]
MINE = [row for row in LATER if row[2] == "challenge_prompts.sql"]


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    inside = text.index("$$", start) + 2
    return text[inside:text.index("\n$$;", inside)]


def node(script: str) -> dict:
    run = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                         timeout=120)
    assert run.returncode == 0, run.stderr
    return json.loads(run.stdout)


def outside_functions(text: str) -> str:
    """[text] with every function's and DO block's body taken out: the
    statements that change the schema."""
    return re.sub(r"\$\$.*?\$\$", "$$ $$", text, flags=re.S)


def test_it_only_adds() -> None:
    plain = outside_functions(code(SQL)).lower()
    for gone in ("drop table", "drop column", "drop function", "delete from", "truncate", "drop index", "rename"):
        assert gone not in plain, gone
    # The one constraint taken out is achievement_marks' list of tracks,
    # put back at once with the streak in it.
    blocks = code(SQL).lower()
    assert blocks.count("drop constraint") == 1 and "'streak'" in blocks[blocks.index("drop constraint"):]
    for column in ("kind text not null default 'month'", "template text references public.shared_models",
                   "stack text references public.shared_models", "seed text"):
        assert f"add column if not exists {column}" in plain, column


def test_every_new_function_is_the_servers_alone() -> None:
    plain = code(SQL)
    # Those it replaces keep the grants they had: create or replace keeps them.
    for name in set(defined(SQL)) - {row[1] for row in MINE}:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name
        start = SQL.index(f"create or replace function public.{name}(")
        head = SQL[start:SQL.index("$$", start)].lower()
        assert re.search(r"set search_path (=|to) '?public'?", head), name
        # achievement_ladders, a list of numbers, runs as its caller, as it always has.
        assert "security definer" in head, name


def picked_out(changed: list[str]) -> bool:
    """Whether [changed] (a diff's lines) only picks the month out, or adds
    the streak: every line it adds, those words taken out, is one it took out."""
    minus = re.sub(r"\s+", "", "".join(line[1:] for line in changed if line[0] == "-"))
    plus = "".join(line[1:] for line in changed if line[0] == "+")
    plus = re.sub(r",\s*\('streak'.*$", "", plus, flags=re.S)
    plain = re.sub(r"\b[a-z]\.kind\s+(=|<>)\s+'month'\s+(and|or)\s+", "", plus)
    wrapped = re.sub(r"\b[a-z]\.kind = 'month' and \((not [a-z]\.test or coalesce\([a-z_.]+, false\))\)", r"\1", plus)
    return minus in (re.sub(r"\s+", "", plain), re.sub(r"\s+", "", wrapped))


def test_each_month_function_replaced_is_the_last_one_with_the_month_picked_out() -> None:
    replaced = {row[1] for row in MINE}
    others = {name for path in (ROOT / "supabase").glob("*.sql") if path.name != "challenge_prompts.sql"
              for name in defined(path.read_text())}
    assert set(defined(SQL)) & others == replaced
    assert all(name.startswith("prompt_") for name in set(defined(SQL)) - replaced)
    for name in replaced:
        ours = body(name, SQL)
        guards = [row for row in MINE if row[1] == name]
        assert all(row[3] in ours for row in guards), name
        # Against the file that defined it last (the closest of those
        # guarded): two or three lines, each picking the month out or
        # counting the streak, and nothing else changed.
        diffs = []
        for row in guards:
            theirs = body(name, (ROOT / "supabase" / row[0]).read_text())
            assert row[3] not in theirs, (name, row[0])
            changed = [line for line in difflib.unified_diff(theirs.strip().splitlines(), ours.strip().splitlines(),
                                                             lineterm="", n=0)
                       if line[:1] in "+-" and not line.startswith(("+++", "---"))]
            diffs.append(changed)
        closest = min(diffs, key=len)
        assert len(closest) <= 4, (name, closest)
        assert picked_out(closest), (name, closest)


def test_a_prompt_is_never_voted_on_listed_with_the_months_or_settled() -> None:
    assert "c.kind <> 'month'" in body("challenge_vote", SQL)
    for name in ("challenge_open", "challenge_shown", "challenge_next", "challenge_past", "challenge_settle_due",
                 "challenge_list", "challenge_set", "challenge_plan"):
        assert "c.kind = 'month'" in body(name, SQL), name
    assert "c.kind = 'month'" in body("achievement_numbers", SQL)
    # A week, two at most, ending after it starts.
    assert "kind = 'prompt' and ends_on <= starts_on + 13" in SQL


def test_the_house_wrote_four_prompts_a_week_apart() -> None:
    insert = SQL[SQL.index("insert into public.challenges (kind, title, brief, starts_on, ends_on, seed)"):]
    rows = re.findall(r"\('([a-z-]+)', '((?:[^']|'')+)',\s*'((?:[^']|'')+)'\s*(?:\|\|\s*'((?:[^']|'')+)')?,\s*date '(\d{4}-\d{2}-\d{2})'\)",
                      insert)
    assert [row[0] for row in rows] == ["habitat", "snowed-in", "workshop", "gift-box"]
    assert [row[4] for row in rows] == ["2026-11-23", "2026-11-30", "2026-12-07", "2026-12-14"]
    assert "x.starts_on + 6" in insert
    for seed, title, *brief, _ in rows:
        said = "".join(brief)
        assert "8×8 plate" in said and "10" in said, seed
    # Each only once, and never over one set already.
    assert "where not exists" in insert.lower()
    out = node("""
      import { HOUSE } from "./api/_prompts.js";
      console.log(JSON.stringify(Object.fromEntries(Object.entries(HOUSE).map(([seed, one]) => [seed, one.entries.length]))));
    """)
    assert out == {"habitat": 2, "snowed-in": 2, "workshop": 2, "gift-box": 2}


def test_the_stack_holds_every_part_of_every_entry_each_its_own_sub_model() -> None:
    out = node("""
      import { inventoryOf, partsTable } from "./api/_parts.js";
      import { HOUSE, houseEntry, sectionsOf, stackText } from "./api/_prompts.js";
      const table = partsTable();
      const entries = [];
      for (const seed of Object.keys(HOUSE)) {
        for (let k = 0; k < HOUSE[seed].entries.length; k += 1) {
          const one = houseEntry(seed, k);
          entries.push({ model: `Entry${seed.slice(0, 3)}${k}`.padEnd(10, "x").slice(0, 10), name: one.name,
            author: "Brickworks", handle: "brickworks", text: one.text, low: -40, high: 0 });
        }
      }
      // A file as people store one: several files, a sub-model used twice,
      // one with a space in its name, and a part the catalogue lacks.
      entries.push({ model: "Somebody01", name: "Two towers", author: "Sam", handle: "sam", low: -60, high: 0, text: [
        "0 FILE towers.ldr", "0 Two towers", "0 Name: towers.ldr", "0 Author: Sam",
        "1 4 -20 -8 0 1 0 0 0 1 0 0 0 1 tower one.ldr", "1 14 20 -8 0 1 0 0 0 1 0 0 0 1 Tower One.ldr",
        "1 15 0 0 0 1 0 0 0 1 0 0 0 1 3020.dat", "0 NOFILE",
        "0 FILE tower one.ldr", "0 Tower", "1 16 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat",
        "1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3005.dat", "1 16 0 -48 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat", "0 NOFILE", ""].join("\\n") });
      const pieces = (text) => inventoryOf(text, table).pieces;
      const stack = stackText({ title: "Habitat", starts_on: "2026-11-23", ends_on: "2026-11-29" }, entries);
      const files = sectionsOf(stack.text).map((one) => one.name);
      console.log(JSON.stringify({
        each: entries.map((one) => pieces(one.text)),
        stacked: pieces(stack.text),
        files,
        refs: stack.text.split("\\n").filter((line) => /^1 .*tower one\\.ldr$/i.test(line)),
        credits: entries.map((one) => stack.text.includes(`0 Author: ${one.author} (@${one.handle})`)
          && stack.text.includes(`/m/${one.model}`)),
        dys: stack.placed.map((one) => one.dy),
      }));
    """)
    # Counted as a card counts them: the part nobody knows is left out, the
    # tower used twice counted twice.
    assert out["stacked"] == sum(out["each"]) and out["each"][-1] == 5
    # The stack's own file, then each entry's; the sub-models renamed apart.
    assert len(out["files"]) == 1 + 8 + 2 and len(set(name.lower() for name in out["files"])) == len(out["files"])
    assert out["files"][-2:] == ["e09-two-towers.ldr", "e09-tower one.ldr"]
    assert len(out["refs"]) == 2 and all(line.endswith("e09-tower one.ldr") for line in out["refs"])
    assert all(out["credits"])
    # Each foot on the studs of the one below: 40 LDU up and 4 back.
    assert out["dys"][:3] == [0, -36, -72]


def test_a_quick_builds_notice_and_page_start_the_studio_on_its_template() -> None:
    out = node("""
      import { noticeSaid, noticeGroups } from "./api/_notifications.js";
      import { promptShown } from "./api/_prompts.js";
      const prompt = { title: "Habitat", template: "Template01", test: false };
      const row = { kind: "challenge_open", at: "2026-11-23T08:00:00Z", challenge: 7, title: "Habitat",
        ends_on: "2026-11-29", read: false, prompt };
      const month = { ...row, challenge: 8, title: "Castles", prompt: undefined };
      const groups = noticeGroups({ rows: [row, month], models: {}, seen_at: null, read_at: null, reads: {} }, "https://x");
      const page = promptShown("https://x", { id: 7, title: "Habitat", brief: "A home.", starts_on: "2026-11-23",
        ends_on: "2026-11-29", state: "open", template: { id: "Template01", name: "Habitat: the template" },
        entries: [{ model: "EntryNew01", card: { id: "EntryNew01", name: "New" }, way: "hand", at: "2026-11-24T10:00:00Z" },
          { model: "EntryOld01", card: { id: "EntryOld01", name: "Old" }, way: "assistant", at: "2026-11-23T10:00:00Z" }],
        makers: 2 });
      console.log(JSON.stringify({ said: noticeSaid(row, "https://x"), groups: groups.groups.map((one) => [one.name, one.start || null]),
        start: page.start, entries: page.entries.map((one) => one.id), kind: page.kind }));
    """)
    assert "quick build" in out["said"]["line"] and "Habitat" in out["said"]["line"]
    assert ["Quick build: Habitat", "https://x/app?copy=Template01"] in out["groups"]
    assert any(name.startswith("Challenge: ") and start is None for name, start in out["groups"])
    assert out["start"] == "/app?copy=Template01" and out["kind"] == "prompt"
    assert out["entries"] == ["EntryNew01", "EntryOld01"]


def test_a_models_picture_drawn_on_the_server_is_a_png() -> None:
    out = node("""
      import { drawModel, pngOf } from "./api/_flatlay.js";
      const png = pngOf(drawModel([], new Map(), { width: 64, height: 48 }));
      console.log(JSON.stringify({ head: [...png.subarray(0, 8)], ihdr: png.subarray(12, 16).toString(),
        width: png.readUInt32BE(16), height: png.readUInt32BE(20), end: png.subarray(-8, -4).toString() }));
    """)
    assert out["head"] == [137, 80, 78, 71, 13, 10, 26, 10] and out["ihdr"] == "IHDR"
    assert (out["width"], out["height"]) == (64, 48) and out["end"] == "IEND"
