"""The functions as tools/deploy.sh ships them (tools/package_api.sh) read the catalogue's facts from
their own folders: a part by the number it means today and a colour by the one a shop files it under,
as the app's Collection.key_of. rel-m285 gave _part_facts.json to /api/share alone, so a Rebrickable
fetch's marks were counted by the number each was written with in production (lb2check M2)."""
from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "assets/generated/catalogue.json"
INDEX = ROOT / "assets/generated/sets/index.json"
ready = pytest.mark.skipif(shutil.which("node") is None or not CATALOGUE.exists() or not INDEX.exists(),
                           reason="no node, or no catalogue and set index (tools/build_meshes.py, tools/collection_data.py)")


def package(out: Path, *routes: str) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", str(ROOT / "tools/package_api.sh"), str(out), *routes], cwd=ROOT,
                          capture_output=True, text=True, timeout=300)


def owned_routes() -> set[str]:
    """Every route whose own file or a shared module it imports reads api/_owned.js."""
    imports = {path.name: set(re.findall(r'from "\./(_[a-z_]+\.js)"', path.read_text()))
               for path in (ROOT / "api").glob("*.js")}
    def reaches(name: str, seen: set[str]) -> bool:
        if name == "_owned.js":
            return True
        seen.add(name)
        return any(reaches(one, seen) for one in imports.get(name, ()) if one not in seen)
    return {name[:-3] for name in imports if not name.startswith("_") and reaches(name, set())}


@ready
def test_every_function_that_counts_parts_reads_the_facts_packaged(tmp_path: Path) -> None:
    routes = owned_routes()
    # The routes this was found in: if a grep finds none, it reads the wrong thing.
    assert {"collection", "admin", "share"} <= routes, routes
    asked = sorted(routes - {"share"})  # share needs a web export's part names
    done = package(tmp_path, *asked)
    assert done.returncode == 0, done.stdout + done.stderr
    assert f"packaged facts: {len(asked)} functions each read" in done.stdout, done.stdout
    said = subprocess.run(["node", "--input-type=module", "-e", """
const owned = await import(process.argv[1]);
const facts = owned.ownedFacts();
console.log(JSON.stringify({ moved: facts.moved.size, plain: facts.plain.size, known: facts.known?.size ?? 0,
  key: `${owned.resolvePart("4073")}/${owned.plainColour(256)}` }));
""", str(tmp_path / "api/collection.func/_owned.js")], capture_output=True, text=True, timeout=60)
    facts = json.loads(said.stdout)
    assert facts["moved"] > 0 and facts["plain"] > 0 and facts["known"] > 10000, facts
    # The two spellings lb2check marked a part under, read as the one the app reads.
    assert facts["key"] == "6141/0", facts
    assert (tmp_path / "api/collection.func/_collection_index.json").exists()


@ready
def test_a_function_packaged_without_them_fails_the_package(tmp_path: Path) -> None:
    done = package(tmp_path, "collection")
    assert done.returncode == 0, done.stdout + done.stderr
    (tmp_path / "api/collection.func/_part_facts.json").unlink()
    check = subprocess.run(["node", str(ROOT / "tools/web/packaged_facts.mjs"), str(tmp_path), "collection"],
                           cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert check.returncode == 1 and "FAILED collection: known none, moved 0" in check.stdout, check.stdout
