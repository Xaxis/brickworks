#!/usr/bin/env python3
"""No call names a function that is not there.

handkeep2 took Builder._lift_on_top out (2026-11-26). Two callers were left:
Assemblies._copies_state, as `builder._lift_on_top()` on a member typed
Builder, and wingplace_probe, as `_builder.call("_lift_on_top")`. Godot's
own check (`godot --check-only`, the merge's parse gate) passed both: it
checks a call on self, super or a class by name, and nothing on a typed
variable, a string or an untyped one. Each unit's probes passed. The release
train went red on six probes, every one a runtime "Nonexistent function"
error that dropped the mirrored-copy warning for a person holding a part, and
a day of release was lost.

This reads every script under src/ and tools/ (no engine run) and names:
  - `X.NAME(...)` where X's class is known (a typed variable, member or
    parameter, `self`, `super`, a class name, an engine singleton, an
    expression whose type follows from those, or a field name such as
    `builder` that the code types one way everywhere) and NAME is a method
    of neither that class, its bases, nor any class derived from it (a
    variable typed Base may hold a Derived);
  - the same for `X.call("NAME")`, call_deferred, callv, rpc, rpc_id,
    has_method (a guard names the method it guards, so a guard for a removed
    method is a silent drop), `Callable(X, "NAME")`, and a method passed as a
    value (`X.NAME.bind(`, `.call(`, `connect(X.NAME)`, tween_callback);
  - for an X of no known class, a NAME that no script, engine class or
    built-in type defines at all, which is how `_lift_on_top` shows;
  - a bare `NAME(` that is in neither the class's chain, an outer class, nor
    GDScript's functions (a base class losing a method its subclass calls:
    Godot checks only the scripts a merge changed).

Engine classes and their methods come from the engine itself
(`godot --dump-extension-api` and `--doctool`'s @GDScript), dumped once per
engine binary into ~/.cache/brickworks-callcheck/.

A call that is meant to be dynamic (a JavaScript object's method, a method
a probe looks for on purpose) is marked on its line, or alone on the line
above, with the reason:

    win.fetch(url)  # callcheck: dynamic, a JavaScript object's own method

A mark with no reason, or on a line with nothing to excuse, is itself named.

    tools/callcheck.py                 the tree this file is in
    tools/callcheck.py --root DIR      another checkout
    tools/callcheck.py --jobs 1        in one process (default: up to 8)

Exit 0 when nothing is named, 1 when something is, 2 when it cannot run.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
SCAN = ("src", "tools")
API_FORMAT = 2      # bumped whenever reduce_api's output changes, so an old cache is not read

# --------------------------------------------------------------------------
# The engine's own classes, read from the engine.


def _norm_type(raw: str | None) -> str | None:
    """An extension_api type as the GDScript one, None for Variant/void."""
    if not raw or raw in ("Variant", "void", "Nil"):
        return None
    if raw.startswith(("enum::", "bitfield::")):
        return "int"
    if raw.startswith("typedarray::"):
        return "Array[" + raw.split("::", 1)[1] + "]"
    if raw.startswith("typeddictionary::"):
        return "Dictionary"
    return raw


def reduce_api(ext: dict, gdscript_functions: dict[str, str | None]) -> dict:
    """The parts of extension_api.json this check reads, small enough to load fast."""
    classes = {}
    for c in ext["classes"]:
        members: dict[str, str | None] = {}
        for p in c.get("properties", []):
            members[p["name"]] = _norm_type(p.get("type"))
        for s in c.get("signals", []):
            members[s["name"]] = "Signal"
        for k in c.get("constants", []):
            members[k["name"]] = "int"
        for e in c.get("enums", []):
            members[e["name"]] = "Dictionary"
            for v in e.get("values", []):
                members[v["name"]] = "int"
        methods = {m["name"]: _norm_type((m.get("return_value") or {}).get("type"))
                   for m in c.get("methods", [])}
        classes[c["name"]] = {"inherits": c.get("inherits"), "methods": methods, "members": members}
    builtins = {}
    for b in ext["builtin_classes"]:
        members = {m["name"]: _norm_type(m.get("type")) for m in b.get("members", [])}
        for k in b.get("constants", []):
            members[k["name"]] = _norm_type(k.get("type"))
        for e in b.get("enums", []):
            members[e["name"]] = "Dictionary"
            for v in e.get("values", []):
                members[v["name"]] = "int"
        methods = {m["name"]: _norm_type(m.get("return_type")) for m in b.get("methods", [])}
        builtins[b["name"]] = {"methods": methods, "members": members}
    functions = {f["name"]: _norm_type(f.get("return_type")) for f in ext["utility_functions"]}
    functions.update(gdscript_functions)
    singletons = {s["name"]: s["type"] for s in ext["singletons"]}
    return {"classes": classes, "builtins": builtins, "functions": functions, "singletons": singletons}


def _godot_key(godot: str) -> str:
    real = os.path.realpath(godot)
    st = os.stat(real)
    return hashlib.sha1(f"{real}:{st.st_size}:{st.st_mtime_ns}".encode()).hexdigest()[:16]


def dump_api(godot: str) -> dict:
    """Ask the engine for its classes and GDScript's functions (about 2 s)."""
    with tempfile.TemporaryDirectory(prefix="callcheck-api-") as tmp:
        env = dict(os.environ)
        # Never the person's own editor settings or app data.
        for var in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            env[var] = os.path.join(tmp, var.lower())

        def godot_in(cwd: str, *args: str) -> None:
            subprocess.run([godot, "--headless", *args], cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120, check=False)

        godot_in(tmp, "--dump-extension-api")
        docs = os.path.join(tmp, "docs")
        os.mkdir(docs)
        godot_in(docs, "--doctool", docs)
        ext_path = os.path.join(tmp, "extension_api.json")
        gd_path = os.path.join(docs, "modules", "gdscript", "doc_classes", "@GDScript.xml")
        object_path = os.path.join(docs, "doc", "classes", "Object.xml")
        if not all(os.path.exists(p) for p in (ext_path, gd_path, object_path)):
            raise RuntimeError(f"{godot} wrote no extension_api.json, @GDScript.xml or Object.xml")
        with open(ext_path, encoding="utf-8") as f:
            ext = json.load(f)

        def methods(path: str) -> dict[str, str | None]:
            out = {}
            for method in ET.parse(path).getroot().iter("method"):
                ret = method.find("return")
                out[method.get("name")] = _norm_type(ret.get("type") if ret is not None else None)
            return out

        api = reduce_api(ext, methods(gd_path))
        # Object's free() and its virtuals (_init, _notification...) are in its
        # documentation, not in the GDExtension list.
        for name, ret in methods(object_path).items():
            api["classes"]["Object"]["methods"].setdefault(name, ret)
    return api


