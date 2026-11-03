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
    _, _, broken = site_lang.translated("beta.html", "de", words)
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
            # A rule page's copy adds one line: that the English binds.
            copy = re.sub(r'\n\t*<p class="binding">.*?</p>', "", copy, count=name in site_lang.BINDING)
            assert shape(copy) == shape((ROOT / "web" / name).read_text(encoding="utf-8")), (code, name)


def test_the_runs_are_the_words_a_reader_meets() -> None:
    page = site_lang.Page('<p>Open the <a href="/app">app</a> now.</p><ul><li>One</li><li><b>Two</b> words</li></ul>'
                          '<pre><code>chmod +x</code></pre><img alt="A castle"><p translate="no">Brickworks</p>')
    assert page.keys() == ['Open the <a href="/app">app</a> now.', "One", "<b>Two</b> words", "A castle"]


def test_each_copy_points_to_its_own_pages_and_carries_its_language_into_the_app() -> None:
    for code in site_lang.LANGUAGES:
        for name, where in site_lang.PAGES.items():
            text = (ROOT / "web" / code / (f"{where}.html" if where else "index.html")).read_text(encoding="utf-8")
            # A tab of the gallery's (tools/browse_pages.py) says which it opens on.
            assert re.search(f'<html lang="{code}"(?: data-tab="[a-z]+")?(?: data-missing)?>', text)
            own = f"https://brickworks.diy/{code}" + (f"/{where}" if where else "")
            if name not in site_lang.UNLISTED:
                assert f'<link rel="canonical" href="{own}">' in text and f'<meta property="og:url" content="{own}">' in text
            links = re.findall(r'<a [^>]*href="([^"]*)"', text)
            english = {"/" + page for page in site_lang.PAGES.values()}
            # Only the binding line's link to the English text, which asks for it.
            assert not [one for one in links if re.split(r"[?#]", one)[0] in english and "lang=en" not in one], (code, name)
            assert not [one for one in links if re.split(r"[?#]", one)[0] == "/app" and f"lang={code}" not in one]
            if name != "authorize.html":  # the consent page leads only back to the app that asked
                assert f"/app?lang={code}" in links and f"/{code}/download" in links


