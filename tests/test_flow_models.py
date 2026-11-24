"""The models the browser flows publish, read from tests/fixtures/flow_models.

rel-m331's train was held on comments: the flow made its two models with
godot from its own tree, a web-lane tree is never imported, so godot wrote
nothing and the flow died on ENOENT four seconds in (2026-11-24). Now the
flows read fixed models (tools/web/flow_models.mjs), which
src/dev/flow_models_probe.gd holds to what the app writes today, and a check
that runs the engine as it goes is one train.sh keeps off the web lane.

Here, with no engine: each model, the run's token put in, is one the server
takes as it takes the app's (api/_versions.js reads its steps, api/_tested.js
keeps its finding); the token makes each run's model its own; the flows run
no godot; and preview_checks.sh names as ENGINE_CHECKS every check whose flow
starts the engine, and no other.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests/fixtures/flow_models"
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()
FLOWS = ["comments_flow", "versions_flow", "tested_flow", "share_steps_flow"]
# A flow starting the engine: godot itself, under xvfb-run, or a probe.
ENGINE = re.compile(r"""spawn(?:Sync)?\(\s*["'](?:godot|xvfb-run)["']|tools/probe\.sh""")


def node(script: str):
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True, timeout=120).stdout)


def models(token: str) -> dict:
    """Each fixture as flowModel gives it with [token]: what the server makes of it."""
    return node(f"""
import {{ flowModel, fixtureNames }} from "./tools/web/flow_models.mjs";
import {{ stepsOf }} from "./api/_versions.js";
import {{ checkTested }} from "./api/_tested.js";
import {{ modelHash }} from "./api/_directory.js";
const out = {{}};
for (const name of fixtureNames()) {{
  const {{ text, tested }} = flowModel(name, {json.dumps(token)});
  const kept = tested ? checkTested(tested, text) : null;
  out[name] = {{ steps: (stepsOf(text) || []).length, hash: modelHash(text), first: text.split("\\r\\n")[0],
    token: text.includes({json.dumps(token)}), placeholder: text.includes("runtoken"),
    kept: kept && kept.row ? {{ passed: kept.row.passed, app: kept.row.app }} : (kept ? {{ refused: kept.refused }} : null) }};
}}
const passed = flowModel("tested_passed", {json.dumps(token)}).tested;
out.forged = checkTested(passed, flowModel("tested_none", {json.dumps(token)}).text);
console.log(JSON.stringify(out));
""")


def version() -> str:
    return re.search(r'^config/version="([^"]*)"', (ROOT / "project.godot").read_text(), re.M).group(1)


def test_each_model_with_a_runs_token_is_one_the_server_takes_as_the_apps() -> None:
    said = models("ab12cd34")
    forged = said.pop("forged")
    assert sorted(said) == ["comments_v1", "comments_v2", "share_steps_1000", "share_steps_300", "share_steps_4000",
                            "tested_failed", "tested_none", "tested_passed", "versions_v1", "versions_v2"]
    for name, one in said.items():
        # Its steps read by the server for this very text: the head names the text with the token in it.
        assert one["steps"] >= 3, (name, one)
        assert not one["placeholder"], (name, one)
    assert [said[n]["steps"] for n in ("comments_v1", "versions_v1", "tested_passed")] == [6, 6, 3]
    assert said["comments_v1"]["token"] and said["tested_passed"]["first"] == "0 Tested Flow Stack ab12cd34"
    # The app's finding kept as the app's, of this text, made by this tree's app.
    assert said["tested_passed"]["kept"] == {"passed": True, "app": version()}
    assert said["tested_failed"]["kept"] == {"passed": False, "app": version()}
    assert said["tested_none"]["kept"] is None
    assert forged == {"refused": "the finding is of another file"}


def test_the_token_makes_each_runs_model_its_own() -> None:
    one, two = models("ab12cd34"), models("ef56ab78")
    for name in ("comments_v1", "comments_v2", "tested_passed", "tested_failed", "tested_none"):
        assert one[name]["hash"] != two[name]["hash"], name
        assert one[name]["steps"] == two[name]["steps"], name
    # A model with no token is the same file every run, as the flow made it.
    assert one["versions_v1"]["hash"] == two["versions_v1"]["hash"]


def test_the_flows_that_publish_them_run_no_engine_and_read_them() -> None:
    for flow in FLOWS:
        source = (ROOT / "tools/web" / (flow + ".mjs")).read_text()
        assert not ENGINE.search(source), flow
        assert 'from "./flow_models.mjs"' in source and "flowModel(" in source, flow
    # Each size the share steps check publishes is kept, and the flow's own default.
    sizes = re.search(r'\[share_steps\]="[^"]*--sizes=([0-9,]+)', CHECKS).group(1).split(",")
    default = re.search(r'args\.sizes \|\| "([0-9,]+)"', (ROOT / "tools/web/share_steps_flow.mjs").read_text()).group(1)
    for n in set(sizes) | set(default.split(",")):
        assert (FIXTURES / ("share_steps_%s.ldr" % n)).exists(), n


def test_engine_checks_are_exactly_the_checks_whose_flows_start_the_engine() -> None:
    engine = set(re.search(r'^ENGINE_CHECKS="([a-z_0-9 ]*)"', CHECKS, re.M).group(1).split())
    starts = set()
    for name, script in re.findall(r'^\s*\[([a-z_0-9]+)\]="(?:\S+ )*?(tools/web/[a-z_0-9]+\.mjs)', CHECKS, re.M):
        if ENGINE.search((ROOT / script).read_text()):
            starts.add(name)
    assert starts == engine == {"together"}
