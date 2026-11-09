#!/usr/bin/env python3
"""The documentation's pictures, made again from the real app and the real
site as docs-site/shots.json sets each one up.

    tools/docs_shots.py                   every picture: the app's from a locked
                                          snapshot of HEAD, the site's from a
                                          site put together from this tree
    tools/docs_shots.py --only=ID,ID      just these
    tools/docs_shots.py --app | --site    just one half
    tools/docs_shots.py --snapshot=DIR    the app's from that worktree, kept
    tools/docs_shots.py --url=DEPLOYMENT  the site's from a deployment
    tools/docs_shots.py --affected [--since=REF]
                                          the pictures a change since REF
                                          (default origin/main) may have changed
    tools/docs_shots.py --check           what is wrong with the pictures, made
                                          nothing (tools/docs_site.py --check
                                          says the same)

The owner, 2026-11-09: docs "including images in it and having an
iterative process established such that you keep it updated as we keep on
building". Units change what a person sees every hour, so a picture taken
by hand is out of date within a day. So each picture is written down once,
in the manifest: the page it is on, what to set up (a model, a menu
command, keys, clicks; the site's page and what its server answers), what
to cut it to, and its words (alt and caption, which --write in
tools/docs_site.py puts into the page). This makes every one of them again.

The app's are taken by src/dev/docs_shots_probe.gd, a windowed probe on
the GPU (tools/probe.sh gives it the lease and Xvfb), from a locked
snapshot worktree of HEAD made and removed here, never a live worktree,
each in a window and an app data folder of its own. The site's by
tools/web/docs_shots_flow.mjs, on SwiftShader under heavy, with what each
page asks its server answered from the manifest. Both write lossless
pictures; this reads their pixels, and a picture whose pixels are the ones
docs-site/img/shots.lock.json says it was made from is left as it is, so
the same code makes no change and a change means the UI changed. A changed
one is written again as WebP into docs-site/img/, and its old and new
picture and what differs are put side by side in the run's folder
(diff/index.html) to be looked at before it is committed.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs-site/shots.json"
IMG = ROOT / "docs-site/img"
LOCK = IMG / "shots.lock.json"
FEATURES = ROOT / ".claude/skills/verify/features.json"
CORE = Path.home() / ".claude/claude-core/bin"
# A picture more than this is too heavy for a docs page (each is lazy).
MOST_BYTES = 300_000
QUALITY = 84
ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
THEMES = ("dark", "light")
SHOWN = re.compile(r'^!\[([^\]]*)\]\(/docs/img/([a-z0-9-]+)\.webp(?:\s+"([^"]*)")?\)\s*$', re.M)


def manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def shots() -> list[dict]:
    return manifest().get("shots", [])


def names(shot: dict) -> list[str]:
    """The files a picture is: one, or one a theme for the site's."""
    themes = shot.get("themes", ["dark"]) if shot.get("source") == "site" else ["dark"]
    return [shot["id"] if theme == "dark" else f"{shot['id']}-{theme}" for theme in themes]


def lock() -> dict:
    return json.loads(LOCK.read_text(encoding="utf-8")) if LOCK.exists() else {}


