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
// Quality 9 and the size hint, which is what `brotli -q 9` does. Going
// to 11 costs minutes on a 40 MB wasm for about a percent.
writeFileSync(output, brotliCompressSync(bytes, {
  params: {
    [constants.BROTLI_PARAM_QUALITY]: 9,
    [constants.BROTLI_PARAM_SIZE_HINT]: statSync(input).size,
  },
}));
