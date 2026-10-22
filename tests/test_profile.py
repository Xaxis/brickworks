"""A person's page (/u/<handle>) and what it shows, held to its promises.

supabase/profile_shows.sql goes into the live project, so it may only add,
and what it keeps goes with the account. What the SQL refuses is proven by
tools/profile_shows_try.sql in a rolled-back dry run; tools/web/profile_flow.mjs
proves the page in a browser. These hold the rest:

- the table cascades from auth.users, has row security on, and nothing is
  granted to the publishable key's roles; a child's row is refused by the
  profile's own trigger;
- a link a person types is kept only as https, and shown only as a link
  marked ugc nofollow, as its domain;
- the page has no special case for anybody, the house account included;
- the flow is wired into the release's preview checks.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/profile_shows.sql").read_text()
PEOPLE = (ROOT / "api/people.js").read_text()
CHECKS = (ROOT / "tools/release/preview_checks.sh").read_text()


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def js_function(text: str, name: str) -> str:
    start = re.search(rf"(export )?(async )?function {name}\(", text)
    assert start, f"no function {name}"
    rest = text[start.start():]
    end = re.search(r"\n}\n", rest)
    return rest[: end.end()] if end else rest


def test_the_file_only_adds_and_goes_with_the_account() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "delete from", "rename ", "alter column", "update public."):
        assert word not in plain, f"profile_shows.sql says {word.strip()}"
    tables = re.findall(r"create table if not exists public\.([a-z_]+)", plain)
    assert tables == ["profile_shows"]
    assert "account     uuid primary key references auth.users (id) on delete cascade" in plain
    assert "alter table public.profile_shows enable row level security;" in plain
    assert "revoke all on public.profile_shows from anon, authenticated;" in plain
    assert "create policy" not in plain and "grant select" not in plain
    # 13 or over, by the profile's own trigger (trust.sql).
    assert "before insert or update on public.profile_shows" in plain
    assert "execute function public.trust_guard_person()" in plain


def test_the_limits_agree() -> None:
    # The table's limits are the API's.
    assert "coalesce(array_length(links, 1), 0) <= 2" in SQL and "export const MOST_LINKS = 2;" in PEOPLE
    assert "coalesce(array_length(pins, 1), 0) <= 3" in SQL and "export const MOST_PINS = 3;" in PEOPLE
    assert "char_length(link) not between 12 and 200" in SQL and "href.length > 200" in PEOPLE


def run_node(script: str) -> object:
    node = shutil.which("node")
    if not node:
        pytest.skip("no node on this machine")
    done = subprocess.run([node, "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, check=True)
    return json.loads(done.stdout)


def test_a_link_is_kept_as_https_and_said_as_its_domain() -> None:
    said = run_node("""
import { cleanLink, linkSaid } from "./api/people.js";
const tried = (text) => { try { return cleanLink(text); } catch (trouble) { return `refused: ${trouble.message}`; } };
console.log(JSON.stringify({
  bare: tried("robin.example/castles"),
  https: tried("https://www.flickr.com/photos/robin#top"),
  http: tried("http://robin.example"),
  script: tried("javascript:alert(1)"),
  password: tried("https://me:pw@robin.example"),
  dotless: tried("https://localhost/x"),
  long: tried(`https://robin.example/${"a".repeat(200)}`),
  said: linkSaid("https://www.flickr.com/photos/robin/"),
}));
""")
    assert said["bare"] == "https://robin.example/castles"
    assert said["https"] == "https://www.flickr.com/photos/robin"
    for refused in ("http", "script", "password", "dotless", "long"):
        assert said[refused].startswith("refused: "), (refused, said[refused])
    assert said["said"] == "flickr.com/photos/robin"


def test_the_page_marks_links_and_has_no_special_case() -> None:
    page = js_function(PEOPLE, "profilePage")
    assert 'rel="ugc nofollow noopener"' in page
    # Every person's page is drawn the same: the house's (U10) included.
    assert '"brickworks"' not in page and "'brickworks'" not in page and "house" not in page.lower()
    # A count of none is never said: each number is hidden at none.
    assert "${zero(n)}" in js_function(PEOPLE, "numbersHtml")
    # The page as the CDN keeps it is the same for everybody: no sign-in read.
    assert "signedIn(" not in page and "bearer(" not in page


def test_the_flow_is_wired() -> None:
    assert re.search(r'^\s*\[profile\]="tools/web/profile_flow\.mjs --url=\$P --out=\$S/\$\{TAG\}_profile"$', CHECKS, flags=re.M)
