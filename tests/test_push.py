"""Push (api/_push.js, supabase/push.sql; homescreen, 2026-11-22): this
device's notifications, sent as Web Push.

Run under node, behind tests/fixtures/push_world.mjs: the API's handler as
Vercel calls it, Supabase's functions of push.sql in memory, and the push
services answering here, each message opened again with the device's own
key as a browser opens it:

- the message is RFC 8291's: the RFC's own example (Appendix A) comes out
  byte for byte up to its tag, and every message opens with the device's key;
- the request is signed for the push service's origin (VAPID, RFC 8292), and
  the signature verifies with the public key the page is given;
- a device is only ever a browser's push service: any other address, a
  port, plain http, or keys that are not a device's are refused, and nothing
  is kept;
- turned on, the account keeps the device, with the address and language
  it was turned on in; turned off, it is gone; signed out, refused;
- without the key (VAPID_PRIVATE_KEY) or before push.sql, it says it is not
  open, and keeps nothing;
- what is due goes to each device of the person, said in its language, a
  model's newest in place of the one before; a device the service says is
  gone (410) is deleted at once, and only rows newer than its turning on go;
- (hsfix, the review's findings) a block list that cannot be read sends
  nothing and puts it all back; a service's 5xx or 429 puts back what it
  did not take; several rows about one model are one push that says how
  many; the knock says nothing (204); only brickworks.diy takes what is due,
  anywhere else only a check's own account signed in as it; a browser
  signing out forgets its device by its secret alone; every device off at
  once; a device is kept with the sign-in it was turned on in.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
ADA = {"sub": "7d6c1a2e-0000-4000-8000-00000000ada0", "email": "ada@example.com",
       "session_id": "5e55e55e-0000-4000-8000-00000000ada0"}
TESTER = {"sub": "7d6c1a2e-0000-4000-8000-0000000000c1", "email": "delivered+bw-c1@resend.dev",
          "session_id": "5e55e55e-0000-4000-8000-0000000000c1"}
FCM = "https://fcm.googleapis.com/fcm/send/ada-phone"
MOZ = "https://updates.push.services.mozilla.com/wpush/v2/ada-laptop"


def run(body: str, *, vapid: bool = True, sql: bool = True) -> object:
    """[body], an async function's body returning JSON, run in a fresh node."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "import { pushWorld, makeDevice, decrypt, keysFor } from './tests/fixtures/push_world.mjs';"
        "import * as push from './api/_push.js';"
        "import { createVerify, createPublicKey, verify } from 'node:crypto';"
        f"const p = await pushWorld({{ vapid: {json.dumps(vapid)}, sqlApplied: {json.dumps(sql)} }});"
        f"const ADA = {json.dumps(ADA)}; const TESTER = {json.dumps(TESTER)};"
        "const ada = await p.signIn(ADA);"
        f"const phone = makeDevice({json.dumps(FCM)});"
        f"const laptop = makeDevice({json.dumps(MOZ)});"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_the_rfc_example_comes_out_as_the_rfc_has_it() -> None:
    # RFC 8291 Appendix A: its keys, salt and words. The record up to the
    # tag is the RFC's; the whole opens with the device's private key.
    out = run(
        "const u = (s) => Buffer.from(s, 'base64url');"
        "const sealed = push.encrypt(u('V2hlbiBJIGdyb3cgdXAsIEkgd2FudCB0byBiZSBhIHdhdGVybWVsb24'), {"
        "  p256dh: 'BCVxsr7N_eNgVRqvHtD0zTZsEc6-VV-JvLexhqUzORcxaOzi6-AYWXvTBHm4bjyPjs7Vd8pZGH6SRpkNtoIAiw4',"
        "  auth: 'BTBZMqHH6r4Tts7J_aSIgg' }, { salt: u('DGv6ra1nlYgDCS1FRnbzlw'),"
        "  serverKey: u('yfWPiYE-n46HLnH0KqZOF1fJJU3MYrct3AELtAQ-oRw') });"
        "const { createECDH } = await import('node:crypto');"
        "const ecdh = createECDH('prime256v1'); ecdh.setPrivateKey(u('q1dXpw3UpT5VOmu_cf_v6ih07Aems3njxI-JWgLcM94'));"
        "const opened = decrypt(sealed, { ecdh, auth: u('BTBZMqHH6r4Tts7J_aSIgg') });"
        "return { text: sealed.toString('base64url'), opened };")
    assert out["text"].startswith(
        "DGv6ra1nlYgDCS1FRnbzlwAAEABBBP4z9KsN6nGRTbVYI_c7VJSPQTBtkgcy27mlmlMoZIIgDll6e3vCYLocInmYWAmS6TlzAC8wEqKK6PBru3jl7A_"
        "yl95bQpu6cVPTpK4Mqgkf1CXztLVBSt2Ks3oZwbuwXPXLWyouBWLVWGNWQexSgSxsj_Q")
    assert out["opened"] == "When I grow up, I want to be a watermelon"


