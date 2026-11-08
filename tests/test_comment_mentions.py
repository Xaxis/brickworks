"""@mentions in comments (docs/SOCIAL.md section 7, item 6), held to what they promise.

supabase/comment_mentions.sql goes into the live project, so it may only add: one table
only its functions reach, deleted with its comment or its account, and functions the
service role alone runs; challenge_notices.sql's notification_rows replaced with every
row it gave and the mentions', guarded so applying any earlier file of it again alone
is refused. tools/comment_mentions_try.sql proves who is told in a rolled-back dry run;
here, that the rules it proves are the ones written, that a comment's words are read
the same by the server and the page, and that a name is never put on the page as markup.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/comment_mentions.sql").read_text()
BEFORE = (ROOT / "supabase/challenge_notices.sql").read_text()
LATER = [line.split("\t") for line in (ROOT / "supabase/later.tsv").read_text().splitlines()
         if line.strip() and not line.startswith("#")]


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def body(name: str, text: str) -> str:
    start = text.index(f"create or replace function public.{name}(")
    return text[start:text.index("\n$$;", start)]


def node(script: str) -> dict:
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "delete from", "update public."):
        assert word not in plain, f"comment_mentions.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["comment_mentions"]
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [("comment_mentions", "enable row level security")]
    assert "comment  bigint not null references public.model_comments (id) on delete cascade" in plain
    assert "account  uuid not null references auth.users (id) on delete cascade" in plain
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"comment_mentions"}


def test_the_table_and_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    assert "revoke all on public.comment_mentions from public, anon, authenticated, service_role;" in plain
    assert not re.search(r"grant [^;]* on public\.comment_mentions\b", plain)
    names = sorted(set(re.findall(r"create or replace function public\.([a-z_]+)\(", plain)))
    assert names == ["comment_mention", "comment_mentions_of", "comment_mentions_said", "notification_rows"]
    for name in names:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name


def test_it_keeps_every_row_given_before_and_is_guarded() -> None:
    before, after = body("notification_rows", BEFORE), body("notification_rows", SQL)
    # challenge_notices.sql's whole, then the mentions: nothing of it changed.
    assert after.startswith(before)
    assert "'mention'::text" in after[len(before):]
    for earlier in ("notifications.sql", "replies.sql", "achievements.sql", "challenge_notices.sql"):
        guard = [row for row in LATER if row[:3] == [earlier, "notification_rows", "comment_mentions.sql"]]
        assert guard, earlier
        assert guard[0][3] in after and guard[0][3] not in body("notification_rows", (ROOT / f"supabase/{earlier}").read_text())
    told = BEFORE[:BEFORE.index("create or replace function public.notification_rows(")]
    assert "REPLACED LATER: comment_mentions.sql" in "\n".join(told.rstrip().splitlines()[-4:])


def test_who_may_be_named_and_who_is_told() -> None:
    named = body("comment_mention", SQL)
    # Its writer's own comment, 13 or over; three a comment however often it
    # is edited; each a profile shown in public, 13 or over, not the writer.
    for rule in ("c.author <> comment_mention.account", "'refused', 'not_yours'", "'refused', 'no_comment'",
                 "public.trust_may_go_public(comment_mention.account)", "room := 3 - (select count(*)",
                 "limit room", "p.account <> comment_mention.account", "public.shown_publicly(p.account)",
                 "public.trust_may_go_public(p.account)", "not public.is_barred(comment_mention.account)",
                 "p.handle = lower(h.handle)", "k.removed_at is null"):
        assert rule in named, rule
    told = body("notification_rows", SQL)[len(body("notification_rows", BEFORE)):]
    # As a reply is hidden; never twice: not for its model's designer (a
    # comment), nor in the viewer's own conversation (a reply).
    for rule in ("n.account = viewer", "k.author <> viewer", "m.owner <> viewer", "m.published and not m.barred",
                 "k.removed_at is null and k.hidden_at is null", "public.shown_publicly(k.author)",
                 "public.comment_parent_shown(k.parent)",
                 "not exists (select 1 from threads t where t.root = k.parent and k.at > t.joined)",
                 "k.at > since and k.at <= until"):
        assert rule in told, rule


def test_the_words_are_read_the_same_everywhere() -> None:
    out = node("""
      import { mentionsIn, mentionPieces } from "./web/card.js";
      console.log(JSON.stringify({
        found: mentionsIn("Hi @Ada-B, @bob and ada@example.org, @ada-b again (@pip). @x @a--b @c_d @123 x@y.z"),
        long: mentionsIn(`@${"a".repeat(25)} @${"b".repeat(24)}`),
        pieces: mentionPieces("Hi @Ada-B, see @bob; @nobody <b>too</b>", [{ handle: "ada-b", name: "Ada" }, { handle: "bob", name: "Bob" }]),
        none: mentionPieces("@bob", []),
      }));
    """)
    assert out["found"] == ["ada-b", "bob", "pip", "123"]
    assert out["long"] == ["b" * 24]
    # As typed, each a piece of its own; a handle nobody was told of, and every other word, text.
    assert out["pieces"] == ["Hi ", {"handle": "ada-b", "name": "Ada", "at": "@Ada-B"}, ", see ",
                             {"handle": "bob", "name": "Bob", "at": "@bob"}, "; @nobody <b>too</b>"]
    assert out["none"] == ["@bob"]


def test_a_mention_is_said_and_grouped_under_its_model() -> None:
    out = node("""
      import { noticeSaid, noticeGroups } from "./api/_notifications.js";
      const row = { kind: "mention", at: "2026-10-30T09:00:00Z", on: "PiaTower01", model: "PiaTower01", name: "Tower",
        comment: 41, parent: null, step: 3, said: "Ask @max about the roof", by: { handle: "lia", name: "Lia" } };
      console.log(JSON.stringify({
        said: noticeSaid(row, "https://x"),
        reply: noticeSaid({ ...row, parent: 40, step: null }, "https://x").line,
        groups: noticeGroups({ rows: [row], models: { PiaTower01: { name: "Tower" } }, seen_at: null, read_at: null, reads: {} },
          "https://x").groups.map((one) => [one.model, one.rows.length]),
      }));
    """)
    said = out["said"]
    assert said["who"] == "Lia" and said["line"] == "{who} mentioned you in a comment on step 3"
    assert said["said"] == "Ask @max about the roof" and said["link"] == "https://x/m/PiaTower01#comment-41"
    assert out["reply"] == "{who} mentioned you in a reply"
    assert out["groups"] == [["PiaTower01", 1]]


def test_the_api_and_the_page_go_together() -> None:
    api = (ROOT / "api/_comments.js").read_text()
    assert 'call("comment_mention", { account: who, comment_id: id, handles: handles.slice(0, 12) }' in api
    assert api.count("await mention(who, comment.id, text)") == 3
    assert 'call("comment_mentions_of", { comment_ids: asked }' in api
    assert "await withMentions((on.comments || []).map(" in api
    page = (ROOT / "web/model-page.js").read_text()
    drawn = page[page.index('words.className = "comment-body";'):page.index("main.append(head, words);")]
    # Words as text nodes and a link's text: never markup.
    assert "mentionPieces(one.body, one.mentions)" in drawn and "innerHTML" not in drawn
    assert "link.textContent = piece.at;" in drawn and "words.append(piece);" in drawn
    picker = page[page.index("function pickMentions("):]
    # A box of several lines stays one (a combobox is a single line): it
    # controls the listbox, marks its option, and a status says it is there.
    for rule in ('list.setAttribute("role", "listbox")', 'item.setAttribute("role", "option")',
                 'field.setAttribute("aria-autocomplete", "list")', 'field.setAttribute("aria-controls", list.id)',
                 'field.setAttribute("aria-activedescendant"', 'said.setAttribute("role", "status")',
                 "event.stopPropagation()"):
        assert rule in picker, rule
    assert '"combobox"' not in picker and '"aria-expanded"' not in picker
    assert page.count("pickMentions(") == 3
    checks = (ROOT / "tools/release/preview_checks.sh").read_text()
    assert '[mentions]="tools/web/mentions_flow.mjs --url=$P --out=$S/${TAG}_mentions"' in checks


# A people table as PostgREST reads it for peopleFound: handle=like.X*, the
# names' or=(...), order=handle and limit, with each account's trust as
# supabase/trust.sql says it.
PEOPLE_DB = r"""
process.env.SUPABASE_URL = "https://db.test";
process.env.SUPABASE_SECRET_KEY = "secret";
process.env.SUPABASE_PUBLISHABLE_KEY = "publishable";
const asked = [];
const acts = [];
let people = [];
const person = (account) => people.find((one) => one.account === account) || {};
const like = (text, pattern) => new RegExp(`^${pattern.split("*").map((part) => part.replace(/[.?+^$()[\]{}|\\-]/g, "\\$&")).join(".*")}$`, "i").test(text);
const reply = (value) => new Response(JSON.stringify(value), { status: 200 });
let token = "";
const { webcrypto } = await import("node:crypto");
const pair = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
const jwk = { ...(await webcrypto.subtle.exportKey("jwk", pair.publicKey)), kid: "mentions", alg: "ES256" };
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(String(input));
  if (url.pathname === "/auth/v1/.well-known/jwks.json") return reply({ keys: [jwk] });
  const body = init.body ? JSON.parse(init.body) : {};
  if (url.pathname === "/rest/v1/rpc/may_act") { acts.push(body); return reply(true); }
  if (url.pathname === "/rest/v1/rpc/shown_publicly") return reply(!person(body.account).barred && person(body.account).over_13 !== false);
  if (url.pathname === "/rest/v1/rpc/trust_may_go_public") return reply(person(body.account).over_13 === true);
  if (url.pathname === "/rest/v1/rpc/trust_is_test_account") return reply(/@resend\.dev$/i.test(person(body.account).email || ""));
  if (url.pathname !== "/rest/v1/people") return new Response("{}", { status: 404 });
  asked.push(decodeURIComponent(url.search));
  let rows = people;
  const handle = url.searchParams.get("handle");
  if (handle) rows = rows.filter((one) => like(one.handle, handle.replace(/^like\./, "")));
  const or = url.searchParams.get("or");
  if (or) {
    const names = or.slice(1, -1).split(/,(?=name)/).map((one) => one.replace(/^name\.ilike\./, "").replace(/^"|"$/g, ""));
    rows = rows.filter((one) => names.some((pattern) => like(one.name, pattern)));
  }
  rows = [...rows].sort((a, b) => (a.handle < b.handle ? -1 : 1)).slice(0, Number(url.searchParams.get("limit") || 1000));
  return reply(rows.map(({ account, handle: h, name }) => ({ account, handle: h, name })));
};
const b64 = (v) => Buffer.from(JSON.stringify(v)).toString("base64url");
const head = b64({ alg: "ES256", kid: "mentions", typ: "JWT" });
const claims = b64({ sub: "11111111-1111-4111-8111-111111111111", aud: "authenticated", iss: "https://db.test/auth/v1",
  exp: Math.floor(Date.now() / 1000) + 3600, amr: [{ method: "otp" }] });
