"""The desktop app is coming soon, everywhere a person could get it.

The owner, 2026-11-07: "make the downloadable access 'Coming soon' or
something of that sort, since we can't properly support it yet." Every page
of the site, in each language, and every script it loads offers no
installer, no release of the releases repository and no /releases.json
(tools/web/coming_soon_check.mjs, here without its browser), and the app
tells nobody on the web to go and get the desktop app without saying it is
coming soon. The desktop app already installed keeps updating itself
(src/net/updates.gd and its feed are not the site's, and are left out).
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
CHECK = ROOT / "tools" / "web" / "coming_soon_check.mjs"
# A string the app shows that sends a person to the desktop app.
SENDS = re.compile(r'"((?:[^"\\\n]|\\.)*\b(?:needs?|use|open it in|download|get|install)\b'
                   r'(?:[^"\\\n]|\\.)*\bdesktop app\b(?:[^"\\\n]|\\.)*)"', re.I)
# The desktop app's own updating, which only an installed app shows.
UPDATING = {"src/net/updates.gd", "src/net/updater.gd", "src/ui/update_notice.gd", "src/ui/update_dialog.gd"}


def _check(*args: str) -> subprocess.CompletedProcess:
    if not shutil.which("node"):
        pytest.skip("no node")
    return subprocess.run(["node", str(CHECK), "--static", *args], cwd=ROOT, capture_output=True, text=True,
                          timeout=300)


def test_no_page_or_script_of_the_site_offers_an_installer() -> None:
    got = _check()
    assert got.returncode == 0, got.stdout[-3000:] + got.stderr[-2000:]
    sent = re.search(r"as sent\s+(\d+) of (\d+) pages, (\d+) scripts", got.stdout)
    assert sent and sent.group(1) == sent.group(2) and int(sent.group(1)) > 100 and int(sent.group(3)) > 20, got.stdout
    # All four languages.
    assert re.search(r"\d+ en, \d+ de, \d+ fr, \d+ es", got.stdout), got.stdout


def test_the_check_fails_on_each_way_of_offering_one(tmp_path: Path) -> None:
    site = tmp_path / "site"
    (site / "de").mkdir(parents=True)
    (site / "index.html").write_text(
        '<!doctype html><html lang="en"><head><script src="/offer.js"></script>'
        '<script type="application/ld+json">{"downloadUrl": "https://brickworks.diy/download"}</script></head><body>'
        '<a href="https://github.com/Xaxis/brickworks-releases/releases/latest">Get it</a>'
        '<a href="/files/Brickworks-0.19.0-linux-amd64.deb">the .deb</a>'
        '<a href="/download">Download</a>'
        '<a href="https://github.com/Xaxis/brickworks-releases/issues">Ask on GitHub</a>'
        '<a href="/download">Desktop app</a>'
        '</body></html>', encoding="utf-8")
    (site / "offer.js").write_text('fetch("/releases.json");\n', encoding="utf-8")
    (site / "de" / "index.html").write_text(
        '<!doctype html><html lang="de"><body><button>Für den Desktop herunterladen</button>'
        '<a href="/de/download">Herunterladen</a></body></html>', encoding="utf-8")
    (site / "404.html").write_text("<!doctype html><title>not found</title>", encoding="utf-8")
    got = _check(f"--root={site}")
    assert got.returncode == 1, got.stdout
    said = got.stdout
    for one in ("links the releases, https://github.com/Xaxis/brickworks-releases/releases/latest",
                "links an installer, /files/Brickworks-0.19.0-linux-amd64.deb",
                '/: links "Download" to /download',
                "JSON-LD downloadUrl",
                '/offer.js: reaches for "releases.json"',
                '/de: a button offers "Für den Desktop herunterladen"',
                '/de: links "Herunterladen" to /de/download'):
        assert one in said, (one, said)
    # Asking on GitHub, and the desktop app's page by its name, offer nothing.
    assert "issues" not in said and '"Desktop app"' not in said, said
    assert said.count("FAIL  ") == 7, said


def test_the_app_tells_nobody_to_get_the_desktop_app_without_saying_it_is_coming_soon() -> None:
    sends = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        where = path.relative_to(ROOT).as_posix()
        if where.startswith("src/dev/") or where in UPDATING:
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            sends += [(where, n, m.group(1)) for m in SENDS.finditer(line) if "coming soon" not in m.group(1)]
    assert not sends, sends
