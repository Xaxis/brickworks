"""live_smoke.sh: what it is asked, what it answers, and when it puts the domain back (fastship, 2026-11-23).

ship.sh asks `current` before it promotes a release and runs `guard` once the domain serves it: a release that
breaks the live site goes back to the build before it, and the owner's console is told. Here the vercel CLI, curl
and the check itself are stand-ins in a folder of the test's own, so nothing reaches the network, Vercel or the
database: each stand-in writes down what it was asked.
"""
import json
import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/release/live_smoke.sh"

# vercel@48 as the script asks it: inspect DOMAIN, alias set URL DOMAIN, rollback URL. What a domain points at is
# kept in points.<domain>; STUB_MOVE_FAILS refuses that many moves, STUB_STUCK accepts a move and moves nothing.
VERCEL = r"""#!/bin/bash
echo "$*" >> "$STUB/vercel.log"
case "$1" in
  inspect)
    h=${2#https://}
    d=$(cat "$STUB/points.$h" 2>/dev/null) || { echo "Error: Can't find the deployment \"$h\"" >&2; exit 1; }
    printf 'Vercel CLI 48.12.1\n> Fetched deployment "%s" in team\n\n  General\n\n    id\t\tdpl_x\n    url\t\thttps://%s\n' "$d" "$d" >&2 ;;
  alias|rollback)
    n=$(cat "$STUB/moves" 2>/dev/null || echo 0); echo $((n + 1)) > "$STUB/moves"
    if [ "$n" -lt "${STUB_MOVE_FAILS:-0}" ]; then
      # STUB_MOVED_ANYWAY: refused in words, but moved (the CLI's own wait ran out after the move).
      [ -n "${STUB_MOVED_ANYWAY:-}" ] && { [ "$1" = alias ] && echo "${3#https://}" > "$STUB/points.$4" || echo "${2#https://}" > "$STUB/points.brickworks.diy"; }
      echo "Error: a rollback or promotion is in progress (409)" >&2; exit 1
    fi
    if [ "$1" = alias ]; then to=$3 domain=$4; else to=$2 domain=brickworks.diy; fi
    [ -n "${STUB_STUCK:-}" ] || echo "${to#https://}" > "$STUB/points.$domain"
    echo "> Success! $domain now points to $to" ;;
  *) exit 1 ;;
esac
"""

# The check guard runs: passes where the build served is one of $STUB/good, fails elsewhere; STUB_FLAKE fails the
# first ask only, STUB_DOMAIN_FAILS fails every ask of a domain (a host with a points.<host>, not a deployment's own
# URL), STUB_NOVERDICT never
# gets to look.
CHECK = r"""#!/bin/bash
o=$1; h=${o#https://}
n=$(cat "$STUB/checks" 2>/dev/null || echo 0); echo $((n + 1)) > "$STUB/checks"; echo "$o" >> "$STUB/checked"
if [ -n "${STUB_NOVERDICT:-}" ]; then echo "live_smoke: not checked $o: heavy: no slot within 1 s (brickworks)"; exit 2; fi
if [ -e "$STUB/points.$h" ]; then d=$(cat "$STUB/points.$h"); else d=$h; fi
b=$(cat "$STUB/build.$d")
if [ -n "${STUB_FLAKE:-}" ] && [ "$n" = 0 ]; then echo "live_smoke: FAILED $o (build $b, 1s): a flake"; exit 1; fi
if [ -e "$STUB/points.$h" ] && [ -n "${STUB_DOMAIN_FAILS:-}" ]; then echo "live_smoke: FAILED $o (build $b, 1s): /app answers 500"; exit 1; fi
if grep -qx "$b" "$STUB/good"; then echo "  ok    the stand-in"; echo "live_smoke: passed $o (build $b, 1s): home, /m/x, /app"; exit 0; fi
echo "live_smoke: FAILED $o (build $b, 1s): the home page is not the site's"; exit 1
"""

