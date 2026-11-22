// Does a search engine read a person's page as a person, and a list's as
// what is in it? (seo2, docs/SOCIAL.md "The units, in waves", rank 9)
//
//   node tools/web/seo_check.mjs                         this checkout's api/, on the design stand-in's people and lists
//   node tools/web/seo_check.mjs --before=DIR            and each page's <body> the same as DIR's api/ draws it
//   node tools/web/seo_check.mjs --root=DIR              another checkout's api/ (an old one, to see it fail)
//   BW_BYPASS=$VERCEL_BYPASS node tools/web/seo_check.mjs --url=<a preview>
//
// Every /u/ and /c/ page its sitemap lists, each in English, German, French
// and Spanish, each of a profile's tabs and the next page of what is paged
// (the head's rel="next"), read as the server sends it, as a crawler reads
// it:
//
// - a profile carries one ProfilePage whose mainEntity is a Person: their
//   name as its heading says it, their handle, the page's own address, an
//   image that answers as a picture (theirs, or the tile they are shown as,
//   ?op=avatar&handle=), and their numbers as the page shows them: followers
//   as interactionStatistic (FollowAction); their models (WriteAction) and
//   whom they follow (FollowAction) as agentInteractionStatistic, as Google's
//   profile pages read them. A number the page does not show (hidden at
//   none) is 0 there, and one the page could not read is not there at all.
// - a public list carries one CollectionPage with hasPart: its name as its
//   heading, its owner, and one CreativeWork for each card on the page, in
//   order, each at the address its card links to (a set never a Product).
// - each parses as schema.org: JSON, the schema.org context, every type one
//   of schema.org's, every property one of schema.org's on that type (or a
//   type it is a kind of), and every value in that property's range: a type
//   the range names (a schema.org address in place of a type names that
//   type), text where it takes text, a whole number for an Integer, an ISO
//   8601 date for a Date or DateTime. Read against schema.org's own
//   vocabulary, fetched once a month to ~/.cache/brickworks/.
// - a page that is not there (an unknown handle, a list that is not public
//   or not there) carries neither.
//
// With --before (the stand-in only): each page's <body>, all a person sees,
// byte for byte what the other checkout's api/ draws: the data is in the
// head and nothing visible changed.
//
// Reads only: no account, no write. About 20 s against a preview.
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const here = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const root = args.root ? path.resolve(String(args.root)) : here;
const remote = args.url ? String(args.url).replace(/\/+$/, "").replace(/\/app$/, "") : "";
const bypass = process.env.BW_BYPASS || "";
const LANGS = ["", "/de", "/fr", "/es"];
const VOCAB = "https://schema.org/version/latest/schemaorg-current-https.jsonld";

let failures = 0;
let checks = 0;
let setsSeen = 0;
const check = (ok, what) => {
  checks += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failures += 1;
};

// ---------------------------------------------------------------------------
// schema.org's vocabulary: its types, what each is a kind of, and its
// properties' domains and ranges.

