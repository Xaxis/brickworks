// Every dialog and panel More opens, by a finger, on a phone and a tablet:
// at 390 x 844 and 430 x 932 (three device pixels to the point) and at
// 768 x 1024 and 1024 x 768 (two), with touch events, in SwiftShader.
//
//   tools/export.sh web
//   python3 tools/web/serve.py build/web 8811 --parts assets/generated/parts --delay 0 &
//   set -a; . ./.env; set +a
//   node tools/web/dialogs_flow.mjs --url=http://127.0.0.1:8811/ --out=shots/dialogs
//   BW_BYPASS=… node tools/web/dialogs_flow.mjs --url=<preview>/app --out=DIR
//
// Building by touch was done (phone_flow.mjs, tablet_flow.mjs), but what
// More opens was still the desktop's: Save as, Share, Versions, Settings
// and the rest at 7 to 9 points, their buttons 17 points tall, in a box in
// the middle of the screen (dialogs255). At each size this opens, from More
// as a finger does (the list scrolled to the row and the row tapped):
//
//   Save as        typed into above the keyboard, saved under a new name
//   Open           its menu; Rename or delete saved models: one renamed,
//                  then deleted, each asked and answered
//   Versions       a version kept
//   Share          the name typed above the keyboard; published by link
//                  where the test account is signed in to a deployment
//   Settings       a setting changed (Reduce motion), and back
//   Build together a session started where signed in, and ended
//   Export         a 3D model's question answered: a file downloaded; an
//                  LDraw model downloaded
//   Find           a part number typed above the keyboard
//   Instructions   the booklet's tab: its Save as PDF a fingertip, pressed,
//                  a PDF downloaded
//   Model tree, Properties  the drawer; on a tablet it takes the parts
//                  panel's place rather than open over it
//   and the rest   every other dialog More has (Library, Account, Render,
//                  Motions, Parts list, My collection, Minifigure builder,
//                  Part maker, Colour the hidden parts, Keys and controls,
//                  About, Clear, Floor size), opened and closed by its own
//                  close button
//
// At every step the app is asked (window.brickworksAskPhone) for every
// target a finger has and every line of text, in points, and what is open
// over the model: the dialog named, none of its targets under 44 points on
// either side, no text under 12, nothing off the screen or, while the
// keyboard is up, under it; the field being typed in above it. The
// keyboard is the visual viewport made shorter, as a phone's is. The
// dialog's own named controls (window.brickworksControls) are measured
// too, so a build whose audit cannot see dialogs still fails with counts.
// --only=save_as,share runs those steps alone. Pictures go to --out,
// <size>_<n>_<what>.png.
import { launch } from "./browser.mjs";
import { mkdirSync } from "node:fs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const url = String(args.url || "http://127.0.0.1:8811/");
const bypass = String(args.bypass || process.env.BW_BYPASS || "");
const first = bypass
  ? `${url}${url.includes("?") ? "&" : "?"}x-vercel-protection-bypass=${bypass}&x-vercel-set-bypass-cookie=true`
  : url;
const out = String(args.out || "shots/dialogs");
const SIZES = String(args.sizes || "390x844,430x932,768x1024,1024x768").split(",");
const ONLY = args.only ? String(args.only).split(",") : null;
mkdirSync(out, { recursive: true });

