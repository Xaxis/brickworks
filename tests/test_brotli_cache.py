"""tools/web/brotli.mjs --cache=DIR: an input compressed before is not compressed again, so a
deploy no longer spends minutes at quality 11 on an engine whose bytes have not changed
(fastship, 2026-11-23). A kept output is used only when it decompresses to exactly the input's
bytes: a damaged one is made again, never shipped. Without --cache nothing is kept."""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools/web/brotli.mjs"
NODE = shutil.which("node")
pytestmark = pytest.mark.skipif(NODE is None, reason="no node on PATH")


def squash(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([NODE, str(SCRIPT), *args], capture_output=True, text=True, timeout=120)


def unsquash(path: Path) -> bytes:
    """What a browser gets from PATH: decompressed by node's own brotli, apart from the tool."""
    reply = subprocess.run([NODE, "-e", "process.stdout.write(require('zlib').brotliDecompressSync("
                            "require('fs').readFileSync(process.argv[1])))", str(path)],
                           capture_output=True, timeout=60)
    assert reply.returncode == 0, reply.stderr
    return reply.stdout


@pytest.fixture
def made(tmp_path):
    data = b"".join(f"part {n} at {n * 20} {n % 7}\n".encode() for n in range(10000))
    (tmp_path / "in.bin").write_bytes(data)
    return tmp_path, data


def kept_files(cache: Path) -> list[Path]:
    return sorted(cache.glob("*.br")) if cache.exists() else []


def test_the_second_compress_of_the_same_bytes_comes_from_the_cache(made):
    tmp, data = made
    cache = tmp / "cache"
    first = squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "a.br"))
    assert first.returncode == 0, first.stderr
    assert "from the cache" not in first.stdout
    [entry] = kept_files(cache)
    assert entry.name.startswith(hashlib.sha256(data).hexdigest() + ".q11w24.")
    second = squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "b.br"))
    assert second.returncode == 0, second.stderr
    assert "from the cache" in second.stdout
    assert unsquash(tmp / "b.br") == data
    # The same bytes a compress without the cache makes: the same settings.
    plain = squash(str(tmp / "in.bin"), str(tmp / "c.br"))
    assert plain.returncode == 0, plain.stderr
    assert (tmp / "a.br").read_bytes() == (tmp / "b.br").read_bytes() == (tmp / "c.br").read_bytes()


def test_other_bytes_are_compressed_and_kept_apart(made):
    tmp, data = made
    cache = tmp / "cache"
    squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "a.br"))
    (tmp / "other.bin").write_bytes(data + b"one more line\n")
    other = squash(f"--cache={cache}", str(tmp / "other.bin"), str(tmp / "o.br"))
    assert other.returncode == 0, other.stderr
    assert "from the cache" not in other.stdout
    assert unsquash(tmp / "o.br") == data + b"one more line\n"
    assert len(kept_files(cache)) == 2


@pytest.mark.parametrize("damage", ["truncated", "another file's", "not brotli"])
def test_a_damaged_kept_output_is_made_again_never_shipped(made, damage):
    tmp, data = made
    cache = tmp / "cache"
    squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "a.br"))
    [entry] = kept_files(cache)
    good = entry.read_bytes()
    if damage == "truncated":
        entry.write_bytes(good[: len(good) // 2])
    elif damage == "another file's":
        (tmp / "x.bin").write_bytes(b"something else entirely\n" * 100)
        squash(str(tmp / "x.bin"), str(tmp / "x.br"))
        entry.write_bytes((tmp / "x.br").read_bytes())
    else:
        entry.write_bytes(b"\x00garbage" * 50)
    again = squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "b.br"))
    assert again.returncode == 0, again.stderr
    assert "from the cache" not in again.stdout
    assert "dropped" in again.stderr
    assert unsquash(tmp / "b.br") == data
    assert entry.read_bytes() == good, "the damaged one was not put right"


def test_without_a_cache_nothing_is_kept(made):
    tmp, data = made
    plain = squash(str(tmp / "in.bin"), str(tmp / "a.br"))
    assert plain.returncode == 0, plain.stderr
    assert unsquash(tmp / "a.br") == data
    assert sorted(p.name for p in tmp.iterdir()) == ["a.br", "in.bin"]


def test_kept_outputs_unused_for_two_days_go_and_a_used_one_stays(made):
    tmp, data = made
    cache = tmp / "cache"
    squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "a.br"))
    [used] = kept_files(cache)
    stale = cache / ("0" * 64 + ".q11w24.0.br")
    stale.write_bytes(b"old")
    three_days_ago = time.time() - 3 * 24 * 3600
    for path in (stale, used):
        os.utime(path, (three_days_ago, three_days_ago))
    squash(f"--cache={cache}", str(tmp / "in.bin"), str(tmp / "b.br"))   # a hit: used again
    assert used.stat().st_mtime > three_days_ago + 24 * 3600
    (tmp / "new.bin").write_bytes(b"new bytes\n" * 1000)
    squash(f"--cache={cache}", str(tmp / "new.bin"), str(tmp / "n.br"))   # a miss: kept, and the old go
    assert used.exists()
    assert not stale.exists()
    assert len(kept_files(cache)) == 2
