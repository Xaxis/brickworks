"""When an address locked out of codes may ask again (api/otp.js freeAt,
sifix 2026-11-15): the limit (four codes an address, twenty from a machine,
in any fifteen minutes) is kept, and its refusal says when it lifts, for the
site and the app to put in the person's own time ("Try again after 14:32")
rather than "a few minutes".

The handler runs here under node with Supabase stood in: may_ask_for_code
refuses, and otp_requests holds the requests the limit counted.

- An address at its four: retry_at is its fourth newest request plus
  fifteen minutes, and the words are the ones a client from before reads.
- A machine at its twenty, later than the address's: the machine's.
- The requests cannot be read: no retry_at, the words alone.
- Allowed to ask (and the rest stood in to fail after), no retry_at.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


def ask(email_rows: list[int], ip_rows: list[int], *, may: bool = False, readable: bool = True) -> dict:
    """One POST /api/otp for ada@example.com from 203.0.113.9: the limit's
    answer [may], and the requests counted, each minutes ago."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "process.env.SUPABASE_URL = 'https://stand-in.supabase.test';"
        "process.env.SUPABASE_SECRET_KEY = 'secret';"
        "process.env.RESEND_API_KEY = 'resend';"
        "const { default: handler } = await import('./api/otp.js');"
        "const now = Date.now();"
        f"const rows = {{ email: {json.dumps(email_rows)}, ip: {json.dumps(ip_rows)} }};"
        f"const may = {json.dumps(may)}, readable = {json.dumps(readable)};"
        "const asked = [];"
        "globalThis.fetch = async (input, init = {}) => {"
        "  const url = new URL(String(input));"
        "  asked.push(url.pathname);"
        "  const reply = (status, body) => new Response(JSON.stringify(body), { status });"
        "  if (url.pathname === '/rest/v1/rpc/may_ask_for_code') return reply(200, may);"
        "  if (url.pathname === '/rest/v1/otp_requests') {"
        "    if (!readable) return reply(500, { message: 'down' });"
        "    const by = url.searchParams.has('email') ? 'email' : 'ip';"
        "    const limit = Number(url.searchParams.get('limit'));"
        "    const since = Date.parse(url.searchParams.get('asked_at').replace(/^gte\\./, ''));"
        "    const list = rows[by].map((m) => now - m * 60000).filter((at) => at >= since).sort((a, b) => b - a).slice(0, limit);"
        "    return reply(200, list.map((at) => ({ asked_at: new Date(at).toISOString().replace('Z', '+00:00') })));"
        "  }"
        "  return reply(503, {});"
        "};"
        "let status = 0; let body = null;"
        "const response = { setHeader() { return response; }, status(s) { status = s; return response; },"
        "  json(b) { body = b; return response; }, end() { return response; } };"
        "await handler({ method: 'POST', query: {}, headers: { 'x-forwarded-for': '203.0.113.9' }, body: { email: 'ada@example.com' } }, response);"
        "const at = body && body.retry_at ? Math.round((Date.parse(body.retry_at) - now) / 60000) : null;"
        "console.log(JSON.stringify({ status, error: body && body.error, minutes: at, asked }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, stdin=subprocess.DEVNULL)
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout.strip().splitlines()[-1])


WORDS = "Too many codes asked for. Wait a few minutes and try again."


def test_an_address_at_its_four_is_told_when_its_oldest_leaves_the_window() -> None:
    said = ask([1, 3, 6, 11, 14], [1, 3, 6, 11])
    assert said["status"] == 429
    assert said["error"] == WORDS
    # The fourth newest was 11 minutes ago: free in 4.
    assert said["minutes"] == 4


def test_a_machine_at_its_twenty_later_than_the_address_is_the_one_said() -> None:
    said = ask([2, 5, 8, 13], [0.5 * n for n in range(20)])
    # The address frees in 2; the machine's twentieth newest, 9.5 minutes
    # ago, in 5.5 (said to the minute).
    assert said["status"] == 429
    assert said["minutes"] in (5, 6)


def test_requests_that_cannot_be_read_leave_the_words_alone() -> None:
    said = ask([1, 2, 3, 4], [], readable=False)
    assert said["status"] == 429
    assert said["error"] == WORDS
    assert said["minutes"] is None


def test_an_address_allowed_to_ask_is_never_given_a_time() -> None:
    said = ask([], [], may=True)
    assert said["status"] != 429
    assert "/rest/v1/otp_requests" not in said["asked"]
