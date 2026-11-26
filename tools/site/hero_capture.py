#!/usr/bin/env python3
"""The home page's loop of the studio at work, taken from the real app.

    tools/site/hero_capture.py                 play every cut in the app
                                               (src/dev/hero_capture_probe.gd, on the
                                               GPU), cut and encode it into web/img/hero/
    tools/site/hero_capture.py --frames=DIR    cut and encode a run's frames already in DIR
    tools/site/hero_capture.py --only=phone    one cut
    tools/site/hero_capture.py --out=DIR       a trial: the files in DIR, the page untouched
    tools/site/hero_capture.py --plan=FILE     another plan than tools/site/hero_capture.json
    tools/site/hero_capture.py --sheets=DIR    a contact sheet of each cut in DIR: twelve
                                               frames across the loop, 4 x 3, and every
                                               15th frame, to look at before it ships
    tools/site/hero_capture.py --check         say whether web/img/hero has every file
                                               the page names, each under its size

The owner, 2026-11-26: the hero a signed-out visitor sees should be "an
animated screenshot of the actual studio so people immediately know what
brickworks is". So the loop is the app itself, played by a probe from
tools/site/hero_capture.json, and every release can take it again (herostudio).

Each cut (a desktop window, 16:10; a phone's layout, 9:16) is its segments
joined: one crossfades into the next (its "fade" frames, else XFADE), unless
it says join; a segment's speed keeps every nth frame, its fit makes it at
most so many seconds and its cut keeps only its first so many frames. A
"still" segment is a picture the probe rendered off camera (the render's
PNG): shown full-frame, covering the cut, for its seconds, pushed in slowly
to its push. The loop's end crossfades into its own start: the cut begins
XFADE frames into the first segment, and its last frames are the last
segment fading into those first frames, so it plays round with no seam. Then
it is encoded twice, each muted, small enough for a first screen: AV1 (MP4)
for the browsers that play it, H.264 (MP4) for the rest, each's quality
lowered step by step until it is under the cut's bytes for that codec. And
its poster, the frame the plan names, as WebP at the cut's size and half of
it: the page's first paint, and all that is shown to someone who asked for
less motion or to save data.

Nothing private and nothing half-done is filmed (herostudio2): the probe
keeps every word in sight at each recorded frame (DIR/<cut>/texts.json),
and a cut whose words hold a path on this computer, the session's names, a
placeholder of a form or a word of work under way (REFUSED) is refused
before anything is encoded. herostudio's first loop showed its render's
status line, "wrote /tmp/claude-1000/<session>/scratchpad/...", with
"Gathering the light… 10%" and the share form's "castle, tower, wizard".

What the page needs of it is written into web/index.html (and the language
copies, by tools/site_lang.py): each cut's length and when each
caption begins (#hero-loop's data-cues-*), from web/hero/studio.json, this
run's record.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
PLAN = ROOT / "tools" / "site" / "hero_capture.json"
OUT = ROOT / "web" / "img" / "hero"
RECORD = ROOT / "web" / "hero" / "studio.json"
PAGE = ROOT / "web" / "index.html"
FPS = 30
# Frames of a crossfade between segments, and of the loop's own, unless a
# segment says its own.
XFADE = 12
# A cut's file is at most this unless its plan says less (the brief: under
# 1.5 MB, for a first screen).
BYTES = 1_450_000
# Quality, as each encoder's CRF: the first tried, then worse by STEP.
AV1_CRF, H264_CRF, STEP, TRIES = 36, 27, 3, 8
# Words a loop must never show, as patterns over each word the probe saw:
# where this computer keeps things and whose session took it, and the words
# of a form or of work not done.
REFUSED = [
    (r"/tmp\b", "a path under /tmp"),
    (r"/home\b", "a path under /home"),
    (r"/mnt\b", "a path under /mnt"),
    (r"(?i)scratchpad", "the session's scratchpad"),
    (r"(?i)claude-", "the session's name"),
    (r"(?i)\.claude\b", "the session's folder"),
    (r"(?i)castle, tower, wizard", "the share form's placeholder"),
    (r"(?i)gathering the light", "the render at work"),
    (r"(?i)\bsaving\b", "a save at work"),
    (r"(?i)working out", "work under way"),
    (r"(?i)\bloading\b", "a load under way"),
    (r"(?i)\brendering\b", "a render at work"),
    (r"(?i)\bpublishing\b", "a publish at work"),
    (r"(?i)\buploading\b", "an upload at work"),
    (r"(?i)\bplease wait\b", "a wait"),
    (r"\b\d{1,3}(\.\d+)?\s?%", "a share done"),
]


@dataclass(frozen=True)
class Still:
    """A frame of a still segment: [path] covering the cut, [zoom] times."""
    path: Path
    zoom: float


@dataclass(frozen=True)
class Blend:
    """[a] fading to [b], [share] of the way."""
    a: object
    b: object
    share: float


def frames_of(folder: Path) -> list[Path]:
    return sorted(folder.glob("*.png"))


def picked(frames: list[Path], speed: float, fit: float) -> list[Path]:
    """Every nth frame, n the segment's speed, or as many as fit seconds take."""
    if fit and len(frames) / speed > fit * FPS:
        speed = len(frames) / (fit * FPS)
    if speed <= 1.0:
        return frames
    count = max(1, int(len(frames) / speed))
    return [frames[min(len(frames) - 1, round(i * speed))] for i in range(count)]


