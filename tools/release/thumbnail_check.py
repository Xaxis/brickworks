#!/usr/bin/env python3
"""Does the .deb give a file manager a picture of each model?

  thumbnail_check.py PACKAGE.deb --out=DIR [--trace] [MODEL...]
  thumbnail_check.py --root=DIR --out=DIR [MODEL...]     files dpkg-deb -x laid out
  thumbnail_check.py --installed --out=DIR [MODEL...]    the package installed in /

The package is installed by dpkg itself, into a root of its own (no root
needed), and the MIME database brought up to date as dpkg's trigger does.
Then GNOME's own thumbnail factory, which Files uses, is asked for each
model's picture at the size Files asks for (tools/release/gnome_thumbnail.py):
it finds the package's thumbnailer entry by the file's MIME type, runs it
through bubblewrap, and reads back the PNG. Where this machine cannot make
bubblewrap's namespaces (Ubuntu's unprivileged user namespace restriction),
bwrap is tools/release/bwrap_standin.py, which keeps GNOME's seccomp filter,
environment and binds but not the namespaces; --trace then follows the run
with strace and names every file the thumbnailer opened that the sandbox
would not have had. --installed uses the system's bwrap and must have a
working one.

Each model must come back drawn, at most 256 px a side, in 3 s or less from
asking, the model filling part of it on a clear ground; a .lxf is not
offered to the thumbnailer (the type's icon stays); a car with three parts no
library has is still drawn; a file of nothing but such parts is not (the
icon stays); and nothing is left in the person's home (the runner gives the
app a data folder of its own). Prints each check, writes DIR/thumbnails.json
and the pictures, and exits 0 only if every check held.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
APP_ID = "dev.brickworks.app"
MODELS = [ROOT / "models" / "car.ldr", ROOT / "tests" / "fixtures" / "steps" / "gatehouse.mpd",
          ROOT / "tests" / "fixtures" / "studio" / "gatehouse_2025.io",
          ROOT / "src" / "dev" / "fixtures" / "49311_test.lxf"]
DRAWN = ("ldr", "mpd", "io")
MOST_MS = 3000
LARGE = 256
# Parts no library has: a sticker, a number nobody made, a sub-file.
UNKNOWN = ("1 4 40 -24 0 1 0 0 0 1 0 0 0 1 bl_nosuchsticker.dat\n"
           "1 15 -40 -24 0 1 0 0 0 1 0 0 0 1 99999zz9.dat\n"
           "1 0 0 -48 0 1 0 0 0 1 0 0 0 1 wheel_not_here.ldr\n")
# What GNOME's sandbox has (libgnome-desktop 44's bwrap line): /usr, a few
# files of /etc, /proc, /dev, fontconfig's cache, and /tmp, the factory's
# folder with the model in it.
SANDBOX = ("/usr/", "/etc/ld.so.cache", "/etc/alternatives/", "/proc/", "/dev/",
           "/var/cache/fontconfig/", "/bin/", "/lib/", "/lib64/", "/sbin/")


def say(ok: bool | None, what: str) -> None:
    print("  %s  %s" % ("ok  " if ok else "--  " if ok is None else "FAIL", what), flush=True)


def install(package: Path, into: Path) -> tuple[bool, str]:
    """dpkg's own install into a root of its own: unpacked, configured and
    in its database. The C library it depends on is this machine's, which
    that database does not know, hence --force-depends."""
    admin = into / "var" / "lib" / "dpkg"
    for folder in ("info", "updates", "triggers"):
        (admin / folder).mkdir(parents=True, exist_ok=True)
    (admin / "status").touch()
    done = subprocess.run(["dpkg", "--root=%s" % into, "--admindir=%s" % admin,
                           "--force-not-root", "--force-script-chrootless", "--force-depends",
                           "--log=%s" % (into / "dpkg.log"), "-i", str(package)],
                          capture_output=True, text=True)
    listed = subprocess.run(["dpkg", "--root=%s" % into, "--admindir=%s" % admin, "-s",
                             "brickworks"], capture_output=True, text=True).stdout
    return done.returncode == 0 and "Status: install ok installed" in listed, \
        done.stdout + done.stderr + listed


def sandbox_works() -> bool:
    if not shutil.which("bwrap"):
        return False
    return subprocess.run(["bwrap", "--ro-bind", "/", "/", "--unshare-all", "true"],
                          capture_output=True).returncode == 0


def factory_env(home: Path, root: Path | None, standin: Path | None) -> dict[str, str]:
    """A desktop's environment, in a home of its own: the package's share/
    in XDG_DATA_DIRS and its bin/ on the PATH, as /usr's are."""
    env = {"HOME": str(home), "XDG_DATA_HOME": str(home / ".local" / "share"),
           "XDG_CONFIG_HOME": str(home / ".config"), "XDG_CACHE_HOME": str(home / ".cache"),
           "LANG": os.environ.get("LANG", "C.UTF-8"), "PATH": "/usr/bin:/bin"}
    if root is not None:
        env["XDG_DATA_DIRS"] = "%s:/usr/share" % (root / "usr" / "share")
        env["PATH"] = "%s:%s" % (root / "usr" / "bin", env["PATH"])
    if standin is not None:
        env["PATH"] = "%s:%s" % (standin, env["PATH"])
    return env


