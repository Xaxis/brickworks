"""How many models a plan keeps with an account (savecap360, 2026-10-29).

api/models.js runs here under node against the stand-in Admission and
Supabase (tests/fixtures/billing/), through the real client: Free keeps 25
models with the account and Pro any number, AI never counted. Every request
is recorded, so "Admission was not asked" is read, not hoped:

- plans off: Admission never asked, and each save sent to the database
  exactly as before plans;
- Free: 25 new models kept, the 26th refused with the plan's words and a
  way to Pro, and not kept; a save over one it has, or the same model
  again, kept at the limit; a delete makes room at once;
- Pro, a comp of Pro and the owner keep any number;
- a plan not known (Admission down, nothing kept of the account) refuses
  nothing, and neither does a deployment without
  supabase/account_models_plan.sql;
- the SQL file only adds, and only the server may call its function.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/account_models_plan.sql").read_text()
WORDS = "Free keeps 25 models in your account. Delete one, or get Pro for unlimited."
# What save_account_model has always been sent, in this order.
SENT = ["p_owner", "p_name", "p_base", "p_model", "p_raw_bytes", "p_parts", "p_sum"]

HELPERS = """
const { gzipSync } = await import('node:zlib');
const as = async (sub, email = `${sub}@example.com`) => ({ authorization: `Bearer ${await w.signIn({ sub, email })}` });
const ldr = (name) => `0 ${name}\\n0 Name: ${name}.ldr\\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\\n`;
const save = (headers, name, base = 0, text = ldr(name)) => askModels({ method: 'POST', headers,
  body: { name, base, model: gzipSync(Buffer.from(text)).toString('base64') } });
const saveMany = async (headers, n, prefix = 'Model') => {
  const out = [];
  for (let i = 1; i <= n; i += 1) out.push(await save(headers, `${prefix} ${i}`));
  return out;
};
const kept = (sub) => [...(w.models.get(sub) || new Map()).keys()];
const admission = () => w.calls.filter((c) => c.includes('admission.test'));
"""


def run(body: str, **world) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process, the world set up as [world] says."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { world, askModels } from './tests/fixtures/billing/world.mjs';"
        f"const w = await world({json.dumps(world)});"
        + HELPERS
        + f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return {**json.loads(done.stdout.strip().splitlines()[-1]), "log": done.stderr}


def test_off_asks_admission_nothing_and_saves_as_before() -> None:
    got = run("""
const me = await as('u-free');
const saves = await saveMany(me, 30);
return { statuses: saves.map((s) => s.status), kept: kept('u-free').length, admission: admission(),
         fns: [...new Set(w.saves.map((s) => s.fn))], keys: w.saves.map((s) => Object.keys(JSON.parse(s.body))) };
""")
    if got is None:
        return
    assert got["admission"] == [], got["admission"]
    assert got["statuses"] == [200] * 30 and got["kept"] == 30
    # The database asked as it always was: the one function, the same body.
    assert got["fns"] == ["save_account_model"]
    assert all(keys == SENT for keys in got["keys"]), got["keys"][0]


def test_free_keeps_25_and_the_26th_is_refused_in_plain_words() -> None:
    got = run("""
const me = await as('u-free');
const under = await saveMany(me, 25);
const past = await save(me, 'One Too Many');
const most = [...new Set(w.saves.map((s) => JSON.parse(s.body).p_most))];
return { under: under.map((s) => s.status), past, kept: kept('u-free'), most,
         fns: [...new Set(w.saves.map((s) => s.fn))] };
""", billing="test")
    if got is None:
        return
    assert got["under"] == [200] * 25
    assert got["past"] == {"status": 413, "json": {"full": "plan", "pro": "/plans", "error": WORDS}}
    # Not kept with the account, and nothing else taken to make room.
    assert len(got["kept"]) == 25 and "One Too Many" not in got["kept"]
    assert got["most"] == [25] and got["fns"] == ["save_account_model_within"]


def test_at_the_limit_a_save_over_one_it_has_is_kept() -> None:
    got = run("""
const me = await as('u-free');
await saveMany(me, 25);
const update = await save(me, 'Model 3', 1, ldr('Model 3') + '1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\\n');
const again = await save(me, 'Model 3', 2, ldr('Model 3') + '1 1 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\\n');
const fresh = await save(me, 'Model 26');
return { update, again, fresh: fresh.status, count: kept('u-free').length };
""", billing="test")
    if got is None:
        return
    assert got["update"] == {"status": 200, "json": {"name": "Model 3", "version": 2}}
    assert got["again"]["status"] == 200 and got["again"]["json"]["same"] is True
    assert got["fresh"] == 413 and got["count"] == 25


def test_a_delete_makes_room_at_once() -> None:
    got = run("""
