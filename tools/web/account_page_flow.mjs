// Your account as your profile (docs/SOCIAL.md U6): /profile is your page
// as everybody sees it, with Edit profile and the tabs only you see, and
// /settings holds the rest. In a real browser at 390 and 1280 px, light
// and dark, signed in and out, against a site and its live database:
//
//   node --env-file=.env tools/web/relay_server.mjs 8890 &
//   node --env-file=.env tools/web/account_page_flow.mjs --url=http://127.0.0.1:8890 --out=DIR
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=.env tools/web/account_page_flow.mjs --url=<preview> --out=DIR
//
// Throwaway accounts at Resend test addresses, each deleted by the end.
//
//   1. Ada has set everything the old account page could set, through the
//      API as it did: a name, handle and words, two links, a banner and
//      two pins on two listed models, a favourite, a private collection,
//      the day's email of comments and new models, and whom she follows
//      shown. Nothing of it may be lost or changed by the new pages.
//   2. Signed out, /profile and /settings say what an account is and offer
//      Sign in, at both widths and themes, nothing sideways.
//   3. Signed in, /profile at 1280 and 390 in both themes: her head as
//      /u/<handle> draws it (name, @handle, words, links ugc nofollow, the
//      banner, her pins in her order, numbers with no count of none), the
//      tabs Models · Builds · Saved · Sets · Insights, Models open with her
//      two models; under 2,000 px tall at 1280; at 390 the avatar, name
//      and Edit profile on the first screen.
//   4. Edit profile: the dialog holds everything she set; her name changed
//      there shows on the page with no reload, and her links, banner, pins
//      and words are as they were (op=me, read back).
//   5. Saved, Sets and Insights: her favourite and collection, what she
//      owns, how her models are doing.
//   6. /settings: every row (Profile, Appearance, Email, Privacy, Claude,
//      Sign out, Delete account), her choices read back as she made them;
//      an email choice and the theme changed and changed back; Sign out.
//   7. Bea, signed in with no profile: two fields, and her profile drawn at
//      once when she makes it.
//   8. Ada deletes her account from Settings: signed out, gone from the
//      sign-in service, her page and models gone, her row of what her
//      profile shows gone (read with the secret key).
//
// Pictures in --out.
import { launch } from "./browser.mjs";
import { deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("account_page_flow: --url=<a relay or a deployment>");
  process.exit(2);
}
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
const out = args.out || "shots/account_page";
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const ID = /^[A-Za-z0-9]{10}$/;
const rand = randomBytes(4).toString("hex");
const adaEmail = `delivered+bw-acct-ada-${rand}@resend.dev`;
const beaEmail = `delivered+bw-acct-bea-${rand}@resend.dev`;
const ADA = `acct-ada-${rand}`;
const BEA = `acct-bea-${rand}`;

