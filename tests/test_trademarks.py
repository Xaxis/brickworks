"""The LEGO Group's marks, written the way its Fair Play policy asks.

docs/TRADEMARKS.md has the rules and where each comes from. This test holds
the words people read to those rules: the website, the share page, the
app's own strings, the connector's tool descriptions, the README, the
changelog and the release README. It fails on "Lego", "Legos" and "LEGO's",
on LEGO used as a noun for the company, on LEGO Art used as the name of a
feature of ours, and on any place the disclaimer has to be that has lost it.

Comments and probes are not read: the policy is about what the public
sees, and internal code may keep its names.
"""

from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import release  # noqa: E402

# The disclaimer the Fair Play policy asks for, word for word. Only the last
# word changes, to say what it is on.
NOTICE = re.compile(
    r"LEGO(?:®|\(R\)) is a trademark of the LEGO Group of companies which does "
    r"not sponsor, authorize or endorse this (?:site|app|software|booklet)\.")

# The policy's brochure asks the disclaimer to name every other LEGO mark a
# page uses. The site and the app name these.
ALSO = ("LEGO® Art, Technic, the Minifigure and the Brick and Knob configurations "
        "are also trademarks of the LEGO Group.")

# Each wrong use, what to write instead, and a sentence it must catch.
WRONG: list[tuple[re.Pattern[str], str, str]] = [
    (re.compile(r"\bLEGO\b(?!®|\(R\)| Group)"),
     "LEGO carries its ® each time it is used, but not in the LEGO Group", "real LEGO bricks"),
    (re.compile(r"LEGO(?:®|\(R\)) Group"), "no ® in the company's name: the LEGO Group",
     "as the LEGO® Group built it"),
    (re.compile(r"\bLegos?\b"), "LEGO is written in capitals", "a Lego set"),
    (re.compile(r"\b(?:LEGO|Lego|lego)s\b"), "LEGO is never plural: LEGO bricks", "Build with LEGOs"),
    (re.compile(r"\b(?:LEGO|Lego)®?['’]s\b"), "LEGO is never possessive: the LEGO Group's",
     "LEGO®'s own colours"),
    (re.compile(r"\bLEGO®? (?:made|makes|built|builds|sells|sold|has|had|never|calls|called|"
                r"names|did|does|designs|designed|moulds|moulded|prints|printed|replaced|"
                r"retired|stopped|added)\b"),
     "LEGO is an adjective, not the company: the LEGO Group made it", "as LEGO® made it"),
    (re.compile(r"\b(?:laid|built|made) in LEGO\b(?!®? (?:bricks|parts|elements|pieces|plates|"
                r"tiles|sets?|colou?rs|Digital))"),
     "LEGO is an adjective: laid in LEGO bricks", "a sculpt laid in LEGO® at any size"),
    (re.compile(r"\bLEGO®? CAD\b"), "not a LEGO product: a CAD app for LEGO bricks",
     "the LEGO® CAD app"),
    # "LEGO® Art," is the mark itself, named in the disclaimer's list.
    (re.compile(r"\bLEGO®? Art\b(?!®? sets?\b|,)"),
     "LEGO Art is the LEGO Group's line, not our feature: Brick Art, or LEGO Art sets",
     "laid as LEGO® Art"),
]


def gd_strings(text: str) -> list[str]:
    """The string literals of a GDScript file, comments left out."""
    found: list[str] = []
    triple = False
    for line in text.splitlines():
        i = 0
        while i < len(line):
            if triple:
                end = line.find('"""', i)
                if end < 0:
                    found.append(line[i:])
                    break
                found.append(line[i:end])
                i, triple = end + 3, False
                continue
            c = line[i]
            if c == "#":
                break
            if line.startswith('"""', i):
                triple, i = True, i + 3
                continue
            if c in "\"'":
                j = i + 1
                while j < len(line) and line[j] != c:
                    j += 2 if line[j] == "\\" else 1
                found.append(line[i + 1:j])
                i = j + 1
                continue
            i += 1
    return found


def json_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in json_strings(v)]
    if isinstance(value, list):
        return [s for v in value for s in json_strings(v)]
    return []


def plain(text: str) -> str:
    """Markup taken out and white space made single, so a sentence across lines reads as one."""
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", html.unescape(text))


def public_text() -> dict[str, str]:
    """Every file a person reads, as the words they read."""
    texts: dict[str, str] = {}
    for path in sorted((ROOT / "web").glob("*.html")) + sorted((ROOT / "web").glob("*.js")) + [
            ROOT / "web/site.webmanifest", ROOT / "api/share.js", ROOT / "api/_directory.js",
            ROOT / "src/boot/shell.html",
            ROOT / "README.md", ROOT / "CHANGELOG.md", ROOT / "tools/brickworks_mcp.py",
            ROOT / "tools/release.py", ROOT / "tools/site.py"]:
        texts[path.relative_to(ROOT).as_posix()] = plain(path.read_text())
    for path in [ROOT / "tools/mcp_tools.json", ROOT / "web/img/manifest.json"]:
        strings = json_strings(json.loads(path.read_text()))
        texts[path.relative_to(ROOT).as_posix()] = " \n".join(strings)
    for path in sorted((ROOT / "src").rglob("*.gd")):
        if "dev" in path.relative_to(ROOT / "src").parts:
            continue
        joined = re.sub(r"\\\n", " ", path.read_text())
        texts[path.relative_to(ROOT).as_posix()] = re.sub(r"\s+", " ", " ".join(gd_strings(joined)))
    return texts


