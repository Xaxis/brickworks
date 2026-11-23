"""A model's page and its 3D view show the same version, even when the CDN
kept the page from before a publish (api/share.js sceneAt, web/model-page.js
load), made by the real handler from the design stand-in's world
(tools/web/design_stand_in.mjs), with no network. The watchtower's newest
version is 2.

- Each version's page names its 3D view's scene by that version's number,
  the newest's too: /m/<id>/v/2/scene.json on /m/<id>, /m/<id>/v/1/scene.json
  on /m/<id>/v/1. /m/<id>/scene.json is kept by the CDN as long as the page,
  so a page drawn after a publish opened the version before's model and
  placed every comment's pin on it (partpins, rel-m321 to rel-m325's
  previews).
- That address is answered with that version's own model.
The page itself, kept by the CDN from before a publish, asks for the newest
anew once its comments (never kept) say a newer one is out: a browser's
part, proved by tools/web/partpins_flow.mjs on a deployment."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ID = "DesignAbc1"


def pages(paths: list[str]) -> list[dict] | None:
    """Each address in [paths] as the stand-in's server answers it:
    {status, html}."""
    if shutil.which("node") is None:
        return None
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "const out = [];"
        f"for (const one of {json.dumps(paths)}) {{ const r = await s.serverPage('api', one);"
        "  out.push({ status: r.status, html: r.html || (r.bytes ? Buffer.from(r.bytes).toString('utf8') : '') }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=180)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def scene_of(html: str) -> str:
    found = re.search(r'<a class="picture" id="model-picture"[^>]*data-scene="([^"]+)"', html)
    return found.group(1) if found else ""


def test_each_version_names_its_own_scene():
    out = pages([f"/m/{ID}", f"/m/{ID}/v/1", f"/m/{ID}/v/2/scene.json", f"/m/{ID}/v/1/scene.json"])
    if out is None:
        return
    newest, older, two, one = out
    assert newest["status"] == 200 and older["status"] == 200
    assert 'data-version="2" data-newest="2"' in newest["html"]
    assert scene_of(newest["html"]) == f"/m/{ID}/v/2/scene.json"
    assert scene_of(older["html"]) == f"/m/{ID}/v/1/scene.json"
    # Each answered with its own version's model, told apart by what it is of.
    assert two["status"] == 200 and one["status"] == 200
    assert json.loads(two["html"])["of"] == f"m:{ID}:2"
    assert json.loads(one["html"])["of"] == f"m:{ID}:1"

