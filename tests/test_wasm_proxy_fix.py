"""tools/web/wasm_proxy_fix.py: the web build's engine signals a worker that
its call to the main thread is done before it lets go of the call's lock, as
Emscripten 5.0.5 does, so the worker cannot return and write over the
condition the main thread is about to signal (househang, 2026-11-07).

A module is made here with Emscripten 4.0.20's two places as clang lays them
out, the lock, unlock, signal and remove_active_ctx it calls imported from
JavaScript, and run in node: what it calls, in which order, before and after.
"""

from __future__ import annotations

import importlib.util
import json
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools/web/wasm_proxy_fix.py"
_spec = importlib.util.spec_from_file_location("wasm_proxy_fix", SCRIPT)
fix = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(fix)

TEMPLATE = Path(os.path.expanduser("~/.local/share/godot/export_templates/4.7.2.stable/web_release.zip"))


def leb(n: int) -> bytes:
    out = bytearray()
    while True:
        byte = n & 0x7F
        n >>= 7
        out.append(byte | (0x80 if n else 0))
        if not n:
            return bytes(out)


def section(kind: int, body: bytes) -> bytes:
    return bytes([kind]) + leb(len(body)) + body


def name(text: str) -> bytes:
    return leb(len(text)) + text.encode()


def vec(items: list[bytes]) -> bytes:
    return leb(len(items)) + b"".join(items)


LOCK, UNLOCK, SIGNAL, REMOVE = 0, 1, 2, 3


def place(state: int, remove: bool) -> bytes:
    """emscripten_proxy_finish's (state 1, then remove_active_ctx) or
    cancel_ctx's (state 2) synchronous branch, as 4.0.20 builds it: ctx in
    local 0, the mutex's address in local 1."""
    return (b"\x20\x00\x41\x10\x6a\x22\x01\x10" + leb(LOCK) + b"\x1a"
            + b"\x20\x00\x41" + bytes([state]) + b"\x36\x02\x0c"
            + (b"\x20\x00\x10" + leb(REMOVE) if remove else b"")
            + b"\x20\x01\x10" + leb(UNLOCK) + b"\x1a"
            + b"\x20\x00\x41\x28\x6a\x10" + leb(SIGNAL))


def module(shared: bool = True, cancel: bool = True) -> bytes:
    i32 = b"\x7f"
    types = vec([b"\x60" + vec([i32]) + vec([i32]), b"\x60" + vec([i32]) + vec([])])
    imports = [name("env") + name("memory") + b"\x02" + (b"\x03" if shared else b"\x01") + leb(1) + leb(1)]
    for field, kind in (("lock", 0), ("unlock", 0), ("signal", 1), ("remove", 1)):
        imports.append(name("env") + name(field) + b"\x00" + leb(kind))
    bodies = [place(1, True)] + ([place(2, False)] if cancel else [])
    funcs = vec([leb(1) for _ in bodies])
    exports = vec([name(n) + b"\x00" + leb(4 + i) for i, n in enumerate(["finish", "cancel"][:len(bodies)])])
    code = vec([leb(len(b"\x01\x01\x7f" + body + b"\x0b")) + b"\x01\x01\x7f" + body + b"\x0b" for body in bodies])
    return (b"\0asm\x01\0\0\0" + section(1, types) + section(2, vec(imports)) + section(3, funcs)
            + section(7, exports) + section(10, code))


RUN = r"""
const fs = require("fs");
const bytes = fs.readFileSync(process.argv[1]);
const valid = WebAssembly.validate(bytes);
const memory = new WebAssembly.Memory({ initial: 1, maximum: 1, shared: true });
let calls = [];
const env = { memory,
  lock: (at) => { calls.push(`lock ${at}`); return 0; },
  unlock: (at) => { calls.push(`unlock ${at}`); return 0; },
  signal: (at) => { calls.push(`signal ${at}`); },
  remove: (at) => { calls.push(`remove ${at}`); } };
const { exports } = new WebAssembly.Instance(new WebAssembly.Module(bytes), { env });
const ints = new Int32Array(memory.buffer);
exports.finish(64);
const finish = calls; calls = [];
exports.cancel(128);
console.log(JSON.stringify({ valid, finish, cancel: calls, done: ints[(64 + 12) / 4], cancelled: ints[(128 + 12) / 4] }));
"""


