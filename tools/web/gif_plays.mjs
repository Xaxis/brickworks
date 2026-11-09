// Whether a GIF plays in a browser: Chromium's own decoder reads it, as a
// page, a chat or a forum post in Chrome would (video2, APP_UX6 #11).
//
//   node tools/web/gif_plays.mjs FILE.gif [--frame0=FILE.png]
//
// Headless Chromium on SwiftShader (browser.mjs's flags; nothing here draws
// on the GPU). The GIF is handed to the page as bytes and read twice: by
// ImageDecoder, which says how many frames it has, how long each shows and
// how often it loops, and gives each frame's pixels; and as an <img>, which
// must decode it at its size. Prints one line of JSON: {"ok", "width",
// "height", "frames", "seconds", "loops", "changed", "img"}, where changed is
// how many frames differ from the one before (a GIF that plays is not one
// picture shown over and over). --frame0 writes the first frame as the
// browser drew it, a PNG, to be held against the picture it was made of.
// Exits 0 when the browser read it, 1 when not.
import { chromium } from "playwright";
import { readFileSync, writeFileSync } from "node:fs";
import { SOFTWARE } from "./browser.mjs";

const file = process.argv[2];
const frame0 = (process.argv.find((a) => a.startsWith("--frame0=")) || "").slice(9);
if (!file) {
  console.error("usage: node tools/web/gif_plays.mjs FILE.gif");
  process.exit(2);
}
const b64 = readFileSync(file).toString("base64");
const browser = await chromium.launch({ args: SOFTWARE });
let result = { ok: false };
try {
  const page = await browser.newPage();
  // ImageDecoder is only in a secure context, which about:blank is not: the
  // page is served at an https address of its own, never fetched.
  await page.route("https://gif.check/", (route) =>
    route.fulfill({ contentType: "text/html", body: "<!doctype html><title>gif</title><body></body>" }));
  await page.goto("https://gif.check/");
  result = await page.evaluate(async (data) => {
    const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
    const out = { ok: false };
    if (typeof ImageDecoder !== "function") {
      out.error = "no ImageDecoder in this browser";
      return out;
    }
    const decoder = new ImageDecoder({ data: bytes, type: "image/gif" });
    await decoder.tracks.ready;
    await decoder.completed;
    const track = decoder.tracks.selectedTrack;
    out.frames = track.frameCount;
    out.loops = track.repetitionCount === Infinity ? "for ever" : track.repetitionCount;
    let micros = 0;
    let before = null;
    out.changed = 0;
    const canvas = new OffscreenCanvas(1, 1);
    const context = canvas.getContext("2d", { willReadFrequently: true });
    for (let n = 0; n < track.frameCount; n++) {
      const { image } = await decoder.decode({ frameIndex: n });
      out.width = image.displayWidth;
      out.height = image.displayHeight;
      micros += image.duration || 0;
      canvas.width = image.displayWidth;
      canvas.height = image.displayHeight;
      context.drawImage(image, 0, 0);
      if (n === 0) {
        const blob = await canvas.convertToBlob({ type: "image/png" });
        const raw = new Uint8Array(await blob.arrayBuffer());
        let text = "";
        for (let i = 0; i < raw.length; i += 0x8000) text += String.fromCharCode(...raw.subarray(i, i + 0x8000));
        out.frame0 = btoa(text);
      }
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
      if (before) {
        let differ = 0;
        for (let i = 0; i < pixels.length; i += 4) {
          if (pixels[i] !== before[i] || pixels[i + 1] !== before[i + 1] || pixels[i + 2] !== before[i + 2]) {
            differ++;
          }
        }
        if (differ > pixels.length / 4 / 1000) out.changed++;
      }
      before = pixels;
      image.close();
    }
    out.seconds = micros / 1e6;
    const img = new Image();
    img.src = URL.createObjectURL(new Blob([bytes], { type: "image/gif" }));
    document.body.append(img);
    try {
      await img.decode();
      out.img = `${img.naturalWidth}x${img.naturalHeight}`;
    } catch (error) {
      out.img = `not decoded: ${error}`;
    }
    out.ok = out.frames > 0 && out.img === `${out.width}x${out.height}`;
    return out;
  }, b64);
} catch (error) {
  result = { ok: false, error: String(error) };
} finally {
  await browser.close();
}
if (result.frame0 && frame0) writeFileSync(frame0, Buffer.from(result.frame0, "base64"));
delete result.frame0;
console.log(JSON.stringify(result));
process.exit(result.ok ? 0 : 1);
