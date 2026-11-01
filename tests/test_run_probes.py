"""A release's probes run as tools/suite lists them (tools/probe.sh PROBE_LISTED)."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _yard(tmp_path: Path) -> Path:
    r = tmp_path / "repo"
    for d in ("tools/release", "tools/suite", "src/dev"):
        (r / d).mkdir(parents=True)
    for f in ("tools/probe.sh", "tools/release/run_probes.sh"):
        (r / f).write_text((ROOT / f).read_text())
        (r / f).chmod(0o755)
    (r / "tools/suite/windowed.txt").write_text(
        "# NAME or NAME:ARGS\nhover_cost   # bare\nopen_menu_reach:--phone   # forty saves\n"
        "motions_render:@out\n")
    (r / "tools/suite/headless.txt").write_text("command:--judge\n")
    for name, how in (("open_menu_reach", "--resolution 390x844"), ("hover_cost", "--resolution 1280x720"),
                      ("motions_render", "--resolution 1280x720"), ("command", "--headless")):
        (r / f"src/dev/{name}_probe.gd").write_text(
            f"## godot --path . {how} --script src/dev/{name}_probe.gd\nextends SceneTree\n")
    return r


def _dry(r: Path, *args: str, listed: bool = True) -> str:
    env = {**os.environ, "PROBE_DRY": "1", "PROBE_LISTED": "1" if listed else ""}
    out = subprocess.run(["bash", str(r / "tools/probe.sh"), *args], env=env, capture_output=True,
                         text=True, timeout=30)
    assert out.returncode == 0, out.stdout + out.stderr
    return out.stdout.splitlines()[-1].split(".gd", 1)[1].strip()


def test_a_probe_named_bare_runs_with_the_arguments_its_suite_line_gives(tmp_path):
    """rel-m234's train ran open_menu_reach bare, which the suite runs with --phone: it laid the
    desktop out in a phone's window and held the release. PROBE_LISTED takes the line's ARGS,
    @out a folder of the run's; ARGS given, or a probe listed bare, keep their own."""
    r = _yard(tmp_path)
    assert _dry(r, "open_menu_reach") == "-- --phone"
    assert _dry(r, "open_menu_reach_probe") == "-- --phone"
    assert _dry(r, "open_menu_reach", listed=False) == ""
    assert _dry(r, "command") == "-- --judge"
    assert _dry(r, "command", "--other") == "-- --other"
    assert _dry(r, "hover_cost") == ""
    assert _dry(r, "motions_render") == "-- /motions_render_probe"


def test_run_probes_and_the_train_ask_for_the_suites_arguments():
    """Both ways a release runs a probe set PROBE_LISTED."""
    assert "PROBE_LISTED=1 timeout 2400 tools/probe.sh" in (ROOT / "tools/release/run_probes.sh").read_text()
    assert "PROBE_LISTED=1 bash tools/probe.sh" in (ROOT / "tools/release/train.sh").read_text()
