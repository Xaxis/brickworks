#!/usr/bin/env python3
"""Put the website brickworks.diy serves around the app into one directory.

    tools/site.py OUT        the pages, pictures and files of web/, ready to serve

tools/deploy.sh runs it into .vercel/output/static; run it into a scratch
directory to look at the site locally (python3 -m http.server there, and
open /changelog.html: the clean addresses are the host's routes, not files).

Everything in web/ is copied as it is, apart from names starting with "_"
or "." (working parts: the render the share card is composed from) and
img/manifest.json, which says where each picture came from. One page is
written rather than copied: the changelog, filled from CHANGELOG.md and
web/releases.json, so it can never say something the release notes do not.
"""

from __future__ import annotations

import datetime
import html
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
MARK = "<!--changelog-->"


def inline(text: str) -> str:
    """The Markdown the changelog uses inside a line: code, bold, links."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", out)
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)",
                 lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>', out)
    return out


def day(iso: str) -> str:
    """"2026-10-11" as "11 October 2026"; anything else as it is."""
    try:
        d = datetime.date.fromisoformat(iso)
    except ValueError:
        return html.escape(iso)
    return f"{d.day} {d:%B %Y}"


def sections(markdown: str) -> list[dict]:
    """Each "## [version] - date" section: its blocks, in order."""
    found: list[dict] = []
    current: dict | None = None
    block: list[str] = []
    kind = ""

    def close() -> None:
        nonlocal block, kind
        if current is not None and block:
            current["blocks"].append((kind, " ".join(s.strip() for s in block)))
        block, kind = [], ""

    for line in markdown.splitlines():
        head = re.match(r"^## \[([^\]]+)\](?:\s*-\s*(\S+))?", line)
        if head:
            close()
            current = {"version": head.group(1), "date": head.group(2) or "", "blocks": []}
            found.append(current)
            continue
        if current is None:
            continue
        if line.startswith("### "):
            close()
            current["blocks"].append(("h3", line[4:].strip()))
        elif line.startswith("- "):
            close()
            kind, block = "li", [line[2:]]
        elif not line.strip():
            close()
        elif line.startswith("  ") and kind == "li":
            block.append(line)
        elif re.match(r"^\[[^\]]+\]:\s", line):
            close()  # a link reference at the foot of the file
        else:
            if kind != "p":
                close()
                kind = "p"
            block.append(line)
    close()
    return found


def render(found: list[dict], releases: dict) -> str:
    by_version = {r["version"]: r for r in releases.get("releases", [])}
    parts: list[str] = []
    for section in found:
        version = section["version"]
        blocks = section["blocks"]
        if not blocks:
            continue
        unreleased = version.lower() == "unreleased"
        anchor = "web" if unreleased else "v" + version
        release = by_version.get(version, {})
        date = release.get("date") or section["date"]
        parts.append(f'<article class="release" id="{anchor}" aria-labelledby="{anchor}-h">')
        if unreleased:
            parts.append(f'<h2 id="{anchor}-h">On the web now</h2>')
            parts.append('<p class="when">In the app at <a href="/app">brickworks.diy/app</a>; '
                         'in the next desktop release.</p>')
        else:
            parts.append(f'<h2 id="{anchor}-h">Brickworks {html.escape(version)}</h2>')
            links = ['<a href="/download">Download</a>']
            if release.get("page"):
                links.append(f'<a href="{html.escape(release["page"])}">On GitHub</a>')
            when = f'<time datetime="{html.escape(date)}">{day(date)}</time>' if date else ""
            parts.append(f'<p class="when">{when}{" · " if when else ""}{" · ".join(links)}</p>')
        open_list = False
        for kind, text in blocks:
            if kind != "li" and open_list:
                parts.append("</ul>")
                open_list = False
            if kind == "h3":
                parts.append(f"<h3>{inline(text)}</h3>")
            elif kind == "li":
                if not open_list:
                    parts.append("<ul>")
                    open_list = True
                parts.append(f"<li>{inline(text)}</li>")
            else:
                parts.append(f"<p>{inline(text)}</p>")
        if open_list:
            parts.append("</ul>")
        parts.append("</article>")
    return "\n".join(parts)


def changelog_page() -> str:
    template = (WEB / "changelog.html").read_text(encoding="utf-8")
    if MARK not in template:
        raise SystemExit(f"site: web/changelog.html has no {MARK} to fill")
    found = sections((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"))
    releases = json.loads((WEB / "releases.json").read_text(encoding="utf-8"))
    body = render(found, releases)
    if "<article" not in body:
        raise SystemExit("site: CHANGELOG.md gave the changelog page nothing to say")
    return template.replace(MARK, body)


def build(out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    count = 0
    for item in sorted(WEB.rglob("*")):
        rel = item.relative_to(WEB)
        if any(part.startswith(("_", ".")) for part in rel.parts) or not item.is_file():
            continue
        if rel.as_posix() == "img/manifest.json":
            continue
        target = out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        if rel.as_posix() == "changelog.html":
            target.write_text(changelog_page(), encoding="utf-8")
        else:
            shutil.copyfile(item, target)
        count += 1
    return count


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1].startswith("-"):
        print((__doc__ or "").strip())
        sys.exit(2)
    n = build(Path(sys.argv[1]))
    print(f"site: {n} file(s) in {sys.argv[1]}")