def ease(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def still_frames(path: Path, seconds: float, push: float) -> list[Still]:
    """A still's frames: [seconds] of it, pushed in from 1 to [push], eased."""
    count = max(2, round(seconds * FPS))
    return [Still(path, 1.0 + (push - 1.0) * ease(i / (count - 1))) for i in range(count)]


def refused(cut_dir: Path) -> list[str]:
    """What the probe saw in [cut_dir]'s recorded frames that the loop must
    never show, each as "segment, frame n: why: the words"; and a cut with no
    record of its words is refused whole, as one that was never looked at."""
    file = cut_dir / "texts.json"
    if not file.exists():
        return [f"{cut_dir.name}: no texts.json, so its words were never looked at"]
    seen = json.loads(file.read_text()).get("segments", {})
    out = []
    for segment, rows in seen.items():
        for frame, kind, words in rows:
            for pattern, why in REFUSED:
                if re.search(pattern, words):
                    out.append(f"{segment}, frame {frame}: {why} ({kind}): {words!r}")
                    break
    return out


def timeline(cut_dir: Path, told: dict, plan_cut: dict) -> tuple[list, list, object]:
    """The cut's frames in order, each a path, a Still or a Blend; the
    captions as [seconds, word]; and the poster's frame."""
    planned = {s["name"]: s for s in plan_cut.get("segments", [])}
    segments = []
    for one in told["segments"]:
        if one["name"] not in planned:
            # Recorded by a run of an older plan: not in this one's loop.
            continue
        plan = planned[one["name"]]
        if plan.get("still"):
            path = cut_dir / plan["still"]
            if not path.exists():
                raise SystemExit(f"hero_capture: {cut_dir.name}/{plan['still']} was not made")
            frames = still_frames(path, float(plan.get("seconds", 3.0)), float(plan.get("push", 1.0)))
        else:
            # cut: at most so many of its first frames.
            recorded = frames_of(cut_dir / one["name"])[: int(plan.get("cut", 0)) or None]
            frames = picked(recorded, float(plan.get("speed", 1.0)), float(plan.get("fit", 0)))
        if not frames:
            raise SystemExit(f"hero_capture: {cut_dir.name}/{one['name']} has no frames")
        segments.append({"name": one["name"], "caption": plan.get("caption", ""), "join": bool(plan.get("join")),
                         "fade": int(plan.get("fade", XFADE)), "frames": frames, "plan": plan})
    poster = None
    want = plan_cut.get("poster", {})
    for one in segments:
        if one["name"] == want.get("segment"):
            if one["plan"].get("still"):
                poster = Still(cut_dir / one["plan"]["still"], 1.0)
            else:
                raw = frames_of(cut_dir / one["name"])
                poster = raw[-1] if want.get("at") == "end" else raw[min(len(raw) - 1, int(want.get("at", 0)))]
    first = segments[0]["frames"]
    loop_fade = int(plan_cut.get("loop_fade", XFADE))
    if len(first) <= loop_fade * 2:
        raise SystemExit(f"hero_capture: {cut_dir.name}'s first segment is too short to loop")
    out: list = []
    cues: list = []
    # The loop begins loop_fade frames into the first segment.
    segments[0] = dict(segments[0], frames=first[loop_fade:])
    for n, one in enumerate(segments):
        frames = one["frames"]
        if n == 0 or one["join"]:
            start = len(out)
            out.extend(frames)
        else:
            # The last frames of what came before fade into this one's first.
            fade = min(one["fade"], len(frames), len(out))
            start = len(out) - fade
            for k in range(fade):
                a = out[start + k]
                out[start + k] = Blend(a.b if isinstance(a, Blend) else a, frames[k], (k + 1) / (fade + 1))
            out.extend(frames[fade:])
        word = one["caption"]
        if word and (not cues or cues[-1][1] != word):
            cues.append([round(start / FPS, 2), word])
    # And the last of it fades into the loop's start (the first segment's first frames).
    tail = len(out) - loop_fade
    for k in range(loop_fade):
        a = out[tail + k]
        out[tail + k] = Blend(a.b if isinstance(a, Blend) else a, first[k], (k + 1) / (loop_fade + 1))
    if cues and cues[0][0] != 0:
        cues[0][0] = 0
    return out, cues, poster


@lru_cache(maxsize=4)
def _covered(path: Path, size: tuple[int, int]) -> Image.Image:
    """[path] scaled to cover [size] at twice its pixels, for a push to crop from."""
    image = Image.open(path).convert("RGB")
    want = (size[0] * 2, size[1] * 2)
    scale = max(want[0] / image.width, want[1] / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left, top = (image.width - want[0]) // 2, (image.height - want[1]) // 2
    return image.crop((left, top, left + want[0], top + want[1]))


def pixels(frame, size: tuple[int, int]) -> Image.Image:
    if isinstance(frame, Blend):
        return Image.blend(pixels(frame.a, size), pixels(frame.b, size), frame.share)
    if isinstance(frame, Still):
        big = _covered(frame.path, size)
        w, h = big.width / frame.zoom, big.height / frame.zoom
        box = ((big.width - w) / 2, (big.height - h) / 2, (big.width + w) / 2, (big.height + h) / 2)
        return big.resize(size, Image.LANCZOS, box=box)
    image = Image.open(frame).convert("RGB")
    if image.size != size:
        image = image.resize(size, Image.LANCZOS)
    return image


def encode(frames: list, size: tuple[int, int], work: Path) -> Path:
    """The cut, lossless, at its size: what both encodes are made from."""
    master = work / "master.mkv"
    ffmpeg = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                               "-s", f"{size[0]}x{size[1]}", "-r", str(FPS), "-i", "-",
                               "-c:v", "ffv1", "-pix_fmt", "yuv444p", str(master)], stdin=subprocess.PIPE)
    assert ffmpeg.stdin is not None
    for frame in frames:
        ffmpeg.stdin.write(pixels(frame, size).tobytes())
    ffmpeg.stdin.close()
    if ffmpeg.wait() != 0:
        raise SystemExit("hero_capture: ffmpeg could not write the lossless cut")
    return master


