#!/usr/bin/env python3
"""The web build's engine, mended where it could freeze a tab for good.

A worker that needs the main thread (a file opened, the page's JavaScript
asked) hands it the call and waits on a mutex and a condition that live on
the worker's own stack. Godot 4.7.2's web template is built with Emscripten
4.0.20, whose main thread finishes such a call by unlocking that mutex and
only then signalling the condition (system/lib/pthread/proxying.c,
emscripten_proxy_finish, and cancel_ctx the same). In between, the worker can
take the mutex, see its call done and return, and what it runs next writes
over the condition. The main thread then signals whatever is there: it takes
the bytes for waiters, finds one that seems to be leaving, and waits for it
to go, which no thread ever does. The page's main thread spins at 100% in one
task, every worker asleep, and the tab never answers again: the house link's
hang in play_flow (househang, 2026-11-07, its stack caught on pre261:
checkMailbox, emscripten_proxy_finish, pthread_cond_signal, __wait).

Emscripten fixed it in 5.0.5 (pull request 26582) by signalling before the
unlock, so the worker cannot wake until the signal is done. This makes the
same change in the built wasm: in both places the signal's instructions and
the unlock's trade places. Each is whole on its own (nothing left on the
stack), the two are the same bytes in another order, and nothing else in the
module moves. Anything other than the two places as 4.0.20 builds them, or
both already mended, and the build fails here, so a new template is looked at
rather than shipped with the freeze in it.

  python3 tools/web/wasm_proxy_fix.py build/web/index.wasm

A build without threads has no shared memory and nothing to mend.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

_LEB = rb"(?:[\x80-\xff]{0,4}[\x00-\x7f])"

# The synchronous branch of emscripten_proxy_finish (state 1, DONE, then
# remove_active_ctx(ctx)) and of cancel_ctx (state 2, CANCELED), as clang
# lays them out for an em_proxying_ctx (mutex at 16, state at 12, the
# condition at 40):
#
#   local.get ctx  i32.const 16  i32.add  local.tee m  call lock  drop
#   local.get ctx  i32.const K   i32.store offset=12
#   [local.get ctx  call remove_active_ctx]
#   local.get m  call unlock  drop                    <- the unlock
#   local.get ctx  i32.const 40  i32.add  call signal  <- the signal
_HEAD = (rb"\x20(?P<c>[\x00-\x7f])\x41\x10\x6a\x22(?P<m>[\x00-\x7f])\x10" + _LEB + rb"\x1a"
         rb"\x20(?P=c)\x41(?P<k>[\x01\x02])\x36\x02\x0c"
         rb"(?:\x20(?P=c)\x10" + _LEB + rb")?")
_UNLOCK = rb"\x20(?P=m)\x10" + _LEB + rb"\x1a"
_SIGNAL = rb"\x20(?P=c)\x41\x28\x6a\x10" + _LEB
UNMENDED = re.compile(_HEAD + rb"(?P<unlock>" + _UNLOCK + rb")(?P<signal>" + _SIGNAL + rb")", re.S)
MENDED = re.compile(_HEAD + rb"(?P<signal>" + _SIGNAL + rb")(?P<unlock>" + _UNLOCK + rb")", re.S)

STATES = {1: "a call done", 2: "a call cancelled"}


class Unmendable(Exception):
    pass


def _leb(data: bytes, at: int) -> tuple[int, int]:
    value = shift = 0
    while True:
        byte = data[at]
        at += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if byte < 0x80:
            return value, at


def _name(data: bytes, at: int) -> int:
    size, at = _leb(data, at)
    return at + size


def sections(data: bytes) -> tuple[bool, tuple[int, int]]:
    """Whether the module's memory is shared (a threads build), and where its
    code section's bytes lie."""
    if data[:8] != b"\0asm\x01\0\0\0":
        raise Unmendable("not a WebAssembly module")
    shared = False
    code = (0, 0)
    at = 8
    while at < len(data):
        kind = data[at]
        size, at = _leb(data, at + 1)
        end = at + size
        if kind == 2:
            count, q = _leb(data, at)
            for _ in range(count):
                q = _name(data, _name(data, q))
                what = data[q]
                q += 1
                if what == 0:
                    _, q = _leb(data, q)
                elif what in (1, 2):
                    if what == 1:
                        q += 1
                    flags, q = _leb(data, q)
                    _, q = _leb(data, q)
                    if flags & 1:
                        _, q = _leb(data, q)
                    if what == 2 and flags & 2:
                        shared = True
                elif what == 3:
                    q += 2
                else:
                    raise Unmendable(f"an import of kind {what} this does not read")
        elif kind == 5:
            count, q = _leb(data, at)
            for _ in range(count):
                flags, q = _leb(data, q)
                _, q = _leb(data, q)
                if flags & 1:
                    _, q = _leb(data, q)
                shared = shared or bool(flags & 2)
        elif kind == 10:
            code = (at, end)
        at = end
    return shared, code


def _found(pattern: re.Pattern, data: bytes, code: tuple[int, int]) -> list[re.Match]:
    return list(pattern.finditer(data, code[0], code[1]))


def mend(data: bytes) -> tuple[bytes, str]:
    """[param data] mended, and what was done, in a few words."""
    shared, code = sections(data)
    if not shared:
        return data, "no threads: nothing to mend"
    if code == (0, 0):
        raise Unmendable("no code section")
    old = _found(UNMENDED, data, code)
    new = _found(MENDED, data, code)
    states = sorted(int(m.group("k")[0]) for m in old + new)
    if states != [1, 2]:
        raise Unmendable(
            f"expected Emscripten's proxy finish and cancel once each, found {len(old)} unmended "
            f"({', '.join(STATES[int(m.group('k')[0])] for m in old) or 'none'}) and {len(new)} mended "
            f"({', '.join(STATES[int(m.group('k')[0])] for m in new) or 'none'}): a template this does "
            "not know; read system/lib/pthread/proxying.c of its Emscripten before shipping it")
    if not old:
        return data, "already mended (signal before unlock, both places)"
    out = bytearray(data)
    for m in old:
        start = m.start("unlock")
        out[start:m.end("signal")] = m.group("signal") + m.group("unlock")
    mended = bytes(out)
    left = _found(UNMENDED, mended, code)
    if left or len(_found(MENDED, mended, code)) != 2:
        raise Unmendable("the mended module does not read back as mended")
    return mended, "mended %d places (%s): signal before unlock" % (
        len(old), ", ".join(STATES[int(m.group("k")[0])] for m in old))


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[0])
        print("usage: python3 tools/web/wasm_proxy_fix.py path/to/index.wasm")
        return 2
    path = Path(argv[1])
    data = path.read_bytes()
    try:
        mended, said = mend(data)
    except Unmendable as why:
        print(f"wasm_proxy_fix: {path}: FAILED: {why}")
        return 1
    if mended != data:
        temp = path.with_name(path.name + ".mending")
        temp.write_bytes(mended)
        os.replace(temp, path)
    print(f"wasm_proxy_fix: {path}: {said}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
