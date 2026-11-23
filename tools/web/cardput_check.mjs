// POST /api/share?op=card: a model's card put on by its owner alone, with
// no publish counted and no version made (cardlook, 2026-11-23).
//
//   node --env-file=.env tools/web/relay_server.mjs 11781 &
//   node --env-file=.env tools/web/cardput_check.mjs --url=http://127.0.0.1:11781 [--dir=CARDS] [--sweep]
//
// The run's own throwaway account publishes a one-brick model, unlisted,
// with a card; then puts another card on it (op=card), and the model's
// /m/X.webp is the new card's bytes while the model's time of its last
// publish stays as it was. A second throwaway account's op=card on it is refused
// 403, a picture that is not a WebP 415, a link nobody has 404, and no
// sign-in 401. With --dir (tools/bench/cardlook.py cards), gallery_seed.mjs
// --cards, run as this account on unlisted models of its own under the
// cards' titles, puts each card on its model. With --sweep, card_sweep.mjs
// --ids draws a model of this account's, traced on the GPU, and puts it.
// Both accounts are deleted at the end, with the models.
import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { deleteAccount, endOwnAccount, mintSession, ownAccount, runAddress } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("cardput_check: --url=<a deployment or a local relay>");
  process.exit(2);
}
const base = String(args.url).replace(/\/+$/, "");
const headers = { "content-type": "application/json" };
if (process.env.BW_BYPASS) headers["x-vercel-protection-bypass"] = process.env.BW_BYPASS;

// Two 1x1 WebPs that differ (lossless, made by hand: RIFF, WEBP, VP8L).
const webp = (rgba) => {
  const pixel = Buffer.from([0x2f, 0x00, 0x00, 0x00, 0x10, 0x07, 0x10, 0x11, 0x11, 0x88, 0x88, 0xfe, 0x07, 0x00]);
  pixel[10] = rgba;
  const chunk = Buffer.concat([Buffer.from("VP8L"), Buffer.from([pixel.length, 0, 0, 0]), pixel]);
  return Buffer.concat([Buffer.from("RIFF"), Buffer.from([chunk.length + 4, 0, 0, 0]), Buffer.from("WEBP"), chunk]);
};
const first = webp(0x88);
const second = webp(0x44);
const MODEL = "0 Card check\n0 Name: card.ldr\n0 Author: cardput_check\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n";

let failed = 0;
const check = (ok, what) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
};
const ask = async (path, token, body) => {
  const init = { method: body === undefined ? "GET" : "POST",
    headers: { ...headers, ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body) };
  // Once more when the connection failed: after the sweep's minutes in the
  // GPU's queue, the kept-alive one to the relay is long closed.
  const reply = await fetch(`${base}${path}`, init).catch((trouble) => {
    if (!(trouble instanceof TypeError)) throw trouble;
    return fetch(`${base}${path}`, init);
  });
  const bytes = Buffer.from(await reply.arrayBuffer());
  let said = {};
  try { said = JSON.parse(bytes.toString("utf8")); } catch { /* a picture */ }
  return { status: reply.status, said, bytes };
};

