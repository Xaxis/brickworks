// How a visit came, as the site's pages keep it for a tab (web/theme.js) and
// as the studio reads it (src/account/account.gd, _CAME_JS), page after page
// in one tab (onfix, 2026-11-18). Each page's own code is run in a context of
// its own, sharing only the tab's sessionStorage, as a browser does.
//
//   node tests/fixtures/owner_notify/came_check.mjs
// Prints one JSON line a case, then {"summary": "N of M", "failed": [...]}.
// tests/test_owner_notify.py runs it.
import vm from "node:vm";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
const theme = readFileSync(path.join(ROOT, "web/theme.js"), "utf8");
const from = theme.indexOf("// How this visit came");
const site = theme.slice(from, theme.indexOf("})();", from) + "})();".length);
const account = readFileSync(path.join(ROOT, "src/account/account.gd"), "utf8");
const studio = account.match(/const _CAME_JS := """([\s\S]*?)"""/)?.[1];
if (from < 0 || !studio) throw new Error("the site's or the studio's code was not found");

/// A tab's sessionStorage: kept between its pages, or throwing on each use.
function tab({ throws = false, given = null } = {}) {
  const kept = new Map(given ? [["brickworks.came", given]] : []);
  const store = {
    getItem: (key) => { if (throws) throw new Error("SecurityError"); return kept.has(key) ? kept.get(key) : null; },
    setItem: (key, value) => { if (throws) throw new Error("QuotaExceededError"); kept.set(key, String(value)); },
  };
  return { kept, store };
}

function context(t, href, referrer) {
  const url = new URL(href);
  const ctx = { URL, URLSearchParams, JSON, Object, String, Array, location: { search: url.search, hostname: url.hostname },
    document: { referrer }, sessionStorage: t.store };
  ctx.globalThis = ctx;
  return ctx;
}

/// A site page of [t] at [href], from [referrer]: what the page knows.
function page(t, href, referrer) {
  const ctx = context(t, href, referrer);
  vm.runInNewContext(site, ctx);
  return ctx.brickworksCame ? { ...ctx.brickworksCame } : null;
}

/// The studio at [href], from [referrer], asked as its sign-in asks
/// (Account.came: JSON, an empty object or null read as nothing known).
function app(t, href, referrer) {
  const said = vm.runInNewContext(studio, context(t, href, referrer));
  const got = JSON.parse(said);
  return got && typeof got === "object" && !Array.isArray(got) && Object.keys(got).length ? got : null;
}

const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const results = [];
const verdict = (name, ok, saw) => {
  results.push({ name, ok });
  process.stdout.write(`${JSON.stringify({ name, ok, saw })}\n`);
};

const reddit = { source: "reddit", medium: "social", campaign: "launch", referrer: "www.reddit.com" };
const landing = "https://brickworks.diy/?utm_source=reddit&utm_medium=social&utm_campaign=launch";
{
  const a = tab();
  const one = page(a, landing, "https://www.reddit.com/r/lego/");
  const two = page(a, "https://brickworks.diy/gallery", "https://brickworks.diy/");
  const four = page(a, "https://brickworks.diy/plans?utm_source=newsletter", "https://mail.example.com/");
  verdict("site: the first page's source kept to the next page, and over one from another link",
    same(one, reddit) && same(two, reddit) && same(four, reddit), { one, two, four });
}
{
  const b = tab();
  const plain = page(b, "https://brickworks.diy/", "");
  const keptNothing = b.kept.size === 0;
  const later = page(b, "https://brickworks.diy/gallery?utm_source=forum", "https://forum.example.org/t/1");
  const after = page(b, "https://brickworks.diy/faq", "https://brickworks.diy/gallery");
  verdict("site: a tab that came from nowhere keeps nothing, then the first page that says something",
    plain === null && keptNothing && same(later, { source: "forum", referrer: "forum.example.org" }) && same(after, later),
    { plain, keptNothing, later, after });
}
{
  const d = tab({ throws: true });
  const one = page(d, landing, "https://www.reddit.com/");
  const two = page(d, "https://brickworks.diy/gallery", "https://brickworks.diy/");
  verdict("site: a browser that keeps nothing for the tab: the page's own source still known, the next none, nothing thrown",
    same(one, reddit) && two === null, { one, two });
}
{
  const bad = ["not json", "[1,2]", "7", "null"].map((given) => page(tab({ given }), "https://brickworks.diy/?utm_source=ok", ""));
  verdict("site: something else kept under the name is read as nothing kept", bad.every((one) => same(one, { source: "ok" })), { bad });
}
{
  const preview = page(tab(), "https://brickworks-abc.vercel.app/gallery", "https://brickworks-abc.vercel.app/");
  const own = page(tab(), "https://brickworks.diy/", "https://www.brickworks.diy/x");
  const junk = page(tab(), "https://brickworks.diy/?utm_source=%3Cscript%3E", "not a url");
  verdict("site: its own pages and a tag that is no word are not a source", preview === null && own === null && junk === null,
    { preview, own, junk });
}
{
  const e = tab();
  page(e, landing, "https://www.reddit.com/r/lego/");
  const studioSaw = app(e, "https://brickworks.diy/app", "https://brickworks.diy/");
  verdict("studio: a visit from the landing page signs up in the studio with the landing's source", same(studioSaw, reddit),
    { studioSaw });
}
{
  const f = tab();
  const studioSaw = app(f, "https://brickworks.diy/app?utm_source=reddit&utm_medium=social&utm_campaign=launch",
    "https://www.reddit.com/r/lego/");
  const kept = f.kept.has("brickworks.came");
  const profile = page(f, "https://brickworks.diy/profile?then=%2Fapp&with=orangecheck", "https://brickworks.diy/app");
  verdict("studio: a visit that began at /app knows its own source, kept for the site's sign-in it goes to (orangecheck)",
    same(studioSaw, reddit) && kept && same(profile, reddit), { studioSaw, kept, profile });
}
{
  const g = tab();
  const plain = app(g, "https://brickworks.diy/app", "");
  const own = app(g, "https://brickworks.diy/app", "https://brickworks.diy/gallery");
  const preview = app(g, "https://brickworks-abc.vercel.app/app", "https://brickworks-abc.vercel.app/");
  const junk = app(g, "https://brickworks.diy/app?utm_source=%3Cscript%3E", "not a url");
  verdict("studio: no tags and the site's own pages are nothing, and nothing is kept",
    plain === null && own === null && preview === null && junk === null && g.kept.size === 0, { plain, own, preview, junk });
}
{
  const h = tab({ throws: true });
  let threw = null;
  let studioSaw = null;
  try {
    studioSaw = app(h, "https://brickworks.diy/app?utm_source=forum", "https://forum.example.org/t/1");
  } catch (error) {
    threw = String(error);
  }
  verdict("studio: a browser that keeps nothing for the tab still knows this page's source, nothing thrown",
    threw === null && same(studioSaw, { source: "forum", referrer: "forum.example.org" }), { studioSaw, threw });
}
const failed = results.filter((one) => !one.ok).map((one) => one.name);
process.stdout.write(`${JSON.stringify({ summary: `${results.length - failed.length} of ${results.length}`, failed })}\n`);