# curl as the script and release_live.sh call it: the RPC written down in rpc.log; /app of a domain or a deployment
# names the build it serves (points.<domain>, build.<deployment>); a site in site.<host> ("good" or "broken")
# answers the check's GETs. Every ask, and whether it carried the bypass, in curl.log.
CURL = r"""#!/usr/bin/env python3
import os, sys, urllib.parse
stub = os.environ["STUB"]
args = sys.argv[1:]
out = fmt = body = None
headers = []
url = ""
i = 0
while i < len(args):
    a = args[i]
    if a in ("-o", "-w", "-d", "-H", "-X", "--max-time", "--connect-timeout"):
        v = args[i + 1]
        if a == "-o": out = v
        elif a == "-w": fmt = v
        elif a == "-d": body = v
        elif a == "-H": headers.append(v)
        i += 2
        continue
    if a.startswith("http"): url = a
    i += 1
parts = urllib.parse.urlsplit(url)
query = "&".join(p for p in parts.query.split("&") if p and not p.startswith("_smoke="))
path = parts.path + ("?" + query if query else "")
bypass = any(h.lower().startswith("x-vercel-protection-bypass:") for h in headers)
with open(os.path.join(stub, "curl.log"), "a") as log:
    log.write(f"{parts.netloc}{path} bypass={bypass}\n")
def read(name):
    try:
        return open(os.path.join(stub, name)).read().strip()
    except OSError:
        return ""
status, kind, text = 404, "text/plain", "Not found"
if path.endswith("/rest/v1/rpc/site_release_live"):
    with open(os.path.join(stub, "rpc.log"), "a") as log:
        log.write((body or "") + "\n")
    status, kind, text = 200, "application/json", "{}"
elif read("site." + parts.netloc):
    good = read("site." + parts.netloc) == "good"
    pages = {
        "/": (200, "text/html", "<html><header></header><main><h1>Home</h1></main></html>" if good else "<title>Not the site</title>"),
        "/app": (200, "text/html", '<script src="/b/abc1234/index.js"></script>') if good else (404, "text/plain", "x"),
        "/version.json": (200, "application/json", '{"commit": "abc1234"}'),
        "/api/share?op=list&page=1": (200, "application/json", '{"models": [{"id": "AAAAAAAAAA", "name": "No picture", "image": null},'
            ' {"id": "BBBBBBBBBB", "name": "Fire & Ice", "image": "https://x/m/BBBBBBBBBB.png"}]}'),
        "/m/BBBBBBBBBB": (200, "text/html", '<a class="picture" href="/app"><img src="/m/BBBBBBBBBB.png" alt=""></a><h1>Fire &amp; Ice</h1>'),
        "/m/BBBBBBBBBB.png": (200, "image/png", "p" * 5000),
        "/talk.js": (404, "text/html", "gone"),
    }
    status, kind, text = pages.get(path, (404, "text/html", "gone"))
elif path == "/app":
    host = read("points." + parts.netloc) or parts.netloc
    build = read("build." + host)
    status, kind, text = 200, "text/html", f'<script src="/b/{build}/index.js"></script>' if build else "none"
if out:
    open(out, "w").write(text)
else:
    sys.stdout.write(text)
if fmt:
    sys.stdout.write(fmt.replace("%{http_code}", str(status)).replace("%{content_type}", kind)
                     .replace("%{size_download}", str(len(text))))
"""

# heavy as check runs the browser through it: the browser's lines from STUB_LOOK, its exit STUB_LOOK_EXIT.
HEAVY = r"""#!/bin/bash
echo "$*" >> "$STUB/heavy.log"
printf '%b' "${STUB_LOOK:-}"
exit "${STUB_LOOK_EXIT:-0}"
"""

# Anything that would reach Vercel or the network for real, on the PATH first: called, it says so and fails.
REAL = r"""#!/bin/bash
echo "$(basename "$0") $*" >> "$STUB/real.log"
exit 99
"""

GOOD = "https://brickworks-good1-xaxis-projects.vercel.app"
BAD = "https://brickworks-bad1-xaxis-projects.vercel.app"


