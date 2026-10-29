"""Paying for Pro, built dark (docs/PLANS.md, unit U3 and gate M7).

api/plans.js's checkout, portal and webhook run here under node against
the stand-in Admission and Supabase (tests/fixtures/billing/), through the
real client (api/_admission.js), every request recorded:

- Checkout only after the renewal terms are agreed, the agreement kept
  first (supabase/plan_consents.sql), monthly at $8 and yearly at $80, and
  back to this site's /settings;
- the billing portal only for an account that pays;
- the webhook: one Admission did not sign is refused and changes nothing;
  one it did forgets what is kept of the account, so the next request
  reads the new plan;
- BRICKWORKS_BILLING off: none of it answers, and each POST is the
  interest form's, refused as it always was, asking nothing;
- a unit's preview answers from the stand-in in its own process, and only
  for the stand-in's key.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/plan_consents.sql").read_text()
# What the interest form has always said to a POST with no address in it.
NOT_AN_ADDRESS = {"status": 422, "json": {"error": "That is not an email address."}}


def run(body: str, cwd: Path = ROOT, **world) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process: `w` the world as [world] says, `billing`
    api/_billing.js, `askPlans` the route, `as(claims)` a session's
    headers, `signWebhook` and `SECRET` the stand-in's signing."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { world, askPlans } from './tests/fixtures/billing/world.mjs';"
        "import { signWebhook, WEBHOOK_SECRET as SECRET } from './tests/fixtures/billing/fake_admission.mjs';"
        f"const w = await world({json.dumps(world)});"
        "const billing = await import('./api/_billing.js');"
        "const as = async (claims) => ({ authorization: `Bearer ${await w.signIn(claims)}`, host: 'pay.vercel.app',"
        " 'x-forwarded-proto': 'https' });"
        "const ADA = { sub: '7d6c1a2e-0000-4000-8000-00000000ada0', email: 'ada@example.com' };"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=cwd, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def admission_calls(calls: list[str], what: str) -> list[str]:
    return [c for c in calls if c == f"POST https://admission.test/v1/{what}"]


def test_checkout_waits_for_the_renewal_terms_agreed() -> None:
    got = run("""
const h = await as(ADA);
const none = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'month' } });
const said = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'month', consent: 'yes' } });
const odd = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'week', consent: true } });
return { none, said, odd, consents: w.consents, calls: w.calls };
""", billing="test")
    if got is None:
        return
    for refused in (got["none"], got["said"]):
        assert refused == {"status": 422, "json": {"error": "Tick the box to agree that Pro renews until you cancel."}}
    assert got["odd"] == {"status": 422, "json": {"error": "Choose monthly or yearly."}}
    # Nothing kept, and Stripe never asked.
    assert got["consents"] == [] and admission_calls(got["calls"], "checkout") == []


def test_checkout_monthly_and_yearly_after_the_agreement_is_kept() -> None:
    got = run("""
const h = await as(ADA);
const month = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h,
  body: { interval: 'month', consent: true, amount: 800 } });
const year = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h,
  body: { interval: 'year', consent: true, amount: 8000 } });
const order = w.calls.filter((c) => /plan_consent_note|v1\\/checkout/.test(c));
return { month, year, asked: w.admission.checkouts, consents: w.consents, order };
""", billing="test")
    if got is None:
        return
    for answer, interval in ((got["month"], "month"), (got["year"], "year")):
        assert answer["status"] == 200 and answer["json"]["kind"] == "checkout"
        assert answer["json"]["url"].startswith("https://checkout.stripe.test/c/pay/cs_test_")
        assert answer["json"]["url"].endswith(f"#{interval}")
    ada = "7d6c1a2e-0000-4000-8000-00000000ada0"
    for asked, interval in zip(got["asked"], ("month", "year")):
        # The account from the session, and back to the deployment it came by.
        assert asked == {"customerId": ada, "email": "ada@example.com", "plan": "pro", "interval": interval,
                         "returnUrl": "https://pay.vercel.app/settings?billing=done#plan",
                         "cancelUrl": "https://pay.vercel.app/settings?billing=cancelled#plan"}
    month, year = got["consents"]
    assert (month["p_user"], month["p_plan"], month["p_interval"], month["p_amount"], month["p_currency"]) == \
        (ada, "pro", "month", 800, "usd")
    assert (year["p_interval"], year["p_amount"]) == ("year", 8000)
    assert "$8.00 USD a month" in month["p_terms"] and "renews automatically" in month["p_terms"]
    assert "$80.00 USD a year" in year["p_terms"] and "cancel any time" in year["p_terms"]
    # Each agreement kept before its Checkout was asked for.
    assert [c.rsplit("/", 1)[-1] for c in got["order"]] == ["plan_consent_note", "checkout"] * 2


def test_no_checkout_when_the_agreement_cannot_be_kept_or_the_price_moved() -> None:
    got = run("""
