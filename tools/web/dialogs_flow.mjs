// Every dialog and panel More opens, by a finger, on a phone and a tablet:
// at 390 x 844 and 430 x 932 (three device pixels to the point) and at
// 768 x 1024 and 1024 x 768 (two), with touch events, in SwiftShader.
//
//   tools/export.sh web
//   set -a; . ./.env; set +a
//   python3 tools/web/serve.py build/web 8811 --parts-url "$PARTS_URL" &
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
//   Library        "UNICEF" typed above the keyboard, and the van opened: in
//                  a tab of its own, 65 parts (the live library, so locally
//                  the server is given the parts bucket, --parts-url)
//   Render         a quick picture made: a PNG downloaded
//   and the rest   the other dialogs More has (Parts list, My collection,
//                  Part maker, Colour the hidden parts, Keys and controls,
//                  About, Clear, Floor size), opened and closed by its own
//                  close button
//   Minifigure     on an empty baseplate: the torso's slot, "jacket" typed
//                  above the keyboard, a torso chosen by its tile, Back to
//                  the slots where they take turns with a slot's choices,
//                  Place in model, and a tap standing the figure there
//   Account        last: Sign out, and the sign-in screen up, where the
//                  test account is signed in, audited as a dialog is
//
// At every step the app is asked (window.brickworksAskPhone) for every
// target a finger has and every line of text, in points, and what is open
// over the model: the dialog named, none of its targets under 44 points on
// either side, no text under 12, nothing off the screen or, while the
// keyboard is up, under it; the field being typed in above it. The
// keyboard is the visual viewport made shorter, as a phone's is. The
// dialog's own named controls (window.brickworksControls) are measured
// too, so a build whose audit cannot see dialogs still fails with counts.
// --only=save_as,share runs those steps alone; --hold=MS holds each tap
// down that long before the finger lifts; --slow=N runs the page's CPU N
// times slower. Pictures go to --out,
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
// --hold=MS: each tap held down that long before the finger lifts, as a
// person's is (about 100 ms) or longer; 0, the default, taps at once.
const HOLD = Number(args.hold || 0);
const SLOW = Number(args.slow || 1);
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
    // Whether a tap's activation still held each time the app asked for a
    // tab: a phone's browser opens one only then, and the headless shell
    // these flows run in has no popup blocker, so any ask opened one. It
    // holds 5 s, from the tap or from the flow's last look before it
    // (Playwright's evaluate is an activation too).
    await context.addInitScript(() => {
      const open = window.open;
      window.open = function (...args) {
        (window.brickworksAsked ||= []).push(Boolean(navigator.userActivation?.isActive));
        return open.apply(this, args);
      };
    });
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(String(e).slice(0, 200)));
    page.on("console", (m) => {
      if (/SCRIPT ERROR|Parse Error|USER ERROR/.test(m.text())) errors.push(m.text().slice(0, 300));
    });
    const cdp = await context.newCDPSession(page);
    // --slow=N: the page's CPU N times slower, as a slow phone's or a busy box's.
    if (SLOW > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: SLOW });
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
    const tap = async (at) => {
      if (HOLD > 0) {
        await touch("touchStart", [at]);
        await page.waitForTimeout(HOLD);
        await touch("touchEnd", []);
      } else {
        await page.touchscreen.tap(at.x, at.y);
      }
      await page.waitForTimeout(600);
    };
    const tapBox = (box) => tap({ x: box[0] + box[2] / 2, y: box[1] + box[3] / 2 });
    // Pressed where it stands still: a dialog moves as the keyboard comes
    // and goes, and the page is told where its controls are twice a second.
    let lastTap = null;
    const press = async (name, seconds = 30) => {
      let at = await where(name, seconds);
      for (let n = 0; at && n < 6; n++) {
        await page.waitForTimeout(600);
        const again = (await controls())[name];
        if (again && again.x === at.x && again.y === at.y) break;
        at = again || await where(name, 5);
      }
      if (!at) { check(`"${name}" is on the screen`, false); return false; }
      lastTap = { name, x: at.x, y: at.y, t: Date.now() - t0 };
      await tap(at);
      return true;
    };
    const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type,
      touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: i + 1, radiusX: 4, radiusY: 4, force: 1 })) });
    // [still] ms held where it ends before the finger lifts, as a person
    // stops a list where they want it: lifted moving, a list glides on.
    const drag = async (a, b, steps = 16, still = 0) => {
      await touch("touchStart", [a]);
      for (let n = 1; n <= steps; n++) {
        await touch("touchMove", [{ x: a.x + (b.x - a.x) * n / steps, y: a.y + (b.y - a.y) * n / steps }]);
        await page.waitForTimeout(30);
      }
      if (still > 0) await page.waitForTimeout(still);
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
      // Open, if it is not: a tablet's More can be open under the newest panel.
      // A dialog a step could not put away by finger (one the audit cannot
      // see, on a build before dialogs255) goes by its key, so the next step
      // is measured still.
      for (let n = 0; n < 3 && !((await ask())?.phone?.sheets || []).includes("More"); n++) {
        if (n === 2) {
          await page.keyboard.press("Escape");
          await page.waitForTimeout(800);
        }
        await press("phone_more");
        await page.waitForTimeout(600);
      }
      const head = await where("phone_sheet_more", 5);
      const panel = await where("phone_panel_more", 5);
      if (!head || !panel) return check(`More is open for ${row}`, false);
      // The menu it is in opened first, as a finger opens it, each other
      // folded again (walk256 T2: More is the menus' names). Each step
      // waited for until the page is told it (twice a second, and slower on
      // a loaded box), so no menu's name is tapped where it stood before the
      // one above it folded; and a menu left open by a step before is
      // folded first. A name that has just moved is not told until it
      // stands still (Main._page_places), so each is waited for, never
      // passed over. What was tried is said if the row is never found.
      const MENUS = ["file", "edit", "view", "build", "tools", "help"];
      const rowsNow = async () => Object.entries(await controls()).filter(([k]) => k.startsWith("phone_row_"));
      const told = async (test) => {
        for (let n = 0; n < 60; n++) {
          if (await test()) return true;
          await page.waitForTimeout(250);
        }
        return false;
      };
      const tried = [];
      // The menu whose rows are showing: the last name above the first row.
      const openMenu = async () => {
        const named = await controls();
        const rows = Object.entries(named).filter(([k]) => k.startsWith("phone_row_"));
        if (!rows.length) return null;
        const first = Math.min(...rows.map(([, at]) => at.y));
        const above = MENUS.filter((m) => named[`phone_section_${m}`] && named[`phone_section_${m}`].y < first);
        return above.length ? above[above.length - 1] : null;
      };
      for (let n = 0; n < 6 && !(await controls())[`phone_row_${row}`]; n++) {
        const left = await openMenu();
        if (!left) break;
        tried.push(`${left} left open, folded`);
        const name = await where(`phone_section_${left}`, 15);
        if (!name) break;
        await tap(name);
        await told(async () => (await openMenu()) !== left);
      }
      for (const menu of MENUS) {
        if ((await controls())[`phone_row_${row}`]) break;
        const section = await where(`phone_section_${menu}`, 15);
        if (!section) {
          tried.push(`${menu} not told`);
          continue;
        }
        await tap(section);
        // A tap lost under load: once more.
        if (!(await told(async () => (await rowsNow()).length > 0))) {
          await tap((await where(`phone_section_${menu}`, 15)) || section);
          await told(async () => (await rowsNow()).length > 0);
        }
        tried.push(`${menu} ${(await rowsNow()).length} rows`);
        if ((await controls())[`phone_row_${row}`]) break;
        await tap((await where(`phone_section_${menu}`, 15)) || section);
        await told(async () => (await rowsNow()).length === 0);
      }
      const top = head.y + head.h / 2 + 6;
      const bottom = panel.y + panel.h / 2 - 6;
      for (let n = 0; n < 40; n++) {
        // Told where it is once it stands still: a flicked list glides on.
        const at = await where(`phone_row_${row}`, 8);
        if (!at) return check(`More has ${row}${tried.length ? ` (${tried.join("; ")})` : ""}`, false);
        if (at.y - at.h / 2 >= top && at.y + at.h / 2 <= bottom) {
          await tap(at);
          await page.waitForTimeout(1200);
          return true;
        }
        const span = (bottom - top) * 0.6;
        const by = at.y < top ? Math.min(top - at.y + 40, span) : -Math.min(at.y - bottom + 40, span);
        const from = by > 0 ? top + 12 : bottom - 12;
        // Held still before it lifts. Lifted moving, the list glides on
        // (ScrollContainer's fling): 434 points dragged went 8,500, end to end,
        // once the app drew at a phone's frame rate (f8596e3f). Each scroll
        // passed the row, and More never stopped on floor_custom.
        await drag({ x: panel.x, y: from }, { x: panel.x, y: from + by }, 16, 400);
        const moved = await where(`phone_row_${row}`, 8);
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
        // Where a save that did not land stopped: the dialog still up (the
        // tap never reached Save), or gone with the app saying why; and
        // who it took for signed in.
        const why = s.storage?.title === named ? "" : `; tapped ${JSON.stringify(lastTap)}, Save now at `
          + `${JSON.stringify((await controls()).save_as_ok || null)}, open ${JSON.stringify((await ask())?.dialogs || null)}, `
          + `said "${s.said || ""}", working ${JSON.stringify(s.working || null)}, `
          + `${JSON.stringify(await page.evaluate(() => window.brickworksAccount || null))}`;
        check(`saved as "${named}" (${s.storage?.title}${why})`, s.storage?.title === named);
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
        // Put away as a phone's is: a tap on the panel off the field.
        await keyboard(0);
        await page.waitForTimeout(600);
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
      }
      await press("parts_done", 5);
      await keyboard(0);
      const after = await ask();
      check(`Find put away by its Done (${JSON.stringify(after?.dialogs)})`,
        !(after?.dialogs || []).some((d) => /InventoryPanel/.test(d)));
    }

    // Instructions: the booklet's own tab, its Save as PDF a fingertip.
    if (step("booklet")) {
      // Heard from before More is scrolled, and waited for from the tap. A
      // wait begun before the scroll ran out during it: under load each
      // drag of the list took 14 s, Instructions was reached after two
      // minutes, and the tab its tap opened at once came to no one, on
      // m173's preview at 430 and 768 (booklet262). One tap: a second found
      // the first booklet drawing, and opened nothing.
      const tabs = [];
      const heard = (tab) => tabs.push(tab);
      context.on("page", heard);
      await page.evaluate(() => { window.brickworksAsked = []; });
      await more("instructions");
      const tab = tabs[0] || await context.waitForEvent("page", { timeout: 90000 }).catch(() => null);
      context.off("page", heard);
      const asked = (await page.evaluate(() => window.brickworksAsked)) || [];
      const when = asked.map((held) => (held ? "inside the tap's activation" : "after it had gone"));
      if (check(`Instructions: the booklet's tab opened (${asked.length ? `asked for ${when.join(", then ")}`
        : "never asked for"}; the app said "${(await state()).said || ""}")`, Boolean(tab) && asked[0] === true)) {
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

    // Library: a set searched for above the keyboard and opened, in a tab
    // of its own: the set is in it. The UNICEF Van, 65 parts: "106-1" finds
    // 42106-1 first, 2,257 of them.
    if (step("library")) {
      await more("library");
      await audit("library", /LibraryDialog/, ["library_search", "library_tab_sets", "library_tab_community"]);
      if (await typeInto("library_search", "UNICEF")) {
        await audit("library_typing", /LibraryDialog/, ["library_search"]);
        await page.keyboard.press("Enter");
        await keyboard(0);
        let found = {};
        for (let n = 0; n < 240 && !((found.ask || {}).q === "UNICEF" && (found.shown || []).length); n++) {
          await page.waitForTimeout(250);
          found = (await page.evaluate(() => window.brickworksLibrary || {})) || {};
        }
        const id = (found.shown || [])[0] || "";
        if (check(`"UNICEF" found the van: ${JSON.stringify(found.shown || [])}`, id === "omr-106-1")) {
          await audit("library_found", /LibraryDialog/, ["library_open_first"]);
          let tab = null;
          // Tapped again where no tab came, as the booklet's: on a loaded
          // box the tap's leave to open one can be gone by its frame.
          for (let n = 0; n < 2 && !tab; n++) {
            const coming = context.waitForEvent("page", { timeout: 60000 }).catch(() => null);
            if (!(await press("library_open_first", 10))) break;
            tab = await coming;
            if (!tab) say(`no tab from the tap (the library said "${(found.status || "")}"): tapped again`);
          }
          if (check(`Open: the set's own tab (${tab ? tab.url().replace(/x-vercel[^&]*&?/g, "") : "none"})`, Boolean(tab))) {
            let s = {};
            for (let n = 0; n < 600 && !(s.bricks > 0 && !s.awaited); n++) {
              await page.waitForTimeout(500);
              s = (await tab.evaluate(() => window.brickworksState || {}).catch(() => ({}))) || {};
            }
            const title = await tab.title().catch(() => "");
            const number = id.replace(/^omr-/, "");
            check(`the set open in it: ${s.bricks || 0} parts, "${title}"`, s.bricks > 0 && title.startsWith(number));
            await tab.screenshot({ path: `${out}/${size}_${String(++shot).padStart(2, "0")}_library_set.png` }).catch(() => {});
            await tab.close();
            await page.bringToFront();
          }
        }
      }
      await keyboard(0);
      await close("library", /LibraryDialog/);
    }

    // Render: a quick picture made, and downloaded.
    if (step("render")) {
      await more("render");
      await audit("render", /RenderDialog/, ["render_quick", "render_size_720p", "render_picture", "render_close"]);
      // Quick and small where a finger reaches them, as a person who wants
      // a picture soon chooses: the choices scroll on a phone.
      for (const name of ["render_quick", "render_size_720p"]) {
        const at = await where(name, 5);
        if (at && at.y > 0 && at.y < height) await press(name, 5);
        else say(`${name} is scrolled out of sight: the picture is made as it is set`);
      }
      const file = download(600);
      if (await press("render_picture", 10)) {
        const got = await file;
        check(`Render: a picture made, ${got ? got.suggestedFilename() : "nothing"} downloaded`,
          Boolean(got && /\.png$/i.test(got.suggestedFilename())));
        await audit("rendered", /RenderDialog/, ["render_picture", "render_close"]);
      }
      await close("render", /RenderDialog/);
    }

    // And the rest of what More opens: each open, its audit, and away by
    // its own way out.
    if (step("rest")) {
      const REST = [["parts_list", /InventoryPanel/], ["collection", /Collection/],
        ["part_maker", /ElementDialog/], ["hidden_colours", /HiddenColoursPanel/], ["keys", /ControlsDialog/],
        ["about", /^About/], ["clear", /^Clear/], ["floor_custom", /^Baseplate size/]];
      for (const [row, dialog] of REST) {
        if (!(await more(row))) continue;
        await audit(row, dialog);
        await close(row, dialog);
      }
    }

    // The Minifigure builder: a slot chosen, a part for it searched for
    // above the keyboard and chosen, and the figure placed: Place in model,
    // then a tap on the baseplate stands it there. On a phone or a tablet
    // held upright the slots and a slot's choices take turns (Back).
    if (step("minifig")) {
      // An empty baseplate, so wherever the tap is the figure has room.
      if (await more("new")) {
        const discard = await where("new_discard", 3);
        if (discard) await tap(discard);
      }
      let s = await until((now) => now.bricks === 0, 20);
      check(`New: an empty baseplate for the figure (${s.bricks} parts)`, s.bricks === 0);
      const form = ["minifig_name", "minifig_surprise", "minifig_close", "minifig_head", "minifig_torso",
        "minifig_keep", "minifig_place"];
      await more("minifig");
      await audit("minifig", /MinifigDialog/, form);
      const was = (await state()).bench || {};
      if (await press("minifig_torso", 20)) {
        const choices = ["minifig_search", "minifig_choice", "minifig_keep", "minifig_place"];
        await audit("minifig_torso", /MinifigDialog/, choices);
        if (await typeInto("minifig_search", "jacket")) {
          await audit("minifig_typing", /MinifigDialog/, ["minifig_search", "minifig_choice"]);
          await keyboard(0);
          await page.waitForTimeout(600);
        }
        await press("minifig_choice", 20);
        s = await until((now) => (now.bench || {}).torso && (now.bench || {}).torso !== was.torso, 10);
        const torso = (s.bench || {}).torso || "";
        check(`a torso chosen by its tile (${was.torso || "none"} to ${torso || "none"})`,
          Boolean(torso) && torso !== was.torso);
        await audit("minifig_chosen", /MinifigDialog/, choices);
        if (await where("minifig_back", 2)) {
          await press("minifig_back", 5);
          await audit("minifig_back", /MinifigDialog/, form);
        }
        if (await press("minifig_place", 10)) {
          s = await until((now) => now.figure_held, 20);
          const after = await ask();
          check(`Place in model: the builder put away, the figure in hand (${JSON.stringify(after?.dialogs)})`,
            s.figure_held && !(after?.dialogs || []).some((d) => /MinifigDialog/.test(d)));
          await press("phone_fit", 5);
          await page.waitForTimeout(1500);
          await page.evaluate(() => { window.brickworksLayout = null; window.brickworksAskLayout = true; });
          let laid = null;
          for (let n = 0; n < 24 && !laid; n++) {
            await page.waitForTimeout(250);
            laid = await page.evaluate(() => window.brickworksLayout);
          }
          const middle = laid && laid.centre ? laid.centre : { x: width / 2, y: height / 2 };
          // Its parts come over the wire: tapped again until it stands.
          let stood = 0;
          for (const [dx, dy] of [[0, 0], [0, 0], [16, 0], [0, 16], [-16, 0], [0, -16]]) {
            await tap({ x: middle.x + dx, y: middle.y + dy });
            s = await until((now) => now.bricks > 0, 8);
            stood = s.bricks || 0;
            if (stood) break;
          }
          await picture("minifig_placed");
          check(`a tap stands it on the baseplate: ${stood} parts, the torso among them `
            + `(${(s.parts || []).slice(0, 12).join(", ")})`, stood >= 7 && (s.parts || []).includes(torso));
        }
      }
    }

    // Account, last: its main control is Sign out, and the way back in is
    // the sign-in screen. Where nobody is signed in (a local server has no
    // accounts) there is no one to sign out.
    if (step("account")) {
      await more("account");
      await audit("account", /AccountPanel/, ["sign_out", "account_done"]);
      const signed = (await page.evaluate(() => window.brickworksAccount || {})) || {};
      if (await press("sign_out", 10)) {
        let now = {};
        for (let n = 0; n < 80; n++) {
          await page.waitForTimeout(250);
          now = (await page.evaluate(() => window.brickworksAccount || {})) || {};
          if (now.state !== "signed_in") break;
        }
        const after = await ask();
        check(`Sign out: the panel put away (${JSON.stringify(after?.dialogs)})`,
          !(after?.dialogs || []).some((d) => /AccountPanel/.test(d)));
        if (signed.state === "signed_in") {
          const way = await where("signin_email", 20);
          check(`signed out (${signed.state} to ${now.state}), the sign-in screen up `
            + `(${way ? `its address ${way.w}x${way.h}` : "none"})`,
          now.state === "signed_out" && now.gated && Boolean(way));
          // The way back in, by finger as the rest: its address was 199 x 20.
          await audit("signed_out", /SignInGate/, ["signin_email", "signin_send", "signin_orangecheck"]);
        } else {
          say(`not signed in here (${signed.state}): signing out is proved on a deployment`);
        }
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
