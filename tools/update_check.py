#!/usr/bin/env python3
"""Prove the desktop app updates itself: packages of two versions, a test
server in place of GitHub's releases, and the real app driven through every
refusal and through a real install that restarts with the model kept.

    tools/update_check.py run --old FILE --new FILE [--port=N] [--log=FILE]
        FILE: two packages of one kind (AppImage, tar.xz, macOS zip or Windows
        zip), the new one a newer version. Unpacks the old one as a person
        would, serves both, and drives the app (--update=...) through:
          refused: a bad signature, a wrong SHA-256, a wrong size, an older
          version, a plain-HTTP address, a redirect off the allowed hosts;
          Check for updates; Update and restart (the model kept); Restart;
          Reinstall; Automatic, put in as the app quits; and a new copy that
          cannot start, put back.
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
import socket
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
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
    """Files from the folder, and three kinds of redirect:
    /redirect/X to /X on this host; /redirect-off/X to https://example.com/X;
    /redirect-localhost/X to http://localhost:PORT/X (another host, plain HTTP)."""

    def do_GET(self) -> None:  # noqa: N802
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


def serve(folder: Path, port: int) -> http.server.ThreadingHTTPServer:
    handler = lambda *a, **k: Handler(*a, directory=str(folder), **k)  # noqa: E731
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


# -- manifests ---------------------------------------------------------------

def version_in(name: str) -> str:
    found = re.match(r"Brickworks-(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)-", name)
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


def broken(package: Path, into: Path) -> Path:
    """A package of the same name whose program cannot start: an update
    that passes every check but the copy's own start (Updater's put back)."""
    into.mkdir(parents=True, exist_ok=True)
    target = into / package.name
    version = version_in(package.name)
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
        folder = "Brickworks-%s-%s" % (version, "macos" if "-macos-" in package.name
                                       else "windows-x86_64")
        with zipfile.ZipFile(target, "w") as archive:
            inside = ("Brickworks.app/Contents/MacOS/Brickworks" if "-macos-" in package.name
                      else "Brickworks.exe")
            archive.writestr(folder + "/" + inside, stop)
            if "-windows-" in package.name:
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
    bad = broken(new, files / "broken")
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
    scenario("redirect", release.sign_update_manifest(
        manifest(B, [entry(new, base + "redirect/files/" + new.name)])),
        "a redirect on the same host, followed")
    scenario("broken", release.sign_update_manifest(
        manifest(B, [entry(bad, url("broken/" + bad.name))])), "a copy that cannot start")
    return scenarios


# -- running the app ---------------------------------------------------------

def program_in(package: Path, install: Path) -> Path:
    return release.unpack(package, install)


def user_dir(home: Path) -> Path:
    if sys.platform == "darwin":
        return home / "Library" / "Application Support" / "Godot" / "app_userdata" / "Brickworks"
    if os.name == "nt":
        return home / "AppData" / "Roaming" / "Godot" / "app_userdata" / "Brickworks"
    return home / ".local" / "share" / "godot" / "app_userdata" / "Brickworks"


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
        if sys.platform == "darwin":
            self.env.update({"HOME": str(Path.home())})
        self.log = user_dir(self.home) / "updates" / "log.txt"

    def check(self, what: str, ok: bool, detail: str = "") -> None:
        say("  %s  %s" % ("ok  " if ok else "FAIL", what))
        if not ok:
            self.failures += 1
            for line in detail.strip().splitlines()[-15:]:
                say("        " + line)

    def app(self, program: Path, base: str, user: list[str], seconds: int = 300) -> tuple[int, str]:
        env = dict(self.env, BRICKWORKS_UPDATE_URL="http://127.0.0.1:%d/%s/" % (self.port, base))
        return release.run_app([str(program), "--headless", "--", *user], env, seconds)

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


