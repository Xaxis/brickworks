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
mark.parametrize, mark.skipif — and raises on anything else by name, so it
can never quietly skip a test it did not understand.

    tools/minitest.py tests/test_ldraw.py
"""

from __future__ import annotations

import importlib.util
import inspect
import math
import re
import sys
import time
import traceback
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


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
        try:
            return math.fabs(float(other) - self.expected) <= self.tolerance()  # type: ignore[arg-type]
        except (TypeError, ValueError):
            return NotImplemented

    def __repr__(self) -> str:
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


def run(path: Path) -> int:
    started = time.time()
    module = _load(path)
    fixtures = {
        name: value
        for name, value in vars(module).items()
        if callable(value) and hasattr(value, "__fixture__")
    }
    cached: dict[str, object] = {}

    def resolve(name: str):
        if name in cached:
            return cached[name]
        if name not in fixtures:
            raise LookupError("no fixture named %r for this test" % name)
        maker = fixtures[name]
        wants = {p: resolve(p) for p in inspect.signature(maker).parameters}
        value = maker(**wants)
        if getattr(maker, "__fixture__") in ("session", "module", "package"):
            cached[name] = value
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
            wants = {p: row[p] if p in row else resolve(p) for p in inspect.signature(fn).parameters}
            try:
                fn(**wants)
            except Skipped as skip:
                skipped.append((label, skip.reason))
                sys.stdout.write("s")
            except BaseException as error:  # noqa: BLE001 - a test may raise anything
                failures.append((label, error))
                sys.stdout.write("F")
            else:
                passed += 1
                sys.stdout.write(".")
            sys.stdout.flush()

    print("")
    for label, error in failures:
        print("")
        print("FAIL  %s" % label)
        print("  %s: %s" % (type(error).__name__, error) if str(error) else "  %s" % type(error).__name__)
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
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    files = [Path(a) for a in argv[1:]] or [ROOT / "tests" / "test_ldraw.py"]
    return max(run(f if f.is_absolute() else ROOT / f) for f in files)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