def load_api(godot: str | None = None, cache_dir: Path | None = None) -> dict:
    godot = godot or shutil.which("godot")
    if not godot:
        raise RuntimeError("no godot on PATH to read the engine's classes from")
    cache_dir = cache_dir or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "brickworks-callcheck"
    path = cache_dir / f"api{API_FORMAT}-{_godot_key(godot)}.json"
    if path.exists():
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    api = dump_api(godot)
    cache_dir.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=cache_dir, prefix=".api-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(api, f)
    os.replace(tmp, path)
    return api


# --------------------------------------------------------------------------
# Reading a script: strings and comments out, the shapes this check needs in.

# A string is kept when it could be a method name or a res:// path, emptied
# otherwise (so no bracket, quote or # inside one is read as code); a
# comment is dropped, its mark kept. Line numbers are unchanged.
_MASK = re.compile(r'"""(.*?)"""|\'\'\'(.*?)\'\'\'|"((?:\\.|[^"\\\n])*)"|\'((?:\\.|[^\'\\\n])*)\'|#([^\n]*)', re.S)
_KEEP = re.compile(r"[A-Za-z_]\w*\Z|res://[\w./ -]+\Z")
_MARK = re.compile(r"callcheck:\s*(\w+)\W*(.*)")


def mask(text: str) -> tuple[str, dict[int, str]]:
    """(the text with strings emptied and comments dropped, {line: mark reason})"""
    marks: dict[int, str] = {}

    def sub(m: re.Match) -> str:
        comment = m.group(5)
        if comment is not None:
            if "callcheck:" in comment:
                mk = _MARK.search(comment)
                line = text.count("\n", 0, m.start()) + 1
                marks[line] = mk.group(2).strip() if mk and mk.group(1) == "dynamic" else "\0" + comment.strip()
            return ""
        body = m.group(1) if m.group(1) is not None else m.group(2)
        if body is not None:
            return '""' + "\n" * body.count("\n")
        body = m.group(3) if m.group(3) is not None else m.group(4)
        return '"' + body + '"' if _KEEP.match(body) else '""'

    return _MASK.sub(sub, text), marks


_DECL = re.compile(r"^([ \t]*)(?:@\w+(?:\([^)\n]*\))?[ \t]+)*(static[ \t]+)?"
                   r"(func|var|const|signal|enum|class_name|class|extends)\b([^\n]*)", re.M)
_TYPE = r"[A-Za-z_][\w.]*(?:\[[\w.,\[\] \t]*\])?"
_VAR = re.compile(r"[ \t]+(\w+)[ \t]*(?::[ \t]*(" + _TYPE + r"))?[ \t]*(:?=)?[ \t]*(.*)")
_CONST = re.compile(r"[ \t]+(\w+)[ \t]*(?::[ \t]*(" + _TYPE + r"))?[ \t]*:?=[ \t]*(.*)")
_FUNC = re.compile(r"[ \t]+(\w+)[ \t]*\(")
_RET = re.compile(r"[ \t]*->[ \t]*(" + _TYPE + ")")
_CLASS = re.compile(r'[ \t]+(\w+)(?:[ \t]+extends[ \t]+([\w.]+|"[^"]*"))?')
_EXTENDS = re.compile(r'[ \t]+([\w.]+|"[^"]*")')
_NAME = re.compile(r"[ \t]+(\w+)")
_PARAM = re.compile(r"\s*(\w+)[ \t]*(?::[ \t]*(" + _TYPE + r"))?[ \t]*(:?=)?[ \t]*(.*)", re.S)


def split_args(text: str) -> list[str]:
    """Top-level comma-separated pieces of an argument list."""
    out, depth, start = [], 0, 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            out.append(text[start:i])
            start = i + 1
    tail = text[start:]
    if tail.strip():
        out.append(tail)
    return out


def _close(text: str, start: int, open_c: str = "(", close_c: str = ")") -> int:
    """Index of the bracket closing the one at text[start], or -1."""
    depth = 0
    for i in range(start, len(text)):
        c = text[i]
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i
    return -1


@dataclass
class Cls:
    key: str
    path: str
    line: int
    name: str | None = None
    extends: str | None = None
    outer: str | None = None
    funcs: dict = field(default_factory=dict)      # name -> return type (raw) or None
    vars: dict = field(default_factory=dict)       # name -> (type raw, initialiser raw)
    consts: dict = field(default_factory=dict)     # name -> (type raw, initialiser raw)
    signals: set = field(default_factory=set)
    enums: set = field(default_factory=set)
    values: set = field(default_factory=set)       # enum values
    inners: dict = field(default_factory=dict)     # name -> key
    parent: tuple | None = None                    # ("s", key) / ("e", engine class) once resolved
    resolved: bool = False                         # its whole chain is known


def parse_params(text: str) -> list[tuple[str, str | None, str | None]]:
    out = []
    for piece in split_args(text):
        m = _PARAM.match(piece)
        if m:
            out.append((m.group(1), m.group(2), m.group(4).strip() if m.group(3) else None))
    return out


def scan_decls(path: str, res: str, text: str) -> tuple[list[Cls], dict[int, tuple]]:
    """Every class in a script and each class-level declaration; and each func by line:
    {line: (name, params, class key)}."""
    top = Cls(key=res, path=path, line=1)
    classes = [top]
    funcs_by_line: dict[int, tuple] = {}
    stack = [(-1, 0, top)]          # (header indent, body indent or -1 until seen, class)
    line, last = 1, 0
    for m in _DECL.finditer(text):
        line += text.count("\n", last, m.start())
        last = m.start()
        d = len(m.group(1))
        while stack[-1][0] >= d:
            stack.pop()
        header, body, cls = stack[-1]
        if body < 0:
            body = d
            stack[-1] = (header, body, cls)
        kind, rest = m.group(3), m.group(4)
        static = bool(m.group(2))
        if kind == "func":
            fm = _FUNC.match(rest)
            if not fm:
                continue        # a lambda
            name = fm.group(1)
            open_at = m.start(4) + fm.end() - 1
            close_at = _close(text, open_at)
            params = parse_params(text[open_at + 1:close_at]) if close_at > 0 else []
            ret = None
            if close_at > 0:
                rm = _RET.match(text, close_at + 1)
                ret = rm.group(1) if rm else None
            funcs_by_line[line] = (name, params, cls.key, static)
            if d == body:
                cls.funcs.setdefault(name, ret)
            continue
        if d != body:
            continue            # a local, or in a function
        if kind == "var":
            vm = _VAR.match(rest)
            if vm:
                cls.vars[vm.group(1)] = (vm.group(2), vm.group(4).strip() if vm.group(3) else None)
        elif kind == "const":
            cm = _CONST.match(rest)
            if cm:
                cls.consts[cm.group(1)] = (cm.group(2), cm.group(3).strip())
        elif kind == "signal":
            nm = _NAME.match(rest)
            if nm:
                cls.signals.add(nm.group(1))
        elif kind == "enum":
            brace = text.find("{", m.start(4))
            end = text.find("}", brace)
            nm = re.match(r"[ \t]*(\w+)", rest)
            if nm and nm.group(1) and not rest.lstrip().startswith("{"):
                cls.enums.add(nm.group(1))
            if brace >= 0 and end > brace:
                for piece in text[brace + 1:end].split(","):
                    v = piece.split("=")[0].strip()
                    if v.isidentifier():
                        cls.values.add(v)
        elif kind == "class_name":
            cm = _CLASS.match(rest)
            if cm and cls is top:
                top.name = cm.group(1)
                if cm.group(2):
                    top.extends = cm.group(2)
        elif kind == "extends":
            em = _EXTENDS.match(rest)
            if em and cls is top:
                top.extends = em.group(1)
        elif kind == "class":
            cm = _CLASS.match(rest)
            if cm:
                inner = Cls(key=cls.key + "::" + cm.group(1) if "::" not in cls.key else cls.key + "." + cm.group(1),
                            path=path, line=line, name=cm.group(1), extends=cm.group(2), outer=cls.key)
                cls.inners[inner.name] = inner.key
                classes.append(inner)
                stack.append((d, -1, inner))
    return classes, funcs_by_line


