"""A stranger's model file, read for sharing (byfix, 2026-11-21).

The review of bringyours handed /share-model hostile Studio files: zip bombs
of 400 MB to 3.9 GB in 1 to 11 MB, a central directory whose extra field ran
past the file, and 3,000 carried Part Designer parts. The page froze the tab
for up to 14 s, said nothing at all for the damaged one, and took 10 s over
the parts. web/studio-io.js now refuses a member stated over 2 MB before it
inflates it, cuts an inflate off where its member said it ends, never
throws, and carries parts in one pass. And a file's Author line with an
email address, or a line naming a place on the builder's computer, is left
out of what is published (web/private-lines.js, held to by api/share.js
for the app's publishes too). Small versions of the same files here, built
in the test, so CI holds what the review's tools proved.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="node is not installed")

# The files built in node (zlib), each read by readStudioIo: what it answers
# and how long it took.
READ = r"""
import { deflateRawSync, crc32 } from "node:zlib";
import { readFileSync } from "node:fs";
import { readStudioIo, TROUBLE, MOST_BYTES } from "./web/studio-io.js";

function zip(members) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const m of members) {
    const name = Buffer.from(m.name);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0); local.writeUInt16LE(20, 4); local.writeUInt16LE(m.method, 8);
    local.writeUInt32LE(m.crc >>> 0, 14); local.writeUInt32LE(m.packed ?? m.data.length, 18);
    local.writeUInt32LE(m.size >>> 0, 22); local.writeUInt16LE(name.length, 26);
    locals.push(local, name, m.data);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0); central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6);
    central.writeUInt16LE(m.method, 10); central.writeUInt32LE(m.crc >>> 0, 16);
    central.writeUInt32LE(m.packed ?? m.data.length, 20); central.writeUInt32LE(m.size >>> 0, 24);
    central.writeUInt16LE(name.length, 28); central.writeUInt16LE(m.extra ?? 0, 30); central.writeUInt32LE(offset, 42);
    centrals.push(central, name);
    offset += 30 + name.length + m.data.length;
  }
  const cd = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(members.length, 8); end.writeUInt16LE(members.length, 10);
  end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, cd, end]);
}
const LINE = "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n";
const lines = (bytes) => Buffer.from(LINE.repeat(Math.ceil(bytes / LINE.length))).subarray(0, bytes);
const deflated = (plain) => ({ data: deflateRawSync(plain, { level: 9 }), size: plain.length, crc: crc32(plain), method: 8 });

