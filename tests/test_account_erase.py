"""Deleting an account ends its plan at Admission first (api/account.js
?op=delete, api/_billing.js eraseAccount; Bookwright's ADR-0014 decision 7).

api/account.js's deletion runs here under node against the stand-in
Admission and Supabase (tests/fixtures/billing/), through the real client
(api/_admission.js), every request recorded:

- BRICKWORKS_BILLING off: Admission is never asked, and the answer is what
  it always was;
- Free: erased at Admission, then deleted;
- Pro: the subscription ended now and the customer erased, then deleted,
  and the answer says the plan ended;
- Admission down, or refusing our key: nothing deleted, and the person told
  plainly;
- a deletion that stopped after Admission erased the account finishes when
  asked again, ending nothing twice;
- an answer under 13 (?op=age) deletes the account by the very same steps,
  Admission first, and with Admission down deletes nothing.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADMISSION = "https://admission.test"
PRO_NOT_ENDED = ("We couldn't cancel your Pro plan, so nothing was deleted. Try again in a minute, or write to "
                 "support@atypic.ai.")
NOT_ERASED = ("We couldn't close your plan with billing just now, so nothing was deleted. Try again in a minute, "
              "or write to support@atypic.ai.")
TOO_YOUNG = ("Brickworks accounts are for 13 and over. Ask a parent or guardian to sign in with their own email "
             "and build with you.")
# What a deletion has always answered for an account with no photos and no avatar.
DELETED = {"status": 200, "json": {"deleted": True, "photos": 0, "avatars": 0, "feedback": 0}}


def run(body: str, **world) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process: `w` the world as [world] says, `billing`
    api/_billing.js, `del(claims)` that account's own deletion, its address
    typed, and `ADA` an account."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { world, askAccount } from './tests/fixtures/billing/world.mjs';"
        f"const w = await world({json.dumps(world)});"
        "const billing = await import('./api/_billing.js');"
        "const del = async (claims) => askAccount({ method: 'POST', query: { op: 'delete' },"
        " headers: { authorization: `Bearer ${await w.signIn(claims)}` }, body: { confirm: claims.email } });"
        "const ADA = { sub: '7d6c1a2e-0000-4000-8000-00000000ada0', email: 'ada@example.com' };"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def erase_of(sub: str) -> str:
    return f"DELETE {ADMISSION}/v1/customers/{sub}"


def test_off_admission_is_never_asked() -> None:
    got = run("""
const said = await del(ADA);
return { said, deleted: w.deleted, calls: w.calls, asked: w.admission.calls };
""", billing="")
    if got is None:
        return
    assert got["said"] == DELETED
    assert got["deleted"] == ["7d6c1a2e-0000-4000-8000-00000000ada0"]
    assert got["asked"] == [] and not any("admission" in c for c in got["calls"])


def test_free_is_erased_then_deleted() -> None:
    got = run("""
w.admission.setUsed(ADA.sub, 'ai_builds', 3);
const said = await del(ADA);
const owner = await del({ sub: '7d6c1a2e-0000-4000-8000-0000000000aa', email: 'owner@example.com' });
return { said, owner, deleted: w.deleted, calls: w.calls, erasures: w.admission.erasures,
  used: w.admission.used(ADA.sub, 'ai_builds') };
""", billing="test")
    if got is None:
        return
    sub = "7d6c1a2e-0000-4000-8000-00000000ada0"
    # A Free account's answer is the same as ever: no plan ended.
    assert got["said"] == DELETED
    assert got["erasures"] == [{"customerId": sub, "found": True, "canceled": []}]
    assert got["used"] == 0
    # Admission first, the account after.
    calls = got["calls"]
    assert calls.index(erase_of(sub)) < calls.index(f"DELETE https://db.test/auth/v1/admin/users/{sub}")
    assert got["deleted"] == [sub]
    # The owner's account is refused before Admission is asked.
    assert got["owner"]["status"] == 403
    assert erase_of("7d6c1a2e-0000-4000-8000-0000000000aa") not in calls


def test_pro_is_cancelled_and_erased_then_deleted() -> None:
    got = run("""