# --------------------------------------------------------------------------
# The index: every class, its chain, and what each class can be asked.

KEYWORDS = {
    "if", "elif", "else", "while", "for", "match", "return", "and", "or", "not", "in", "is", "as",
    "await", "func", "signal", "static", "var", "const", "class", "extends", "super", "self", "pass",
    "break", "continue", "breakpoint", "yield", "when", "null", "true", "false", "void",
    "PI", "TAU", "INF", "NAN",
}
REF_CALLS = {"bind", "unbind", "call", "callv", "call_deferred", "bindv"}
STRING_CALLS = {"call": 0, "call_deferred": 0, "callv": 0, "has_method": 0, "rpc": 0, "rpc_id": 1}
CONNECTS = {"connect", "disconnect", "is_connected"}
CALLBACKS = {"tween_callback": 0, "tween_method": 0}


class Index:
    def __init__(self, api: dict, classes: list[Cls]):
        self.api = api
        self.eclasses: dict = api["classes"]
        self.builtins: dict = api["builtins"]
        self.functions: dict = api["functions"]
        self.singletons: dict = api["singletons"]
        self.classes: dict[str, Cls] = {c.key: c for c in classes}
        self.global_names: dict[str, str] = {}
        for c in classes:
            if c.name and not c.outer:
                self.global_names[c.name] = c.key
        self._member_type: dict = {}
        self._reach: dict = {}
        # Remembered once every class's parent is known (before, a chain is half made).
        self._frozen = False
        self._chains: dict = {}
        self._statics: dict = {}
        self._types: dict = {}
        for c in classes:
            self._resolve_parent(c)
        for c in classes:
            c.resolved = self._chain_ok(c.key)
        self._frozen = True
        self.children: dict[str, list[str]] = {}
        self.engine_children: dict[str, list[str]] = {}
        for c in classes:
            if c.parent and c.parent[0] == "s":
                self.children.setdefault(c.parent[1], []).append(c.key)
            elif c.parent and c.parent[0] == "e":
                self.engine_children.setdefault(c.parent[1], []).append(c.key)
        self.engine_subclasses: dict[str, list[str]] = {}
        for name, e in self.eclasses.items():
            if e.get("inherits"):
                self.engine_subclasses.setdefault(e["inherits"], []).append(name)
        # Every name anything defines, for a receiver of no known class.
        funcs, members = {"new"}, {"new"}
        for c in classes:
            funcs.update(c.funcs)
            members.update(c.funcs, c.vars, c.consts, c.signals, c.enums, c.values, c.inners)
        for e in self.eclasses.values():
            funcs.update(e["methods"])
            members.update(e["methods"], e["members"])
        for b in self.builtins.values():
            funcs.update(b["methods"])
            members.update(b["methods"], b["members"])
        self.all_funcs, self.all_members = funcs, members
        # A field name typed one way wherever it is typed (`var builder: Builder`).
        seen: dict[str, set] = {}
        for c in classes:
            for name, (raw, _init) in c.vars.items():
                if raw:
                    t = self.type_named(raw, c)
                    seen.setdefault(name, set()).add(t)
        self.field_types = {n: next(iter(ts)) for n, ts in seen.items()
                            if len(ts) == 1 and next(iter(ts)) and next(iter(ts))[0] == "s"}

    # -- names and chains

    def _resolve_parent(self, c: Cls) -> None:
        raw = c.extends
        if raw is None:
            c.parent = ("e", "RefCounted")
            return
        if raw.startswith('"'):
            key = raw.strip('"')
            c.parent = ("s", key) if key in self.classes else None
            return
        t = self.static_named(raw, self.classes.get(c.outer) if c.outer else None, skip=c)
        if t and t[0] == "S":
            c.parent = ("s", t[1])
        elif t and t[0] == "E":
            c.parent = ("e", t[1])
        else:
            c.parent = None

    def _chain_ok(self, key: str) -> bool:
        seen = set()
        while key not in seen:
            seen.add(key)
            c = self.classes.get(key)
            if c is None or c.parent is None:
                return False
            if c.parent[0] == "e":
                return c.parent[1] in self.eclasses
            key = c.parent[1]
        return False

    def script_chain(self, key: str) -> list[Cls]:
        """The class and each script class above it."""
        if self._frozen and key in self._chains:
            return self._chains[key]
        out: list[Cls] = []
        start = key
        while key in self.classes and all(c.key != key for c in out):
            c = self.classes[key]
            out.append(c)
            if not c.parent or c.parent[0] != "s":
                break
            key = c.parent[1]
        if self._frozen:
            self._chains[start] = out
        return out

    def engine_base(self, key: str) -> str | None:
        chain = self.script_chain(key)
        last = chain[-1] if chain else None
        if last and last.parent and last.parent[0] == "e":
            return last.parent[1]
        return None

    def engine_chain(self, name: str | None) -> list[tuple[str, dict]]:
        k = ("engine", name)
        if k in self._chains:
            return self._chains[k]
        out: list[tuple[str, dict]] = []
        while name and name in self.eclasses and all(n != name for n, _e in out):
            out.append((name, self.eclasses[name]))
            name = self.eclasses[name].get("inherits")
        self._chains[k] = out
        return out

    def static_named(self, raw: str, cls: Cls | None, skip: Cls | None = None) -> tuple | None:
        """A class named in source: ("S", key), ("E", engine class), ("B", built-in type)."""
        parts = raw.split(".")
        t = self._first_static(parts[0], cls, skip)
        for p in parts[1:]:
            if t is None:
                return None
            if t[0] == "S":
                t = self._static_member(t[1], p)
            else:
                return None
        return t

    def _first_static(self, name: str, cls: Cls | None, skip: Cls | None = None) -> tuple | None:
        if not self._frozen:
            return self._find_static(name, cls, skip)
        k = (name, cls.key if cls else None)
        if k not in self._statics:
            self._statics[k] = self._find_static(name, cls, None)
        return self._statics[k]

    def _find_static(self, name: str, cls: Cls | None, skip: Cls | None) -> tuple | None:
        scope = cls
        while scope is not None:
            for c in ([scope] if scope is skip else self.script_chain(scope.key)):
                if name in c.inners:
                    return ("S", c.inners[name])
                if name in c.consts:
                    t = self._const_class(c, name)
                    if t:
                        return t
            scope = self.classes.get(scope.outer) if scope.outer else None
        if name in self.global_names:
            return ("S", self.global_names[name])
        if name in self.eclasses:
            return ("E", name)
        if name in self.builtins:
            return ("B", name)
        return None

    def _static_member(self, key: str, name: str) -> tuple | None:
        for c in self.script_chain(key):
            if name in c.inners:
                return ("S", c.inners[name])
            if name in c.consts:
                return self._const_class(c, name)
        return None

    def _const_class(self, c: Cls, name: str) -> tuple | None:
        _raw, init = c.consts[name]
        m = re.fullmatch(r'(?:pre)?load\(\s*"(res://[^"]+)"\s*\)', init or "")
        if m and m.group(1) in self.classes:
            return ("S", m.group(1))
        return None

    def type_named(self, raw: str | None, cls: Cls | None) -> tuple | None:
        """The type of a value declared `: raw`."""
        if not raw:
            return None
        k = (raw, cls.key if cls else None)
        if k in self._types:
            return self._types[k]
        t = self._type_named(raw.replace(" ", "").replace("\t", ""), cls)
        if self._frozen:
            self._types[k] = t
        return t

    def _type_named(self, raw: str, cls: Cls | None) -> tuple | None:
        if "[" in raw:
            base, _, inner = raw.partition("[")
            inner = inner[:-1] if inner.endswith("]") else inner
            if base == "Array":
                return ("b", "Array", self.type_named(inner, cls))
            if base == "Dictionary":
                pieces = split_args(inner)
                return ("b", "Dictionary", self.type_named(pieces[-1], cls) if len(pieces) == 2 else None)
            return self.type_named(base, cls)
        if raw in ("Variant", "void"):
            return None
        t = self.static_named(raw, cls)
        if t is None:
            return None
        return self.instance(t)

    def instance(self, t: tuple) -> tuple | None:
        kind, name = t[0], t[1]
        if kind == "S":
            return ("s", name)
        if kind == "E":
            if name in ("GDScript", "Script"):
                return None         # a script of no known class: its functions are any script's
            return ("d", name) if name == "JavaScriptObject" else ("e", name)
        if kind == "B":
            return ("b", name, None)
        return t

    def norm(self, raw: str | None, cls: Cls | None = None) -> tuple | None:
        """An engine-API type string (or a script's) as a type."""
        return self.type_named(raw, cls) if raw else None

    # -- members

    def member_type(self, t: tuple | None, name: str, call: bool, args: str | None = None) -> tuple | None:
        """The type of `t.name` (call: of `t.name(...)`, given args)."""
        if t is None or t[0] == "u":
            return None
        kind = t[0]
        if kind == "d":
            return t
        if kind == "S" and call and name in LATER and args and self.classes[t[1]].name == "Later":
            m = _NAME_ARG.match(args)
            if m and m.group(1) in self.global_names:
                return (LATER[name], self.global_names[m.group(1)])
        if kind in ("s", "S"):
            for c in self.script_chain(t[1]):
                if call and name in c.funcs:
                    return self.type_named(c.funcs[name], c)
                if not call:
                    if name in c.vars:
                        return self.var_type(c, name)
                    if name in c.inners:
                        return ("S", c.inners[name])
                    if name in c.consts:
                        return self._const_class(c, name) or self.type_named(c.consts[name][0], c) or self.infer(c.consts[name][1], c, None)
                    if name in c.signals:
                        return ("b", "Signal", None)
                    if name in c.enums:
                        return ("b", "Dictionary", None)
            if call and name == "new" and kind == "S":
                return ("s", t[1])
            if kind == "S":
                found = self.member_type(("e", "GDScript"), name, call)
                if found is not None:
                    return found
            return self.member_type(("e" if kind == "s" else "E", self.engine_base(t[1])), name, call) \
                if self.engine_base(t[1]) else None
        if kind in ("e", "E"):
            if call and name == "new" and kind == "E":
                return self.instance(t)
            for _n, e in self.engine_chain(t[1]):
                if call and name in e["methods"]:
                    return self.norm(e["methods"][name])
                if not call and name in e["members"]:
                    return self.norm(e["members"][name])
            return None
        if kind in ("b", "B"):
            b = self.builtins.get(t[1])
            if not b:
                return None
            if call:
                if t[1] in ("Array",) and name in ("pop_back", "pop_front", "back", "front", "pick_random", "get") and len(t) > 2:
                    return t[2]
                return self.norm(b["methods"].get(name))
            return self.norm(b["members"].get(name))
        return None

    def var_type(self, c: Cls, name: str) -> tuple | None:
        k = (c.key, name)
        if k in self._member_type:
            return self._member_type[k]
        self._member_type[k] = None         # a cycle is unknown
        raw, init = c.vars[name]
        t = self.declared(raw, init, init is not None, c, None)
        if t is None:
            t = self.field_types.get(name)
        self._member_type[k] = t
        return t

    def _reach_names(self, t: tuple, refs: bool) -> set:
        """Every name `t.NAME(` may call (refs: may name as a value)."""
        k = (t[0], t[1], refs)
        if k in self._reach:
            return self._reach[k]
        out: set = set()
        kind = t[0]
        if kind in ("s", "S"):
            for c in self.script_chain(t[1]):
                out.update(c.funcs)
                if refs:
                    out.update(c.vars, c.consts, c.signals, c.enums, c.values, c.inners)
            for _n, e in self.engine_chain(self.engine_base(t[1])):
                out.update(e["methods"])
                if refs:
                    out.update(e["members"])
            if kind == "S":
                # the class as a value is its GDScript: get_script_constant_map()...
                out.add("new")
                for _n, e in self.engine_chain("GDScript"):
                    out.update(e["methods"])
                    if refs:
                        out.update(e["members"])
            else:
                for d in self._script_descendants(t[1]):
                    c = self.classes[d]
                    out.update(c.funcs)
                    if refs:
                        out.update(c.vars, c.consts, c.signals)
        elif kind in ("e", "E"):
            for _n, e in self.engine_chain(t[1]):
                out.update(e["methods"])
                if refs:
                    out.update(e["members"])
            if kind == "E":
                out.add("new")
            else:
                if any(n == t[1] for n, _e in self.engine_chain("GDScript")):
                    # a Resource (or Script) may be a script, and a script's
                    # own functions are called on it
                    for c in self.classes.values():
                        out.update(c.funcs)
                for sub in self._engine_descendants(t[1]):
                    e = self.eclasses[sub]
                    out.update(e["methods"])
                    if refs:
                        out.update(e["members"])
                    for root in self.engine_children.get(sub, []):
                        for d in [root, *self._script_descendants(root)]:
                            c = self.classes[d]
                            out.update(c.funcs)
                            if refs:
                                out.update(c.vars, c.consts, c.signals)
        elif kind in ("b", "B"):
            b = self.builtins.get(t[1], {"methods": {}, "members": {}})
            out.update(b["methods"])
            if refs:
                out.update(b["members"])
        self._reach[k] = out
        return out

    def _script_descendants(self, key: str) -> list[str]:
        out, todo = [], list(self.children.get(key, []))
        while todo:
            k = todo.pop()
            out.append(k)
            todo.extend(self.children.get(k, []))
        return out

    def _engine_descendants(self, name: str) -> list[str]:
        out, todo = [name], list(self.engine_subclasses.get(name, []))
        while todo:
            n = todo.pop()
            out.append(n)
            todo.extend(self.engine_subclasses.get(n, []))
        return out

    def has(self, t: tuple | None, name: str, refs: bool = False) -> bool:
        if t is None or t[0] == "u":
            return name in (self.all_members if refs else self.all_funcs)
        if t[0] == "d":
            return True
        if t[0] in ("s", "S") and not self.classes[t[1]].resolved:
            return True             # a chain this check cannot follow: say nothing
        return name in self._reach_names(t, refs)

    def describe(self, t: tuple) -> str:
        kind, name = t[0], t[1]
        if kind in ("s", "S"):
            c = self.classes[name]
            label = c.name if c.name and not c.outer else name.removeprefix("res://")
            if c.outer:
                label = self.describe(("s", c.outer)) + "." + str(c.name)
            return label if kind == "s" else label + " (the class)"
        return name

    # -- expressions

    def infer(self, expr: str | None, cls: Cls | None, scope) -> tuple | None:
        """The type of an initialiser, or None."""
        if not expr:
            return None
        e = expr.strip()
        if e.endswith(":"):
            e = e[:-1].rstrip()
        if e.startswith("await "):
            e = e[6:].lstrip()
        if not e:
            return None
        m = _AS_TAIL.search(e)
        if m:
            return self.type_named(m.group(1), cls)
        c0 = e[0]
        if c0 == "{":
            return ("b", "Dictionary", None)
        if c0 == "[":
            return ("b", "Array", None)
        if c0 in "\"'":
            return ("b", "String", None) if e.endswith(c0) and e.count(c0) == 2 else None
        if e.startswith("func"):
            return ("b", "Callable", None)
        got = scan_back(e, len(e))
        if got is None or got[2] != 0:
            # Not a name, a call or a chain of them (an operator, a value
            # that goes on to the next line): of no type this check knows.
            m = re.match(r"([A-Za-z_]\w*)(?:\.new)?\(", e)
            if m and m.group(1) in self.builtins:
                return ("b", m.group(1), None)
            return UNKNOWN
        return self.resolve_chain(got[0], got[1], cls, scope)

    def declared(self, raw: str | None, init: str | None, has_init: bool, cls: Cls | None, scope) -> tuple | None:
        """The type of `var x: raw = init`. An initialiser of a script's class
        narrows a declared engine type (`var dialog: Window = Later.make(&"X")`)."""
        t_init = self.infer(init, cls, scope) if has_init else None
        if not raw:
            return t_init
        t = self.type_named(raw, cls)
        if t_init and t_init[0] in ("s", "S"):
            base = raw.strip()
            if t is None and base in ("GDScript", "Script", "Resource", "Object", "RefCounted", "Variant"):
                return t_init
            if t and t[0] == "e":
                engine = self.engine_base(t_init[1])
                if any(n == t[1] for n, _e in self.engine_chain(engine)):
                    return t_init
        return t if t is not None else UNKNOWN

    def resolve_chain(self, head, segs, cls: Cls | None, scope, upto: int | None = None) -> tuple | None:
        """The type of a receiver: head (how it starts) and its segments."""
        segs = segs if upto is None else segs[:upto]
        kind = head[0]
        if kind == "node":
            t: tuple | None = ("e", "Node")
        elif kind == "as":
            t = self.type_named(head[1], cls)
        elif kind == "lit":
            t = ("b", head[1], None)
        elif kind == "id":
            if not segs:
                return None
            t = self.first_type(segs[0], cls, scope)
            segs = segs[1:]
        else:
            return None
        for name, call, index, args in segs:
            if t is None or t[0] == "u":
                t = None if call or index else self.field_types.get(name)
            else:
                t = self.member_type(t, name, call, args)
            if index:
                t = self._index(t)
        return t

    def _index(self, t: tuple[Any, ...] | None) -> tuple | None:
        """The type of `t[...]`."""
        if not t:
            return None
        kind, name, elem = (*t, None, None)[:3]
        if kind == "b" and name in ("Array", "Dictionary"):
            return elem
        if kind == "b" and name in ("String", "StringName"):
            return ("b", "String", None)
        return t if kind == "d" else None

    def first_type(self, seg, cls: Cls | None, scope) -> tuple | None:
        name, call, index, args = seg
        t = self._first_type(name, call, args, cls, scope)
        return self._index(t) if index else t

    def _first_type(self, name: str, call: bool, args: str | None, cls: Cls | None, scope) -> tuple | None:
        if call:
            if name in ("load", "preload") and args:
                m = _RES_ARG.match(args)
                if m:
                    p = m.group(1)
                    if p in self.classes:
                        return ("S", p)
                    return ("e", "PackedScene") if p.endswith((".tscn", ".scn")) else ("e", "Resource")
            if cls is not None:
                for c in self.script_chain(cls.key):
                    if name in c.funcs:
                        return self.type_named(c.funcs[name], c)
                base = self.engine_base(cls.key)
                for _n, e in self.engine_chain(base):
                    if name in e["methods"]:
                        return self.norm(e["methods"][name])
            if name in self.functions:
                return self.norm(self.functions[name])
            if name in self.builtins:
                return ("b", name, None)
            return None
        if name == "self":
            return ("s", cls.key) if cls else None
        if name == "super":
            if cls and cls.parent:
                return cls.parent
            return None
        if scope is not None:
            found, t = scope.lookup(name)
            if found:
                return t if t is not None else self.field_types.get(name)
        if cls is not None:
            for c in self.script_chain(cls.key):
                if name in c.vars:
                    return self.var_type(c, name)
                if name in c.signals:
                    return ("b", "Signal", None)
                if name in c.enums:
                    return ("b", "Dictionary", None)
                if name in c.consts:
                    t = self._const_class(c, name)
                    if t:
                        return t
                    return self.type_named(c.consts[name][0], c) or self.infer(c.consts[name][1], c, None)
            for _n, e in self.engine_chain(self.engine_base(cls.key)):
                if name in e["members"]:
                    return self.norm(e["members"][name])
        t = self._first_static(name, cls)
        if t is not None:
            return t
        if name in self.singletons:
            return ("e", self.singletons[name])
        return None


