"""tools/release/run_probes.sh: a release's probes run as the suite lists them."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_a_bare_name_runs_with_the_arguments_its_suite_line_gives(tmp_path):
    """rel-m234 named open_menu_reach, which the suite runs with --phone: run bare, it laid
    the desktop out in a phone's window and failed. A bare name takes its line's ARGS (and
    @out a folder of the run's); a name given with ARGS and a name listed bare keep theirs."""
    r = tmp_path / "repo"
    (r / "tools/release").mkdir(parents=True)
    (r / "tools/suite").mkdir(parents=True)
    (r / "tools/release/run_probes.sh").write_text((ROOT / "tools/release/run_probes.sh").read_text())
    probe = r / "tools/probe.sh"
    probe.write_text('#!/bin/bash\necho "args: $*"\necho "  ok    ran"\n')
    probe.chmod(0o755)
    (r / "tools/suite/windowed.txt").write_text(
        "# NAME or NAME:ARGS\nhover_cost   # bare\nopen_menu_reach:--phone   # forty saves\n"
        "motions_render:@out\n")
    (r / "tools/suite/headless.txt").write_text("command:--judge\n")
    subprocess.run(["git", "init", "-q", str(r)], check=True)
    subprocess.run(["git", "-C", str(r), "-c", "user.name=Xaxis", "-c", "user.email=william.neeley@gmail.com",
                    "commit", "-q", "--allow-empty", "-m", "yard"], check=True)
    prefix = tmp_path / "out" / "rel"
    prefix.parent.mkdir()
    run = subprocess.run(["bash", str(r / "tools/release/run_probes.sh"), str(prefix), "open_menu_reach",
                          "open_menu_reach_probe", "hover_cost", "command:--other", "motions_render", "nowhere"],
                         capture_output=True, text=True, timeout=60)
    assert run.returncode == 0, run.stdout + run.stderr

    def said(name: str) -> str:
        return Path(f"{prefix}_{name}.log").read_text().splitlines()[0]

    assert said("open_menu_reach") == "args: open_menu_reach --phone"
    assert said("open_menu_reach_probe") == "args: open_menu_reach_probe --phone"
    assert said("hover_cost") == "args: hover_cost"
    assert said("command") == "args: command --other"
    assert said("motions_render") == f"args: motions_render {prefix}_motions_render_out"
    assert said("nowhere") == "args: nowhere"
