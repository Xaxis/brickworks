"""Plans from Admission, built dark (docs/PLANS.md, unit U1).

api/_billing.js and api/plans.js run here under node against a stand-in
Admission and Supabase (tests/fixtures/billing/), through the real client
(api/_admission.js, UPSTREAM.md). Every request either of them is sent is
recorded, so "nothing was asked" is a fact the tests read, not a hope:

- an account's entitlement: Free with 10 Claude builds and none used, Pro
  with no limit and the desktop, a comp, the owner (MASTER_EMAIL);
- Admission unreachable: a cold instance answers from the snapshot kept in
  the database; with no snapshot, an answer that refuses nothing, so
  nobody who pays is ever locked out;
- BRICKWORKS_BILLING off (unset, or a mode without its own kind of key):
  no request at all, and /api/plans answers a GET as it always has;
- supabase/admission_snapshots.sql only adds, and only the server reads it.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/admission_snapshots.sql").read_text()
LIVE_KEY = "adm_live_00000000000000000000000000000000"
# What a GET to /api/plans has always been answered (api/plans.js before plans).
REFUSED_GET = {"error": "POST {email, plan, billing, note} or {email, forget: true}"}


def run(body: str, **world) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process, with the world set up as [world] says and
    api/_billing.js as `billing`, `w` the world and `askPlans` the route."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { world, askPlans } from './tests/fixtures/billing/world.mjs';"
        f"const w = await world({json.dumps(world)});"
        "const billing = await import('./api/_billing.js');"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def next_month() -> str:
    now = datetime.now(timezone.utc)
    year, month = (now.year + 1, 1) if now.month == 12 else (now.year, now.month + 1)
    return f"{year:04d}-{month:02d}-01T00:00:00.000Z"


ASK = """
const e = await billing.entitlementOf(WHO);
return { e, build: billing.mayBuild(e), desktop: billing.mayDesktop(e), calls: w.calls };
"""


def ask(setup: str, who: str, **world) -> dict | None:
    return run(setup + ASK.replace("WHO", json.dumps(who)), billing="test", **world)


def test_free_has_ten_claude_builds_and_none_used() -> None:
    got = ask("", "u-free")
    if got is None:
        return
    e = got["e"]
    assert e["billing"] == "test" and e["standing"] == "known" and e["freshness"] == "live"
    assert e["plan"] == {"key": "free", "name": "Free", "source": "default", "until": None}
    assert e["builds"] == {"limit": 10, "used": 0, "remaining": 10, "resetsAt": next_month()}
    assert e["desktop"] is False and e["owner"] is False and e["subscription"] is None
    assert got["build"] is True and got["desktop"] is False
    # The account and the plans, from Admission; the snapshot read and kept.
    assert "GET https://admission.test/v1/customers/u-free" in got["calls"]
    assert "POST https://db.test/rest/v1/rpc/admission_snapshot_put" in got["calls"]


def test_free_with_its_ten_used_may_not_build() -> None:
    got = ask("w.admission.setUsed('u-free', 'claude_builds', 10);", "u-free")
    if got is None:
        return
    assert got["e"]["builds"]["remaining"] == 0 and got["build"] is False


def test_pro_has_no_limit_and_the_desktop() -> None:
    got = ask("w.admission.subscribe('u-pro'); w.admission.setUsed('u-pro', 'claude_builds', 400);", "u-pro")
    if got is None:
        return
    e = got["e"]
    assert e["plan"] == {"key": "pro", "name": "Pro", "source": "subscription", "until": None}
    assert e["builds"] == {"limit": None, "used": 400, "remaining": None, "resetsAt": next_month()}
    assert e["desktop"] is True and got["build"] is True and got["desktop"] is True
    assert e["subscription"]["status"] == "active" and e["subscription"]["endsAt"] is None


def test_a_comp_gives_pro_until_it_ends() -> None:
    got = ask("w.admission.comp('u-school', 'pro', '2027-10-29T00:00:00.000Z');", "u-school")
    if got is None:
        return
    e = got["e"]
    assert e["plan"] == {"key": "pro", "name": "Pro", "source": "override", "until": "2027-10-29T00:00:00.000Z"}
    assert e["builds"]["limit"] is None and e["desktop"] is True and e["subscription"] is None


def test_down_a_cold_instance_answers_from_the_kept_snapshot() -> None:
    got = run("""