const me = await as('u-free');
await saveMany(me, 25);
const refused = await save(me, 'The Castle');
const deleted = await askModels({ method: 'DELETE', headers: me, query: { name: 'Model 7', version: '1' } });
const now = await save(me, 'The Castle');
const next = await save(me, 'The Barn');
return { refused: refused.status, deleted, now, next: next.status, kept: kept('u-free') };
""", billing="test")
    if got is None:
        return
    assert got["refused"] == 413
    assert got["deleted"] == {"status": 200, "json": {"name": "Model 7", "deleted": True}}
    assert got["now"] == {"status": 200, "json": {"name": "The Castle", "version": 1}}
    assert got["next"] == 413 and len(got["kept"]) == 25 and "Model 7" not in got["kept"]


def test_pro_a_comp_and_the_owner_keep_any_number() -> None:
    got = run("""
w.admission.subscribe('u-pro');
w.admission.comp('u-school', 'pro', '2027-10-29T00:00:00.000Z');
const out = {};
for (const [who, headers] of [['u-pro', await as('u-pro')], ['u-school', await as('u-school')],
                              ['u-own', await as('u-own', 'owner@example.com')]]) {
  out[who] = (await saveMany(headers, 30)).map((s) => s.status);
}
return { out, owners: [...w.admission.owners], fns: [...new Set(w.saves.map((s) => s.fn))],
         kept: ['u-pro', 'u-school', 'u-own'].map((s) => kept(s).length) };
""", billing="test")
    if got is None:
        return
    for who in ("u-pro", "u-school", "u-own"):
        assert got["out"][who] == [200] * 30, who
    assert got["kept"] == [30, 30, 30]
    # The owner (MASTER_EMAIL) is reported to Admission, which gives them everything.
    assert got["owners"] == ["u-own"]
    assert got["fns"] == ["save_account_model"]


def test_a_plan_not_known_refuses_nobody() -> None:
    got = run("""
w.admission.down = true;
const never = await saveMany(await as('u-new'), 30);
return { never: never.map((s) => s.status), fns: [...new Set(w.saves.map((s) => s.fn))] };
""", billing="test")
    if got is None:
        return
    assert got["never"] == [200] * 30 and got["fns"] == ["save_account_model"]


def test_down_free_kept_in_the_database_stays_at_its_limit() -> None:
    got = run("""
const billing = await import('./api/_billing.js');
const me = await as('u-free');
await saveMany(me, 25);
billing.forgetClient();
w.age(10 * 60_000);
w.admission.down = true;
return { past: await save(me, 'One Too Many') };
""", billing="test")
    if got is None:
        return
    assert got["past"]["status"] == 413 and got["past"]["json"]["error"] == WORDS


def test_without_the_sql_file_a_save_is_kept_and_the_log_says_why() -> None:
    got = run("""
w.noPlanSql = true;
const saves = await saveMany(await as('u-free'), 26);
return { statuses: saves.map((s) => s.status), fns: w.saves.map((s) => s.fn).slice(0, 2) };
""", billing="test")
    if got is None:
        return
    assert got["statuses"] == [200] * 26
    assert got["fns"] == ["save_account_model_within", "save_account_model"]
    assert "account_models_plan.sql is not applied here" in got["log"]


def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_sql_only_adds_and_only_the_server_calls_it() -> None:
    plain = code(SQL)
    lowered = plain.lower()
    for word in ("drop ", "truncate", "rename ", "alter ", "update public.", "delete from", "insert into"):
        assert word not in lowered, f"account_models_plan.sql says {word.strip()}"
    made = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert made == ["save_account_model_within"]
    signature = r"public\.save_account_model_within\(uuid, text, integer, text, integer, integer, text, integer\)"
    assert re.search(rf"revoke all on function {signature}\s+from public, anon, authenticated;", plain)
    assert re.search(rf"grant execute on function {signature}\s+to service_role;", plain)
    assert plain.count("security definer") == 1 and "set search_path = ''" in plain
    # Its refusal is the one api/models.js reads.
    assert "raise exception 'models: plan'" in plain
    assert "too many|too big|plan" in (ROOT / "api/models.js").read_text()
