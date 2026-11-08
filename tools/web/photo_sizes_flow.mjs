// How large each photo of a real build is drawn against the pixels of the
// picture the browser took for it, every place a photo is drawn, against
// the design stand-in (its photos each the size its row says, their copies
// for the cards made by api/_photo.js cardOf):
//
//   node tools/web/photo_sizes_flow.mjs --out=DIR
//
// streview (2026-11-07) found the cards' copy drawn 1.5 to 2.26 times its
// size: a whole column wide on a profile's Builds, 260 by 190 on a model's
// page, short of height in a 4:3 card for a wide photo. Each place now gives
// the browser the copy and the whole photo (web/card.js photoPicture) and
// takes the whole where a browser took the copy and would draw it larger
// (sharpPhotos: Chrome picks the smaller of two until the geometric mean).
//
// At 390 px at 3x and 1280 px at 2x, signed out: the gallery's Builds tab,
// a profile's Builds tab, a model's page (its strip of pictures and its
// builds) and the feed's Latest; signed in as the stand-in's Sam: the feed's
// photos and Designs on their own profile. Every photo there is drawn no
// larger than its picture (each its own number, "x" the most it is
// stretched: 1.00 or less), unless that picture is the whole photo, the
// largest there is (a 1,080 px photo across the feed's 600 px at 2x).
// At 1280 px at 1x, where the copy is enough, the
// Builds tab's cards and a model page's thumbs take the copy, so the copy
// still does its job. A picture of each page in --out.
import { launch } from "./browser.mjs";
import * as stand from "./design_stand_in.mjs";
import { STORAGE_KEY } from "./session.mjs";
import { mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const out = path.resolve(String(args.out || "shots/photo_sizes"));
mkdirSync(out, { recursive: true });

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];

/// Every photo of a build on [page], each in view in turn so a lazy one is
/// asked for, once it and any whole photo it was given have loaded: {src
/// ("card" or "whole"), css [w, h], natural [w, h] (the picture's own
/// pixels, read apart: an <img> with a srcset says its size over the
/// density it chose), x (the most it is stretched), place}.
async function photosOn(page) {
  const count = await page.evaluate(() => document.querySelectorAll("img").length);
  for (let n = 0; n < count; n++) {
    const asked = await page.evaluate((at) => {
      const img = document.querySelectorAll("img")[at];
      if (!img || !/op=photo_file/.test(img.currentSrc || img.src)) return false;
      img.scrollIntoView({ block: "center", inline: "center" });
      return true;
    }, n);
    if (!asked) continue;
    // Loaded, and still loaded a moment on: sharpPhotos may give it the
    // whole photo after the copy began.
    const end = Date.now() + 15000;
    let steady = 0;
    while (Date.now() < end && steady < 2) {
      const ready = await page.evaluate((at) => {
        const img = document.querySelectorAll("img")[at];
        return Boolean(img && img.complete && img.naturalWidth > 0 && img.currentSrc);
      }, n);
      steady = ready ? steady + 1 : 0;
      await page.waitForTimeout(200);
    }
  }
  return page.evaluate(async (dpr) => Promise.all([...document.querySelectorAll("img")].filter((img) => /op=photo_file/.test(img.currentSrc || img.src))
    .map(async (img) => {
      const box = img.getBoundingClientRect();
      const own = new Image();
      own.src = img.currentSrc;
      await own.decode().catch(() => null);
      const natural = [own.naturalWidth, own.naturalHeight];
      const x = natural[0] && box.width ? Math.max((box.width * dpr) / natural[0], (box.height * dpr) / natural[1]) : Infinity;
      const place = img.closest(".build-card") ? "card" : img.closest(".thumb") ? "thumb" : img.closest(".design-builders") ? "builders"
        : img.closest(".feed-photo") ? "feed" : img.closest(".build-grid") ? "columns" : img.closest(".build-strip") ? "strip" : "other";
      return { src: /size=card/.test(img.currentSrc) ? "card" : "whole", css: [Math.round(box.width), Math.round(box.height)], natural,
        x: Math.round(x * 1000) / 1000, place, id: /id=([A-Za-z0-9]{10})/.exec(img.currentSrc)?.[1] || "" };
    })), await page.evaluate(() => devicePixelRatio));
}

