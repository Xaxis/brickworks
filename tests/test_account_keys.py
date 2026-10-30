"""The app's keys on the account (api/account.js ?op=keys, APP_UX A11): a
person's preset and the keys they set, kept so a new browser has them once
they sign in (src/account/keymap_sync.gd, supabase/keymap.sql).

The handler runs here under node, signed in through the stand-in Supabase
of tests/fixtures/billing/world.mjs, with profiles.keys stood in for here:

- before keymap.sql (PostgREST 400 for the column): GET says nothing kept
  and not ready, POST says not kept, never an error;
- after it: what POST keeps GET answers, and a second POST replaces it;
- the ten favourite colours on keys (keys3) are kept with them, and an app
  from before them sends none and is kept as ever;
- what is not keys is refused with words and keeps nothing: another preset,
  a name no command has, a key that is not a whole number, no time, too
  many keys, favourite colours that are not ten colour codes;
- nobody signed in is refused.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
ADA = {"sub": "7d6c1a2e-0000-4000-8000-00000000ada0", "email": "ada@example.com"}
STUDIO = {"preset": "studio", "own": {"mode_paint": 33554498, "fit_model": 268435504}, "at": 1793350000.5}


def run(body: str, column: bool) -> dict:
    """[body] (an async function's body that returns something JSON) run in a
    fresh node process: `ask(method, sent, signedIn)` one request to
    ?op=keys, and `rows` profiles as the stand-in keeps them."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "import { world, askAccount, SUPABASE_URL } from './tests/fixtures/billing/world.mjs';"
        "const w = await world({});"
        f"const column = {json.dumps(column)};"
        "const rows = new Map();"
        "const theirs = globalThis.fetch;"
        "globalThis.fetch = async (input, init = {}) => {"
        "  const url = new URL(String(input));"
        "  if (url.origin !== SUPABASE_URL || url.pathname !== '/rest/v1/profiles') return theirs(input, init);"
        "  const reply = (status, body) => new Response(JSON.stringify(body), { status });"
        "  if (!column) return reply(400, { message: 'column profiles.keys does not exist' });"
        "  const id = /^eq\\.(.+)$/.exec(url.searchParams.get('id') || '')?.[1];"
        "  const method = (init.method || 'GET').toUpperCase();"
        "  if (method === 'GET') return reply(200, rows.has(id) ? [{ keys: rows.get(id) }] : []);"
        "  const sent = JSON.parse(init.body);"
        "  if (method === 'PATCH') {"
        "    if (!rows.has(id)) return reply(200, []);"
        "    rows.set(id, sent.keys); return reply(200, [{ id }]);"
        "  }"
        "  rows.set(sent.id, sent.keys); return new Response('', { status: 201 });"
        "};"
        f"const ADA = {json.dumps(ADA)};"
        "const ask = async (method, sent, signedIn = true) => askAccount({ method, query: { op: 'keys' },"
        "  headers: signedIn ? { authorization: `Bearer ${await w.signIn(ADA)}` } : {}, body: sent });"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_before_keymap_sql_nothing_is_kept_and_nothing_fails() -> None:
    out = run("return [await ask('GET'), await ask('POST', " + json.dumps(STUDIO) + ")];", column=False)
    assert out[0] == {"status": 200, "json": {"keys": None, "ready": False}}
    assert out[1] == {"status": 200, "json": {"keys": STUDIO, "kept": False}}


def test_what_is_kept_is_what_is_read_back() -> None:
    later = {**STUDIO, "preset": "ldcad", "own": {}, "at": STUDIO["at"] + 60}
    out = run(
        "const first = [await ask('GET'), await ask('POST', " + json.dumps(STUDIO) + "), await ask('GET')];"
        "const again = [await ask('POST', " + json.dumps(later) + "), await ask('GET')];"
        "return [...first, ...again, rows.size];",
        column=True)
    assert out[0] == {"status": 200, "json": {"keys": None, "ready": True}}
    assert out[1] == {"status": 200, "json": {"keys": STUDIO, "kept": True}}
    assert out[2] == {"status": 200, "json": {"keys": STUDIO, "ready": True}}
    assert out[3] == {"status": 200, "json": {"keys": later, "kept": True}}
    assert out[4] == {"status": 200, "json": {"keys": later, "ready": True}}
    assert out[5] == 1


def test_the_favourite_colours_are_kept_with_the_keys() -> None:
    sent = {**STUDIO, "colours": [0, 71, 15, 72, 4, 14, 1, 19, 70, 378]}
    out = run("return [await ask('POST', " + json.dumps(sent) + "), await ask('GET')];", column=True)
    assert out[0] == {"status": 200, "json": {"keys": sent, "kept": True}}
    assert out[1] == {"status": 200, "json": {"keys": sent, "ready": True}}


@pytest.mark.parametrize("sent", [
    {**STUDIO, "colours": [0, 71, 15]},
    {**STUDIO, "colours": [0, 71, 15, 72, 4, 14, 1, 19, 70, -2]},
    {**STUDIO, "colours": [0, 71, 15, 72, 4, 14, 1, 19, 70, 1.5]},
    {**STUDIO, "colours": "red"},
    {**STUDIO, "preset": "vim"},
    {**STUDIO, "own": {"Not A Name": 66}},
    {**STUDIO, "own": {"mode_paint": 1.5}},
    {**STUDIO, "own": {"mode_paint": -1}},
    {**STUDIO, "own": ["mode_paint"]},
    {"preset": "studio", "own": {}},
    {**STUDIO, "own": {f"a{n}": n for n in range(401)}},
])
def test_what_is_not_keys_is_refused_and_keeps_nothing(sent: dict) -> None:
    out = run("return [await ask('POST', " + json.dumps(sent) + "), rows.size];", column=True)
    assert out[0]["status"] == 422 and out[0]["json"]["error"]
    assert out[1] == 0


def test_nobody_signed_in_is_refused() -> None:
    out = run("return [await ask('GET', undefined, false), await ask('POST', "
              + json.dumps(STUDIO) + ", false), rows.size];", column=True)
    assert out[0]["status"] == 401 and out[1]["status"] == 401
    assert out[2] == 0