def squeeze(master: Path, file: Path, codec: str, most: int) -> tuple[int, int]:
    """[file] encoded by [codec], its quality lowered until it is at most [most] bytes: (bytes, crf)."""
    crf = AV1_CRF if codec == "av1" else H264_CRF
    size = 0
    for _ in range(TRIES):
        if codec == "av1":
            how = ["-c:v", "libsvtav1", "-preset", "4", "-crf", str(crf), "-g", "300",
                   "-svtav1-params", "tune=0:enable-overlays=1:scd=1"]
        else:
            how = ["-c:v", "libx264", "-preset", "veryslow", "-crf", str(crf), "-g", "300",
                   "-profile:v", "high", "-level", "4.1", "-tune", "animation"]
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(master), *how, "-pix_fmt", "yuv420p",
                        "-an", "-movflags", "+faststart", str(file)], check=True)
        size = file.stat().st_size
        if size <= most:
            return size, crf
        crf += STEP
    raise SystemExit(f"hero_capture: {file.name} is still {size} bytes at CRF {crf - STEP}")


def sheets(video: Path, name: str, seconds: float, into: Path) -> list[Path]:
    """[video]'s contact sheets in [into]: twelve frames spread over the loop,
    4 x 3, and every 15th frame, twelve to a sheet, for a person to look at."""
    into.mkdir(parents=True, exist_ok=True)
    made = []
    loop = into / f"{name}-loop.png"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-vf",
                    f"fps={12 / seconds:.6f},scale=480:-2,tile=4x3", "-frames:v", "1", str(loop)], check=True)
    made.append(loop)
    every = into / f"{name}-every15-%02d.png"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-vf",
                    "select=not(mod(n\\,15)),scale=480:-2,tile=4x3", "-fps_mode", "vfr", str(every)], check=True)
    made.extend(sorted(into.glob(f"{name}-every15-*.png")))
    return made


