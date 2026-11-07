#!/usr/bin/env python3
"""bwrap, for a machine that cannot make the sandbox GNOME runs thumbnailers in.

GNOME's thumbnail factory (libgnome-desktop) runs every thumbnailer through
bubblewrap: /usr read-only, a folder of its own as /tmp, the file at
/tmp/gnome-desktop-file-to-thumbnail.<ext>, no network, and a seccomp filter
it writes to a descriptor (--seccomp FD). Where unprivileged user namespaces
are refused (Ubuntu 24.04's kernel.apparmor_restrict_unprivileged_userns=1,
for a program with no AppArmor profile of its own), bwrap cannot start, and
the factory draws nothing for any thumbnailer.

Put first on PATH as `bwrap`, this runs the command the factory asked for
with what of the sandbox needs no namespace: GNOME's own seccomp filter, its
environment (--setenv, --unsetenv), its working folder, its death with the
factory, and each path in the command read through the binds back to the
file it stands for (/tmp/gnome-desktop-thumbnailer.png is the factory's own
folder's). TMPDIR is that folder too, as /tmp is in the sandbox. What it
cannot make is the namespaces: the filesystem the command sees is the
machine's, so a check that the command reads only what the sandbox has must
be made apart (tools/release/thumbnail_check.py --trace).

BWRAP_STANDIN_VIEW=LIB, a build of tools/release/sandbox_view.c, is
preloaded into the command so it finds only what the sandbox has: each
bind's file, /proc, /dev, the links bwrap makes, and the folders in
BWRAP_STANDIN_ALSO (colon-separated: the package's usr/, where it stands in
for /usr). BWRAP_STANDIN_LOG=FILE appends each call's arguments there, one
JSON list a line.
"""

import ctypes
import json
import os
import signal
import sys

# Arguments each option takes, as bwrap 0.9 reads them.
TAKES = {
    "--args": 1, "--argv0": 1, "--unshare-user": 0, "--unshare-user-try": 0, "--unshare-ipc": 0,
    "--unshare-pid": 0, "--unshare-net": 0, "--unshare-uts": 0, "--unshare-cgroup": 0,
    "--unshare-cgroup-try": 0, "--unshare-all": 0, "--share-net": 0, "--userns": 1,
    "--userns2": 1, "--disable-userns": 0, "--assert-userns-disabled": 0, "--pidns": 1,
    "--uid": 1, "--gid": 1, "--hostname": 1, "--chdir": 1, "--clearenv": 0, "--setenv": 2,
    "--unsetenv": 1, "--lock-file": 1, "--sync-fd": 1, "--bind": 2, "--bind-try": 2,
    "--dev-bind": 2, "--dev-bind-try": 2, "--ro-bind": 2, "--ro-bind-try": 2,
    "--remount-ro": 1, "--exec-label": 1, "--file-label": 1, "--proc": 1, "--dev": 1,
    "--tmpfs": 1, "--mqueue": 1, "--dir": 1, "--file": 2, "--bind-data": 2,
    "--ro-bind-data": 2, "--symlink": 2, "--seccomp": 1, "--add-seccomp-fd": 1,
    "--block-fd": 1, "--userns-block-fd": 1, "--info-fd": 1, "--json-status-fd": 1,
    "--new-session": 0, "--die-with-parent": 0, "--as-pid-1": 0, "--cap-add": 1,
    "--cap-drop": 1, "--perms": 1, "--size": 1, "--chmod": 2, "--level-prefix": 0,
}
BINDS = ("--bind", "--bind-try", "--dev-bind", "--dev-bind-try", "--ro-bind", "--ro-bind-try")

PR_SET_PDEATHSIG = 1
PR_SET_SECCOMP = 22
PR_SET_NO_NEW_PRIVS = 38
SECCOMP_MODE_FILTER = 2


class SockFprog(ctypes.Structure):
    _fields_ = [("len", ctypes.c_ushort), ("filter", ctypes.c_void_p)]


def read_all(fd: int) -> bytes:
    data = b""
    while True:
        more = os.read(fd, 65536)
        if not more:
            return data
        data += more


