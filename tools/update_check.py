#!/usr/bin/env python3
"""Prove the desktop app updates itself: packages of two versions, a test
server in place of GitHub's releases, and the real app driven through every
refusal and through a real install that restarts with the model kept.

    tools/update_check.py run --old FILE --new FILE [--port=N] [--log=FILE] [--system]
        FILE: two packages of one kind (AppImage, tar.xz, .deb, macOS disk
        image or Windows installer), the new one a newer version. Installs
        the old one as a person would, serves both, and drives the app
        (--update=...) through:
          refused: a bad signature, a wrong SHA-256, a wrong size, an older
          version, a plain-HTTP address, a redirect off the allowed hosts;
          Off, which asks nothing at a person's start where Automatic asks;
          Check for updates; Update and restart (the model kept); Restart;
          Reinstall; Automatic, put in as the app quits; and a new copy that
          cannot start (on a Mac and Windows, says the wrong version), put
          back. A .deb's copy is never swapped: the new .deb is downloaded
          into the app's own data and apt installs it as root; refused, or
          with no pkexec, it says so and offers the file.
        --system: the first copy where its installer puts it, /Applications,
        %LOCALAPPDATA%\\Programs or (the .deb, by sudo apt-get) /usr/lib, and
        taken away after: for a runner's throwaway machine, and refused
        where a Brickworks is already there. There the .deb is updated by
        apt for real, sudo standing in for pkexec's password dialog
    tools/update_check.py run --laid=DIR [--system]
        the same, served from a folder `lay` made: a runner on macOS or
        Windows has no signing key, so its manifests are signed here
    tools/update_check.py lay --old FILE --new FILE --port=N --out=DIR
        the packages and every scenario's signed manifest, for `run --laid`
        on another machine at the same port
    tools/update_check.py serve --dir=DIR [--port=N] [--seconds=N]
        the test server alone (src/dev/updater_probe.gd starts it), for
        --seconds or until stopped
    tools/update_check.py trim --out=DIR
        a small part library for test packages: the parts the shipped models
        use, with their meshes, and the rest of assets/generated's tables
    tools/update_check.py packages --versions=A,B --out=DIR [linux mac windows]
        build this commit as versions A and B with the small library, each in
        a throwaway worktree (the version is a commit there, never here)

The manifests it serves are signed with the real keys (.env, as
tools/release.py signs a release's), since a package believes only the keys
it carries. The app is pointed at the server by BRICKWORKS_UPDATE_URL, which
only a person sets by hand (Updates.test_base). docs/UPDATES.md is the design.
"""

from __future__ import annotations

import http.server
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import urllib.parse
import zipfile
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import release  # noqa: E402

ROOT = HERE.parent


def say(text: str) -> None:
    print(text, flush=True)


# -- the server --------------------------------------------------------------

class Handler(http.server.SimpleHTTPRequestHandler):
    """Files from the folder, and four kinds of redirect:
    /redirect/X to /X on this host; /redirect-off/X to https://example.com/X;
    /redirect-localhost/X to http://localhost:PORT/X (another host, plain HTTP);
    /redirect-to?LOCATION to LOCATION as it is, %-escaped in the address.
    Every address asked is kept in the server's `asked`."""

    def do_GET(self) -> None:  # noqa: N802
        self.server.asked.append(self.path)
        if self.path.startswith("/redirect-to?"):
            self.send_response(302)
            self.send_header("Location", urllib.parse.unquote(self.path[len("/redirect-to?"):]))
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        for prefix, to in (("/redirect-off/", "https://example.com/"),
                           ("/redirect-localhost/", "http://localhost:%d/" % self.server.server_port),
                           ("/redirect/", "/")):
            if self.path.startswith(prefix):
                self.send_response(302)
                self.send_header("Location", to + self.path[len(prefix):])
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        super().do_GET()

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        if os.environ.get("UPDATE_CHECK_VERBOSE"):
            super().log_message(format, *args)


class Server(http.server.ThreadingHTTPServer):
    asked: list[str]

    def handle_error(self, request: Any, client_address: Any) -> None:
        # The app hanging up on a download it refused is the point, not an error.
        if not isinstance(sys.exc_info()[1], (ConnectionResetError, BrokenPipeError)):
            super().handle_error(request, client_address)


def serve(folder: Path, port: int) -> Server:
    handler = lambda *a, **k: Handler(*a, directory=str(folder), **k)  # noqa: E731
    server = Server(("127.0.0.1", port), handler)
    server.asked = []
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# -- manifests ---------------------------------------------------------------

def version_in(name: str) -> str:
    # The system after it, or "-linux" reads as a pre-release.
    found = re.match(r"Brickworks-(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)-(?:linux|macos|windows)-", name)
    if not found:
        raise SystemExit("no version in %s" % name)
    return found.group(1)


def entry(package: Path, url: str, size: int | None = None, sha: str | None = None) -> dict[str, Any]:
    facts = release.describe_file(package.name)
    return {"os": facts["os"], "kind": facts["kind"], "name": package.name, "url": url,
            "size": package.stat().st_size if size is None else size,
            "sha256": release.sha256_of(package) if sha is None else sha}