def drive(old: Path, new: Path, port: int, keep_log: Path | None) -> int:
    with tempfile.TemporaryDirectory(prefix="brickworks-update-", ignore_cleanup_errors=True) as scratch:
        root = Path(scratch)
        serve_dir = root / "serve"
        scenarios = lay_out(serve_dir, old, new, port)
        server = serve(serve_dir, port)
        run = Run(old, new, port, root)
        say("── %s → %s, %s, served at http://127.0.0.1:%d/ ──" % (run.A, run.B,
            release.describe_file(old.name)["kind"], port))
        try:
            install = root / "install"
            install.mkdir()
            program = program_in(old, install)
            said = run.about(program)
            run.check("the old copy says %s" % said, said.startswith("Brickworks %s" % run.A))

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
            code, output = run.app(program, "redirect", ["--model=res://models/house.ldr",
                                                         "--update=install"])
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
            time.sleep(2)
            run.check("the old copy is gone once the new one started: %s" % (run.staged(install) or "nothing left"),
                      not run.staged(install))

            mark = run.mark()
            run.app(program, "good", ["--update=restart"])
            text = run.log_after(mark, "report:")
            after2 = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts; session (\w+)", text)
            run.check("Restart Brickworks: %s" % (after2.group(0) if after2 else "no report"),
                      bool(after and after2) and after2.groups() == after.groups(), text)

            mark = run.mark()
            code, output = run.app(program, "good", ["--update=reinstall"])
            text = run.log_after(mark, "report:")
            after3 = re.search(r"report: running (\S+); model “([^”]*)”, (\d+) parts", text)
            run.check("Reinstall Brickworks: %s" % (after3.group(0) if after3 else "no report"),
                      bool(after3) and after3.group(1) == run.B
                      and "started %s (from %s)" % (run.B, run.B) in text, output + "\n" + text)
            run.log_after(mark, "is up", 60)

            # Automatic: downloaded, then put in as the app quits; the next
            # start is the new version.
            again = root / "install2"
            again.mkdir()
            program2 = program_in(old, again)
            mark = run.mark()
            code, output = run.app(program2, "good", ["--update=fetch"])
            text = run.log_after(mark, "the new copy says it is", 180)
            said = run.about(program2)
            run.check("Automatic: fetched, put in as it quit; the next start says %s" % said,
                      said.startswith("Brickworks %s" % run.B), output + "\n" + text)

            # A new copy that cannot start: the old one put back, and started.
            again = root / "install3"
            again.mkdir()
            program3 = program_in(old, again)
            mark = run.mark()
            code, output = run.app(program3, "broken", ["--model=res://models/house.ldr",
                                                       "--update=install"])
            text = run.log_after(mark, "report:")
            back = re.search(r"report: running (\S+);", text)
            said = run.about(program3)
            run.check("a new copy that cannot start is put back: %s, and %s started again"
                      % (said, back.group(1) if back else "nothing"),
                      said.startswith("Brickworks %s" % run.A) and bool(back)
                      and back.group(1) == run.A and "putting the old copy back" in text,
                      output + "\n" + text)
        finally:
            server.shutdown()
            if keep_log is not None and run.log.exists():
                keep_log.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(run.log, keep_log)
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
    small = out / "assets"
    if not (small / "catalogue.json").exists():
        trim(small)
    commit = release.git("rev-parse", "HEAD")
    for version in versions:
        tree = out / ("tree-" + version)
        subprocess.run(["git", "worktree", "add", "--detach", "-f", str(tree), commit], cwd=ROOT,
                       check=True, capture_output=True)
        try:
            for name in ("node_modules", "vendor"):
                if (ROOT / name).exists():
                    (tree / name).symlink_to((ROOT / name).resolve())
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
    for arg in args:
        if arg.startswith("--%s=" % name):
            return arg.split("=", 1)[1]
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
        old, new = Path(option(args, "old")).resolve(), Path(option(args, "new")).resolve()
        port = int(option(args, "port", "0")) or free_port()
        log = option(args, "log")
        return drive(old, new, port, Path(log).resolve() if log else None)
    if command == "trim":
        return trim(Path(option(args, "out")).resolve())
    if command == "packages":
        versions = option(args, "versions").split(",")
        platforms = [a for a in args if not a.startswith("--")] or ["linux"]
        return packages(versions, platforms, Path(option(args, "out")).resolve())
    raise SystemExit("unknown command %s: see --help" % command)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except release.Failed as failure:
        print("update_check FAILED: %s" % failure, file=sys.stderr)
        sys.exit(1)
