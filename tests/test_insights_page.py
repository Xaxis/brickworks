"""What the site's pages ask before they count (infix, 2026-11-18; docs/ANALYTICS.md, /counting).

The review of insights (bench/results/inreview-2026-11-18/report.md) found
the counter fetched where the answer was already no (L3), the social desk's
visit told under Do Not Track, GPC and No (L2), and a clock that names no
place (UTC, Etc/*) counted in the EU without a yes (L4).
tests/fixtures/insights/page_check.mjs runs web/counting.js's clocks and
web/theme.js whole against a stand-in page, a browser state at a time.
The consent card by keyboard (M5) and the console's page (M6, M7, L7) are
shown in a browser by the review's own tools (pages/ask.mjs, analytics.mjs).
"""

from __future__ import annotations

import functools
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
THEME = (ROOT / "web/theme.js").read_text()
SHELL = (ROOT / "src/boot/shell.html").read_text()
COUNTING = (ROOT / "web/counting.js").read_text()
ASK = (ROOT / "web/counting-ask.js").read_text()
ANALYTICS = (ROOT / "web/admin-analytics.js").read_text()


@functools.cache
def _page() -> dict:
    done = subprocess.run(["node", "tests/fixtures/insights/page_check.mjs"], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-3000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_a_clock_that_names_no_place_asks_first() -> None:
    zones = _page()["zones"]
    for zone in ["UTC", "Etc/UTC", "Etc/GMT+5", "Etc/GMT-1", "GMT", "Universal", "Zulu", "(none)"]:
        assert zones[zone] is True, zone
    assert _page()["utc_state"] == "ask"


def test_the_eus_places_on_other_clocks_ask_first() -> None:
    zones = _page()["zones"]
    for zone in ["Europe/Berlin", "Europe/Mariehamn", "Indian/Reunion", "America/Guadeloupe", "America/Martinique",
                 "America/Cayenne", "Indian/Mayotte", "America/Marigot", "Atlantic/Canary"]:
        assert zones[zone] is True, zone
    for zone in ["America/New_York", "America/Anchorage", "Asia/Tokyo", "Australia/Sydney", "America/Sao_Paulo"]:
        assert zones[zone] is False, zone


def test_a_no_fetches_no_counter() -> None:
    loads = _page()["loads"]
    for state in ["dnt", "gpc", "said_no", "driven", "console"]:
        assert loads[state]["tally"] is False and loads[state]["counting_js"] is False, (state, loads[state])
        assert loads[state]["beacons"] == 0 and loads[state]["fetched"] == 0, state
    # Where it may count, or must ask, the counter comes (the ask is its).
    for state in ["counted", "driven_asked", "berlin", "utc"]:
        assert loads[state]["tally"] is True, (state, loads[state])
    # The rest of the page is as it was.
    for state in loads.values():
        assert "/betabar.js" in state["imports"] and "/notice.js" in state["imports"]


def test_the_desks_visit_keeps_to_the_counting_page() -> None:
    desk = _page()["desk"]
    for state in ["dnt", "gpc", "said_no"]:
        assert desk[state]["beacons"] == 0 and desk[state]["counting_js"] is False, (state, desk[state])
    assert desk["counted"]["beacons"] == 1 and desk["said_yes"]["beacons"] == 1
    # A said yes needs nothing more fetched to tell it.
    assert desk["said_yes"]["counting_js"] is False
    # The desk's own flow lands a driven browser: still told.
    assert desk["driven"]["beacons"] == 1
    # Where a yes comes first: only once it is given, on this page.
    assert desk["berlin"]["beacons"] == 0 and desk["berlin_then_no"]["beacons"] == 0
    assert desk["berlin_then_yes"]["beacons"] == 1
    assert desk["untagged"]["beacons"] == 0 and desk["untagged"]["counting_js"] is False


def test_the_studio_fetches_no_counter_on_a_no() -> None:
    at = SHELL.index('import("/tally.js")')
    gate = SHELL[SHELL.rindex("setTimeout(function () {", 0, at):at]
    for said in ["navigator.doNotTrack", "navigator.globalPrivacyControl === true", 'kept("brickworks.counting") === "no"',
                 'navigator.webdriver === true && kept("brickworks.counting.check") !== "1"']:
        assert said in gate, said
    assert re.search(r"\) return;\s*$", gate.rstrip() + "\n", re.S) or "return;" in gate


def test_the_cheap_no_is_said_the_same_everywhere() -> None:
    # counting.js's no, repeated where the counter is fetched (theme.js, the studio's shell).
    for text in [THEME, SHELL]:
        assert 'kept("brickworks.counting") === "no"' in text
        assert 'kept("brickworks.counting.check") !== "1"' in text
        assert "navigator.globalPrivacyControl === true" in text
    assert "web/theme.js and src/boot/shell.html repeat" in COUNTING


def test_the_ask_is_first_by_tab_and_closes_by_escape() -> None:
    assert "document.body.prepend(card)" in ASK and "document.body.append(card)" not in ASK
    assert 'event.key !== "Escape"' in ASK
    # Focus is given back, never left on the page's body.
    assert "before.focus(" in ASK and "stop?.focus(" in ASK


def test_a_chart_is_one_tab_stop() -> None:
    assert "tabindex: at === lit ? 0 : -1" in ANALYTICS
    assert "points.length <= 120 ? 0 : -1" not in ANALYTICS
    for key in ["ArrowLeft", "ArrowRight", "Home", "End"]:
        assert key in ANALYTICS


def test_people_and_never_are_defined_as_counted() -> None:
    assert re.search(r'people: \["People", "[^"]*person-days', ANALYTICS)
    assert 'head: "People", key: "people"' in ANALYTICS
    assert "never pressed with a pointer or finger" in ANALYTICS
    assert re.search(r'never: \["Never used", "[^"]*Keys, shortcuts and Claude', ANALYTICS)
