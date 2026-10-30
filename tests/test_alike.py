"""More like a designer (docs/SOCIAL.md section 7, item 9), held to what it promises.

A person's page shows up to six designers whose work is closest to theirs
(api/_alike.js): closeness is the themes, tags and parts their models in the
gallery share, then followers in common; never the person, nor whoever asks,
nor anybody they follow; only profiles shown in public. supabase/designers_alike.sql
adds the parts and the followers in common, which only the database may read;
tools/designers_alike_try.sql proves what it answers in a rolled-back dry run.
Here, the order itself, worked out by the pure function both paths share, and
the promises around it.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/designers_alike.sql").read_text()
ALIKE = (ROOT / "api/_alike.js").read_text()
PEOPLE = (ROOT / "api/people.js").read_text()
FOLLOW = (ROOT / "web/follow.js").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def node(script: str):
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def closest(mine: dict, theirs: list, **options) -> list:
    return node(f"""
import {{ closestDesigners }} from "./api/_alike.js";
console.log(JSON.stringify(closestDesigners({json.dumps(mine)}, {json.dumps(theirs)}, {json.dumps(options)})));
""")


MINE = {"kinds": ["castle", "other", "castle"], "tags": ["knights", "dragon", "ai-designed"]}


def one(id_: str, kinds=(), tags=(), parts=0, common=0) -> dict:
    return {"id": id_, "kinds": list(kinds), "tags": list(tags), "parts": parts, "common": common}


def test_themes_tags_and_parts_make_closeness_then_followers_in_common() -> None:
    said = closest(MINE, [
        one("jo", ["castle"], ["knights"]),
        one("kim", ["space"], ["dragon"], parts=0.5),
        one("lee", ["castle", "castle"], ["knights"], common=3),
        one("ola", parts=0.4),
    ])
    # kim: a tag and half the parts (1 + 1.5); lee and jo a theme and a tag
    # each (2), lee with three followers in common first; ola a third of the
    # parts and more (1.2).
    assert [row["id"] for row in said] == ["kim", "lee", "jo", "ola"]
    lee = said[1]
    assert lee["kinds"] == ["castle"] and lee["tags"] == ["knights"] and lee["common"] == 3 and lee["close"] == 2


def test_something_else_and_the_made_with_tags_are_nothing_in_common() -> None:
    # "Something else" is no theme; ai-designed and brickify say how a model
    # was made, not what it is of.
    assert closest(MINE, [one("max", ["other"], ["ai-designed", "brickify"])]) == []


def test_a_few_parts_alone_are_not_close() -> None:
    said = closest(MINE, [one("ned", parts=0.2), one("ola", parts=1 / 3)])
    assert [row["id"] for row in said] == ["ola"]


def test_followers_in_common_alone_are_not_close() -> None:
    assert closest(MINE, [one("pat", common=40)]) == []


def test_six_at_most_and_none_twice() -> None:
    many = [one(f"d{n:02}", ["castle"]) for n in range(10)]
    said = closest(MINE, many + [one("d03", ["castle"], ["dragon"])], most=6)
    ids = [row["id"] for row in said]
    assert len(ids) == 6 and len(set(ids)) == 6
    # The one met twice keeps what it shares either time.
    assert ids[0] == "d03" and said[0]["tags"] == ["dragon"]


def test_ties_hold_their_order() -> None:
    first = closest(MINE, [one("b", ["castle"]), one("a", ["castle"]), one("c", ["castle"])])
    again = closest(MINE, [one("c", ["castle"]), one("b", ["castle"]), one("a", ["castle"])])
    assert [row["id"] for row in first] == [row["id"] for row in again] == ["a", "b", "c"]


def test_what_they_share_is_said_in_words() -> None:
    said = node("""
import { alikeSaid } from "./api/_alike.js";
console.log(JSON.stringify([
  alikeSaid({ kinds: ["castle", "space"], tags: ["knights", "dragon", "moat", "keep"], parts: 0 }),
  alikeSaid({ kinds: [], tags: ["knights"], parts: 0.5 }),
  alikeSaid({ kinds: [], tags: [], parts: 0.5 }),
  alikeSaid({ kinds: ["castle", "space"], tags: ["castle", "space", "knights"], parts: 0 }),
]));
""")
    assert said == ["Castles and fantasy, Space · knights, dragon, moat",
                    "Knights · many of the same parts", "Many of the same parts",
                    # Not a tag the theme's name says already.
                    "Castles and fantasy, Space · knights"]


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "delete ", "update ", "insert ", "rename ", "alter ", "create table"):
        assert word not in plain, f"designers_alike.sql says {word.strip()}"
    assert re.findall(r"create or replace function public\.([a-z_]+)\(", plain) == ["designers_alike"]


def test_it_replaces_no_function_another_file_defines() -> None:
    for path in (ROOT / "supabase").glob("*.sql"):
        if path.name != "designers_alike.sql":
            assert "function public.designers_alike(" not in path.read_text(), path.name


def test_only_the_server_runs_it() -> None:
    plain = code(SQL)
    assert "security definer" in plain and "set search_path = public" in plain
    assert "revoke all on function public.designers_alike(uuid, boolean) from public, anon, authenticated;" in plain
    assert "grant execute on function public.designers_alike(uuid, boolean) to service_role;" in plain


def test_it_counts_only_what_the_gallery_shows_and_never_names_a_follower() -> None:
    body = code(SQL)
    for rule in ("m.published and m.listed and not m.barred and m.author is not null", "(tests or not m.test)",
                 "public.barred_accounts", "public.shown_publicly(f.follower)"):
        assert rule in body, rule
    returned = re.search(r"returns table \(([^)]*)\)", body).group(1)
    assert returned == "account uuid, parts numeric, common integer"


def test_never_the_person_the_asker_or_whom_they_follow() -> None:
    gather = ALIKE[ALIKE.index("export async function designersAlike("):]
    # The asker's own follow state for each: mine, and you_follow, both left out,
    # and only a profile that may be followed (follow_state answers none else).
    for rule in ("followsOf(", "state.mine", "state.you_follow", "person.account"):
        assert rule in gather, rule


def test_signed_in_answers_are_never_kept() -> None:
    handler = PEOPLE[PEOPLE.index("async function alike("):]
    handler = handler[:handler.index("\n}\n")]
    assert '"private, no-store"' in handler and "SHARED_CACHE" in handler or "s-maxage" in handler


def test_the_page_draws_it_with_follow_in_place() -> None:
    assert "data-alike" in PEOPLE
    assert "op=alike" in FOLLOW and "followButton(" in FOLLOW


def test_its_flow_is_a_preview_check() -> None:
    assert "alike_flow.mjs" in CHECKS
