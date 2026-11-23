#!/usr/bin/env python3
"""Can a photo of a build in progress be read to its step, with the fault named? (photostep)

APP_UX11 past parity 3: a photo of the build so far, told "step 12 is done, but the 2 x 4
plate is one stud to the left". Measured first, as an MCP task on the owner's path: Claude
Code on the subscription (no API key), its only tools a small MCP server of this bench's
that hands it what a `check_step_photo` tool would: the photo, the steps around the one the
builder is on as the instructions draw them, and their parts.

The photos are RENDERS, not photographs: src/dev/photostep_bench.gd draws each build at
Best, Product look, from a hand-held angle that is never the booklet's, and `dress` lays it
on a table (a procedural wood desk, a white desk or a carpet, under the render's own
shadows) and makes it a phone's picture (white balance, vignette, lens softness and
fringes, sensor noise, over-sharpening, a JPEG).

    tools/bench/photostep.py dress DIR           the photos and the step pictures
    tools/bench/photostep.py read DIR [--jobs 3] [--only KEY,...] [--model M]
                                                 each case asked once; DIR/answers/<case>.json
    tools/bench/photostep.py score DIR           the numbers against the bar, the misses
    tools/bench/photostep.py mcp --dir DIR --case CASE
                                                 the bench's MCP server (stdio), one case

DIR is where the probe drew (--pictures=DIR): DIR/cases.json and DIR/raw/.
Each group (a set's page N) gives five cases: right, missing, moved (one stud), colour
(the wrong colour) and behind (step N-1 shown as N). The builder always says step N.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import os
import random
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent.parent
KINDS = ("right", "missing", "moved", "colour", "behind")
FAULTY = ("missing", "moved", "colour")
SIDES = ("front-left", "front-right", "back-left", "back-right", "top")
TABLES = ("oak desk", "grey carpet", "walnut desk", "white desk", "beige carpet")
SERVER = "photostep"
TIMEOUT = 900
# The bar (brief_photostep.md): step exact, fault found, fault named, false alarms.
BAR = {"step_exact": 0.80, "found": 0.75, "named": 0.60, "false_alarms": 0.10}

SCHEMA: dict = {
    "type": "object",
    "properties": {
        "step_shown": {"type": "integer",
                       "description": "the step the build in the photo has got to: the last step "
                                      "any of whose new parts are on"},
        "fault": {"type": "string", "enum": ["none", "missing", "moved", "wrong_colour", "extra", "other"],
                  "description": "the one mistake you are surest of in what is built, or none"},
        "part": {"type": "string", "description": "the faulty part's number as the step's parts list gives "
                                                  "it, or empty"},
        "part_name": {"type": "string"},
        "colour": {"type": "string", "description": "the colour the part should be, as listed"},
        "seen_colour": {"type": "string", "description": "for wrong_colour: the colour it is in the photo"},
        "moved_toward": {"type": "string", "enum": ["", "left", "right", "nearer", "farther", "up", "down"],
                         "description": "for moved: which way it is off, as seen in the photo"},
        "studs": {"type": "number", "description": "for moved: how far off, in studs"},
        "at_x": {"type": "number", "description": "where in the photo the faulty part is (or, missing, "
                                                  "should be): 0 the left edge, 1 the right"},
        "at_y": {"type": "number", "description": "0 the top edge, 1 the bottom"},
        "confidence": {"type": "integer", "minimum": 0, "maximum": 100},
        "says": {"type": "string", "description": "what you tell the builder, a sentence or two"},
    },
    "required": ["step_shown", "fault", "part", "part_name", "colour", "seen_colour", "moved_toward",
                 "studs", "at_x", "at_y", "confidence", "says"],
}


# -- the cases ------------------------------------------------------------------------


def groups(root: Path) -> list[dict]:
    return json.loads((root / "cases.json").read_text())["groups"]


def cases(root: Path) -> list[dict]:
    out = []
    for g in groups(root):
        for kind in KINDS:
            out.append({"id": f"{g['key']}_{kind}", "group": g, "kind": kind})
    return out


def opaque(case_id: str) -> str:
    """A name for a case's files that says nothing of its kind."""
    return hashlib.sha256(f"photostep:{case_id}".encode()).hexdigest()[:10]


# -- the table and the phone ----------------------------------------------------------


