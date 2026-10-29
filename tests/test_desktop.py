"""The paid desktop, built dark (docs/PLANS.md, units U5 and U6).

api/_desktop.js and its two ops of api/plans.js run here under node against
the stand-in Admission, Supabase and GitHub of tests/fixtures/billing/, every
request recorded:

- downloads: billing off answers the address a file has always had and asks
  nobody; on, a Free account is refused in the plan's words, a Pro one (or
  one whose plan cannot be known just now) is sent to GitHub's signed URL,
  and a GitHub that streams instead of redirecting is an error, never a
  stream through Vercel;
- the token: signed RS256 by the key in DESKTOP_TOKEN_KEY, verified by its
  public half and by no other key, refused when changed; never signed on an
  entitlement that is not known; paid_through as the plan says, kept so it
  only moves on, and never before DESKTOP_FREE_THROUGH;
- supabase/desktop_paid_through.sql only adds, and only the server reads it.

The app's own rules on a token (a build released by paid_through runs, 44
days of grace) are proven where they run: src/dev/desktop_pass_probe.gd,
against tokens this code signs.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/desktop_paid_through.sql").read_text()
APPIMAGE = "Brickworks-0.10.0-linux-x86_64.AppImage"
PUBLIC = f"https://github.com/Xaxis/brickworks-releases/releases/download/v0.10.0/{APPIMAGE}"
SIGNED = "https://release-assets.githubusercontent.com/asset-11?se=soon&sig=signed"
PRO_WORDS = "The desktop app comes with Pro. The web app is free, in any browser."

PRELUDE = """
import { generateKeyPairSync } from 'node:crypto';
const pair = generateKeyPairSync('rsa', { modulusLength: 2048 });
const other = generateKeyPairSync('rsa', { modulusLength: 2048 });
process.env.DESKTOP_TOKEN_KEY = pair.privateKey.export({ type: 'pkcs8', format: 'pem' });
const desktop = await import('./api/_desktop.js');
const as = async (sub) => ({ authorization: `Bearer ${await w.signIn({ sub, email: sub + '@example.com' })}` });
const download = async (sub, extra = {}) => askPlans({ query: { op: 'download', file: extra.file ?? APPIMAGE },
  headers: { ...(sub ? await as(sub) : {}), ...(extra.headers || {}) } });
const entitle = async (sub) => askPlans({ query: { op: 'entitlement' }, headers: sub ? await as(sub) : {} });
const claims = (r) => r.json?.token ? desktop.verify(r.json.token, pair.publicKey) : null;
"""


def run(body: str, billing: str = "test", env: dict | None = None) -> dict | None:
    """[body] run in a fresh node process with the stand-in world, billing
    [billing] ("" for off) and [env] set first."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { world, askPlans } from './tests/fixtures/billing/world.mjs';"
        f"const APPIMAGE = {json.dumps(APPIMAGE)};"
        f"Object.assign(process.env, {json.dumps(env or {})});"
        f"const w = await world({json.dumps({'billing': billing})});"
        + PRELUDE +
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def day(offset: int = 0) -> str:
    return (datetime.now(timezone.utc) + timedelta(days=offset)).strftime("%Y-%m-%d")


# --- Downloads ---------------------------------------------------------------

def test_off_a_download_is_the_address_it_always_had_and_nobody_is_asked() -> None:
    got = run("""
const gated = await askPlans({ query: { op: 'download' } });
const file = await download(null);
const signedIn = await download('u-free');
const asJson = await download(null, { headers: { accept: 'application/json' } });
const token = await entitle('u-free');
return { gated, file, signedIn, asJson, token, calls: w.calls.filter((c) => !c.includes('jwks')) };
""", billing="")
    if got is None:
        return
    assert got["gated"] == {"status": 200, "json": {"gated": False}}
    assert got["file"] == {"status": 302, "json": None, "location": PUBLIC}
    assert got["signedIn"] == got["file"]
    assert got["asJson"] == {"status": 200, "json": {"url": PUBLIC}}
    # The app's ask at start: billing off, and nothing granted or kept.
    assert got["token"] == {"status": 200, "json": {"billing": "off"}}
    assert got["calls"] == [], got["calls"]