def test_each_english_page_names_its_copies() -> None:
    # web/theme.js finds a copy by its <link rel="alternate" hreflang>.
    for name, where in site_lang.PAGES.items():
        text = (ROOT / "web" / name).read_text(encoding="utf-8")
        if name == "404.html":
            # It has no address of its own: its copy is the one at the
            # address asked for, in the language (data-missing).
            assert "<html lang=\"en\" data-missing>" in text
            continue
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
            # The consent page's footer has the notice's first sentence alone.
            said = notice.split(". ")[0] + "." if name == "authorize.html" else notice
            assert said.replace('href="/terms', f'href="/{code}/terms') in footer, (code, name)
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
                 "gallery you can build with it."] == "web/models.js"
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
        assert len(pairs) == 18 and all(one["name"] != other["name"] and one["acceptedAnswer"]["text"]
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


def test_the_viewer_the_server_s_words_and_the_tested_why_are_said() -> None:
    # languages5: the 3D view's own words (tools/viewer/inline.js), what the
    # API a model's page, a profile and a library set call answers in words,
    # a challenge's rules and what a model breaks of them (web/card.js), and
    # the app's reasons a model is not Tested (web/model-page.js whySaid):
    # each has its entry in each language.
    words = site_lang.script_words()
    for english, where in (("The 3D view could not load: {why}. The picture is still here.", "tools/viewer/inline.js"),
                           ("Comments are off on this model.", "api/_comments.js"),
                           ("Three of your models are in this challenge already: that is the most.", "api/_challenges.js"),
                           ("The LDraw library has no such set.", "api/share.js"),
                           ("At most {parts}", "web/card.js"),
                           ("{n} of its parts are not in {set}, or not as many: {lots}.", "web/card.js"),
                           ("Step {n}: {part} is put down in the air", "web/model-page.js"),
                           ("Edit profile", "web/settings.js"),
                           ("first challenge", "web/card.js"),
                           ("vote", "web/challenge.js")):
        assert words.get(english) == where, (english, words.get(english))
    for code in site_lang.LANGUAGES:
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        for english in ("Full screen", "Comments are off on this model.", "Step {n}: {part} is put down in the air"):
            assert said[english] != english, f"{code}: {english}"


def test_an_answer_shown_as_the_server_wrote_it_is_caught() -> None:
    text = (ROOT / "web/model-page.js").read_text(encoding="utf-8")
    assert site_lang.untold(text) == []
    planted = text.replace('told(answer.body.error, say("The comments did not load just now."))',
                           'answer.body.error || say("The comments did not load just now.")', 1)
    assert planted != text and len(site_lang.untold(planted)) == 1
    assert site_lang.untold("note.textContent = state.you?.why_not;") != []
    assert site_lang.untold("if (answer.body.error) note.textContent = say(answer.body.error);") == []


def test_a_link_to_a_profile_as_english_writes_it_is_caught() -> None:
    # Every profile has its copy (/de/u/<handle>): a copy's link to one is
    # in its language, not to the English page theme.js sends it on from.
    designer = site_lang.scope("api/share.js", ("designerRow",))
    assert site_lang.unled(designer) == [] and "${langAt()}/u/${handle}" in designer
    planted = designer.replace('href="${langAt()}/u/${handle}"', 'href="/u/${handle}"', 1)
    assert planted != designer and len(site_lang.unled(planted)) == 1
    assert site_lang.unled("link.href = `/u/${encodeURIComponent(one.handle)}`;") != []
    assert site_lang.unled("link.href = `${langAt()}/u/${encodeURIComponent(one.handle)}`;") == []


def test_a_word_between_two_templates_and_a_name_s_sentence_are_caught() -> None:
    # A template in another's ${} is read as one of its own, so the words
    # between two are never taken for one; and "Brickworks could not ..."
    # is a sentence, though its only capital is a name.
    nested = 'html = `<p>${ok ? `<b>${say("Yes")}</b>` : ""} Nobody here</p>`;'
    left = site_lang.unsaid(nested)
    assert len(left) == 1 and left[0].endswith(" Nobody here</p>`")
    assert site_lang.unsaid('html = `<p>${ok ? `<b>${n}</b>` : ""}</p>`;') == []
    assert site_lang.unsaid('note.textContent = "Brickworks could not say.";') == ['"Brickworks could not say."']
    assert site_lang.unsaid('mark.textContent = "Brickworks";') == []


def test_a_link_to_any_page_with_copies_as_english_writes_it_is_caught() -> None:
    # languages6: a collection, every collection, this month's challenge,
    # your own profile and your settings have copies too, so a link to one
    # is in the page's language, in any script a copy loads.
    for link in ('a.href = "/collections";', "a.href = `/c/${id}`;", 'a.href = "/profile?edit=1";',
                 'a.href = "/settings#plan";', 'link.href = `/challenge${tests ? "?tests=1" : ""}`;'):
        assert site_lang.unled(link) != [], link
    # languages7: the account menu's pages, the footer's and the consent page too.
    for link in ('a.href = "/takedown";', 'href="/terms#notices"', 'a.href = "/feed";', 'a.href = "/beta-hub";',
                 '`<a href="/changelog">`', 'location.href = "/oauth/authorize?" + query;'):
        assert site_lang.unled(link) != [], link
    for link in ("a.href = `${langAt()}/collections`;", "a.href = `${langAt()}/settings#plan`;", 'img.src = "/m/X.png";',
                 'a.href = "/docs";', 'call("/api/people?op=profile");', "alternatesOf(origin, `c/${id}`)"):
        assert site_lang.unled(link) == [], link
    loaded = {script for name in site_lang.PAGES for script in site_lang.scripts_of(name)}
    # A script the gallery's imports (web/gallery.js, its lists) is loaded too.
    models = (ROOT / "web/models.js").read_text(encoding="utf-8")
    assert {"gallery.js", "models.js"} <= loaded and "web/models.js" not in site_lang.SAID_ALL and site_lang.unled(models) == []
    planted = models.replace("`${langAt()}/challenge", "`/challenge", 1)
    assert planted != models and len(site_lang.unled(planted)) == 1


def test_the_pages_languages6_said_have_their_words() -> None:
    # A collection and every collection (api/people.js), this month's
    # challenge and a challenge's link, your own profile, your settings and
    # the feedback form, and what the API they call answers in words: each
    # has its entry in each language.
    words = site_lang.script_words()
    for english, where in (("Collected by {who} · updated {when}", "api/people.js"),
                           ("Collections — the Brickworks gallery", "web/collections.js"),
                           ("{title} · Brickworks challenge", "api/_challenges.js"),
                           ("{title} · a Brickworks challenge", "web/challenge.js"),
                           ("a link is at most 200 characters", "api/people.js"),
                           ("make your profile first: a name and a handle", "api/people.js"),
                           ("The picture did not go with it.", "api/_feedback.js"),
                           ("Pictures of your own and likes on your profile are not open on Brickworks yet.", "api/_avatars.js")):
        assert words.get(english) == where, (english, words.get(english))
    assert any(where == "api/_oc.js" and english.startswith("orangecheck could not delete") for english, where in words.items())
    for code in site_lang.LANGUAGES:
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        for english in ("Collections — the Brickworks gallery", "{title} · a Brickworks challenge",
                        "Delete this account and everything in it, for good?"):
            assert said[english] != english, f"{code}: {english}"


def test_a_challenge_s_link_has_its_head_in_the_language() -> None:
    script = """
      import { readFileSync } from "node:fs";
      import { challengeHead } from "./api/_challenges.js";
      import { inLanguage, siteWords } from "./api/_directory.js";
      const page = { id: 7, title: "Harbour", brief: "Build a harbour.", starts_on: "2026-10-01", ends_on: "2026-10-31",
        state: "ended", test: false, winners: [], entries: [] };
      const made = inLanguage("de", siteWords("de"), () => challengeHead(readFileSync("web/de/challenge.html", "utf8"),
        "https://x", page, false, "de"));
      const tag = (pattern) => (pattern.exec(made) || [])[1];
      console.log(JSON.stringify({ title: tag(/<title>([^<]*)<\\/title>/), about: tag(/<meta name="description" content="([^"]*)">/),
        canonical: tag(/<link rel="canonical" href="([^"]*)">/),
        alternates: Object.fromEntries([...made.matchAll(/<link rel="alternate" hreflang="([a-z-]+)" href="([^"]*)">/g)]
          .map((m) => [m[1], m[2]])) }));
    """
    out = json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                    capture_output=True, text=True).stdout)
    said = json.loads((ROOT / "web/de/words.json").read_text(encoding="utf-8"))
    assert out["title"] == said["{title} · Brickworks challenge"].replace("{title}", "Harbour")
    assert out["about"] == "Build a harbour. " + said["Ran {days}: see who won."].replace("{days}", "1.–31. Oktober 2026")
    assert out["canonical"] == "https://x/de/challenge?id=7"
    assert out["alternates"] == {"en": "https://x/challenge?id=7", "de": "https://x/de/challenge?id=7",
                                 "fr": "https://x/fr/challenge?id=7", "es": "https://x/es/challenge?id=7",
                                 "x-default": "https://x/challenge?id=7"}


