"""A page's description, as a search result or a shared link shows it
(meta description, og:description): its words on one line, cut after a
whole word with "…" where they are longer than it holds, never mid-word
("The collec", a profile's bio cut to 160 until 2026-11-01). Each page
the server makes cuts through api/_directory.js summary.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def summary(text: str, most: int | None = None) -> str | None:
    if shutil.which("node") is None:
        return None
    asked = json.dumps(text) + ("" if most is None else f", {most}")
    done = subprocess.run(["node", "--input-type=module", "-e",
                           "const { summary } = await import('./api/_directory.js');"
                           f"console.log(JSON.stringify(summary({asked})));"],
                          cwd=ROOT, capture_output=True, text=True, timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


BIO = ("The Brickworks studio's own account. Its own models were designed with the assistant, Claude\n"
       "working in the app, and each one's description says how. The collection From the LDraw library holds real "
       "sets as LDraw's builders modelled them, each credited to them. Open one to build it step by step.")


def test_a_long_text_is_cut_after_a_whole_word() -> None:
    said = summary(BIO)
    if said is None:
        return
    assert len(said) <= 160, said
    assert said.endswith("…"), said
    kept = said[:-1]
    flat = re.sub(r"\s+", " ", BIO)
    assert flat.startswith(kept), said
    assert flat[len(kept)] == " " or not flat[len(kept) - 1].isalnum(), f"cut mid-word: {said!r}"
    assert not re.search(r"[\s,;:]$", kept), f"a comma or space before the …: {said!r}"


def test_a_short_text_is_its_words_on_one_line() -> None:
    said = summary("  A castle,\n  with a drawbridge. ")
    if said is None:
        return
    assert said == "A castle, with a drawbridge."


def test_a_word_longer_than_it_holds_is_cut_where_it_must() -> None:
    said = summary("x" * 300, 50)
    if said is None:
        return
    assert len(said) == 50 and said.endswith("…")


def test_every_page_the_server_makes_cuts_its_description_through_summary() -> None:
    cut = re.compile(r"(?<!\w)(?:about|description)\b[^\n]*\.slice\(0, \d+\)")
    found = [f"{path.name}:{n}" for path in sorted((ROOT / "api").glob("*.js"))
             for n, line in enumerate(path.read_text().splitlines(), 1) if cut.search(line)]
    assert not found, f"a description cut by length, not summary: {found}"