def test_on_free_is_refused_in_the_plans_words_and_github_is_not_asked() -> None:
    got = run("""
const gated = await askPlans({ query: { op: 'download' } });
const free = await download('u-free');
const nobody = await download(null);
return { gated, free, nobody, github: w.calls.filter((c) => c.includes('github')) };
""")
    if got is None:
        return
    assert got["gated"]["json"] == {"gated": True}
    assert got["free"] == {"status": 403, "json": {"error": PRO_WORDS, "pro": "/plans"}}
    assert got["nobody"] == {"status": 401, "json": {"error": "sign in to Brickworks first"}}
    assert got["github"] == []


def test_on_pro_and_a_comp_get_githubs_signed_url_through_the_token() -> None:
    got = run("""
w.admission.subscribe('u-pro');
w.admission.comp('u-comp', 'pro');
const pro = await download('u-pro');
const asJson = await download('u-pro', { headers: { accept: 'application/json' } });
const comp = await download('u-comp');
return { pro, asJson, comp, auth: [...new Set(w.githubAuth)] };
""", env={"RELEASES_TOKEN": "github_pat_test"})
    if got is None:
        return
    assert got["pro"] == {"status": 302, "json": None, "location": SIGNED}
    assert got["asJson"] == {"status": 200, "json": {"url": SIGNED}}
    assert got["comp"]["location"] == SIGNED
    # Every request to GitHub carries the read-only token, once it is set.
    assert got["auth"] == ["Bearer github_pat_test"]


def test_on_with_the_plan_unknown_nobody_is_refused() -> None:
    got = run("""
w.admission.down = true;
return await download('u-stranger');
""")
    if got is None:
        return
    # Admission away and nothing kept of the account: as today, a download.
    assert got == {"status": 302, "json": None, "location": SIGNED}


def test_a_github_that_streams_or_a_file_that_is_not_there_is_never_passed_through() -> None:
    got = run("""
w.admission.subscribe('u-pro');
const missing = await download('u-pro', { file: 'Brickworks-0.10.0-windows-x86_64.zip' });
const noRelease = await download('u-pro', { file: 'Brickworks-9.9.9-linux-x86_64.AppImage' });
const notAPackage = await download('u-pro', { file: '../../etc/passwd' });
const sums = await download('u-pro', { file: 'SHA256SUMS' });
w.githubStreams = true;
const streams = await download('u-pro');
return { missing, noRelease, notAPackage, sums, streams };
""")
    if got is None:
        return
    for name in ("missing", "noRelease", "notAPackage", "sums"):
        assert got[name]["status"] == 404, (name, got[name])
    # A 200 would mean streaming ~700 MB through a function: an error instead.
    assert got["streams"]["status"] == 503 and "location" not in got["streams"]


def test_the_package_names_are_the_releases() -> None:
    got = run("""
const names = ['Brickworks-0.10.0-linux-x86_64.AppImage', 'Brickworks-0.10.0-linux-x86_64.tar.xz',
  'Brickworks-0.10.0-macos-universal.zip', 'Brickworks-0.10.0-windows-x86_64.zip', 'Brickworks-0.10.0.zip',
  'SHA256SUMS', 'Brickworks-0.10.0-linux-x86_64.AppImage?x=1', 'Brickworks-0.10-linux.zip', ''];
return names.map((n) => desktop.tagOf(n));
""", billing="")
    if got is None:
        return
    assert got == ["v0.10.0"] * 4 + [None] * 5
    # Every file the download page lists today is one the route serves.
    manifest = json.loads((ROOT / "web/releases.json").read_text())
    names = [f["name"] for r in manifest["releases"] for f in r["files"]]
    assert names and all(re.fullmatch(r"Brickworks-\d+\.\d+\.\d+-[A-Za-z0-9_]+(-[A-Za-z0-9_]+)*\."
                                      r"(AppImage|tar\.xz|zip)", n) for n in names), names