def ask(env: dict[str, str], out: Path, models: list[Path],
        trace: Path | None = None) -> list[dict]:
    command = [sys.executable, str(HERE / "gnome_thumbnail.py"), str(out)] + [str(m) for m in models]
    if trace is not None:
        command = ["strace", "-f", "-qq", "-e", "trace=%file,%process", "-o", str(trace)] + command
    done = subprocess.run(command, env=env, capture_output=True, text=True, timeout=600)
    said = [json.loads(line) for line in done.stdout.splitlines() if line.startswith("{")]
    if len(said) != len(models):
        raise SystemExit("the factory said %d of %d: %s" % (len(said), len(models),
                                                           done.stderr[-2000:]))
    return said


def outside_sandbox(trace: Path, root: Path, model: Path, tools: tuple[str, ...] = ()) -> list[str]:
    """Files the thumbnailer's processes found that GNOME's sandbox would not
    have had: from the runner's exec on, in it and every process it made,
    each path a call named and found (not -1) that is neither in SANDBOX,
    nor the package (under [root], which is /usr in an installed copy), nor
    the model, nor the factory's own folder (the sandbox's /tmp), nor
    [tools], this check's own (the preloaded sandbox_view.so)."""
    ours: set[str] = set()
    began = False
    pending: dict[str, str] = {}
    found: set[str] = set()
    for line in trace.read_text(errors="replace").splitlines():
        pid, _, call = line.partition(" ")
        call = call.strip()
        if call.endswith("<unfinished ...>"):
            pending[pid] = call[:-len("<unfinished ...>")]
            continue
        # A call strace split in two ends on a "<... NAME resumed>" line.
        resumed = re.match(r"<\.\.\. (\w+) resumed>", call)
        if resumed:
            call = pending.pop(pid, resumed.group(1) + "(") + call[resumed.end():]
        name = re.match(r"\w*", call).group(0)
        if not began:
            if name == "execve" and " = 0" in call and "brickworks-thumbnailer" in call.split(",")[0]:
                began = True
                ours.add(pid)
            continue
        if name in ("clone", "clone3", "fork", "vfork"):
            child = re.search(r"= (\d+)$", call)
            if pid in ours and child:
                ours.add(child.group(1))
            continue
        if pid not in ours or " = -1 " in call:
            continue
        named = re.search(r'"(/[^"]*)"', call)
        if not named:
            continue
        path = os.path.normpath(named.group(1))
        if path == str(model) or path in tools or path.startswith(str(root / "usr") + "/") \
                or path.startswith("/tmp/gnome-desktop-thumbnailer-"):
            continue
        if any(path.startswith(place) or path == place.rstrip("/") for place in SANDBOX):
            continue
        if path in ("/", "/etc", "/var", "/var/cache", "/tmp"):
            continue
        found.add(path)
    return sorted(found)


