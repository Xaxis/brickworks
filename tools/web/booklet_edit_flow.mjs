// The booklet edited by hand in a real browser, as a designer edits one in
// Studio's Instruction Maker: a real set opened with its designer's steps,
// a step turned and zoomed, a new page and a page alone, a parts list left
// off, steps a page, a merge undone, all by the timeline's buttons and the
// keys; then the booklet made from those choices and the file saved.
//
//   python3 tools/web/serve.py build/web 8841 --parts assets/generated/parts --delay 0 &
//   node tools/web/booklet_edit_flow.mjs --url=http://127.0.0.1:8841/index.html --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/booklet_edit_flow.mjs --url=https://<a preview>/app
//
// Opens vendor/omr/files/106-1.mpd (--model=FILE for another) through
// Open… > From a file. Timeline comes up in the author's steps; Right
// arrow to step 3, Turn right and Zoom in on the Booklet row (the row's line
// says "turned 45°, zoom 1.25x"); Ctrl-Z takes the zoom off and Ctrl-Shift-Z
// puts it back, one undo each; step 4 New page, step 5 Alone and Parts
// list off; Per page twice, "2"; Merge with next on step 6 and Ctrl-Z. Then
// the timeline's Instructions: in the tab that opens, step 4 heads a page,
// step 5 is alone on one with no parts box, no page has more than two
// steps, and the PDF printed from it has the booklet's pages. File > Export
// > LDraw model: Python reads the ROTSTEP and the app's own lines in it.
// Then step 4's page by hand in Lay out page…: its picture dragged by the
// mouse onto the top margin, which it snaps to; its parts list widened by its
// corner; words added and typed; a picture added through the file chooser;
// Ctrl-Z and Ctrl-Shift-Z on it; Draw an arrow and a drag from below its
// picture to its middle, Ctrl-Z and Ctrl-Shift-Z. The booklet's page 4
// (the arrow printed on it) and the file (ARROW and the step's PANEL) say so.
// Fails if any of that does not happen or a script error reaches a console.
// Every result read off window.brickworksState; pictures in --out.
import { launch } from "./browser.mjs";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = args.url || "http://127.0.0.1:8841/index.html";
const bypass = args.bypass || process.env.BW_BYPASS || "";
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = resolve(args.out || "shots/booklet_edit_web");
mkdirSync(out, { recursive: true });
const model = resolve(args.model || "vendor/omr/files/106-1.mpd");

const t0 = Date.now();
const said = [];
const errors = [];
const ok = (passed, line) => {
  const text = `  ${passed ? "ok  " : "FAIL"}  ${line}  [${Math.round((Date.now() - t0) / 1000)}s]`;
  said.push(text);
  console.log(text);
  return passed;
};

