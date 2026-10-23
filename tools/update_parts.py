#!/usr/bin/env python3
"""Bring the parts up to date with LDraw, building only what changed.

    tools/update_parts.py                    fetch LDraw's updates, apply them
    tools/update_parts.py --dry-run          say what they would change, write nothing
    tools/update_parts.py --zip FILE ...     apply these zips instead of fetching
    tools/update_parts.py --ldraw DIR --out DIR    another library and generated folder

The full mesh build (tools/build_meshes.py) is ninety minutes for every
part in the library. A month of LDraw is a few hundred files: the official
update (library.ldraw.org/library/updates/lcadYYRR.zip, each release newer
than the library's own release notes in models/) and the Parts Tracker's
unofficial zip, which changes daily. So this

1. fetches those zips (or takes them as --zip), and reads them as data:
   every member is checked for where it would land and how big it is, and
   only part, primitive and release-note files are taken;
2. compares each member with the library's file by hash. The library on
   disk is what the catalogue was built from, and this changes the two
   together, so a member that matches is already in the catalogue;
3. works out which parts reach a new or changed file through their
   references, as tools/ldraw/library.py resolves them: a part whose own
   file is unchanged is rebuilt when a subpart or primitive it draws did;
4. writes the files into the library and builds just those parts with the
   full build's own conversion (build_meshes._convert, as
   tools/build_custom.py does), seconds a part;
5. puts the meshes beside the others (content-hashed, so nothing already
   there is touched and older builds keep working), merges the entries
   into catalogue.json, and runs tools/refresh_catalogue.py's refresh over
   it, so the new parts carry the same fields a full build and a refresh
   give them.

A second run finds every member matching and builds nothing. A run that
dies after writing into the library leaves update_parts.pending.json in
the generated folder, and the next run builds what it lists.

It uploads nothing: names are content hashes, so the meshes go up with
tools/storage_parts.py and the new LDraw files with tools/storage_ldraw.py,
as the last lines it prints say. Needs numpy and scipy, as the full build
does.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import zipfile
from collections.abc import Iterable
from multiprocessing import Pool
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.library import Library, search_roots  # noqa: E402
from ldraw.parser import decode, normalise_filename  # noqa: E402

DEFAULT_LDRAW = ROOT / "vendor" / "ldraw"
DEFAULT_OUT = ROOT / "assets" / "generated"
DEFAULT_DOWNLOADS = ROOT / "vendor" / "updates"

SITE = "https://library.ldraw.org"
UPDATES_PAGE = SITE + "/updates"
UPDATE_ZIP = SITE + "/library/updates/lcad{}.zip"
UNOFFICIAL_ZIP = SITE + "/library/unofficial/ldrawunf.zip"

PENDING = "update_parts.pending.json"
# What a member may be: a part, subpart or primitive (and the pictures a
# printed one is drawn with), a release's notes, or the colour table.
TAKEN = {".dat", ".ldr", ".mpd", ".png"}
TOP_FILES = {"ldconfig.ldr", "ldcfgalt.ldr"}
# The 2026-09 official zip is 0.9 MB and the unofficial one 88 MB, 210 MB
# unpacked; a zip claiming far more than that is not one of theirs.
MEMBER_LIMIT = 64 << 20
ZIP_LIMIT = 2 << 30


# -- the zips ------------------------------------------------------------


def release_number(yyrr: str) -> int:
    """'2609' -> 202609, '9807' -> 199807: LDraw's releases, in order."""
    year = int(yyrr[:2])
    return ((1900 if year >= 90 else 2000) + year) * 100 + int(yyrr[2:])


def library_release(ldraw: Path) -> int:
    """The newest official release the library holds, from the notes each
    release puts in models/ (Note2609CA.txt). 0 when it has none."""
    found = [release_number(m.group(1)) for f in (ldraw / "models").glob("*")
             if (m := re.fullmatch(r"note(\d{4})ca\.txt", f.name.lower()))]
    return max(found, default=0)


def fetch(ldraw: Path, downloads: Path) -> list[Path]:
    """Download the official updates newer than the library, then the
    unofficial zip, into ``downloads``. Returns them in the order to apply."""
    downloads.mkdir(parents=True, exist_ok=True)
    have = library_release(ldraw)
    if not have:
        # No release notes: not a library from complete.zip, and every
        # update since 1998 would be "newer". fetch_data.sh --force first.
        raise SystemExit(f"{ldraw}/models has no release notes (NoteYYRRCA.txt), "
                         "so which updates it lacks is unknown: tools/fetch_data.sh --force")
    with urllib.request.urlopen(UPDATES_PAGE, timeout=60) as reply:
        page = reply.read().decode("utf-8", "replace")
    releases = sorted({m for m in re.findall(r"lcad(\d{4})\.zip", page)
                       if release_number(m) > have}, key=release_number)
    print(f"library at release {have}; official updates newer: "
          + (", ".join(releases) or "none"))
    zips = [_download(UPDATE_ZIP.format(r), downloads / f"lcad{r}.zip") for r in releases]
    zips.append(_download(UNOFFICIAL_ZIP, downloads / "ldrawunf.zip"))
    return zips