def manifest(version: str, files: list[dict[str, Any]], notes: str = "") -> dict[str, Any]:
    return {"product": release.UPDATE_PRODUCT, "version": version, "date": time.strftime("%Y-%m-%d"),
            "tag": "v" + version, "page": "https://github.com/%s/releases/tag/v%s" % (release.REPO, version),
            "notes": notes or "A test release of %s, made by tools/update_check.py." % version,
            "files": files}


def put(folder: Path, envelope: dict[str, Any]) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "latest.json").write_text(json.dumps(envelope, indent=1))


def broken(package: Path, into: Path, old: Path) -> Path:
    """A package of the same name whose program cannot start: an update
    that passes every check but the copy's own start (Updater's put back).
    On a Mac an app that will not start fails its code signature first, and
    an installer is a program of its own, so there it is the old version
    under the new one's name, which the helper puts back as surely: it says
    the wrong version."""
    into.mkdir(parents=True, exist_ok=True)
    target = into / package.name
    version = version_in(package.name)
    if package.name.endswith((".dmg", "-setup.exe", ".deb")):
        shutil.copy2(old, target)
        return target
    stop = b"#!/bin/sh\necho 'not Brickworks'\nexit 3\n"
    if package.name.endswith(".AppImage"):
        target.write_bytes(stop)
        target.chmod(0o755)
    elif package.name.endswith(".tar.xz"):
        folder = "Brickworks-%s-linux-x86_64" % version
        with tarfile.open(target, "w:xz") as archive:
            info = tarfile.TarInfo(folder + "/brickworks.x86_64")
            info.size, info.mode = len(stop), 0o755
            import io
            archive.addfile(info, io.BytesIO(stop))
    else:
        with zipfile.ZipFile(target, "w") as archive:
            folder = "Brickworks-%s-windows-x86_64" % version
            archive.writestr(folder + "/Brickworks.exe", stop)
            archive.writestr(folder + "/Brickworks.console.exe", stop)
    return target


def lay_out(serve_dir: Path, old: Path, new: Path, port: int) -> dict[str, str]:
    """Every scenario's manifest in a folder of its own, each the base the
    app is pointed at. What each is for, by name."""
    base = "http://127.0.0.1:%d/" % port
    files = serve_dir / "files"
    files.mkdir(parents=True)
    for package in (old, new):
        release.link_or_copy(package, files / package.name)
    bad = broken(new, files / "broken", old)
    A, B = version_in(old.name), version_in(new.name)
    url = lambda name: base + "files/" + name  # noqa: E731
    good = manifest(B, [entry(new, url(new.name))],
                    "Test release %s: the notice's What's new comes from here." % B)
    scenarios: dict[str, str] = {}

    def scenario(name: str, envelope: dict[str, Any], why: str) -> None:
        put(serve_dir / name / "latest" / "download", envelope)
        scenarios[name] = why

    signed = release.sign_update_manifest(good)
    scenario("good", signed, "a newer version, signed")
    put(serve_dir / "good" / "download" / ("v" + B), signed)
    put(serve_dir / "good" / "download" / ("v" + A),
        release.sign_update_manifest(manifest(A, [entry(old, url(old.name))])))
    forged = dict(signed)
    forged["signed"] = signed["signed"].replace(release.sha256_of(new), "0" * 64)
    scenario("badsig", forged, "the manifest changed after it was signed")
    scenario("badhash", release.sign_update_manifest(
        manifest(B, [entry(new, url(new.name), sha="1" * 64)])), "a SHA-256 not the file's")
    scenario("badsize", release.sign_update_manifest(
        manifest(B, [entry(new, url(new.name), size=new.stat().st_size - 1)])),
        "a size not the file's")
    scenario("older", release.sign_update_manifest(manifest("0.0.1", [entry(new, url(new.name))])),
             "an older version")
    scenario("plainhttp", release.sign_update_manifest(
        manifest(B, [entry(new, "http://example.com/files/" + new.name)])), "a plain-HTTP address")
    scenario("offhost", release.sign_update_manifest(
        manifest(B, [entry(new, base + "redirect-off/files/" + new.name)])),
        "a redirect to example.com")
    # Not named "redirect": the server sends /redirect/... on to /...
    scenario("hop", release.sign_update_manifest(
        manifest(B, [entry(new, base + "redirect/files/" + new.name)])),
        "a redirect on the same host, followed")
    scenario("broken", release.sign_update_manifest(
        manifest(B, [entry(bad, url("broken/" + bad.name))])), "a copy that cannot start")
    (serve_dir / "laid.json").write_text(json.dumps(
        {"port": port, "old": old.name, "new": new.name, "scenarios": scenarios}, indent=1))
    return scenarios


# -- running the app ---------------------------------------------------------

