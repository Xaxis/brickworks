"""The pieces that let a .deb's thumbnailer be checked where GNOME's sandbox
cannot be made: bwrap's stand-in, the sandbox's view of the files, and the
trace reader that names what the thumbnailer found outside it."""

from __future__ import annotations

import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "release"))

import thumbnail_check  # noqa: E402

STANDIN = ROOT / "tools" / "release" / "bwrap_standin.py"


def standin(args: list[str], env: dict[str, str] | None = None,
            pass_fds: tuple[int, ...] = ()) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(STANDIN)] + args, capture_output=True, text=True,
                          env=env if env is not None else dict(os.environ), pass_fds=pass_fds)


def test_the_stand_in_runs_the_command_on_the_files_the_binds_stand_for(tmp_path):
    folder = tmp_path / "factory"
    folder.mkdir()
    model = tmp_path / "car.ldr"
    model.write_text("0 a car\n")
    env = dict(os.environ, DISPLAY=":9", GONE="yes")
    done = standin(["--ro-bind", "/usr", "/usr", "--bind", str(folder), "/tmp",
                    "--ro-bind", str(model), "/tmp/gnome-desktop-file-to-thumbnail.ldr",
                    "--setenv", "GIO_USE_VFS", "local", "--unsetenv", "GONE", "--chdir", "/",
                    "--unshare-all", "--die-with-parent",
                    "sh", "-c", 'cat "$1"; echo "$TMPDIR|$GIO_USE_VFS|${GONE:-}|${DISPLAY:-}|$PWD"'
                    ' > "$2"', "sh", "/tmp/gnome-desktop-file-to-thumbnail.ldr",
                    "/tmp/gnome-desktop-thumbnailer.png"], env)
    assert done.returncode == 0, done.stderr
    assert done.stdout == "0 a car\n"
    # /tmp is the factory's folder, as in the sandbox; the desktop's display
    # is not there.
    said = (folder / "gnome-desktop-thumbnailer.png").read_text().strip()
    assert said == "%s|local|||/" % folder


def test_the_stand_in_keeps_gnomes_seccomp_filter(tmp_path):
    # A filter in the form libgnome-desktop hands bwrap on a descriptor:
    # mkdir and mkdirat refused with EPERM, everything else allowed.
    def statement(code: int, k: int, jt: int = 0, jf: int = 0) -> bytes:
        return struct.pack("<HBBI", code, jt, jf, k)
    load_nr, jeq, ret = 0x20, 0x15, 0x06
    program = (statement(load_nr, 0) + statement(jeq, 83, 2, 0) + statement(jeq, 258, 1, 0)
               + statement(ret, 0x7FFF0000) + statement(ret, 0x00050000 | 1))
    read, write = os.pipe()
    os.write(write, program)
    os.close(write)
    blocked = tmp_path / "blocked"
    done = standin(["--seccomp", str(read), "mkdir", str(blocked)], pass_fds=(read,))
    os.close(read)
    assert done.returncode != 0 and not blocked.exists()
    assert "Operation not permitted" in done.stderr
    # And without it, the same command makes the folder.
    assert standin(["mkdir", str(blocked)]).returncode == 0 and blocked.is_dir()


def test_the_sandbox_view_hides_what_the_sandbox_has_not_got(tmp_path):
    if not shutil.which("cc"):
        return
    view = tmp_path / "sandbox_view.so"
    subprocess.run(["cc", "-shared", "-fPIC", "-O2", "-o", str(view),
                    str(ROOT / "tools" / "release" / "sandbox_view.c"), "-ldl"], check=True)
    inside = tmp_path / "in"
    inside.mkdir()
    (inside / "seen.txt").write_text("seen\n")
    (tmp_path / "unseen.txt").write_text("unseen\n")
    env = dict(os.environ, BWRAP_STANDIN_VIEW=str(view), BWRAP_STANDIN_ALSO="")
    done = standin(["--ro-bind", "/usr", "/usr", "--symlink", "usr/bin", "/bin",
                    "--symlink", "usr/lib", "/lib", "--symlink", "usr/lib64", "/lib64",
                    "--ro-bind", "/etc/ld.so.cache", "/etc/ld.so.cache", "--proc", "/proc",
                    "--bind", str(inside), "/tmp",
                    "/bin/sh", "-c", 'cat "$1/seen.txt"; cat "$1/../unseen.txt" || echo gone;'
                    ' ls /home >/dev/null 2>&1 || echo no-home', "sh", "/tmp"], env)
    assert done.stdout.split() == ["seen", "gone", "no-home"], done.stdout + done.stderr


