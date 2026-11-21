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
    blind = ROOT / "bench" / "results" / "blind" / _opaque(f"tag:{tag}")
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
    return judge_tag(args.tag, out, args.model, args.jobs, [s for s in args.only.split(",") if s])


if __name__ == "__main__":
    sys.exit(main())
