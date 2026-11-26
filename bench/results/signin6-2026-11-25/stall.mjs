// signin6: how often a session read from this box stalls, through api/_db.js as the server asks it
// (Node's fetch, its kept-alive sockets), N reads one after another, then N at 8 at once. A made-up
// session id: nothing is read but "not there". Prints counts and times only.
//
//   set -a; . ./.env; set +a
//   node bench/results/signin6-2026-11-25/stall.mjs [N]
const { db } = await import(new URL("../../../api/_db.js", import.meta.url).href);
const N = Number(process.argv[2] || 150);
const session = "00000000-0000-4000-8000-000000000000";
async function one() {
  const at = Date.now();
  try {
    await db("rpc/oc_session_of", { method: "POST", body: { session }, seconds: 20 });
    return Date.now() - at;
  } catch {
    return -(Date.now() - at);
  }
}
function say(what, times) {
  const ok = times.filter((t) => t >= 0).sort((a, b) => a - b);
  const at = (q) => ok[Math.min(ok.length - 1, Math.floor(ok.length * q))];
  console.log(`${what}: ${times.length} reads, ${times.length - ok.length} failed, median ${at(0.5)} ms, p99 ${at(0.99)} ms,`
    + ` max ${ok[ok.length - 1]} ms, over 3 s ${ok.filter((t) => t > 3000).length}, over 15 s ${ok.filter((t) => t > 15000).length}`);
}
const serial = [];
for (let n = 0; n < N; n += 1) serial.push(await one());
say("one after another", serial);
const parallel = [];
for (let n = 0; n < N; n += 8) parallel.push(...(await Promise.all(Array.from({ length: 8 }, one))));
say("8 at once", parallel);
