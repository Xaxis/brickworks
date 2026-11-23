"""The beta strip's room, decided before a page is drawn (2026-11-23).

A set's page on a phone held 48 px at its top for the beta strip, then let it
go half a second in, when the server said the beta was off (checkdrift). Each
page the server makes now says the beta in its head, just before
web/theme.js (api/_settings.js sayBeta), so theme.js holds the room or holds
none before the first frame. tools/web/betahome_flow.mjs --only=steady
watches the header's top over the first second in a browser; this file holds
what the server writes.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEME = '<script src="/theme.js"></script>'
PAGES = ["/m/DesignAbc1", "/de/m/DesignAbc1", "/library/set/30476-1", "/u/design-tester", "/c/ListAbcde1",
         "/talk", "/challenge"]


def pages(beta: str, *paths: str) -> list[dict] | None:
    """Each of [paths] as the server makes it, with the project's beta
    [beta] and no switch set in the console: {status, html}."""
    if shutil.which("node") is None:
        return None
    script = (
        f"process.env.BRICKWORKS_BETA = {json.dumps(beta)};"
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "const out = [];"
        f"for (const path of {json.dumps(list(paths))}) {{ const r = await s.serverPage('api', path);"
        "  out.push({ status: r.status, html: r.html }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def said(html: str) -> list[str]:
    return re.findall(r'<meta name="brickworks-beta" content="([a-z]+)">', html)


def test_each_page_the_server_makes_says_the_beta_just_before_theme_js() -> None:
    for beta in ("open", "off"):
        answered = pages(beta, *PAGES)
        if answered is None:
            return
        for path, page in zip(PAGES, answered):
            assert page["status"] == 200, (beta, path, page["status"])
            assert said(page["html"]) == [beta], (beta, path, said(page["html"]))
            assert f'<meta name="brickworks-beta" content="{beta}">\n{THEME}' in page["html"], (beta, path)


def test_an_embeds_card_says_nothing_of_it() -> None:
    answered = pages("open", "/m/DesignAbc1/embed")
    if answered is None:
        return
    assert answered[0]["status"] == 200 and not said(answered[0]["html"])


def test_the_stamp_needs_theme_js_and_a_beta_it_knows() -> None:
    if shutil.which("node") is None:
        return
    script = (
        "const { sayBeta, betaSaid } = await import('./api/_settings.js');"
        f"const page = '<head>\\n{THEME}\\n</head>';"
        "delete process.env.SUPABASE_URL;"
        "console.log(JSON.stringify({ open: sayBeta(page, 'open'), none: sayBeta('<head></head>', 'open'),"
        "  odd: sayBeta(page, 'maybe'), nodb: await betaSaid({ headers: {} }, { BRICKWORKS_BETA: 'open' }) }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, check=True)
    out = json.loads(done.stdout.strip().splitlines()[-1])
    assert out["open"] == f'<head>\n<meta name="brickworks-beta" content="open">\n{THEME}\n</head>'
    assert out["none"] == "<head></head>"
    assert out["odd"] == f"<head>\n{THEME}\n</head>"
    # No database, no beta: as ?op=beta_spots answers (api/_beta.js).
    assert out["nodb"] == "off"
