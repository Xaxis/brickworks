"""tools/deploy.sh runs its three browser checks side by side (check.mjs, fit_check.mjs and the
landing page), where one after another they were five of a release's eleven minutes (fastship,
2026-11-23). Each is still a gate with its old words, read in the old order whatever order they
end in: the first that fails is the one said, and the others are stopped rather than waited for.
--no-fit leaves out the fit check alone.

deploy.sh runs here in a checkout of its own, --dir with a made-up build, every tool it calls a
stand-in: nothing reaches Vercel or a browser (the npx and node on its PATH are this test's)."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
URL = "https://brickworks-stand-in.vercel.app"
SENT_BR = ["index.wasm", "index.pck", "index.data.pck", "index.parts.bin", "index.primitives.bin",
           "index.hdri.bin", "index.fonts.bin", "index.js"]

# Stands in for node: each check sleeps and exits as the test says (STUB_<NAME>_SLEEP and
# _EXIT), and writes down when it began and ended. One process, so a TERM ends it.
NODE = """#!/usr/bin/python3
import os, sys, time
name = {"check.mjs": "APP", "fit_check.mjs": "FIT", "landing_check.mjs": "LANDING"}[os.path.basename(sys.argv[1])]
log = os.environ["STUB_LOG"]
with open(log, "a") as out:
    out.write(f"{name} start {time.time()}\\n")
print(f"{name.lower()} says its words")
sys.stdout.flush()
time.sleep(float(os.environ.get(f"STUB_{name}_SLEEP", "0")))
with open(log, "a") as out:
    out.write(f"{name} end {time.time()}\\n")
sys.exit(int(os.environ.get(f"STUB_{name}_EXIT", "0")))
"""
NPX = f"""#!/bin/bash
echo "Preview: {URL}"
"""
CURL = """#!/bin/bash
echo -n "${STUB_LANDING_CODE:-200}"
"""
SITE = """import pathlib, sys
out = pathlib.Path(sys.argv[1])
for page in ("index.html", "404.html", "download.html", "de/index.html", "de/404.html", "docs/start.html"):
    (out / page).parent.mkdir(parents=True, exist_ok=True)
    (out / page).write_text("<html></html>")