def test_a_push_is_signed_for_its_service_with_the_key_the_page_is_given() -> None:
    out = run(
        "const key = push.vapid();"
        f"const header = push.vapidHeader({json.dumps(FCM)}, key);"
        "const [, t, k] = /^vapid t=([^,]+), k=(.+)$/.exec(header);"
        "const [h, c, s] = t.split('.');"
        "const point = Buffer.from(k, 'base64url');"
        "const pub = createPublicKey({ format: 'jwk', key: { kty: 'EC', crv: 'P-256',"
        "  x: point.subarray(1, 33).toString('base64url'), y: point.subarray(33).toString('base64url') } });"
        "const good = verify('sha256', Buffer.from(`${h}.${c}`), { key: pub, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'));"
        "const said = await p.people('GET', { op: 'push' });"
        "return { good, claims: JSON.parse(Buffer.from(c, 'base64url')), given: said.json.key === k, ready: said.json.ready };")
    assert out["good"] is True and out["given"] is True and out["ready"] is True
    assert out["claims"]["aud"] == "https://fcm.googleapis.com"
    assert out["claims"]["sub"] == "https://brickworks.diy"


@pytest.mark.parametrize("endpoint", [
    "https://evil.example/fcm/send/x", "http://fcm.googleapis.com/fcm/send/x", "https://fcm.googleapis.com:8443/x",
    "https://169.254.169.254/latest", "https://fcm.googleapis.com.evil.example/x", "not a url",
    "https://user:pw@fcm.googleapis.com/x",
])
def test_a_device_is_only_ever_a_browsers_push_service(endpoint: str) -> None:
    out = run(
        f"const sent = {{ on: true, ...phone.json, endpoint: {json.dumps(endpoint)} }};"
        "const said = await p.people('POST', { op: 'push' }, sent, ada);"
        "return { said, kept: p.devices.size };")
    assert out["said"]["status"] == 400 and out["said"]["json"]["error"]
    assert out["kept"] == 0


@pytest.mark.parametrize("change", [{"p256dh": "AAAA"}, {"auth": "short"}, {"p256dh": None}, {"auth": "!!!!"}])
def test_keys_that_are_not_a_devices_are_refused(change: dict) -> None:
    out = run(
        f"const sent = {{ on: true, ...phone.json, ...{json.dumps(change)} }};"
        "const said = await p.people('POST', { op: 'push' }, sent, ada);"
        "return { said, kept: p.devices.size };")
    assert out["said"]["status"] == 400 and out["kept"] == 0


def test_on_and_off_for_the_account_signed_in() -> None:
    out = run(
        "const asked = (d) => p.people('GET', { op: 'push', endpoint: d.json.endpoint }, undefined, ada);"
        "const before = await asked(phone);"
        "const on = await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'de' }, ada);"
        "const kept = p.devices.get(phone.json.endpoint);"
        "const after = await asked(phone);"
        "const other = await asked(laptop);"
        "const off = await p.people('POST', { op: 'push' }, { on: false, endpoint: phone.json.endpoint }, ada);"
        "const gone = await asked(phone);"
        "const nobody = await p.people('POST', { op: 'push' }, { on: true, ...phone.json });"
        "return { before: before.json.on, on, kept, after: after.json.on, other: other.json.on, off, gone: gone.json.on,"
        "  nobody: nobody.status, left: p.devices.size };")
    assert out["before"] is False
    assert out["on"] == {"status": 200, "json": {"on": True, "devices": 1}}
    assert out["kept"]["account"] == ADA["sub"] and out["kept"]["lang"] == "de"
    assert out["kept"]["origin"] == "https://brickworks.diy"
    assert out["after"] is True and out["other"] is False
    assert out["off"] == {"status": 200, "json": {"on": False, "devices": 0}}
    assert out["gone"] is False
    assert out["nobody"] == 401 and out["left"] == 0


