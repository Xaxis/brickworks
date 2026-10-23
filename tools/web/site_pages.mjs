// Every page of the site and the states each is left in, for the checks
// that visit them all: design_flow.mjs (does every control look right)
// and a11y_flow.mjs (can everyone use it). One list, so a page added for
// one is judged by both.
//
//   import { onDeployment, sitePages, visit } from "./site_pages.mjs";
//   const PAGES = sitePages({ remote });
//   const remoteDb = await onDeployment(PAGES, remote, headers);
//   const context = await visit(browser, one, { width, theme, signedIn, web, api, remote, headers, remoteDb });
//
// Each page: where it is, what it waits for before it is judged (ready),
// and what it opens (open), which returns the states it left the page in
// as [label, the part to judge, or null for the whole page]. A label
// ending "(missing)" fails: what was to be opened was not there. open is
// given { width, signedIn, judge }: judge(what, scope) judges a state
// there and then, for one that does not last (First steps' own steps).
// local: the stand-in's alone; signedInOnly, dialogOnly, askAge, admin,
// nobody and fresh say how the page is visited (design_stand_in.mjs).
import * as stand from "./design_stand_in.mjs";

const AUTHORIZE = "/oauth/authorize?response_type=code&client_id=design-flow&redirect_uri="
  + encodeURIComponent("https://claude.ai/api/mcp/auth_callback")
  + "&state=s1&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256";

export const until = (page, test, ms = 8000) => page.waitForFunction(test, null, { timeout: ms }).then(() => true, () => false);