"""


@pytest.fixture
def checkout(tmp_path):
    co = tmp_path / "co"
    (co / "tools/web/node_modules/playwright").mkdir(parents=True)
    shutil.copy(ROOT / "tools/deploy.sh", co / "tools/deploy.sh")
    (co / "tools/storage_parts.py").write_text("print('  already up: 3')\nprint('  to upload : 0  (0 MB)')\n")
    (co / "tools/package_api.sh").write_text('#!/bin/bash\nmkdir -p "$1"\n')
    (co / "tools/package_api.sh").chmod(0o755)
    (co / "tools/site.py").write_text(SITE)
    (co / "tools/web/place_build.py").write_text("print('0123456789abcdef')\n")
    build = co / "build/web"
    (build / "knowledge").mkdir(parents=True)
    (build / "index.html").write_text("<html><script>start()</script></html>")
    for name in SENT_BR:
        (build / name).write_bytes(b"x")
        (build / f"{name}.br").write_bytes(b"x")
    (build / "knowledge/snippets.json.gz").write_bytes(b"x")
    (build / "knowledge/part_looks.json").write_text("{}")
    sets = co / "assets/generated/sets"
    sets.mkdir(parents=True)
    for name in ("index.json", "models.json", "all_sets.bin"):
        (sets / name).write_text("{}")
    (co / "docs-site").mkdir()
    (co / "docs-site/_moved.json").write_text("{}")
    (co / "src/ai").mkdir(parents=True)
    (co / "src/ai/provider_settings.gd").write_text(
        '"base": "https://api.anthropic.com/v1"\n"base": "https://api.openai.com/v1"\n')
    (co / ".vercel").mkdir()
    (co / ".vercel/project.json").write_text(json.dumps({"orgId": "team_x", "projectId": "prj_x"}))
    stubs = tmp_path / "stubs"
    stubs.mkdir()
    for name, body in (("node", NODE), ("npx", NPX), ("curl", CURL)):
        (stubs / name).write_text(body)
        (stubs / name).chmod(0o755)
    git = ["git", "-C", str(co), "-c", "user.name=t", "-c", "user.email=t@example.com"]
    subprocess.run([*git, "init", "-q"], check=True)
    subprocess.run([*git, "add", "-A"], check=True)
    subprocess.run([*git, "commit", "-q", "-m", "stand-in"], check=True)
    return co, stubs, tmp_path / "checks.log"


def deploy(checkout, *args, **stub):
    co, stubs, log = checkout
    env = {"PATH": f"{stubs}:/usr/bin:/bin", "HOME": str(co.parent), "TMPDIR": str(co.parent),
           "VERCEL_TOKEN": "stand-in", "STUB_LOG": str(log), **stub}
    began = time.time()
    out = subprocess.run(["bash", str(co / "tools/deploy.sh"), "--dir=build/web", "--unit", *args],
                         env=env, capture_output=True, text=True, timeout=90)
    return out, time.time() - began


def times(checkout) -> dict[str, dict[str, float]]:
    seen: dict[str, dict[str, float]] = {}
    log = checkout[2]
    for line in log.read_text().splitlines() if log.exists() else []:
        name, what, at = line.split()
        seen.setdefault(name, {})[what] = float(at)
    return seen


def test_the_three_run_side_by_side_and_all_must_pass(checkout):
    out, took = deploy(checkout, STUB_APP_SLEEP="2", STUB_FIT_SLEEP="2", STUB_LANDING_SLEEP="2")
    assert out.returncode == 0, out.stdout + out.stderr
    assert "deploy: landing page ok, app runs" in out.stdout
    assert out.stdout.rstrip().endswith(f"deploy done {URL}")
    ran = times(checkout)
    assert set(ran) == {"APP", "FIT", "LANDING"}
    assert max(r["start"] for r in ran.values()) < min(r["end"] for r in ran.values()), ran
    assert took < 5.5, f"{took:.1f} s: one after another"


def test_their_words_are_said_in_the_old_order_whichever_ends_first(checkout):
    out, _ = deploy(checkout, STUB_APP_SLEEP="2", STUB_FIT_SLEEP="1", STUB_LANDING_SLEEP="0")
    assert out.returncode == 0, out.stdout + out.stderr
    said = out.stdout
    assert said.index("app says") < said.index("fit says") < said.index("landing says") \
        < said.index("landing page ok")


def test_the_app_not_running_fails_at_once_and_stops_the_others(checkout):
    out, took = deploy(checkout, STUB_APP_EXIT="1", STUB_FIT_SLEEP="60", STUB_LANDING_SLEEP="60")
    assert out.returncode == 1, out.stdout + out.stderr
    assert f"deploy FAILED: the build does not run at {URL}/app" in out.stdout
    assert "deploy done" not in out.stdout and "fit says" not in out.stdout
    assert took < 30, f"{took:.1f} s: waited for the checks it had already failed past"
    ran = times(checkout)
    assert "end" not in ran["FIT"] and "end" not in ran["LANDING"], ran


@pytest.mark.parametrize(("code", "words"), [
    ("2", "deploy FAILED: the app did not start at every size at {URL}/app"),
    ("1", "deploy FAILED: the app does not fit the page at {URL}/app"),
])
def test_a_fit_that_fails_says_which_way(checkout, code, words):
    out, _ = deploy(checkout, STUB_FIT_EXIT=code)
    assert out.returncode == 1, out.stdout + out.stderr
    assert words.format(URL=URL) in out.stdout
    assert "deploy done" not in out.stdout


def test_a_landing_page_that_answers_otherwise_fails(checkout):
    out, _ = deploy(checkout, STUB_LANDING_CODE="404")
    assert out.returncode == 1, out.stdout + out.stderr
    assert f"deploy FAILED: the landing page answers 404 at {URL}/" in out.stdout
    assert "LANDING" not in times(checkout), "the browser opened a page that answered 404"


def test_a_landing_page_that_does_not_hold_together_fails(checkout):
    out, _ = deploy(checkout, STUB_LANDING_EXIT="1")
    assert out.returncode == 1, out.stdout + out.stderr
    assert f"deploy FAILED: the landing page does not hold together at {URL}/" in out.stdout


def test_no_fit_leaves_out_the_fit_check_alone(checkout):
    out, _ = deploy(checkout, "--no-fit", STUB_FIT_EXIT="1")
    assert out.returncode == 0, out.stdout + out.stderr
    assert "deploy: no fit check (--no-fit)" in out.stdout
    assert set(times(checkout)) == {"APP", "LANDING"}
    assert out.stdout.rstrip().endswith(f"deploy done {URL}")


def test_the_checks_tempdir_goes(checkout):
    deploy(checkout)
    assert not list(checkout[0].parent.glob("brickworks-checks.*"))
    assert not list(checkout[0].parent.glob("brickworks-deploy.*")), os.listdir(checkout[0].parent)
