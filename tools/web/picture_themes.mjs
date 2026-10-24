// Does a model's picture sit in the site's light theme and its dark one?
// (docs/SOCIAL.md U15)
//
//   node tools/web/picture_themes.mjs --url=https://brickworks.diy --id=<model> --out=shots/themes
//   BW_BYPASS=… node tools/web/picture_themes.mjs --url=<a preview> --id=<model> --tests --out=…
//
// A model's renders sat on a light grey ground the app drew into them, so in
// the dark theme every card and every model page had a bright tile in it.
// Since 2026-10-24 the app draws the site's pictures with nothing behind the
// model, the card's four to three, and the site draws the ground in the
// theme's own colours (site.css --picture-ground). This looks where a person
// does: the model's card in the gallery (found by its name, so it is the
// only one) and its page, at 390 and 1280 px, in each theme, each pictured,
// and a corner of each picture measured on the screen. In the dark theme a
// corner is dark, never the light box; in the light one it is light. And
// the pictures themselves: the card's is four to three with nothing in its
// corners, the page's has nothing in its corners. A model published before
// keeps its old pictures (the light box); --old says to expect that.
//
// share_flow.mjs runs it on the model it publishes (pictureThemes).
import { launch, allPictures } from "./browser.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/// What a picture is, decoded in a browser: {width, height, corners: [alpha
/// of each of its four corners]}, or null when it is none.
async function pictureOf(context, url, headers) {
  const reply = await fetch(url, { headers });
  if (!reply.ok) return null;
  const bytes = Buffer.from(await reply.arrayBuffer());
  const page = await context.newPage();
  try {
    return await page.evaluate(async ([data, type]) => {
      const bitmap = await createImageBitmap(new Blob([Uint8Array.from(atob(data), (c) => c.charCodeAt(0))], { type }));
      const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
      const draw = canvas.getContext("2d");
      draw.drawImage(bitmap, 0, 0);
      const at = (x, y) => draw.getImageData(x, y, 1, 1).data[3];
      const w = bitmap.width - 1;
      const h = bitmap.height - 1;
      return { width: bitmap.width, height: bitmap.height, corners: [at(0, 0), at(w, 0), at(0, h), at(w, h)] };
    }, [bytes.toString("base64"), reply.headers.get("content-type") || "image/png"]);
  } finally {
    await page.close();
  }
}

/// The brightness, 0 to 1, of one point of a screenshot, read in a browser:
/// [y] below 0 counts up from its foot.
async function brightness(context, png, x, y) {
  const page = await context.newPage();
  try {
    return await page.evaluate(async ([data, px, py]) => {
      const bitmap = await createImageBitmap(new Blob([Uint8Array.from(atob(data), (c) => c.charCodeAt(0))], { type: "image/png" }));
      const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
      const draw = canvas.getContext("2d");
      draw.drawImage(bitmap, 0, 0);
      const y = py < 0 ? bitmap.height + py : py;
      const [r, g, b] = draw.getImageData(Math.min(px, bitmap.width - 1), Math.min(y, bitmap.height - 1), 1, 1).data;
      return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
    }, [png.toString("base64"), x, y]);
  } finally {
    await page.close();
  }
}