w.admission.subscribe(ADA.sub, { interval: 'year' });
const before = await billing.entitlementOf(ADA.sub);
const said = await del(ADA);
const after = await (await w.admission.fetch(`https://admission.test/v1/customers/${ADA.sub}`,
  { headers: { authorization: 'Bearer adm_test_00000000000000000000000000000000' } })).json();
const held = [...w.snapshots.entries()].filter(([k]) => k.includes(ADA.sub));
return { before: before.subscription, said, after: { plan: after.plan, subscription: after.subscription }, held,
  deleted: w.deleted, calls: w.calls, erasures: w.admission.erasures };
""", billing="test")
    if got is None:
        return
    sub = "7d6c1a2e-0000-4000-8000-00000000ada0"
    assert got["before"]["status"] == "active"
    assert got["said"] == {"status": 200, "json": {**DELETED["json"], "plan": {"ended": 1}}}
    assert got["erasures"] == [{"customerId": sub, "found": True, "canceled": [f"sub_{sub}"]}]
    # Nothing left at Admission to charge: no subscription, the default plan.
    assert got["after"]["subscription"] is None and got["after"]["plan"]["source"] == "default"
    # What the client kept of them, emptied in the database too.
    assert got["held"] and all(value == "" for _, value in got["held"])
    calls = got["calls"]
    assert calls.index(erase_of(sub)) < calls.index(f"DELETE https://db.test/auth/v1/admin/users/{sub}")
    assert got["deleted"] == [sub]


def test_admission_down_or_refusing_deletes_nothing() -> None:
    got = run("""
w.admission.subscribe(ADA.sub);
await billing.entitlementOf(ADA.sub);
w.admission.down = true;
const pro = await del(ADA);
const free = await del({ sub: '7d6c1a2e-0000-4000-8000-0000000000b0', email: 'bea@example.com' });
const touched = w.calls.filter((c) => /oc_connect_leaving|shared_models|build_photos|profile_avatars|\\/storage\\/|admin\\/users/.test(c));
w.admission.down = false;
const still = (await billing.entitlementOf(ADA.sub)).subscription;
return { pro, free, touched, deleted: w.deleted, erasures: w.admission.erasures, still };
""", billing="test")
    if got is None:
        return
    assert got["pro"] == {"status": 503, "json": {"error": PRO_NOT_ENDED}}
    assert got["free"] == {"status": 503, "json": {"error": NOT_ERASED}}
    # Nothing of either account touched, and the plan as it was.
    assert got["touched"] == [] and got["deleted"] == [] and got["erasures"] == []
    assert got["still"]["status"] == "active"

    # A key Admission does not know is our mistake: still nothing deleted.
    wrong = run("""
const said = await del(ADA);
return { said, deleted: w.deleted, asked: w.admission.calls };
""", billing="test", key="adm_test_" + "1" * 32)
    if wrong is None:
        return
    assert wrong["said"] == {"status": 503, "json": {"error": NOT_ERASED}}
    assert wrong["deleted"] == [] and "DELETE /v1/customers/7d6c1a2e-0000-4000-8000-00000000ada0" in wrong["asked"]


def test_a_repeat_after_a_half_done_deletion_finishes() -> None:
    got = run("""
w.admission.subscribe(ADA.sub);
w.authDown = true;
const first = await del(ADA);
const between = await (await w.admission.fetch(`https://admission.test/v1/customers/${ADA.sub}`,
  { headers: { authorization: 'Bearer adm_test_00000000000000000000000000000000' } })).json();
