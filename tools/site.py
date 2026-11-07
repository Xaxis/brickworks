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
web/releases.json, so it can never say something the release notes do not;
and each language's copy of it (web/de/changelog.html, tools/site_lang.py),
its heads, links and dates in the language from its words
(web/<code>/words.json), the notes as written, in English (lang="en").
And the documentation at /docs is made from docs-site/ (tools/docs_site.py).

    tools/site.py --changelog=CODE   the changelog page in CODE's language
"""

from __future__ import annotations

import datetime
import html
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import docs_site  # noqa: E402  the documentation, /docs

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


def english(words: str) -> str:
    return words


def day(iso: str, say=english) -> str:
    """"2026-10-11" as "11 October 2026", in [say]'s language ("11. Oktober
    2026"); anything else as it is."""
    try:
        d = datetime.date.fromisoformat(iso)
    except ValueError:
        return html.escape(iso)
    month = (say("January"), say("February"), say("March"), say("April"), say("May"), say("June"), say("July"),
             say("August"), say("September"), say("October"), say("November"), say("December"))[d.month - 1]
    return say("{day} {month} {year}").replace("{day}", str(d.day)).replace("{month}", month).replace("{year}", str(d.year))


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


def render(found: list[dict], releases: dict, say=english, code: str = "en") -> str:
    """The releases as the changelog shows them: each one's head and date in
    [say]'s language, [code]'s, its link into the app in that language; its
    notes as they were written, in English."""
    by_version = {r["version"]: r for r in releases.get("releases", [])}
    app = "/app" if code == "en" else f"/app?lang={code}"
    notes = '<div class="release-notes">' if code == "en" else '<div class="release-notes" lang="en">'
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
        # Its name and date in a head of their own, which stays beside the
        # notes as they scroll on a laptop (web/changelog.html).
        parts.append('<div class="release-head">')
        if unreleased:
            parts.append(f'<h2 id="{anchor}-h">{html.escape(say("On the web now"))}</h2>')
            where = html.escape(say("In the app at {app}; in the next desktop release.")).replace(
                "{app}", f'<a href="{app}">brickworks.diy/app</a>')
            parts.append(f'<p class="when">{where}</p>')
        else:
            parts.append(f'<h2 id="{anchor}-h">Brickworks {html.escape(version)}</h2>')
            # Its date, and no link to its files: the desktop app is coming
            # soon (the owner, 2026-11-07), so neither /download nor the
            # release on GitHub is offered (tools/web/coming_soon_check.mjs).
            if date:
                parts.append(f'<p class="when"><time datetime="{html.escape(date)}">{html.escape(day(date, say))}</time></p>')
        parts.append(f'</div>\n{notes}')
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
        parts.append("</div>\n</article>")
    return "\n".join(parts)


def changelog_page(code: str = "en") -> str:
    """web/changelog.html filled, or [code]'s copy of it in its words."""
    name = "changelog.html" if code == "en" else f"{code}/changelog.html"
    template = (WEB / name).read_text(encoding="utf-8")
    if MARK not in template:
        raise SystemExit(f"site: web/{name} has no {MARK} to fill")
    found = sections((ROOT / "CHANGELOG.md").read_text(encoding="utf-8"))
    releases = json.loads((WEB / "releases.json").read_text(encoding="utf-8"))
    words = {} if code == "en" else json.loads((WEB / code / "words.json").read_text(encoding="utf-8"))
    body = render(found, releases, lambda english: words.get(english, english), code)
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
        if rel.name == "changelog.html":
            target.write_text(changelog_page(rel.parent.as_posix() if rel.parent.parts else "en"), encoding="utf-8")
        else:
            shutil.copyfile(item, target)
        count += 1
    return count + docs_site.build(out)


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1].startswith("--changelog="):
        sys.stdout.write(changelog_page(sys.argv[1].split("=", 1)[1]))
        sys.exit(0)
    if len(sys.argv) != 2 or sys.argv[1].startswith("-"):
        print((__doc__ or "").strip())
        sys.exit(2)
    n = build(Path(sys.argv[1]))
    print(f"site: {n} file(s) in {sys.argv[1]}")
