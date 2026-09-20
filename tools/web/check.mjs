// Prove a deployed build actually runs, in a real browser.
//
// A successful upload says nothing about whether the engine starts. The
// threaded web build refuses to boot unless the page is cross-origin
// isolated, and that depends on headers the host has to send — exactly
// the kind of failure that looks like a successful deploy from here and
// a blank page to everyone else.
//
// So this loads the real URL, waits for the canvas to show something
// other than the loading colour, and fails loudly if it does not.
//
//   node tools/web/check.mjs --url=https://... [--out=shots/deploy.png]

import { chromium } from "playwright";

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, ...rest] = a.replace(/^--/, "").split("=");
    return [k, rest.join("=") || true];
  }),
);

if (!args.url) {
  console.error("check: --url is required");
  process.exit(2);
}

const out = args.out || "shots/deploy.png";
const budget = Number(args.timeout || 120000);

const browser = await chromium.launch({
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

// A preview deployment is behind the team's sign-in, so without this the
// check would load a login page, find no canvas, and report that the
// build does not run. The bypass is for automation only: previews stay
// protected for anyone arriving with a browser, and production is on a
// custom domain, which the protection does not cover anyway.
if (args.bypass) {
  await page.setExtraHTTPHeaders({ "x-vercel-protection-bypass": args.bypass });
}

const problems = [];
page.on("console", (m) => {
  if (m.type() === "error") problems.push(m.text().slice(0, 200));
});
page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));

let failed = null;
try {
  const response = await page.goto(args.url, {
    waitUntil: "domcontentloaded",
    timeout: budget,
  });
  if (!response || !response.ok()) {
    throw new Error(`HTTP ${response ? response.status() : "no response"}`);
  }

  // Cross-origin isolation is what the threaded build needs; report it
  // either way, because "works but single-threaded" is worth knowing.
  const isolated = await page.evaluate(() => globalThis.crossOriginIsolated === true);
  console.log(`crossOriginIsolated: ${isolated}`);

  await page.waitForSelector("canvas", { timeout: budget });

  // Wait for the canvas to stop being one flat colour. Godot paints the
  // loading background first, so "has any variation" is the signal that
  // the engine is running and drawing the scene.
  await page.waitForFunction(
    () => {
      const canvas = document.querySelector("canvas");
      if (!canvas || !canvas.width) return false;
      const probe = document.createElement("canvas");
      probe.width = 64;
      probe.height = 36;
      const ctx = probe.getContext("2d");
      try {
        ctx.drawImage(canvas, 0, 0, 64, 36);
        const { data } = ctx.getImageData(0, 0, 64, 36);
        let min = 255;
        let max = 0;
        for (let i = 0; i < data.length; i += 4) {
          const v = (data[i] + data[i + 1] + data[i + 2]) / 3;
          if (v < min) min = v;
          if (v > max) max = v;
        }
        return max - min > 18;
      } catch {
        return false;
      }
    },
    // Options are waitForFunction's THIRD argument; passing them second
    // makes them the function's argument and silently leaves the timeout
    // at the 30 s default, which a software-rendered WebGL build misses.
    undefined,
    { timeout: budget, polling: 1000 },
  );

  await page.waitForTimeout(3000);
  await page.screenshot({ path: out });
  console.log(`check ok: the build runs at ${args.url}`);
} catch (error) {
  failed = error;
  try {
    await page.screenshot({ path: out });
  } catch {}
}

await browser.close();

if (problems.length) {
  console.log("browser reported:");
  for (const p of problems.slice(0, 8)) console.log(`  ${p}`);
}
if (failed) {
  console.error(`check FAILED: ${failed.message}`);
  process.exit(1);
}