@pytest.mark.parametrize("vapid,sql", [(False, True), (True, False)])
def test_not_open_without_the_key_or_the_file(vapid: bool, sql: bool) -> None:
    out = run(
        "const state = await p.people('GET', { op: 'push', endpoint: phone.json.endpoint }, undefined, ada);"
        "const on = await p.people('POST', { op: 'push' }, { on: true, ...phone.json }, ada);"
        "const knock = await p.people('POST', { op: 'push_send' });"
        "return { state: state.json, on, knock, kept: p.devices.size, sent: p.sent.length };", vapid=vapid, sql=sql)
    assert out["state"]["ready"] is False
    assert out["on"]["status"] == 503 and "not open" in out["on"]["json"]["error"]
    assert out["knock"]["status"] == 204 and out["kept"] == 0 and out["sent"] == 0


def test_what_is_due_goes_to_each_device_in_its_language_and_a_gone_one_is_deleted() -> None:
    comment = {"kind": "comment", "on": "AbCdEfGhIj", "model": "AbCdEfGhIj", "name": "Red castle", "comment": 41,
               "said": "Love the towers", "version": 1, "step": None, "by": {"handle": "bob", "name": "Bob"}}
    photo = {"kind": "photo", "on": "AbCdEfGhIj", "model": "AbCdEfGhIj", "name": "Red castle", "photo": "PhOtO12345",
             "words": "Built it!", "yours": True, "by": {"handle": "cy", "name": "Cy"}}
    like = {"kind": "likes", "on": "AbCdEfGhIj", "model": "AbCdEfGhIj", "name": "Red castle", "likes": 3, "day": "2026-11-22"}
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'de' }, ada);"
        "await p.people('POST', { op: 'push' }, { on: true, ...laptop.json, lang: 'en' }, ada);"
        f"p.answers.set({json.dumps(MOZ)}, 410);"
        "const now = new Date().toISOString();"
        "const old = new Date(Date.now() - 3600e3).toISOString();"
        f"p.due.push({{ account: ADA.sub, rows: [{{ ...{json.dumps(comment)}, at: now }}, {{ ...{json.dumps(photo)}, at: now }},"
        f"  {{ ...{json.dumps(like)}, at: now }}, {{ ...{json.dumps(comment)}, comment: 7, at: old }}] }});"
        "const knock = await p.people('POST', { op: 'push_send' });"
        "const opened = p.sent.map((one) => ({ endpoint: one.endpoint, headers: one.headers,"
        "  said: JSON.parse(decrypt(one.body, one.endpoint === phone.json.endpoint ? phone : laptop)) }));"
        "return { knock, opened, left: [...p.devices.keys()] };")
    # The knock says nothing of what it sent, or to whom.
    assert out["knock"] == {"status": 204, "json": None}
    phone = [one for one in out["opened"] if one["endpoint"] == FCM]
    laptop = [one for one in out["opened"] if one["endpoint"] == MOZ]
    # The comment, the photo and the like, one model's three rows: one push,
    # the newest's words and how many more; not the hour-old comment. Which
    # kinds come at all is push_collect's (supabase/notification_prefs.sql:
    # those the account chose), so a like handed over is pushed.
    assert len(phone) == 1
    said = phone[0]["said"]
    assert said["title"] == "Red castle"
    assert ("Love the towers" in said["body"] and "Bob" in said["body"]) or ("Built it!" in said["body"] and "Cy" in said["body"])
    # In German: the page's own sentences, not the English.
    assert not said["body"].startswith(("Bob commented", "Cy posted")), said
    assert said["body"].endswith("2 weitere auf seiner Seite"), said
    assert said["tag"] == "model-AbCdEfGhIj"
    assert said["url"].startswith("https://brickworks.diy/m/AbCdEfGhIj#")
    headers = phone[0]["headers"]
    assert headers["content-encoding"] == "aes128gcm" and headers["ttl"] == "86400"
    assert headers["authorization"].startswith("vapid t=")
    # The laptop's service said it is gone: one try, then deleted.
    assert len(laptop) == 1
    assert out["left"] == [FCM]


def test_a_device_hears_only_what_came_after_it_was_turned_on() -> None:
    row = {"kind": "comment", "on": "AbCdEfGhIj", "model": "AbCdEfGhIj", "name": "Red castle", "comment": 41,
           "said": "Hello", "by": {"handle": "bob", "name": "Bob"}}
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json }, ada);"
        "const made = Date.parse(p.devices.get(phone.json.endpoint).made_at);"
        f"p.due.push({{ account: ADA.sub, rows: [{{ ...{json.dumps(row)}, at: new Date(made - 1000).toISOString() }}] }});"
        "await p.people('POST', { op: 'push_send' });"
        "return p.sent.length;")
    assert out == 0