def program_in(package: Path, install: Path, system: bool = False) -> Path:
    """The package installed in [install] as a person installs it: the disk
    image's app dragged out of it, the installer run silently into a folder
    there, the .deb's files where dpkg puts them (under [install]/root,
    which needs no root). [system]: the first copy where its installer puts
    it, /Applications or the installer's own folder."""
    name = package.name
    if name.endswith(".dmg"):
        app = Path("/Applications/Brickworks.app") if system else install / "Brickworks.app"
        if app.exists():
            raise release.Failed("%s is there already: --system is for a throwaway machine" % app)
        with tempfile.TemporaryDirectory(prefix="brickworks-dmg-") as scratch:
            mount = Path(scratch) / "volume"
            mount.mkdir()
            subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount),
                            str(package)], check=True, capture_output=True)
            try:
                subprocess.run(["ditto", str(mount / "Brickworks.app"), str(app)], check=True)
            finally:
                subprocess.run(["hdiutil", "detach", str(mount)], capture_output=True)
        return app / "Contents" / "MacOS" / "Brickworks"
    if name.endswith("-setup.exe"):
        folder = release.WINDOWS_INSTALLED if system else install / "Brickworks"
        if folder.exists():
            raise release.Failed("%s is there already: --system is for a throwaway machine" % folder)
        # As the updater runs it; /D= (NSIS's folder) last, and only for a
        # folder of the test's own.
        done = subprocess.run([str(package), "/VERYSILENT"] + ([] if system else ["/D=%s" % folder]),
                              timeout=1200)
        if done.returncode != 0:
            raise release.Failed("%s /VERYSILENT exited %d" % (name, done.returncode))
        return folder / "Brickworks.console.exe"
    return release.unpack(package, install)


def take_away(programs: list[Path], system: bool) -> None:
    """The test's installs gone: each installer's copy by its own
    uninstaller, and what --system put in a person's places."""
    for program in programs:
        folder = program.parent
        uninstaller = folder / "Uninstall Brickworks.exe"
        if os.name == "nt" and uninstaller.exists():
            # _?= runs it in place, so it is waited for, and leaves the folder.
            subprocess.run([str(uninstaller), "/S", "_?=%s" % folder], timeout=300)
            shutil.rmtree(folder, ignore_errors=True)
    if system:
        place = Path("/Applications") if sys.platform == "darwin" else release.WINDOWS_INSTALLED.parent
        shutil.rmtree(place / ".brickworks-update", ignore_errors=True)
        if sys.platform == "darwin":
            shutil.rmtree(place / "Brickworks.app", ignore_errors=True)
        else:
            shutil.rmtree(release.WINDOWS_INSTALLED, ignore_errors=True)


LISTING = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Brickworks"


def listed() -> str:
    """The version Settings, Apps lists for Brickworks: the installer's."""
    done = subprocess.run(["reg", "query", LISTING, "/v", "DisplayVersion"], capture_output=True, text=True)
    found = re.search(r"DisplayVersion\s+REG_SZ\s+(\S+)", done.stdout)
    return found.group(1) if found else ""


def has_key(key: str) -> bool:
    return subprocess.run(["reg", "query", key], capture_output=True).returncode == 0


def uninstalled(folder: Path) -> tuple[str, bool, str]:
    """The copy's own uninstaller run as Settings, Apps runs it, and what it
    leaves: nothing of the app, its listing, its Start menu entry or its
    file types (the person's models are in their own folder)."""
    subprocess.run([str(folder / "Uninstall Brickworks.exe"), "/S"], timeout=600)
    # It runs from a copy of itself, so its own exit says nothing: the
    # folder going says it is done.
    end = time.time() + 300
    while (folder / "Brickworks.exe").exists() and time.time() < end:
        time.sleep(2)
    start_menu = Path(os.environ["APPDATA"]) / "Microsoft" / "Windows" / "Start Menu" / "Programs" \
        / "Brickworks.lnk"
    left = sorted(p.name for p in folder.glob("*")) if folder.exists() else []
    left += [key for key in (LISTING, r"HKCU\Software\Brickworks", r"HKCU\Software\Classes\Brickworks.ldr")
             if has_key(key)]
    left += [str(start_menu)] if start_menu.exists() else []
    return ("Uninstall leaves nothing of it: %s" % (", ".join(left) or
            "no file, no Settings, Apps entry, no Start menu entry, no file type"), not left, "")


def apt(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["sudo", "apt-get", *args], capture_output=True, text=True, timeout=900)


def tree(folder: Path) -> dict[str, tuple[int, int, int]]:
    """Every file and link under [folder], with its size, time and mode."""
    out: dict[str, tuple[int, int, int]] = {}
    for path in sorted(folder.rglob("*")):
        facts = path.lstat()
        out[str(path.relative_to(folder))] = (facts.st_size, facts.st_mtime_ns, facts.st_mode)
    return out


def user_dir(home: Path) -> Path:
    if sys.platform == "darwin":
        return home / "Library" / "Application Support" / "Godot" / "app_userdata" / "Brickworks"
    if os.name == "nt":
        return home / "AppData" / "Roaming" / "Godot" / "app_userdata" / "Brickworks"
    return home / ".local" / "share" / "godot" / "app_userdata" / "Brickworks"


# How long a person's start is watched for the day's check: the window up
# (Main) and Updater.AFTER_START_S, 8 s, after it, on a runner's slowest start.
QUIET_S = 90