def _download(url: str, target: Path) -> Path:
    print(f"fetch {url}")
    partial = target.with_name(target.name + ".part")
    with urllib.request.urlopen(url, timeout=600) as reply, partial.open("wb") as out:
        while chunk := reply.read(1 << 20):
            out.write(chunk)
            if out.tell() > ZIP_LIMIT:
                raise SystemExit(f"{url}: larger than {ZIP_LIMIT >> 20} MB, refused")
    partial.replace(target)
    return target


def members(path: Path) -> tuple[str, int, dict[str, bytes]]:
    """A zip's files as library paths: (layout, release, {path: bytes}).

    Official zips put everything under ldraw/; the unofficial zip holds
    parts/ and p/ at its top, which land in the library's unofficial/.
    Release is the newest release-notes file an official zip carries, 0
    for the unofficial one. Members that would land anywhere else, or are
    not part files, are left out and counted.
    """
    taken: dict[str, bytes] = {}
    skipped = 0
    total = 0
    with zipfile.ZipFile(path) as archive:
        infos = [i for i in archive.infolist() if not i.is_dir()]
        official = bool(infos) and all(i.filename.startswith("ldraw/") for i in infos)
        for info in infos:
            name = info.filename[len("ldraw/"):] if official else info.filename
            rel = _safe(name)
            if rel is None or info.file_size > MEMBER_LIMIT:
                skipped += 1
                continue
            total += info.file_size
            if total > ZIP_LIMIT:
                raise SystemExit(f"{path}: unpacks to more than {ZIP_LIMIT >> 20} MB, refused")
            if not official:
                rel = "unofficial/" + rel
            data = archive.read(info)
            if len(data) > MEMBER_LIMIT:
                raise SystemExit(f"{path}: {info.filename} is not the size it says")
            taken[rel] = data
    release = max((release_number(m.group(1)) for rel in taken
                   if (m := re.fullmatch(r"models/note(\d{4})ca\.txt", rel.lower()))),
                  default=0)
    if skipped:
        print(f"  {path.name}: {skipped} members are not part files, left out")
    return ("official" if official else "unofficial"), release, taken


def _safe(name: str) -> str | None:
    """``name`` as a relative path inside the library, or None when it
    would land outside parts/, p/ and models/, or is not a part file."""
    if "\\" in name or ":" in name or name.startswith("/"):
        return None
    path = PurePosixPath(name)
    if any(part in ("", ".", "..") for part in path.parts):
        return None
    if len(path.parts) == 1:
        return name if name.lower() in TOP_FILES else None
    top = path.parts[0]
    if top == "models":
        return name if re.fullmatch(r"note\d{4}ca\.txt", path.name.lower()) else None
    if top in ("parts", "p") and path.suffix.lower() in TAKEN:
        return name
    return None


# -- what changed --------------------------------------------------------


def file_hash(data: bytes) -> str:
    return hashlib.blake2b(data, digest_size=16).hexdigest()


def compare(ldraw: Path, incoming: dict[str, bytes]) -> tuple[dict[str, bytes], int]:
    """The members whose bytes differ from the library's file, keyed by
    where they go, and how many already match. A file the library holds
    under another case is the same file, and is written where it is."""
    changed: dict[str, bytes] = {}
    same = 0
    listings: dict[Path, dict[str, str]] = {}
    for rel, data in incoming.items():
        folder = (ldraw / rel).parent
        if folder not in listings:
            listings[folder] = ({f.name.lower(): f.name for f in folder.iterdir()}
                                if folder.is_dir() else {})
        name = listings[folder].get(PurePosixPath(rel).name.lower())
        if name is not None:
            on_disk = folder / name
            rel = str(on_disk.relative_to(ldraw))
            if file_hash(on_disk.read_bytes()) == file_hash(data):
                same += 1
                continue
        changed[rel] = data
    return changed, same


def key_of(ldraw: Path, rel: str) -> tuple[int, str] | None:
    """(rank, reference name) a library file is found as, or None for a
    file no reference reaches. The lower rank wins a name."""
    path = ldraw / rel
    if path.suffix.lower() not in (".dat", ".ldr", ".mpd"):
        return None
    for rank, (prefix, folder) in enumerate(search_roots(ldraw)):
        if path.parent == folder:
            return rank, prefix + path.name.lower()
    return None