async function vocabulary() {
  const dir = path.join(process.env.XDG_CACHE_HOME || path.join(homedir(), ".cache"), "brickworks");
  const file = path.join(dir, "schemaorg-current-https.jsonld");
  const fresh = existsSync(file) && Date.now() - statSync(file).mtimeMs < 30 * 86400e3;
  if (!fresh) {
    try {
      const got = await fetch(VOCAB, { signal: AbortSignal.timeout(60_000) });
      if (!got.ok) throw new Error(`${got.status}`);
      const text = await got.text();
      JSON.parse(text);
      mkdirSync(dir, { recursive: true });
      writeFileSync(file, text);
    } catch (trouble) {
      if (!existsSync(file)) throw new Error(`schema.org's vocabulary could not be fetched (${trouble.message})`);
      console.log(`  (schema.org's vocabulary not fetched again: ${trouble.message}; the copy kept is used)`);
    }
  }
  const graph = JSON.parse(readFileSync(file, "utf8"))["@graph"];
  const name = (ref) => String(ref?.["@id"] ?? ref).replace(/^schema:/, "");
  const list = (value) => [].concat(value ?? []).map(name);
  const classes = new Map();
  const props = new Map();
  for (const node of graph) {
    const types = [].concat(node["@type"]);
    if (!String(node["@id"]).startsWith("schema:")) continue;
    if (types.includes("rdfs:Class") || types.includes("schema:DataType")) {
      classes.set(name(node), list(node["rdfs:subClassOf"]));
    }
    if (types.includes("rdf:Property")) {
      props.set(name(node), { domain: list(node["schema:domainIncludes"]), range: list(node["schema:rangeIncludes"]) });
    }
  }
  const kinds = new Map();
  const kindsOf = (type) => {
    if (!kinds.has(type)) {
      const found = new Set([type]);
      kinds.set(type, found);
      for (const parent of classes.get(type) || []) for (const one of kindsOf(parent)) found.add(one);
    }
    return kinds.get(type);
  };
  return { classes, props, kindsOf };
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const ISO_DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$/;

/// Every way [data] is not schema.org: a list of where and why.
function conformance(vocab, data) {
  const problems = [];
  const { classes, props, kindsOf } = vocab;
  const textual = (range) => range.some((type) => kindsOf(type).has("Text"));
  const fits = (value, range) => {
    if (value && typeof value === "object") {
      const types = [].concat(value["@type"] || []);
      return types.some((type) => range.some((wanted) => kindsOf(type).has(wanted))) || `a ${types.join("/")} where ${range.join(" or ")} goes`;
    }
    if (typeof value === "number") {
      if (range.includes("Integer") && Number.isInteger(value)) return true;
      return range.some((type) => ["Number", "Float"].includes(type)) || `a number where ${range.join(" or ")} goes`;
    }
    if (typeof value === "boolean") return range.includes("Boolean") || `true/false where ${range.join(" or ")} goes`;
    if (typeof value !== "string") return `${typeof value} where ${range.join(" or ")} goes`;
    if (range.includes("Date") && ISO_DATE.test(value)) return true;
    if (range.includes("DateTime") && ISO_DATETIME.test(value)) return true;
    // A type named by its address: that type, in the range.
    const named = /^https?:\/\/schema\.org\/([A-Za-z]+)$/.exec(value);
    if (named && classes.has(named[1])) {
      return range.some((wanted) => kindsOf(named[1]).has(wanted)) || `${named[1]} where ${range.join(" or ")} goes`;
    }
    if (textual(range)) {
      if (range.includes("URL") && !textual(range.filter((type) => type !== "URL")) && !/^https?:\/\//.test(value)) {
        return `"${value.slice(0, 40)}" is not an address`;
      }
      return true;
    }
    // Any other type may be given by its address (a reference).
    return (/^https?:\/\//.test(value) && range.some((type) => classes.has(type))) || `"${value.slice(0, 40)}" where ${range.join(" or ")} goes`;
  };
  const walk = (node, where) => {
    const types = [].concat(node["@type"] || []);
    if (!types.length) problems.push(`${where}: no @type`);
    for (const type of types) if (!classes.has(type)) problems.push(`${where}: ${type} is not a schema.org type`);
    const kinds = new Set(types.flatMap((type) => [...kindsOf(type)]));
    for (const [key, value] of Object.entries(node)) {
      if (key.startsWith("@")) continue;
      const prop = props.get(key);
      if (!prop) {
        problems.push(`${where}.${key}: not a schema.org property`);
        continue;
      }
      if (!prop.domain.some((type) => kinds.has(type))) problems.push(`${where}.${key}: not a property of ${types.join("/")}`);
      const many = Array.isArray(value);
      [].concat(value).forEach((one, at) => {
        const said = many ? `${where}.${key}[${at}]` : `${where}.${key}`;
        if (one === null || one === undefined) {
          problems.push(`${said}: empty`);
          return;
        }
        const fit = fits(one, prop.range);
        if (fit !== true) problems.push(`${said}: ${fit}`);
        if (one && typeof one === "object" && !Array.isArray(one)) walk(one, said);
      });
    }
  };
  for (const [at, node] of [].concat(data).entries()) {
    const where = Array.isArray(data) ? `[${at}]` : "";
    if (!/^https?:\/\/schema\.org\/?$/.test(String(node?.["@context"] || ""))) problems.push(`${where}@context: not schema.org`);
    walk(node || {}, where || node?.["@type"] || "?");
  }
  return problems;
}

// ---------------------------------------------------------------------------
// Pages, from a deployment or from the stand-in.

const standIn = remote ? null : await import("./design_stand_in.mjs");
const origin = remote || standIn.ORIGIN;

async function get(address, apiDir = path.join(root, "api")) {
  const where = address.startsWith("http") ? new URL(address) : new URL(address, origin);
  if (remote) {
    const answer = await fetch(where, { headers: bypass ? { "x-vercel-protection-bypass": bypass } : {}, redirect: "manual",
      signal: AbortSignal.timeout(60_000) });
    const type = answer.headers.get("content-type") || "";
    const body = Buffer.from(await answer.arrayBuffer());
    return { status: answer.status, type, html: body.toString("utf8"), size: body.length };
  }
  const asked = `${where.pathname}${where.search}`;
  if (where.pathname.startsWith("/api/people")) {
    const said = await standIn.serverAsk(apiDir, { name: "people", query: Object.fromEntries(where.searchParams) });
    return { status: said.status, type: String(said.headers["content-type"] || ""), html: said.html,
      size: said.bytes ? said.bytes.length : Buffer.byteLength(said.html || "") };
  }
  const said = await standIn.serverPage(apiDir, asked);
  return { status: said.status, type: String(said.headers["content-type"] || ""), html: said.html,
    size: said.bytes ? said.bytes.length : Buffer.byteLength(said.html || "") };
}

const unescape = (text) => String(text).replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
  .replace(/&#0?39;/g, "'").replace(/&#x27;/g, "'").replace(/&amp;/g, "&");
const headOf = (html) => html.split("</head>")[0];
const blocksOf = (html) => [...headOf(html).matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const canonicalOf = (html) => unescape(/<link rel="canonical" href="([^"]+)">/.exec(html)?.[1] || "");
const nextOf = (html) => unescape(/<link rel="next" href="([^"]+)">/.exec(headOf(html))?.[1] || "");
const headingOf = (html) => unescape(/<h1>([\s\S]*?)<\/h1>/.exec(html)?.[1] || "");
/// The number in a page's [data-stat=kind], 0 when it is hidden at none,
/// null when the page does not show that number at all.
const statOf = (html, kind) => {
  const found = new RegExp(`<li data-stat="${kind}"[^>]*?( hidden)?><b>([^<]*)</b>`).exec(html);
  if (!found) return null;
  return found[1] ? 0 : Number(found[2].replace(/\D/g, ""));
};
const counted = (person, field, action) => [].concat(person?.[field] || [])
  .filter((one) => one?.interactionType === `https://schema.org/${action}`);

/// robots.txt's rules for every crawler (the "*" group): whether a crawler
/// may fetch [address], by RFC 9309: the longest rule that matches wins, an
/// Allow on a tie; "*" any run of characters, a "$" at the end the end.
function robotsOf(text) {
  const rules = [];
  let agents = [];
  let agentLine = false;
  for (const raw of String(text).split(/\r?\n/)) {
    const line = raw.replace(/#.*/, "").trim();
    const colon = line.indexOf(":");
    if (colon < 0) continue;
    const key = line.slice(0, colon).trim().toLowerCase();
    const value = line.slice(colon + 1).trim();
    if (key === "user-agent") {
      if (!agentLine) agents = [];
      agents.push(value.toLowerCase());
      agentLine = true;
      continue;
    }
    agentLine = false;
    if ((key === "allow" || key === "disallow") && value && agents.includes("*")) {
      const pattern = value.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\\\$$/, "$");
      rules.push({ allow: key === "allow", length: value.length, test: new RegExp(`^${pattern}`) });
    }
  }
  return (address) => {
    const where = new URL(address, origin);
    const asked = `${where.pathname}${where.search}`;
    let best = null;
    for (const rule of rules) {
      if (!rule.test.test(asked)) continue;
      if (!best || rule.length > best.length || (rule.length === best.length && rule.allow)) best = rule;
    }
    return !best || best.allow;
  };
}
let mayCrawl = () => true;

/// Every address of this site in [data] (its own, its parts', their
/// pictures'): another site's (sameAs) is that site's to say.
const addressesIn = (data, found = []) => {
  if (Array.isArray(data)) data.forEach((one) => addressesIn(one, found));
  else if (data && typeof data === "object") Object.values(data).forEach((one) => addressesIn(one, found));
  else if (typeof data === "string" && data.startsWith(`${origin}/`)) found.push(data);
  return found;
};

/// The one block of [type] on [html], parsed, with what is wrong with it:
/// as schema.org, and any address in it robots.txt keeps a crawler from.
function readData(vocab, html, type) {
  const blocks = blocksOf(html);
  const parsed = [];
  for (const block of blocks) {
    try {
      parsed.push(JSON.parse(block));
    } catch (trouble) {
      return { problems: [`not JSON: ${trouble.message}`] };
    }
  }
  const mine = parsed.filter((one) => one?.["@type"] === type);
  if (mine.length !== 1) return { problems: [`${mine.length} ${type} blocks, of ${blocks.length}`] };
  const shut = [...new Set(addressesIn(mine[0]).filter((one) => !mayCrawl(one)))];
  return { data: mine[0], problems: [...conformance(vocab, mine[0]), ...shut.map((one) => `robots.txt keeps out ${one.replace(origin, "")}`)] };
}

async function picture(address, what) {
  const got = await get(address);
  check(got.status === 200 && /^image\//.test(got.type) && got.size > 0,
    `${what}: its image answers as a picture (${address.replace(origin, "")}: ${got.status}, ${got.type}, ${got.size} bytes)`);
}

async function profile(vocab, address, { images }) {
  const got = await get(address);
  const shown = address.replace(origin, "");
  if (got.status !== 200) return check(false, `${shown}: answers (${got.status})`);
  const { data, problems } = readData(vocab, got.html, "ProfilePage");
  check(!problems.length, `${shown}: one ProfilePage, schema.org through and through, each address in it open to a crawler${problems.length ? `: ${problems.slice(0, 4).join("; ")}` : ""}`);
  if (!data) return null;
  const person = data.mainEntity || {};
  const handle = /\/u\/([a-z0-9-]+)/.exec(shown)[1];
  const followers = counted(person, "interactionStatistic", "FollowAction");
  const models = counted(person, "agentInteractionStatistic", "WriteAction");
  const follows = counted(person, "agentInteractionStatistic", "FollowAction");
  const said = { followers: statOf(got.html, "followers"), models: statOf(got.html, "models"), following: statOf(got.html, "following") };
  const agrees = (counters, n) => (n === null ? counters.length === 0 : counters.length === 1 && counters[0].userInteractionCount === n);
  check(person["@type"] === "Person" && person.name === headingOf(got.html) && person.alternateName === `@${handle}`
    && person.identifier === handle && person.url === `${origin}/u/${handle}` && data.url === canonicalOf(got.html)
    && typeof person.image === "string" && person.image.startsWith(`${origin}/api/people?op=avatar&`)
    && agrees(followers, said.followers) && agrees(models, said.models) && agrees(follows, said.following),
  `${shown}: a Person, "${person.name}" (@${handle}) at ${String(person.url).replace(origin, "")}, ${followers[0]?.userInteractionCount ?? "no"} followers, `
    + `${models[0]?.userInteractionCount ?? "no"} models, following ${follows[0]?.userInteractionCount ?? "no"}, as the page shows `
    + `(${said.followers ?? "-"}, ${said.models ?? "-"}, ${said.following ?? "-"})`);
  if (images && person.image) await picture(person.image, `${shown}'s Person`);
  return got.html;
}

async function collection(vocab, address, { images }) {
  const got = await get(address);
  const shown = address.replace(origin, "");
  if (got.status !== 200) return check(false, `${shown}: answers (${got.status})`);
  const { data, problems } = readData(vocab, got.html, "CollectionPage");
  check(!problems.length, `${shown}: one CollectionPage, schema.org through and through, each address in it open to a crawler${problems.length ? `: ${problems.slice(0, 4).join("; ")}` : ""}`);
  if (!data) return null;
  const cards = [...got.html.matchAll(/<a class="open" href="([^"]+)">/g)].map((m) => `${origin}${unescape(m[1])}`);
  const parts = [].concat(data.hasPart || []);
  const by = /<p class="handle">[^<]*<a href="([^"]+)">([^<]*)<\/a>/.exec(got.html);
  const sets = parts.filter((part) => /\/library\/set\/[^/]+$/.test(part.url) && part.identifier && !/Product|offers|price/i.test(JSON.stringify(part)));
  setsSeen += sets.length;
  check(Array.isArray(data.hasPart) && data.name === headingOf(got.html) && data.url === canonicalOf(got.html)
    && parts.length === cards.length && parts.every((part, at) => part["@type"] === "CreativeWork" && part.url === cards[at] && part.name)
    && (!by || (data.author?.name === unescape(by[2]) && data.author?.url === `${origin}${unescape(by[1]).replace(/^\/(de|fr|es)\//, "/")}`)),
  `${shown}: "${data.name}" by ${data.author?.name || "nobody named"}, hasPart ${parts.length} CreativeWorks, each its card's (${cards.length} cards), of them ${sets.length} sets`);
  if (images && data.image) await picture(data.image, `${shown}'s CollectionPage`);
  return got.html;
}

