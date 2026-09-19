"""The LDraw colour palette, from LDConfig.ldr.

Each colour is declared by one meta line:

    0 !COLOUR <name> CODE <n> VALUE #RRGGBB EDGE #RRGGBB [modifiers...]

The modifiers are what make this more than a lookup table, because they
say how the plastic behaves rather than just what hue it is:

    ALPHA <0-255>      translucent; needs real transmission, not blending
    LUMINANCE <0-255>  glow-in-the-dark; emissive at low light
    CHROME             mirror-finish metallic plating
    PEARLESCENT        soft metallic sheen
    METAL              painted or moulded metallic
    RUBBER             matte, low specular (tyres, bands)
    MATERIAL GLITTER VALUE #RRGGBB FRACTION f VFRACTION v SIZE s
    MATERIAL SPECKLE VALUE #RRGGBB FRACTION f MINSIZE a MAXSIZE b

The MATERIAL forms carry a second colour: the flecks suspended in the
otherwise-translucent body.  A shader needs both, plus the fraction, to
look like the real part rather than a flat approximation.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

# The two inheritance codes are not real colours and never appear in
# LDConfig; they are resolved during flattening.  See parser.py.
CODE_INHERIT = 16
CODE_EDGE_INHERIT = 24

# LDraw's fallback when a file names a code that is not in the palette.
DEFAULT_CODE = 16


class Finish(Enum):
    """How the surface behaves, which decides the shader it needs."""

    SOLID = "solid"
    TRANSPARENT = "transparent"
    CHROME = "chrome"
    PEARLESCENT = "pearlescent"
    METAL = "metal"
    RUBBER = "rubber"
    GLITTER = "glitter"
    OPALESCENT = "opalescent"
    SPECKLE = "speckle"
    GLOW = "glow"
    FABRIC = "fabric"


@dataclass(slots=True)
class Material:
    """The suspended-particle detail of a GLITTER or SPECKLE colour."""

    kind: str                 # "GLITTER" or "SPECKLE"
    value: tuple[int, int, int] = (0, 0, 0)
    fraction: float = 0.0     # share of surface area covered by flecks
    vfraction: float = 0.0    # share of volume, for glitter
    size: float = 0.0
    minsize: float = 0.0
    maxsize: float = 0.0


@dataclass(slots=True)
class Color:
    code: int
    name: str
    value: tuple[int, int, int]
    edge: tuple[int, int, int]
    alpha: int = 255
    luminance: int = 0
    finish: Finish = Finish.SOLID
    material: Material | None = None
    # Cross-references, filled in by the catalogue build from Rebrickable.
    rebrickable_id: int | None = None
    bricklink_id: int | None = None
    lego_name: str = ""

    @property
    def is_transparent(self) -> bool:
        return self.alpha < 255

    @property
    def hex(self) -> str:
        return "#%02X%02X%02X" % self.value

    def as_linear(self) -> tuple[float, float, float]:
        """sRGB hex to linear float, which is what a renderer wants.

        LDConfig values are sRGB display colours.  Feeding them to a
        physically-based renderer without converting makes every part read
        as washed out, which is the single most common reason fan renders
        look like plastic toys of plastic toys.
        """
        return tuple(_srgb_to_linear(c / 255.0) for c in self.value)  # type: ignore[return-value]


def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _parse_hex(token: str) -> tuple[int, int, int]:
    token = token.lstrip("#").strip()
    if len(token) == 3:  # a few legacy entries use the short form
        token = "".join(c * 2 for c in token)
    return (int(token[0:2], 16), int(token[2:4], 16), int(token[4:6], 16))


_COLOUR_RE = re.compile(r"^0\s+!COLOUR\s+(.*)$", re.IGNORECASE)


class Palette:
    """Every colour LDraw knows about, by code."""

    def __init__(self, colors: dict[int, Color] | None = None) -> None:
        self.by_code: dict[int, Color] = colors or {}

    @classmethod
    def from_file(cls, path: str | Path) -> "Palette":
        text = Path(path).read_text(encoding="latin-1")
        return cls.from_text(text)

    @classmethod
    def from_text(cls, text: str) -> "Palette":
        colors: dict[int, Color] = {}
        for raw in text.splitlines():
            match = _COLOUR_RE.match(raw.strip())
            if not match:
                continue
            color = _parse_colour_line(match.group(1))
            if color is not None:
                colors[color.code] = color
        return cls(colors)

    def get(self, code: int) -> Color:
        """Look up a code, falling back to a visible placeholder.

        Returning a real object rather than None keeps every caller from
        having to handle the case; an unknown code means a malformed file,
        and rendering it in glaring magenta makes that obvious.
        """
        found = self.by_code.get(code)
        if found is not None:
            return found
        return Color(
            code=code,
            name=f"Unknown_{code}",
            value=(255, 0, 255),
            edge=(0, 0, 0),
        )

    def __contains__(self, code: int) -> bool:
        return code in self.by_code

    def __len__(self) -> int:
        return len(self.by_code)

    def __iter__(self):
        return iter(sorted(self.by_code.values(), key=lambda c: c.code))

    def solids(self) -> list[Color]:
        return [c for c in self if c.finish is Finish.SOLID]

    def transparents(self) -> list[Color]:
        return [c for c in self if c.is_transparent]


def _parse_colour_line(body: str) -> Color | None:
    """Parse the part of a !COLOUR line after the keyword.

    The name may contain no spaces (LDraw uses underscores), so the line
    tokenises cleanly, but MATERIAL opens a nested key/value run that
    re-uses the VALUE key — so it is parsed separately, after the tail is
    split off.
    """
    tokens = body.split()
    if len(tokens) < 2:
        return None

    name = tokens[0]
    rest = tokens[1:]

    # Split off a MATERIAL tail before reading the outer keys, so the
    # material's own VALUE cannot overwrite the body colour.
    material: Material | None = None
    upper = [t.upper() for t in rest]
    if "MATERIAL" in upper:
        cut = upper.index("MATERIAL")
        material = _parse_material(rest[cut + 1:])
        rest = rest[:cut]

    fields: dict[str, str] = {}
    flags: set[str] = set()
    n = 0
    while n < len(rest):
        key = rest[n].upper()
        if key in ("CODE", "VALUE", "EDGE", "ALPHA", "LUMINANCE", "SIZE",
                   "FRACTION", "VFRACTION", "MINSIZE", "MAXSIZE"):
            if n + 1 < len(rest):
                fields[key] = rest[n + 1]
            n += 2
        else:
            flags.add(key)
            n += 1

    if "CODE" not in fields or "VALUE" not in fields:
        return None

    try:
        code = int(fields["CODE"])
        value = _parse_hex(fields["VALUE"])
    except ValueError:
        return None

    edge = (51, 51, 51)
    if "EDGE" in fields:
        try:
            edge = _parse_hex(fields["EDGE"])
        except ValueError:
            pass

    alpha = int(fields.get("ALPHA", 255))
    luminance = int(fields.get("LUMINANCE", 0))

    # Order matters: the most specific finish wins, because a glitter
    # colour is also transparent and a chrome colour is also metallic.
    #
    # The MATERIAL kinds are not two but three. Treating everything that
    # is not GLITTER as SPECKLE swept the twenty FABRIC colours in with
    # the four real speckles — and fabric is not plastic at all. It is
    # cloth: capes, sails, flags. It needs its own shader, not a
    # flecked-plastic one, and the count matters because it sizes the
    # bucket.
    #
    # The eight Opal_* colours are split out for the same reason. LDraw
    # writes them as GLITTER, but they carry LUMINANCE as well, and a
    # milky opalescent sheen does not look like suspended glitter flecks.
    if material is not None:
        if material.kind == "FABRIC":
            finish = Finish.FABRIC
        elif material.kind == "GLITTER":
            finish = Finish.OPALESCENT if luminance > 0 else Finish.GLITTER
        else:
            finish = Finish.SPECKLE
    elif "CHROME" in flags:
        finish = Finish.CHROME
    elif "PEARLESCENT" in flags:
        finish = Finish.PEARLESCENT
    elif "METAL" in flags:
        finish = Finish.METAL
    elif "RUBBER" in flags:
        finish = Finish.RUBBER
    elif luminance > 0:
        finish = Finish.GLOW
    elif alpha < 255:
        finish = Finish.TRANSPARENT
    else:
        finish = Finish.SOLID

    return Color(
        code=code,
        name=name,
        value=value,
        edge=edge,
        alpha=alpha,
        luminance=luminance,
        finish=finish,
        material=material,
    )


def _parse_material(tokens: list[str]) -> Material | None:
    if not tokens:
        return None
    kind = tokens[0].upper()
    fields: dict[str, str] = {}
    n = 1
    while n < len(tokens) - 1:
        fields[tokens[n].upper()] = tokens[n + 1]
        n += 2

    def number(key: str) -> float:
        try:
            return float(fields.get(key, 0.0))
        except ValueError:
            return 0.0

    value = (0, 0, 0)
    if "VALUE" in fields:
        try:
            value = _parse_hex(fields["VALUE"])
        except ValueError:
            pass

    return Material(
        kind=kind,
        value=value,
        fraction=number("FRACTION"),
        vfraction=number("VFRACTION"),
        size=number("SIZE"),
        minsize=number("MINSIZE"),
        maxsize=number("MAXSIZE"),
    )
