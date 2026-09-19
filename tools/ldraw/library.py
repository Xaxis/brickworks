"""Locating and caching LDraw source files.

An LDraw part is the root of a reference tree: ``3001.dat`` (brick 2x4)
pulls in ``s/3001s01.dat``, which pulls in ``stud.dat``, which pulls in
``4-4cyli.dat`` and friends.  Resolving those names is most of the work,
because references are written Windows-style and case-insensitively while
the library on disk is neither.

Search order follows the convention every LDraw tool uses:

    1. the directory of the file doing the referencing (models with
       self-contained parts rely on this)
    2. <root>/parts/
    3. <root>/p/
    4. <root>/models/
    5. the unofficial mirrors, if present

Curve resolution
----------------
Round primitives ship at three tessellations.  ``4-4cyli.dat`` in ``p/``
is the 16-segment standard; ``p/48/4-4cyli.dat`` is 48-segment for
close-ups and ``p/8/4-4cyli.dat`` is 8-segment for distance.  A reference
always names the standard one and the *renderer* decides to substitute, so
the same part file yields several levels of detail.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

from .parser import Command, normalise_filename, parse_text


class Detail(Enum):
    """Which tessellation of the round primitives to substitute."""

    LOW = "8"        # p/8/  — 8-segment circles
    STANDARD = ""    # p/    — 16-segment circles
    HIGH = "48"      # p/48/ — 48-segment circles


@dataclass(slots=True)
class LDrawFile:
    """One parsed source file, with the header fields we care about."""

    name: str                       # normalised name as referenced, e.g. "3001.dat"
    path: Path
    commands: list[Command]
    description: str = ""           # the first line of the file
    part_type: str = ""             # from !LDRAW_ORG: Part, Subpart, Primitive, ...
    category: str = ""              # from !CATEGORY, or inferred from description
    keywords: list[str] = field(default_factory=list)
    bfc_certified: bool = False
    bfc_ccw: bool = True            # winding declared by BFC CERTIFY
    license: str = ""

    @property
    def is_primitive(self) -> bool:
        return "primitive" in self.part_type.lower()

    @property
    def is_subpart(self) -> bool:
        return "subpart" in self.part_type.lower()

    @property
    def is_shortcut(self) -> bool:
        return "shortcut" in self.part_type.lower()

    @property
    def is_alias(self) -> bool:
        return "alias" in self.part_type.lower()

    @property
    def is_physical_colour(self) -> bool:
        """A mould that is moulded in fixed colours (printed or multi-shot).

        These carry real colour codes instead of 16, so they cannot be
        recoloured and need separate handling in the catalogue.
        """
        return "physical_colour" in self.part_type.lower()


class Library:
    """An LDraw installation, with a parse cache.

    The cache matters a great deal: ``stud.dat`` is referenced hundreds of
    thousands of times across the library, and re-reading and re-parsing it
    each time turns a two-minute build into an hour-long one.
    """

    def __init__(self, root: str | os.PathLike[str]) -> None:
        self.root = Path(root)
        if not (self.root / "parts").is_dir():
            raise FileNotFoundError(
                f"{self.root} does not look like an LDraw library "
                "(no parts/ directory)"
            )
        self._index: dict[str, Path] = {}
        self._cache: dict[str, LDrawFile | None] = {}
        self._build_index()

    # -- index -----------------------------------------------------------

    def _build_index(self) -> None:
        """Map every normalised reference name to a path, once.

        Walking the tree up front costs a second and removes a stat() storm
        from the hot path.  Later roots do not overwrite earlier ones, so
        search-order precedence is preserved.
        """
        search_roots: list[tuple[str, Path]] = [
            ("", self.root / "parts"),
            ("s/", self.root / "parts" / "s"),
            ("", self.root / "p"),
            ("48/", self.root / "p" / "48"),
            ("8/", self.root / "p" / "8"),
            ("", self.root / "models"),
        ]
        # Unofficial parts mirror the same layout and are additive.
        unofficial = self.root / "unofficial"
        if unofficial.is_dir():
            search_roots += [
                ("", unofficial / "parts"),
                ("s/", unofficial / "parts" / "s"),
                ("", unofficial / "p"),
                ("48/", unofficial / "p" / "48"),
                ("8/", unofficial / "p" / "8"),
            ]

        for prefix, directory in search_roots:
            if not directory.is_dir():
                continue
            for entry in directory.iterdir():
                if not entry.is_file():
                    continue
                if entry.suffix.lower() not in (".dat", ".ldr", ".mpd"):
                    continue
                key = prefix + entry.name.lower()
                self._index.setdefault(key, entry)

    # -- resolution ------------------------------------------------------

    def resolve(self, name: str, detail: Detail = Detail.STANDARD) -> Path | None:
        """Find the file a reference names, honouring curve substitution."""
        key = normalise_filename(name)

        if detail is not Detail.STANDARD:
            # Only primitives living directly in p/ have hi/lo-res twins;
            # a part or subpart reference is never substituted.
            candidate = f"{detail.value}/{key}"
            if candidate in self._index:
                return self._index[candidate]

        return self._index.get(key)

    def get(self, name: str, detail: Detail = Detail.STANDARD) -> LDrawFile | None:
        """Parse a file by reference name, from cache when possible."""
        key = normalise_filename(name)
        cache_key = f"{detail.value}|{key}" if detail is not Detail.STANDARD else key

        if cache_key in self._cache:
            return self._cache[cache_key]

        path = self.resolve(key, detail)
        if path is None:
            self._cache[cache_key] = None
            return None

        parsed = self._parse_file(key, path)
        self._cache[cache_key] = parsed
        return parsed

    def _parse_file(self, name: str, path: Path) -> LDrawFile:
        # LDraw files are Latin-1 in practice; a handful carry accented
        # author names that are not valid UTF-8.
        text = path.read_text(encoding="latin-1")
        commands = [command for _, command in parse_text(text)]

        ldfile = LDrawFile(name=name, path=path, commands=commands)
        _read_header(ldfile, text)
        return ldfile

    # -- enumeration -----------------------------------------------------

    def part_names(self, *, include_unofficial: bool = True) -> list[str]:
        """Every top-level part reference name, e.g. ``3001.dat``.

        Excludes subparts (``s/``) and primitives, which are building
        blocks rather than things a user can place.
        """
        names = []
        roots = [self.root / "parts"]
        unofficial = self.root / "unofficial" / "parts"
        if include_unofficial and unofficial.is_dir():
            roots.append(unofficial)

        for directory in roots:
            for entry in directory.iterdir():
                if entry.is_file() and entry.suffix.lower() == ".dat":
                    names.append(entry.name.lower())
        return sorted(set(names))

    def __len__(self) -> int:
        return len(self._index)


def _read_header(ldfile: LDrawFile, text: str) -> None:
    """Pull the metadata out of the type-0 lines at the top of a file.

    Parsed from raw text rather than the command list because the
    description is positional: it is the very first line, with no keyword
    to recognise it by.
    """
    first = True
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if not line.startswith("0"):
            # The header ends at the first drawing command.
            break

        body = line[1:].strip()
        if first:
            ldfile.description = body
            first = False
            continue

        upper = body.upper()
        if upper.startswith("!LDRAW_ORG"):
            # "!LDRAW_ORG Part UPDATE 2004-03" -> "Part"
            rest = body[len("!LDRAW_ORG"):].strip()
            words: list[str] = []
            for word in rest.split():
                if word.upper() in ("UPDATE", "ORIGINAL"):
                    break
                words.append(word)
            ldfile.part_type = " ".join(words)
        elif upper.startswith("!CATEGORY"):
            ldfile.category = body[len("!CATEGORY"):].strip()
        elif upper.startswith("!KEYWORDS"):
            extra = body[len("!KEYWORDS"):].strip()
            ldfile.keywords += [k.strip() for k in extra.split(",") if k.strip()]
        elif upper.startswith("!LICENSE"):
            ldfile.license = body[len("!LICENSE"):].strip()
        elif upper.startswith("BFC"):
            tokens = upper.split()[1:]
            if "CERTIFY" in tokens:
                ldfile.bfc_certified = True
                ldfile.bfc_ccw = "CW" not in tokens
            elif "NOCERTIFY" in tokens:
                ldfile.bfc_certified = False

    if not ldfile.category and ldfile.description:
        # By convention the first word of the description is the category
        # for parts that predate the !CATEGORY meta command.
        head = ldfile.description.lstrip("~_=")
        ldfile.category = head.split()[0] if head.split() else ""