_AS_TAIL = re.compile(r"\bas[ \t]+(" + _TYPE + r")[ \t]*\Z")
_RES_ARG = re.compile(r'[ \t]*"(res://[^"]+)"[ \t]*\Z')
_NAME_ARG = re.compile(r'[ \t]*&?"(\w+)"[ \t]*(?:,|\Z)')
# Later (src/later.gd) hands out a feature's script, or a new one of it, by
# its class name: `Later.script(&"PartEditor").make_dat(...)` is PartEditor's.
LATER = {"script": "S", "script_in_background": "S", "make": "s"}
UNKNOWN = ("u", None)       # of a type this check cannot follow: guess nothing for it


def scan_back(s: str, end: int):
    """The receiver ending just before s[end]: (head, segments, start index), or None.

    head is ("id",) when the receiver starts with a name, ("node",) for $Path
    or %Name, ("as", Type) for `(x as Type)`, ("lit", type) for a literal.
    Each segment is (name, called, indexed, the call's arguments or None), leftmost first."""
    segs = []
    j = end - 1
    while True:
        while j >= 0 and s[j] in " \t":
            j -= 1
        if j < 0:
            return None
        c = s[j]
        call = index = False
        args = None
        if c == ")":
            k = _open_back(s, j, "(", ")")
            if k < 0:
                return None
            e = k - 1
            if e >= 0 and (s[e].isalnum() or s[e] == "_"):
                call = True
                args = s[k + 1:j]
                j = e
            else:
                m = _AS_TAIL.search(s, k + 1, j)
                segs.reverse()
                return (("as", m.group(1)) if m else ("expr",)), segs, k
        elif c == "]":
            k = _open_back(s, j, "[", "]")
            if k < 0:
                return None
            e = k - 1
            while e >= 0 and s[e] in " \t":
                e -= 1
            if e >= 0 and (s[e].isalnum() or s[e] == "_" or s[e] in ")]"):
                if s[e] in ")]":
                    return None
                index = True
                j = e
            else:
                segs.reverse()
                return ("lit", "Array"), segs, k
        elif c == '"' or c == "'":
            k = s.rfind(c, 0, j)
            if k < 0:
                return None
            if k > 0 and s[k - 1] in "$%^&":
                segs.reverse()
                return (("node",) if s[k - 1] in "$%" else ("lit", "StringName" if s[k - 1] == "&" else "NodePath")), segs, k - 1
            segs.reverse()
            return ("lit", "String"), segs, k
        elif c == "}":
            k = _open_back(s, j, "{", "}")
            segs.reverse()
            return (("lit", "Dictionary"), segs, k) if k >= 0 else None
        if not (s[j].isalnum() or s[j] == "_"):
            return None
        e = j
        while j >= 0 and (s[j].isalnum() or s[j] == "_"):
            j -= 1
        name = s[j + 1:e + 1]
        if name[0].isdigit():
            return None
        segs.append((name, call, index, args))
        # $Path/To/Node or %Unique, written against the name
        if j >= 0 and s[j] in "$%/":
            k = j
            while k >= 0 and (s[k].isalnum() or s[k] in "_/"):
                k -= 1
            if k >= 0 and s[k] in "$%" and (s[j] != "/" or k < j):
                segs.pop()
                segs.reverse()
                return ("node",), segs, k
            if s[j] == "/":
                return None
        k = j
        while k >= 0 and s[k] in " \t":
            k -= 1
        if k >= 0 and s[k] == "." and not (k > 0 and s[k - 1] == "."):
            j = k - 1
            continue
        segs.reverse()
        return ("id",), segs, j + 1


