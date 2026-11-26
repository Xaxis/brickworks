// hairreview (review of sitehair): the maker's Hair and hats for somebody
// with no mould of their own yet, in en, de, fr and es at 1280 and 390: the
// line saying how to make one, its link, and whether anything spills.
// One throwaway account, deleted at the end.
//
//   node --env-file=.env tools/web/hairreview_words.mjs --url=http://127.0.0.1:12170 --out=DIR
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const site = String(args.url || "").replace(/\/+$/, "");
const out = path.resolve(String(args.out || "."));
mkdirSync(out, { recursive: true });
const rand = randomBytes(4).toString("hex");
const email = `delivered+bw-hairreview-words-${rand}@resend.dev`;
const said = [];
const log = (line) => { console.log(line); said.push(line); };
const until = (page, test, arg = null, timeout = 30000) => page.waitForFunction(test, arg, { timeout, polling: 250 }).then(() => true, () => false);

let who = null;
const browser = await launch({ signedOut: true });
try {
  who = await mintSession(email);
  const r = await fetch(`${site}/api/people?op=profile`, { method: "POST",
    headers: { authorization: `Bearer ${who.access_token}`, "content-type": "application/json" },
    body: JSON.stringify({ handle: `hairwords-${rand}`, name: "Wren Words" }) });
  log(`profile: ${r.status}`);
  for (const lang of ["en", "de", "fr", "es"]) {
    for (const width of [1280, 390]) {
      const phone = width < 600;
      const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: "light",
        ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
      await context.addInitScript(([key, value, access]) => {
        try {
          if (!localStorage.getItem(key)) localStorage.setItem(key, value);
          if (!sessionStorage.getItem("brickworks.access")) sessionStorage.setItem("brickworks.access", access);
        } catch { /* nothing kept */ }
      }, [STORAGE_KEY, JSON.stringify(who.kept), JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000,
        email: who.kept.email })]);
      const page = await context.newPage();
      const errors = [];
      page.on("pageerror", (e) => errors.push(String(e).slice(0, 160)));
      await page.goto(`${site}${lang === "en" ? "" : `/${lang}`}/profile`, { waitUntil: "load", timeout: 120000 });
      await until(page, () => document.documentElement.dataset.profile === "ready", null, 60000);
      await page.click("#edit");
      await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
      await page.click("#avatar-make");
      await until(page, () => ["ready", "failed"].includes(document.querySelector("dialog#minifig-dialog[open]")?.dataset.figure), null, 120000);
      await page.click("[role=tab][data-tab=hair]");
      await until(page, () => document.querySelector(".mf-own-none"), null, 20000);
      const seen = await page.evaluate(() => {
        const note = document.querySelector(".mf-own-none");
        const link = note?.querySelector("a");
        const spill = [...document.querySelectorAll("#minifig-dialog *")].filter((el) => {
          const box = el.getBoundingClientRect();
          return box.width > 0 && el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflowX === "visible"
            && !el.closest(".scroller");
        }).map((el) => `${el.tagName.toLowerCase()}.${[...el.classList].join(".")}`).slice(0, 5);
        const box = note?.getBoundingClientRect();
        return { words: note?.textContent.trim() || null, link: link ? `${link.textContent} -> ${link.getAttribute("href")}` : null,
          inside: box ? box.left >= 0 && box.right <= innerWidth : null, pill: Boolean(document.querySelector("[data-filter=own]")), spill };
      });
      log(`${lang} ${width}: ${JSON.stringify(seen)}${errors.length ? ` errors ${JSON.stringify(errors)}` : ""}`);
      await page.locator(".mf-own-none").scrollIntoViewIfNeeded().catch(() => {});
      await page.screenshot({ path: path.join(out, `empty_${lang}_${width}.png`), timeout: 90000 }).catch(() => {});
      await context.close();
    }
  }
} finally {
  await browser.close();
  if (who) log(`account deleted: ${await deleteAccount(email)}`);
  writeFileSync(path.join(out, "words.txt"), `${said.join("\n")}\n`);
}
