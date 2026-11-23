// Does a model published as made with the assistant say so nowhere public
// until its owner chooses? Against the real functions and database, on a
// local relay (the owner, 2026-11-23; supabase/made_with_shown.sql).
//
//   set -a; . ./.env; set +a
//   node tools/web/relay_server.mjs 11831 &
//   node tools/web/made_shown_relay.mjs --url=http://127.0.0.1:11831
//
// A throwaway account of this run's own (session.mjs runAddress), deleted
// at the end with its model:
//
//   1. publishes a small model as the app does for one Claude laid
//      (made_with assistant, tagged ai-designed, made_with_shown left out);
//   2. a stranger reads its page and its JSON: no With the assistant among
//      the facts, no ai-designed tag;
//   3. its owner reads ?op=made: made_with assistant, not shown; and says
//      to show it (POST ?op=made {shown: true});
//   4. the stranger reads again: the fact and the tag;
//   5. its owner takes it back, and the stranger reads nothing again.
//
// Before supabase/made_with_shown.sql is applied, step 3 answers ready
// false and the POST 503, which is said, and steps 4-5 are not run: every
// model reads as not shown. Exits 1 on any failure.
import { deleteAccount, mintSession, runAddress } from "./session.mjs";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
const base = String(args.url || "http://127.0.0.1:11831").replace(/\/+$/, "");
const SMALL = "0 Made Shown Relay\r\n0 Name: made.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n";
let failed = 0;
const check = (ok, what) => {
  console.log(`${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed++;
};
const call = async (path, { method = "GET", token = "", body } = {}) => {
  const answer = await fetch(`${base}${path}`, { method, headers: {
    ...(token ? { authorization: `Bearer ${token}` } : {}), ...(body ? { "content-type": "application/json" } : {}),
    accept: path.startsWith("/m/") ? "text/html" : "application/json" }, body: body ? JSON.stringify(body) : undefined });
  const text = await answer.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {}
  return { status: answer.status, text, json };
};
const seen = async (id) => {
  const page = await call(`/m/${id}?tests=1`);
  const facts = /<ul class="facts pills">[^]*?<\/ul>/.exec(page.text)?.[0] || "";
  const json = await call(`/api/share?id=${id}`);
  return { status: page.status, fact: /<li class="pill made"[^>]*>With the assistant<\/li>/.test(facts),
    tagged: (json.json?.tags || []).includes("ai-designed"), json: json.status };
};

const email = runAddress();
let id = "";
try {
  const owner = await mintSession(email);
  const token = owner.access_token;
  let r = await call("/api/share", { method: "POST", token, body: { name: "Made Shown Relay", model: SMALL,
    tags: "ai-designed, tower", made_with: "assistant", listed: false } });
  id = r.json?.id || "";
  check(r.status === 201 && id, `1. published as the app does for a model Claude laid: ${r.status} ${id} (made_with ${r.json?.made_with})`);
  let look = await seen(id);
  check(look.status === 200 && !look.fact && !look.tagged,
    `2. a stranger: its page ${look.status}, the fact ${look.fact ? "SAID" : "not said"}, the ai-designed tag ${look.tagged ? "SAID" : "not said"}`);
  r = await call(`/api/share?op=made&id=${id}`, { token });
  check(r.status === 200 && r.json.made_with === "assistant" && r.json.made_with_shown === false,
    `3. its owner reads ?op=made: ${r.status} made_with ${r.json?.made_with}, shown ${r.json?.made_with_shown}, ready ${r.json?.ready}`);
  const stranger = await call(`/api/share?op=made&id=${id}`);
  check(stranger.status === 401 || stranger.status === 403, `...a stranger asking the same is refused (${stranger.status})`);
  if (r.json?.ready !== true) {
    console.log("--    supabase/made_with_shown.sql is not applied: nothing can be shown, and nothing is; 4-5 not run");
  } else {
    r = await call(`/api/share?op=made&id=${id}`, { method: "POST", token, body: { shown: true } });
    check(r.status === 200 && r.json.made_with_shown === true, `3. its owner says to show it: ${r.status}, shown ${r.json?.made_with_shown}`);
    look = await seen(id);
    check(look.fact && look.tagged, `4. the stranger again: the fact ${look.fact ? "said" : "NOT said"}, the tag ${look.tagged ? "said" : "NOT said"}`);
    r = await call(`/api/share?op=made&id=${id}`, { method: "POST", token, body: { shown: false } });
    look = await seen(id);
    check(r.status === 200 && !look.fact && !look.tagged, `5. taken back: ${r.status}, the fact ${look.fact ? "SAID" : "not said"}, the tag ${look.tagged ? "SAID" : "not said"}`);
  }
} finally {
  await deleteAccount(email).catch((trouble) => console.log(`--    the run's account was not deleted: ${trouble}`));
}
console.log(failed ? `made shown relay: ${failed} problem(s)` : "made shown relay: nothing public said it until its owner chose to");
process.exit(failed ? 1 : 0);
