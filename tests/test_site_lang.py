"""The landing page and the download page in German, French and Spanish.

tools/site_lang.py writes each language's copy (web/de/, web/fr/, web/es/)
from the English page and web/_lang/<code>.json; this fails when a copy is
not what it writes, or when an English run of the page has no words in a
language, so nothing reaches the site half in English. And each copy says
the LEGO Group's notice and the mark as the English does, in its language.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import site_lang  # noqa: E402

# The LEGO Group, as each language names the company (never with ®).
COMPANY = {"de": r"LEGO (?:Unternehmens)?[Gg]ruppe", "fr": r"(?:[Gg]roupe|sociétés) LEGO",
           "es": r"(?:[Gg]rupo|empresas) LEGO"}


def test_every_copy_is_written_and_has_all_its_words() -> None:
    said = subprocess.run([sys.executable, str(ROOT / "tools/site_lang.py"), "--check"], capture_output=True, text=True)
    assert said.returncode == 0, said.stdout + said.stderr


def test_a_run_with_no_words_stops_the_copy() -> None:
    # The check above means something: a page's run missing from a table is
    # caught, and so is an entry that lost the English's link.
    words = site_lang.table("de")
    del words["pages"]["Download for desktop"]
    _, missing, _ = site_lang.translated("index.html", "de", words)
    assert missing == ["Download for desktop"]
    words = site_lang.table("de")
    key = next(k for k in words["pages"] if '<a href="/plans#had">' in k)
    words["pages"][key] = re.sub(r"<[^>]+>", "", words["pages"][key])
    _, _, broken = site_lang.translated("index.html", "de", words)
    assert broken == [key]


def test_each_copy_has_the_english_page_s_markup() -> None:
    # Only the words change: every tag in its place, so a copy never shows
    # a fragment of what it was made from (a link inside a sentence once
    # left ".app</a>" behind it).
    def shape(text: str) -> list[tuple[str, str]]:
        return [(kind, tag) for kind, _, tag, _ in site_lang.Tokens(text).found if kind in ("start", "end", "empty")]
    for code in site_lang.LANGUAGES:
        for name, where in site_lang.PAGES.items():
            copy = (ROOT / "web" / code / (f"{where}.html" if where else "index.html")).read_text(encoding="utf-8")
            copy = re.sub(r'<script type="application/json" id="site-words">.*?</script>\n', "", copy, flags=re.S)
            assert shape(copy) == shape((ROOT / "web" / name).read_text(encoding="utf-8")), (code, name)


def test_the_runs_are_the_words_a_reader_meets() -> None:
    page = site_lang.Page('<p>Open the <a href="/app">app</a> now.</p><ul><li>One</li><li><b>Two</b> words</li></ul>'
                          '<pre><code>chmod +x</code></pre><img alt="A castle"><p translate="no">Brickworks</p>')
    assert page.keys() == ['Open the <a href="/app">app</a> now.', "One", "<b>Two</b> words", "A castle"]


def test_each_copy_points_to_its_own_pages_and_carries_its_language_into_the_app() -> None:
    for code in site_lang.LANGUAGES:
        for name, where in site_lang.PAGES.items():
            text = (ROOT / "web" / code / (f"{where}.html" if where else "index.html")).read_text(encoding="utf-8")
            assert f'<html lang="{code}">' in text
            own = f"https://brickworks.diy/{code}" + (f"/{where}" if where else "")
            assert f'<link rel="canonical" href="{own}">' in text and f'<meta property="og:url" content="{own}">' in text
            links = re.findall(r'<a [^>]*href="([^"]*)"', text)
            assert not [one for one in links if one.split("#")[0] in ("/", "/download", "/app")], (code, name)
            assert f"/app?lang={code}" in links and f"/{code}/download" in links


def test_each_english_page_names_its_copies() -> None:
    # web/theme.js finds a copy by its <link rel="alternate" hreflang>.
    for name, where in site_lang.PAGES.items():
        text = (ROOT / "web" / name).read_text(encoding="utf-8")
        for code in site_lang.LANGUAGES:
            own = f"https://brickworks.diy/{code}" + (f"/{where}" if where else "")
            assert f'<link rel="alternate" hreflang="{code}" href="{own}">' in text, (name, code)
        assert 'hreflang="x-default"' in text


def test_the_mark_and_the_notice_in_each_language() -> None:
    for code in site_lang.LANGUAGES:
        words = json.loads((ROOT / "web/_lang" / f"{code}.json").read_text(encoding="utf-8"))
        notice = next(v for k, v in words["pages"].items() if k.startswith("LEGO® is a trademark of the LEGO Group"))
        assert notice.startswith("LEGO® ") and re.search(COMPANY[code], notice), notice
        for name, where in site_lang.PAGES.items():
            text = (ROOT / "web" / code / (f"{where}.html" if where else "index.html")).read_text(encoding="utf-8")
            footer = re.search(r"<footer.*?</footer>", text, re.S).group(0)
            assert notice in footer, (code, name)
        for value in [*words["pages"].values(), *words["scripts"].values()]:
            rest = re.sub(COMPANY[code], "", value)
            assert not re.search(r"LEGO(?!®)", rest), f"{code}: LEGO carries its ® but in the company's name: {value}"
            assert not re.search(r"LEGO® ?(?:Gruppe|Group)|(?:Groupe|Grupo) LEGO®", value), f"{code}: ® in the company: {value}"
            assert not re.search(r"\b(?:Legos?|LEGOs)\b", value), f"{code}: {value}"