def run(tmp_path: Path, data: bytes) -> dict:
    if shutil.which("node") is None:
        pytest.skip("no node to run the module in")
    wasm = tmp_path / "proxy.wasm"
    wasm.write_bytes(data)
    done = subprocess.run(["node", "-e", RUN, str(wasm)], capture_output=True, text=True, timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_mended_signals_before_it_unlocks(tmp_path):
    before = run(tmp_path, module())
    assert before["valid"]
    assert before["finish"] == ["lock 80", "remove 64", "unlock 80", "signal 104"]
    assert before["cancel"] == ["lock 144", "unlock 144", "signal 168"]
    mended, said = fix.mend(module())
    assert said == "mended 2 places (a call done, a call cancelled): signal before unlock"
    assert len(mended) == len(module())
    after = run(tmp_path, mended)
    assert after["valid"]
    assert after["finish"] == ["lock 80", "remove 64", "signal 104", "unlock 80"]
    assert after["cancel"] == ["lock 144", "signal 168", "unlock 144"]
    # What each stores is untouched: done, cancelled.
    assert (after["done"], after["cancelled"]) == (1, 2)


def test_mending_twice_changes_nothing(tmp_path):
    once, _ = fix.mend(module())
    twice, said = fix.mend(once)
    assert twice == once
    assert said.startswith("already mended")
    wasm = tmp_path / "index.wasm"
    wasm.write_bytes(once)
    done = subprocess.run(["python3", str(SCRIPT), str(wasm)], capture_output=True, text=True)
    assert done.returncode == 0 and "already mended" in done.stdout
    assert wasm.read_bytes() == once


def test_a_template_it_does_not_know_fails_the_build(tmp_path):
    lone = module(cancel=False)
    try:
        fix.mend(lone)
        refused = ""
    except fix.Unmendable as why:
        refused = str(why)
    assert "found 1 unmended (a call done) and 0 mended (none)" in refused
    wasm = tmp_path / "index.wasm"
    wasm.write_bytes(lone)
    done = subprocess.run(["python3", str(SCRIPT), str(wasm)], capture_output=True, text=True)
    assert done.returncode == 1 and "FAILED" in done.stdout
    assert wasm.read_bytes() == lone


def test_a_build_without_threads_has_nothing_to_mend():
    plain = module(shared=False)
    assert fix.mend(plain) == (plain, "no threads: nothing to mend")


@pytest.mark.skipif(not TEMPLATE.exists(), reason="no Godot 4.7.2 web template on this machine")
def test_the_template_the_web_build_is_made_from(tmp_path):
    data = zipfile.ZipFile(TEMPLATE).read("godot.wasm")
    mended, said = fix.mend(data)
    assert said == "mended 2 places (a call cancelled, a call done): signal before unlock"
    changed = [i for i in range(len(data)) if data[i] != mended[i]] if len(data) == len(mended) else None
    # Two places of 14 bytes each, reordered: nothing else in 38 MB moves.
    assert changed is not None and 0 < len(changed) <= 28
    assert changed[-1] - changed[0] > 1000
    if shutil.which("node") is not None:
        wasm = tmp_path / "godot.wasm"
        wasm.write_bytes(mended)
        done = subprocess.run(["node", "-e", "console.log(WebAssembly.validate(require('fs').readFileSync(process.argv[1])))",
                               str(wasm)], capture_output=True, text=True, timeout=120)
        assert done.stdout.strip() == "true", done.stderr[-2000:]
