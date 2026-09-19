"""Reading the generated catalogue, and the part facts a designer needs.

Two audiences, one source. The validator needs exact collision boxes and
socket positions; the language model needs a short, honest description of
what a part *is* — "Brick 2 x 4, covers 2 by 4 studs, 3 plates tall" —
because it cannot be handed 24,731 entries and is not owed geometry it
has no way to check.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw import meshfile  # noqa: E402

GENERATED = ROOT / "assets" / "generated"

STUD = 20.0
PLATE = 8.0
CELL = 2.0
CELLS_PER_STUD = int(STUD / CELL)
CELLS_PER_PLATE = int(PLATE / CELL)


@dataclass(slots=True)
class Part:
    id: str
    name: str
    category: str
    kind: str
    mesh: str
    triangles: int
    size_ldu: tuple[float, float, float]
    bounds_min: tuple[float, float, float]
    bounds_max: tuple[float, float, float]
    stud_count: int
    socket_count: int
    connector_counts: dict[str, int]
    recolourable: bool
    unofficial: bool
    moved_to: str = ""

    # Filled on demand from the .lbm.
    boxes: list[tuple[int, ...]] = field(default_factory=list)
    sockets: list[tuple[float, float]] = field(default_factory=list)
    loaded: bool = False

    @property
    def width(self) -> int:
        """Footprint across, in whole studs, rounded up."""
        return max(1, round(self.size_ldu[0] / STUD))

    @property
    def depth(self) -> int:
        return max(1, round(self.size_ldu[2] / STUD))

    @property
    def height_plates(self) -> int:
        """Body height in plates, not counting the studs on top.

        The stud adds 4 LDU to the measured extent, so the body is the
        extent less that, rounded to whole plates. A part shorter than a
        plate still counts as one: a tile is one plate tall.
        """
        body = self.size_ldu[1]
        if self.stud_count > 0:
            body -= 4.0
        return max(1, round(body / PLATE))

    def describe(self) -> str:
        """One line, for a model that has to choose between parts."""
        shape = f"{self.width}x{self.depth}"
        tall = f"{self.height_plates} plate" + (
            "s" if self.height_plates != 1 else "")
        bits = [f"{self.id}: {self.name.strip()}", f"covers {shape} studs", tall]
        if self.stud_count:
            bits.append(f"{self.stud_count} studs on top")
        else:
            bits.append("no studs on top")
        return ", ".join(bits)


class Catalogue:
    """Every part, with geometry loaded lazily."""

    def __init__(self, generated: Path = GENERATED) -> None:
        self.root = Path(generated)
        path = self.root / "catalogue.json"
        if not path.exists():
            raise FileNotFoundError(
                f"no catalogue at {path} — run tools/build_meshes.py")

        document = json.loads(path.read_text())
        self.cell_ldu: float = float(document.get("cell_ldu", CELL))
        self.parts: dict[str, Part] = {}
        for entry in document.get("parts", []):
            part = _read(entry)
            self.parts[part.id] = part

        colors_path = self.root / "colors.json"
        self.colors: dict[int, dict[str, Any]] = {}
        if colors_path.exists():
            for entry in json.loads(colors_path.read_text()):
                self.colors[int(entry["code"])] = entry

    def __contains__(self, part_id: str) -> bool:
        return part_id in self.parts

    def __len__(self) -> int:
        return len(self.parts)

    def resolve(self, part_id: str) -> str:
        """Follow a redirect stub to the part that replaced it."""
        seen: set[str] = set()
        current = part_id
        while current not in seen:
            seen.add(current)
            part = self.parts.get(current)
            if part is None or not part.moved_to:
                return current
            current = part.moved_to
        return part_id

    def get(self, part_id: str) -> Part | None:
        part = self.parts.get(part_id)
        if part is not None and not part.loaded:
            self._load_geometry(part)
        return part

    def _load_geometry(self, part: Part) -> None:
        part.loaded = True
        path = self.root / "parts" / f"{part.mesh}.lbm"
        if not path.exists():
            return
        mesh = meshfile.read(path.read_bytes())
        part.boxes = [tuple(int(v) for v in box) for box in mesh.boxes]
        part.sockets = [(float(x), float(z)) for x, z in mesh.sockets]

    def sizes(self) -> dict[str, tuple[int, int, int]]:
        """Part id -> (width, depth, height in plates), for LDraw export."""
        return {
            p.id: (p.width, p.depth, p.height_plates)
            for p in self.parts.values()
        }

    def search(self, query: str, limit: int = 40) -> list[Part]:
        """Parts whose name, id or category contains every word given."""
        needles = [w for w in query.lower().split() if w]
        if not needles:
            return []
        found: list[Part] = []
        for part in self.parts.values():
            # Never offer a redirect stub. It renders, but "~Moved to
            # 3665" is not a part, and a model that picks one has picked
            # a name rather than a thing.
            if part.moved_to:
                continue
            haystack = f"{part.id} {part.name} {part.category}".lower()
            if all(n in haystack for n in needles):
                found.append(part)
                if len(found) >= limit:
                    break
        # Official, simple parts first: they are the ones people have.
        found.sort(key=lambda p: (p.unofficial, p.triangles))
        return found

    def color_name(self, code: int) -> str:
        entry = self.colors.get(code)
        return entry["name"] if entry else f"Unknown {code}"


def _read(entry: dict[str, Any]) -> Part:
    return Part(
        id=str(entry["id"]),
        name=str(entry.get("name", "")),
        category=str(entry.get("category", "")),
        kind=str(entry.get("kind", "Part")),
        mesh=str(entry.get("mesh", "")),
        triangles=int(entry.get("triangles", 0)),
        size_ldu=tuple(entry.get("size_ldu", [0, 0, 0])),  # type: ignore[arg-type]
        bounds_min=tuple(entry.get("bounds_min", [0, 0, 0])),  # type: ignore[arg-type]
        bounds_max=tuple(entry.get("bounds_max", [0, 0, 0])),  # type: ignore[arg-type]
        stud_count=int(entry.get("stud_count", 0)),
        socket_count=int(entry.get("socket_count", 0)),
        connector_counts=dict(entry.get("connector_counts", {})),
        recolourable=bool(entry.get("recolourable", True)),
        unofficial=bool(entry.get("unofficial", False)),
        moved_to=str(entry.get("moved_to", "")),
    )


@lru_cache(maxsize=1)
def load() -> Catalogue:
    """The catalogue, loaded once per process."""
    return Catalogue()
