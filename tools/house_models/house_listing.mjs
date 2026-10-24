// Read-only: the house account's own models and the public gallery, written
// to a JSON file, to compare before and after a seed (compare.py).
//
//   set -a; . ./.env; set +a
//   node tools/house_models/house_listing.mjs OUT.json [--url=https://brickworks.diy]
//
// The house account (GALLERY_EMAIL, gallery@brickworks.diy unless said) is
// signed in as gallery_seed.mjs signs it in, and only asked: /api/share?op=mine
// and every page of op=list. Nothing is written to the site. Used by seed211
// (2026-10-24) before the twelve went up, between the two sixes and after.
import { writeFileSync } from "node:fs";
import { mintSession } from "../web/session.mjs";

const out = process.argv[2];
const url = (process.argv.find((a) => a.startsWith("--url=")) || "--url=https://brickworks.diy").slice(6);
if (!out) {
  console.error("house_listing: OUT.json [--url=...]");
  process.exit(2);
}
const { access_token: token } = await mintSession(process.env.GALLERY_EMAIL || "gallery@brickworks.diy");
const mine = await (await fetch(`${url}/api/share?op=mine`, { headers: { authorization: `Bearer ${token}` } })).json();
const gallery = [];
for (let page = 1; page < 20; page++) {
  const got = await (await fetch(`${url}/api/share?op=list&page=${page}&tests=0`)).json();
  gallery.push(...(got.models || []));
  if (!got.more) break;
}
writeFileSync(out, JSON.stringify({ mine, gallery }, null, 1));
for (const row of mine.shared || []) console.log(`mine  ${row.id} | ${row.name} | listed=${row.listed} | ${row.updated_at}`);
for (const row of gallery) console.log(`list  ${row.id} | ${row.name} | ${row.by?.handle || row.author} | ${row.listed_at}`);