def _open_back(s: str, j: int, open_c: str, close_c: str) -> int:
    depth = 0
    while j >= 0:
        c = s[j]
        if c == close_c:
            depth += 1
        elif c == open_c:
            depth -= 1
            if depth == 0:
                return j
        j -= 1
    return -1


# --------------------------------------------------------------------------
# Checking a script, line by line.


class Scope:
    """A function's locals, by the indentation they were declared at."""

    __slots__ = ("entries",)

    def __init__(self):
        self.entries: list[tuple[int, str, tuple | None]] = []

    def drop_deeper(self, indent: int) -> None:
        e = self.entries
        while e and e[-1][0] > indent:
            e.pop()

    def add(self, indent: int, name: str, t: tuple | None) -> None:
        self.entries.append((indent, name, t))

    def lookup(self, name: str) -> tuple[bool, tuple | None]:
        for _i, n, t in reversed(self.entries):
            if n == name:
                return True, t
        return False, None

    def names(self) -> set:
        return {n for _i, n, _t in self.entries}


_CALL = re.compile(r"(\.)?[ \t]*([A-Za-z_]\w*)[ \t]*\(")
_LOCAL_VAR = re.compile(r"(?:@\w+[ \t]+)*(?:var|const)[ \t]+(\w+)[ \t]*(?::[ \t]*(" + _TYPE + r"))?[ \t]*(:?=)?[ \t]*(.*)")
_FOR = re.compile(r"for[ \t]+(\w+)[ \t]*(?::[ \t]*(" + _TYPE + r"))?[ \t]+in[ \t]+")