const h = await as(ADA);
w.noConsents = true;
const unkept = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'year', consent: true } });
w.noConsents = false;
const moved = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h,
  body: { interval: 'month', consent: true, amount: 500 } });
w.admission.comp('u-given', 'pro');
const given = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: await as({ sub: 'u-given', email: 'g@example.com' }),
  body: { interval: 'month', consent: true } });
const nobody = await askPlans({ method: 'POST', query: { op: 'checkout' }, body: { interval: 'month', consent: true } });
return { unkept, moved, given, nobody, consents: w.consents, checkouts: w.admission.checkouts };
""", billing="test")
    if got is None:
        return
    assert got["unkept"] == {"status": 503, "json": {"error": "Paying for Pro is not open here yet."}}
    assert got["moved"]["status"] == 409 and "$8.00 USD a month" in got["moved"]["json"]["error"]
    assert got["given"] == {"status": 409, "json": {"error": "This account has Pro already, with nothing to pay."}}
    assert got["nobody"] == {"status": 401, "json": {"error": "sign in to Brickworks first"}}
    assert got["consents"] == [] and got["checkouts"] == []


def test_the_portal_is_only_for_an_account_that_pays() -> None:
    got = run("""
const free = await askPlans({ method: 'POST', query: { op: 'portal' }, headers: await as(ADA), body: {} });
w.admission.subscribe('u-pro');
const h = await as({ sub: 'u-pro', email: 'pro@example.com' });
const home = await askPlans({ method: 'POST', query: { op: 'portal' }, headers: h, body: {} });
const card = await askPlans({ method: 'POST', query: { op: 'portal' }, headers: h, body: { flow: 'payment_method_update' } });
const odd = await askPlans({ method: 'POST', query: { op: 'portal' }, headers: h, body: { flow: 'refund' } });
// One who pays and asks Checkout again is sent to the portal by Admission.
const again = await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'year', consent: true } });
return { free, home, card, odd, again, portals: w.admission.portals };
""", billing="test")
    if got is None:
        return
    assert got["free"] == {"status": 409, "json": {"error": "There is no billing to manage: this account has never paid for Pro."}}
    assert got["home"]["status"] == 200 and got["home"]["json"]["url"].startswith("https://billing.stripe.test/")
    assert got["card"]["status"] == 200
    assert got["odd"] == {"status": 422, "json": {"error": "That is not something billing does."}}
    assert got["again"]["status"] == 200 and got["again"]["json"]["kind"] == "portal"
    # Only the account that pays reached Admission's portal, and back to /settings.
    assert [p["customerId"] for p in got["portals"]] == ["u-pro", "u-pro"]
    assert got["portals"][0] == {"customerId": "u-pro", "returnUrl": "https://pay.vercel.app/settings?billing=portal#plan"}
    assert got["portals"][1]["flow"] == "payment_method_update"


HEAR = """
const event = (id, customerId) => JSON.stringify({ id, type: 'customer.updated', createdAt: new Date().toISOString(),
  mode: 'test', seq: 1, data: { customerId, reason: 'subscription.created', customer: null } });
const send = async (raw, signature) => askPlans({ method: 'POST', query: { op: 'webhook' }, raw,
  headers: { 'content-type': 'application/json', ...(signature ? { 'admission-signature': signature } : {}) } });
"""


def test_the_webhook_refuses_what_admission_did_not_sign_and_forgets_on_what_it_did() -> None:
    got = run(HEAR + """
process.env.ADMISSION_WEBHOOK_SECRET = SECRET;
const before = await billing.entitlementOf('u-ada');
// Ada pays; until Admission's word arrives, what is kept says Free.
w.admission.subscribe('u-ada');
const raw = event('adm_evt_1', 'u-ada');
const unsigned = await send(raw);
const forged = await send(raw, await signWebhook(raw, 'adm_whsec_somebodyelse'));
const changed = await send(raw.replace('u-ada', 'u-bob'), await signWebhook(raw));
const stale = await send(raw, await signWebhook(raw, SECRET, Math.floor(Date.now() / 1000) - 600));
const still = await billing.entitlementOf('u-ada');
const heard = await send(raw, await signWebhook(raw));
const after = await billing.entitlementOf('u-ada');
const again = await send(raw, await signWebhook(raw));
delete process.env.ADMISSION_WEBHOOK_SECRET;
const unset = await send(raw, await signWebhook(raw));
return { plans: [before, still, after].map((e) => [e.plan.key, e.freshness]), unsigned, forged, changed, stale, heard,
         again, unset };