const signature = await webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, pair.privateKey, new TextEncoder().encode(`${head}.${claims}`));
token = `${head}.${claims}.${Buffer.from(signature).toString("base64url")}`;
const handler = (await import("./api/people.js")).default;
const find = async (query, { signed = true } = {}) => {
  const headers = {};
  const response = { statusCode: 200, body: null, setHeader(name, value) { headers[name.toLowerCase()] = value; return this; },
    status(code) { this.statusCode = code; return this; }, json(value) { this.body = value; return this; }, end() { return this; } };
  await handler({ method: "GET", query: { op: "people_find", ...query },
    headers: { host: "x.test", ...(signed ? { authorization: `Bearer ${token}` } : {}) } }, response);
  return { status: response.statusCode, body: response.body, cache: headers["cache-control"] };
};
"""


def test_anybody_who_may_be_named_is_offered() -> None:
    # @ offers the people on the page first, then anybody whose profile may
    # be named (socialtails): a handle typed whole, then one it starts, then
    # a name it starts, then a word of a name; only a profile shown in public
    # and said 13 or over (comment_mentions.sql names nobody else), and a
    # test account only to a probe (streview: @resend.dev was offered to all).
    got = node(PEOPLE_DB + """
people = [
  { account: "a1", handle: "mika-mocs", name: "Mika Tanaka", over_13: true },
  { account: "a2", handle: "mi", name: "Mi", over_13: true },
  { account: "a3", handle: "jo-bricks", name: "Mia Lindqvist", over_13: true },
  { account: "a4", handle: "sam-builds", name: "Sam Mikkelsen", over_13: true },
  { account: "a5", handle: "milo-young", name: "Milo", over_13: false },
  { account: "a6", handle: "robin", name: "Robin Castell", over_13: true },
  { account: "a7", handle: "mint-new", name: "Mint", over_13: null },
  { account: "a8", handle: "mila-taken", name: "Mila", over_13: true, barred: true },
  { account: "a9", handle: "mio-probe", name: "Mio Probe", over_13: true, email: "probe+mio@resend.dev" },
];
const { peopleFound, peopleRanked } = await import("./api/people.js");
const ranked = peopleRanked(people, "mi").map((one) => one.handle);
const out = { ranked };
out.found = (await find({ q: "Mi" })).body.people;
out.asked = asked.splice(0);
out.probe = (await find({ q: "mi", tests: "1" })).body.people.map((one) => one.handle);
asked.splice(0);
out.refused = await peopleFound("mi,handle.eq.x", async () => true);
out.refusedAsked = asked.splice(0);
console.log(JSON.stringify(out));
""")
    assert got["ranked"] == ["mi", "mint-new", "mika-mocs", "mio-probe", "mila-taken", "milo-young", "jo-bricks", "sam-builds"]
    # Milo said under 13, Mint was never asked, Mila was taken out, Mio is a
    # probe's: none offered. Robin's name has no word starting "mi".
    assert [one["handle"] for one in got["found"]] == ["mi", "mika-mocs", "jo-bricks", "sam-builds"]
    assert got["found"][1] == {"handle": "mika-mocs", "name": "Mika Tanaka"}
    assert got["probe"] == ["mi", "mika-mocs", "mio-probe", "jo-bricks", "sam-builds"]
    # The handles it starts first, 8 at most, then the names.
    assert got["asked"][0] == "?handle=like.mi*&select=account,handle,name&order=handle&limit=8"
    assert got["asked"][1] == '?or=(name.ilike.mi*,name.ilike."* mi*")&select=account,handle,name&order=handle&limit=40'
    # What may follow an @ only: anything else asks nothing.
    assert got["refused"] == [] and got["refusedAsked"] == []


def test_a_handle_typed_whole_is_found_however_many_names_come_first() -> None:
    # peopleFound read 40 rows by handle before ranking, so with 40 names
    # starting "mi" whose handles sort before it, the handle "mi" typed
    # whole was never offered (streview).
    got = node(PEOPLE_DB + """
