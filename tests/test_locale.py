"""The interface's languages, locale/<code>.po (src/ui/language.gd).

Each language is read by the app as Godot reads a .po: an entry's msgid is the
English the app draws, its msgstr how it reads in that language, and an msgid
with %s or %d in it a pattern whose places the msgstr fills in turn ("%2$s"
naming one). So every msgstr says something, keeps its msgid's places, no
language lacks an entry another has, and LEGO® is written in each as the Fair
Play policy asks of the English (docs/TRADEMARKS.md): an adjective that keeps
its ®, and no ® in the company's own name, which each language words its own
way (die LEGO Gruppe, le Groupe LEGO, el Grupo LEGO).

What the running app draws through them, and that nothing it shows is left
out, is languages_probe's.
"""
from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ["de", "fr", "es"]
PLACES = re.compile(r"%(?:(\d+)\$)?[sd]")
# The company's name in each, which carries no ®.
GROUP = {"de": "LEGO Gruppe", "fr": "Groupe LEGO", "es": "Grupo LEGO"}


def entries(code: str) -> list[tuple[str, str]]:
    """[msgid, msgstr] for each entry of locale/<code>.po, the header left out."""
    out: list[tuple[str, str]] = []
    field = ""
    got: dict[str, str] = {}

    def unquote(text: str) -> str:
        return (text[1:-1].replace('\\"', '"').replace("\\n", "\n").replace("\\t", "\t")
                .replace("\\\\", "\\"))

    for line in (ROOT / "locale" / f"{code}.po").read_text(encoding="utf-8").splitlines() + [""]:
        line = line.strip()
        if line.startswith("msgid "):
            if "msgstr" in got and got.get("msgid"):
                out.append((got["msgid"], got["msgstr"]))
            got = {"msgid": unquote(line[6:])}
            field = "msgid"
        elif line.startswith("msgstr "):
            got["msgstr"] = unquote(line[7:])
            field = "msgstr"
        elif line.startswith('"') and field:
            got[field] += unquote(line)
        elif not line or line.startswith("#"):
            field = "" if not line else field
    if "msgstr" in got and got.get("msgid"):
        out.append((got["msgid"], got["msgstr"]))
    return out


@pytest.mark.parametrize("code", LANGUAGES)
def test_every_entry_is_translated_once(code: str) -> None:
    found = entries(code)
    assert len(found) > 500, f"{code}: {len(found)} entries"
    empty = [english for english, said in found if not said.strip()]
    assert not empty, f"{code}: no translation for {empty[:5]}"
    ids = [english for english, _ in found]
    twice = sorted({english for english in ids if ids.count(english) > 1})
    assert not twice, f"{code}: twice: {twice[:5]}"


def test_no_language_lacks_what_another_has() -> None:
    ids = {code: {english for english, _ in entries(code)} for code in LANGUAGES}
    for code in LANGUAGES:
        for other in LANGUAGES:
            lacking = sorted(ids[other] - ids[code])
            assert not lacking, f"{code} lacks {other}'s {lacking[:5]}"


@pytest.mark.parametrize("code", LANGUAGES)
def test_a_pattern_keeps_its_places(code: str) -> None:
    for english, said in entries(code):
        wanted = PLACES.findall(english)
        given = PLACES.findall(said)
        assert len(given) == len(wanted), f"{code}: {english!r} -> {said!r}"
        named = [int(n) for n in given if n]
        assert all(1 <= n <= len(wanted) for n in named), f"{code}: {said!r}"
        # Each place taken as a number where the English takes a number.
        if not named:
            kinds = [m.group().endswith("d") for m in PLACES.finditer(english)]
            took = [m.group().endswith("d") for m in PLACES.finditer(said)]
            assert kinds == took, f"{code}: {english!r} -> {said!r}"


@pytest.mark.parametrize("code", LANGUAGES)
def test_lego_is_an_adjective_with_its_mark(code: str) -> None:
    for english, said in entries(code):
        if "LEGO®" in english:
            assert "LEGO®" in said, f"{code}: {said!r} lost the ® of {english!r}"
        if "the LEGO Group" in english:
            assert GROUP[code] in said, f"{code}: {said!r} does not name {GROUP[code]}"
        bare = said.replace(GROUP[code], "")
        assert not re.search(r"\bLEGO\b(?!®)", bare), f"{code}: LEGO without ® in {said!r}"
        assert not re.search(r"LEGO® (?:Gruppe|Group)|(?:Groupe|Grupo) LEGO®", said), \
            f"{code}: a ® in the company's name in {said!r}"
        assert not re.search(r"\bLegos?\b|\bLEGOs\b", said), f"{code}: {said!r}"
