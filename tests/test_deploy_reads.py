"""A release reuses its preview when only checks, release tools or tests changed.

tools/release/deploy_reads.sh says which files a deploy reads. Only flows and
checks by name were unread before, so rel-m319's fix to a module of the
checks (tools/web/browser.mjs) rebuilt an identical site twice (2026-11-23).
Now every file of tools/web is unread but those the build runs; these hold
that list to the build's own scripts, so a new build step there cannot be
taken for a check.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "tools" / "release" / "deploy_reads.sh"
BUILD = ["tools/deploy.sh", "tools/export.sh", "tools/package_api.sh", "tools/site.py", "tools/web_pack.py",
         "tools/docs_site.py", "tools/site_lang.py"]
# Named by the deploy, but run against the deployment once it is made: they
# make nothing in it.
RUN_ON_IT = {"check.mjs", "fit_check.mjs", "landing_check.mjs", "coming_soon_check.mjs", "load_check.mjs",
             "beta_flow.mjs", "billing_flow.mjs", "serve.py"}


def reads(path: str) -> bool:
    return subprocess.run(["bash", "-c", f'. "{LIB}"; deploy_reads "$1"', "_", path]).returncode == 0


def test_checks_release_tools_and_tests_are_unread():
    for path in ("tools/web/browser.mjs", "tools/web/gallery_flow.mjs", "tools/web/site_check.mjs",
                 "tools/web/session.mjs", "tools/release/ship.sh", "tests/test_lean.py", "tools/web/live_smoke.mjs"):
        assert not reads(path), path


def test_what_the_build_runs_is_read():
    for path in ("tools/web/place_build.py", "tools/web/brotli.mjs", "tools/web/pck_split.py", "web/site.css",
                 "api/share.js", "src/main.gd", "tools/deploy.sh", "tools/export.sh", "tools/site.py",
                 "tools/web/gallery_seeds/a.json", "tools/package_api.sh", "CHANGELOG.md"):
        assert reads(path), path


def test_every_tools_web_file_the_build_names_is_read():
    named = set()
    for script in BUILD:
        text = (ROOT / script).read_text(errors="ignore")
        named |= set(re.findall(r"tools/web/([A-Za-z0-9_.-]+\.(?:mjs|py|sh|json))", text))
    # And what those import, one step at a time (not what a check run on the
    # deployment imports: that is a check's module).
    named -= RUN_ON_IT
    todo = list(named)
    while todo:
        f = ROOT / "tools" / "web" / todo.pop()
        if not f.exists():
            continue
        text = f.read_text(errors="ignore")
        for dep in re.findall(r"""(?:from|import\()\s*['"]\./([a-z_0-9]+\.mjs)['"]""", text) + \
                re.findall(r"tools/web/([a-z_0-9]+\.py)", text):
            if dep not in named:
                named.add(dep)
                todo.append(dep)
    missing = sorted(n for n in named if (ROOT / "tools" / "web" / n).exists() and not reads(f"tools/web/{n}"))
    assert not missing, f"the build runs these, so deploy_reads.sh's DEPLOY_READS_WEB must name them: {missing}"


def test_unread_since_on_this_repo():
    # HEAD~0 is never "since" itself; an ancestor with only tests changed is.
    head = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    same = subprocess.run(["bash", "-c", f'cd "{ROOT}" && . "{LIB}" && unread_since "$1" "$1"', "_", head])
    assert same.returncode == 1