def test_the_tested_why_names_parts_and_colours_as_the_parts_list_does() -> None:
    # Every part and colour a why names goes through nameSaid (the parts
    # list's words in the language), none as the app wrote it; and German
    # opens the sentence after "Bei Schritt 3:" with a capital.
    said = site_lang.scope("web/model-page.js", ("pieceSaid", "tipSaid"))
    assert not re.search(r"\b(?:part|other|who|colour):\s*m\[\d\]", said), said
    assert "afterColon(what)" in said and "nameSaid(m[5], names?.colours)" in said


def copy_of(code: str, where: str) -> str:
    return (ROOT / "web" / code / (f"{where}.html" if where else "index.html")).read_text(encoding="utf-8")


def years(page: str) -> list[str]:
    return sorted(re.findall(r"\b20\d\d\b", re.sub(r"<!--.*?-->|<script.*?</script>", "", page, flags=re.S)))


def test_a_rule_page_s_copy_says_the_english_text_binds() -> None:
    # languages7: the terms, privacy, guidelines and takedown pages are
    # translated in full, and each copy opens with one line in its language
    # that the English text binds, linking to it (?lang=en keeps it English,
    # web/theme.js). Every date of the English is kept.
    for name in site_lang.BINDING:
        assert 'class="binding"' not in (ROOT / "web" / name).read_text(encoding="utf-8")
    for code in site_lang.LANGUAGES:
        line = json.loads((ROOT / "web/_lang" / f"{code}.json").read_text(encoding="utf-8"))["pages"][site_lang.BOUND]
        assert line != site_lang.BOUND and '<a href="{english}">' in line
        for name, where in site_lang.PAGES.items():
            text = copy_of(code, where)
            said = re.findall(r'<p class="binding">(.*?)</p>', text)
            if name not in site_lang.BINDING:
                assert said == [], (code, name)
                continue
            assert said == [line.replace("{english}", f"/{where}?lang=en")], (code, name)
            assert re.search(r'</h1>\n\t*<p class="binding">', text), (code, name)
            english = (ROOT / "web" / name).read_text(encoding="utf-8")
            assert years(text) == years(english), (code, name)


