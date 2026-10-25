// brotli, for a machine that has not got the command.
//
// The web build ships a .br beside every large file — the wasm is ~40 MB
// raw and ~9 MB compressed — so skipping it is not an option, and on
// Ubuntu the CLI needs a password to install. Node has brotli in its
// standard library and is already needed to prove a deploy, so there is
// no new dependency here, only one fewer.
//
//   node tools/web/brotli.mjs <input> <output>

import { readFileSync, writeFileSync, statSync } from "node:fs";
import { brotliCompressSync, constants } from "node:zlib";

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error("brotli: need an input and an output path");
  process.exit(2);
}

const bytes = readFileSync(input);
// Quality 11 and the largest window a browser takes, which is what
// `brotli -q 11 -w 24` does: these are the bytes a visitor waits for
// (tools/export.sh). 11 makes the wasm 6.9 MB where 9 made 7.9, at about
// a minute and a half where 9 took seven seconds (load250, 2026-10-24).
writeFileSync(output, brotliCompressSync(bytes, {
  params: {
    [constants.BROTLI_PARAM_QUALITY]: 11,
    [constants.BROTLI_PARAM_LGWIN]: 24,
    [constants.BROTLI_PARAM_SIZE_HINT]: statSync(input).size,
  },
}));