w.admission.subscribe('u-pro');
w.admission.setUsed('u-free', 'claude_builds', 10);
const before = [await billing.entitlementOf('u-pro'), await billing.entitlementOf('u-free')];
billing.forgetClient();
w.age(10 * 60_000);
w.admission.down = true;
const after = [await billing.entitlementOf('u-pro'), await billing.entitlementOf('u-free')];
return { before, after, may: after.map(billing.mayBuild), desk: after.map(billing.mayDesktop),
         kept: [...w.snapshots.keys()] };
""", billing="test")
    if got is None:
        return
    pro, free = got["after"]
    # Pro stays Pro, from the database, with nothing held in the new client.
    assert pro["standing"] == "known" and pro["freshness"] == "stale"
    assert pro["plan"]["key"] == "pro" and pro["desktop"] is True and got["desk"] == [True, False]
    # And Free stays Free at its limit: an outage is never more than you had.
    assert free["plan"]["key"] == "free" and free["builds"]["remaining"] == 0 and got["may"] == [True, False]
    assert {"admission:v2:brickworks:test:c:u-pro", "admission:v2:brickworks:test:c:u-free"} <= set(got["kept"])


def test_down_with_no_snapshot_refuses_nobody() -> None:
    got = run("""
w.admission.down = true;
const never = await billing.entitlementOf('u-new');
// Admission answered for somebody else once, so the client knows the plans
// and would guess Free for a stranger: a guess refuses nobody either.
w.admission.down = false;
billing.forgetClient();
await billing.entitlementOf('u-other');
await billing.currentOffer();
w.admission.down = true;
const guessed = await billing.entitlementOf('u-paying');
// The database down as well, for one who pays and was kept there.
w.admission.down = false;
billing.forgetClient();
w.admission.subscribe('u-pro');
await billing.entitlementOf('u-pro');
billing.forgetClient();
w.admission.down = true;
w.storeDown = true;
const bare = await billing.entitlementOf('u-pro');
const all = [never, guessed, bare];
return { all, may: all.map(billing.mayBuild), desk: all.map(billing.mayDesktop) };
""", billing="test")
    if got is None:
        return
    for e in got["all"]:
        assert e["standing"] == "unknown" and e["billing"] == "test"
        # Nothing to refuse on, and nothing lasting to grant on.
        assert e["plan"] is None and e["builds"] is None and e["desktop"] is None
    assert got["may"] == [True, True, True] and got["desk"] == [True, True, True]


def test_off_asks_nothing_at_all() -> None:
    got = run("""
const e = await billing.entitlementOf('u1');
const offer = await billing.currentOffer();
await billing.reportOwner({ sub: 'u1', email: 'owner@example.com' });
const token = await w.signIn({ sub: 'u1', email: 'ada@example.com' });
const routes = [await askPlans(), await askPlans({ query: { op: 'plan' }, headers: { authorization: `Bearer ${token}` } })];
return { e, offer, routes, may: [billing.mayBuild(e), billing.mayDesktop(e)], calls: w.calls,
         client: billing.admission() };
""")
    if got is None:
        return
    assert got["calls"] == [], got["calls"]
    assert got["e"]["standing"] == "off" and got["e"]["billing"] == "off" and got["may"] == [True, True]
    assert got["offer"] is None and got["client"] is None
    # A GET to /api/plans, with or without a session, as before plans.
    assert got["routes"] == [{"status": 405, "json": REFUSED_GET}] * 2


def test_the_switch_needs_its_own_kind_of_key() -> None:
    got = run("""
