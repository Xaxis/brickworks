// What the site's functions read from storage, counted (set3d): a preload
// for tools/web/relay_server.mjs, every read the functions make of the
// parts bucket sent to this machine's copy of it (STORE_MIRROR, the URL
// `node tools/web/storage_mirror.mjs serve PORT` prints) and written down,
// one line a read in STORE_LOG: {at, path, status, bytes}. The bytes a
// page's view would have drawn from Supabase Storage, which bills them as
// egress; tools/web/set3d_flow.mjs --store-log=FILE says them a view.
//
//   STORE_MIRROR=http://127.0.0.1:PORT/ STORE_LOG=FILE \
//     node --env-file=.env --import ./tools/web/store_count.mjs tools/web/relay_server.mjs PORT2
import { appendFileSync } from "node:fs";

const mirror = (process.env.STORE_MIRROR || "").replace(/\/?$/, "/");
const log = process.env.STORE_LOG || "";
const bucket = `${String(process.env.SUPABASE_URL || "").replace(/\/+$/, "")}/storage/v1/object/public/parts/`;
const real = globalThis.fetch;
globalThis.fetch = async (input, init) => {
  const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
  if (!mirror || !url.startsWith(bucket)) return real(input, init);
  const path = url.slice(bucket.length);
  const answer = await real(mirror + path, init);
  const body = await answer.arrayBuffer();
  if (log) appendFileSync(log, `${JSON.stringify({ at: Date.now(), path, status: answer.status, bytes: body.byteLength })}\n`);
  return new Response(body, { status: answer.status, statusText: answer.statusText, headers: answer.headers });
};