# --- The token -----------------------------------------------------------------

def test_a_pro_account_gets_a_token_its_public_key_verifies_and_no_other() -> None:
    got = run("""
w.admission.subscribe('u-pro');
const r = await entitle('u-pro');
const [h, b, s] = r.json.token.split('.');
const forged = Buffer.from(JSON.stringify({ ...claims(r), paid_through: '2099-12-31' })).toString('base64url');
return { r, claims: claims(r), header: JSON.parse(Buffer.from(h, 'base64url')),
  kid: desktop.kidOf(pair.publicKey),
  otherKey: desktop.verify(r.json.token, other.publicKey),
  tampered: desktop.verify(`${h}.${forged}.${s}`, pair.publicKey),
  cut: desktop.verify(`${h}.${b}`, pair.publicKey), none: desktop.verify('', pair.publicKey),
  algNone: desktop.verify(`${Buffer.from('{"alg":"none"}').toString('base64url')}.${b}.`, pair.publicKey),
  kept: [...w.paidThrough] };
""")
    if got is None:
        return
    r, c = got["r"], got["claims"]
    assert r["status"] == 200 and r["json"]["billing"] == "test" and r["json"]["desktop"] is True
    assert got["header"] == {"alg": "RS256", "typ": "JWT", "kid": got["kid"]}
    # The period's end (the first of next month), and today at the least.
    first = (datetime.now(timezone.utc).replace(day=1) + timedelta(days=32)).replace(day=1).strftime("%Y-%m-%d")
    assert c["sub"] == "u-pro" and c["plan"] == "pro" and c["desktop"] is True and c["paid_through"] == first
    assert abs(c["iat"] - datetime.now(timezone.utc).timestamp()) < 60
    assert r["json"]["paid_through"] == first and r["json"]["plan"] == "pro"
    for refused in ("otherKey", "tampered", "cut", "none", "algNone"):
        assert got[refused] is None, refused
    assert got["kept"] == [["u-pro", first]]


def test_a_lapsed_account_keeps_its_last_paid_day_and_the_day_only_moves_on() -> None:
    got = run("""
w.paidThrough.set('u-lapsed', '2026-12-01');
const lapsed = await entitle('u-lapsed');
w.admission.comp('u-later', 'pro', '2031-05-01T00:00:00.000Z');
w.paidThrough.set('u-later', '2030-01-01');
const later = await entitle('u-later');
w.paidThrough.set('u-sooner', '2032-01-01');
w.admission.comp('u-sooner', 'pro', '2031-05-01T00:00:00.000Z');
const sooner = await entitle('u-sooner');
return { lapsed: claims(lapsed), later: claims(later), sooner: claims(sooner), kept: Object.fromEntries(w.paidThrough) };
""")
    if got is None:
        return
    # Free now, its last paid day kept: older builds stay its own.
    assert got["lapsed"]["desktop"] is False and got["lapsed"]["plan"] == "free"
    assert got["lapsed"]["paid_through"] == "2026-12-01"
    # A comp's end, kept as the largest; a larger day kept stays.
    assert got["later"]["paid_through"] == "2031-05-01" and got["kept"]["u-later"] == "2031-05-01"
    assert got["sooner"]["paid_through"] == "2032-01-01" and got["kept"]["u-sooner"] == "2032-01-01"