def references(path: Path) -> set[str]:
    """The reference names a file's type-1 lines give, as parse_line reads them."""
    found = set()
    for line in decode(path.read_bytes()).splitlines():
        tokens = line.split()
        if len(tokens) >= 15 and tokens[0] == "1":
            found.add(normalise_filename(" ".join(tokens[14:])))
    return found


def _references(item: tuple[str, str]) -> tuple[str, set[str]]:
    key, path = item
    try:
        return key, references(Path(path))
    except OSError:
        return key, set()


def affected(library: Library, changed_keys: set[str], jobs: int) -> set[str]:
    """Every reference name that reaches one in ``changed_keys`` through
    the library's references, those included."""
    index = library._index  # noqa: SLF001 — the resolved names are the point
    with Pool(jobs) as pool:
        graph = dict(pool.imap_unordered(
            _references, ((k, str(p)) for k, p in index.items()), chunksize=256))
    users: dict[str, set[str]] = {}
    for key, refs in graph.items():
        for ref in refs:
            users.setdefault(ref, set()).add(key)
    reached = set(changed_keys)
    frontier = list(changed_keys)
    while frontier:
        for user in users.get(frontier.pop(), ()):
            if user not in reached:
                reached.add(user)
                frontier.append(user)
    return reached


# -- applying ------------------------------------------------------------


def write_atomic(path: Path, data: bytes) -> None:
    """Replace ``path`` whole, never in place: a reader sees the old file
    or the new one, and a link at ``path`` is replaced, not written through."""
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.{os.getpid()}.part")
    partial.write_bytes(data)
    partial.replace(path)


