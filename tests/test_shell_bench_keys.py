"""A browser's address never sets the bench's flags.

src/boot/shell.html carries the address's query into the app's arguments
(?view=<id> -> --view=<id>). The app read --brickbench, --held-out= and
--held-out-name= as the signs of a bench, whose save takes the design's own
refused parts off the model, so a link with ?brickbench or ?held-out= made a
person's tab a bench's (savereview2 G1). The page drops those keys; the app
ignores them on the web as well (save_whole_probe).

The page's own code is run here in node, as it stands between its markers,
with each address.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
START = "const query = new URLSearchParams(location.search);"
END = 'if (args.length) GODOT_CONFIG.args = ["--", ...args];'

needs_node = pytest.mark.skipif(shutil.which("node") is None, reason="no node here")


def page_block() -> str:
    """The lines of shell.html that turn the address's query into arguments."""
    text = (ROOT / "src/boot/shell.html").read_text()
    # The nearest START before END: the share prefetch reads the query too.
    end = text.index(END) + len(END)
    start = text.rindex(START, 0, end)
    return text[start:end]


def arguments(search: str) -> list[str] | None:
    """The app's arguments the page passes for an address's [search] part."""
    script = (
        "const location = { search: %s };\n"
        "const GODOT_CONFIG = {};\n"
        "%s\n"
        "process.stdout.write(JSON.stringify(GODOT_CONFIG.args === undefined ? null : GODOT_CONFIG.args));\n"
    ) % (json.dumps(search), page_block())
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True,
                          text=True, timeout=60, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout)


@needs_node
@pytest.mark.parametrize("search", [
    "?brickbench",
    "?brickbench=1",
    "?held-out=7634-1",
    "?held-out-name=Tower%20Crane",
    "?held-out=7634-1&held-out-name=Tower%20Crane&brickbench",
    # The key "held-out=7634-1", which would be the argument --held-out=7634-1.
    "?held-out%3D7634-1",
    "?%62rickbench",
])
def test_bench_keys_never_reach_the_app(search: str) -> None:
    assert arguments(search) is None


@needs_node
def test_other_keys_still_carry_through_beside_them() -> None:
    assert arguments("?view=AbCdEfGhIj&brickbench&lang=de&held-out=7634-1&model=a.ldr") == [
        "--", "--view=AbCdEfGhIj", "--lang=de", "--model=a.ldr"]


@needs_node
def test_a_plain_address_passes_nothing() -> None:
    assert arguments("") is None
