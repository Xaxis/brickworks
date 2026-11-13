"""The share page's download names (api/share.js fileName and attachment),
as se4check found them: a Japanese title named "model" and an Arabic one
"1", only a to z and 0 to 9 kept, and a Windows device's "_" put on the
title before its tail ("con_-v2.mpd"). The app's own rule is
SubmodelFile.titled; src/dev/subexport_probe.gd holds that one to its
cases. Every header is one Node will send (http.validateHeaderValue)."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def named(titles: list[str], tails: list[str]) -> dict | None:
    """For each title, fileName's name and the header for each tail."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { validateHeaderValue } from 'node:http';"
        "const { fileName, attachment } = await import('./api/share.js');"
        "const out = {};"
        f"for (const t of {json.dumps(titles)}) {{ const name = fileName(t, 'model'); out[t] = {{ name }};"
        f"  for (const tail of {json.dumps(tails)}) {{ const h = attachment(name + tail);"
        "    validateHeaderValue('Content-Disposition', h); out[t][tail] = h; } }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_plain_titles_are_named_as_they_always_were() -> None:
    said = named(["House", "My Castle", "Set 10497-1", "Tom's House", "AC/DC"], [".mpd", "-v2-bricklink.xml"])
    if said is None:
        return
    assert said["House"][".mpd"] == 'attachment; filename="house.mpd"'
    assert said["My Castle"][".mpd"] == 'attachment; filename="my-castle.mpd"'
    assert said["Set 10497-1"]["-v2-bricklink.xml"] == 'attachment; filename="set-10497-1-v2-bricklink.xml"'
    assert said["Tom's House"]["name"] == "toms-house"
    assert said["AC/DC"]["name"] == "ac-dc"


def test_a_title_in_any_script_keeps_its_letters() -> None:
    titles = ["がっこう", "مرحبا؜ 1", "Café", "Café", "城" * 70, "​‌", "COM¹"]
    said = named(titles, [".mpd"])
    if said is None:
        return
    assert said["がっこう"]["name"] == "がっこう"
    # The name as it is in filename*, and ASCII for a browser that reads only filename.
    assert said["がっこう"][".mpd"] == ("attachment; filename=\"model.mpd\"; "
                                     "filename*=UTF-8''%E3%81%8C%E3%81%A3%E3%81%93%E3%81%86.mpd")
    assert said["مرحبا؜ 1"]["name"] == "مرحبا-1"
    # é as one letter, either way it was written; "cafe" where only ASCII is read.
    assert said["Café"]["name"] == said["Café"]["name"] == "café"
    assert said["Café"][".mpd"] == "attachment; filename=\"cafe.mpd\"; filename*=UTF-8''caf%C3%A9.mpd"
    # At most 60 characters, cut between two.
    assert said["城" * 70]["name"] == "城" * 60
    assert said["​‌"]["name"] == "model"
    assert said["COM¹"]["name"] == "com1"


def test_a_windows_device_is_looked_for_in_the_whole_name() -> None:
    said = named(["con", "CON", "nul", "lpt9", "con.txt", "COM¹"], [".mpd", "-v2.mpd", "-bricklink.xml"])
    if said is None:
        return
    assert said["con"][".mpd"] == 'attachment; filename="con_.mpd"'
    # con-v2.mpd and con-bricklink.xml are no device's: the "_" was put on before the tail.
    assert said["con"]["-v2.mpd"] == 'attachment; filename="con-v2.mpd"'
    assert said["CON"]["-bricklink.xml"] == 'attachment; filename="con-bricklink.xml"'
    assert said["nul"][".mpd"] == 'attachment; filename="nul_.mpd"'
    assert said["lpt9"][".mpd"] == 'attachment; filename="lpt9_.mpd"'
    assert said["con.txt"][".mpd"] == 'attachment; filename="con-txt.mpd"'
    assert said["COM¹"][".mpd"] == 'attachment; filename="com1_.mpd"'