def _header_colon(text: str) -> int:
    """Where a block header's own colon is (not one inside brackets), or the end."""
    depth = 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == ":" and depth == 0:
            return i
    return len(text)
_LAMBDA = re.compile(r"\bfunc[ \t]*(?:\w+[ \t]*)?\(([^()]*(?:\([^()]*\)[^()]*)*)\)")
_REF = re.compile(r"[A-Za-z_]\w*(?:[ \t]*\.[ \t]*[A-Za-z_]\w*)*\Z")
_STR_ARG = re.compile(r'[ \t]*[&]?"(\w+)"[ \t]*\Z')
_FUNC_HEAD = re.compile(r"(?:@\w+(?:\([^)]*\))?[ \t]+)*(?:static[ \t]+)?func[ \t]+\w")
_CLASS_HEAD = re.compile(r"class[ \t]+\w")


@dataclass
class Finding:
    path: str
    line: int
    what: str
    why: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.what}: {self.why}"


def check_script(ix: Index, path: str, res: str, text: str, marks: dict[int, str],
                 funcs_by_line: dict[int, tuple], class_lines: dict[int, str]) -> tuple[list[Finding], int]:
    findings: list[Finding] = []
    top = ix.classes[res]
    cstack: list[tuple[int, Cls]] = [(-1, top)]
    func_indent = -1
    func_static = False
    scope: Scope | None = None
    pending_mark: int | None = None
    depth = 0
    cont_next = False
    calls = 0
    line_marks: dict[int, int] = {}      # code line -> mark line

    def report(line: int, what: str, why: str) -> None:
        findings.append(Finding(path, line, what, why))

    for lineno, raw in enumerate(text.split("\n"), 1):
        s = raw.lstrip(" \t")
        if lineno in marks:
            if s:
                line_marks[lineno] = lineno
            else:
                pending_mark = lineno
        if not s:
            continue
        if pending_mark is not None:
            line_marks.setdefault(lineno, pending_mark)
            pending_mark = None
        d = len(raw) - len(s)
        # A line inside brackets left open (or after a \) goes on a statement
        # above: its indentation says nothing of where a block ends.
        cont = depth > 0 or cont_next
        opened = s.count("(") + s.count("[") + s.count("{")
        if opened or depth:
            depth += opened - s.count(")") - s.count("]") - s.count("}")
            if depth < 0:
                depth = 0
        cont_next = s.endswith("\\")
        if not cont:
            if scope is not None and d <= func_indent:
                scope = None
                func_indent = -1
            while cstack[-1][0] >= d:
                cstack.pop()
        cls = cstack[-1][1]
        if not cont and lineno in class_lines and _CLASS_HEAD.match(s):
            cstack.append((d, ix.classes[class_lines[lineno]]))
            continue
        head_func = not cont and lineno in funcs_by_line and _FUNC_HEAD.match(s)
        if head_func:
            _name, params, _key, func_static = funcs_by_line[lineno]
            scope = Scope()
            func_indent = d
            for pname, ptype, pdefault in params:
                scope.add(d + 1, pname, ix.declared(ptype, pdefault, pdefault is not None, cls, None))
        elif scope is not None:
            if not cont:
                scope.drop_deeper(d)
            c0 = s[0]
            if c0 in "vc@" and (s.startswith(("var ", "const ", "@"))):
                vm = _LOCAL_VAR.match(s)
                if vm:
                    scope.add(d, vm.group(1), ix.declared(vm.group(2), vm.group(4), bool(vm.group(3)), cls, scope))
            elif c0 == "f" and s.startswith("for "):
                fm = _FOR.match(s)
                if fm:
                    if fm.group(2):
                        t = ix.type_named(fm.group(2), cls)
                    else:
                        rest = s[fm.end():]
                        it = ix.infer(rest[:_header_colon(rest)], cls, scope)
                        t = it[2] if it and it[0] == "b" and it[1] == "Array" and len(it) > 2 else None
                        if it and it[0] == "d":
                            t = it
                    scope.add(d + 1, fm.group(1), t)
        if "(" not in s:
            continue
        if "func" in s:
            for lm in _LAMBDA.finditer(s):
                if head_func and lm.start() == s.find("func"):
                    continue
                if scope is None:
                    # a lambda at class level: its parameters are this line's
                    scope = Scope()
                    func_indent = d
                for pname, ptype, _pd in parse_params(lm.group(1)):
                    scope.add(d + 1, pname, ix.declared(ptype, None, False, cls, scope))
        for m in _CALL.finditer(s):
            name = m.group(2)
            start = m.start()
            calls += 1
            if m.group(1):
                got = scan_back(s, start)
                if got is None:
                    # a receiver this check cannot read: of no known class
                    head, segs, t, recv = ("expr",), [], None, "…"
                else:
                    head, segs, st = got
                    t = ix.resolve_chain(head, segs, cls, scope)
                    recv = s[st:start].strip()
                if not ix.has(t, name):
                    report(lineno, f"{recv}.{name}()", _why(ix, t, name))
                elif name in REF_CALLS and segs and not segs[-1][1] and not segs[-1][2] and head[0] == "id":
                    # X.NAME.bind(...): NAME is a method of X's class
                    if len(segs) == 1:
                        _bare_ref(ix, segs[0][0], cls, scope, lineno, report)
                    else:
                        base = ix.resolve_chain(head, segs, cls, scope, upto=len(segs) - 1)
                        if not ix.has(base, segs[-1][0], refs=True):
                            report(lineno, f"{recv}.{name}()", _why(ix, base, segs[-1][0], refs=True))
                recv_t, recv_text = t, recv
            else:
                before = s[:start].rstrip()
                if before.endswith(("func", "signal", "@")) or name in KEYWORDS:
                    continue
                if name in STRING_CALLS or name in CONNECTS or name in CALLBACKS or name == "Callable":
                    recv_t, recv_text = (("s", cls.key), "self")
                else:
                    recv_t, recv_text = None, ""
                if not _bare_ok(ix, name, cls, scope):
                    report(lineno, f"{name}()", f"no {name} in {ix.describe(('s', cls.key))} or anything it extends")
                    continue
            # The arguments, where they name a method.
            if name in STRING_CALLS or name in CONNECTS or name in CALLBACKS or name == "Callable" \
                    or name in ("call_group", "call_group_flags"):
                close = _close(s, m.end() - 1)
                args = split_args(s[m.end():close if close > 0 else len(s)])
                if name in STRING_CALLS:
                    at = STRING_CALLS[name]
                    # A Callable's call() is handed its arguments, not a method name.
                    if len(args) > at and not (recv_t and recv_t[0] == "b"):
                        sm = _STR_ARG.match(args[at])
                        if sm and not ix.has(recv_t, sm.group(1)):
                            report(lineno, f'{recv_text + "." if recv_text else ""}{name}("{sm.group(1)}")',
                                   _why(ix, recv_t, sm.group(1)))
                elif name in ("call_group", "call_group_flags"):
                    at = 1 if name == "call_group" else 2
                    if len(args) > at:
                        sm = _STR_ARG.match(args[at])
                        if sm and not ix.has(None, sm.group(1)):
                            report(lineno, f'{name}(…, "{sm.group(1)}")', _why(ix, None, sm.group(1)))
                elif name == "Callable" and not m.group(1):
                    if len(args) == 2:
                        sm = _STR_ARG.match(args[1])
                        if sm:
                            ot = _arg_type(ix, args[0], cls, scope)
                            if ot is not False and not ix.has(ot, sm.group(1)):
                                report(lineno, f'Callable({args[0].strip()}, "{sm.group(1)}")', _why(ix, ot, sm.group(1)))
                else:
                    at = CALLBACKS.get(name, 0)
                    if name in CONNECTS and args and _STR_ARG.match(args[0]):
                        at = 1
                    if len(args) > at:
                        _value_ref(ix, args[at].strip(), cls, scope, lineno, report, f"{name}(")
    used = set()
    for f in findings:
        if f.line in line_marks:
            used.add(f.line)
    kept = []
    for f in findings:
        if f.line in line_marks and marks[line_marks[f.line]] and not marks[line_marks[f.line]].startswith("\0"):
            continue
        kept.append(f)
    for code_line, mark_line in sorted(line_marks.items()):
        reason = marks[mark_line]
        if reason.startswith("\0"):
            kept.append(Finding(path, mark_line, "callcheck mark", f"not understood: {reason[1:]!r} (say `# callcheck: dynamic, why`)"))
        elif not reason:
            kept.append(Finding(path, mark_line, "callcheck: dynamic", "say why the call is dynamic after the mark"))
        elif code_line not in used:
            kept.append(Finding(path, mark_line, "callcheck: dynamic", "nothing on its line needs it: take the mark out"))
    return kept, calls