def _noise(u: np.ndarray, v: np.ndarray, scale: float, seed: int) -> np.ndarray:
    """Smooth value noise in -1..1 at [scale] LDU a cell, over floor coordinates."""
    import numpy as np
    rng = np.random.default_rng(seed)
    n = 257
    grid = rng.uniform(-1.0, 1.0, (n, n)).astype(np.float32)
    x = u / scale
    y = v / scale
    x0 = np.floor(x)
    y0 = np.floor(y)
    fx = (x - x0).astype(np.float32)
    fy = (y - y0).astype(np.float32)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    i0 = (x0.astype(np.int64)) % (n - 1)
    j0 = (y0.astype(np.int64)) % (n - 1)
    a = grid[j0, i0]
    b = grid[j0, i0 + 1]
    c = grid[j0 + 1, i0]
    d = grid[j0 + 1, i0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def _fbm(u, v, scale, seed, octaves=4):
    import numpy as np
    out = np.zeros_like(u, dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += amp * _noise(u, v, scale / (2 ** o), seed + o)
        total += amp
        amp *= 0.5
    return out / total


def table(kind: str, u: np.ndarray, v: np.ndarray, seed: int) -> np.ndarray:
    """A table's colour (sRGB 0-1) at floor coordinates u, v in LDU (an LDU is 0.4 mm)."""
    import numpy as np
    if kind in ("oak desk", "walnut desk"):
        base = np.array([0.66, 0.48, 0.31] if kind == "oak desk" else [0.40, 0.27, 0.18], np.float32)
        plank = np.floor(u / 300.0)
        jitter = _noise(plank * 37.0, plank * 11.0, 1.0, seed + 5)[..., None] * 0.06
        warp = _fbm(u * 0.2, v, 400.0, seed, 3) * 18.0
        rings = np.sin((u % 300.0 + warp) * 0.35 + _fbm(u, v * 0.05, 60.0, seed + 9, 2) * 6.0)
        grain = (0.5 + 0.5 * rings)[..., None] * 0.10
        fleck = _fbm(u * 4.0, v * 0.25, 30.0, seed + 3, 2)[..., None] * 0.04
        seam = (np.abs((u % 300.0) - 150.0) > 148.5)[..., None] * -0.18
        colour = base * (1.0 - grain + jitter + fleck + seam)
    elif kind == "white desk":
        base = np.array([0.86, 0.86, 0.84], np.float32)
        colour = base * (1.0 + _fbm(u, v, 200.0, seed, 3)[..., None] * 0.02)
    else:
        base = np.array([0.50, 0.50, 0.52] if kind == "grey carpet" else [0.70, 0.62, 0.50], np.float32)
        mottle = _fbm(u, v, 120.0, seed, 3)[..., None] * 0.08
        fibre = np.random.default_rng(seed + 1).normal(0, 0.09, u.shape + (1,)).astype(np.float32)
        tuft = _noise(u, v, 4.0, seed + 2)[..., None] * 0.10
        colour = base * (1.0 + mottle + fibre + tuft)
    return np.clip(colour, 0, 1)


def floor_coords(camera: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """For each pixel of the photo, where its ray meets the table (u, v in LDU), and whether it does."""
    import numpy as np
    w, h = camera["size"]
    o = np.array(camera["origin"], np.float64)
    bx, by, bz = (np.array(camera[k], np.float64) for k in ("x", "y", "z"))
    t = math.tan(math.radians(camera["fov"]) / 2)
    aspect = w / h
    xs = ((np.arange(w) + 0.5) / w * 2 - 1) * t * aspect
    ys = (1 - (np.arange(h) + 0.5) / h * 2) * t
    gx, gy = np.meshgrid(xs, ys)
    d = gx[..., None] * bx + gy[..., None] * by - bz
    floor = camera["floor_y"]
    dy = d[..., 1]
    hits = dy < -1e-4
    s = np.where(hits, (floor - o[1]) / np.where(hits, dy, -1), 0)
    u = o[0] + s * d[..., 0]
    v = o[2] + s * d[..., 2]
    return u.astype(np.float32), v.astype(np.float32), hits


def dress_one(raw: Path, mask: Path, camera: dict, table_kind: str, seed: int, out: Path) -> None:
    import numpy as np
    photo = np.asarray(Image.open(raw).convert("RGB"), np.float32) / 255.0
    alpha = np.asarray(Image.open(mask).convert("RGBA"), np.float32)[..., 3] / 255.0
    # The model wherever the mask is the model's; its own shadow is left on the floor
    # render, which the table takes over.
    # Its contact shadow comes as a faint alpha round it (under 0.2 but at the touch).
    model = np.clip((alpha - 0.3) / 0.6, 0, 1)
    model = np.asarray(Image.fromarray((model * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6)),
                       np.float32) / 255.0
    lum = photo @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    floor_px = model < 0.02
    ref = np.percentile(lum[floor_px], 92) if floor_px.any() else 0.6
    ref_rgb = np.median(photo[floor_px & (lum > ref * 0.95)], axis=0) if floor_px.any() else np.full(3, 0.6)
    u, v, hits = floor_coords(camera)
    tex = table(table_kind, u, v, seed)
    shade = photo / np.maximum(ref_rgb, 1e-3)
    floor_rgb = np.clip(tex * shade, 0, 1)
    floor_rgb[~hits] = tex[~hits].mean(axis=(0,)) if (~hits).any() else floor_rgb[~hits]
    m = model[..., None]
    img = photo * m + floor_rgb * (1 - m)
    rng = np.random.default_rng(seed)
    h, w = lum.shape
    # White balance and exposure: a room's warm light, or a window's cool one.
    warm = rng.uniform(0.03, 0.08) * (1 if seed % 4 else -0.6)
    img = img * np.array([1 + warm, 1.0, 1 - warm * 1.1], np.float32) * rng.uniform(0.92, 1.06)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r2 = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2
    img = img * (1 - 0.16 * r2 / 2)[..., None]
    img = np.clip(img, 0, 1)
    pic = Image.fromarray((img * 255).astype(np.uint8))
    # Fringes: red a hair larger than green, blue a hair smaller.
    r, g, b = pic.split()
    def scaled(ch: Image.Image, k: float) -> Image.Image:
        big = ch.resize((round(w * k), round(h * k)), Image.BICUBIC)
        left, top = (big.width - w) // 2, (big.height - h) // 2
        if k >= 1:
            return big.crop((left, top, left + w, top + h))
        canvas = ch.copy()
        canvas.paste(big, (-left, -top))
        return canvas
    pic = Image.merge("RGB", (scaled(r, 1.0015), g, scaled(b, 0.9985)))
    # A small lens and a hand that moves.
    pic = pic.filter(ImageFilter.GaussianBlur(0.9))
    arr = np.asarray(pic, np.float32) / 255.0
    lum = arr @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    sigma = (0.010 + 0.028 * (1 - lum))[..., None]
    blotch = np.asarray(Image.fromarray(((rng.normal(0, 1, (h // 2, w // 2, 3)) * 40 + 128).clip(0, 255))
                                        .astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 40 - 3.2
    fine = rng.normal(0, 1, (h, w, 1)).astype(np.float32)
    arr = arr + sigma * (0.7 * fine + 0.5 * blotch * np.array([1.0, 0.6, 1.2], np.float32))
    pic = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    pic = pic.filter(ImageFilter.UnsharpMask(radius=1.8, percent=70, threshold=2))
    out.parent.mkdir(parents=True, exist_ok=True)
    pic.save(out, "JPEG", quality=82, subsampling=2)


def outlined(before: Path, after: Path, out: Path) -> None:
    """[after] with what is new since [before] (from the same camera) ringed in magenta."""
    import numpy as np
    a = Image.open(before).convert("RGB")
    b = Image.open(after).convert("RGB")
    diff = np.asarray(ImageChops.difference(a, b), np.int32).sum(axis=2)
    # A new part's shadow on the white sweep is a change too, and not a part: the sweep
    # before (light and grey) gone a grey shade after.
    pa, pb = np.asarray(a, np.int32), np.asarray(b, np.int32)
    grey = lambda p: (p.max(axis=2) - p.min(axis=2)) < 14
    shadow = grey(pa) & (pa.mean(axis=2) > 215) & grey(pb) & (pb.mean(axis=2) > 110)
    changed = Image.fromarray((((diff > 40) & ~shadow) * 255).astype(np.uint8))
    changed = changed.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(11))
    ring = ImageChops.subtract(changed.filter(ImageFilter.MaxFilter(5)), changed)
    shown = b.copy()
    shown.paste((235, 0, 200), mask=ring)
    out.parent.mkdir(parents=True, exist_ok=True)
    shown.save(out, "PNG")


def dress(root: Path) -> int:
    made = 0
    for n, g in enumerate(groups(root)):
        raw = root / "raw" / g["key"]
        if (root / "refs" / g["key"] / ".dressed").exists():
            continue
        kind_of_table = TABLES[n % len(TABLES)]
        g_seed = int(hashlib.sha256(g["key"].encode()).hexdigest()[:6], 16)
        for kind in KINDS:
            src, mask = raw / f"photo_{kind}.png", raw / f"mask_{kind}.png"
            if not src.exists():
                print(f"  {g['key']} {kind}: not drawn")
                continue
            dress_one(src, mask, g["camera"], kind_of_table, g_seed, root / "photos" / f"{opaque(g['key'] + '_' + kind)}.jpg")
            made += 1
        refs = root / "refs" / g["key"]
        refs.mkdir(parents=True, exist_ok=True)
        for side in SIDES:
            for step in (g["before"], g["step"], g["after"]):
                src = raw / f"ref_{step}_{side}.png"
                if src.exists():
                    Image.open(src).convert("RGB").save(refs / f"{step}_{side}.png")
            for older, newer in ((g["before"], g["step"]), (g["step"], g["after"])):
                a, b = raw / f"ref_{older}_{side}.png", raw / f"ref_{newer}_{side}.png"
                if a.exists() and b.exists():
                    outlined(a, b, refs / f"{newer}_{side}_new.png")
        (refs / ".dressed").touch()
        print(f"  {g['key']}: {g['name']} step {g['step']} on a {kind_of_table}")
    print(f"photostep: {made} photos in {root / 'photos'}")
    return 0


# -- the MCP server: what check_step_photo hands the session ------------------------------


def _parts_words(lots: list[dict]) -> str:
    return "; ".join(f"{l['count']} x {l['name']} ({l['part']}), {l['colour_name']}" for l in lots) or "nothing"


GUIDE = (
    "How to check a step from a photo: (1) Find which side the photo was taken from, and look at "
    "the step pictures from that side (step_picture, from= the corner that matches). (2) The step: "
    "if none of step {n}'s new parts are on and step {b}'s are, the photo shows step {b}; if step "
    "{a}'s parts are on too, step {a}. (3) Then each part step {n} adds, one at a time: is it there; "
    "is it on the same studs as in the step picture (count studs from an edge or a neighbouring "
    "part, never judge by eye alone); is it the listed colour. A phone's light shifts colours: dark "
    "grey can read as black, white as light grey, so compare with parts of known colour in the same "
    "photo. (4) Name the one fault you are surest of, by its part number from the list, its colour "
    "and where it is in the photo; say none when every part is where the step puts it. Parts "
    "built in earlier steps that the photo hides cannot be checked: do not guess at them.")


def tool_list() -> list[dict]:
    sides = list(SIDES)
    return [
        {"name": "check_step_photo",
         "description": "The builder's photo of their build, taken in Build mode on the step they are "
                        "on, with that step, the one before and the one after as the instructions draw "
                        "them, each step's new parts outlined, and the parts each step adds. Call it "
                        "first to check a step from a photo.",
         "inputSchema": {"type": "object", "properties": {}}},
        {"name": "step_picture",
         "description": "A step of the instructions drawn from one side: the build as it is when that "
                        "step is done. The model's front is the side its booklet faces. new=true "
                        "rings the parts the step adds in magenta.",
         "inputSchema": {"type": "object", "properties": {
             "step": {"type": "integer"},
             "from": {"type": "string", "enum": sides},
             "new": {"type": "boolean"}}, "required": ["step", "from"]}},
    ]


def _image(path: Path) -> dict:
    data = path.read_bytes()
    kind = "image/jpeg" if path.suffix.lower() in (".jpg", ".jpeg") else "image/png"
    return {"type": "image", "data": base64.b64encode(data).decode(), "mimeType": kind}


def _small(path: Path) -> Path:
    """A step picture as a JPEG, as the app would send one."""
    out = path.with_suffix(".jpg")
    if not out.exists():
        Image.open(path).convert("RGB").save(out, "JPEG", quality=88)
    return out


def tool_call(root: Path, case: dict, name: str, args: dict) -> list[dict]:
    g = case["group"]
    n, b, a = g["step"], g["before"], g["after"]
    refs = root / "refs" / g["key"]
    lots = g["lots"]
    if name == "check_step_photo":
        photo = root / "photos" / f"{opaque(case['id'])}.jpg"
        return [
            {"type": "text", "text": f"{g['name']} ({g['set']}), the builder is on step {n} of "
                                     f"{g['steps']}. Their photo, real bricks on their table, taken "
                                     "from wherever they stood:"},
            _image(photo),
            {"type": "text", "text": f"Step {n} as the instructions draw it, from the front-right; "
                                     "its new parts ringed in magenta:"},
            _image(_small(refs / f"{n}_front-right_new.png")),
            {"type": "text", "text": f"Step {b} (the step before), from the same side:"},
            _image(_small(refs / f"{b}_front-right.png")),
            {"type": "text", "text": f"Step {a} (the step after), its new parts ringed:"},
            _image(_small(refs / f"{a}_front-right_new.png")),
            {"type": "text", "text": f"Step {b} adds: {_parts_words(lots.get(str(b), []))}.\n"
                                     f"Step {n} adds: {_parts_words(lots.get(str(n), []))}.\n"
                                     f"Step {a} adds: {_parts_words(lots.get(str(a), []))}.\n"
                                     f"Each of steps {b}, {n} and {a} from another side: step_picture "
                                     f"(from= {', '.join(SIDES)}; new=true rings its new parts).\n\n"
                                     + GUIDE.format(n=n, b=b, a=a)},
        ]
    if name == "step_picture":
        step = int(args.get("step", n))
        side = str(args.get("from", "front-right"))
        if step not in (b, n, a) or side not in SIDES:
            return [{"type": "text", "text": f"Only steps {b}, {n} and {a}, from {', '.join(SIDES)}."}]
        file = refs / (f"{step}_{side}_new.png" if args.get("new") and step != b else f"{step}_{side}.png")
        return [{"type": "text", "text": f"Step {step} from the {side}" + (", its new parts ringed:" if
                                                                           "_new" in file.name else ":")},
                _image(_small(file))]
    return [{"type": "text", "text": f"No tool {name}."}]


def serve(root: Path, case_id: str) -> int:
    case = next(c for c in cases(root) if c["id"] == case_id)
    log = root / "answers" / f"{case_id}.tools.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        msg = json.loads(line)
        method, mid = msg.get("method"), msg.get("id")
        if mid is None:
            continue
        if method == "initialize":
            result = {"protocolVersion": msg.get("params", {}).get("protocolVersion", "2025-06-18"),
                      "capabilities": {"tools": {}}, "serverInfo": {"name": SERVER, "version": "1"}}
        elif method == "tools/list":
            result = {"tools": tool_list()}
        elif method == "tools/call":
            p = msg.get("params", {})
            with log.open("a") as f:
                f.write(json.dumps({"t": time.time(), "tool": p.get("name"), "args": p.get("arguments", {})}) + "\n")
            result = {"content": tool_call(root, case, p.get("name", ""), p.get("arguments") or {})}
        elif method == "ping":
            result = {}
        else:
            sys.stdout.write(json.dumps({"jsonrpc": "2.0", "id": mid,
                                         "error": {"code": -32601, "message": method}}) + "\n")
            sys.stdout.flush()
            continue
        sys.stdout.write(json.dumps({"jsonrpc": "2.0", "id": mid, "result": result}) + "\n")
        sys.stdout.flush()
    return 0


# -- the reading -----------------------------------------------------------------------


def ask_words(g: dict) -> str:
    return (f"I'm building {g['name']} ({g['set']}) from its instructions in Brickworks and I'm on "
            f"step {g['step']} of {g['steps']}. I took a photo of my build in Build mode. Did I do "
            f"step {g['step']} right? If something's wrong, tell me which part and where.")


def read_one(root: Path, case: dict, model: str | None) -> dict:
    out = root / "answers" / f"{case['id']}.json"
    if out.exists():
        return json.loads(out.read_text())
    out.parent.mkdir(parents=True, exist_ok=True)
    stream = root / "answers" / f"{case['id']}.stream.jsonl"
    tools_log = root / "answers" / f"{case['id']}.tools.jsonl"
    tools_log.unlink(missing_ok=True)
    config = root / "answers" / f"{case['id']}.mcp.json"
    config.write_text(json.dumps({"mcpServers": {SERVER: {
        "type": "stdio", "command": sys.executable,
        "args": [str(Path(__file__).resolve()), "mcp", "--dir", str(root), "--case", case["id"]]}}}))
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    command = ["timeout", "--kill-after=30", str(TIMEOUT), "claude", "-p", ask_words(case["group"]),
               "--mcp-config", str(config), "--strict-mcp-config", "--tools", "", "--restricted",
               "--allowedTools", f"mcp__{SERVER}", "--no-session-persistence",
               "--output-format", "stream-json", "--verbose", "--json-schema", json.dumps(SCHEMA)]
    if model:
        command += ["--model", model]
    started = time.time()
    with stream.open("w") as said:
        code = subprocess.run(command, cwd=root, env=env, stdout=said, stderr=subprocess.STDOUT,
                              stdin=subprocess.DEVNULL).returncode
    took = time.time() - started
    answer, model_used, result_text = None, "", ""
    for line in stream.read_text().splitlines():
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        if msg.get("type") == "system" and msg.get("subtype") == "init":
            model_used = msg.get("model", "")
        if msg.get("type") == "result":
            answer = msg.get("structured_output")
            result_text = str(msg.get("result", ""))
    poisoned = bool(re.search(r"hit your (5-hour|session) limit|OAuth session expired|Login expired",
                              stream.read_text()))
    calls = [json.loads(l) for l in tools_log.read_text().splitlines()] if tools_log.exists() else []
    record = {"case": case["id"], "kind": case["kind"], "answer": answer, "seconds": round(took, 1),
              "exit": code, "model": model_used, "tool_calls": calls, "result": result_text[:2000]}
    if answer is None or poisoned:
        record["poisoned"] = poisoned
        print(f"  {case['id']}: no answer (exit {code}{', limit or login' if poisoned else ''})")
        out.with_suffix(".failed.json").write_text(json.dumps(record, indent=1))
        return record
    out.write_text(json.dumps(record, indent=1))
    print(f"  {case['id']}: step {answer.get('step_shown')}, {answer.get('fault')} "
          f"{answer.get('part')} in {took:.0f} s")
    return record


def read(root: Path, jobs: int, only: list[str], model: str | None) -> int:
    # Only pages dressed whole: the dresser may be at work on the next.
    todo = [c for c in cases(root) if (not only or any(c["id"].startswith(o) for o in only))
            and (root / "refs" / c["group"]["key"] / ".dressed").exists()]
    random.Random(11).shuffle(todo)
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        list(pool.map(lambda c: read_one(root, c, model), todo))
    return 0


# -- the score -------------------------------------------------------------------------


def _norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", str(text).lower().replace(".dat", ""))


def _part_right(answer: dict, fault: dict) -> bool:
    said = _norm(answer.get("part", ""))
    if said and said == _norm(fault["part"]):
        return True
    return bool(answer.get("part_name")) and _norm(answer["part_name"]) == _norm(fault["part_name"])


def _place_right(answer: dict, fault: dict, grow: float = 0.06) -> bool:
    try:
        x, y = float(answer.get("at_x")), float(answer.get("at_y"))
    except (TypeError, ValueError):
        return False
    boxes = [fault["box"]] + ([fault["box_after"]] if "box_after" in fault else [])
    return any(b[0] - grow <= x <= b[2] + grow and b[1] - grow <= y <= b[3] + grow for b in boxes)


def judge(case: dict, answer: dict) -> dict:
    g, kind = case["group"], case["kind"]
    want_step = g["before"] if kind == "behind" else g["step"]
    said_step = int(answer.get("step_shown", -999))
    fault_said = answer.get("fault", "none")
    out = {"step_exact": said_step == want_step, "step_within": abs(said_step - want_step) <= 1,
           "said_step": said_step, "want_step": want_step}
    if kind in FAULTY:
        truth = g["faults"][kind]
        want_kind = {"missing": "missing", "moved": "moved", "colour": "wrong_colour"}[kind]
        out["found"] = fault_said != "none"
        out["kind_right"] = fault_said == want_kind
        out["part_right"] = _part_right(answer, truth)
        out["place_right"] = _place_right(answer, truth)
        way_right = True
        if kind == "moved":
            way_right = answer.get("moved_toward", "") in truth.get("toward", [])
            out["way_right"] = way_right
        out["named"] = out["kind_right"] and out["part_right"] and out["place_right"] and way_right
        out["changed"] = truth.get("changed", 0.0)
    else:
        # A step behind, "missing" a part step N adds is true: that part is not on yet. So it
        # is not a false alarm (the step read is still wrong unless it said N-1); any other
        # fault is. The strict count (any fault at all) is kept beside it.
        out["false_alarm_strict"] = fault_said != "none"
        not_yet = {_norm(l["part"]) for l in g["lots"].get(str(g["step"]), [])}
        out["false_alarm"] = fault_said != "none" and not (
            kind == "behind" and fault_said == "missing" and _norm(answer.get("part", "")) in not_yet)
    return out


def score(root: Path) -> int:
    rows = []
    for case in cases(root):
        f = root / "answers" / f"{case['id']}.json"
        if not f.exists():
            continue
        rec = json.loads(f.read_text())
        rows.append((case, rec, judge(case, rec["answer"])))
    if not rows:
        print("no answers")
        return 1
    def share(xs):
        xs = list(xs)
        return (sum(xs) / len(xs), sum(xs), len(xs)) if xs else (0.0, 0, 0)
    exact = share(j["step_exact"] for _, _, j in rows)
    within = share(j["step_within"] for _, _, j in rows)
    always_n = share(c["kind"] != "behind" for c, _, _ in rows)
    faulty = [r for r in rows if r[0]["kind"] in FAULTY]
    found = share(j["found"] for _, _, j in faulty)
    named = share(j["named"] for _, _, j in faulty)
    fine = [r for r in rows if r[0]["kind"] not in FAULTY]
    alarms = share(j["false_alarm"] for _, _, j in fine)
    strict = share(j["false_alarm_strict"] for _, _, j in fine)
    secs = sorted(rec["seconds"] for _, rec, _ in rows)
    lines = [f"# photostep: {len(rows)} cases read ({len({c['group']['key'] for c, _, _ in rows})} pages, "
             f"{len({c['group']['set'] for c, _, _ in rows})} sets)", "",
             "| measure | result | bar |", "|---|---|---|",
             f"| step exact | {exact[0]:.0%} ({exact[1]}/{exact[2]}) | {BAR['step_exact']:.0%} |",
             f"| step within one | {within[0]:.0%} ({within[1]}/{within[2]}) | |",
             f"| (always saying the builder's step) | {always_n[0]:.0%} | |",
             f"| fault found, of the faulty | {found[0]:.0%} ({found[1]}/{found[2]}) | {BAR['found']:.0%} |",
             f"| fault named right (kind, part, place) | {named[0]:.0%} ({named[1]}/{named[2]}) | {BAR['named']:.0%} |",
             f"| false alarms, of the right builds | {alarms[0]:.0%} ({alarms[1]}/{alarms[2]}) | {BAR['false_alarms']:.0%} or less |",
             f"| (any fault said on a right build, a step behind's not-yet-placed parts too) | {strict[0]:.0%} ({strict[1]}/{strict[2]}) | |",
             f"| time an answer | median {secs[len(secs) // 2]:.0f} s, longest {secs[-1]:.0f} s | |", ""]
    ok = (exact[0] >= BAR["step_exact"] and found[0] >= BAR["found"] and named[0] >= BAR["named"]
          and alarms[0] <= BAR["false_alarms"])
    lines.append(f"**{'GO' if ok else 'NO-GO'}** against the bar.\n")
    lines += ["## By kind", "", "| kind | cases | step exact | found | kind right | part right | place right | named | false alarm |",
              "|---|---|---|---|---|---|---|---|---|"]
    for kind in KINDS:
        rs = [j for c, _, j in rows if c["kind"] == kind]
        if not rs:
            continue
        cell = lambda key: f"{share(j[key] for j in rs)[0]:.0%}" if key in rs[0] else ""
        lines.append(f"| {kind} | {len(rs)} | {cell('step_exact')} | {cell('found')} | {cell('kind_right')} | "
                     f"{cell('part_right')} | {cell('place_right')} | {cell('named')} | {cell('false_alarm')} |")
    lines += ["", "## By set", "", "| set | cases | step exact | found | named | false alarms |", "|---|---|---|---|---|---|"]
    for number in dict.fromkeys(c["group"]["set"] for c, _, _ in rows):
        rs = [(c, j) for c, _, j in rows if c["group"]["set"] == number]
        fl = [j for c, j in rs if c["kind"] in FAULTY]
        ok_ = [j for c, j in rs if c["kind"] not in FAULTY]
        lines.append(f"| {number} {rs[0][0]['group']['name']} | {len(rs)} | {share(j['step_exact'] for _, j in rs)[0]:.0%} | "
                     f"{share(j['found'] for j in fl)[0]:.0%} | {share(j['named'] for j in fl)[0]:.0%} | "
                     f"{share(j['false_alarm'] for j in ok_)[0]:.0%} |")
    # The misses read: by how much of the picture the fault changes, and whether the
    # answer moved with the photo at all (the same fault and part said of the right build).
    bands = ((0.0, 0.001, "under 0.1%"), (0.001, 0.003, "0.1 to 0.3%"), (0.003, 0.01, "0.3 to 1%"),
             (0.01, 1.0, "1% or more"))
    lines += ["", "## By how much of the picture the fault changes", "",
              "| changed | faulty cases | found | named |", "|---|---|---|---|"]
    for low, high, words in bands:
        rs = [j for c, _, j in faulty if low <= j["changed"] < high]
        if rs:
            lines.append(f"| {words} | {len(rs)} | {share(j['found'] for j in rs)[0]:.0%} | "
                         f"{share(j['named'] for j in rs)[0]:.0%} |")
    said_right = {c["group"]["key"]: (rec["answer"].get("fault"), _norm(rec["answer"].get("part", "")))
                  for c, rec, _ in rows if c["kind"] == "right" and rec["answer"].get("fault") != "none"}
    same = [(c, rec) for c, rec, _ in faulty if c["group"]["key"] in said_right
            and (rec["answer"].get("fault"), _norm(rec["answer"].get("part", ""))) == said_right[c["group"]["key"]]]
    sharp = [j for c, _, j in faulty if c["group"]["key"] not in said_right]
    lines += ["", f"On {len(said_right)} of {len({c['group']['key'] for c, _, _ in rows})} pages the right "
              f"build itself drew a fault; {len(same)} faulty cases of those pages drew the very same fault "
              f"and part, so the answer did not follow the photo there. On the {len({c['group']['key'] for c, _, _ in rows}) - len(said_right)} "
              f"pages whose right build drew none: found {share(j['found'] for j in sharp)[0]:.0%}, "
              f"named {share(j['named'] for j in sharp)[0]:.0%} of {len(sharp)}."]
    lines += ["", "## Every case", "", "| case | truth | said | step | verdict | s |", "|---|---|---|---|---|---|"]
    for c, rec, j in sorted(rows, key=lambda r: r[0]["id"]):
        a = rec["answer"]
        g = c["group"]
        truth = "right" if c["kind"] == "right" else f"step {g['before']} (behind)" if c["kind"] == "behind" else \
            f"{c['kind']} {g['faults'][c['kind']]['part']} {g['faults'][c['kind']]['colour_name']}" + \
            (f" -> {g['faults']['colour']['colour_to_name']}" if c["kind"] == "colour" else "") + \
            (f" {'/'.join(g['faults']['moved']['toward'])}" if c["kind"] == "moved" else "") + \
            f" ({g['faults'][c['kind']]['changed']:.2%} of the picture)"
        said = f"{a.get('fault')} {a.get('part')} {a.get('colour')}" + \
            (f" {a.get('moved_toward')}" if a.get("fault") == "moved" else "") + \
            (f" seen {a.get('seen_colour')}" if a.get("fault") == "wrong_colour" else "") + \
            f" at {a.get('at_x', 0):.2f},{a.get('at_y', 0):.2f}"
        verdict = ("named" if j.get("named") else "found" if j.get("found") else "MISSED") if c["kind"] in FAULTY \
            else ("FALSE ALARM" if j["false_alarm"] else "ok")
        lines.append(f"| {c['id']} | {truth} | {said} | {j['said_step']}/{j['want_step']} | {verdict} | {rec['seconds']:.0f} |")
    report = "\n".join(lines) + "\n"
    (root / "score.md").write_text(report)
    (root / "score.json").write_text(json.dumps([{"case": c["id"], "kind": c["kind"], **j}
                                                  for c, _, j in rows], indent=1))
    print(report)
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("dress")
    d.add_argument("dir", type=Path)
    r = sub.add_parser("read")
    r.add_argument("dir", type=Path)
    r.add_argument("--jobs", type=int, default=3)
    r.add_argument("--only", default="")
    r.add_argument("--model", default=None)
    s = sub.add_parser("score")
    s.add_argument("dir", type=Path)
    m = sub.add_parser("mcp")
    m.add_argument("--dir", type=Path, required=True)
    m.add_argument("--case", required=True)
    a = p.parse_args()
    if a.cmd == "dress":
        return dress(a.dir.resolve())
    if a.cmd == "read":
        return read(a.dir.resolve(), a.jobs, [o for o in a.only.split(",") if o], a.model)
    if a.cmd == "score":
        return score(a.dir.resolve())
    return serve(a.dir.resolve(), a.case)


if __name__ == "__main__":
    sys.exit(main())