let failed = 0;
let passed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (ok) passed += 1;
  else failed += 1;
  return ok;
};
const errors = [];
function listen(page, who) {
  page.on("pageerror", (e) => errors.push(`${who}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (m.type() === "error" && /Content Security Policy|Refused to|SyntaxError|TypeError|ReferenceError/.test(m.text())) {
      errors.push(`${who}: ${m.text().slice(0, 220)}`);
    }
  });
}
const shot = (page, name, full = true) => page.screenshot({ path: path.join(out, name), fullPage: full, timeout: 60000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const until = (page, test, arg = null, timeout = 20000) => page.waitForFunction(test, arg, { timeout }).then(() => true, () => false);

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(site + pathname, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: reply.status, json: await reply.json().catch(() => null) };
}

/// Whether the sign-in service has an account at [email].
async function accountExists(email) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const secret = process.env.SUPABASE_SECRET_KEY || "";
  const listed = await (await fetch(`${base}/auth/v1/admin/users?page=1&per_page=1000`, {
    headers: { apikey: secret, authorization: `Bearer ${secret}` } })).json();
  return (listed.users || []).some((u) => (u.email || "").toLowerCase() === email.toLowerCase());
}

const browser = await launch({ signedOut: true });

/// A page of the site at [width] in [theme], signed in as [who] or not.
async function open(pathname, { width, theme, who = null, label }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 }, colorScheme: theme,
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (who) {
    // Its access token too, good for the hour, so a page need not renew the
    // sign-in that every context of the run starts from.
    const access = JSON.stringify({ token: who.access_token, until: Date.now() + 50 * 60 * 1000, email: who.kept.email });
    await context.addInitScript(([key, value, token]) => {
      try {
        if (!localStorage.getItem(key)) {
          localStorage.setItem(key, value);
          sessionStorage.setItem("brickworks.access", token);
        }
      } catch { /* a browser that keeps nothing */ }
    }, [STORAGE_KEY, JSON.stringify(who.kept), access]);
  }
  const page = await context.newPage();
  listen(page, label);
  await page.goto(site + pathname, { waitUntil: "load", timeout: 60000 });
  return { page, context };
}

const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

/// What /profile shows, read as a person reads it.
const profileSaid = (page) => page.evaluate(() => {
  const box = (el) => (el ? el.getBoundingClientRect() : null);
  return {
    start: !document.getElementById("start").hidden,
    me: !document.getElementById("me").hidden,
    name: document.getElementById("title").textContent,
    handle: document.getElementById("handle-line").textContent.replace(/\s+/g, " ").trim(),
    bio: document.getElementById("bio-shown").hidden ? "" : document.getElementById("bio-shown").textContent,
    links: [...document.querySelectorAll("#links-shown a")].map((a) => ({ href: a.getAttribute("href"), rel: a.rel })),
    banner: document.querySelector("#banner-shown img")?.getAttribute("src") || "",
    pins: [...document.querySelectorAll("#pins .model")].map((card) => card.dataset.id),
    numbers: [...document.querySelectorAll("#numbers li")].map((li) => li.textContent.replace(/\s+/g, " ").trim()),
    tabs: [...document.querySelectorAll("#tabs a")].filter((a) => !a.hidden).map((a) => ({ tab: a.dataset.tab,
      current: a.getAttribute("aria-current") === "page", n: a.querySelector(".n:not([hidden])")?.textContent || "" })),
    panel: [...document.querySelectorAll("#work [data-panel]")].filter((p) => !p.hidden).map((p) => p.dataset.panel),
    cards: [...document.querySelectorAll("#my-models .model")].map((card) => card.dataset.id),
    more: !document.getElementById("models-paging").hidden,
    avatar: (() => {
      const a = document.getElementById("avatar");
      return a ? { letter: a.textContent, tile: [...a.classList].some((c) => /^c[1-8]$/.test(c)), bottom: box(a).bottom } : null;
    })(),
    nameBottom: box(document.getElementById("title"))?.bottom ?? 1e9,
    editBottom: box(document.getElementById("edit"))?.bottom ?? 1e9,
    actsRows: new Set([...document.querySelectorAll(".profile-head .acts > *")].filter((one) => one.offsetParent)
      .map((one) => Math.round(one.getBoundingClientRect().top))).size,
    height: document.documentElement.scrollHeight,
    screen: innerHeight,
    sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    tabsScroll: (() => {
      const t = document.getElementById("tabs");
      return t.scrollWidth > t.clientWidth + 1;
    })(),
  };
});

const made = [];
let ada = null;
let bea = null;
let adaGone = false;
let adaId = "";
try {
  // --- 1. Everything Ada set, the way the old page set it -------------------
  console.log("1. Ada has set everything the account page could set");
  ada = await mintSession(adaEmail);
  bea = await mintSession(beaEmail);
  adaId = ada.kept.user_id;
  let r = await api("/api/people?op=profile", { method: "POST", token: ada.access_token,
    body: { handle: ADA, name: "Ada Account", bio: "Castles and small machines.\nFor the account page flow." } });
  check(`her profile: ${r.status} /u/${r.json?.handle}`, r.status === 200 && r.json?.handle === ADA);
  const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");
  // Five: more than a laptop's row, so Show more is on the page measured.
  for (const [file, name] of [["castle.ldr", "Account Castle"], ["lighthouse.ldr", "Account Lighthouse"],
    ["house.ldr", "Account House"], ["car.ldr", "Account Car"], ["boat.ldr", "Account Boat"]]) {
    r = await api("/api/share", { method: "POST", token: ada.access_token, body: { name: `${name} ${rand}`, author: "Ada Account",
      model: readFileSync(path.join(root, "models", file), "utf8"), image: picture, listed: true, kind: "castle",
      tags: "account flow", licence: "cc-by-4.0" } });
    check(`listed ${name}: ${r.status} ${r.json?.id}`, r.status === 201 && ID.test(String(r.json?.id || "")));
    made.push(r.json?.id);
  }
  const LINKS = ["https://ada-builds.example/castles", "https://www.flickr.com/photos/ada"];
  r = await api("/api/people?op=showcase", { method: "POST", token: ada.access_token,
    body: { links: LINKS, banner: made[1], pins: [made[1], made[0]] } });
  check(`links, a banner and pins: ${r.status}`, r.status === 200 && r.json.pins.join(",") === `${made[1]},${made[0]}`);
  r = await api(`/api/people?op=favourite&id=${made[0]}`, { method: "POST", token: ada.access_token, body: { on: true } });
  check(`a favourite: ${r.status}`, r.status === 200);
  r = await api("/api/people?op=collection", { method: "POST", token: ada.access_token, body: { name: `Towers ${rand}`, public: false } });
  const listId = r.json?.id || "";
  check(`a private collection: ${r.status} ${listId}`, r.status === 200 && ID.test(listId));
  r = await api("/api/people?op=mail", { method: "POST", token: ada.access_token, body: { comments: true, models: true } });
  const mailReady = r.status === 200;
  check(`the day's email of comments and new models: ${r.status}`, mailReady || r.status === 503);
  r = await api("/api/people?op=follow_choice", { method: "POST", token: ada.access_token, body: { shows: true } });
  const followsReady = r.status === 200;
  check(`whom she follows shown: ${r.status}`, followsReady || r.status === 503);
  const before = (await api("/api/people?op=me", { token: ada.access_token })).json;
  check(`read back: ${before.profile?.name}, ${before.showcase?.links?.length} links, banner ${before.showcase?.banner}`,
    before.showcase?.banner === made[1] && before.showcase?.links?.length === 2);

  // --- 2. Signed out ----------------------------------------------------------
  console.log("2. signed out");
  for (const width of [390, 1280]) {
    for (const theme of ["light", "dark"]) {
      for (const where of ["/profile", "/settings"]) {
        const label = `${where} ${width} ${theme} out`;
        const { page, context } = await open(where, { width, theme, label });
        const done = await until(page, () => ["signed-out"].includes(document.documentElement.dataset.profile
          || document.documentElement.dataset.settings));
        check(`${label}: Sign in offered, nothing sideways`, done && await page.isVisible("#sign-in") && !(await sideways(page)));
        await shot(page, `out_${where.slice(1)}_${width}_${theme}.png`);
        await context.close();
      }
    }
  }

  // --- 3. Signed in: her profile ---------------------------------------------
  console.log("3. her profile, signed in");
  for (const width of [1280, 390]) {
    for (const theme of ["dark", "light"]) {
      const label = `/profile ${width} ${theme} in`;
      const { page, context } = await open("/profile", { width, theme, who: ada, label });
      await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
      await page.evaluate(async () => {
        await Promise.race([Promise.all([...document.images].map((img) => img.decode().catch(() => {}))),
          new Promise((done) => setTimeout(done, 6000))]);
      });
      const said = await profileSaid(page);
      check(`${label}: "${said.name}", ${said.handle.split(" · ")[0]}, an avatar "${said.avatar?.letter}" on a tile`,
        said.me && !said.start && said.name === "Ada Account" && said.handle.startsWith(`@${ADA}`)
        && said.avatar?.tile && said.avatar.letter === "A");
      check(`${label}: her words, links (ugc nofollow), the banner and her pins in her order`,
        said.bio === "Castles and small machines.\nFor the account page flow."
        && said.links.map((one) => one.href).join(" ") === LINKS.join(" ")
        && said.links.every((one) => /\bugc\b/.test(one.rel) && /\bnofollow\b/.test(one.rel))
        && said.banner === `/m/${made[1]}.png` && said.pins.join(",") === `${made[1]},${made[0]}`);
      check(`${label}: numbers ${said.numbers.join(" · ")}, none of none`, said.numbers.join() === "5 models");
      check(`${label}: tabs ${said.tabs.map((t) => `${t.tab}${t.n ? ` ${t.n}` : ""}${t.current ? "*" : ""}`).join(" · ")}, `
        + `Models open with ${said.cards.length} of her 5 models and Show more`,
        said.tabs.map((t) => t.tab).join(",") === "models,builds,saved,sets,insights" && said.tabs[0].current
        && said.tabs[0].n === "5" && said.tabs.every((t) => t.n !== "0") && said.panel.join() === "models"
        && said.cards.length === 4 && said.cards.every((id) => made.includes(id)) && said.more);
      await page.click("#models-more");
      const all = await until(page, () => document.querySelectorAll("#my-models .model").length === 5
        && document.getElementById("models-paging").hidden);
      check(`${label}: Show more brings the fifth, and goes`, all);
      if (width === 1280) check(`${label}: ${said.height} px tall with its first tab open (under 2,000)`, said.height < 2000);
      else {
        const last = Math.max(said.avatar?.bottom ?? 1e9, said.nameBottom, said.editBottom);
        check(`${label}: avatar, name and Edit profile on the first screen (to ${Math.round(last)} of ${said.screen} px), `
          + `its buttons in ${said.actsRows} row, tabs ${said.tabsScroll ? "scroll inside their row" : "fit"}`,
        last <= said.screen && said.actsRows === 1);
      }
      check(`${label}: nothing sideways`, !said.sideways);
      await shot(page, `profile_${width}_${theme}.png`);
      await shot(page, `profile_${width}_${theme}_fold.png`, false);
      if (theme === "dark") {
        // --- 4. Edit profile ---------------------------------------------------
        await page.click("#edit");
        await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
        const form = await page.evaluate(() => ({ name: document.getElementById("name").value,
          handle: document.getElementById("handle").value, bio: document.getElementById("bio").value,
          links: [document.getElementById("link-1").value, document.getElementById("link-2").value],
          banner: document.getElementById("banner").value,
          pins: [...document.querySelectorAll("select[data-pin]")].map((s) => s.value),
          shown: [...document.querySelectorAll("#profile-form label")].filter((l) => l.offsetParent).length,
          sideways: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 }));
        check(`${label}: Edit profile holds what she set (${form.shown} fields shown)`, form.name === "Ada Account"
          && form.handle === ADA && form.bio === "Castles and small machines.\nFor the account page flow."
          && form.links.join(" ") === LINKS.join(" ") && form.banner === made[1]
          && form.pins.join(",") === `${made[1]},${made[0]},` && form.shown === 9 && !form.sideways);
        await shot(page, `edit_${width}_${theme}.png`, false);
        if (width === 1280) {
          await page.evaluate(() => { window.notReloaded = true; });
          await page.fill("#name", "Ada Renamed");
          await page.click("#save");
          const shown = await until(page, () => !document.querySelector("dialog#edit-dialog[open]")
            && document.getElementById("title").textContent === "Ada Renamed");
          const kept = await page.evaluate(() => window.notReloaded === true);
          check(`${label}: a name changed in Edit shows on the page, no reload`, shown && kept);
          const after = (await api("/api/people?op=me", { token: ada.access_token })).json;
          check(`...and nothing else changed: words, links ${after.showcase.links.length}, banner, pins `
            + `${after.showcase.pins.join(",")}`, after.profile.name === "Ada Renamed" && after.profile.handle === ADA
            && after.profile.bio === before.profile.bio && JSON.stringify(after.showcase.links) === JSON.stringify(before.showcase.links)
            && after.showcase.banner === before.showcase.banner && after.showcase.pins.join() === before.showcase.pins.join());
          const publicPage = await (await fetch(`${site}/u/${ADA}?tests=1`, { headers })).text();
          check("...and on her public page", publicPage.includes("<h1>Ada Renamed</h1>"));
          // Back as she was, from the same dialog.
          await page.click("#edit");
          await until(page, () => document.querySelector("dialog#edit-dialog[open]"));
          await page.fill("#name", "Ada Account");
          await page.click("#save");
          check(`${label}: and back`, await until(page, () => document.getElementById("title").textContent === "Ada Account"));

          // --- 5. The tabs only she sees ---------------------------------------
          await page.click('#tabs a[data-tab="saved"]');
          const saved = await until(page, () => document.querySelectorAll("#favourites .model").length
            && document.querySelectorAll("#lists .list-mine").length, null, 20000);
          const savedSaid = await page.evaluate(() => ({ favourites: [...document.querySelectorAll("#favourites .model")].map((a) => a.dataset.id),
            lists: [...document.querySelectorAll("#lists .list-mine")].map((one) => one.dataset.id), address: location.search }));
          check(`${label}: Saved, her favourite and her collection (${savedSaid.address})`, saved
            && savedSaid.favourites.includes(made[0]) && savedSaid.lists.includes(listId) && savedSaid.address === "?tab=saved");
          await shot(page, `saved_${width}_${theme}.png`);
          await page.click('#tabs a[data-tab="sets"]');
          check(`${label}: Sets, what she owns`, await until(page, () => /^Tell Brickworks what you own/
            .test(document.getElementById("owned-said").textContent)));
          await page.click('#tabs a[data-tab="insights"]');
          check(`${label}: Insights, how her models are doing`, await until(page, () => ["ready", "empty", "not-yet"]
            .includes(document.documentElement.dataset.designs), null, 20000));
          await shot(page, `insights_${width}_${theme}.png`);
          await page.reload({ waitUntil: "load" });
          await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
          check(`${label}: a reload comes back to Insights`, await page.evaluate(() =>
            document.querySelector("#tabs [aria-current=page]")?.dataset.tab === "insights"));
        } else {
          await page.click("#cancel");
        }
      }
      await context.close();
    }
  }

  // Her own public page offers Edit profile where Follow would be; nobody
  // else's does.
  for (const [who, label] of [[ada, "her own /u/ page"], [bea, "her /u/ page to Bea"], [null, "her /u/ page signed out"]]) {
    const { page, context } = await open(`/u/${ADA}?tests=1`, { width: 1280, theme: "dark", who, label });
    await until(page, () => document.querySelector("button[data-follow]") && (!document.querySelector("button[data-follow]").hidden
      || !document.querySelector("[data-edit-own]").hidden));
    const shown = await page.isVisible("[data-edit-own]");
    check(`${label}: Edit profile ${shown ? "offered" : "not offered"}`, shown === (who === ada));
    if (who === ada) {
      await page.click("[data-edit-own]");
      check(`${label}: Edit profile opens the dialog on /profile`, await until(page,
        () => document.querySelector("dialog#edit-dialog[open]") && document.getElementById("name").value === "Ada Account", null, 30000));
    }
    await context.close();
  }

  // --- 6. Her settings --------------------------------------------------------
  console.log("6. her settings");
  for (const width of [1280, 390]) {
    for (const theme of ["dark", "light"]) {
      const label = `/settings ${width} ${theme} in`;
      const { page, context } = await open("/settings", { width, theme, who: ada, label });
      await until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);
      const rows = await page.evaluate(() => [...document.querySelectorAll(".settings > .setting")]
        .filter((one) => !one.hidden).map((one) => one.querySelector("h2, summary")?.textContent.trim()));
      const choices = await page.evaluate(() => ({
        comments: document.getElementById("mail-comments").checked,
        kinds: [...document.querySelectorAll("#mail-kinds input[data-kind]")].map((box) => `${box.dataset.kind}:${box.checked}`).join(" "),
        follows: document.getElementById("shows-follows").checked,
        who: document.getElementById("who").textContent, edit: document.getElementById("edit-profile").getAttribute("href") }));
      check(`${label}: ${rows.join(" · ")}`, rows.join(",") === "Profile,Appearance,Email,Privacy,Claude,Sign out,Delete this account…");
      check(`${label}: her choices as she made them (comments ${choices.comments}, ${choices.kinds}, follows shown ${choices.follows})`,
        (!mailReady || (choices.comments && /models:true/.test(choices.kinds) && /remixes:false/.test(choices.kinds)))
        && (!followsReady || choices.follows) && choices.who.includes(adaEmail) && choices.edit === "/profile?edit=1");
      check(`${label}: nothing sideways`, !(await sideways(page)));
      await shot(page, `settings_${width}_${theme}.png`);
      if (width === 1280 && theme === "dark") {
        if (mailReady) {
          await page.check("#mail-remixes");
          await until(page, () => /^On/.test(document.getElementById("mail-said").textContent));
          let me = (await api("/api/people?op=me", { token: ada.access_token })).json;
          check(`an email choice turned on from Settings: remixes ${me.mail.remixes}`, me.mail.remixes === true);
          await page.uncheck("#mail-remixes");
          await until(page, () => /^Off/.test(document.getElementById("mail-said").textContent));
          me = (await api("/api/people?op=me", { token: ada.access_token })).json;
          check(`...and off again: remixes ${me.mail.remixes}, comments ${me.mail.comments}`, me.mail.remixes === false && me.mail.comments === true);
        }
        await page.click('#theme-part [data-theme-choice="light"]');
        check("Appearance: Light, at once", await until(page, () => document.documentElement.dataset.theme === "light"));
        await page.click('#theme-part [data-theme-choice="system"]');
        check("...and System again", await until(page, () => !document.documentElement.dataset.theme));
        await page.click("#edit-profile");
        await page.waitForURL(/\/profile/, { timeout: 20000 }).catch(() => {});
        check("Settings' Edit profile opens the dialog on her profile", await until(page,
          () => document.querySelector("dialog#edit-dialog[open]") && document.getElementById("name").value === "Ada Account", null, 30000));
        await page.click("#cancel");
        await page.click("#to-settings");
        await until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);
        await page.click("#sign-out");
        check("Sign out: the page asks her to sign in", await until(page, () => document.documentElement.dataset.settings === "signed-out"
          && !document.getElementById("signed-out").hidden));
      }
      await context.close();
    }
  }

  // --- 7. Bea, with no profile ------------------------------------------------
  console.log("7. Bea, signed in with no profile");
  for (const width of [390, 1280]) {
    const label = `/profile ${width} no profile`;
    const { page, context } = await open("/profile", { width, theme: width === 390 ? "light" : "dark", who: bea, label });
    await until(page, () => document.documentElement.dataset.profile === "ready", null, 30000);
    const fields = await page.evaluate(() => [...document.querySelectorAll("#start label")].filter((l) => l.offsetParent)
      .map((l) => l.firstChild.textContent.trim()));
    let said = await profileSaid(page);
    check(`${label}: two fields to start (${fields.join(", ")}), the tabs ${said.tabs.map((t) => t.tab).join(" · ")}`,
      said.start && !said.me && fields.join(",") === "Name,Handle" && said.tabs.map((t) => t.tab).join(",") === "saved,sets,insights");
    await shot(page, `start_${width}.png`);
    if (width === 1280) {
      await page.evaluate(() => { window.notReloaded = true; });
      await page.fill("#name", "Bea Start");
      await page.fill("#handle", BEA);
      await page.click("#save");
      await until(page, () => !document.getElementById("me").hidden);
      said = await profileSaid(page);
      check(`${label}: her profile made and drawn at once: "${said.name}", ${said.handle.split(" · ")[0]}, `
        + `tabs ${said.tabs.map((t) => t.tab).join(" · ")}`, said.me && !said.start && said.name === "Bea Start"
        && said.handle.startsWith(`@${BEA}`) && await page.evaluate(() => window.notReloaded === true)
        && said.tabs.map((t) => t.tab).join(",") === "models,builds,saved,sets,insights");
      await shot(page, `started_${width}.png`);
    }
    await context.close();
  }

  // --- 8. Ada deletes her account from Settings -------------------------------
  console.log("8. Ada deletes her account from Settings");
  {
    const again = await mintSession(adaEmail);
    const { page, context } = await open("/settings", { width: 1280, theme: "dark", who: again, label: "delete" });
    await until(page, () => document.documentElement.dataset.settings === "ready", null, 30000);
    page.once("dialog", (dialog) => dialog.accept());
    await page.click("#delete-part summary");
    await page.fill("#delete-confirm", adaEmail);
    await shot(page, "delete_1280.png", false);
    await page.click("#delete-go");
    await until(page, () => document.documentElement.dataset.deleted === "yes", null, 30000);
    const after = await page.evaluate(() => ({ deleted: document.documentElement.dataset.deleted === "yes",
      out: !document.getElementById("signed-out").hidden, said: document.querySelector("#signed-out .lede").textContent,
      kept: localStorage.getItem("brickworks.session") }));
    adaGone = after.deleted && !(await accountExists(adaEmail));
    check(`deleted from Settings: signed out, "${after.said.slice(0, 40)}"`, after.deleted && after.out && !after.kept && /deleted/.test(after.said));
    check("gone from the sign-in service", adaGone);
    const pageAfter = await fetch(`${site}/u/${ADA}?tests=1`, { headers });
    check(`her page after: ${pageAfter.status}`, pageAfter.status === 404);
    for (const id of made) {
      const model = await fetch(`${site}/m/${id}`, { headers });
      check(`her model /m/${id} after: ${model.status}`, model.status === 404 || model.status === 410);
    }
    const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
    const secret = process.env.SUPABASE_SECRET_KEY || "";
    for (const [table, column] of [["people", "account"], ["profile_shows", "account"], ["model_collections", "owner"],
      ["model_favourites", "account"]]) {
      const rows = await fetch(`${base}/rest/v1/${table}?${column}=eq.${adaId}&select=${column}`,
        { headers: { apikey: secret, authorization: `Bearer ${secret}` } });
      const held = rows.ok ? await rows.json() : null;
      check(`her rows of ${table} after: ${held ? held.length : rows.status}`, Array.isArray(held) && held.length === 0);
    }
    await context.close();
  }
} catch (trouble) {
  check(`ran: ${String(trouble?.stack || trouble).split("\n").slice(0, 3).join(" | ")}`, false);
} finally {
  check(`no script errors or refused requests (${errors.length})`, errors.length === 0);
  for (const line of errors.slice(0, 6)) console.log(`        ${line}`);
  await browser.close();
  if (!adaGone && ada) {
    for (const id of made) {
      if (id) await api(`/api/share?op=unpublish&id=${id}`, { method: "POST", token: ada.access_token }).catch(() => {});
    }
  }
  const gone = [adaGone || await deleteAccount(adaEmail), await deleteAccount(beaEmail)];
  check("both throwaway accounts deleted", gone.every(Boolean));
  console.log(`account page: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}