ROW = {"kind": "comment", "on": "AbCdEfGhIj", "model": "AbCdEfGhIj", "name": "Red castle", "comment": 41,
       "said": "Love the towers", "version": 1, "step": None, "by": {"handle": "bob", "name": "Bob"}}
TROLL = {**ROW, "comment": 42, "said": "words from someone Ada blocked", "by": {"handle": "troll", "name": "Troll"}}


def blocks(answer: int) -> str:
    """block.sql's block_list answering [answer]: Ada blocked troll, or a fault."""
    return (
        "const inner = globalThis.fetch;"
        "globalThis.fetch = async (input, init = {}) => {"
        "  const path = new URL(String(input)).pathname;"
        f"  if (path.endsWith('/rpc/block_list')) return {answer} === 200"
        "    ? new Response(JSON.stringify([{ handle: 'troll', name: 'Troll', at: new Date().toISOString() }]), { status: 200 })"
        f"    : new Response('{{}}', {{ status: {answer} }});"
        "  if (path.endsWith('/rpc/block_models')) return new Response('[]', { status: 200 });"
        "  return inner(input, init);"
        "};")


@pytest.mark.parametrize("answer", [200, 503])
def test_a_block_list_not_read_sends_nothing_and_puts_it_all_back(answer: int) -> None:
    # F1: the page fails closed when it cannot read whom she blocked; so does a push.
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'en' }, ada);"
        + blocks(answer) +
        "const now = new Date().toISOString();"
        f"p.due.push({{ account: ADA.sub, rows: [{{ ...{json.dumps(TROLL)}, at: now }}, {{ ...{json.dumps(ROW)}, model: 'ZyXwVuTsRq',"
        "  on: 'ZyXwVuTsRq', at: now }] });"
        "await p.people('POST', { op: 'push_send' });"
        "return { shown: p.sent.map((one) => JSON.parse(decrypt(one.body, phone)).body), again: p.again };")
    if answer == 200:
        assert out["shown"] == ["Bob commented\nLove the towers"] and out["again"] == []
    else:
        assert out["shown"] == []
        assert len(out["again"]) == 1 and out["again"][0]["tries"] == 0
        assert sorted(key.split("@")[0] for key in out["again"][0]["keys"] if not key.startswith("last:")) == [
            "comment:41:ZyXwVuTsRq", "comment:42:AbCdEfGhIj"]


@pytest.mark.parametrize("status,again", [(500, True), (429, True), (503, True), (400, False), (201, False)])
def test_a_service_that_cannot_take_it_now_has_it_put_back(status: int, again: bool) -> None:
    # N2: a 5xx or 429 is not "sent"; what that device did not take is due again.
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'en' }, ada);"
        "await p.people('POST', { op: 'push' }, { on: true, ...laptop.json, lang: 'en' }, ada);"
        f"p.answers.set(phone.json.endpoint, {status});"
        f"p.due.push({{ account: ADA.sub, tries: 1, rows: [{{ ...{json.dumps(ROW)}, at: new Date().toISOString() }}] }});"
        "await p.people('POST', { op: 'push_send' });"
        "return { to: p.sent.map((one) => one.endpoint), again: p.again, left: p.devices.size,"
        "  keys: keysFor({ ...p.due[0], kind: 'comment', comment: 41, model: 'AbCdEfGhIj', on: 'AbCdEfGhIj' }, phone.json.endpoint) };")
    assert sorted(out["to"]) == sorted([FCM, MOZ])
    if again:
        assert len(out["again"]) == 1
        assert out["again"][0]["tries"] == 1
        # Only the phone's: the laptop had it.
        assert sorted(out["again"][0]["keys"]) == sorted([out["keys"]["key"], out["keys"]["last"]])
    else:
        assert out["again"] == []
    assert out["left"] == 2


def test_a_models_rows_are_one_push_that_says_how_many() -> None:
    # N11: a pile-on is one push a model (the database holds the next for three minutes).
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'en' }, ada);"
        "const at = (s) => new Date(Date.now() - s * 1000).toISOString();"
        f"const row = {json.dumps(ROW)};"
        "p.due.push({ account: ADA.sub, rows: [{ ...row, comment: 1, said: 'first', at: at(30) },"
        "  { ...row, comment: 2, said: 'second', at: at(20) }, { ...row, comment: 3, said: 'third', at: at(10) },"
        "  { ...row, comment: 4, model: 'ZyXwVuTsRq', on: 'ZyXwVuTsRq', name: 'Blue boat', said: 'other', at: at(5) }] });"
        "await p.people('POST', { op: 'push_send' });"
        "return p.sent.map((one) => JSON.parse(decrypt(one.body, phone)));")
    assert len(out) == 2
    by_title = {one["title"]: one for one in out}
    assert by_title["Red castle"]["body"] == "Bob commented\nthird\n2 more on its page"
    assert by_title["Blue boat"]["body"] == "Bob commented\nother"


