"""An export's engine and packs behind this checkout's loading page.

    python3 tools/web/shell_arm.py BASE OUT [--shell=src/boot/shell.html]

BASE is a web export (build/web, or a copy of one); OUT is made again from
it: every file hard-linked (each folder copied), except index.html, which
is SHELL filled with the values Godot put in BASE's own (the project's name,
the head include, the config and the threads flag), with its .br and .gz as
tools/export.sh makes them. Each inline script of the page is then parsed by
node. So two arms differ only in their loading page, and timing them side by
side (tools/web/start_abba.mjs) or flowing them (tools/web/bootlook_flow.mjs)
measures the page alone, without an export of its own (bootlook, 2026-11-23).
Filled from BASE's own shell, OUT's index.html is BASE's, byte for byte.
"""

from __future__ import annotations

import gzip
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGE = ("index.html", "index.html.br", "index.html.gz")


def found(pattern: str, page: str, what: str, flags: int = 0) -> str:
    said = re.search(pattern, page, flags)
    if said is None:
        raise SystemExit(f"shell_arm: BASE's index.html has no {what}: not a page Godot filled")
    return said.group(1)


def filled(shell: str, page: str) -> str:
    """SHELL with the values Godot put in PAGE in place of its placeholders."""
    name = found(r"<title>(.*?)</title>", page, "title")
    config = found(r"^const GODOT_CONFIG = (.*);$", page, "GODOT_CONFIG", re.M)
    threads = found(r"^const GODOT_THREADS_ENABLED = (.*);$", page, "GODOT_THREADS_ENABLED", re.M)
    # The head include: what stands between the engine's choice and </head>.
    head = found(r"\n\}\)\(\);\n</script>\n(.*?)\n</head>", page, "head include", re.S)
    for key, value in (("$GODOT_PROJECT_NAME", name), ("$GODOT_HEAD_INCLUDE", head),
                       ("$GODOT_CONFIG", config), ("$GODOT_THREADS_ENABLED", threads)):
        if key not in shell:
            raise SystemExit(f"shell_arm: the shell has no {key}")
        shell = shell.replace(key, value)
    # Godot ends the page with a line of its own.
    if page.endswith("\n\n") and not shell.endswith("\n\n"):
        shell += "\n"
    return shell


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    shell = next((a.split("=", 1)[1] for a in argv if a.startswith("--shell=")),
                 str(ROOT / "src/boot/shell.html"))
    if len(args) != 2:
        print("usage: python3 tools/web/shell_arm.py BASE OUT [--shell=src/boot/shell.html]")
        return 2
    base, out = Path(args[0]).resolve(), Path(args[1]).resolve()
    if not (base / "index.html").is_file():
        raise SystemExit(f"shell_arm: {base} has no index.html")
    if out == base or base in out.parents:
        raise SystemExit("shell_arm: OUT must stand apart from BASE")
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    for one in sorted(base.iterdir()):
        if one.is_dir():
            shutil.copytree(one, out / one.name)
        elif one.name not in PAGE:
            (out / one.name).hardlink_to(one)
    page = filled(Path(shell).read_text(encoding="utf-8"),
                  (base / "index.html").read_text(encoding="utf-8"))
    (out / "index.html").write_text(page, encoding="utf-8")
    subprocess.run(["node", "tools/web/brotli.mjs", str(out / "index.html"),
                    str(out / "index.html.br")], cwd=ROOT, check=True, stdin=subprocess.DEVNULL)
    (out / "index.html.gz").write_bytes(gzip.compress(page.encode("utf-8"), 9))
    scripts = re.findall(r"<script>(.*?)</script>", page, re.S)
    with tempfile.TemporaryDirectory() as scratch:
        for n, body in enumerate(scripts):
            one = Path(scratch) / f"{n}.js"
            one.write_text(body, encoding="utf-8")
            said = subprocess.run(["node", "--check", str(one)], capture_output=True, text=True,
                                  stdin=subprocess.DEVNULL)
            if said.returncode:
                print(f"shell_arm: the page's script {n + 1} does not parse:\n{said.stderr}")
                return 1
    same = page == (base / "index.html").read_text(encoding="utf-8")
    print(f"shell_arm: {out}, {sum(1 for _ in out.iterdir())} files, {len(scripts)} scripts parse"
          + (", its page BASE's own" if same else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