def webp_size(path: Path) -> tuple[int, int] | None:
    head = path.read_bytes()[:30]
    if head[:4] != b"RIFF" or head[8:12] != b"WEBP":
        return None
    kind = head[12:16]
    if kind == b"VP8 ":
        return int.from_bytes(head[26:28], "little") & 0x3FFF, int.from_bytes(head[28:30], "little") & 0x3FFF
    if kind == b"VP8L":
        bits = int.from_bytes(head[21:25], "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if kind == b"VP8X":
        return int.from_bytes(head[24:27], "little") + 1, int.from_bytes(head[27:30], "little") + 1
    return None


# -- the check -----------------------------------------------------------------------


def problems(pages: dict[str, str]) -> list[str]:
    """What is wrong with the pictures, given each page's Markdown by name:
    a picture missing or not what its last run made, one no page shows or a
    page shows twice, words on a page not the manifest's, a feature named
    that the feature map no longer has, a file nobody names."""
    found: list[str] = []
    try:
        listed = shots()
    except (OSError, ValueError) as trouble:
        return [f"docs-site/shots.json cannot be read: {trouble}"]
    made = lock()
    features = {f["id"] for f in json.loads(FEATURES.read_text(encoding="utf-8"))["features"]}
    seen: set[str] = set()
    files: set[str] = set()
    shown: dict[str, list[tuple[str, str, str]]] = {}
    for page, text in pages.items():
        for alt, name, caption in SHOWN.findall(text):
            shown.setdefault(name, []).append((page, alt, caption))
    for shot in listed:
        sid = str(shot.get("id", ""))
        where = f"docs-site/shots.json's {sid or 'picture with no id'}"
        if not ID.match(sid):
            found.append(f"{where}: an id is lower-case words joined by -")
            continue
        if sid in seen:
            found.append(f"{where} is in docs-site/shots.json twice")
        seen.add(sid)
        if shot.get("source") not in ("app", "site"):
            found.append(f"{where}: source is app or site")
        if shot.get("page") not in pages:
            found.append(f"{where} is for {shot.get('page')}, which is no docs page")
        alt = str(shot.get("alt", "")).strip()
        if not alt:
            found.append(f"{where} has no alt: the words a person who cannot see it reads")
        elif "]" in alt or '"' in str(shot.get("caption", "")) or "\n" in alt:
            found.append(f"{where}: no ] in an alt, no \" in a caption, one line each (they go in Markdown)")
        elif len(alt) > 320:
            found.append(f"{where}'s alt is {len(alt)} characters: say what it shows in under 320")
        if shot.get("source") == "site" and not str(shot.get("route", "")).startswith("/"):
            found.append(f"{where} names no route on the site")
        for theme in shot.get("themes", []):
            if theme not in THEMES:
                found.append(f"{where} asks for a theme {theme}, which is none of {', '.join(THEMES)}")
        for feature in shot.get("features", []):
            if feature not in features:
                found.append(f"{where} shows {feature}, which the feature map does not have "
                             "(renamed or gone? see .claude/skills/verify/features.json)")
        for name in names(shot):
            files.add(name)
            path = IMG / f"{name}.webp"
            if not path.exists():
                found.append(f"docs-site/img/{name}.webp is missing: tools/docs_shots.py --only={sid}")
                continue
            size = webp_size(path)
            record = made.get(name)
            if not record or size != (record.get("width"), record.get("height")) \
                    or path.stat().st_size != record.get("bytes"):
                found.append(f"docs-site/img/{name}.webp is not what tools/docs_shots.py made "
                             "(docs-site/img/shots.lock.json): make it again with --only=" + sid)
            if path.stat().st_size > MOST_BYTES:
                found.append(f"docs-site/img/{name}.webp is {path.stat().st_size // 1000} KB: crop it "
                             f"or give it a width, under {MOST_BYTES // 1000} KB")
        on = shown.get(sid, [])
        if not on:
            found.append(f"{where} is shown on no page: put ![](/docs/img/{sid}.webp) on "
                         f"docs-site/{shot.get('page')}.md, then tools/docs_site.py --write")
        for page, page_alt, caption in on:
            if page != shot.get("page"):
                found.append(f"docs-site/{page}.md shows {sid}, which docs-site/shots.json gives to {shot.get('page')}")
            elif page_alt != alt or caption != str(shot.get("caption", "")):
                found.append(f"docs-site/{page}.md's words for {sid} are not docs-site/shots.json's: "
                             "tools/docs_site.py --write")
        if len(on) > 1:
            found.append(f"{sid} is shown {len(on)} times")
    for name in sorted(set(shown) - seen):
        found.append(f"docs-site/{shown[name][0][0]}.md shows /docs/img/{name}.webp, which docs-site/shots.json "
                     "does not have")
    for path in sorted(IMG.glob("*.webp")) if IMG.exists() else []:
        if path.stem not in files:
            found.append(f"docs-site/img/{path.name} is in no docs-site/shots.json picture: remove it")
    for name in sorted(set(made) - files):
        found.append(f"docs-site/img/shots.lock.json has {name}, which docs-site/shots.json does not")
    return found


def with_words(text: str) -> str:
    """A page's Markdown with each picture's alt and caption the manifest's."""
    by_id = {s.get("id"): s for s in shots()}

    def words(match: re.Match) -> str:
        shot = by_id.get(match.group(2))
        if shot is None:
            return match.group(0)
        alt = str(shot.get("alt", "")).strip()
        caption = str(shot.get("caption", ""))
        return f'![{alt}](/docs/img/{match.group(2)}.webp' + (f' "{caption}"' if caption else "") + ")"

    return SHOWN.sub(words, text)


# -- which pictures a change may have changed -----------------------------------


def affected(since: str) -> list[str]:
    changed = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", f"{since}...HEAD"],
                             capture_output=True, text=True, check=True).stdout.split()
    changed += subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.split()
    changed_set = set(changed)
    entries = {f["id"]: f.get("entry", "") for f in json.loads(FEATURES.read_text(encoding="utf-8"))["features"]}
    out = []
    for shot in shots():
        why = []
        for feature in shot.get("features", []):
            if entries.get(feature) in changed_set:
                why.append(entries[feature])
        if f"docs-site/{shot.get('page')}.md" in changed_set:
            why.append(f"docs-site/{shot.get('page')}.md")
        if why:
            out.append(f"{shot['id']}  ({', '.join(sorted(set(why)))})")
    # A change to what every window is made of may change every picture.
    common = [p for p in changed_set if p.startswith(("src/ui/look", "src/ui/theme", "assets/ui/", "assets/fonts/"))
              or p in ("src/main.gd", "src/main.tscn", "src/ui/shell.gd", "web/site.css")]
    if common:
        out.append(f"(every picture may have changed: {', '.join(sorted(common))})")
    return out