const other = runAddress();
try {
  const mine = await ownAccount();
  const { access_token: token } = await mintSession(mine);
  const { access_token: theirs } = await mintSession(other);
  const published = await ask("/api/share", token, { name: "Card check", model: MODEL, listed: false,
    thumb: first.toString("base64") });
  check(published.status === 200 || published.status === 201, `published unlisted: ${published.status} ${published.said.error || published.said.id}`);
  const id = published.said.id;
  const rowOf = async () => ((await ask("/api/share?op=mine", token)).said.shared || []).find((row) => row.id === id);
  const before = await rowOf();
  const card = await ask(`/m/${id}.webp`, "");
  check(card.bytes.equals(first), `its card is the one published (${card.bytes.length} bytes)`);

  const put = await ask(`/api/share?op=card&id=${id}`, token, { thumb: second.toString("base64") });
  check(put.status === 200 && put.said.card === true, `op=card by its owner: ${put.status} ${put.said.error || ""}`);
  const after = await ask(`/m/${id}.webp?v=${Date.now().toString(36)}`, "");
  check(after.bytes.equals(second), `its card is the new one (${after.bytes.length} bytes)`);
  const row = await rowOf();
  check(Boolean(row) && row.updated_at === before?.updated_at && row.has_thumb === true,
    `no publish and no version: updated ${row?.updated_at} as before (${before?.updated_at})`);

  const stranger = await ask(`/api/share?op=card&id=${id}`, theirs, { thumb: first.toString("base64") });
  check(stranger.status === 403, `another account's op=card refused: ${stranger.status} ${stranger.said.error || ""}`);
  const still = await ask(`/m/${id}.webp?v=x${Date.now().toString(36)}`, "");
  check(still.bytes.equals(second), "and its card is still the owner's");
  const png = await ask(`/api/share?op=card&id=${id}`, token, { thumb: Buffer.from("not a picture at all").toString("base64") });
  check(png.status === 415, `a picture that is not a WebP refused: ${png.status} ${png.said.error || ""}`);
  const none = await ask("/api/share?op=card&id=Zz9Zz9Zz9Z", token, { thumb: second.toString("base64") });
  check(none.status === 404 || none.status === 400, `a link nobody has: ${none.status} ${none.said.error || ""}`);
  const nobody = await ask(`/api/share?op=card&id=${id}`, "", { thumb: second.toString("base64") });
  check(nobody.status === 401, `no sign-in refused: ${nobody.status} ${nobody.said.error || ""}`);
  await ask(`/api/share?op=unpublish&id=${id}`, token, {});

  // --dir=CARDS (tools/bench/cardlook.py cards): gallery_seed.mjs --cards
  // run as this account, on unlisted models of its own under the bodies'
  // titles, puts each body's card on its model and nothing else.
  if (args.dir) {
    const bodies = readdirSync(String(args.dir)).filter((f) => /^\d+\.json$/.test(f))
      .map((f) => JSON.parse(readFileSync(join(String(args.dir), f), "utf8")));
    const ids = new Map();
    for (const body of bodies) {
      const made = await ask("/api/share", token, { name: body.name, model: MODEL, listed: false, thumb: first.toString("base64") });
      ids.set(body.name, made.said.id);
    }
    const ran = spawnSync(process.execPath, ["tools/web/gallery_seed.mjs", `--url=${base}`, `--dir=${args.dir}`, "--cards"],
      { env: { ...process.env, GALLERY_EMAIL: mine }, encoding: "utf8" });
    check(ran.status === 0, `gallery_seed.mjs --cards: exit ${ran.status}: ${ran.stdout.trim().split("\n").pop()}`);
    for (const body of bodies) {
      const got = await ask(`/m/${ids.get(body.name)}.webp?v=c${Date.now().toString(36)}`, "");
      check(got.bytes.equals(Buffer.from(body.thumb, "base64")), `${body.name}: its card is the body's (${got.bytes.length} bytes)`);
      await ask(`/api/share?op=unpublish&id=${ids.get(body.name)}`, token, {});
    }
  }

  // --sweep: tools/web/card_sweep.mjs --ids on an unlisted model of this
  // account's, published with a cut-out card: the card it puts is a
  // 480 x 360 WebP with no clear pixels, and a second sweep reads its file
  // from the cache, not the bucket.
  if (args.sweep) {
    const made = await ask("/api/share", token, { name: "Card sweep check", listed: false,
      model: readFileSync("models/sports_car.ldr", "utf8"), thumb: first.toString("base64") });
    const swept = made.said.id;
    check(Boolean(swept), `a model to sweep: ${made.status} ${swept || made.said.error}`);
    const cache = `/tmp/card_sweep_check.${process.pid}`;
    const once = spawnSync(process.execPath, ["tools/web/card_sweep.mjs", `--ids=${swept}`, `--cache=${cache}`],
      { env: process.env, encoding: "utf8", timeout: 6 * 3600 * 1000 });
    const said = once.stdout.trim().split("\n");
    check(once.status === 0 && said.some((line) => line.includes(`ok    ${swept}: put`)),
      `card_sweep.mjs put its card: exit ${once.status}: ${said.slice(-3).join(" | ")} ${once.stderr.trim().slice(-200)}`);
    const card = await ask(`/m/${swept}.webp?v=s${Date.now().toString(36)}`, "");
    const chunk = card.bytes.subarray(12, 16).toString("latin1");
    const alpha = chunk === "VP8X" ? (card.bytes[20] & 0x10) !== 0 : chunk === "VP8L" ? (card.bytes[24] & 0x10) !== 0 : false;
    check(card.bytes.subarray(8, 12).toString("latin1") === "WEBP" && !card.bytes.equals(first) && !alpha,
      `its card is the sweep's photograph: a ${card.bytes.length}-byte WebP, ${chunk}, ${alpha ? "with" : "no"} clear pixels`);
    const again = spawnSync(process.execPath, ["tools/web/card_sweep.mjs", `--ids=${swept}`, `--cache=${cache}`, "--dry"],
      { env: process.env, encoding: "utf8" });
    check(again.stdout.includes("file kept"), `a second sweep reads its file from the cache: ${again.stdout.trim().split("\n").pop()}`);
    await ask(`/api/share?op=unpublish&id=${swept}`, token, {});
  }
} catch (trouble) {
  check(false, `the check stopped: ${trouble.message}`);
} finally {
  await deleteAccount(other).catch(() => {});
  await endOwnAccount();
}
console.log(failed ? `cardput_check: ${failed} FAILED` : "cardput_check: all passed");
process.exit(failed ? 1 : 0);
