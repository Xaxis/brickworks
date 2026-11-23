// Every listed model's card drawn as a photograph, path traced on the box's
// graphics card, where it is not one already (cardlook, 2026-11-23).
//
//   node --env-file=.env tools/web/card_sweep.mjs --dry            which, and nothing read
//   node --env-file=.env tools/web/card_sweep.mjs [--most=N]       draw and put them
//   node --env-file=.env tools/web/card_sweep.mjs --ids=A,B        only these links, listed or not
//
// A publish sends the cut-out, and the app then draws the card as a
// photograph and puts it on the link (src/ui/share_panel.gd _card_after,
// api/share.js op=card): traced where the graphics card traces rays, frames
// averaged in a browser, not at all on a phone, and never when the model
// changed while it was drawn. Most publishes come from a browser. So the
// gallery would show three kinds of card side by side; this makes every
// listed one traced, newest first, the lead running it once after the
// house's 49 (gallery_seed.mjs --cards) and then daily.
//
// Which: supabase/card_kind.sql's columns. A card is traced when card_kind
// is 'traced' and card_at is after the last publish (updated_at); anything
// else is the cut-out or a browser's. Before that file is applied there is
// no telling, and the sweep stops and says so (unless --ids names them).
//
// Each model's file is read from the shared-models bucket once, ever: kept
// in CACHE (bench/results/card_sweep/ unless --cache=DIR) under its id and
// the time of its publish, and read again only for a later publish
// (Supabase's egress is the scarce thing, supabase-egress-restriction).
// The cards are drawn by src/dev/card_probe.gd --models under the GPU's
// lease (the box's `gpu`, Xvfb, Forward+), then each is put where op=card
// puts it (shared-thumbs/<id>.webp) with the secret key, and its row told
// card_kind 'traced' and card_at now (api/share.js keepCard). A link
// published again while its card was being drawn is left as it is.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, readdirSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// The checkout this file is in: the app it draws with.
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const dry = Boolean(args.dry);
const most = Number(args.most || 500);
const ids = args.ids ? String(args.ids).split(",").filter(Boolean) : null;
const cache = resolve(ROOT, String(args.cache || "bench/results/card_sweep"));
const SUPABASE = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SECRET = process.env.SUPABASE_SECRET_KEY || "";
if (!SUPABASE || !SECRET) {
  console.error("card_sweep: no SUPABASE_URL / SUPABASE_SECRET_KEY: run it with --env-file=.env");
  process.exit(2);
}
const headers = { apikey: SECRET, authorization: `Bearer ${SECRET}` };

// A request sent again once when the connection itself failed: the files
// are read, then the drawing holds this process for many minutes in the
// GPU's queue, and the first request after it went down a kept-alive
// connection the server had long closed (EPIPE, "fetch failed").
async function send(url, init) {
  try {
    return await fetch(url, init);
  } catch (trouble) {
    if (!(trouble instanceof TypeError)) throw trouble;
    return await fetch(url, { ...init, signal: AbortSignal.timeout(30000) });
  }
}

async function rest(path, init = {}) {
  const reply = await send(`${SUPABASE}/rest/v1/${path}`, {
    ...init, headers: { ...headers, "content-type": "application/json", ...(init.headers || {}) },
    signal: AbortSignal.timeout(30000) });
  const text = await reply.text();
  if (!reply.ok) throw new Error(`${path.split("?")[0]}: ${reply.status} ${text.slice(0, 160)}`);
  return text ? JSON.parse(text) : null;
}

// Whether a card is traced and newer than the model's last publish.
const traced = (row) => row.card_kind === "traced" && row.card_at && Date.parse(row.card_at) >= Date.parse(row.updated_at);
const stamp = (row) => String(Date.parse(row.updated_at) || 0);

let rows;
const columns = "id,name,updated_at,card_kind,card_at";
try {
  rows = ids
    ? await rest(`shared_models?id=in.(${ids.join(",")})&published=is.true&select=${columns}`)
    : await rest(`shared_models?published=is.true&listed=is.true&select=${columns}&order=updated_at.desc&limit=5000`);
} catch (trouble) {
  if (!/card_kind|card_at|: 400 /.test(trouble.message)) throw trouble;
  if (!ids) {
    console.error("card_sweep: supabase/card_kind.sql is not applied, so which cards are traced cannot be told: apply it first");
    process.exit(2);
  }
  rows = (await rest(`shared_models?id=in.(${ids.join(",")})&published=is.true&select=id,name,updated_at`))
    .map((row) => ({ ...row, card_kind: null, card_at: null }));
}
const wanted = rows.filter((row) => ids || !traced(row)).slice(0, most);
console.log(`card_sweep: ${rows.length} ${ids ? "named" : "listed"}, ${rows.filter(traced).length} traced already, `
  + `${wanted.length} to draw${wanted.length < rows.length - rows.filter(traced).length ? ` (--most=${most})` : ""}`);