const HOSTILE = "Hi </script><script>alert(1)</script> <!-- <script> \u2028 \"quoted\" \\ back";
const vocab = await vocabulary();
console.log(`schema.org: ${vocab.classes.size} types, ${vocab.props.size} properties`);

// The vocabulary check itself, on what it must refuse.
const refused = conformance(vocab, { "@context": "https://schema.org", "@type": "ProfilePage",
  mainEntity: { "@type": "Person", name: "x", followers: 3, image: { "@type": "Offer" },
    interactionStatistic: { "@type": "InteractionCounter", interactionType: "https://schema.org/Person", userInteractionCount: 1.5 } },
  hasPart: [{ "@type": "Brick" }], sameAs: "not an address", dateCreated: "last week" });
const wanted = [/mainEntity\.followers: not a schema\.org property/, /mainEntity\.image: a Offer where/,
  /interactionType: Person where Action goes/, /userInteractionCount: a number where Integer goes/, /Brick is not a schema\.org type/,
  /sameAs: "not an address" is not an address/, /dateCreated: "last week" where/];
check(wanted.every((one) => refused.some((said) => one.test(said))) && refused.length === wanted.length + 1,
  `the vocabulary check refuses a made-up property, a type out of a range, a type that is no action, a fraction for an Integer, `
  + `an unknown type, text for a URL and a date in words (${refused.length}: ${refused.join("; ")})`);