/// The pages, as visited here (remote "") or on a deployment.
export function sitePages({ remote = "" } = {}) {
  return [
    { name: "home", path: "/" },
    { name: "gallery", path: "/gallery",
      ready: (page) => until(page, () => document.querySelectorAll("#models .model").length > 0),
      // Filters, a sheet over the cards at every width (docs/SOCIAL.md U3).
      open: async (page) => {
        await page.click("#filters summary");
        return [["filters", "#filters"]];
      } },
    { name: "model", path: `/m/${stand.MODEL_ID}`,
      // The comments listed (Comment's count), and signed out Report it made
      // live in More. On a deployment the page is its own model, whose
      // comments the stand-in answering the API has none of: there, the
      // comments asked and either listed or said why not.
      ready: (page, { signedIn }) => until(page, signedIn
        ? (remote ? () => !document.getElementById("comments")?.hidden
          || Boolean(document.querySelector("#comments .comments-said")?.textContent)
          : () => !document.getElementById("comments")?.hidden)
        : () => !document.querySelector('[data-report="this model"]')?.hidden),
      open: async (page, { signedIn, judge }) => {
        if (!signedIn) {
          await page.click("#more > summary");
          const shown = await until(page, () => document.querySelector("#more[open]"));
          // Judged open, before Report's dialog covers it.
          if (!shown) return [["more (missing)", ".side"]];
          await page.waitForTimeout(200);
          await judge("more", ".side");
          await page.click('[data-report="this model"]');
          const opened = await until(page, () => document.querySelector("dialog.report[open]"));
          return [[opened ? "report" : "report (missing)", "dialog.report"]];
        }
        // Save: your lists, Favourites first (web/model-page.js).
        await page.click('#marks [data-mark="save"]');
        const saved = await until(page, () => !document.getElementById("save-panel")?.hidden);
        const states = [[saved ? "save" : "save (missing)", ".side"]];
        const add = page.locator("[data-add-build]");
        if (await add.isVisible().catch(() => false)) {
          await add.click();
          const opened = await until(page, () => !document.querySelector("form.build-form")?.hidden);
          states.push([opened ? "add a photo" : "add a photo (missing)", "#builds"]);
        } else states.push(["add a photo (missing)", "#builds"]);
        return states;
      } },
    // A designer's own model in the gallery, signed in: Enter this month's
    // challenge, and its dialog (web/model-page.js enterDialog). Here only:
    // a deployment has no model of the stand-in's account.
    { name: "model-mine", path: "/m/SamModel01", signedInOnly: true,
      ready: (page) => until(page, () => document.querySelector("button[data-enter]")),
      open: async (page) => {
        await page.click("button[data-enter]");
        const opened = await until(page, () => document.querySelector("dialog.enter[open]"));
        return [[opened ? "enter" : "enter (missing)", "dialog.enter"]];
      } },
    { name: "model-older", path: `/m/${stand.MODEL_ID}/v/1` },
    // A model nobody has remixed or liked yet, as most of the live gallery
    // is: its page says no count of none ("0 remixes").
    { name: "model-quiet", path: "/m/DesignFox1", local: true },
    { name: "embed", path: `/m/${stand.MODEL_ID}/embed` },
    { name: "person", path: `/u/${stand.HANDLE}` },
    // A person's other tabs (api/people.js profilePage, docs/SOCIAL.md U5):
    // photos of real builds in columns, and collections as cards; the house
    // account, credited "Brickworks" as the live gallery's models are, and
    // somebody with nothing yet, whose tabs say what goes there. Its More
    // menu open. Here only: the stand-in's people.
    { name: "person-builds", path: `/u/${stand.HANDLE}?tab=builds`, local: true },
    { name: "person-lists", path: `/u/${stand.HANDLE}?tab=collections`, local: true,
      open: async (page) => {
        await page.click(".profile-head .more-menu summary");
        const opened = await until(page, () => document.querySelector(".profile-head .more-menu[open]"));
        return [[opened ? "more" : "more (missing)", ".profile-head .more-menu"]];
      } },
    { name: "person-house", path: "/u/brickworks?tests=1", local: true },
    // The models Robin liked, which Robin chose to show (supabase/avatars.sql):
    // a Likes tab of their cards, and Robin's own picture as the avatar.
    { name: "person-likes", path: `/u/${stand.HANDLE}?tab=likes`, local: true },
    { name: "person-new", path: "/u/new-here", local: true },
    { name: "collection", path: `/c/${stand.LIST_ID}` },
    { name: "challenge", path: "/challenge",
      ready: (page) => until(page, () => document.documentElement.dataset.challenge === "open") },
    // The feed as posts with pictures (docs/SOCIAL.md U9): signed in, what
    // the people Sam follows made, and designers to follow beside it; signed
    // out and following nobody, Latest on Brickworks too.
    { name: "feed", path: "/feed",
      ready: (page, { signedIn }) => (signedIn
        ? until(page, () => document.documentElement.dataset.feed === "ready" && document.querySelectorAll(".feed-row").length > 0)
        : until(page, () => document.documentElement.dataset.feed === "signed-out" && document.querySelectorAll("#latest .model").length > 0)) },
    { name: "feed-nobody", path: "/feed", nobody: true, signedInOnly: true, local: true,
      ready: (page) => until(page, () => document.documentElement.dataset.feed === "ready"
        && document.querySelectorAll("#latest .model").length > 0) },
    // Notifications (docs/SOCIAL.md U7): a group a model, with its picture;
    // and signed in, the account menu open from the avatar (Menu on a phone).
    { name: "notifications", path: "/notifications",
      ready: (page, { signedIn }) => (signedIn ? until(page, () => document.querySelectorAll("#groups .notice").length > 0)
        : until(page, () => document.documentElement.dataset.notifications === "signed-out")),
      open: async (page, { signedIn }) => {
        if (!signedIn) return [];
        const where = (page.viewportSize()?.width || 1280) <= 860 ? ".site-head .menu" : ".site-head .account-menu";
        await page.click(`${where} summary`);
        const opened = await page.waitForFunction((at) => document.querySelector(`${at}[open] .account-part`), where,
          { timeout: 8000 }).then(() => true, () => false);
        return [[opened ? "account menu" : "account menu (missing)", where]];
      } },
    // Your profile (docs/SOCIAL.md U6): your page's head and its first tab;
    // Edit profile's dialog; and the tabs only you see, each its own page.
    { name: "account", path: "/profile",
      ready: (page, { signedIn }) => (signedIn ? until(page, () => document.documentElement.dataset.profile === "ready") : true),
      open: async (page, { signedIn }) => {
        if (signedIn) {
          await page.click("#edit");
          const opened = await until(page, () => document.querySelector("dialog#edit-dialog[open]")
            && document.querySelector("#name")?.value);
          return [[opened ? "edit" : "edit (missing)", "dialog#edit-dialog"]];
        }
        await page.click("#sign-in");
        if (!(await until(page, () => document.querySelector("dialog.sign-in[open]")))) return [["sign-in (missing)", "dialog.sign-in"]];
        const states = [["sign-in", "dialog.sign-in"]];
        await page.fill("dialog.sign-in input", stand.EMAIL);
        await page.click('dialog.sign-in button[type="submit"]');
        const coded = await until(page, () => /code sent/.test(document.querySelector("dialog.sign-in label")?.textContent || ""));
        states.push([coded ? "sign-in code" : "sign-in code (missing)", "dialog.sign-in"]);
        return states;
      } },
    // A picture of your own as your avatar (web/picture.js): one chosen in
    // Edit profile opens the circle to crop it to. Here only: the picture is
    // made here, and sent nowhere.
    { name: "account-picture", path: "/profile", signedInOnly: true, local: true,
      ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready"),
      open: async (page) => {
        await page.click("#edit");
        if (!(await until(page, () => document.querySelector("dialog#edit-dialog[open]")))) return [["edit (missing)", "dialog#edit-dialog"]];
        await page.setInputFiles("#avatar-file", { name: "me.jpg", mimeType: "image/jpeg", buffer: stand.PORTRAIT });
        const opened = await until(page, () => document.querySelector("dialog#crop-dialog[open]")
          && document.querySelector("#crop")?.dataset.zoom);
        return [[opened ? "crop" : "crop (missing)", "dialog#crop-dialog"]];
      } },
    { name: "account-saved", path: "/profile?tab=saved", signedInOnly: true,
      ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready"
        && document.querySelectorAll("#favourites .model").length > 0) },
    { name: "account-sets", path: "/profile?tab=sets", signedInOnly: true,
      ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready") },
    { name: "account-insights", path: "/profile?tab=insights", signedInOnly: true,
      ready: (page) => until(page, () => document.documentElement.dataset.profile === "ready") },
    // Your settings, apart from your profile (docs/SOCIAL.md U6): the same
    // rows the account page ended with.
    { name: "settings", path: "/settings",
      ready: (page, { signedIn }) => (signedIn ? until(page, () => document.documentElement.dataset.settings === "ready")
        : until(page, () => document.documentElement.dataset.settings === "signed-out")),
      open: async (page, { signedIn }) => {
        if (!signedIn) return [];
        await page.click("#delete-part summary");
        const opened = await until(page, () => document.querySelector("#delete-part details[open]"));
        return [[opened ? "delete" : "delete (missing)", "#delete-part"]];
      } },
    // The age question, which a signed-in page asks once of an account that
    // has not answered it: the owner's example. Only the dialog is judged.
    { name: "age", path: "/profile", askAge: true, signedInOnly: true, dialogOnly: true,
      open: async (page) => {
        const opened = await until(page, () => document.querySelector("dialog.age[open]"));
        return [[opened ? "age" : "age (missing)", "dialog.age"]];
      } },
    // First steps after a first sign-in (docs/SOCIAL.md U10, web/first-steps.js):
    // a new account answers the age question on /profile, and each of the
    // three steps is judged, skipped to the next.
    { name: "first-steps", path: "/profile", fresh: true, signedInOnly: true, dialogOnly: true, local: true,
      open: async (page, { judge }) => {
        if (!(await until(page, () => document.querySelector("dialog.age[open]")))) return [["age (missing)", "dialog.age"]];
        await page.selectOption("#age-month", "3");
        await page.selectOption("#age-year", String(new Date().getUTCFullYear() - 30));
        await page.click("#age-go");
        // The first two judged here, before each is skipped; the last as any
        // page's open state is.
        for (const step of ["profile", "kinds", "start"]) {
          const shown = await page.waitForFunction((want) => document.querySelector("dialog.first-steps[open]")?.dataset.step === want
            && (want !== "start" || document.querySelectorAll("dialog.first-steps .model").length > 0), step, { timeout: 8000 })
            .then(() => true, () => false);
          if (!shown) return [[`${step} (missing)`, "dialog.first-steps"]];
          if (step === "start") return [[step, "dialog.first-steps"]];
          await page.waitForTimeout(200);
          await judge(step, "dialog.first-steps");
          await page.click("#first-skip");
        }
        return [];
      } },
    { name: "admin", path: "/admin", admin: true,
      ready: (page, { signedIn }) => (signedIn ? until(page, () => !document.querySelector("#view")?.classList.contains("hide")) : true) },
    { name: "authorize", path: AUTHORIZE,
      ready: (page) => until(page, () => [...document.querySelectorAll("main section")].some((s) => !s.classList.contains("hide"))) },
    { name: "compare", path: "/compare" },
    { name: "download", path: "/download" },
    { name: "faq", path: "/faq" },
    { name: "changelog", path: "/changelog" },
    { name: "terms", path: "/terms" },
    { name: "guidelines", path: "/guidelines" },
    { name: "privacy", path: "/privacy" },
    { name: "takedown", path: "/takedown" },
    { name: "404", path: "/no-such-page-here" },
    // Every component once (web/_kit.html, never published): what no page
    // uses yet is judged as the pages are, its "more" menu open.
    { name: "kit", path: "/_kit", local: true,
      ready: (page) => until(page, () => document.querySelectorAll("#cards .model").length === 3),
      open: async (page) => {
        await page.click("#more summary");
        const opened = await until(page, () => document.querySelector("#more[open]"));
        const states = [[opened ? "more" : "more (missing)", "#more"]];
        // Copy link says so in the toast (web/kit.js), judged and pictured
        // with the menu still open.
        if (opened) {
          await page.click("#copy");
          const said = await until(page, () => document.querySelector("body > .toast.shown")?.textContent === "Link copied");
          states.push([said ? "toast" : "toast (missing)", "body > .toast"]);
        }
        return states;
      } },
  ];
}