def main(argv: list[str]) -> int:
    options = [a for a in argv if a.startswith("--")]
    given = [Path(a) for a in argv if not a.startswith("--")]
    out = next((Path(a.split("=", 1)[1]) for a in options if a.startswith("--out=")), None)
    root_given = next((Path(a.split("=", 1)[1]) for a in options if a.startswith("--root=")), None)
    installed = "--installed" in options
    if out is None:
        raise SystemExit(__doc__)
    out = out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    package = given[0] if given and given[0].suffix == ".deb" else None
    models = [m.resolve() for m in (given[1:] if package else given)] or list(MODELS)
    failures = 0
    facts: dict = {"checks": []}

    def check(ok: bool | None, what: str) -> None:
        nonlocal failures
        say(ok, what)
        facts["checks"].append({"ok": ok, "what": what})
        if ok is False:
            failures += 1

    try:
        import gi  # noqa: F401
        gi.require_version("GnomeDesktop", "4.0")
    except (ImportError, ValueError) as error:
        check(None, "no GNOME thumbnail factory here (gir1.2-gnomedesktop-4.0): %s" % error)
        return 0

    work = Path(tempfile.mkdtemp(prefix="thumbnail-check-"))
    try:
        if package is not None:
            root = work / "root"
            ok, said = install(package, root)
            check(ok, "dpkg installs %s into a root of its own" % package.name)
            if not ok:
                print(said[-3000:])
                return 1
        else:
            root = root_given.resolve() if root_given else None
        if root is not None:
            subprocess.run(["update-mime-database", str(root / "usr" / "share" / "mime")],
                           capture_output=True)
            entry = root / "usr" / "share" / "thumbnailers" / (APP_ID + ".thumbnailer")
            check(entry.exists(), "its thumbnailer entry is in /usr/share/thumbnailers")
        standin = None
        built = False
        if installed:
            check(sandbox_works(), "this machine's bubblewrap makes GNOME's sandbox")
        else:
            standin = work / "sandbox"
            standin.mkdir()
            (standin / "bwrap").symlink_to(HERE / "bwrap_standin.py")
            view = work / "sandbox_view.so"
            built = shutil.which("cc") and subprocess.run(
                ["cc", "-shared", "-fPIC", "-O2", "-o", str(view), str(HERE / "sandbox_view.c"),
                 "-ldl"], capture_output=True).returncode == 0
            check(None, "bwrap is the stand-in (tools/release/bwrap_standin.py): GNOME's "
                  "seccomp filter, environment and binds, %s; %s" % (
                      "and only the files the sandbox has (sandbox_view.c)" if built else
                      "but every file of this machine's (no cc to build sandbox_view.c)",
                      "this machine makes no user namespaces"
                      if not sandbox_works() else "the package is not in this machine's /usr"))
        home = work / "home"
        home.mkdir()
        env = factory_env(home, root, standin)
        if standin is not None and built:
            env["BWRAP_STANDIN_VIEW"] = str(view)
            env["BWRAP_STANDIN_ALSO"] = str(root / "usr") if root is not None else ""
        unknown = out / "car with unknown parts.ldr"
        unknown.write_text((ROOT / "models" / "car.ldr").read_text() + UNKNOWN)
        nothing = out / "only unknown parts.ldr"
        nothing.write_text("0 Nothing a library has\n" + UNKNOWN)
        asked = models + [unknown, nothing]
        said = ask(env, out, asked)
        facts["thumbnails"] = said
        for model, made in zip(asked, said):
            ext = model.suffix[1:].lower()
            if model == nothing:
                check(not made.get("picture"), "%s: no picture, so the icon stays (%s)"
                      % (model.name, made.get("error", "drawn")))
                continue
            if ext not in DRAWN:
                check(not made["taken"], "a .%s (%s) is not offered to it: its icon stays"
                      % (ext, made["mime"]))
                continue
            size = made.get("size", [0, 0])
            check(made["taken"] and bool(made.get("picture")),
                  "%s (%s): drawn by the factory%s" % (model.name, made["mime"],
                                                       "" if made.get("picture") else
                                                       ", no: %s" % made.get("error")))
            check(made["ms"] <= MOST_MS, "%s: %d ms from asking to the picture (at most %d)"
                  % (model.name, made["ms"], MOST_MS))
            check(max(size) == LARGE, "%s: %d x %d px" % (model.name, size[0], size[1]))
            check(made.get("filled", 0) > 0.08 and made.get("alpha"),
                  "%s: the model fills %.0f%% of it, on a clear ground"
                  % (model.name, made.get("filled", 0) * 100))
        left = sorted(str(p.relative_to(home)) for p in home.rglob("*")
                      if "godot" in p.name.lower() or "brickworks" in p.name.lower())
        check(not left, "nothing of the app's in the home: %s" % (", ".join(left) or "none"))
        if "--trace" in options and root is not None and shutil.which("strace"):
            log = out / "trace.txt"
            first = models[0]
            ask(env, work / "traced", [first], log)
            strays = outside_sandbox(log, root, first, (env.get("BWRAP_STANDIN_VIEW", ""),))
            facts["outside_sandbox"] = strays
            check(not strays, "the thumbnailer opened nothing GNOME's sandbox lacks: %s"
                  % (", ".join(strays[:12]) or "none"))
        (out / "thumbnails.json").write_text(json.dumps(facts, indent=1) + "\n")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("thumbnails: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