// What robots.txt lets a crawler fetch, and that it reads as meant.
const robotsText = remote ? (await get("/robots.txt")).html : readFileSync(path.join(root, "web", "robots.txt"), "utf8");
mayCrawl = robotsOf(robotsText);
const tile = "/api/people?op=avatar&handle=sam-builds";
check(mayCrawl("/u/sam-builds") && mayCrawl(tile) && mayCrawl("/api/people?op=avatar&id=FacePriya1") && !mayCrawl("/api/people?op=me")
  && !mayCrawl("/api/share?op=list") && !mayCrawl("/admin"), `robots.txt lets a crawler fetch a profile and a person's picture or tile, `
  + `and keeps it from the rest of the API and /admin (${robotsText.split("\n").filter((line) => /^(Allow|Disallow):/.test(line)).length} rules)`);

// What the sitemap lists.
const map = await get("/sitemap.xml");
const listed = [...map.html.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(unescape(m[1])).pathname);
const people = [...new Set(listed.filter((one) => /^\/u\/[a-z0-9-]+$/.test(one)))];
const lists = [...new Set(listed.filter((one) => /^\/c\/[A-Za-z0-9]{10}$/.test(one)))];
check(map.status === 200 && (standIn || (people.length > 0 && lists.length > 0)),
  `the sitemap lists ${people.length} profiles and ${lists.length} public lists (${map.status})`);
