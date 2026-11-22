"""A model's clip for its link's preview (docs/SOCIAL.md, unit turntable).

web/turntable-clip.js writes the file in the designer's browser (muxMp4,
muxWebm) from what WebCodecs encodes, and api/_clip.js reads every clip
again before it is kept (readClip). Here, under node, without a browser:

- readClip on the fixtures: the two it keeps say what they are, every one
  it must refuse is refused in words, and nothing makes it throw;
- muxMp4 and muxWebm fed frames ffmpeg encoded as WebCodecs would give
  them (H.264's NAL units with their lengths in front and its avcC; VP9's
  frames), and the files they write read back by ffprobe and ffmpeg (the
  size, 96 frames, 4.000 s, no decoding error), by readClip, and the MP4
  with its moov before its mdat.

The fixtures in tests/fixtures/clip/ were made once (64 x 36, 24 fps) with:

    S=testsrc2=size=64x36:rate=24
    ffmpeg -f lavfi -i $S -frames:v 96 -c:v libx264 -profile:v baseline -preset ultrafast \
        -pix_fmt yuv420p -movflags +faststart -an turn.mp4
    ffmpeg -f lavfi -i $S -frames:v 96 -c:v libvpx-vp9 -deadline realtime -cpu-used 8 -b:v 50k \
        -pix_fmt yuv420p -an turn.webm
    ffmpeg -f lavfi -i $S -frames:v 120 (as turn.mp4) long.mp4                      # 5 s
    ffmpeg -f lavfi -i $S -f lavfi -i sine=frequency=440:sample_rate=8000 -frames:v 96 -t 4 \
        (as turn.mp4) -c:a aac -b:a 16k audio.mp4                                    # with sound
    ffmpeg -f lavfi -i $S -frames:v 96 -c:v libvpx -deadline realtime -cpu-used 8 -b:v 50k \
        -pix_fmt yuv420p -an -live 1 -f webm mediarecorder.webm                      # no Duration
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "tests" / "fixtures" / "clip"


def node(body: str) -> object:
    """[body], an async function's body returning something JSON, run in a
    fresh node process with `readClip`, `muxMp4`, `muxWebm`, `CLIP`, `fs`
    and `F` (the fixtures' folder) to hand."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "import * as fs from 'node:fs';"
        "import { readClip } from './api/_clip.js';"
        "import { CLIP, muxMp4, muxWebm } from './web/turntable-clip.js';"
        f"const F = {json.dumps(str(FIXTURES))};"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def read(name: str) -> dict:
    return node(f"return readClip(fs.readFileSync(`${{F}}/{name}`));")


def test_the_clips_it_keeps_say_what_they_are():
    assert read("turn.mp4") == {"kind": "mp4", "codec": "avc1", "width": 64, "height": 36, "ms": 4000, "frames": 96}
    assert read("turn.webm") == {"kind": "webm", "codec": "vp9", "width": 64, "height": 36, "ms": 4000,
                                 "frames": 96}


def test_what_it_refuses_is_refused_in_words():
    said = {name: read(name).get("error", "") for name in ("long.mp4", "audio.mp4", "mediarecorder.webm")}
    assert said == {
        "long.mp4": "the clip is longer than 4 seconds",
        "audio.mp4": "the clip carries more than its pictures: one picture track and no sound",
        "mediarecorder.webm": "the clip says no length",
    }
    odd = node(
        "const turn = fs.readFileSync(`${F}/turn.mp4`);"
        "const random = Buffer.alloc(4096); for (let k = 0; k < random.length; k++) random[k] = (k * 7919 + 13) % 251;"
        "return {"
        " truncated: readClip(turn.subarray(0, 5000)),"
        " webmTruncated: readClip(fs.readFileSync(`${F}/turn.webm`).subarray(0, 3000)),"
        " random: readClip(random),"
        " empty: readClip(Buffer.alloc(0)),"
        " big: readClip(Buffer.alloc(1600000)),"
        " notBytes: readClip('a string'),"
        " ftypOnly: readClip(turn.subarray(0, 40)),"
        "};"
    )
    assert odd == {
        "truncated": {"error": "the clip is cut short"},
        "webmTruncated": {"error": "the clip is cut short"},
        "random": {"error": "the clip is not an MP4 or a WebM"},
        "empty": {"error": "the clip is empty"},
        "big": {"error": "the clip is larger than 1.5 MB"},
        "notBytes": {"error": "the clip is not a file"},
        "ftypOnly": {"error": "the clip is cut short"},
    }


def test_a_webm_of_unknown_sizes_is_read_as_a_live_stream_writes_it():
    # turn.webm's Segment and every Cluster rewritten with the size a live
    # stream writes (not known): the same 96 frames and 4 s are found, and
    # an element after the last Cluster ends it.
    found = node(
        "const b = fs.readFileSync(`${F}/turn.webm`);"
        "const vint = (at) => { const lead = b[at]; let n = 1; while (!(lead & (0x80 >> (n - 1)))) n++;"
        "  let v = lead & (0xff >> n); for (let k = 1; k < n; k++) v = v * 256 + b[at + k]; return [v, n]; };"
        "const idLen = (at) => (b[at] >= 0x80 ? 1 : b[at] >= 0x40 ? 2 : b[at] >= 0x20 ? 3 : 4);"
        "const UNKNOWN = Buffer.from([0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]);"
        "const [headSize, headN] = vint(4); const segAt = 4 + headN + headSize;"
        "const segIdN = idLen(segAt); const [segSize, segN] = vint(segAt + segIdN);"
        "const parts = [b.subarray(0, segAt), b.subarray(segAt, segAt + segIdN), UNKNOWN];"
        "let at = segAt + segIdN + segN; const end = at + segSize;"
        "while (at < end) { const n = idLen(at); const id = b.readUIntBE(at, n); const [size, sn] = vint(at + n);"
        "  const body = b.subarray(at + n + sn, at + n + sn + size);"
        "  parts.push(b.subarray(at, at + n), id === 0x1f43b675 ? UNKNOWN : b.subarray(at + n, at + n + sn), body);"
        "  at += n + sn + size; }"
        "parts.push(Buffer.from([0x12, 0x54, 0xc3, 0x67, 0x80]));"
        "return readClip(Buffer.concat(parts));"
    )
    assert found == {"kind": "webm", "codec": "vp9", "width": 64, "height": 36, "ms": 4000, "frames": 96}


def tools() -> None:
    for tool in ("node", "ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            pytest.skip(f"no {tool}")


def small(out: Path, seconds: int, codec: list[str]) -> None:
    """[seconds] of the fixtures' pattern (64 x 36, 24 fps), as [codec] says."""
    done = subprocess.run(
        ["nice", "-n", "19", "ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=64x36:rate=24",
         "-t", str(seconds), "-pix_fmt", "yuv420p", "-an", *codec, str(out)],
        capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-2000:]


def test_a_clip_is_as_long_as_its_pictures_whatever_its_headers_say(tmp_path):
    # ttreview F4 (bench/results/ttreview-2026-11-22/lie.mjs): each was kept
    # as 4 s or less, and each plays longer. ffmpeg's own fragmented MP4,
    # whose moov tells of its first fragment alone; an MP4 whose movie,
    # track and media headers were rewritten to 4 s, its frames' times
    # (stts) left; a WebM whose Duration was rewritten to 4 s, its blocks'
    # times left.
    tools()
    x264 = ["-c:v", "libx264", "-profile:v", "baseline", "-preset", "ultrafast"]
    small(tmp_path / "frag.mp4", 8, [*x264, "-movflags", "frag_keyframe"])
    small(tmp_path / "long.webm", 6, ["-c:v", "libvpx-vp9", "-deadline", "realtime", "-cpu-used", "8", "-b:v", "20k"])
    said = node(
        f"const T = {json.dumps(str(tmp_path))};"
        "const lie = fs.readFileSync(`${F}/long.mp4`);"
        "const at = (type) => lie.indexOf(Buffer.from(type));"
        "for (const type of ['mvhd', 'mdhd']) {"
        "  const box = at(type); lie.writeUInt32BE(lie.readUInt32BE(box + 16) * 4, box + 20); }"
        "lie.writeUInt32BE(lie.readUInt32BE(at('mvhd') + 20), at('tkhd') + 24);"
        "const webm = fs.readFileSync(`${T}/long.webm`);"
        "const d = webm.indexOf(Buffer.from([0x44, 0x89]));"
        "if (webm[d + 2] === 0x88) webm.writeDoubleBE(4000, d + 3); else webm.writeFloatBE(4000, d + 3);"
        "return { frag: readClip(fs.readFileSync(`${T}/frag.mp4`)), mp4: readClip(lie), webm: readClip(webm),"
        "  mp4Said: lie.readUInt32BE(at('mvhd') + 20) / lie.readUInt32BE(at('mvhd') + 16) };"
    )
    assert said == {
        "frag": {"error": "the clip is in fragments: one moov that describes every picture"},
        "mp4": {"error": "the clip is longer than 4 seconds"},
        "webm": {"error": "the clip is longer than 4 seconds"},
        "mp4Said": 4,
    }


def encode(out: Path, codec: list[str]) -> None:
    """96 frames of a moving test pattern, 768 x 432 at 24 fps, a key frame
    every 48, written by ffmpeg as [codec] says."""
    done = subprocess.run(
        ["nice", "-n", "19", "ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=768x432:rate=24",
         "-frames:v", "96", "-pix_fmt", "yuv420p", "-an", *codec, str(out)],
        capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-2000:]


def probe(path: Path) -> dict:
    done = subprocess.run(
        ["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
         "stream=codec_name,width,height,nb_read_frames:format=duration", "-of", "json", str(path)],
        capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-2000:]
    facts = json.loads(done.stdout)
    stream = facts["streams"][0]
    return {"codec": stream["codec_name"], "width": stream["width"], "height": stream["height"],
            "frames": int(stream["nb_read_frames"]), "duration": round(float(facts["format"]["duration"]), 3)}


def decode_errors(path: Path) -> str:
    done = subprocess.run(["nice", "-n", "19", "ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"],
                          capture_output=True, text=True, timeout=120, stdin=subprocess.DEVNULL)
    return (done.stderr + ("" if done.returncode == 0 else f" (exit {done.returncode})")).strip()


def key_frames(path: Path) -> list[bool]:
    done = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "packet=flags",
                           "-of", "csv=p=0", str(path)], capture_output=True, text=True, timeout=120,
                          stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr[-2000:]
    return ["K" in line for line in done.stdout.split()]


def test_muxmp4_writes_an_mp4_every_player_reads(tmp_path):
    tools()
    raw = tmp_path / "turn.h264"
    encode(raw, ["-c:v", "libx264", "-profile:v", "baseline", "-preset", "ultrafast",
                 "-x264-params", "keyint=48:min-keyint=48:scenecut=0:aud=1", "-bsf:v", "h264_mp4toannexb",
                 "-f", "h264"])
    out = tmp_path / "muxed.mp4"
    # Annex B's start codes taken off, each frame's NAL units given their
    # lengths instead, its parameter sets taken out into the avcC: what
    # VideoEncoder gives with avc's "avc" format.
    made = node(
        f"const b = fs.readFileSync({json.dumps(str(raw))});"
        "const nals = []; let at = 0; const starts = [];"
        "for (let k = 0; k + 3 <= b.length; k++) {"
        "  if (b[k] === 0 && b[k + 1] === 0 && b[k + 2] === 1) { starts.push([k, k + 3]); k += 2; } }"
        "for (let s = 0; s < starts.length; s++) {"
        "  let end = s + 1 < starts.length ? starts[s + 1][0] : b.length;"
        "  while (end > starts[s][1] && b[end - 1] === 0) end--;"
        "  nals.push(b.subarray(starts[s][1], end)); }"
        "let sps = null; let pps = null; const frames = []; let unit = null;"
        "for (const nal of nals) { const type = nal[0] & 31;"
        "  if (type === 9) { unit = { parts: [], key: false }; frames.push(unit); continue; }"
        "  if (type === 7) { sps = sps || nal; continue; } if (type === 8) { pps = pps || nal; continue; }"
        "  if (type === 5) unit.key = true; unit.parts.push(nal); }"
        "const chunks = frames.map((f) => ({ key: f.key, data: Buffer.concat(f.parts.flatMap((p) => {"
        "  const n = Buffer.alloc(4); n.writeUInt32BE(p.length); return [n, p]; })) }));"
        "const be16 = (v) => Buffer.from([v >> 8, v & 255]);"
        "const description = Buffer.concat([Buffer.from([1, sps[1], sps[2], sps[3], 0xff, 0xe1]), be16(sps.length), sps,"
        "  Buffer.from([1]), be16(pps.length), pps]);"
        "const bytes = muxMp4({ width: 768, height: 432, fps: 24, description, chunks });"
        f"fs.writeFileSync({json.dumps(str(out))}, bytes);"
        "const at4 = (name) => { let k = 0; while (k + 8 <= bytes.length) {"
        "  const size = Buffer.from(bytes).readUInt32BE(k); const type = Buffer.from(bytes.subarray(k + 4, k + 8)).toString();"
        "  if (type === name) return k; k += size; } return -1; };"
        "return { frames: chunks.length, keys: chunks.filter((c) => c.key).length, read: readClip(bytes),"
        "  moov: at4('moov'), mdat: at4('mdat') };"
    )
    assert made["frames"] == 96 and made["keys"] == 2
    assert made["read"] == {"kind": "mp4", "codec": "avc1", "width": 768, "height": 432, "ms": 4000, "frames": 96}
    assert 0 < made["moov"] < made["mdat"], "moov comes before mdat"
    assert probe(out) == {"codec": "h264", "width": 768, "height": 432, "frames": 96, "duration": 4.0}
    assert decode_errors(out) == ""
    keys = key_frames(out)
    assert len(keys) == 96 and [k for k, key in enumerate(keys) if key] == [0, 48]


def test_muxwebm_writes_a_webm_every_player_reads(tmp_path):
    tools()
    raw = tmp_path / "turn.ivf"
    encode(raw, ["-c:v", "libvpx-vp9", "-deadline", "realtime", "-cpu-used", "8", "-b:v", "1M", "-g", "48",
                 "-keyint_min", "48", "-auto-alt-ref", "0", "-lag-in-frames", "0", "-f", "ivf"])
    keys = key_frames(raw)
    out = tmp_path / "muxed.webm"
    # IVF: a 32-byte header, then each frame's size and time (12 bytes)
    # and the frame, as VideoEncoder gives VP9's.
    made = node(
        f"const b = fs.readFileSync({json.dumps(str(raw))}); const keys = {json.dumps(keys)};"
        "const chunks = []; let at = b.readUInt16LE(6);"
        "while (at + 12 <= b.length) { const size = b.readUInt32LE(at);"
        "  chunks.push({ data: b.subarray(at + 12, at + 12 + size), key: keys[chunks.length] }); at += 12 + size; }"
        "const bytes = muxWebm({ width: 768, height: 432, fps: 24, codec: 'V_VP9', chunks });"
        f"fs.writeFileSync({json.dumps(str(out))}, bytes);"
        "return { frames: chunks.length, keys: chunks.filter((c) => c.key).length, read: readClip(bytes) };"
    )
    assert made["frames"] == 96 and made["keys"] == 2
    assert made["read"] == {"kind": "webm", "codec": "vp9", "width": 768, "height": 432, "ms": 4000, "frames": 96}
    assert probe(out) == {"codec": "vp9", "width": 768, "height": 432, "frames": 96, "duration": 4.0}
    assert decode_errors(out) == ""
    assert [k for k, key in enumerate(key_frames(out)) if key] == [0, 48]


def test_the_clip_module_loads_where_there_is_no_browser():
    # Nothing in it runs as it loads: without WebCodecs it says it cannot
    # record, rather than failing.
    said = node("const m = await import('./web/turntable-clip.js');"
                "return { kind: await m.clipKind(), made: await m.recordClip(() => null), clip: m.CLIP };")
    assert said == {"kind": "", "made": None,
                    "clip": {"width": 768, "height": 432, "fps": 24, "frames": 96, "maxBytes": 1572864}}