def _stub(tmp: pathlib.Path) -> pathlib.Path:
    stub = tmp / "stub"
    (stub / "bin").mkdir(parents=True)
    for name, text in (("vercel", VERCEL), ("check", CHECK), ("bin/curl", CURL), ("heavy", HEAVY),
                       ("bin/vc", REAL), ("bin/vercel", REAL), ("bin/npx", REAL), ("bin/node", REAL), ("bin/wget", REAL)):
        (stub / name).write_text(text)
        (stub / name).chmod(0o755)
    (stub / "build.brickworks-good1-xaxis-projects.vercel.app").write_text("1111111\n")
    (stub / "build.brickworks-bad1-xaxis-projects.vercel.app").write_text("2222222\n")
    (stub / "good").write_text("1111111\n")
    return stub


def _run(stub: pathlib.Path, *args: str, **env: str) -> subprocess.CompletedProcess:
    full = dict(os.environ, STUB=str(stub), PATH=f"{stub / 'bin'}:{os.environ['PATH']}", VERCEL_TOKEN="stubtoken",
                VERCEL_BYPASS="stubbypass", SUPABASE_URL="http://supabase.stub", SUPABASE_SECRET_KEY="stubkey",
                LIVE_SMOKE_VERCEL=str(stub / "vercel"), LIVE_SMOKE_CHECK=str(stub / "check"),
                LIVE_SMOKE_HEAVY=str(stub / "heavy"), LIVE_SMOKE_AGAIN_WAIT="0", LIVE_SMOKE_REFUSED_WAIT="0",
                LIVE_SMOKE_SERVES_WAIT="3", LIVE_SMOKE_POLL="1", TMPDIR=str(stub), **env)
    full.pop("BOX_HEAVY_PRIORITY", None)
    run = subprocess.run(["bash", str(SCRIPT), *args], env=full, capture_output=True, text=True,
                         stdin=subprocess.DEVNULL, timeout=120)
    assert not _read(stub, "real.log"), f"reached past the stand-ins: {_read(stub, 'real.log')}"
    return run


def _read(stub: pathlib.Path, name: str) -> str:
    path = stub / name
    return path.read_text() if path.exists() else ""


def _points(stub: pathlib.Path, domain: str, url: str) -> None:
    (stub / f"points.{domain}").write_text(url.removeprefix("https://") + "\n")


def test_arguments_it_does_not_take_are_refused_before_anything_runs(tmp_path):
    # ship.sh runs it as "$HERE/live_smoke.sh", as it runs release_live.sh.
    assert os.access(SCRIPT, os.X_OK), f"{SCRIPT} is not executable"
    stub = _stub(tmp_path)
    for args in [(), ("promote",), ("current", "a", "b"), ("check",), ("check", "brickworks.diy"),
                 ("check", "https://x.vercel.app/app"), ("check", "https://a", "https://b"),
                 ("guard", "brickworks.diy", GOOD), ("guard", "brickworks.diy", "https://example.com", "rel-m1"),
                 ("guard", "brickworks.diy", GOOD, "Rel m1!"), ("guard", "brickworks.diy", GOOD, "a" * 30),
                 ("guard", "https://", GOOD, "rel-m1")]:
        run = _run(stub, *args)
        assert run.returncode == 64, (args, run.returncode, run.stdout, run.stderr)
        assert "usage: live_smoke.sh" in run.stderr, (args, run.stderr)
    assert not _read(stub, "vercel.log") and not _read(stub, "checks") and not _read(stub, "curl.log")


def test_current_names_the_deployment_the_domain_points_at(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks.diy", GOOD)
    run = _run(stub, "current")
    assert run.returncode == 0 and run.stdout.strip() == GOOD, (run.stdout, run.stderr)
    team = json.loads((ROOT / ".vercel/project.json").read_text())["orgId"] if (ROOT / ".vercel/project.json").exists() else ""
    asked = _read(stub, "vercel.log").splitlines()
    assert asked[0].startswith("inspect brickworks.diy --scope ") and asked[0].endswith(" --token stubtoken"), asked
    assert not team or f"--scope {team} " in asked[0], asked
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "current", "https://brickworks-x-rb.vercel.app/")
    assert run.returncode == 0 and run.stdout.strip() == BAD, (run.stdout, run.stderr)
    # A domain Vercel does not know: nothing on stdout for ship.sh to roll back to, and why on stderr.
    run = _run(stub, "current", "nowhere.vercel.app")
    assert run.returncode == 1 and run.stdout == "" and "could not tell what nowhere.vercel.app points at" in run.stderr, run


