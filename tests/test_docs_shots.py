"""The docs' pictures (tools/docs_shots.py, docs-site/pictures/) stay made and
current: the docs check fails on a picture missing or not what its run made,
on a page naming a feature the feature map no longer has, and on a feature
in the map with no page, and passes on the docs as they are."""

from __future__ import annotations

import importlib.util
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

_spec = importlib.util.spec_from_file_location("docs_site_for_shots", ROOT / "tools/docs_site.py")
docs_site = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(docs_site)
shots = docs_site.docs_shots


def _pages() -> dict[str, str]:
    return {p.stem: p.read_text(encoding="utf-8") for p in (ROOT / "docs-site").glob("*.md")
            if not p.stem.startswith("_")}


def test_every_picture_is_made_and_shown_on_its_page() -> None:
    assert shots.shots(), "docs-site/pictures/ names no picture"
    problems = shots.problems(_pages())
    assert not problems, "\n".join(problems)


def test_a_missing_picture_fails(monkeypatch, tmp_path: Path) -> None:
    img = tmp_path / "img"
    shutil.copytree(shots.IMG, img)
    gone = shots.names(shots.shots()[0])[0]
    (img / f"{gone}.webp").unlink()
    monkeypatch.setattr(shots, "IMG", img)
    monkeypatch.setattr(shots, "LOCK", img / "shots.lock")
    problems = shots.problems(_pages())
    assert any(p.startswith(f"docs-site/img/{gone}.webp is missing") for p in problems), problems


def test_a_picture_changed_by_hand_fails(monkeypatch, tmp_path: Path) -> None:
    img = tmp_path / "img"
    shutil.copytree(shots.IMG, img)
    name = shots.names(shots.shots()[0])[0]
    with (img / f"{name}.webp").open("ab") as picture:
        picture.write(b"\0" * 16)
    monkeypatch.setattr(shots, "IMG", img)
    monkeypatch.setattr(shots, "LOCK", img / "shots.lock")
    problems = shots.problems(_pages())
    assert any(f"{name}.webp is not what tools/docs_shots.py made" in p for p in problems), problems


def _features_without(tmp_path: Path, drop: str = "", add: dict | None = None) -> Path:
    data = json.loads(docs_site.FEATURES.read_text(encoding="utf-8"))
    data["features"] = [f for f in data["features"] if f["id"] != drop] + ([add] if add else [])
    path = tmp_path / "features.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def test_a_page_naming_a_feature_the_map_no_longer_has_fails(monkeypatch, tmp_path: Path) -> None:
    """A feature renamed or gone from .claude/skills/verify/features.json, still
    named by a page's covers and by a picture's features."""
    shown = next(f for s in shots.shots() for f in s.get("features", []))
    path = _features_without(tmp_path, drop=shown)
    monkeypatch.setattr(docs_site, "FEATURES", path)
    monkeypatch.setattr(shots, "FEATURES", path)
    problems = docs_site.check()
    assert any(f"covers {shown}, which the feature map does not have" in p for p in problems), problems
    assert any(f"shows {shown}, which the feature map does not have" in p for p in problems), problems


def test_a_feature_with_no_page_fails(monkeypatch, tmp_path: Path) -> None:
    planted = {"id": "ui:a planted panel", "kind": "ui", "entry": "src/ui/planted_panel.gd", "reach": "",
               "area": "ui", "tests": []}
    path = _features_without(tmp_path, add=planted)
    monkeypatch.setattr(docs_site, "FEATURES", path)
    monkeypatch.setattr(shots, "FEATURES", path)
    problems = docs_site.check()
    assert any(p.startswith("ui:a planted panel (src/ui/planted_panel.gd) is in no docs page") for p in problems), problems


def test_a_pictures_words_on_its_page_are_its_manifests() -> None:
    shot = shots.shots()[0]
    line = f'![Something else](/docs/img/{shot["id"]}.webp "Not its caption")'
    written = shots.with_words(f"Before\n\n{line}\n\nAfter\n")
    assert f'![{shot["alt"]}](/docs/img/{shot["id"]}.webp' in written
    assert "Something else" not in written and "Not its caption" not in written


def test_a_picture_is_drawn_at_its_size_lazily_and_opens_whole() -> None:
    shot = next(s for s in shots.shots() if s.get("source") == "app")
    figure = docs_site.shot_figure(f"/docs/img/{shot['id']}.webp", shot["alt"], "")
    width, height = shots.webp_size(shots.IMG / f"{shot['id']}.webp")
    assert f'width="{width}" height="{height}"' in figure
    assert 'loading="lazy"' in figure and f'href="/docs/img/{shot["id"]}.webp"' in figure


def test_a_picture_of_the_site_has_one_a_theme() -> None:
    site = [s for s in shots.shots() if s.get("source") == "site" and len(s.get("themes", [])) > 1]
    if not site:
        return
    figure = docs_site.shot_figure(f"/docs/img/{site[0]['id']}.webp", site[0]["alt"], "")
    assert figure.count("<img ") == 2 and 'shot-open on-dark' in figure and 'shot-open on-light' in figure


def test_the_built_docs_carry_every_picture(tmp_path: Path) -> None:
    docs_site.build(tmp_path)
    for shot in shots.shots():
        for name in shots.names(shot):
            assert (tmp_path / "docs/img" / f"{name}.webp").exists(), name
        page = tmp_path / ("docs.html" if shot["page"] == "index" else f"docs/{shot['page']}.html")
        assert f'id="shot-{shot["id"]}"' in page.read_text(encoding="utf-8"), shot["id"]