if (dry) {
  for (const row of wanted) {
    const kept = existsSync(join(cache, `${row.id}@${stamp(row)}.mpd`));
    console.log(`  would draw ${row.id} ${JSON.stringify(row.name)}: card ${row.card_kind || "cut-out"}, file ${kept ? "kept" : "to read"}`);
  }
  process.exit(0);
}
if (wanted.length === 0) process.exit(0);

// The files, each read once.
mkdirSync(cache, { recursive: true });
const models = [];
let read = 0;
for (const row of wanted) {
  const file = join(cache, `${row.id}@${stamp(row)}.mpd`);
  if (!existsSync(file)) {
    const reply = await send(`${SUPABASE}/storage/v1/object/shared-models/${row.id}.mpd`, { headers,
      signal: AbortSignal.timeout(30000) });
    if (!reply.ok) {
      console.log(`  --    ${row.id}: its file: ${reply.status}`);
      continue;
    }
    writeFileSync(file, await reply.text());
    read += 1;
    // An older publish's copy is never read again.
    for (const old of readdirSync(cache)) {
      if (old.startsWith(`${row.id}@`) && old.endsWith(".mpd") && join(cache, old) !== file) unlinkSync(join(cache, old));
    }
  }
  models.push({ id: row.id, file });
}
console.log(`card_sweep: ${read} files read, ${models.length - read} kept from before`);

// Drawn, traced, under the GPU's lease.
const run = join(cache, `run-${Date.now().toString(36)}`);
mkdirSync(run, { recursive: true });
writeFileSync(join(run, "models.json"), JSON.stringify(models));
const godotArgs = ["--path", ROOT, "--resolution", "1400x900", "--script", "src/dev/card_probe.gd", "--",
  `--models=${join(run, "models.json")}`, `--cards=${run}`];
const drawn = spawnSync(join(homedir(), ".claude/claude-core/bin/gpu"),
  ["xvfb-run", "-a", "-s", "-screen 0 1600x900x24", "godot", ...godotArgs],
  { cwd: ROOT, env: { ...process.env, MESA_VK_WSI_DEBUG: "sw" }, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"],
    maxBuffer: 64 * 1024 * 1024 });
for (const line of String(drawn.stdout || "").split("\n")) if (/^ {2}(ok|FAIL)/.test(line)) console.log(line);
const swept = existsSync(join(run, "swept.json")) ? JSON.parse(readFileSync(join(run, "swept.json"), "utf8")) : [];
if (swept.length === 0) {
  console.error(`card_sweep: nothing drawn (exit ${drawn.status}): ${String(drawn.stderr || "").trim().split("\n").slice(-3).join(" | ")}`);
  process.exit(1);
}

// Put, each where op=card puts it, unless published again meanwhile.
let put = 0;
let failed = swept.filter((one) => !one.ok).length;
for (const one of swept.filter((s) => s.ok)) {
  const row = wanted.find((r) => r.id === one.id);
  const now = (await rest(`shared_models?id=eq.${one.id}&select=updated_at,published`))[0];
  if (!now || !now.published || now.updated_at !== row.updated_at) {
    console.log(`  --    ${one.id}: published again or taken down while it was drawn; left as it is`);
    continue;
  }
  const answer = await send(`${SUPABASE}/storage/v1/object/shared-thumbs/${one.id}.webp`, {
    method: "POST", body: readFileSync(join(run, `${one.id}.webp`)),
    headers: { ...headers, "content-type": "image/webp", "x-upsert": "true", "cache-control": "no-store" },
    signal: AbortSignal.timeout(30000) });
  if (!answer.ok) {
    console.log(`  FAIL  ${one.id}: storage ${answer.status}`);
    failed += 1;
    continue;
  }
  try {
    await rest(`shared_models?id=eq.${one.id}`, { method: "PATCH",
      body: JSON.stringify({ has_thumb: true, card_kind: "traced", card_at: new Date().toISOString() }) });
  } catch (trouble) {
    if (!/: 400 /.test(trouble.message)) throw trouble;
    await rest(`shared_models?id=eq.${one.id}`, { method: "PATCH", body: JSON.stringify({ has_thumb: true }) });
    console.log(`  ok    ${one.id}: put (card_kind.sql not applied: its kind not kept)`);
    put += 1;
    continue;
  }
  console.log(`  ok    ${one.id}: put, traced in ${one.ms} ms`);
  put += 1;
}
console.log(`card_sweep: ${put} cards put, ${failed} failed; the drawn ones are in ${run}`);
process.exit(failed ? 1 : 0);