def test_a_domain_that_passes_is_left_as_it_is(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", GOOD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", BAD, "rel-m9")
    assert run.returncode == 0, run.stdout
    assert "live_smoke: brickworks-x-rb.vercel.app passed its live smoke (rel-m9" in run.stdout, run.stdout
    assert _read(stub, "checks").strip() == "1" and not _read(stub, "vercel.log") and not _read(stub, "rpc.log")


def test_a_flake_is_asked_again_and_passes(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", GOOD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", BAD, "rel-m9", STUB_FLAKE="1")
    assert run.returncode == 0, run.stdout
    assert "passed its live smoke on its second go" in run.stdout, run.stdout
    assert _read(stub, "checks").strip() == "2" and not _read(stub, "vercel.log")
    # The check's own lines are indented: only the guard's begin "live_smoke: ".
    assert "\n  live_smoke: FAILED https://brickworks-x-rb.vercel.app (build 1111111, 1s): a flake" in run.stdout, run.stdout


def test_an_alias_that_fails_twice_goes_back_and_is_written_down(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", GOOD, "REL-m9")
    assert run.returncode == 3, run.stdout
    checked = _read(stub, "checked").split()
    # Twice on the domain, the build before on its own URL, then the domain again once it serves that build.
    assert checked == ["https://brickworks-x-rb.vercel.app"] * 2 + [GOOD, "https://brickworks-x-rb.vercel.app"], checked
    assert _read(stub, "vercel.log").splitlines()[0].startswith(f"alias set {GOOD} brickworks-x-rb.vercel.app --scope "), \
        _read(stub, "vercel.log")
    assert "rollback" not in _read(stub, "vercel.log")
    said = [line for line in run.stdout.splitlines() if line.startswith("live_smoke: rolled back")]
    assert len(said) == 1 and said[0].startswith(f"live_smoke: rolled back brickworks-x-rb.vercel.app to {GOOD} (build 1111111): "
                                                 "rel-m9 failed its live smoke twice: the home page is not the site's"), said
    rows = [json.loads(line) for line in _read(stub, "rpc.log").splitlines()]
    assert len(rows) == 1, rows
    assert rows[0]["p_tag"] == "rel-m9-rolled-back" and rows[0]["p_sha"] == "1111111" and rows[0]["p_live_at"] is None, rows
    assert rows[0]["p_title"].startswith("rel-m9 failed its live smoke on brickworks-x-rb.vercel.app twice (the home page is not "
                                         "the site's) and was rolled back"), rows
    assert rows[0]["p_title"].endswith("serves 1111111 again, which passes the smoke"), rows
    assert "release_live: rel-m9-rolled-back (1111111) written down" in run.stdout, run.stdout
    # The alias asked which build it serves: a *.vercel.app host is behind the deployment's protection, so with the bypass.
    assert "brickworks-x-rb.vercel.app/app bypass=True" in _read(stub, "curl.log"), _read(stub, "curl.log")


def test_the_production_domain_goes_back_by_vercel_rollback(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks.diy", BAD)
    run = _run(stub, "guard", "brickworks.diy", GOOD, "rel-m9")
    assert run.returncode == 3, run.stdout
    asked = _read(stub, "vercel.log").splitlines()
    assert len(asked) == 1 and asked[0].startswith(f"rollback {GOOD} --yes --timeout 3m --scope "), asked
    # brickworks.diy is not a deployment's own URL: the bypass never goes there.
    assert "brickworks.diy/app bypass=False" in _read(stub, "curl.log") and "brickworks.diy/app bypass=True" not in _read(stub, "curl.log")
    assert "live_smoke: rolled back brickworks.diy to " in run.stdout


def test_nothing_is_rolled_back_when_the_build_before_fails_too(tmp_path):
    stub = _stub(tmp_path)
    (stub / "good").write_text("9999999\n")
    _points(stub, "brickworks.diy", BAD)
    run = _run(stub, "guard", "brickworks.diy", GOOD, "rel-m9")
    assert run.returncode == 1, run.stdout
    assert "live_smoke: FAILED, not rolled back: brickworks.diy fails its live smoke" in run.stdout, run.stdout
    assert f"and {GOOD} fails it too" in run.stdout and "what is live stays" in run.stdout, run.stdout
    assert not _read(stub, "vercel.log") and not _read(stub, "rpc.log")
    assert "live_smoke: rolled back" not in run.stdout


def test_rolled_back_and_failing_there_too_is_1_and_still_written_down(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", GOOD, "rel-m9", STUB_DOMAIN_FAILS="1")
    assert run.returncode == 1, run.stdout
    assert "live_smoke: rolled back brickworks-x-rb.vercel.app to " in run.stdout
    assert "the build before fails there too: /app answers 500" in run.stdout, run.stdout
    rows = [json.loads(line) for line in _read(stub, "rpc.log").splitlines()]
    assert len(rows) == 1 and rows[0]["p_title"].endswith("which fails the smoke too (/app answers 500)"), rows


def test_no_verdict_is_2_and_nothing_moves(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks.diy", BAD)
    run = _run(stub, "guard", "brickworks.diy", GOOD, "rel-m9", STUB_NOVERDICT="1")
    assert run.returncode == 2, run.stdout
    assert "live_smoke: no verdict on brickworks.diy (not checked https://brickworks.diy: heavy: no slot" in run.stdout, run.stdout
    assert _read(stub, "checks").strip() == "2" and not _read(stub, "vercel.log") and not _read(stub, "rpc.log")


def test_a_refused_move_is_asked_once_more_then_given_up(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", GOOD, "rel-m9", STUB_MOVE_FAILS="1")
    assert run.returncode == 3 and _read(stub, "moves").strip() == "2", run.stdout
    assert "the first ask to move brickworks-x-rb.vercel.app was refused" in run.stdout, run.stdout
    stub = _stub(tmp_path / "again")
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", GOOD, "rel-m9", STUB_MOVE_FAILS="2")
    assert run.returncode == 1 and "live_smoke: FAILED, could not roll brickworks-x-rb.vercel.app back" in run.stdout, run.stdout
    assert "live_smoke: rolled back" not in run.stdout and not _read(stub, "rpc.log")


def test_a_refusal_after_the_move_was_made_is_not_asked_again(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks.diy", BAD)
    run = _run(stub, "guard", "brickworks.diy", GOOD, "rel-m9", STUB_MOVE_FAILS="1", STUB_MOVED_ANYWAY="1")
    assert run.returncode == 3, run.stdout
    assert _read(stub, "moves").strip() == "1" and "refused" not in run.stdout, run.stdout
    assert "live_smoke: rolled back brickworks.diy to " in run.stdout, run.stdout


def test_the_gallerys_model_ids_are_checked_before_a_page_is_asked(tmp_path):
    stub = _stub(tmp_path)
    (stub / "site.example.test").write_text("good\n")
    run = _run(stub, "check", "https://example.test", STUB_LOOK="  ok    home: fine  [1.0s]\n")
    assert run.returncode == 0 and "its first model with a picture is BBBBBBBBBB" in run.stdout, run.stdout
    assert "/m/AAAAAAAAAA" not in _read(stub, "curl.log"), "a model with no picture was asked for"


def test_a_move_the_domain_never_shows_is_1_with_no_rolled_back_line(tmp_path):
    stub = _stub(tmp_path)
    _points(stub, "brickworks-x-rb.vercel.app", BAD)
    run = _run(stub, "guard", "brickworks-x-rb.vercel.app", GOOD, "rel-m9", STUB_STUCK="1")
    assert run.returncode == 1, run.stdout
    assert "but it serves 2222222 (not 1111111) after 3 s" in run.stdout, run.stdout
    assert "live_smoke: rolled back" not in run.stdout and not _read(stub, "rpc.log")


def test_check_says_each_broken_page_and_never_starts_a_browser_over_them(tmp_path):
    stub = _stub(tmp_path)
    (stub / "site.broken.vercel.app").write_text("broken\n")
    run = _run(stub, "check", "https://broken.vercel.app")
    assert run.returncode == 1, run.stdout
    last = run.stdout.strip().splitlines()[-1]
    assert last.startswith("live_smoke: FAILED https://broken.vercel.app (build none"), last
    assert "the home page is not the site's: no header, main or heading in it (titled \"Not the site\")" in last, last
    assert "/app answers 404" in last and "no Talk on this build" in run.stdout, run.stdout
    assert not _read(stub, "heavy.log")
    # Every GET cache-busted (the stand-in drops ?_smoke= and logs what is left) and with the bypass, a deployment's.
    asked = _read(stub, "curl.log").splitlines()
    assert asked and all(line.endswith("bypass=True") for line in asked), asked


def test_check_passes_a_good_site_through_the_browser_and_keeps_the_bypass_at_home(tmp_path):
    stub = _stub(tmp_path)
    (stub / "site.example.test").write_text("good\n")
    look = "heavy: waiting\\n  ok    home: holds together  [1.0s]\\n  ok    app: up  [9.0s]\\nbrowser: all 2 parts hold\\n"
    run = _run(stub, "check", "https://example.test", STUB_LOOK=look)
    assert run.returncode == 0, run.stdout
    assert run.stdout.strip().splitlines()[-1].startswith(
        "live_smoke: passed https://example.test (build abc1234 of abc1234, "), run.stdout
    assert "/m/BBBBBBBBBB is titled \"Fire & Ice\", its picture answers" in run.stdout, run.stdout
    assert "  ok    app: up  [9.0s]" in run.stdout and "heavy: waiting" not in run.stdout, run.stdout
    browser = _read(stub, "heavy.log")
    assert "node tools/web/live_smoke.mjs --origin=https://example.test --model=BBBBBBBBBB --name=Fire & Ice" in browser, browser
    assert "--talk" not in browser
    # Not a deployment's own URL: no GET carried the bypass.
    asked = _read(stub, "curl.log").splitlines()
    assert asked and all(line.endswith("bypass=False") for line in asked), asked


def test_the_gets_alone_say_so_and_start_no_browser(tmp_path):
    stub = _stub(tmp_path)
    (stub / "site.example.test").write_text("good\n")
    run = _run(stub, "check", "https://example.test", LIVE_SMOKE_BROWSER="0")
    assert run.returncode == 0 and not _read(stub, "heavy.log"), run.stdout
    assert run.stdout.strip().splitlines()[-1].startswith("live_smoke: passed https://example.test (build abc1234 of abc1234, ")
    assert " (GETs only): home, /m/BBBBBBBBBB, /app; no Talk on this build" in run.stdout, run.stdout


def test_check_without_a_browser_has_no_verdict_and_with_a_failing_one_says_why(tmp_path):
    stub = _stub(tmp_path)
    (stub / "site.example.test").write_text("good\n")
    run = _run(stub, "check", "https://example.test", STUB_LOOK="heavy: no slot within 1200 s (brickworks)\\n", STUB_LOOK_EXIT="2")
    assert run.returncode == 2, run.stdout
    assert run.stdout.strip().splitlines()[-1] == "live_smoke: not checked https://example.test: heavy: no slot within 1200 s (brickworks)"
    look = "  ok    home: holds together  [1.0s]\\n  FAIL  app: the app did not come up within 180 s (canvas there, 0 controls told)  [180.2s]\\n"
    run = _run(stub, "check", "https://example.test", STUB_LOOK=look, STUB_LOOK_EXIT="1")
    assert run.returncode == 1, run.stdout
    assert run.stdout.strip().splitlines()[-1].endswith(
        "): app: the app did not come up within 180 s (canvas there, 0 controls told)"), run.stdout