// The stand-in's sitemap lists no people or lists: its own, a designer, a
// builder with a picture and one with none and nothing made; and a set put
// in one of its lists, which hold models alone (as list_items answers once
// the stand-in's fetch, put in place by the call above, has answered it).
if (standIn) {
  for (const handle of [standIn.HANDLE, "sam-builds", "new-here", "priya-plays"]) if (!people.includes(`/u/${handle}`)) people.push(`/u/${handle}`);
  for (const id of [standIn.LIST_ID, "ListSmall1"]) if (!lists.includes(`/c/${id}`)) lists.push(`/c/${id}`);
  // And words a person typed that try to end the block or break its JSON:
  // Alex's bio, as the profile's row gives it.
  const answered = globalThis.fetch;
  const json = (value) => new Response(JSON.stringify(value), { status: 200, headers: { "content-type": "application/json" } });
  globalThis.fetch = async (input, init = {}) => {
    const answer = await answered(input, init);
    const asked = typeof input === "string" || input instanceof URL ? String(input) : input.url;
    if (asked.startsWith(`${standIn.DB}/rest/v1/people?handle=eq.new-here&`)) {
      return json((await answer.json()).map((row) => ({ ...row, bio: HOSTILE })));
    }
    if (asked !== `${standIn.DB}/rest/v1/rpc/list_items` || JSON.parse(init.body || "{}").list !== "ListSmall1") return answer;
    return json([...await answer.json(), { kind: "set", key: "10497-1", at: "2026-10-01T00:00:00Z", position: null }]);
  };
}

