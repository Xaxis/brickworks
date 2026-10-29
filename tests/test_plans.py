"""Plans, coming soon: the page, its form and the table, held to their promises.

supabase/plan_interest.sql goes into the live project, so it may only add,
and nobody but the server may read what it keeps. What the SQL answers is
proven by tools/plan_interest_try.sql in a rolled-back dry run; the browser
flow (tools/web/plans_flow.mjs) proves the page on a deployment. These read
the files and run api/plans.js's handler with the database played here:

- the file adds two tables and five functions and changes nothing else;
  row security on both, every grant revoked, each function the server's;
- the API refuses what it should in words, asks the rate limit before it
  keeps anything, keeps the address in lower case and never the address it
  came from, keeps Pro as 'plus' (the table allows Plus and Creator, which
  both mean Pro now), and answers a first entry and a second in the same
  words;
- nothing on the page takes money, Free lists no limit smaller than
  today's (api/models.js keeps 500 models an account), and the page keeps
  the promise to accounts that exist and says what stays free (gate M1,
  docs/PLANS.md).
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/plan_interest.sql").read_text()
PAGE = (ROOT / "web/plans.html").read_text()
MODELS = (ROOT / "api/models.js").read_text()


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "alter table public.profiles", "update public."):
        assert word not in plain, f"plan_interest.sql says {word.strip()}"
    # The one delete is of its own rows: old tries, and an address asked for.
    assert set(re.findall(r"delete from public\.([a-z_]+)", plain)) == {"plan_interest_tries", "plan_interest"}
    assert set(re.findall(r"create table if not exists public\.([a-z_]+)", plain)) == {"plan_interest", "plan_interest_tries"}
    assert set(re.findall(r"alter table public\.([a-z_]+)", plain)) == {"plan_interest", "plan_interest_tries"}


def test_nobody_but_the_server_touches_it() -> None:
    plain = code(SQL)
    for table in ("plan_interest", "plan_interest_tries"):
        assert f"alter table public.{table} enable row level security;" in plain
        assert f"revoke all on public.{table} from public, anon, authenticated, service_role;" in plain
    assert "create policy" not in plain.lower()
    made = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert sorted(made) == ["plan_interest_counts", "plan_interest_forget", "plan_interest_may",
                            "plan_interest_note", "plan_interest_of"]
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name
        assert not re.search(rf"grant [^;]*{name}[^;]* to [^;]*(anon|authenticated)", plain), name
    assert plain.count("security definer") == len(made)


def handler(cases: list[dict], answers: dict) -> list[dict] | None:
    """Each of [cases] ({body, headers}) through api/plans.js, the database's
    functions answering from [answers] by name: [{status, json, asked}],
    asked being the functions called and what they were sent."""
    if shutil.which("node") is None:
        return None
    script = (
        "process.env.SUPABASE_URL = 'https://db.test'; process.env.SUPABASE_SECRET_KEY = 'secret';"
        f"const answers = {json.dumps(answers)}; let asked = [];"
        "globalThis.fetch = async (url, init) => { const name = String(url).split('/rpc/')[1];"
        "  asked.push([name, JSON.parse(init.body)]); const said = answers[name];"
        "  return new Response(JSON.stringify(said ?? null), { status: said === undefined ? 404 : 200 }); };"
        "const { default: handle } = await import('./api/plans.js');"
        f"const out = []; for (const one of {json.dumps(cases)}) {{ asked = []; let status = 0, body = null;"
        "  const response = { setHeader() { return response; }, status(s) { status = s; return response; },"
        "    json(b) { body = b; return response; } };"
        "  await handle({ method: one.method || 'POST', body: one.body, headers: one.headers || {} }, response);"
        "  out.push({ status, json: body, asked }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


GOOD = {"email": "  Ada@Example.com ", "plan": "pro", "billing": "yearly", "note": "for my\tclub  "}
FROM = {"x-forwarded-for": "203.0.113.9, 10.0.0.1"}


def test_refusals_say_why_and_keep_nothing() -> None:
    got = handler([
        {"body": {**GOOD, "email": "ada@"}},
        {"body": {**GOOD, "plan": "plus"}},
        {"body": {**GOOD, "billing": "weekly"}},
        {"body": {**GOOD, "note": "x" * 201}},
        {"body": {**GOOD, "note": 5}},
        {"method": "GET", "body": {}},
    ], {"plan_interest_may": True, "plan_interest_note": "added"})
    if got is None:
        return
    assert [one["status"] for one in got] == [422, 422, 422, 422, 422, 405]
    assert got[0]["json"]["error"] == "That is not an email address."
    assert got[1]["json"]["error"] == "Choose Pro." and "monthly or yearly" in got[2]["json"]["error"]
    assert "at most 200" in got[3]["json"]["error"]
    assert all(one["asked"] == [] for one in got), "a refusal asked the database"


def test_an_entry_is_counted_then_kept_and_a_second_says_the_same() -> None:
    got = handler([{"body": GOOD, "headers": FROM}, {"body": GOOD, "headers": FROM}],
                  {"plan_interest_may": True, "plan_interest_note": "added"})
    if got is None:
        return
    first, again = got
    assert first["status"] == 200 and first["json"] == again["json"]
    assert "write to you once" in first["json"]["said"]
    (may, place), (note, kept) = first["asked"]
    assert (may, note) == ("plan_interest_may", "plan_interest_note")
    # The place is a key, the same for the same address, never the address.
    assert re.fullmatch(r"[0-9a-f]{32}", place["p_who"]) and place == again["asked"][0][1]
    assert "203.0.113.9" not in json.dumps(first["asked"])
    assert kept == {"p_email": "ada@example.com", "p_plan": "plus", "p_billing": "yearly", "p_note": "for my club"}


def test_too_many_from_one_place_and_before_the_file() -> None:
    got = handler([{"body": GOOD}, {"body": {"email": GOOD["email"], "forget": True}}],
                  {"plan_interest_may": False})
    if got is None:
        return
    assert [one["status"] for one in got] == [429, 429]
    assert all([name for name, _ in one["asked"]] == ["plan_interest_may"] for one in got)
    before = handler([{"body": GOOD}], {})
    assert before is not None and before[0]["status"] == 503 and "not open yet" in before[0]["json"]["error"]


def test_take_it_off_forgets_that_address_alone() -> None:
    got = handler([{"body": {"email": "Ada@Example.com", "forget": True, "plan": "creator"}}],
                  {"plan_interest_may": True, "plan_interest_forget": 2})
    if got is None:
        return
    assert got[0]["status"] == 200 and "not on the list" in got[0]["json"]["said"]
    assert got[0]["asked"][1] == ["plan_interest_forget", {"p_email": "ada@example.com"}]


def test_the_page_takes_no_money_and_keeps_its_promises() -> None:
    lowered = PAGE.lower()
    # No payment anywhere: nothing of Stripe's, no link or form to a
    # checkout, no card's fields, no script but the site's own and its counter.
    assert "stripe" not in lowered
    assert not re.search(r'(href|action|src)="[^"]*(checkout|pay|billing)', lowered)
    assert not re.search(r'autocomplete="cc-', lowered)
    assert re.findall(r'<script[^>]*src="([^"]+)"', PAGE) == [
        "https://overlook.technology/s.js", "/theme.js", "/follow.js", "/plans.js"]
    # What stays free, and the promise to every account made before Pro.
    plain = re.sub(r"\s+", " ", PAGE)
    assert "What stays free" in plain and "It takes nothing out of Free" in plain
    assert "Every account made before 29 October 2026, when this page changed, gets Pro, free and with no end date" in plain
    assert "Education is free" in plain
    # The desktop app is never listed in Free, and AI builds are not Claude's.
    assert "desktop" not in re.search(r'<ul class="rows">.*?</ul>', PAGE, re.S).group(0)
    assert "Claude build" not in PAGE
    # Free says today's limit for models kept with an account, never less.
    most = int(re.search(r"export const MOST_MODELS = (\d+);", MODELS).group(1))
    free = re.search(r'<article class="card tier" id="free".*?</article>', PAGE, re.S).group(0)
    said = [int(n) for n in re.findall(r"up to (\d+)", free)]
    assert said == [most], f"Free says up to {said}, the account keeps {most}"
    tiers = re.findall(r'<article class="card tier" id="([a-z]+)"', PAGE)
    assert tiers == ["free", "pro"], tiers
    pro = re.search(r'<article class="card tier" id="pro".*?</article>', PAGE, re.S).group(0)
    assert "Coming soon" in pro and "Coming with Pro" in pro and 'data-interest="pro"' in pro
    assert re.sub(r"<[^>]+>", "", re.search(r'<p class="price">(.*?)</p>', pro).group(1)) == "$8 a month, or $80 a year"
