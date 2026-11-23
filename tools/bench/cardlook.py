#!/usr/bin/env python3
"""The gallery's cards as they were and as photographs, side by side and blind (cardlook).

src/dev/card_probe.gd draws each of the house's models' cards into DIR: <n>_old.png, the
cut-out the Share panel drew (nothing behind the model), and <n>_<look>.png, CardPhoto's.
The site shows a cut-out on its picture ground (web/site.css --picture-ground), so it is
judged and shown on that ground, the light theme's unless said.

    tools/bench/cardlook.py sheet DIR --looks new [--out FILE]
        a contact sheet: each model's old card on both themes' grounds, then each look
    tools/bench/cardlook.py judge DIR --look new --out OUT [--model opus] [--jobs 4]
        the blind judge (tools/bench/judge.py, on the subscription), both orders of each
        pair: which looks more like a photograph of the real model. A model is won when
        the new card is chosen in both orders. OUT/judge_<look>.json and a summary.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from bench import judge  # noqa: E402

# web/site.css --picture-ground: the light theme's, then the dark one's.
GROUNDS = {"light": ((0xED, 0xEF, 0xF5), (0xCC, 0xD4, 0xDE)),
           "dark": ((0x33, 0x3A, 0x45), (0x1D, 0x22, 0x2A))}
SCHEMA: dict = {
    "type": "object",
    "properties": {
        "looked_at": {"type": "array", "items": {"type": "string"}},
        "photograph": {"type": "string", "enum": ["A", "B"]},
        "confidence": {"type": "integer", "minimum": 50, "maximum": 100},
        "reason": {"type": "string"},
        "render_tells": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["looked_at", "photograph", "confidence", "reason", "render_tells"],
}


def on_ground(cut: Image.Image, theme: str = "light") -> Image.Image:
    """A cut-out as the site shows it: on its picture ground, lighter at the top."""
    top, foot = GROUNDS[theme]
    w, h = cut.size
    ground = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(ground)
    for y in range(h):
        t = y / max(h - 1, 1)
        draw.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, foot)))
    ground.paste(cut.convert("RGBA"), (0, 0), cut.convert("RGBA"))
    return ground


def models(folder: Path, look: str) -> list[int]:
    return sorted(int(p.name.split("_")[0]) for p in folder.glob("*_old.png")
                  if (folder / f"{p.name.split('_')[0]}_{look}.png").exists())


def sheet(folder: Path, looks: list[str], out: Path, only: list[int] | None) -> int:
    found = [n for n in models(folder, looks[0]) if not only or n in only]
    cell = (320, 240)
    columns = ["old (light)", "old (dark)", *looks]
    picture = Image.new("RGB", (cell[0] * len(columns) + 40, (cell[1] + 4) * len(found) + 24), "white")
    draw = ImageDraw.Draw(picture)
    for c, name in enumerate(columns):
        draw.text((40 + c * cell[0] + 4, 6), name, fill="black")
    for r, n in enumerate(found):
        y = 24 + r * (cell[1] + 4)
        draw.text((4, y + cell[1] // 2), str(n), fill="black")
        cut = Image.open(folder / f"{n}_old.png")
        row = [on_ground(cut, "light"), on_ground(cut, "dark")]
        row += [Image.open(folder / f"{n}_{look}.png").convert("RGB") for look in looks]
        for c, one in enumerate(row):
            picture.paste(one.resize(cell, Image.LANCZOS), (40 + c * cell[0], y))
    out.parent.mkdir(parents=True, exist_ok=True)
    picture.save(out, quality=88)
    print(f"{out}: {len(found)} models, {', '.join(columns)}")
    return 0


def _opaque(words: str) -> str:
    return hashlib.sha256(f"cardlook:{words}".encode()).hexdigest()[:10]


def prompt(a: Path, b: Path) -> str:
    return "\n".join([
        "You are shown two pictures, A and B, of the same LEGO® model, each as a website's "
        "gallery shows it on a card. Say which one looks more like a photograph of the real "
        "model: built of real LEGO bricks, standing somewhere real, taken with a camera.",
        "",
        "Open both pictures with the Read tool before you answer.",
        f"  A: {a}",
        f"  B: {b}",
        "",
        "Look at the plastic, the edges, the studs, the light and shadows, what the model "
        "stands on and what is behind it, and the camera. The order means nothing: you are "
        "shown the same two the other way round as well. You must choose one.",
        "",
        "Reply with only the JSON object the schema asks for: photograph (A or B, the one "
        "more like a photograph), confidence (50 a pure guess, 100 certain), reason (one or "
        "two sentences), render_tells (short phrases, each one thing in the other picture "
        "that gives it away as computer generated), and looked_at (the file names you opened).",
    ])


def _ask(where: Path, first: Path, second: Path, new_is: str, model: str) -> dict:
    error = ""
    for _attempt in (1, 2):
        try:
            reply, seconds = judge.call(prompt(first, second), where, [where], model=model, schema=SCHEMA)
        except Exception as failed:  # noqa: BLE001
            error = str(failed)
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
        return {"order": "new first" if new_is == "A" else "old first", "picked": pick,
                "new_chosen": pick == new_is, "confidence": int(found.get("confidence", 50)),
                "reason": " ".join(str(found.get("reason", "")).split()),
                "render_tells": [str(t) for t in found.get("render_tells", [])],
                "seconds": round(seconds, 1)}
    return {"error": error}


def judge_look(folder: Path, look: str, out: Path, model: str, jobs: int, only: list[int] | None,
               theme: str) -> int:
    blind = out / "blind" / _opaque(f"{folder}:{look}")
    blind.mkdir(parents=True, exist_ok=True)
    (out / "blind" / ".gdignore").touch()
    asks = []
    for n in models(folder, look):
        if only and n not in only:
            continue
        old = blind / f"{_opaque(f'{n}old')}.jpg"
        new = blind / f"{_opaque(f'{n}{look}')}.jpg"
        on_ground(Image.open(folder / f"{n}_old.png"), theme).save(old, quality=92)
        Image.open(folder / f"{n}_{look}.png").convert("RGB").save(new, quality=92)
        asks += [(n, new, old, "A"), (n, old, new, "B")]
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        answers = list(pool.map(lambda item: (item[0], _ask(blind, item[1], item[2], item[3], model)), asks))
    found: dict[int, list[dict]] = {}
    for n, answer in answers:
        found.setdefault(n, []).append(answer)
    both = [n for n, vs in found.items() if len(vs) == 2 and all(v.get("new_chosen") for v in vs)]
    neither = [n for n, vs in found.items() if len(vs) == 2 and not any(v.get("new_chosen") for v in vs)]
    errors = sum(1 for vs in found.values() for v in vs if "error" in v)
    chosen = sum(1 for vs in found.values() for v in vs if v.get("new_chosen"))
    summary = {"look": look, "theme": theme, "models": len(found), "won_both_orders": len(both),
               "lost_both_orders": len(neither), "split": len(found) - len(both) - len(neither),
               "new_chosen": chosen, "verdicts": sum(len(vs) for vs in found.values()) - errors,
               "errors": errors, "won": sorted(both), "lost": sorted(neither)}
    out.mkdir(parents=True, exist_ok=True)
    (out / f"judge_{look}_{theme}.json").write_text(json.dumps(
        {"summary": summary, "model": model, "verdicts": {str(k): v for k, v in sorted(found.items())}},
        indent=1, ensure_ascii=False))
    print(json.dumps(summary, indent=1))
    for n, vs in sorted(found.items()):
        for v in vs:
            if "error" in v:
                print(f"  {n}: no verdict ({v['error'][:120]})")
            else:
                print(f"  {n} [{v['order']}]: {'NEW' if v['new_chosen'] else 'old'} at {v['confidence']}: {v['reason']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["sheet", "judge"])
    parser.add_argument("dir", type=Path)
    parser.add_argument("--looks", default="new")
    parser.add_argument("--look", default="new")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--only", default="")
    parser.add_argument("--model", default="opus")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--theme", default="light", choices=list(GROUNDS))
    given = parser.parse_args()
    only = [int(n) for n in given.only.split(",") if n] or None
    if given.what == "sheet":
        return sheet(given.dir, given.looks.split(","), given.out or given.dir / "sheet.jpg", only)
    return judge_look(given.dir, given.look, given.out or given.dir / "judge", given.model, given.jobs,
                      only, given.theme)


if __name__ == "__main__":
    sys.exit(main())