people = Array.from({ length: 45 }, (_, n) => ({ account: `n${n}`, handle: `a-${String(n).padStart(2, "0")}`, name: `Mi ${n}`, over_13: true }));
people.push({ account: "me", handle: "mi", name: "Zed", over_13: true });
console.log(JSON.stringify((await find({ q: "mi" })).body.people));
""")
    assert got[0] == {"handle": "mi", "name": "Zed"} and len(got) == 6


def test_finding_people_needs_the_session_and_is_counted() -> None:
    # Anybody could list every profile: no session, one letter, and a cache
    # miss per letter (streview). Now: signed in, from two letters, each
    # look counted, each answer the asker's own; q cut to a handle's 23.
    got = node(PEOPLE_DB + """
people = [{ account: "a1", handle: "mika-mocs", name: "Mika Tanaka", over_13: true }];
const out = {};
out.out = await find({ q: "mi" }, { signed: false });
out.one = await find({ q: "m" });
out.oneAsked = [asked.splice(0), acts.splice(0)];
out.two = await find({ q: "mi" });
out.acts = acts.splice(0);
out.long = (await find({ q: "mika-mocs-and-a-great-deal-more" })).body.q;
console.log(JSON.stringify(out));
""")
    assert got["out"]["status"] == 401 and not got["out"]["body"].get("people")
    assert got["one"]["status"] == 200 and got["one"]["body"]["people"] == [] and got["oneAsked"] == [[], []]
    assert got["two"]["status"] == 200 and got["two"]["body"]["people"] == [{"handle": "mika-mocs", "name": "Mika Tanaka"}]
    assert got["two"]["cache"] == "private, no-store"
    assert got["acts"] == [{"actor": "11111111-1111-4111-8111-111111111111", "act": "people_find", "per_hour": 600, "per_day": 3000}]
    assert got["long"] == "mika-mocs-and-a-great-d"
    people_js = (ROOT / "api/people.js").read_text()
    # The docstring says what it checks: not "13 or over" alone.
    assert "(shown in public: 13 or\n/// over" not in people_js
    page = (ROOT / "web/model-page.js").read_text()
    picker = page[page.index("function pickMentions("):]
    assert "asked.length < 2" in picker and 'call(`/api/people?op=people_find&q=' in picker and '"&tests=1"' in picker


def test_the_stand_in_finds_people_as_the_server_does() -> None:
    stand = (ROOT / "tools/web/design_stand_in.mjs").read_text()
    found = stand[stand.index('if (op === "people_find") {'):]
    found = found[:found.index("\n    }\n") + 6]
    for rule in ('.slice(0, 23)', "namedOf(q)", "slice(0, 8)", "RPC.shown_publicly({ account })",
                 "RPC.trust_may_go_public({ account })", "tests || !RPC.trust_is_test_account({ account })"):
        assert rule in found, rule
    opened = stand[stand.index("const open = method === \"GET\""):stand.index('    : ["report", "digest"];')]
    assert '"people_find"' not in opened