def outside(path: str, binds: list[tuple[str, str]]) -> str:
    """The file [path] in the sandbox stands for: through the deepest bind
    that holds it."""
    best = None
    for source, dest in binds:
        if path == dest or path.startswith(dest.rstrip("/") + "/"):
            if best is None or len(dest) > len(best[1]):
                best = (source, dest)
    if best is None or best[0] == best[1]:
        return path
    return best[0] + path[len(best[1]):]


def main(argv: list[str]) -> int:
    log = os.environ.get("BWRAP_STANDIN_LOG")
    if log:
        with open(log, "a") as handle:
            handle.write(json.dumps(argv) + "\n")
    env = dict(os.environ)
    env.pop("BWRAP_STANDIN_LOG", None)
    view = env.pop("BWRAP_STANDIN_VIEW", "")
    also = env.pop("BWRAP_STANDIN_ALSO", "")
    binds: list[tuple[str, str]] = []
    seen: list[str] = []
    chdir = None
    seccomp = []
    die_with_parent = new_session = False
    at = 0
    while at < len(argv) and argv[at].startswith("--"):
        option = argv[at]
        if option == "--":
            at += 1
            break
        if option not in TAKES:
            sys.stderr.write("bwrap stand-in: %s is not an option it knows\n" % option)
            return 1
        given = argv[at + 1:at + 1 + TAKES[option]]
        at += 1 + TAKES[option]
        if option in BINDS:
            binds.append((given[0], given[1]))
            seen.append(given[0])
        elif option in ("--proc", "--dev", "--tmpfs", "--dir", "--mqueue"):
            seen.append(given[0])
        elif option == "--symlink":
            seen.append(given[1])
        elif option == "--setenv":
            env[given[0]] = given[1]
        elif option == "--unsetenv":
            env.pop(given[0], None)
        elif option == "--clearenv":
            env = {"PWD": env.get("PWD", "/")}
        elif option == "--chdir":
            chdir = given[0]
        elif option in ("--seccomp", "--add-seccomp-fd"):
            seccomp.append(read_all(int(given[0])))
        elif option == "--die-with-parent":
            die_with_parent = True
        elif option == "--new-session":
            new_session = True
    command = argv[at:]
    if not command:
        sys.stderr.write("bwrap stand-in: no command\n")
        return 1
    command = [outside(part, binds) for part in command]
    tmp = outside("/tmp", binds)
    if tmp != "/tmp":
        env["TMPDIR"] = tmp
    # A desktop's display is not in the sandbox (--unshare-all, and no
    # socket bound in for it).
    for name in ("DISPLAY", "WAYLAND_DISPLAY"):
        env.pop(name, None)
    if view:
        seen += [place for place in also.split(":") if place]
        env["SANDBOX_VIEW"] = ":".join(seen)
        env["LD_PRELOAD"] = ":".join(filter(None, [view, env.get("LD_PRELOAD", "")]))
    os.chdir(outside(chdir, binds) if chdir else "/")
    libc = ctypes.CDLL(None, use_errno=True)
    if die_with_parent:
        libc.prctl(PR_SET_PDEATHSIG, signal.SIGKILL, 0, 0, 0)
    if new_session:
        os.setsid()
    if seccomp:
        if libc.prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0:
            sys.stderr.write("bwrap stand-in: no_new_privs: %s\n" % os.strerror(ctypes.get_errno()))
            return 1
        for program in seccomp:
            buffer = ctypes.create_string_buffer(program, len(program))
            fprog = SockFprog(len(program) // 8, ctypes.cast(buffer, ctypes.c_void_p))
            if libc.prctl(PR_SET_SECCOMP, SECCOMP_MODE_FILTER, ctypes.byref(fprog), 0, 0) != 0:
                sys.stderr.write("bwrap stand-in: seccomp: %s\n"
                                 % os.strerror(ctypes.get_errno()))
                return 1
    try:
        os.execvpe(command[0], command, env)
    except OSError as error:
        sys.stderr.write("bwrap stand-in: %s: %s\n" % (command[0], error))
        return 127
    return 127


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
