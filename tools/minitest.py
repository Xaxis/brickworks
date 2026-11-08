#!/usr/bin/env python3
"""Run the pytest suite on a machine that has no pytest.

tests/test_ldraw.py is where the physical facts are pinned: a stud is 8 mm
apart, a brick is 9.6 mm tall, -Y is up.  On a machine without pytest the
suite printed NOT RUN for that whole file, which is thirty-nine
measurements nobody is checking, and the first wrong one would be found by
a person holding a ruler instead of by the suite.

Ubuntu 24.04 ships Python with no pip and no ensurepip, and apt wants a
password, so "just install pytest" is not something a check script can do.
This runs the file instead.

Real pytest wins wherever it exists; tools/check.sh only falls back here.
The shim implements exactly what the suite uses — approx, fixture,
mark.parametrize, mark.skipif, and the tmp_path, capsys and monkeypatch
(its setattr) fixtures — and
raises on anything else by name, so it can never quietly skip a test it did
not understand.

    tools/minitest.py tests/test_ldraw.py

Given several files it runs them side by side, a process each, as many at
once as the cores a heavy slot is given (MINITEST_JOBS=N to choose; 1 runs
them one after another in this process). Each file's output is kept apart
and printed whole, under its name, in the order the files were given, and
the verdict for the lot is last, as before. One after another, the suite
had grown to 815 s and held rel-m270 past its gate's budget (2026-11-07).
"""

from __future__ import annotations

import importlib.util
import inspect
import io
import json
import math
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import traceback
import types
from collections import namedtuple
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
## How long each file took when the files last ran side by side, so the
## longest begin first and the run is not left waiting on one begun last.
TIMES = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "brickworks" / "minitest-times.json"


class Skipped(Exception):
    """A test that could not run, which is neither a pass nor a failure."""

    def __init__(self, reason: str = "") -> None:
        super().__init__(reason)
        self.reason = reason


# -- the pieces of pytest the suite actually uses -------------------------


class Approx:
    """`x == approx(y)`, with pytest's own tolerances.

    rel=1e-6 and abs=1e-12 are pytest's defaults; approx(0.0) only ever
    passes on the absolute one, which is the behaviour the lattice test
    depends on.
    """

    def __init__(self, expected: float, rel: float | None = None, abs: float | None = None) -> None:
        self.expected = expected
        self.rel = 1e-6 if rel is None else rel
        self.abs = 1e-12 if abs is None else abs

    def tolerance(self) -> float:
        return max(self.abs, self.rel * math.fabs(self.expected))

    def __eq__(self, other: object) -> bool:
        # A sequence compares element by element, as pytest's does: the
        # element tests compare a point to a point.
        if isinstance(self.expected, (tuple, list)):
            if not isinstance(other, (tuple, list)) or len(other) != len(self.expected):
                return False
            return all(Approx(e, self.rel, self.abs) == o
                       for e, o in zip(self.expected, other))
        try:
            return math.fabs(float(other) - self.expected) <= self.tolerance()  # type: ignore[arg-type]
        except (TypeError, ValueError):
            return NotImplemented

    def __repr__(self) -> str:
        if isinstance(self.expected, (tuple, list)):
            return "approx(%r)" % (self.expected,)
        return "%r +- %.3g" % (self.expected, self.tolerance())


class SkipIf:
    """Both a decorator and a value, because `pytestmark` uses it as one."""

    def __init__(self, condition, reason: str) -> None:
        self.condition = condition
        self.reason = reason

    def holds(self) -> bool:
        return bool(self.condition() if callable(self.condition) else self.condition)

    def __call__(self, fn):
        fn.__skipifs__ = [*getattr(fn, "__skipifs__", []), self]
        return fn


class Mark:
    def skipif(self, condition, reason: str = "") -> SkipIf:
        return SkipIf(condition, reason)

    def parametrize(self, argnames, argvalues):
        names = [n.strip() for n in argnames.split(",")] if isinstance(argnames, str) else list(argnames)

        def mark(fn):
            rows = []
            for row in argvalues:
                values = row if isinstance(row, (tuple, list)) else (row,)
                if len(values) != len(names):
                    raise TypeError(
                        "parametrize on %s: %d names, row with %d values: %r"
                        % (fn.__name__, len(names), len(values), row))
                rows.append(dict(zip(names, values)))
            fn.__params__ = [*getattr(fn, "__params__", []), rows]
            return fn

        return mark

    def __getattr__(self, name):
        raise NotImplementedError(
            "tools/minitest.py does not implement @pytest.mark.%s. Add it there, "
            "or install real pytest." % name)