const browser = await launch();
const context = await browser.newContext({ viewport: { width: 1600, height: 900 }, acceptDownloads: true });
const page = await context.newPage();
page.choosers = [];
page.on("filechooser", (chooser) => page.choosers.push(chooser));
const listen = (p, who) => {
  p.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  p.on("console", (m) => {
    if (/SCRIPT ERROR|USER ERROR|Parse Error|Content Security Policy/i.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 300)}`);
    }
  });
};
listen(page, "app");

const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
async function shot(name) {
  try {
    await page.screenshot({ path: `${out}/${name}`, timeout: 180000 });
    console.log(`        picture: ${out}/${name}`);
  } catch (e) {
    console.log(`  --    no picture ${name}: ${String(e).split("\n")[0]}`);
  }
}
async function until(test, seconds) {
  let now = await state();
  for (let n = 0; n < seconds * 2; n++) {
    if (test(now)) return now;
    await page.waitForTimeout(500);
    now = await state();
  }
  return test(now) ? now : null;
}
async function where(name, seconds = 240) {
  for (let n = 0; n < seconds * 2; n++) {
    const at = (await controls())[name];
    if (at) return at;
    await page.waitForTimeout(500);
  }
  await shot(`never_${name}.png`);
  throw new Error(`the app never showed "${name}"`);
}
async function press(name) {
  const at = await where(name);
  await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(1500);
}
const timeline = async () => (await state()).timeline || {};
const look = async () => (await timeline()).look || "";
// The row as it says once it says what the test wants, or as it last said:
// the page is told what the window says twice a second, so a row read once
// straight after a press can still say the step before it (m73's preview).
async function says(test, seconds = 15) {
  let now = await look();
  for (let n = 0; n < seconds * 2 && !test(now); n++) {
    await page.waitForTimeout(500);
    now = await look();
  }
  return now;
}
async function open(file) {
  const at = await where("open");
  for (let n = 0; n < 3; n++) {
    page.choosers.length = 0;
    await page.mouse.click(at.x, at.y);
    await page.waitForTimeout(4000 + 4000 * n);
    await page.mouse.click(at.x + 40, at.y + 22);
    for (let wait = 0; wait < 60 && page.choosers.length === 0; wait++) {
      await page.waitForTimeout(500);
    }
    const picker = page.choosers.shift();
    if (picker) {
      await picker.setFiles(file);
      return;
    }
    await shot(`no_picker_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  throw new Error("no file picker came up");
}
async function exportLdraw() {
  const file = await where("menu_file");
  for (let n = 0; n < 3; n++) {
    const download = page.waitForEvent("download", { timeout: 90000 }).catch(() => null);
    await page.mouse.click(file.x, file.y);
    await page.waitForTimeout(2500 + 2500 * n);
    await page.keyboard.type("Export", { delay: 120 });
    await page.waitForTimeout(800);
    await page.keyboard.press("ArrowRight");
    await page.waitForTimeout(1500);
    await page.keyboard.type("LDraw", { delay: 120 });
    await page.waitForTimeout(800);
    await page.keyboard.press("Enter");
    const got = await download;
    if (got) return got;
    await shot(`no_download_${n}.png`);
    await page.keyboard.press("Escape");
    await page.waitForTimeout(3000);
  }
  return null;
}
// Right arrow until the timeline shows step [number] (the window's own key).
async function toStep(number) {
  for (let n = 0; n < 40; n++) {
    const caption = (await timeline()).caption || "";
    const at = Number((caption.match(/^Step (\d+)/) || [])[1] || 0);
    if (at === number) return true;
    await page.keyboard.press(at < number ? "ArrowRight" : "ArrowLeft");
    await page.waitForTimeout(900);
  }
  return false;
}

try {
  await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
  ok(Boolean(await where("open", 400)), "the app came up");
  await page.waitForTimeout(Number(args.load || 15000));

  let note = null;
  for (let attempt = 0; attempt < 3; attempt++) {
    await open(model);
    note = await until((s) => /^opened \d+ parts/.test(s.said || ""), 240);
    if (note && !/arriving/.test(note.said)) break;
    await page.waitForTimeout(20000);
  }
  await until((s) => (s.bricks || 0) > 0 && !s.awaited, 240);
  ok((await state()).bricks > 20, `${model.split("/").pop()} opened through Open… > From a file: ${(await state()).bricks} parts`);

  await press("tool_timeline");
  const up = await until((s) => (s.timeline || {}).caption, 60);
  const total = Number((((up || {}).timeline || {}).caption || "").match(/of (\d+)/)?.[1] || 0);
  ok(Boolean(up) && up.timeline.order === "Author's steps",
    `Timeline in the author's steps: ${up ? `"${up.timeline.caption}"` : "nothing"}`);
  // The window's keys walk the steps.
  await page.mouse.move(800, 300);
  ok(await toStep(3), `Right arrow to step 3: "${(await timeline()).caption}"`);

  await press("booklet_turn_right");
  const turned = await says((l) => /turned 45°/.test(l));
  ok(/turned 45°/.test(turned), `Turn right: the row says "${turned}"`);
  await press("booklet_zoom_in");
  const zoomed = await says((l) => /zoom 1\.25x/.test(l));
  ok(/zoom 1\.25x/.test(zoomed), `Zoom in: "${zoomed}"`);
  await shot("1_step_3_turned_zoomed.png");
  await page.keyboard.press("Control+z");
  const undone = await says((l) => !/zoom/.test(l) && /turned 45°/.test(l));
  ok(!/zoom/.test(undone) && /turned 45°/.test(undone),
    `Ctrl-Z takes the zoom off and only that: "${undone}"`);
  await page.keyboard.press("Control+Shift+z");
  const redone = await says((l) => /zoom 1\.25x/.test(l));
  ok(/zoom 1\.25x/.test(redone), `Ctrl-Shift-Z puts it back: "${redone}"`);

  ok(await toStep(4), `step 4: "${(await timeline()).caption}"`);
  await press("booklet_new_page");
  const paged = await says((l) => /new page/.test(l));
  ok(/new page/.test(paged), `New page: "${paged}"`);
  ok(await toStep(5), `step 5: "${(await timeline()).caption}"`);
  await press("booklet_alone");
  await press("booklet_parts");
  const alone = await says((l) => /a page alone/.test(l) && /no parts list/.test(l));
  ok(/a page alone/.test(alone) && /no parts list/.test(alone), `Alone and Parts list off: "${alone}"`);
  await press("booklet_per_page");
  await press("booklet_per_page");
  // Waited for: the page is told what the window says twice a second, and
  // read once straight after the press it said the first press's "1".
  const twice = await until((s) => /steps a page: 2/.test(s.said || ""), 10);
  ok(Boolean(twice), `Per page twice: "${(await state()).said}"`);
  await shot("2_step_5_alone.png");

  ok(await toStep(6), `step 6: "${(await timeline()).caption}"`);
  await press("steps_merge");
  const merged = await until((s) => new RegExp(`of ${total - 1}\\b`).test((s.timeline || {}).caption || ""), 30);
  ok(Boolean(merged), `Merge with next: "${(await timeline()).caption}"`);
  await page.keyboard.press("Control+z");
  const unmerged = await until((s) => new RegExp(`of ${total}\\b`).test((s.timeline || {}).caption || ""), 30);
  ok(Boolean(unmerged), `Ctrl-Z unmerges: "${(await timeline()).caption}"`);
  const back5 = await toStep(5);
  const still = await says((l) => /a page alone/.test(l));
  ok(back5 && /a page alone/.test(still), `...and step 5 is still alone: "${still}"`);

  // The page by hand: step 4's page in Lay out page…, its picture dragged by
  // the mouse and let go a millimetre and a half below the top margin, which
  // it snaps onto; its parts list widened by its corner; words added and
  // typed; a picture added from a file; Ctrl-Z and Ctrl-Shift-Z on it.
  ok(await toStep(4), `step 4 for its page: "${(await timeline()).caption}"`);
  await press("booklet_lay_out");
  const editor = async () => (await state()).page_editor || {};
  const laid = async (test, seconds = 60) => {
    for (let n = 0; n < seconds * 2; n++) {
      const now = await editor();
      if (now.items && !now.laying && test(now)) return now;
      await page.waitForTimeout(500);
    }
    return null;
  };
  const opened4 = await laid((s) => (s.steps || []).includes(4));
  ok(Boolean(opened4), `Lay out page… opens step 4's page: ${opened4 ? `page ${opened4.page}, steps ${opened4.steps}, ${Object.keys(opened4.items).length} items` : "nothing"}`);
  if (opened4) {
    await shot("3_page_editor_before.png");
    const canvas = await where("page_canvas");
    const k = canvas.w / 269; // CSS px a millimetre of page
    const picture = "page_picture_4";
    const was = opened4.items[picture];
    const from = await where(picture);
    const by = { x: 30, y: 9 + 1.5 - was[1] };
    await page.mouse.move(from.x, from.y);
    await page.mouse.down();
    for (let n = 1; n <= 10; n++) {
      await page.mouse.move(from.x + by.x * k * n / 10, from.y + by.y * k * n / 10);
      await page.waitForTimeout(120);
    }
    await page.mouse.up();
    // Past the frames that still show the drag, to the page laid out again.
    await page.waitForTimeout(2500);
    const moved = await laid((s) => s.items[picture] && Math.abs(s.items[picture][0] - was[0]) > 5);
    const now = moved ? moved.items[picture] : null;
    ok(Boolean(now) && Math.abs(now[1] - 9) < 0.05,
      `step 4's picture dragged from ${was.slice(0, 2)} by ${by.x}, ${by.y.toFixed(1)} mm: at ${now ? now.slice(0, 2) : "nowhere"}, snapped onto the top margin (9 mm)`);
    const parts = "page_parts_4";
    if (moved && moved.items[parts]) {
      const box = await where(parts);
      await page.mouse.click(box.x, box.y);
      ok(Boolean(await laid((s) => s.selected === parts)), `a click on the parts list selects it`);
      // Its corner, from the box itself: the handle's place as last told can
      // still be the picture's corner while the page's pictures are drawn
      // (a slow frame on SwiftShader), and a drag there sized the picture.
      const corner = { x: box.x + box.w / 2, y: box.y + box.h / 2 };
      const narrow = moved.items[parts][2];
      await page.mouse.move(corner.x, corner.y);
      await page.mouse.down();
      for (let n = 1; n <= 8; n++) {
        await page.mouse.move(corner.x + 24 * k * n / 8, corner.y);
        await page.waitForTimeout(120);
      }
      await page.mouse.up();
      await page.waitForTimeout(2500);
      const wider = await laid((s) => s.items[parts] && s.items[parts][2] > narrow + 10);
      ok(Boolean(wider), `the parts list's corner dragged 24 mm: ${narrow} to ${wider ? wider.items[parts][2] : "unchanged"} mm wide`);
    }
    await press("page_add_text");
    const worded = await laid((s) => Object.keys(s.items).some((n) => n.startsWith("page_text_4")));
    ok(Boolean(worded), `Add words puts words on the page: ${worded ? Object.keys(worded.items).filter((n) => n.startsWith("page_text")) : "none"}`);
    await page.keyboard.type("Build both sides alike", { delay: 40 });
    await page.keyboard.press("Enter");
    await page.waitForTimeout(2500);
    const picker = new Promise((done) => {
      page.once("filechooser", done);
    });
    page.choosers.length = 0;
    await press("page_add_image");
    const chooser = await Promise.race([picker, page.waitForTimeout(20000).then(() => null)]);
    if (chooser) await chooser.setFiles(resolve("assets/icon.png"));
    const pictured = await laid((s) => Object.keys(s.items).some((n) => n.startsWith("page_image_4")));
    ok(Boolean(pictured), `Add a picture… from a file puts it on the page (${chooser ? "a file chooser came up" : "no file chooser"})`);
    await page.waitForTimeout(3000);
    await shot("4_page_editor_after.png");
    await page.keyboard.press("Control+z");
    const unpictured = await laid((s) => !Object.keys(s.items).some((n) => n.startsWith("page_image_4")));
    ok(Boolean(unpictured), "Ctrl-Z takes the picture off, and only that");
    await page.keyboard.press("Control+Shift+z");
    const repictured = await laid((s) => Object.keys(s.items).some((n) => n.startsWith("page_image_4")));
    ok(Boolean(repictured), "Ctrl-Shift-Z puts it back");
    // An arrow of the designer's: Draw an arrow, then a drag on the page from
    // below and left of step 4's picture to its middle.
    const box = repictured ? repictured.items[picture] : null;
    if (box) {
      const sheet = await where("page_canvas");
      const left = sheet.x - sheet.w / 2;
      const top = sheet.y - sheet.h / 2;
      const tip = { x: box[0] + box[2] / 2, y: box[1] + box[3] / 2 };
      const tail = { x: Math.max(12, tip.x - 45), y: Math.min(180, tip.y + 35) };
      await press("page_add_arrow");
      ok(Boolean(await laid((s) => s.arrow_mode)), "Draw an arrow: the page is ready to draw on");
      await page.mouse.move(left + tail.x * k, top + tail.y * k);
      await page.mouse.down();
      for (let n = 1; n <= 10; n++) {
        await page.mouse.move(left + (tail.x + (tip.x - tail.x) * n / 10) * k,
          top + (tail.y + (tip.y - tail.y) * n / 10) * k);
        await page.waitForTimeout(120);
      }
      await page.mouse.up();
      const drawn = await laid((s) => Object.keys(s.arrows || {}).length > 0);
      const arrow = drawn ? Object.values(drawn.arrows)[0] : null;
      ok(Boolean(arrow) && Math.hypot(arrow.at[2] - tip.x, arrow.at[3] - tip.y) < 3,
        `an arrow dragged from ${tail.x.toFixed(0)}, ${tail.y.toFixed(0)} to ${tip.x.toFixed(0)}, ${tip.y.toFixed(0)} mm: ${arrow ? JSON.stringify(arrow) : "none"}`);
      await shot("5_page_editor_arrow.png");
      await page.keyboard.press("Control+z");
      ok(Boolean(await laid((s) => Object.keys(s.arrows || {}).length === 0)), "Ctrl-Z takes the arrow off");
      await page.keyboard.press("Control+Shift+z");
      ok(Boolean(await laid((s) => Object.keys(s.arrows || {}).length === 1)), "Ctrl-Shift-Z puts it back");
    }
    await press("page_done");
  }

  // The booklet from those choices, in the tab the timeline's Instructions opens.
  const opened = context.waitForEvent("page", { timeout: 30000 });
  await press("steps_booklet");
  let tab = null;
  try {
    tab = await opened;
  } catch {
    tab = null;
  }
  ok(tab !== null, "the timeline's Instructions opens a tab");
  if (tab) {
    listen(tab, "booklet");
    const started = Date.now();
    let pages = 0;
    while (Date.now() - started < Number(args.wait || 900) * 1000) {
      pages = await tab.evaluate(() => document.querySelectorAll("section.page").length).catch(() => 0);
      if (pages > 0) break;
      await tab.waitForTimeout(2000);
    }
    ok(pages > 0, `the booklet arrives (${pages} pages, ${Math.round((Date.now() - started) / 1000)} s)`);
    await tab.waitForLoadState("load").catch(() => {});
    const facts = await tab.evaluate(() => [...document.querySelectorAll("section.page.steps")].map((s) => ({
      id: s.id,
      steps: (s.dataset.steps || "").split(" ").filter(Boolean).map(Number),
      boxes: s.querySelectorAll(".box").length,
    })));
    const of = (n) => facts.find((p) => p.steps.includes(n));
    const four = of(4);
    const five = of(5);
    ok(four && four.steps[0] === 4, `step 4 heads its page (${four ? `${four.id}: ${four.steps.join(",")}` : "none"})`);
    ok(five && five.steps.length === 1 && five.boxes === 0,
      `step 5 alone on its page, no parts box (${five ? `${five.id}: ${five.steps.join(",")}, ${five.boxes} boxes` : "none"})`);
    const most = Math.max(...facts.map((p) => p.steps.length));
    ok(most <= 2, `no page of more than two steps (${most})`);
    // The page laid out by hand, as printed.
    const byHand = four ? await tab.evaluate((id) => {
      const s = document.getElementById(id);
      const img = [...s.querySelectorAll("img.a")].find((i) => /Step 4/.test(i.alt));
      return {
        top: img ? img.style.getPropertyValue("--y") : "",
        words: s.innerText.includes("Build both sides alike"),
        picture: [...s.querySelectorAll("img.a")].some((i) => i.src.startsWith("data:image/png")),
        arrows: s.querySelectorAll("path.drawn-arrow").length,
      };
    }, four.id) : {};
    ok(parseFloat(byHand.top) === 9 && byHand.words && byHand.picture,
      `step 4's page as dragged: its picture at the top margin (--y ${byHand.top}), the words and the picture on it`);
    ok(byHand.arrows === 1, `...and the arrow drawn on it, printed (${byHand.arrows})`);
    await tab.setViewportSize({ width: 1060, height: 800 });
    await tab.addStyleTag({ content: ".bar { display: none !important; }" });
    for (const p of [three(facts), four, five].filter(Boolean)) {
      await tab.locator(`#${p.id}`).screenshot({ path: `${out}/${p.id}.png` }).catch(() => {});
    }
    await tab.emulateMedia({ media: "print" });
    const pdf = `${out}/booklet.pdf`;
    await tab.pdf({ path: pdf, format: "A4", landscape: true, printBackground: true, preferCSSPageSize: true });
    const printed = (readFileSync(pdf, "latin1").match(/\/Type\s*\/Page[^s]/g) || []).length;
    ok(printed === pages, `printed to PDF, ${printed} pages, the booklet's ${pages}`);
    await tab.close();
  }

  await press("steps_done");
  const download = await exportLdraw();
  ok(Boolean(download), `File > Export > LDraw model downloads ${download ? download.suggestedFilename() : "nothing"}`);
  if (download) {
    const saved = `${out}/edited.mpd`;
    await download.saveAs(saved);
    const lines = execFileSync("python3", ["-I", "-c", `
import json, sys
text = open(sys.argv[1], encoding="utf-8").read()
want = ["0 ROTSTEP 0 45 0 REL", "0 !BRICKWORKS ZOOM 1.25", "0 !BRICKWORKS PAGE NEW",
        "0 !BRICKWORKS PAGE ALONE", "0 !BRICKWORKS PARTS OFF", "0 !BRICKWORKS PER_PAGE 2"]
have = [l.strip() for l in text.splitlines()]
found = {w: w in have for w in want}
# The page by hand: the picture placed at the top margin, the parts list
# widened, the words, and the picture with its embedded file.
found["PLACE PICTURE x 9"] = any(l.startswith("0 !BRICKWORKS PLACE PICTURE ") and l.split()[5] == "9" for l in have)
found["PLACE PARTS"] = any(l.startswith("0 !BRICKWORKS PLACE PARTS ") for l in have)
found["TEXT"] = any(l.startswith("0 !BRICKWORKS TEXT ") and l.endswith("Build both sides alike") for l in have)
found["IMAGE"] = any(l.startswith("0 !BRICKWORKS IMAGE ") for l in have)
found["!DATA"] = any(l.startswith("0 !DATA brickworks-page-") for l in have)
found["ARROW"] = any(l.startswith("0 !BRICKWORKS ARROW RED 0.9 ") for l in have)
found["PANEL"] = any(l.startswith("0 !BRICKWORKS PANEL ") for l in have)
print(json.dumps(found))
`, saved], { encoding: "utf8" });
    const found = JSON.parse(lines);
    ok(Object.values(found).every(Boolean), `the file says each: ${JSON.stringify(found)}`);
  }
} catch (e) {
  ok(false, String(e).split("\n")[0]);
}
await browser.close();

function three(facts) {
  return facts.find((p) => p.steps.includes(3));
}

for (const line of errors.slice(0, 8)) console.log(`  error: ${line}`);
const failed = said.filter((l) => l.includes("FAIL")).length + errors.length;
writeFileSync(`${out}/result.txt`, said.join("\n") + "\n");
console.log(failed
  ? `booklet edit flow: ${failed} problem(s); pictures in ${out}`
  : `booklet edit flow: a step turned, zoomed, put on a new page and a page alone, its parts list off, two a page, a merge undone, the booklet and its PDF laid out so, and the file saying it; pictures in ${out}`);
process.exit(failed ? 1 : 0);