""", billing="test")
    if got is None:
        return
    refused = {"status": 400, "json": {"error": "That is not from Admission."}}
    assert got["unsigned"] == got["forged"] == got["changed"] == got["stale"] == refused
    # Refused, nothing was forgotten: the kept answer stood. Heard, the next
    # request asked Admission and read Pro.
    assert got["plans"] == [["free", "live"], ["free", "cached"], ["pro", "live"]]
    assert got["heard"] == {"status": 200, "json": {"heard": "customer.updated"}}
    assert got["again"] == {"status": 200, "json": {"heard": "again"}}
    assert got["unset"] == {"status": 404, "json": {"error": "This deployment takes no webhook."}}


def test_fresh_asks_admission_again() -> None:
    got = run("""
const h = await as({ sub: 'u-back', email: 'back@example.com' });
await askPlans({ query: { op: 'plan' }, headers: h });
w.admission.subscribe('u-back');
const kept = await askPlans({ query: { op: 'plan' }, headers: h });
const fresh = await askPlans({ query: { op: 'plan', fresh: '1' }, headers: h });
return [kept.json.plan.key, fresh.json.plan.key, fresh.json.subscription.status];
""", billing="test")
    if got is None:
        return
    assert got == ["free", "pro", "active"]


def test_off_none_of_it_answers() -> None:
    got = run(HEAR + """
process.env.ADMISSION_WEBHOOK_SECRET = SECRET;
const h = await as(ADA);
const raw = event('adm_evt_2', ADA.sub);
const asked = [
  await askPlans({ method: 'POST', query: { op: 'checkout' }, headers: h, body: { interval: 'month', consent: true } }),
  await askPlans({ method: 'POST', query: { op: 'portal' }, headers: h, body: {} }),
  await send(raw, await signWebhook(raw)),
  await askPlans({ method: 'POST', body: {} }),
];
return { asked, calls: w.calls, consents: w.consents };
""")
    if got is None:
        return
    # Each is the interest form's POST, refused as before plans, and nothing
    # was asked of Admission or the database.
    assert got["asked"] == [NOT_AN_ADDRESS] * 4
    assert [c for c in got["calls"] if "admission" in c or "/rpc/" in c] == [] and got["consents"] == []


def test_back_to_this_site_and_in_live_mode_only_to_brickworks_diy() -> None:
    got = run("""
const preview = { headers: { host: 'pay.vercel.app', 'x-forwarded-proto': 'https' } };
const here = { headers: { host: '127.0.0.1:8890' } };
return [billing.returnOrigin(preview, 'test'), billing.returnOrigin(here, 'test'), billing.returnOrigin(preview, 'live')];
""")
    if got is None:
        return
    assert got == ["https://pay.vercel.app", "http://127.0.0.1:8890", "https://brickworks.diy"]


def test_a_unit_preview_answers_from_the_stand_in_and_only_for_its_key() -> None:
    if shutil.which("node") is None:
        return
    # As tools/deploy.sh --billing-stand-in puts a function together: api/'s
    # files, and the stand-in beside them.
    with tempfile.TemporaryDirectory() as made:
        here = Path(made)
        shutil.copytree(ROOT / "api", here / "api", ignore=shutil.ignore_patterns("_webp*"))
        shutil.copytree(ROOT / "tests/fixtures", here / "tests/fixtures")
        shutil.copy(ROOT / "tests/fixtures/billing/fake_admission.mjs", here / "api/_admission_stand_in.mjs")
        ask = """
