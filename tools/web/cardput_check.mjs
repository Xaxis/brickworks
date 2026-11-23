// POST /api/share?op=card: a model's card put on by its owner alone, with
// no publish counted and no version made (cardlook, 2026-11-23).
//
//   node --env-file=.env tools/web/relay_server.mjs 11781 &
//   node --env-file=.env tools/web/cardput_check.mjs --url=http://127.0.0.1:11781
//
// The run's own throwaway account publishes a one-brick model, unlisted,
// with a card; then puts another card on it (op=card), and the model's
// /m/X.webp is the new card's bytes while the model's time of its last
// publish stays as it was. A second throwaway account's op=card on it is refused
// 403, a picture that is not a WebP 415, a link nobody has 404, and no
// sign-in 401. Both accounts are deleted at the end, with the model.
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
  const reply = await fetch(`${base}${path}`, { method: body === undefined ? "GET" : "POST",
    headers: { ...headers, ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body) });
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
} catch (trouble) {
  check(false, `the check stopped: ${trouble.message}`);
} finally {
  await deleteAccount(other).catch(() => {});
  await endOwnAccount();
}
console.log(failed ? `cardput_check: ${failed} FAILED` : "cardput_check: all passed");
process.exit(failed ? 1 : 0);
