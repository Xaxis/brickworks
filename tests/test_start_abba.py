"""tools/web/start_abba.mjs judges builds by their ratio at equal moments.

Its table is read from load_check's own load.json files, so these write
runs by hand and hold the verdict: an arm slower than the bar fails and
names the measure, an arm within it passes, and a load that rises through
each block slows both arms alike, so the pairing keeps it out of the ratio.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools/web/start_abba.mjs"


def node_order(names: list[str], blocks: int) -> list[dict]:
    script = (f'import {{ order }} from "{TOOL.as_posix()}";'
              f"console.log(JSON.stringify(order({json.dumps(names)}, {blocks})));")
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def write_runs(out: Path, arms: list[str], seconds) -> None:
    """Each run's load.json as load_check writes it; seconds(arm, block, n) gives
    (cold usable, cold compile, warm usable, warm compile), in seconds."""
    plan = node_order(arms, 2)
    out.mkdir(parents=True, exist_ok=True)
    (out / "arms.json").write_text(json.dumps({"arms": [{"name": a, "target": f"/b/{a}"} for a in arms],
                                               "blocks": 2, "bar": 10, "passed": [], "plan": plan}))
    lines = []
    for step in plan:
        cold, ccomp, warm, wcomp = seconds(step["arm"], step["block"], step["n"])
        run = out / f"{step['n']}_{step['arm']}"
        run.mkdir()
        summary = {
            "broadband cold": {"interactive": cold * 1000, "cpu": cold * 500, "bytes": 16.8e6, "split": {"compile": ccomp * 1000}},
            "broadband warm": {"interactive": warm * 1000, "cpu": warm * 500, "bytes": 0.1e6, "split": {"compile": wcomp * 1000}},
        }
        (run / "load.json").write_text(json.dumps({"url": "x", "summary": summary, "results": []}))
        load = {"one": 30.0, "five": 30.0, "fifteen": 30.0, "runnable": "20"}
        lines.append(json.dumps({**step, "started": "2026-11-09T00:00:00Z", "before": load, "after": load, "exit": 0}))
    (out / "runs.jsonl").write_text("\n".join(lines) + "\n")


def summary(out: Path) -> subprocess.CompletedProcess:
    return subprocess.run(["node", str(TOOL), "--summary", f"--out={out}"], cwd=ROOT, capture_output=True, text=True)


def test_order_runs_each_block_forward_and_back():
    assert [r["arm"] for r in node_order(["a", "b"], 2)] == ["a", "b", "b", "a", "a", "b", "b", "a"]
    three = node_order(["a", "l", "b"], 1)
    assert [r["arm"] for r in three] == ["a", "l", "b", "b", "l", "a"]
    assert [r["n"] for r in three] == [1, 2, 3, 4, 5, 6]


def test_a_compile_a_fifth_slower_fails_and_says_which(tmp_path):
    write_runs(tmp_path, ["m276", "pre261"],
               lambda arm, block, n: (12.0, 4.0 * (1.2 if arm == "pre261" else 1.0), 7.0, 4.0))
    got = summary(tmp_path)
    assert got.returncode == 1, got.stdout
    fails = [line for line in got.stdout.splitlines() if "FAIL" in line]
    assert any("compile, cold" in line and "x1.200" in line for line in fails), got.stdout
    assert not any("bin usable" in line for line in fails), got.stdout
    assert (tmp_path / "summary.txt").read_text().rstrip().endswith("start_abba: FAIL")


def test_a_rising_load_weighs_on_both_and_passes(tmp_path):
    # The load doubles the time from one run to the last; pre261 is 4% slower.
    # Unpaired, its runs late in each block would look slower or faster by
    # chance; paired by block, the ratio is the 4% alone.
    write_runs(tmp_path, ["m276", "pre261"],
               lambda arm, block, n: tuple(x * (1 + n / 8) * (1.04 if arm == "pre261" else 1.0) for x in (12.0, 4.0, 7.0, 3.0)))
    got = summary(tmp_path)
    assert got.returncode == 0, got.stdout
    line = next(line for line in got.stdout.splitlines() if "compile, warm" in line and " x" in line)
    assert line.split()[0] == "ok" and "x1.040" in line, line
    assert got.stdout.rstrip().endswith("start_abba: ok")


def test_an_arm_with_most_runs_lost_fails(tmp_path):
    write_runs(tmp_path, ["m276", "pre261"], lambda arm, block, n: (12.0, 4.0, 7.0, 3.0))
    for run in tmp_path.glob("*_pre261"):
        if run.name != "2_pre261":
            (run / "load.json").unlink()
    got = summary(tmp_path)
    assert got.returncode == 1
    assert "FAIL pre261: 1 of 4 runs gave a result" in got.stdout
