"""A picture the browser drops under load is taken again (tools/web/steady_shots.mjs).

rel-m284's app_menu failed on "Unable to capture screenshot" and rel-m283's docs
on a capture past its 30 s, each after every step had passed. steadyShots wraps
page.screenshot: a dropped capture is tried again, twice at most; any other
error, and a third drop, still reach the check.
"""

import json
import shutil
import subprocess
import pytest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SCRIPT = r"""
import { steadyShots, CAPTURE_TRIES } from "./tools/web/steady_shots.mjs";
function page(failures) {
  let calls = 0; const seen = [];
  return { calls: () => calls, seen, isClosed: () => false,
    async screenshot(options) { calls += 1; seen.push(options.timeout);
      if (calls <= failures.length) throw new Error(failures[calls - 1]); return Buffer.from("png"); } };
}
const quiet = { pauseMs: 1, log: () => {} };
const out = {};
const once = steadyShots(page(["page.screenshot: Protocol error (Page.captureScreenshot): Unable to capture screenshot"]), quiet);
out.once = { got: String(await once.screenshot({ path: "x" })), calls: once.calls(), timeout: once.seen[0] };
const late = steadyShots(page(["page.screenshot: Timeout 30000ms exceeded.", "page.screenshot: Timeout 30000ms exceeded."]), quiet);
out.late = { got: String(await late.screenshot({ timeout: 5000 })), calls: late.calls(), timeout: late.seen[0] };
const real = steadyShots(page(["Target page, context or browser has been closed"]), quiet);
out.real = await real.screenshot({}).then(() => "taken", (e) => e.message);
out.realCalls = real.calls();
const never = steadyShots(page(Array(CAPTURE_TRIES).fill("Unable to capture screenshot")), quiet);
out.never = await never.screenshot({}).then(() => "taken", (e) => e.message);
out.neverCalls = never.calls();
const twice = steadyShots(steadyShots(page(["Unable to capture screenshot"]), quiet), quiet);
await twice.screenshot({}); out.twiceCalls = twice.calls();
console.log(JSON.stringify(out));
"""


_OUT = None


def _out() -> dict:
    global _OUT
    if _OUT is None:
        done = subprocess.run(["node", "--input-type=module", "-e", SCRIPT], cwd=ROOT, capture_output=True,
                              text=True, timeout=60)
        assert done.returncode == 0, done.stderr
        _OUT = json.loads(done.stdout.strip().splitlines()[-1])
    return _OUT


needs_node = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


@needs_node
def test_a_dropped_capture_is_taken_again():
    assert _out()["once"] == {"got": "png", "calls": 2, "timeout": 120000}


@needs_node
def test_a_late_capture_is_taken_again_in_the_callers_own_time():
    assert _out()["late"] == {"got": "png", "calls": 3, "timeout": 5000}


@needs_node
def test_any_other_error_goes_straight_to_the_check():
    assert "has been closed" in _out()["real"]
    assert _out()["realCalls"] == 1


@needs_node
def test_a_page_that_never_draws_still_fails():
    assert "Unable to capture screenshot" in _out()["never"]
    assert _out()["neverCalls"] == 3


@needs_node
def test_wrapped_once_however_often_it_is_asked():
    assert _out()["twiceCalls"] == 2
