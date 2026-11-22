"""A test's wall-clock bound as it holds on this box now.

The suite runs under heavy on a shared box, often with more threads wanting a CPU than it has cores:
rel-m319's three gates on 11-22 ran at load 119-137 on 24 cores, and two failed on an "answered in under
N ms" bound (3,556 ms against 3,500; 657 against 500) that the same code had passed minutes before. Such a
bound says "promptly, not hung". On an idle box it is the number written; on a loaded one it stretches by
the threads wanting each core, so each process's share of a core is what the bound is measured against.

A bound set against a hang of known length (a 15 s read waited for, a 10 s lookup) passes that hang as
[short_of]: stretched, it still stops short of it, so the test tells the two apart at any load.
"""

from __future__ import annotations

import os


def within(ms: float, short_of: float | None = None) -> float:
    """[ms] as a bound on this box now: [ms] itself unless the 1-minute load passes the cores, and never
    as long as [short_of], the hang it rules out."""
    stretched = ms * max(1.0, os.getloadavg()[0] / (os.cpu_count() or 1))
    if short_of is not None:
        stretched = min(stretched, max(ms, short_of * 0.85))
    return stretched