w.authDown = false;
const again = await del(ADA);
return { first, between: between.subscription, again, deleted: w.deleted, erasures: w.admission.erasures };
""", billing="test")
    if got is None:
        return
    sub = "7d6c1a2e-0000-4000-8000-00000000ada0"
    # Admission erased it and ended Pro; Supabase then failed, so the account stayed.
    assert got["first"]["status"] == 502
    assert got["between"] is None
    # Asked again: erasing finds nothing and ends nothing, and the account goes.
    assert got["again"] == DELETED
    assert got["erasures"] == [
        {"customerId": sub, "found": True, "canceled": [f"sub_{sub}"]},
        {"customerId": sub, "found": False, "canceled": []},
    ]
    assert got["deleted"] == [sub]


def test_an_answer_under_13_is_deleted_by_the_same_steps() -> None:
    got = run("""
w.ageAsk = true;
const BO = { sub: '7d6c1a2e-0000-4000-8000-0000000000b0', email: 'bo@example.com' };
const young = async (claims) => askAccount({ method: 'POST', query: { op: 'age' },
  headers: { authorization: `Bearer ${await w.signIn(claims)}` },
  body: { month: 1, year: new Date().getUTCFullYear() - 9 } });
w.admission.down = true;
const down = await young(BO);
const held = { deleted: [...w.deleted], erasures: [...w.admission.erasures],
  touched: w.calls.filter((c) => /oc_connect_leaving|\\/storage\\/|admin\\/users|otp_requests/.test(c)) };
w.admission.down = false;
let from = w.calls.length;
const said = await young(BO);
const age = w.calls.slice(from);
from = w.calls.length;
await del(ADA);
const asked = w.calls.slice(from);
return { down, held, said, age, asked, deleted: w.deleted, erased: w.admission.erasures.map((e) => e.customerId) };
""", billing="test")
    if got is None:
        return
    bo, ada = "7d6c1a2e-0000-4000-8000-0000000000b0", "7d6c1a2e-0000-4000-8000-00000000ada0"
    # Admission down: refused, and nothing of the account touched.
    assert got["down"]["status"] == 503 and "deleted" not in got["down"]["json"]
    assert got["held"] == {"deleted": [], "erasures": [], "touched": []}
    # Up: told, and gone, erased at Admission first.
    assert got["said"] == {"status": 403, "json": {"error": TOO_YOUNG, "deleted": True}}
    assert got["erased"] == [bo, ada] and got["deleted"] == [bo, ada]
    age = got["age"]
    users = f"DELETE https://db.test/auth/v1/admin/users/{bo}"
    assert age.index(erase_of(bo)) < age.index(users) < age.index("DELETE https://db.test/rest/v1/otp_requests")

    # The same steps in the same order as the deletion a person asks for:
    # only the question before them and the codes' count after differ.
    def steps(calls: list[str], sub: str) -> list[str]:
        return [c.replace(sub, "<id>") for c in calls if not re.search(r"jwks|rpc/age_of|otp_requests", c)]
    assert steps(age, bo) == steps(got["asked"], ada) and erase_of("<id>") in steps(age, bo)


def test_its_photos_go_with_their_card_copies() -> None:
    # Each photo of a real build it posted is two files in storage, the photo
    # and its copy for the cards (api/_builds.js photoName, cardName): both go.
    got = run("""
w.photos = [{ id: "PhotoAaa01", account: ADA.sub, model: "ModelAaa01" },
  { id: "PhotoBbb02", account: ADA.sub, model: "ModelBbb02" },
  { id: "PhotoCcc03", account: "someone-else", model: "ModelAaa01" }];
const said = await del(ADA);
return { said, removed: w.storageDeletes, deleted: w.deleted };
""", billing="")
    if got is None:
        return
    assert got["said"]["status"] == 200 and got["said"]["json"]["photos"] == 2
    assert got["removed"] == [["PhotoAaa01.jpg", "PhotoAaa01.card.jpg", "PhotoBbb02.jpg", "PhotoBbb02.card.jpg"]]
    assert got["deleted"] == ["7d6c1a2e-0000-4000-8000-00000000ada0"]