def _why(ix: Index, t: tuple | None, name: str, refs: bool = False) -> str:
    if t is None or t[0] == "u":
        return f"{name} is defined by no script, engine class or built-in type"
    what = "member" if refs else "method"
    if t[0] in ("s", "e"):
        return f"{ix.describe(t)} has no {what} {name}, nor does any class it extends or any derived from it"
    return f"{ix.describe(t)} has no {what} {name}"


def _bare_ok(ix: Index, name: str, cls: Cls, scope: Scope | None) -> bool:
    if not cls.resolved:
        return True
    if scope is not None and scope.lookup(name)[0]:
        return True
    if name in ix.functions or name in ix.builtins or name in ix.eclasses or name in ix.global_names:
        return True
    c: Cls | None = cls
    while c is not None:
        for cc in ix.script_chain(c.key):
            if name in cc.funcs or name in cc.inners or name in cc.vars or name in cc.consts:
                return True
        for _n, e in ix.engine_chain(ix.engine_base(c.key)):
            if name in e["methods"]:
                return True
        c = ix.classes.get(c.outer) if c.outer else None
    return False


def _bare_ref(ix: Index, name: str, cls: Cls, scope: Scope | None, lineno: int, report) -> None:
    """A method named alone as a value: in scope, or a member of the class or an outer one."""
    if not cls.resolved or name in KEYWORDS:
        return
    if scope is not None and scope.lookup(name)[0]:
        return
    if name in ix.functions or name in ix.global_names or name in ix.eclasses or name in ix.builtins \
            or name in ix.singletons:
        return
    c: Cls | None = cls
    while c is not None:
        if name in ix._reach_names(("s", c.key), True) or name in ix._reach_names(("S", c.key), True):
            return
        c = ix.classes.get(c.outer) if c.outer else None
    report(lineno, name, f"no {name} in {ix.describe(('s', cls.key))} or anything it extends")