# -- making them -------------------------------------------------------------------


def run(cmd: list[str], **kw) -> int:
    print("docs_shots: " + " ".join(cmd), flush=True)
    return subprocess.run(cmd, **kw).returncode


def snapshot() -> tuple[Path, str]:
    """A worktree of HEAD for the app's pictures, locked, its import seeded
    from this one's: (where, its name)."""
    sha = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True,
                         check=True).stdout.strip()
    name = f"docshots-snap-{sha[:10]}"
    if run(["bash", str(ROOT / "tools/release/release_wt.sh"), name, sha], cwd=ROOT) != 0:
        raise SystemExit("docs_shots: could not make the snapshot worktree")
    common = Path(subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--path-format=absolute",
                                  "--git-common-dir"], capture_output=True, text=True, check=True).stdout.strip())
    where = common.parent / ".claude/worktrees" / name
    subprocess.run(["git", "-C", str(where), "worktree", "lock", "--reason", "docs_shots: pictures being taken",
                    str(where)], check=False)
    # The import, seeded: .godot and the .import files beside the sources
    # (git-ignored). Whatever is still behind, probe.sh imports.
    if (ROOT / ".godot").is_dir() and not (where / ".godot").exists():
        shutil.copytree(ROOT / ".godot", where / ".godot", symlinks=True)
        listed = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--others", "--ignored", "--exclude-standard",
                                 "--", "*.import"], capture_output=True, text=True).stdout.split("\n")
        for rel in filter(None, listed):
            if not (where / rel).exists() and (ROOT / rel).exists():
                (where / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / rel, where / rel)
    return where, name


def retire(where: Path, name: str) -> None:
    subprocess.run(["git", "-C", str(ROOT), "worktree", "unlock", str(where)], check=False)
    subprocess.run(["git", "-C", str(ROOT), "worktree", "remove", "--force", str(where)], check=False)
    subprocess.run(["git", "-C", str(ROOT), "branch", "-D", name], check=False, capture_output=True)


def take_app(only: list[str], raw: Path, given: Path | None) -> int:
    where, name = (given, "") if given else snapshot()
    try:
        cmd = ["tools/probe.sh", "docs_shots_probe", "--", f"--out={raw}", f"--manifest={MANIFEST}"]
        if only:
            cmd.append("--only=" + ",".join(only))
        return run(cmd, cwd=where)
    finally:
        if not given:
            retire(where, name)


def take_site(only: list[str], raw: Path, url: str) -> int:
    heavy = [str(CORE / "heavy")] if (CORE / "heavy").exists() else []
    cmd = ["node", "tools/web/docs_shots_flow.mjs", f"--out={raw}", f"--manifest={MANIFEST}"]
    if only:
        cmd.append("--only=" + ",".join(only))
    if url:
        return run(heavy + cmd + [f"--url={url}"], cwd=ROOT)
    site = raw / "_site"
    if run([sys.executable, "tools/site.py", str(site)], cwd=ROOT, stdout=subprocess.DEVNULL) != 0:
        return 1
    try:
        return run(heavy + cmd + [f"--root={site}"], cwd=ROOT)
    finally:
        shutil.rmtree(site, ignore_errors=True)


def pixels(path: Path):
    from PIL import Image
    with Image.open(path) as picture:
        return picture.convert("RGB")