CaptureResult = namedtuple("CaptureResult", "out err")


class CaptureFixture:
    """pytest's capsys: what the test printed since it began or last asked."""

    def __init__(self) -> None:
        self._saved = sys.stdout, sys.stderr
        self._out, self._err = io.StringIO(), io.StringIO()
        sys.stdout, sys.stderr = self._out, self._err

    def readouterr(self) -> CaptureResult:
        said = CaptureResult(self._out.getvalue(), self._err.getvalue())
        for stream in (self._out, self._err):
            stream.seek(0)
            stream.truncate()
        return said

    def close(self) -> None:
        sys.stdout, sys.stderr = self._saved


class MonkeyPatch:
    """pytest's monkeypatch, its setattr: each attribute set is put back as
    it was when the test ends."""

    def __init__(self) -> None:
        self._was: list[tuple[object, str, object]] = []

    def setattr(self, target: object, name: str, value: object) -> None:
        self._was.append((target, name, getattr(target, name)))
        setattr(target, name, value)

    def undo(self) -> None:
        for target, name, value in reversed(self._was):
            setattr(target, name, value)
        self._was.clear()


def fixture(fn=None, *, scope: str = "function"):
    def mark(f):
        f.__fixture__ = scope
        return f

    return mark(fn) if fn is not None else mark


def _fake_pytest() -> types.ModuleType:
    """A module named `pytest` holding only what this suite imports.

    Anything else raises with the attribute's name in the message. A shim
    that answered every attribute with a no-op would turn a test that
    reaches past it into a test that passes while checking nothing.
    """
    module = types.ModuleType("pytest")
    vars(module).update(
        approx=Approx,
        fixture=fixture,
        mark=Mark(),
        skip=lambda reason="": (_ for _ in ()).throw(Skipped(reason)),
    )

    def missing(name):
        raise NotImplementedError(
            "tools/minitest.py does not implement pytest.%s. Add it there, or "
            "install real pytest." % name)

    vars(module)["__getattr__"] = missing
    return module


# -- running the file ----------------------------------------------------


