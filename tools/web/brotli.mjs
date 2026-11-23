// brotli, for a machine that has not got the command.
//
// The web build ships a .br beside every large file — the wasm is ~40 MB
// raw and ~9 MB compressed — so skipping it is not an option, and on
// Ubuntu the CLI needs a password to install. Node has brotli in its
// standard library and is already needed to prove a deploy, so there is
// no new dependency here, only one fewer.
//
//   node tools/web/brotli.mjs <input> <output>
//   node tools/web/brotli.mjs --cache=DIR <input> <output>
//
// With --cache, a file whose bytes were compressed before is not compressed
// again: DIR keeps each output under the sha256 of its input and the
// settings below. The engine's wasm is the same bytes in every export of one
// Godot, and so are most of the packs, and quality 11 took most of a
// release's two and a half minutes of compressing to make them again
// (fastship, 2026-11-23). A kept output is used only once it decompresses
// to exactly the input's bytes, so a damaged or truncated one is made again,
// never shipped. Kept outputs not used for two days go.

import { mkdirSync, readFileSync, readdirSync, renameSync, statSync, unlinkSync, utimesSync,
  writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { brotliCompressSync, brotliDecompressSync, constants } from "node:zlib";

const KEEP_MS = 2 * 24 * 3600 * 1000;
const args = process.argv.slice(2);
const cacheArg = args.find((a) => a.startsWith("--cache="));
const [input, output] = args.filter((a) => !a.startsWith("--cache="));
if (!input || !output) {
  console.error("brotli: need an input and an output path");
  process.exit(2);
}
const cache = cacheArg ? cacheArg.slice("--cache=".length) : "";

const bytes = readFileSync(input);
const sha = (data) => createHash("sha256").update(data).digest("hex");
const digest = sha(bytes);
// The settings are in the name, and the library's version: a kept output is
// what this very call would make.
const kept = cache ? join(cache, `${digest}.q11w24.${process.versions.brotli}.br`) : "";

function fromCache() {
  let packed;
  try {
    packed = readFileSync(kept);
  } catch {
    return false;
  }
  try {
    if (sha(brotliDecompressSync(packed)) !== digest) throw new Error("not the input's bytes");
  } catch (trouble) {
    console.error(`brotli: ${kept} dropped (${trouble.message}); compressing ${input} again`);
    try { unlinkSync(kept); } catch {}
    return false;
  }
  writeFileSync(output, packed);
  try { const now = new Date(); utimesSync(kept, now, now); } catch {}
  console.log(`  brotli: ${input} from the cache`);
  return true;
}

function keep(packed) {
  try {
    mkdirSync(cache, { recursive: true });
    // Whole, then named: another export reading the same name finds all of
    // it or nothing.
    const part = `${kept}.${process.pid}.part`;
    writeFileSync(part, packed);
    renameSync(part, kept);
    const old = Date.now() - KEEP_MS;
    for (const name of readdirSync(cache)) {
      const path = join(cache, name);
      try { if (statSync(path).mtimeMs < old) unlinkSync(path); } catch {}
    }
  } catch (trouble) {
    console.error(`brotli: could not keep ${input} in ${cache} (${trouble.message})`);
  }
}

if (!(kept && fromCache())) {
  // Quality 11 and the largest window a browser takes, which is what
  // `brotli -q 11 -w 24` does: these are the bytes a visitor waits for
  // (tools/export.sh). 11 makes the wasm 6.9 MB where 9 made 7.9, at about
  // a minute and a half where 9 took seven seconds (load250, 2026-10-24).
  const packed = brotliCompressSync(bytes, {
    params: {
      [constants.BROTLI_PARAM_QUALITY]: 11,
      [constants.BROTLI_PARAM_LGWIN]: 24,
      [constants.BROTLI_PARAM_SIZE_HINT]: statSync(input).size,
    },
  });
  writeFileSync(output, packed);
  if (kept) keep(packed);
}
