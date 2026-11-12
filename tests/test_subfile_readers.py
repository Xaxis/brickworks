"""Every reader of a file's sub-files takes the open's rule (openfaults;
ofcheck, 2026-11-12): the server's (api/_versions.js partsOf, api/_parts.js
inventoryOf, api/models.js partsIn, api/share.js checkModel) and the Python
tools' (tools/omr.py, by tools/ldraw/subfiles.py).

- A block that says it is a library file (a shortcut) under a number the
  library has is that part: 10251-1's door 60797c02 was a sub-model of its
  two pieces, and left the parts list, the shop lists and the price. One of
  a name the library has not ("10265 - 42716c01.dat") is a sub-model.
- The model's own block is in no table, as LDView reads a file: a later
  block of the main file's name is the one its references mean. The server
  counted 1 part of 3 and share refused it as placing itself in itself.
- A line is split on any of LDraw's space: partsIn counted 2 of a tabbed
  file's 4. A byte order mark is no part of the first line.

src/dev/openfaults_probe.gd holds the app to the same files."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import omr  # noqa: E402
from ldraw import subfiles  # noqa: E402

FX = ROOT / "src/dev/fixtures"


def server(fixture: str) -> dict | None:
    """[fixture] read by each of the server's readers, with the parts table
    where it takes one, or None where there is no node or no table."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { readFileSync } from 'node:fs';"
        "const { partsOf } = await import('./api/_versions.js');"
        "const { inventoryOf, partsTable } = await import('./api/_parts.js');"
        "const { partsIn } = await import('./api/models.js');"
        "const { checkModel } = await import('./api/share.js');"
        "const table = partsTable();"
        "if (!table) { console.log('null'); process.exit(0); }"
        "const known = (id) => Object.prototype.hasOwnProperty.call(table.parts, id);"
        f"const text = readFileSync({json.dumps(str(FX / fixture))}, 'utf8');"
        "const inv = inventoryOf(text);"
        "const said = (f) => { try { return f(); } catch (e) { return `refused: ${e.message}`; } };"
        "console.log(JSON.stringify({"
        "  bare: partsOf(text).map((p) => p.part).sort(),"
        "  known: partsOf(text, known).map((p) => p.part).sort(),"
        "  pieces: inv.pieces, lots: inv.lots.map((l) => `${l.part}/${l.colour} x${l.count}`).sort(),"
        "  stored: partsIn(text), marked: partsIn(`\\uFEFF${text}`), shared: said(() => checkModel(text).parts) }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=180, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def python_parts(text: str) -> list[str]:
    return sorted(part for part, _colour, _at, _within in omr._flatten(text))


def test_a_shortcut_named_as_a_library_part_is_that_part() -> None:
    said = server("of_shortcut.mpd")
    if said is None:
        return
    # The door is one part of the list, the shop lists and the price; the
    # prefixed shortcut the library has no number of is its two parts.
    assert said["lots"] == ["15413/256 x1", "3001/4 x1", "42716/72 x1", "60797c02/0 x1"]
    assert said["pieces"] == 4
    assert said["known"] == ["15413", "3001", "42716", "60797c02"]
    # With no library to ask, the block is what it says: its pieces.
    assert said["bare"] == ["15413", "3001", "42716", "u9086", "u9087"]


def test_a_sub_model_named_as_the_main_file_is_the_one_its_references_mean() -> None:
    said = server("of_mainname.mpd")
    if said is None:
        return
    assert said["known"] == ["3001", "3003", "3004"]
    assert said["pieces"] == 3
    assert said["stored"] == 3
    assert said["shared"] == 3
    assert python_parts((FX / "of_mainname.mpd").read_text()) == ["3001.dat", "3003.dat", "3004.dat"]


def test_a_line_is_split_on_any_space() -> None:
    said = server("of_crlf.mpd")
    if said is None:
        return
    assert said["known"] == ["3001", "3003", "3010", "3024"]
    assert said["pieces"] == 4
    assert said["stored"] == 4
    # A byte order mark before the first line is none of it: partsIn read
    # 4558-1 as 85 parts of the 856 the app has.
    assert said["marked"] == 4
    assert said["shared"] == 4
    assert python_parts((FX / "of_crlf.mpd").read_bytes().decode()) == ["3001.dat", "3003.dat", "3010.dat",
                                                                         "3024.dat"]


def test_the_python_readers_follow_a_sub_file_by_its_whole_name() -> None:
    # Keyed by a bare name with "\" left in, omr.py never followed a part's
    # "s\..." sub-file, and counted 112-2 as 80 parts of LDView's 240.
    # Of two blocks of a name the first is the one (LDView's "already
    # loaded"), whichever way its slash leans.
    text = "\n".join([
        "0 FILE main.ldr", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 S/wing.ldr", "1 2 0 0 0 1 0 0 0 1 0 0 0 1 Wing.ldr",
        "0 FILE s\\Wing.LDR", "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
        "0 FILE wing.ldr", "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat",
        "0 FILE s/wing.ldr", "1 1 0 0 0 1 0 0 0 1 0 0 0 1 3005.dat",
    ])
    assert python_parts(text) == ["3001.dat", "3003.dat", "3004.dat"]
    blocks = subfiles.blocks(text)
    assert list(blocks) == [subfiles.MAIN, "s/wing.ldr", "wing.ldr"]
    assert blocks["s/wing.ldr"][0] == "s\\Wing.LDR"
