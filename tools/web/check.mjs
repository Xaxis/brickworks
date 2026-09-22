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

/// A small fingerprint of what the canvas is showing.
///
/// Downscaled hard, because the question is only "did the view change",
/// and a full-resolution comparison would also answer yes to a shadow
/// moving by a pixel.
async function frameOf(page) {
  return page.evaluate(() => {
    const canvas = document.querySelector("canvas");
    const probe = document.createElement("canvas");
    probe.width = 32;
    probe.height = 18;
    const ctx = probe.getContext("2d");
    ctx.drawImage(canvas, 0, 0, 32, 18);
    const { data } = ctx.getImageData(0, 0, 32, 18);
    const out = [];
    for (let i = 0; i < data.length; i += 4) {
      out.push((data[i] + data[i + 1] + data[i + 2]) / 3);
    }
    return out;
  });
}

/// How different two fingerprints are, as average brightness per cell.
function differ(a, b) {
  let total = 0;
  for (let i = 0; i < a.length; i += 1) total += Math.abs(a[i] - b[i]);
  return total / a.length;
}

/// Does each gesture move the view?
///
/// Aimed at the middle of the window, which is the 3D view: the parts
/// bin and the assistant take the sides.
async function controls(page, problems) {
  const box = page.viewportSize();
  const at = { x: Math.round(box.width / 2), y: Math.round(box.height / 2) };
  // Gestures are only worth anything if there is something on screen to
  // move, and a build that opened an empty autosave would pass every
  // one of them trivially.
  const still = await frameOf(page);
  const variation = Math.max(...still) - Math.min(...still);
  if (variation < 18) {
    problems.push("controls: nothing on screen to move");
    return;
  }

  const gestures = [
    ["turn (right-drag)", async () => {
      await page.mouse.move(at.x, at.y);
      await page.mouse.down({ button: "right" });
      for (let n = 1; n <= 8; n += 1) {
        await page.mouse.move(at.x + n * 20, at.y + n * 4);
      }
      await page.mouse.up({ button: "right" });
    }],
    ["zoom (wheel)", async () => {
      await page.mouse.move(at.x, at.y);
      // Outward. Zooming in on a model that already fills the view
      // barely changes what is on screen; pulling back shrinks it
      // against the background, which is unmistakable.
      //
      // Spaced out, too: Godot reads input once a frame, and a burst of
      // wheel events delivered in the same millisecond is not what a
      // hand does with a wheel.
      for (let n = 0; n < 7; n += 1) {
        await page.mouse.wheel(0, 120);
        await page.waitForTimeout(90);
      }
    }],
    ["slide (shift and scroll)", async () => {
      await page.mouse.move(at.x, at.y);
      await page.keyboard.down("Shift");
      for (let n = 0; n < 6; n += 1) {
        await page.mouse.wheel(0, -120);
        await page.waitForTimeout(90);
      }
      await page.keyboard.up("Shift");
    }],
    ["turn (middle-drag)", async () => {
      await page.mouse.move(at.x, at.y);
      await page.mouse.down({ button: "middle" });
      for (let n = 1; n <= 8; n += 1) {
        await page.mouse.move(at.x - n * 20, at.y);
      }
      await page.mouse.up({ button: "middle" });
    }],
  ];

  for (const [what, doing] of gestures) {
    // Put the view back first.
    //
    // Each gesture leaves the camera somewhere else, and the next one
    // is then measured from wherever the last one finished. Zooming out
    // made everything small, so every gesture after it moved almost no
    // pixels and read as broken — a test that fails because of the test
    // before it. 0 is the default angle and F frames the model; neither
    // touches a brick.
    await page.keyboard.press("Digit0");
    await page.keyboard.press("KeyF");
    // Settled before measuring, not only after: the camera eases
    // towards where it is going, so a baseline taken mid-flight is
    // compared against a view that was going to change anyway.
    await page.waitForTimeout(1400);
    const before = await frameOf(page);
    await doing();
    await page.waitForTimeout(1200);
    const after = await frameOf(page);
    const moved = differ(before, after);
    // The number, not just the verdict. "Changed nothing" is a claim
    // about a threshold and the threshold is a guess; printing what was
    // measured is what makes a surprising result diagnosable instead of
    // an argument.
    if (moved < 2.0) {
      problems.push(`controls: ${what} changed nothing (${moved.toFixed(1)})`);
      console.log(`  FAIL  ${what} — moved ${moved.toFixed(1)}`);
    } else {
      console.log(`  ok    ${what} — moved ${moved.toFixed(1)}`);
    }
  }
}

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
// Things that mean the deployment is wrong, as opposed to noisy.
const broken = [];
page.on("console", (m) => {
  if (m.type() === "error") problems.push(m.text().slice(0, 200));
});
page.on("pageerror", (e) => problems.push(String(e).slice(0, 200)));

// And which resource, which the console line does not say.
//
// A failed fetch arrives as "Failed to load resource: the server
// responded with a status of 404 ()" — no URL, so the one thing worth
// knowing is the one thing missing. Chasing a message that names
// nothing has cost this project real time more than once.
page.on("requestfailed", (r) => {
  problems.push(`request failed: ${r.url().slice(0, 160)} — ${
    r.failure()?.errorText ?? "no reason given"}`);
});
page.on("response", (r) => {
  if (r.status() >= 400) {
    broken.push(`HTTP ${r.status()}: ${r.url().slice(0, 160)}`);
  }
});

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
  console.log(`the build runs at ${args.url}`);

  // And that the view controls do something.
  //
  // The whole reason this exists: the camera listened for a mouse wheel
  // and a middle button, a browser sends neither for a trackpad, and
  // every test in the project drove the camera by calling its methods —
  // so nothing noticed that nobody could turn, slide or zoom the model.
  // Reaching the deployed build through a real browser is the only
  // place that could have been caught.
  await controls(page, problems);
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
// A page that asks for something and is told 404 is a broken
// deployment, whatever else works.
//
// These were collected and printed and then ignored, so a build where
// every part outside the shipped pack came back 404 — which is most of
// the library — passed as "the build runs". It does run. It just
// cannot fetch a brick.
if (broken.length) {
  const seen = [...new Set(broken)];
  console.error(`check FAILED: ${seen.length} request(s) the page `
    + "made came back as errors");
  for (const b of seen.slice(0, 8)) console.error(`  ${b}`);
  process.exit(1);
}
// Said once, at the end, after everything that could contradict it.
// It used to be printed the moment the canvas appeared, so a run that
// went on to fail announced itself as ok first.
console.log(`check ok: ${args.url}`);