def run_probe(frames: Path, only: list[str], plan: Path) -> None:
    args = ["bash", "tools/probe.sh", "hero_capture_probe", "--", f"--frames={frames}"]
    if only:
        args.append("--only=" + ",".join(only))
    if plan.resolve() != PLAN:
        args.append(f"--plan={plan.resolve()}")
    code = subprocess.run(args, cwd=ROOT).returncode
    if code != 0:
        raise SystemExit(f"hero_capture: the probe failed ({code}); its frames, if any, are in {frames}")


def write_page(record: dict) -> bool:
    """#hero-loop's data-cues-* in web/index.html, from the record."""
    text = PAGE.read_text()
    new = text
    for name, cut in record["cuts"].items():
        words = ",".join(f"{t:g}:{w}" for t, w in cut["cues"])
        value = f'{cut["seconds"]:g};{words}'
        new = re.sub(rf'data-cues-{name}="[^"]*"', f'data-cues-{name}="{value}"', new)
    if new != text:
        PAGE.write_text(new)
        return True
    return False


def most_bytes(plan_cut: dict, codec: str) -> int:
    return min(BYTES, int(plan_cut.get("bytes", {}).get(codec, BYTES)))


def check(out: Path, plan: dict) -> int:
    bad = 0
    record = json.loads(RECORD.read_text())
    for name, cut in record["cuts"].items():
        plan_cut = plan["cuts"].get(name, {})
        for file in cut["files"]:
            path = out / file
            codec = "av1" if ".av1." in file else "h264"
            if not path.exists():
                print(f"hero_capture: {path} is missing")
                bad += 1
            elif path.suffix == ".mp4" and path.stat().st_size > most_bytes(plan_cut, codec):
                print(f"hero_capture: {path} is {path.stat().st_size} bytes, over {most_bytes(plan_cut, codec)}")
                bad += 1
        words = ",".join(f"{t:g}:{w}" for t, w in cut["cues"])
        if f'data-cues-{name}="{cut["seconds"]:g};{words}"' not in PAGE.read_text():
            print(f"hero_capture: web/index.html's data-cues-{name} is not the record's")
            bad += 1
    print("hero_capture: " + ("ok" if not bad else f"{bad} wrong"))
    return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--frames", type=Path)
    parser.add_argument("--only", default="")
    parser.add_argument("--out", type=Path, default=OUT)
    parser.add_argument("--plan", type=Path, default=PLAN)
    parser.add_argument("--sheets", type=Path)
    parser.add_argument("--check", action="store_true")
    a = parser.parse_args(argv)
    plan = json.loads(a.plan.read_text())
    if a.check:
        return check(a.out, plan)
    only = [o for o in a.only.split(",") if o]
    frames = a.frames
    if frames is None:
        frames = Path(tempfile.mkdtemp(prefix="hero_capture."))
        run_probe(frames, only, a.plan)
    names = [name for name in plan["cuts"] if not only or name in only]
    # Every cut looked at before any is encoded: a refused word in one
    # refuses the run, and the files already in web/img/hero stay as they are.
    for name in names:
        told = json.loads((frames / name / "cut.json").read_text())
        if not told.get("ok"):
            raise SystemExit(f"hero_capture: {name} was not recorded: {told.get('why')}")
        wrong = refused(frames / name)
        if wrong:
            # A status line held for 400 frames is one fault: the first ten, and a count.
            for line in wrong[:10]:
                print(f"hero_capture: refused, {name}'s {line}", file=sys.stderr)
            if len(wrong) > 10:
                print(f"hero_capture: and {len(wrong) - 10} more", file=sys.stderr)
            raise SystemExit(f"hero_capture: {name} is refused: it shows {len(wrong)} thing(s) a loop must not")
    a.out.mkdir(parents=True, exist_ok=True)
    record = json.loads(RECORD.read_text()) if RECORD.exists() else {"cuts": {}}
    for name in names:
        plan_cut = plan["cuts"][name]
        told = json.loads((frames / name / "cut.json").read_text())
        order, cues, poster = timeline(frames / name, told, plan_cut)
        size = tuple(plan_cut.get("out", [1440, 900]))
        seconds = len(order) / FPS
        work = Path(tempfile.mkdtemp(prefix=f"hero_{name}."))
        try:
            master = encode(order, size, work)
            files = {}
            for codec in ("av1", "h264"):
                file = a.out / f"studio-{name}.{codec}.mp4"
                got, crf = squeeze(master, file, codec, most_bytes(plan_cut, codec))
                files[file.name] = got
                print(f"hero_capture: {file} {got / 1e6:.2f} MB (CRF {crf}), {seconds:.1f} s")
            if a.sheets:
                for sheet in sheets(a.out / f"studio-{name}.av1.mp4", name, seconds, a.sheets):
                    print(f"hero_capture: {sheet}")
            if poster is not None:
                still = pixels(poster, size)
                for scale in (1, 2):
                    shown = still if scale == 1 else still.resize((size[0] // 2, size[1] // 2), Image.LANCZOS)
                    file = a.out / f"studio-{name}-{shown.size[0]}.webp"
                    shown.save(file, "WEBP", quality=82, method=6)
                    files[file.name] = file.stat().st_size
                    print(f"hero_capture: {file} {shown.size[0]} x {shown.size[1]}, {file.stat().st_size // 1024} KB")
        finally:
            shutil.rmtree(work, ignore_errors=True)
        record["cuts"][name] = {"size": list(size), "seconds": round(seconds, 2), "cues": cues,
                                "files": sorted(files)}
        print(f"hero_capture: {name}'s captions {cues}")
    if a.out.resolve() != OUT:
        # A trial elsewhere: the files alone, the page and its record as they were.
        return 0
    RECORD.parent.mkdir(parents=True, exist_ok=True)
    RECORD.write_text(json.dumps(record, indent="\t") + "\n")
    if write_page(record):
        print("hero_capture: web/index.html's cues written; run tools/site_lang.py for the language copies")
    return 0


if __name__ == "__main__":
    sys.exit(main())