@pytest.mark.parametrize("host", ["brickworks-abc123-xaxis.vercel.app", "127.0.0.1:11005", "evil.example"])
def test_only_brickworks_diy_takes_whats_due_anywhere_else_only_a_checks_own(host: str) -> None:
    # S1: a preview (or a local server) never takes a real person's due row.
    out = run(
        "const tester = await p.signIn(TESTER);"
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json, lang: 'en' }, ada);"
        "await p.people('POST', { op: 'push' }, { on: true, ...laptop.json, lang: 'en' }, tester);"
        "const now = new Date().toISOString();"
        f"const row = {{ ...{json.dumps(ROW)}, at: now }};"
        "p.due.push({ account: ADA.sub, rows: [row] }, { account: TESTER.sub, rows: [row] });"
        f"const host = {json.dumps(host)};"
        "const nobody = await p.people('POST', { op: 'push_send' }, undefined, null, { host });"
        "const asAda = await p.people('POST', { op: 'push_send' }, undefined, ada, { host });"
        "const before = p.rpcs.filter((one) => /^push_take/.test(one.name)).map((one) => one.name);"
        "const asTester = await p.people('POST', { op: 'push_send' }, undefined, tester, { host });"
        "const takes = p.rpcs.filter((one) => /^push_take/.test(one.name)).map((one) => [one.name, one.body]);"
        "const sentTo = p.sent.map((one) => one.endpoint);"
        "const live = await p.people('POST', { op: 'push_send' }, undefined, null, { host: 'brickworks.diy' });"
        "return { codes: [nobody.status, asAda.status, asTester.status], before, takes, sentTo,"
        "  afterLive: p.sent.map((one) => one.endpoint), due: p.due.length };")
    assert out["codes"] == [204, 204, 204]
    assert out["before"] == []
    assert out["takes"] == [["push_take_tester", {"p_account": TESTER["sub"]}]]
    assert out["sentTo"] == [MOZ]
    # brickworks.diy's own knock takes the rest.
    assert out["afterLive"] == [MOZ, FCM] and out["due"] == 0


def test_signing_out_forgets_the_device_by_its_secret_alone() -> None:
    # F2: web/account.js signOut says the device's endpoint and secret, with no sign-in.
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json }, ada);"
        "const wrong = await p.people('POST', { op: 'push' }, { on: false, endpoint: phone.json.endpoint,"
        "  auth: 'AAAAAAAAAAAAAAAAAAAAAA' });"
        "const after_wrong = p.devices.size;"
        "const right = await p.people('POST', { op: 'push' }, { on: false, endpoint: phone.json.endpoint, auth: phone.json.auth });"
        "return { wrong: wrong.status, after_wrong, right: right.status, left: p.devices.size };")
    assert out == {"wrong": 204, "after_wrong": 1, "right": 204, "left": 0}


def test_every_device_off_at_once_and_a_device_kept_with_its_sign_in() -> None:
    # S2: "Turn off on every device"; and each device tied to the session it was turned on in.
    out = run(
        "await p.people('POST', { op: 'push' }, { on: true, ...phone.json }, ada);"
        "await p.people('POST', { op: 'push' }, { on: true, ...laptop.json }, ada);"
        "const session = p.rpcs.find((one) => one.name === 'push_subscribe').body.p_session;"
        "const state = await p.people('GET', { op: 'push', endpoint: phone.json.endpoint }, undefined, ada);"
        "const nobody = await p.people('POST', { op: 'push' }, { on: false, all: true });"
        "const all = await p.people('POST', { op: 'push' }, { on: false, all: true }, ada);"
        "p.endedSessions.add(ADA.session_id);"
        "const ended = await p.people('POST', { op: 'push' }, { on: true, ...phone.json }, ada);"
        "return { session, devices: state.json.devices, nobody: nobody.status, all, left: p.devices.size, ended: ended.status };")
    assert out["session"] == ADA["session_id"]
    assert out["devices"] == 2 and out["nobody"] == 401
    assert out["all"] == {"status": 200, "json": {"on": False, "devices": 0, "gone": 2}}
    assert out["left"] == 0 and out["ended"] == 401