const pages = [];
for (const where of people) {
  for (const lang of LANGS) {
    const html = await profile(vocab, `${origin}${lang}${where}`, { images: lang === "" });
    if (!html) continue;
    pages.push(`${lang}${where}`);
    if (lang !== "") continue;
    // Each tab it shows, and the next page of what is paged.
    const tabs = [...html.matchAll(/<a href="([^"]+)" data-tab="([a-z]+)"/g)].map((m) => unescape(m[1]));
    for (const tab of tabs) {
      const tabbed = await profile(vocab, `${origin}${tab}`, { images: false });
      if (tabbed) pages.push(tab);
      const next = tabbed && nextOf(tabbed);
      if (next && await profile(vocab, next.startsWith("http") ? next : `${origin}${next}`, { images: false })) pages.push(next);
    }
  }
}
for (const where of lists) {
  for (const lang of LANGS) {
    const html = await collection(vocab, `${origin}${lang}${where}`, { images: lang === "" });
    if (!html) continue;
    pages.push(`${lang}${where}`);
    const next = nextOf(html);
    if (next && await collection(vocab, next.startsWith("http") ? next : `${origin}${next}`, { images: false })) pages.push(next);
  }
}

if (standIn) {
  const got = await get("/u/new-here");
  const head = headOf(got.html);
  const block = readData(vocab, got.html, "ProfilePage");
  check(block.data?.mainEntity?.description === HOSTILE && (head.match(/<script\b/g) || []).length === (head.match(/<\/script>/g) || []).length,
    `a bio that tries to end the block (</script>, <!--, a line separator, quotes) is read back whole, and every script in the head ends once`);
}
if (standIn) check(setsSeen >= 4, `a set in a list is a CreativeWork at its own page, never a Product, in each language (${setsSeen} seen)`);

// Pages that are not there carry neither.
for (const gone of ["/u/nobody-has-this", "/c/NoListHere"]) {
  const got = await get(gone);
  check(got.status === 404 && !/ProfilePage|CollectionPage/.test(got.html), `${gone}: not there, and no structured data (${got.status})`);
}

// Nothing a person sees changed: each page's body as the other checkout draws it.
if (args.before && standIn) {
  const before = path.join(path.resolve(String(args.before)), "api");
  let same = 0;
  const differ = [];
  for (const where of pages) {
    const [now, then] = await Promise.all([get(where), get(where, before)]);
    const body = (html) => html.slice(html.indexOf("</head>"));
    if (body(now.html) === body(then.html) && now.status === then.status) same += 1;
    else differ.push(where);
  }
  check(!differ.length && same === pages.length, `each page's <body> byte for byte as ${args.before} draws it: ${same} of ${pages.length}`
    + `${differ.length ? ` (differ: ${differ.slice(0, 5).join(", ")})` : ""}`);
}

console.log(`${failures ? "FAIL" : "PASS"}: ${checks - failures} of ${checks} (${pages.length} pages read)`);
process.exit(failures ? 1 : 0);