/// On a deployment, its own model, person and collection: the stand-in's
/// are not there. Found the way a visitor finds them: the gallery's newest,
/// who shared it, and a collection on their page. Marks the pages it has
/// none of to skip; returns the Supabase project the deployment names
/// ("" when it says none).
export async function onDeployment(PAGES, remote, headers) {
  let remoteDb = "";
  try {
    remoteDb = new URL((await (await fetch(`${remote}/api/account`, { headers })).json()).url).origin;
  } catch { /* none: the stand-in's own */ }
  const text = async (address) => {
    try {
      const reply = await fetch(remote + address, { headers });
      return reply.ok ? await reply.text() : "";
    } catch {
      return "";
    }
  };
  let listed = {};
  try {
    listed = JSON.parse(await text("/api/share?op=list&page=1")) || {};
  } catch { /* none */ }
  const id = (listed.models || [])[0]?.id || "";
  const modelPage = id ? await text(`/m/${id}`) : "";
  const handle = (/\/u\/([a-z0-9-]{3,24})"/.exec(modelPage) || [])[1] || "";
  const personPage = handle ? await text(`/u/${handle}`) : "";
  const list = (/\/c\/([A-Za-z0-9]{10})"/.exec(personPage) || [])[1] || "";
  const found = { model: id && `/m/${id}`, "model-mine": "", "model-older": "", embed: id && `/m/${id}/embed`,
    person: handle && `/u/${handle}`, collection: list && `/c/${list}` };
  for (const one of PAGES) {
    if (!(one.name in found)) continue;
    if (found[one.name]) one.path = found[one.name];
    else {
      one.skip = true;
      console.log(`  skip  ${one.name}: none on this deployment to visit`);
    }
  }
  return remoteDb;
}

/// A browser context for visiting [one] as it asks: [width] (a phone's,
/// with touch, under 600), [theme], signed in or out, the site served by
/// design_stand_in.mjs (or a deployment's, its API answered there).
export async function visit(browser, one, { width, theme, signedIn, web, api, remote = "", headers = {}, remoteDb = "" }) {
  const phone = width < 600;
  const context = await browser.newContext({ viewport: { width, height: phone ? 844 : 900 },
    colorScheme: theme, extraHTTPHeaders: headers,
    ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  await stand.serveSite(context, { web, api, remote, headers, remoteDb,
    state: { askAge: Boolean(one.askAge), admin: Boolean(one.admin), nobody: Boolean(one.nobody),
      ...(one.fresh ? { fresh: { aged: false, profile: null, follows: new Set() } } : {}) } });
  if (signedIn) {
    const asProject = (text) => (remoteDb ? text.split(stand.DB).join(remoteDb) : text);
    const kept = JSON.parse(asProject(JSON.stringify(stand.signedInStorage())));
    await context.addInitScript(([session, access]) => {
      try {
        localStorage.setItem("brickworks.session", session);
        sessionStorage.setItem("brickworks.access", access);
      } catch { /* a browser that keeps nothing */ }
    }, [JSON.stringify(kept.session), JSON.stringify(kept.access)]);
  }
  return context;
}