def _load(path: Path) -> types.ModuleType:
    sys.modules.setdefault("pytest", _fake_pytest())
    spec = importlib.util.spec_from_file_location(path.stem, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[path.stem] = module
    spec.loader.exec_module(module)
    return module


def _why_it_failed(error: BaseException) -> list[str]:
    """The failing line, plus what the names in it were at the time.

    Real pytest rewrites asserts so a failure reads `80.0 != 78.4`. Without
    that, `assert hi.x - lo.x == approx(80.0)` fails with no numbers at
    all, so this reads them out of the frame instead.
    """
    frames = traceback.extract_tb(error.__traceback__)
    deepest = frames[-1] if frames else None
    if deepest is None:
        return []
    said = ["%s:%d  %s" % (deepest.filename, deepest.lineno, (deepest.line or "").strip())]
    frame = error.__traceback__
    while frame and frame.tb_next:
        frame = frame.tb_next
    if frame is None or not deepest.line:
        return said
    scope = {**frame.tb_frame.f_globals, **frame.tb_frame.f_locals}
    for name in dict.fromkeys(re.findall(r"[A-Za-z_][A-Za-z_0-9]*", deepest.line)):
        if name in scope and not callable(scope[name]) and not isinstance(scope[name], types.ModuleType):
            said.append("    %s = %r" % (name, scope[name]))
    return said


def run(path: Path) -> tuple[int, int, int]:
    started = time.time()
    module = _load(path)
    fixtures = {
        name: value
        for name, value in vars(module).items()
        if callable(value) and hasattr(value, "__fixture__")
    }
    cached: dict[str, object] = {}
    temp = Path(tempfile.mkdtemp(prefix="minitest-"))

    def capture(closers: list) -> CaptureFixture:
        capsys = CaptureFixture()
        closers.append(capsys.close)
        return capsys

    def patch(closers: list) -> MonkeyPatch:
        monkeypatch = MonkeyPatch()
        closers.append(monkeypatch.undo)
        return monkeypatch

    # pytest's own fixtures, the ones the suite asks for.
    builtin = {
        "tmp_path": lambda closers: Path(tempfile.mkdtemp(dir=temp)),
        "capsys": capture,
        "monkeypatch": patch,
    }

    def resolve(name: str, test: dict[str, object], closers: list):
        # A function-scoped fixture is made once per test, as pytest makes
        # it: a fixture and the test that both ask for tmp_path get the
        # same folder.
        for made in (cached, test):
            if name in made:
                return made[name]
        if name in fixtures:
            maker = fixtures[name]
            wants = {p: resolve(p, test, closers) for p in inspect.signature(maker).parameters}
            value, scope = maker(**wants), getattr(maker, "__fixture__")
        elif name in builtin:
            value, scope = builtin[name](closers), "function"
        else:
            raise LookupError("no fixture named %r for this test" % name)
        (cached if scope in ("session", "module", "package") else test)[name] = value
        return value

    module_skips = getattr(module, "pytestmark", [])
    module_skips = module_skips if isinstance(module_skips, list) else [module_skips]

    passed, skipped, failures = 0, [], []
    for name, fn in list(vars(module).items()):
        if not (name.startswith("test_") and callable(fn)):
            continue
        rows: list[dict] = [{}]
        for group in getattr(fn, "__params__", []):
            rows = [{**outer, **inner} for outer in rows for inner in group]
        for row in rows:
            label = name + ("[%s]" % ",".join(str(v) for v in row.values()) if row else "")
            stop = next((s for s in [*module_skips, *getattr(fn, "__skipifs__", [])] if s.holds()), None)
            if stop is not None:
                skipped.append((label, stop.reason))
                sys.stdout.write("s")
                sys.stdout.flush()
                continue
            test: dict[str, object] = {}
            closers: list = []
            # Fixtures are made inside the try, so one a test cannot have
            # fails that test, not the run: a missing one ended the run
            # with the verdict of the files before it (2026-10-23).
            try:
                wants = {p: row[p] if p in row else resolve(p, test, closers)
                         for p in inspect.signature(fn).parameters}
                fn(**wants)
            except Skipped as skip:
                skipped.append((label, skip.reason))
                mark = "s"
            except BaseException as error:  # noqa: BLE001 - a test may raise anything
                failures.append((label, error))
                mark = "F"
            else:
                passed += 1
                mark = "."
            finally:
                for close in reversed(closers):
                    close()
            sys.stdout.write(mark)
            sys.stdout.flush()

    shutil.rmtree(temp, ignore_errors=True)
    print("")
    # Named with its file, as pytest names it: the gates print the FAIL
    # blocks alone, without the files' output around them.
    where = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
    for label, error in failures:
        print("")
        print("FAIL  %s::%s" % (where, label))
        said = ("%s: %s" % (type(error).__name__, error) if str(error) else type(error).__name__).splitlines()
        # Every line of the message indented, so a failure is one block to
        # its last line, as tools/failures.awk reads it.
        print("  " + said[0])
        for line in said[1:]:
            print("    " + line)
        for line in _why_it_failed(error):
            print("  " + line)
    # Said out loud, not counted as a pass: a skipped measurement is one
    # nobody is checking, and the reason is how it gets fixed.
    for label, reason in skipped:
        print("SKIP  %s — %s" % (label, reason))
    print("")
    verdict = "%d passed" % passed
    if skipped:
        verdict += ", %d skipped" % len(skipped)
    if failures:
        verdict += ", %d FAILED" % len(failures)
    print("%s in %.1fs  (tools/minitest.py, not pytest)" % (verdict, time.time() - started))
    return passed, len(skipped), len(failures)


def jobs(files: int) -> int:
    """How many files run at once: MINITEST_JOBS when set; in a heavy slot,
    the cores it is given (heavy passes them on as LP_NUM_THREADS, the cores
    over a project's share of slots: 3 of 24); elsewhere the same share,
    worked out as heavy works it out."""
    said = os.environ.get("MINITEST_JOBS", "")
    if not said and os.environ.get("BOX_HEAVY_HELD"):
        said = os.environ.get("LP_NUM_THREADS", "")
    try:
        wanted = int(said)
    except ValueError:
        cores = os.cpu_count() or 2
        wanted = max(2, cores // max(2, cores // 3))
    return max(1, min(wanted, files))


def _known_times() -> dict[str, float]:
    try:
        said = json.loads(TIMES.read_text())
        return {k: float(v) for k, v in said.items() if isinstance(v, (int, float))}
    except (OSError, ValueError, AttributeError):
        return {}


def _keep_times(took: dict[str, float]) -> None:
    """Merged into what was known, written whole: two suites may end at once."""
    try:
        TIMES.parent.mkdir(parents=True, exist_ok=True)
        fresh = TIMES.with_name("%s.%d" % (TIMES.name, os.getpid()))
        fresh.write_text(json.dumps({**_known_times(), **took}, indent=0, sort_keys=True) + "\n")
        os.replace(fresh, TIMES)
    except OSError:
        pass


def run_apart(files: list[Path], names: list[str], at_once: int) -> list[tuple[int, int, int]]:
    """Each file in a process of its own, [param at_once] at a time, its
    output (stdout and stderr, its subprocesses' too) kept in a file and
    printed whole, in the order given, once the files before it are. The
    files that took longest last time begin first, and one never timed
    before them all."""
    keys = [str(f.resolve().relative_to(ROOT)) if f.resolve().is_relative_to(ROOT) else str(f) for f in files]
    known = _known_times()
    order = sorted(range(len(files)), key=lambda i: -known.get(keys[i], math.inf))
    counts: list[tuple[int, int, int] | None] = [None] * len(files)
    running: dict[int, tuple[subprocess.Popen, int, float]] = {}
    took: dict[str, float] = {}
    begun = printed = 0
    # Stopped (a gate's timeout), it stops the files it began: an exit, so
    # the finally below runs, where the signal's default would leave them.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(128 + signal.SIGTERM))
    with tempfile.TemporaryDirectory(prefix="minitest-files-") as where:
        out = [Path(where, "%d.out" % i) for i in range(len(files))]
        said = [Path(where, "%d.counts" % i) for i in range(len(files))]
        try:
            while printed < len(files):
                while begun < len(files) and len(running) < at_once:
                    i = order[begun]
                    with open(out[i], "wb") as sink:
                        child = subprocess.Popen(
                            [sys.executable, str(Path(__file__).resolve()), str(files[i])],
                            stdin=subprocess.DEVNULL, stdout=sink, stderr=subprocess.STDOUT,
                            env={**os.environ, "MINITEST_COUNTS": str(said[i])})
                    running[child.pid] = (child, i, time.time())
                    begun += 1
                # The next file to end, waited for, never polled.
                pid, status = os.wait()
                if pid not in running:
                    continue
                child, done, since = running.pop(pid)
                child.returncode = os.waitstatus_to_exitcode(status)
                took[keys[done]] = round(time.time() - since, 1)
                try:
                    counts[done] = tuple(int(n) for n in said[done].read_text().split())  # type: ignore[assignment]
                except (OSError, ValueError):
                    # Ended before its verdict (a file that does not import,
                    # a test that killed it): a failure, under its name.
                    with open(out[done], "a") as sink:
                        sink.write("\nFAIL  %s\n  ended (exit %s) before its verdict\n"
                                   % (names[done], child.returncode))
                    counts[done] = (0, 0, 1)
                while printed < len(files) and counts[printed] is not None:
                    sys.stdout.write("%s " % names[printed])
                    sys.stdout.write(out[printed].read_bytes().decode("utf-8", "replace"))
                    sys.stdout.flush()
                    printed += 1
        finally:
            for child, _, _ in running.values():
                child.kill()
                child.wait()
    _keep_times(took)
    return counts  # type: ignore[return-value]


def main(argv: list[str]) -> int:
    started = time.time()
    # Read once and taken out, so no test's subprocess writes over it.
    counts_to = os.environ.pop("MINITEST_COUNTS", "")
    given = [Path(a) for a in argv[1:]] or [ROOT / "tests" / "test_ldraw.py"]
    files = [f if f.is_absolute() else ROOT / f for f in given]
    names = [str(f) for f in given]
    at_once = jobs(len(files))
    if at_once > 1:
        counts = run_apart(files, names, at_once)
    else:
        counts = []
        for name, path in zip(names, files):
            if len(files) > 1:
                sys.stdout.write("%s " % name)
            counts.append(run(path))
    passed, skipped, failed = (sum(c[k] for c in counts) for k in range(3))
    if counts_to:
        Path(counts_to).write_text("%d %d %d\n" % (passed, skipped, failed))
    if len(files) > 1:
        # One verdict for the lot, last, because tools/check.sh reads the
        # last one: read alone, the last file's would hide the others'
        # skips and failures.
        verdict = "%d passed" % passed
        if skipped:
            verdict += ", %d skipped" % skipped
        if failed:
            verdict += ", %d FAILED" % failed
        print("%s in %.1fs over %d files  (tools/minitest.py, not pytest)"
              % (verdict, time.time() - started, len(files)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