const out = {};
async function read(name, bytes) {
  const started = performance.now();
  let said;
  try {
    said = await readStudioIo(new Uint8Array(bytes));
  } catch (trouble) {
    said = { threw: String(trouble) };
  }
  out[name] = { error: said.error ?? null, size: said.size ?? 0, carried: said.carried ?? 0, text: said.text?.length ?? 0,
    threw: said.threw ?? null, ms: Math.round(performance.now() - started) };
}
// An honest bomb: 64 MB of part lines in a few hundred kilobytes.
await read("bomb", zip([{ name: "model.ldr", ...deflated(lines(64 * 1048576)) }]));
// A lying one: the same deflate, its size stated just under the most.
{
  const real = deflated(lines(64 * 1048576));
  await read("lying", zip([{ name: "model.ldr", ...real, size: MOST_BYTES - 1, crc: 0 }]));
}
// A central directory whose extra field runs past the end of the file.
{
  const plain = Buffer.from("0 Bay\r\n" + LINE);
  await read("past_end", zip([{ name: "model.ldr", data: plain, size: plain.length, crc: crc32(plain), method: 0, extra: 0x4000 }]));
}
// A carried part stated over the most.
{
  const model = Buffer.from("0 FILE m.ldr\r\n0 M\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 big.dat\r\n");
  const big = deflated(lines(3 * 1048576));
  await read("big_part", zip([{ name: "model.ldr", data: model, size: model.length, crc: crc32(model), method: 0 },
    { name: "CustomParts/parts/big.dat", ...big }]));
}
// 3,000 Part Designer parts, each named by the model and carried.
{
  const head = ["0 FILE custom.ldr", "0 Custom"];
  for (let k = 0; k < 3000; k += 1) head.push(`1 4 ${k * 20} 0 0 1 0 0 0 1 0 0 0 1 c${k}.dat`);
  const model = Buffer.from(head.join("\r\n"));
  const members = [{ name: "model.ldr", data: model, size: model.length, crc: crc32(model), method: 0 }];
  for (let k = 0; k < 3000; k += 1) {
    const part = Buffer.from(`0 c${k}\r\n3 16 0 0 0 10 0 0 0 0 10\r\n`);
    members.push({ name: `CustomParts/parts/c${k}.dat`, data: part, size: part.length, crc: crc32(part), method: 0 });
  }
  await read("custom_3000", zip(members));
}
// Bytes that are no zip at all, and a zip cut short.
await read("noise", Buffer.from("PK\x03\x04 and then nothing a zip has"));
{
  const whole = readFileSync("tests/fixtures/studio/bay_2025.io");
  await read("cut_short", whole.subarray(0, Math.floor(whole.length / 2)));
}
console.log(JSON.stringify({ TOO_BIG: TROUBLE.TOO_BIG, DAMAGED: TROUBLE.DAMAGED, out }));
"""


def run(script: str) -> dict:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                          capture_output=True, text=True, timeout=120)
    return json.loads(done.stdout)


def test_hostile_studio_files_are_refused_in_moments():
    said = run(READ)
    out = said["out"]
    # Refused by its stated size, before anything is inflated.
    assert out["bomb"]["error"] == said["TOO_BIG"] and out["bomb"]["size"] == 64 * 1048576
    assert out["bomb"]["ms"] < 500
    # Its size a lie: cut off where it said it ends, as damaged.
    assert out["lying"]["error"] == said["DAMAGED"] and out["lying"]["ms"] < 500
    # A directory that runs past the file: damaged, never a throw.
    assert out["past_end"]["error"] == said["DAMAGED"] and out["past_end"]["threw"] is None
    assert out["big_part"]["error"] == said["TOO_BIG"]
    for name in ("noise", "cut_short"):
        assert out[name]["threw"] is None and out[name]["error"], name
    # 3,000 carried parts in one pass: all of them, in well under a second.
    assert out["custom_3000"]["error"] == "" and out["custom_3000"]["carried"] == 3000
    assert out["custom_3000"]["ms"] < 1000


PRIVATE = r"""
import { withoutPrivateLines } from "./web/private-lines.js";
const file = ["0 FILE lighthouse.ldr", "0 Lighthouse", "0 Name: C:\\Users\\jane\\Models\\lighthouse.ldr",
  "0 Author: Jane Q. Public <jane.public@example.com>", "0 !LEOCAD MODEL AUTHOR jane.public@example.com",
  "0 !LEOCAD MODEL BACKGROUND IMAGE_NAME C:\\Users\\jane\\Pictures\\backdrop.png",
  "0 !LDCAD GENERATED [path=/home/jane/ldraw/parts]", "0 // mac: /Users/jane/Desktop", "0 // share: \\\\nas\\jane\\lego",
  "0 Author: Jane Q. Public", "0 // write to me at jane.public@example.com",
  "1 4 0 0 0 1 0 0 0 1 0 0 0 1 C:\\Users\\jane\\parts\\3001.dat", "0 NOFILE", ""].join("\r\n");
const plain = "0 Plain\n0 Name: plain.ldr\n0 Author: Jane [jane]\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n";
console.log(JSON.stringify({ file: withoutPrivateLines(file), plain: withoutPrivateLines(plain), plainSame: withoutPrivateLines(plain).text === plain,
  notText: withoutPrivateLines(null) }));
"""


def test_a_files_private_lines_are_left_out():
    said = run(PRIVATE)
    kept = said["file"]["text"].split("\r\n")
    assert kept == ["0 FILE lighthouse.ldr", "0 Lighthouse", "0 Name: lighthouse.ldr", "0 Author: Jane Q. Public",
                    "0 // write to me at jane.public@example.com",
                    "1 4 0 0 0 1 0 0 0 1 0 0 0 1 C:\\Users\\jane\\parts\\3001.dat", "0 NOFILE", ""]
    assert said["file"]["emails"] == 2 and said["file"]["paths"] == 5
    assert said["plainSame"] and said["plain"]["emails"] == 0 and said["plain"]["paths"] == 0
    assert said["notText"]["text"] is None


def test_every_publish_is_held_to_the_rule():
    # The server leaves the lines out of what it keeps, whoever publishes:
    # the app's Share and the connector's come through the same handler.
    text = (ROOT / "api/share.js").read_text(encoding="utf-8")
    body = text[text.index("async function publish(request, response) {"):text.index("async function unpublish(")]
    assert "const model = withoutPrivateLines(body.model).text;" in body
    assert body.count("body.model") == 2  # the rule's input, and the app's finding, hashed as it sent it