def encode(raw: Path, out: Path) -> list[dict]:
    """Each picture taken, against what it was made from last: written as
    WebP where its pixels are new. What happened to each, in order."""
    from PIL import Image, ImageChops
    made = lock()
    told = []
    IMG.mkdir(parents=True, exist_ok=True)
    diff = out / "diff"
    for shot in shots():
        for name in names(shot):
            png = raw / f"{name}.png"
            said = raw / f"{name}.json"
            if not png.exists():
                if said.exists():
                    why = json.loads(said.read_text(encoding="utf-8")).get("why", "not taken")
                    told.append({"name": name, "what": "failed", "why": why})
                continue
            picture = pixels(png)
            sha = hashlib.sha256(f"{picture.width}x{picture.height}\n".encode() + picture.tobytes()).hexdigest()
            target = IMG / f"{name}.webp"
            record = made.get(name, {})
            if record.get("sha256") == sha and target.exists():
                told.append({"name": name, "what": "same", "bytes": target.stat().st_size})
                continue
            old = pixels(target) if target.exists() else None
            picture.save(target, "WEBP", quality=QUALITY, method=6)
            made[name] = {"sha256": sha, "width": picture.width, "height": picture.height,
                          "bytes": target.stat().st_size}
            entry = {"name": name, "what": "new" if old is None else "changed", "bytes": target.stat().st_size}
            if old is not None:
                diff.mkdir(parents=True, exist_ok=True)
                width, height = max(old.width, picture.width), max(old.height, picture.height)
                a = Image.new("RGB", (width, height)); a.paste(old)
                b = Image.new("RGB", (width, height)); b.paste(picture)
                delta = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 24 else 0)
                entry["differ"] = sum(1 for v in delta.getdata() if v)
                marked = b.copy()
                marked.paste(Image.new("RGB", (width, height), (255, 0, 255)), mask=delta)
                old.save(diff / f"{name}.old.png")
                picture.save(diff / f"{name}.new.png")
                marked.save(diff / f"{name}.diff.png")
            told.append(entry)
    LOCK.write_text(json.dumps(dict(sorted(made.items())), indent=1) + "\n", encoding="utf-8")
    changed = [t for t in told if t["what"] in ("changed", "new")]
    if changed:
        diff.mkdir(parents=True, exist_ok=True)
        rows = "".join(
            f"<h2>{html.escape(t['name'])} ({t['what']}{', %d px differ' % t['differ'] if 'differ' in t else ''})</h2>"
            + (f'<p><img src="{t["name"]}.old.png" alt="before"> <img src="{t["name"]}.new.png" alt="after"> '
               f'<img src="{t["name"]}.diff.png" alt="what differs, in magenta"></p>' if t["what"] == "changed"
               else f'<p><img src="../../{IMG.relative_to(ROOT)}/{t["name"]}.webp" alt="new"></p>')
            for t in changed)
        (diff / "index.html").write_text(
            "<!DOCTYPE html><meta charset=utf-8><title>Docs pictures that changed</title>"
            "<style>body{font:14px system-ui;background:#222;color:#eee}img{max-width:32%;vertical-align:top;"
            "border:1px solid #555}</style>" + rows, encoding="utf-8")
    return told


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("--only", default="")
    parser.add_argument("--app", action="store_true")
    parser.add_argument("--site", action="store_true")
    parser.add_argument("--snapshot", default="")
    parser.add_argument("--url", default="")
    parser.add_argument("--out", default="")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--affected", action="store_true")
    parser.add_argument("--since", default="origin/main")
    given = parser.parse_args(argv)
    if given.check:
        sys.path.insert(0, str(ROOT / "tools"))
        import docs_site  # noqa: E402
        found = docs_site.shot_problems()
        for problem in found:
            print(f"docs_shots: {problem}")
        print(f"docs_shots: {len(shots())} picture(s) in docs-site/shots.json, "
              + (f"{len(found)} problem(s)" if found else "each made and shown"))
        return 1 if found else 0
    if given.affected:
        for line in affected(given.since):
            print(line)
        return 0
    only = [s for s in given.only.split(",") if s]
    unknown = sorted(set(only) - {s["id"] for s in shots()})
    if unknown:
        raise SystemExit(f"docs_shots: no picture {', '.join(unknown)} in docs-site/shots.json")
    want = [s for s in shots() if not only or s["id"] in only]
    app = [s["id"] for s in want if s.get("source") == "app"] if not given.site or given.app else []
    site = [s["id"] for s in want if s.get("source") == "site"] if not given.app or given.site else []
    out = Path(given.out).resolve() if given.out else Path(tempfile.mkdtemp(prefix="docs_shots."))
    raw = out / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    bad = 0
    if app:
        bad |= take_app(only and app, raw, Path(given.snapshot).resolve() if given.snapshot else None)
    if site:
        bad |= take_site(only and site, raw, given.url)
    told = encode(raw, out)
    total = sum(p.stat().st_size for p in IMG.glob("*.webp"))
    for t in told:
        if t["what"] != "same":
            print(f"  {t['what']:8} {t['name']}" + (f": {t['why']}" if "why" in t else
                                                     f", {t['bytes'] // 1000} KB" + (f", {t['differ']} px differ"
                                                                                    if "differ" in t else "")))
    counts = {k: sum(1 for t in told if t["what"] == k) for k in ("same", "changed", "new", "failed")}
    print(f"docs_shots: {len(told)} picture(s): {counts['same']} the same, {counts['changed']} changed, "
          f"{counts['new']} new, {counts['failed']} failed; docs-site/img/ is {total // 1000} KB")
    if counts["changed"] or counts["new"]:
        print(f"docs_shots: look at {out / 'diff/index.html'} before committing docs-site/img/")
    print(f"docs_shots: the run's pictures are in {out}")
    return 1 if bad or counts["failed"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
