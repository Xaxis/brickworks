#!/usr/bin/env python3
"""Renders of LEGO® bricks beside real photographs of them, and a blind judge (photoreal1).

The owner asked whether Brickworks draws LEGO bricks that look like real ones. This puts
each picture src/dev/photoreal_probe.gd drew (Best, Product look) beside the real
photograph it was framed on (tools/photoreal/shots.json), and asks Claude, on the
subscription through Claude Code with the Read tool and nothing else (judge.call), which
of the two is the photograph and why. Each pair is asked both ways round, under names
that say nothing, both pictures the same size and both written as the same JPEG, so
neither a file name, a size nor a compression gives one away.

The judge's pick rate is how often it finds the photograph: 1.0 is a render that never
passes, 0.5 is one it cannot tell from the real thing. Its "sure" is the chance it gave
the photograph, its confidence when right and one less it when wrong, averaged. Its
reasons, the things it names in the render that give it away, are the gap list.

    tools/bench/photoreal.py pairs TAG [--out DIR]
        each photograph beside its render, and all of them in one sheet
    tools/bench/photoreal.py compare BEFORE AFTER [--out DIR]
        photograph, before and after, side by side
    tools/bench/photoreal.py gloss TAG [--out DIR]
        each close-up's highlights and shading, photograph against render (photoreal3)
    tools/bench/photoreal.py judge TAG [--out DIR] [--model opus] [--jobs 4] [--only a,b]
        the blind judge, both orders; DIR/judge_TAG.json and a summary printed

TAG is the folder under shots/photoreal/ the probe drew into (-- --tag=TAG).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from bench import judge  # noqa: E402

SHOTS = ROOT / "tools" / "photoreal" / "shots.json"
DRAWN = ROOT / "shots" / "photoreal"
PROMPT_VERSION = 1

SCHEMA: dict = {
    "type": "object",
    "properties": {
        "looked_at": {"type": "array", "items": {"type": "string"},
                      "description": "the file name of every picture you opened"},
        "photograph": {"type": "string", "enum": ["A", "B"]},
        "confidence": {"type": "integer", "minimum": 50, "maximum": 100},
        "reason": {"type": "string"},
        "render_tells": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["looked_at", "photograph", "confidence", "reason", "render_tells"],
}


def shots(only: list[str] | None = None) -> list[dict]:
    found = json.loads(SHOTS.read_text())["shots"]
    return [s for s in found if not only or s["name"] in only]


def photo_of(shot: dict) -> Image.Image:
    """The photograph, cropped as the shot says and then to the render's shape, at its size."""
    image = Image.open(ROOT / shot["photo"]).convert("RGB")
    if "crop" in shot:
        left, top, right, bottom = shot["crop"]
        w, h = image.size
        image = image.crop((round(left * w), round(top * h), round(right * w), round(bottom * h)))
    want_w, want_h = shot["size"]
    w, h = image.size
    if w / h > want_w / want_h:
        cut = round(h * want_w / want_h)
        image = image.crop(((w - cut) // 2, 0, (w - cut) // 2 + cut, h))
    else:
        cut = round(w * want_h / want_w)
        image = image.crop((0, (h - cut) // 2, w, (h - cut) // 2 + cut))
    return image.resize((want_w, want_h), Image.LANCZOS)


def render_of(shot: dict, tag: str) -> Image.Image | None:
    path = DRAWN / tag / f"{shot['name']}.png"
    if not path.exists():
        return None
    image = Image.open(path).convert("RGB")
    return image if image.size == tuple(shot["size"]) else image.resize(tuple(shot["size"]))


def _side_by_side(images: list[tuple[str, Image.Image]], height: int = 360) -> Image.Image:
    scaled = [(words, im.resize((round(im.width * height / im.height), height), Image.LANCZOS))
              for words, im in images]
    out = Image.new("RGB", (sum(im.width for _, im in scaled) + 8 * (len(scaled) - 1), height + 22),
                    "white")
    draw = ImageDraw.Draw(out)
    x = 0
    for words, im in scaled:
        out.paste(im, (x, 22))
        draw.text((x + 4, 5), words, fill="black")
        x += im.width + 8
    return out


def _stack(rows: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGB", (max(r.width for r in rows), sum(r.height + 8 for r in rows)), "white")
    y = 0
    for row in rows:
        sheet.paste(row, (0, y))
        y += row.height + 8
    return sheet


def pairs(tag: str, out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot in shots():
        drawn = render_of(shot, tag)
        if drawn is None:
            print(f"  {shot['name']}: no render in {DRAWN / tag}")
            continue
        row = _side_by_side([(f"{shot['name']}: photograph", photo_of(shot)),
                             (f"render ({tag})", drawn)])
        row.save(out / f"{shot['name']}_{tag}.jpg", quality=90)
        rows.append(row)
    if rows:
        _stack(rows).save(out / f"all_{tag}.jpg", quality=88)
    print(f"  {len(rows)} pairs in {out}")
    return 0 if rows else 1


def compare(before: str, after: str, out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot in shots():
        a, b = render_of(shot, before), render_of(shot, after)
        if a is None or b is None:
            continue
        row = _side_by_side([(f"{shot['name']}: photograph", photo_of(shot)),
                             (f"before ({before})", a), (f"after ({after})", b)])
        row.save(out / f"{shot['name']}_before_after.jpg", quality=90)
        rows.append(row)
    if rows:
        _stack(rows).save(out / "all_before_after.jpg", quality=88)
    print(f"  {len(rows)} before-and-after rows in {out}")
    return 0 if rows else 1


def _lab(rgb: tuple[float, float, float]) -> tuple[float, float, float]:
    """CIELAB (D65) of an sRGB colour, 0 to 255 a channel."""
    def lin(c: float) -> float:
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))


def delta_e2000(one: tuple[float, float, float], two: tuple[float, float, float]) -> float:
    """CIEDE2000 between two CIELAB colours (Sharma, Wu and Dalal's formulae)."""
    from math import atan2, cos, degrees, exp, radians, sin, sqrt
    l1, a1, b1 = one
    l2, a2, b2 = two
    c_mean = (sqrt(a1 * a1 + b1 * b1) + sqrt(a2 * a2 + b2 * b2)) / 2
    g = 0.5 * (1 - sqrt(c_mean ** 7 / (c_mean ** 7 + 25 ** 7)))
    a1p, a2p = a1 * (1 + g), a2 * (1 + g)
    c1p, c2p = sqrt(a1p * a1p + b1 * b1), sqrt(a2p * a2p + b2 * b2)
    h1p = degrees(atan2(b1, a1p)) % 360 if c1p else 0.0
    h2p = degrees(atan2(b2, a2p)) % 360 if c2p else 0.0
    dl, dc = l2 - l1, c2p - c1p
    dh = 0.0
    if c1p * c2p:
        dh = h2p - h1p
        dh -= 360 if dh > 180 else 0
        dh += 360 if dh < -180 else 0
    dhh = 2 * sqrt(c1p * c2p) * sin(radians(dh / 2))
    lm, cm = (l1 + l2) / 2, (c1p + c2p) / 2
    hm = h1p + h2p
    if c1p * c2p:
        hm = (h1p + h2p) / 2 if abs(h1p - h2p) <= 180 else (
            (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2)
    t = (1 - 0.17 * cos(radians(hm - 30)) + 0.24 * cos(radians(2 * hm))
         + 0.32 * cos(radians(3 * hm + 6)) - 0.20 * cos(radians(4 * hm - 63)))
    sl = 1 + 0.015 * (lm - 50) ** 2 / sqrt(20 + (lm - 50) ** 2)
    sc = 1 + 0.045 * cm
    sh = 1 + 0.015 * cm * t
    rt = -2 * sqrt(cm ** 7 / (cm ** 7 + 25 ** 7)) * sin(radians(60 * exp(-((hm - 275) / 25) ** 2)))
    return sqrt((dl / sl) ** 2 + (dc / sc) ** 2 + (dhh / sh) ** 2 + rt * (dc / sc) * (dhh / sh))


def face_lab(image: Image.Image, box: list[float]) -> tuple[float, float, float]:
    """The mean CIELAB of a flat face: the box (fractions [left, top, right, bottom]) of the
    picture, its pixels' lightest and darkest fifths left out (a highlight, a seam, grain)."""
    w, h = image.size
    part = image.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))
    labs = sorted(_lab(p) for p in part.getdata())
    kept = labs[len(labs) // 5: len(labs) - len(labs) // 5] or labs
    return tuple(sum(v[k] for v in kept) / len(kept) for k in range(3))  # type: ignore[return-value]


def colour(tag: str, out: Path, drawn: Path) -> int:
    """Each close-up's flat lit faces measured in the photograph and the render (shots.json
    "faces"), mean CIELAB and the CIEDE2000 between them; out/colour_TAG.json and a table."""
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot in shots():
        path = drawn / tag / f"{shot['name']}.png"
        if not shot.get("faces") or not path.exists():
            continue
        photo = photo_of(shot)
        render = Image.open(path).convert("RGB").resize(tuple(shot["size"]))
        for face in shot["faces"]:
            p, r = face_lab(photo, face["photo"]), face_lab(render, face["render"])
            rows.append({"shot": shot["name"], "face": face["name"], "main": face.get("main", False),
                         "photo": [round(v, 1) for v in p], "render": [round(v, 1) for v in r],
                         "delta_e2000": round(delta_e2000(p, r), 2)})
    (out / f"colour_{tag}.json").write_text(json.dumps(rows, indent=1))
    print(f"| shot | face | photograph L*a*b* | render ({tag}) L*a*b* | ΔE2000 |")
    print("|---|---|---|---|---|")
    for row in rows:
        star = " (main)" if row["main"] else ""
        print(f"| {row['shot']} | {row['face']}{star} | {', '.join(f'{v:.1f}' for v in row['photo'])} "
              f"| {', '.join(f'{v:.1f}' for v in row['render'])} | {row['delta_e2000']:.1f} |")
    worst = max((row["delta_e2000"] for row in rows if row["main"]), default=0.0)
    print(f"worst main colour: ΔE2000 {worst:.1f}")
    return 0 if rows else 1


def _lightness(image: Image.Image, box: list[float]) -> list[float]:
    """Each pixel's CIELAB L* in the box (fractions [left, top, right, bottom]), sorted."""
    w, h = image.size
    part = image.crop((round(box[0] * w), round(box[1] * h), round(box[2] * w), round(box[3] * h)))
    return sorted(_lab(p)[0] for p in part.getdata())


def _at(values: list[float], share: float) -> float:
    return values[min(len(values) - 1, int(share * len(values)))]


def gloss(tag: str, out: Path, drawn: Path) -> int:
    """How glossy each close-up reads (photoreal3): in each box on a part's tops and studs
    (shots.json "gloss"), the highlight's share (pixels over the box's median L* by 15 or more)
    and its peak (the 99.5th percentile's L* over the median); and the shading across each main
    face (its L* from the 10th to the 90th percentile). Photograph against render, beside ΔE."""
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for shot in shots():
        path = drawn / tag / f"{shot['name']}.png"
        if shot.get("kind") != "closeup" or not path.exists():
            continue
        photo = photo_of(shot)
        render = Image.open(path).convert("RGB").resize(tuple(shot["size"]))
        for box in shot.get("gloss", []):
            row = {"shot": shot["name"], "box": box["name"], "what": "gloss"}
            for who, image in (("photo", photo), ("render", render)):
                values = _lightness(image, box["box"])
                middle = _at(values, 0.5)
                row[who] = {"median": round(middle, 1),
                            "share": round(sum(v >= middle + 15 for v in values) / len(values), 4),
                            "peak": round(_at(values, 0.995) - middle, 1)}
            rows.append(row)
        for face in shot.get("faces", []):
            if not face.get("main"):
                continue
            row = {"shot": shot["name"], "box": face["name"], "what": "spread"}
            for who, image, box in (("photo", photo, face["photo"]), ("render", render, face["render"])):
                values = _lightness(image, box)
                row[who] = {"spread": round(_at(values, 0.9) - _at(values, 0.1), 1)}
            rows.append(row)
    (out / f"gloss_{tag}.json").write_text(json.dumps(rows, indent=1))
    print(f"| shot | box | photograph | render ({tag}) |")
    print("|---|---|---|---|")
    for row in rows:
        if row["what"] == "gloss":
            p, r = row["photo"], row["render"]
            print(f"| {row['shot']} | {row['box']}: highlight share, peak | {p['share'] * 100:.1f}%, "
                  f"+{p['peak']:.0f} L* | {r['share'] * 100:.1f}%, +{r['peak']:.0f} L* |")
        else:
            print(f"| {row['shot']} | {row['box']}: L* spread | {row['photo']['spread']:.1f} "
                  f"| {row['render']['spread']:.1f} |")
    return 0 if rows else 1


def _opaque(words: str) -> str:
    return hashlib.sha256(f"photoreal:{words}".encode()).hexdigest()[:10]


def prompt(a: Path, b: Path) -> str:
    return "\n".join([
        "You are shown two pictures, A and B, of the same LEGO® bricks. One is a photograph "
        "of real LEGO bricks taken with a camera. The other is a computer render of a 3D model "
        "of the same bricks. Your job is to say which one is the photograph of the real bricks.",
        "",
        "Open both pictures with the Read tool before you answer.",
        f"  A: {a}",
        f"  B: {b}",
        "",
        "Look closely at the plastic and its gloss, the edges and corners, the studs, the "
        "light and the shadows, the background, the camera (focus, grain, lens) and anything "
        "else that tells a photograph from a render. The framing and the background may differ "
        "a little; judge what looks real. The order means nothing: you are shown the same two "
        "the other way round as well. You must choose one.",
        "",
        "Reply with only the JSON object the schema asks for: photograph (A or B), confidence "
        "(50 a pure guess, 100 certain), reason (one or two sentences naming what decides it), "
        "render_tells (short phrases, each one thing in the other picture that gives it away "
        "as computer generated), and looked_at (the file names you opened).",
    ])


def _ask(where: Path, first: Path, second: Path, real_is: str, model: str) -> dict:
    text = prompt(first, second)
    error = ""
    for _attempt in (1, 2):
        try:
            reply, seconds = judge.call(text, where, [where], model=model, schema=SCHEMA)
        except Exception as failed:  # noqa: BLE001
            error = str(failed)
            continue
        if reply.get("is_error"):
            error = str(reply.get("result"))[:200]
            continue
        found = reply.get("structured_output")
        if not isinstance(found, dict):
            try:
                found = judge._object(str(reply.get("result", "")))
            except ValueError as failed:
                error = str(failed)
                continue
        pick = str(found.get("photograph", "")).strip().upper()[:1]
        if pick not in ("A", "B"):
            error = f"no A or B: {found.get('photograph')!r}"
            continue
        confidence = max(50, min(100, int(found.get("confidence", 50))))
        right = pick == real_is
        return {"order": "photograph first" if real_is == "A" else "render first",
                "picked": pick, "right": right, "confidence": confidence,
                "sure": confidence / 100 if right else 1 - confidence / 100,
                "reason": " ".join(str(found.get("reason", "")).split()),
                "render_tells": [str(t) for t in found.get("render_tells", [])],
                "looked_at": found.get("looked_at", []), "seconds": round(seconds, 1),
                "model": ", ".join(sorted((reply.get("modelUsage") or {}).keys())) or model}
    return {"error": error}


def judge_tag(tag: str, out: Path, model: str, jobs: int, only: list[str] | None) -> int:
    out.mkdir(parents=True, exist_ok=True)
    # The judge's copies go beside its verdicts, never into the checkout it
    # runs in: a checkout's bench/ is not left out of the web export, and a
    # unit's preview packed photoreal1's first copies into the app. The
    # .gdignore keeps Godot from importing them when DIR is in a checkout.
    (out / "blind").mkdir(parents=True, exist_ok=True)
    (out / "blind" / ".gdignore").touch()
    blind = out / "blind" / _opaque(f"tag:{tag}")
    blind.mkdir(parents=True, exist_ok=True)
    asks = []
    for shot in shots(only):
        drawn = render_of(shot, tag)
        if drawn is None:
            print(f"  {shot['name']}: no render, left out")
            continue
        real = blind / f"{_opaque(tag + shot['name'] + 'p')}.jpg"
        fake = blind / f"{_opaque(tag + shot['name'] + 'r')}.jpg"
        photo_of(shot).save(real, quality=92)
        drawn.save(fake, quality=92)
        asks.append((shot, real, fake, "A"))
        asks.append((shot, fake, real, "B"))

    def run(item: tuple) -> tuple[dict, dict]:
        shot, first, second, real_is = item
        return shot, _ask(blind, first, second, real_is, model)

    with ThreadPoolExecutor(max_workers=jobs) as pool:
        answers = list(pool.map(run, asks))
    found: dict[str, list[dict]] = {}
    for shot, answer in answers:
        found.setdefault(shot["name"], []).append({**answer, "kind": shot["kind"]})
    summary = summarise(found)
    record = {"tag": tag, "prompt": PROMPT_VERSION, "model": model, "summary": summary,
              "verdicts": found}
    (out / f"judge_{tag}.json").write_text(json.dumps(record, indent=1, ensure_ascii=False))
    print(json.dumps(summary, indent=1))
    for name, verdicts in found.items():
        for v in verdicts:
            if "error" in v:
                print(f"  {name}: no verdict ({v['error'][:120]})")
                continue
            print(f"  {name} [{v['order']}]: {'found the photograph' if v['right'] else 'FOOLED'}"
                  f" at {v['confidence']}: {v['reason']}")
            print(f"      tells: {'; '.join(v['render_tells'])}")
    return 0


def summarise(found: dict[str, list[dict]]) -> dict:
    def over(kind: str | None) -> dict:
        vs = [v for verdicts in found.values() for v in verdicts
              if "error" not in v and (kind is None or v["kind"] == kind)]
        if not vs:
            return {"trials": 0}
        return {"trials": len(vs), "found_photograph": sum(v["right"] for v in vs),
                "pick_rate": round(sum(v["right"] for v in vs) / len(vs), 3),
                "sure": round(sum(v["sure"] for v in vs) / len(vs), 3)}
    return {"closeups": over("closeup"), "sets": over("set"), "all": over(None)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    p = sub.add_parser("pairs")
    p.add_argument("tag")
    p.add_argument("--out", type=Path)
    c = sub.add_parser("compare")
    c.add_argument("before")
    c.add_argument("after")
    c.add_argument("--out", type=Path)
    k = sub.add_parser("colour")
    k.add_argument("tag")
    k.add_argument("--out", type=Path)
    k.add_argument("--drawn", type=Path, default=DRAWN)
    g = sub.add_parser("gloss")
    g.add_argument("tag")
    g.add_argument("--out", type=Path)
    g.add_argument("--drawn", type=Path, default=DRAWN)
    j = sub.add_parser("judge")
    j.add_argument("tag")
    j.add_argument("--out", type=Path)
    j.add_argument("--model", default="opus")
    j.add_argument("--jobs", type=int, default=4)
    j.add_argument("--only", default="")
    args = parser.parse_args()
    out = args.out or (DRAWN / "pairs")
    if args.what == "pairs":
        return pairs(args.tag, out)
    if args.what == "compare":
        return compare(args.before, args.after, out)
    if args.what == "colour":
        return colour(args.tag, out, args.drawn)
    if args.what == "gloss":
        return gloss(args.tag, out, args.drawn)
    return judge_tag(args.tag, out, args.model, args.jobs, [s for s in args.only.split(",") if s])


if __name__ == "__main__":
    sys.exit(main())