def test_the_page_not_found_and_the_consent_page_have_copies() -> None:
    # The page not found answers /de/<anything> in German (tools/deploy.sh),
    # and theme.js sends a visitor who chose German from the English one to
    # the same address under /de; the consent page is at /de/oauth/authorize.
    theme = (ROOT / "web/theme.js").read_text(encoding="utf-8")
    assert 'hasAttribute("data-missing")' in theme and 'get("lang")' in theme
    deploy = (ROOT / "tools/deploy.sh").read_text(encoding="utf-8")
    assert '"/($langs)/.*", "status": 404, "dest": "/\\$1/404.html"' in deploy
    assert '"src": "/($langs)/oauth/authorize/?", "dest": "/\\$1/oauth/authorize.html"' in deploy
    for code in site_lang.LANGUAGES:
        words = json.loads((ROOT / "web/_lang" / f"{code}.json").read_text(encoding="utf-8"))["pages"]
        missing = copy_of(code, "404")
        assert f'<html lang="{code}" data-missing>' in missing and 'rel="canonical"' not in missing
        assert f"<h1>{words['This brick is missing.']}</h1>" in missing
        consent = copy_of(code, "oauth/authorize")
        assert f'<html lang="{code}">' in consent and 'rel="canonical"' not in consent
        assert f'<link rel="alternate" hreflang="{code}" href="https://brickworks.diy/{code}/oauth/authorize">' in consent
        assert '<script type="module" src="/authorize.js"></script>' in consent


def test_the_changelog_s_copy_says_its_chrome_and_keeps_the_notes_as_written() -> None:
    def page(code: str) -> str:
        return subprocess.run([sys.executable, "tools/site.py", f"--changelog={code}"], cwd=ROOT, check=True,
                              capture_output=True, text=True).stdout
    english = page("en")
    notes = re.findall(r'<div class="release-notes">(.*?)</div>\n</article>', english, re.S)
    assert len(notes) > 5
    for code in site_lang.LANGUAGES:
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        title = json.loads((ROOT / "web/_lang" / f"{code}.json").read_text(encoding="utf-8"))["pages"]["Changelog · Brickworks"]
        copy = page(code)
        assert f'<html lang="{code}">' in copy and f"<title>{title}</title>" in copy and title != "Changelog · Brickworks"
        # Each release's notes as they were written, marked English.
        assert re.findall(r'<div class="release-notes" lang="en">(.*?)</div>\n</article>', copy, re.S) == notes
        assert '<div class="release-notes">' not in copy
        # Its date, links and their words in the language.
        stamp = re.search(r'<time datetime="(\d{4})-(\d\d)-(\d\d)">([^<]*)</time>', copy)
        year, month, day = (int(n) for n in stamp.groups()[:3])
        months = ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                  "October", "November", "December"]
        assert stamp.group(4) == said["{day} {month} {year}"].replace("{day}", str(day)).replace(
            "{month}", said[months[month - 1]]).replace("{year}", str(year))
        assert f'<a href="/{code}/download">{said["Download"]}</a>' in copy and f'>{said["On GitHub"]}</a>' in copy
        assert 'href="/download"' not in copy


