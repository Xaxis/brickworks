// A minifigure avatar as one picture (avatarkit, 2026-11-23): the one made
// from a person's handle (web/card.js minifigOf), for whoever asks for it by
// address rather than draws it from its layers as the site's pages do: a
// search engine's image of the person (api/people.js profile JSON-LD), a
// share card. Its layers are the site's own (web/minifig/256, drawn by
// tools/web/minifig_layers.mjs), beside the function as _minifig/
// (tools/package_api.sh) or in the checkout's web/; each decoded, laid over
// the avatar's colour, and made a JPEG, kept in the function a while.

import { readFile } from "node:fs/promises";
import { decodePicture, encodeJpeg } from "./_photo.js";
import { MINIFIG, minifigLayers } from "./_card.js";

export const MINIFIG_SIDE = 256;
const QUALITY = 88;
const KEPT = 200;
const made = new Map();

async function layerBytes(name) {
  for (const at of [new URL(`./_minifig/${name}`, import.meta.url), new URL(`../web/minifig/${MINIFIG_SIDE}/${name}`, import.meta.url)]) {
    try {
      return await readFile(at);
    } catch { /* the next place */ }
  }
  throw new Error(`minifig: no layer ${name}`);
}

/// [recipe] (web/card.js minifigShape) drawn as one square JPEG,
/// MINIFIG_SIDE a side, on its background colour.
export async function minifigJpeg(recipe) {
  const key = JSON.stringify(recipe);
  if (made.has(key)) return made.get(key);
  const side = MINIFIG_SIDE;
  const out = new Uint8Array(side * side * 4);
  const hex = MINIFIG.backgrounds[recipe.background - 1] || MINIFIG.backgrounds[7];
  const ground = [1, 3, 5].map((at) => parseInt(hex.slice(at, at + 2), 16));
  for (let p = 0; p < side * side; p++) out.set([...ground, 255], p * 4);
  const files = minifigLayers(recipe, side).map((file) => file.split("/").pop()).reverse();
  for (const name of files) {
    const layer = await decodePicture(await layerBytes(name), "image/webp");
    if (layer.width !== side || layer.height !== side) throw new Error(`minifig: ${name} is not ${side} a side`);
    const from = layer.data;
    for (let i = 0; i < side * side * 4; i += 4) {
      const a = from[i + 3] / 255;
      if (a === 0) continue;
      for (let c = 0; c < 3; c++) out[i + c] = Math.round(from[i + c] * a + out[i + c] * (1 - a));
    }
  }
  const jpeg = Buffer.from(encodeJpeg({ data: out, width: side, height: side }, QUALITY).data);
  if (made.size >= KEPT) made.delete(made.keys().next().value);
  made.set(key, jpeg);
  return jpeg;
}
