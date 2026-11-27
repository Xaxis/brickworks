"""Best path traced in a browser (photoreal28): tools/web/tracer_port.py writes the desktop's
tracer as GLSL ES 3.00 into the page's tracer, and page_tracer.js's trees find what testing
every triangle finds (tests/web/page_tracer_tree.test.mjs, under node)."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PORT = ROOT / "tools/web/tracer_port.py"
NODE = shutil.which("node")


def test_port_writes_every_shader(tmp_path):
    reply = subprocess.run([sys.executable, str(PORT), "--glsl", str(tmp_path)], capture_output=True,
                           text=True, timeout=120)
    assert reply.returncode == 0, reply.stderr
    names = sorted(p.stem for p in tmp_path.glob("*.glsl"))
    assert names == ["marks", "photo", "plain", "resolve", "vertex"]
    for name in names:
        text = (tmp_path / f"{name}.glsl").read_text()
        assert text.startswith("#version 300 es\n"), name
        for left in ("traceRayEXT", "imageStore", "imageLoad", "std430", "gl_LaunchIDEXT"):
            assert left not in text, f"{left} left in {name}"
    # Each version is the desktop's: marks and photo say so, plain neither.
    assert "#define MARKS" in (tmp_path / "marks.glsl").read_text()
    assert "#define PHOTO" in (tmp_path / "photo.glsl").read_text()
    plain = (tmp_path / "plain.glsl").read_text()
    assert "#define MARKS\n#define" not in plain and "#define PHOTO\n" not in plain.split("#ifdef PHOTO")[0]
    # The trees are walked, and the closest hit is the desktop's, called as a function.
    assert "bool trace(vec3 from, vec3 way, float far, uint mask, uint flags)" in plain
    assert "void closest_hit() {" in plain


def test_port_fills_the_page_tracer(tmp_path):
    out = tmp_path / "tracer.js"
    reply = subprocess.run([sys.executable, str(PORT), "--js", str(out)], capture_output=True, text=True,
                           timeout=120)
    assert reply.returncode == 0, reply.stderr
    text = out.read_text()
    assert "const SHADERS = {" in text
    assert "const SHADERS = null;" not in text
    assert "export function start()" in text


@pytest.mark.skipif(NODE is None, reason="no node on PATH")
def test_trees_find_what_every_triangle_finds():
    reply = subprocess.run([NODE, "--test", str(ROOT / "tests/web/page_tracer_tree.test.mjs")],
                           capture_output=True, text=True, timeout=300)
    assert reply.returncode == 0, reply.stdout[-3000:] + reply.stderr[-2000:]
    assert "fail 0" in reply.stdout