def _value_ref(ix: Index, arg: str, cls: Cls, scope: Scope | None, lineno: int, report, where: str) -> None:
    """A method handed over as a value (connect, tween_callback): X.NAME or NAME."""
    if not _REF.match(arg):
        return
    parts = [p.strip() for p in arg.split(".")]
    if parts[0] in KEYWORDS and parts[0] not in ("self", "super"):
        return
    if len(parts) == 1:
        _bare_ref(ix, parts[0], cls, scope, lineno, report)
        return
    segs = [(p, False, False, None) for p in parts]
    base = ix.resolve_chain(("id",), segs[:-1], cls, scope)
    if not ix.has(base, parts[-1], refs=True):
        report(lineno, f"{where}{arg})", _why(ix, base, parts[-1], refs=True))


def _arg_type(ix: Index, arg: str, cls: Cls, scope: Scope | None):
    arg = arg.strip()
    got = scan_back(arg, len(arg))
    if got is None or got[2] != 0:
        return False
    return ix.resolve_chain(got[0], got[1], cls, scope)


# --------------------------------------------------------------------------
# The tree.


def scripts(root: Path) -> list[Path]:
    out = []
    for top in SCAN:
        base = root / top
        if not base.is_dir():
            continue
        for dirpath, dirnames, filenames in os.walk(base, followlinks=True):
            if ".gdignore" in filenames:
                dirnames[:] = []
                continue
            dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
            out.extend(Path(dirpath) / f for f in sorted(filenames) if f.endswith(".gd"))
    return out


_FILES: list = []
_INDEX: Index | None = None


def _read(arg):
    root, path = arg
    text = path.read_text(encoding="utf-8", errors="replace").removeprefix("﻿")
    rel = path.relative_to(root).as_posix()
    masked, marks = mask(text)
    classes, funcs_by_line = scan_decls(rel, "res://" + rel, masked)
    return rel, masked, marks, classes, funcs_by_line


def _check(i: int):
    rel, masked, marks, classes, funcs_by_line = _FILES[i]
    class_lines = {c.line: c.key for c in classes if c.outer}
    assert _INDEX is not None
    return check_script(_INDEX, rel, "res://" + rel, masked, marks, funcs_by_line, class_lines)


def run(root: Path, api: dict, jobs: int = 1) -> tuple[list[Finding], int, int]:
    """(findings, scripts read, calls read)"""
    global _FILES, _INDEX
    paths = scripts(root)
    work = [(root, p) for p in paths]
    jobs = max(1, min(jobs, len(paths) // 50 or 1))
    # Read in parallel, index once, then check in parallel: a forked worker
    # has the whole index without it being sent (about 9 s in one process,
    # 2 in eight, for 1,100 scripts).
    _FILES = _each(_read, work, jobs)
    classes = [c for f in _FILES for c in f[3]]
    _INDEX = Index(api, classes)
    results = _each(_check, range(len(_FILES)), jobs)
    findings = sorted((f for r in results for f in r[0]), key=lambda f: (f.path, f.line, f.what))
    return findings, len(paths), sum(r[1] for r in results)


def _each(fn, items, jobs: int) -> list:
    if jobs > 1:
        import multiprocessing as mp
        try:
            with mp.get_context("fork").Pool(jobs) as pool:
                return pool.map(fn, items, chunksize=16)
        except OSError:
            pass                # no processes to be had here: one will do
    return [fn(i) for i in items]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n", 1)[0])
    ap.add_argument("--root", type=Path, default=ROOT, help="the checkout (default: this one)")
    ap.add_argument("--jobs", type=int, default=0, help="processes (default: up to 8)")
    ap.add_argument("--api", type=Path, help="a reduced engine API (default: dumped from godot once)")
    args = ap.parse_args(argv)
    started = time.time()
    try:
        if args.api:
            with open(args.api, encoding="utf-8") as f:
                api = json.load(f)
        else:
            api = load_api()
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
        print(f"callcheck: cannot read the engine's classes: {exc}", file=sys.stderr)
        return 2
    jobs = args.jobs or min(8, len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else os.cpu_count() or 1)
    findings, n_scripts, n_calls = run(args.root.resolve(), api, jobs)
    for f in findings:
        print(f)
    took = time.time() - started
    if findings:
        print(f"callcheck: {len(findings)} call(s) to a method that is not there, in {n_scripts} scripts "
              f"({n_calls} calls, {took:.1f} s). Fix each, or mark a deliberate one on its line: "
              "# callcheck: dynamic, why")
        return 1
    print(f"callcheck: every call names a method that is there ({n_scripts} scripts, {n_calls} calls, {took:.1f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