def build(ldraw: Path, names: list[str], jobs: int) -> list[tuple[str, bytes | None, dict]]:
    """The full build's conversion of each named part, in parallel."""
    import build_meshes  # numpy and scipy, which a dry run does not need
    results = []
    with Pool(jobs, initializer=build_meshes._init, initargs=(str(ldraw),)) as pool:
        for n, result in enumerate(pool.imap_unordered(
                build_meshes._convert, names, chunksize=2), start=1):
            results.append(result)
            if n % 100 == 0:
                print(f"  {n:,}/{len(names):,} built", flush=True)
    return results


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--zip", nargs="+", type=Path, default=None,
                        help="apply these, in order, instead of fetching")
    parser.add_argument("--ldraw", type=Path, default=DEFAULT_LDRAW)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--downloads", type=Path, default=DEFAULT_DOWNLOADS)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    parser.add_argument("--dry-run", action="store_true",
                        help="say what would change and be built, write nothing")
    args = parser.parse_args(None if argv is None else list(argv))
    ldraw, out = args.ldraw, args.out
    catalogue_path = out / "catalogue.json"
    if not (ldraw / "parts").is_dir():
        print(f"no LDraw library at {ldraw} (tools/fetch_data.sh)")
        return 1
    if not catalogue_path.exists():
        print(f"no catalogue at {catalogue_path} (tools/build_meshes.py)")
        return 1
    started = time.time()

    zips = args.zip if args.zip is not None else fetch(ldraw, args.downloads)
    have = library_release(ldraw)
    incoming: dict[str, bytes] = {}
    for path in zips:
        layout, release, taken = members(path)
        if layout == "official" and release and release < have:
            # Its files are older than the library's: applying it would
            # take back what a later release changed.
            print(f"  {path.name}: release {release} is older than the library's "
                  f"{have}, skipped")
            continue
        print(f"  {path.name}: {layout}, {len(taken):,} files")
        incoming.update(taken)
    changed, same = compare(ldraw, incoming)
    print(f"against the library: {len(changed):,} new or changed, {same:,} already there")

    pending_path = out / PENDING
    pending = json.loads(pending_path.read_text()) if pending_path.exists() else {}
    if pending:
        print(f"a run that did not finish left {len(pending['files']):,} files "
              f"and {len(pending['parts']):,} parts ({pending_path.name}): built too")
    files = set(changed) | set(pending.get("files", []))

    # The library as it will be: each new or changed file that wins its
    # reference name over the file holding it now. Worked out before
    # anything is written, so a dry run sees what a real one does.
    library = Library(ldraw)
    index = library._index  # noqa: SLF001 — the resolved names are the point
    ranked = sorted(((found, rel) for rel in files
                     if (found := key_of(ldraw, rel)) is not None))
    changed_keys = set()
    for (rank, key), rel in ranked:
        holder = index.get(key)
        held = key_of(ldraw, str(holder.relative_to(ldraw))) if holder else None
        if held is None or rank <= held[0]:
            index[key] = ldraw / rel
            changed_keys.add(key)
    reached = affected(library, changed_keys, args.jobs) if changed_keys else set()
    part_names = set(library.part_names()) | {
        PurePosixPath(rel).name.lower() for rel in files
        if PurePosixPath(rel).parent.as_posix() in ("parts", "unofficial/parts")
        and rel.lower().endswith(".dat")}
    names = sorted((part_names & reached) | set(pending.get("parts", [])))
    through = [n for n in names if n not in changed_keys]
    print(f"  {len(changed_keys):,} reference names reach a new or changed file, "
          f"{len(names):,} parts draw one, {len(through):,} of them through a "
          "subpart or primitive")

    document = json.loads(catalogue_path.read_text())
    entries = {e["id"]: e for e in document["parts"]}
    new_ids = [n[:-4] for n in names if n[:-4] not in entries]
    if args.dry_run:
        print(f"dry run: {len(new_ids):,} new parts, {len(names) - len(new_ids):,} "
              f"rebuilt; nothing written ({time.time() - started:.0f}s)")
        print("new: " + " ".join(new_ids))
        print("rebuilt: " + " ".join(n[:-4] for n in names if n[:-4] in entries))
        print("through a subpart or primitive: " + " ".join(n[:-4] for n in through))
        return 0
    if not names and not files:
        print(f"nothing to build ({time.time() - started:.0f}s)")
        return 0

    # Recorded before the library changes: from here until the catalogue
    # is written the two disagree, and a run that dies in between must not
    # leave the next one finding nothing to do.
    pending_path.write_text(json.dumps({"files": sorted(files), "parts": names}))
    for rel, data in changed.items():
        write_atomic(ldraw / rel, data)
    print(f"wrote {len(changed):,} files into {ldraw}")
    building = time.time()
    results = build(ldraw, names, args.jobs)
    print(f"built {len(results):,} parts in {time.time() - building:.0f}s "
          f"with {args.jobs} workers")

    written = 0
    failures: list[tuple[str, str]] = []
    before_mesh: dict[str, str] = {}
    after_mesh: dict[str, str] = {}
    for part_id, blob, record in results:
        if blob is None:
            failures.append((part_id, record.get("error", "unknown")))
            continue
        target = out / "parts" / f"{record['mesh']}.lbm"
        if not target.exists() and not target.is_symlink():
            write_atomic(target, blob)
            written += 1
        old = entries.get(part_id)
        if old is not None:
            before_mesh[part_id] = old["mesh"]
            after_mesh[part_id] = record["mesh"]
        entries[part_id] = record

    # A part that built before and does not now keeps its entry: the full
    # build would drop it, and every model holding it with it.
    kept = [(i, why) for i, why in failures if i in entries]
    document["parts"] = sorted(entries.values(), key=lambda e: e["id"])
    document["counts"]["parts"] = len(document["parts"])
    document["counts"]["meshes"] = len({e["mesh"] for e in document["parts"]})

    from merge_subbuild import carry_exact
    from refresh_catalogue import refresh
    carried, lacking = carry_exact(before_mesh, after_mesh, out / "exact")
    said = refresh(document, out, ldraw)
    write_atomic(catalogue_path, json.dumps(document, separators=(",", ":")).encode())
    pending_path.unlink(missing_ok=True)

    changed_entries = sum(1 for i in before_mesh if before_mesh[i] != after_mesh[i])
    print("\n".join("  " + line for line in said))
    print(f"\ndone in {time.time() - started:.0f}s: {len(results) - len(failures):,} "
          f"parts built, {written:,} new meshes, {changed_entries:,} parts' meshes "
          f"changed, {carried:,} exact shapes carried to them")
    if lacking:
        print(f"WARNING: {len(lacking)} parts lost their exact shapes: "
              + ", ".join(lacking[:10]))
    for part_id, why in failures:
        print(f"  failed {part_id}: {why}"
              + (" (its old entry is kept)" if (part_id, why) in kept else ""))
    added = [entries[i] for i in new_ids if i in entries]
    real = [e for e in added if not e.get("moved_to")]
    print(f"\n{len(real)} new parts: " + "; ".join(
        f"{e['name']} ({e['id']})" for e in real))
    moved = len(added) - len(real)
    if moved:
        print(f"and {moved} new redirects (~Moved to)")
    rebuilt = [n[:-4] for n in names if n[:-4] not in new_ids]
    print(f"{len(rebuilt)} rebuilt, {len(through)} of them for a subpart or primitive "
          "they draw: " + ", ".join(rebuilt))
    print("\nTo put them live, from this checkout: tools/storage_parts.py (the "
          f"{written:,} new meshes, and exact shapes carried), tools/storage_ldraw.py "
          "(official LDraw files the bucket lacks), then a deploy and a release, "
          "which carry the catalogue.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
