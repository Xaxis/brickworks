"""Every module a function imports is in the deployment beside it.

A deployment has no web/ beside its functions: a function's own folder holds its handler, every
api/_*.js, and the web files tools/package_api.sh copies in place of the api/_*.js wrappers that pass
them through in a checkout. rel-m319's preview, 11-22: api/share.js imported ../web/private-lines.js
straight, every op of /api/share answered 500 (ERR_MODULE_NOT_FOUND), and the home page lost its
challenge and its 3D view. Every check run from a checkout passed, since there web/ is beside api/.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATIC = re.compile(r'^\s*(?:import\b[^;]*?\bfrom|export\b[^;]*?\bfrom|import)\s*["\']([^"\']+)["\']', re.M)


def _copied() -> dict[str, str]:
    """{wrapper name: the web file package_api.sh copies in its place}."""
    script = (ROOT / "tools/package_api.sh").read_text()
    return {name: source for source, name in re.findall(r'cp (web/[\w./-]+) "\$fn/(_[\w.-]+\.js)"', script)}


def test_every_function_import_is_in_its_deployment() -> None:
    copied = _copied()
    wrong = []
    for path in sorted((ROOT / "api").glob("*.js")):
        for target in STATIC.findall(path.read_text()):
            if target.startswith("./"):
                if not (ROOT / "api" / target[2:]).is_file():
                    wrong.append(f"{path.name}: imports {target}, not a file in api/")
            elif target.startswith("../"):
                source = copied.get(path.name)
                if source is None or (ROOT / "api" / target).resolve() != (ROOT / source).resolve():
                    wrong.append(f"{path.name}: imports {target}, which no deployment holds"
                                 " (pass it through an api/_*.js that tools/package_api.sh replaces)")
    assert not wrong, "\n".join(wrong)


def test_each_wrapper_package_api_replaces_passes_that_file_through() -> None:
    for name, source in _copied().items():
        wrapper = ROOT / "api" / name
        assert wrapper.is_file(), f"package_api.sh copies {source} to {name}, but api/{name} is not there"
        assert f'"../{source}"' in wrapper.read_text(), f"api/{name} does not pass {source} through"