/// Look at model [id] on [site] in both themes at 390 and 1280: [check]
/// each finding, pictures in [out]. [name] finds its card in the gallery's
/// search; [tests] asks the gallery for test models (a probe's are).
/// [old]: a model published before 2026-10-24, its pictures with their own
/// light ground, which is what the dark theme shows of it.
export async function pictureThemes(browser, { site, id, name, headers = {}, out, check, tests = false, old = false }) {
  const made = await browser.newContext({ extraHTTPHeaders: headers });
  try {
    const card = await pictureOf(made, `${site}/m/${id}.webp`, headers);
    const page = await pictureOf(made, `${site}/m/${id}.cutout.png`, headers);
    if (!old) {
      check(`its card's picture is four to three with nothing in its corners (${card && `${card.width} x ${card.height}, `
        + `corners ${card.corners.join(" ")}`})`, card && card.width * 3 === card.height * 4 && card.corners.every((a) => a === 0));
      check(`its page's picture has nothing in its corners (${page && `${page.width} x ${page.height}, corners ${page.corners.join(" ")}`})`,
        page && page.corners.every((a) => a === 0));
    }
  } finally {
    await made.close();
  }
  for (const width of [390, 1280]) {
    for (const theme of ["light", "dark"]) {
      const phone = width < 600;
      const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
        extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
      try {
        const page = await context.newPage();
        const label = `${width} ${theme}`;
        // Its card, found by its name: the only one.
        await page.goto(`${site}/gallery?q=${encodeURIComponent(name)}${tests ? "&tests=1" : ""}`, { waitUntil: "load", timeout: 120000 });
        await page.waitForFunction(() => ["ready", "broken"].includes(document.documentElement.dataset.gallery), null, { timeout: 60000 });
        await allPictures(page);
        const frame = page.locator(`#models .model[data-id="${id}"] .frame`);
        const cardShot = (await frame.count()) ? await frame.screenshot({ timeout: 60000 }) : null;
        if (out) await page.screenshot({ path: path.join(out, `card_${width}_${theme}.png`), timeout: 60000 }).catch(() => {});
        // Its page.
        await page.goto(`${site}/m/${id}`, { waitUntil: "load", timeout: 120000 });
        await page.waitForFunction(() => {
          const img = document.querySelector(".model-page .picture img");
          return img && img.complete && img.naturalWidth > 0;
        }, null, { timeout: 60000 }).catch(() => {});
        await allPictures(page);
        const big = page.locator(".model-page .picture");
        const pageShot = (await big.count()) ? await big.screenshot({ timeout: 60000 }) : null;
        if (out) await page.screenshot({ path: path.join(out, `page_${width}_${theme}.png`), timeout: 60000 }).catch(() => {});
        // A corner of each, as drawn: the card's lower left (its marks are
        // over the upper), the page's upper left (View in 3D is lower right).
        const ratio = phone ? 2 : 1;
        const cardSaid = cardShot ? await brightness(context, cardShot, 6 * ratio, -6 * ratio) : null;
        const pageSaid = pageShot ? await brightness(context, pageShot, 14 * ratio, 14 * ratio) : null;
        const fits = (said) => said !== null && (theme === "dark" && !old ? said < 0.3 : said > 0.6);
        check(`${label}: its card's picture ${theme === "dark" && !old ? "on the dark ground, no light box" : "on a light ground"}`
          + ` (a corner ${cardSaid === null ? "not found" : cardSaid.toFixed(2)} bright)`, fits(cardSaid));
        check(`${label}: its page's picture ${theme === "dark" && !old ? "on the dark ground, no light box" : "on a light ground"}`
          + ` (a corner ${pageSaid === null ? "not found" : pageSaid.toFixed(2)} bright)`, fits(pageSaid));
      } finally {
        await context.close();
      }
    }
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = Object.fromEntries(process.argv.slice(2).map((a) => {
    const [k, ...rest] = a.replace(/^--/, "").split("=");
    return [k, rest.join("=") || true];
  }));
  const site = new URL(String(args.url || "https://brickworks.diy")).origin;
  const id = String(args.id || "");
  const out = args.out ? String(args.out) : "";
  if (out) mkdirSync(out, { recursive: true });
  const bypass = process.env.BW_BYPASS || "";
  const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
  let failed = 0;
  const check = (what, ok) => {
    console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
    if (!ok) failed += 1;
  };
  const model = await (await fetch(`${site}/api/share?id=${id}`, { headers })).json().catch(() => ({}));
  console.log(`picture themes: ${model.name || "?"} (${id}) at ${site}`);
  const browser = await launch({ signedOut: true });
  try {
    await pictureThemes(browser, { site, id, name: String(args.name || model.name || ""), headers, out, check,
      tests: Boolean(args.tests), old: Boolean(args.old) });
  } finally {
    await browser.close();
  }
  console.log(failed ? `\n${failed} FAILED` : args.old ? "\nits pictures as published before are shown in both themes"
    : "\nits pictures sit in both themes");
  process.exit(failed ? 1 : 0);
}