def test_the_mark_is_written_as_the_policy_asks() -> None:
    wrong: list[str] = []
    for name, text in public_text().items():
        for pattern, why, _ in WRONG:
            for found in pattern.finditer(text):
                around = text[max(0, found.start() - 40):found.end() + 40].replace("\n", " ")
                wrong.append(f"{name}: {why}: …{around}…")
    assert not wrong, "\n".join(wrong)


@pytest.mark.parametrize("pattern, example", [(p, e) for p, _, e in WRONG])
def test_each_pattern_catches_its_wrong_use(pattern: re.Pattern[str], example: str) -> None:
    """Each pattern does fire, so the test above passing means something."""
    assert pattern.search(example), example


@pytest.mark.parametrize("good", [
    "LEGO® bricks", "as the LEGO Group made it", "the LEGO Group's own designers",
    "a mosaic in the style of LEGO® Art sets", "laid in LEGO® bricks",
    "LEGO® Digital Designer model (.lxf)", "Brick Art", "LEGO(R) is a trademark",
])
def test_the_check_lets_right_use_through(good: str) -> None:
    assert not any(pattern.search(good) for pattern, _, _ in WRONG), good


# Where the disclaimer has to be: each page's footer, the web app's loading
# page, the share page and its page for a link that is gone, the app's About,
# the booklet's credits, the README and each release's README.
def test_every_web_page_carries_the_notice() -> None:
    for path in sorted((ROOT / "web").glob("*.html")):
        if path.name == "admin.html":   # the owner's own page, kept out of robots
            continue
        text = plain(path.read_text())
        footer = re.search(r"<footer.*?</footer>", path.read_text(), re.S)
        assert footer is not None, f"{path.name} has no footer"
        assert NOTICE.search(plain(footer.group(0))), f"{path.name}'s footer has no notice"
        assert NOTICE.search(text)
        # The site's own pages name the other marks too; the sign-in page for
        # the connector names none of them.
        if path.name != "authorize.html":
            assert ALSO in plain(footer.group(0)), f"{path.name}'s footer does not name the other marks"


def test_the_web_app_and_the_readme_carry_the_notice() -> None:
    for name in ["src/boot/shell.html", "README.md"]:
        assert NOTICE.search(plain((ROOT / name).read_text())), name
    assert ALSO in plain((ROOT / "README.md").read_text())


def _function(source: str, name: str) -> str:
    start = source.index(f"function {name}(")
    ends = [at for at in (source.find("\nfunction ", start + 1), source.find("\nexport function ", start + 1),
                          source.find("\nasync function ", start + 1)) if at > 0]
    return source[start:min(ends) if ends else len(source)]


def test_the_share_page_carries_the_notice() -> None:
    """A shared model's page and the page of a link taken down (api/share.js)
    end in the site's own footer, read from web/gallery.html, whose footer
    carries the notice (above); and where that page is not there, in one of
    their own with it (api/_directory.js siteChrome)."""
    shared = (ROOT / "api/_directory.js").read_text()
    said = re.search(r'export const NOTICE = "([^"]+)";', shared)
    assert said is not None and NOTICE.fullmatch(said.group(1)), "_directory.js has no NOTICE"
    chrome = _function(shared, "siteChrome")
    assert "${NOTICE}" in chrome and "gallery.html" in chrome, "siteChrome has no footer of its own with the notice"
    source = (ROOT / "api/share.js").read_text()
    for page in ["sharePage", "gonePage"]:
        body = _function(source, page)
        assert "${NOTICE}" in body or ("siteChrome()" in body and "${footer}" in body), \
            f"{page} does not show the notice"


def test_the_app_says_it_in_about_and_in_the_booklet() -> None:
    for name, function in [("src/ui/shell.gd", "_show_about"),
                           ("src/render/booklet_maker.gd", None)]:
        source = (ROOT / name).read_text()
        if function is not None:
            source = source[source.index(f"func {function}("):]
            source = source[:source.find("\nfunc ", 1)]
        joined = re.sub(r"\s+", " ", " ".join(gd_strings(source)))
        assert NOTICE.search(joined), name
        if function is not None:
            assert ALSO in joined, name


@pytest.mark.parametrize("platform", ["linux", "mac", "windows"])
def test_each_release_readme_carries_the_notice(platform: str) -> None:
    text = release.readme(platform, "9.9.9", "2026-10-13", {})
    assert NOTICE.search(re.sub(r"\s+", " ", text)), platform
