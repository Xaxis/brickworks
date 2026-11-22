"""A wall-clock bound stretches with the box's load, and never as far as the hang it rules out."""

from __future__ import annotations

import os
import sys
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from loadbound import within  # noqa: E402


@contextmanager
def _at(load: float, cores: int = 24):
    """The box at [load] on [cores], put back after: every test in the process reads the same os."""
    kept = os.getloadavg, os.cpu_count
    os.getloadavg = lambda: (load, load, load)
    os.cpu_count = lambda: cores
    try:
        yield
    finally:
        os.getloadavg, os.cpu_count = kept


def test_an_idle_box_keeps_the_number_written() -> None:
    with _at(5):
        assert within(500) == 500
    with _at(24):
        assert within(500) == 500


def test_a_loaded_box_stretches_by_the_threads_wanting_each_core() -> None:
    with _at(120):
        assert within(500) == 2500


def test_a_stretched_bound_still_tells_a_hang_from_an_answer() -> None:
    with _at(137):
        assert within(3500, short_of=15_000) < 15_000
        assert within(2500, short_of=4000) < 4000
    with _at(5):
        assert within(3500, short_of=15_000) == 3500


def test_the_box_is_put_back() -> None:
    real = os.getloadavg
    with _at(137):
        pass
    assert os.getloadavg is real


def test_every_tests_millisecond_ceiling_stretches_with_the_load() -> None:
    """A bare "answered in under N ms" in a test fails a gate whenever the box is busy (rel-m319, 11-22)."""
    import re

    bare = re.compile(r'\[\s*"[A-Za-z_]*[mM]s"\s*\](?:\[\d+\])?\s*<=?\s*[0-9][0-9_]*\b(?!\s*\))')
    found = []
    for path in sorted((ROOT / "tests").glob("test_*.py")):
        for at, line in enumerate(path.read_text().splitlines(), 1):
            if bare.search(line) and not line.lstrip().startswith("#"):
                found.append(f"{path.name}:{at}: {line.strip()}")
    assert not found, "use loadbound.within(ms, short_of=the hang it rules out):\n" + "\n".join(found)