process.env.ADMISSION_URL = __URL__;
process.env.ADMISSION_KEY = __KEY__;
billing.forgetClient();
// Nothing on the network answers: only the stand-in in this process can.
const before = w.calls.length;
globalThis.fetch = async (input) => { w.calls.push(`refused ${input}`); throw new TypeError('no network'); };
const e = await billing.entitlementOf('u-ada');
return { standing: e.standing, plan: e.plan && e.plan.key, network: w.calls.slice(before).filter((c) => !c.includes('db.test')) };
"""
        zeros = "adm_test_00000000000000000000000000000000"
        real = "adm_test_5Hq2c0Lr8Hq2c0Lr8Hq2c0Lr8Hq2c0Lr"
        cases = [(zeros, "stand-in"), (real, "stand-in"), (zeros, "https://admission.sh")]
        got = [run(ask.replace("__URL__", json.dumps(url)).replace("__KEY__", json.dumps(key)), cwd=here, billing="test")
               for key, url in cases]
    stood_in, real_key, real_url = got
    assert stood_in == {"standing": "known", "plan": "free", "network": []}
    # A key Admission made, or no stand-in asked for: the network, which
    # does not answer here.
    assert real_key["standing"] == "unknown" and real_key["network"]
    assert real_url["standing"] == "unknown" and real_url["network"]


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_consent_table_only_adds_and_only_the_server_reads_it() -> None:
    plain = code(SQL)
    lowered = plain.lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "update public."):
        assert word not in lowered, f"plan_consents.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", lowered) == ["plan_consents"]
    assert set(re.findall(r"delete from public\.([a-z_]+)", lowered)) == {"plan_consents"}
    assert "alter table public.plan_consents enable row level security;" in plain
    assert "revoke all on public.plan_consents from public, anon, authenticated, service_role;" in plain
    assert "create policy" not in lowered
    made = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert made == ["plan_consent_note"]
    assert re.search(r"revoke all on function public\.plan_consent_note\([^)]*\) from public, anon, authenticated;", plain)
    assert re.search(r"grant execute on function public\.plan_consent_note\([^)]*\) to service_role;", plain)
    assert plain.count("security definer") == 1
    # Four years, and the function the server calls is the one made here.
    assert "interval '4 years'" in plain
    assert set(re.findall(r"rpc/(plan_consent_[a-z]+)", (ROOT / "api/_billing.js").read_text())) == set(made)


def deploy(*flags: str, **env: str) -> subprocess.CompletedProcess:
    """tools/deploy.sh [flags], copied alone into an empty checkout, so no
    .env is found and no VERCEL_TOKEN: it can stop on its options, or say it
    has no token, and never deploy anything."""
    with tempfile.TemporaryDirectory() as made:
        (Path(made) / "tools").mkdir()
        shutil.copy(ROOT / "tools/deploy.sh", Path(made) / "tools/deploy.sh")
        clean = {"PATH": "/usr/bin:/bin", "HOME": made, **env}
        return subprocess.run(["bash", str(Path(made) / "tools/deploy.sh"), *flags], cwd=made, env=clean,
                              capture_output=True, text=True, timeout=30)


def test_a_unit_preview_tries_the_real_test_mode_only_with_a_test_key() -> None:
    test_key = "adm_test_" + "Ab3" * 10 + "Cd"
    live_key = "adm_live_" + "Ab3" * 10 + "Cd"
    # A unit's preview alone, and never with the stand-in too.
    assert deploy("--billing-test", ADMISSION_TEST_KEY=test_key).returncode == 2
    assert deploy("--prod", "--billing-test", ADMISSION_TEST_KEY=test_key).returncode == 2
    assert deploy("--unit", "--billing-test", "--billing-stand-in", ADMISSION_TEST_KEY=test_key).returncode == 2
    # No key, a live key, or a webhook secret that is not one: refused
    # before anything is asked of Vercel.
    for env in ({}, {"ADMISSION_TEST_KEY": live_key}, {"ADMISSION_TEST_KEY": "adm_test_short"},
                {"ADMISSION_TEST_KEY": test_key, "ADMISSION_TEST_WEBHOOK_SECRET": "whsec_stripe"}):
        done = deploy("--unit", "--billing-test", **env)
        assert done.returncode == 2, (env, done.stdout)
        assert "--billing-test needs an adm_test_ key" in done.stdout or "not an adm_whsec_" in done.stdout
        assert live_key not in done.stdout + done.stderr
    # A test key, with or without a webhook secret, gets past the options
    # to the token, which this empty checkout has none of; the key is
    # never printed.
    for env in ({"ADMISSION_TEST_KEY": test_key},
                {"ADMISSION_TEST_KEY": test_key, "ADMISSION_TEST_WEBHOOK_SECRET": "adm_whsec_" + "x" * 32}):
        done = deploy("--unit", "--billing-test", **env)
        assert done.returncode == 1 and "no VERCEL_TOKEN" in done.stdout, done.stdout
        assert test_key not in done.stdout + done.stderr