const browser = await launch({ signedOut: true });
const pages = [
  { name: "builds", where: "/builds", shown: ".build-card img" },
  { name: "profile_builds", where: `/u/${stand.HANDLE}?tab=builds`, shown: ".build-grid img" },
  { name: "model", where: `/m/${stand.MODEL_ID}`, shown: ".build-strip img" },
  { name: "latest", where: "/feed", shown: "#latest-photos img" },
  { name: "feed", where: "/feed", signed: true, shown: ".feed-photo img" },
  { name: "designs", where: "/u/sam-builds", signed: true, shown: ".design-builders img" },
];
const worst = {};
try {
  for (const [width, dpr] of [[390, 3], [1280, 2], [1280, 1]]) {
    console.log(`at ${width} px, ${dpr}x`);
    for (const one of pages) {
      // At 1x only what proves the copy is still taken.
      if (dpr === 1 && !["builds", "model"].includes(one.name)) continue;
      const phone = width < 600;
      const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, deviceScaleFactor: dpr,
        ...(phone ? { isMobile: true, hasTouch: true } : {}) });
      await stand.serveSite(context, { web: path.join(root, "web"), api: path.join(root, "api") });
      if (one.signed) {
        // Signed in as the stand-in's Sam.
        const kept = stand.signedInStorage();
        await context.addInitScript(([name, value, access]) => {
          try {
            if (!localStorage.getItem(name)) localStorage.setItem(name, value);
            sessionStorage.setItem("brickworks.access", access);
          } catch {}
        }, [STORAGE_KEY, JSON.stringify(kept.session), JSON.stringify(kept.access)]);
      }
      const page = await context.newPage();
      page.on("pageerror", (e) => errors.push(`${one.name} ${width}@${dpr}: ${String(e).slice(0, 200)}`));
      await page.goto(`${stand.ORIGIN}${one.where}`, { waitUntil: "load" });
      const came = await page.waitForFunction((shown) => Boolean(document.querySelector(shown)), one.shown, { timeout: 30000 })
        .then(() => true).catch(() => false);
      const photos = came ? await photosOn(page) : [];
      // The picture: the place's first photo in the middle of the screen.
      await page.evaluate((shown) => document.querySelector(shown)?.scrollIntoView({ block: "center" }), one.shown);
      await page.waitForTimeout(300);
      await page.screenshot({ path: path.join(out, `${one.name}_${width}_${dpr}x.png`) }).catch(() => null);
      const most = photos.reduce((at, photo) => Math.max(at, photo.x), 0);
      worst[`${one.name} ${width}@${dpr}`] = most;
      for (const photo of photos) {
        console.log(`        ${one.name} ${photo.place} ${photo.id}: drawn ${photo.css.join("x")} css, ${photo.src} ${photo.natural.join("x")}, x ${photo.x.toFixed(2)}`);
      }
      if (dpr === 1) {
        const small = photos.filter((photo) => photo.place === (one.name === "builds" ? "card" : "thumb"));
        check(`${one.name} at ${width} px 1x: ${small.length} ${one.name === "builds" ? "cards" : "thumbs"} take the copy `
          + `(${small.map((photo) => photo.src).join(", ")}), none stretched (most ${most.toFixed(2)})`,
          small.length > 0 && small.every((photo) => photo.src === "card") && most <= 1);
      } else {
        // The whole photo is the most there is: one smaller than its box
        // (a 1,080 px photo in the feed's 600 px at 2x) is drawn as large as
        // it can be, not stretched for want of a larger picture.
        const copies = photos.filter((photo) => photo.src === "card");
        const short = photos.filter((photo) => photo.src === "whole" && photo.x > 1);
        const mostCopy = copies.reduce((at, photo) => Math.max(at, photo.x), 0);
        check(`${one.name} at ${width} px ${dpr}x: ${photos.length} photos, ${copies.length} the copy (most stretched `
          + `${mostCopy.toFixed(2)}), ${photos.length - copies.length} the whole${short.length ? `, ${short.length} of them smaller than its box` : ""}; `
          + `none drawn larger than its picture where a larger one is there (most ${most.toFixed(2)})`,
          photos.length > 0 && photos.every((photo) => photo.x <= 1 || photo.src === "whole"));
      }
      await context.close();
    }
  }
} finally {
  await browser.close();
}
check(`no page error (${errors.length})`, errors.length === 0);
for (const line of errors.slice(0, 5)) console.log(`        ${line}`);
console.log(`worst ${JSON.stringify(worst)}`);
console.log(failed ? `photo sizes flow: ${failed} FAIL` : "photo sizes flow: passed");
process.exit(failed ? 1 : 0);
