// signreview3: any account left at a throwaway address of this review (bw-sr3-), counted
// only, and deleted when DELETE=1 (they are this review's own throwaways). Reads otherwise.
//   set -a; . ./.env; set +a; node bench/results/signreview3-2026-11-25/left.mjs
import { deleteAccount } from "../../../tools/web/session.mjs";

const SB = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const key = process.env.SUPABASE_SECRET_KEY;
// PREFIX=bw-ways-flow- counts the flow's own throwaways instead, with when each was made
// (ways_flow deletes its own in a finally; this shows none of the review's runs left one).
const prefix = process.env.PREFIX || "bw-sr3-";
const left = [];
for (let page = 1; page <= 60; page += 1) {
  const reply = await fetch(`${SB}/auth/v1/admin/users?${new URLSearchParams({ filter: prefix, page: String(page), per_page: "100" })}`,
    { headers: { apikey: key, authorization: `Bearer ${key}` } });
  const users = (await reply.json()).users || [];
  left.push(...users.filter((one) => String(one.email || "").includes(prefix)).map((one) => ({ email: one.email, made: one.created_at })));
  if (users.length < 100) break;
}
console.log(`left (${prefix}): ${left.length}${left.length ? `, made ${left.map((one) => String(one.made).slice(0, 16)).join(" ")}` : ""}`);
if (process.env.DELETE === "1" && prefix !== "bw-sr3-") throw new Error("DELETE only for this review's own bw-sr3- throwaways");
if (process.env.DELETE === "1") {
  for (const { email } of left) console.log(`deleted ${email.replace(/^(.{14}).*(@.*)$/, "$1...$2")}: ${await deleteAccount(email).catch(() => false)}`);
}