let failed = 0;
const t0 = Date.now();
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}  [${Math.round((Date.now() - t0) / 1000)}s]`);
  if (!ok) failed += 1;
  return ok;
};
const say = (what) => console.log(`  --    ${what}`);
const sizes = (list) => list.slice(0, 4).map((t) => `${t.name} ${t.box[2]}x${t.box[3]}`).join("; ");

const browser = await launch();
try {
  for (const size of SIZES) {
    const [width, height] = size.split("x").map(Number);
    const ratio = Math.min(width, height) < 600 ? 3 : 2;
    console.log(`\n${width} x ${height} at ${ratio}x, by a finger`);
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: ratio,
      isMobile: true, hasTouch: true, acceptDownloads: true });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
    });
    const cdp = await context.newCDPSession(page);
    let shot = 0;
    const picture = async (what) => {
      shot += 1;
      await page.screenshot({ path: `${out}/${size}_${String(shot).padStart(2, "0")}_${what}.png` });
    };
    const state = async () => (await page.evaluate(() => window.brickworksState || {})) || {};
    const controls = async () => (await page.evaluate(() => window.brickworksControls || {})) || {};
    const until = async (test, seconds = 30) => {
      for (let n = 0; n < seconds * 4; n++) {
        const s = await state();
        if (test(s)) return s;
        await page.waitForTimeout(250);
      }
      return state();
    };
    const where = async (name, seconds = 30) => {
      for (let n = 0; n < seconds * 4; n++) {
        const at = (await controls())[name];
        if (at) return at;
        await page.waitForTimeout(250);
      }
      return null;
    };
    const tap = async (at) => { await page.touchscreen.tap(at.x, at.y); await page.waitForTimeout(600); };
    const tapBox = (box) => tap({ x: box[0] + box[2] / 2, y: box[1] + box[3] / 2 });
    const press = async (name, seconds = 30) => {
      const at = await where(name, seconds);
      if (!at) { check(`"${name}" is on the screen`, false); return false; }
      await tap(at);
      return true;
    };
    const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
    const drag = async (a, b, steps = 16) => {
      await touch("touchStart", [a]);
      for (let n = 1; n <= steps; n++) {
        await touch("touchMove", [{ x: a.x + (b.x - a.x) * n / steps, y: a.y + (b.y - a.y) * n / steps }]);
        await page.waitForTimeout(30);
      }
      await touch("touchEnd", []);
      await page.waitForTimeout(700);
    };
    const ask = async () => {
      await page.evaluate(() => { window.brickworksPhone = null; window.brickworksAskPhone = true; });
      for (let n = 0; n < 40; n++) {
        await page.waitForTimeout(250);
        const told = await page.evaluate(() => window.brickworksPhone);
        if (told) return told;
      }
      return null;
    };
    // The on-screen keyboard: the visual viewport [points] shorter, as a
    // phone's is while it is up; 0 puts it down.
    let keys = 0;
    const keyboard = async (points) => {
      keys = points;
      await page.evaluate((kb) => {
        const vv = window.visualViewport;
        if (kb > 0) Object.defineProperty(vv, "height", { configurable: true, get: () => window.innerHeight - kb });
        else delete vv.height;
        vv.dispatchEvent(new Event("resize"));
      }, points);
      await page.waitForTimeout(900);
    };
    const KEYBOARD = Math.round(height * (width < 600 ? 0.4 : 0.38));

    // What is on the screen, asked of the app and judged: the dialog
    // [dialog] open, its targets and every one a fingertip, its words, and
    // nothing off the screen. [named] are its controls by the page's names.
    const audit = async (what, dialog, named = []) => {
      await page.waitForTimeout(700);
      const told = await ask();
      await picture(what);
      if (!check(`${what}: the app said what is on the screen`, Boolean(told))) return null;
      const open = told.dialogs || null;
      check(`${what}: ${dialog} is open (${open ? JSON.stringify(open) : "the app says nothing of dialogs"})`,
        Boolean(open && open.some((d) => dialog.test(d))));
      const mine = (t) => !open || (t.in && dialog.test(t.in));
      const targets = told.targets.filter(mine);
      const small = told.targets.filter((t) => t.box[2] < 44 || t.box[3] < 44);
      const tiny = told.texts.filter((t) => t.px < 12);
      const off = told.targets.concat(told.texts).filter((t) => t.off);
      check(`${what}: ${targets.length} of its targets, ${told.targets.length} in all, `
        + `${small.length} under 44 points${small.length ? ` (${sizes(small)})` : ""}`,
        small.length === 0 && targets.length > 0);
      check(`${what}: ${told.texts.length} lines of text, ${tiny.length} under 12 points`
        + (tiny.length ? ` (${tiny.slice(0, 4).map((t) => `"${t.text}" ${t.px}`).join("; ")})` : ""),
        tiny.length === 0);
      check(`${what}: ${off.length} off the screen${keys ? " or under the keyboard" : ""}`
        + (off.length ? ` (${off.slice(0, 4).map((t) => `${t.name} at ${t.box}`).join("; ")})` : ""),
        off.length === 0);
      if (named.length) {
        const all = await controls();
        const shown = named.filter((n) => all[n]);
        const under = shown.filter((n) => all[n].w < 44 || all[n].h < 44);
        check(`${what}: ${shown.length} of its named controls, ${under.length} under 44 points`
          + (under.length ? ` (${under.slice(0, 5).map((n) => `${n} ${all[n].w}x${all[n].h}`).join("; ")})` : ""),
          under.length === 0);
      }
      if (keys) {
        const field = told.typing || [];
        const top = height - keys;
        check(`${what}: the field typed in is above the keyboard (its foot at `
          + `${field.length ? field[1] + field[3] : "none"}, the keyboard's top at ${top})`,
          field.length === 4 && field[1] >= 0 && field[1] + field[3] <= top + 1);
      }
      return told;
    };
    // A row of More: the list scrolled until the row is in it, by a finger,
    // and the row tapped.
    const more = async (row) => {
      if (((await ask())?.phone?.sheet) !== "More") await press("phone_more");
      const head = await where("phone_sheet_more", 5);
      const panel = await where("phone_panel_more", 5);
      if (!head || !panel) return check(`More is open for ${row}`, false);
      const top = head.y + head.h / 2 + 6;
      const bottom = panel.y + panel.h / 2 - 6;
      for (let n = 0; n < 40; n++) {
        const at = (await controls())[`phone_row_${row}`];
        if (!at) return check(`More has ${row}`, false);
        if (at.y - at.h / 2 >= top && at.y + at.h / 2 <= bottom) {
          await tap(at);
          await page.waitForTimeout(1200);
          return true;
        }
        const span = (bottom - top) * 0.6;
        const by = at.y < top ? Math.min(top - at.y + 40, span) : -Math.min(at.y - bottom + 40, span);
        const from = by > 0 ? top + 12 : bottom - 12;
        await drag({ x: panel.x, y: from }, { x: panel.x, y: from + by });
        const moved = (await controls())[`phone_row_${row}`];
        if (moved && Math.abs(moved.y - at.y) < 4) {
          return check(`More scrolls under a finger (a drag of ${Math.round(by)} moved ${row} `
            + `${moved.y - at.y} points)`, false);
        }
      }
      return check(`More scrolled to ${row}`, false);
    };
    // A dialog put away by its own way out: its close button, or a Done,
    // Close or Cancel in it.
    const close = async (what, dialog) => {
      const told = await ask();
      if (told?.dialogs && !told.dialogs.some((d) => dialog.test(d))) {
        say(`${what}: put away by what was done in it`);
        return true;
      }
      const mine = (told?.targets || []).filter((t) => t.in && dialog.test(t.in));
      const way = mine.find((t) => t.close) || mine.find((t) => /^(Done|Close|Cancel|OK)$/.test(t.text || ""));
      if (!check(`${what}: a way out a finger can press (${way ? `${way.name} ${way.box[2]}x${way.box[3]}` : "none"})`,
        Boolean(way))) {
        await page.keyboard.press("Escape");
        await page.waitForTimeout(800);
        return false;
      }
      await tapBox(way.box);
      await page.waitForTimeout(900);
      const after = await ask();
      return check(`${what}: put away (${JSON.stringify(after?.dialogs)})`,
        !(after?.dialogs || []).some((d) => dialog.test(d)));
    };
    // Typed into a field by its page name: tapped, and the keyboard comes
    // up, as a phone's does.
    const typeInto = async (name, text) => {
      const at = await where(name, 10);
      if (!at) return check(`"${name}" is on the screen`, false);
      await tap(at);
      await keyboard(KEYBOARD);
      await page.keyboard.press("Control+a");
      await page.keyboard.type(text, { delay: 30 });
      await page.waitForTimeout(500);
      return true;
    };
    const download = (seconds = 60) => page.waitForEvent("download", { timeout: seconds * 1000 }).catch(() => null);
    const step = (name) => !ONLY || ONLY.includes(name);

    await page.goto(first, { waitUntil: "domcontentloaded", timeout: 180000 });
    await until((s) => (s.awaited || 0) === 0 && s.mode, 300);
    if (!check("the layout for a finger is on: its row along the foot", Boolean(await where("phone_parts", 60)))) {
      await picture("never");
      await context.close();
      continue;
    }
    const wide = Boolean((await ask())?.phone?.wide);
    say(wide ? "laid out wide, for a tablet" : "laid out for a phone");
    const named = `Touch ${size} ${Date.now() % 100000}`;

    // Save as: a name typed above the keyboard, and saved under it.
    if (step("save_as")) {
      await more("save_as");
      await audit("save_as", /^Save as$/, ["save_as_name", "save_as_ok"]);
      if (await typeInto("save_as_name", named)) {
        await audit("save_as_typing", /^Save as$/, ["save_as_name", "save_as_ok"]);
        // Saved with the keyboard still up, as a finger does.
        await press("save_as_ok", 5);
        await keyboard(0);
        const s = await until((now) => now.storage?.title === named, 20);
        check(`saved as "${named}" (${s.storage?.title})`, s.storage?.title === named);
      }
    }

    // Open: its menu, and Rename or delete saved models.
    if (step("saved")) {
      await more("open");
      const menu = await audit("open_menu", /PopupMenu/);
      const manage = (menu?.texts || []).find((t) => /^Rename or delete saved models/.test(t.text));
      if (check(`the menu has Rename or delete saved models (${manage ? manage.box : "none"})`, Boolean(manage))) {
        await tapBox(manage.box);
        await audit("saved_models", /^Saved models$/, ["saved_rename_1", "saved_delete_1", "saved_close"]);
        if (await press("saved_rename_1", 10)) {
          await audit("rename", /^Rename$/, ["saved_rename_name", "saved_rename_ok"]);
          if (await typeInto("saved_rename_name", `${named} again`)) {
            await audit("rename_typing", /^Rename$/, ["saved_rename_name", "saved_rename_ok"]);
            await press("saved_rename_ok", 5);
            await keyboard(0);
            const s = await until((now) => now.storage?.title === `${named} again`, 15);
            check(`renamed "${named} again" (${s.storage?.title})`, s.storage?.title === `${named} again`);
          }
        }
        if (await press("saved_delete_1", 10)) {
          await audit("delete", /Delete/, ["saved_delete_ok", "saved_delete_cancel"]);
          await press("saved_delete_ok", 5);
          check("deleted: Undo offered in its row", Boolean(await where("saved_undo_1", 10)));
          await audit("deleted", /^Saved models$/, ["saved_undo_1", "saved_close"]);
          await press("saved_undo_1", 5);
        }
        await close("saved_models", /^Saved models$/);
      }
    }

    // Versions: one kept.
    if (step("versions")) {
      await more("versions");
      await audit("versions", /^Versions/, ["versions_save", "versions_close", "version_open_1"]);
      // Saved as above, the save is kept here: opened again from it.
      const rows = ((await state()).storage?.versions?.rows || []).length;
      if (check(`the saves kept (${rows})`, rows > 0 || !step("save_as")) && await where("version_open_1", 5)) {
        await press("version_open_1", 5);
        await page.waitForTimeout(2000);
        const s = await state();
        check(`a version opened (${s.storage?.title}, ${s.bricks} parts)`, s.bricks > 0);
      }
      await close("versions", /^Versions/);
    }

    // Share: its name typed above the keyboard; published where signed in.
    if (step("share")) {
      await more("share");
      const form = ["share_name", "share_credit", "share_about", "share_tags", "share_kind", "share_licence",
        "share_list", "share_publish", "share_done"];
      await audit("share", /SharePanel/, form);
      if (await typeInto("share_name", named)) {
        await audit("share_typing", /SharePanel/, form);
        await keyboard(0);
      }
      const publish = (await controls()).share_publish;
      const signed = (await page.evaluate(() => window.brickworksAccount || {})) || {};
      if (signed.state === "signed_in") {
        await press("share_publish");
        const link = await where("share_copy_link", 60);
        check(`published: its link to copy (${link ? `${link.w}x${link.h}` : "none"})`, Boolean(link));
        await audit("shared", /SharePanel/, ["share_copy_link", "share_open", "share_unpublish", "share_done"]);
        if (await press("share_unpublish", 5)) await page.waitForTimeout(3000);
      } else {
        say(`not signed in here (${publish ? "Publish shown" : "no Publish"}): publishing is proved on a deployment`);
      }
      await press("share_done", 5);
    }

    // Settings: Reduce motion changed, and changed back.
    if (step("settings")) {
      await more("settings");
      const told = await audit("settings", /ControlsDialog/, ["reduce_motion", "interface_size", "settings_done"]);
      const box = await where("reduce_motion", 5);
      const was = (told?.targets || []).find((t) => box && Math.abs(t.box[0] + t.box[2] / 2 - box.x) < 3
        && Math.abs(t.box[1] + t.box[3] / 2 - box.y) < 3);
      if (check(`Reduce motion is there (${was ? `on: ${was.on}` : "none"})`, Boolean(box && was))) {
        await tap(box);
        const now = (await ask())?.targets.find((t) => t.name === was.name);
        check(`tapped: Reduce motion changed (${was.on} to ${now?.on})`, now && now.on !== was.on);
        await audit("setting_changed", /ControlsDialog/, ["reduce_motion", "settings_done"]);
        await tap(await where("reduce_motion", 5));
      }
      await press("settings_done", 5);
    }

    // Build together: a session started where signed in, and ended.
    if (step("together")) {
      await more("together");
      await audit("together", /^Build together$/, ["together_start", "together_join_field", "together_join", "together_close"]);
      const signed = (await page.evaluate(() => window.brickworksAccount || {})) || {};
      if (signed.state === "signed_in" && await press("together_start", 5)) {
        const copy = await where("together_copy", 40);
        check(`started: its link to send (${copy ? `${copy.w}x${copy.h}` : "none"})`, Boolean(copy));
        await audit("together_on", /^Build together$/, ["together_copy", "together_end", "together_close"]);
        await press("together_end", 5);
        await page.waitForTimeout(2000);
      } else {
        say("not signed in here: a session is started on a deployment");
      }
      await close("together", /^Build together$/);
    }

    // Export: a 3D model, asked and answered, and an LDraw model.
    if (step("export")) {
      await more("export_3d");
      const told = await audit("export_3d", /3D model|Export/);
      const ok = (told?.targets || []).find((t) => t.in && /^(Export|Save|OK)/.test(t.text || ""));
      if (check(`its Export to press (${ok ? ok.text : "none"})`, Boolean(ok))) {
        const file = download();
        await tapBox(ok.box);
        const got = await file;
        check(`a 3D model downloaded (${got ? got.suggestedFilename() : "none"})`, Boolean(got));
      }
      const file = download();
      await more("export_ldraw");
      const got = await file;
      check(`an LDraw model downloaded (${got ? got.suggestedFilename() : "none"})`, Boolean(got));
    }

    // Find: a part number typed above the keyboard.
    if (step("find")) {
      await more("select_find");
      await audit("find", /InventoryPanel/, ["parts_find", "parts_done"]);
      if (await typeInto("parts_find", "3001")) {
        await audit("find_typing", /InventoryPanel/, ["parts_find", "parts_done"]);
        await keyboard(0);
      }
      await press("parts_done", 5);
    }

    // Instructions: the booklet's own tab, its Save as PDF a fingertip.
    if (step("booklet")) {
      const opened = context.waitForEvent("page", { timeout: 90000 }).catch(() => null);
      await more("instructions");
      const active = await page.evaluate(() => navigator.userActivation?.isActive);
      const tab = await opened;
      if (check(`Instructions: the booklet's tab opened (the tap ${active ? "is" : "is not"} a user's `
        + `activation; the app said "${(await state()).said || ""}")`, Boolean(tab))) {
        const save = tab.locator("#save-pdf");
        await save.waitFor({ state: "visible", timeout: 240000 }).catch(() => null);
        const bar = await tab.evaluate(() => [...document.querySelectorAll(".bar button:not([hidden])")].map((b) => {
          const r = b.getBoundingClientRect();
          return { text: b.textContent, w: Math.round(r.width), h: Math.round(r.height),
            px: parseFloat(getComputedStyle(b).fontSize), off: r.right > innerWidth + 1 || r.left < -1 };
        }));
        await tab.screenshot({ path: `${out}/${size}_${String(++shot).padStart(2, "0")}_booklet.png` });
        const small = bar.filter((b) => b.w < 44 || b.h < 44);
        check(`the booklet's bar: ${bar.length} buttons, ${small.length} under 44 points`
          + (small.length ? ` (${small.map((b) => `${b.text} ${b.w}x${b.h}`).join("; ")})` : ""),
          bar.length >= 2 && small.length === 0);
        check(`its words at ${[...new Set(bar.map((b) => b.px))].join(", ")} points, none under 12, none off the screen`,
          bar.every((b) => b.px >= 12 && !b.off));
        if (await save.isVisible().catch(() => false)) {
          const file = tab.waitForEvent("download", { timeout: 240000 }).catch(() => null);
          const pdf = page.waitForEvent("download", { timeout: 240000 }).catch(() => null);
          await save.tap();
          const got = await Promise.race([file, pdf]);
          check(`Save as PDF tapped: ${got ? got.suggestedFilename() : "nothing"} downloaded`,
            Boolean(got && /\.pdf$/.test(got.suggestedFilename())));
        } else {
          check("the booklet shows Save as PDF", false);
        }
        await tab.close();
      }
    }

    // The model tree and the properties, in the drawer.
    if (step("drawer")) {
      for (const [row, what, name] of [["panel_outliner", "model_tree", "outliner_tree"],
        ["panel_properties", "properties", "properties"]]) {
        if (wide && !(((await ask())?.phone?.sheets) || []).includes("Parts")) await press("phone_parts");
        await more(row);
        await page.waitForTimeout(1200);
        const told = await audit(what, /PanelStack/, []);
        const drawer = await where(name, 5);
        const sheets = told?.phone?.sheets || [];
        if (wide) {
          const parts = await where("phone_panel_parts", 2);
          const left = (b) => b.x - b.w / 2;
          const right = (b) => b.x + b.w / 2;
          const over = parts && drawer && left(drawer) < right(parts) && right(drawer) > left(parts);
          check(`${what}: the parts panel not under it (${sheets.join(", ") || "no panel"}${over ? ", covered" : ""})`,
            !over);
        }
        check(`${what}: in the drawer (${drawer ? `${drawer.w}x${drawer.h}` : "none"})`, Boolean(drawer));
        await press(row === "panel_outliner" ? "parts_rail" : "parts_rail", 5);
        await page.waitForTimeout(1200);
        if (wide) {
          const back = ((await ask())?.phone?.sheets) || [];
          check(`${what}: folded, the parts panel back (${back.join(", ") || "none"})`, back.includes("Parts"));
        }
      }
    }

    // And the rest of what More opens: each open, its audit, and away by
    // its own way out.
    if (step("rest")) {
      const REST = [["library", /LibraryDialog/], ["account", /AccountPanel/], ["render", /RenderDialog/],
        ["parts_list", /InventoryPanel/], ["collection", /Collection/], ["minifig", /MinifigDialog/],
        ["part_maker", /ElementDialog/], ["hidden_colours", /HiddenColoursPanel/], ["keys", /ControlsDialog/],
        ["about", /^About/], ["clear", /^Clear/], ["floor_custom", /^Baseplate size/]];
      for (const [row, dialog] of REST) {
        if (!(await more(row))) continue;
        await audit(row, dialog);
        await close(row, dialog);
      }
    }

    check(`no script errors (${errors.length}${errors.length ? `: ${errors[0]}` : ""})`, errors.length === 0);
    await context.close();
  }
} finally {
  await browser.close();
}
console.log(failed ? `\n${failed} checks failed` : "\nevery dialog More opens is used by a finger alone");
process.exit(failed ? 1 : 0);