def test_the_trace_names_what_a_child_found_outside_the_sandbox(tmp_path):
    root = tmp_path / "root"
    model = tmp_path / "car.ldr"
    trace = tmp_path / "trace.txt"
    trace.write_text("\n".join([
        '100 execve("/home/me/.local/bin/python3", ["python3"], 0x0 /* 3 vars */) = 0',
        '100 openat(AT_FDCWD, "/home/me/before.txt", O_RDONLY) = 3',
        '200 execve("%s/usr/bin/brickworks-thumbnailer", ["brickworks-thumbnailer"], 0x0) = 0'
        % root,
        '200 openat(AT_FDCWD, "%s/usr/lib/brickworks/brickworks.pck", O_RDONLY) = 3' % root,
        '200 clone3({flags=CLONE_VM, exit_signal=SIGCHLD} <unfinished ...>',
        '200 <... clone3 resumed> => {parent_tid=[0]}, 88) = 201',
        '201 openat(AT_FDCWD, "/sys/devices/system/cpu/possible", O_RDONLY <unfinished ...>',
        '201 <... openat resumed>) = 4',
        '201 openat(AT_FDCWD, "/etc/fonts/fonts.conf", O_RDONLY) = -1 ENOENT (No such file)',
        '201 openat(AT_FDCWD, "%s", O_RDONLY) = 5' % model,
        '201 openat(AT_FDCWD, "/tmp/gnome-desktop-thumbnailer-AB12/out.png", O_WRONLY) = 6',
        '201 openat(AT_FDCWD, "/usr/lib/x86_64-linux-gnu/libm.so.6", O_RDONLY) = 7',
        '201 stat("/proc/self/exe", {st_mode=S_IFREG}) = 0',
        '300 openat(AT_FDCWD, "/home/me/other.txt", O_RDONLY) = 3',
    ]) + "\n")
    # Found and outside: the child's /sys read. Not: what ran before the
    # thumbnailer, what was not found, the package, the model, the
    # factory's folder, /usr, /proc, and a process the thumbnailer did not make.
    assert thumbnail_check.outside_sandbox(trace, root, model) == ["/sys/devices/system/cpu/possible"]


def test_without_gnomes_factory_a_smoke_says_so_and_the_installed_check_fails(tmp_path):
    # -S: no site packages, so no GObject bindings, as setup-python's Python
    # on a runner has none. A smoke on such a machine checks nothing and
    # passes on; a runner asking for the installed package must not.
    script = str(ROOT / "tools" / "release" / "thumbnail_check.py")
    smoke = subprocess.run([sys.executable, "-S", script, "--root=%s" % tmp_path,
                            "--out=%s" % (tmp_path / "smoke")], capture_output=True, text=True)
    assert smoke.returncode == 0, smoke.stdout + smoke.stderr
    assert "--    no GNOME thumbnail factory here" in smoke.stdout, smoke.stdout
    runner = subprocess.run([sys.executable, "-S", script, "--installed",
                             "--out=%s" % (tmp_path / "runner")], capture_output=True, text=True)
    assert runner.returncode == 1, runner.stdout + runner.stderr
    assert "FAIL  no GNOME thumbnail factory here" in runner.stdout, runner.stdout
