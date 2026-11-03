"""Production is the release train's: tools/deploy.sh refuses --prod and --promote unless ship.sh
asks (SHIP_DEPLOY) or the lead names why (PROD_BY_HAND). A unit's own --prod put 0.15.0's download
page on brickworks.diy with none of its checks run (2026-11-03)."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _deploy(tmp_path: Path, *args: str, **env: str) -> subprocess.CompletedProcess:
    """deploy.sh copied alone into an empty checkout: whatever it would go on to do (the meshes,
    the export, Vercel) finds nothing there, so even a deploy.sh without the guard cannot ship.
    A first version ran the real one, which without its guard began a production deploy."""
    (tmp_path / "tools").mkdir(exist_ok=True)
    (tmp_path / "tools/deploy.sh").write_text((ROOT / "tools/deploy.sh").read_text())
    clean = {k: v for k, v in os.environ.items() if k not in ("SHIP_DEPLOY", "PROD_BY_HAND")}
    clean["PATH"] = "/usr/bin:/bin"
    return subprocess.run(["bash", str(tmp_path / "tools/deploy.sh"), *args], env={**clean, **env},
                          capture_output=True, text=True, timeout=30)


def test_production_by_hand_is_refused_and_says_how(tmp_path):
    for args in (["--prod"], ["--promote=https://brickworks-x.vercel.app"]):
        out = _deploy(tmp_path, *args)
        assert out.returncode == 2, out.stdout + out.stderr
        assert "production is the release train's" in out.stdout, out.stdout
        assert "PROD_BY_HAND=" in out.stdout, out.stdout


def test_a_preview_is_not_held_by_it(tmp_path):
    # --prod --unit fails on its own rule, which comes first: the guard is for production alone.
    out = _deploy(tmp_path, "--unit", "--prod")
    assert "--unit is a preview, never --prod" in out.stdout, out.stdout


def test_the_ship_asks_for_both_of_its_production_steps():
    ship = (ROOT / "tools/release/ship.sh").read_text()
    assert "SHIP_DEPLOY=1 timeout 900 tools/deploy.sh --promote=" in ship
    assert "SHIP_DEPLOY=1 timeout 10800 ~/.claude/claude-core/bin/heavy timeout 3000 tools/deploy.sh --prod" in ship
