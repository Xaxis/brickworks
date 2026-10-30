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
        reply: noticeSaid({ ...row, parent: 40, step: null }, "https://x").did,
        groups: noticeGroups({ rows: [row], models: { PiaTower01: { name: "Tower" } }, seen_at: null, read_at: null, reads: {} },
          "https://x").groups.map((one) => [one.model, one.rows.length]),
      }));
    """)
    said = out["said"]
    assert said["who"] == "Lia" and said["did"] == "mentioned you in a comment on step 3"
    assert said["said"] == "Ask @max about the roof" and said["link"] == "https://x/m/PiaTower01#comment-41"
    assert out["reply"] == "mentioned you in a reply"
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