def test_no_end_free_and_the_free_through_floor() -> None:
    got = run("""
w.admission.comp('u-comp', 'pro');
const comp = await entitle('u-comp');
const free = await entitle('u-free');
process.env.DESKTOP_FREE_THROUGH = '2026-11-20';
const floored = await entitle('u-free2');
return { comp: claims(comp), free: claims(free), floored: claims(floored), kept: Object.fromEntries(w.paidThrough) };
""")
    if got is None:
        return
    # A comp with no end has no end; kept as today, for after it ends.
    assert got["comp"]["desktop"] is True and got["comp"]["paid_through"] is None
    assert got["kept"]["u-comp"] == day()
    # Never had it: nothing to run a build on, and nothing kept.
    assert got["free"]["desktop"] is False and got["free"]["paid_through"] is None
    assert "u-free" not in got["kept"]
    # Every build released while billing was off stays everyone's.
    assert got["floored"]["desktop"] is False and got["floored"]["paid_through"] == "2026-11-20"


def test_never_signed_while_the_plan_is_unknown_or_without_a_key() -> None:
    got = run("""
w.admission.down = true;
const unknown = await entitle('u-stranger');
w.admission.down = false;
const nobody = await entitle(null);
delete process.env.DESKTOP_TOKEN_KEY;
const unsigned = await entitle('u-free');
process.env.DESKTOP_TOKEN_KEY = 'not a key';
const wrong = await entitle('u-free');
return { unknown, nobody, unsigned, wrong, kept: [...w.paidThrough] };
""")
    if got is None:
        return
    assert got["unknown"] == {"status": 503, "json": {"billing": "test", "standing": "unknown"}}
    assert got["nobody"] == {"status": 401, "json": {"error": "sign in to Brickworks first"}}
    assert got["unsigned"] == {"status": 503, "json": {"billing": "test", "standing": "unsigned"}}
    assert got["wrong"] == got["unsigned"]
    assert got["kept"] == []


def test_paid_through_while_stripe_retries_is_today_at_least() -> None:
    got = run("""
const past = { billing: 'test', standing: 'known', desktop: true, owner: false,
  plan: { key: 'pro', source: 'subscription', until: null },
  subscription: { status: 'past_due', periodEnd: '2026-01-01T00:00:00.000Z' } };
const owner = { ...past, owner: true };
return [desktop.paidThroughOf(past), desktop.paidThroughOf(owner)];
""", billing="")
    if got is None:
        return
    assert got[0] == {"desktop": True, "paidThrough": day(), "keep": day()}
    assert got[1] == {"desktop": True, "paidThrough": None, "keep": day()}


def test_the_key_tool_never_prints_the_private_half(tmp_path: Path) -> None:
    if shutil.which("node") is None:
        return
    key = tmp_path / "desktop.pem"
    made = subprocess.run(["node", "tools/desktop_key.mjs", "new", str(key)], cwd=ROOT, capture_output=True,
                          text=True, timeout=60)
    assert made.returncode == 0, made.stderr
    secret = key.read_text()
    assert "PRIVATE KEY" in secret and (key.stat().st_mode & 0o777) == 0o600
    body = "".join(secret.splitlines()[1:-1])
    assert "PRIVATE" not in made.stdout and body[:40] not in made.stdout
    assert re.search(r'^\t"[0-9a-f]{16}": "-----BEGIN PUBLIC KEY-----\\n', made.stdout, re.M)
    again = subprocess.run(["node", "tools/desktop_key.mjs", "new", str(key)], cwd=ROOT, capture_output=True,
                           text=True, timeout=60)
    assert again.returncode != 0 and key.read_text() == secret


# --- The table -----------------------------------------------------------------

def code(text: str) -> str:
    """[text] without its SQL comments."""
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def test_the_paid_through_table_only_adds_and_only_the_server_reads_it() -> None:
    plain = code(SQL)
    lowered = plain.lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "delete from"):
        assert word not in lowered, f"desktop_paid_through.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", lowered) == ["desktop_paid_through"]
    assert "alter table public.desktop_paid_through enable row level security;" in plain
    assert "revoke all on public.desktop_paid_through from public, anon, authenticated, service_role;" in plain
    assert "create policy" not in lowered
    # The day only ever moves on.
    assert "where d.day < excluded.day" in plain
    made = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert sorted(made) == ["desktop_paid_through_get", "desktop_paid_through_put"]
    for name in made:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain)
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain)