class Run:
    def __init__(self, old: Path, new: Path, port: int, root: Path) -> None:
        self.old, self.new, self.port, self.root = old, new, port, root
        self.A, self.B = version_in(old.name), version_in(new.name)
        self.failures = 0
        # On a Mac the new copy is started by `open`, and launchd gives it the
        # session's own environment, not this one's: so the real home there
        # (a runner's is a throwaway), and a clean one elsewhere.
        self.home = Path.home() if sys.platform == "darwin" else root / "home"
        self.env = release.clean_env(root / "home")
        # The updater is what is tested here: in its default, Automatic.
        self.env.pop("BRICKWORKS_UPDATES", None)
        if sys.platform == "darwin":
            self.env.update({"HOME": str(Path.home())})
        self.log = user_dir(self.home) / "updates" / "log.txt"

    def check(self, what: str, ok: bool, detail: str = "") -> None:
        say("  %s  %s" % ("ok  " if ok else "FAIL", what))
        if not ok:
            self.failures += 1
            for line in detail.strip().splitlines()[-15:]:
                say("        " + line)

    def app(self, program: Path, base: str, user: list[str], seconds: int = 300,
            person: bool = False, more: dict[str, str] | None = None) -> tuple[int, str]:
        """[person]: started as a person starts it, for a step judged by the
        updater's log. On Windows that is Brickworks.exe, not the console
        wrapper, which keeps all the app starts in a job of its own and runs
        until the last has ended (Godot's console_wrapper_windows.cpp): the
        new copy among them, so the old wrapper's own file could not go."""
        env = dict(self.env, BRICKWORKS_UPDATE_URL="http://127.0.0.1:%d/%s/" % (self.port, base),
                   **(more or {}))
        if person and program.name == "Brickworks.console.exe":
            program = program.with_name("Brickworks.exe")
        return release.run_app([str(program), "--headless", "--", *user], env, seconds)

    def started_asks(self, program: Path, base: str, server: Server,
                     stop_when_asked: bool) -> tuple[float, list[str], str]:
        """Started as a person starts it, with nothing asked of the updater,
        for QUIET_S at most (to its first request with [stop_when_asked]):
        when it first asked the server, in seconds from its start (-1 for
        never), every address it asked, and what it said."""
        env = dict(self.env, BRICKWORKS_UPDATE_URL="http://127.0.0.1:%d/%s/" % (self.port, base))
        if program.name == "Brickworks.console.exe":
            program = program.with_name("Brickworks.exe")
        server.asked.clear()
        began, when = time.time(), -1.0
        with tempfile.TemporaryFile("w+", errors="replace") as log:
            process = subprocess.Popen([str(program), "--headless"], env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
            try:
                while time.time() - began < QUIET_S and process.poll() is None:
                    if server.asked and when < 0:
                        when = time.time() - began
                        if stop_when_asked:
                            break
                    time.sleep(0.5)
            finally:
                if process.poll() is None:
                    if os.name != "nt":
                        os.killpg(process.pid, signal.SIGKILL)
                    else:
                        release.end_tree(process.pid)
                    process.wait()
            log.seek(0)
            output = log.read()
        return when, list(server.asked), output

    def off_asks_nothing(self, program: Path, server: Server) -> None:
        """Settings, Updates, Off: a person's start asks nothing in the time
        the same start in Automatic asks (the day's check, Updater's
        AFTER_START_S after the window is up), so the quiet is the setting's
        and not a slow start. Off first: Automatic's check is the day's, and
        a start after it would not ask again. Both on the same feed."""
        prefs = user_dir(self.home) / "shell.cfg"
        prefs.parent.mkdir(parents=True, exist_ok=True)
        prefs.write_text('[shell]\n\nupdates="off"\n')
        _, off, said_off = self.started_asks(program, "older", server, False)
        prefs.write_text('[shell]\n\nupdates="auto"\n')
        when, auto, said_auto = self.started_asks(program, "older", server, True)
        prefs.unlink(missing_ok=True)
        self.check("Off asks nothing: %s in %d s, where Automatic's same start asked %s %.0f s in"
                   % (", ".join(off) or "no request", QUIET_S, ", ".join(auto) or "nothing", when),
                   not off and when >= 0, said_off + "\n" + said_auto)

    def about(self, program: Path) -> str:
        code, output = release.run_app([str(program), "--headless", "--", "--about"], self.env, 180)
        return next((line for line in output.splitlines() if line.startswith("Brickworks ")), "")

    def log_after(self, mark: int, words: str, seconds: int = 300) -> str:
        """The updater's log from [mark] bytes on, once it has a line with
        [words] in it, or what it has when the time runs out."""
        until = time.time() + seconds
        text = ""
        while time.time() < until:
            if self.log.exists():
                text = self.log.read_text(errors="replace")[mark:]
                if words in text:
                    return text
            time.sleep(1)
        return text

    def mark(self) -> int:
        return len(self.log.read_text(errors="replace")) if self.log.exists() else 0

    def staged(self, install: Path) -> list[str]:
        stage = install / ".brickworks-update"
        return sorted(str(p.relative_to(install)) for p in stage.rglob("*")) if stage.exists() else []


def drive_deb(old: Path, new: Path, port: int, keep_log: Path | None, laid: Path | None = None,
              system: bool = False) -> int:
    """A copy installed from the .deb: dpkg's files are never swapped. It
    refuses what every copy refuses, and the new .deb is downloaded into
    the app's own data, checked, and installed
    by apt as root. A stand-in for pkexec says no, then none is there: each
    is said, and the file offered. Then it goes in as dpkg puts it, each
    file renamed over the old one's while the old copy runs (a stand-in for
    apt here), and the copy comes back as the new version with the model
    kept. With [system] (a runner) apt installed the old copy itself, and
    the update goes in by apt for real, sudo standing in for pkexec's
    password dialog; then apt removes it."""
    with tempfile.TemporaryDirectory(prefix="brickworks-update-", ignore_cleanup_errors=True) as scratch:
        root = Path(scratch)
        serve_dir = laid if laid is not None else root / "serve"
        scenarios = lay_out(serve_dir, old, new, port) if laid is None \
            else json.loads((laid / "laid.json").read_text())["scenarios"]
        server = serve(serve_dir, port)
        run = Run(old, new, port, root)
        say("── %s → %s, deb%s, served at http://127.0.0.1:%d/ ──" % (
            run.A, run.B, ", installed by apt" if system else "", port))
        asked = root / "asked.txt"
        refuse = root / "refuse.sh"
        refuse.write_text('#!/bin/sh\necho "$*" > "%s"\nexit 126\n' % asked)
        refuse.chmod(0o755)
        # dpkg's way, without root: unpacked aside, then each file renamed
        # into place, a new file under the old name, as the old copy runs.
        dpkg = root / "dpkg.sh"
        dpkg.write_text('#!/bin/sh\n# $1 /usr/bin/apt-get, $2 install, $3 -y, $4 the .deb\nset -e\n'
                        'aside="%s"; into="%s"\nrm -rf "$aside"; dpkg-deb -x "$4" "$aside"\n'
                        'cd "$aside"\nfind . -type f | while read -r f; do\n'
                        '  mkdir -p "$into/$(dirname "$f")"; mv -f "$f" "$into/$f"\ndone\n'
                        % (root / "aside", root / "install" / "root"))
        dpkg.chmod(0o755)
        staged = user_dir(run.home) / ".brickworks-update" / run.B / new.name
        try:
            if system:
                if Path("/usr/lib/brickworks").exists():
                    raise release.Failed("/usr/lib/brickworks is there already: --system is for a "
                                         "throwaway machine")
                done = apt("install", "-y", str(old))
                if done.returncode != 0:
                    raise release.Failed("apt-get install %s: %s" % (old.name, done.stderr[-500:]))
                install, program = Path("/usr/lib/brickworks"), Path("/usr/bin/brickworks")
            else:
                install = root / "install"
                install.mkdir()
                program = program_in(old, install)
            said = run.about(program)
            run.check("the old copy, in usr/lib/brickworks as dpkg puts it, says %s" % said,
                      said.startswith("Brickworks %s" % run.A))
            run.off_asks_nothing(program, server)
            for name in ("badsig", "badhash", "badsize", "older", "plainhttp", "offhost"):
                code, output = run.app(program, name, ["--update=fetch"])
                verdict = next((line for line in output.splitlines()
                                if line.startswith("update: fetch: ")), "(nothing said)")
                run.check("refuses %s: %s" % (scenarios[name], verdict.removeprefix("update: fetch: ")),
                          "refused" in verdict and not staged.exists(), output)
            before = tree(install)
            code, output = run.app(program, "good", ["--update=check"])
            verdict = next((line for line in output.splitlines() if line.startswith("update: check: ")), "")
            run.check("Check for updates: %s" % verdict.removeprefix("update: check: "),
                      code == 0 and "Brickworks %s is out" % run.B in verdict, output)
            for stand_in, words in ((refuse, "the password was refused or not given"),
                                    (root / "no-pkexec", "pkexec isn't on this system")):
                code, output = run.app(program, "good", ["--update=install"],
                                       more={"BRICKWORKS_UPDATE_ELEVATE": str(stand_in)})
                verdict = next((line for line in output.splitlines()
                                if line.startswith("update: install: ")), "(nothing said)")
                shown = next((line for line in output.splitlines() if line.startswith("update: show: ")), "")
                run.check("Update and restart %s: %s; it offers %s" % (
                    "with pkexec refused" if stand_in == refuse else "with no pkexec",
                    verdict.removeprefix("update: install: "), shown.removeprefix("update: show: ")),
                    code == 1 and words in verdict and shown == "update: show: %s" % staged
                    and staged.exists() and release.sha256_of(staged) == release.sha256_of(new), output)
            elevated = asked.read_text().strip() if asked.exists() else "(not asked)"
            run.check("...apt was asked for the checked .deb, as root: %s" % elevated,
                      elevated == "/usr/bin/apt-get install -y %s" % staged)
            after = tree(install)
            run.check("nothing dpkg put there was changed", after == before,
                      "\n".join(sorted(str(x) for x in set(after.items()) ^ set(before.items())))[:2000])
            if not system:
                said = run.about(program)
                run.check("the copy is still %s" % run.A, said.startswith("Brickworks %s" % run.A))
            mark = run.mark()
            code, output = run.app(program, "good", ["--model=res://models/house.ldr", "--update=install"],
                                   more={"BRICKWORKS_UPDATE_ELEVATE": "sudo" if system else str(dpkg)})
            text = run.log_after(mark, "report:")
            before_ = re.search(r"restart: model “([^”]*)”, (\d+) parts; session (\w+)", text)
            after_ = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts; session (\w+)", text)
            run.check("Update and restart, %s: %s" % (
                "apt installing it by sudo in pkexec's place" if system
                else "its files renamed in as dpkg does while the old copy runs",
                after_.group(0) if after_ else "no report"),
                bool(before_ and after_) and after_.group(1) == run.B
                and after_.groups()[1:] == before_.groups() and int(after_.group(3)) > 0,
                output + "\n" + text)
            said = run.about(program)
            if system:
                listed_ = subprocess.run(["dpkg-query", "-W", "-f", "${Version}", "brickworks"],
                                         capture_output=True, text=True).stdout.strip()
                run.check("dpkg lists brickworks %s, and the copy says %s" % (listed_, said),
                          listed_ == run.B and said.startswith("Brickworks %s" % run.B))
            else:
                run.check("the copy says %s" % said, said.startswith("Brickworks %s" % run.B))
            time.sleep(2)
            run.check("the downloaded .deb is gone once the new copy started",
                      not staged.parent.exists())
            if system:
                done = apt("remove", "-y", "brickworks")
                left = [str(path) for path in (Path("/usr/lib/brickworks"), Path("/usr/bin/brickworks"))
                        if path.exists() or path.is_symlink()]
                run.check("apt remove leaves nothing of it: %s" % (", ".join(left) or "nothing left"),
                          done.returncode == 0 and not left, done.stderr)
        finally:
            server.shutdown()
            if keep_log is not None and run.log.exists():
                keep_log.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(run.log, keep_log)
            if system and Path("/usr/lib/brickworks").exists():
                apt("remove", "-y", "brickworks")
    say("")
    if run.failures:
        say("%d check(s) failed: the .deb's copy does not update by apt" % run.failures)
        return 1
    say("%s → %s: the .deb's copy downloads the new .deb, and apt installs it%s" % (
        old.name, new.name, " by sudo" if system else " (refused and missing here, then put in the dpkg way)"))
    return 0


def drive(old: Path, new: Path, port: int, keep_log: Path | None, laid: Path | None = None,
          system: bool = False) -> int:
    if release.describe_file(old.name)["kind"] == "deb":
        return drive_deb(old, new, port, keep_log, laid, system)
    programs: list[Path] = []
    with tempfile.TemporaryDirectory(prefix="brickworks-update-", ignore_cleanup_errors=True) as scratch:
        root = Path(scratch)
        serve_dir = root / "serve"
        if laid is None:
            scenarios = lay_out(serve_dir, old, new, port)
        else:
            serve_dir = laid
            scenarios = json.loads((laid / "laid.json").read_text())["scenarios"]
        server = serve(serve_dir, port)
        run = Run(old, new, port, root)
        say("── %s → %s, %s, served at http://127.0.0.1:%d/ ──" % (run.A, run.B,
            release.describe_file(old.name)["kind"], port))
        try:
            install = root / "install"
            install.mkdir()
            program = program_in(old, install, system)
            programs.append(program)
            if system:
                install = program.parents[3] if sys.platform == "darwin" else program.parents[1]
            said = run.about(program)
            run.check("the old copy says %s" % said, said.startswith("Brickworks %s" % run.A))
            run.off_asks_nothing(program, server)

            for name in ("badsig", "badhash", "badsize", "older", "plainhttp", "offhost"):
                code, output = run.app(program, name, ["--update=fetch"])
                verdict = next((line for line in output.splitlines()
                                if line.startswith("update: fetch: ")), "(nothing said)")
                refused = "refused" in verdict
                run.check("refuses %s: %s" % (scenarios[name], verdict.removeprefix("update: fetch: ")),
                          refused and run.staged(install) in ([], [".brickworks-update/" + run.B]),
                          output)
            said = run.about(program)
            run.check("after every refusal the copy is still %s" % run.A,
                      said.startswith("Brickworks %s" % run.A))

            code, output = run.app(program, "good", ["--update=check"])
            verdict = next((line for line in output.splitlines() if line.startswith("update: check: ")), "")
            run.check("Check for updates: %s" % verdict.removeprefix("update: check: "),
                      code == 0 and "Brickworks %s is out" % run.B in verdict, output)

            # Update and restart, from a run with a model open: the copy that
            # comes back is the new version, in the same session, on that model.
            mark = run.mark()
            code, output = run.app(program, "hop", ["--model=res://models/house.ldr",
                                                         "--update=install"], person=True)
            text = run.log_after(mark, "report:")
            before = re.search(r"restart: model “([^”]*)”, (\d+) parts; session (\w+)", text)
            after = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts; session (\w+)", text)
            run.check("Update and restart (by a redirect on the same host): %s"
                      % (after.group(0) if after else "no report"),
                      bool(before and after) and after.group(1) == run.B
                      and after.group(2) == before.group(1) and after.group(3) == before.group(2)
                      and after.group(4) == before.group(3) and int(after.group(3)) > 0,
                      output + "\n" + text)
            run.log_after(mark, "is up", 60)
            said = run.about(program)
            run.check("the copy in place says %s" % said, said.startswith("Brickworks %s" % run.B))
            installer = old.name.endswith("-setup.exe")
            if installer:
                run.check("Settings, Apps lists %s" % listed(), listed() == run.B)
            if installer and system:
                # The Start menu entry and the file types the update wrote.
                start_menu = Path(os.environ["APPDATA"]) / "Microsoft" / "Windows" / "Start Menu" \
                    / "Programs" / "Brickworks.lnk"
                run.check("...with its Start menu entry and .ldr opening in it",
                          start_menu.exists() and has_key(r"HKCU\Software\Classes\Brickworks.ldr"))
            time.sleep(2)
            run.check("the old copy is gone once the new one started: %s" % (run.staged(install) or "nothing left"),
                      not run.staged(install))

            mark = run.mark()
            run.app(program, "good", ["--update=restart"], person=True)
            text = run.log_after(mark, "report:")
            after2 = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts; session (\w+)", text)
            run.check("Restart Brickworks: %s" % (after2.group(0) if after2 else "no report"),
                      bool(after and after2) and after2.groups() == after.groups(), text)

            mark = run.mark()
            code, output = run.app(program, "good", ["--update=reinstall"], person=True)
            text = run.log_after(mark, "report:")
            after3 = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts", text)
            run.check("Reinstall Brickworks: %s" % (after3.group(0) if after3 else "no report"),
                      bool(after3) and after3.group(1) == run.B
                      and "started %s (from %s)" % (run.B, run.B) in text, output + "\n" + text)
            run.log_after(mark, "is up", 60)
            if installer and system:
                time.sleep(3)
                run.check(*uninstalled(program.parent))

            # Automatic: downloaded, then put in as the app quits; the next
            # start is the new version.
            again = root / "install2"
            again.mkdir()
            program2 = program_in(old, again)
            programs.append(program2)
            mark = run.mark()
            code, output = run.app(program2, "good", ["--update=fetch"], person=True)
            text = run.log_after(mark, "the new copy says it is", 180)
            said = run.about(program2)
            run.check("Automatic: fetched, put in as it quit; the next start says %s" % said,
                      said.startswith("Brickworks %s" % run.B), output + "\n" + text)

            # A new copy that cannot start: the old one put back, and started.
            again = root / "install3"
            again.mkdir()
            program3 = program_in(old, again)
            programs.append(program3)
            if installer:
                # Marked, since the broken installer is A's and lists A too: put
                # back, the listing is the one from before, word for word.
                subprocess.run(["reg", "add", LISTING, "/v", "DisplayVersion", "/d", run.A + "-before", "/f"],
                               capture_output=True)
            mark = run.mark()
            code, output = run.app(program3, "broken", ["--model=res://models/house.ldr",
                                                       "--update=install"], person=True)
            text = run.log_after(mark, "report:")
            back = re.search(r"report: running (\S+);", text)
            said = run.about(program3)
            run.check("a new copy that cannot start is put back: %s, and %s started again"
                      % (said, back.group(1) if back else "nothing"),
                      said.startswith("Brickworks %s" % run.A) and bool(back)
                      and back.group(1) == run.A and "putting the old copy back" in text,
                      output + "\n" + text)
            if installer:
                run.check("...and Settings, Apps lists what it did before: %s" % listed(),
                          listed() == run.A + "-before")
        finally:
            server.shutdown()
            if keep_log is not None and run.log.exists():
                keep_log.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(run.log, keep_log)
            take_away(programs, system)
    say("")
    if run.failures:
        say("%d check(s) failed: the %s package does not update itself" % (
            run.failures, release.describe_file(old.name)["kind"]))
        return 1
    say("%s → %s: every refusal held, and it updates, restarts, reinstalls and puts back"
        % (old.name, new.name))
    return 0


# -- small test packages -----------------------------------------------------

def trim(out: Path) -> int:
    """assets/generated with only the parts the shipped models use."""
    source = ROOT / "assets" / "generated"
    catalogue = json.loads((source / "catalogue.json").read_text())
    used: set[str] = set()
    for model in (ROOT / "models").glob("*.ldr"):
        for line in model.read_text(errors="replace").splitlines():
            parts = line.split()
            if len(parts) >= 15 and parts[0] == "1":
                used.add(parts[14].lower().removesuffix(".dat"))
    kept = [p for p in catalogue["parts"] if p["id"].lower() in used]
    catalogue["parts"] = kept
    out.mkdir(parents=True, exist_ok=True)
    (out / "parts").mkdir(exist_ok=True)
    (out / "catalogue.json").write_text(json.dumps(catalogue))
    for table in source.glob("*.json"):
        if table.name != "catalogue.json":
            shutil.copy2(table, out / table.name)
    for part in kept:
        if part.get("mesh"):
            release.link_or_copy(source / "parts" / (part["mesh"] + ".lbm"),
                                 out / "parts" / (part["mesh"] + ".lbm"))
    say("trimmed to %d parts, the shipped models' own: %s" % (len(kept), out))
    return 0


def packages(versions: list[str], platforms: list[str], out: Path) -> int:
    """This commit built as each version, in a throwaway worktree."""
    commit = release.git("rev-parse", "HEAD")
    # Only what is committed is built: changes left in the app would be
    # proven by packages that do not have them.
    changed = release.git("status", "--porcelain", "--", "src", "project.godot", "export_presets.cfg")
    if changed:
        raise release.Failed("packages build HEAD (%s), and these changes are not in it: commit "
                             "them first\n%s" % (commit[:8], changed))
    small = out / "assets"
    if not (small / "catalogue.json").exists():
        trim(small)
    for version in versions:
        tree = out / ("tree-" + version)
        subprocess.run(["git", "worktree", "add", "--detach", "-f", str(tree), commit], cwd=ROOT,
                       check=True, capture_output=True)
        try:
            for name in ("node_modules", "vendor"):
                if (ROOT / name).exists():
                    (tree / name).symlink_to((ROOT / name).resolve())
            # A release says what changed, and the notice's What's new reads it.
            changelog = tree / "CHANGELOG.md"
            changelog.write_text(changelog.read_text().replace(
                "## [Unreleased]\n", "## [Unreleased]\n\nTest version %s, built by "
                "tools/update_check.py: the updater's What's new reads this.\n" % version, 1))
            subprocess.run([sys.executable, "tools/release.py", "version", "--set", version], cwd=tree,
                           check=True)
            subprocess.run(["git", "-c", "user.name=Xaxis", "-c", "user.email=william.neeley@gmail.com",
                            "commit", "-q", "-m", "Test version %s for tools/update_check.py" % version,
                            "VERSION", "project.godot", "CHANGELOG.md"], cwd=tree, check=True)
            subprocess.run([sys.executable, "tools/release.py", "build", "--assets=%s" % small,
                            *platforms], cwd=tree, check=True)
            (out / version).mkdir(exist_ok=True)
            for built in (tree / "dist" / version).iterdir():
                shutil.move(str(built), out / version / built.name)
        finally:
            subprocess.run(["git", "worktree", "remove", "--force", str(tree)], cwd=ROOT,
                           capture_output=True)
    say("built %s in %s" % (", ".join(versions), out))
    return 0


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def option(args: list[str], name: str, default: str = "") -> str:
    """--name=VALUE or --name VALUE."""
    for at, arg in enumerate(args):
        if arg.startswith("--%s=" % name):
            return arg.split("=", 1)[1]
        if arg == "--" + name and at + 1 < len(args):
            return args[at + 1]
    return default


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    command, args = argv[0], argv[1:]
    if command == "serve":
        folder = Path(option(args, "dir")).resolve()
        port = int(option(args, "port", "0")) or free_port()
        server = serve(folder, port)
        say("serving %s at http://127.0.0.1:%d/" % (folder, server.server_port))
        # A probe's server ends by itself, whatever becomes of the probe.
        seconds = float(option(args, "seconds", "0")) or float("inf")
        try:
            time.sleep(min(seconds, 1e9))
        except KeyboardInterrupt:
            pass
        return 0
    if command == "run":
        log = Path(option(args, "log")).resolve() if option(args, "log") else None
        if option(args, "laid"):
            laid = Path(option(args, "laid")).resolve()
            facts = json.loads((laid / "laid.json").read_text())
            return drive(laid / "files" / facts["old"], laid / "files" / facts["new"], facts["port"],
                         log, laid, "--system" in args)
        old, new = Path(option(args, "old")).resolve(), Path(option(args, "new")).resolve()
        port = int(option(args, "port", "0")) or free_port()
        return drive(old, new, port, log, system="--system" in args)
    if command == "lay":
        out = Path(option(args, "out")).resolve()
        if out.exists() and any(out.iterdir()):
            raise SystemExit("%s is not empty" % out)
        scenarios = lay_out(out, Path(option(args, "old")).resolve(), Path(option(args, "new")).resolve(),
                            int(option(args, "port")))
        say("laid out %d scenarios in %s" % (len(scenarios), out))
        return 0
    if command == "trim":
        return trim(Path(option(args, "out")).resolve())
    if command == "packages":
        versions = option(args, "versions").split(",")
        platforms = [a for a in args if a in ("linux", "mac", "windows")] or ["linux"]
        return packages(versions, platforms, Path(option(args, "out")).resolve())
    raise SystemExit("unknown command %s: see --help" % command)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except release.Failed as failure:
        print("update_check FAILED: %s" % failure, file=sys.stderr)
        sys.exit(1)
