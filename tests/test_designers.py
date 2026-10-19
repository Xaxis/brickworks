"""A designer's page and their own numbers, held to what they promise.

supabase/designers.sql goes into the live project, so it may only add: a
table, an index, a trigger, new functions, and nothing another file defines
replaced (a redefinition that left out a column would quietly drop it from
every page). What the SQL answers is proven by tools/designers_try.sql in a
rolled-back dry run; these read the files and hold the promises around it:

- the designer's own numbers are asked only with the account its sign-in
  proves, and no answer of them is ever kept by a cache, a refusal included;
- the profile's page, which the CDN keeps, never carries them;
- the page's numbers are the cards' own: builds as model_stats counts them,
  remixes as the card counts them, and a card leads with builds and remixes
  and never says its views;
- the local stand-in answers the functions the API asks, and the browser
  flow asks a deployment only through its API.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/designers.sql").read_text()
DESIGNERS = (ROOT / "api/_designers.js").read_text()
PEOPLE = (ROOT / "api/people.js").read_text()
STAND_IN = (ROOT / "tools/web/designers_stand_in.mjs").read_text()
FLOW = (ROOT / "tools/web/designers_flow.mjs").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()
PAGE_SCRIPT = (ROOT / "web/designs.js").read_text()


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def defined(text: str) -> list[str]:
    return re.findall(r"create or replace function public\.([a-z_]+)\(", text)


def body(text: str, name: str) -> str:
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name}"
    return found[-1]


def js_function(text: str, name: str) -> str:
    start = re.search(rf"(export )?(async )?function {name}\(", text)
    assert start, f"no function {name}"
    rest = text[start.start():]
    end = re.search(r"\n}\n", rest)
    return rest[: end.end()] if end else rest


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "delete from", "rename ", "alter column"):
        assert word not in plain, f"designers.sql says {word.strip()}"
    # The one update is the trigger's own count, on its own new table.
    updates = re.findall(r"\bupdate\b[^;]*", plain)
    assert updates == ["update set opens = public.model_opens.opens + 1"], updates
    assert "on conflict (model, day) do update set opens = public.model_opens.opens + 1" in plain
    for table in re.findall(r"create table if not exists public\.([a-z_]+)", plain):
        assert table == "model_opens", f"a new table {table}"
    # Only the new table is altered, and only to turn its row security on.
    for altered in re.findall(r"alter table public\.([a-z_]+)", plain):
        assert altered == "model_opens", f"alters {altered}"


def test_it_replaces_no_function_another_file_defines() -> None:
    others = {
        name
        for path in (ROOT / "supabase").glob("*.sql")
        if path.name != "designers.sql"
        for name in defined(path.read_text())
    }
    mine = defined(SQL)
    assert set(mine) == {"model_opens_count", "designer_said", "designer_page", "designer_mine"}
    assert not set(mine) & others, f"replaces {set(mine) & others}"


def test_only_the_server_reads_anything() -> None:
    plain = code(SQL)
    assert "revoke all on public.model_opens from public, anon, authenticated, service_role;" in plain
    assert "alter table public.model_opens enable row level security;" in plain
    for name in ("designer_said", "designer_page", "designer_mine"):
        assert "security definer" in body(SQL, name) or re.search(
            rf"function public\.{name}\(.*?security definer", SQL, flags=re.S
        )
        signature = re.search(rf"revoke all on function public\.{name}\(([^)]*)\) from public, anon, authenticated;", plain)
        assert signature, f"{name} is not revoked from every key a page has"
        assert f"grant execute on function public.{name}({signature[1]}) to service_role;" in plain
        assert not re.search(rf"grant execute on function public\.{name}\([^)]*\) to (anon|authenticated)", plain)


def test_the_page_counts_as_its_cards_do() -> None:
    page = body(SQL, "designer_page")
    # Builds as model_stats counts them, once per device: the card's and Top builds'.
    assert "coalesce(s.builds, 0) as builds" in page
    # Remixes as directory_card counts them: published, by link or listed.
    card = body((ROOT / "supabase/builds.sql").read_text(), "directory_card")
    assert "r.remixed_from = m.id and r.published" in card
    assert "r.remixed_from in (select t.id from theirs t) and r.published" in page
    # The models the profile lists: directory_models' owner filter.
    assert "m.published and m.listed and not m.barred and m.author is not null" in page
    # Comments counted once, by one rule, not the owner's own.
    said = body(SQL, "designer_said")
    assert "c.author <> m.owner" in said and "c.hidden_at is null" in said and "c.removed_at is null" in said
    assert "public.designer_said(" in page and "public.designer_said(" in body(SQL, "designer_mine")


def test_a_designer_card_leads_with_builds_and_never_says_views() -> None:
    card = js_function(PEOPLE, "cardHtml")
    earned = card[card.index("if (earned) {"): card.index("} else {")]
    order = [earned.index(f"card.{kind})") for kind in ("builds", "remixes", "comments", "likes")]
    assert order == sorted(order), "builds, remixes, comments, likes"
    assert "views" not in earned


def test_the_band_leads_with_builds_and_remixes() -> None:
    band = js_function(PEOPLE, "earnedHtml")
    kinds = re.findall(r'tile\("([a-z]+)"', band)
    assert kinds == ["builds", "remixes", "tested", "comments", "models", "followers"]
    assert re.search(r'tile\("builds",[^\n]*true\)', band) and re.search(r'tile\("remixes",[^\n]*true\)', band)


def test_the_own_numbers_are_never_kept_and_only_the_caller_s() -> None:
    designs = js_function(DESIGNERS, "designs")
    assert 'export const MINE_CACHE = "private, no-store";' in DESIGNERS
    # Said before the sign-in is checked, so a refusal is not kept either.
    assert designs.index('response.setHeader("Cache-Control", MINE_CACHE)') < designs.index("verify(")
    assert "const account = (await verify(bearer(request))).sub;" in designs
    assert 'db("rpc/designer_mine", { method: "POST", body: { designer: account, days: DAYS } })' in designs
    # Asked from another's page: nothing but that it is not theirs.
    assert "return response.status(200).json({ mine: false });" in designs
    # Nothing else takes an account from the request.
    assert "query?.account" not in DESIGNERS and "body?.account" not in DESIGNERS


def test_the_profile_page_never_carries_them() -> None:
    page = js_function(PEOPLE, "profilePage")
    assert "designer_mine" not in PEOPLE and "designs(" not in page
    assert 'id="designs-mine"' in page and re.search(r'id="designs-mine"[^>]*hidden', page)
    assert "mine: true" in page  # the page loads web/designs.js
    assert 'if (op === "designs") return await designs(request, response' in PEOPLE
    # The page asks for them with the sign-in, by its own handle.
    assert "op=designs" in PAGE_SCRIPT and "handle: page.dataset.handle" in PAGE_SCRIPT


def test_the_stand_in_answers_what_the_api_asks() -> None:
    asked = set(re.findall(r'db\("rpc/(designer_[a-z]+)"', DESIGNERS))
    listed = re.search(r"const NAMES = \[([^\]]*)\]", STAND_IN)
    assert listed, "the stand-in names no functions"
    names = set(re.findall(r'"(designer_[a-z]+)"', listed[1]))
    assert asked == names == {"designer_page", "designer_mine"}
    for name in names:
        assert f"async {name}(" in STAND_IN


def test_the_flow_asks_a_deployment_only_through_its_api() -> None:
    assert "/__held" not in FLOW
    assert re.search(r'^\s*\[designers\]="tools/web/designers_flow\.mjs --url=\$P --out=\$S/\$\{TAG\}_designers"$', CHECKS, flags=re.M)
    assert "x-vercel-protection-bypass" in FLOW
    for path in re.findall(r"fetch\(`\$\{site\}(/[^`]*)`", FLOW):
        assert path.startswith(("/api/", "/u/")), path