def test_the_feed_and_the_notifications_say_their_lines_in_the_language() -> None:
    # The server says each line whole in the language asked (?lang=), with
    # {who} where the language puts the name: no English verb left in it.
    script = """
      import { feedSaid } from "./api/_follows.js";
      import { dayWords, noticeSaid } from "./api/_notifications.js";
      import { inLanguage, siteWords } from "./api/_directory.js";
      const now = Date.parse("2026-11-02T12:00:00Z");
      const by = { handle: "ana", name: "Ana" };
      const said = (code) => inLanguage(code, siteWords(code), () => ({
        feed: feedSaid({ kind: "comment", step: 3, model: "abcdefghij", name: "Harbour", by }).line,
        remix: feedSaid({ kind: "remix", model: "abcdefghij", name: "Harbour", of_name: "Boat", by }),
        reply: noticeSaid({ kind: "reply", step: 2, model: "abcdefghij", by, said: "Nice" }, "", now).line,
        likes: noticeSaid({ kind: "likes", model: "abcdefghij", likes: 3, day: "2026-10-03" }, "", now).line,
        one: noticeSaid({ kind: "likes", model: "abcdefghij", likes: 1, day: "2026-11-02" }, "", now).line,
        yesterday: dayWords("2026-11-01", now) }));
      console.log(JSON.stringify({ en: said("en"), de: said("de"), fr: said("fr") }));
    """
    out = json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                    capture_output=True, text=True).stdout)
    assert out["en"]["feed"] == "{who} commented on step 3 of your model {name}"
    assert out["en"]["likes"] == "3 new likes on 3 October" and out["en"]["one"] == "1 new like today"
    for code in ("de", "fr"):
        said = json.loads((ROOT / "web" / code / "words.json").read_text(encoding="utf-8"))
        got = out[code]
        assert got["feed"] == said["{who} commented on step {step} of your model {name}"].replace("{step}", "3")
        assert got["reply"] == said["{who} replied to your comment on step {step}"].replace("{step}", "2")
        assert got["remix"]["line"] == said["{who} remixed your model {of} as {name}"] and got["remix"]["of"] == "Boat"
        assert got["likes"].startswith(f"3 {said['new likes']} ") and got["one"] == f"1 {said['new like']} {said['today']}"
        assert got["yesterday"] == said["yesterday"]
        for line in got["feed"], got["reply"], got["likes"]:
            assert not re.search(r"\b(?:commented|replied|new likes?|October|on step)\b", line), (code, line)
    assert "3 octobre" in out["fr"]["likes"] and "3. Oktober" in out["de"]["likes"]


def test_the_account_and_rule_pages_scripts_say_every_word() -> None:
    # A word left in English in the scripts these pages run fails the check
    # (SAID_ALL), and an answer shown as the server wrote it (untold).
    for path in ("web/feed.js", "web/notifications.js", "web/builds.js", "web/beta.js", "web/beta-hub.js",
                 "web/authorize.js", "web/takedown.js"):
        text = site_lang.scope(path, site_lang.SAID_ALL[path])
        assert len(text) > 500 and site_lang.unsaid(text) == [] and site_lang.untold(text) == [], path
        planted = text + '\nstatus.textContent = "Mark all read";\nnote.textContent = body.error;\n'
        assert site_lang.unsaid(planted) == ['"Mark all read"'] and len(site_lang.untold(planted)) == 1, path
    for server in ("api/_beta.js", "api/_notifications.js", "api/oauth.js"):
        assert server in site_lang.TOLD, server
