"""The site's pages in German, French and Spanish: home, download, plans,
FAQ, compare, the gallery and the LDraw library (tools/site_lang.py PAGES).

tools/site_lang.py writes each language's copy (web/de/, web/fr/, web/es/)
from the English page and web/_lang/<code>.json; this fails when a copy is
not what it writes, or when an English run of the page has no words in a
language, so nothing reaches the site half in English. And each copy says
the LEGO Group's notice and the mark as the English does, in its language.

The sign-in's dialogs (web/account.js) say every word through say(), from
the copy's words or /<code>/words.json on a page with none, and so do
First steps after it (web/first-steps.js) and a set's page, written on the
server (api/_sets.js); every theme of the catalogue has an entry in
locale/<code>.po, which the app's Library and the site's library both draw:
this fails on an English word come back to one of them, and on a theme
with no entry.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import pytest  # noqa: E402

import site_lang  # noqa: E402
from library_build import tidy, with_marks  # noqa: E402

CATALOGUE = ROOT / "assets" / "generated" / "set_catalog.json"

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
            english = {"/" + page for page in site_lang.PAGES.values()}
            assert not [one for one in links if re.split(r"[?#]", one)[0] in english], (code, name)
            assert not [one for one in links if re.split(r"[?#]", one)[0] == "/app" and f"lang={code}" not in one]
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


def test_what_the_scripts_say_has_its_words() -> None:
    # Every say("...") of a script a copy loads, joined where it is written
    # over lines, each counted() noun with its plural, and the labels the API
    # hands the gallery and the library (an id is not one).
    words = site_lang.script_words()
    assert words["Tell Brickworks what you own (in the app, Build › My collection…) and this shows what in the "
                 "gallery you can build with it."] == "web/gallery.js"
    assert {"set", "sets", "build finished", "builds finished", "Show more", "Page {n}"} <= set(words)
    assert {"Castles and fantasy", "Small, under 200 parts", "Built in 3D first", "Most liked"} <= set(words)
    assert "castle" not in words and "small" not in words
    for code in site_lang.LANGUAGES:
        has = site_lang.table(code)["scripts"]
        assert not [word for word in words if word not in has], code


def test_the_faq_search_shows_is_in_the_language_too() -> None:
    # The FAQ's questions and answers as search results show them (its
    # JSON-LD, shorter than the page's): one with no words stops the copy,
    # and each copy's are its own.
    ld = r'<script type="application/ld\+json">(.*?)</script>'
    english = json.loads(re.search(ld, (ROOT / "web/faq.html").read_text(encoding="utf-8"), re.S).group(1))
    answer = english["mainEntity"][0]["acceptedAnswer"]["text"]
    words = site_lang.table("de")
    del words["pages"][site_lang.key_of(answer)]
    _, missing, _ = site_lang.translated("faq.html", "de", words)
    assert missing == [site_lang.key_of(answer)]
    for code in site_lang.LANGUAGES:
        copy = json.loads(re.search(ld, (ROOT / "web" / code / "faq.html").read_text(encoding="utf-8"), re.S).group(1))
        pairs = list(zip(english["mainEntity"], copy["mainEntity"]))
        assert len(pairs) == 17 and all(one["name"] != other["name"] and one["acceptedAnswer"]["text"]
                                        != other["acceptedAnswer"]["text"] for one, other in pairs), code


def test_the_sign_in_says_its_words_and_the_server_s() -> None:
    # The dialogs' words, what the account API answers a visitor (a code
    # asked for too often, a wrong one), orangecheck's own copy, and why a
    # page asks to sign in all reach the tables.
    words = site_lang.script_words()
    assert {"Sign in to Brickworks", "Email me a code", "The code sent to {address}",
            "That code is wrong or has expired. Check it, or ask for a new one.", "One question first", "Carry on",
            "Signing in…"} <= set(words)
    assert words["Too many codes asked for. Wait a few minutes and try again."] == "api/otp.js"
    assert "Sign in to like it: we email you a code, no password." in words
    for code in site_lang.LANGUAGES:
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        assert said == site_lang.script_table(code, site_lang.table(code)), code
        assert said["Sign in to Brickworks"] != "Sign in to Brickworks", code
        # A theme by its context: Space the kind of model is a word, Space
        # the theme a name (web/card.js themeSaid).
        assert said["theme\x04Collectible Minifigures"] == site_lang.theme_entries(code)["Collectible Minifigures"], code
        assert said["Space"] != "Space" and "theme\x04Space" not in said, code


def test_an_english_word_back_in_the_dialog_is_caught() -> None:
    text = (ROOT / "web/account.js").read_text(encoding="utf-8")
    assert site_lang.unsaid(text) == []
    planted = text.replace('say("Not now")', '"Not now"', 1)
    assert planted != text and site_lang.unsaid(planted) == ['"Not now"']
    assert site_lang.unsaid('label.title = `Signed in as ${who}`; // A Comment\n') == ["`Signed in as ${who}`"]


def test_first_steps_and_a_set_s_page_say_their_words() -> None:
    # First steps after the sign-in (web/first-steps.js) and the Follow
    # buttons in it (web/follow.js), what the profile API refuses a handle
    # with, and a set's page as the server writes it (api/_sets.js) and the
    # scripts on it: each word in each language.
    words = site_lang.script_words()
    assert {"Make your profile", "What do you build?", "Designers and models to start with", "See your feed"} <= set(words)
    assert words["Following"] == words["You follow them: press to stop"] == "web/follow.js"
    assert words["somebody already has that handle: choose another"] == "api/people.js"
    assert words["that handle is kept for Brickworks itself: choose another"] == "api/_names.js"
    assert {"Build it in 3D", "{name}, LEGO® set {set}: every part — Brickworks", "Parts you own",
            "Parts you own: {have} of {pieces}. You are missing {missing} in {lots}.", "element {element}"} <= set(words)
    for code in site_lang.LANGUAGES:
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        for english in ("Make your profile", "somebody already has that handle: choose another", "Build it in 3D"):
            assert said[english] != english, f"{code}: {english}"


def test_an_english_word_back_in_first_steps_or_a_set_s_page_is_caught() -> None:
    for path, names, english in (("web/first-steps.js", (), "Make my profile"),
                                 ("api/_sets.js", ("setPage",), "Build it in 3D"),
                                 ("web/model-page.js", ("startParts",), "Other")):
        text = (ROOT / path).read_text(encoding="utf-8")
        assert site_lang.unsaid(site_lang.scope(path, names)) == [], path
        planted = text.replace(f'say("{english}")', f'"{english}"', 1)
        assert planted != text and site_lang.unsaid(site_lang.scope(path, names, planted)) == [f'"{english}"'], path


def test_the_server_s_languages_are_the_site_s() -> None:
    # api/_directory.js SITE_LANGS writes a set's page in each, and
    # web/theme.js leads a reader to a copy in each.
    directory = (ROOT / "api/_directory.js").read_text(encoding="utf-8")
    assert json.loads(re.search(r"SITE_LANGS = (\[.*?\]);", directory).group(1)) == list(site_lang.LANGUAGES)


@pytest.mark.skipif(not CATALOGUE.exists(), reason="no assets/generated/set_catalog.json (tools/set_catalog.py)")
def test_every_theme_of_the_catalogue_has_its_entry() -> None:
    # As the app draws it (LEGO® and LEGOLAND® marked): a word in the
    # language, a product line's or a licence's name as it is. A theme
    # Rebrickable adds is a gap until it has one.
    names = {with_marks(tidy(str(row[0]))) for row in json.loads(CATALOGUE.read_text(encoding="utf-8"))["themes"].values()}
    for code in site_lang.LANGUAGES:
        entries = site_lang.theme_entries(code)
        missing = sorted(names - set(entries))
        assert not missing, f"{code}: {len(missing)} themes with no entry in locale/{code}.po, first {missing[:3]}"
        assert entries["Collectible Minifigures"] != "Collectible Minifigures" and entries["Technic"] == "Technic", code
        assert "Technic" not in site_lang.themes(code) and site_lang.themes(code)["LEGO® Brand Store"] != "LEGO® Brand Store", code
