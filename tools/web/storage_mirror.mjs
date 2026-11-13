// The parts bucket as our own browsers read it: from a copy on this machine,
// each object fetched from Supabase at most once.
//
// The bucket (PARTS_URL: part geometry, exact shapes, the model library, set
// pictures, LDraw files) is Supabase's cached egress, which is billed. Every
// check starts a browser with a fresh profile, so each one downloaded every
// part, cover and model it showed again, in every train, every unit preview
// and every bench session's browser. On 2026-11-12 the owner's organisation
// went over its cached egress quota and every Supabase API answered 402.
// Real visitors are untouched: only the browsers our scripts start are
// routed, and every script here that starts Chromium imports browser.mjs,
// which imports this.
//
// An object kept here is served from here. One not kept yet is fetched from
// the bucket once and kept. One past its max-age (library/index.json, five
// minutes) is asked again with its ETag, and a 304 costs no body. The
// bucket's "no such object" (400 or 404) passes through as it came. When the
// bucket cannot answer (402, 403, 429, 5xx, offline), it is read from the
// folders the uploaders send from (tools/storage_parts.py, storage_ldraw.py,
// storage_library.py, set_pictures.py) and not kept, and asked of the bucket
// again a minute later. Each answer says where it came from in
// x-brickworks-mirror (cache, bucket, local), and a run says how many of
// each when it ends.
//
//   BW_STORAGE_MIRROR=DIR   where the copy is ($XDG_CACHE_HOME/brickworks-storage)
//   BW_STORAGE_MIRROR=off   no mirror: the bucket itself
//   { realStore: true }     in chromium.launch or launchPersistentContext's
//                           options: that browser reads the bucket itself
//                           (load_check times a real first visit)
//
//   node tools/web/storage_mirror.mjs serve [PORT]
//     the same copy over HTTP for a headless probe: prints its URL, which
//     stands for PARTS_URL (tools/check.sh --network)
import { chromium } from "playwright";
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, renameSync, statSync, utimesSync, writeFileSync } from "node:fs";
import http from "node:http";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const PUBLIC = "/storage/v1/object/public/parts/";
const HERE = fileURLToPath(new URL("../../", import.meta.url));
const setting = process.env.BW_STORAGE_MIRROR || "";
export const MIRROR = setting === "off" ? ""
  : setting || join(process.env.XDG_CACHE_HOME || join(homedir(), ".cache"), "brickworks-storage");