const key = (mode) => `adm_${mode}_00000000000000000000000000000000`;
const cases = [
  {}, { BRICKWORKS_BILLING: 'off', ADMISSION_KEY: key('test') }, { BRICKWORKS_BILLING: 'yes', ADMISSION_KEY: key('test') },
  { BRICKWORKS_BILLING: 'test' }, { BRICKWORKS_BILLING: 'test', ADMISSION_KEY: key('live') },
  { BRICKWORKS_BILLING: 'live', ADMISSION_KEY: key('test') }, { BRICKWORKS_BILLING: 'test', ADMISSION_KEY: 'adm_test_short' },
  { BRICKWORKS_BILLING: ' Test ', ADMISSION_KEY: key('test') }, { BRICKWORKS_BILLING: 'live', ADMISSION_KEY: key('live') },
];
return cases.map((env) => billing.billingMode(env));
""")
    if got is None:
        return
    assert got == ["off"] * 7 + ["test", "live"]
    # A test key never answers for live, nor a live one for test: off, asked nothing.
    mismatched = run(ASK.replace("WHO", '"u1"'), billing="live")
    assert mismatched is not None and mismatched["calls"] == [] and mismatched["e"]["standing"] == "off"
    live_as_test = run(ASK.replace("WHO", '"u1"'), billing="test", key=LIVE_KEY)
    assert live_as_test is not None and live_as_test["calls"] == [] and live_as_test["e"]["standing"] == "off"


def test_the_route_answers_a_signed_in_account_and_the_owner() -> None:
    got = run("""
const as = async (claims) => ({ authorization: `Bearer ${await w.signIn(claims)}` });
const mine = await askPlans({ query: { op: 'plan' }, headers: await as({ sub: 'u-ada', email: 'ada@example.com' }) });
const owner = await askPlans({ query: { op: 'plan' }, headers: await as({ sub: 'u-own', email: 'Owner@Example.com' }) });
const nobody = await askPlans({ query: { op: 'plan' } });
const offer = await askPlans();
const odd = await askPlans({ query: { op: 'checkout' } });
return { mine, owner, nobody, offer, odd, owners: [...w.admission.owners] };
""", billing="test")
    if got is None:
        return
    mine, owner = got["mine"], got["owner"]
    assert mine["status"] == 200 and mine["json"]["plan"]["key"] == "free" and mine["json"]["builds"]["limit"] == 10
    # The owner (MASTER_EMAIL) is reported to Admission, and has everything.
    assert got["owners"] == ["u-own"]
    assert owner["json"]["owner"] is True and owner["json"]["builds"]["limit"] is None and owner["json"]["desktop"] is True
    assert got["nobody"] == {"status": 401, "json": {"error": "sign in to Brickworks first"}}
    assert got["odd"]["status"] == 404
    offer = got["offer"]["json"]
    assert got["offer"]["status"] == 200 and offer["billing"] == "test" and offer["forSale"] is True
    assert offer["free"]["claudeBuilds"] == 10 and offer["free"]["desktop"] is False
    assert offer["pro"]["claudeBuilds"] == "unlimited" and offer["pro"]["desktop"] is True
    assert offer["pro"]["prices"] == {"month": 800, "year": 8000}


def test_the_offer_when_admission_never_answered_is_the_published_one_not_for_sale() -> None:
    got = run("w.admission.down = true; return await billing.currentOffer();", billing="test")
    if got is None:
        return
    assert got["forSale"] is False and got["free"]["claudeBuilds"] == 10
    assert got["pro"]["prices"] == {"month": 800, "year": 8000}


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_snapshot_table_only_adds_and_only_the_server_reads_it() -> None:
    plain = code(SQL)
    lowered = plain.lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "update public."):
        assert word not in lowered, f"admission_snapshots.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", lowered) == ["admission_snapshots"]
    assert set(re.findall(r"delete from public\.([a-z_]+)", lowered)) == {"admission_snapshots"}
    assert "alter table public.admission_snapshots enable row level security;" in plain
    assert "revoke all on public.admission_snapshots from public, anon, authenticated, service_role;" in plain
    assert "create policy" not in lowered
    made = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert sorted(made) == ["admission_snapshot_get", "admission_snapshot_put"]
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain)
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain)
    assert plain.count("security definer") == len(made)
    # The functions the store calls are the ones the file makes.
    billing = (ROOT / "api/_billing.js").read_text()
    assert set(re.findall(r'rpc/(admission_snapshot_[a-z]+)', billing)) == set(made)
