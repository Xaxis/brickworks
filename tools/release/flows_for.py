#!/usr/bin/env python3
"""The preview checks whose flows visit what a change touched.

    tools/release/flows_for.py                 changes since main
    tools/release/flows_for.py --since REF     since another ref
    tools/release/flows_for.py web/gallery.js api/_owned.js

The feature map follows imports, and a browser flow reaches a page by its
address, not by an import, so `featuremap affected` never lists one. Three
times a unit broke a flow it did not know visited its page: share_flow after
Versions, follows_flow on Designers, and share_flow, tested and builds on
Discovery's gallery shelves, which held m84 for an hour (2026-10-19).

A changed page is its address. A script or stylesheet is the address of
every page that loads it, following imports between scripts. An API file is
its route and the addresses tools/deploy.sh sends to it (/m/ to share.js).
A helper (api/_x.js) is the routes of the API files that import it. Then
every flow in tools/web that names one of those addresses, and the
preview_checks.sh names that run it. Godot files are left to the feature map.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
WEB, API, FLOWS = ROOT / "web", ROOT / "api", ROOT / "tools" / "web"


def changed(since: str) -> list[str]:
    out = subprocess.run(["git", "-C", str(ROOT), "diff", "--name-only", f"{since}...HEAD"],
                         capture_output=True, text=True, check=True).stdout
    return [line for line in out.splitlines() if line]


def page_address(html: Path) -> str:
    return "/" if html.stem == "index" else f"/{html.stem}"


def loaders(name: str, seen: set[str]) -> set[str]:
    """The addresses of the pages that load web/[name], directly or through
    another script that imports it."""
    if name in seen:
        return set()
    seen.add(name)
    found: set[str] = set()
    # Loaded, not mentioned: a src or href, or an import.
    quoted = rf"""["'](?:/|\./)?{re.escape(name)}(?:\?[^"']*)?["']"""
    pattern = re.compile(rf"""(?:src|href)\s*=\s*{quoted}|from\s+{quoted}|import\(\s*{quoted}""")
    for html in WEB.glob("*.html"):
        if pattern.search(html.read_text(errors="ignore")):
            found.add(page_address(html))
    for script in WEB.glob("*.js"):
        if script.name != name and pattern.search(script.read_text(errors="ignore")):
            found |= loaders(script.name, seen)
    return found


def routed_to(api_name: str) -> set[str]:
    """Addresses tools/deploy.sh sends to api/[api_name]: the literal start
    of each route's source, as far as it goes before a pattern begins."""
    deploy = (ROOT / "tools" / "deploy.sh").read_text(errors="ignore")
    found = {f"/api/{api_name}"}
    for source, dest in re.findall(r'"src":\s*"([^"]+)",\s*"dest":\s*"([^"]+)"', deploy):
        if re.match(rf"/api/{re.escape(api_name)}(\?|$)", dest):
            literal = re.split(r"[(\[.?*+\\$]", source)[0]
            if len(literal) > 1:
                found.add(literal)
    return found


def addresses(path: str) -> set[str]:
    p = Path(path)
    if p.parts[:1] == ("web",):
        if p.suffix == ".html":
            return {page_address(p)}
        if p.suffix in (".js", ".css"):
            return loaders(p.name, set())
        return set()
    if p.parts[:1] == ("api",) and p.suffix == ".js":
        name = p.stem
        if not name.startswith("_"):
            return routed_to(name)
        found: set[str] = set()
        pattern = re.compile(rf"""["']\./{re.escape(p.name)}["']""")
        for api in API.glob("*.js"):
            if api.name != p.name and pattern.search(api.read_text(errors="ignore")):
                found |= addresses(f"api/{api.name}")
        return found
    return set()


def checks() -> dict[str, list[str]]:
    """Flow file name -> the preview_checks.sh names that run it."""
    text = (ROOT / "tools" / "release" / "preview_checks.sh").read_text(errors="ignore")
    named: dict[str, list[str]] = {}
    for name, flow in re.findall(r'^\s*\[([a-z_0-9]+)\]="tools/web/([a-z_0-9]+\.mjs)', text, re.M):
        named.setdefault(flow, []).append(name)
    return named


def visits(flow: Path, address: str) -> bool:
    text = flow.read_text(errors="ignore")
    if address == "/":
        # The home page: a page sent to the site itself and nothing after it.
        # A bare goto(url) is no sign: the app's flows are given the app's own.
        return re.search(r"""goto\(\s*`\$\{[^}]+\}/`""", text) is not None
    # The address begins a path ("${site}/gallery", "/m/"), so /admin is not
    # found inside /api/admin.
    return re.search(rf"""(?<![A-Za-z0-9_.-]){re.escape(address)}(?![A-Za-z0-9_-])""", text) is not None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*")
    parser.add_argument("--since", default="main")
    args = parser.parse_args()
    files = args.files or changed(args.since)
    wanted: dict[str, set[str]] = {}
    for path in files:
        for address in addresses(path):
            wanted.setdefault(address, set()).add(path)
    if not wanted:
        print("no page or API route changed: nothing for the browser flows here")
        return 0
    named = checks()
    found: dict[str, set[str]] = {}
    unchecked: set[str] = set()
    for flow in sorted(FLOWS.glob("*.mjs")):
        hits = {a for a in wanted if visits(flow, a)}
        if not hits:
            continue
        names = named.get(flow.name)
        if not names:
            unchecked.add(flow.name)
            continue
        for name in names:
            found.setdefault(name, set()).update(hits)
    for name in sorted(found):
        why = ", ".join(f"{a} ({', '.join(sorted(wanted[a]))})" for a in sorted(found[name]))
        print(f"{name:16} {why}")
    if unchecked:
        print(f"also visit them, with no preview check: {', '.join(sorted(unchecked))}")
    # site and frames run on every ship (tools/release/ship.sh) whatever is named.
    print("checks: " + (" ".join(sorted(found)) or "none named; site and frames run on every ship"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