// Where each uploader sends from, by the object's name.
const SOURCES = [
  [/^[0-9a-f]+\.lbm$/, (name) => `assets/generated/parts/${name}`],
  [/^[0-9a-f]+\.bwx$/, (name) => `assets/generated/exact/${name}`],
  [/^ldraw\/parts\//, (name) => `vendor/${name}`],
  [/^sets\/(card|page)\//, (name) => `vendor/rebrickable/set_pictures/webp/${name.slice(5)}`],
  [/^library\//, (name) => `bench/results/library-2026-10-26/${name}`],
];
// Kept from the bucket's answer and given again with the object.
const KEPT = ["content-type", "cache-control", "etag", "last-modified", "cross-origin-resource-policy"];
const MINUTE = 60 * 1000;

const tally = { cache: [0, 0], bucket: [0, 0], local: [0, 0], passed: [0, 0] };
let asks = 0;
const asking = new Map();
// The bucket's last refusal (402, 5xx, offline), and until when it is not asked.
let bucketDown = { until: 0, why: "", answer: null };
let roots = null;
let complained = false;

// This checkout, then the main one, which a unit's worktree has no
// assets/generated or bench/results of its own without.
function rootsOf() {
  if (roots) return roots;
  roots = [HERE];
  try {
    const common = execFileSync("git", ["-C", HERE, "rev-parse", "--path-format=absolute", "--git-common-dir"],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    if (`${dirname(common)}/` !== HERE) roots.push(`${dirname(common)}/`);
  } catch { /* not a checkout */ }
  return roots;
}

/// The object's name in the bucket, or null for one that could leave the copy.
function nameOf(path) {
  let name;
  try {
    name = decodeURIComponent(path);
  } catch {
    return null;
  }
  const parts = name.split("/");
  return parts.every((part) => part && part !== "." && part !== ".." && !/[\\\0]/.test(part)) ? name : null;
}

function kept(name) {
  const file = join(MIRROR, name);
  try {
    const whole = readFileSync(file);
    const cut = whole.indexOf(10);
    const head = JSON.parse(whole.subarray(0, cut).toString());
    const age = /max-age=(\d+)/.exec(head["cache-control"] || "");
    const fresh = Date.now() - statSync(file).mtimeMs < (age ? Number(age[1]) : 86400) * 1000;
    return { head, body: whole.subarray(cut + 1), fresh, file };
  } catch {
    return null;
  }
}

// The head on its first line, the bytes after: one file, written whole and
// then renamed into place, so a run beside this one never reads half.
function keep(name, head, body) {
  const file = join(MIRROR, name);
  mkdirSync(dirname(file), { recursive: true });
  const part = `${file}.${process.pid}.${Math.random().toString(36).slice(2)}.part`;
  writeFileSync(part, Buffer.concat([Buffer.from(`${JSON.stringify(head)}\n`), body]));
  renameSync(part, file);
}

function local(name) {
  const source = SOURCES.find(([pattern]) => pattern.test(name));
  if (!source) return null;
  for (const root of rootsOf()) {
    try {
      return readFileSync(join(root, source[1](name)));
    } catch { /* not in this checkout */ }
  }
  return null;
}

function answer(from, status, head, body) {
  tally[from][0] += 1;
  tally[from][1] += body.length;
  return { status, body, headers: { ...head, "access-control-allow-origin": "*", "x-brickworks-mirror": from } };
}

// Until the bucket has answered this run, and again after it refuses, one
// ask at a time: a page asking for a hundred parts at once while it answers
// 402 asks it once, not a hundred times.
let trusted = false;
let probe = null;

/// The bucket's answer for [url] ({ status, head, body }), or null while it
/// refuses (402, 403, 429, 5xx, offline: bucketDown).
async function bucket(url, headers) {
  while (!trusted && probe) await probe;
  if (Date.now() < bucketDown.until) return null;
  if (trusted) return ask(url, headers);
  probe = ask(url, headers).finally(() => { probe = null; });
  return probe;
}

async function ask(url, headers) {
  asks += 1;
  try {
    const asked = await fetch(url, { headers, signal: AbortSignal.timeout(5 * MINUTE) });
    const body = Buffer.from(await asked.arrayBuffer());
    const head = Object.fromEntries(KEPT.filter((h) => asked.headers.has(h)).map((h) => [h, asked.headers.get(h)]));
    if (![402, 403, 429].includes(asked.status) && asked.status < 500) {
      trusted = true;
      return { status: asked.status, head, body };
    }
    bucketDown = { until: Date.now() + MINUTE, why: `HTTP ${asked.status}`, answer: [asked.status, head, body] };
  } catch (trouble) {
    const why = String(trouble.message || trouble);
    bucketDown = { until: Date.now() + MINUTE, why, answer: [502, { "content-type": "text/plain" }, Buffer.from(why)] };
  }
  trusted = false;
  return null;
}

async function fetched(name, url) {
  const have = kept(name);
  if (have?.fresh) return answer("cache", 200, have.head, have.body);
  const got = await bucket(url, have?.head.etag ? { "if-none-match": have.head.etag } : {});
  if (got?.status === 304 && have) {
    utimesSync(have.file, new Date(), new Date());
    return answer("cache", 200, have.head, have.body);
  }
  if (got?.status === 200) {
    try {
      keep(name, got.head, got.body);
    } catch (trouble) {
      if (!complained) console.log(`  (storage mirror: could not keep ${name}: ${trouble.message})`);
      complained = true;
    }
    return answer("bucket", 200, got.head, got.body);
  }
  // The bucket's own "no such object" (400, 404), as it came.
  if (got) return answer("passed", got.status, got.head, got.body);
  if (have) return answer("cache", 200, have.head, have.body);
  const body = local(name);
  if (body) return answer("local", 200, { "content-type": "application/octet-stream", "cache-control": "no-cache" }, body);
  return answer("passed", ...bucketDown.answer);
}

/// The object at [path] under the bucket (as a URL has it), from [url] when
/// it has to be fetched: { status, headers, body }.
export function object(path, url) {
  const name = nameOf(path);
  if (!name) return Promise.resolve(answer("passed", 400, { "content-type": "text/plain" }, Buffer.from("no such name")));
  if (!asking.has(name)) asking.set(name, fetched(name, url).finally(() => asking.delete(name)));
  return asking.get(name);
}

const PREFLIGHT = { "access-control-allow-origin": "*", "access-control-allow-methods": "GET, HEAD, OPTIONS",
  "access-control-allow-headers": "*", "access-control-max-age": "3600" };

async function routed(route) {
  const request = route.request();
  const url = new URL(request.url());
  try {
    if (request.method() === "OPTIONS") return await route.fulfill({ status: 204, headers: PREFLIGHT });
    if (!["GET", "HEAD"].includes(request.method())) return await route.fallback();
    return await route.fulfill(await object(url.pathname.slice(PUBLIC.length), `${url.origin}${url.pathname}`));
  } catch (trouble) {
    if (/closed|disposed/i.test(String(trouble.message))) return undefined;
    if (!complained) console.log(`  (storage mirror: ${trouble.message}; from the bucket instead)`);
    complained = true;
    return route.fallback().catch(() => {});
  }
}

/// [context] reads the parts bucket from the mirror.
export async function mirrored(context) {
  await context.route((url) => url.hostname.endsWith(".supabase.co") && url.pathname.startsWith(PUBLIC), routed);
  return context;
}

// Every browser this process starts, whichever script starts it.
const DONE = Symbol.for("brickworks.storageMirror");
if (MIRROR && !chromium[DONE]) {
  chromium[DONE] = true;
  const launch = chromium.launch.bind(chromium);
  chromium.launch = async ({ realStore = false, ...options } = {}) => {
    const browser = await launch(options);
    if (!realStore) {
      const made = browser.newContext.bind(browser);
      browser.newContext = async (contextOptions) => mirrored(await made(contextOptions));
    }
    return browser;
  };
  const persistent = chromium.launchPersistentContext.bind(chromium);
  chromium.launchPersistentContext = async (dir, { realStore = false, ...options } = {}) => {
    const context = await persistent(dir, options);
    return realStore ? context : mirrored(context);
  };
  process.on("exit", () => {
    const said = Object.entries(tally).filter(([, [n]]) => n)
      .map(([from, [n, bytes]]) => `${n} ${from} (${(bytes / 1e6).toFixed(1)} MB)`);
    if (said.length) {
      console.log(`  (storage mirror: ${said.join(", ")}; the bucket asked ${asks} time(s)`
        + `${bucketDown.why ? `, last refusing with ${bucketDown.why}` : ""})`);
    }
  });
}

function partsUrl() {
  if (process.env.PARTS_URL) return process.env.PARTS_URL;
  try {
    const line = readFileSync(join(rootsOf().at(-1), ".env"), "utf8").split("\n").find((l) => l.startsWith("PARTS_URL="));
    return line ? line.slice(10).trim().replace(/^["']|["']$/g, "") : "";
  } catch {
    return "";
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv[2] === "serve") {
  if (!MIRROR) throw new Error("storage mirror: BW_STORAGE_MIRROR=off, nothing to serve");
  const bucket = partsUrl().replace(/\/?$/, "/");
  if (!bucket.includes(PUBLIC)) throw new Error("storage mirror: no PARTS_URL (environment or .env)");
  const server = http.createServer(async (request, response) => {
    const path = new URL(request.url, "http://mirror").pathname.slice(1);
    const got = await object(path, bucket + path);
    response.writeHead(got.status, got.headers);
    response.end(request.method === "HEAD" ? undefined : got.body);
  });
  server.listen(Number(process.argv[3] || 0), "127.0.0.1", () => {
    console.log(`http://127.0.0.1:${server.address().port}/`);
  });
  for (const signal of ["SIGINT", "SIGTERM"]) process.on(signal, () => process.exit(0));
}
